import 'package:flutter_test/flutter_test.dart';
import 'package:suniti_crm/models/customer.dart';
import 'package:suniti_crm/providers/customer_provider.dart';
import 'package:suniti_crm/core/api/customer_service.dart';

class MockCustomerService extends CustomerService {
  final List<Customer> mockNewCustomers;
  final List<Customer> mockFilteredCustomers;

  MockCustomerService({
    this.mockNewCustomers = const [],
    this.mockFilteredCustomers = const [],
  });

  @override
  Future<List<Customer>> getNewCustomers() async {
    return mockNewCustomers;
  }

  @override
  Future<AllCustomersResult> getAllCustomers({
    String? search,
    String? location,
    String? customerType,
    String? tier,
    bool? isBlocklisted,
  }) async {
    return AllCustomersResult(
      count: mockFilteredCustomers.length,
      customers: mockFilteredCustomers,
    );
  }
}

void main() {
  group('CustomerProvider Milestone 5A Tests', () {
    test('loadNewCustomers updates state correctly', () async {
      final sampleNewCustomer = Customer(
        customerId: 101,
        name: 'Nexus Construction New Ltd',
        customerType: CustomerType.NEW,
        createdAt: DateTime.now(),
      );

      final service = MockCustomerService(
        mockNewCustomers: [sampleNewCustomer],
      );
      final provider = CustomerProvider(service: service);

      expect(provider.newCustomers.isEmpty, isTrue);
      expect(provider.newCustomersCount, 0);

      await provider.loadNewCustomers();

      expect(provider.newCustomers.length, 1);
      expect(provider.newCustomersCount, 1);
      expect(provider.newCustomers.first.name, 'Nexus Construction New Ltd');
      expect(provider.newCustomers.first.customerType, CustomerType.NEW);
    });

    test('loadFilteredCustomers queries and sets filtered state', () async {
      final sampleCustomer = Customer(
        customerId: 202,
        name: 'Apex Interiors Mumbai',
        customerType: CustomerType.EXISTING,
        tier: CustomerTier.INTERIOR_DESIGNER,
        billingAddress: 'Bandra, Mumbai',
      );

      final service = MockCustomerService(
        mockFilteredCustomers: [sampleCustomer],
      );
      final provider = CustomerProvider(service: service);

      await provider.loadFilteredCustomers(
        search: 'Apex',
        location: 'Mumbai',
        customerType: 'EXISTING',
      );

      expect(provider.filteredCustomers.length, 1);
      expect(provider.filteredCustomers.first.name, 'Apex Interiors Mumbai');
      expect(
        provider.filteredCustomers.first.tier,
        CustomerTier.INTERIOR_DESIGNER,
      );

      provider.clearFilteredCustomers();
      expect(provider.filteredCustomers.isEmpty, isTrue);
    });
  });
}
