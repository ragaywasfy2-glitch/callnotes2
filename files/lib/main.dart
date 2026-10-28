import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite/sqflite.dart';

void main() => runApp(const MyApp());

// ---------------------------------------------------------------- Model
class Booking {
  int? id;
  String name;
  String phone;
  String date; // yyyy-MM-dd
  String notes;

  Booking({
    this.id,
    required this.name,
    required this.phone,
    required this.date,
    this.notes = '',
  });

  static String _latin(String s) {
    const ar = '٠١٢٣٤٥٦٧٨٩';
    var r = s;
    for (var i = 0; i < 10; i++) {
      r = r.replaceAll(ar[i], '$i');
    }
    return r;
  }

  /// آخر 9 أرقام من الرقم (عشان +2010... و 010... يطلعوا نفس الشخص)
  static String keyOf(String phone) {
    final d = _latin(phone).replaceAll(RegExp(r'\D'), '');
    return d.length > 9 ? d.substring(d.length - 9) : d;
  }

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'phone': phone,
        'phone_key': keyOf(phone),
        'date': date,
        'notes': notes,
      };

  factory Booking.fromMap(Map<String, Object?> m) => Booking(
        id: m['id'] as int?,
        name: (m['name'] as String?) ?? '',
        phone: (m['phone'] as String?) ?? '',
        date: (m['date'] as String?) ?? '',
        notes: (m['notes'] as String?) ?? '',
      );
}

String isoOf(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String fmtDate(String iso) {
  final s = iso.split('-');
  return s.length == 3 ? '${s[2]}/${s[1]}/${s[0]}' : iso;
}

// ---------------------------------------------------------------- DB
// نفس ملف القاعدة بيقراه كود الأندرويد (CallReceiver.kt) وقت الرنين
class Db {
  static Database? _db;

  static Future<Database> get instance async {
    _db ??= await openDatabase(
      p.join(await getDatabasesPath(), 'bookings.db'),
      version: 1,
      onCreate: (d, v) => d.execute('''
        CREATE TABLE bookings(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT,
          phone TEXT,
          phone_key TEXT,
          date TEXT,
          notes TEXT
        )'''),
    );
    return _db!;
  }

  static Future<List<Booking>> all() async {
    final d = await instance;
    final rows = await d.query('bookings', orderBy: 'date DESC, id DESC');
    return rows.map(Booking.fromMap).toList();
  }

  static Future<void> save(Booking b) async {
    final d = await instance;
    if (b.id == null) {
      await d.insert('bookings', b.toMap());
    } else {
      await d.update('bookings', b.toMap(), where: 'id = ?', whereArgs: [b.id]);
    }
  }

  static Future<void> delete(int id) async {
    final d = await instance;
    await d.delete('bookings', where: 'id = ?', whereArgs: [id]);
  }
}

// ---------------------------------------------------------------- App
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'دليل العملاء',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
      ),
      builder: (c, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  List<Booking> _items = [];
  String _query = '';
  bool _permsOk = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reload();
    _checkPerms();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkPerms();
  }

  Future<void> _reload() async {
    final items = await Db.all();
    if (mounted) setState(() => _items = items);
  }

  Future<void> _checkPerms() async {
    final ok = await Permission.phone.isGranted &&
        await Permission.notification.isGranted &&
        await Permission.systemAlertWindow.isGranted;
    if (mounted) setState(() => _permsOk = ok);
  }

  Future<void> _askPerms() async {
    await [Permission.phone, Permission.notification].request();
    if (!await Permission.systemAlertWindow.isGranted) {
      await Permission.systemAlertWindow.request(); // بيفتح الإعدادات
    }
    _checkPerms();
  }

  Future<void> _edit([Booking? b]) async {
    final name = TextEditingController(text: b?.name ?? '');
    final phone = TextEditingController(text: b?.phone ?? '');
    final notes = TextEditingController(text: b?.notes ?? '');
    var date = b?.date ?? isoOf(DateTime.now());

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'الاسم'),
              ),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'رقم الموبايل'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.event),
                label: Text('تاريخ الحجز: ${fmtDate(date)}'),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.tryParse(date) ?? DateTime.now(),
                    firstDate: DateTime(2015),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) setS(() => date = isoOf(d));
                },
              ),
              TextField(
                controller: notes,
                decoration: const InputDecoration(
                    labelText: 'ملاحظات (اختياري) - مثلًا نوع الشغل'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('حفظ'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (saved != true || phone.text.trim().isEmpty) return;
    await Db.save(Booking(
      id: b?.id,
      name: name.text.trim().isEmpty ? 'بدون اسم' : name.text.trim(),
      phone: phone.text.trim(),
      date: date,
      notes: notes.text.trim(),
    ));
    _reload();
  }

  Future<void> _confirmDelete(Booking b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الحجز؟'),
        content: Text('${b.name} - ${fmtDate(b.date)}'),
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
    if (ok == true && b.id != null) {
      await Db.delete(b.id!);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim();
    final shown = q.isEmpty
        ? _items
        : _items
            .where((b) => b.name.contains(q) || b.phone.contains(q))
            .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('دليل العملاء')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('حجز جديد'),
      ),
      body: Column(
        children: [
          if (!_permsOk)
            Card(
              color: Colors.amber.shade100,
              margin: const EdgeInsets.all(12),
              child: ListTile(
                leading: const Icon(Icons.warning_amber_rounded),
                title: const Text('التنبيه وقت المكالمة محتاج صلاحيات'),
                subtitle: const Text('الهاتف + الإشعارات + الظهور فوق التطبيقات'),
                trailing: FilledButton(
                    onPressed: _askPerms, child: const Text('تفعيل')),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'ابحث بالاسم أو الرقم',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? const Center(child: Text('لسه مفيش حجوزات'))
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 90),
                    itemCount: shown.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final b = shown[i];
                      return ListTile(
                        title: Text(b.name),
                        subtitle: Text(
                          '${b.phone}\n${fmtDate(b.date)}'
                          '${b.notes.isEmpty ? '' : ' • ${b.notes}'}',
                        ),
                        isThreeLine: true,
                        onTap: () => _edit(b),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _confirmDelete(b),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
