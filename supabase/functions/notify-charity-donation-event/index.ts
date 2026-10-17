import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { SignJWT, importPKCS8 } from "https://esm.sh/jose@5.9.6";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const wapilotApiBase = "https://api.wapilot.net/api";
const wapilotInstanceId = "instance5127";
const wapilotToken = Deno.env.get("WAPILOT_TOKEN") ?? "";
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
  if (request.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  try {
    const authorization = request.headers.get("Authorization") ?? "";
    if (!authorization.startsWith("Bearer ")) {
      return json({ error: "unauthorized" }, 401);
    }

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
    if (!requestId || !["created", "status", "volunteer_assigned"].includes(event)) {
      return json({ error: "requestId_and_valid_event_required" }, 400);
    }

    const { data: donation, error: donationError } = await admin
      .from("charity_donation_requests")
      .select(
        "id, donor_id, charity_id, volunteer_id, title, description, quantity, pickup_address, donor_phone, volunteer_name, volunteer_phone, assigned_at, status, rejection_reason, cancellation_reason",
      )
      .eq("id", requestId)
      .maybeSingle();
    if (donationError || !donation) {
      return json({ error: "donation_not_found" }, 404);
    }

    const [charityResult, donorResult, volunteerResult] = await Promise.all([
      admin
        .from("charities")
        .select("user_id, name, phone")
        .eq("id", donation.charity_id)
        .maybeSingle(),
      admin
        .from("users")
        .select("name, phone")
        .eq("id", donation.donor_id)
        .maybeSingle(),
      donation.volunteer_id
        ? admin
            .from("users")
            .select("name, phone")
            .eq("id", donation.volunteer_id)
            .maybeSingle()
        : Promise.resolve({ data: null, error: null }),
    ]);

    const charity = charityResult.data;
    const donor = donorResult.data;
    const volunteer = volunteerResult.data;
    if (charityResult.error || !charity?.user_id) {
      return json({ error: "charity_not_found" }, 404);
    }

    const status = String(donation.status ?? "pending");
    if (
      !actorCanNotify({
        actorId,
        event,
        status,
        donorId: String(donation.donor_id),
        charityUserId: String(charity.user_id),
        volunteerId: donation.volunteer_id
          ? String(donation.volunteer_id)
          : null,
        assignedAt: donation.assigned_at,
      })
    ) {
      return json({ error: "not_allowed_for_event" }, 403);
    }

    const recipientIds = {
      donorId: String(donation.donor_id),
      charityUserId: String(charity.user_id),
      volunteerId: donation.volunteer_id
        ? String(donation.volunteer_id)
        : null,
    };
    const notificationStatus = event === "volunteer_assigned"
      ? "volunteer_assigned"
      : status;
    const recipients = event === "volunteer_assigned"
      ? uniqueIds([recipientIds.donorId, recipientIds.volunteerId])
      : recipientsForStatus(status, recipientIds);
    const message = messageFor(
      notificationStatus,
      text(donation.title, 160) || "التبرع",
    );

    // The database trigger create_direct_charity_status_notifications is the
    // single source of truth for in-app notifications. Do not insert here:
    // doing so would create a duplicate for every create/status event.
    const pushResults = await Promise.all(
      recipients.map(async (recipientId) => {
        try {
          return await sendPush(recipientId, message.title, message.body, {
            type: "charity_donation_status",
            reference_id: requestId,
            reference_type: "charity_donation",
            status,
          });
        } catch (error) {
          console.error(
            "push_delivery_failed",
            error instanceof Error ? error.name : "unknown",
          );
          return { sent: false, failures: ["firebase_setup_failed"] };
        }
      }),
    );

    const whatsappDeliveries = event === "created"
      ? [
          {
            phone: text(charity.phone, 40),
            message: newDonationMessage({ donation, charity, donor, requestId }),
          },
        ]
      : whatsappMessagesForStatus({
          status: notificationStatus,
          donation,
          charity,
          donor,
          volunteer,
        });

    const uniqueDeliveries = deduplicateWhatsAppDeliveries(whatsappDeliveries);
    const whatsappResults = await Promise.all(
      uniqueDeliveries.map((delivery) =>
        sendWhatsApp(delivery.phone, delivery.message),
      ),
    );

    const pushSent = pushResults.filter((result) => result.sent).length;
    const whatsappSent = whatsappResults.filter((result) => result.sent).length;
    const pushFailures = [...new Set(pushResults.flatMap((result) => result.failures))];
    const whatsappFailures = [...new Set(
      whatsappResults.flatMap((result) => result.sent ? [] : [result.code]),
    )];
    const delivered = pushSent + whatsappSent > 0;

    return json({
      success: delivered,
      ...(!delivered ? { error: "all_delivery_channels_failed" } : {}),
      recipients: recipients.length,
      push_sent: pushSent,
      push_failure_codes: pushFailures,
      whatsapp_sent: whatsappSent,
      whatsapp_failed: whatsappResults.filter((result) => !result.sent).length,
      whatsapp_failure_codes: whatsappFailures,
      status,
    });
  } catch (error) {
    console.error(
      "[notify-charity-donation-event] failed",
      error instanceof Error ? error.name : "unknown",
    );
    return json({ error: "notification_delivery_failed" }, 500);
  }
});

