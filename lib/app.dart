import 'package:flutter/material.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class FidelizaApp extends StatelessWidget {
  const FidelizaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Fideliza',
      theme: AppTheme.light,
      routerConfig: appRouter,
    );
  }
}