import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Bảng được nghe realtime (thêm vào publication trong `09_admin.sql`).
enum LiveTable {
  shifts('shifts'),
  bills('bills'),
  billLines('bill_lines');

  const LiveTable(this.tableName);
  final String tableName;
}

/// Một thay đổi vừa xảy ra. Chỉ là TÍN HIỆU để tải lại; dữ liệu vẫn đọc qua RPC như cũ
/// (để mọi luật tính tiền/quyền vẫn nằm ở database).
class LiveChange {
  const LiveChange(this.table, {this.billId});

  /// Đọc mã bill từ dòng thay đổi: `bills.id` hoặc `bill_lines.bill_id`.
  factory LiveChange.fromRow(LiveTable table, Map<String, dynamic> row) {
    final id = switch (table) {
      LiveTable.bills => row['id'],
      LiveTable.billLines => row['bill_id'],
      LiveTable.shifts => null,
    };
    return LiveChange(table, billId: id is String ? id : null);
  }

  final LiveTable table;
  final String? billId;
}

/// Trạng thái kênh realtime.
enum LiveStatus {
  /// Đang kết nối (chưa nhận được sự kiện): app vẫn tải lại theo giờ.
  connecting,

  /// Đang nhận sự kiện: tắt tải lại theo giờ.
  live,

  /// Lỗi kênh / hết thời gian / bị đóng / mất mạng: tải lại theo giờ và thử kết nối lại.
  offline,
}

/// Một lần đăng ký nghe. Gọi [cancel] để gỡ kênh (tránh rò kết nối).
abstract interface class LiveSubscription {
  Future<void> cancel();
}

/// Nguồn thay đổi realtime của một quán.
abstract interface class LiveFeed {
  /// Nghe thay đổi ca và bill của quán `shopId` (`null`: không lọc, RLS vẫn chỉ trả quán của mình).
  LiveSubscription watchShop(
    String? shopId, {
    required void Function(LiveChange change) onChange,
    required void Function(LiveStatus status, Object? error) onStatus,
  });
}

/// Supabase Realtime (`postgres_changes`), một kênh cho cả 3 bảng.
class SupabaseLiveFeed implements LiveFeed {
  SupabaseLiveFeed(this._client);

  final SupabaseClient _client;
  int _seq = 0;

  @override
  LiveSubscription watchShop(
    String? shopId, {
    required void Function(LiveChange change) onChange,
    required void Function(LiveStatus status, Object? error) onStatus,
  }) {
    // Tên kênh luôn mới: kênh cũ đang được gỡ không bị dùng lại.
    final channel = _client.channel('fore-live-${shopId ?? 'me'}-${_seq++}');
    final filter = shopId == null
        ? null
        : PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'shop_id',
            value: shopId,
          );
    for (final table in LiveTable.values) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table.tableName,
        filter: filter,
        callback: (payload) {
          final row = payload.newRecord.isNotEmpty
              ? payload.newRecord
              : payload.oldRecord;
          onChange(LiveChange.fromRow(table, row));
        },
      );
    }
    onStatus(LiveStatus.connecting, null);
    channel.subscribe((status, error) {
      onStatus(
        status == RealtimeSubscribeStatus.subscribed
            ? LiveStatus.live
            : LiveStatus.offline,
        error,
      );
    });
    return _SupabaseLiveSubscription(_client, channel);
  }
}

class _SupabaseLiveSubscription implements LiveSubscription {
  _SupabaseLiveSubscription(this._client, this._channel);

  final SupabaseClient _client;
  final RealtimeChannel _channel;
  bool _cancelled = false;

  @override
  Future<void> cancel() async {
    if (_cancelled) return;
    _cancelled = true;
    try {
      await _client.removeChannel(_channel);
    } catch (e) {
      debugPrint('Fore: gỡ kênh realtime lỗi: $e');
    }
  }
}