function actorCanNotify({
  actorId,
  event,
  status,
  donorId,
  charityUserId,
  volunteerId,
  assignedAt,
}: {
  actorId: string;
  event: string;
  status: string;
  donorId: string;
  charityUserId: string;
  volunteerId: string | null;
  assignedAt: unknown;
}) {
  if (event === "volunteer_assigned") {
    return actorId === charityUserId && Boolean(assignedAt);
  }
  if (event === "created") {
    return actorId === donorId && status === "pending";
  }

  switch (status) {
    case "accepted":
    case "rejected":
    case "volunteer_assigned":
      return actorId === charityUserId;
    case "donor_ready":
    case "cancelled":
      return actorId === donorId;
    case "picked_up_from_donor":
    case "in_transit":
      return actorId === donorId ||
        actorId === charityUserId ||
        actorId === volunteerId;
    case "completed":
      return actorId === charityUserId || actorId === volunteerId;
    case "volunteer_needed":
      return actorId === charityUserId;
    default:
      return false;
  }
}

function recipientsForStatus(
  status: string,
  ids: { donorId: string; charityUserId: string; volunteerId: string | null },
) {
  switch (status) {
    case "pending":
    case "volunteer_needed":
    case "donor_ready":
      return [ids.charityUserId];
    case "accepted":
    case "rejected":
    case "completed":
      return [ids.donorId];
    case "volunteer_assigned":
      return uniqueIds([ids.donorId, ids.volunteerId]);
    case "picked_up_from_donor":
    case "in_transit":
    case "expired":
      return uniqueIds([ids.donorId, ids.charityUserId]);
    case "cancelled":
      return uniqueIds([ids.charityUserId, ids.volunteerId]);
    default:
      return uniqueIds([ids.donorId, ids.charityUserId, ids.volunteerId]);
  }
}

function uniqueIds(values: Array<string | null>) {
  return [...new Set(values.filter((value): value is string => Boolean(value)))];
}

function messageFor(status: string, title: string) {
  const messages: Record<string, { title: string; body: string }> = {
    pending: {
      title: "تبرع جديد للجمعية",
      body: `وصل تبرع جديد بعنوان «${title}» ويحتاج إلى المراجعة.`,
    },
    accepted: {
      title: "تم قبول التبرع",
      body: `وافقت الجمعية على تبرعك «${title}». راجع التطبيق لمعرفة الخطوة التالية.`,
    },
    rejected: {
      title: "تم رفض التبرع",
      body: `اعتذرت الجمعية عن قبول تبرعك «${title}». افتح التطبيق لمعرفة التفاصيل.`,
    },
    donor_ready: {
      title: "المتبرع جاهز للاستلام",
      body: `أعلن المتبرع جاهزية «${title}» للاستلام.`,
    },
    volunteer_assigned: {
      title: "تم تعيين مندوب للتبرع",
      body: `تم تعيين مندوب لاستلام «${title}».`,
    },
    picked_up_from_donor: {
      title: "تم استلام التبرع من المتبرع",
      body: `تم استلام «${title}» من المتبرع.`,
    },
    in_transit: {
      title: "التبرع في الطريق",
      body: `التبرع «${title}» في طريقه إلى الجمعية.`,
    },
    completed: {
      title: "وصل التبرع للجمعية",
      body: `أكدت الجمعية استلام تبرعك «${title}».`,
    },
    cancelled: {
      title: "تم إلغاء التبرع",
      body: `تم إلغاء التبرع «${title}».`,
    },
    expired: {
      title: "انتهت مهلة التبرع",
      body: `انتهت مهلة متابعة التبرع «${title}».`,
    },
    volunteer_needed: {
      title: "التبرع يحتاج مندوبًا",
      body: `التبرع «${title}» يحتاج إلى مندوب للتوصيل.`,
    },
  };
  return messages[status] ?? {
    title: "تحديث التبرع",
    body: `تم تحديث حالة التبرع «${title}». افتح التطبيق للتفاصيل.`,
  };
}

