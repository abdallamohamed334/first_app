import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { importPKCS8, SignJWT } from "https://esm.sh/jose@5.9.6";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const internalSecret = Deno.env.get("NOTIFICATION_INTERNAL_SECRET") ?? "";
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-notification-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const authorization = req.headers.get("Authorization") ?? "";
  const expectedAuthorization = serviceRoleKey ? `Bearer ${serviceRoleKey}` : "";
  const providedSecret = req.headers.get("x-notification-secret") ?? "";
  // Database triggers hold the internal secret in Vault but must not expose
  // the service-role key. Client/server callers may continue sending both.
  if (
    !serviceRoleKey || !internalSecret || providedSecret !== internalSecret ||
    (authorization.length > 0 && authorization !== expectedAuthorization)
  ) {
    return json({ error: "unauthorized" }, 401);
  }
  if (!supabaseUrl) return json({ error: "service_not_configured" }, 503);

  try {
    const payload = await req.json();
    const rawUserId = payload?.userId ?? payload?.user_id;
    const userId = typeof rawUserId === "string" ? rawUserId.trim() : "";
    const title = typeof payload?.title === "string" ? payload.title.trim() : "";
    const body = typeof payload?.body === "string" ? payload.body.trim() : "";
    if (
      !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(userId) ||
      !title || !body || title.length > 120 || body.length > 1000
    ) {
      return json({ error: "invalid_notification" }, 400);
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { data: user, error: userError } = await supabase
      .from("users")
      .select("fcm_token, notifications_enabled, is_active, account_status")
      .eq("id", userId)
      .maybeSingle();
    if (userError) return json({ error: "recipient_lookup_failed" }, 500);
    if (!user) return json({ error: "recipient_not_found" }, 404);
    if (
      user.notifications_enabled === false || user.is_active !== true ||
      user.account_status !== "active"
    ) {
      return json({ success: true, skipped: true });
    }

    const { data: devices, error: deviceError } = await supabase
      .from("user_devices")
      .select("fcm_token")
      .eq("user_id", userId)
      .eq("is_active", true)
      .limit(20);
    if (deviceError) return json({ error: "device_lookup_failed" }, 500);

    const tokens = [...new Set([
      ...(devices ?? []).map((device) => String(device.fcm_token ?? "").trim()),
      String(user.fcm_token ?? "").trim(),
    ].filter((token) => token.length > 0))];
    if (tokens.length === 0) {
      return json({ success: true, skipped: true, reason: "no_device" });
    }

    const { accessToken, projectId } = await getGoogleAccessToken();
    const eventData = payload?.data ?? {
      type: payload?.type,
      reference_id: payload?.reference_id,
      reference_type: payload?.reference_type,
      screen: payload?.screen,
    };
    const safeData = sanitizeData(eventData);
    const results = await Promise.all(tokens.map(async (token) => {
      try {
        const response = await fetch(
          `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(projectId)}/messages:send`,
          {
            method: "POST",
            headers: {
              Authorization: `Bearer ${accessToken}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              message: {
                token,
                notification: { title, body },
                data: safeData,
                android: { priority: "HIGH" },
                apns: { payload: { aps: { sound: "default" } } },
              },
            }),
            signal: AbortSignal.timeout(10_000),
          },
        );
        if (response.ok) return { ok: true as const };
        const providerBody = await response.json().catch(() => ({}));
        const providerError = providerBody?.error;
        const detail = Array.isArray(providerError?.details)
          ? providerError.details.find((item: Record<string, unknown>) =>
              typeof item.errorCode === "string"
            )
          : null;
        const code = typeof detail?.errorCode === "string"
          ? detail.errorCode
          : typeof providerError?.status === "string"
          ? providerError.status
          : `HTTP_${response.status}`;
        return { ok: false as const, status: response.status, code: code.slice(0, 60) };
      } catch (_) {
        return { ok: false as const, status: 0, code: "network_error" };
      }
    }));
    const sent = results.filter((result) => result.ok).length;
    if (sent === 0) {
      return json({
        error: "notification_provider_failed",
        failures: results.filter((result) => !result.ok).map(({ status, code }) => ({ status, code })),
      }, 502);
    }
    return json({ success: true, sent });
  } catch (error) {
    console.error("push delivery failed", error instanceof Error ? error.name : "unknown");
    return json({ error: "notification_delivery_failed" }, 500);
  }
});

function sanitizeData(value: unknown): Record<string, string> {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  const entries = Object.entries(value as Record<string, unknown>).slice(0, 25);
  const result: Record<string, string> = {};
  for (const [key, raw] of entries) {
    if (!/^[A-Za-z0-9_-]{1,40}$/.test(key)) continue;
    if (raw === null || raw === undefined) continue;
    result[key] = String(raw).slice(0, 500);
  }
  return result;
}

async function getGoogleAccessToken(): Promise<{ accessToken: string; projectId: string }> {
  const raw = Deno.env.get("GOOGLE_SERVICE_ACCOUNT");
  if (!raw) throw new Error("Google service account is not configured");
  const account = JSON.parse(raw);
  const projectId = typeof account.project_id === "string" ? account.project_id.trim() : "";
  if (!/^[a-z0-9-]+$/.test(projectId)) throw new Error("Invalid Firebase project id");

  const privateKeyPem = typeof account.private_key === "string"
    ? account.private_key.replace(/\\n/g, "\n")
    : "";
  if (!privateKeyPem) throw new Error("Google private key is missing");

  const privateKey = await importPKCS8(privateKeyPem, "RS256");
  const now = Math.floor(Date.now() / 1000);
  const assertion = await new SignJWT({
    iss: account.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
  })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(privateKey);

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
    signal: AbortSignal.timeout(10_000),
  });
  const result = await response.json();
  if (!response.ok || typeof result.access_token !== "string") {
    throw new Error("Google access token request failed");
  }
  return { accessToken: result.access_token, projectId };
}

function json(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
