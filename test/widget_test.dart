import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fidelito/app.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-publishable-key',
    );
  });

  testWidgets('Vanty abre a tela de login', (WidgetTester tester) async {
    await tester.pumpWidget(const VantyApp());
    await tester.pumpAndSettle();

    expect(find.text('Vanty'), findsOneWidget);
    expect(find.text('Fidelidade que gera benefícios'), findsOneWidget);
    expect(find.text('E-mail'), findsOneWidget);
  });
}
