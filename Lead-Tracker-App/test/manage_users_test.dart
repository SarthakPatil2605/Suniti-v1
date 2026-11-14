import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:suniti_crm/core/api/api_exceptions.dart';
import 'package:suniti_crm/core/api/user_service.dart';
import 'package:suniti_crm/models/employee.dart';
import 'package:suniti_crm/providers/auth_provider.dart';
import 'package:suniti_crm/providers/lead_provider.dart';
import 'package:suniti_crm/providers/task_provider.dart';
import 'package:suniti_crm/providers/user_provider.dart';
import 'package:suniti_crm/screens/admin/manage_users_screen.dart';
import 'package:suniti_crm/screens/home/home_screen.dart';

class MockUserService extends UserService {
  final List<Employee> initialUsers;
  final List<Map<String, dynamic>> createdPayloads = [];
  bool shouldThrowConflict = false;
  bool shouldThrowForbidden = false;

  MockUserService({this.initialUsers = const []});

  @override
  Future<List<Employee>> getUsers() async {
    if (shouldThrowForbidden) {
      throw const ForbiddenException(
        message: 'Access restricted: only Administrators can view CRM users.',
      );
    }
    return List.from(initialUsers);
  }

  @override
  Future<Employee> createUser({
    required String email,
    required String password,
    required String role,
    String? name,
  }) async {
    if (shouldThrowConflict) {
      throw ConflictException(
        message: 'An employee with email "$email" is already registered.',
      );
    }
    if (shouldThrowForbidden) {
      throw const ForbiddenException(
        message: 'Permission denied: only Administrators are authorized to provision CRM accounts.',
      );
    }

    createdPayloads.add({
      'email': email,
      'password': password,
      'role': role,
      'name': name,
    });

    final newEmp = Employee(
      employeeId: 100 + createdPayloads.length,
      name: name ?? email.split('@')[0],
      email: email,
      role: EmployeeRole.fromString(role),
      createdAt: DateTime.now(),
    );
    initialUsers.insert(0, newEmp);
    return newEmp;
  }
}

class MockAuthProvider extends ChangeNotifier implements AuthProvider {
  final Employee? _currentEmployee;

  MockAuthProvider(this._currentEmployee);

  @override
  Employee? get currentEmployee => _currentEmployee;

  @override
  bool get isAuthenticated => _currentEmployee != null;

  @override
  bool get isAuthenticating => false;

  @override
  bool get isInitial => false;

  @override
  bool get isUnauthenticated => _currentEmployee == null;

  @override
  AuthStatus get status => _currentEmployee != null
      ? AuthStatus.authenticated
      : AuthStatus.unauthenticated;

  @override
  String? get errorMessage => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Milestone 5D: EmployeeRole Model Tests', () {
    test('EmployeeRole displayName provides readable labels', () {
      expect(EmployeeRole.ADMIN.displayName, 'Administrator');
      expect(EmployeeRole.MANAGER.displayName, 'Manager');
      expect(EmployeeRole.SALES_REP.displayName, 'Sales Representative');
    });

