import 'package:booster_club/config/app_config.dart';
import 'package:booster_club/models/donation.dart';
import 'package:booster_club/services/firestore_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => AppConfig.demoMode = true);

  test('a donation is recorded pending, then confirmed, in the ledger',
      () async {
    final fs = FirestoreService();

    final id = await fs.createPendingDonation(const Donation(
      id: 'new',
      donorName: 'Test Donor',
      donorEmail: 'test@example.com',
      amount: 75,
      designation: 'Athletics',
    ));
    expect(id, isNotEmpty);

    // It shows up in the ledger as pending.
    var ledger = await fs.donations().first;
    var mine = ledger.firstWhere((d) => d.id == id);
    expect(mine.status, DonationStatus.pending);
    expect(mine.amount, 75);

    // The backend (simulated) confirms it via PayPal.
    await fs.simulateDonationCompleted(id);

    ledger = await fs.donations().first;
    mine = ledger.firstWhere((d) => d.id == id);
    expect(mine.status, DonationStatus.completed);
    expect(mine.paypalCaptureId, isNotNull);
    expect(mine.completedAt, isNotNull);
  });

  test('donationDoc emits the completed status for a watched donation',
      () async {
    final fs = FirestoreService();
    final id = await fs.createPendingDonation(const Donation(
      id: 'new',
      donorName: 'Watcher',
      donorEmail: 'watch@example.com',
      amount: 40,
      designation: 'Greatest Need',
    ));

    final completed = fs.donationDoc(id).firstWhere(
        (d) => d != null && d.status == DonationStatus.completed);
    await fs.simulateDonationCompleted(id);

    final d = await completed;
    expect(d!.status, DonationStatus.completed);
  });
}
