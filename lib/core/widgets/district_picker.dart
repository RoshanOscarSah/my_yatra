import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../models/models.dart';
import '../providers/district_provider.dart';

/// Searchable single-district picker.
Future<String?> pickDistrict(BuildContext context, {String title = 'Choose a district'}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    builder: (ctx) => _DistrictSearchSheet(title: title),
  );
}

class _DistrictSearchSheet extends StatefulWidget {
  final String title;
  const _DistrictSearchSheet({required this.title});
  @override
  State<_DistrictSearchSheet> createState() => _DistrictSearchSheetState();
}

class _DistrictSearchSheetState extends State<_DistrictSearchSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final all = context.watch<DistrictProvider>().districts;
    final list = all
        .where((d) => d.name.toLowerCase().contains(_q.toLowerCase()))
        .toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * .8,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.title, style: AppTheme.serif(18)),
              const SizedBox(height: 10),
              TextField(
                autofocus: true,
                decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search), hintText: 'Search districts'),
                onChanged: (v) => setState(() => _q = v),
              ),
            ]),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (_, i) => ListTile(
                title: Text(list[i].name),
                subtitle: Text('${list[i].provinceName} Province'),
                onTap: () => Navigator.pop(context, list[i].id),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class DistrictPickerField extends StatelessWidget {
  final String? value;
  final String label;
  final ValueChanged<String> onChanged;
  final String? errorText;
  const DistrictPickerField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'District',
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final District? d = context.watch<DistrictProvider>().byId(value);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final id = await pickDistrict(context, title: label);
        if (id != null) onChanged(id);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          errorText: errorText,
          suffixIcon: const Icon(Icons.expand_more),
        ),
        isEmpty: d == null,
        child: Text(d?.name ?? ''),
      ),
    );
  }
}
