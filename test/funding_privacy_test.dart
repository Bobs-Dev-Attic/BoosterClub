import 'package:flutter_test/flutter_test.dart';
import 'package:booster_club/models/content_models.dart';

void main() {
  test('FundingRequest summary doc carries no contact PII', () {
    const r = FundingRequest(
      id: 'r',
      title: 'Robotics Club',
      description: 'New parts',
      amountRequested: 500,
      requestedBy: 'Coach Lee',
      studentCount: 12,
    );
    final map = r.toMap();
    // Summary keeps only non-sensitive fields...
    expect(map.containsKey('title'), isTrue);
    expect(map.containsKey('studentCount'), isTrue);
    // ...and never the private contact fields.
    for (final k in [
      'coachEmail',
      'parentName',
      'parentEmail',
      'previousRequests',
      'boosterMembersInfo',
    ]) {
      expect(map.containsKey(k), isFalse, reason: '$k must not be in summary');
    }
  });

  test('FundingApplicationDetail round-trips and reports emptiness', () {
    const empty = FundingApplicationDetail();
    expect(empty.isEmpty, isTrue);
    final d = FundingApplicationDetail.fromMap({
      'coachEmail': 'c@x.org',
      'parentName': 'Pat',
      'parentEmail': 'p@x.org',
    });
    expect(d.isEmpty, isFalse);
    expect(d.toMap()['coachEmail'], 'c@x.org');
    expect(d.toMap()['parentName'], 'Pat');
  });
}
