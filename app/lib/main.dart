import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'models/security_event.dart';
import 'events_list_screen.dart';
import 'home_screen.dart';
import 'known_people_screen.dart';
import 'services/local_db_service.dart';
import 'package:flutter/foundation.dart';

//flutter run -d web-server --web-port=8080
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final localDb = LocalDbService();
  await localDb.init();

  // Wipes the database cleanly. when done comment it out.
  //await localDb.clearAll();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  FirebaseMessaging messaging = FirebaseMessaging.instance;
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  print('User granted permission: ${settings.authorizationStatus}');

  String? token;
  if (kIsWeb) {
    // requesting a token for the browser
    token = await messaging.getToken(
      vapidKey: "insert your vapid key here if you changed it",
    );
  } else {
    // requesting a token for the mobile (Android / iOS)
    token = await messaging.getToken();
  }

  print("\n\n" + "=" * 50);
  print("YOUR FCM TOKEN IS:");
  print(token);
  print("=" * 50 + "\n\n");

  runApp(const MyApp());
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

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  int _unreadEvents = 0;
  List<SecurityEvent> _events = [];
  final LocalDbService _localDbService = LocalDbService();

  @override
  void initState() {
    super.initState();
    _loadStoredEvents();
    // Uncomment for testing data
    //_setupTestData();

    _setupFirebaseListeners();
  }

  void _loadStoredEvents() {
    setState(() {
      _events = _localDbService.getAllSecurityEvents();
    });
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

  void _onTabTapped(int index) {
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
        return EventsListScreen(events: _events, onRefresh: _loadStoredEvents);
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
