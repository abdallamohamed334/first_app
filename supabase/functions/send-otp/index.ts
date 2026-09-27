// supabase/functions/send-otp/index.ts

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const WAPILOT_TOKEN = Deno.env.get("WAPILOT_TOKEN")!;
const WAPILOT_BASE = "https://api.wapilot.net/api";
const INSTANCE_ID = "instance5694";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, content-type, apikey, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type LoginMode = "user" | "provider";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return errorResponse("طريقة الطلب غير صحيحة", 405);
  }

  try {
    const body = await req.json();
    const phone = typeof body?.phone === "string" ? body.phone : "";
    const loginMode = body?.loginMode as LoginMode | undefined;

    if (!phone.trim()) {
      return errorResponse("رقم الهاتف مطلوب", 400);
    }

    if (loginMode !== "user" && loginMode !== "provider") {
      return errorResponse("نوع الدخول مطلوب: user أو provider", 400);
    }

    const cleanPhone = normalizeEgyptianPhone(phone);

    if (!cleanPhone) {
      return errorResponse("رقم الهاتف غير صحيح", 400);
    }

    // افحص الحالة قبل حذف أو إنشاء أو إرسال أي OTP.
    const { data: access, error: accessError } = await supabase.rpc(
      "check_phone_access",
      {
        p_phone: cleanPhone,
        p_login_mode: loginMode,
      },
    );

    if (accessError) {
      console.error("check_phone_access error:", accessError);
      return errorResponse("تعذر التحقق من صلاحية الرقم", 500);
    }

    if (!access || access.allowed !== true) {
      console.warn(
        `OTP blocked: phone=${cleanPhone}, mode=${loginMode}, reason=${access?.reason}`,
      );

      return new Response(
        JSON.stringify({
          success: false,
          error: access?.message ?? "لا يمكن إرسال كود لهذا الرقم",
          reason: access?.reason ?? "phone_not_allowed",
        }),
        {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const { error: deleteError } = await supabase
      .from("otp_codes")
      .delete()
      .eq("phone", cleanPhone)
      .eq("verified", false);

    if (deleteError) {
      console.error("Delete old OTP error:", deleteError);
      return errorResponse("تعذر تجهيز كود التحقق", 500);
    }

    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000).toISOString();

    const { error: insertError } = await supabase
      .from("otp_codes")
      .insert({
        phone: cleanPhone,
        code,
        expires_at: expiresAt,
        verified: false,
      });

    if (insertError) {
      console.error("Insert OTP error:", insertError);
      return errorResponse("تعذر إنشاء الكود", 500);
    }

    const waResponse = await fetch(
      `${WAPILOT_BASE}/v2/${INSTANCE_ID}/send-message`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${WAPILOT_TOKEN}`,
          "Content-Type": "application/json",
          Accept: "application/json",
        },
        body: JSON.stringify({
          chat_id: cleanPhone,
          text:
            `🔐 كود التحقق بتاعك في وِصلة:\n\n` +
            `*${code}*\n\n` +
            `صالح لمدة 5 دقايق.\n\n` +
            `⚠️ متشاركهوش مع حد.`,
        }),
      },
    );

    if (!waResponse.ok) {
      const err = await waResponse.text();
      console.error("WhatsApp error:", err);

      await supabase
        .from("otp_codes")
        .delete()
        .eq("phone", cleanPhone)
        .eq("code", code)
        .eq("verified", false);

      return errorResponse("تعذر إرسال الكود، حاول تاني", 502);
    }

    console.log(`OTP sent to ${cleanPhone} for mode=${loginMode}`);

    return new Response(
      JSON.stringify({
        success: true,
        message: "تم إرسال الكود على واتساب",
        phone: cleanPhone,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (error) {
    console.error("send-otp error:", error);
    return errorResponse("خطأ غير متوقع", 500);
  }
});

function normalizeEgyptianPhone(input: string): string | null {
  let phone = input.replace(/\D/g, "");

  if (phone.startsWith("0020")) {
    phone = phone.slice(2);
  } else if (phone.startsWith("0") && phone.length === 11) {
    phone = `20${phone.slice(1)}`;
  } else if (phone.length === 10) {
    phone = `20${phone}`;
  }

  if (!/^20\d{10}$/.test(phone)) {
    return null;
  }

  return phone;
}

function errorResponse(message: string, status = 400) {
  return new Response(
    JSON.stringify({ success: false, error: message }),
    {
      status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    },
  );
}
