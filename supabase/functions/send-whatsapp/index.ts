const API_BASE = "https://api.wapilot.net/api";
const INSTANCE_ID = "instance5127";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const apiToken = Deno.env.get("WAPILOT_TOKEN") ?? "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, content-type, apikey, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function unauthorized() {
  return new Response(JSON.stringify({ error: "unauthorized" }), {
    status: 401,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "method_not_allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // This endpoint can spend the platform's WhatsApp quota. It is server-only:
  // a valid user session is not sufficient authorization to send arbitrary text.
  const authHeader = req.headers.get("Authorization") ?? "";
  const expected = serviceRoleKey ? `Bearer ${serviceRoleKey}` : "";
  if (!expected || authHeader !== expected) return unauthorized();

  try {
    const payload = await req.json();
    const to = payload?.to;
    const message = payload?.message;
    if (
      typeof to !== "string" ||
      typeof message !== "string" ||
      !to.trim() ||
      !message.trim() ||
      message.trim().length > 1000
    ) {
      return new Response(JSON.stringify({ error: "to_and_message_required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    let cleanPhone = to.replace(/[^\d]/g, "");
    if (cleanPhone.startsWith("0")) {
      cleanPhone = `20${cleanPhone.slice(1)}`;
    } else if (cleanPhone.length === 10) {
      cleanPhone = `20${cleanPhone}`;
    }
    if (!/^20\d{10}$/.test(cleanPhone)) {
      return new Response(JSON.stringify({ error: "invalid_phone" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (!apiToken) {
      return new Response(JSON.stringify({ error: "service_not_configured" }), {
        status: 503,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const response = await fetch(`${API_BASE}/v2/${INSTANCE_ID}/send-message`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiToken}`,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify({ to: cleanPhone, text: message.trim() }),
      signal: AbortSignal.timeout(10_000),
    });
    await response.text();

    return new Response(JSON.stringify({ success: response.ok }), {
      status: response.ok ? 200 : 502,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
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
