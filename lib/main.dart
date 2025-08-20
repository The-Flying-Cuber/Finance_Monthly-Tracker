import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';

void main() {
  runApp(const BillsApp());
}

/* ──────────────────────────────────────────────────────────────────────────────
  Settings can toggle dark mode & seed color
────────────────────────────────────────────────────────────────────────────── */
class BillsApp extends StatefulWidget {
  const BillsApp({super.key});

  @override
  State<BillsApp> createState() => _BillsAppState();
}

class _BillsAppState extends State<BillsApp> {
  ThemeMode _mode = ThemeMode.light;
  Color _seed = const Color(0xFF1A73E8);

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final sp = await SharedPreferences.getInstance();
    final dark = sp.getBool('theme_dark') ?? false;
    final seed = sp.getInt('seed_color') ?? _seed.value;
    setState(() {
      _mode = dark ? ThemeMode.dark : ThemeMode.light;
      _seed = Color(seed);
    });
  }

  Future<void> _saveTheme({required bool dark, required Color seed}) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('theme_dark', dark);
    await sp.setInt('seed_color', seed.value);
  }

  void _applyTheme({bool? dark, Color? seed}) {
    setState(() {
      if (dark != null) _mode = dark ? ThemeMode.dark : ThemeMode.light;
      if (seed != null) _seed = seed;
    });
    _saveTheme(dark: _mode == ThemeMode.dark, seed: _seed);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bills Tracker',
      themeMode: _mode,

      // LIGHT
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF6F8FC), // light page bg
        appBarTheme: AppBarTheme(
          backgroundColor: ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.light).primary,
          foregroundColor: ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.light).onPrimary,
          elevation: 0,
        ),
        navigationRailTheme: NavigationRailThemeData(
          backgroundColor: const Color(0xFFF6F8FC),
          selectedIconTheme: const IconThemeData(size: 24),
          unselectedIconTheme: const IconThemeData(size: 24),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),

      // DARK
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0F1115), // dark page bg
        appBarTheme: AppBarTheme(
          backgroundColor: ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark).primary,
          foregroundColor: ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark).onPrimary,
          elevation: 0,
        ),
        navigationRailTheme: const NavigationRailThemeData(
          backgroundColor: Color(0xFF0F1115),
          selectedIconTheme: IconThemeData(size: 24),
          unselectedIconTheme: IconThemeData(size: 24),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF181B21), // darker cards
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),

      home: BillsHomePage(
        onToggleDark: (v) => _applyTheme(dark: v),
        onChangeSeed: (c) => _applyTheme(seed: c),
        isDark: _mode == ThemeMode.dark,
        seed: _seed,
      ),
    );

  }
}

/* ──────────────────────────────────────────────────────────────────────────────
   Data model + storage
────────────────────────────────────────────────────────────────────────────── */
class Expense {
  String id;
  String name;
  String category;
  double amount;
  int dueDay; // 1..31, clamped per-month
  Map<String, String> paidByMonth; // monthKey -> ISO date

  Expense({
    required this.id,
    required this.name,
    required this.category,
    required this.amount,
    required this.dueDay,
    Map<String, String>? paidByMonth,
  }) : paidByMonth = paidByMonth ?? {};

  bool isPaid(String monthKey) => paidByMonth.containsKey(monthKey);
  DateTime? paidAt(String monthKey) =>
      paidByMonth[monthKey] == null ? null : DateTime.tryParse(paidByMonth[monthKey]!);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'amount': amount,
        'dueDay': dueDay,
        'paidByMonth': paidByMonth,
      };

  factory Expense.fromJson(Map<String, dynamic> m) => Expense(
        id: m['id'] as String,
        name: m['name'] as String,
        category: (m['category'] as String?) ?? 'General',
        amount: (m['amount'] as num).toDouble(),
        dueDay: m['dueDay'] as int,
        paidByMonth: Map<String, String>.from(m['paidByMonth'] ?? {}),
      );
}

class BillsStore {
  static const _k = 'bills_v2';
  static Future<List<Expense>> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_k);
    if (raw == null) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map((e) => Expense.fromJson(e)).toList();
  }

  static Future<void> save(List<Expense> items) async {
    final sp = await SharedPreferences.getInstance();
    final raw = jsonEncode(items.map((e) => e.toJson()).toList());
    await sp.setString(_k, raw);
  }
}

/* ──────────────────────────────────────────────────────────────────────────────
   Main page with 4 views controlled by NavigationRail
────────────────────────────────────────────────────────────────────────────── */
class BillsHomePage extends StatefulWidget {
  const BillsHomePage({
    super.key,
    required this.onToggleDark,
    required this.onChangeSeed,
    required this.isDark,
    required this.seed,
  });

  final ValueChanged<bool> onToggleDark;
  final ValueChanged<Color> onChangeSeed;
  final bool isDark;
  final Color seed;

