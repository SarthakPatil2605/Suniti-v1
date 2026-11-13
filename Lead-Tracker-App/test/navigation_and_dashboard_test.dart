import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:suniti_crm/core/api/customer_service.dart';
import 'package:suniti_crm/core/api/task_service.dart';
import 'package:suniti_crm/core/constants/app_theme.dart';
import 'package:suniti_crm/models/employee.dart';
import 'package:suniti_crm/providers/auth_provider.dart';
import 'package:suniti_crm/providers/customer_provider.dart';
import 'package:suniti_crm/providers/lead_provider.dart';
import 'package:suniti_crm/providers/task_provider.dart';
import 'package:suniti_crm/screens/home/main_shell.dart';

// CustomerListScreen calls loadExistingCustomers() via addPostFrameCallback.
// Since IndexedStack renders all children, this fires a Dio request that hangs
// in test environment. All tests use pump(Duration) instead of pumpAndSettle.

void main() {
  Widget createShellWidget({
    required AuthProvider authProvider,
    required CustomerProvider customerProvider,
    required LeadProvider leadProvider,
    required TaskProvider taskProvider,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<CustomerProvider>.value(value: customerProvider),
        ChangeNotifierProvider<LeadProvider>.value(value: leadProvider),
        ChangeNotifierProvider<TaskProvider>.value(value: taskProvider),
      ],
      child: MaterialApp(theme: AppTheme.darkTheme, home: const MainShell()),
    );
  }

  group('MainShell & Dashboard Tests', () {
    testWidgets('renders navigation bar tabs and active home dashboard', (
      tester,
    ) async {
      final authProvider = AuthProvider();
      final customerProvider = CustomerProvider(service: CustomerService());
      final leadProvider = LeadProvider();
      final taskProvider = TaskProvider(service: TaskService());

      authProvider.setCurrentEmployee(
        const Employee(
          employeeId: 1,
          name: 'Sandeep Kumar',
          email: 'sandeep@suniti.com',
          role: EmployeeRole.SALES_REP,
        ),
      );

      await tester.pumpWidget(
        createShellWidget(
          authProvider: authProvider,
          customerProvider: customerProvider,
          leadProvider: leadProvider,
          taskProvider: taskProvider,
        ),
      );
      // Use pump(Duration) — pumpAndSettle hangs due to pending Dio requests
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Check navigation bar items
      expect(find.text('HOME'), findsOneWidget);
      expect(find.text('ONGOING'), findsOneWidget);
      expect(find.text('LEAD'), findsOneWidget);
      expect(find.text('CUSTOMERS'), findsOneWidget);

      // Check Dashboard Header
      expect(find.text('Suniti'), findsOneWidget);
      expect(find.text('Sandeep Kumar'), findsOneWidget);

      // Check Dashboard Cards
      expect(find.text('Active Leads'), findsOneWidget);
      expect(find.text('Follow-ups'), findsOneWidget);
      expect(find.text('Customer\nList'), findsOneWidget);
      expect(find.text('Ongoing\nLeads'), findsOneWidget);
      expect(find.text('Blacklisted\nCustomers'), findsOneWidget);
    });

    testWidgets('navigates cleanly between tabs preserving index', (
      tester,
    ) async {
      final authProvider = AuthProvider();
      final customerProvider = CustomerProvider(service: CustomerService());
      final leadProvider = LeadProvider();
      final taskProvider = TaskProvider(service: TaskService());

      await tester.pumpWidget(
        createShellWidget(
          authProvider: authProvider,
          customerProvider: customerProvider,
          leadProvider: leadProvider,
          taskProvider: taskProvider,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Switch to ONGOING tab
      await tester.tap(find.text('ONGOING'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Ongoing Leads'), findsOneWidget);

      // Switch to CUSTOMERS tab — verify AppBar title shows 'Customers'
      await tester.tap(find.text('CUSTOMERS'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Customers'), findsOneWidget);

      // Switch back to HOME tab
      await tester.tap(find.text('HOME'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Active Leads'), findsOneWidget);
    });

    testWidgets(
      'opens Create Lead Track screen when tapping central LEAD action',
      (tester) async {
        final authProvider = AuthProvider();
        final customerProvider = CustomerProvider(service: CustomerService());
        final leadProvider = LeadProvider();
        final taskProvider = TaskProvider(service: TaskService());

        await tester.pumpWidget(
          createShellWidget(
            authProvider: authProvider,
            customerProvider: customerProvider,
            leadProvider: leadProvider,
            taskProvider: taskProvider,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Tap central LEAD floating button
        await tester.tap(find.text('LEAD'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Create Lead Track'), findsOneWidget);
        expect(find.text('1. CUSTOMER SEGMENT'), findsOneWidget);

        // Close create lead modal
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('Active Leads'), findsOneWidget);
      },
    );

    testWidgets('displays clean empty states when no active data is loaded', (
      tester,
    ) async {
      final authProvider = AuthProvider();
      final customerProvider = CustomerProvider(service: CustomerService());
      final leadProvider = LeadProvider();
      final taskProvider = TaskProvider(service: TaskService());

      await tester.pumpWidget(
        createShellWidget(
          authProvider: authProvider,
          customerProvider: customerProvider,
          leadProvider: leadProvider,
          taskProvider: taskProvider,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Active leads count shows '00'
      expect(find.text('00'), findsNWidgets(2)); // Leads and Follow-ups

      // Follow-up section shows clean empty state
      expect(
        find.text('No pending follow-ups scheduled for today'),
        findsOneWidget,
      );
    });
  });
}
