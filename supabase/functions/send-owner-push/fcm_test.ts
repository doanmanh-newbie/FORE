// Test phần thuần của send-owner-push. Chạy được bằng cả hai:
//   node --test supabase/functions/send-owner-push/fcm_test.ts      (Node 22.6+ / 24)
//   deno test supabase/functions/send-owner-push/fcm_test.ts
// Dùng khóa RSA tạo tạm trong test, không cần Firebase thật.
import { test } from "node:test";
import assert from "node:assert/strict";
import {
  buildMessage,
  getAccessToken,
  parsePushRequest,
  parseServiceAccount,
  safeEqual,
  sendToToken,
  signServiceAccountJwt,
  stringifyData,
} from "./fcm.ts";

async function makeServiceAccount() {
  const pair = await crypto.subtle.generateKey(
    { name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" },
    true,
    ["sign", "verify"],
  );
  const der = new Uint8Array(await crypto.subtle.exportKey("pkcs8", pair.privateKey));
  let s = "";
  for (const b of der) s += String.fromCharCode(b);
  const pem = `-----BEGIN PRIVATE KEY-----\n${btoa(s).match(/.{1,64}/g)!.join("\n")}\n-----END PRIVATE KEY-----\n`;
  return {
    sa: { project_id: "fore-test", client_email: "push@fore-test.iam.gserviceaccount.com", private_key: pem },
    publicKey: pair.publicKey,
  };
}

function b64urlDecode(s: string): Uint8Array {
  const b64 = s.replace(/-/g, "+").replace(/_/g, "/") + "===".slice((s.length + 3) % 4);
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
}

test("parseServiceAccount: thiếu secret / JSON sai / thiếu trường thì báo rõ", () => {
  assert.throws(() => parseServiceAccount(undefined), /Thiếu secret/);
  assert.throws(() => parseServiceAccount("{"), /không phải JSON/);
  assert.throws(() => parseServiceAccount('{"project_id":"p","client_email":"e"}'), /private_key/);
});

test("parsePushRequest: đọc payload Database Webhook của owner_notifications", () => {
  const r = parsePushRequest({
    type: "INSERT",
    table: "owner_notifications",
    record: {
      id: 7,
      shop_id: "shop-1",
      title: "Ca vừa đóng",
      body: "Lan đã đóng ca.",
      data: { shift_id: "s1", kind: "shift_closed", n: 3 },
    },
  });
  assert.equal(r.notificationId, 7);
  assert.equal(r.shopId, "shop-1");
  assert.equal(r.userId, null);
  assert.deepEqual(r.data, { shift_id: "s1", kind: "shift_closed", n: "3" });
});

test("parsePushRequest: gọi trực tiếp theo user_id; thiếu người nhận / nội dung thì lỗi", () => {
  const r = parsePushRequest({ user_id: "u1", title: " Thử ", body: "Xin chào" });
  assert.equal(r.userId, "u1");
  assert.equal(r.title, "Thử");
  assert.equal(r.notificationId, null);
  assert.throws(() => parsePushRequest({ title: "a", body: "b" }), /shop_id hoặc user_id/);
  assert.throws(() => parsePushRequest({ shop_id: "s", title: "a" }), /title và body/);
  assert.throws(() => parsePushRequest({ type: "UPDATE", table: "owner_notifications", record: {} }), /INSERT/);
  assert.throws(() => parsePushRequest(null), /JSON object/);
});

test("stringifyData + buildMessage: data của FCM chỉ gồm chuỗi", () => {
  assert.deepEqual(stringifyData({ a: 1, b: "x", c: null, d: { e: true } }), { a: "1", b: "x", d: '{"e":true}' });
  const m = buildMessage("tok", { notificationId: null, shopId: "s", userId: null, title: "T", body: "B", data: { k: "v" } });
  assert.equal(m.message.token, "tok");
  assert.deepEqual(m.message.notification, { title: "T", body: "B" });
  assert.equal(m.message.android.priority, "high");
});

test("signServiceAccountJwt: JWT RS256 hợp lệ, đúng scope FCM và hạn 1 giờ", async () => {
  const { sa, publicKey } = await makeServiceAccount();
  const jwt = await signServiceAccountJwt(sa, 1_700_000_000);
  const [h, c, sig] = jwt.split(".");
  assert.deepEqual(JSON.parse(new TextDecoder().decode(b64urlDecode(h))), { alg: "RS256", typ: "JWT" });
  const claims = JSON.parse(new TextDecoder().decode(b64urlDecode(c)));
  assert.equal(claims.iss, sa.client_email);
  assert.equal(claims.scope, "https://www.googleapis.com/auth/firebase.messaging");
  assert.equal(claims.aud, "https://oauth2.googleapis.com/token");
  assert.equal(claims.exp - claims.iat, 3600);
  const ok = await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    publicKey,
    b64urlDecode(sig),
    new TextEncoder().encode(`${h}.${c}`),
  );
  assert.ok(ok, "chữ ký phải khớp khóa công khai");
});

