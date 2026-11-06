import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../data/marketplace_image_picker.dart';
import '../data/marketplace_repository.dart' show kListingImageMaxBytes;
import '../util/app_language.dart';

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

/// Crop screen in the style of common apps: a fixed frame, the photo moves
/// under it. Pinch or scroll to zoom, drag to move, double tap to zoom in or
/// back to the start. The photo always covers the frame, so no empty edges.
/// Saves the framed part as a resized JPEG that fits the upload limit.
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

/// Position of the photo under the frame. [scale] is screen pixels per photo
/// pixel; [offset] is where the photo's top left sits, from the frame's top
/// left.
@visibleForTesting
class CropView {
  const CropView(this.scale, this.offset);
  final double scale;
  final Offset offset;
}

/// Smallest scale at which the photo still covers the frame.
@visibleForTesting
double coverScale(Size photo, Size frame) =>
    math.max(frame.width / photo.width, frame.height / photo.height);

/// Keeps the photo covering the frame: scale between cover and 6x cover, and
/// the offset so no edge of the frame shows empty space.
@visibleForTesting
CropView clampCrop(Size photo, Size frame, double scale, Offset offset) {
  final cover = coverScale(photo, frame);
  final s = scale.clamp(cover, cover * 6).toDouble();
  final minX = frame.width - photo.width * s;
  final minY = frame.height - photo.height * s;
  return CropView(
    s,
    Offset(
      offset.dx.clamp(minX, 0).toDouble(),
      offset.dy.clamp(minY, 0).toDouble(),
    ),
  );
}

/// Centered start position.
@visibleForTesting
CropView startCrop(Size photo, Size frame) {
  final s = coverScale(photo, frame);
  return CropView(
    s,
    Offset(
      (frame.width - photo.width * s) / 2,
      (frame.height - photo.height * s) / 2,
    ),
  );
}

/// Zooms to [scale] keeping the photo point under [focal] (frame coordinates).
@visibleForTesting
CropView zoomAt(
  Size photo,
  Size frame,
  CropView from,
  double scale,
  Offset focal,
) {
  final p = (focal - from.offset) / from.scale;
  final s = scale;
  return clampCrop(photo, frame, s, focal - p * s);
}

class _PhotoAdjustScreenState extends State<PhotoAdjustScreen> {
  ui.Image? _photo;
  bool _loadFailed = false;
  CropView? _view;
  Size? _lastFrame;
  bool _saving = false;
  String? _error;

  // Gesture start values.
  CropView? _gestureStart;
  Offset _gestureFocal = Offset.zero;
  Offset _lastTap = Offset.zero;

