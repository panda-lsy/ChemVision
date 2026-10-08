import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json; charset=utf-8",
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: corsHeaders });
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  const authorization = request.headers.get("Authorization") ?? "";
  const bearer = authorization.match(/^Bearer\s+(.+)$/i);
  if (!bearer) return jsonResponse({ error: "unauthorized" }, 401);

  const projectUrl = Deno.env.get("SUPABASE_URL");
  const publishableKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!projectUrl || !publishableKey || !serviceRoleKey) {
    console.error("Supabase function environment is incomplete");
    return jsonResponse({ error: "server_not_configured" }, 500);
  }

  const callerClient = createClient(projectUrl, publishableKey, {
    global: { headers: { Authorization: `Bearer ${bearer[1]}` } },
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: userResult, error: userError } =
    await callerClient.auth.getUser(bearer[1]);
  if (userError || !userResult.user) {
    return jsonResponse({ error: "unauthorized" }, 401);
  }

  const { data: isOwner, error: ownerError } = await callerClient.rpc(
    "is_chemvision_owner",
  );
  if (ownerError) {
    console.error("Owner check failed", ownerError.message);
    return jsonResponse({ error: "owner_check_failed" }, 500);
  }
  if (isOwner !== true) return jsonResponse({ error: "forbidden" }, 403);

  let input: Record<string, unknown> = {};
  try {
    const body: unknown = await request.json();
    if (body && typeof body === "object" && !Array.isArray(body)) {
      input = body as Record<string, unknown>;
    }
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }

  const page = input.page === undefined ? 1 : Number(input.page);
  const perPage = input.perPage === undefined ? 50 : Number(input.perPage);
  if (
    !Number.isInteger(page) || page < 1 ||
    !Number.isInteger(perPage) || perPage < 1 || perPage > 100
  ) {
    return jsonResponse({ error: "invalid_pagination" }, 400);
  }

  const adminClient = createClient(projectUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data, error } = await adminClient.auth.admin.listUsers({
    page,
    perPage,
  });
  if (error) {
    console.error("Could not list users", error.message);
    return jsonResponse({ error: "user_list_failed" }, 500);
  }

  const users = data.users.map((user) => {
    const providers = Array.isArray(user.app_metadata?.providers)
      ? user.app_metadata.providers.filter(
        (provider): provider is string => typeof provider === "string",
      )
      : typeof user.app_metadata?.provider === "string"
      ? [user.app_metadata.provider]
      : [];
    const githubIdentity = user.identities?.find(
      (identity) => identity.provider === "github",
    );
    const identityData = githubIdentity?.identity_data ?? {};
    const githubUsername =
      typeof identityData.user_name === "string"
        ? identityData.user_name
        : typeof identityData.login === "string"
        ? identityData.login
        : null;

    return {
      id: user.id,
      email: user.email ?? null,
      createdAt: user.created_at,
      lastSignInAt: user.last_sign_in_at ?? null,
      providers,
      githubUsername,
    };
  });

  return jsonResponse({
    page,
    perPage,
    hasMore: users.length === perPage,
    users,
  });
});
