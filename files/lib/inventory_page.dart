import 'package:flutter/material.dart';
import 'inventory_sheet.dart';
import 'inventory_utils.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  List<InvItem> _items = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await InvDb.all(query: _query);
    if (mounted) setState(() => _items = list);
  }

  Future<void> _delete(InvItem it) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الصنف؟'),
        content: Text('${it.name}\nهيتحذف سجل حركاته كمان.'),
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
    if (ok == true && it.id != null) {
      await InvDb.delete(it.id!);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lowCount = _items.where((i) => i.low).length;
    return Scaffold(
      appBar: AppBar(title: const Text('الجرد')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await openItemSheet(context);
          _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('صنف جديد'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: TextField(
              onChanged: (v) {
                _query = v;
                _load();
              },
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'ابحث عن صنف',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          if (lowCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('⚠️ $lowCount صنف وصل للحد الأدنى',
                    style: TextStyle(
                        color: Colors.red.shade800,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          Expanded(
            child: _items.isEmpty
                ? const Center(child: Text('لسه مفيش أصناف في الجرد'))
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 90),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final it = _items[i];
                      return ListTile(
                        title: Text(it.name),
                        subtitle: Text(it.category.isEmpty
                            ? it.unit
                            : '${it.category} • ${it.unit}'),
                        trailing: Text(
                          '${it.quantity == it.quantity.roundToDouble() ? it.quantity.toStringAsFixed(0) : it.quantity.toStringAsFixed(2)} ${it.unit}',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: it.low ? Colors.red : null),
                        ),
                        onTap: () async {
                          await openAdjustSheet(context, it);
                          _load();
                        },
                        onLongPress: () => showModalBottomSheet(
                          context: context,
                          builder: (ctx) => SafeArea(
                            child: Wrap(children: [
                              ListTile(
                                leading: const Icon(Icons.edit),
                                title: const Text('تعديل بيانات الصنف'),
                                onTap: () async {
                                  Navigator.pop(ctx);
                                  await openItemSheet(context, it);
                                  _load();
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.delete_outline),
                                title: const Text('حذف'),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _delete(it);
                                },
                              ),
                            ]),
                          ),
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
