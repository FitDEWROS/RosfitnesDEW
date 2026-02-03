import 'dart:math' as math;
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
            builder: (context, child) {
              return Stack(
                children: [
                  const _AnimatedBackdrop(),
                  if (child != null) child,
                ],
              );
            },
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

class _AnimatedBackdrop extends StatefulWidget {
  const _AnimatedBackdrop();

  @override
  State<_AnimatedBackdrop> createState() => _AnimatedBackdropState();
}

class _AnimatedBackdropState extends State<_AnimatedBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 9000),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) {
          final t = _anim.value;
          return Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(-1 + 2 * t, -1),
                      end: Alignment(1 - 2 * t, 1),
                      colors: isDark
                          ? const [
                              Color(0xFF0F0F10),
                              Color(0xFF151518),
                              Color(0xFF0C0C0D),
                            ]
                          : const [
                              Color(0xFFF4F1E6),
                              Color(0xFFF8F3E8),
                              Color(0xFFF1E9D6),
                            ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0.3 + 0.4 * t, -0.2),
                      radius: 1.2,
                      colors: [
                        AppTheme.accentColor(context)
                            .withOpacity(isDark ? 0.12 : 0.16),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(-0.4 + 0.3 * t, 1.1),
                      radius: 1.1,
                      colors: [
                        AppTheme.accentStrongColor(context)
                            .withOpacity(isDark ? 0.10 : 0.14),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              const Positioned.fill(
                child: CustomPaint(
                  painter: _GlobalNoisePainter(opacity: 0.012),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GlobalNoisePainter extends CustomPainter {
  final double opacity;
  final int seed;
  const _GlobalNoisePainter({this.opacity = 0.012, this.seed = 1337});

  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random(seed);
    final light = Paint()..color = Colors.white.withOpacity(opacity);
    final dark = Paint()..color = Colors.black.withOpacity(opacity * 0.7);
    const step = 7.0;
    for (double y = 0; y < size.height; y += step) {
      for (double x = 0; x < size.width; x += step) {
        final r = rand.nextDouble();
        if (r < 0.28) {
          final paint = r < 0.14 ? dark : light;
          canvas.drawRect(Rect.fromLTWH(x, y, 1.2, 1.2), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GlobalNoisePainter oldDelegate) => false;
}
