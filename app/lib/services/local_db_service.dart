import 'package:hive_flutter/hive_flutter.dart';
import '../models/known_face.dart';
import '../models/security_event.dart';

class LocalDbService {
  static const String knownFacesBoxName = 'known_faces';
  static const String securityEventsBoxName = 'security_events';

  Future<void> init() async {
    await Hive.initFlutter();
    
    // Register Adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(KnownFaceAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(SecurityEventAdapter());
    }

    // Open boxes
    await Hive.openBox<KnownFace>(knownFacesBoxName);
    await Hive.openBox<SecurityEvent>(securityEventsBoxName);
  }

  // --- Known Faces ---
  Box<KnownFace> get _knownFacesBox => Hive.box<KnownFace>(knownFacesBoxName);

  Future<void> addKnownFace(KnownFace face) async {
    await _knownFacesBox.put(face.faceId, face);
  }

  List<KnownFace> getAllKnownFaces() {
    return _knownFacesBox.values.toList();
  }

  Future<void> deleteKnownFace(String faceId) async {
    await _knownFacesBox.delete(faceId);
  }

  KnownFace? getKnownFace(String faceId) {
    return _knownFacesBox.get(faceId);
  }

  // --- Security Events ---
  Box<SecurityEvent> get _securityEventsBox => Hive.box<SecurityEvent>(securityEventsBoxName);

  Future<void> addSecurityEvent(SecurityEvent event) async {
    await _securityEventsBox.put(event.eventId, event);
  }

  List<SecurityEvent> getAllSecurityEvents() {
    final events = _securityEventsBox.values.toList();
    // Sort by timestamp descending
    events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return events;
  }

  SecurityEvent? getSecurityEvent(String eventId) {
    return _securityEventsBox.get(eventId);
  }

  Future<void> clearAll() async {
    await _knownFacesBox.clear();
    await _securityEventsBox.clear();
  }
}
