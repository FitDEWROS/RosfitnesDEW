import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'package:flutter/services.dart';
import 'config.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/programs_screen.dart';
import 'screens/program_detail_screen.dart';
import 'screens/workout_screen.dart';
import 'screens/diary_screen.dart';
import 'screens/metrics_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/exercises_screen.dart';
import 'screens/crossfit_exercises_screen.dart';
import 'screens/exercise_detail_screen.dart';
import 'theme.dart';

class FitDewApp extends StatefulWidget {
  const FitDewApp({super.key});

  @override
  State<FitDewApp> createState() => _FitDewAppState();
}

class _FitDewAppState extends State<FitDewApp> {
  final _auth = AuthService();
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _themeController = ThemeController();
  bool _ready = false;
  bool _isAuthed = false;
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
      _isAuthed = true;
    }
    try {
      final link = await _channel.invokeMethod<String>('getInitialLink');
      if (link != null) {
        await _handleLink(link);
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _ready = true);
    }
  }

  Future<void> _handleLink(String link) async {
    final uri = Uri.tryParse(link);
    if (uri == null) return;
    if (uri.scheme == AppConfig.authScheme) {
      final token = await _auth.handleAuthUri(uri);
      if (token != null) {
        setState(() => _isAuthed = true);
        _navigatorKey.currentState?.pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: _themeController,
      child: AnimatedBuilder(
        animation: _themeController,
        builder: (context, _) {
          return MaterialApp(
            navigatorKey: _navigatorKey,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme(),
            darkTheme: AppTheme.darkTheme(),
            themeMode: _themeController.mode,
            home: _ready
                ? (_isAuthed ? const HomeScreen() : const LoginScreen())
                : const _SplashScreen(),
            routes: {
              '/login': (context) => const LoginScreen(),
              '/home': (context) => const HomeScreen(),
              '/programs': (context) => const ProgramsScreen(),
              '/program': (context) => const ProgramDetailScreen(),
              '/workout': (context) => const WorkoutScreen(),
              '/diary': (context) => const DiaryScreen(),
              '/metrics': (context) => const MetricsScreen(),
              '/profile': (context) => const ProfileScreen(),
              '/chat': (context) => const ChatScreen(),
              '/notifications': (context) => const NotificationsScreen(),
              '/exercises': (context) => const ExercisesScreen(),
              '/exercises_crossfit': (context) => const CrossfitExercisesScreen(),
              '/exercise': (context) => const ExerciseDetailScreen(),
            },
          );
        },
      ),
    );
  }
}

class ThemeController extends ChangeNotifier {
  ThemeMode mode = ThemeMode.dark;

  void toggle() {
    mode = mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }
}

class AppScope extends InheritedNotifier<ThemeController> {
  const AppScope({super.key, required ThemeController controller, required Widget child})
      : super(notifier: controller, child: child);

  static ThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    return scope!.notifier!;
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor(context),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
