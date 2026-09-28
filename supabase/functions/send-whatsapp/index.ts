import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const API_BASE = "https://api.wapilot.net/api";
const INSTANCE_ID = "instance5127";
const API_TOKEN = Deno.env.get("WAPILOT_TOKEN")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, content-type, apikey, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req) => {
  // ✅ CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return new Response(JSON.stringify({ error: "unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    const authClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } },
    );
    const {
      data: { user },
      error: authError,
    } = await authClient.auth.getUser();
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    const { to, message } = await req.json();

    // ✅ Validation
    if (
      typeof to !== "string" ||
      typeof message !== "string" ||
      !to ||
      !message ||
      message.length > 1000
    ) {
      return new Response(JSON.stringify({ error: "to و message مطلوبين" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // ✅ ننضف الرقم
    let cleanPhone = to.replace(/[^\d]/g, "");
    if (cleanPhone.startsWith("0")) {
      cleanPhone = "20" + cleanPhone.substring(1);
    } else if (cleanPhone.length === 10) {
      cleanPhone = "20" + cleanPhone;
    }

    if (!/^20\d{10}$/.test(cleanPhone)) {
      return new Response(JSON.stringify({ error: "invalid_phone" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // ✅ نبعث الرسالة
    const response = await fetch(`${API_BASE}/v2/${INSTANCE_ID}/send-message`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${API_TOKEN}`,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify({
        to: cleanPhone,
        text: message.trim(),
      }),
    });

    await response.text();

    return new Response(
      JSON.stringify({
        success: response.ok,
      }),
      {
        status: response.ok ? 200 : 502,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (_) {
    return new Response(
      JSON.stringify({ success: false, error: "message_delivery_failed" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
