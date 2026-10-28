import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// قناة الاتصال بكود الأندرويد (واتساب، تذكيرات، جهات الاتصال)
const channel = MethodChannel('callnotes/native');

String latin(String s) {
  const ar = '٠١٢٣٤٥٦٧٨٩';
  var r = s;
  for (var i = 0; i < 10; i++) {
    r = r.replaceAll(ar[i], '$i');
  }
  return r;
}

/// آخر 9 أرقام (عشان +2010... و 010... يطلعوا نفس الشخص)
String keyOf(String phone) {
  final d = latin(phone).replaceAll(RegExp(r'\D'), '');
  return d.length > 9 ? d.substring(d.length - 9) : d;
}

/// رقم بصيغة دولية لواتساب (الافتراضي مصر 20)
String waNumber(String phone) {
  final d = latin(phone).replaceAll(RegExp(r'[^0-9+]'), '');
  if (d.startsWith('+')) return d.substring(1);
  if (d.startsWith('00')) return d.substring(2);
  if (d.startsWith('0')) return '20${d.substring(1)}';
  return d;
}

String isoOf(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String fmtDate(String iso) {
  final s = iso.split('-');
  return s.length == 3 ? '${s[2]}/${s[1]}/${s[0]}' : iso;
}

// ---------------------------------------------------------------- Model
class Booking {
  int? id;
  String name;
  String phone;
  String date; // yyyy-MM-dd
  String notes;
  String? followUp; // yyyy-MM-dd
  bool followDone;
  String rating; // none / good / bad
  String warn;

  Booking({
    this.id,
    required this.name,
    required this.phone,
    required this.date,
    this.notes = '',
    this.followUp,
    this.followDone = false,
    this.rating = 'none',
    this.warn = '',
  });

  bool get followPending =>
      followUp != null && followUp!.isNotEmpty && !followDone;

  bool get followDue =>
      followPending && followUp!.compareTo(isoOf(DateTime.now())) <= 0;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'phone': phone,
        'phone_key': keyOf(phone),
        'date': date,
        'notes': notes,
        'follow_up': followUp,
        'follow_done': followDone ? 1 : 0,
      };

  factory Booking.fromMap(Map<String, Object?> m) => Booking(
        id: m['id'] as int?,
        name: (m['name'] as String?) ?? '',
        phone: (m['phone'] as String?) ?? '',
        date: (m['date'] as String?) ?? '',
        notes: (m['notes'] as String?) ?? '',
        followUp: m['follow_up'] as String?,
        followDone: ((m['follow_done'] as int?) ?? 0) == 1,
        rating: (m['rating'] as String?) ?? 'none',
        warn: (m['warn'] as String?) ?? '',
      );
}

// ---------------------------------------------------------------- DB
// نفس الملف بيقراه كود الأندرويد وقت الرنين (CallReceiver.kt)
class Db {
  static Database? _db;

  static const _bookingsSql = '''
    CREATE TABLE bookings(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT,
      phone TEXT,
      phone_key TEXT,
      date TEXT,
      notes TEXT,
      follow_up TEXT,
      follow_done INTEGER DEFAULT 0
    )''';

  static Future<void> _extra(Database d) async {
    await d.execute('''
      CREATE TABLE IF NOT EXISTS clients(
        phone_key TEXT PRIMARY KEY,
        rating TEXT,
        warn TEXT
      )''');
    await d.execute('''
      CREATE TABLE IF NOT EXISTS invoices(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        year INTEGER,
        month INTEGER,
        day INTEGER,
        title TEXT,
        amount REAL,
        note TEXT,
        photos TEXT
      )''');
  }

  static Future<Database> get instance async {
    _db ??= await openDatabase(
      p.join(await getDatabasesPath(), 'bookings.db'),
      version: 2,
      onCreate: (d, v) async {
        await d.execute(_bookingsSql);
        await _extra(d);
      },
      onUpgrade: (d, o, n) async {
        if (o < 2) {
          await d.execute('ALTER TABLE bookings ADD COLUMN follow_up TEXT');
          await d.execute(
              'ALTER TABLE bookings ADD COLUMN follow_done INTEGER DEFAULT 0');
          await _extra(d);
        }
      },
    );
    return _db!;
  }

