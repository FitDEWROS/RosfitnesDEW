import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'config.dart';
import 'services/auth_service.dart';
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
  late final AppLinks _appLinks;
  String _initialRoute = '/login';

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _bootstrap();
    _appLinks.uriLinkStream.listen((uri) {
      if (uri.scheme == AppConfig.authScheme) {
        _auth.handleAuthUri(uri).then((token) {
          if (token != null) {
            _navigatorKey.currentState?.pushReplacementNamed('/programs');
          }
        });
      }
    });
  }

  Future<void> _bootstrap() async {
    final token = await _auth.getToken();
    if (token != null && token.isNotEmpty) {
      setState(() => _initialRoute = '/programs');
    }
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null && initialUri.scheme == AppConfig.authScheme) {
      final handled = await _auth.handleAuthUri(initialUri);
      if (handled != null) {
        setState(() => _initialRoute = '/programs');
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
