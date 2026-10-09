import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const wapilotToken = Deno.env.get("WAPILOT_TOKEN") ?? "";
const wapilotBase = "https://api.wapilot.net/api";
const instanceId = "instance5694";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, content-type, apikey, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function normalizeEgyptianPhone(input: string): string | null {
  let phone = input.replace(/\D/g, "");
  if (phone.startsWith("0020")) phone = phone.slice(2);
  else if (phone.startsWith("0") && phone.length === 11) {
    phone = `20${phone.slice(1)}`;
  } else if (phone.length === 10) {
    phone = `20${phone}`;
  }
  return /^20\d{10}$/.test(phone) ? phone : null;
}

function randomOtp(): string {
  const value = new Uint32Array(1);
  crypto.getRandomValues(value);
  return String(value[0] % 1_000_000).padStart(6, "0");
}

function randomSalt(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(16));
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
}

async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return Array.from(new Uint8Array(digest), (byte) =>
    byte.toString(16).padStart(2, "0")
  ).join("");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }
  if (!supabaseUrl || !anonKey || !serviceRoleKey || !wapilotToken) {
    return jsonResponse({ error: "service_not_configured" }, 503);
  }

  const authorization = req.headers.get("Authorization") ?? "";
  const tokenMatch = authorization.match(/^Bearer\s+(.+)$/i);
  if (!tokenMatch) return jsonResponse({ error: "unauthorized" }, 401);

  try {
    const body = await req.json();
    const partnerType = body?.partnerType;
    if (partnerType !== "institution" && partnerType !== "charity") {
      return jsonResponse({ error: "invalid_partner_type" }, 400);
    }

    const authClient = createClient(supabaseUrl, anonKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { data: authData, error: authError } = await authClient.auth.getUser(
      tokenMatch[1],
    );
    const user = authData.user;
    if (authError || !user) return jsonResponse({ error: "unauthorized" }, 401);

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const table = partnerType === "institution" ? "institutions" : "charities";
    const { data: partners, error: partnerError } = await admin
      .from(table)
      .select("id, phone")
      .eq("user_id", user.id)
      .in("status", ["approved", "active"])
      .limit(2);

    if (partnerError || !partners || partners.length !== 1) {
      console.warn("Partner OTP request rejected", partnerType);
      return jsonResponse({ error: "partner_not_allowed" }, 403);
    }

    const partner = partners[0];
    const phone = typeof partner.phone === "string"
      ? normalizeEgyptianPhone(partner.phone)
      : null;
    if (!phone) return jsonResponse({ error: "registered_phone_invalid" }, 409);

    const code = randomOtp();
    const salt = randomSalt();
    const codeHash = await sha256Hex(`${code}:${salt}`);
    const { data: challenge, error: challengeError } = await admin.rpc(
      "create_partner_login_otp_challenge",
      {
        p_user_id: user.id,
        p_partner_type: partnerType,
        p_partner_id: partner.id,
        p_code_hash: codeHash,
        p_salt: salt,
      },
    );

    if (challengeError) {
      console.error("Partner OTP challenge creation failed", challengeError.code);
      return jsonResponse({ error: "challenge_unavailable" }, 503);
    }
    if (challenge?.success !== true) {
      const isCooldown = challenge?.reason === "cooldown";
      return jsonResponse(
        { error: isCooldown ? "cooldown" : "partner_not_allowed" },
        isCooldown ? 429 : 403,
      );
    }

    let deliveryResponse: Response;
    try {
      deliveryResponse = await fetch(
        `${wapilotBase}/v2/${instanceId}/send-message`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${wapilotToken}`,
            "Content-Type": "application/json",
            Accept: "application/json",
          },
          body: JSON.stringify({
            chat_id: phone,
            text:
              `رمز الدخول المؤقت لتطبيق وِصلة هو: *${code}*\n` +
              `صالح لمدة 5 دقائق ولمرة واحدة. لا تشاركه مع أي شخص.`,
          }),
          signal: AbortSignal.timeout(10_000),
        },
      );
    } catch (_) {
      deliveryResponse = new Response(null, { status: 502 });
    }

    if (!deliveryResponse.ok) {
      await deliveryResponse.text();
      await admin
        .from("partner_login_otp_challenges")
        .update({ consumed_at: new Date().toISOString() })
        .eq("user_id", user.id)
        .eq("partner_type", partnerType)
        .eq("partner_id", partner.id)
        .eq("code_hash", codeHash)
        .is("consumed_at", null);
      console.error("Partner OTP provider rejected delivery", partnerType);
      return jsonResponse({ error: "delivery_failed" }, 502);
    }

    const maskedPhone = `${phone.slice(0, 4)}******${phone.slice(-2)}`;
    return jsonResponse({ success: true, phone: maskedPhone });
  } catch (_) {
    console.error("Partner OTP request failed");
    return jsonResponse({ error: "unexpected_error" }, 500);
  }
});
