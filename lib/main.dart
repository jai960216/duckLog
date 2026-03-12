import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'services/fcm_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  if (!SupabaseConfig.isConfigured) {
    if (kDebugMode) debugPrint('⚠️ SUPABASE_URL/SUPABASE_ANON_KEY not set. '
        'Use --dart-define-from-file=.env.json');
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              '환경변수가 설정되지 않았습니다.\n'
              '--dart-define-from-file=.env.json 을 확인해주세요.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
    return;
  }

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  runApp(
    const ProviderScope(
      child: DuckLogApp(),
    ),
  );
}
