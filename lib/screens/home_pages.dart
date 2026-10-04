import 'package:flutter/material.dart';

import '../data/business_repository.dart';
import '../data/marketplace_repository.dart';
import '../models/marketplace_listing.dart';
import 'alumni_screen.dart';
import 'announcement_detail_screen.dart';
import 'announcements_screen.dart';
import 'business_directory_screen.dart';
import 'job_board_screen.dart';
import 'job_detail_screen.dart';
import 'marketplace_detail_screen.dart';
import 'business_form_screen.dart';
import 'market_screen.dart';
import 'my_businesses_screen.dart';
import 'marketplace_screen.dart';
import 'messages_list_screen.dart';
import 'notifications_screen.dart';
import 'profile_detail_screen.dart';
import 'requests_screen.dart';

typedef UserPageBuilder = Widget Function(
  ValueNotifier<Map<String, dynamic>> currentUser,
);

/// Every page the Home hub and the bottom navigation can open, as builders.
/// The defaults are the real screens; tests pass fakes because the real
/// ones talk to Supabase as soon as they are built.
class HomePages {
  const HomePages({
    this.profile = _profile,
    this.directory = _directory,
    this.chat = _chat,
    this.jobs = _jobs,
    this.marketplace = _marketplace,
    this.market = _market,
    this.myBusinesses = _myBusinesses,
    this.registerBusiness = _registerBusiness,
    this.businesses = _businesses,
    this.requests = _requests,
    this.notifications = _notifications,
    this.nearby = _nearby,
    this.announcements = _announcements,
    this.jobDetail = _jobDetail,
    this.listingDetail = _listingDetail,
    this.announcementDetail = _announcementDetail,
  });

  final Widget Function(
    Map<String, dynamic> profile,
    ValueNotifier<Map<String, dynamic>> currentUser,
  )
  profile;
  final UserPageBuilder directory;
  final UserPageBuilder chat;
  final UserPageBuilder jobs;
  final UserPageBuilder marketplace;

  /// The Market tab (Products and Businesses). The notifier is the selected
  /// segment: 0 Products, 1 Businesses.
  final Widget Function(
    ValueNotifier<Map<String, dynamic>> currentUser,
    ValueNotifier<int> segment,
  )
  market;
  final UserPageBuilder businesses;
  final UserPageBuilder myBusinesses;
  final UserPageBuilder registerBusiness;
  final UserPageBuilder requests;
  final UserPageBuilder notifications;
  final UserPageBuilder nearby;
  final Widget Function() announcements;
  final Widget Function(
    Map<String, dynamic> job,
    ValueNotifier<Map<String, dynamic>> currentUser,
  )
  jobDetail;
  final Widget Function(
    MarketplaceListing listing,
    MarketplaceRepository repository,
    ValueNotifier<Map<String, dynamic>> currentUser,
  )
  listingDetail;
  final Widget Function(Map<String, dynamic> announcement) announcementDetail;

  static Widget _profile(
    Map<String, dynamic> profile,
    ValueNotifier<Map<String, dynamic>> user,
  ) => ProfileDetailScreen(profile: profile, currentUser: user);

  // Bottom-nav tab roots (no back arrow).
  static Widget _directory(ValueNotifier<Map<String, dynamic>> user) =>
      AlumniScreen(currentUser: user);
  static Widget _chat(ValueNotifier<Map<String, dynamic>> user) =>
      MessagesListScreen(currentUser: user);

  // Pushed from Home (back arrow on).
  static Widget _jobs(ValueNotifier<Map<String, dynamic>> user) =>
      JobBoardScreen(currentUser: user, showBack: true);
  static Widget _myBusinesses(ValueNotifier<Map<String, dynamic>> user) =>
      MyBusinessesScreen(ownerId: user.value['id'] as String);
  static Widget _registerBusiness(ValueNotifier<Map<String, dynamic>> user) =>
      BusinessFormScreen(
        ownerId: user.value['id'] as String,
        repository: BusinessRepository(),
      );
  static Widget _market(
    ValueNotifier<Map<String, dynamic>> user,
    ValueNotifier<int> segment,
  ) => MarketScreen(currentUser: user, segment: segment);
  static Widget _marketplace(ValueNotifier<Map<String, dynamic>> user) =>
      MarketplaceScreen(currentUser: user, showBack: true);
  static Widget _businesses(ValueNotifier<Map<String, dynamic>> user) =>
      BusinessDirectoryScreen(currentUser: user);
  static Widget _notifications(ValueNotifier<Map<String, dynamic>> user) =>
      NotificationsScreen(currentUser: user);
  static Widget _requests(ValueNotifier<Map<String, dynamic>> user) =>
      RequestsScreen(currentUser: user);
  static Widget _nearby(ValueNotifier<Map<String, dynamic>> user) =>
      AlumniScreen(currentUser: user, initialTab: 1, showBack: true);
  static Widget _announcements() => const AnnouncementsScreen(showBack: true);

  static Widget _jobDetail(
    Map<String, dynamic> job,
    ValueNotifier<Map<String, dynamic>> user,
  ) => JobDetailScreen(job: job, currentUser: user);
  static Widget _listingDetail(
    MarketplaceListing listing,
    MarketplaceRepository repository,
    ValueNotifier<Map<String, dynamic>> user,
  ) => MarketplaceDetailScreen(
    listing: listing,
    repository: repository,
    currentUser: user,
  );
  static Widget _announcementDetail(Map<String, dynamic> a) =>
      AnnouncementDetailScreen(announcement: a);
}
