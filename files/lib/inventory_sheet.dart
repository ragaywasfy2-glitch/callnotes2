import 'package:flutter/material.dart';
import 'data.dart';
import 'inventory_utils.dart';

String _n(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

Future<void> openItemSheet(BuildContext context, [InvItem? existing]) async {
  final name = TextEditingController(text: existing?.name ?? '');
  final category = TextEditingController(text: existing?.category ?? '');
  final unit = TextEditingController(text: existing?.unit ?? 'قطعة');
  final qty =
      TextEditingController(text: existing == null ? '0' : _n(existing.quantity));
  final minAlert = TextEditingController(
      text: existing?.minAlert == null ? '' : _n(existing!.minAlert!));
  final price = TextEditingController(
      text: existing?.price == null ? '' : _n(existing!.price!));
  final note = TextEditingController(text: existing?.note ?? '');

  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'اسم الصنف'),
            ),
            TextField(
              controller: category,
              decoration: const InputDecoration(labelText: 'التصنيف (اختياري)'),
            ),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: unit,
                  decoration: const InputDecoration(labelText: 'الوحدة'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: qty,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  enabled: existing == null,
                  decoration: InputDecoration(
                      labelText: existing == null
                          ? 'الكمية الحالية'
                          : 'عدّل الكمية من شاشة الجرد'),
                ),
              ),
            ]),
            TextField(
              controller: minAlert,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  const InputDecoration(labelText: 'حد التنبيه الأدنى (اختياري)'),
            ),
            TextField(
              controller: price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  const InputDecoration(labelText: 'سعر الوحدة (اختياري)'),
            ),
            TextField(
              controller: note,
              decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
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

  if (saved != true || name.text.trim().isEmpty) return;
  await InvDb.save(InvItem(
    id: existing?.id,
    name: name.text.trim(),
    category: category.text.trim(),
    unit: unit.text.trim().isEmpty ? 'قطعة' : unit.text.trim(),
    quantity: existing == null
        ? (double.tryParse(latin(qty.text.trim())) ?? 0)
        : existing.quantity,
    minAlert: double.tryParse(latin(minAlert.text.trim())),
    price: double.tryParse(latin(price.text.trim())),
    note: note.text.trim(),
  ));
}

Future<void> openAdjustSheet(BuildContext context, InvItem item) async {
  final amount = TextEditingController();
  final note = TextEditingController();
  var moves = await InvDb.moves(item.id!);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        Future<void> apply(double sign) async {
          final v = double.tryParse(latin(amount.text.trim())) ?? 0;
          if (v == 0 || item.id == null) return;
          await InvDb.adjust(item.id!, v * sign, note.text.trim());
          final fresh = await InvDb.moves(item.id!);
          final items = await InvDb.all();
          final updated =
              items.firstWhere((x) => x.id == item.id, orElse: () => item);
          setS(() {
            item.quantity = updated.quantity;
            moves = fresh;
            amount.clear();
            note.clear();
          });
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                Text('الكمية الحالية: ${_n(item.quantity)} ${item.unit}',
                    style: TextStyle(
                        fontSize: 16,
                        color: item.low ? Colors.red : Colors.teal,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'الكمية'),
                ),
                TextField(
                  controller: note,
                  decoration:
                      const InputDecoration(labelText: 'سبب الحركة (اختياري)'),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => apply(1),
                      icon: const Icon(Icons.add),
                      label: const Text('وارد'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => apply(-1),
                      icon: const Icon(Icons.remove),
                      label: const Text('منصرف'),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                const Text('آخر الحركات',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                if (moves.isEmpty)
                  const Text('مفيش حركات لسه')
                else
                  ...moves.map((m) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(fmtDate(m.date)),
                            Text(
                              '${m.delta > 0 ? '+' : ''}${_n(m.delta)} ${item.unit}'
                              '${m.note.isEmpty ? '' : ' - ${m.note}'}',
                              style: TextStyle(
                                  color: m.delta >= 0
                                      ? Colors.green.shade700
                                      : Colors.red.shade700),
                            ),
                          ],
                        ),
                      )),
              ],
            ),
          ),
        );
      },
    ),
  );
}
