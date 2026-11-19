import 'package:flutter_test/flutter_test.dart';

import 'package:lenslinks_mobile/main.dart';

void main() {
  // The full app starts network servers and the camera, which are not
  // available in a unit test, so this only checks that the app class exists.
  test('LensLinksMobileApp can be created', () {
    expect(const LensLinksMobileApp(), isA<LensLinksMobileApp>());
  });
}
