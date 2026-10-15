// Turns a photo of a nutrition label into text, on the device.

import 'dart:ui' show Rect;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../ocr_page.dart';

/// Where the label photo comes from.
enum LabelPhotoSource { camera, gallery }

/// Takes or picks a photo and reads the text on it.
abstract class LabelTextReader {
  /// What was recognised in the photo, or null if the user cancelled.
  Future<OcrPage?> read(LabelPhotoSource source);
}

/// ML Kit text recognition (Latin script, bundled, works offline). It does
/// not read Hebrew letters, so on a Hebrew label only the numbers and any
/// English words come through.
class MlKitLabelTextReader implements LabelTextReader {
  @override
  Future<OcrPage?> read(LabelPhotoSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source == LabelPhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: 2400,
    );
    if (picked == null) return null;
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(picked.path),
      );
      return ocrPageFromMlKit(result);
    } finally {
      await recognizer.close();
    }
  }
}

/// Converts an ML Kit result into an [OcrPage] with every line and word box.
OcrPage ocrPageFromMlKit(RecognizedText result) {
  OcrBox box(Rect r) => OcrBox(r.left, r.top, r.right, r.bottom);
  return OcrPage([
    for (final block in result.blocks)
      for (final line in block.lines)
        OcrLine(
          line.text,
          box: box(line.boundingBox),
          words: [
            for (final e in line.elements) OcrWord(e.text, box(e.boundingBox)),
          ],
        ),
  ]);
}

final labelTextReaderProvider = Provider<LabelTextReader>(
  (ref) => MlKitLabelTextReader(),
);
