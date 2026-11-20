import 'package:flutter/material.dart';

import '../../app/env.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/experience_ui.dart';
import '../../app/theme.dart';
import '../../core/providers/district_provider.dart';
import '../../core/providers/journal_provider.dart';
import '../../core/widgets/common.dart';
import 'entry_form.dart';
import 'postcard_screen.dart';

class EntryDetailScreen extends StatelessWidget {
  final String entryId;
  const EntryDetailScreen({super.key, required this.entryId});

  @override
  Widget build(BuildContext context) {
    final e = context.watch<JournalProvider>().byId(entryId);
    if (e == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('Entry deleted')));
    final d = context.watch<DistrictProvider>().byId(e.districtId);
    final fmt = DateFormat.yMMMd();
    return Scaffold(
      appBar: AppBar(
        title: Text(d?.name ?? ''),
        actions: [
          IconButton(
            tooltip: 'Make a postcard',
            icon: const Icon(Icons.mail_outline),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => PostcardScreen(entry: e))),
          ),
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => EntryForm(existing: e))),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text(
          e.endDate == null || e.endDate == e.startDate
              ? fmt.format(e.startDate)
              : '${fmt.format(e.startDate)} – ${fmt.format(e.endDate!)}',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        if (e.activities.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final a in e.activities) TagChip(a.label, icon: a.icon),
          ]),
        ],
        if (e.story.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(e.story, style: const TextStyle(fontSize: 15, height: 1.5)),
        ],
        if (e.photoUrls.isNotEmpty) ...[
          const SectionTitle('Photos'),
          PhotoGrid(urls: e.photoUrls),
        ],
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => PostcardScreen(entry: e))),
          icon: const Icon(Icons.mail_outline),
          label: const Text('Turn into a postcard'),
        ),
      ]),
    );
  }
}

class PhotoGrid extends StatelessWidget {
  final List<String> urls;
  const PhotoGrid({super.key, required this.urls});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      children: [
        for (final u in urls)
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  backgroundColor: Colors.black,
                  appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
                  body: Center(child: InteractiveViewer(child: Image.network(Env.photoUrl(u)))),
                ),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(Env.photoUrl(u), fit: BoxFit.cover),
            ),
          ),
      ],
    );
  }
}
