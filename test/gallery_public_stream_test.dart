import 'package:flutter_test/flutter_test.dart';
import 'package:booster_club/config/app_config.dart';
import 'package:booster_club/services/firestore_service.dart';

void main() {
  test('galleryPublic() excludes hidden images (demo)', () async {
    AppConfig.demoMode = true;
    final fs = FirestoreService();
    final all = await fs.gallery().first;
    final pub = await fs.galleryPublic().first;
    expect(all.any((g) => !g.public), isTrue,
        reason: 'demo data should include a hidden image');
    expect(pub.every((g) => g.public), isTrue);
    expect(pub.length, lessThan(all.length));
  });
}