function newDonationMessage({
  donation,
  charity,
  donor,
  requestId,
}: {
  donation: Record<string, unknown>;
  charity: Record<string, unknown>;
  donor: Record<string, unknown> | null;
  requestId: string;
}) {
  const donorPhone = text(donation.donor_phone, 40) || text(donor?.phone, 40);
  return [
    `تبرع جديد وصل لجمعية ${text(charity.name, 120) || "الجمعية"}`,
    `العنوان: ${text(donation.title, 160) || "تبرع"}`,
    `الكمية: ${text(donation.quantity, 20)}`,
    `المتبرع: ${text(donor?.name, 100) || "متبرع"}`,
    `هاتف المتبرع: ${donorPhone || "غير متاح"}`,
    `عنوان الاستلام: ${text(donation.pickup_address, 220) || "غير محدد"}`,
    `التفاصيل: ${text(donation.description, 350) || "لا توجد تفاصيل إضافية"}`,
    `رقم التبرع داخل التطبيق: ${requestId}`,
    "افتح التطبيق لمراجعة التبرع واتخاذ الإجراء.",
  ].join("\n");
}

function whatsappMessagesForStatus({
  status,
  donation,
  charity,
  donor,
  volunteer,
}: {
  status: string;
  donation: Record<string, unknown>;
  charity: Record<string, unknown>;
  donor: Record<string, unknown> | null;
  volunteer: Record<string, unknown> | null;
}) {
  const title = text(donation.title, 160) || "التبرع";
  const charityName = text(charity.name, 120) || "الجمعية";
  const donorName = text(donor?.name, 100) || "المتبرع";
  const donorPhone = text(donation.donor_phone, 40) || text(donor?.phone, 40);
  const charityPhone = text(charity.phone, 40);
  const volunteerName = text(donation.volunteer_name, 100) ||
    text(volunteer?.name, 100) || "مندوب الجمعية";
  const volunteerPhone = text(donation.volunteer_phone, 40) ||
    text(volunteer?.phone, 40);
  const address = text(donation.pickup_address, 220) || "غير محدد";
  const deliveries: Array<{ phone: string; message: string }> = [];
  const add = (phone: string, message: string) => {
    if (phone) deliveries.push({ phone, message });
  };

  switch (status) {
    case "accepted":
      add(
        donorPhone,
        [
          `تم قبول تبرعك «${title}» من جمعية ${charityName}.`,
          "يرجى متابعة التطبيق لمعرفة موعد وطريقة الاستلام.",
        ].join("\n"),
      );
      break;
    case "rejected": {
      const reason = text(donation.rejection_reason, 250);
      add(
        donorPhone,
        [
          `نأسف، تم رفض تبرعك «${title}» من جمعية ${charityName}.`,
          ...(reason ? [`السبب: ${reason}`] : []),
          "يمكنك فتح التطبيق لمعرفة التفاصيل أو التواصل مع الجمعية.",
        ].join("\n"),
      );
      break;
    }
    case "donor_ready":
      add(
        charityPhone,
        [
          `أعلن ${donorName} جاهزية التبرع «${title}» للاستلام.`,
          `عنوان الاستلام: ${address}`,
          `هاتف المتبرع: ${donorPhone || "غير متاح"}`,
        ].join("\n"),
      );
      break;
    case "volunteer_assigned":
      add(
        donorPhone,
        [
          `تم تعيين ${volunteerName} لاستلام تبرعك «${title}» لصالح ${charityName}.`,
          ...(volunteerPhone ? [`هاتف المندوب: ${volunteerPhone}`] : []),
          `عنوان الاستلام: ${address}`,
        ].join("\n"),
      );
      add(
        volunteerPhone,
        [
          `تم تكليفك باستلام تبرع «${title}» لصالح ${charityName}.`,
          `المتبرع: ${donorName}`,
          `هاتف المتبرع: ${donorPhone || "غير متاح"}`,
          `عنوان الاستلام: ${address}`,
        ].join("\n"),
      );
      break;
    case "picked_up_from_donor":
      add(
        charityPhone,
        `تم استلام تبرع «${title}» من ${donorName}، وهو في طريقه للجمعية.`,
      );
      add(
        donorPhone,
        `تم استلام تبرعك «${title}» من المندوب لتوصيله إلى جمعية ${charityName}.`,
      );
      break;
    case "in_transit":
      add(
        charityPhone,
        `تبرع «${title}» في الطريق إلى الجمعية. المتبرع: ${donorName}.`,
      );
      add(
        donorPhone,
        `تبرعك «${title}» في الطريق إلى جمعية ${charityName}.`,
      );
      break;
    case "completed":
      add(
        donorPhone,
        `تم تأكيد وصول تبرعك «${title}» إلى جمعية ${charityName}. شكرًا لمساهمتك.`,
      );
      break;
    case "cancelled": {
      const reason = text(donation.cancellation_reason, 250);
      const message = [
        `تم إلغاء التبرع «${title}» المرسل من ${donorName}.`,
        ...(reason ? [`السبب: ${reason}`] : []),
      ].join("\n");
      add(charityPhone, message);
      add(volunteerPhone, message);
      break;
    }
    case "expired": {
      const message = `انتهت مهلة متابعة التبرع «${title}» المرسل من ${donorName}.`;
      add(donorPhone, `انتهت مهلة متابعة تبرعك «${title}» لدى جمعية ${charityName}.`);
      add(charityPhone, message);
      break;
    }
    case "volunteer_needed":
      add(
        charityPhone,
        `التبرع «${title}» يحتاج إلى مندوب لاستلامه من ${donorName}. عنوان الاستلام: ${address}`,
      );
      break;
    default: {
      const message = `تم تحديث حالة التبرع «${title}» لدى جمعية ${charityName}. افتح التطبيق لمعرفة التفاصيل.`;
      add(donorPhone, message);
      add(charityPhone, message);
      add(volunteerPhone, message);
    }
  }
  return deliveries;
}

