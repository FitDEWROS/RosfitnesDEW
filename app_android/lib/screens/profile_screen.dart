import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _avatarUrl;
  String _name = '\u041c\u0410\u041a\u0421\u0418\u041c';
  String _username = '@maksim_nazarkin';
  String _tariff = '\u0412\u041b\u0410\u0414\u0415\u041b\u0415\u0426';
  String _userId = '354538028';

  final _heightController = TextEditingController(text: '173');
  final _weightController = TextEditingController(text: '91');
  final _ageController = TextEditingController(text: '28');
  final _weightEntryController = TextEditingController();
  final _waistController = TextEditingController();
  final _chestController = TextEditingController();
  final _hipController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    _weightEntryController.dispose();
    _waistController.dispose();
    _chestController.dispose();
    _hipController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final auth = AuthService();
    final photo = await auth.getProfilePhotoUrl();
    final firstName = await auth.getFirstName();
    final prefs = await SharedPreferences.getInstance();
    final tariffName = prefs.getString('tariff_name');
    if (!mounted) return;
    setState(() {
      _avatarUrl = photo;
      if (firstName != null && firstName.trim().isNotEmpty) {
        _name = firstName.trim().toUpperCase();
        _username = '@${firstName.trim().toLowerCase()}';
      }
      if (tariffName != null && tariffName.trim().isNotEmpty) {
        _tariff = tariffName.trim().toUpperCase();
      }
    });
  }

  Future<void> _logout(BuildContext context) async {
    final auth = AuthService();
    await auth.clearToken();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  void _showStub(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _openWeightDynamics(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final isDark = AppTheme.isDark(context);
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: isDark ? const Color(0xFF1C1D21) : const Color(0xFFF4F0E7),
              border: Border.all(color: Colors.white10),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 24,
                  offset: Offset(0, 12),
                )
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              '\u0414\u0418\u041d\u0410\u041c\u0418\u041a\u0410 \u0412\u0415\u0421\u0410',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(letterSpacing: 1.4),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '02.02 - 08.02',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: AppTheme.mutedColor(context)),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(999),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.close, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _InlineField(
                          hint: '\u0412\u0435\u0441, \u043a\u0433',
                          controller: _weightEntryController,
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentColor(context),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        onPressed: () => _showStub(
                          context,
                          '\u0412\u0435\u0441 \u0441\u043e\u0445\u0440\u0430\u043d\u0435\u043d',
                        ),
                        child: const Text('\u0421\u041e\u0425\u0420\u0410\u041d\u0418\u0422\u042c'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '\u0417\u0410\u041c\u0415\u0420\u042b, \u0421\u041c',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(letterSpacing: 2, color: AppTheme.mutedColor(context)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _InlineField(
                          hint: '\u0422\u0430\u043b\u0438\u044f, \u0441\u043c',
                          controller: _waistController,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _InlineField(
                          hint: '\u0413\u0440\u0443\u0434\u044c, \u0441\u043c',
                          controller: _chestController,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _InlineField(
                          hint: '\u0411\u0435\u0434\u0440\u0430, \u0441\u043c',
                          controller: _hipController,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentColor(context),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      onPressed: () => _showStub(
                        context,
                        '\u0417\u0430\u043c\u0435\u0440\u044b \u0441\u043e\u0445\u0440\u0430\u043d\u0435\u043d\u044b',
                      ),
                      child: const Text('\u0421\u041e\u0425\u0420\u0410\u041d\u0418\u0422\u042c \u0417\u0410\u041c\u0415\u0420\u042b'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: const [
                      Expanded(child: _WeightPhotoCard(title: '\u0421\u041f\u0415\u0420\u0415\u0414\u0418')),
                      SizedBox(width: 12),
                      Expanded(child: _WeightPhotoCard(title: '\u0421\u0411\u041e\u041a\u0423')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const _WeightPhotoCard(title: '\u0421\u0417\u0410\u0414\u0418'),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.black12,
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '01.01 - 31.01',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: AppTheme.mutedColor(context)),
                          ),
                        ),
                        Text(
                          '91 \u043a\u0433',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: AppTheme.mutedColor(context)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
            children: [
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  color: AppTheme.cardColor(context),
                  border: Border.all(color: Colors.white10),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 38,
                          backgroundColor: isDark
                              ? const Color(0xFF2A2B2F)
                              : Colors.black12,
                          backgroundImage: (_avatarUrl != null &&
                                  _avatarUrl!.isNotEmpty)
                              ? NetworkImage(_avatarUrl!)
                              : null,
                          child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                              ? Text(
                                  _name.isNotEmpty ? _name[0] : '\u041c',
                                  style: TextStyle(
                                    color: AppTheme.accentColor(context),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 22,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(letterSpacing: 1.1),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _username,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppTheme.mutedColor(context)),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(999),
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(Icons.close, size: 20),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _InfoChip(text: 'ID: $_userId'),
                        _InfoChip(text: '\u0422\u0410\u0420\u0418\u0424: $_tariff'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _StatCard(
                          title: '\u0420\u041e\u0421\u0422',
                          value: '${_heightController.text} \u0441\u043c',
                        ),
                        const SizedBox(width: 10),
                        _StatCard(
                          title: '\u0412\u0415\u0421',
                          value: '${_weightController.text} \u043a\u0433',
                        ),
                        const SizedBox(width: 10),
                        _StatCard(
                          title: '\u0412\u041e\u0417\u0420\u0410\u0421\u0422',
                          value: '${_ageController.text} \u043b\u0435\u0442',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _ActionRow(
                      title: '\u0414\u0418\u041d\u0410\u041c\u0418\u041a\u0410 \u0412\u0415\u0421\u0410',
                      buttonText: '\u041e\u0422\u041a\u0420\u042b\u0422\u042c',
                      onTap: () => _openWeightDynamics(context),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.black12,
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '\u0420\u0415\u0414\u0410\u041a\u0422\u041e\u0420 \u041f\u0420\u041e\u0424\u0418\u041b\u042f',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  letterSpacing: 2,
                                  color: AppTheme.mutedColor(context),
                                ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _FieldBlock(
                                  label: '\u0420\u041e\u0421\u0422 (\u0421\u041c)',
                                  controller: _heightController,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _FieldBlock(
                                  label: '\u0412\u0415\u0421 (\u041a\u0413)',
                                  controller: _weightController,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _FieldBlock(
                                  label: '\u0412\u041e\u0417\u0420\u0410\u0421\u0422',
                                  controller: _ageController,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: 160,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentColor(context),
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                              ),
                              onPressed: () => _showStub(
                                context,
                                '\u0421\u043e\u0445\u0440\u0430\u043d\u0435\u043d\u043e',
                              ),
                              child: const Text('\u0421\u041e\u0425\u0420\u0410\u041d\u0418\u0422\u042c'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: () => _logout(context),
                        child: const Text('\u0412\u042b\u0419\u0422\u0418'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String text;
  const _InfoChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.black12,
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(letterSpacing: 1.2),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.black12,
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(letterSpacing: 1.6, color: AppTheme.mutedColor(context)),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final String title;
  final String buttonText;
  final VoidCallback onTap;
  const _ActionRow({
    required this.title,
    required this.buttonText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.black12,
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(letterSpacing: 1.6),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentColor(context),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: onTap,
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }
}

class _FieldBlock extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  const _FieldBlock({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(letterSpacing: 1.4, color: AppTheme.mutedColor(context)),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.black12,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _InlineField extends StatelessWidget {
  final String hint;
  final TextEditingController controller;
  const _InlineField({required this.hint, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.black12,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }
}

class _WeightPhotoCard extends StatelessWidget {
  final String title;
  const _WeightPhotoCard({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.black12,
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(letterSpacing: 1.6, color: AppTheme.mutedColor(context)),
          ),
          const SizedBox(height: 10),
          Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.black12,
              border: Border.all(color: Colors.white10),
            ),
            child: Center(
              child: Text(
                '\u0424\u043e\u0442\u043e \u0435\u0449\u0435 \u043d\u0435 \u0437\u0430\u0433\u0440\u0443\u0436\u0435\u043d\u043e',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: AppTheme.mutedColor(context)),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('\u0421\u043a\u043e\u0440\u043e')),
                    );
                  },
                  child: const Text('\u0417\u0410\u0413\u0420\u0423\u0417\u0418\u0422\u042c'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('\u0423\u0434\u0430\u043b\u0435\u043d\u043e')),
                    );
                  },
                  child: const Text('\u0423\u0414\u0410\u041b\u0418\u0422\u042c'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