  @override
  State<BillsHomePage> createState() => _BillsHomePageState();
}

class _BillsHomePageState extends State<BillsHomePage> {
  // 0=Overview, 1=Bills, 2=Analytics, 3=Settings
  int _selectedIndex = 0;

  List<Expense> _items = [];
  bool _loading = true;
  bool _piePaidOnly = true; // toggle for pie chart

  String get _monthKey {
    final now = DateTime.now();
    return DateFormat('yyyy-MM').format(DateTime(now.year, now.month));
  }

  DateTime _dueDateForMonth(Expense e, DateTime now) {
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    final day = e.dueDay.clamp(1, lastDay);
    return DateTime(now.year, now.month, day);
  }

  @override
  void initState() {
    super.initState();
    BillsStore.load().then((data) {
      setState(() {
        _items = data;
        _loading = false;
      });
    });
  }

  Future<void> _persist() async => BillsStore.save(_items);

  void _togglePaid(Expense e) {
    final mk = _monthKey;
    setState(() {
      if (e.isPaid(mk)) {
        e.paidByMonth.remove(mk);
      } else {
        e.paidByMonth[mk] = DateTime.now().toIso8601String();
      }
    });
    _persist();
  }

  Future<void> _addOrEdit({Expense? existing}) async {
    final res = await showDialog<Expense>(
      context: context,
      builder: (_) => _ExpenseDialog(existing: existing),
    );
    if (res == null) return;
    setState(() {
      if (existing == null) {
        _items.add(res);
      } else {
        final i = _items.indexWhere((x) => x.id == existing.id);
        if (i >= 0) {
          // keep paid history
          res.paidByMonth = existing.paidByMonth;
          _items[i] = res;
        }
      }
    });
    _persist();
  }

