// supabase/functions/verify-and-create/index.ts

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const adminClient = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { autoRefreshToken: false, persistSession: false } },
);

const anonClient = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_ANON_KEY")!,
  { auth: { autoRefreshToken: false, persistSession: false } },
);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, content-type, apikey, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const { phone, code, profile } = body;

    // Never log OTPs, profile PII, or other authentication material.

    if (
      typeof phone !== "string" ||
      typeof code !== "string" ||
      !profile ||
      typeof profile !== "object" ||
      Array.isArray(profile)
    ) {
      return err("بيانات ناقصة", 400);
    }
    const requestedRole =
      typeof profile.role === "string"
        ? profile.role.trim().toLowerCase()
        : "user";
    if (!["user", "provider"].includes(requestedRole)) {
      return err("نوع الحساب غير مدعوم", 400);
    }

    // ✅ 1. نظّف الرقم
    let cleanPhone = phone.replace(/\D/g, "");
    if (cleanPhone.startsWith("0")) cleanPhone = "20" + cleanPhone.slice(1);
    else if (cleanPhone.length === 10) cleanPhone = "20" + cleanPhone;

    const cleanCode = code.trim();
    if (!/^20\d{10}$/.test(cleanPhone) || !/^\d{6}$/.test(cleanCode)) {
      return err("بيانات التحقق غير صحيحة", 400);
    }

    // Consume under a per-phone database lock: a challenge can succeed once only.
    const { data: otpResult, error: otpError } = await adminClient.rpc(
      "consume_otp_challenge",
      {
        p_phone: cleanPhone,
        p_code: cleanCode,
        p_login_mode: requestedRole,
      },
    );
    if (otpError) {
      console.error("OTP consumption failed", otpError.code);
      return err("تعذر التحقق الآن، حاول مرة أخرى", 503);
    }
    if (otpResult?.success !== true) {
      const reason = otpResult?.reason;
      const message = reason === "expired"
        ? "انتهت صلاحية الكود، اطلب كودًا جديدًا"
        : reason === "not_found" || reason === "already_consumed"
        ? "لا يوجد كود صالح، اطلب كودًا جديدًا"
        : reason === "attempts_exceeded"
        ? "تجاوزت عدد المحاولات، اطلب كودًا جديدًا"
        : "الكود غير صحيح";
      return err(message, reason === "attempts_exceeded" ? 429 : 400);
    }

    // ✅ 4. المفاتيح الداخلية
    const internalEmail = `${cleanPhone}@loqma.local`;
    const passwordBytes = new Uint8Array(32);
    crypto.getRandomValues(passwordBytes);
    const internalPassword = Array.from(passwordBytes, (value) =>
      value.toString(16).padStart(2, "0"),
    ).join("");

    // ═══════════════════════════════════════════════════════════
    // 🎯 الخطوة 5: تحديد الـ user النهائي
    // ═══════════════════════════════════════════════════════════
    let finalUserId: string | null = null;
    let isNewUser = false;

    // (أ) لو في public.users → نجرب auth بنفس الـ ID
    const { data: publicUser } = await adminClient
      .from("users")
      .select("id")
      .eq("phone", cleanPhone)
      .maybeSingle();

    if (publicUser?.id) {
      try {
        const { data: authData, error: authErr } =
          await adminClient.auth.admin.getUserById(publicUser.id);

        if (!authErr && authData?.user) {
          finalUserId = publicUser.id;
          console.log("Existing Auth and public user matched");
        } else {
          // Never delete an orphan automatically: the row may contain user data
          // that needs manual reconciliation. Stop safely and preserve it.
          console.warn("Orphan public user detected; automatic deletion skipped");
          return err("تعذر مزامنة الحساب، تواصل مع الدعم", 409);
        }
      } catch (e) {
        console.error("getUserById reconciliation failed:", e);
        return err("تعذر مزامنة الحساب، حاول مرة أخرى", 503);
      }
    }

    // (ب) لو مفيش → نحاول ننشئ auth user
    if (!finalUserId) {
      const { data: authData, error: authError } =
        await adminClient.auth.admin.createUser({
          email: internalEmail,
          password: internalPassword,
          email_confirm: true,
          user_metadata: {
            phone: cleanPhone,
            role: requestedRole,
            name: profile.name || "",
          },
        });

      if (authData?.user) {
        finalUserId = authData.user.id;
        isNewUser = true;
        console.log("New auth user created");
      } else if (authError) {
        console.error("⚠️ Auth create failed:", authError.message);

        // ممكن موجود بالفعل → ندور عليه بـ pagination
        let page = 1;
        const perPage = 1000;

        while (page <= 10 && !finalUserId) {
          const { data: listData, error: listErr } =
            await adminClient.auth.admin.listUsers({ page, perPage });

          if (listErr) {
            console.error("❌ listUsers error:", listErr);
            break;
          }

          const found = listData?.users?.find(
            (u: any) => u.email === internalEmail,
          );

          if (found) {
            finalUserId = found.id;
            // The Auth identity survived but its public profile was deleted.
            // Recreate only a minimal profile and force completion in the app.
            isNewUser = true;
            console.log("Existing auth user found");
            break;
          }

          if (!listData?.users || listData.users.length < perPage) break;
          page++;
        }

        if (!finalUserId) {
          return err("تعذر إنشاء الحساب");
        }
      }
    }

    if (!finalUserId) {
      return err("تعذر تحديد المستخدم");
    }

    // users has a trigger that keeps role and user_type in sync. Set both
    // explicitly; otherwise user_type defaults to "user" and provider
    // registration is rejected by the database guard.
    const { data: conflictRow } = await adminClient
      .from("users")
      .select("id")
      .eq("phone", cleanPhone)
      .maybeSingle();
    if (conflictRow?.id && conflictRow.id !== finalUserId) {
      console.warn("Phone conflict detected; automatic cleanup skipped");
      return err("رقم الهاتف مرتبط بحساب آخر", 409);
    }

    // ═══════════════════════════════════════════════════════════
    // ✅ 6. نتأكد إن public.users فيه سجل (upsert)
    // ═══════════════════════════════════════════════════════════
    // Login must never overwrite an existing profile with empty/default
    // registration fields. Only send profile fields when they were supplied;
    // a new account still receives the required defaults.
    const userPatch: Record<string, unknown> = {
      "id": finalUserId,
      "phone": cleanPhone,
      "is_phone_verified": true,
    };
    if (isNewUser || (profile["name"]?.toString().trim().isNotEmpty ?? false)) {
      userPatch["name"] = profile["name"]?.toString().trim() ?? "";
    }
    if (isNewUser || (profile["city"]?.toString().trim().isNotEmpty ?? false)) {
      userPatch["city"] = profile["city"]?.toString().trim() ?? "طنطا";
    }
    if (isNewUser) {
      userPatch["role"] = requestedRole;
      userPatch["user_type"] = requestedRole;
    }
    const updateQuery = isNewUser
        ? adminClient.from("users").upsert(userPatch, { onConflict: "id" })
        : adminClient.from("users").update(userPatch).eq("id", finalUserId);
    const updateResult = await updateQuery;
    const upsertError = updateResult.error;

    if (upsertError) {
      console.error("❌ User upsert error:", JSON.stringify(upsertError));
      return err("تعذر حفظ بيانات الحساب");
    }

    console.log("✅ User row upserted");

    // ── لو مقدم خدمة ──
    if (requestedRole === "provider") {
      const { data: existingProvider, error: providerLookupError } =
        await adminClient
          .from("service_providers")
          .select("id")
          .eq("user_id", finalUserId)
          .maybeSingle();

      if (providerLookupError) {
        console.error("⚠️ Provider lookup error:", JSON.stringify(providerLookupError));
        return err("تعذر تحميل ملف مزود الخدمة");
      }

      // Login must never create a partial provider row. Registration carries
      // categoryId; a login without an existing profile gets a clear response.
      if (!existingProvider && !profile.categoryId) {
        return err(
          "الرقم ده مش مسجل كمزود خدمة. اعمل حساب جديد أولاً.",
          403,
        );
      }

      if (!existingProvider) {
        const { error: providerError } = await adminClient
          .from("service_providers")
          .insert({
            user_id: finalUserId,
            category_id: profile.categoryId,
            provider_type: profile.providerType || "individual",
            display_name: profile.name || cleanPhone,
            city: profile.city || "طنطا",
            address: profile.address || "",
            phone: cleanPhone,
            whatsapp: profile.whatsapp || cleanPhone,
            bio: profile.bio,
            experience_years: profile.experienceYears,
            skills: profile.skills || [],
            service_areas: profile.serviceAreas || [],
            pricing_type: profile.pricingType || "market",
            price_from: profile.priceFrom,
            verification_status: "pending",
            // Pending providers may reach the review screen; features remain
            // guarded by verification_status.
            is_active: true,
            is_available: true,
          });

        if (providerError) {
          console.error("⚠️ Provider error:", JSON.stringify(providerError));
          return err("تعذر إنشاء ملف مزود الخدمة");
        }
      }
    }

    // ═══════════════════════════════════════════════════════════
    // ✅ 7. نضبط الـ password (حل مشكلة signIn)
    // ═══════════════════════════════════════════════════════════
    const { error: updatePwError } =
      await adminClient.auth.admin.updateUserById(finalUserId, {
        password: internalPassword,
      });

    if (updatePwError) {
      console.error("Password update failed:", updatePwError.code);
      return err("تعذر تجهيز جلسة الحساب، حاول مرة أخرى", 503);
    }

    // ═══════════════════════════════════════════════════════════
    // ✅ 8. نسجل دخول
    // ═══════════════════════════════════════════════════════════
    const { data: sessionData, error: signInError } =
      await anonClient.auth.signInWithPassword({
        email: internalEmail,
        password: internalPassword,
      });

    if (signInError || !sessionData.session) {
      console.error("SignIn error:", signInError?.code ?? "no_session");
      return err("تعذر تسجيل الدخول، حاول مرة أخرى", 503);
    }

    console.log("✅ Session created");

    return new Response(
      JSON.stringify({
        success: true,
        isNewUser,
        user_id: finalUserId,
        access_token: sessionData.session.access_token,
        refresh_token: sessionData.session.refresh_token,
        user: {
          id: finalUserId,
          phone: cleanPhone,
          name: profile.name,
          role: requestedRole,
        },
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (e) {
    console.error("💥 Error:", e);
    return err("خطأ غير متوقع");
  }
});

function err(message: string, status = 500) {
  return new Response(JSON.stringify({ success: false, error: message }), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
