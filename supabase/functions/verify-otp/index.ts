// supabase/functions/verify-otp/index.ts

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type, apikey, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { phone, code } = await req.json();

    if (!phone || !code) {
      return errorResponse("الرقم والكود مطلوبين");
    }

    // ✅ ننضف الرقم
    let cleanPhone = phone.replace(/\D/g, "");
    if (cleanPhone.startsWith("0")) {
      cleanPhone = "20" + cleanPhone.slice(1);
    } else if (cleanPhone.length === 10) {
      cleanPhone = "20" + cleanPhone;
    }

    // ✅ نجيب الكود
    const { data: otpData, error: fetchError } = await supabase
      .from("otp_codes")
      .select("*")
      .eq("phone", cleanPhone)
      .eq("verified", false)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (fetchError || !otpData) {
      return errorResponse("مفيش كود لهذا الرقم، اطلب كود جديد");
    }

    // ✅ نشوف الوقت
    if (new Date(otpData.expires_at) < new Date()) {
      return errorResponse("انتهت صلاحية الكود، اطلب كود جديد");
    }

    // ✅ نشوف المحاولات
    if (otpData.attempts >= 5) {
      return errorResponse("تجاوزت عدد المحاولات، اطلب كود جديد");
    }

    // ✅ نتحقق من الكود
    if (otpData.code !== code) {
      await supabase
        .from("otp_codes")
        .update({ attempts: otpData.attempts + 1 })
        .eq("id", otpData.id);

      return errorResponse("الكود غلط، حاول تاني");
    }

    // ✅ علامة إنه اتأكد
    await supabase
      .from("otp_codes")
      .update({ verified: true })
      .eq("id", otpData.id);

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
        console.error("SignIn error:", signInError);
        return errorResponse("تعذر تسجيل الدخول");
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
        }
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
      }
    );
  } catch (e) {
    console.error("Error:", e);
    return errorResponse(e.message || "خطأ غير متوقع");
  }
});

function errorResponse(message: string) {
  return new Response(
    JSON.stringify({ success: false, error: message }),
    {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    }
  );
}