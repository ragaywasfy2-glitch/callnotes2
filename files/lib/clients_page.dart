import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'data.dart';

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> with WidgetsBindingObserver {
  List<Booking> _items = [];
  String _query = '';
  bool _onlyFollow = false;
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
    if (state == AppLifecycleState.resumed) {
      _checkPerms();
      _reload();
    }
  }

  void _snack(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
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
      await Permission.systemAlertWindow.request();
    }
    _checkPerms();
  }

  // ------------------------------------------------------------ نسخ احتياطي
  Future<void> _menu(String v) async {
    if (v == 'export') {
      final text = await Db.exportJson();
      await Clipboard.setData(ClipboardData(text: text));
      _snack('اتنسخت النسخة الاحتياطية. الصقها في ملاحظة أو رسالة لنفسك');
      return;
    }
    final clip = await Clipboard.getData('text/plain');
    final c = TextEditingController(text: clip?.text ?? '');
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('استرجاع نسخة احتياطية'),
        content: TextField(
          controller: c,
          maxLines: 6,
          decoration: const InputDecoration(hintText: 'الصق النسخة هنا'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('استرجاع')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final n = await Db.importJson(c.text.trim());
      _snack('اتضاف $n حجز جديد');
      _reload();
    } catch (e) {
      _snack('النسخة دي مش صالحة');
    }
  }

  // ------------------------------------------------------------ واتساب
  Future<void> _whatsapp(Booking b) async {
    try {
      final ok = await channel.invokeMethod<bool>('openWhatsApp', {
        'phone': waNumber(b.phone),
        'text': 'أهلاً ${b.name} 👋',
      });
      if (ok != true) _snack('مقدرتش أفتح واتساب');
    } catch (e) {
      _snack('مقدرتش أفتح واتساب');
    }
  }

  // ------------------------------------------------------------ تعديل / إضافة
  Future<void> _edit([Booking? b]) async {
    final name = TextEditingController(text: b?.name ?? '');
    final phone = TextEditingController(text: b?.phone ?? '');
    final notes = TextEditingController(text: b?.notes ?? '');
    final warn = TextEditingController(text: b?.warn ?? '');
    var date = b?.date ?? isoOf(DateTime.now());
    String? followUp = b?.followUp;
    var rating = b?.rating ?? 'none';

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
                  controller: name,
                  decoration: const InputDecoration(labelText: 'الاسم'),
                ),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      decoration:
                          const InputDecoration(labelText: 'رقم الموبايل'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.contacts),
                    tooltip: 'من جهات الاتصال',
                    onPressed: () async {
                      final c = await Navigator.push<Map<String, String>>(
                        ctx,
                        MaterialPageRoute(builder: (_) => const ContactsPage()),
                      );
                      if (c != null) {
                        setS(() {
                          name.text = c['name'] ?? '';
                          phone.text = c['phone'] ?? '';
                        });
                      }
                    },
                  ),
                ]),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
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
                ),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.alarm),
                      label: Text(followUp == null
                          ? 'تذكير متابعة: بدون'
                          : 'متابعة: ${fmtDate(followUp!)}'),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate:
                              DateTime.now().add(const Duration(days: 7)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) setS(() => followUp = isoOf(d));
                      },
                    ),
                  ),
                  if (followUp != null)
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setS(() => followUp = null),
                    ),
                ]),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  for (final r in const [
                    ['none', 'بدون تقييم'],
                    ['good', '⭐ ممتاز'],
                    ['bad', '⚠️ متعب'],
                  ])
                    ChoiceChip(
                      label: Text(r[1]),
                      selected: rating == r[0],
                      onSelected: (_) => setS(() => rating = r[0]),
                    ),
                ]),
                TextField(
                  controller: warn,
                  decoration: const InputDecoration(
                      labelText: 'تحذير يظهر وقت المكالمة (اختياري)'),
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
      ),
    );

    if (saved != true || phone.text.trim().isEmpty) return;
    final same = followUp == b?.followUp;
    final nb = Booking(
      id: b?.id,
      name: name.text.trim().isEmpty ? 'بدون اسم' : name.text.trim(),
      phone: phone.text.trim(),
      date: date,
      notes: notes.text.trim(),
      followUp: followUp,
      followDone: same ? (b?.followDone ?? false) : false,
      rating: rating,
      warn: warn.text.trim(),
    );
    nb.id = await Db.save(nb);
    await scheduleFollowUp(nb);
    _reload();
  }

  Future<void> _toggleDone(Booking b) async {
    if (b.id == null) return;
    await Db.setDone(b.id!, true);
    await cancelFollowUp(b.id!);
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
      await cancelFollowUp(b.id!);
      await Db.delete(b.id!);
      _reload();
    }
  }

  // ------------------------------------------------------------ الواجهة
  Widget _tile(Booking b) {
    final Widget icon = b.rating == 'good'
        ? const Icon(Icons.star, color: Colors.amber)
        : b.rating == 'bad'
            ? const Icon(Icons.warning_amber_rounded, color: Colors.red)
            : const Icon(Icons.person_outline);
    return ListTile(
      leading: icon,
      title: Text(b.name),
      isThreeLine: true,
      onTap: () => _edit(b),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${b.phone}\n${fmtDate(b.date)}'
              '${b.notes.isEmpty ? '' : ' • ${b.notes}'}'),
          if (b.warn.isNotEmpty)
            Text('⚠️ ${b.warn}', style: const TextStyle(color: Colors.red)),
          if (b.followPending)
            Text(
              '⏰ متابعة: ${fmtDate(b.followUp!)}',
              style: TextStyle(
                color: b.followDue ? Colors.red : Colors.teal,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          icon: const Icon(Icons.chat, color: Colors.green),
          onPressed: () => _whatsapp(b),
        ),
        PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'done') {
              _toggleDone(b);
            } else {
              _confirmDelete(b);
            }
          },
          itemBuilder: (_) => [
            if (b.followPending)
              const PopupMenuItem(value: 'done', child: Text('تمت المتابعة')),
            const PopupMenuItem(value: 'del', child: Text('حذف')),
          ],
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim();
    final pending = _items.where((x) => x.followPending).length;
    final shown = _items.where((x) {
      if (_onlyFollow && !x.followPending) return false;
      if (q.isEmpty) return true;
      return x.name.contains(q) || x.phone.contains(q);
    }).toList();
    if (_onlyFollow) {
      shown.sort((a, c) => a.followUp!.compareTo(c.followUp!));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('دليل العملاء'),
        actions: [
          PopupMenuButton<String>(
            onSelected: _menu,
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'export', child: Text('نسخ احتياطي (نسخ للحافظة)')),
              PopupMenuItem(value: 'import', child: Text('استرجاع نسخة (لصق)')),
            ],
          ),
        ],
      ),
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
                subtitle:
                    const Text('الهاتف + الإشعارات + الظهور فوق التطبيقات'),
                trailing: FilledButton(
                    onPressed: _askPerms, child: const Text('تفعيل')),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(children: [
              Expanded(
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
              const SizedBox(width: 8),
              FilterChip(
                label: Text('متابعات ($pending)'),
                selected: _onlyFollow,
                onSelected: (v) => setState(() => _onlyFollow = v),
              ),
            ]),
          ),
          Expanded(
            child: shown.isEmpty
                ? const Center(child: Text('مفيش حجوزات هنا'))
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 90),
                    itemCount: shown.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) => _tile(shown[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- اختيار من الجهات
class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  List<Map<String, String>> _all = [];
  String _q = '';
  bool _loading = true;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final st = await Permission.contacts.request();
      if (!st.isGranted) {
        if (mounted) {
          setState(() {
            _loading = false;
            _err = 'محتاج صلاحية جهات الاتصال';
          });
        }
        return;
      }
      final raw = await channel.invokeMethod<List<dynamic>>('readContacts') ??
          <dynamic>[];
      final seen = <String>{};
      final out = <Map<String, String>>[];
      for (final e in raw) {
        final m = Map<String, String>.from(e as Map);
        final k = keyOf(m['phone'] ?? '');
        if (k.isEmpty || !seen.add(k)) continue;
        out.add(m);
      }
      if (mounted) {
        setState(() {
          _all = out;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _err = 'حصل خطأ في قراءة الجهات';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.trim();
    final list = q.isEmpty
        ? _all
        : _all
            .where((m) =>
                (m['name'] ?? '').contains(q) || (m['phone'] ?? '').contains(q))
            .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('اختار من الجهات')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _err != null
              ? Center(child: Text(_err!))
              : Column(children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      onChanged: (v) => setState(() => _q = v),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'ابحث',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (_, i) => ListTile(
                        title: Text(list[i]['name'] ?? ''),
                        subtitle: Text(list[i]['phone'] ?? ''),
                        onTap: () => Navigator.pop(context, list[i]),
                      ),
                    ),
                  ),
                ]),
    );
  }
}
