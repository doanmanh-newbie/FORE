import 'dart:async';

import 'package:fore/core/errors/app_failure.dart';
import 'package:fore/core/remote_config/app_config_repository.dart';
import 'package:fore/core/remote_config/remote_app_config.dart';

/// Bản giả của [AppConfigRepository]: trả [config] hoặc ném [failure].
class FakeAppConfigRepository implements AppConfigRepository {
  FakeAppConfigRepository([this.config = RemoteAppConfig.fallback]);

  RemoteAppConfig config;
  AppFailure? failure;
  int fetchCount = 0;

  /// Đặt để giữ request lại tới khi test cho phép.
  Completer<void>? gate;

  @override
  Future<RemoteAppConfig> fetch() async {
    fetchCount++;
    if (gate != null) await gate!.future;
    if (failure != null) throw failure!;
    return config;
  }
}
