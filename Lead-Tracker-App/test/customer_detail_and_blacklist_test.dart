import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:suniti_crm/core/api/customer_service.dart';
import 'package:suniti_crm/models/customer.dart';
import 'package:suniti_crm/models/employee.dart';
import 'package:suniti_crm/models/lead_note.dart';
import 'package:suniti_crm/models/opportunity.dart';
import 'package:suniti_crm/providers/auth_provider.dart';
import 'package:suniti_crm/providers/customer_provider.dart';
import 'package:suniti_crm/screens/customers/customer_detail_screen.dart';

class MockDetailCustomerService extends CustomerService {
  final List<Customer> customers;
  final Map<int, List<Opportunity>> opportunitiesByCustomer;
  final Map<int, String?> blocklistReasons = {};

  MockDetailCustomerService({
    required this.customers,
    required this.opportunitiesByCustomer,
  });

  @override
  Future<CustomerOpportunitiesResult> getCustomerOpportunities(
    int customerId,
  ) async {
    final customer = customers.firstWhere((c) => c.customerId == customerId);
    final opps = opportunitiesByCustomer[customerId] ?? [];
    return CustomerOpportunitiesResult(
      companyId: 1,
      companyName: 'Suniti CRM',
      customer: customer,
      opportunities: opps,
    );
  }

  @override
  Future<Customer> toggleBlocklist(
    int customerId, {
    bool? isBlocklisted,
    String? blocklistReason,
  }) async {
    final index = customers.indexWhere((c) => c.customerId == customerId);
    if (index != -1) {
      final current = customers[index];
      final newStatus = isBlocklisted ?? !current.isBlocklisted;
      blocklistReasons[customerId] = newStatus ? blocklistReason : null;
      final updated = current.copyWith(
        isBlocklisted: newStatus,
        blocklistReason: newStatus ? blocklistReason : null,
        clearBlocklistReason: !newStatus,
      );
      customers[index] = updated;
      return updated;
    }
    throw Exception('Customer not found');
  }

  @override
  Future<List<Customer>> getBlocklistedCustomers() async {
    return customers.where((c) => c.isBlocklisted).toList();
  }

  @override
  Future<ExistingCustomersResult> getExistingCustomers() async {
    final active = customers
        .where(
          (c) => !c.isBlocklisted && c.customerType == CustomerType.EXISTING,
        )
        .toList();
    return ExistingCustomersResult(
      grouped: {CustomerTier.PREMIUM: active},
      counts: {CustomerTier.PREMIUM: active.length},
      total: active.length,
    );
  }

