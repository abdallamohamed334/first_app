import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const supabaseUrl = Deno.env.get('SUPABASE_URL');
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
const resendApiKey = Deno.env.get('RESEND_API_KEY');
const fromEmail = Deno.env.get('RESEND_FROM_EMAIL');

if (!supabaseUrl || !serviceRoleKey || !resendApiKey || !fromEmail) {
  throw new Error('Missing required server secrets');
}

const admin = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json; charset=utf-8' },
  });

const asRecord = (value: unknown): Record<string, unknown> =>
  value && typeof value === 'object' ? value as Record<string, unknown> : {};

const escapeHtml = (value: unknown) => String(value ?? '')
  .replaceAll('&', '&amp;')
  .replaceAll('<', '&lt;')
  .replaceAll('>', '&gt;')
  .replaceAll('"', '&quot;')
  .replaceAll("'", '&#039;');

const donationEmailHtml = (payload: Record<string, unknown>) => {
  const restaurant = escapeHtml(payload.restaurant_name ?? 'مطعم مشارك');
  const charity = escapeHtml(payload.charity_name ?? 'الجمعية المستفيدة');
  const title = escapeHtml(payload.item_title ?? 'تبرع غذائي');
  const description = escapeHtml(payload.description ?? '');
  const quantity = escapeHtml(payload.quantity ?? 'غير محددة');

  return `<!doctype html>
<html lang="ar" dir="rtl">
  <body style="margin:0;background:#f5f8f6;font-family:Arial,Tahoma,sans-serif;color:#12352b;direction:rtl">
    <div style="max-width:620px;margin:32px auto;background:#ffffff;border-radius:18px;overflow:hidden;border:1px solid #dce9e2">
      <div style="background:#003527;color:#ffffff;padding:28px 30px">
        <div style="font-size:13px;opacity:.82">لقمة • إشعار تبرع جديد</div>
        <h1 style="font-size:25px;margin:12px 0 0">طلب تبرع جديد من ${restaurant}</h1>
      </div>
      <div style="padding:28px 30px;line-height:1.9">
        <p style="font-size:17px;margin-top:0">مرحبًا، وصل إلى جمعيتكم طلب تبرع جديد يحتاج إلى المراجعة.</p>
        <div style="background:#f4faf6;border:1px solid #d9eadf;border-radius:14px;padding:18px;margin:20px 0">
          <p style="margin:0 0 8px"><strong>المطعم:</strong> ${restaurant}</p>
          <p style="margin:0 0 8px"><strong>التبرع:</strong> ${title}</p>
          <p style="margin:0 0 8px"><strong>الكمية:</strong> ${quantity}</p>
          <p style="margin:0"><strong>الجمعية:</strong> ${charity}</p>
        </div>
        ${description ? `<p><strong>الوصف:</strong><br>${description}</p>` : ''}
        <p style="color:#557168">افتحي التطبيق لمراجعة الطلب واتخاذ الإجراء المناسب.</p>
      </div>
      <div style="background:#f8fbf9;color:#6a7f76;padding:16px 30px;font-size:12px">هذا بريد آلي من تطبيق لقمة، يرجى عدم الرد عليه.</div>
    </div>
  </body>
</html>`;
};

