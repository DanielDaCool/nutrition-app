/// Text normalization shared by the food matcher and the unit weights:
/// lowercase tokens, common spelling variants, singular forms.
///
/// Pure Dart: no Flutter or DB imports.
library;

import 'meal_text_parser.dart';

/// Spelling variants and run-together words, mapped to one form.
const Map<String, String> _variants = {
  'humus': 'hummus',
  'houmous': 'hummus',
  'houmus': 'hummus',
  'hommus': 'hummus',
  'hoummus': 'hummus',
  'chumus': 'hummus',
  'pitta': 'pita',
  'pitah': 'pita',
  'yoghurt': 'yogurt',
  'yoghourt': 'yogurt',
  'yogourt': 'yogurt',
  'yogurth': 'yogurt',
  'tehina': 'tahini',
  'tahina': 'tahini',
  'tchina': 'tahini',
  'labneh': 'labaneh',
  'labne': 'labaneh',
  'labane': 'labaneh',
  'lebaneh': 'labaneh',
  'labana': 'labaneh',
  'omelet': 'omelette',
  'omlet': 'omelette',
  'omlette': 'omelette',
  'shakshouka': 'shakshuka',
  'chakchouka': 'shakshuka',
  'shnitzel': 'schnitzel',
  'shnitsel': 'schnitzel',
  'felafel': 'falafel',
  'tomatoe': 'tomato',
  'potatoe': 'potato',
  'wholewheat': 'whole wheat',
  'wholegrain': 'whole grain',
  'peanutbutter': 'peanut butter',
  'icecream': 'ice cream',
  'hotdog': 'hot dog',
  'cornflakes': 'cornflake',
  'mayo': 'mayonnaise',
  'coke': 'cola',
  'veggie': 'vegetable',
  'veg': 'vegetable',
  'choc': 'chocolate',
  'avo': 'avocado',
};

/// Words that don't tell foods apart.
const _stopwords = {
  'of',
  'with',
  'and',
  'the',
  'a',
  'an',
  'in',
  'on',
  'for',
  'or',
  'my',
  'some',
};

final _nonWord = RegExp(r'[^a-z0-9%.\u0590-\u05ff]+');
final _percent = RegExp(r'^\d+(?:\.\d+)?%$');

/// Normalized word tokens of [text]: "Cottage Cheese, 5%" -> [cottage,
/// cheese, 5%]; "Eggs" -> [egg]; "houmous" -> [hummus].
List<String> foodTokens(String text) {
  final out = <String>[];
  final cleaned = text
      .toLowerCase()
      .replaceAll(',', ' ')
      .replaceAll(_nonWord, ' ');
  for (var raw in cleaned.split(' ')) {
    raw = raw.replaceAll(RegExp(r'^\.+|\.+$'), '');
    if (raw.isEmpty || _stopwords.contains(raw)) continue;
    final v = _variants[raw] ?? _variants[singularize(raw)];
    if (v != null) {
      out.addAll(v.split(' '));
      continue;
    }
    out.add(_percent.hasMatch(raw) ? raw : singularize(raw));
  }
  return out;
}

/// True for tokens like "5%" or "1.5%".
bool isPercentToken(String token) => _percent.hasMatch(token);

/// The tokens of [text] joined by spaces; used as the key for learned names.
String normalizePhrase(String text) => foodTokens(text).join(' ');
