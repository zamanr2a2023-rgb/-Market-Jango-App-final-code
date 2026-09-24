import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:market_jango/core/services/fcm_push_service.dart';
import 'package:market_jango/features/vendor/offline_sync/data/offline_sale_queue_store.dart';
import 'package:market_jango/features/vendor/offline_sync/data/offline_sync_manager.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await OfflineSaleQueueStore.instance.init();

  if (defaultTargetPlatform == TargetPlatform.android) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  runApp(
    ProviderScope(
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        minTextAdapt: true,
        splitScreenMode: true,
        child: const App(),
      ),
    ),
  );

  // Let the first frame paint before Firebase / FCM / notification setup (reduces long white screen on slow devices).
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(OfflineSyncManager.instance.start());
    if (defaultTargetPlatform == TargetPlatform.android) {
      unawaited(FcmPushService.instance.initializeIfAndroid());
    }
  });
}
