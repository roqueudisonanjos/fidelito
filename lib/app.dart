import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class FidelitoApp extends StatefulWidget {
  const FidelitoApp({super.key});

  @override
  State<FidelitoApp> createState() => _FidelitoAppState();
}

class _FidelitoAppState extends State<FidelitoApp> {
  final SupabaseClient _supabase = Supabase.instance.client;
  StreamSubscription<AuthState>? _authSubscription;
  Timer? _companyStatusTimer;
  bool _checkingCompanyStatus = false;
  bool _alreadyRedirectedForSuspension = false;

  @override
  void initState() {
    super.initState();
    _authSubscription = _supabase.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.signedIn) {
        unawaited(_startCompanyStatusMonitor());
      } else if (state.event == AuthChangeEvent.signedOut) {
        _companyStatusTimer?.cancel();
        _companyStatusTimer = null;
        _alreadyRedirectedForSuspension = false;
      }
    });

    if (_supabase.auth.currentUser != null) {
      unawaited(_startCompanyStatusMonitor());
    }
  }

  Future<void> _startCompanyStatusMonitor() async {
    _companyStatusTimer?.cancel();
    _companyStatusTimer = null;
    _alreadyRedirectedForSuspension = false;

    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final profile = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted || _supabase.auth.currentUser?.id != user.id) return;
      if (profile?['role'] != 'company_owner') return;

      await _checkCompanyStatus(user.id);
      _companyStatusTimer = Timer.periodic(
        const Duration(seconds: 12),
        (_) => unawaited(_checkCompanyStatus(user.id)),
      );
    } catch (_) {
      // A verificação também é feita pelo redirecionamento do GoRouter.
    }
  }

  Future<void> _checkCompanyStatus(String userId) async {
    if (_checkingCompanyStatus || !mounted) return;
    if (_supabase.auth.currentUser?.id != userId) return;

    _checkingCompanyStatus = true;
    try {
      final company = await _supabase
          .from('companies')
          .select('active, suspended_at')
          .eq('owner_id', userId)
          .maybeSingle();

      if (!mounted || _supabase.auth.currentUser?.id != userId) return;

      if (company != null && company['active'] != true) {
        if (_alreadyRedirectedForSuspension) return;
        _alreadyRedirectedForSuspension = true;
        final destination = company['suspended_at'] != null
            ? '/company/suspended'
            : '/company/pending';
        appRouter.go(destination);
      } else if (company?['active'] == true) {
        final wasSuspended = _alreadyRedirectedForSuspension;
        _alreadyRedirectedForSuspension = false;
        if (wasSuspended) {
          appRouter.go('/company');
        }
      }
    } catch (_) {
      // Falhas temporárias de rede não encerram a sessão automaticamente.
    } finally {
      _checkingCompanyStatus = false;
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _companyStatusTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Fidelito',
      theme: AppTheme.light,
      routerConfig: appRouter,
    );
  }
}
