import 'package:flutter/material.dart';
import 'calculator_tools.dart';

class CalculatorTab extends StatefulWidget {
  const CalculatorTab({super.key});

  @override
  State<CalculatorTab> createState() => _CalculatorTabState();
}

class _CalculatorTabState extends State<CalculatorTab> {
  int _mode = 0; // 0 = حاسبة, 1 = تحويل وحدات

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('حاسبة')),
              ButtonSegment(value: 1, label: Text('تحويل وحدات')),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
        ),
        Expanded(child: _mode == 0 ? const _Calculator() : const _Converter()),
      ],
    );
  }
}

// ---------------------------------------------------------------- الآلة الحاسبة
class _Calculator extends StatefulWidget {
  const _Calculator();

  @override
  State<_Calculator> createState() => _CalculatorState();
}

class _CalculatorState extends State<_Calculator> {
  String _expr = '';
  String _result = '';
  bool _sci = false;
  bool _rad = false;
  bool _err = false;

  void _tap(String t) => setState(() {
        _expr += t;
        _err = false;
      });

  void _clear() => setState(() {
        _expr = '';
        _result = '';
        _err = false;
      });

  void _back() => setState(() {
        if (_expr.isNotEmpty) _expr = _expr.substring(0, _expr.length - 1);
        _err = false;
      });

  void _eval() {
    try {
      final v = evalExpression(_expr, radians: _rad);
      setState(() {
        _result = _fmt(v);
        _err = false;
      });
    } on CalcError catch (e) {
      setState(() {
        _result = e.message;
        _err = true;
      });
    } catch (e) {
      setState(() {
        _result = 'معادلة غير صحيحة';
        _err = true;
      });
    }
  }

  String _fmt(double v) {
    if (v == v.roundToDouble() && v.abs() < 1e15) {
      return v.toStringAsFixed(0);
    }
    var s = v.toStringAsPrecision(10);
    if (s.contains('.')) {
      s = s.replaceFirst(RegExp(r'0+$'), '');
      s = s.replaceFirst(RegExp(r'\.$'), '');
    }
    return s;
  }

  void _square() => setState(() => _expr = '($_expr)^2');
  void _inverse() => setState(() => _expr = '1/($_expr)');

