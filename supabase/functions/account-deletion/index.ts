import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req) => {
  if (req.method === "GET") return new Response(page(), { headers: { "Content-Type": "text/html; charset=utf-8" } });
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
  try {
    const form = await req.formData();
    const identifier = String(form.get("identifier") ?? "").trim();
    if (identifier.length < 5 || identifier.length > 160) return new Response(page("من فضلك اكتب البريد أو رقم الهاتف بشكل صحيح."), { status: 400, headers: { "Content-Type": "text/html; charset=utf-8" } });
    const admin = createClient(Deno.env.get("SUPABASE_URL") ?? "", Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "");
    const { error } = await admin.from("account_deletion_requests").insert({ identifier, source: "web" });
    if (error) { console.error("deletion request insert failed", error.message); return new Response(page("تعذر تسجيل الطلب الآن. تواصل مع support@khedma.app."), { status: 500, headers: { "Content-Type": "text/html; charset=utf-8" } }); }
    return new Response(page("تم استلام طلبك. سيتواصل معك فريق الدعم للتحقق وإتمام الحذف."), { headers: { "Content-Type": "text/html; charset=utf-8" } });
  } catch (_) { return new Response(page("تعذر تسجيل الطلب الآن."), { status: 500, headers: { "Content-Type": "text/html; charset=utf-8" } }); }
});
function page(message = "") { return `<!doctype html><html lang="ar" dir="rtl"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>طلب حذف حساب Khedma</title><style>body{font-family:Arial,sans-serif;max-width:620px;margin:40px auto;padding:0 20px;line-height:1.8;color:#17352b}h1{color:#0b7650}form{display:grid;gap:12px}input,button{padding:13px;border-radius:10px;border:1px solid #ccd8d2;font-size:16px}button{background:#0b7650;color:white;border:0} .msg{padding:12px;background:#eef8f2;border-radius:10px}</style></head><body><h1>طلب حذف حساب Khedma</h1><p>اكتب البريد الإلكتروني أو رقم الهاتف المرتبط بحسابك. سيستخدم فريق الدعم هذه البيانات للتحقق من الطلب وحذف الحساب والبيانات المرتبطة به.</p>${message ? `<p class="msg">${message}</p>` : ""}<form method="post"><label for="identifier">البريد أو رقم الهاتف</label><input id="identifier" name="identifier" required maxlength="160"><button type="submit">إرسال طلب الحذف</button></form><p>للاستفسار: support@khedma.app</p></body></html>`;}