const signupEmailHtml = (payload: Record<string, unknown>) => {
  const code = escapeHtml(payload.verification_code ?? '------');
  const expires = escapeHtml(payload.expires_minutes ?? '10');
  return `<!doctype html><html lang="ar" dir="rtl"><body style="margin:0;background:#f5f8f6;font-family:Arial,Tahoma,sans-serif;color:#12352b;direction:rtl"><div style="max-width:560px;margin:32px auto;background:#fff;border-radius:18px;overflow:hidden;border:1px solid #dce9e2"><div style="background:#003527;color:#fff;padding:28px 30px"><div style="font-size:13px;opacity:.82">لقمة • تأكيد البريد الإلكتروني</div><h1 style="font-size:25px;margin:12px 0 0">كود تفعيل حسابك</h1></div><div style="padding:30px;text-align:center;line-height:1.9"><p style="font-size:17px;margin-top:0">استخدم الكود التالي لتفعيل حسابك في تطبيق لقمة:</p><div style="display:inline-block;background:#f0f8f3;border:1px solid #cfe7d8;border-radius:16px;padding:16px 30px;font-size:34px;letter-spacing:8px;font-weight:800;color:#08724d;direction:ltr">${code}</div><p style="color:#557168;margin-bottom:0">الكود صالح لمدة ${expires} دقائق، ولا تشاركه مع أي شخص.</p></div><div style="background:#f8fbf9;color:#6a7f76;padding:16px 30px;font-size:12px;text-align:center">هذا بريد آلي من تطبيق لقمة، يرجى عدم الرد عليه.</div></div></body></html>`;
};

Deno.serve(async (request) => {
  if (request.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

  let incoming: Record<string, unknown>;
  try {
    incoming = asRecord(await request.json());
  } catch {
    return json({ error: 'invalid_json' }, 400);
  }

  const record = asRecord(incoming.record ?? incoming);
  const outboxId = String(record.id ?? incoming.id ?? '').trim();
  if (!outboxId) return json({ error: 'missing_outbox_id' }, 400);

  const { data: claimed, error: claimError } = await admin
    .from('restaurant_charity_email_outbox')
    .update({
      status: 'processing',
      attempts: (Number(record.attempts) || 0) + 1,
      updated_at: new Date().toISOString(),
    })
    .eq('id', outboxId)
    .in('status', ['pending', 'failed'])
    .lt('attempts', 5)
    .select('*')
    .maybeSingle();

  if (claimError) return json({ error: 'outbox_claim_failed' }, 500);
  if (!claimed) return json({ ok: true, skipped: true, reason: 'already_claimed_or_sent' });

  const payload = asRecord(claimed.payload);
  const recipient = String(claimed.recipient_email ?? '').trim().toLowerCase();
  if (!recipient) {
    await admin.from('restaurant_charity_email_outbox').update({
      status: 'failed',
      last_error: 'missing_recipient_email',
      updated_at: new Date().toISOString(),
    }).eq('id', outboxId);
    return json({ error: 'missing_recipient_email' }, 422);
  }

  try {
    const resendResponse = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        authorization: `Bearer ${resendApiKey}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        from: fromEmail,
        to: [recipient],
        subject: payload.email_kind === 'signup_verification' ? 'كود تفعيل حسابك في لقمة' : `طلب تبرع جديد من ${String(payload.restaurant_name ?? 'مطعم مشارك')}`,
        html: payload.email_kind === 'signup_verification' ? signupEmailHtml(payload) : donationEmailHtml(payload),
      }),
    });

    if (!resendResponse.ok) {
      const providerBody = await resendResponse.text();
      throw new Error(`resend_${resendResponse.status}: ${providerBody.slice(0, 500)}`);
    }

    const providerResult = await resendResponse.json();
    const { error: sentUpdateError } = await admin
      .from('restaurant_charity_email_outbox')
      .update({
        status: 'sent',
        sent_at: new Date().toISOString(),
        last_error: null,
        updated_at: new Date().toISOString(),
      })
      .eq('id', outboxId)
      .eq('status', 'processing');

    if (sentUpdateError) return json({ error: 'sent_but_status_update_failed' }, 500);
    return json({ ok: true, email_id: providerResult?.id ?? null });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'email_send_failed';
    await admin.from('restaurant_charity_email_outbox').update({
      status: 'failed',
      last_error: message.slice(0, 1000),
      updated_at: new Date().toISOString(),
    }).eq('id', outboxId).eq('status', 'processing');
    return json({ error: 'email_send_failed' }, 502);
  }
});
