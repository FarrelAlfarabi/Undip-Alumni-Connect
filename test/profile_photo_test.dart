import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/avatar_repository.dart';
import 'package:undip_alumni_connect/data/contact_repository.dart';
import 'package:undip_alumni_connect/data/marketplace_image_picker.dart';
import 'package:undip_alumni_connect/screens/first_login_profile_screen.dart';
import 'package:undip_alumni_connect/screens/profile_detail_screen.dart';
import 'package:undip_alumni_connect/screens/profile_photo_screen.dart';
import 'package:undip_alumni_connect/widgets/avatar.dart';
import 'package:undip_alumni_connect/widgets/image_size_hint.dart';

import 'support/fake_contact_api.dart';

const kUrl =
    'https://x.supabase.co/storage/v1/object/public/avatars/me/1_me.png';

class FakeAvatarApi implements AvatarApi {
  final calls = <String>[];
  final params = <String, Object?>{};
  Object? error;
  dynamic listResult = <Map<String, dynamic>>[];

  @override
  Future<dynamic> rpc(String function, Map<String, dynamic> p) async {
    calls.add(function);
    params.addAll(p);
    if (error != null) throw error!;
    return p['p_url'];
  }

  @override
  Future<String> upload(
    String path,
    Uint8List bytes,
    String contentType,
  ) async {
    calls.add('upload:$path:$contentType');
    if (error != null) throw error!;
    return 'https://x.supabase.co/storage/v1/object/public/avatars/$path';
  }

  @override
  Future<dynamic> listUrls({String? id}) async {
    calls.add('list');
    if (error != null) throw error!;
    return listResult;
  }
}

Future<PickedImage?> pickFake() async =>
    PickedImage(name: 'foto saya.png', bytes: Uint8List.fromList([1, 2, 3]));