  static Future<List<Booking>> all() async {
    final d = await instance;
    final rows = await d.rawQuery('''
      SELECT b.*, c.rating AS rating, c.warn AS warn
      FROM bookings b LEFT JOIN clients c ON c.phone_key = b.phone_key
      ORDER BY b.date DESC, b.id DESC''');
    return rows.map(Booking.fromMap).toList();
  }

  static Future<int> save(Booking b) async {
    final d = await instance;
    int id;
    if (b.id == null) {
      id = await d.insert('bookings', b.toMap());
    } else {
      await d.update('bookings', b.toMap(), where: 'id = ?', whereArgs: [b.id]);
      id = b.id!;
    }
    final k = keyOf(b.phone);
    if (b.rating == 'none' && b.warn.isEmpty) {
      await d.delete('clients', where: 'phone_key = ?', whereArgs: [k]);
    } else {
      await d.insert(
        'clients',
        {'phone_key': k, 'rating': b.rating, 'warn': b.warn},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    return id;
  }

  static Future<void> delete(int id) async {
    final d = await instance;
    await d.delete('bookings', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> setDone(int id, bool v) async {
    final d = await instance;
    await d.update('bookings', {'follow_done': v ? 1 : 0},
        where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------- نسخ احتياطي
  static Future<String> exportJson() async {
    final d = await instance;
    return jsonEncode({
      'app': 'callnotes',
      'version': 1,
      'bookings': await d.query('bookings'),
      'clients': await d.query('clients'),
      'invoices': await d.query('invoices'),
    });
  }

  /// بيضيف الناقص بس (من غير تكرار) ويرجّع عدد الحجوزات الجديدة
  static Future<int> importJson(String text) async {
    final data = jsonDecode(text) as Map<String, dynamic>;
    final d = await instance;
    var added = 0;

    final old = await d.query('bookings');
    final seen =
        old.map((r) => '${r['phone_key']}|${r['date']}|${r['name']}').toSet();
    for (final r in (data['bookings'] as List? ?? [])) {
      final m = Map<String, Object?>.from(r as Map);
      final sig = '${m['phone_key']}|${m['date']}|${m['name']}';
      if (seen.contains(sig)) continue;
      m.remove('id');
      await d.insert('bookings', m);
      seen.add(sig);
      added++;
    }

    for (final r in (data['clients'] as List? ?? [])) {
      await d.insert('clients', Map<String, Object?>.from(r as Map),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    final oldI = await d.query('invoices');
    String sigI(Map m) =>
        '${m['year']}|${m['month']}|${m['day']}|${m['title']}|${m['amount']}|${m['note']}';
    final seenI = oldI.map(sigI).toSet();
    for (final r in (data['invoices'] as List? ?? [])) {
      final m = Map<String, Object?>.from(r as Map);
      final sig = sigI(m);
      if (seenI.contains(sig)) continue;
      m.remove('id');
      m['photos'] = '';
      await d.insert('invoices', m);
      seenI.add(sig);
    }
    return added;
  }
}

// ---------------------------------------------------------------- تذكير المتابعة
Future<void> cancelFollowUp(int id) async {
  try {
    await channel.invokeMethod('cancelReminder', {'id': id});
  } catch (e) {
    // تجاهل
  }
}

Future<void> scheduleFollowUp(Booking b) async {
  if (b.id == null) return;
  await cancelFollowUp(b.id!);
  if (!b.followPending) return;
  final d = DateTime.tryParse(b.followUp!);
  if (d == null) return;
  var t = DateTime(d.year, d.month, d.day, 10);
  final now = DateTime.now();
  if (t.isBefore(now)) {
    final today = DateTime(now.year, now.month, now.day);
    if (DateTime(d.year, d.month, d.day).isBefore(today)) return;
    t = now.add(const Duration(minutes: 1));
  }
  try {
    await channel.invokeMethod('scheduleReminder', {
      'id': b.id,
      'millis': t.millisecondsSinceEpoch,
      'title': 'متابعة: ${b.name}',
      'body': 'كلّم العميل ${b.phone}',
    });
  } catch (e) {
    // تجاهل
  }
}
