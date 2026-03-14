import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../widgets/sg_design_system.dart';
import '../providers/theme_provider.dart';
import 'user_detail_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fs    = FirestoreService();
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    final name  = email.split('@').first;

    return Scaffold(
      backgroundColor: SGTheme.of(context).bg,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: fs.getUsersStream(),
          builder: (context, snap) {
            final users     = snap.data?.docs ?? [];
            int outOfZone   = 0, falls = 0;
            for (final d in users) {
              final m = d.data() as Map<String, dynamic>;
              if (m['outOfZone']    == true) outOfZone++;
              if (m['fallDetected'] == true) falls++;
            }

            return CustomScrollView(
              slivers: [
                // ── Header ──────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hello, $name 👋', style: SG.display(context)),
                        SizedBox(height: 4),
                        Text(
                          users.isEmpty
                              ? 'No one monitored yet'
                              : 'Monitoring ${users.length} ${users.length == 1 ? "person" : "people"}',
                          style: SG.bodyStyle(context),
                        ),

                        // ── Stat cards ─────────────────────────────────────
                        if (users.isNotEmpty) ...[
                          SizedBox(height: 20),
                          Row(children: [
                            _StatCard(
                              value: '${users.length}',
                              label: 'Monitored',
                              icon: Icons.people_outline,
                              color: SG.accent,
                            ),
                            SizedBox(width: 10),
                            _StatCard(
                              value: '$outOfZone',
                              label: 'Out of Zone',
                              icon: Icons.location_off_outlined,
                              color: outOfZone > 0
                                  ? SG.warn
                                  : SG.textMuted,
                            ),
                            SizedBox(width: 10),
                            _StatCard(
                              value: '$falls',
                              label: 'Fall Alerts',
                              icon: Icons.warning_amber_rounded,
                              color: falls > 0
                                  ? SG.danger
                                  : SG.textMuted,
                            ),
                          ]),
                        ],

                        SizedBox(height: 28),
                        const SGSectionLabel('Monitored Users'),
                      ],
                    ),
                  ),
                ),

                // ── Loading ──────────────────────────────────────────────────
                if (snap.connectionState == ConnectionState.waiting)
                  const SliverFillRemaining(
                    child: Center(
                        child: CircularProgressIndicator(color: SG.accent)),
                  )

                // ── Empty ───────────────────────────────────────────────────
                else if (users.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80, height: 80,
                            decoration: BoxDecoration(
                              color: SG.accentGlow,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: SG.accent.withOpacity(0.3)),
                            ),
                            child: Icon(Icons.people_outline,
                                size: 36, color: SG.accent),
                          ),
                          SizedBox(height: 20),
                          Text('No one added yet', style: SG.headingStyle(context)),
                          SizedBox(height: 6),
                          Text('Tap + to add someone to monitor',
                              style: SG.bodyStyle(context)),
                        ],
                      ),
                    ),
                  )

                // ── List ────────────────────────────────────────────────────
                else
                  SliverPadding(
                    padding:
                        const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final doc = users[i];
                          final d   = doc.data() as Map<String, dynamic>;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _UserTile(
                              data: d,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => UserDetailScreen(
                                      personId: doc.id),
                                ),
                              ),
                              onDelete: () =>
                                  _delete(context, fs, doc.id,
                                      d['name'] ?? ''),
                            ),
                          );
                        },
                        childCount: users.length,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),

      // ── FAB ─────────────────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addSheet(context, FirestoreService()),
        backgroundColor: SG.accent,
        elevation: 8,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> _delete(BuildContext ctx, FirestoreService fs,
      String id, String name) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => _DarkDialog(
        title: 'Remove $name?',
        body: 'This will permanently delete their data and alerts.',
        confirmLabel: 'Remove',
        confirmColor: SG.danger,
      ),
    );
    if (ok == true) {
      await fs.deleteUser(id);
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text('$name removed'),
          backgroundColor: SGTheme.of(ctx).card,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                            behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  // ── Add sheet (multi-step) ────────────────────────────────────────────────

  Future<void> _addSheet(BuildContext ctx, FirestoreService fs) async {
    await showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddPatientSheet(fs: fs),
    );
  }
}

// ── User tile ─────────────────────────────────────────────────────────────────

