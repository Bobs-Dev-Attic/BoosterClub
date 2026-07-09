import 'package:flutter_test/flutter_test.dart';
import 'package:booster_club/models/content_models.dart';

void main() {
  test('public defaults to true when the field is absent (legacy docs)', () {
    final g = GalleryImage.fromDoc('a', {'title': 'x', 'imageUrl': 'u'});
    expect(g.public, isTrue);
  });

  test('public is read and round-trips through toMap', () {
    final hidden =
        GalleryImage.fromDoc('b', {'title': 'x', 'imageUrl': 'u', 'public': false});
    expect(hidden.public, isFalse);
    expect(hidden.toMap()['public'], isFalse);
    expect(hidden.copyWith(public: true).public, isTrue);
  });

  test('public filter selects only visible images', () {
    final imgs = [
      const GalleryImage(id: '1', title: 'a', imageUrl: 'u', public: true),
      const GalleryImage(id: '2', title: 'b', imageUrl: 'u', public: false),
    ];
    expect(imgs.where((i) => i.public).map((i) => i.id).toList(), ['1']);
  });
}
