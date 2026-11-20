// Nepal district map.
//
// Adapted from Hariyo Naksha by Roshan Sah (map_screen.dart's
// InteractiveViewer + GestureDetector + ClipPath code and DistrictPainter),
// extended with a third colour for recommended districts (US-3.3).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_drawing/path_drawing.dart';
import 'package:xml/xml.dart';

import '../../app/theme.dart';

class MapShape {
  final String svgLabel;
  final String provinceGroup; // p1..p7
  final Path path;
  const MapShape(this.svgLabel, this.provinceGroup, this.path);
}

/// Loads district outlines from the SVG. The province is read from the parent
/// `<g>` label (p1..p7).
class SvgMapLoader {
  static const viewBoxWidth = 1086.36;
  static const viewBoxHeight = 543.89;
  static List<MapShape>? _cache;

  static Future<List<MapShape>> load() async {
    if (_cache != null) return _cache!;
    final svg =
        await rootBundle.loadString('assets/maps/nepal_map_with_data.svg');
    _cache = parse(svg);
    return _cache!;
  }

  static List<MapShape> parse(String svg) {
    final doc = XmlDocument.parse(svg);
    final shapes = <MapShape>[];
    for (final el in doc.findAllElements('polygon')) {
      final label = el.getAttribute('inkscape:label') ?? el.getAttribute('id');
      final points = el.getAttribute('points') ?? '';
      if (label == null || points.isEmpty) continue;
      final group = el.parentElement?.getAttribute('inkscape:label') ?? '';
      shapes.add(MapShape(label, group, parseSvgPathData(_pointsToPath(points))));
    }
    for (final el in doc.findAllElements('path')) {
      final label = el.getAttribute('inkscape:label');
      final d = el.getAttribute('d') ?? '';
      if (label == null || d.isEmpty) continue;
      final group = el.parentElement?.getAttribute('inkscape:label') ?? '';
      shapes.add(MapShape(label, group, parseSvgPathData(d)));
    }
    return shapes;
  }

  static String _pointsToPath(String points) {
    final list = points.trim().split(RegExp(r'\s+'));
    final b = StringBuffer('M${list.first}');
    for (var i = 1; i < list.length; i++) {
      b.write(' L${list[i]}');
    }
    b.write(' Z');
    return b.toString();
  }
}

enum MapStatus { visited, recommended, other }

class NepalMap extends StatefulWidget {
  /// Maps the SVG label of each district to its app district id.
  final Map<String, String> labelToId;
  final Set<String> visitedIds;
  final Set<String> recommendedIds;
  final String? selectedId;
  final ValueChanged<String>? onTap;
  final bool interactive;

  /// Full-screen use: Nepal is wide, so in a tall box start zoomed in a
  /// little and show zoom buttons.
  final bool fillHeight;

  const NepalMap({
    super.key,
    required this.labelToId,
    required this.visitedIds,
    this.recommendedIds = const {},
    this.selectedId,
    this.onTap,
    this.interactive = true,
    this.fillHeight = false,
  });

  @override
  State<NepalMap> createState() => _NepalMapState();
}

class _NepalMapState extends State<NepalMap> {
  List<MapShape>? _shapes;
  final _controller = TransformationController();
  Size? _fittedFor;
  Matrix4 _home = Matrix4.identity();

  /// Zoom by [factor] around the centre of the [viewport].
  Matrix4 _zoomed(Matrix4 from, double factor, Size viewport) {
    final current = from.getMaxScaleOnAxis();
    final target = (current * factor).clamp(1.0, 6.0);
    final f = target / current;
    final cx = viewport.width / 2, cy = viewport.height / 2;
    return Matrix4.identity()
      ..translateByDouble(cx * (1 - f), cy * (1 - f), 0, 1)
      ..scaleByDouble(f, f, 1, 1)
      ..multiply(from);
  }

