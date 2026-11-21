// =====================================================================================
// Edge Function: send-owner-push — gửi push FCM (HTTP v1) cho CHỦ QUÁN.
//
// Luồng: trigger trong database/09_admin.sql thêm dòng vào owner_notifications (nhân viên đóng ca,
// hủy bill đã thu, gửi yêu cầu sửa kho) -> Database Webhook gọi function này -> function lấy token
// FCM của các chủ quán (device_tokens) và gửi; ghi sent_at / sent_count / error vào dòng thông báo;
// token không còn hợp lệ thì xóa.
//
// 1) Secrets (KHÔNG commit file khóa vào repo):
//      supabase secrets set FIREBASE_SERVICE_ACCOUNT="$(cat duong-dan/service-account.json)"
//      supabase secrets set PUSH_WEBHOOK_SECRET="<chuỗi ngẫu nhiên dài>"
//    - FIREBASE_SERVICE_ACCOUNT: nội dung file JSON khóa service account (Firebase Console ->
//      Project settings -> Service accounts -> Generate new private key). Dùng để tự ký OAuth2.
//    - PUSH_WEBHOOK_SECRET: webhook gửi kèm header x-push-secret (không cần lộ service_role key).
//    - SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY: Supabase tự cấp cho Edge Function.
//
// 2) Deploy (function tự kiểm tra bí mật nên tắt kiểm tra JWT mặc định):
//      supabase functions deploy send-owner-push --no-verify-jwt
//
// 3) Database Webhook (Dashboard -> Database -> Webhooks -> Create):
//      Table: public.owner_notifications   Events: Insert
//      Type: Supabase Edge Functions -> send-owner-push   Method: POST
//      HTTP Headers: x-push-secret: <PUSH_WEBHOOK_SECRET>
//
// 4) Gọi trực tiếp (thử tay, hoặc từ server khác):
//      curl -X POST https://<project>.supabase.co/functions/v1/send-owner-push \
//        -H "x-push-secret: <PUSH_WEBHOOK_SECRET>" -H "content-type: application/json" \
//        -d '{"shop_id":"<uuid quán>","title":"Thử","body":"Xin chào chủ quán"}'
//    Thay shop_id bằng user_id để gửi cho đúng một người.
// =====================================================================================

import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  getAccessToken,
  parsePushRequest,
  parseServiceAccount,
  type PushRequest,
  safeEqual,
  sendToToken,
} from "./fcm.ts";

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });

/** Chỉ webhook (x-push-secret) hoặc server có service_role key được gọi. */
function authorized(req: Request): boolean {
  const secret = Deno.env.get("PUSH_WEBHOOK_SECRET");
  const header = req.headers.get("x-push-secret");
  if (secret && header && safeEqual(header, secret)) return true;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const bearer = req.headers.get("authorization")?.replace(/^Bearer\s+/i, "");
  return !!serviceKey && !!bearer && safeEqual(bearer, serviceKey);
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { error: "Chỉ nhận POST" });
  if (!authorized(req)) return json(401, { error: "Không có quyền" });

  let push: PushRequest;
  try {
    push = parsePushRequest(await req.json());
  } catch (e) {
    return json(400, { error: (e as Error).message });
  }

  const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });

  const finish = async (sent: number, error: string | null) => {
    if (push.notificationId === null) return;
    await db.from("owner_notifications")
      .update({ sent_at: new Date().toISOString(), sent_count: sent, error })
      .eq("id", push.notificationId);
  };

  try {
    // Người nhận: một user cụ thể, hoặc mọi chủ đang hoạt động của quán.
    let userIds: string[];
    if (push.userId) {
      userIds = [push.userId];
    } else {
      const { data, error } = await db.from("staff")
        .select("auth_user_id")
        .eq("shop_id", push.shopId!)
        .eq("role", "owner")
        .eq("active", true)
        .not("auth_user_id", "is", null);
      if (error) throw error;
      userIds = (data ?? []).map((r) => r.auth_user_id as string);
    }
    if (userIds.length === 0) {
      await finish(0, "Không có chủ quán nào");
      return json(200, { sent: 0, failed: 0, removed: 0, reason: "no_recipients" });
    }

    const { data: rows, error } = await db.from("device_tokens").select("token").in("user_id", userIds);
    if (error) throw error;
    const tokens = (rows ?? []).map((r) => r.token as string);
    if (tokens.length === 0) {
      await finish(0, "Chủ quán chưa có thiết bị nhận thông báo");
      return json(200, { sent: 0, failed: 0, removed: 0, reason: "no_tokens" });
    }

    const sa = parseServiceAccount(Deno.env.get("FIREBASE_SERVICE_ACCOUNT"));
    const accessToken = await getAccessToken(sa);
    const results = await Promise.all(tokens.map((t) => sendToToken(sa.project_id, accessToken, t, push)));

    const invalid = results.filter((r) => r.invalidToken).map((r) => r.token);
    if (invalid.length > 0) await db.from("device_tokens").delete().in("token", invalid);

    const sent = results.filter((r) => r.ok).length;
    const errors = results.filter((r) => !r.ok && !r.invalidToken).map((r) => r.error);
    await finish(sent, errors.length ? errors.join(" | ").slice(0, 1000) : null);
    return json(200, { sent, failed: results.length - sent, removed: invalid.length });
  } catch (e) {
    const message = (e as Error).message ?? String(e);
    console.error("send-owner-push:", message);
    await finish(0, message.slice(0, 1000)).catch(() => {});
    return json(500, { error: message });
  }
});
