import 'package:flutter/material.dart';
import 'package:undip_alumni_connect/data/home_repository.dart';
import 'package:undip_alumni_connect/screens/home_pages.dart';

Map<String, dynamic> announcementMap(int n) => {
  'id': 'an$n',
  'title': 'Announcement $n',
  'body': 'Body text $n',
  'posted_by': 'Ikafe',
  'created_at': '2026-09-${10 + n}T08:00:00+00:00',
};

Map<String, dynamic> jobMap(int n) => {
  'id': 'j$n',
  'title': 'Job $n',
  'company': 'Company $n',
  'industry': 'Finance',
  'description': 'Desc',
  'poster': {'name': 'Poster'},
  'created_at': '2026-09-${10 + n}T08:00:00+00:00',
};

class FakeHomeApi implements HomeApi {
  FakeHomeApi({
    this.announcements = const [],
    this.jobs = const [],
    this.announcementsError,
    this.jobsError,
  });

  List<Map<String, dynamic>> announcements;
  List<Map<String, dynamic>> jobs;
  Object? announcementsError;
  Object? jobsError;
  int announcementCalls = 0;
  int jobCalls = 0;

  @override
  Future<List<Map<String, dynamic>>> latestAnnouncements(int limit) async {
    announcementCalls++;
    if (announcementsError != null) throw announcementsError!;
    return announcements.take(limit).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> latestJobs(int limit) async {
    jobCalls++;
    if (jobsError != null) throw jobsError!;
    return jobs.take(limit).toList();
  }
}

/// A stand-in page that shows [label] so tests can tell where they landed.
class MarkerPage extends StatelessWidget {
  const MarkerPage(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(label)),
    body: Text('PAGE $label'),
  );
}

/// Counts how many times it was created (initState), to prove tab refetch.
class CountingPage extends StatefulWidget {
  const CountingPage(this.label, this.counter, {super.key});
  final String label;
  final List<int> counter;

  @override
  State<CountingPage> createState() => _CountingPageState();
}

class _CountingPageState extends State<CountingPage> {
  @override
  void initState() {
    super.initState();
    widget.counter.add(1);
  }

  @override
  Widget build(BuildContext context) => Text('TAB ${widget.label}');
}

/// Fake pages. [users] collects the notifier every page received.
HomePages fakePages({
  List<ValueNotifier<Map<String, dynamic>>>? users,
  List<int>? chatBuilds,
}) {
  void note(ValueNotifier<Map<String, dynamic>> u) => users?.add(u);
  return HomePages(
    profile: (p, u) {
      note(u);
      return const MarkerPage('Profile');
    },
    directory: (u) {
      note(u);
      return const MarkerPage('Directory');
    },
    chat: (u) {
      note(u);
      return chatBuilds == null
          ? const MarkerPage('Chat')
          : CountingPage('Chat', chatBuilds);
    },
    jobs: (u) {
      note(u);
      return const MarkerPage('Jobs');
    },
    marketplace: (u) {
      note(u);
      return const MarkerPage('Marketplace');
    },
    nearby: (u) {
      note(u);
      return const MarkerPage('Nearby');
    },
    announcements: () => const MarkerPage('Announcements'),
    jobDetail: (job, u) => MarkerPage('JobDetail ${job['id']}'),
    listingDetail: (l, r, u) => MarkerPage('ListingDetail ${l.id}'),
    announcementDetail: (a) => MarkerPage('AnnouncementDetail ${a['id']}'),
  );
}