function deduplicateWhatsAppDeliveries(
  deliveries: Array<{ phone: string; message: string }>,
) {
  const seen = new Set<string>();
  return deliveries.filter((delivery) => {
    const normalizedPhone = normalizePhone(delivery.phone);
    if (!normalizedPhone || seen.has(normalizedPhone)) return false;
    seen.add(normalizedPhone);
    return true;
  });
}

async function sendWhatsApp(phone: string, message: string) {
  const cleanPhone = normalizePhone(phone);
  const cleanMessage = Array.from(message.trim()).slice(0, 950).join("");
  if (!cleanPhone) return { sent: false, code: "invalid_phone" };
  if (!wapilotToken) return { sent: false, code: "provider_not_configured" };
  if (!cleanMessage) return { sent: false, code: "empty_message" };
  try {
    const response = await fetch(
      `${wapilotApiBase}/v2/${wapilotInstanceId}/send-message`,
      {
      method: "POST",
      headers: {
        Authorization: `Bearer ${wapilotToken}`,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify({ to: cleanPhone, text: cleanMessage }),
      signal: AbortSignal.timeout(10_000),
      },
    );
    if (!response.ok) {
      await response.text();
      const code = response.status === 401
        ? "provider_unauthorized"
        : `provider_http_${response.status}`;
      console.error("whatsapp_provider_rejected", response.status, code);
      return { sent: false, code };
    }
    await response.text();
    return { sent: true, code: "" };
  } catch (error) {
    console.error(
      "whatsapp_delivery_failed",
      error instanceof Error ? error.name : "unknown",
    );
    return { sent: false, code: "network_error" };
  }
}

async function sendPush(
  userId: string,
  title: string,
  body: string,
  data: Record<string, string>,
) {
  const { data: devices, error: deviceError } = await admin
    .from("user_devices")
    .select("id, fcm_token")
    .eq("user_id", userId)
    .eq("is_active", true)
    .limit(10);
  if (deviceError) return { sent: false, failures: ["device_lookup_failed"] };
  const fallback = devices && devices.length > 0
    ? devices
    : await fallbackDevice(userId);
  if (!fallback || fallback.length === 0) {
    return { sent: false, failures: ["no_active_device"] };
  }

  const { accessToken, projectId } = await googleAccessToken();
  let sent = false;
  const failures: string[] = [];
  for (const device of fallback) {
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
              token: String(device.fcm_token),
              notification: { title, body },
              data,
              android: { priority: "HIGH" },
              apns: { payload: { aps: { sound: "default" } } },
            },
          }),
          signal: AbortSignal.timeout(10_000),
        },
      );
      if (response.ok) {
        sent = true;
      } else {
        const payload = await response.json().catch(() => ({}));
        const providerError = payload?.error;
        const detail = Array.isArray(providerError?.details)
          ? providerError.details.find(
            (item: Record<string, unknown>) => typeof item.errorCode === "string",
          )
          : null;
        const code = typeof detail?.errorCode === "string"
          ? detail.errorCode
          : typeof providerError?.status === "string"
          ? providerError.status
          : `HTTP_${response.status}`;
        failures.push(code.slice(0, 60));
        if (code === "UNREGISTERED") {
          try {
            if ("id" in device) {
              const { error: deviceUpdateError } = await admin
                .from("user_devices")
                .update({ is_active: false, updated_at: new Date().toISOString() })
                .eq("id", device.id)
                .eq("user_id", userId);
              if (deviceUpdateError) {
                console.error("fcm_invalid_device_deactivation_failed");
              }
            }
            const { error: legacyTokenError } = await admin
              .from("users")
              .update({ fcm_token: null })
              .eq("id", userId)
              .eq("fcm_token", String(device.fcm_token));
            if (legacyTokenError) {
              console.error("fcm_invalid_legacy_token_clear_failed");
            }
          } catch (_) {
            console.error("fcm_invalid_token_cleanup_failed");
          }
        }
        console.error("fcm_delivery_rejected", response.status, code.slice(0, 60));
      }
    } catch (error) {
      failures.push("network_error");
      console.error(
        "fcm_delivery_failed",
        error instanceof Error ? error.name : "unknown",
      );
    }
  }
  return { sent, failures: [...new Set(failures)] };
}

