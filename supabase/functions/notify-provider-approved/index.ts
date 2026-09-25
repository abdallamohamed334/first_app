// supabase/functions/notify-provider-approved/index.ts

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// ═══════════════════════════════════════════════════════════
// 🔧 Helpers
// ═══════════════════════════════════════════════════════════
function cleanPhoneIntl(phone: string): string {
  let cleaned = phone.replace(/\D/g, "");
  if (cleaned.startsWith("0") && cleaned.length === 11) {
    return "20" + cleaned.substring(1);
  }
  if (cleaned.startsWith("20") && cleaned.length === 12) {
    return cleaned;
  }
  if (cleaned.length === 10 && cleaned.startsWith("1")) {
    return "20" + cleaned;
  }
  return cleaned;
}

// ═══════════════════════════════════════════════════════════
// 📱 إرسال واتساب (Meta Cloud API)
// ═══════════════════════════════════════════════════════════
async function sendWhatsApp(
  phone: string,
  message: string,
): Promise<{ success: boolean; error?: string }> {
  const WHATSAPP_TOKEN = Deno.env.get("WHATSAPP_TOKEN");
  const WHATSAPP_PHONE_ID = Deno.env.get("WHATSAPP_PHONE_ID");

  if (!WHATSAPP_TOKEN || !WHATSAPP_PHONE_ID) {
    return {
      success: false,
      error: "WHATSAPP_TOKEN or WHATSAPP_PHONE_ID not configured",
    };
  }

  const url = `https://graph.facebook.com/v20.0/${WHATSAPP_PHONE_ID}/messages`;

  try {
    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${WHATSAPP_TOKEN}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        messaging_product: "whatsapp",
        to: phone,
        type: "text",
        text: { body: message },
      }),
    });

    const data = await response.json();

    if (!response.ok) {
      console.error("WhatsApp API error:", JSON.stringify(data));
      return {
        success: false,
        error: data?.error?.message || `HTTP ${response.status}`,
      };
    }

    return { success: true };
  } catch (error) {
    console.error("WhatsApp fetch error:", error);
    return { success: false, error: String(error) };
  }
}

// ═══════════════════════════════════════════════════════════
// 🚀 Handler
// ═══════════════════════════════════════════════════════════
serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const payload = await req.json();

    console.log("📥 Payload:", JSON.stringify(payload));

    const record = payload.record || {};
    const oldRecord = payload.old_record || {};

    // ✅ نتحقق إنها حالة قبول
    if (record.verification_status !== "approved") {
      console.log("⏭️ Not approved, skipping");
      return new Response(
        JSON.stringify({ success: true, skipped: true, reason: "not approved" }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // ✅ لو كانت approved قبل كده، منبعتش تاني
    if (oldRecord.verification_status === "approved") {
      console.log("⏭️ Already was approved, skipping");
      return new Response(
        JSON.stringify({ success: true, skipped: true, reason: "already approved" }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // ✅ نجيب رقم المزود
    const phone = record.phone || record.whatsapp;
    const name = record.display_name || "مزود خدمة";

    if (!phone) {
      return new Response(
        JSON.stringify({ success: false, error: "No phone in record" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const cleanPhone = cleanPhoneIntl(phone);

    // ═══════════════════════════════════════════════════════
    // ✉️ نص الرسالة
    // ═══════════════════════════════════════════════════════
    const message =
      `🎉 مبروك ${name}!\n\n` +
      `تم قبول حسابك كمزود خدمة في جُود ✅\n\n` +
      `دلوقتي تقدر:\n` +
      `• تسجّل دخولك على التطبيق\n` +
      `• تستقبل طلبات من العملاء\n` +
      `• تكمل ملفك الشخصي\n\n` +
      `نتمنى لك التوفيق 🙏\n` +
      `فريق جُود`;

    const result = await sendWhatsApp(cleanPhone, message);

    console.log("✅ WhatsApp result:", JSON.stringify(result));

    return new Response(JSON.stringify(result), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("❌ Handler error:", error);
    return new Response(
      JSON.stringify({ success: false, error: String(error) }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});