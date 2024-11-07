import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:http/http.dart' as http;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> requestNotificationPermission() async {
  await Permission.notification.request();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

  await initializeLocalNotifications();
  await requestNotificationPermission();

  runApp(const FirebaseTestApp());
}

Future<void> initializeLocalNotifications() async {
  const AndroidInitializationSettings androidInitializationSettings =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  const DarwinInitializationSettings darwinInitializationSettings =
  DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  const InitializationSettings initializationSettings = InitializationSettings(
    android: androidInitializationSettings,
    iOS: darwinInitializationSettings,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
  );

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'test_channel123',
    'Message Notifications',
    description: 'This channel is used for message notifications',
    importance: Importance.max,
  );

  final AndroidFlutterLocalNotificationsPlugin? androidFlutterLocalNotificationsPlugin =
  flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  if (androidFlutterLocalNotificationsPlugin != null) {
    await androidFlutterLocalNotificationsPlugin.createNotificationChannel(channel);
  }


  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Got a message whilst in the foreground!');
    print('Message data: ${message.data}');

    if (message.notification != null) {
      print('Message also contained a notification: ${message.notification}');
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              importance: Importance.max,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
          ),
        );
      }
    }
  });
}



class FirebaseTestApp extends StatelessWidget {
  const FirebaseTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firebase Test',
      home: TestScreen(),
    );
  }
}

class TestScreen extends StatelessWidget {
  const TestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Center(
          child: SignUpForm(),
        ),
      ),
    );
  }
}

class SignUpForm extends StatefulWidget {
  @override
  _SignUpFormState createState() => _SignUpFormState();
}

class _SignUpFormState extends State<SignUpForm> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> signUp() async {
    final String email = _emailController.text;
    final String password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      print("이메일과 비밀번호를 입력하세요.");
      return;
    }

    FirebaseMessaging messaging = FirebaseMessaging.instance;
    String? token = await messaging.getToken();
    print('=======FCM 토큰: $token========');

    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:5001/fir-testapp-b3582/us-central1/createUser'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password, "token": token}),
      );

      if (response.statusCode == 201) {
        print("회원가입 성공: ${jsonDecode(response.body)['uid']}");
      } else {
        print("회원가입 실패: ${jsonDecode(response.body)['error']}");
      }
    } catch (e) {
      print("오류 발생: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextField(
          controller: _emailController,
          decoration: InputDecoration(labelText: '이메일'),
        ),
        TextField(
          controller: _passwordController,
          decoration: InputDecoration(labelText: '비밀번호'),
          obscureText: true,
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: signUp,
          child: const Text('회원가입'),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: showImmediateNotification,
          child: const Text('즉시 알림 보내기'),
        ),
      ],
    );
  }

  Future<void> showImmediateNotification() async {
    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      'test_channel123',
      'Message Notifications',
      channelDescription: 'This channel is used for message notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      0,
      '즉시 알림 제목',
      '즉시 알림 내용',
      notificationDetails,
      payload: '즉시 알림 페이로드',
    );
  }
}
