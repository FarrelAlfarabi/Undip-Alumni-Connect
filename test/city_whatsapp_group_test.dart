import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/city_group_repository.dart';
import 'package:undip_alumni_connect/screens/nearby_alumni_screen.dart';

const _link = 'https://chat.whatsapp.com/AbCdEfGhIjKl';

class FakeCityApi implements CityGroupApi {
  FakeCityApi({Map<String, String>? links, this.saveError})
    : links = links ?? {};
  final Map<String, String> links;
  final Object? saveError;
  final calls = <String>[];

  @override
  Future<dynamic> rpc(String function, Map<String, dynamic> params) async {
    calls.add(function);
    if (function == 'city_whatsapp_groups_list') {
      return [
        for (final e in links.entries) {'city': e.key, 'invite_url': e.value},
      ];
    }
    if (saveError != null) throw saveError!;
    links[params['p_city'] as String] = params['p_url'] as String;
    return null;
  }
}

final me = {'id': 'me', 'name': 'Me', 'city': 'Semarang'};
final alumni = [
  me,
  {'id': 'j1', 'name': 'Bunga Ayu', 'city': 'Jakarta', 'current_role': 'A'},
  {'id': 'j2', 'name': 'Candra Dewi', 'city': 'Jakarta', 'current_role': 'B'},
  {'id': 'b1', 'name': 'Dimas Putra', 'city': 'Bandung', 'current_role': 'C'},
];

Future<List<Uri>> pump(
  WidgetTester tester, {
  required FakeCityApi api,
  bool chat = false,
}) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final opened = <Uri>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: NearbyAlumniScreen(
          currentUser: ValueNotifier(me),
          chat: chat,
          fetchAlumni: () async => alumni,
          groups: CityGroupRepository(api),
          openUrl: (uri) async {
            opened.add(uri);
            return true;
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return opened;
}

Future<void> pickCity(WidgetTester tester, String city) async {
  final chip = find.byKey(Key('nearby-city-$city'));
  await tester.ensureVisible(chip);
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

void main() {
  group('isWhatsAppInviteUrl', () {
    test('accepts a WhatsApp invite link', () {
      expect(isWhatsAppInviteUrl(_link), isTrue);
      expect(isWhatsAppInviteUrl('  $_link '), isTrue);
    });
    test('rejects everything else', () {
      expect(isWhatsAppInviteUrl(''), isFalse);
      expect(
        isWhatsAppInviteUrl('http://chat.whatsapp.com/AbCdEfGhIjKl'),
        isFalse,
      );
      expect(
        isWhatsAppInviteUrl('https://evil.example.com/AbCdEfGhIjKl'),
        isFalse,
      );
      expect(isWhatsAppInviteUrl('https://chat.whatsapp.com/short'), isFalse);
      expect(
        isWhatsAppInviteUrl('https://chat.whatsapp.com/AbCdEfGhIjKl/x'),
        isFalse,
      );
    });
  });

  group('CityGroupRepository', () {
    test('list returns city to link', () async {
      final repo = CityGroupRepository(FakeCityApi(links: {'Jakarta': _link}));
      expect(await repo.list('me'), {'Jakarta': _link});
    });

    test('save maps database errors to codes', () async {
      Future<CityGroupErrorCode> codeFor(Object error) async {
        try {
          await CityGroupRepository(FakeCityApi(saveError: error))
              .save('me', 'Jakarta', _link);
        } on CityGroupException catch (e) {
          return e.code;
        }
        fail('expected CityGroupException');
      }

      expect(
        await codeFor(Exception('invalid_input')),
        CityGroupErrorCode.invalidInput,
      );
      expect(
        await codeFor(Exception('not_verified')),
        CityGroupErrorCode.notVerified,
      );
      expect(await codeFor(Exception('boom')), CityGroupErrorCode.unknown);
    });
  });

  group('Nearby list', () {
    testWidgets('has no map and no List/Map switch', (tester) async {
      await pump(tester, api: FakeCityApi());
      expect(find.text('Map'), findsNothing);
      expect(find.byType(SegmentedButton<bool>), findsNothing);
      expect(find.text('Bunga Ayu'), findsOneWidget);
      expect(find.text('Dimas Putra'), findsOneWidget);
    });

    testWidgets('city chips filter the list', (tester) async {
      await pump(tester, api: FakeCityApi());
      await pickCity(tester, 'Jakarta');
      expect(find.text('Bunga Ayu'), findsOneWidget);
      expect(find.text('Candra Dewi'), findsOneWidget);
      expect(find.text('Dimas Putra'), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('nearby-city-all')));
      await tester.tap(find.byKey(const Key('nearby-city-all')));
      await tester.pumpAndSettle();
      expect(find.text('Dimas Putra'), findsOneWidget);
    });

    testWidgets('no group card until a city is picked', (tester) async {
      await pump(tester, api: FakeCityApi(links: {'Jakarta': _link}));
      expect(find.byKey(const Key('nearby-wa-join')), findsNothing);
      expect(find.byKey(const Key('nearby-wa-add')), findsNothing);
    });

    testWidgets('city with a link: Gabung opens the link', (tester) async {
      final opened = await pump(
        tester,
        api: FakeCityApi(links: {'Jakarta': _link}),
      );
      await pickCity(tester, 'Jakarta');
      await tester.tap(find.byKey(const Key('nearby-wa-join')));
      await tester.pumpAndSettle();
      expect(opened, [Uri.parse(_link)]);
    });

    testWidgets('city without a link: anyone can add one', (tester) async {
      final api = FakeCityApi();
      await pump(tester, api: api);
      await pickCity(tester, 'Bandung');
      expect(find.byKey(const Key('nearby-wa-join')), findsNothing);
      await tester.tap(find.byKey(const Key('nearby-wa-add')));
      await tester.pumpAndSettle();

      // A link that is not a WhatsApp invite is refused before any call.
      await tester.enterText(
        find.byKey(const Key('nearby-wa-field')),
        'https://evil.example.com/x',
      );
      await tester.tap(find.byKey(const Key('nearby-wa-save')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Link tidak valid'), findsOneWidget);
      expect(api.calls.where((c) => c == 'city_whatsapp_group_set'), isEmpty);

      await tester.enterText(find.byKey(const Key('nearby-wa-field')), _link);
      await tester.tap(find.byKey(const Key('nearby-wa-save')));
      await tester.pumpAndSettle();
      expect(api.links['Bandung'], _link);
      expect(find.byKey(const Key('nearby-wa-join')), findsOneWidget);
    });

    testWidgets('a failed save shows a plain message and keeps the dialog', (
      tester,
    ) async {
      await pump(tester, api: FakeCityApi(saveError: Exception('boom')));
      await pickCity(tester, 'Bandung');
      await tester.tap(find.byKey(const Key('nearby-wa-add')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('nearby-wa-field')), _link);
      await tester.tap(find.byKey(const Key('nearby-wa-save')));
      await tester.pumpAndSettle();
      expect(find.textContaining('belum bisa disimpan'), findsOneWidget);
      expect(find.byKey(const Key('nearby-wa-field')), findsOneWidget);
    });

    testWidgets('group chat button follows the chat switch', (tester) async {
      await pump(tester, api: FakeCityApi(), chat: false);
      await pickCity(tester, 'Jakarta');
      expect(find.textContaining('Group Chat'), findsNothing);
    });

    testWidgets('group chat button shows when chat is on', (tester) async {
      await pump(tester, api: FakeCityApi(), chat: true);
      await pickCity(tester, 'Jakarta');
      expect(find.text('Open Jakarta Group Chat'), findsOneWidget);
    });
  });
}
