import 'dart:math' as math;

// ---------------------------------------------------------------- تقييم المعادلات
class CalcError implements Exception {
  final String message;
  CalcError(this.message);
}

double evalExpression(String input, {required bool radians}) {
  var expr = input.trim();
  if (expr.isEmpty) throw CalcError('فاضي');
  final open = '('.allMatches(expr).length;
  final close = ')'.allMatches(expr).length;
  if (close < open) expr += ')' * (open - close);
  final parser = _Parser(expr, radians);
  final v = parser.parseExpression();
  parser._skipSpace();
  if (parser._i != parser._s.length) throw CalcError('معادلة غير صحيحة');
  if (v.isNaN || v.isInfinite) throw CalcError('غير معرف');
  return v;
}

class _Parser {
  final String _s;
  final bool radians;
  int _i = 0;
  _Parser(this._s, this.radians);

  void _skipSpace() {
    while (_i < _s.length && _s[_i] == ' ') {
      _i++;
    }
  }

  bool _match(String c) {
    _skipSpace();
    if (_i < _s.length && _s[_i] == c) {
      _i++;
      return true;
    }
    return false;
  }

  double parseExpression() {
    var v = _parseTerm();
    while (true) {
      if (_match('+')) {
        v += _parseTerm();
      } else if (_match('-')) {
        v -= _parseTerm();
      } else {
        break;
      }
    }
    return v;
  }

  double _parseTerm() {
    var v = _parsePower();
    while (true) {
      if (_match('*') || _match('×')) {
        v *= _parsePower();
      } else if (_match('/') || _match('÷')) {
        final d = _parsePower();
        if (d == 0) throw CalcError('القسمة على صفر');
        v /= d;
      } else {
        break;
      }
    }
    return v;
  }

  double _parsePower() {
    final v = _parseUnary();
    if (_match('^')) {
      final e = _parsePower();
      return math.pow(v, e).toDouble();
    }
    return v;
  }

  double _parseUnary() {
    if (_match('-')) return -_parseUnary();
    if (_match('+')) return _parseUnary();
    return _parsePostfix();
  }

  double _parsePostfix() {
    var v = _parsePrimary();
    while (_match('%')) {
      v = v / 100;
    }
    return v;
  }

  double _parsePrimary() {
    _skipSpace();
    if (_i >= _s.length) throw CalcError('معادلة غير صحيحة');

    if (_match('(')) {
      final v = parseExpression();
      if (!_match(')')) throw CalcError('قوس ناقص');
      return v;
    }

    final start = _i;
    while (_i < _s.length && RegExp(r'[a-zA-Z]').hasMatch(_s[_i])) {
      _i++;
    }
    if (_i > start) {
      final name = _s.substring(start, _i);
      switch (name) {
        case 'sin':
        case 'cos':
        case 'tan':
          if (!_match('(')) throw CalcError('قوس ناقص');
          var a = parseExpression();
          if (!_match(')')) throw CalcError('قوس ناقص');
          if (!radians) a = a * math.pi / 180;
          return name == 'sin'
              ? math.sin(a)
              : name == 'cos'
                  ? math.cos(a)
                  : math.tan(a);
        case 'log':
          if (!_match('(')) throw CalcError('قوس ناقص');
          final a = parseExpression();
          if (!_match(')')) throw CalcError('قوس ناقص');
          if (a <= 0) throw CalcError('غير معرف');
          return math.log(a) / math.ln10;
        case 'ln':
          if (!_match('(')) throw CalcError('قوس ناقص');
          final a = parseExpression();
          if (!_match(')')) throw CalcError('قوس ناقص');
          if (a <= 0) throw CalcError('غير معرف');
          return math.log(a);
        case 'sqrt':
          if (!_match('(')) throw CalcError('قوس ناقص');
          final a = parseExpression();
          if (!_match(')')) throw CalcError('قوس ناقص');
          if (a < 0) throw CalcError('غير معرف');
          return math.sqrt(a);
        case 'e':
          return math.e;
        default:
          throw CalcError('غير معروف: $name');
      }
    }

    if (_s[_i] == 'π') {
      _i++;
      return math.pi;
    }

    final numStart = _i;
    while (_i < _s.length && RegExp(r'[0-9.]').hasMatch(_s[_i])) {
      _i++;
    }
    if (_i == numStart) throw CalcError('معادلة غير صحيحة');
    final v = double.tryParse(_s.substring(numStart, _i));
    if (v == null) throw CalcError('رقم غير صحيح');
    return v;
  }
}

// ---------------------------------------------------------------- تحويل الوحدات
class UnitCategory {
  final String name;
  final Map<String, double> units; // المعامل بالنسبة للوحدة الأساسية
  const UnitCategory(this.name, this.units);
}

const unitCategories = <UnitCategory>[
  UnitCategory('الطول', {
    'مم': 0.001,
    'سم': 0.01,
    'م': 1,
    'كم': 1000,
    'بوصة': 0.0254,
    'قدم': 0.3048,
    'ياردة': 0.9144,
    'ميل': 1609.344,
  }),
  UnitCategory('الوزن', {
    'مجم': 0.000001,
    'جم': 0.001,
    'كجم': 1,
    'طن': 1000,
    'رطل': 0.45359237,
    'أونصة': 0.028349523,
  }),
  UnitCategory('المساحة', {
    'م²': 1,
    'كم²': 1000000,
    'سم²': 0.0001,
    'فدان': 4200.83,
    'هكتار': 10000,
  }),
  UnitCategory('الحجم', {
    'مل': 0.001,
    'لتر': 1,
    'م³': 1000,
    'جالون': 3.78541,
  }),
  UnitCategory('السرعة', {
    'م/ث': 1,
    'كم/س': 0.2777778,
    'ميل/س': 0.44704,
  }),
];

double convertUnit(double value, double fromFactor, double toFactor) =>
    value * fromFactor / toFactor;

/// الحرارة مش علاقة خطية فاتعاملت لوحدها
double convertTemp(double v, String from, String to) {
  double c;
  switch (from) {
    case 'فهرنهايت':
      c = (v - 32) * 5 / 9;
      break;
    case 'كلفن':
      c = v - 273.15;
      break;
    default:
      c = v; // مئوية
  }
  switch (to) {
    case 'فهرنهايت':
      return c * 9 / 5 + 32;
    case 'كلفن':
      return c + 273.15;
    default:
      return c; // مئوية
  }
}

const tempUnits = ['مئوية', 'فهرنهايت', 'كلفن'];
