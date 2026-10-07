import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/config/policy_config.dart';
import 'package:undip_alumni_connect/data/admin_repository.dart';
import 'package:undip_alumni_connect/data/business_repository.dart';
import 'package:undip_alumni_connect/data/cities.dart';
import 'package:undip_alumni_connect/data/contact_repository.dart';
import 'package:undip_alumni_connect/data/marketplace_repository.dart';
import 'package:undip_alumni_connect/models/business.dart';
import 'package:undip_alumni_connect/screens/admin_screen.dart';
import 'package:undip_alumni_connect/screens/business_form_screen.dart';
import 'package:undip_alumni_connect/screens/contact_admin_screen.dart';
import 'package:undip_alumni_connect/screens/default_contact_screen.dart';
import 'package:undip_alumni_connect/screens/profile_detail_screen.dart';
import 'package:undip_alumni_connect/screens/my_businesses_screen.dart';
import 'package:undip_alumni_connect/screens/my_job_postings_screen.dart';
import 'package:undip_alumni_connect/screens/requests_screen.dart';

import 'support/fake_admin_api.dart';
import 'support/fake_business_api.dart';
import 'support/fake_contact_api.dart';
import 'support/fake_marketplace_api.dart';

void tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(600, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('personal business', () {
    test('register sends the personal flag', () async {
      final api = FakeBusinessApi()
        ..results['business_register'] = businessMap(personal: true);
      final saved = await BusinessRepository(api).register(
        'me',
        const BusinessInput(
          name: 'Kopi',
          description: 'x',
          category: 'Other',
          socialLink: 'https://instagram.com/kopi',
          band: BusinessBand.micro,
          isPersonal: true,
        ),
      );
      expect(api.params['business_register']!['p_personal'], true);
      expect(saved.isPersonal, isTrue);
    });

    testWidgets('the form has a Personal business switch', (tester) async {
      tall(tester);
      final api = FakeBusinessApi()
        ..results['business_register'] = businessMap();
      await tester.pumpWidget(
        MaterialApp(
          home: BusinessFormScreen(
            ownerId: 'me',
            repository: BusinessRepository(api),
          ),
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Business name *'),
        'Kopi Solo',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Short description *'),
        'Kopi',
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Other').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Instagram or social link'),
        'https://instagram.com/kopisolo',
      );
      await tester.tap(find.byKey(const Key('personal-business')));
      await tester.tap(find.byKey(const Key('band-micro')));
      await tester.pump();
      await tester.tap(find.text('Submit for review'));
      await tester.pumpAndSettle();
      expect(api.params['business_register']!['p_personal'], true);
    });
  });

  group('business limit', () {
    test('the database error turns into a sentence with the email', () {
      final msg = businessErrorMessage(
        const BusinessException(BusinessErrorCode.businessLimit, 'x'),
      );
      expect(msg, contains('$kMaxBusinesses'));
      expect(msg, contains(kContactEmail));
    });

    testWidgets('My businesses shows the limit note and blocks a 4th', (
      tester,
    ) async {
      tall(tester);
      final api = FakeBusinessApi()
        ..results['business_my'] = [
          for (var i = 0; i < 3; i++) businessMap(id: 'b$i', name: 'Biz $i'),
        ]
        ..results['business_my_usage'] = [];
      await tester.pumpWidget(
        MaterialApp(
          home: MyBusinessesScreen(
            ownerId: 'me',
            repository: BusinessRepository(api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('business-limit-note')), findsOneWidget);
      expect(find.textContaining(kContactEmail), findsWidgets);
      await tester.tap(find.text('Register a business'));
      await tester.pumpAndSettle();
      // Still on the list: the form did not open.
      expect(find.text('Submit for review'), findsNothing);
    });

    testWidgets('a rejected business does not count towards the limit', (
      tester,
    ) async {
      tall(tester);
      final api = FakeBusinessApi()
        ..results['business_my'] = [
          businessMap(id: 'a'),
          businessMap(id: 'b'),
          businessMap(id: 'c', status: 'rejected', reason: 'x'),
        ]
        ..results['business_my_usage'] = [];
      await tester.pumpWidget(
        MaterialApp(
          home: MyBusinessesScreen(
            ownerId: 'me',
            repository: BusinessRepository(api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Register a business'));
      await tester.pumpAndSettle();
      expect(find.text('Submit for review'), findsOneWidget);
    });
  });

  test('cities: list is sorted, and an old city is kept', () {
    final sorted = [...kMarketplaceCities]..sort();
    expect(kMarketplaceCities, sorted);
    expect(citiesWith('Semarang'), kMarketplaceCities);
    expect(citiesWith('Kudus'), contains('Kudus'));
    expect(citiesWith(null), kMarketplaceCities);
  });

  testWidgets('accepting a request prefills my email as the contact', (
    tester,
  ) async {
    tall(tester);
    final api = FakeContactApi()
      ..results['contact_requests_incoming'] = [incomingMap()]
      ..results['contact_requests_outgoing'] = [];
    await tester.pumpWidget(
      MaterialApp(
        home: RequestsScreen(
          currentUser: ValueNotifier({
            'id': 'me',
            'email': 'ahmad@example.com',
          }),
          repository: ContactRepository(api),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('accept-r1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accept and share'));
    await tester.pumpAndSettle();
    expect(
      api.params['contact_request_respond']!['p_shared'],
      'ahmad@example.com',
    );
  });

  testWidgets('Contact admin lists the support email', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ContactAdminScreen()));
    expect(find.text(kContactEmail), findsOneWidget);
    expect(find.byKey(const Key('support-email')), findsOneWidget);
  });

  testWidgets('Admin: Reports row shows the unseen count', (tester) async {
    tall(tester);
    final api = FakeAdminApi()
      ..results['admin_reports_unseen_count'] = 3
      ..results['admin_feedback_new_count'] = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AdminScreen(
          adminId: 'me',
          adminRepository: AdminRepository(api),
          marketplaceRepository: MarketplaceRepository(FakeApi()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('reports-badge')),
        matching: find.text('3'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('My job postings lists my jobs with applicant counts', (
    tester,
  ) async {
    tall(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: MyJobPostingsScreen(
          currentUser: ValueNotifier({'id': 'me'}),
          fetch: (id) async => [
            {
              'id': 'j1',
              'title': 'Analyst',
              'company': 'Bank X',
              'applicant_count': 2,
            },
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Analyst'), findsOneWidget);
    expect(find.text('Bank X · 2 applicants'), findsOneWidget);
  });

  group('default contact', () {
    test('repository reads and saves it', () async {
      final api = FakeContactApi()
        ..results['contact_default_get'] = ' WA 0812 ';
      final repo = ContactRepository(api);
      expect(await repo.defaultContact('me'), 'WA 0812');
      await repo.setDefaultContact('me', '  IG @ahmad ');
      expect(api.params['contact_default_set'], {
        'p_profile': 'me',
        'p_contact': 'IG @ahmad',
      });
      api.results['contact_default_get'] = null;
      expect(await repo.defaultContact('me'), isNull);
    });

    testWidgets('the screen shows the saved value and saves any text', (
      tester,
    ) async {
      tall(tester);
      final api = FakeContactApi()
        ..results['contact_default_get'] = 't.me/ahmad';
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultContactScreen(
            profileId: 'me',
            repository: ContactRepository(api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('t.me/ahmad'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('default-contact-field')),
        'Signal +62 811, ahmad@work.id',
      );
      await tester.tap(find.byKey(const Key('default-contact-save')));
      await tester.pumpAndSettle();
      expect(
        api.params['contact_default_set']!['p_contact'],
        'Signal +62 811, ahmad@work.id',
      );
    });

    testWidgets('accepting pre-fills the saved default, not the email', (
      tester,
    ) async {
      tall(tester);
      final api = FakeContactApi()
        ..results['contact_requests_incoming'] = [incomingMap()]
        ..results['contact_requests_outgoing'] = []
        ..results['contact_default_get'] = 'WA 0812-1111';
      await tester.pumpWidget(
        MaterialApp(
          home: RequestsScreen(
            currentUser: ValueNotifier({'id': 'me', 'email': 'a@example.com'}),
            repository: ContactRepository(api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('accept-r1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Accept and share'));
      await tester.pumpAndSettle();
      expect(
        api.params['contact_request_respond']!['p_shared'],
        'WA 0812-1111',
      );
    });
  });

  testWidgets('Profile: Admin row shows the unseen reports number', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileDetailScreen(
          profile: {'id': 'me', 'name': 'Ahmad'},
          currentUser: ValueNotifier({'id': 'me'}),
          adminCheck: (_) async => true,
          unseenReportsCheck: (_) async => 4,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('4 new reports'), findsOneWidget);
  });
}
