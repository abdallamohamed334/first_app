// supabase/functions/verify-and-create/index.ts

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const adminClient = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { autoRefreshToken: false, persistSession: false } }
);

const anonClient = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_ANON_KEY")!,
  { auth: { autoRefreshToken: false, persistSession: false } }
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

    console.log("📥 Request:", JSON.stringify({ phone, code, profile }));

    if (!phone || !code || !profile) {
      return err("بيانات ناقصة");
    }

    // ✅ 1. نظّف الرقم
    let cleanPhone = phone.replace(/\D/g, "");
    if (cleanPhone.startsWith("0")) cleanPhone = "20" + cleanPhone.slice(1);
    else if (cleanPhone.length === 10) cleanPhone = "20" + cleanPhone;

    console.log("📞 Clean phone:", cleanPhone);

    // ✅ 2. تحقق من الكود
    const { data: otp, error: otpFetchError } = await adminClient
      .from("otp_codes")
      .select("*")
      .eq("phone", cleanPhone)
      .eq("verified", false)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (otpFetchError) {
      console.error("❌ OTP fetch error:", JSON.stringify(otpFetchError));
      return err("تعذر قراءة الكود");
    }

    if (!otp) return err("مفيش كود، اطلب كود جديد");
    if (new Date(otp.expires_at) < new Date()) return err("انتهت صلاحية الكود");
    if ((otp.attempts || 0) >= 5) return err("تجاوزت عدد المحاولات");

    if (otp.code !== code) {
      await adminClient
        .from("otp_codes")
        .update({ attempts: (otp.attempts || 0) + 1 })
        .eq("id", otp.id);
      return err("الكود غلط");
    }

    console.log("✅ Code verified");

    // ✅ 3. علّم الكود
    await adminClient
      .from("otp_codes")
      .update({ verified: true })
      .eq("id", otp.id);

    // ✅ 4. المفاتيح الداخلية
    const internalEmail = `${cleanPhone}@loqma.local`;
    const internalPassword = `Loqma_${cleanPhone}_2025`;

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
          console.log("✅ Both exist (matched):", finalUserId);
        } else {
          // orphan public row → امسحه
          console.log("⚠️ Orphan public user. Deleting:", publicUser.id);
          await adminClient.from("users").delete().eq("id", publicUser.id);
        }
      } catch (e) {
        console.error("⚠️ getUserById error:", e);
        await adminClient.from("users").delete().eq("id", publicUser.id);
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
            role: profile.role || "user",
            name: profile.name || "",
          },
        });

      if (authData?.user) {
        finalUserId = authData.user.id;
        isNewUser = true;
        console.log("✅ New auth user:", finalUserId);
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
            (u: any) => u.email === internalEmail
          );

          if (found) {
            finalUserId = found.id;
            console.log("✅ Found existing auth user:", finalUserId);
            break;
          }

          if (!listData?.users || listData.users.length < perPage) break;
          page++;
        }

        if (!finalUserId) {
          return err("تعذر إنشاء الحساب: " + authError.message);
        }
      }
    }

    if (!finalUserId) {
      return err("تعذر تحديد المستخدم");
    }

    // ═══════════════════════════════════════════════════════════
    // ✅ 6. نتأكد إن public.users فيه سجل (upsert)
    // ═══════════════════════════════════════════════════════════
    const { error: upsertError } = await adminClient
      .from("users")
      .upsert(
        {
          id: finalUserId,
          phone: cleanPhone,
          name: profile.name || "",
          city: profile.city || "طنطا",
          role: profile.role || "user",
          is_phone_verified: true,
        },
        { onConflict: "id" }
      );

    if (upsertError) {
      console.error("❌ User upsert error:", JSON.stringify(upsertError));
      return err("تعذر حفظ البيانات: " + upsertError.message);
    }

    console.log("✅ User row upserted");

    // ── لو مقدم خدمة ──
    if (profile.role === "provider") {
      const { error: providerError } = await adminClient
        .from("service_providers")
        .upsert(
          {
            user_id: finalUserId,
            submitted_by: finalUserId,
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
            verification_status: "approved",
            is_active: true,
            is_available: true,
          },
          { onConflict: "user_id" }
        );

      if (providerError) {
        console.error("⚠️ Provider error:", JSON.stringify(providerError));
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
      console.error("❌ Password update error:", JSON.stringify(updatePwError));
    } else {
      console.log("✅ Password updated");
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
      console.error("❌ SignIn error:", JSON.stringify(signInError));
      return err("تعذر تسجيل الدخول: " + (signInError?.message || ""));
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
          role: profile.role || "user",
        },
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (e) {
    console.error("💥 Error:", e);
    return err(e.message || "خطأ غير متوقع");
  }
});

function err(message: string) {
  return new Response(
    JSON.stringify({ success: false, error: message }),
    {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    }
  );
}