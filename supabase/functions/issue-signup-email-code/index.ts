// supabase/functions/issue-signup-email-code/index.ts
//
// انشره بالأمر:
//   supabase functions deploy issue-signup-email-code
//
// وحط الـ secret بتاع Resend مرة واحدة:
//   supabase secrets set RESEND_API_KEY=re_xxxxxxxx
//
// SUPABASE_URL و SUPABASE_SERVICE_ROLE_KEY متوفرين تلقائيًا جوه الـ Edge Function.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")!;
const FROM_ADDRESS = Deno.env.get("RESEND_FROM_EMAIL") ?? "noreply@loqma.com";

const supabaseAdmin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
  };
}

function generateCode(): string {
  // 6 أرقام آمنة (مش Math.random بسيط)
  const buf = new Uint32Array(1);
  crypto.getRandomValues(buf);
  const n = buf[0] % 1_000_000;
  return n.toString().padStart(6, "0");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders() });
  }

  try {
    const { p_user_id, p_email, p_name, p_phone } = await req.json();

    if (!p_user_id || !p_email) {
      return new Response(
        JSON.stringify({ success: false, error: "missing_params" }),
        { status: 400, headers: corsHeaders() },
      );
    }

    const email = String(p_email).trim().toLowerCase();

    // Rate limit: امنع طلب كود جديد لو فيه كود اتبعت خلال آخر 60 ثانية
    const { data: recent } = await supabaseAdmin
      .from("signup_email_codes")
      .select("created_at")
      .eq("user_id", p_user_id)
      .eq("email", email)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (recent) {
      const secondsSince =
        (Date.now() - new Date(recent.created_at).getTime()) / 1000;
      if (secondsSince < 60) {
        return new Response(
          JSON.stringify({ success: false, error: "rate_limited" }),
          { status: 429, headers: corsHeaders() },
        );
      }
    }

    const code = generateCode();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();

    // ألغِ أي أكواد سابقة لسه شغالة لنفس اليوزر
    await supabaseAdmin
      .from("signup_email_codes")
      .update({ used: true })
      .eq("user_id", p_user_id)
      .eq("email", email)
      .eq("used", false);

    const { error: insertError } = await supabaseAdmin
      .from("signup_email_codes")
      .insert({
        user_id: p_user_id,
        email,
        code,
        name: p_name ?? null,
        phone: p_phone ?? null,
        expires_at: expiresAt,
      });

    if (insertError) {
      console.error("insert error", insertError);
      return new Response(
        JSON.stringify({ success: false, error: "db_insert_failed" }),
        { status: 500, headers: corsHeaders() },
      );
    }

    const resendRes = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: FROM_ADDRESS,
        to: [email],
        subject: "كود تفعيل حسابك في لقمة",
        html: `
          <div dir="rtl" style="font-family: sans-serif; text-align: right;">
            <h2>كود التحقق الخاص بك</h2>
            <p style="font-size: 28px; font-weight: bold; letter-spacing: 4px;">${code}</p>
            <p>الكود صالح لمدة 10 دقائق.</p>
          </div>
        `,
      }),
    });

    if (!resendRes.ok) {
      const text = await resendRes.text();
      console.error("resend error", resendRes.status, text);
      return new Response(
        JSON.stringify({ success: false, error: "email_send_failed" }),
        { status: 502, headers: corsHeaders() },
      );
    }

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: corsHeaders(),
    });
  } catch (err) {
    console.error("unexpected error", err);
    return new Response(
      JSON.stringify({ success: false, error: "unexpected_error" }),
      { status: 500, headers: corsHeaders() },
    );
  }
});