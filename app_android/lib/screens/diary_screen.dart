import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/nutrition.dart';
import '../services/api_service.dart';

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  final ApiService _api = ApiService();
  DateTime _date = DateTime.now();
  bool _loading = true;
  String? _error;
  NutritionDay? _day;

  @override
  void initState() {
    super.initState();
    _loadDay();
  }

  String _dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _loadDay() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final day = await _api.fetchNutritionDay(date: _dateKey(_date));
      setState(() {
        _day = day;
      });
    } catch (e) {
      setState(() {
        _error = 'Не удалось загрузить данные';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _shiftDay(int delta) async {
    setState(() => _date = _date.add(Duration(days: delta)));
    await _loadDay();
  }

  Future<void> _openSearch(String meal) async {
    final result = await showModalBottomSheet<_AddItemResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FoodSearchSheet(meal: meal),
    );
    if (result == null) return;
    try {
      await _api.addNutritionItem(
        date: _dateKey(_date),
        meal: result.meal,
        grams: result.grams,
        product: result.product,
        title: result.customTitle,
        brand: result.customBrand,
      );
      await _loadDay();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось добавить продукт')),
      );
    }
  }

  Future<void> _deleteItem(int id) async {
    try {
      await _api.deleteNutritionItem(id);
      await _loadDay();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось удалить')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _day?.items ?? const <NutritionItem>[];
    final totals = _calcTotals(items);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppTheme.backgroundGradient(context),
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadDay,
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                const SizedBox(height: 4),
                _Header(
                  dateLabel: _formatDate(_date),
                  onPrev: () => _shiftDay(-1),
                  onNext: () => _shiftDay(1),
                ),
                const SizedBox(height: 16),
                _TotalsCard(
                  kcal: totals.kcal,
                  protein: totals.protein,
                  fat: totals.fat,
                  carb: totals.carb,
                ),
                const SizedBox(height: 16),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_error != null)
                  _ErrorCard(text: _error!)
                else ..._buildMealSections(items),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildMealSections(List<NutritionItem> items) {
    final grouped = <String, List<NutritionItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.meal, () => []).add(item);
    }

    return _meals.map((meal) {
      final mealItems = grouped[meal.key] ?? const [];
      return _MealSection(
        title: meal.title,
        subtitle: meal.time,
        items: mealItems,
        onAdd: () => _openSearch(meal.key),
        onDelete: _deleteItem,
      );
    }).toList();
  }

  _Totals _calcTotals(List<NutritionItem> items) {
    double kcal = 0;
    double protein = 0;
    double fat = 0;
    double carb = 0;
    for (final item in items) {
      kcal += item.kcal;
      protein += item.protein;
      fat += item.fat;
      carb += item.carb;
    }
    return _Totals(
      kcal: kcal.round(),
      protein: protein,
      fat: fat,
      carb: carb,
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];
    final d = date.day;
    final m = months[date.month - 1];
    return '$d $m';
  }
}

class _Header extends StatelessWidget {
  final String dateLabel;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _Header({
    required this.dateLabel,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: AppTheme.headerGradient(context),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            'Дневник питания',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const Spacer(),
          _NavButton(icon: Icons.chevron_left, onTap: onPrev),
          const SizedBox(width: 6),
          Text(
            dateLabel,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.mutedColor(context),
                ),
          ),
          const SizedBox(width: 6),
          _NavButton(icon: Icons.chevron_right, onTap: onNext),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _NavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white12),
        ),
        child: Icon(icon, size: 18, color: Colors.white70),
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  final int kcal;
  final double protein;
  final double fat;
  final double carb;

  const _TotalsCard({
    required this.kcal,
    required this.protein,
    required this.fat,
    required this.carb,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.titleMedium;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: AppTheme.accentColor(context),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentGlow(context).withOpacity(0.35),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _SmallStat(label: 'Ккал', value: kcal.toString(), style: textStyle),
          _SmallStat(label: 'Б', value: protein.toStringAsFixed(0), style: textStyle),
          _SmallStat(label: 'Ж', value: fat.toStringAsFixed(0), style: textStyle),
          _SmallStat(label: 'У', value: carb.toStringAsFixed(0), style: textStyle),
        ],
      ),
    );
  }
}

class _SmallStat extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? style;

  const _SmallStat({required this.label, required this.value, this.style});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: style?.copyWith(color: Colors.black)),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: Colors.black54, letterSpacing: 1.2),
        ),
      ],
    );
  }
}

