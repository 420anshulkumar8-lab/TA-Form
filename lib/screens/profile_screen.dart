// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/employee_profile.dart';
import '../providers/app_provider.dart';
import '../config/ta_rates.dart';

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
  late TextEditingController _basicPayCtrl;
  late TextEditingController _hqCtrl;
  late TextEditingController _hqCodeCtrl;   // from Claude_Original
  late TextEditingController _divisionCtrl;
  late TextEditingController _mobileCtrl;
  late TextEditingController _employeeIdCtrl;

  // Grade level dropdown (from Claude_Original - much better than free text!)
  String _gradeLevel = 'Level-6';
  final List<String> _gradeLevels =
      List.generate(14, (i) => 'Level-${i + 1}');

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
    _basicPayCtrl = TextEditingController(
        text: profile.basicPay > 0 ? profile.basicPay.toStringAsFixed(0) : '');
    _hqCtrl = TextEditingController(text: profile.headquarters);
    _hqCodeCtrl = TextEditingController(text: profile.hqStationCode);
    _divisionCtrl = TextEditingController(text: profile.division);
    _mobileCtrl = TextEditingController(text: profile.mobile);
    _employeeIdCtrl = TextEditingController(text: profile.employeeId);
    _dateOfAppointment = profile.dateOfAppointment;
    _gradeLevel = profile.gradeLevel.isNotEmpty ? profile.gradeLevel : 'Level-6';
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _designationCtrl, _basicPayCtrl,
      _hqCtrl, _hqCodeCtrl, _divisionCtrl, _mobileCtrl, _employeeIdCtrl,
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

    final profile = EmployeeProfile(
      name: _nameCtrl.text.trim(),
      designation: _designationCtrl.text.trim(),
      gradeLevel: _gradeLevel,
      basicPay: double.tryParse(_basicPayCtrl.text.trim()) ?? 0,
      dateOfAppointment: _dateOfAppointment,
      headquarters: _hqCtrl.text.trim(),
      hqStationCode: _hqCodeCtrl.text.trim().toUpperCase(),
      division: _divisionCtrl.text.trim(),
      mobile: _mobileCtrl.text.trim(),
      employeeId: _employeeIdCtrl.text.trim(),
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
    final rates = TaRates.ratesForGradeLevel(_gradeLevel);

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
            _buildField(label: 'Employee Name *', controller: _nameCtrl,
                enabled: _isEditing,
                validator: (v) => v!.trim().isEmpty ? 'Required' : null),
            _buildField(label: 'Designation *', controller: _designationCtrl,
                enabled: _isEditing,
                validator: (v) => v!.trim().isEmpty ? 'Required' : null),
            _buildField(label: 'Employee ID', controller: _employeeIdCtrl,
                enabled: _isEditing),
            _buildField(label: 'Mobile Number (10 digits)',
                controller: _mobileCtrl, enabled: _isEditing,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: (v) {
                  if (v!.trim().isEmpty) return null;
                  if (v.trim().length != 10) return 'Must be 10 digits';
                  return null;
                }),
            _buildField(label: 'Headquarters *  (e.g. Ghaziabad)',
                controller: _hqCtrl, enabled: _isEditing,
                validator: (v) => v!.trim().isEmpty ? 'Required' : null),
            // HQ Station Code — from Claude_Original (needed for AI prompt)
            _buildField(label: 'HQ Station Code  (e.g. GZB, NDLS)',
                controller: _hqCodeCtrl, enabled: _isEditing),
            _buildField(label: 'Division *', controller: _divisionCtrl,
                enabled: _isEditing,
                validator: (v) => v!.trim().isEmpty ? 'Required' : null),
            _buildField(label: 'Basic Pay *', controller: _basicPayCtrl,
                enabled: _isEditing,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v!.trim().isEmpty) return 'Required';
                  if (double.tryParse(v.trim()) == null) return 'Enter valid number';
                  return null;
                }),

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
            const SizedBox(height: 16),

            // Grade Level Dropdown (from Claude_Original — much better!)
            DropdownButtonFormField<String>(
              value: _gradeLevel,
              decoration: const InputDecoration(
                labelText: 'Grade Pay Level *',
                border: OutlineInputBorder(),
              ),
              items: _gradeLevels
                  .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                  .toList(),
              onChanged: _isEditing
                  ? (v) => setState(() => _gradeLevel = v!)
                  : null,
            ),
            const SizedBox(height: 16),

            // Auto-calculated TA rates display
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.08),
                border: Border.all(color: Colors.blue.shade200),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Your TA Rates (auto-calculated)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 6),
                  Text('TA Rate: Rs. ${rates.taPerKm}/km',
                      style: const TextStyle(fontSize: 14)),
                  Text('DA Rate: Rs. ${rates.daPerDay.toStringAsFixed(0)}/day',
                      style: const TextStyle(fontSize: 14)),
                ],
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
