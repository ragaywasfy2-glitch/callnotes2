import 'package:flutter/material.dart';
import 'data.dart';
import 'invoice_editor.dart';
import 'invoice_utils.dart';

// ---------------------------------------------------------------- تبويب الفواتير (الشهور)
class InvoicesPage extends StatefulWidget {
  const InvoicesPage({super.key});

  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  int _year = DateTime.now().year;
  Map<int, Stat> _stats = {};

  @override
  void initState() {
    super.initState();
    photosDir();
    _load();
  }

  Future<void> _load() async {
    final s = await loadStats('month', 'year = ?', [_year]);
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
          MaterialPageRoute(builder: (_) => MonthPage(year: _year, month: m)),
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
            Text(months[m - 1],
                style: const TextStyle(fontWeight: FontWeight.bold)),
            if (s != null)
              Text('${s.count} فاتورة', style: const TextStyle(fontSize: 12)),
            if (s != null && s.sum > 0)
              Text(money(s.sum), style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final total = _stats.values.fold<double>(0, (a, b) => a + b.sum);
    return Scaffold(
      appBar: AppBar(title: const Text('الفواتير')),
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
          Text('إجمالي السنة: ${money(total)}'),
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
class MonthPage extends StatefulWidget {
  final int year;
  final int month;
  const MonthPage({super.key, required this.year, required this.month});

  @override
  State<MonthPage> createState() => _MonthPageState();
}

class _MonthPageState extends State<MonthPage> {
  Map<int, Stat> _days = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await loadStats(
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
                DayPage(year: widget.year, month: widget.month, day: d),
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
    final total = _days.values.fold<double>(0, (a, b) => a + b.sum);
    return Scaffold(
      appBar: AppBar(title: Text('${months[widget.month - 1]} ${widget.year}')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('إجمالي الشهر: ${money(total)}',
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

// ---------------------------------------------------------------- اليوم (الفواتير)
class DayPage extends StatefulWidget {
  final int year;
  final int month;
  final int day;
  const DayPage(
      {super.key, required this.year, required this.month, required this.day});

  @override
  State<DayPage> createState() => _DayPageState();
}

class _DayPageState extends State<DayPage> {
  List<Invoice> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await Db.instance;
    final rows = await d.query(
      'invoices',
      where: 'year = ? AND month = ? AND day = ?',
      whereArgs: [widget.year, widget.month, widget.day],
      orderBy: 'id DESC',
    );
    if (mounted) setState(() => _items = rows.map(Invoice.fromMap).toList());
  }

  Future<void> _edit([Invoice? inv]) async {
    await editInvoice(context, widget.year, widget.month, widget.day, inv);
    _load();
  }

  Future<void> _delete(Invoice inv) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الفاتورة؟'),
        content: Text(inv.title),
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
    if (ok != true || inv.id == null) return;
    for (final n in inv.photos) {
      await deletePhoto(n);
    }
    final d = await Db.instance;
    await d.delete('invoices', where: 'id = ?', whereArgs: [inv.id]);
    _load();
  }

  Widget _card(Invoice inv) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: InkWell(
        onTap: () => _edit(inv),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(inv.title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                if (inv.amount != null)
                  Text(money(inv.amount!),
                      style: const TextStyle(
                          color: Colors.teal, fontWeight: FontWeight.bold)),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'del') {
                      _delete(inv);
                    } else {
                      _edit(inv);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('تعديل')),
                    PopupMenuItem(value: 'del', child: Text('حذف')),
                  ],
                ),
              ]),
              if (inv.note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(inv.note),
                ),
              if (inv.photos.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(
                    height: 72,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (var i = 0; i < inv.photos.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: thumb(
                              inv.photos[i],
                              size: 72,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PhotoViewer(
                                      names: inv.photos, index: i),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
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
    final total = _items.fold<double>(0, (a, b) => a + (b.amount ?? 0));
    return Scaffold(
      appBar: AppBar(
        title: Text(
            '${widget.day} ${months[widget.month - 1]} ${widget.year}'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('فاتورة جديدة'),
      ),
      body: _items.isEmpty
          ? const Center(child: Text('مفيش فواتير في اليوم ده'))
          : ListView(
              padding: const EdgeInsets.only(bottom: 90),
              children: [
                if (total > 0)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('إجمالي اليوم: ${money(total)}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                for (final inv in _items) _card(inv),
              ],
            ),
    );
  }
}
