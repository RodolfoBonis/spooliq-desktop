import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spooliq_desktop/core/update/update_checker.dart';
import 'package:spooliq_desktop/core/update/update_cubit.dart';

class _Dio extends Mock implements Dio {}

class _Checker extends Mock implements UpdateChecker {}

const _feed = 'https://api.github.com/repos/o/r/releases/latest';

Map<String, dynamic> _release(String tag) => {
  'tag_name': tag,
  'html_url': 'https://github.com/o/r/releases/tag/$tag',
  'assets': [
    {'name': 'SpoolIQ-x.dmg', 'browser_download_url': 'https://d/mac.dmg'},
    {'name': 'SpoolIQ-Setup-x.exe', 'browser_download_url': 'https://d/w.exe'},
  ],
};

void main() {
  group('compareVersions', () {
    test('compares numerically and ignores build metadata', () {
      expect(compareVersions('0.10.0', '0.9.9'), greaterThan(0));
      expect(compareVersions('0.1.1', '0.1.1+2'), 0);
      expect(compareVersions('1.0', '1.0.1'), lessThan(0));
    });
  });

  group('UpdateChecker', () {
    late _Dio dio;

    setUp(() {
      dio = _Dio();
      registerFallbackValue(Options());
    });

    void respond(String tag) =>
        when(
          () => dio.get<Map<String, dynamic>>(
            _feed,
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: _feed),
            data: _release(tag),
          ),
        );

    test('picks the installer for the platform', () async {
      respond('v0.2.0');
      final mac = await UpdateChecker(
        feedUrl: _feed,
        dio: dio,
        platform: 'macos',
      ).check('0.1.1');
      final win = await UpdateChecker(
        feedUrl: _feed,
        dio: dio,
        platform: 'windows',
      ).check('0.1.1');
      expect(mac?.version, '0.2.0');
      expect(mac?.downloadUrl, 'https://d/mac.dmg');
      expect(win?.downloadUrl, 'https://d/w.exe');
    });

    test('returns null when already up to date', () async {
      respond('v0.1.1');
      final update = await UpdateChecker(
        feedUrl: _feed,
        dio: dio,
        platform: 'macos',
      ).check('0.1.1');
      expect(update, isNull);
    });
  });

  group('UpdateCubit', () {
    late _Checker checker;
    late SharedPreferences prefs;
    const update = AvailableUpdate(
      version: '0.2.0',
      releaseUrl: 'https://github.com/o/r/releases/tag/v0.2.0',
    );

    setUp(() async {
      checker = _Checker();
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    blocTest<UpdateCubit, AvailableUpdate?>(
      'skipping a version hides it on the next checks',
      setUp: () =>
          when(() => checker.check(any())).thenAnswer((_) async => update),
      build: () => UpdateCubit(
        checker,
        prefs,
        currentVersion: () async => '0.1.1',
      ),
      act: (c) async {
        await c.check();
        await c.skip();
        await c.check();
      },
      expect: () => [update, null],
    );

    blocTest<UpdateCubit, AvailableUpdate?>(
      'network failures keep the current state',
      setUp: () => when(
        () => checker.check(any()),
      ).thenThrow(DioException(requestOptions: RequestOptions())),
      build: () => UpdateCubit(
        checker,
        prefs,
        currentVersion: () async => '0.1.1',
      ),
      act: (c) => c.check(),
      expect: () => <AvailableUpdate?>[],
    );
  });
}
