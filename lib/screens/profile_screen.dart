// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/employee_profile.dart';
import '../providers/app_provider.dart';
import '../config/railway_options.dart';
import '../config/department_options.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isEditing = false;

  late TextEditingController _nameCtrl;
  late TextEditingController _designationCtrl;
  late TextEditingController _employeeNoCtrl;
  late TextEditingController _divisionCtrl;
  late TextEditingController _headquarterCtrl;
  late TextEditingController _basicPayCtrl;
  late TextEditingController _railwayOtherCtrl;
  late TextEditingController _departmentOtherCtrl;

  int _level = 1;
  String _railway = RailwayOptions.list.first;
  String _department = DepartmentOptions.list.first;
  String _dateOfAppointment = '';

  @override
  void initState() {
    super.initState();
    final profile = context.read<AppProvider>().profile;
    _initControllers(profile);
  }

  void _initControllers(EmployeeProfile profile) {
    _nameCtrl = TextEditingController(text: profile.name);
    _designationCtrl = TextEditingController(text: profile.designation);
    _employeeNoCtrl = TextEditingController(text: profile.employeeNo);
    _divisionCtrl = TextEditingController(text: profile.division);
    _headquarterCtrl = TextEditingController(text: profile.headquarter);
    _basicPayCtrl = TextEditingController(
        text: profile.basicPay > 0 ? profile.basicPay.toStringAsFixed(0) : '');
    _dateOfAppointment = profile.dateOfAppointment;
    _level = profile.level >= 1 && profile.level <= 9 ? profile.level : 1;

    // Railway: if the saved value is in the fixed list, select it; else it
    // was a custom "Other" value.
    if (profile.railway.isNotEmpty &&
        RailwayOptions.list.contains(profile.railway)) {
      _railway = profile.railway;
      _railwayOtherCtrl = TextEditingController();
    } else if (profile.railway.isNotEmpty) {
      _railway = RailwayOptions.other;
      _railwayOtherCtrl = TextEditingController(text: profile.railway);
    } else {
      _railway = RailwayOptions.list.first;
      _railwayOtherCtrl = TextEditingController();
    }

    // Department: same pattern
    if (profile.department.isNotEmpty &&
        DepartmentOptions.list.contains(profile.department)) {
      _department = profile.department;
      _departmentOtherCtrl = TextEditingController();
    } else if (profile.department.isNotEmpty) {
      _department = DepartmentOptions.other;
      _departmentOtherCtrl = TextEditingController(text: profile.department);
    } else {
      _department = DepartmentOptions.list.first;
      _departmentOtherCtrl = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _designationCtrl,
      _employeeNoCtrl,
      _divisionCtrl,
      _headquarterCtrl,
      _basicPayCtrl,
      _railwayOtherCtrl,
      _departmentOtherCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    if (!_isEditing) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2010),
      firstDate: DateTime(1970),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dateOfAppointment = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final railwayValue = _railway == RailwayOptions.other
        ? _railwayOtherCtrl.text.trim()
        : _railway;
    final departmentValue = _department == DepartmentOptions.other
        ? _departmentOtherCtrl.text.trim()
        : _department;

    final profile = EmployeeProfile(
      name: _nameCtrl.text.trim(),
      designation: _designationCtrl.text.trim(),
      level: _level,
      basicPay: double.tryParse(_basicPayCtrl.text.trim()) ?? 0,
      dateOfAppointment: _dateOfAppointment,
      headquarter: _headquarterCtrl.text.trim(),
      division: _divisionCtrl.text.trim(),
      employeeNo: _employeeNoCtrl.text.trim(),
      railway: railwayValue,
      department: departmentValue,
    );

    await context.read<AppProvider>().saveProfile(profile);

    if (mounted) {
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _cancelEdit() {
    final profile = context.read<AppProvider>().profile;
    _initControllers(profile);
    setState(() => _isEditing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Profile'),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit',
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildField(
                label: 'Name *',
                controller: _nameCtrl,
                enabled: _isEditing,
                validator: (v) => v!.trim().isEmpty ? 'Required' : null),
            _buildField(
                label: 'Designation *',
                controller: _designationCtrl,
                enabled: _isEditing,
                validator: (v) => v!.trim().isEmpty ? 'Required' : null),

            // Level picker (1-9)
            _buildLevelPicker(),

            _buildField(
                label: 'Employee No. *',
                controller: _employeeNoCtrl,
                enabled: _isEditing,
                validator: (v) => v!.trim().isEmpty ? 'Required' : null),

            // Railway dropdown + Other
            _buildRailwayField(),

            _buildField(
                label: 'Division *',
                controller: _divisionCtrl,
                enabled: _isEditing,
                validator: (v) => v!.trim().isEmpty ? 'Required' : null),
            _buildField(
                label: 'Headquarter *',
                controller: _headquarterCtrl,
                enabled: _isEditing,
                validator: (v) => v!.trim().isEmpty ? 'Required' : null),

            // Department dropdown + Other
            _buildDepartmentField(),

            _buildField(
              label: 'Basic Pay * (5-6 digit)',
              controller: _basicPayCtrl,
              enabled: _isEditing,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              validator: (v) {
                if (v!.trim().isEmpty) return 'Required';
                final digits = v.trim().length;
                if (digits < 5 || digits > 6) {
                  return 'Must be 5 or 6 digits';
                }
                return null;
              },
            ),

            // Date of appointment
            GestureDetector(
              onTap: _pickDate,
              child: AbsorbPointer(
                child: TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Date of Appointment',
                    border: const OutlineInputBorder(),
                    suffixIcon: const Icon(Icons.calendar_today),
                    enabled: _isEditing,
                  ),
                  controller: TextEditingController(text: _dateOfAppointment),
                ),
              ),
            ),
            const SizedBox(height: 24),

            if (_isEditing)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _cancelEdit,
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelPicker() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<int>(
        value: _level,
        decoration: const InputDecoration(
          labelText: 'Level *',
          border: OutlineInputBorder(),
        ),
        items: List.generate(9, (i) => i + 1)
            .map((l) => DropdownMenuItem(value: l, child: Text('Level $l')))
            .toList(),
        onChanged: _isEditing ? (v) => setState(() => _level = v ?? 1) : null,
      ),
    );
  }

  Widget _buildRailwayField() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: DropdownButtonFormField<String>(
            value: _railway,
            decoration: const InputDecoration(
              labelText: 'Railway *',
              border: OutlineInputBorder(),
            ),
            isExpanded: true,
            items: RailwayOptions.list
                .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                .toList(),
            onChanged: _isEditing
                ? (v) => setState(() => _railway = v ?? RailwayOptions.list.first)
                : null,
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ),
        ),
        if (_railway == RailwayOptions.other)
          _buildField(
            label: 'Specify Railway *',
            controller: _railwayOtherCtrl,
            enabled: _isEditing,
            validator: (v) {
              if (_railway == RailwayOptions.other && v!.trim().isEmpty) {
                return 'Required';
              }
              return null;
            },
          ),
      ],
    );
  }

  Widget _buildDepartmentField() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: DropdownButtonFormField<String>(
            value: _department,
            decoration: const InputDecoration(
              labelText: 'Department *',
              border: OutlineInputBorder(),
            ),
            isExpanded: true,
            items: DepartmentOptions.list
                .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                .toList(),
            onChanged: _isEditing
                ? (v) => setState(
                    () => _department = v ?? DepartmentOptions.list.first)
                : null,
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ),
        ),
        if (_department == DepartmentOptions.other)
          _buildField(
            label: 'Specify Department *',
            controller: _departmentOtherCtrl,
            enabled: _isEditing,
            validator: (v) {
              if (_department == DepartmentOptions.other &&
                  v!.trim().isEmpty) {
                return 'Required';
              }
              return null;
            },
          ),
      ],
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required bool enabled,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        validator: validator,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
