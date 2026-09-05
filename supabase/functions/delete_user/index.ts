// Zmazanie vlastného Auth účtu.
//
// Bezpečnostná oprava (audit 20. 8. 2026): pôvodná verzia brala cieľové UUID
// z tela požiadavky a mazala ho service-role kľúčom bez akejkoľvek kontroly
// volajúceho — ktokoľvek s platným tokenom vedel zmazať cudzí účet.
// Cieľ sa teraz odvodzuje výhradne z overeného JWT.
//
// Hlavná cesta pre appku je backend endpoint /api/user/delete-account, ktorý
// popri Auth účte maže aj profilové dáta. Táto funkcia ostáva len pre staršie
// verzie klienta.

import { createClient } from "jsr:@supabase/supabase-js@2";

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.toLowerCase().startsWith("bearer ")
    ? authHeader.slice(7).trim()
    : "";

  if (!token) {
    return new Response("Unauthorized", { status: 401 });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAdminKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !supabaseAdminKey) {
    return new Response("Missing env vars", { status: 500 });
  }

  const admin = createClient(supabaseUrl, supabaseAdminKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data, error } = await admin.auth.getUser(token);
  if (error || !data.user) {
    return new Response("Unauthorized", { status: 401 });
  }

  const { error: deleteError } = await admin.auth.admin.deleteUser(
    data.user.id,
  );
  if (deleteError) {
    return new Response(`Failed to delete user: ${deleteError.message}`, {
      status: 500,
    });
  }

  return new Response("User deleted", { status: 200 });
});
