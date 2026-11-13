import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:suniti_crm/core/constants/app_theme.dart';
import 'package:suniti_crm/providers/auth_provider.dart';
import 'package:suniti_crm/screens/auth/login_screen.dart';

void main() {
  Widget createTestWidget(AuthProvider authProvider) {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: ChangeNotifierProvider<AuthProvider>.value(
        value: authProvider,
        child: const LoginScreen(),
      ),
    );
  }

  group('LoginScreen Tests', () {
    testWidgets('renders all essential login elements', (tester) async {
      final authProvider = AuthProvider();

      await tester.pumpWidget(createTestWidget(authProvider));
      await tester.pumpAndSettle();

      expect(find.text('Suniti CRM'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
    });

    testWidgets('validates required email and password fields', (tester) async {
      final authProvider = AuthProvider();

      await tester.pumpWidget(createTestWidget(authProvider));
      await tester.pumpAndSettle();

      // Tap Sign In with empty fields
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your work email'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
    });

    testWidgets('validates email format and password length', (tester) async {
      final authProvider = AuthProvider();

      await tester.pumpWidget(createTestWidget(authProvider));
      await tester.pumpAndSettle();

      // Enter invalid email and short password
      await tester.enterText(find.byType(TextFormField).first, 'invalid-email');
      await tester.enterText(find.byType(TextFormField).last, '123');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email address'), findsOneWidget);
      expect(
        find.text('Password must be at least 6 characters'),
        findsOneWidget,
      );
    });

    testWidgets('toggles password visibility correctly', (tester) async {
      final authProvider = AuthProvider();

      await tester.pumpWidget(createTestWidget(authProvider));
      await tester.pumpAndSettle();

      final passwordFieldFinder = find.byType(TextFormField).last;
      TextField passwordField = tester.widget(
        find.descendant(
          of: passwordFieldFinder,
          matching: find.byType(TextField),
        ),
      );

      // Initially obscured
      expect(passwordField.obscureText, isTrue);

      // Tap visibility toggle icon
      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pumpAndSettle();

      passwordField = tester.widget(
        find.descendant(
          of: passwordFieldFinder,
          matching: find.byType(TextField),
        ),
      );
      expect(passwordField.obscureText, isFalse);
    });
  });
}