void main() {
  group('Avatar', () {
    testWidgets('shows the image when there is a URL', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Avatar(url: kUrl, name: 'Siti Azizah'),
        ),
      );
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('shows initials without a URL', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Avatar(url: null, name: 'Siti Azizah')),
      );
      expect(find.byType(Image), findsNothing);
      expect(find.text('SA'), findsOneWidget);
    });

    testWidgets('an empty URL counts as none', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Avatar(url: '', name: 'Siti Azizah'),
        ),
      );
      expect(find.byType(Image), findsNothing);
    });
  });

  testWidgets('ImageSizeHint profile text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ImageSizeHint(ImageSizeKind.profile)),
    );
    expect(find.textContaining('persegi 1:1 (800 x 800 px)'), findsOneWidget);
    expect(find.textContaining('maksimal 2 MB'), findsOneWidget);
  });

  group('AvatarRepository', () {
    test('setAvatar calls profile_set_avatar', () async {
      final api = FakeAvatarApi();
      final r = AvatarRepository(api);
      final url = await r.setAvatar('me', kUrl);
      expect(url, kUrl);
      expect(api.calls, ['profile_set_avatar']);
      expect(api.params['p_profile'], 'me');
    });

    test('upload cleans the file name and prefixes the profile id', () async {
      final api = FakeAvatarApi();
      await AvatarRepository(
        api,
      ).upload(profileId: 'me', fileName: 'foto saya.png', bytes: Uint8List(1));
      expect(
        api.calls.single,
        matches(r'^upload:me/\d+_foto_saya\.png:image/png$'),
      );
    });

    test('urlsById gives nothing when the column is missing', () async {
      final api = FakeAvatarApi()..error = Exception('column does not exist');
      expect(await AvatarRepository(api).urlsById(), isEmpty);
    });

    test('withAvatars merges links into rows by id', () {
      final rows = AvatarRepository.withAvatars(
        [
          {'id': 'a', 'name': 'A'},
          {'id': 'b', 'name': 'B'},
        ],
        {'a': kUrl},
      );
      expect(rows[0]['avatar_url'], kUrl);
      expect(rows[1].containsKey('avatar_url'), isFalse);
    });

    test('errors become a plain message', () async {
      final api = FakeAvatarApi()..error = Exception('not_verified');
      expect(
        () => AvatarRepository(api).setAvatar('me', kUrl),
        throwsA(isA<AvatarException>()),
      );
    });
  });

  group('ProfilePhotoScreen', () {
    Future<FakeAvatarApi> pump(
      WidgetTester tester, {
      String? current,
      double scale = 1,
      Object? error,
    }) async {
      final api = FakeAvatarApi()..error = error;
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          builder: (c, w) => MediaQuery(
            data: MediaQuery.of(c)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: w!,
          ),
          home: ProfilePhotoScreen(
            profileId: 'me',
            name: 'Ahmad Ramadhan',
            currentUrl: current,
            repository: AvatarRepository(api),
            pickPhoto: pickFake,
          ),
        ),
      );
      return api;
    }

    testWidgets('shows the size hint and no overflow at text scale 1.3', (
      tester,
    ) async {
      await pump(tester, scale: 1.3);
      expect(find.byType(ImageSizeHint), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Simpan is disabled until a photo is chosen', (tester) async {
      await pump(tester);
      final save = tester.widget<FilledButton>(
        find.byKey(const Key('photo-save')),
      );
      expect(save.onPressed, isNull);
    });

    testWidgets('choose then save uploads and sets the link', (tester) async {
      final api = await pump(tester);
      await tester.tap(find.byKey(const Key('photo-choose')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('photo-save')));
      await tester.pumpAndSettle();
      expect(api.calls.first, startsWith('upload:me/'));
      expect(api.calls.last, 'profile_set_avatar');
    });

    testWidgets('Hapus foto clears the link', (tester) async {
      final api = await pump(tester, current: kUrl);
      await tester.tap(find.byKey(const Key('photo-remove')));
      await tester.pumpAndSettle();
      expect(api.calls, ['profile_set_avatar']);
      expect(api.params['p_url'], isNull);
    });

    testWidgets('Hapus foto is hidden when there is no photo', (tester) async {
      await pump(tester);
      expect(find.byKey(const Key('photo-remove')), findsNothing);
    });

    testWidgets('a failed save shows a message and stays', (tester) async {
      await pump(tester, error: Exception('boom'));
      await tester.tap(find.byKey(const Key('photo-choose')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('photo-save')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('photo-error')), findsOneWidget);
      expect(find.byType(ProfilePhotoScreen), findsOneWidget);
    });

    testWidgets('a rejected file shows its message', (tester) async {
      final api = FakeAvatarApi();
      await tester.pumpWidget(
        MaterialApp(
          home: ProfilePhotoScreen(
            profileId: 'me',
            name: 'A',
            repository: AvatarRepository(api),
            pickPhoto: () async => throw const ImagePickException(
              'The image must be 2 MB or smaller.',
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('photo-choose')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('photo-error')), findsOneWidget);
    });
  });

  group('Profile card', () {
    Future<void> pumpProfile(
      WidgetTester tester,
      Map<String, dynamic> profile, {
      required bool own,
    }) async {
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileDetailScreen(
            profile: profile,
            currentUser: ValueNotifier({'id': 'me', 'name': 'Ahmad'}),
            showEditButton: own,
            chat: false,
            contactRepository: ContactRepository(FakeContactApi()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('own profile has the camera badge', (tester) async {
      await pumpProfile(tester, {'id': 'me', 'name': 'Ahmad'}, own: true);
      expect(find.byKey(const Key('avatar-edit')), findsOneWidget);
      expect(find.byType(Avatar), findsOneWidget);
    });

    testWidgets('another profile has no camera badge', (tester) async {
      await pumpProfile(tester, {'id': 'u2', 'name': 'Siti'}, own: false);
      expect(find.byKey(const Key('avatar-edit')), findsNothing);
      expect(find.byType(Avatar), findsOneWidget);
    });

    testWidgets('shows the photo when avatar_url is set', (tester) async {
      await pumpProfile(tester, {
        'id': 'u2',
        'name': 'Siti',
        'avatar_url': kUrl,
      }, own: false);
      expect(find.byType(Image), findsOneWidget);
    });
  });

  group('first login photo row', () {
    testWidgets('shows the row with the hint and opens the photo screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(420, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: FirstLoginProfileScreen(
            profile: const {'id': 'me', 'name': 'Ahmad'},
            onDone: (_, _) {},
            avatarRepository: AvatarRepository(FakeAvatarApi()),
          ),
        ),
      );
      expect(find.byKey(const Key('first-login-photo')), findsOneWidget);
      expect(find.byType(ImageSizeHint), findsOneWidget);
      await tester.tap(find.byKey(const Key('first-login-photo')));
      await tester.pumpAndSettle();
      expect(find.byType(ProfilePhotoScreen), findsOneWidget);
    });
  });
}
