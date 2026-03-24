import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/colors.dart';
import 'config/theme.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/onboarding_screen.dart';
import 'features/auth/services/auth_service.dart';
import 'features/social/screens/suspension_screen.dart';
import 'features/subscription/services/purchase_service.dart';
import 'services/fcm_service.dart';
import 'shell.dart';

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DuckColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/splash_logo.png', width: 72, height: 72),
            const SizedBox(height: 16),
            Text(
              'DuckLog',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
            ),
            const SizedBox(height: 24),
            Lottie.asset(
              'assets/lottie/duck_loading.json',
              width: 80,
              height: 80,
              fit: BoxFit.contain,
            ),
          ],
        ),
      ),
    );
  }
}

class DuckLogApp extends ConsumerWidget {
  const DuckLogApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'DuckLog',
      debugShowCheckedModeBanner: false,
      theme: DuckTheme.light,
      navigatorObservers: [
        FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
      ],
      home: const AuthGate(),
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (state) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) {
          return const LoginScreen();
        }
        // Check if profile exists for onboarding
        return const _ProfileGate();
      },
      loading: () => const _SplashScreen(),
      error: (_, _) => const LoginScreen(),
    );
  }
}

class _ProfileGate extends ConsumerStatefulWidget {
  const _ProfileGate();

  @override
  ConsumerState<_ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends ConsumerState<_ProfileGate> {
  bool _fcmInitialized = false;
  bool _purchaseInitialized = false;

  void _initFcm() {
    if (_fcmInitialized) return;
    _fcmInitialized = true;
    FcmService.instance.initialize();
  }

  void _initPurchaseListener() {
    _purchaseInitialized = true;
    ref.read(purchaseServiceProvider).startListening();
  }

  void _resetPurchaseListener() {
    if (!_purchaseInitialized) return;
    _purchaseInitialized = false;
    ref.read(purchaseServiceProvider).reset();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);

    return profileAsync.when(
      data: (profile) {
        if (profile == null) {
          _resetPurchaseListener();
          return const OnboardingScreen();
        }
        if (profile.isSuspended) {
          _resetPurchaseListener();
          return SuspensionScreen(
            userId: profile.id,
            nickname: profile.nickname,
          );
        }
        _initFcm();
        _initPurchaseListener();
        return const AppShell();
      },
      loading: () => const _SplashScreen(),
      error: (_, _) => const OnboardingScreen(),
    );
  }
}
