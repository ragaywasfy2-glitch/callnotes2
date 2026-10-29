import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'data.dart';

const months = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
];

String numStr(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
String money(double v) => '${numStr(v)} ج.م';

// ---------------------------------------------------------------- صور
String _pp = '';

Future<Directory> photosDir() async {
  final base = await getApplicationDocumentsDirectory();
  final d = Directory(p.join(base.path, 'invoice_photos'));
  if (!await d.exists()) await d.create(recursive: true);
  _pp = d.path;
  return d;
}

Future<void> deletePhoto(String name) async {
  try {
    final f = File(p.join(_pp, name));
    if (await f.exists()) await f.delete();
  } catch (e) {
    // تجاهل
  }
}

Widget thumb(String name, {double size = 64, VoidCallback? onTap}) {
  return GestureDetector(
    onTap: onTap,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(
        File(p.join(_pp, name)),
        width: size,
        height: size,
        cacheWidth: 240,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          color: Colors.black12,
          child: const Icon(Icons.broken_image),
        ),
      ),
    ),
  );
}

class PhotoViewer extends StatelessWidget {
  final List<String> names;
  final int index;
  const PhotoViewer({super.key, required this.names, this.index = 0});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: PageView.builder(
        controller: PageController(initialPage: index),
        itemCount: names.length,
        itemBuilder: (_, i) => InteractiveViewer(
          child: Center(child: Image.file(File(p.join(_pp, names[i])))),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- بيانات
class Stat {
  final int count;
  final double sum;
  const Stat(this.count, this.sum);
}

class Invoice {
  int? id;
  String title;
  double? amount;
  String note;
  List<String> photos;

  Invoice({
    this.id,
    required this.title,
    this.amount,
    this.note = '',
    this.photos = const <String>[],
  });

  factory Invoice.fromMap(Map<String, Object?> m) {
    final ph = (m['photos'] as String?) ?? '';
    return Invoice(
      id: m['id'] as int?,
      title: (m['title'] as String?) ?? '',
      amount: (m['amount'] as num?)?.toDouble(),
      note: (m['note'] as String?) ?? '',
      photos: ph.isEmpty ? <String>[] : ph.split('|'),
    );
  }
}

Future<Map<int, Stat>> loadStats(
    String col, String where, List<Object?> args) async {
  final d = await Db.instance;
  final rows = await d.rawQuery(
    'SELECT $col AS k, COUNT(*) AS c, COALESCE(SUM(amount), 0) AS s '
    'FROM invoices WHERE $where GROUP BY $col',
    args,
  );
  return {
    for (final r in rows)
      (r['k'] as int): Stat(r['c'] as int, (r['s'] as num).toDouble()),
  };
}
