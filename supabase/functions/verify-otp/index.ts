// supabase/functions/verify-otp/index.ts

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, content-type, apikey, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const expectedSecret = Deno.env.get("INTERNAL_FUNCTION_SECRET")?.trim();
  const providedSecret = req.headers.get("x-internal-function-secret")?.trim();
  if (!expectedSecret || providedSecret !== expectedSecret) {
    return new Response(JSON.stringify({ error: "unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
  try {
    const { phone, code, loginMode = "user" } = await req.json();

    if (typeof phone !== "string" || typeof code !== "string") {
      return errorResponse("الرقم والكود مطلوبين");
    }

    // ✅ ننضف الرقم
    let cleanPhone = phone.replace(/\D/g, "");
    if (cleanPhone.startsWith("0")) {
      cleanPhone = "20" + cleanPhone.slice(1);
    } else if (cleanPhone.length === 10) {
      cleanPhone = "20" + cleanPhone;
    }

    const cleanCode = String(code).trim();
    if (!/^\d{6}$/.test(cleanCode)) {
      return errorResponse("بيانات التحقق غير صحيحة");
    }
    const { data: otpResult, error: consumeError } = await supabase.rpc(
      "consume_otp_challenge",
      {
        p_phone: cleanPhone,
        p_code: cleanCode,
        p_login_mode: loginMode,
      },
    );
    if (consumeError) {
      console.error("OTP consumption failed", consumeError.code);
      return errorResponse("تعذر التحقق الآن، حاول مرة أخرى", 503);
    }
    if (otpResult?.success !== true) {
      const reason = otpResult?.reason;
      const message = reason === "expired"
        ? "انتهت صلاحية الكود، اطلب كود جديد"
        : reason === "attempts_exceeded"
        ? "تجاوزت عدد المحاولات، اطلب كود جديد"
        : reason === "not_found" || reason === "already_consumed"
        ? "مفيش كود صالح، اطلب كود جديد"
        : "الكود غلط، حاول تاني";
      return errorResponse(message, reason === "attempts_exceeded" ? 429 : 400);
    }

    // ✅ نجيب الـ user (لو موجود)
    const { data: existingUser } = await supabase
      .from("users")
      .select("id")
      .eq("phone", cleanPhone)
      .maybeSingle();

    if (existingUser) {
      // ─── مستخدم قديم → نعمل sign in ───
      const { data: session, error: signInError } =
        await supabase.auth.admin.generateLink({
          type: "magiclink",
          email: `${cleanPhone}@loqma.app`,
        });

    if (signInError) {
        console.error("SignIn error:", signInError.code);
        return errorResponse("تعذر تسجيل الدخول", 503);
      }

      return new Response(
        JSON.stringify({
          success: true,
          isNewUser: false,
          message: "تم التحقق، مرحبًا بيك تاني",
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // ─── مستخدم جديد → نرجع بس "verified" ونخلي Flutter يكمل ───
    return new Response(
      JSON.stringify({
        success: true,
        isNewUser: true,
        message: "تم التحقق، كمّل التسجيل",
        phone: cleanPhone,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (e) {
    console.error(
      "verify-otp failed:",
      e instanceof Error ? e.name : "unknown_error",
    );
    return errorResponse("خطأ غير متوقع", 500);
  }
});

function errorResponse(message: string, status = 400) {
  return new Response(JSON.stringify({ success: false, error: message }), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
