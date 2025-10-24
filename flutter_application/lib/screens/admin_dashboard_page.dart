import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_application/styles/global_styles.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/theme.dart';
import '../styles/admindashboard_styles.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final DatabaseReference _dbRef =
      FirebaseDatabase.instance.ref().child('volunteer_requests');

  List<Map<String, dynamic>> events = [];
  List<Map<String, dynamic>> filteredEvents = [];
  bool isLoading = true;
  String searchQuery = '';

  int totalVolunteers = 0;
  int approvedVolunteers = 0;
  int pendingVolunteers = 0;

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  void _fetchEvents() {
    _dbRef.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      if (data != null) {
        final fetched = data.entries.map((entry) {
          final val = Map<String, dynamic>.from(entry.value);
          val['id'] = entry.key;
          return val;
        }).toList();

        _calculateVolunteerStats(fetched);

        setState(() {
          events = fetched;
          filteredEvents = fetched;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    });
  }

  void _calculateVolunteerStats(List<Map<String, dynamic>> fetchedEvents) {
    int total = 0;
    int approved = 0;
    int pending = 0;

    for (var event in fetchedEvents) {
      final applicants = event['applicants'] as Map<dynamic, dynamic>?;
      if (applicants != null) {
        total += applicants.length;
        for (var applicant in applicants.values) {
          final status = (applicant['status'] ?? '').toString().toLowerCase();
          if (status == 'approved') {
            approved++;
          } else {
            pending++;
          }
        }
      }
    }

    setState(() {
      totalVolunteers = total;
      approvedVolunteers = approved;
      pendingVolunteers = pending;
    });
  }

  void _filterEvents(String query) {
    setState(() {
      searchQuery = query;
      filteredEvents = events
          .where((event) =>
              (event['eventName'] ?? '')
                  .toLowerCase()
                  .contains(query.toLowerCase()) ||
              (event['description'] ?? '')
                  .toLowerCase()
                  .contains(query.toLowerCase()))
          .toList();
    });
  }

  void _viewApplicants(String eventId, Map<String, dynamic> eventData) async {
    final applicantsRef =
        FirebaseDatabase.instance.ref('volunteer_requests/$eventId/applicants');
    final snapshot = await applicantsRef.get();

    final applicants = (snapshot.value as Map<dynamic, dynamic>?)
            ?.entries
            .map((e) => MapEntry(e.key, Map<String, dynamic>.from(e.value)))
            .toList() ??
        [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AdminDashboardStyles.borderRadiusLarge))),
      builder: (_) => Padding(
        padding: const EdgeInsets.only(
            top: AdminDashboardStyles.spacingMedium,
            left: AdminDashboardStyles.spacingMedium,
            right: AdminDashboardStyles.spacingMedium,
            bottom: AdminDashboardStyles.spacingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Applicants for "${eventData['eventName']}"',
              style: AdminDashboardStyles.header,
            ),
            const SizedBox(height: AdminDashboardStyles.spacingSmall),
            if (applicants.isEmpty)
              Text('No applicants yet.', style: AdminDashboardStyles.subtitle),
            ...applicants.map((entry) {
              final uid = entry.key;
              final applicant = entry.value;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: AdminDashboardStyles.spacingXSmall),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AdminDashboardStyles.borderRadiusMedium)),
                child: ListTile(
                  title: Text(applicant['email'] ?? 'No email', style: AdminDashboardStyles.output),
                  subtitle: Text(
                      'Status: ${applicant['status'] ?? 'Pending'}',
                      style: AdminDashboardStyles.subtitle),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check_circle, color: Colors.green),
                        tooltip: 'Approve',
                        onPressed: () =>
                            _updateStatus(eventId, uid, 'approved'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.redAccent),
                        tooltip: 'Reject',
                        onPressed: () =>
                            _updateStatus(eventId, uid, 'rejected'),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatus(
      String eventId, String uid, String newStatus) async {
    await FirebaseDatabase.instance
        .ref('volunteer_requests/$eventId/applicants/$uid/status')
        .set(newStatus);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Applicant status updated to "$newStatus"'),
      backgroundColor:
          newStatus == 'approved' ? Colors.green : Colors.redAccent,
    ));
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AdminDashboardStyles.spacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Admin Dashboard', style: GlobalStyles.header),
          const SizedBox(height: AdminDashboardStyles.spacingXSmall),
          Text(
            '${events.length} Event(s) | $totalVolunteers Volunteer(s)',
            style: AdminDashboardStyles.subtitle,
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCards() {
    return Padding(
      padding: const EdgeInsets.all(AdminDashboardStyles.spacingSmall),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatCard('Events', events.length, Icons.event, ThemeConstants.accent),
          _buildStatCard('Volunteers', totalVolunteers, Icons.people, ThemeConstants.accentBlue),
          _buildStatCard('Approved', approvedVolunteers, Icons.check, Colors.green),
          _buildStatCard('Pending', pendingVolunteers, Icons.hourglass_empty, Colors.orange),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, int value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AdminDashboardStyles.spacingXSmall),
        padding: const EdgeInsets.all(AdminDashboardStyles.spacingSmall),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AdminDashboardStyles.borderRadiusMedium),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: AdminDashboardStyles.spacingXSmall),
            Text(
              value.toString(),
              style: AdminDashboardStyles.output.copyWith(
                  color: color, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              title,
              style: AdminDashboardStyles.subtitle,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomRight,
            colors: [Color(0x6614AEBB), Color(0xFFFFF9F0)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildAnalyticsCards(),
              Padding(
                padding: const EdgeInsets.all(AdminDashboardStyles.spacingSmall),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: ThemeConstants.placeholder),
                    borderRadius: BorderRadius.circular(AdminDashboardStyles.borderRadiusXLarge),
                  ),
                  child: TextField(
                    onChanged: _filterEvents,
                    style: AdminDashboardStyles.output,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, color: ThemeConstants.primary),
                      hintText: 'Search event...',
                      hintStyle: AdminDashboardStyles.subtitle,
                      border: InputBorder.none,
                      filled: true,
                      fillColor: Colors.transparent,
                      isDense: true, 
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: AdminDashboardStyles.spacingMedium,
                      ),
                    ),
                  ),

                ),
              ),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredEvents.isEmpty
                        ? Center(child: Text('No events found.', style: AdminDashboardStyles.subtitle))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: AdminDashboardStyles.spacingSmall),
                            itemCount: filteredEvents.length,
                            itemBuilder: (context, i) {
                              final event = filteredEvents[i];
                              return Card(
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AdminDashboardStyles.borderRadiusMedium)),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(AdminDashboardStyles.spacingMedium),
                                  title: Text(
                                    event['eventName'] ?? 'Untitled Event',
                                    style: AdminDashboardStyles.output.copyWith(
                                        fontWeight: FontWeight.w600, fontSize: 16),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: AdminDashboardStyles.spacingXSmall),
                                    child: Text(
                                      event['description'] ?? 'No description available.',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AdminDashboardStyles.subtitle,
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.people, color: ThemeConstants.accent, size: 26),
                                    onPressed: () => _viewApplicants(event['id'], event),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}