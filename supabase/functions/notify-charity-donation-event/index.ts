import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { SignJWT, importPKCS8 } from "https://esm.sh/jose@5.9.6";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const admin = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
const text = (value: unknown, max = 500) => {
  const valueText = String(value ?? "").trim();
  return valueText.length > max ? valueText.slice(0, max) : valueText;
};

Deno.serve(async (request) => {
  if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  try {
    const authorization = request.headers.get("Authorization") ?? "";
    if (!authorization.startsWith("Bearer ")) return json({ error: "unauthorized" }, 401);
    const authClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: authData, error: authError } = await authClient.auth.getUser();
    const actorId = authData.user?.id;
    if (authError || !actorId) return json({ error: "unauthorized" }, 401);

    const payload = await request.json();
    const requestId = text(payload?.requestId, 80);
    const event = text(payload?.event, 30);
    if (!requestId || !["created", "status"].includes(event)) {
      return json({ error: "requestId_and_valid_event_required" }, 400);
    }

    const { data: donation, error: donationError } = await admin
      .from("charity_donation_requests")
      .select("id, donor_id, charity_id, volunteer_id, title, description, quantity, pickup_address, donor_phone, status")
      .eq("id", requestId)
      .maybeSingle();
    if (donationError || !donation) return json({ error: "donation_not_found" }, 404);

    const [charityResult, donorResult, volunteerResult] = await Promise.all([
      admin.from("charities").select("user_id, name, phone").eq("id", donation.charity_id).maybeSingle(),
      admin.from("users").select("name, phone").eq("id", donation.donor_id).maybeSingle(),
      donation.volunteer_id
        ? admin.from("users").select("name, phone").eq("id", donation.volunteer_id).maybeSingle()
        : Promise.resolve({ data: null, error: null }),
    ]);
    const charity = charityResult.data;
    if (!charity?.user_id) return json({ error: "charity_not_found" }, 404);

    const allowedActors = new Set<string>([
      String(donation.donor_id),
      String(charity.user_id),
      ...(donation.volunteer_id ? [String(donation.volunteer_id)] : []),
    ]);
    if (!allowedActors.has(actorId)) return json({ error: "not_allowed" }, 403);

    const status = String(donation.status ?? "pending");
    const recipients = recipientsForStatus(status, {
      donorId: String(donation.donor_id),
      charityUserId: String(charity.user_id),
      volunteerId: donation.volunteer_id ? String(donation.volunteer_id) : null,
    });
    const message = messageFor(status, String(donation.title ?? "تبرع"));

    for (const recipientId of recipients) {
      const { error: notificationError } = await admin.from("notifications").insert({
        user_id: recipientId,
        title: message.title,
        body: message.body,
        type: "system",
        reference_id: requestId,
        reference_type: "charity_donation",
        is_read: false,
      });
      if (notificationError) {
        console.error("notification_insert_failed", notificationError.message);
      }
    }

    let whatsappSent = false;
    if (event === "created") {
      const charityPhone = text(charity.phone, 40);
      if (charityPhone) {
        const donor = donorResult.data;
        const donorName = text(donor?.name, 100) || "متبرع";
        const donationMessage = [
          `تبرع جديد للجمعية: ${text(charity.name, 120)}`,
          `العنوان: ${text(donation.title, 160)}`,
          `الكمية: ${text(donation.quantity, 20)}`,
          `المتبرع: ${donorName}`,
          `هاتف المتبرع: ${text(donation.donor_phone || donor?.phone, 40)}`,
          `عنوان الاستلام: ${text(donation.pickup_address, 220)}`,
          `التفاصيل: ${text(donation.description, 350)}`,
          `رقم التبرع داخل التطبيق: ${requestId}`,
          "افتح تطبيق وِصلة لمراجعة التبرع واتخاذ الإجراء.",
        ].join("\n");
        whatsappSent = await sendWhatsApp(charityPhone, donationMessage, authorization);
      }
    }

    const pushResults = await Promise.all(recipients.map(async (recipientId) => {
      try {
        return await sendPush(recipientId, message.title, message.body, {
          type: "charity_donation_status",
          reference_id: requestId,
          reference_type: "charity_donation",
          status,
        });
      } catch (error) {
        console.error("push_delivery_failed", error instanceof Error ? error.message : "unknown");
        return false;
      }
    }));

    return json({
      success: true,
      recipients: recipients.length,
      push_sent: pushResults.filter(Boolean).length,
      whatsapp_sent: whatsappSent,
      status,
    });
  } catch (error) {
    console.error("[notify-charity-donation-event] failed", error instanceof Error ? error.name : "unknown");
    return json({ error: "notification_delivery_failed" }, 500);
  }
});

