import 'data.dart';

class InvItem {
  int? id;
  String name;
  String category;
  String unit;
  double quantity;
  double? minAlert;
  double? price;
  String note;

  InvItem({
    this.id,
    required this.name,
    this.category = '',
    this.unit = 'قطعة',
    this.quantity = 0,
    this.minAlert,
    this.price,
    this.note = '',
  });

  bool get low => minAlert != null && quantity <= minAlert!;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'category': category,
        'unit': unit,
        'quantity': quantity,
        'min_alert': minAlert,
        'price': price,
        'note': note,
      };

  factory InvItem.fromMap(Map<String, Object?> m) => InvItem(
        id: m['id'] as int?,
        name: (m['name'] as String?) ?? '',
        category: (m['category'] as String?) ?? '',
        unit: (m['unit'] as String?) ?? 'قطعة',
        quantity: (m['quantity'] as num?)?.toDouble() ?? 0,
        minAlert: (m['min_alert'] as num?)?.toDouble(),
        price: (m['price'] as num?)?.toDouble(),
        note: (m['note'] as String?) ?? '',
      );
}

class InvMove {
  final int? id;
  final int itemId;
  final String date;
  final double delta;
  final String note;
  const InvMove({
    this.id,
    required this.itemId,
    required this.date,
    required this.delta,
    this.note = '',
  });

  factory InvMove.fromMap(Map<String, Object?> m) => InvMove(
        id: m['id'] as int?,
        itemId: m['item_id'] as int,
        date: (m['date'] as String?) ?? '',
        delta: (m['delta'] as num?)?.toDouble() ?? 0,
        note: (m['note'] as String?) ?? '',
      );
}

class InvDb {
  static Future<List<InvItem>> all({String query = ''}) async {
    final d = await Db.instance;
    final rows = query.isEmpty
        ? await d.query('inventory_items', orderBy: 'name')
        : await d.query('inventory_items',
            where: 'name LIKE ?', whereArgs: ['%$query%'], orderBy: 'name');
    return rows.map(InvItem.fromMap).toList();
  }

  static Future<int> save(InvItem it) async {
    final d = await Db.instance;
    if (it.id == null) return d.insert('inventory_items', it.toMap());
    await d.update('inventory_items', it.toMap(),
        where: 'id = ?', whereArgs: [it.id]);
    return it.id!;
  }

  static Future<void> delete(int id) async {
    final d = await Db.instance;
    await d.delete('inventory_moves', where: 'item_id = ?', whereArgs: [id]);
    await d.delete('inventory_items', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> adjust(int itemId, double delta, String note) async {
    final d = await Db.instance;
    await d.insert('inventory_moves', {
      'item_id': itemId,
      'date': isoOf(DateTime.now()),
      'delta': delta,
      'note': note,
    });
    await d.rawUpdate(
        'UPDATE inventory_items SET quantity = quantity + ? WHERE id = ?',
        [delta, itemId]);
  }

  static Future<List<InvMove>> moves(int itemId) async {
    final d = await Db.instance;
    final rows = await d.query('inventory_moves',
        where: 'item_id = ?',
        whereArgs: [itemId],
        orderBy: 'id DESC',
        limit: 30);
    return rows.map(InvMove.fromMap).toList();
  }
}
