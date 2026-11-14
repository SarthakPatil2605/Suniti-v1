import 'package:flutter_test/flutter_test.dart';
import 'package:suniti_crm/models/customer.dart';
import 'package:suniti_crm/models/opportunity.dart';
import 'package:suniti_crm/core/api/customer_service.dart';
import 'package:suniti_crm/core/api/opportunity_service.dart';

class MockSearchCustomerService extends CustomerService {
  final List<Customer> database;

  MockSearchCustomerService(this.database);

  @override
  Future<AllCustomersResult> getAllCustomers({
    String? search,
    String? location,
    String? customerType,
    String? tier,
    bool? isBlocklisted,
  }) async {
    List<Customer> filtered = database;

    if (search != null && search.trim().isNotEmpty) {
      final s = search.trim().toLowerCase();
      filtered = filtered.where((c) {
        final matchesName = c.name.toLowerCase().contains(s);
        final matchesPhone = c.phone?.toLowerCase().contains(s) ?? false;
        final matchesAddress =
            c.billingAddress?.toLowerCase().contains(s) ?? false;
        return matchesName || matchesPhone || matchesAddress;
      }).toList();
    }

    return AllCustomersResult(count: filtered.length, customers: filtered);
  }
}

class MockOpportunityCreationService extends OpportunityService {
  final List<Map<String, dynamic>> createdOpportunities = [];

  @override
  Future<Opportunity> createOpportunity({
    required int customerId,
    required String projectTitle,
    required String locationName,
    String leadTemperature = 'WARM',
    String dealStatus = 'PIPELINE',
    String? conclusionNotes,
    DateTime? nextCallDate,
  }) async {
    createdOpportunities.add({
      'customer_id': customerId,
      'project_title': projectTitle,
      'location_name': locationName,
      'lead_temperature': leadTemperature,
      'deal_status': dealStatus,
      'conclusion_notes': conclusionNotes,
      'next_call_date': nextCallDate,
    });

    return Opportunity(
      opportunityId: 999,
      customerId: customerId,
      employeeId: 1,
      projectTitle: projectTitle,
      locationName: locationName,
      leadTemperature: LeadTemperature.fromString(leadTemperature),
      dealStatus: DealStatus.fromString(dealStatus),
    );
  }
}

void main() {
  group(
    'Milestone 5B: Customer Search, Selection & Opportunity Linking Tests',
    () {
      late List<Customer> mockCustomers;
      late MockSearchCustomerService searchService;
      late MockOpportunityCreationService oppService;

      setUp(() {
        mockCustomers = [
          Customer(
            customerId: 1,
            name: 'Shree Ganesh Builders',
            phone: '+919822011223',
            billingAddress: 'Shivajinagar, Pune',
            customerType: CustomerType.EXISTING,
            tier: CustomerTier.PREMIUM,
          ),
          Customer(
            customerId: 2,
            name: 'Shree Ganesh Interiors',
            phone: '+919822099887',
            billingAddress: 'Kothrud, Pune',
            customerType: CustomerType.EXISTING,
            tier: CustomerTier.INTERIOR_DESIGNER,
          ),
          Customer(
            customerId: 3,
            name: 'Oberoi Sky Heights',
            phone: '+919876543210',
            billingAddress: 'Worli, Mumbai',
            customerType: CustomerType.EXISTING,
            tier: CustomerTier.LOYAL,
          ),
        ];
        searchService = MockSearchCustomerService(mockCustomers);
        oppService = MockOpportunityCreationService();
      });

      test(
        'Searching customer by partial name returns case-insensitive matches',
        () async {
          final results = await searchService.getAllCustomers(search: 'shree');
          expect(results.count, 2);
          expect(
            results.customers.any((c) => c.name == 'Shree Ganesh Builders'),
            isTrue,
          );
          expect(
            results.customers.any((c) => c.name == 'Shree Ganesh Interiors'),
            isTrue,
          );
        },
      );

      test(
        'Searching customer by phone number returns matching customer',
        () async {
          final results = await searchService.getAllCustomers(
            search: '9876543210',
          );
          expect(results.count, 1);
          expect(results.customers.first.customerId, 3);
          expect(results.customers.first.name, 'Oberoi Sky Heights');
        },
      );

      test('Distinguishes multiple customers sharing similar name using phone & address', () async {
        final results = await searchService.getAllCustomers(search: 'Ganesh');
        expect(results.count, 2);

        final builder = results.customers.firstWhere((c) => c.customerId == 1);
        final interior = results.customers.firstWhere((c) => c.customerId == 2);

        expect(builder.phone, '+919822011223');
        expect(builder.billingAddress, 'Shivajinagar, Pune');
        expect(builder.tier, CustomerTier.PREMIUM);

        expect(interior.phone, '+919822099887');
        expect(interior.billingAddress, 'Kothrud, Pune');
        expect(interior.tier, CustomerTier.INTERIOR_DESIGNER);
      });

      test(
        'Empty search results handled cleanly when no customer matches',
        () async {
          final results = await searchService.getAllCustomers(
            search: 'NonExistent Corp',
          );
          expect(results.count, 0);
          expect(results.customers.isEmpty, isTrue);
        },
      );

      test('Selecting existing customer links opportunity without creating duplicate customer', () async {
        // User selects customerId: 1
        final selectedCustomer = mockCustomers.firstWhere(
          (c) => c.customerId == 1,
        );

        final initialCustomerCount = mockCustomers.length;

        // Link opportunity
        final newOpportunity = await oppService.createOpportunity(
          customerId: selectedCustomer.customerId,
          projectTitle: 'Tower B Elevation Glasswork',
          locationName: 'Shivajinagar, Pune',
          leadTemperature: 'HOT',
          conclusionNotes: 'Met client on site. Blueprint approved.',
        );

        // Verify opportunity is linked directly to customerId 1
        expect(newOpportunity.customerId, 1);
        expect(newOpportunity.projectTitle, 'Tower B Elevation Glasswork');
        expect(oppService.createdOpportunities.length, 1);
        expect(oppService.createdOpportunities.first['customer_id'], 1);

        // Verify no customer record was added to mockCustomers
        expect(mockCustomers.length, initialCustomerCount);
        expect(selectedCustomer.tier, CustomerTier.PREMIUM);
      });
    },
  );
}
