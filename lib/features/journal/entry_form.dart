import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/env.dart';
import '../../app/experience_ui.dart';
import '../../app/theme.dart';
import '../../core/models/models.dart';
import '../../core/providers/connectivity_provider.dart';
import '../../core/providers/journal_provider.dart';
import '../../core/providers/visit_provider.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/district_picker.dart';

/// Create / edit a journal entry (US-7.1, US-7.2, US-7.3).
class EntryForm extends StatefulWidget {
  final JournalEntry? existing;
  final String? initialDistrictId;
  const EntryForm({super.key, this.existing, this.initialDistrictId});

  @override
  State<EntryForm> createState() => _EntryFormState();
}

class _EntryFormState extends State<EntryForm> {
  late String? _district = widget.existing?.districtId ?? widget.initialDistrictId;
  late DateTime? _start = widget.existing?.startDate;
  late DateTime? _end = widget.existing?.endDate;
  late final Set<Experience> _activities = {...?widget.existing?.activities};
  late final _story = TextEditingController(text: widget.existing?.story);
  late final List<String> _urls = [...?widget.existing?.photoUrls];
  late final List<String> _paths = [...?widget.existing?.photoPaths];
  final List<String> _removed = [];
  final List<PickedPhoto> _new = [];
  bool _busy = false;
  bool _tried = false;

  @override
  void dispose() {
    _story.dispose();
    super.dispose();
  }

  int get _photoCount => _urls.length + _new.length;

  Future<void> _pickPhotos() async {
    if (_photoCount >= Env.maxPhotosPerEntry) {
      showSnack(context, 'You can add up to ${Env.maxPhotosPerEntry} photos per entry.');
      return;
    }
    try {
      // image_picker resizes and re-encodes, which compresses the photo.
      final files = await ImagePicker().pickMultiImage(maxWidth: 1600, imageQuality: 75);
      var rejected = 0;
      for (final f in files) {
        if (_photoCount >= Env.maxPhotosPerEntry) break;
        final name = f.name.toLowerCase();
        var ext = name.contains('.') ? name.split('.').last : 'jpg';
        if (ext == 'jpeg') ext = 'jpg';
        final bytes = await f.readAsBytes();
        if (!Env.allowedPhotoTypes.contains(ext) || bytes.length > Env.maxPhotoBytes) {
          rejected++;
          continue;
        }
        setState(() => _new.add(PickedPhoto(bytes, ext)));
      }
      if (rejected > 0 && mounted) {
        showSnack(context,
            '$rejected photo(s) skipped: use JPG, PNG, WEBP or HEIC under ${Env.maxPhotoBytes ~/ 1024 ~/ 1024} MB.');
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Could not open your photos. Please allow photo access.');
    }
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1990),
      lastDate: now,
      initialDateRange: _start == null
          ? null
          : DateTimeRange(start: _start!, end: _end ?? _start!),
    );
    if (r != null) {
      setState(() {
        _start = r.start;
        _end = r.end;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _tried = true);
    if (_district == null || _start == null) return;
    setState(() => _busy = true);
    final journal = context.read<JournalProvider>();
    final visits = context.read<VisitProvider>();
    final online = context.read<ConnectivityProvider>().online;
    final entry = JournalEntry(
      id: widget.existing?.id ?? journal.newId(),
      districtId: _district!,
      startDate: _start!,
      endDate: _end,
      activities: _activities.toList(),
      story: _story.text.trim(),
      photoUrls: _urls,
      photoPaths: _paths,
    );
    try {
      await journal.save(entry, newPhotos: _new, removedPaths: _removed, online: online);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, 'Could not save photos. Check your connection or storage and try again.');
      }
      return;
    }
    if (!mounted) return;
    // US-7.1: offer to mark the district visited.
    if (!visits.isVisited(_district!)) {
      final mark = await confirmDialog(context,
          title: 'Mark as visited?',
          message: 'This district is not marked visited yet. Mark it visited on ${DateFormat.yMMMd().format(_start!)}?',
          confirm: 'Mark visited');
      if (mark) await visits.addVisit(_district!, _start);
    }
    if (!mounted) return;
    showSnack(context, !online && _new.isNotEmpty
        ? 'Saved. Photos will upload when you are back online.'
        : 'Journal entry saved.');
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(context,
        title: 'Delete this entry?',
        message: 'The entry and its photos will be deleted. Your visited districts stay the same.',
        confirm: 'Delete',
        destructive: true);
    if (!ok || !mounted) return;
    await context.read<JournalProvider>().delete(widget.existing!);
    if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.yMMMd();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New journal entry' : 'Edit entry'),
        actions: [
          if (widget.existing != null)
            IconButton(tooltip: 'Delete', onPressed: _delete, icon: const Icon(Icons.delete_outline)),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        DistrictPickerField(
          value: _district,
          onChanged: (v) => setState(() => _district = v),
          errorText: _tried && _district == null ? 'Choose a district.' : null,
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: _pickRange,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Dates',
              suffixIcon: const Icon(Icons.date_range),
              errorText: _tried && _start == null ? 'Choose the dates of your trip.' : null,
            ),
            isEmpty: _start == null,
            child: Text(_start == null
                ? ''
                : _end == null || _end == _start
                    ? fmt.format(_start!)
                    : '${fmt.format(_start!)} – ${fmt.format(_end!)}'),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Activities (optional)', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in Experience.values)
            FilterChip(
              avatar: Icon(e.icon, size: 16),
              label: Text(e.label),
              selected: _activities.contains(e),
              onSelected: (s) => setState(() => s ? _activities.add(e) : _activities.remove(e)),
            ),
        ]),
        const SizedBox(height: 16),
        TextField(
          controller: _story,
          maxLines: 6,
          maxLength: 3000,
          decoration: const InputDecoration(labelText: 'Your story (optional)', alignLabelWithHint: true),
        ),
        const SizedBox(height: 8),
        Row(children: [
          const Expanded(child: Text('Photos', style: TextStyle(fontWeight: FontWeight.w600))),
          Text('$_photoCount/${Env.maxPhotosPerEntry}', style: const TextStyle(color: AppColors.textSecondary)),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (var i = 0; i < _urls.length; i++)
            _Thumb(
              image: Image.network(_urls[i], fit: BoxFit.cover),
              onRemove: () => setState(() {
                _urls.removeAt(i);
                _removed.add(_paths.removeAt(i));
              }),
            ),
          for (var i = 0; i < _new.length; i++)
            _Thumb(
              image: Image.memory(_new[i].bytes, fit: BoxFit.cover),
              onRemove: () => setState(() => _new.removeAt(i)),
            ),
          InkWell(
            onTap: _pickPhotos,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
                color: AppColors.surface,
              ),
              child: const Icon(Icons.add_a_photo_outlined, color: AppColors.primary),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Text(
          'JPG, PNG, WEBP or HEIC, up to ${Env.maxPhotoBytes ~/ 1024 ~/ 1024} MB each. Photos are private to you.',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        PrimaryButton(label: 'Save entry', loading: _busy, onPressed: _save),
      ]),
    );
  }
}

class _Thumb extends StatelessWidget {
  final Widget image;
  final VoidCallback onRemove;
  const _Thumb({required this.image, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(width: 88, height: 88, child: image),
      ),
      Positioned(
        right: 2,
        top: 2,
        child: InkWell(
          onTap: onRemove,
          child: const CircleAvatar(
            radius: 12,
            backgroundColor: Colors.black54,
            child: Icon(Icons.close, size: 14, color: Colors.white),
          ),
        ),
      ),
    ]);
  }
}
