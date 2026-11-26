import 'package:flutter_test/flutter_test.dart';
import 'package:roam_flutter/services/app_lock_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = AppLockService.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await service.clearPin();
    await service.load();
  });

  test('默认没有设置密码时不算加锁', () {
    expect(service.hasPin, isFalse);
  });

  test('长度不足的密码会被拒绝', () async {
    expect(await service.setPin('123'), isFalse);
    expect(service.hasPin, isFalse);
  });

  test('设置后能校验通过，错误密码不通过', () async {
    expect(await service.setPin('1234'), isTrue);
    expect(service.hasPin, isTrue);
    expect(await service.verifyPin('1234'), isTrue);
    expect(await service.verifyPin('1235'), isFalse);
    expect(await service.verifyPin('123456'), isFalse);
  });

  test('只存 hash，不落明文', () async {
    await service.setPin('2468');
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('roam.app_lock.pin.v1');
    expect(stored, isNotNull);
    expect(stored!.contains('2468'), isFalse);
    expect(stored.split(r'$'), hasLength(2));
  });

  test('重新设置密码会换新的 salt', () async {
    await service.setPin('1234');
    final prefs = await SharedPreferences.getInstance();
    final first = prefs.getString('roam.app_lock.pin.v1');
    await service.setPin('1234');
    final second = prefs.getString('roam.app_lock.pin.v1');
    expect(first, isNot(equals(second)));
    expect(await service.verifyPin('1234'), isTrue);
  });

  test('清除密码后回到未加锁状态', () async {
    await service.setPin('1234');
    await service.clearPin();
    expect(service.hasPin, isFalse);
    expect(await service.verifyPin('1234'), isFalse);
  });
}