class _UserTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap, onDelete;
  const _UserTile({required this.data, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final name = (data['name'] ?? 'Unknown') as String;
    final hr   = data['heartRate'];
    final tmp  = data['temperature'];
    final out  = data['outOfZone']    == true;
    final fall = data['fallDetected'] == true;

    Color  statusColor = SG.safe;
    String statusLabel = 'Safe';
    Color  statusBg    = SG.safeGlow;
    IconData statusIcon = Icons.check_circle_outline;

    if (fall) {
      statusColor = SG.danger; statusLabel = 'Fall Alert';
      statusBg = SG.dangerGlow; statusIcon = Icons.warning_amber_rounded;
    } else if (out) {
      statusColor = SG.warn; statusLabel = 'Out of Zone';
      statusBg = SG.warnGlow; statusIcon = Icons.location_off_outlined;
    }

    return SGCard(
      onTap: onTap,
      borderColor: fall
          ? SG.danger.withOpacity(0.4)
          : out
              ? SG.warn.withOpacity(0.3)
              : SG.navyBorder,
      child: Row(children: [
        // Avatar
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withOpacity(0.3)),
          ),
          child: Center(
            child: Text(
              name[0].toUpperCase(),
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800,
                  color: statusColor),
            ),
          ),
        ),
        SizedBox(width: 14),

        // Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: SG.headingStyle(context)),
              SizedBox(height: 4),
              Row(children: [
                if (hr != null && hr != 0) ...[
                  Icon(Icons.favorite, size: 11, color: SG.danger),
                  SizedBox(width: 3),
                  Text('$hr bpm', style: TextStyle(
                      fontSize: 12, color: SGTheme.of(context).textSecondary)),
                  SizedBox(width: 10),
                ],
                if (tmp != null && tmp != 0) ...[
                  Icon(Icons.thermostat, size: 11, color: SG.purple),
                  SizedBox(width: 3),
                  Text('${(tmp as num).toStringAsFixed(1)}°C',
                      style: TextStyle(
                          fontSize: 12, color: SGTheme.of(context).textSecondary)),
                ],
                if ((hr == null || hr == 0) && (tmp == null || tmp == 0))
                  Text('No vitals data', style: SG.bodyStyle(context).copyWith(fontSize: 12)),
              ]),
            ],
          ),
        ),

        // Right side
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SGPill(
                label: statusLabel, color: statusColor, bg: statusBg,
                icon: statusIcon),
            SizedBox(height: 8),
            GestureDetector(
              onTap: onDelete,
              child: Icon(Icons.delete_outline,
                  size: 16, color: SGTheme.of(context).textMuted),
            ),
          ],
        ),
      ]),
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;
  const _StatCard({required this.value, required this.label,
      required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: SGTheme.of(context).surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800, color: color)),
            SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w600,
                    color: SGTheme.of(context).textSecondary, letterSpacing: 0.3)),
          ],
        ),
      ),
    );
  }
}

// ── Shared form widgets ───────────────────────────────────────────────────────

class _DarkInput extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final TextInputType? type;
  final int maxLines;
  const _DarkInput({required this.ctrl, required this.label,
      required this.hint, this.type, this.maxLines = 1});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: SGTheme.of(context).textSecondary, letterSpacing: 0.4)),
          SizedBox(height: 6),
          TextField(
            controller: ctrl, keyboardType: type, maxLines: maxLines,
            style: TextStyle(fontSize: 14, color: SGTheme.of(context).textPrimary),
            cursorColor: SG.accent,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: SGTheme.of(context).textMuted),
              filled: true, fillColor: SGTheme.of(context).surface,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: SGTheme.of(context).border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: SGTheme.of(context).border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: SG.accent, width: 1.5),
              ),
            ),
          ),
        ],
      );
}

class _GenderPicker extends StatelessWidget {
  final String value;
  final void Function(String) onChanged;
  const _GenderPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Gender', style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: SGTheme.of(context).textSecondary, letterSpacing: 0.4)),
          SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: value,
            dropdownColor: SG.navySurface,
            style: TextStyle(fontSize: 14, color: SGTheme.of(context).textPrimary),
            decoration: InputDecoration(
              filled: true, fillColor: SGTheme.of(context).surface,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: SGTheme.of(context).border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: SGTheme.of(context).border),
              ),
            ),
            items: const [
              DropdownMenuItem(value: 'Male',   child: Text('Male')),
              DropdownMenuItem(value: 'Female', child: Text('Female')),
              DropdownMenuItem(value: 'Other',  child: Text('Other')),
            ],
            onChanged: (v) => onChanged(v!),
          ),
        ],
      );
}

// ── Dark dialog ───────────────────────────────────────────────────────────────

