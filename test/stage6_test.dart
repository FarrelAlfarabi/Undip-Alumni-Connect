import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/business_repository.dart';
import 'package:undip_alumni_connect/data/category_repository.dart';
import 'package:undip_alumni_connect/data/marketplace_repository.dart';
import 'package:undip_alumni_connect/screens/business_form_screen.dart';
import 'package:undip_alumni_connect/screens/feature_intro_screen.dart';
import 'package:undip_alumni_connect/screens/marketplace_form_screen.dart';
import 'package:undip_alumni_connect/screens/post_job_screen.dart';
import 'package:undip_alumni_connect/widgets/app_photo.dart';
import 'package:undip_alumni_connect/widgets/business_photo.dart';
import 'package:undip_alumni_connect/widgets/image_size_hint.dart';

import 'support/fake_business_api.dart';
import 'support/fake_marketplace_api.dart';

class _FakeCategoryApi implements CategoryApi {
  _FakeCategoryApi(this.rows, {this.fail = false});
  final List<Map<String, dynamic>> rows;
  final bool fail;
  int calls = 0;

  @override
  Future<List<Map<String, dynamic>>> fetch() async {
    calls++;
    if (fail) throw Exception('offline');
    return rows;
  }
}

void main() {
  group('CategoryRepository', () {
    test('starts with the built-in five so the list is never empty', () {
      final repo = CategoryRepository(_FakeCategoryApi(const []));
      expect(repo.names.value, kBuiltInCategories);
      expect(kBuiltInCategories.length, 5);
    });

    test('keeps the built-in list when the call fails', () async {
      final repo = CategoryRepository(_FakeCategoryApi(const [], fail: true));
      final list = await repo.load();
      expect(list, kBuiltInCategories);
    });

    test('loads active categories, ordered by sort_order then name', () async {
      final api = _FakeCategoryApi([
        {'name': 'Zebra', 'sort_order': 20, 'active': true},
        {'name': 'Beauty', 'sort_order': 20, 'active': true},
        {'name': 'Fashion', 'sort_order': 10, 'active': true},
        {'name': 'Old', 'sort_order': 1, 'active': false},
      ]);
      final repo = CategoryRepository(api);
      expect(await repo.load(), ['Fashion', 'Beauty', 'Zebra']);
      expect(repo.names.value, ['Fashion', 'Beauty', 'Zebra']);
    });

    test('loads once per session', () async {
      final api = _FakeCategoryApi([
        {'name': 'Fashion', 'sort_order': 10, 'active': true},
      ]);
      final repo = CategoryRepository(api);
      await repo.load();
      await repo.load();
      expect(api.calls, 1);
    });

    test('an empty answer falls back to the built-in list', () async {
      final repo = CategoryRepository(_FakeCategoryApi(const []));
      expect(await repo.load(), kBuiltInCategories);
    });

    test(
      'validation accepts a loaded category and rejects an unknown one',
      () async {
        final repo = CategoryRepository(
          _FakeCategoryApi([
            {'name': 'Beauty', 'sort_order': 5, 'active': true},
          ]),
        );
        await repo.load();
        expect(repo.validate('Beauty'), isNull);
        expect(repo.validate('Nonsense'), isNotNull);
        expect(repo.validate(null), isNotNull);
        // The category the item already has stays valid when it was made
        // inactive later.
        expect(repo.validate('Nonsense', current: 'Nonsense'), isNull);
      },
    );
  });

  group('Category fields', () {
    tearDown(() => CategoryRepository.shared.names.value = kBuiltInCategories);

    testWidgets('the product form can pick a category outside the old five', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(600, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      CategoryRepository.shared.names.value = [...kBuiltInCategories, 'Beauty'];
      await tester.pumpWidget(
        MaterialApp(
          home: MarketplaceFormScreen(
            sellerId: 's1',
            businessId: 'biz1',
            repository: MarketplaceRepository(FakeApi()),
            defaultCity: 'Jakarta',
            pickImage: () async => null,
          ),
        ),
      );
      // Type to narrow the list, then pick (the list scrolls past five).
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('category-choice')),
          matching: find.byType(TextField),
        ),
        'Beau',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beauty').last);
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('category-choice')),
          matching: find.byType(TextField),
        ),
      );
      expect(field.controller!.text, 'Beauty');
    });
  });

  group('AppPhoto', () {
    testWidgets('draws a 3:2 box', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: SizedBox(
              width: 300,
              child: AppPhoto(
                url: 'https://x.test/a.png',
                semanticLabel: 'Kopi',
              ),
            ),
          ),
        ),
      );
      final size = tester.getSize(find.byType(AppPhoto));
      expect(size.width / size.height, closeTo(1.5, 0.01));
    });

    testWidgets('BusinessPhoto uses the same 3:2 box', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: SizedBox(
              width: 300,
              child: BusinessPhoto(url: 'https://x.test/a.png'),
            ),
          ),
        ),
      );
      expect(find.byType(AppPhoto), findsOneWidget);
      final size = tester.getSize(find.byType(AppPhoto));
      expect(size.width / size.height, closeTo(1.5, 0.01));
    });

    testWidgets('a photo gets a semantic label, not an excluded one', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 300,
            child: AppPhoto(url: 'https://x.test/a.png', semanticLabel: 'Kopi'),
          ),
        ),
      );
      final img = tester.widget<Image>(find.byType(Image));
      expect(img.semanticLabel, 'Kopi');
      expect(img.excludeFromSemantics, isFalse);
    });
  });

  group('ImageSizeHint', () {
    testWidgets('landscape text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ImageSizeHint())),
      );
      expect(
        find.text('Foto terbaik: landscape 3:2 (1200 x 800 px).'),
        findsOneWidget,
      );
      expect(find.text('JPG, PNG atau WebP, maksimal 2 MB.'), findsOneWidget);
    });

    testWidgets('the product form shows it', (tester) async {
      tester.view.physicalSize = const Size(600, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: MarketplaceFormScreen(
            sellerId: 's1',
            businessId: 'biz1',
            repository: MarketplaceRepository(FakeApi()),
            defaultCity: 'Jakarta',
            pickImage: () async => null,
          ),
        ),
      );
      expect(find.byType(ImageSizeHint), findsOneWidget);
    });

    testWidgets('the business form shows it', (tester) async {
      tester.view.physicalSize = const Size(600, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: BusinessFormScreen(
            ownerId: 'me',
            repository: BusinessRepository(FakeBusinessApi()),
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.byType(ImageSizeHint),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byType(ImageSizeHint), findsOneWidget);
    });

    testWidgets('the job form shows it', (tester) async {
      tester.view.physicalSize = const Size(600, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: PostJobScreen(posterId: 'p1', pickPhoto: () async => null),
        ),
      );
      await tester.scrollUntilVisible(
        find.byType(ImageSizeHint),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byType(ImageSizeHint), findsOneWidget);
    });

    testWidgets('Save stays reachable at text scale 1.3 on 360 x 640', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: MarketplaceFormScreen(
            sellerId: 's1',
            businessId: 'biz1',
            repository: MarketplaceRepository(FakeApi()),
            defaultCity: 'Jakarta',
            pickImage: () async => null,
          ),
        ),
      );
      final save = find.byType(FilledButton).last;
      await tester.scrollUntilVisible(
        save,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(save, findsOneWidget);
    });
  });

  group('Feature intro, 3 pages', () {
    testWidgets('Cari alumni, Marketplace dan Business, Jobs, then Mulai', (
      tester,
    ) async {
      var done = 0;
      await tester.pumpWidget(
        MaterialApp(home: FeatureIntroScreen(onDone: (_) async => done++)),
      );
      expect(find.text('Cari alumni'), findsOneWidget);
      expect(find.text('Lanjut'), findsOneWidget);

      await tester.tap(find.byKey(const Key('intro-next')));
      await tester.pumpAndSettle();
      expect(find.text('Marketplace dan Business'), findsOneWidget);
      expect(find.textContaining('tab Explore'), findsOneWidget);

      await tester.tap(find.byKey(const Key('intro-next')));
      await tester.pumpAndSettle();
      expect(find.text('Jobs'), findsOneWidget);
      expect(
        find.textContaining('Buka tab Explore, pilih Jobs.'),
        findsOneWidget,
      );
      expect(find.text('Mulai'), findsOneWidget);

      await tester.tap(find.byKey(const Key('intro-next')));
      await tester.pumpAndSettle();
      expect(done, 1);
    });

    testWidgets('Skip still finishes', (tester) async {
      var done = 0;
      await tester.pumpWidget(
        MaterialApp(home: FeatureIntroScreen(onDone: (_) async => done++)),
      );
      await tester.tap(find.byKey(const Key('intro-skip')));
      await tester.pumpAndSettle();
      expect(done, 1);
    });
  });
}