  void _delete(Expense e) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete expense?'),
        content: Text('This will remove "${e.name}".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              setState(() => _items.removeWhere((x) => x.id == e.id));
              _persist();
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  double get _totalAll => _items.fold(0.0, (a, b) => a + b.amount);

  double get _totalUnpaidThisMonth {
    final mk = _monthKey;
    return _items.where((e) => !e.isPaid(mk)).fold(0.0, (a, b) => a + b.amount);
  }

  double get _totalPaidThisMonth {
    final mk = _monthKey;
    return _items.where((e) => e.isPaid(mk)).fold(0.0, (a, b) => a + b.amount);
  }

  Map<String, double> _categoryTotals({required bool paidOnly}) {
    final mk = _monthKey;
    final map = <String, double>{};
    for (final e in _items) {
      if (paidOnly && !e.isPaid(mk)) continue;
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthLabel = DateFormat('MMMM yyyy').format(now);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    _items.sort((a, b) {
      final da = _dueDateForMonth(a, now);
      final db = _dueDateForMonth(b, now);
      final c = da.compareTo(db);
      if (c != 0) return c;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return Scaffold(
      // appBar: AppBar(
      //   backgroundColor: const Color(0xFF0B5BD3),
      //   foregroundColor: Colors.white,
      //   title: Text('Deals • $monthLabel', style: const TextStyle(fontWeight: FontWeight.w600)),
      // ),
        appBar: AppBar(
          title: Text('Deals • $monthLabel', style: const TextStyle(fontWeight: FontWeight.w600)),
        ),

      body: Row(
        children: [
          // Left rail (now interactive)
          NavigationRail(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (i) => setState(() => _selectedIndex = i),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Image.asset('assets/Ian.png', width: 32, height: 32),
            ),
            destinations:  [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined, color: Theme.of(context).colorScheme.onSurface,),
                selectedIcon: Icon(Icons.dashboard, color: Theme.of(context).colorScheme.primary,),
                label: Text('Overview'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.receipt_long_outlined, color: Theme.of(context).colorScheme.onSurface,),
                selectedIcon: Icon(Icons.receipt_long, color: Theme.of(context).colorScheme.primary,),
                label: Text('Bills'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.analytics_outlined, color: Theme.of(context).colorScheme.onSurface,),
                selectedIcon: Icon(Icons.analytics, color: Theme.of(context).colorScheme.primary,),
                label: Text('Analytics'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined, color: Theme.of(context).colorScheme.onSurface,),
                selectedIcon: Icon(Icons.settings, color: Theme.of(context).colorScheme.primary,),
                label: Text('Settings'),
              ),
            ],
          ),

          // Main content switches per tab
          Expanded(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  if (_selectedIndex == 0) ..._buildOverview(now)
                  else if (_selectedIndex == 1) ..._buildBillsOnly(now)
                  else if (_selectedIndex == 2) ..._buildAnalyticsOnly()
                  else ..._buildSettings(),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 3
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _addOrEdit(),
              icon: const Icon(Icons.add),
              label: const Text('Add Bill'),
            ),
    );
  }

  /* ─────────── VIEW: Overview (metrics + chart + list) ─────────── */
  List<Widget> _buildOverview(DateTime now) => [
        // Metrics
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _metricChip(
              title: 'Total (all)',
              value: NumberFormat.simpleCurrency().format(_totalAll),
              color: Colors.indigo,
            ),
            _metricChip(
              title: 'Paid this month',
              value: NumberFormat.simpleCurrency().format(_totalPaidThisMonth),
              color: Colors.green,
            ),
            _metricChip(
              title: 'Unpaid this month',
              value: NumberFormat.simpleCurrency().format(_totalUnpaidThisMonth),
              color: Colors.orange,
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Chart
        _PieCard(
          data: _categoryTotals(paidOnly: _piePaidOnly),
          paidOnly: _piePaidOnly,
          onTogglePaidOnly: (v) => setState(() => _piePaidOnly = v),
        ),
        const SizedBox(height: 16),
        // List
        ..._buildBillsList(now),
      ];

  /* ─────────── VIEW: Bills only ─────────── */
  List<Widget> _buildBillsOnly(DateTime now) => _buildBillsList(now);

  /* ─────────── VIEW: Analytics only (chart + breakdown) ─────────── */
  List<Widget> _buildAnalyticsOnly() {
    final data = _categoryTotals(paidOnly: _piePaidOnly);
    final total = data.values.fold<double>(0, (a, b) => a + b);

    final breakdown = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return [
      _PieCard(
        data: data,
        paidOnly: _piePaidOnly,
        onTogglePaidOnly: (v) => setState(() => _piePaidOnly = v),
      ),
      const SizedBox(height: 16),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Breakdown', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (total == 0)
                const Text('No data yet')
              else
                ...breakdown.map((e) {
                  final pct = (e.value / total) * 100;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(child: Text(e.key)),
                        Text(NumberFormat.simpleCurrency().format(e.value)),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 60,
                          child: Text('${pct.toStringAsFixed(0)}%',
                              textAlign: TextAlign.right),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    ];
  }

  /* ─────────── VIEW: Settings (dark mode + seed color) ─────────── */
  List<Widget> _buildSettings() => [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.dark_mode),
                const SizedBox(width: 12),
                const Text('Dark mode', style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                Switch(
                  value: widget.isDark,
                  onChanged: widget.onToggleDark,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Accent color', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final c in [
                      const Color(0xFF1A73E8), // blue
                      const Color(0xFF00A86B), // green
                      const Color(0xFFFF6D00), // orange
                      const Color(0xFF8E24AA), // purple
                      const Color(0xFFEF5350), // red
                      const Color(0xFF00838F), // teal
                    ])
                      GestureDetector(
                        onTap: () => widget.onChangeSeed(c),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: c == widget.seed ? Colors.black54 : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ];

  /* ─────────── Bills list shared by Overview/Bills ─────────── */
  List<Widget> _buildBillsList(DateTime now) {
    if (_items.isEmpty) {
      return const [
        Card(
          child: SizedBox(
            height: 120,
            child: Center(child: Text('No expenses yet. Click “Add Bill”.')),
          ),
        )
      ];
    }

    return _items.map((e) {
      final due = _dueDateForMonth(e, now);
      final days = due.difference(DateTime(now.year, now.month, now.day)).inDays;
      final paid = e.isPaid(_monthKey);
      final paidAt = e.paidAt(_monthKey);
      final currency = NumberFormat.simpleCurrency().format(e.amount);

      Color border = Colors.transparent;
      if (!paid) {
        if (days < 0) border = Colors.red;
        else if (days <= 3) border = Colors.orange;
        else border = Colors.blueGrey.shade200;
      } else {
        border = Colors.green;
      }

      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _togglePaid(e),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 64,
                  decoration: BoxDecoration(
                    color: border.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(e.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 16)),
                          const SizedBox(width: 8),
                          Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(e.category,
                                style: TextStyle(
                                    color: Colors.blue.shade700, fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        (paid && paidAt != null)
                            ? 'Paid ${DateFormat.yMMMd().format(paidAt)}'
                            : 'Due ${DateFormat.MMMd().format(due)} • '
                              '${days >= 0 ? 'in $days day${days == 1 ? '' : 's'}'
                                          : '${-days} day${days == -1 ? '' : 's'} ago'}',
                        style: TextStyle(
                          color: paid
                              ? Colors.green.shade700
                              : (days < 0
                                  ? Colors.red.shade700
                                  : (days <= 3
                                      ? Colors.orange.shade700
                                      : Colors.blueGrey)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(currency,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _addOrEdit(existing: e),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(e),
                        ),
                        Checkbox(
                          value: paid,
                          onChanged: (_) => _togglePaid(e),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _metricChip({required String title, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color, // <- was Colors.white
        borderRadius: BorderRadius.circular(14),
        boxShadow: Theme.of(context).brightness == Brightness.light
            ? const [BoxShadow(blurRadius: 8, color: Color(0x14000000), offset: Offset(0, 2))]
            : null,
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.light ? Colors.black12 : Colors.white10,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          Text(value),
        ],
      ),
    );
  }
}

/* ──────────────────────────────────────────────────────────────────────────────
   Pie card (unchanged visuals, with paid-only toggle)
────────────────────────────────────────────────────────────────────────────── */
class _PieCard extends StatelessWidget {
  final Map<String, double> data;
  final bool paidOnly;
  final ValueChanged<bool> onTogglePaidOnly;

  const _PieCard({
    required this.data,
    required this.paidOnly,
    required this.onTogglePaidOnly,
  });

  @override
  Widget build(BuildContext context) {
    final total = data.values.fold<double>(0, (a, b) => a + b);
    final legend = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth > 700;
            final chart = SizedBox(
              height: 260,
              child: total <= 0
                  ? const Center(child: Text('No data to chart yet'))
                  : PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 48,
                        sections: [
                          for (int i = 0; i < legend.length; i++)
                            PieChartSectionData(
                              value: legend[i].value,
                              title: '${((legend[i].value / total) * 100).toStringAsFixed(0)}%',
                              radius: 90,
                              titleStyle: const TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.w700),
                              color: Colors.primaries[i % Colors.primaries.length],
                            ),
                        ],
                      ),
                    ),
            );

            final legendList = Wrap(
              spacing: 12,
              runSpacing: 8,
              children: legend.map((e) {
                final pct = total == 0 ? 0 : (e.value / total) * 100;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.10), // follows accent
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.light
                          ? Colors.black12
                          : Colors.white10, // adjusts for dark mode
                    ),
                  ),
                  child: Text('${e.key}: ${pct.toStringAsFixed(0)}%'),
                );
              }).toList(),
            );

            final toggle = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Paid only'),
                Switch(value: paidOnly, onChanged: onTogglePaidOnly),
              ],
            );

            return wide
                ? Row(
                    children: [
                      Expanded(child: chart),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Spend by category', style: TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            legendList,
                            const SizedBox(height: 8),
                            toggle,
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Spend by category', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      chart,
                      const SizedBox(height: 8),
                      legendList,
                      const SizedBox(height: 8),
                      toggle,
                    ],
                  );
          },
        ),
      ),
    );
  }
}

