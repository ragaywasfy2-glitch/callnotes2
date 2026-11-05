import 'package:flutter/material.dart';
import 'bookings_editor.dart';
import 'bookings_utils.dart';
import 'data.dart';

// ---------------------------------------------------------------- الشهور
class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  int _year = DateTime.now().year;
  Map<int, OrderStat> _stats = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await loadOrderStats('month', 'year = ?', [_year]);
    if (mounted) setState(() => _stats = s);
  }

  Widget _monthCard(int m, ColorScheme cs, DateTime now) {
    final s = _stats[m];
    final isNow = m == now.month && _year == now.year;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => OrderMonthPage(year: _year, month: m)),
        );
        _load();
      },
      child: Container(
        decoration: BoxDecoration(
          color: s == null ? null : cs.primaryContainer,
          border: Border.all(
            color: isNow ? cs.primary : Colors.black12,
            width: isNow ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(orderMonths[m - 1],
                style: const TextStyle(fontWeight: FontWeight.bold)),
            if (s != null)
              Text('${s.count} عملية', style: const TextStyle(fontSize: 12)),
            if (s != null)
              Text(orderMoney(s.profit),
                  style: TextStyle(
                      fontSize: 12,
                      color: s.profit >= 0 ? Colors.green.shade800 : Colors.red.shade800)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final total = _stats.values.fold<double>(0, (a, b) => a + b.profit);
    return Scaffold(
      appBar: AppBar(title: const Text('الحجوزات')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() => _year--);
                    _load();
                  },
                ),
                Text('$_year',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() => _year++);
                    _load();
                  },
                ),
              ],
            ),
          ),
          Text('إجمالي ربح السنة: ${orderMoney(total)}'),
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              padding: const EdgeInsets.all(12),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.05,
              children: [
                for (var m = 1; m <= 12; m++) _monthCard(m, cs, now),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- الشهر (الأيام)
class OrderMonthPage extends StatefulWidget {
  final int year;
  final int month;
  const OrderMonthPage({super.key, required this.year, required this.month});

  @override
  State<OrderMonthPage> createState() => _OrderMonthPageState();
}

class _OrderMonthPageState extends State<OrderMonthPage> {
  Map<int, OrderStat> _days = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await loadOrderStats(
        'day', 'year = ? AND month = ?', [widget.year, widget.month]);
    if (mounted) setState(() => _days = s);
  }

  Widget _cell(int d, ColorScheme cs, DateTime now) {
    final s = _days[d];
    final isToday =
        d == now.day && widget.month == now.month && widget.year == now.year;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                OrderDayPage(year: widget.year, month: widget.month, day: d),
          ),
        );
        _load();
      },
      child: Container(
        decoration: BoxDecoration(
          color: s == null ? null : cs.primaryContainer,
          border: Border.all(
            color: isToday ? cs.primary : Colors.black12,
            width: isToday ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$d', style: const TextStyle(fontWeight: FontWeight.bold)),
            if (s != null)
              Text('${s.count}', style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final n = DateTime(widget.year, widget.month + 1, 0).day;
    final offset = (DateTime(widget.year, widget.month, 1).weekday + 1) % 7;
    final total = _days.values.fold<double>(0, (a, b) => a + b.profit);
    return Scaffold(
      appBar: AppBar(
          title: Text('${orderMonths[widget.month - 1]} ${widget.year}')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('إجمالي ربح الشهر: ${orderMoney(total)}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(children: [
              for (final w in const ['س', 'ح', 'ن', 'ث', 'ر', 'خ', 'ج'])
                Expanded(child: Center(child: Text(w))),
            ]),
          ),
          Expanded(
            child: GridView.count(
              crossAxisCount: 7,
              padding: const EdgeInsets.all(8),
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              children: [
                for (var i = 0; i < offset; i++) const SizedBox.shrink(),
                for (var d = 1; d <= n; d++) _cell(d, cs, now),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- اليوم (العمليات)
class OrderDayPage extends StatefulWidget {
  final int year;
  final int month;
  final int day;
  const OrderDayPage(
      {super.key, required this.year, required this.month, required this.day});

  @override
  State<OrderDayPage> createState() => _OrderDayPageState();
}

class _OrderDayPageState extends State<OrderDayPage> {
  List<OrderEntry> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await Db.instance;
    final rows = await d.query(
      'orders',
      where: 'year = ? AND month = ? AND day = ?',
      whereArgs: [widget.year, widget.month, widget.day],
      orderBy: 'id DESC',
    );
    if (mounted) setState(() => _items = rows.map(OrderEntry.fromMap).toList());
  }

  Future<void> _edit([OrderEntry? e]) async {
    await editOrder(context, widget.year, widget.month, widget.day, e);
    _load();
  }

  Future<void> _delete(OrderEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف العملية؟'),
        content: Text(e.title.isEmpty
            ? (e.type == 'poultry' ? 'حجز دواجن' : 'بيع دواء')
            : e.title),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true || e.id == null) return;
    final d = await Db.instance;
    await d.delete('orders', where: 'id = ?', whereArgs: [e.id]);
    _load();
  }

  Widget _card(OrderEntry e) {
    final isPoultry = e.type == 'poultry';
    final qtyText = isPoultry
        ? '${e.quantity.toStringAsFixed(0)} كتكوت'
        : '${e.quantity.toStringAsFixed(e.quantity == e.quantity.roundToDouble() ? 0 : 2)} ${e.unit}';
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: InkWell(
        onTap: () => _edit(e),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(isPoultry ? '🐤' : '💊',
                    style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                      e.title.isEmpty
                          ? (isPoultry ? 'حجز دواجن' : 'بيع دواء')
                          : e.title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'del') {
                      _delete(e);
                    } else {
                      _edit(e);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('تعديل')),
                    PopupMenuItem(value: 'del', child: Text('حذف')),
                  ],
                ),
              ]),
              const SizedBox(height: 4),
              Text(qtyText),
              Text('سعر المكتب: ${orderMoney(e.officePrice)} • '
                  'سعر الجمهور: ${orderMoney(e.publicPrice)}'),
              if (e.note.isNotEmpty) Text(e.note),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: e.profit >= 0
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'ربح: ${orderMoney(e.profit)} (${e.profitPercent.toStringAsFixed(1)}%)',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: e.profit >= 0
                          ? Colors.green.shade800
                          : Colors.red.shade800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _items.fold<double>(0, (a, b) => a + b.profit);
    return Scaffold(
      appBar: AppBar(
        title: Text(
            '${widget.day} ${orderMonths[widget.month - 1]} ${widget.year}'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('حجز جديد'),
      ),
      body: _items.isEmpty
          ? const Center(child: Text('مفيش حجوزات في اليوم ده'))
          : ListView(
              padding: const EdgeInsets.only(bottom: 90),
              children: [
                if (_items.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('إجمالي ربح اليوم: ${orderMoney(total)}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                for (final e in _items) _card(e),
              ],
            ),
    );
  }
}