  void _fitHeight(Size viewport, Size mapSize) {
    if (_fittedFor == viewport) return;
    _fittedFor = viewport;
    // Enough to make districts easy to tap while keeping most of the
    // country in view; pan or use the buttons for the rest.
    final zoom = (viewport.height * .5 / mapSize.height).clamp(1.0, 1.6);
    _home = _zoomed(Matrix4.identity(), zoom, viewport);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.value = _home;
    });
  }

  @override
  void initState() {
    super.initState();
    SvgMapLoader.load().then((s) {
      if (mounted) setState(() => _shapes = s);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  MapStatus _status(String id) {
    if (widget.visitedIds.contains(id)) return MapStatus.visited;
    if (widget.recommendedIds.contains(id)) return MapStatus.recommended;
    return MapStatus.other;
  }

  @override
  Widget build(BuildContext context) {
    final shapes = _shapes;
    if (shapes == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return LayoutBuilder(builder: (context, c) {
      // Fit inside both bounds, so a fixed-height box never overflows.
      var scale = c.maxWidth / SvgMapLoader.viewBoxWidth;
      if (c.maxHeight.isFinite) {
        final h = c.maxHeight / SvgMapLoader.viewBoxHeight;
        if (h < scale) scale = h;
      }
      final size = Size(c.maxWidth, SvgMapLoader.viewBoxHeight * scale);

      final map = SizedBox.fromSize(
        size: size,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) {
            final p = d.localPosition / scale;
            for (final s in shapes.reversed) {
              if (s.path.contains(p)) {
                final id = widget.labelToId[s.svgLabel];
                if (id != null) widget.onTap?.call(id);
                return;
              }
            }
          },
          child: CustomPaint(
            size: size,
            painter: _MapPainter(
              shapes: shapes,
              scale: scale,
              statusOf: (label) {
                final id = widget.labelToId[label];
                return id == null ? MapStatus.other : _status(id);
              },
              selectedLabel: widget.labelToId.entries
                  .where((e) => e.value == widget.selectedId)
                  .map((e) => e.key)
                  .firstOrNull,
              statusKey: Object.hashAll([
                ...widget.visitedIds,
                '|',
                ...widget.recommendedIds,
                widget.selectedId
              ]),
            ),
          ),
        ),
      );

      if (!widget.interactive) {
        return ClipRect(
          child: SizedBox(
            width: c.maxWidth,
            height: c.maxHeight.isFinite ? c.maxHeight : size.height,
            child: Center(child: map),
          ),
        );
      }
      final viewer = InteractiveViewer(
        transformationController: _controller,
        minScale: 1,
        maxScale: 6,
        boundaryMargin: const EdgeInsets.all(40),
        child: Center(child: map),
      );
      if (!widget.fillHeight || !c.maxHeight.isFinite) return viewer;
      final viewport = Size(c.maxWidth, c.maxHeight);
      _fitHeight(viewport, size);
      Widget button(IconData icon, String tip, VoidCallback onTap) => Padding(
            padding: const EdgeInsets.only(top: 8),
            child: IconButton.filledTonal(tooltip: tip, icon: Icon(icon), onPressed: onTap),
          );
      return Stack(children: [
        Positioned.fill(child: viewer),
        Positioned(
          right: 4,
          bottom: 4,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            button(Icons.add, 'Zoom in',
                () => _controller.value = _zoomed(_controller.value, 1.5, viewport)),
            button(Icons.remove, 'Zoom out',
                () => _controller.value = _zoomed(_controller.value, 1 / 1.5, viewport)),
            button(Icons.center_focus_strong, 'Reset view',
                () => _controller.value = _home.clone()),
          ]),
        ),
      ]);
    });
  }
}

class _MapPainter extends CustomPainter {
  final List<MapShape> shapes;
  final double scale;
  final MapStatus Function(String label) statusOf;
  final String? selectedLabel;
  final int statusKey;

  _MapPainter({
    required this.shapes,
    required this.scale,
    required this.statusOf,
    required this.selectedLabel,
    required this.statusKey,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(scale);
    final fill = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white
      ..strokeWidth = 1 / scale * 0.9
      ..strokeJoin = StrokeJoin.round;

    for (final s in shapes) {
      fill.color = switch (statusOf(s.svgLabel)) {
        MapStatus.visited => AppColors.mapVisited,
        MapStatus.recommended => AppColors.mapRecommended,
        MapStatus.other => AppColors.mapOther,
      };
      canvas.drawPath(s.path, fill);
      canvas.drawPath(s.path, stroke);
    }
    if (selectedLabel != null) {
      final sel = shapes.where((s) => s.svgLabel == selectedLabel);
      final hl = Paint()
        ..style = PaintingStyle.stroke
        ..color = AppColors.textPrimary
        ..strokeWidth = 2.5 / scale;
      for (final s in sel) {
        canvas.drawPath(s.path, hl);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MapPainter old) =>
      old.statusKey != statusKey || old.scale != scale;
}

class MapLegend extends StatelessWidget {
  final bool showRecommended;
  const MapLegend({super.key, this.showRecommended = true});

  @override
  Widget build(BuildContext context) {
    Widget item(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                  color: c, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 6),
          Text(t, style: const TextStyle(fontSize: 12)),
        ]);
    return Wrap(spacing: 16, runSpacing: 6, children: [
      item(AppColors.mapVisited, 'Visited'),
      if (showRecommended) item(AppColors.mapRecommended, 'Recommended'),
      item(AppColors.mapOther, 'Not yet'),
    ]);
  }
}
