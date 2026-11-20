import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../app/env.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/theme.dart';
import '../../core/models/models.dart';
import '../../core/providers/district_provider.dart';
import '../../core/utils/share_helper.dart';
import '../../core/widgets/common.dart';

/// US-7.4: photo + district + caption → shareable PNG. Nothing is posted
/// unless the user chooses to share.
class PostcardScreen extends StatefulWidget {
  final JournalEntry entry;
  const PostcardScreen({super.key, required this.entry});

  @override
  State<PostcardScreen> createState() => _PostcardScreenState();
}

class _PostcardScreenState extends State<PostcardScreen> {
  final _key = GlobalKey();
  late final _caption = TextEditingController(text: 'Greetings from MyYatra!');
  int _photo = 0;
  bool _busy = false;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final boundary = _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = XFile.fromData(data!.buffer.asUint8List(),
          mimeType: 'image/png', name: 'myyatra_postcard.png');
      if (!mounted) return;
      await ShareHelper.shareFiles(context, [file], text: _caption.text);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not create the postcard image.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = context.watch<DistrictProvider>().byId(widget.entry.districtId);
    final photos = widget.entry.photoUrls;
    return Scaffold(
      appBar: AppBar(title: const Text('Digital postcard')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        RepaintBoundary(
          key: _key,
          child: AspectRatio(
            aspectRatio: 1.5,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(fit: StackFit.expand, children: [
                if (photos.isNotEmpty)
                  Image.network(Env.photoUrl(photos[_photo]), fit: BoxFit.cover)
                else
                  const Icon(Icons.landscape, color: Colors.white24, size: 120),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 16,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d?.name ?? '', style: AppTheme.serif(30, color: Colors.white)),
                    const SizedBox(height: 4),
                    ValueListenableBuilder(
                      valueListenable: _caption,
                      builder: (_, v, _) => Text(v.text,
                          style: const TextStyle(color: Colors.white, fontSize: 15)),
                    ),
                    const SizedBox(height: 6),
                    const Text('MyYatra · Every district. A new story.',
                        style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (photos.length > 1)
          SizedBox(
            height: 64,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (var i = 0; i < photos.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => setState(() => _photo = i),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: i == _photo ? AppColors.primary : Colors.transparent, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(Env.photoUrl(photos[i]), width: 60, height: 60, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: _caption,
          maxLength: 80,
          decoration: const InputDecoration(labelText: 'Caption'),
        ),
        const SizedBox(height: 12),
        PrimaryButton(label: 'Share or save', icon: Icons.ios_share, arrow: false, loading: _busy, onPressed: _share),
      ]),
    );
  }
}