  @override
  Future<List<Customer>> getNewCustomers() async {
    return customers
        .where((c) => !c.isBlocklisted && c.customerType == CustomerType.NEW)
        .toList();
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
  group('Milestone 5C: Customer Model & RBAC Permission Tests', () {
    test('Customer model serializes blocklist_reason properly', () {
      final json = {
        'customer_id': 15,
        'name': 'Reliant Glassworks Ltd',
        'phone': '9876543210',
        'billing_address': 'Sector 4, Rohini, Delhi',
        'tier': 'PREMIUM',
        'customer_type': 'EXISTING',
        'is_blocklisted': true,
        'blocklist_reason': 'Repeated non-payment for deliveries',
      };

      final customer = Customer.fromJson(json);
      expect(customer.customerId, 15);
      expect(customer.name, 'Reliant Glassworks Ltd');
      expect(customer.isBlocklisted, isTrue);
      expect(customer.blocklistReason, 'Repeated non-payment for deliveries');

      final serialized = customer.toJson();
      expect(
        serialized['blocklist_reason'],
        'Repeated non-payment for deliveries',
      );
      expect(serialized['is_blocklisted'], isTrue);

      final updated = customer.copyWith(
        isBlocklisted: false,
        clearBlocklistReason: true,
      );
      expect(updated.isBlocklisted, isFalse);
      expect(updated.blocklistReason, isNull);
    });

    test('RBAC canManage getter gives access to ADMIN and MANAGER but not SALES_REP', () {
      final admin = Employee(
        employeeId: 1,
        name: 'Admin User',
        email: 'admin@suniti.com',
        role: EmployeeRole.ADMIN,
      );
      final manager = Employee(
        employeeId: 2,
        name: 'Manager User',
        email: 'manager@suniti.com',
        role: EmployeeRole.MANAGER,
      );
      final salesRep = Employee(
        employeeId: 3,
        name: 'Sales Rep User',
        email: 'rep@suniti.com',
        role: EmployeeRole.SALES_REP,
      );

      expect(admin.canManage, isTrue);
      expect(admin.isAdmin, isTrue);

      expect(manager.canManage, isTrue);
      expect(manager.isManager, isTrue);

      expect(salesRep.canManage, isFalse);
      expect(salesRep.isSalesRep, isTrue);
    });
  });

  group('Milestone 5C: CustomerProvider Blacklist & Unblacklist State Tests', () {
    test(
      'blockCustomer moves customer to blocklist with reason and updates state',
      () async {
        final customer = Customer(
          customerId: 42,
          name: 'Evergreen Enterprises',
          phone: '9988776655',
          billingAddress: 'MG Road, Pune',
          customerType: CustomerType.EXISTING,
          tier: CustomerTier.PREMIUM,
          isBlocklisted: false,
        );

        final service = MockDetailCustomerService(
          customers: [customer],
          opportunitiesByCustomer: {},
        );

        final provider = CustomerProvider(service: service);
        await provider.loadExistingCustomers();
        await provider.loadBlocklistedCustomers();

        expect(provider.allExistingCustomers.length, 1);
        expect(provider.blocklistedCustomers.length, 0);

        final success = await provider.blockCustomer(
          42,
          reason: 'Fraudulent bank slip submitted',
        );

        expect(success, isTrue);
        expect(provider.blocklistedCustomers.length, 1);
        expect(provider.blocklistedCustomers.first.customerId, 42);
        expect(
          provider.blocklistedCustomers.first.blocklistReason,
          'Fraudulent bank slip submitted',
        );
        expect(provider.blocklistedCustomers.first.isBlocklisted, isTrue);
        expect(provider.allExistingCustomers.isEmpty, isTrue);
      },
    );

    test(
      'unblockCustomer restores customer to active list and clears reason',
      () async {
        final customer = Customer(
          customerId: 42,
          name: 'Evergreen Enterprises',
          phone: '9988776655',
          billingAddress: 'MG Road, Pune',
          customerType: CustomerType.EXISTING,
          tier: CustomerTier.PREMIUM,
          isBlocklisted: true,
          blocklistReason: 'Fraudulent bank slip submitted',
        );

        final service = MockDetailCustomerService(
          customers: [customer],
          opportunitiesByCustomer: {},
        );

        final provider = CustomerProvider(service: service);
        await provider.loadBlocklistedCustomers();
        expect(provider.blocklistedCustomers.length, 1);

        await provider.unblockCustomer(42);
        expect(provider.blocklistedCustomers.isEmpty, isTrue);
        expect(provider.allExistingCustomers.length, 1);
        expect(provider.allExistingCustomers.first.isBlocklisted, isFalse);
        expect(provider.allExistingCustomers.first.blocklistReason, isNull);
      },
    );
  });

  group('Milestone 5C: CustomerDetailScreen Widget & Lead History Tests', () {
    final sampleCustomer = Customer(
      customerId: 50,
      name: 'Skyline Architects Pvt Ltd',
      phone: '9123456780',
      billingAddress: 'Connaught Place, New Delhi',
      tier: CustomerTier.PREMIUM,
      customerType: CustomerType.EXISTING,
      isBlocklisted: false,
    );

    final sampleOpp1 = Opportunity(
      opportunityId: 101,
      customerId: 50,
      employeeId: 1,
      projectTitle: 'Skyline Tower Glazing Project',
      locationName: 'Delhi Central',
      dealStatus: DealStatus.PIPELINE,
      leadTemperature: LeadTemperature.HOT,
      leadNotes: [
        LeadNote(
          noteId: 1,
          opportunityId: 101,
          employeeId: 1,
          conclusionNotes: 'Met client on site; drawings received for quote.',
          createdAt: DateTime(2026, 11, 10),
        ),
      ],
      createdAt: DateTime(2026, 11, 1),
    );

    final sampleOpp2 = Opportunity(
      opportunityId: 102,
      customerId: 50,
      employeeId: 1,
      projectTitle: 'Skyline Villa Windows',
      locationName: 'Gurugram',
      dealStatus: DealStatus.CLOSED_WON,
      leadTemperature: LeadTemperature.WARM,
      leadNotes: [
        LeadNote(
          noteId: 2,
          opportunityId: 102,
          employeeId: 1,
          conclusionNotes: 'Advance payment received; dispatched sample batch.',
          createdAt: DateTime(2026, 10, 15),
        ),
      ],
      createdAt: DateTime(2026, 10, 1),
    );

    Widget createTestWidget({
      required Customer customer,
      required List<Opportunity> opportunities,
      required Employee currentUser,
      required CustomerService mockService,
    }) {
      final customerProvider = CustomerProvider(service: mockService);
      final authProvider = MockAuthProvider(currentUser);

      return MultiProvider(
        providers: [
          ChangeNotifierProvider<CustomerProvider>.value(
            value: customerProvider,
          ),
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ],
        child: MaterialApp(
          home: CustomerDetailScreen(
            customerId: customer.customerId,
            initialCustomer: customer,
            customerService: mockService,
          ),
        ),
      );
    }

    testWidgets(
      'renders customer basic info and lead history sorted newest first',
      (tester) async {
        final admin = Employee(
          employeeId: 1,
          name: 'Admin User',
          email: 'admin@suniti.com',
          role: EmployeeRole.ADMIN,
        );

        final mockService = MockDetailCustomerService(
          customers: [sampleCustomer],
          opportunitiesByCustomer: {
            sampleCustomer.customerId: [
              sampleOpp2,
              sampleOpp1,
            ], // pass unsorted
          },
        );

        await tester.pumpWidget(
          createTestWidget(
            customer: sampleCustomer,
            opportunities: [sampleOpp2, sampleOpp1],
            currentUser: admin,
            mockService: mockService,
          ),
        );

        await tester.pumpAndSettle();

        // Verify customer details
        expect(find.text('Skyline Architects Pvt Ltd'), findsWidgets);
        expect(find.text('9123456780'), findsOneWidget);
        expect(find.text('Connaught Place, New Delhi'), findsOneWidget);
        expect(find.text('PREMIUM CUSTOMER'), findsOneWidget);

        // Verify opportunities count header
        expect(find.text('LEAD HISTORY'), findsOneWidget);
        expect(find.text('2 TOTAL LEADS'), findsOneWidget);
        expect(find.text('Skyline Tower Glazing Project'), findsOneWidget);
        expect(find.text('Skyline Villa Windows'), findsOneWidget);

        // Status badges
        expect(find.text('PIPELINE'), findsOneWidget);
        expect(find.text('WON'), findsOneWidget);

        // Temperatures
        expect(find.text('HOT'), findsOneWidget);
        expect(find.text('WARM'), findsOneWidget);

        // Notes
        expect(
          find.text('Met client on site; drawings received for quote.'),
          findsOneWidget,
        );
        expect(
          find.text('Advance payment received; dispatched sample batch.'),
          findsOneWidget,
        );

        // Check Blacklist Customer action is displayed for Admin
        expect(find.text('Blacklist Customer'), findsOneWidget);
      },
    );

    testWidgets('displays empty state when customer has no lead history', (
      tester,
    ) async {
      final admin = Employee(
        employeeId: 1,
        name: 'Admin User',
        email: 'admin@suniti.com',
        role: EmployeeRole.ADMIN,
      );

      final mockService = MockDetailCustomerService(
        customers: [sampleCustomer],
        opportunitiesByCustomer: {sampleCustomer.customerId: []},
      );

      await tester.pumpWidget(
        createTestWidget(
          customer: sampleCustomer,
          opportunities: [],
          currentUser: admin,
          mockService: mockService,
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No Lead History Found'), findsOneWidget);
      expect(
        find.text(
          'No past opportunities have been recorded for this customer.',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'displays blacklisted warning banner and reason when customer is blacklisted',
      (tester) async {
        final blacklistedCustomer = sampleCustomer.copyWith(
          isBlocklisted: true,
          blocklistReason:
              'Repeated bounced checks and refusal to settle invoices.',
        );

        final admin = Employee(
          employeeId: 1,
          name: 'Admin User',
          email: 'admin@suniti.com',
          role: EmployeeRole.ADMIN,
        );

        final mockService = MockDetailCustomerService(
          customers: [blacklistedCustomer],
          opportunitiesByCustomer: {blacklistedCustomer.customerId: []},
        );

        await tester.pumpWidget(
          createTestWidget(
            customer: blacklistedCustomer,
            opportunities: [],
            currentUser: admin,
            mockService: mockService,
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('RESTRICTED / BLACKLISTED'), findsOneWidget);
        expect(find.text('BLACKLIST REASON'), findsOneWidget);
        expect(
          find.text('Repeated bounced checks and refusal to settle invoices.'),
          findsOneWidget,
        );
        expect(find.text('Unblacklist Customer'), findsOneWidget);
      },
    );

    testWidgets('hides blacklist/unblacklist action for SALES_REP role', (
      tester,
    ) async {
      final salesRep = Employee(
        employeeId: 3,
        name: 'Rep User',
        email: 'rep@suniti.com',
        role: EmployeeRole.SALES_REP,
      );

      final mockService = MockDetailCustomerService(
        customers: [sampleCustomer],
        opportunitiesByCustomer: {sampleCustomer.customerId: []},
      );

      await tester.pumpWidget(
        createTestWidget(
          customer: sampleCustomer,
          opportunities: [],
          currentUser: salesRep,
          mockService: mockService,
        ),
      );

      await tester.pumpAndSettle();

      // Blacklist action button should not be present for SALES_REP
      expect(find.text('Blacklist Customer'), findsNothing);
    });
  });
}
