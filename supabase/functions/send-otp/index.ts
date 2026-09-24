// supabase/functions/send-otp/index.ts

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

const WAPILOT_TOKEN = Deno.env.get("WAPILOT_TOKEN")!;
const WAPILOT_BASE = "https://api.wapilot.net/api";
const INSTANCE_ID = "instance5127";

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
    const { phone } = await req.json();

    if (!phone) {
      return errorResponse("رقم الهاتف مطلوب");
    }

    // ✅ ننضف الرقم
    let cleanPhone = phone.replace(/\D/g, "");
    if (cleanPhone.startsWith("0")) {
      cleanPhone = "20" + cleanPhone.slice(1);
    } else if (cleanPhone.length === 10) {
      cleanPhone = "20" + cleanPhone;
    }

    if (cleanPhone.length < 10 || cleanPhone.length > 15) {
      return errorResponse("رقم الهاتف غير صحيح");
    }

    // ✅ نشيل الأكواد القديمة
    await supabase
      .from("otp_codes")
      .delete()
      .eq("phone", cleanPhone)
      .eq("verified", false);

    // ✅ نولّد كود 6 أرقام
    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000).toISOString();

    // ✅ نحفظ الكود
    const { error: insertError } = await supabase
      .from("otp_codes")
      .insert({
        phone: cleanPhone,
        code,
        expires_at: expiresAt,
      });

    if (insertError) {
      console.error("Insert error:", insertError);
      return errorResponse("تعذر إنشاء الكود");
    }

    // ✅ نبعت على واتساب
    const waResponse = await fetch(
      `${WAPILOT_BASE}/v2/${INSTANCE_ID}/send-message`,
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${WAPILOT_TOKEN}`,
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: JSON.stringify({
          to: cleanPhone,
          text: `🔐 كود التحقق بتاعك في Loqma:\n\n*${code}*\n\nصالح لمدة 5 دقايق.\n\n⚠️ متشاركهوش مع حد.`,
        }),
      }
    );

    if (!waResponse.ok) {
      const err = await waResponse.text();
      console.error("WhatsApp error:", err);
      return errorResponse("تعذر إرسال الكود، حاول تاني");
    }

    console.log(`✅ OTP sent to ${cleanPhone}`);

    return new Response(
      JSON.stringify({
        success: true,
        message: "تم إرسال الكود على واتساب",
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