
import 'package:flutter/foundation.dart';
import 'package:video_compress/video_compress.dart';

/// Storage accepts files up to 50 MB; people may pick videos up to 250 MB.
const maxUploadBytes = 50 * 1024 * 1024;
const maxPickVideoBytes = 250 * 1024 * 1024;

/// Shrinks a picked video on Android/iOS so it fits under [maxUploadBytes].
/// Tries 720p first and falls back to a smaller size. Returns null if it
/// still doesn't fit or compression isn't available (web).
Future<Uint8List?> compressVideo(String path) async {
  if (kIsWeb) return null;
  for (final q in [VideoQuality.Res1280x720Quality, VideoQuality.Res960x540Quality, VideoQuality.Res640x480Quality]) {
    try {
      final info = await VideoCompress.compressVideo(path, quality: q, deleteOrigin: false, includeAudio: true);
      final file = info?.file;
      if (file == null) continue;
      final bytes = await file.readAsBytes();
      if (bytes.length <= maxUploadBytes) return bytes;
    } catch (_) {
      return null;
    }
  }
  return null;
}
