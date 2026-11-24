import 'package:explorehub/widgets/common.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('commons FilePath gets a standard width for the drawn size', () {
    const u = 'https://commons.wikimedia.org/wiki/Special:FilePath/Stadtbild_M%C3%BCnchen.jpg?width=1200';
    expect(sizedImageUrl(u, 300), contains('width=330'));
    expect(sizedImageUrl(u, 700), contains('width=960'));
    expect(sizedImageUrl(u, 4000), contains('width=1280'));
    expect(sizedImageUrl(u, 300), contains('Stadtbild_M%C3%BCnchen.jpg'));
  });

  test('wikimedia thumbs shrink but never grow', () {
    const u = 'https://thumb.wikimedia.org/wikipedia/commons/thumb/a/ae/Raja.jpg/1280px-Raja.jpg';
    expect(sizedImageUrl(u, 400), endsWith('/500px-Raja.jpg'));
    expect(sizedImageUrl(u, 2000), u);
  });

  test('other hosts are untouched', () {
    const u = 'https://example.supabase.co/storage/v1/object/public/a.jpg';
    expect(sizedImageUrl(u, 300), u);
  });
}
