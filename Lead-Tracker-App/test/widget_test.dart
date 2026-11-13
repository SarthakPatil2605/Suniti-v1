import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suniti_crm/main.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('SunitiApp boots cleanly with AuthGate', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SunitiApp());
    await tester.pump();
    expect(find.byType(SunitiApp), findsOneWidget);

    // Let the post-frame auth check callback run
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    // Routes cleanly to LoginScreen when unauthenticated
    expect(find.text('Suniti CRM'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
