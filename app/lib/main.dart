import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:ui' as ui;
import 'firebase_options.dart';
import 'models/security_event.dart';
import 'events_list_screen.dart';
import 'home_screen.dart';
import 'known_people_screen.dart';
import 'services/local_db_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'aws_sender.dart'; // IMPORT ADDED

const AndroidNotificationChannel _alertsChannel = AndroidNotificationChannel(
  'smart_home_guard_alerts',
  'Smart Home Guard Alerts',
  description: 'Alerts for unknown person detections',
  importance: Importance.high,
);

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

const String _pendingSecurityEventsKey = 'pending_security_events';

//flutter run -d web-server --web-port=8080
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  ui.DartPluginRegistrant.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Handling a background message: ${message.messageId}");

  try {
    await _queuePendingSecurityEvent(message);
  } catch (e) {
    print('Failed to queue background event: $e');
  }

  if (message.notification == null) {
    await _showLocalAlert(message);
  }
}

Future<void> _queuePendingSecurityEvent(RemoteMessage message) async {
  if (!message.data.containsKey('eventId') || !message.data.containsKey('imageUrl')) {
    return;
  }

  final prefs = await SharedPreferences.getInstance();
  final pendingEvents = prefs.getStringList(_pendingSecurityEventsKey) ?? <String>[];

  pendingEvents.add(
    jsonEncode({
      'eventId': message.data['eventId'].toString(),
      'imageUrl': message.data['imageUrl'].toString(),
      'status': 'Unknown',
      'timestamp': DateTime.now().toIso8601String(),
    }),
  );

  await prefs.setStringList(_pendingSecurityEventsKey, pendingEvents);
}

Future<bool> _syncPendingSecurityEvents(LocalDbService localDb) async {
  final prefs = await SharedPreferences.getInstance();
  final pendingEvents = prefs.getStringList(_pendingSecurityEventsKey);

  if (pendingEvents == null || pendingEvents.isEmpty) {
    return false;
  }

  bool importedAnyEvent = false;

  for (final pendingEventJson in pendingEvents) {
    try {
      final Map<String, dynamic> pendingEvent = jsonDecode(pendingEventJson);
      final String? eventId = pendingEvent['eventId']?.toString();
      final String? imageUrl = pendingEvent['imageUrl']?.toString();

      if (eventId == null || imageUrl == null || eventId.isEmpty || imageUrl.isEmpty) {
        continue;
      }

      await localDb.addSecurityEvent(
        SecurityEvent(
          eventId: eventId,
          status: pendingEvent['status']?.toString() ?? 'Unknown',
          imageUrl: imageUrl,
          timestamp: DateTime.tryParse(pendingEvent['timestamp']?.toString() ?? '') ??
              DateTime.now(),
        ),
      );
      importedAnyEvent = true;
    } catch (e) {
      print('Failed to sync pending security event: $e');
    }
  }

  await prefs.remove(_pendingSecurityEventsKey);
  return importedAnyEvent;
}

Future<void> _initializeLocalNotifications() async {
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );

  await _localNotifications.initialize(
    settings: const InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    ),
  );

  final androidPlugin = _localNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  await androidPlugin?.createNotificationChannel(_alertsChannel);
}

Future<void> _showLocalAlert(RemoteMessage message) async {
  final RemoteNotification? notification = message.notification;
  final String title =
      message.data['title']?.toString() ?? notification?.title ?? 'Smart Home Guard';
  final String body =
      message.data['body']?.toString() ??
      notification?.body ??
      'New security event detected while the app is closed.';

  final notificationId =
      (message.data['eventId']?.toString().hashCode ?? DateTime.now().millisecondsSinceEpoch) & 0x7fffffff;

  const androidDetails = AndroidNotificationDetails(
    'smart_home_guard_alerts',
    'Smart Home Guard Alerts',
    channelDescription: 'Alerts for unknown person detections',
    importance: Importance.high,
    priority: Priority.high,
    icon: '@mipmap/ic_launcher',
  );

  const iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  await _localNotifications.show(
    id: notificationId,
    title: title,
    body: body,
    notificationDetails:
        const NotificationDetails(android: androidDetails, iOS: iosDetails),
    payload: jsonEncode(message.data),
  );
}