  Size get _photoSize =>
      Size(_photo!.width.toDouble(), _photo!.height.toDouble());

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.image.bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() => _photo = frame.image);
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  @override
  void dispose() {
    _photo?.dispose();
    super.dispose();
  }

  /// Frame size and top-left inside the editing area.
  (Rect, bool) _frameFor(Size area) {
    const pad = 24.0;
    final maxW = math.min(area.width - pad * 2, 560.0);
    final maxH = area.height - pad * 2;
    var w = maxW;
    var h = w / widget.aspectRatio;
    if (h > maxH) {
      h = maxH;
      w = h * widget.aspectRatio;
    }
    final rect = Rect.fromLTWH(
      (area.width - w) / 2,
      (area.height - h) / 2,
      w,
      h,
    );
    return (rect, true);
  }

  void _ensureView(Size frame) {
    if (_photo == null) return;
    if (_view == null || _lastFrame != frame) {
      _view = _view == null || _lastFrame == null
          ? startCrop(_photoSize, frame)
          : clampCrop(_photoSize, frame, _view!.scale, _view!.offset);
      _lastFrame = frame;
    }
  }

  void _onScaleStart(ScaleStartDetails d, Rect frame) {
    _gestureStart = _view;
    _gestureFocal = d.localFocalPoint - frame.topLeft;
  }

  void _onScaleUpdate(ScaleUpdateDetails d, Rect frame) {
    final start = _gestureStart;
    if (start == null || _photo == null) return;
    final focalNow = d.localFocalPoint - frame.topLeft;
    // Photo point that was under the fingers at the start.
    final p = (_gestureFocal - start.offset) / start.scale;
    final s = start.scale * d.scale;
    setState(() {
      _view = clampCrop(_photoSize, frame.size, s, focalNow - p * s);
    });
  }

  void _onWheel(PointerSignalEvent e, Rect frame) {
    if (e is! PointerScrollEvent || _view == null || _photo == null) return;
    final factor = math.exp(-e.scrollDelta.dy / 300);
    setState(() {
      _view = zoomAt(
        _photoSize,
        frame.size,
        _view!,
        _view!.scale * factor,
        e.localPosition - frame.topLeft,
      );
    });
  }

  void _onDoubleTap(Rect frame) {
    if (_view == null || _photo == null) return;
    final cover = coverScale(_photoSize, frame.size);
    setState(() {
      if (_view!.scale > cover * 1.05) {
        _view = startCrop(_photoSize, frame.size);
      } else {
        _view = zoomAt(
          _photoSize,
          frame.size,
          _view!,
          cover * 2.5,
          _lastTap - frame.topLeft,
        );
      }
    });
  }

  Future<void> _save() async {
    final view = _view;
    final photo = _photo;
    final frame = _lastFrame;
    if (view == null || photo == null || frame == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // The part of the photo inside the frame, in photo pixels.
      final src = Rect.fromLTWH(
        -view.offset.dx / view.scale,
        -view.offset.dy / view.scale,
        frame.width / view.scale,
        frame.height / view.scale,
      );
      // Common apps resize before upload: 1200 px wide for photos, 800 for a
      // profile picture, and never bigger than the photo itself.
      final target = widget.circle ? 800.0 : 1200.0;
      var outW = math.min(target, src.width).round().clamp(1, 4096);
      var outH = (outW / widget.aspectRatio).round().clamp(1, 4096);

      Uint8List? out;
      for (final quality in const [85, 75, 60, 45]) {
        final rec = ui.PictureRecorder();
        final canvas = Canvas(rec);
        canvas.drawRect(
          Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()),
          Paint()..color = Colors.white,
        );
        canvas.drawImageRect(
          photo,
          src,
          Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()),
          Paint()..filterQuality = FilterQuality.high,
        );
        final cropped = await rec.endRecording().toImage(outW, outH);
        final data = await cropped.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        cropped.dispose();
        if (data == null) break;
        final raster = img.Image.fromBytes(
          width: outW,
          height: outH,
          bytes: data.buffer,
          numChannels: 4,
        );
        out = Uint8List.fromList(img.encodeJpg(raster, quality: quality));
        if (out.length <= kListingImageMaxBytes) break;
        outW = (outW * 0.8).round();
        outH = (outH * 0.8).round();
      }
      if (out == null || out.length > kListingImageMaxBytes) {
        throw const ImagePickException('Foto terlalu besar. Pilih foto lain.');
      }
      final name = widget.image.name;
      final base = name.contains('.')
          ? name.substring(0, name.lastIndexOf('.'))
          : name;
      if (!mounted) return;
      Navigator.of(context).pop(PickedImage(name: '$base.jpg', bytes: out));
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
    const bg = Color(0xFF111111);
    final canSave = _photo != null && !_saving;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: Colors.white,
        title: Text(tr('Atur foto')),
        automaticallyImplyLeading: false,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                final (frame, _) = _frameFor(box.biggest);
                _ensureView(frame.size);
                final view = _view;
                return Listener(
                  onPointerSignal: (e) => _onWheel(e, frame),
                  child: GestureDetector(
                    key: const Key('photo-adjust-area'),
                    behavior: HitTestBehavior.opaque,
                    onScaleStart: (d) => _onScaleStart(d, frame),
                    onScaleUpdate: (d) => _onScaleUpdate(d, frame),
                    onDoubleTapDown: (d) => _lastTap = d.localPosition,
                    onDoubleTap: () => _onDoubleTap(frame),
                    child: SizedBox.expand(
                      key: const Key('photo-adjust-frame'),
                      child: _loadFailed
                          ? Center(
                              child: Text(
                                tr('Foto tidak bisa dibuka. Pilih foto lain.'),
                                style: const TextStyle(color: Colors.white),
                              ),
                            )
                          : view == null
                          ? const Center(child: CircularProgressIndicator())
                          : CustomPaint(
                              painter: _CropPainter(
                                photo: _photo!,
                                view: view,
                                frame: frame,
                                circle: widget.circle,
                              ),
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr(
                      'Geser untuk memindah, cubit atau scroll untuk zoom, '
                      'ketuk dua kali untuk zoom atau reset.',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('photo-adjust-cancel'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                            minimumSize: const Size.fromHeight(48),
                          ),
                          onPressed: _saving
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: Text(tr('Batal')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          key: const Key('photo-adjust-save'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                          onPressed: canSave ? _save : null,
                          child: _saving
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(tr('Simpan')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CropPainter extends CustomPainter {
  _CropPainter({
    required this.photo,
    required this.view,
    required this.frame,
    required this.circle,
  });

  final ui.Image photo;
  final CropView view;
  final Rect frame;
  final bool circle;

  @override
  void paint(Canvas canvas, Size size) {
    // The whole photo, so the person sees what lies outside the frame.
    final dst = Rect.fromLTWH(
      frame.left + view.offset.dx,
      frame.top + view.offset.dy,
      photo.width * view.scale,
      photo.height * view.scale,
    );
    canvas.drawImageRect(
      photo,
      Rect.fromLTWH(0, 0, photo.width.toDouble(), photo.height.toDouble()),
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );
    final hole = circle
        ? (Path()..addOval(frame))
        : (Path()..addRRect(
            RRect.fromRectAndRadius(frame, const Radius.circular(4)),
          ));
    final shade = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      hole,
    );
    canvas.drawPath(shade, Paint()..color = const Color(0xB3000000));
    canvas.drawPath(
      hole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );
    if (!circle) {
      // Thirds grid, like camera apps.
      final grid = Paint()
        ..strokeWidth = 1
        ..color = Colors.white38;
      for (var i = 1; i < 3; i++) {
        final x = frame.left + frame.width * i / 3;
        final y = frame.top + frame.height * i / 3;
        canvas.drawLine(Offset(x, frame.top), Offset(x, frame.bottom), grid);
        canvas.drawLine(Offset(frame.left, y), Offset(frame.right, y), grid);
      }
    }
  }

  @override
  bool shouldRepaint(_CropPainter old) =>
      old.view != view || old.frame != frame || old.photo != photo;
}
