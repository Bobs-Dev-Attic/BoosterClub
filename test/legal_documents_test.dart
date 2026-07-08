import 'package:booster_club/config/app_config.dart';
import 'package:booster_club/models/app_user.dart';
import 'package:booster_club/models/content_models.dart';
import 'package:booster_club/services/firestore_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => AppConfig.demoMode = true);

  group('Policy Admin role', () {
    test('has manage_legal and nothing else', () {
      const user = AppUser(
        uid: 'p1',
        email: 'policy@example.com',
        displayName: 'Pat Policy',
        role: UserRole.policyAdmin,
      );
      expect(user.can('manage_legal'), isTrue);
      expect(user.can('manage_events'), isFalse);
      expect(user.can('manage_users'), isFalse);
      expect(user.canManageAny, isTrue);
    });

    test('administrators and web admins can also manage legal', () {
      expect(rolePermissions(UserRole.administrator).contains('manage_legal'),
          isTrue);
      expect(
          rolePermissions(UserRole.webAdmin).contains('manage_legal'), isTrue);
      // A plain member cannot.
      expect(rolePermissions(UserRole.member).contains('manage_legal'), isFalse);
    });
  });

  group('Legal documents', () {
    test('demo data seeds Terms and Privacy', () async {
      final fs = FirestoreService();
      final docs = await fs.legalDocuments().first;
      final ids = docs.map((d) => d.id).toSet();
      expect(ids.contains('terms'), isTrue);
      expect(ids.contains('privacy'), isTrue);
      expect(docs.every((d) => d.body.isNotEmpty), isTrue);
    });

    test('a legal document can be edited and re-read', () async {
      final fs = FirestoreService();
      await fs.upsert(
        'legal_documents',
        const LegalDocument(
          id: 'terms',
          title: 'Terms of Use',
          body: '# Terms of Use\n\nUpdated body.',
        ),
      );
      final docs = await fs.legalDocuments().first;
      final terms = docs.firstWhere((d) => d.id == 'terms');
      expect(terms.body, contains('Updated body.'));
    });
  });
}
