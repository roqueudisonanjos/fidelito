import 'package:flutter/material.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class FidelitoApp extends StatelessWidget {
  const FidelitoApp({super.key});

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