// supabase/functions/send-notification/index.ts
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { SignJWT, importPKCS8 } from 'https://esm.sh/jose@5.9.6';

const JSON_HEADERS = { 'Content-Type': 'application/json' };

serve(async (req) => {
  if (req.method !== 'POST') {
    return json({ error: 'method_not_allowed' }, 405);
  }

  if (!isAuthorizedInternalRequest(req)) {
    return json({ error: 'unauthorized' }, 401);
  }

  try {
    const payload = await req.json();
    const userId = cleanText(payload?.userId, 100);
    const title = cleanText(payload?.title, 120);
    const body = cleanText(payload?.body, 1000);
    const data = normalizeData(payload?.data);

    if (!userId || !title || !body) {
      return json({ error: 'userId, title and body are required' }, 400);
    }

    const supabaseUrl = requiredEnv('SUPABASE_URL');
    const serviceRoleKey = requiredEnv('SUPABASE_SERVICE_ROLE_KEY');
    const projectId = requiredEnv('FIREBASE_PROJECT_ID');

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: devices, error: devicesError } = await supabase
      .from('user_devices')
      .select('id, fcm_token')
      .eq('user_id', userId)
      .eq('is_active', true);

    if (devicesError) {
      console.error('[send-notification] device lookup failed', devicesError.code);
      return json({ error: 'device_lookup_failed' }, 500);
    }

    if (!devices || devices.length === 0) {
      return json({ error: 'no_active_devices' }, 404);
    }

    const accessToken = await getGoogleAccessToken();
    const results = await Promise.all(
      devices.map((device) =>
        sendToDevice({
          deviceId: String(device.id),
          projectId,
          accessToken,
          token: String(device.fcm_token),
          title,
          body,
          data,
        }),
      ),
    );

    const invalidDeviceIds = results
      .filter((result) => result.invalidToken)
      .map((result) => result.deviceId)
      .filter((id): id is string => Boolean(id));

    if (invalidDeviceIds.length > 0) {
      await supabase
        .from('user_devices')
        .update({
          is_active: false,
          updated_at: new Date().toISOString(),
        })
        .in('id', invalidDeviceIds);
    }

    const sent = results.filter((result) => result.sent).length;
    const failed = results.length - sent;

    if (sent === 0) {
      return json({ success: false, sent, failed }, 502);
    }

    return json({
      success: true,
      sent,
      failed,
      deactivated: invalidDeviceIds.length,
    });
  } catch (error) {
    console.error(
      '[send-notification] request failed',
      error instanceof Error ? error.name : 'unknown_error',
    );
    return json({ error: 'notification_delivery_failed' }, 500);
  }
});

async function sendToDevice({
  deviceId,
  projectId,
  accessToken,
  token,
  title,
  body,
  data,
}: {
  deviceId: string;
  projectId: string;
  accessToken: string;
  token: string;
  title: string;
  body: string;
  data: Record<string, string>;
}): Promise<{ sent: boolean; invalidToken: boolean; deviceId?: string }> {
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body },
          data,
          android: { priority: 'HIGH' },
          apns: { payload: { aps: { sound: 'default' } } },
        },
      }),
    },
  );

  if (response.ok) {
    return { sent: true, invalidToken: false, deviceId };
  }

  let errorCode = '';
  try {
    const result = await response.json();
    errorCode = String(result?.error?.status ?? '');
  } catch (_) {
    // Do not expose or log the provider response body.
  }

  return {
    sent: false,
    invalidToken:
      errorCode === 'UNREGISTERED' || errorCode === 'INVALID_ARGUMENT',
    deviceId,
  };
}

function isAuthorizedInternalRequest(req: Request): boolean {
  const expected = Deno.env.get('NOTIFICATION_INTERNAL_SECRET')?.trim();
  const provided = req.headers.get('x-notification-secret')?.trim();
  return Boolean(expected && provided && provided === expected);
}

function requiredEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`${name}_not_configured`);
  return value;
}

function cleanText(value: unknown, maxLength: number): string {
  if (typeof value !== 'string') return '';
  const normalized = value.trim();
  return normalized.length > maxLength ? '' : normalized;
}

function normalizeData(value: unknown): Record<string, string> {
  if (value == null) return {};
  if (typeof value !== 'object' || Array.isArray(value)) {
    throw new Error('data_must_be_an_object');
  }

  const result: Record<string, string> = {};
  for (const [key, rawValue] of Object.entries(value)) {
    if (Object.keys(result).length >= 20) break;
    const cleanKey = cleanText(key, 40);
    if (!cleanKey) continue;
    if (
      typeof rawValue !== 'string' &&
      typeof rawValue !== 'number' &&
      typeof rawValue !== 'boolean'
    ) {
      continue;
    }
    result[cleanKey] = String(rawValue).slice(0, 200);
  }
  return result;
}

async function getGoogleAccessToken(): Promise<string> {
  const raw = requiredEnv('GOOGLE_SERVICE_ACCOUNT');
  const account = JSON.parse(raw) as {
    client_email?: string;
    private_key?: string;
  };
  const clientEmail = account.client_email?.trim();
  const privateKeyText = account.private_key?.replace(/\\n/g, '\n');
  if (!clientEmail || !privateKeyText) {
    throw new Error('google_service_account_invalid');
  }

  const privateKey = await importPKCS8(privateKeyText, 'RS256');
  const now = Math.floor(Date.now() / 1000);
  const assertion = await new SignJWT({
    iss: clientEmail,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
  })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(privateKey);

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });

  const result = await response.json();
  if (!response.ok || typeof result?.access_token !== 'string') {
    throw new Error('google_access_token_failed');
  }
  return result.access_token;
}

function json(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: JSON_HEADERS,
  });
}
