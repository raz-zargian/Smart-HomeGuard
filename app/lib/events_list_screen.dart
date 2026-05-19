import 'package:flutter/material.dart';
import 'models/security_event.dart';
import 'event_detail_screen.dart';
import 'services/local_db_service.dart';

class EventsListScreen extends StatelessWidget {
  final List<SecurityEvent> events;
  final VoidCallback? onRefresh;

  const EventsListScreen({super.key, required this.events, this.onRefresh});

  String _formatDate(DateTime date) {
    final String amPm = date.hour >= 12 ? 'PM' : 'AM';
    final int hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final String minute = date.minute.toString().padLeft(2, '0');
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} $hour:$minute $amPm";
  }

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Center(
        child: Text(
          "No recent events.",
          style: TextStyle(fontSize: 18, color: Colors.white70),
        ),
      );
    }

    final localDb = LocalDbService();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("Recent Events"),
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12.0),
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[index];
          final formattedTime = _formatDate(event.timestamp);

          String titleText = "Unknown Person Detected";
          if (event.status == 'known') {
            final face = localDb.getKnownFace(event.eventId);
            if (face != null) {
              titleText = face.name;
            } else {
              titleText = "Known Person";
            }
          }

          return Card(
            color: const Color(0xFF1E1E1E),
            margin: const EdgeInsets.only(bottom: 12.0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EventDetailScreen(
                      eventId: event.eventId,
                      imageUrl: event.imageUrl,
                    ),
                  ),
                );
                if (onRefresh != null) {
                  onRefresh!();
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        event.imageUrl,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(
                              width: 80,
                              height: 80,
                              color: Colors.grey[800],
                              child: const Icon(Icons.broken_image, color: Colors.white54),
                            ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titleText,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            formattedTime,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white54,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Event ID: ${event.eventId.length > 8 ? event.eventId.substring(0, 8) + '...' : event.eventId}",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.white54),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
