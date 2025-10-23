import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({Key? key}) : super(key: key);

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
          if (status == 'approved') approved++;
          else pending++;
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
      backgroundColor: Colors.grey[50],
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding:
            const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Applicants for "${eventData['eventName']}"',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.teal),
            ),
            const SizedBox(height: 12),
            if (applicants.isEmpty)
              const Text('No applicants yet.',
                  style: TextStyle(color: Colors.black54)),
            ...applicants.map((entry) {
              final uid = entry.key;
              final applicant = entry.value;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  title: Text(applicant['email'] ?? 'No email'),
                  subtitle: Text(
                      'Status: ${applicant['status'] ?? 'Pending'}',
                      style: const TextStyle(fontSize: 13)),
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
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFFFA3B99),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Admin Dashboard',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 6),
          Text(
            '${events.length} Event(s) | $totalVolunteers Volunteer(s)',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCards() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatCard('Events', events.length, Icons.event, Colors.indigo),
          _buildStatCard('Volunteers', totalVolunteers, Icons.people, Colors.teal),
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
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              value.toString(),
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        title: const Text('Admin Dashboard',
        style: TextStyle(
        color: Colors.white, 
        fontSize: 12, 
      ),
      ),
        backgroundColor: const Color(0xFF14AEBB),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildHeader(),
          _buildAnalyticsCards(),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: _filterEvents,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search event...',
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredEvents.isEmpty
                    ? const Center(child: Text('No events found.'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: filteredEvents.length,
                        itemBuilder: (context, i) {
                          final event = filteredEvents[i];
                          return Card(
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              title: Text(
                                event['eventName'] ?? 'Untitled Event',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  event['description'] ??
                                      'No description available.',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.people,
                                    color: Color(0xFFFA3B99), size: 26),
                                onPressed: () =>
                                    _viewApplicants(event['id'], event),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
