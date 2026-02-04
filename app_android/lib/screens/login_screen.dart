import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import '../theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _remember = true;

  Future<void> _openLogin() async {
    final url = Uri.parse(AppConfig.telegramLoginUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c \u043e\u0442\u043a\u0440\u044b\u0442\u044c Telegram \u043b\u043e\u0433\u0438\u043d.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final accent = AppTheme.accentColor(context);
    return Scaffold(
      body: Stack(
        children: [
          const SizedBox.expand(),
          Positioned(
            top: -140,
            left: -40,
            child: _GlowBlob(
              color: accent.withOpacity(isDark ? 0.35 : 0.45),
              size: 320,
            ),
          ),
          Positioned(
            bottom: -160,
            right: -60,
            child: _GlowBlob(
              color: AppTheme.accentStrongColor(context)
                  .withOpacity(isDark ? 0.28 : 0.4),
              size: 360,
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Container(
                  width: 360,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    color: AppTheme.cardColor(context).withOpacity(0.9),
                    border: Border.all(color: Colors.white12),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black45,
                        blurRadius: 28,
                        offset: Offset(0, 16),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '\u0414\u041e\u0411\u0420\u041e \u041f\u041e\u0416\u0410\u041b\u041e\u0412\u0410\u0422\u042c',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(letterSpacing: 2.2),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 1,
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        color: Colors.white12,
                      ),
                      const SizedBox(height: 18),
                      const _LoginInput(
                        hint: '\u041b\u043e\u0433\u0438\u043d',
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 12),
                      const _LoginInput(
                        hint: '\u041f\u0430\u0440\u043e\u043b\u044c',
                        icon: Icons.lock_outline,
                        obscure: true,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => setState(() => _remember = !_remember),
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.white24),
                                color: _remember ? accent : Colors.transparent,
                              ),
                              child: _remember
                                  ? const Icon(Icons.check, size: 14, color: Colors.black)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '\u0417\u0430\u043f\u043e\u043c\u043d\u0438\u0442\u044c \u043c\u0435\u043d\u044f',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: AppTheme.mutedColor(context)),
                          ),
                          const Spacer(),
                          Text(
                            '\u0417\u0430\u0431\u044b\u043b\u0438 \u043f\u0430\u0440\u043e\u043b\u044c?',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: AppTheme.mutedColor(context)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(letterSpacing: 1.2, fontWeight: FontWeight.w700),
                        ),
                        onPressed: null,
                        child: const Text('\u0412\u043e\u0439\u0442\u0438'),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '\u0412\u0445\u043e\u0434 \u0447\u0435\u0440\u0435\u0437',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppTheme.mutedColor(context)),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _SocialButton(
                              label: 'Telegram',
                              icon: Icons.send_rounded,
                              active: true,
                              onTap: _openLogin,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: _SocialButton(
                              label: '\u042f\u043d\u0434\u0435\u043a\u0441',
                              icon: Icons.person,
                              active: false,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: _SocialButton(
                              label: 'Google',
                              icon: Icons.g_mobiledata,
                              active: false,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '\u0421\u043a\u043e\u0440\u043e: \u042f\u043d\u0434\u0435\u043a\u0441, Google, \u043f\u0430\u0440\u043e\u043b\u044c',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: AppTheme.mutedColor(context)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class _LoginInput extends StatelessWidget {
  final String hint;
  final IconData icon;
  final bool obscure;
  const _LoginInput({
    required this.hint,
    required this.icon,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: AppTheme.mutedColor(context)),
        filled: true,
        fillColor: AppTheme.cardColor(context).withOpacity(0.6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white10),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: AppTheme.accentColor(context).withOpacity(0.6),
          ),
        ),
      ),
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback? onTap;
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.active,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = active ? AppTheme.accentColor(context) : AppTheme.cardColor(context);
    final fg = active ? Colors.black : AppTheme.mutedColor(context);
    return InkWell(
      onTap: active ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: fg, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
