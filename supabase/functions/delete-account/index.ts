import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const auth = req.headers.get("Authorization") ?? "";
    const token = auth.replace(/^Bearer\s+/i, "").trim();
    if (!token) return json({ success: false, error: "unauthorized" }, 401);

    const publicClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: `Bearer ${token}` } } },
    );
    const { data: userData, error: userError } = await publicClient.auth.getUser(token);
    if (userError || !userData.user) return json({ success: false, error: "unauthorized" }, 401);

    const admin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );
    await admin.from("user_devices").delete().eq("user_id", userData.user.id);
    const { error } = await admin.auth.admin.deleteUser(userData.user.id);
    if (error) {
      console.error("account deletion failed", error.message);
      return json({ success: false, error: "تعذر حذف الحساب" }, 500);
    }
    return json({ success: true });
  } catch (error) {
    console.error("delete-account error", error);
    return json({ success: false, error: "تعذر حذف الحساب" }, 500);
  }
});

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Content-Type": "application/json",
};
function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: corsHeaders });
}
