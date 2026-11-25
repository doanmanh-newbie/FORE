// Phần thuần của Edge Function send-owner-push: ký JWT service account, lấy access token OAuth2,
// dựng và gửi tin FCM HTTP v1, đọc payload. Chỉ dùng API web chuẩn (fetch, WebCrypto) nên chạy được
// trên Deno (Supabase Edge) lẫn Node 20+ (để thử nhanh trên máy).

export type ServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
  token_uri?: string;
};

/** Thông báo cần gửi, sau khi đọc từ webhook hoặc lời gọi trực tiếp. */
export type PushRequest = {
  notificationId: number | null; // id trong owner_notifications (null nếu gọi trực tiếp)
  shopId: string | null;
  userId: string | null;
  title: string;
  body: string;
  data: Record<string, string>;
};

export type SendResult = {
  token: string;
  ok: boolean;
  /** Token không còn hợp lệ (gỡ app, đăng xuất trên máy): nên xóa khỏi device_tokens. */
  invalidToken: boolean;
  error?: string;
};

const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
const DEFAULT_TOKEN_URI = "https://oauth2.googleapis.com/token";

/** Đọc secret FIREBASE_SERVICE_ACCOUNT (JSON của file khóa service account). */
export function parseServiceAccount(raw: string | undefined): ServiceAccount {
  if (!raw) throw new Error("Thiếu secret FIREBASE_SERVICE_ACCOUNT");
  let sa: ServiceAccount;
  try {
    sa = JSON.parse(raw);
  } catch {
    throw new Error("FIREBASE_SERVICE_ACCOUNT không phải JSON hợp lệ");
  }
  for (const k of ["project_id", "client_email", "private_key"] as const) {
    if (typeof sa[k] !== "string" || !sa[k]) {
      throw new Error(`FIREBASE_SERVICE_ACCOUNT thiếu ${k}`);
    }
  }
  return sa;
}

/**
 * Đọc thân request. Hỗ trợ:
 * - Database Webhook của Supabase: { type: "INSERT", table: "owner_notifications", record: {...} }
 * - Gọi trực tiếp: { shop_id? | user_id?, title, body, data? }
 */
export function parsePushRequest(body: unknown): PushRequest {
  if (!body || typeof body !== "object") throw new Error("Thân request phải là JSON object");
  const b = body as Record<string, unknown>;
  const isWebhook = b.type !== undefined && b.record !== undefined;
  if (isWebhook && (b.type !== "INSERT" || b.table !== "owner_notifications")) {
    throw new Error("Webhook chỉ nhận INSERT trên owner_notifications");
  }
  const r = (isWebhook ? b.record : b) as Record<string, unknown>;
  const str = (v: unknown) => (typeof v === "string" && v.trim() ? v.trim() : null);
  const shopId = str(r.shop_id);
  const userId = str(r.user_id);
  const title = str(r.title);
  const text = str(r.body);
  if (!shopId && !userId) throw new Error("Cần shop_id hoặc user_id");
  if (!title || !text) throw new Error("Cần title và body");
  return {
    notificationId: typeof r.id === "number" ? r.id : null,
    shopId,
    userId,
    title: title.slice(0, 120),
    body: text.slice(0, 500),
    data: stringifyData(r.data),
  };
}

/** FCM chỉ nhận data dạng chuỗi -> chuỗi. */
export function stringifyData(data: unknown): Record<string, string> {
  const out: Record<string, string> = {};
  if (!data || typeof data !== "object") return out;
  for (const [k, v] of Object.entries(data as Record<string, unknown>)) {
    if (v === null || v === undefined) continue;
    out[k] = typeof v === "string" ? v : JSON.stringify(v);
  }
  return out;
}

/** Tin FCM HTTP v1 cho một token. */
export function buildMessage(token: string, req: PushRequest) {
  return {
    message: {
      token,
      notification: { title: req.title, body: req.body },
      data: req.data,
      android: { priority: "high" },
      apns: { payload: { aps: { sound: "default" } } },
    },
  };
}

// ---------------------------------------------------------------- JWT + OAuth2

function base64url(bytes: Uint8Array | string): string {
  const b = typeof bytes === "string" ? new TextEncoder().encode(bytes) : bytes;
  let s = "";
  for (const x of b) s += String.fromCharCode(x);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToDer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/\\n/g, "\n")
    .replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s+/g, "");
  const bin = atob(b64);
  const der = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) der[i] = bin.charCodeAt(i);
  return der.buffer;
}

/** JWT RS256 tự ký bằng private_key của service account (không cần thư viện). */
export async function signServiceAccountJwt(
  sa: ServiceAccount,
  nowSeconds = Math.floor(Date.now() / 1000),
): Promise<string> {
  const header = { alg: "RS256", typ: "JWT" };
  const claims = {
    iss: sa.client_email,
    scope: FCM_SCOPE,
    aud: sa.token_uri ?? DEFAULT_TOKEN_URI,
    iat: nowSeconds,
    exp: nowSeconds + 3600,
  };
  const unsigned = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(claims))}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToDer(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(unsigned));
  return `${unsigned}.${base64url(new Uint8Array(sig))}`;
}

let cached: { token: string; expiresAt: number; email: string } | null = null;

/** Access token OAuth2 cho FCM, dùng lại tới gần hết hạn (giữa các lần gọi của cùng một instance). */
export async function getAccessToken(sa: ServiceAccount, fetchFn: typeof fetch = fetch): Promise<string> {
  const now = Date.now();
  if (cached && cached.email === sa.client_email && cached.expiresAt - 60_000 > now) return cached.token;
  const assertion = await signServiceAccountJwt(sa);
  const res = await fetchFn(sa.token_uri ?? DEFAULT_TOKEN_URI, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!res.ok) throw new Error(`Lấy access token thất bại: ${res.status} ${await res.text()}`);
  const json = await res.json() as { access_token: string; expires_in?: number };
  cached = {
    token: json.access_token,
    expiresAt: now + (json.expires_in ?? 3600) * 1000,
    email: sa.client_email,
  };
  return json.access_token;
}

/** Gửi tới một token. Token hết hạn / không còn đăng ký -> invalidToken = true. */
export async function sendToToken(
  projectId: string,
  accessToken: string,
  token: string,
  req: PushRequest,
  fetchFn: typeof fetch = fetch,
): Promise<SendResult> {
  const res = await fetchFn(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
    method: "POST",
    headers: { authorization: `Bearer ${accessToken}`, "content-type": "application/json" },
    body: JSON.stringify(buildMessage(token, req)),
  });
  if (res.ok) return { token, ok: true, invalidToken: false };
  const text = await res.text();
  const invalidToken = res.status === 404 || /UNREGISTERED|registration-token-not-registered/.test(text) ||
    (res.status === 400 && /INVALID_ARGUMENT/.test(text) && /token/i.test(text));
  return { token, ok: false, invalidToken, error: `${res.status} ${text.slice(0, 300)}` };
}

/** So sánh chuỗi bí mật không lộ thời gian theo vị trí ký tự sai. */
export function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}