function recipientsForStatus(status: string, ids: { donorId: string; charityUserId: string; volunteerId: string | null }) {
  const result = new Set<string>();
  if (status === "pending") result.add(ids.charityUserId);
  else if (status === "volunteer_needed") result.add(ids.charityUserId);
  else {
    result.add(ids.donorId);
    result.add(ids.charityUserId);
    if (ids.volunteerId) result.add(ids.volunteerId);
  }
  return [...result];
}

function messageFor(status: string, title: string) {
  const map: Record<string, { title: string; body: string }> = {
    pending: { title: "تبرع جديد للجمعية", body: `وصل تبرع جديد بعنوان «${title}» ويحتاج للمراجعة.` },
    accepted: { title: "تم قبول التبرع", body: `تم قبول تبرع «${title}» وبدأت خطوات الاستلام.` },
    rejected: { title: "تم رفض التبرع", body: `تم تحديث حالة تبرع «${title}». افتح التطبيق لمعرفة التفاصيل.` },
    volunteer_needed: { title: "التبرع يحتاج مندوبًا", body: `التبرع «${title}» متاح الآن للتوصيل.` },
    volunteer_assigned: { title: "تم تعيين مندوب للتبرع", body: `تم تعيين مندوب لتوصيل «${title}».` },
    donor_ready: { title: "المتبرع جاهز للاستلام", body: `المتبرع أعلن جاهزية «${title}» للاستلام.` },
    picked_up_from_donor: { title: "تم استلام التبرع", body: `تم استلام «${title}» من المتبرع.` },
    in_transit: { title: "التبرع في الطريق", body: `التبرع «${title}» في الطريق إلى الجمعية.` },
    completed: { title: "وصل التبرع للجمعية", body: `تم تسجيل وصول «${title}» إلى الجمعية بنجاح.` },
    cancelled: { title: "تم إلغاء التبرع", body: `تم إلغاء تبرع «${title}».` },
    expired: { title: "انتهت مهلة التبرع", body: `انتهت مهلة متابعة «${title}».` },
  };
  return map[status] ?? { title: "تحديث التبرع", body: `تم تحديث حالة «${title}». افتح التطبيق للتفاصيل.` };
}

async function sendWhatsApp(phone: string, message: string, authorization: string) {
  const cleanPhone = normalizePhone(phone);
  if (!cleanPhone) return false;
  const response = await fetch(`${supabaseUrl}/functions/v1/send-whatsapp`, {
    method: "POST",
    headers: {
      Authorization: authorization,
      apikey: anonKey,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ to: cleanPhone, message }),
  });
  await response.text();
  return response.ok;
}

async function sendPush(userId: string, title: string, body: string, data: Record<string, string>) {
  const { data: devices } = await admin.from("user_devices").select("id, fcm_token").eq("user_id", userId).eq("is_active", true).limit(10);
  const fallback = devices && devices.length > 0 ? devices : await fallbackDevice(userId);
  if (!fallback || fallback.length === 0) return false;
  const accessToken = await googleAccessToken();
  let sent = false;
  for (const device of fallback) {
    const response = await fetch(`https://fcm.googleapis.com/v1/projects/${Deno.env.get("FIREBASE_PROJECT_ID") ?? "flutter-app-45f07"}/messages:send`, {
      method: "POST",
      headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
      body: JSON.stringify({ message: { token: String(device.fcm_token), notification: { title, body }, data, android: { priority: "HIGH" }, apns: { payload: { aps: { sound: "default" } } } } }),
    });
    if (response.ok) sent = true;
    await response.text();
  }
  return sent;
}

async function fallbackDevice(userId: string) {
  const { data } = await admin.from("users").select("fcm_token").eq("id", userId).maybeSingle();
  return data?.fcm_token ? [{ fcm_token: data.fcm_token }] : [];
}

async function googleAccessToken() {
  const raw = Deno.env.get("GOOGLE_SERVICE_ACCOUNT");
  if (!raw) throw new Error("GOOGLE_SERVICE_ACCOUNT is not configured");
  const account = JSON.parse(raw);
  const privateKey = await importPKCS8(account.private_key.replace(/\\n/g, "\n"), "RS256");
  const now = Math.floor(Date.now() / 1000);
  const assertion = await new SignJWT({ iss: account.client_email, scope: "https://www.googleapis.com/auth/firebase.messaging", aud: "https://oauth2.googleapis.com/token" }).setProtectedHeader({ alg: "RS256", typ: "JWT" }).setIssuedAt(now).setExpirationTime(now + 3600).sign(privateKey);
  const response = await fetch("https://oauth2.googleapis.com/token", { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" }, body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion }) });
  const result = await response.json();
  if (!response.ok || !result.access_token) throw new Error("google_access_token_failed");
  return result.access_token as string;
}

function normalizePhone(phone: string) {
  let value = phone.replace(/[^\d]/g, "");
  if (value.startsWith("0")) value = `20${value.slice(1)}`;
  else if (value.length === 10) value = `20${value}`;
  return /^20\d{10}$/.test(value) ? value : "";
}