class _DarkDialog extends StatelessWidget {
  final String title, body, confirmLabel;
  final Color confirmColor;
  const _DarkDialog({required this.title, required this.body,
      required this.confirmLabel, required this.confirmColor});

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: SGTheme.of(context).card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title,
            style: SG.headingStyle(context)),
        content: Text(body, style: SG.bodyStyle(context)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TextStyle(color: SGTheme.of(context).textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: confirmColor,
                foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel,
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Multi-step Add Patient Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _AddPatientSheet extends StatefulWidget {
  final FirestoreService fs;
  const _AddPatientSheet({required this.fs});

  @override
  State<_AddPatientSheet> createState() => _AddPatientSheetState();
}

class _AddPatientSheetState extends State<_AddPatientSheet> {
  int _step = 0; // 0=Basic, 1=Medical, 2=Emergency, 3=Doctor
  bool _saving = false;

  // Step 0 — Basic info
  final _nameCtrl   = TextEditingController();
  final _ageCtrl    = TextEditingController();
  String _gender    = 'Male';
  String _dementiaStage = 'Early';

  // Step 1 — Medical
  final _conditionsCtrl   = TextEditingController();
  final _medicationsCtrl  = TextEditingController();
  final _allergiesCtrl    = TextEditingController();
  String _bloodType       = 'Unknown';

  // Step 2 — Emergency contact
  final _ecNameCtrl   = TextEditingController();
  final _ecPhoneCtrl  = TextEditingController();
  final _ecRelCtrl    = TextEditingController();

  // Step 3 — Doctor
  final _drNameCtrl     = TextEditingController();
  final _drPhoneCtrl    = TextEditingController();
  final _drHospitalCtrl = TextEditingController();

  static const _steps = ['Basic Info', 'Medical', 'Emergency', 'Doctor'];
  static const _stepIcons = [
    Icons.person_outline,
    Icons.medical_information_outlined,
    Icons.contact_phone_outlined,
    Icons.local_hospital_outlined,
  ];

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _ageCtrl, _conditionsCtrl, _medicationsCtrl,
      _allergiesCtrl, _ecNameCtrl, _ecPhoneCtrl, _ecRelCtrl,
      _drNameCtrl, _drPhoneCtrl, _drHospitalCtrl,
    ]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.fs.addUserFromFields(
      name:             _nameCtrl.text.trim(),
      age:              int.tryParse(_ageCtrl.text) ?? 0,
      gender:           _gender,
      dementiaStage:    _dementiaStage,
      conditions:       _conditionsCtrl.text.trim().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      medications:      _medicationsCtrl.text.trim().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      allergies:        _allergiesCtrl.text.trim().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      bloodType:        _bloodType,
      ecName:           _ecNameCtrl.text.trim(),
      ecPhone:          _ecPhoneCtrl.text.trim(),
      ecRelation:       _ecRelCtrl.text.trim(),
      doctorName:       _drNameCtrl.text.trim(),
      doctorPhone:      _drPhoneCtrl.text.trim(),
      doctorHospital:   _drHospitalCtrl.text.trim(),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SGTheme.of(context).card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: SGTheme.of(context).textMuted,
                borderRadius: BorderRadius.circular(99)),
          )),
          SizedBox(height: 20),

          // Step progress bar
          Row(children: List.generate(_steps.length, (i) {
            final active   = i == _step;
            final done     = i < _step;
            final color    = done || active ? SG.accent : SG.navyBorder;
            return Expanded(child: Row(children: [
              if (i > 0) Expanded(child: Container(
                height: 2,
                color: done ? SG.accent : SG.navyBorder,
              )),
              Column(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done || active
                        ? SG.accent.withOpacity(active ? 1 : 0.3)
                        : SG.navySurface,
                    border: Border.all(color: color, width: 1.5),
                  ),
                  child: Icon(
                    done ? Icons.check : _stepIcons[i],
                    size: 16,
                    color: done || active ? Colors.white : SG.textMuted,
                  ),
                ),
                SizedBox(height: 4),
                Text(_steps[i], style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600,
                  color: active ? SG.accent : SG.textMuted,
                )),
              ]),
            ]));
          })),

          SizedBox(height: 24),
          Divider(color: SGTheme.of(context).border, height: 1),
          SizedBox(height: 20),

          // Step content
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: KeyedSubtree(
              key: ValueKey(_step),
              child: _buildStep(),
            ),
          ),

          SizedBox(height: 24),

          // Navigation buttons
          Row(children: [
            if (_step > 0) ...[
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SG.textSecondary,
                    side: BorderSide(color: SGTheme.of(context).border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => setState(() => _step--),
                  child: Text('Back'),
                ),
              ),
              SizedBox(width: 12),
            ],
            Expanded(
              flex: 2,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: SG.accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _saving ? null : () {
                  if (_step < _steps.length - 1) {
                    if (_step == 0 && _nameCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Please enter the patient\'s name'),
                        backgroundColor: SG.danger,
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                            behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ));
                      return;
                    }
                    setState(() => _step++);
                  } else {
                    _save();
                  }
                },
                child: _saving
                    ? SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : Text(
                        _step < _steps.length - 1 ? 'Continue' : 'Add Patient',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0: return _stepBasic();
      case 1: return _stepMedical();
      case 2: return _stepEmergency();
      case 3: return _stepDoctor();
      default: return SizedBox();
    }
  }

  // ── Step 0: Basic info ────────────────────────────────────────────────────
  Widget _stepBasic() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sheetLabel('Patient Information', context),
      _DarkInput(ctrl: _nameCtrl, label: 'Full name *',
          hint: 'e.g. Grandma Rose'),
      SizedBox(height: 12),
      Row(children: [
        Expanded(child: _DarkInput(
            ctrl: _ageCtrl, label: 'Age',
            hint: '72', type: TextInputType.number)),
        SizedBox(width: 12),
        Expanded(child: _GenderPicker(
          value: _gender,
          onChanged: (v) => setState(() => _gender = v),
        )),
      ]),
      SizedBox(height: 16),
      _sheetLabel('Dementia Stage', context),
      _ChipSelector(
        options: const ['Early', 'Moderate', 'Severe'],
        selected: _dementiaStage,
        onChanged: (v) => setState(() => _dementiaStage = v),
        colors: const [SG.safe, SG.warn, SG.danger],
      ),
    ],
  );

  // ── Step 1: Medical ────────────────────────────────────────────────────────
  Widget _stepMedical() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sheetLabel('Medical Details', context),
      _DarkInput(ctrl: _conditionsCtrl,
          label: 'Existing conditions',
          hint: 'e.g. Hypertension, Diabetes',
          maxLines: 2),
      SizedBox(height: 12),
      _DarkInput(ctrl: _medicationsCtrl,
          label: 'Current medications',
          hint: 'e.g. Donepezil 10mg, Metformin',
          maxLines: 2),
      SizedBox(height: 12),
      _DarkInput(ctrl: _allergiesCtrl,
          label: 'Known allergies',
          hint: 'e.g. Penicillin, Aspirin'),
      SizedBox(height: 16),
      _sheetLabel('Blood Type', context),
      _ChipSelector(
        options: const ['A+', 'A−', 'B+', 'B−', 'O+', 'O−', 'AB+', 'AB−', 'Unknown'],
        selected: _bloodType,
        onChanged: (v) => setState(() => _bloodType = v),
        colors: null,
      ),
    ],
  );

  // ── Step 2: Emergency contact ──────────────────────────────────────────────
  Widget _stepEmergency() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sheetLabel('Emergency Contact', context),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: SG.danger.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: SG.danger.withOpacity(0.2)),
        ),
        child: Row(children: [
          Icon(Icons.info_outline, color: SG.danger, size: 16),
          SizedBox(width: 10),
          Expanded(child: Text(
            'This person will be called first in any emergency.',
            style: TextStyle(fontSize: 12, color: SG.danger.withOpacity(0.8)),
          )),
        ]),
      ),
      SizedBox(height: 14),
      _DarkInput(ctrl: _ecNameCtrl, label: 'Contact name',
          hint: 'e.g. Sarah Johnson'),
      SizedBox(height: 12),
      _DarkInput(ctrl: _ecPhoneCtrl, label: 'Phone number',
          hint: '+91 98765 43210',
          type: TextInputType.phone),
      SizedBox(height: 12),
      _DarkInput(ctrl: _ecRelCtrl, label: 'Relationship',
          hint: 'e.g. Daughter, Son, Spouse'),
    ],
  );

  // ── Step 3: Doctor ─────────────────────────────────────────────────────────
  Widget _stepDoctor() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sheetLabel('Doctor / Care Provider', context),
      _DarkInput(ctrl: _drNameCtrl, label: 'Doctor\'s name',
          hint: 'e.g. Dr. Anil Kumar'),
      SizedBox(height: 12),
      _DarkInput(ctrl: _drPhoneCtrl, label: 'Clinic / Mobile',
          hint: '+91 80 2345 6789',
          type: TextInputType.phone),
      SizedBox(height: 12),
      _DarkInput(ctrl: _drHospitalCtrl, label: 'Hospital / Clinic',
          hint: 'e.g. Manipal Hospital, Bangalore'),
    ],
  );

  Widget _sheetLabel(String text, BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text, style: TextStyle(
      fontSize: 11, fontWeight: FontWeight.w700,
      color: SGTheme.of(context).textMuted, letterSpacing: 1,
    )),
  );
}

// ── Chip selector widget ──────────────────────────────────────────────────────

class _ChipSelector extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;
  final List<Color>? colors;

  const _ChipSelector({
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8, runSpacing: 8,
    children: List.generate(options.length, (i) {
      final opt      = options[i];
      final isActive = opt == selected;
      final color    = colors != null && i < colors!.length
          ? colors![i]
          : SG.accent;
      return GestureDetector(
        onTap: () => onChanged(opt),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? color.withOpacity(0.15) : SG.navySurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive ? color : SG.navyBorder,
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Text(opt, style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600,
            color: isActive ? color : SG.textSecondary,
          )),
        ),
      );
    }),
  );
}
