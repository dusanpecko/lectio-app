import { serve } from "https://deno.land/std/http/server.ts";

serve(async (req) => {
  const { user } = await req.json();
  const supabaseAdminKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  if (!supabaseAdminKey || !supabaseUrl) {
    return new Response('Missing env vars', { status: 500 });
  }

  const { id } = user;
  const res = await fetch(`${supabaseUrl}/auth/v1/admin/users/${id}`, {
    method: 'DELETE',
    headers: {
      'apiKey': supabaseAdminKey,
      'Authorization': `Bearer ${supabaseAdminKey}`,
    },
  });

  if (!res.ok) {
    const err = await res.text();
    return new Response(`Failed to delete user: ${err}`, { status: 500 });
  }

  return new Response('User deleted', { status: 200 });
});