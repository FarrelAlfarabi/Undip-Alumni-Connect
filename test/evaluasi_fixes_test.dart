import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/business_repository.dart';
import 'package:undip_alumni_connect/data/city_distances.dart';
import 'package:undip_alumni_connect/data/industries.dart';
import 'package:undip_alumni_connect/data/marketplace_image_picker.dart';
import 'package:undip_alumni_connect/models/business.dart';
import 'package:undip_alumni_connect/screens/business_directory_screen.dart';
import 'package:undip_alumni_connect/screens/business_form_screen.dart';
import 'package:undip_alumni_connect/screens/directory_screen.dart';
import 'package:undip_alumni_connect/screens/nearby_alumni_screen.dart';
import 'package:undip_alumni_connect/screens/profile_setup_screen.dart';
import 'package:undip_alumni_connect/widgets/business_photo.dart';

import 'support/fake_business_api.dart';

const _photoUrl =
    'https://x.supabase.co/storage/v1/object/public/business-photos/me/1_logo.png';

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(600, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('Profile edit: one employer field, picklists', () {
    Future<void> pumpSetup(
      WidgetTester tester, [
      Map<String, dynamic>? profile,
    ]) async {
      phone(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileSetupScreen(
            profile: profile ?? {'id': 'me', 'nim': '1'},
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('has Company but no Current Employer', (tester) async {
      await pumpSetup(tester);
      expect(find.text('Current Employer'), findsNothing);
      expect(find.text('Company'), findsOneWidget);
      expect(find.text('Current Role'), findsOneWidget);
    });

    testWidgets('Company shows the old employer when Company was empty', (
      tester,
    ) async {
      await pumpSetup(tester, {
        'id': 'me',
        'current_employer': 'PT Lama',
        'company': '',
      });
      expect(find.text('PT Lama'), findsOneWidget);
    });

    testWidgets('Company wins when both are filled', (tester) async {
      await pumpSetup(tester, {
        'id': 'me',
        'current_employer': 'PT Lama',
        'company': 'PT Baru',
      });
      expect(find.text('PT Baru'), findsOneWidget);
      expect(find.text('PT Lama'), findsNothing);
    });

    String fieldText(WidgetTester tester, String key) => tester
        .widget<TextField>(
          find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(TextField),
          ),
        )
        .controller!
        .text;

    testWidgets('Industry is a picker you can type to narrow', (tester) async {
      await pumpSetup(tester);
      final field = find.descendant(
        of: find.byKey(const Key('profile-industry')),
        matching: find.byType(TextField),
      );
      await tester.tap(field);
      await tester.pumpAndSettle();
      final all = find.byType(MenuItemButton).evaluate().length;
      await tester.enterText(field, 'Informa');
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton).evaluate().length, lessThan(all));
      expect(find.text('Information Technology'), findsWidgets);
    });

    testWidgets('an industry saved before the list existed is kept', (
      tester,
    ) async {
      await pumpSetup(tester, {'id': 'me', 'industry': 'Konstruksi lama'});
      expect(fieldText(tester, 'profile-industry'), 'Konstruksi lama');
    });

    testWidgets('City is a picker too', (tester) async {
      await pumpSetup(tester, {'id': 'me', 'city': 'Semarang'});
      expect(fieldText(tester, 'profile-city'), 'Semarang');
    });

    test('the industry list is tidy: no repeats, Other is last', () {
      expect(kIndustries.toSet().length, kIndustries.length);
      expect(kIndustries.last, 'Other');
    });

    test('the city picker offers only cities Nearby has distances for', () {
      expect(kNearbyCities, contains('Semarang'));
      for (final a in kNearbyCities) {
        for (final b in kNearbyCities) {
          expect(approxDistanceKm(a, b), isNotNull, reason: '$a to $b');
        }
      }
    });
  });

  group('Directory shows one employer', () {
    Future<void> pumpDirectory(
      WidgetTester tester,
      Map<String, dynamic> row,
    ) async {
      phone(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DirectoryScreen(
              currentUser: ValueNotifier({'id': 'me'}),
              fetchAlumni: () async => [
                {
                  'id': 'a1',
                  'name': 'Bunga Ayu',
                  'major': 'Manajemen',
                  'graduation_year': 2020,
                  'current_role': 'Analyst',
                  ...row,
                },
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('uses Company', (tester) async {
      await pumpDirectory(tester, {
        'company': 'PT Baru',
        'current_employer': 'PT Lama',
      });
      expect(find.textContaining('Analyst @ PT Baru'), findsOneWidget);
    });

    testWidgets('falls back to the old employer field', (tester) async {
      await pumpDirectory(tester, {
        'company': '',
        'current_employer': 'PT Lama',
      });
      expect(find.textContaining('Analyst @ PT Lama'), findsOneWidget);
    });

    testWidgets('no employer, no "@"', (tester) async {
      await pumpDirectory(tester, {});
      expect(find.textContaining('@'), findsNothing);
    });
  });

  group('Nearby: where to set the city', () {
    testWidgets('no city shows a Set your city button that opens the editor', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NearbyAlumniScreen(
              currentUser: ValueNotifier({'id': 'me', 'name': 'Me'}),
              fetchAlumni: () async => [],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('no city on file'), findsOneWidget);
      await tester.tap(find.byKey(const Key('nearby-set-city')));
      await tester.pumpAndSettle();
      expect(find.text('Edit Employment Info'), findsOneWidget);
      expect(find.byKey(const Key('profile-city')), findsOneWidget);
    });

    testWidgets('with a city there is no such button', (tester) async {
      phone(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NearbyAlumniScreen(
              currentUser: ValueNotifier({
                'id': 'me',
                'name': 'Me',
                'city': 'Semarang',
              }),
              fetchAlumni: () async => [],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('nearby-set-city')), findsNothing);
    });
  });

  group('Business photo', () {
    final png = Uint8List.fromList(const [
      0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, //
    ]);

    Future<FakeBusinessApi> pumpForm(
      WidgetTester tester, {
      Business? existing,
      ImagePickerFn? pick,
    }) async {
      phone(tester);
      final api = FakeBusinessApi()
        ..results['business_register'] = businessMap()
        ..results['business_update'] = businessMap()
        ..results['business_set_photo'] = businessMap(photoUrl: _photoUrl);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(ctx).push(
                  MaterialPageRoute(
                    builder: (_) => BusinessFormScreen(
                      ownerId: 'me',
                      repository: BusinessRepository(api),
                      existing: existing,
                      pickPhoto:
                          pick ??
                          () async => PickedImage(name: 'logo.png', bytes: png),
                    ),
                  ),
                ),
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();
      return api;
    }

    Future<void> fillAndSubmit(WidgetTester tester) async {
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Business name *'),
        'Kopi Ahmad',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Short description *'),
        'Kopi dari Semarang',
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Food & Drink').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Instagram or social link'),
        'instagram.com/kopi_ahmad',
      );
      await tester.tap(find.byKey(const Key('band-small')));
      await tester.pump();
      await tester.ensureVisible(find.text('Submit for review'));
      await tester.tap(find.text('Submit for review'));
      await tester.pumpAndSettle();
    }

    testWidgets('the form offers an optional photo', (tester) async {
      await pumpForm(tester);
      expect(find.text('Photo (optional)'), findsOneWidget);
      expect(find.text('Add photo'), findsOneWidget);
      expect(find.byKey(const Key('business-photo-remove')), findsNothing);
    });

    testWidgets('no photo: registers without touching storage', (tester) async {
      final api = await pumpForm(tester);
      await fillAndSubmit(tester);
      expect(api.calls, ['business_register']);
      expect(api.uploads, isEmpty);
    });

    testWidgets('a chosen photo is uploaded and attached after saving', (
      tester,
    ) async {
      final api = await pumpForm(tester);
      await tester.tap(find.byKey(const Key('business-photo-pick')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('business-photo-preview')), findsOneWidget);
      expect(find.text('Change photo'), findsOneWidget);
      await fillAndSubmit(tester);
      expect(api.calls, ['business_register', 'business_set_photo']);
      expect(api.uploads.single, startsWith('me/'));
      expect(api.uploads.single, endsWith('_logo.png'));
      expect(api.params['business_set_photo']!['p_business'], 'b1');
      expect(
        api.params['business_set_photo']!['p_photo_url'],
        contains('/business-photos/me/'),
      );
      expect(find.text(kBusinessSubmittedMessage), findsOneWidget);
    });

    testWidgets('a failed upload still saves the business and says so', (
      tester,
    ) async {
      final api = await pumpForm(tester);
      await tester.tap(find.byKey(const Key('business-photo-pick')));
      await tester.pumpAndSettle();
      api.throwOnUpload = Exception('storage down');
      await fillAndSubmit(tester);
      expect(api.calls, ['business_register']);
      expect(
        find.text('$kBusinessSubmittedMessage$kBusinessPhotoFailedMessage'),
        findsOneWidget,
      );
    });

    testWidgets('a wrong file type shows the reason and adds nothing', (
      tester,
    ) async {
      final api = await pumpForm(
        tester,
        pick: () async =>
            throw const ImagePickException('Use a JPG, PNG or WebP image.'),
      );
      await tester.tap(find.byKey(const Key('business-photo-pick')));
      await tester.pumpAndSettle();
      expect(find.text('Use a JPG, PNG or WebP image.'), findsOneWidget);
      expect(find.byKey(const Key('business-photo-preview')), findsNothing);
      expect(api.calls, isEmpty);
    });

    testWidgets('editing: Remove clears the saved photo', (tester) async {
      final existing = Business.fromMap(
        businessMap(photoUrl: _photoUrl, status: 'rejected', reason: 'blur'),
      );
      final api = await pumpForm(tester, existing: existing);
      expect(find.text('Change photo'), findsOneWidget);
      await tester.tap(find.byKey(const Key('business-photo-remove')));
      await tester.pumpAndSettle();
      expect(find.text('Add photo'), findsOneWidget);
      await tester.ensureVisible(find.text('Save and send again'));
      await tester.tap(find.text('Save and send again'));
      await tester.pumpAndSettle();
      expect(api.calls, ['business_update', 'business_set_photo']);
      expect(api.params['business_set_photo']!['p_photo_url'], isNull);
    });

    testWidgets('editing without touching the photo leaves it alone', (
      tester,
    ) async {
      final existing = Business.fromMap(
        businessMap(photoUrl: _photoUrl, status: 'rejected', reason: 'blur'),
      );
      final api = await pumpForm(tester, existing: existing);
      await tester.ensureVisible(find.text('Save and send again'));
      await tester.tap(find.text('Save and send again'));
      await tester.pumpAndSettle();
      expect(api.calls, ['business_update']);
    });

    test('directory rows get their photo from the second call', () async {
      final api = FakeBusinessApi()
        ..results['business_directory'] = [
          businessMap(id: '1', status: 'approved', ownerName: 'A'),
          businessMap(id: '2', status: 'approved', ownerName: 'B'),
        ]
        ..results['business_photo_urls'] = [
          {'business_id': '2', 'photo_url': _photoUrl},
        ];
      final list = await BusinessRepository(api).directory('me');
      expect(list.firstWhere((b) => b.id == '1').photoUrl, isNull);
      expect(list.firstWhere((b) => b.id == '2').photoUrl, _photoUrl);
    });

    test('a failing photo call never breaks the list', () async {
      final api = _PhotoFailsApi()
        ..results['business_directory'] = [
          businessMap(id: '1', status: 'approved', ownerName: 'A'),
        ];
      final list = await BusinessRepository(api).directory('me');
      expect(list.single.name, 'Kopi Ahmad');
      expect(list.single.photoUrl, isNull);
    });

    testWidgets('BusinessPhoto draws nothing without a photo', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: BusinessPhoto(url: null))),
      );
      expect(find.byType(Image), findsNothing);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: BusinessPhoto(url: _photoUrl)),
        ),
      );
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('a directory card shows the photo when the business has one', (
      tester,
    ) async {
      phone(tester);
      final api = FakeBusinessApi()
        ..results['business_directory'] = [
          businessMap(id: '1', status: 'approved', ownerName: 'A'),
          businessMap(
            id: '2',
            name: 'Batik Siti',
            status: 'approved',
            ownerName: 'S',
            social: null,
            website: 'https://batiksiti.example.com',
          ),
        ]
        ..results['business_photo_urls'] = [
          {'business_id': '2', 'photo_url': _photoUrl},
        ];
      await tester.pumpWidget(
        MaterialApp(
          home: BusinessDirectoryScreen(
            currentUser: ValueNotifier({'id': 'me'}),
            repository: BusinessRepository(api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BusinessPhoto), findsNWidgets(2));
      expect(find.byType(Image), findsOneWidget);
    });
  });
}

class _PhotoFailsApi extends FakeBusinessApi {
  @override
  Future<dynamic> rpc(String function, Map<String, dynamic> p) {
    if (function == 'business_photo_urls') {
      throw pgError('function does not exist');
    }
    return super.rpc(function, p);
  }
}
