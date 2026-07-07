import 'package:booster_club/config/app_config.dart';
import 'package:booster_club/models/content_models.dart';
import 'package:booster_club/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => AppConfig.demoMode = true);

  group('SchoolEvent geolocation & optional time', () {
    test('serializes latitude/longitude and allDay through a round-trip', () {
      const event = SchoolEvent(
        id: 'e-test',
        title: 'Homecoming',
        description: 'Big game',
        location: 'Memorial Stadium',
        latitude: 39.0349,
        longitude: -77.1136,
        allDay: true,
      );
      final restored = SchoolEvent.fromDoc('e-test', event.toMap());
      expect(restored.latitude, 39.0349);
      expect(restored.longitude, -77.1136);
      expect(restored.hasGeo, isTrue);
      expect(restored.allDay, isTrue);
    });

    test('defaults: no geo, timed (not all-day)', () {
      final restored = SchoolEvent.fromDoc('e2', {
        'title': 'Meeting',
        'description': 'Monthly',
        'startsAt': Timestamp.fromDate(DateTime(2026, 7, 6, 18, 0)),
      });
      expect(restored.hasGeo, isFalse);
      expect(restored.allDay, isFalse);
      expect(restored.startsAt, isNotNull);
    });
  });

  group('Gallery collection', () {
    test('demo data seeds gallery images', () async {
      final fs = FirestoreService();
      final images = await fs.gallery().first;
      expect(images, isNotEmpty);
      expect(images.every((g) => g.imageUrl.isNotEmpty), isTrue);
    });

    test('a gallery image can be added and removed', () async {
      final fs = FirestoreService();
      await fs.upsert(
        'gallery',
        const GalleryImage(
          id: 'g-new',
          title: 'Team Photo',
          imageUrl: 'https://example.com/gallery/team.jpg',
          caption: 'Fall roster',
          tags: ['athletics'],
        ),
      );
      var images = await fs.gallery().first;
      expect(images.any((g) => g.id == 'g-new'), isTrue);

      await fs.delete('gallery', 'g-new');
      images = await fs.gallery().first;
      expect(images.any((g) => g.id == 'g-new'), isFalse);
    });
  });
}
