import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const url = Deno.env.get("SUPABASE_URL") ?? "";
const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const wapilotToken = Deno.env.get("WAPILOT_TOKEN") ?? "";
const admin = createClient(url, serviceKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ success: false, error: "method_not_allowed" }, 405);

  try {
    const authorization = req.headers.get("Authorization") ?? "";
    const token = authorization.replace(/^Bearer\s+/i, "").trim();
    if (!token) return json({ success: false, error: "unauthorized" }, 401);

    const { data: authData, error: authError } = await admin.auth.getUser(token);
    const user = authData.user;
    if (authError || !user) return json({ success: false, error: "unauthorized" }, 401);

    const publicClient = createClient(url, anonKey, {
      global: { headers: { Authorization: `Bearer ${token}` } },
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { data: profile, error: profileError } = await admin
      .from("users")
      .select("phone_normalized")
      .eq("id", user.id)
      .maybeSingle();
    const phone = normalizePhone(String(profile?.phone_normalized ?? ""));
    if (profileError || !phone) {
      console.warn("Account deletion blocked: verified account phone unavailable");
      return json({ success: false, error: "تعذر التأكد من رقم الهاتف المرتبط بالحساب" }, 409);
    }

    let body: Record<string, unknown>;
    try {
      body = await req.json();
    } catch {
      return json({ success: false, error: "invalid_request" }, 400);
    }

    if (body.action === "request_code") {
      if (!wapilotToken) return json({ success: false, error: "خدمة إرسال كود التحقق غير متاحة الآن" }, 503);

      const ip = req.headers.get("cf-connecting-ip") ??
        req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "unknown";
      const rateKey = await sha256(`account-deletion-otp:v1:${user.id}:${ip}`);
      const { data: rateAllowed, error: rateError } = await admin.rpc(
        "consume_otp_rate_limit",
        { p_key: rateKey, p_window_seconds: 3600, p_max_requests: 3 },
      );
      if (rateError || rateAllowed !== true) {
        return json({ success: false, error: "وصلت للحد المسموح من الأكواد. حاول لاحقًا." }, 429);
      }

      const random = new Uint32Array(1);
      crypto.getRandomValues(random);
      const code = String(random[0] % 1_000_000).padStart(6, "0");
      const { data: challenge, error: challengeError } = await admin.rpc(
        "create_account_deletion_otp_challenge",
        {
          p_user_id: user.id,
          p_phone: phone,
          p_code: code,
          p_expires_at: new Date(Date.now() + 5 * 60 * 1000).toISOString(),
        },
      );
      if (challengeError || challenge?.success !== true) {
        const reason = challenge?.reason;
        return json(
          {
            success: false,
            error: reason === "cooldown"
              ? "انتظر دقيقة قبل طلب كود جديد"
              : "تعذر تجهيز كود التحقق، حاول مرة أخرى",
          },
          reason === "cooldown" ? 429 : 500,
        );
      }

      let deliveryResponse: Response;
      try {
        deliveryResponse = await fetch(
          "https://api.wapilot.net/api/v2/instance5694/send-message",
          {
            method: "POST",
            headers: {
              Authorization: `Bearer ${wapilotToken}`,
              "Content-Type": "application/json",
              Accept: "application/json",
            },
            body: JSON.stringify({
              chat_id: phone,
              text: `🔐 طلبت حذف حسابك في خِدمة.\n\nكود التأكيد: *${code}*\nصالح لمدة 5 دقائق.\n\nإذا لم تطلب الحذف، تجاهل الرسالة ولا تشارك الكود مع أي شخص.`,
            }),
            signal: AbortSignal.timeout(10000),
          },
        );
      } catch {
        deliveryResponse = new Response(null, { status: 502 });
      }
      if (!deliveryResponse.ok) {
        await admin
          .from("account_deletion_otp_challenges")
          .delete()
          .eq("user_id", user.id)
          .is("consumed_at", null);
        console.error("Account deletion OTP delivery failed", deliveryResponse.status);
        return json({ success: false, error: "تعذر إرسال الكود، حاول بعد قليل" }, 502);
      }

      console.log("Account deletion OTP sent");
      return json({
        success: true,
        phone_hint: `••••${phone.slice(-4)}`,
        expires_in_seconds: 300,
      });
    }

    if (body.action === "confirm") {
      const code = typeof body.code === "string" ? body.code.trim() : "";
      if (!/^\d{6}$/.test(code)) {
        return json({ success: false, error: "اكتب كود التحقق المكوّن من 6 أرقام" }, 400);
      }

      const { data: verification, error: verificationError } = await admin.rpc(
        "consume_account_deletion_otp_challenge",
        { p_user_id: user.id, p_phone: phone, p_code: code },
      );
      if (verificationError) {
        console.error("Account deletion OTP verification failed", verificationError.code);
        return json({ success: false, error: "تعذر التحقق الآن، حاول مرة أخرى" }, 503);
      }
      if (verification?.success !== true) {
        const reason = verification?.reason;
        const message = reason === "expired"
          ? "انتهت صلاحية الكود. اطلب كودًا جديدًا."
          : reason === "attempts_exceeded"
          ? "تجاوزت عدد المحاولات. اطلب كودًا جديدًا."
          : "كود التحقق غير صحيح أو منتهي. راجعه وحاول مرة أخرى.";
        return json({ success: false, error: message }, reason === "attempts_exceeded" ? 429 : 400);
      }

      // This RPC uses auth.uid(), so execute it with the authenticated user's JWT.
      const { error: cleanupError } = await publicClient.rpc("delete_my_account");
      if (cleanupError) {
        console.error("Account cleanup failed", cleanupError.code);
        return json({ success: false, error: "تم التحقق، لكن تعذر حذف بيانات الحساب. تواصل مع الدعم." }, 500);
      }

      const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
      if (deleteError) {
        console.error("Auth account deletion failed", deleteError.code);
        return json({ success: false, error: "تم التحقق، لكن تعذر إكمال حذف الحساب. تواصل مع الدعم." }, 500);
      }

      console.log("Account deleted after OTP verification");
      return json({ success: true });
    }

    return json({ success: false, error: "طلب غير مدعوم" }, 400);
  } catch (error) {
    console.error(
      "delete-account failed",
      error instanceof Error ? error.name : "unknown",
    );
    return json({ success: false, error: "تعذر تنفيذ طلب حذف الحساب الآن" }, 500);
  }
});

function normalizePhone(input: string): string {
  let phone = input.replace(/\D/g, "");
  if (phone.startsWith("0020")) phone = phone.slice(2);
  else if (phone.startsWith("0") && phone.length === 11) phone = `20${phone.slice(1)}`;
  else if (phone.length === 10) phone = `20${phone}`;
  return /^20\d{10}$/.test(phone) ? phone : "";
}

async function sha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: corsHeaders });
}
