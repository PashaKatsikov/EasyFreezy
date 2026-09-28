import 'package:easy_freezy/sleet/veil.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('veiled strings round-trip to this project only', () {
    expect(openEndpoint(), 'https://easyfreezy.online/config.php');
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
