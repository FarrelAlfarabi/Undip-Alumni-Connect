import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/screens/marketplace_screen.dart';
import 'package:undip_alumni_connect/widgets/app_photo.dart';
import 'package:undip_alumni_connect/widgets/avatar.dart';

const _url = 'https://example.supabase.co/storage/v1/object/public/x.png';

Future<void> _pump(WidgetTester t, Widget child) => t.pumpWidget(
  MaterialApp(
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  testWidgets('Avatar uses the on-device image cache', (t) async {
    await _pump(t, const Avatar(url: _url, name: 'Siti Azizah'));
    expect(find.byType(CachedNetworkImage), findsOneWidget);
  });

  testWidgets('Avatar without URL still shows initials', (t) async {
    await _pump(t, const Avatar(url: null, name: 'Siti Azizah'));
    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.text('SA'), findsOneWidget);
  });

  testWidgets('AppPhoto uses the on-device image cache', (t) async {
    await _pump(t, const SizedBox(width: 300, child: AppPhoto(url: _url)));
    expect(find.byType(CachedNetworkImage), findsOneWidget);
  });

  testWidgets('ListingImage uses the on-device image cache', (t) async {
    await _pump(t, const ListingImage(url: _url, size: 80));
    expect(find.byType(CachedNetworkImage), findsOneWidget);
  });

  testWidgets('ListingImage without URL shows placeholder', (t) async {
    await _pump(t, const ListingImage(url: '', size: 80));
    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
  });
}