async function fallbackDevice(userId: string) {
  const { data } = await admin
    .from("users")
    .select("fcm_token")
    .eq("id", userId)
    .maybeSingle();
  return data?.fcm_token ? [{ fcm_token: data.fcm_token }] : [];
}

async function googleAccessToken() {
  const raw = Deno.env.get("GOOGLE_SERVICE_ACCOUNT");
  if (!raw) throw new Error("GOOGLE_SERVICE_ACCOUNT is not configured");
  const account = JSON.parse(raw);
  const projectId = typeof account.project_id === "string"
    ? account.project_id.trim()
    : "";
  if (!/^[a-z0-9-]+$/.test(projectId)) {
    throw new Error("firebase_project_id_invalid");
  }
  const privateKeyPem = typeof account.private_key === "string"
    ? account.private_key.replace(/\\n/g, "\n")
    : "";
  if (!privateKeyPem) throw new Error("firebase_private_key_missing");
  const privateKey = await importPKCS8(
    privateKeyPem,
    "RS256",
  );
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
  });
  const result = await response.json();
  if (!response.ok || typeof result.access_token !== "string") {
    throw new Error("google_access_token_failed");
  }
  return { accessToken: result.access_token as string, projectId };
}

function normalizePhone(phone: string) {
  let value = phone.replace(/[^\d]/g, "");
  if (value.startsWith("0")) value = `20${value.slice(1)}`;
  else if (value.length === 10) value = `20${value}`;
  return /^20\d{10}$/.test(value) ? value : "";
}
