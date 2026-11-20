import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../core/models/models.dart';
import '../../core/providers/district_provider.dart';
import '../../core/repositories/community_repository.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/district_picker.dart';
import 'admin_home.dart';

/// US-15.6: safety alerts with an expiry; expired ones disappear for users.
class AdminAlertsScreen extends StatelessWidget {
  const AdminAlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DistrictProvider>();
    final fmt = DateFormat('d MMM y, h:mm a');
    return Scaffold(
      appBar: AppBar(title: const Text('Safety alerts')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AlertForm())),
        icon: const Icon(Icons.add),
        label: const Text('New alert'),
      ),
      body: StreamBuilder<List<SafetyAlert>>(
        stream: CommunityRepository().allAlerts(),
        builder: (context, snap) {
          final alerts = snap.data ?? const [];
          if (alerts.isEmpty) {
            return const EmptyState(icon: Icons.warning_amber_rounded, title: 'No alerts', message: 'Add one for road closures, weather or other risks.');
          }
          return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 90), children: [
            for (final a in alerts)
              Card(
                child: ListTile(
                  title: Text(dp.byId(a.districtId)?.name ?? a.districtId),
                  subtitle: Text('${a.message}\n${a.isActive() ? 'Active until' : 'Expired'} ${fmt.format(a.expiresAt)}'),
                  isThreeLine: true,
                  leading: Icon(Icons.warning_amber_rounded,
                      color: a.isActive() ? AppColors.warning : AppColors.textSecondary),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AlertForm(existing: a))),
                ),
              ),
          ]);
        },
      ),
    );
  }
}

class AlertForm extends StatefulWidget {
  final SafetyAlert? existing;
  const AlertForm({super.key, this.existing});
  @override
  State<AlertForm> createState() => _AlertFormState();
}

class _AlertFormState extends State<AlertForm> {
  late String? _district = widget.existing?.districtId;
  late final _msg = TextEditingController(text: widget.existing?.message);
  late DateTime _expires = widget.existing?.expiresAt ?? DateTime.now().add(const Duration(days: 3));
  bool _busy = false;

  @override
  void dispose() {
    _msg.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_district == null || _msg.text.trim().isEmpty) {
      showSnack(context, 'Choose a district and write the alert.');
      return;
    }
    if (!_expires.isAfter(DateTime.now())) {
      showSnack(context, 'The expiry must be in the future.');
      return;
    }
    setState(() => _busy = true);
    final a = adminOf(context);
    await CommunityRepository().saveAlert(
      SafetyAlert(
        id: widget.existing?.id ?? '',
        districtId: _district!,
        message: _msg.text.trim(),
        expiresAt: _expires,
        createdAt: widget.existing?.createdAt,
        createdBy: a.uid,
      ),
      widget.existing,
      adminUid: a.uid,
      adminName: a.name,
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickExpiry() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _expires,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_expires));
    setState(() => _expires = DateTime(date.year, date.month, date.day, time?.hour ?? 23, time?.minute ?? 59));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New alert' : 'Edit alert'),
        actions: [
          if (widget.existing != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await confirmDialog(context, title: 'Delete alert?', message: 'Users will no longer see it.', confirm: 'Delete', destructive: true);
                if (!ok || !context.mounted) return;
                final a = adminOf(context);
                await CommunityRepository().deleteAlert(widget.existing!, adminUid: a.uid, adminName: a.name);
                if (context.mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        DistrictPickerField(value: _district, onChanged: (v) => setState(() => _district = v)),
        const SizedBox(height: 12),
        TextField(controller: _msg, maxLines: 4, maxLength: 300, decoration: const InputDecoration(labelText: 'Alert message')),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Expires'),
          subtitle: Text(DateFormat('d MMM y, h:mm a').format(_expires)),
          trailing: const Icon(Icons.event),
          onTap: _pickExpiry,
        ),
        const SizedBox(height: 16),
        PrimaryButton(label: 'Publish alert', loading: _busy, onPressed: _save),
      ]),
    );
  }
}
