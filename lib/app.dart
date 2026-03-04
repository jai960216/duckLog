import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/theme.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/onboarding_screen.dart';
import 'features/auth/services/auth_service.dart';
import 'shell.dart';

class DuckLogApp extends ConsumerWidget {
  const DuckLogApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'DuckLog',
      debugShowCheckedModeBanner: false,
      theme: DuckTheme.light,
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
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (_, __) => const LoginScreen(),
    );
  }
}

class _ProfileGate extends ConsumerWidget {
  const _ProfileGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return profileAsync.when(
      data: (profile) {
        if (profile == null) {
          return const OnboardingScreen();
        }
        return const AppShell();
      },
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (_, __) => const OnboardingScreen(),
    );
  }
}