  Widget _btn(String label, {VoidCallback? onTap, Color? bg, Color? fg}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Material(
          color: bg ?? Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap ?? () => _tap(label),
            child: Center(
              child: FittedBox(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: fg)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(List<Widget> children) => Expanded(child: Row(children: children));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: Row(
            children: [
              FilterChip(
                label: const Text('علمي'),
                selected: _sci,
                onSelected: (v) => setState(() => _sci = v),
              ),
              const SizedBox(width: 8),
              if (_sci)
                FilterChip(
                  label: Text(_rad ? 'راديان' : 'درجة'),
                  selected: _rad,
                  onSelected: (v) => setState(() => _rad = v),
                ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_expr.isEmpty ? '0' : _expr,
                  style: const TextStyle(fontSize: 18),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(_result,
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: _err ? Colors.red : cs.primary)),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Column(
              children: [
                if (_sci) ...[
                  _row([
                    _btn('sin', onTap: () => _tap('sin(')),
                    _btn('cos', onTap: () => _tap('cos(')),
                    _btn('tan', onTap: () => _tap('tan(')),
                    _btn('√', onTap: () => _tap('sqrt(')),
                  ]),
                  _row([
                    _btn('log', onTap: () => _tap('log(')),
                    _btn('ln', onTap: () => _tap('ln(')),
                    _btn('π', onTap: () => _tap('π')),
                    _btn('e', onTap: () => _tap('e')),
                  ]),
                  _row([
                    _btn('x²', onTap: _square),
                    _btn('1/x', onTap: _inverse),
                    _btn('^', onTap: () => _tap('^')),
                    _btn('%', onTap: () => _tap('%')),
                  ]),
                ],
                _row([
                  _btn('C',
                      onTap: _clear,
                      bg: Colors.red.shade100,
                      fg: Colors.red.shade900),
                  _btn('⌫', onTap: _back),
                  _btn('(', onTap: () => _tap('(')),
                  _btn(')', onTap: () => _tap(')')),
                ]),
                _row([
                  _btn('7'),
                  _btn('8'),
                  _btn('9'),
                  _btn('÷', onTap: () => _tap('/'), fg: cs.primary),
                ]),
                _row([
                  _btn('4'),
                  _btn('5'),
                  _btn('6'),
                  _btn('×', onTap: () => _tap('*'), fg: cs.primary),
                ]),
                _row([
                  _btn('1'),
                  _btn('2'),
                  _btn('3'),
                  _btn('−', onTap: () => _tap('-'), fg: cs.primary),
                ]),
                _row([
                  _btn('0'),
                  _btn('.'),
                  _btn('=', onTap: _eval, bg: cs.primary, fg: Colors.white),
                  _btn('+', fg: cs.primary),
                ]),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- تحويل الوحدات
class _Converter extends StatefulWidget {
  const _Converter();

  @override
  State<_Converter> createState() => _ConverterState();
}

class _ConverterState extends State<_Converter> {
  static const _tempIndex = -1;
  int _cat = 0;
  String? _from;
  String? _to;
  final _input = TextEditingController(text: '1');
  String _output = '';

  @override
  void initState() {
    super.initState();
    _resetUnits();
    _convert();
  }

  void _resetUnits() {
    if (_cat == _tempIndex) {
      _from = tempUnits[0];
      _to = tempUnits[1];
    } else {
      final keys = unitCategories[_cat].units.keys.toList();
      _from = keys[0];
      _to = keys.length > 1 ? keys[1] : keys[0];
    }
  }

  void _convert() {
    final v = double.tryParse(_input.text.trim());
    if (v == null || _from == null || _to == null) {
      setState(() => _output = '');
      return;
    }
    double r;
    if (_cat == _tempIndex) {
      r = convertTemp(v, _from!, _to!);
    } else {
      final u = unitCategories[_cat].units;
      r = convertUnit(v, u[_from]!, u[_to]!);
    }
    setState(() {
      _output = r == r.roundToDouble()
          ? r.toStringAsFixed(0)
          : r
              .toStringAsPrecision(8)
              .replaceFirst(RegExp(r'0+$'), '')
              .replaceFirst(RegExp(r'\.$'), '');
    });
  }

  @override
  Widget build(BuildContext context) {
    final names = [for (final c in unitCategories) c.name, 'الحرارة'];
    final units =
        _cat == _tempIndex ? tempUnits : unitCategories[_cat].units.keys.toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < names.length; i++)
              ChoiceChip(
                label: Text(names[i]),
                selected: (i == names.length - 1 ? _tempIndex : i) == _cat,
                onSelected: (_) => setState(() {
                  _cat = i == names.length - 1 ? _tempIndex : i;
                  _resetUnits();
                  _convert();
                }),
              ),
          ],
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _input,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => _convert(),
          decoration: const InputDecoration(
            labelText: 'القيمة',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _from,
              decoration: const InputDecoration(
                  labelText: 'من', border: OutlineInputBorder()),
              items: [
                for (final u in units) DropdownMenuItem(value: u, child: Text(u))
              ],
              onChanged: (v) => setState(() {
                _from = v;
                _convert();
              }),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            onPressed: () => setState(() {
              final t = _from;
              _from = _to;
              _to = t;
              _convert();
            }),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _to,
              decoration: const InputDecoration(
                  labelText: 'إلى', border: OutlineInputBorder()),
              items: [
                for (final u in units) DropdownMenuItem(value: u, child: Text(u))
              ],
              onChanged: (v) => setState(() {
                _to = v;
                _convert();
              }),
            ),
          ),
        ]),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            _output.isEmpty ? '—' : '$_output ${_to ?? ''}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
