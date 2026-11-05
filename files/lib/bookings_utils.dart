import 'data.dart';

const orderMonths = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
];

String orderMoney(double v) {
  final s = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  return '$s ج.م';
}

// ---------------------------------------------------------------- بيانات
class OrderEntry {
  int? id;
  String type; // poultry / medicine
  String title;
  double quantity;
  String unit;
  double officePrice;
  double publicPrice;
  String note;

  OrderEntry({
    this.id,
    required this.type,
    this.title = '',
    required this.quantity,
    required this.unit,
    required this.officePrice,
    required this.publicPrice,
    this.note = '',
  });

  double get totalOffice => quantity * officePrice;
  double get totalPublic => quantity * publicPrice;
  double get profit => totalPublic - totalOffice;
  double get profitPercent =>
      officePrice == 0 ? 0 : (publicPrice - officePrice) / officePrice * 100;

  factory OrderEntry.fromMap(Map<String, Object?> m) => OrderEntry(
        id: m['id'] as int?,
        type: (m['type'] as String?) ?? 'poultry',
        title: (m['title'] as String?) ?? '',
        quantity: (m['quantity'] as num?)?.toDouble() ?? 0,
        unit: (m['unit'] as String?) ?? '',
        officePrice: (m['office_price'] as num?)?.toDouble() ?? 0,
        publicPrice: (m['public_price'] as num?)?.toDouble() ?? 0,
        note: (m['note'] as String?) ?? '',
      );

  Map<String, Object?> toMap(int y, int mo, int d) => {
        'year': y,
        'month': mo,
        'day': d,
        'type': type,
        'title': title,
        'quantity': quantity,
        'unit': unit,
        'office_price': officePrice,
        'public_price': publicPrice,
        'note': note,
      };
}

class OrderStat {
  final int count;
  final double profit;
  const OrderStat(this.count, this.profit);
}

Future<Map<int, OrderStat>> loadOrderStats(
    String col, String where, List<Object?> args) async {
  final d = await Db.instance;
  final rows = await d.rawQuery(
    'SELECT $col AS k, COUNT(*) AS c, '
    'COALESCE(SUM((public_price - office_price) * quantity), 0) AS p '
    'FROM orders WHERE $where GROUP BY $col',
    args,
  );
  return {
    for (final r in rows)
      (r['k'] as int): OrderStat(r['c'] as int, (r['p'] as num).toDouble()),
  };
}
