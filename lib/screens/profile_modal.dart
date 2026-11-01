import 'package:flutter/material.dart';
import '../models/portal_models.dart';
import '../services/api_service.dart';
import '../theme/portal_theme.dart';
import '../widgets/common_widgets.dart';

/// Replicates `#profile-screen`, `#survey-warning-modal`, and `#change-pass-modal`
/// from `index.html`. Supports both mandatory completion gate (non-dismissible)
/// and on-demand View/Edit mode.
class StudentProfileSheet extends StatefulWidget {
  final String studentId;
  final StudentProfile initialProfile;
  final bool mandatoryCompletion;
  final ValueChanged<StudentProfile> onProfileSaved;

  const StudentProfileSheet({
    super.key,
    required this.studentId,
    required this.initialProfile,
    required this.mandatoryCompletion,
    required this.onProfileSaved,
  });

  @override
  State<StudentProfileSheet> createState() => _StudentProfileSheetState();
}

class _StudentProfileSheetState extends State<StudentProfileSheet> {
  late bool _editMode;
  late StudentProfile _currentProfile;

  final _fatherNameCtrl = TextEditingController();
  final _fatherContactCtrl = TextEditingController();
  final _motherNameCtrl = TextEditingController();
  final _motherContactCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  bool _naFatherName = false;
  bool _naFatherContact = false;
  bool _naMotherName = false;
  bool _naMotherContact = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _currentProfile = widget.initialProfile;
    _editMode = widget.mandatoryCompletion || !_currentProfile.isComplete;
    _hydrateEditors(_currentProfile);
  }

  void _hydrateEditors(StudentProfile p) {
    _naFatherName = p.fatherName == 'N/A';
    _fatherNameCtrl.text = _naFatherName ? '' : p.fatherName;

    _naFatherContact = p.fatherContact == 'N/A';
    _fatherContactCtrl.text = _naFatherContact ? '' : p.fatherContact;

    _naMotherName = p.motherName == 'N/A';
    _motherNameCtrl.text = _naMotherName ? '' : p.motherName;

    _naMotherContact = p.motherContact == 'N/A';
    _motherContactCtrl.text = _naMotherContact ? '' : p.motherContact;

    _addressCtrl.text = p.address;
    _emailCtrl.text = p.email;
  }

  @override
  void dispose() {
    _fatherNameCtrl.dispose();
    _fatherContactCtrl.dispose();
    _motherNameCtrl.dispose();
    _motherContactCtrl.dispose();
    _addressCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmAndSubmit() async {
    final fName = _naFatherName ? 'N/A' : _fatherNameCtrl.text.trim();
    final fContact = _naFatherContact ? 'N/A' : _fatherContactCtrl.text.trim();
    final mName = _naMotherName ? 'N/A' : _motherNameCtrl.text.trim();
    final mContact = _naMotherContact ? 'N/A' : _motherContactCtrl.text.trim();
    final address = _addressCtrl.text.trim();
    final email = _emailCtrl.text.trim();

    if (fName.isEmpty ||
        fContact.isEmpty ||
        mName.isEmpty ||
        mContact.isEmpty ||
        address.isEmpty ||
        email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please fill in all fields or check 'Not Applicable'.",
          ),
        ),
      );
      return;
    }

    // Show certification notice (#survey-warning-modal)
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Important Notice',
          textAlign: TextAlign.center,
          style: PortalTheme.serif(size: 24, color: PortalColors.burg),
        ),
        content: Text(
          'By submitting this form, you certify that the information provided is true and correct. Providing false information may be subject to disciplinary action.',
          textAlign: TextAlign.center,
          style: PortalTheme.sans(size: 13.5, color: PortalColors.ink2),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Review Again'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: PortalColors.forest,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('I Confirm & Submit'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final updated = StudentProfile(
      fatherName: fName,
      fatherContact: fContact,
      motherName: mName,
      motherContact: mContact,
      address: address,
      email: email,
    );

    setState(() => _saving = true);
    try {
      final res = await PortalLoadingOverlay.run(
        context,
        message: 'Saving Student Profile...',
        subtitle: 'Updating your guardian & contact records',
        task: () => ApiService.instance.saveStudentProfile(
          id: widget.studentId,
          profile: updated,
        ),
      );
      if (res['success'] == true) {
        _currentProfile = updated;
        widget.onProfileSaved(updated);
        if (widget.mandatoryCompletion) {
          if (mounted) Navigator.of(context).pop(updated);
        } else {
          setState(() => _editMode = false);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']?.toString() ?? 'Failed to save.'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving profile: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openChangePasswordDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => _ChangePasswordOtpDialog(studentId: widget.studentId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.mandatoryCompletion,
      child: Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Student Information Profile',
                  textAlign: TextAlign.center,
                  style: PortalTheme.serif(size: 25, italic: true),
                ),
                const SizedBox(height: 16),
                if (!_editMode)
                  _buildViewMode()
                else
                  _buildEditMode(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewMode() {
    Widget row(String label, String val) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: RichText(
          text: TextSpan(
            style: PortalTheme.sans(size: 13.5, color: PortalColors.ink),
            children: [
              TextSpan(
                text: '$label: ',
                style: PortalTheme.sans(
                  size: 13.5,
                  weight: FontWeight.w700,
                  color: PortalColors.forest,
                ),
              ),
              TextSpan(text: val.isEmpty ? 'Not Provided' : val),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: PortalColors.parchment,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: PortalColors.ruleMed),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              row("Father's Name", _currentProfile.fatherName),
              row("Father's Contact", _currentProfile.fatherContact),
              row("Mother's Name", _currentProfile.motherName),
              row("Mother's Contact", _currentProfile.motherContact),
              row('Permanent Address', _currentProfile.address),
              row('Active Email', _currentProfile.email),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: PortalColors.goldDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                onPressed: () {
                  _hydrateEditors(_currentProfile);
                  setState(() => _editMode = true);
                },
                child: const Text('Edit / Update'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(),
        Center(
          child: TextButton.icon(
            onPressed: _openChangePasswordDialog,
            icon: const Icon(Icons.lock_reset_rounded, size: 18),
            label: const Text('Change Password (Email OTP)'),
          ),
        ),
      ],
    );
  }

  Widget _buildEditMode() {
    Widget naField({
      required TextEditingController ctrl,
      required String hint,
      required bool isNa,
      required ValueChanged<bool> onChangedNa,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ctrl,
              enabled: !isNa,
              decoration: InputDecoration(
                hintText: hint,
                filled: true,
                fillColor: isNa ? PortalColors.parchmentDk : PortalColors.parchment,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            Row(
              children: [
                Checkbox(
                  value: isNa,
                  visualDensity: VisualDensity.compact,
                  onChanged: (v) {
                    final checked = v ?? false;
                    if (checked) ctrl.clear();
                    onChangedNa(checked);
                  },
                ),
                Text(
                  'Not Applicable',
                  style: PortalTheme.sans(size: 11.5, color: PortalColors.ink2),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.mandatoryCompletion
              ? 'Complete your student profile once to unlock your academic records.'
              : 'Please provide accurate information.',
          textAlign: TextAlign.center,
          style: PortalTheme.sans(
            size: 12.5,
            weight: FontWeight.w600,
            color: PortalColors.burg,
          ),
        ),
        const SizedBox(height: 14),
        naField(
          ctrl: _fatherNameCtrl,
          hint: "Father's Name",
          isNa: _naFatherName,
          onChangedNa: (v) => setState(() => _naFatherName = v),
        ),
        naField(
          ctrl: _fatherContactCtrl,
          hint: "Father's Contact Number",
          isNa: _naFatherContact,
          onChangedNa: (v) => setState(() => _naFatherContact = v),
        ),
        naField(
          ctrl: _motherNameCtrl,
          hint: "Mother's Name",
          isNa: _naMotherName,
          onChangedNa: (v) => setState(() => _naMotherName = v),
        ),
        naField(
          ctrl: _motherContactCtrl,
          hint: "Mother's Contact Number",
          isNa: _naMotherContact,
          onChangedNa: (v) => setState(() => _naMotherContact = v),
        ),
        TextField(
          controller: _addressCtrl,
          decoration: InputDecoration(
            hintText: 'Permanent Address (Purok, Brgy, Municipality, Province)',
            filled: true,
            fillColor: PortalColors.parchment,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: 'Active Email Address',
            filled: true,
            fillColor: PortalColors.parchment,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: PortalColors.forest,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: _saving ? null : _confirmAndSubmit,
          child: Text(_saving ? 'Saving Profile...' : 'SAVE PROFILE'),
        ),
        if (!widget.mandatoryCompletion) ...[
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _saving ? null : () => setState(() => _editMode = false),
            child: const Text('Cancel'),
          ),
        ],
      ],
    );
  }
}

class _ChangePasswordOtpDialog extends StatefulWidget {
  final String studentId;

  const _ChangePasswordOtpDialog({required this.studentId});

  @override
  State<_ChangePasswordOtpDialog> createState() =>
      _ChangePasswordOtpDialogState();
}

class _ChangePasswordOtpDialogState extends State<_ChangePasswordOtpDialog> {
  int _step = 1;
  bool _loading = false;
  String? _error;
  final _otpCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  @override
  void dispose() {
    _otpCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiService.instance.generateAndSendOTP(widget.studentId);
      if (res['success'] == true) {
        setState(() => _step = 2);
      } else {
        setState(() => _error = res['message']?.toString() ?? 'Failed.');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _savePassword() async {
    final otp = _otpCtrl.text.trim();
    final newPass = _passCtrl.text.trim();
    if (otp.isEmpty || newPass.isEmpty) {
      setState(() => _error = 'Enter both the 6-digit OTP and new password.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiService.instance.verifyOTPAndResetPassword(
        id: widget.studentId,
        otp: otp,
        newPassword: newPass,
      );
      if (res['success'] == true) {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password updated successfully!')),
          );
        }
      } else {
        setState(() => _error = res['message']?.toString() ?? 'Failed.');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Change Password', style: PortalTheme.serif(size: 24)),
            const SizedBox(height: 10),
            if (_error != null) ...[
              Text(
                '⚠️ $_error',
                textAlign: TextAlign.center,
                style: PortalTheme.sans(
                  size: 12.5,
                  weight: FontWeight.w600,
                  color: PortalColors.burg,
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_step == 1) ...[
              Text(
                'We will send a 6-digit OTP to your registered email address.',
                textAlign: TextAlign.center,
                style: PortalTheme.sans(size: 13, color: PortalColors.ink3),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _loading ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PortalColors.gold,
                        foregroundColor: PortalColors.forest,
                      ),
                      onPressed: _loading ? null : _sendOtp,
                      child: Text(_loading ? 'Sending...' : 'Send OTP'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              TextField(
                controller: _otpCtrl,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Enter 6-digit OTP',
                  filled: true,
                  fillColor: PortalColors.parchment,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passCtrl,
                obscureText: true,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: 'New Password',
                  filled: true,
                  fillColor: PortalColors.parchment,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _loading ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PortalColors.gold,
                        foregroundColor: PortalColors.forest,
                      ),
                      onPressed: _loading ? null : _savePassword,
                      child: Text(_loading ? 'Saving...' : 'Save Password'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