Future<void> _configurePushNotifications() async {
  final FirebaseMessaging messaging = FirebaseMessaging.instance;

  await messaging.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  final NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  print('User granted permission: ${settings.authorizationStatus}');

  try {
    final String? token = kIsWeb
        ? await messaging.getToken(
            vapidKey: "insert your vapid key here if you changed it",
          )
        : await messaging.getToken();

    print("\n\n" + "=" * 50);
    print("YOUR FCM TOKEN IS:");
    print(token);
    print("=" * 50 + "\n\n");

    if (token != null) {
      await registerDeviceToken(token);
    }
  } catch (e) {
    print("Failed to get FCM token: $e");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final localDb = LocalDbService();
  await localDb.init();

  // Wipes the database cleanly. when done comment it out.
  //await localDb.clearAll();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await _initializeLocalNotifications();

  runApp(const MyApp());

  unawaited(_configurePushNotifications());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Home Guard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.blueAccent,
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  int _unreadEvents = 0;
  List<SecurityEvent> _events = [];
  final LocalDbService _localDbService = LocalDbService();
  Timer? _resumeRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refreshEventsFromStorage());
    // Uncomment for testing data
    //_setupTestData();

    _setupFirebaseListeners();
  }

  @override
  void dispose() {
    _resumeRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleResumeRefreshes();
    }
  }

  void _scheduleResumeRefreshes() {
    _resumeRefreshTimer?.cancel();
    unawaited(_refreshEventsFromStorage());

    int attempts = 0;
    _resumeRefreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      attempts++;
      unawaited(_refreshEventsFromStorage());
      if (attempts >= 45) {
        timer.cancel();
      }
    });
  }

  void _loadStoredEvents() {
    setState(() {
      _events = _localDbService.getAllSecurityEvents();
    });
  }

  Future<void> _refreshEventsFromStorage() async {
    final bool importedPendingEvents = await _syncPendingSecurityEvents(_localDbService);
    if (!mounted) {
      return;
    }
    _loadStoredEvents();

    if (importedPendingEvents) {
      setState(() {
        _currentIndex = 1;
        _unreadEvents = 0;
      });
    }
  }

  void _setupTestData() async {
    final newEvent = SecurityEvent(
      eventId: "3e1c6af4-2de9-463d-9300-34cd25040220",
      status: "Unknown",
      imageUrl: "insert your image url",
      timestamp: DateTime.now(),
    );
    await _localDbService.addSecurityEvent(newEvent);

    setState(() {
      _events = _localDbService.getAllSecurityEvents();
      if (_currentIndex != 1) {
        _unreadEvents++;
      }
    });
    _showInAppNotification();
  }

  void _setupFirebaseListeners() async {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("Got a message whilst in the foreground!");
      _handleMessage(message, isForeground: true);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("App opened from background message!");
      _handleMessage(message, isForeground: false);
    });

    RemoteMessage? initialMessage = await FirebaseMessaging.instance
        .getInitialMessage();
    if (initialMessage != null) {
      print("App opened from terminated state!");
      _handleMessage(initialMessage, isForeground: false);
    }
  }

  void _handleMessage(
    RemoteMessage message, {
    bool isForeground = false,
  }) async {
    if (message.data.containsKey('eventId') &&
        message.data.containsKey('imageUrl')) {
      final newEvent = SecurityEvent(
        eventId: message.data['eventId'],
        status: "Unknown",
        imageUrl: message.data['imageUrl'],
        timestamp: DateTime.now(),
      );
      await _localDbService.addSecurityEvent(newEvent);

      setState(() {
        _events = _localDbService.getAllSecurityEvents();

        if (_currentIndex != 1) {
          _unreadEvents++;
        }
      });

      if (isForeground) {
        _showInAppNotification();
      } else {
        // If opened from background, automatically switch to the Event tab
        setState(() {
          _currentIndex = 1;
          _unreadEvents = 0;
        });
      }
    }
  }

  void _showInAppNotification() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("New unknown person detected!"),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(
          days: 365,
        ), // Stay on screen until dismissed or action taken
        action: SnackBarAction(
          label: 'VIEW',
          textColor: Colors.blueAccent,
          onPressed: () {
            setState(() {
              _currentIndex = 1;
              _unreadEvents = 0;
            });
          },
        ),
      ),
    );
  }

  Future<void> _onTabTapped(int index) async {
    if (index == 1) {
      await _refreshEventsFromStorage();
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _currentIndex = index;
      if (index == 1) {
        _unreadEvents = 0; // Clear unread events when visiting the tab
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    });
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return const HomeScreen();
      case 1:
        return EventsListScreen(
          events: _events,
          onRefresh: () => _refreshEventsFromStorage(),
        );
      case 2:
        return const KnownPeopleScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        backgroundColor: const Color(0xFF1E1E1E),
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.white54,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: _unreadEvents > 0,
              label: Text('$_unreadEvents'),
              child: const Icon(Icons.event),
            ),
            label: 'Events',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Known People',
          ),
        ],
      ),
    );
  }
}
