import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'data.dart';
import 'invoice_utils.dart';

// ---------------------------------------------------------------- إضافة / تعديل فاتورة
Future<void> editInvoice(
  BuildContext context,
  int y,
  int m,
  int d, [
  Invoice? inv,
]) async {
  await photosDir();
  final title = TextEditingController(text: inv?.title ?? '');
  final amount = TextEditingController(
      text: inv?.amount == null ? '' : numStr(inv!.amount!));
  final note = TextEditingController(text: inv?.note ?? '');
  final photos = List<String>.from(inv?.photos ?? const <String>[]);
  final added = <String>[];
  final picker = ImagePicker();

  Future<void> add(ImageSource src, void Function() refresh) async {
    try {
      final dir = await photosDir();
      final files = <XFile>[];
      if (src == ImageSource.camera) {
        final x = await picker.pickImage(
            source: src, imageQuality: 80, maxWidth: 1600);
        if (x != null) files.add(x);
      } else {
        files.addAll(
            await picker.pickMultiImage(imageQuality: 80, maxWidth: 1600));
      }
      for (final x in files) {
        final name =
            '${DateTime.now().microsecondsSinceEpoch}_${photos.length}.jpg';
        await File(x.path).copy(p.join(dir.path, name));
        photos.add(name);
        added.add(name);
      }
      refresh();
    } catch (e) {
      // تجاهل
    }
  }

  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration:
                    const InputDecoration(labelText: 'اسم / وصف الفاتورة'),
              ),
              TextField(
                controller: amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    const InputDecoration(labelText: 'المبلغ (اختياري)'),
              ),
              TextField(
                controller: note,
                maxLines: 3,
                decoration:
                    const InputDecoration(labelText: 'ملاحظات (اختياري)'),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final n in photos)
                    Stack(children: [
                      thumb(n, size: 80),
                      Positioned(
                        top: 0,
                        left: 0,
                        child: GestureDetector(
                          onTap: () => setS(() => photos.remove(n)),
                          child: const CircleAvatar(
                            radius: 11,
                            backgroundColor: Colors.red,
                            child: Icon(Icons.close,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ]),
                ],
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.photo_library),
                    label: const Text('من المعرض'),
                    onPressed: () => add(ImageSource.gallery, () => setS(() {})),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('كاميرا'),
                    onPressed: () => add(ImageSource.camera, () => setS(() {})),
                  ),
                ),
              ]),
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
    ),
  );

  if (saved != true) {
    for (final n in added) {
      await deletePhoto(n);
    }
    return;
  }
  final amt = double.tryParse(latin(amount.text.trim()).replaceAll(',', '.'));
  if (title.text.trim().isEmpty &&
      amt == null &&
      note.text.trim().isEmpty &&
      photos.isEmpty) {
    return;
  }
  for (final n in (inv?.photos ?? const <String>[])) {
    if (!photos.contains(n)) await deletePhoto(n);
  }
  final row = <String, Object?>{
    'year': y,
    'month': m,
    'day': d,
    'title': title.text.trim().isEmpty ? 'فاتورة' : title.text.trim(),
    'amount': amt,
    'note': note.text.trim(),
    'photos': photos.join('|'),
  };
  final db = await Db.instance;
  if (inv == null || inv.id == null) {
    await db.insert('invoices', row);
  } else {
    await db.update('invoices', row, where: 'id = ?', whereArgs: [inv.id]);
  }
}
