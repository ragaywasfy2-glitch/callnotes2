import 'package:flutter/material.dart';
import 'bookings_utils.dart';
import 'data.dart';

String _n(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

Future<void> editOrder(
  BuildContext context,
  int y,
  int m,
  int d, [
  OrderEntry? entry,
]) async {
  var type = entry?.type ?? 'poultry';
  var unit = entry?.unit ?? (type == 'poultry' ? 'كتكوت' : 'مل');
  final title = TextEditingController(text: entry?.title ?? '');
  final qty =
      TextEditingController(text: entry == null ? '' : _n(entry.quantity));
  final office =
      TextEditingController(text: entry == null ? '' : _n(entry.officePrice));
  final public =
      TextEditingController(text: entry == null ? '' : _n(entry.publicPrice));
  final note = TextEditingController(text: entry?.note ?? '');

  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        final q = double.tryParse(latin(qty.text)) ?? 0;
        final of = double.tryParse(latin(office.text)) ?? 0;
        final pu = double.tryParse(latin(public.text)) ?? 0;
        final profit = (pu - of) * q;
        final pct = of == 0 ? 0.0 : (pu - of) / of * 100;

        return Padding(
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(spacing: 8, children: [
                  ChoiceChip(
                    label: const Text('🐤 دواجن'),
                    selected: type == 'poultry',
                    onSelected: (_) => setS(() {
                      type = 'poultry';
                      unit = 'كتكوت';
                    }),
                  ),
                  ChoiceChip(
                    label: const Text('💊 دواء'),
                    selected: type == 'medicine',
                    onSelected: (_) => setS(() {
                      type = 'medicine';
                      unit = 'مل';
                    }),
                  ),
                ]),
                const SizedBox(height: 12),
                TextField(
                  controller: title,
                  decoration: const InputDecoration(
                      labelText: 'اسم العميل / وصف (اختياري)'),
                ),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: qty,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setS(() {}),
                      decoration: InputDecoration(
                          labelText:
                              type == 'poultry' ? 'عدد الكتاكيت' : 'الكمية'),
                    ),
                  ),
                  if (type == 'medicine') ...[
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: unit,
                      items: const [
                        DropdownMenuItem(value: 'مل', child: Text('مل')),
                        DropdownMenuItem(value: 'لتر', child: Text('لتر')),
                        DropdownMenuItem(value: 'علبة', child: Text('علبة')),
                        DropdownMenuItem(value: 'كيس', child: Text('كيس')),
                      ],
                      onChanged: (v) => setS(() => unit = v ?? unit),
                    ),
                  ],
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: office,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setS(() {}),
                      decoration:
                          const InputDecoration(labelText: 'سعر المكتب'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: public,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setS(() {}),
                      decoration:
                          const InputDecoration(labelText: 'سعر الجمهور'),
                    ),
                  ),
                ]),
                TextField(
                  controller: note,
                  decoration:
                      const InputDecoration(labelText: 'ملاحظات (اختياري)'),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color:
                        profit >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text('الربح: ${orderMoney(profit)}',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: profit >= 0
                                  ? Colors.green.shade800
                                  : Colors.red.shade800)),
                      Text('نسبة الربح: ${pct.toStringAsFixed(1)}%'),
                    ],
                  ),
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
        );
      },
    ),
  );

  if (saved != true) return;
  final q = double.tryParse(latin(qty.text)) ?? 0;
  final of = double.tryParse(latin(office.text)) ?? 0;
  final pu = double.tryParse(latin(public.text)) ?? 0;
  if (q == 0 && of == 0 && pu == 0 && title.text.trim().isEmpty) return;

  final row = OrderEntry(
    id: entry?.id,
    type: type,
    title: title.text.trim(),
    quantity: q,
    unit: unit,
    officePrice: of,
    publicPrice: pu,
    note: note.text.trim(),
  ).toMap(y, m, d);

  final db = await Db.instance;
  if (entry == null || entry.id == null) {
    await db.insert('orders', row);
  } else {
    await db.update('orders', row, where: 'id = ?', whereArgs: [entry.id]);
  }
}
