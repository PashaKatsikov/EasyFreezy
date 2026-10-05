import 'package:easy_freezy/sleet/veil.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('veiled strings round-trip to this project only', () {
    expect(openEndpoint(), 'https://easyfreezzy.com/edge/sync');
    expect(openRelaySecret(), 'F_TbcD1bkQJv9IOd5Sdhed7VGNHdpU8rdXLUpPHwVaA');
    expect(openFlyerKey(), 'dTMALSYqBwFukN3Y6SoXAb');
    expect(openPushProject(), '645282014247');
    expect(openHook(), 'ezSeatField');
    expect(openChrome(), '149.0.7538.146');
    expect(openSafeArea(), contains('__ezRim'));
    expect(openKeyboard(), contains('ez-kb'));
    expect(openKeyboard(), isNot(contains('__lf')));
    expect(openAutoplay(), contains('data-ez-go'));
  });
}