/* ──────────────────────────────────────────────────────────────────────────────
   Add/Edit dialog
────────────────────────────────────────────────────────────────────────────── */
class _ExpenseDialog extends StatefulWidget {
  final Expense? existing;
  const _ExpenseDialog({this.existing});

  @override
  State<_ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends State<_ExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _name;
  late TextEditingController _amount;
  late TextEditingController _category;
  int _dueDay = DateTime.now().day;
  final List<String> _presetCats = const ['Rent', 'Utilities', 'Internet', 'Phone', 'Food', 'Transport', 'Other'];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _amount = TextEditingController(
        text: widget.existing == null ? '' : widget.existing!.amount.toStringAsFixed(2));
    _category = TextEditingController(text: widget.existing?.category ?? 'Other');
    _dueDay = widget.existing?.dueDay ?? _dueDay;
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _category.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add bill' : 'Edit bill'),
      content: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 480,
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Name (e.g., Rent, Wi-Fi)'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amount,
                  decoration: const InputDecoration(labelText: 'Amount'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    final x = double.tryParse(v.replaceAll(',', ''));
                    if (x == null) return 'Enter a number';
                    if (x < 0) return 'Must be ≥ 0';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _presetCats.contains(_category.text) ? _category.text : 'Other',
                        decoration: const InputDecoration(labelText: 'Category'),
                        items: _presetCats
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) _category.text = v;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _category,
                        decoration: const InputDecoration(labelText: 'Or type a category'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Due day:'),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Slider(
                        value: _dueDay.toDouble(),
                        min: 1,
                        max: 31,
                        divisions: 30,
                        label: _dueDay.toString(),
                        onChanged: (v) => setState(() => _dueDay = v.round()),
                      ),
                    ),
                  ],
                ),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Short months will clamp to last day (e.g., Feb).',
                      style: TextStyle(fontSize: 12, color: Colors.black54)),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            final id = widget.existing?.id ?? UniqueKey().toString();
            final amt = double.parse(_amount.text.replaceAll(',', ''));
            final e = Expense(
              id: id,
              name: _name.text.trim(),
              category: _category.text.trim().isEmpty ? 'Other' : _category.text.trim(),
              amount: amt,
              dueDay: _dueDay,
            );
            Navigator.pop(context, e);
          },
          child: Text(widget.existing == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}