class _MealSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<NutritionItem> items;
  final VoidCallback onAdd;
  final ValueChanged<int> onDelete;

  const _MealSection({
    required this.title,
    required this.subtitle,
    required this.items,
    required this.onAdd,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final kcal = items.fold<double>(0, (sum, item) => sum + item.kcal);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppTheme.cardColor(context),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: 8),
              Text(
                subtitle,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppTheme.mutedColor(context)),
              ),
              const Spacer(),
              Text(
                '${kcal.round()} ккал',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppTheme.mutedColor(context)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text(
              'Нет записей',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.mutedColor(context)),
            )
          else
            Column(
              children: items.map((item) {
                return _ItemRow(item: item, onDelete: onDelete);
              }).toList(),
            ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Добавить'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final NutritionItem item;
  final ValueChanged<int> onDelete;

  const _ItemRow({required this.item, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.grams.toStringAsFixed(0)} г • ${item.kcal.toStringAsFixed(0)} ккал',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppTheme.mutedColor(context)),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => onDelete(item.id),
            icon: const Icon(Icons.close, size: 18),
            color: Colors.white70,
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String text;
  const _ErrorCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.red.withOpacity(0.15),
        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _MealConfig {
  final String key;
  final String title;
  final String time;

  const _MealConfig(this.key, this.title, this.time);
}

const _meals = [
  _MealConfig('breakfast', 'Завтрак', '08:30'),
  _MealConfig('lunch', 'Обед', '13:00'),
  _MealConfig('dinner', 'Ужин', '19:00'),
  _MealConfig('snack', 'Перекус', '—'),
];

class _Totals {
  final int kcal;
  final double protein;
  final double fat;
  final double carb;
  const _Totals({
    required this.kcal,
    required this.protein,
    required this.fat,
    required this.carb,
  });
}

class _FoodSearchSheet extends StatefulWidget {
  final String meal;
  const _FoodSearchSheet({required this.meal});

  @override
  State<_FoodSearchSheet> createState() => _FoodSearchSheetState();
}

class _FoodSearchSheetState extends State<_FoodSearchSheet> {
  final ApiService _api = ApiService();
  final TextEditingController _controller = TextEditingController();
  bool _loading = false;
  List<NutritionProduct> _results = const [];
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _api.searchFood(query: query);
      setState(() => _results = items);
    } catch (_) {
      setState(() => _error = 'Не удалось найти продукты');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _searchBarcode() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Штрих-код'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Введите штрих-код'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Найти'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code == null || code.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final product = await _api.fetchFoodByBarcode(code);
      if (product == null) {
        setState(() => _error = 'Продукт не найден');
        return;
      }
      await _pickProduct(product);
    } catch (_) {
      setState(() => _error = 'Не удалось найти продукт');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickProduct(NutritionProduct product) async {
    final grams = await _askGrams(context);
    if (grams == null) return;
    if (!mounted) return;
    Navigator.pop(context, _AddItemResult(
      meal: widget.meal,
      grams: grams,
      product: product,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final viewInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + viewInset),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Добавить продукт', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    hintText: 'Поиск продукта',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _search,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _searchBarcode,
                icon: const Icon(Icons.qr_code),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(),
            )
          else if (_error != null)
            Text(_error!, style: Theme.of(context).textTheme.bodySmall)
          else
            SizedBox(
              height: 320,
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final item = _results[index];
                  return ListTile(
                    title: Text(item.title),
                    subtitle: Text(item.brand ?? ''),
                    trailing: const Icon(Icons.add),
                    onTap: () => _pickProduct(item),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

Future<double?> _askGrams(BuildContext context) async {
  final controller = TextEditingController(text: '100');
  final result = await showDialog<double>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Сколько грамм?'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Например, 150'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              final value = double.tryParse(controller.text.replaceAll(',', '.'));
              Navigator.pop(context, value);
            },
            child: const Text('Добавить'),
          ),
        ],
      );
    },
  );
  controller.dispose();
  return result;
}

class _AddItemResult {
  final String meal;
  final double grams;
  final NutritionProduct? product;
  final String? customTitle;
  final String? customBrand;

  _AddItemResult({
    required this.meal,
    required this.grams,
    this.product,
    this.customTitle,
    this.customBrand,
  });
}