    test('EmployeeRole serialization preserves backend enum strings', () {
      expect(EmployeeRole.ADMIN.toJson(), 'ADMIN');
      expect(EmployeeRole.MANAGER.toJson(), 'MANAGER');
      expect(EmployeeRole.SALES_REP.toJson(), 'SALES_REP');

      expect(EmployeeRole.fromString('ADMIN'), EmployeeRole.ADMIN);
      expect(EmployeeRole.fromString('MANAGER'), EmployeeRole.MANAGER);
      expect(EmployeeRole.fromString('SALES_REP'), EmployeeRole.SALES_REP);
      expect(EmployeeRole.fromString('unknown'), EmployeeRole.SALES_REP);
    });
  });

  group(
    'Milestone 5D: Admin Dashboard UI - Manage Users Action Visibility',
    () {
      final adminUser = Employee(
        employeeId: 1,
        name: 'Super Admin',
        email: 'admin@suniti.com',
        role: EmployeeRole.ADMIN,
      );

      final managerUser = Employee(
        employeeId: 2,
        name: 'Team Manager',
        email: 'manager@suniti.com',
        role: EmployeeRole.MANAGER,
      );

      final salesRepUser = Employee(
        employeeId: 3,
        name: 'Sales Rep',
        email: 'sales@suniti.com',
        role: EmployeeRole.SALES_REP,
      );

      Widget createHomeScreenWithRole(Employee user) {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(
              value: MockAuthProvider(user),
            ),
            ChangeNotifierProvider<LeadProvider>(create: (_) => LeadProvider()),
            ChangeNotifierProvider<TaskProvider>(create: (_) => TaskProvider()),
          ],
          child: const MaterialApp(home: HomeScreen()),
        );
      }

      testWidgets('Manage Users icon appears in Top App Bar for ADMIN role', (
        tester,
      ) async {
        await tester.pumpWidget(createHomeScreenWithRole(adminUser));
        await tester.pumpAndSettle();

        // Manage Users icon button with tooltip should be present
        expect(find.byTooltip('Manage Users'), findsOneWidget);
        expect(find.byIcon(Icons.manage_accounts_rounded), findsOneWidget);
      });

      testWidgets('Manage Users icon is hidden for MANAGER role', (
        tester,
      ) async {
        await tester.pumpWidget(createHomeScreenWithRole(managerUser));
        await tester.pumpAndSettle();

        expect(find.byTooltip('Manage Users'), findsNothing);
        expect(find.byIcon(Icons.manage_accounts_rounded), findsNothing);
      });

      testWidgets('Manage Users icon is hidden for SALES_REP role', (
        tester,
      ) async {
        await tester.pumpWidget(createHomeScreenWithRole(salesRepUser));
        await tester.pumpAndSettle();

        expect(find.byTooltip('Manage Users'), findsNothing);
        expect(find.byIcon(Icons.manage_accounts_rounded), findsNothing);
      });
    },
  );

  group('Milestone 5D: Manage Users Screen & Account Creation Tests', () {
    final adminUser = Employee(
      employeeId: 1,
      name: 'Admin User',
      email: 'admin@suniti.com',
      role: EmployeeRole.ADMIN,
    );

    final existingUser1 = Employee(
      employeeId: 10,
      name: 'Alice Johnson',
      email: 'alice@suniti.com',
      role: EmployeeRole.MANAGER,
      createdAt: DateTime(2026, 10, 1),
    );

    final existingUser2 = Employee(
      employeeId: 11,
      name: 'Bob Smith',
      email: 'bob@suniti.com',
      role: EmployeeRole.SALES_REP,
      createdAt: DateTime(2026, 11, 5),
    );

    Widget createManageUsersWidget({
      required MockUserService mockService,
      Employee? currentUser,
    }) {
      final userProvider = UserProvider(userService: mockService);
      final authProvider = MockAuthProvider(currentUser ?? adminUser);

      return MultiProvider(
        providers: [
          ChangeNotifierProvider<UserProvider>.value(value: userProvider),
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ],
        child: const MaterialApp(home: ManageUsersScreen()),
      );
    }

    testWidgets('renders user creation form and lists existing CRM users', (
      tester,
    ) async {
      final mockService = MockUserService(
        initialUsers: [existingUser1, existingUser2],
      );

      await tester.pumpWidget(
        createManageUsersWidget(mockService: mockService),
      );
      await tester.pumpAndSettle();

      // Form header and inputs
      expect(find.text('Add New CRM User'), findsOneWidget);
      expect(find.text('Email Address *'), findsOneWidget);
      expect(find.text('Password *'), findsOneWidget);
      expect(find.text('Role *'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);

      // Existing users list
      expect(find.text('EXISTING USERS'), findsOneWidget);
      expect(find.text('2 TOTAL'), findsOneWidget);
      expect(find.text('alice@suniti.com'), findsOneWidget);
      expect(find.text('MANAGER'), findsOneWidget);
      expect(find.text('bob@suniti.com'), findsOneWidget);
      expect(find.text('SALES REPRESENTATIVE'), findsOneWidget);
    });

    testWidgets(
      'form validates required fields, invalid email and short password',
      (tester) async {
        final mockService = MockUserService(initialUsers: []);

        await tester.pumpWidget(
          createManageUsersWidget(mockService: mockService),
        );
        await tester.pumpAndSettle();

        // 1. Submit empty form
        await tester.tap(find.text('Create Account'));
        await tester.pumpAndSettle();

        expect(find.text('Email address is required'), findsOneWidget);
        expect(find.text('Password is required'), findsOneWidget);

        // 2. Enter invalid email and short password
        await tester.enterText(
          find.widgetWithText(TextFormField, 'e.g. john@suniti.com'),
          'invalid-email',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Minimum 6 characters'),
          '123',
        );

        await tester.tap(find.text('Create Account'));
        await tester.pumpAndSettle();

        expect(find.text('Please enter a valid email address'), findsOneWidget);
        expect(
          find.text('Password must be at least 6 characters'),
          findsOneWidget,
        );
        expect(mockService.createdPayloads.isEmpty, isTrue);
      },
    );

    testWidgets('password visibility toggle changes obscured state', (
      tester,
    ) async {
      final mockService = MockUserService(initialUsers: []);

      await tester.pumpWidget(
        createManageUsersWidget(mockService: mockService),
      );
      await tester.pumpAndSettle();

      final passwordFieldFinder = find.widgetWithText(
        TextFormField,
        'Minimum 6 characters',
      );
      expect(passwordFieldFinder, findsOneWidget);

      final initialTextField = tester.widget<TextField>(
        find.descendant(
          of: passwordFieldFinder,
          matching: find.byType(TextField),
        ),
      );
      expect(initialTextField.obscureText, isTrue);

      // Tap show password toggle
      await tester.tap(find.byTooltip('Show password'));
      await tester.pumpAndSettle();

      final toggledTextField = tester.widget<TextField>(
        find.descendant(
          of: passwordFieldFinder,
          matching: find.byType(TextField),
        ),
      );
      expect(toggledTextField.obscureText, isFalse);
    });

    testWidgets(
      'successful user creation clears password and adds user to list',
      (tester) async {
        final mockService = MockUserService(initialUsers: []);

        await tester.pumpWidget(
          createManageUsersWidget(mockService: mockService),
        );
        await tester.pumpAndSettle();

        // Fill in user details
        await tester.enterText(
          find.widgetWithText(TextFormField, 'e.g. john@suniti.com'),
          'charlie@suniti.com',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Minimum 6 characters'),
          'Secret1234',
        );

        // Select Role: Manager
        await tester.tap(find.text('Sales Representative'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Manager').last);
        await tester.pumpAndSettle();

        // Submit
        await tester.tap(find.text('Create Account'));
        await tester.pumpAndSettle();

        // Verify backend payload
        expect(mockService.createdPayloads.length, 1);
        expect(
          mockService.createdPayloads.first['email'],
          'charlie@suniti.com',
        );
        expect(mockService.createdPayloads.first['password'], 'Secret1234');
        expect(mockService.createdPayloads.first['role'], 'MANAGER');

        // Password field must be cleared
        final passwordField = tester.widget<TextField>(
          find.descendant(
            of: find.widgetWithText(TextFormField, 'Minimum 6 characters'),
            matching: find.byType(TextField),
          ),
        );
        expect(passwordField.controller?.text.isEmpty, isTrue);

        // User appears in the list below
        expect(find.text('charlie@suniti.com'), findsOneWidget);
        expect(find.text('MANAGER'), findsOneWidget);
        expect(find.text('1 TOTAL'), findsOneWidget);
      },
    );

    testWidgets(
      'failed creation due to duplicate email displays 409 conflict error',
      (tester) async {
        final mockService = MockUserService(initialUsers: []);
        mockService.shouldThrowConflict = true;

        await tester.pumpWidget(
          createManageUsersWidget(mockService: mockService),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'e.g. john@suniti.com'),
          'existing@suniti.com',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Minimum 6 characters'),
          'Password123',
        );

        await tester.tap(find.text('Create Account'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'An employee with email "existing@suniti.com" is already registered.',
          ),
          findsWidgets,
        );
      },
    );

    testWidgets('non-admin user accessing screen receives access denied gate', (
      tester,
    ) async {
      final mockService = MockUserService(initialUsers: []);
      final salesRep = Employee(
        employeeId: 5,
        name: 'Sales Rep User',
        email: 'sales@suniti.com',
        role: EmployeeRole.SALES_REP,
      );

      await tester.pumpWidget(
        createManageUsersWidget(
          mockService: mockService,
          currentUser: salesRep,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Administrator Privileges Required'), findsOneWidget);
      expect(find.text('Add New CRM User'), findsNothing);
    });
  });
}
