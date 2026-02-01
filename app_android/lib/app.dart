import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'package:flutter/services.dart';
import 'config.dart';
import 'screens/login_screen.dart';
import 'screens/programs_screen.dart';
import 'screens/program_detail_screen.dart';
import 'screens/workout_screen.dart';
import 'theme.dart';

class FitDewApp extends StatefulWidget {
  const FitDewApp({super.key});

  @override
  State<FitDewApp> createState() => _FitDewAppState();
}

class _FitDewAppState extends State<FitDewApp> {
  final _auth = AuthService();
  final _navigatorKey = GlobalKey<NavigatorState>();
  String _initialRoute = '/login';
  static const _channel = MethodChannel('app.links');

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onLink') {
        final link = call.arguments?.toString();
        if (link != null) {
          await _handleLink(link);
        }
      }
    });
  }

  Future<void> _bootstrap() async {
    final token = await _auth.getToken();
    if (token != null && token.isNotEmpty) {
      setState(() => _initialRoute = '/programs');
    }
    try {
      final link = await _channel.invokeMethod<String>('getInitialLink');
      if (link != null) {
        await _handleLink(link);
      }
    } catch (_) {}
  }

  Future<void> _handleLink(String link) async {
    final uri = Uri.tryParse(link);
    if (uri == null) return;
    if (uri.scheme == AppConfig.authScheme) {
      final token = await _auth.handleAuthUri(uri);
      if (token != null) {
        _navigatorKey.currentState?.pushReplacementNamed('/programs');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme(),
      initialRoute: _initialRoute,
      routes: {
        '/login': (context) => const LoginScreen(),
        '/programs': (context) => const ProgramsScreen(),
        '/program': (context) => const ProgramDetailScreen(),
        '/workout': (context) => const WorkoutScreen(),
      },
    );
  }
}
