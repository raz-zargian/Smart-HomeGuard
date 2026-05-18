import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SecurityEvent {
  final String id;
  final String imageUrl;
  final DateTime timestamp;

  SecurityEvent({
    required this.id,
    required this.imageUrl,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imageUrl': imageUrl,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory SecurityEvent.fromJson(Map<String, dynamic> json) {
    return SecurityEvent(
      id: json['id'],
      imageUrl: json['imageUrl'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class EventStorageService {
  static const String _storageKey = 'security_events';

  Future<List<SecurityEvent>> loadEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final String? eventsJson = prefs.getString(_storageKey);
    if (eventsJson == null) {
      return [];
    }

    try {
      final List<dynamic> decoded = jsonDecode(eventsJson);
      return decoded.map((e) => SecurityEvent.fromJson(e)).toList();
    } catch (e) {
      print('Error decoding events: $e');
      return [];
    }
  }

  Future<void> saveEvents(List<SecurityEvent> events) async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> serialized = events.map((e) => e.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(serialized));
  }
}
