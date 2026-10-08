import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json; charset=utf-8",
};

const AI_LIMIT = 5;
const MODEL = "deepseek-flash";
const MAX_BODY_BYTES = 8 * 1024 * 1024;
const MAX_IMAGE_DATA_URI_CHARS = 7 * 1024 * 1024;

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: corsHeaders });
}

function asRecord(value: unknown): Record<string, unknown> | null {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

function asCount(value: unknown): number {
  const count = typeof value === "number" ? value : Number(value ?? 0);
  return Number.isSafeInteger(count) && count >= 0 ? count : 0;
}

function getProviders(user: {
  app_metadata?: Record<string, unknown>;
  identities?: Array<{ provider?: string }> | null;
}): Set<string> {
  const providers = new Set<string>();
  const appProviders = user.app_metadata?.providers;
  if (Array.isArray(appProviders)) {
    for (const provider of appProviders) {
      if (typeof provider === "string") providers.add(provider.toLowerCase());
    }
  }
  const appProvider = user.app_metadata?.provider;
  if (typeof appProvider === "string") providers.add(appProvider.toLowerCase());
  for (const identity of user.identities ?? []) {
    if (typeof identity.provider === "string") {
      providers.add(identity.provider.toLowerCase());
    }
  }
  return providers;
}

function quotaPayload(
  used: number,
  reserved: number,
  isAdmin: boolean,
) {
  return {
    used,
    reserved,
    limit: isAdmin ? null : AI_LIMIT,
    remaining: isAdmin ? null : Math.max(0, AI_LIMIT - used - reserved),
    unlimited: isAdmin,
  };
}

async function readQuota(
  adminClient: SupabaseClient<any>,
  userId: string,
  isAdmin: boolean,
) {
  if (isAdmin) return quotaPayload(0, 0, true);
  const { data, error } = await adminClient
    .from("chemvision_ai_usage")
    .select("used_count, reserved_count")
    .eq("user_id", userId)
    .maybeSingle();
  if (error) throw error;
  const row = asRecord(data);
  return quotaPayload(
    asCount(row?.used_count),
    asCount(row?.reserved_count),
    false,
  );
}

async function finalizeReservation(
  adminClient: SupabaseClient<any>,
  requestId: string,
  succeeded: boolean,
  totalTokens: number | null = null,
) {
  const { error } = await adminClient.rpc("finalize_chemvision_ai_call", {
    p_request_id: requestId,
    p_succeeded: succeeded,
    p_total_tokens: totalTokens,
  });
  if (error) {
    console.error("Could not finalize AI quota reservation", error.message);
    return false;
  }
  return true;
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
  const { data: userResult, error: userError } = await callerClient.auth
    .getUser(bearer[1]);
  const user = userResult.user;
  if (userError || !user) return jsonResponse({ error: "unauthorized" }, 401);

  const providers = getProviders(user);
  if (!providers.has("email") && !providers.has("github")) {
    return jsonResponse({ error: "supported_sign_in_required" }, 403);
  }

  const { data: ownerResult, error: ownerError } = await callerClient.rpc(
    "is_chemvision_owner",
  );
  if (ownerError) {
    console.error("Owner check failed", ownerError.message);
    return jsonResponse({ error: "owner_check_failed" }, 500);
  }
  const isAdmin = ownerResult === true;

  const adminClient = createClient(projectUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const contentLength = Number(request.headers.get("content-length") ?? 0);
  if (contentLength > MAX_BODY_BYTES) {
    return jsonResponse({ error: "request_too_large" }, 413);
  }

  let input: Record<string, unknown> | null;
  try {
    const rawBody = await request.text();
    if (new TextEncoder().encode(rawBody).length > MAX_BODY_BYTES) {
      return jsonResponse({ error: "request_too_large" }, 413);
    }
    input = asRecord(JSON.parse(rawBody));
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }
  if (!input) return jsonResponse({ error: "invalid_request" }, 400);

  if (input.action === "usage") {
    try {
      const quota = await readQuota(adminClient, user.id, isAdmin);
      return jsonResponse({ authenticated: true, isAdmin, quota });
    } catch (error) {
      console.error("Could not read AI usage", error);
      return jsonResponse({ error: "quota_unavailable" }, 500);
    }
  }

  const prompt = typeof input.prompt === "string" ? input.prompt.trim() : "";
  if (!prompt || prompt.length > 30000) {
    return jsonResponse({ error: "invalid_prompt" }, 400);
  }

  let imageDataUri: string | null = null;
  if (input.imageDataUri !== undefined && input.imageDataUri !== null) {
    if (
      typeof input.imageDataUri !== "string" ||
      input.imageDataUri.length > MAX_IMAGE_DATA_URI_CHARS ||
      !/^data:image\/(?:png|jpeg|webp|gif);base64,[A-Za-z0-9+/]+={0,2}$/i
        .test(input.imageDataUri)
    ) {
      return jsonResponse({ error: "invalid_image" }, 400);
    }
    imageDataUri = input.imageDataUri;
  }

  const deepseekApiKey = Deno.env.get("DEEPSEEK_API_KEY");
  if (!deepseekApiKey) {
    console.error("DeepSeek API key is not configured");
    return jsonResponse({ error: "ai_service_not_configured" }, 503);
  }

  let requestId: string | null = null;
  if (!isAdmin) {
    const { data, error } = await adminClient.rpc(
      "reserve_chemvision_ai_call",
      {
        p_user_id: user.id,
        p_limit: AI_LIMIT,
      },
    );
    if (error) {
      console.error("Could not reserve AI quota", error.message);
      return jsonResponse({ error: "quota_unavailable" }, 500);
    }
    const reservation = asRecord(data);
    if (!reservation || reservation.allowed !== true) {
      const quota = quotaPayload(
        asCount(reservation?.used),
        asCount(reservation?.reserved),
        false,
      );
      return jsonResponse({ error: "ai_limit_reached", quota }, 429);
    }
    requestId = typeof reservation.requestId === "string"
      ? reservation.requestId
      : null;
    if (!requestId) {
      console.error("Quota reservation did not return a request id");
      return jsonResponse({ error: "quota_unavailable" }, 500);
    }
  }

  const content = imageDataUri
    ? [
      { type: "text", text: prompt },
      { type: "image_url", image_url: { url: imageDataUri } },
    ]
    : prompt;

  let providerResponse: Response;
  try {
    providerResponse = await fetch(
      "https://api.deepseek.com/chat/completions",
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${deepseekApiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: MODEL,
          messages: [{ role: "user", content }],
          stream: false,
          max_tokens: 4096,
        }),
        signal: AbortSignal.timeout(60_000),
      },
    );
  } catch {
    if (requestId) await finalizeReservation(adminClient, requestId, false);
    return jsonResponse({ error: "ai_provider_unavailable" }, 502);
  }

  if (!providerResponse.ok) {
    if (requestId) await finalizeReservation(adminClient, requestId, false);
    return jsonResponse({ error: "ai_provider_rejected_request" }, 502);
  }

  let providerPayload: Record<string, unknown> | null = null;
  try {
    providerPayload = asRecord(await providerResponse.json());
  } catch {
    // A successful upstream response consumes a call even if its body is malformed.
    if (requestId) await finalizeReservation(adminClient, requestId, true);
    return jsonResponse({ error: "ai_provider_invalid_response" }, 502);
  }

  const usage = asRecord(providerPayload?.usage);
  const totalTokens = usage && Number.isSafeInteger(usage.total_tokens) &&
      (usage.total_tokens as number) >= 0
    ? usage.total_tokens as number
    : null;
  if (requestId) {
    const finalized = await finalizeReservation(
      adminClient,
      requestId,
      true,
      totalTokens,
    );
    if (!finalized) {
      return jsonResponse({ error: "quota_finalize_failed" }, 500);
    }
  }

  const choices = providerPayload?.choices;
  const firstChoice = Array.isArray(choices) ? asRecord(choices[0]) : null;
  const message = asRecord(firstChoice?.message);
  const text = typeof message?.content === "string"
    ? message.content.trim()
    : "";
  if (!text) {
    return jsonResponse({ error: "ai_provider_invalid_response" }, 502);
  }

  try {
    const quota = await readQuota(adminClient, user.id, isAdmin);
    return jsonResponse({ text, quota, model: MODEL });
  } catch (error) {
    console.error("Could not read AI usage after completion", error);
    return jsonResponse({ text, quota: null, model: MODEL });
  }
});