test("signServiceAccountJwt: chấp nhận private_key có \\n dạng chữ (dán từ secret)", async () => {
  const { sa } = await makeServiceAccount();
  const escaped = { ...sa, private_key: sa.private_key.replace(/\n/g, "\\n") };
  assert.equal((await signServiceAccountJwt(escaped)).split(".").length, 3);
});

test("getAccessToken: đổi JWT lấy token, dùng lại token còn hạn", async () => {
  const { sa } = await makeServiceAccount();
  let calls = 0;
  const fakeFetch = (async (_url: string, init: RequestInit) => {
    calls++;
    const body = new URLSearchParams(init.body as URLSearchParams);
    assert.equal(body.get("grant_type"), "urn:ietf:params:oauth:grant-type:jwt-bearer");
    assert.ok(body.get("assertion")?.split(".").length === 3);
    return new Response(JSON.stringify({ access_token: "ya29.test", expires_in: 3600 }));
  }) as unknown as typeof fetch;
  assert.equal(await getAccessToken(sa, fakeFetch), "ya29.test");
  assert.equal(await getAccessToken(sa, fakeFetch), "ya29.test");
  assert.equal(calls, 1);
});

test("sendToToken: thành công / token hết hiệu lực / lỗi khác", async () => {
  const req = { notificationId: 1, shopId: "s", userId: null, title: "T", body: "B", data: {} };
  let sentUrl = "";
  const ok = await sendToToken("fore-test", "at", "tok-1", req, (async (url: string, init: RequestInit) => {
    sentUrl = url;
    assert.equal((init.headers as Record<string, string>).authorization, "Bearer at");
    return new Response("{}", { status: 200 });
  }) as unknown as typeof fetch);
  assert.deepEqual(ok, { token: "tok-1", ok: true, invalidToken: false });
  assert.equal(sentUrl, "https://fcm.googleapis.com/v1/projects/fore-test/messages:send");

  const gone = await sendToToken("p", "at", "tok-2", req, (async () =>
    new Response('{"error":{"status":"NOT_FOUND","details":[{"errorCode":"UNREGISTERED"}]}}', { status: 404 })
  ) as unknown as typeof fetch);
  assert.equal(gone.ok, false);
  assert.equal(gone.invalidToken, true);

  const busy = await sendToToken("p", "at", "tok-3", req, (async () =>
    new Response('{"error":{"status":"UNAVAILABLE"}}', { status: 503 })
  ) as unknown as typeof fetch);
  assert.equal(busy.ok, false);
  assert.equal(busy.invalidToken, false, "lỗi tạm thời không được xóa token");
  assert.match(busy.error!, /^503/);
});

test("safeEqual", () => {
  assert.ok(safeEqual("abc", "abc"));
  assert.ok(!safeEqual("abc", "abd"));
  assert.ok(!safeEqual("abc", "abcd"));
});
