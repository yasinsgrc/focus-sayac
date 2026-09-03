import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../features/story_card/widgets/story_card_view.dart';

final Provider<StoryCardExporter> storyCardExporterProvider = Provider<StoryCardExporter>((Ref ref) {
  return const StoryCardExporter();
});

/// Ekran 05'in üç aksiyonunun sonucu. Ekran bunları kullanıcıya farklı
/// mesajlarla gösteriyor — özellikle [permissionDenied], "kaydedilemedi"
/// ile aynı şey değil (kullanıcının yapabileceği bir şey var).
enum StoryCardExportResult { success, permissionDenied, failed }

/// Başarı kartını PNG'ye çevirip paylaşan/kaydeden/kopyalayan servis
/// (SPEC.md Ekran 05: `share_plus` / `gal` / `pasteboard`).
///
/// Metotlar `Riverpod` üzerinden geldiği ve sanal olduğu için testlerde alt
/// sınıfla değiştirilebiliyor: eklenti kanalı olmayan koşumlarda gerçek
/// paylaşım sayfasını açmaya çalışmak yerine sahte bir uygulayıcı kullanılır.
class StoryCardExporter {
  const StoryCardExporter();

  /// Paylaşılan/kaydedilen dosyanın adı. `Gal.putImageBytes` adı uzantısız
  /// istediği için uzantı yalnızca paylaşımda ekleniyor.
  static const String fileBaseName = 'focussayac-basari-karti';

  /// [boundaryKey]'in gösterdiği `RepaintBoundary`yi tam **1080×1920** PNG'ye
  /// çevirir (SPEC.md Ekran 05 DoD).
  Future<Uint8List?> capturePng(GlobalKey boundaryKey) async {
    final RenderObject? renderObject = boundaryKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) return null;

    final ui.Image image = await renderObject.toImage(pixelRatio: kStoryCardExportPixelRatio);
    try {
      final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  Future<StoryCardExportResult> share(GlobalKey boundaryKey) async {
    final Uint8List? bytes = await capturePng(boundaryKey);
    if (bytes == null) return StoryCardExportResult.failed;
    try {
      // `share_plus` bayt değil dosya paylaşıyor; geçici dizin sistem
      // tarafından temizlendiği için ayrıca silmeye gerek yok.
      final Directory directory = await getTemporaryDirectory();
      final File file = File('${directory.path}/$fileBaseName.png');
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(
        ShareParams(files: <XFile>[XFile(file.path, mimeType: 'image/png')]),
      );
      return StoryCardExportResult.success;
    } on PlatformException {
      return StoryCardExportResult.failed;
    } on MissingPluginException {
      return StoryCardExportResult.failed;
    } on FileSystemException {
      return StoryCardExportResult.failed;
    }
  }

  Future<StoryCardExportResult> saveToGallery(GlobalKey boundaryKey) async {
    final Uint8List? bytes = await capturePng(boundaryKey);
    if (bytes == null) return StoryCardExportResult.failed;
    try {
      if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
        return StoryCardExportResult.permissionDenied;
      }
      await Gal.putImageBytes(bytes, name: fileBaseName);
      return StoryCardExportResult.success;
    } on GalException catch (error) {
      return error.type == GalExceptionType.accessDenied
          ? StoryCardExportResult.permissionDenied
          : StoryCardExportResult.failed;
    } on PlatformException {
      return StoryCardExportResult.failed;
    } on MissingPluginException {
      return StoryCardExportResult.failed;
    }
  }

  Future<StoryCardExportResult> copyToClipboard(GlobalKey boundaryKey) async {
    final Uint8List? bytes = await capturePng(boundaryKey);
    if (bytes == null) return StoryCardExportResult.failed;
    try {
      await Pasteboard.writeImage(bytes);
      return StoryCardExportResult.success;
    } on PlatformException {
      return StoryCardExportResult.failed;
    } on MissingPluginException {
      return StoryCardExportResult.failed;
    }
  }
}
