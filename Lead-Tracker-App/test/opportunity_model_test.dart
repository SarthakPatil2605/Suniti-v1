import 'package:flutter_test/flutter_test.dart';
import 'package:suniti_crm/models/opportunity.dart';

void main() {
  group('Opportunity Model & DealStatus.OTHER Tests', () {
    test('DealStatus enum parses OTHER and round-trips correctly', () {
      expect(DealStatus.fromString('OTHER'), equals(DealStatus.OTHER));
      expect(DealStatus.fromString('other'), equals(DealStatus.OTHER));
      expect(
        DealStatus.fromString('CLOSED_WON'),
        equals(DealStatus.CLOSED_WON),
      );
      expect(
        DealStatus.fromString('CLOSED_LOST'),
        equals(DealStatus.CLOSED_LOST),
      );
      expect(DealStatus.fromString('PIPELINE'), equals(DealStatus.PIPELINE));
      expect(DealStatus.fromString(null), equals(DealStatus.PIPELINE));
      expect(DealStatus.OTHER.toJson(), equals('OTHER'));
    });

    test('Opportunity fromJson and toJson handle OTHER and closure_reason', () {
      final json = {
        'opportunity_id': 42,
        'customer_id': 10,
        'employee_id': 2,
        'project_title': 'Residential Villa',
        'location_name': 'Baner, Pune',
        'lead_temperature': 'WARM',
        'deal_status': 'OTHER',
        'project_phase': 'DEAL_CLOSED',
        'closure_reason': 'Client relocated out of state',
        'is_completed': true,
      };

      final opp = Opportunity.fromJson(json);

      expect(opp.opportunityId, equals(42));
      expect(opp.dealStatus, equals(DealStatus.OTHER));
      expect(opp.isOther, isTrue);
      expect(opp.isClosed, isTrue);
      expect(opp.isPipeline, isFalse);
      expect(opp.closureReason, equals('Client relocated out of state'));

      final serialized = opp.toJson();
      expect(serialized['deal_status'], equals('OTHER'));
      expect(
        serialized['closure_reason'],
        equals('Client relocated out of state'),
      );
    });

    test(
      'Opportunity copyWith correctly updates closureReason and dealStatus',
      () {
        const opp = Opportunity(
          opportunityId: 1,
          customerId: 10,
          employeeId: 2,
          projectTitle: 'Office Fitout',
        );

        final updated = opp.copyWith(
          dealStatus: DealStatus.OTHER,
          closureReason: 'Budget constraints',
          isCompleted: true,
        );

        expect(updated.dealStatus, equals(DealStatus.OTHER));
        expect(updated.closureReason, equals('Budget constraints'));
        expect(updated.isCompleted, isTrue);
        expect(updated.isOther, isTrue);
        expect(updated.isClosed, isTrue);
      },
    );
  });
}
