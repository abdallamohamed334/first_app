import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const API_BASE = "https://api.wapilot.net/api";
const INSTANCE_ID = "instance5127";
const API_TOKEN = Deno.env.get("WAPILOT_TOKEN")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type, apikey, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req) => {
  // ✅ CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { to, message } = await req.json();

    // ✅ Validation
    if (!to || !message) {
      return new Response(
        JSON.stringify({ error: "to و message مطلوبين" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ✅ ننضف الرقم
    let cleanPhone = to.replace(/[^\d]/g, "");
    if (cleanPhone.startsWith("0")) {
      cleanPhone = "20" + cleanPhone.substring(1);
    } else if (cleanPhone.length === 10) {
      cleanPhone = "20" + cleanPhone;
    }

    // ✅ نبعث الرسالة
    const response = await fetch(
      `${API_BASE}/v2/${INSTANCE_ID}/send-message`,
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${API_TOKEN}`,
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: JSON.stringify({
          to: cleanPhone,
          text: message,
        }),
      }
    );

    const data = await response.json();

    return new Response(
      JSON.stringify({
        success: response.ok,
        status: response.status,
        data,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});