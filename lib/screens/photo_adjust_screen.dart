import 'dart:typed_data';

import '../util/app_language.dart';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../data/marketplace_image_picker.dart';
import '../data/marketplace_repository.dart' show kListingImageMaxBytes;

/// Switch for the adjuster step. Tests turn it off so a form test can pick a
/// photo and carry on; the app leaves it on.
class PhotoAdjust {
  static bool enabled = true;

  /// Opens the adjuster for [image] and returns the cropped photo, or null if
  /// the person cancelled. When the adjuster is off, returns [image] as is.
  static Future<PickedImage?> run(
    BuildContext? context,
    PickedImage image, {
    double aspectRatio = 3 / 2,
    bool circle = false,
  }) async {
    if (!enabled || context == null) return image;
    return Navigator.of(context).push<PickedImage>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PhotoAdjustScreen(
          image: image,
          aspectRatio: aspectRatio,
          circle: circle,
        ),
      ),
    );
  }
}

/// Lets the person move and zoom a just-chosen photo inside the frame it
/// will be shown in, so nothing important gets cut off. Saves what the frame
/// shows as a new PNG.
class PhotoAdjustScreen extends StatefulWidget {
  const PhotoAdjustScreen({
    super.key,
    required this.image,
    this.aspectRatio = 3 / 2,
    this.circle = false,
  });

  final PickedImage image;
  final double aspectRatio;
  final bool circle;

  @override
  State<PhotoAdjustScreen> createState() => _PhotoAdjustScreenState();
}

class _PhotoAdjustScreenState extends State<PhotoAdjustScreen> {
  final _boundary = GlobalKey();
  final _controller = TransformationController();
  bool _saving = false;
  String? _error;

  /// The photo must stay under the upload limit (2 MB), so the picture is
  /// saved at a modest size and shrunk further if needed.
  static const _targetWidth = 900.0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final box =
          _boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      var ratio = _targetWidth / box.size.width;
      Uint8List? out;
      for (var i = 0; i < 4; i++) {
        final img = await box.toImage(pixelRatio: ratio);
        final data = await img.toByteData(format: ui.ImageByteFormat.png);
        img.dispose();
        out = data?.buffer.asUint8List();
        if (out != null && out.length <= kListingImageMaxBytes) break;
        ratio *= 0.7;
      }
      if (out == null || out.length > kListingImageMaxBytes) {
        throw const ImagePickException('Foto terlalu besar. Pilih foto lain.');
      }
      final base = widget.image.name.contains('.')
          ? widget.image.name.substring(0, widget.image.name.lastIndexOf('.'))
          : widget.image.name;
      if (!mounted) return;
      Navigator.of(context).pop(PickedImage(name: '$base.png', bytes: out));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e is ImagePickException
            ? e.message
            : tr('Foto tidak bisa disimpan. Coba lagi.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Atur foto')),
        leading: TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(tr('Batal')),
        ),
        leadingWidth: 80,
        actions: [
          TextButton(
            key: const Key('photo-adjust-save'),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(tr('Simpan')),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AspectRatio(
                    aspectRatio: widget.aspectRatio,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        widget.circle ? 1000 : 12,
                      ),
                      child: RepaintBoundary(
                        key: _boundary,
                        child: ColoredBox(
                          key: const Key('photo-adjust-frame'),
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: InteractiveViewer(
                            transformationController: _controller,
                            minScale: 1,
                            maxScale: 5,
                            child: SizedBox.expand(
                              child: Image.memory(
                                widget.image.bytes,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    tr(
                      'Geser dan cubit (atau scroll) untuk mengatur posisi foto. '
                      'Bagian di dalam bingkai yang akan tersimpan.',
                    ),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
