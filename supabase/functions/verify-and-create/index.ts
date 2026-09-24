// supabase/functions/verify-and-create/index.ts

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Admin client (للإنشاء)
const adminClient = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { autoRefreshToken: false, persistSession: false } }
);

// Anon client (للـ signIn)
const anonClient = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_ANON_KEY")!,
  { auth: { autoRefreshToken: false, persistSession: false } }
);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type, apikey, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const { phone, code, profile } = body;

    if (!phone || !code || !profile) {
      return err("بيانات ناقصة");
    }

    // ✅ 1. نظّف الرقم
    let cleanPhone = phone.replace(/\D/g, "");
    if (cleanPhone.startsWith("0")) cleanPhone = "20" + cleanPhone.slice(1);
    else if (cleanPhone.length === 10) cleanPhone = "20" + cleanPhone;

    // ✅ 2. تحقق من الكود
    const { data: otp } = await adminClient
      .from("otp_codes")
      .select("*")
      .eq("phone", cleanPhone)
      .eq("verified", false)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (!otp) return err("مفيش كود، اطلب كود جديد");
    if (new Date(otp.expires_at) < new Date()) return err("انتهت صلاحية الكود");
    if (otp.attempts >= 5) return err("تجاوزت عدد المحاولات");

    if (otp.code !== code) {
      await adminClient
        .from("otp_codes")
        .update({ attempts: otp.attempts + 1 })
        .eq("id", otp.id);
      return err("الكود غلط");
    }

    // ✅ 3. علّم الكود إنه اتستخدم
    await adminClient
      .from("otp_codes")
      .update({ verified: true })
      .eq("id", otp.id);

    // ✅ 4. المفتاح الداخلي
    const internalEmail = `${cleanPhone}@loqma.local`;
    const internalPassword = `Loqma_${cleanPhone}_2025`;

    // ✅ 5. نشوف لو الحساب موجود
    const { data: existingUser } = await adminClient
      .from("users")
      .select("id, role, name")
      .eq("phone", cleanPhone)
      .maybeSingle();

    let authUserId: string;
    let isNewUser = false;

    if (existingUser) {
      // ─── مستخدم قديم ───
      authUserId = existingUser.id;
    } else {
      // ─── مستخدم جديد ───
      isNewUser = true;

      // إنشاء Auth user
      const { data: authData, error: authError } = await adminClient.auth.admin.createUser({
        email: internalEmail,
        password: internalPassword,
        email_confirm: true,
        user_metadata: {
          phone: cleanPhone,
          role: profile.role || "user",
          name: profile.name || "",
        },
      });

      if (authError || !authData.user) {
        console.error("Auth error:", authError);
        return err("تعذر إنشاء الحساب: " + (authError?.message || ""));
      }

      authUserId = authData.user.id;

      // إنشاء سجل users
      const { error: userError } = await adminClient.from("users").insert({
        id: authUserId,
        phone: cleanPhone,
        name: profile.name || "",
        city: profile.city || "طنطا",
        role: profile.role || "user",
        is_phone_verified: true,
      });

      if (userError) {
        console.error("User insert error:", userError);
        // ننضف الـ auth user
        await adminClient.auth.admin.deleteUser(authUserId);
        return err("تعذر حفظ البيانات");
      }

      // ── لو مقدم خدمة → نضيفه في service_providers ──
      if (profile.role === "provider") {
        const { error: providerError } = await adminClient
          .from("service_providers")
          .insert({
            user_id: authUserId,
            submitted_by: authUserId,
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
            verification_status: "approved", // ✅ موافق فورًا (هو بيسجل نفسه)
            is_active: true,
            is_available: true,
          });

        if (providerError) {
          console.error("Provider insert error:", providerError);
          // مش هنوقف — نكمّل
        }
      }
    }

    // ✅ 6. نسجل دخول للحصول على tokens
    const { data: sessionData, error: signInError } =
      await anonClient.auth.signInWithPassword({
        email: internalEmail,
        password: internalPassword,
      });

    if (signInError || !sessionData.session) {
      console.error("SignIn error:", signInError);
      return err("تعذر تسجيل الدخول");
    }

    // ✅ 7. نرجّع البيانات
    return new Response(
      JSON.stringify({
        success: true,
        isNewUser,
        user_id: authUserId,
        access_token: sessionData.session.access_token,
        refresh_token: sessionData.session.refresh_token,
        user: {
          id: authUserId,
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
    console.error("Error:", e);
    return err(e.message || "خطأ غير متوقع");
  }
});

function err(message: string) {
  return new Response(
    JSON.stringify({ success: false, error: message }),
    {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    }
  );
}