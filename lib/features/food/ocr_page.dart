/// What a text recogniser saw on a photo: lines and words with their boxes.
/// Pure Dart: no Flutter or DB imports, so the layout reader can be tested
/// on recorded pages.
library;

/// An axis-aligned box in image pixels (y grows downwards).
class OcrBox {
  const OcrBox(this.left, this.top, this.right, this.bottom);

  factory OcrBox.fromJson(List<dynamic> j) => OcrBox(
    (j[0] as num).toDouble(),
    (j[1] as num).toDouble(),
    (j[2] as num).toDouble(),
    (j[3] as num).toDouble(),
  );

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;
  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;

  List<double> toJson() => [left, top, right, bottom];
}

/// One recognised word (or number) and where it sits.
class OcrWord {
  const OcrWord(this.text, this.box);

  factory OcrWord.fromJson(Map<String, dynamic> j) =>
      OcrWord(j['t'] as String, OcrBox.fromJson(j['b'] as List<dynamic>));

  final String text;
  final OcrBox box;

  Map<String, dynamic> toJson() => {'t': text, 'b': box.toJson()};
}

/// One recognised line of text. [words] is empty when the source had no boxes.
class OcrLine {
  const OcrLine(this.text, {this.box, this.words = const []});

  factory OcrLine.fromJson(Map<String, dynamic> j) => OcrLine(
    j['t'] as String,
    box: j['b'] == null ? null : OcrBox.fromJson(j['b'] as List<dynamic>),
    words: [
      for (final w in (j['w'] as List<dynamic>? ?? const []))
        OcrWord.fromJson(w as Map<String, dynamic>),
    ],
  );

  final String text;
  final OcrBox? box;
  final List<OcrWord> words;

  Map<String, dynamic> toJson() => {
    't': text,
    if (box != null) 'b': box!.toJson(),
    if (words.isNotEmpty) 'w': [for (final w in words) w.toJson()],
  };
}

/// Everything recognised on one photo.
class OcrPage {
  const OcrPage(this.lines);

  /// A page made of plain text, with no boxes (tests, other engines).
  factory OcrPage.fromText(String text) =>
      OcrPage([for (final l in text.split('\n')) OcrLine(l)]);

  factory OcrPage.fromJson(Map<String, dynamic> j) => OcrPage([
    for (final l in (j['lines'] as List<dynamic>))
      OcrLine.fromJson(l as Map<String, dynamic>),
  ]);

  final List<OcrLine> lines;

  /// The plain text, one recognised line per row.
  String get text => lines.map((l) => l.text).join('\n');

  Map<String, dynamic> toJson() => {
    'lines': [for (final l in lines) l.toJson()],
  };
}
