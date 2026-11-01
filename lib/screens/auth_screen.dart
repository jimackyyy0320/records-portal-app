import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/portal_models.dart';
import '../services/api_service.dart';
import '../theme/portal_theme.dart';
import '../widgets/common_widgets.dart';

enum _AuthMode { studentLogin, register, forgot, facultyLogin }

class AuthScreen extends StatefulWidget {
  final ValueChanged<UserSession> onAuthenticated;
  final bool initialFacultyMode;

  const AuthScreen({
    super.key,
    required this.onAuthenticated,
    this.initialFacultyMode = false,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late _AuthMode _mode = widget.initialFacultyMode
      ? _AuthMode.facultyLogin
      : _AuthMode.studentLogin;
  bool _loading = false;
  String? _message;
  bool _isSuccessMsg = false;

  // Student Login
  final _loginIdCtrl = TextEditingController();
  final _loginPassCtrl = TextEditingController();

  // Student Register
  final _regIdCtrl = TextEditingController();
  DateTime? _regBirthdate;
  final _regPassCtrl = TextEditingController();

  // Forgot Password OTP
  int _forgotStep = 1;
  final _forgotIdCtrl = TextEditingController();
  final _forgotOtpCtrl = TextEditingController();
  final _forgotNewPassCtrl = TextEditingController();

  // Faculty Login
  final _facIdCtrl = TextEditingController();
  final _facPassCtrl = TextEditingController();

  @override
  void dispose() {
    _loginIdCtrl.dispose();
    _loginPassCtrl.dispose();
    _regIdCtrl.dispose();
    _regPassCtrl.dispose();
    _forgotIdCtrl.dispose();
    _forgotOtpCtrl.dispose();
    _forgotNewPassCtrl.dispose();
    _facIdCtrl.dispose();
    _facPassCtrl.dispose();
    super.dispose();
  }

  void _switchMode(_AuthMode next) {
    setState(() {
      _mode = next;
      _message = null;
      _isSuccessMsg = false;
      if (next == _AuthMode.forgot) _forgotStep = 1;
    });
  }

  void _setFeedback(String msg, {bool success = false}) {
    setState(() {
      _message = msg;
      _isSuccessMsg = success;
    });
  }

  Future<void> _handleStudentLogin() async {
    final id = _loginIdCtrl.text.trim();
    final pass = _loginPassCtrl.text;
    if (id.isEmpty || pass.isEmpty) {
      _setFeedback('Required fields missing.');
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final res = await ApiService.instance.loginStudent(id: id, password: pass);
      if (res['success'] != true) {
        _setFeedback(res['message']?.toString() ?? 'Invalid ID or Password.');
        return;
      }
      final avatar = await ApiService.instance.getStudentAvatar(id);
      final subjects = (res['subjects'] as List?)
              ?.whereType<Map>()
              .map((e) => SubjectItem.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          const <SubjectItem>[];
      final schedule = (res['schedule'] as List?)
              ?.whereType<Map>()
              .map(
                (e) => ClassScheduleItem.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList() ??
          const <ClassScheduleItem>[];
      final profile = StudentProfile.fromJson(
        res['profile'] is Map
            ? Map<String, dynamic>.from(res['profile'] as Map)
            : null,
      );

      widget.onAuthenticated(
        UserSession(
          id: id,
          name: res['studentName']?.toString() ?? id,
          isFaculty: false,
          subjects: subjects,
          schedule: schedule,
          profile: profile,
          avatarDataUrl: avatar,
        ),
      );
    } catch (e) {
      _setFeedback(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleRegister() async {
    final id = _regIdCtrl.text.trim();
    final pass = _regPassCtrl.text;
    if (id.isEmpty || _regBirthdate == null || pass.isEmpty) {
      _setFeedback('Fill out all fields.');
      return;
    }
    final bdateStr = DateFormat('yyyy-MM-dd').format(_regBirthdate!);

    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final res = await ApiService.instance.registerStudent(
        id: id,
        bdate: bdateStr,
        password: pass,
      );
      if (res['success'] != true) {
        _setFeedback(res['message']?.toString() ?? 'Registration failed.');
        return;
      }
      _loginIdCtrl.text = id;
      _loginPassCtrl.clear();
      _switchMode(_AuthMode.studentLogin);
      _setFeedback(
        res['message']?.toString() ?? 'Registration successful!',
        success: true,
      );
    } catch (e) {
      _setFeedback(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleForgotSendOtp() async {
    final id = _forgotIdCtrl.text.trim();
    if (id.isEmpty) {
      _setFeedback('Please enter your Student ID.');
      return;
    }
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final res = await ApiService.instance.generateAndSendOTP(id);
      if (res['success'] == true) {
        setState(() => _forgotStep = 2);
      } else {
        _setFeedback(res['message']?.toString() ?? 'Failed to send OTP.');
      }
    } catch (e) {
      _setFeedback(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleForgotReset() async {
    final id = _forgotIdCtrl.text.trim();
    final otp = _forgotOtpCtrl.text.trim();
    final newPass = _forgotNewPassCtrl.text;
    if (otp.isEmpty || newPass.isEmpty) {
      _setFeedback('Please enter OTP and new password.');
      return;
    }
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final res = await ApiService.instance.verifyOTPAndResetPassword(
        id: id,
        otp: otp,
        newPassword: newPass,
      );
      if (res['success'] == true) {
        _switchMode(_AuthMode.studentLogin);
        _setFeedback(
          res['message']?.toString() ?? 'Password updated!',
          success: true,
        );
      } else {
        _setFeedback(res['message']?.toString() ?? 'Reset failed.');
      }
    } catch (e) {
      _setFeedback(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleFacultyLogin() async {
    final id = _facIdCtrl.text.trim();
    final pass = _facPassCtrl.text;
    if (id.isEmpty || pass.isEmpty) {
      _setFeedback('Required fields missing.');
      return;
    }
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final res = await ApiService.instance.loginFaculty(id: id, password: pass);
      if (res['success'] != true) {
        _setFeedback(
          res['message']?.toString() ?? 'Invalid Faculty Credentials.',
        );
        return;
      }
      final subjects = (res['subjects'] as List?)
              ?.whereType<Map>()
              .map((e) => SubjectItem.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          const <SubjectItem>[];

      final facSession = UserSession(
        id: id,
        name: res['facName']?.toString() ?? id,
        isFaculty: true,
        subjects: subjects,
        scannerAuthToken: res['scannerAuthToken']?.toString(),
      );

      // Pre-warm offline scanner Reference Column C cache upon Faculty login
      ApiService.instance.fetchScannerBootstrap(sessionOverride: facSession);

      widget.onAuthenticated(facSession);
    } catch (e) {
      _setFeedback(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _neumorphicInput({
    required TextEditingController controller,
    required String hint,
    required String emoji,
    bool obscure = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x161A3A2A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        autocorrect: false,
        enableSuggestions: !obscure,
        style: PortalTheme.sans(size: 15, weight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: PortalTheme.sans(size: 15, color: PortalColors.ink3),
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(emoji, style: const TextStyle(fontSize: 18)),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 48),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 15,
          ),
        ),
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required VoidCallback onPressed,
    Color background = PortalColors.forest,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 4,
        ),
        onPressed: _loading ? null : onPressed,
        child: Text(
          _loading ? 'PLEASE WAIT…' : label.toUpperCase(),
          style: PortalTheme.sans(
            size: 14,
            weight: FontWeight.w700,
            letterSpacing: 0.6,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showToggle =
        _mode == _AuthMode.studentLogin || _mode == _AuthMode.facultyLogin;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            children: [
              PortalHeader(
                onOpenSettings: () {
                  showDialog<bool>(
                    context: context,
                    builder: (_) => const BackendConfigDialog(),
                  );
                },
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 26),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.white, PortalColors.parchment],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x261A3A2A),
                      blurRadius: 36,
                      offset: Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    if (showToggle) ...[
                      Container(
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: PortalColors.rule,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _toggleTab(
                                label: 'Student',
                                active: _mode == _AuthMode.studentLogin,
                                onTap: () =>
                                    _switchMode(_AuthMode.studentLogin),
                              ),
                            ),
                            Expanded(
                              child: _toggleTab(
                                label: 'Faculty',
                                active: _mode == _AuthMode.facultyLogin,
                                onTap: () =>
                                    _switchMode(_AuthMode.facultyLogin),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (_message != null) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Text(
                          '${_isSuccessMsg ? "✅" : "⚠️"} $_message',
                          textAlign: TextAlign.center,
                          style: PortalTheme.sans(
                            size: 13,
                            weight: FontWeight.w600,
                            color: _isSuccessMsg
                                ? PortalColors.forest
                                : PortalColors.burg,
                          ),
                        ),
                      ),
                    ],
                    if (_mode == _AuthMode.studentLogin) _buildStudentLogin(),
                    if (_mode == _AuthMode.register) _buildRegister(),
                    if (_mode == _AuthMode.forgot) _buildForgot(),
                    if (_mode == _AuthMode.facultyLogin) _buildFacultyLogin(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toggleTab({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              label,
              style: PortalTheme.sans(
                size: 16,
                weight: FontWeight.w700,
                color: active ? PortalColors.forest : PortalColors.ink3,
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 3,
            width: active ? 90 : 0,
            decoration: BoxDecoration(
              color: PortalColors.gold,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentLogin() {
    return Column(
      children: [
        _neumorphicInput(
          controller: _loginIdCtrl,
          hint: 'Student ID',
          emoji: '🎓',
        ),
        _neumorphicInput(
          controller: _loginPassCtrl,
          hint: 'Password',
          emoji: '🔒',
          obscure: true,
        ),
        const SizedBox(height: 8),
        _primaryButton(label: 'Log In', onPressed: _handleStudentLogin),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => _switchMode(_AuthMode.forgot),
          child: Text(
            'Forgot Password?',
            style: PortalTheme.sans(
              size: 13.5,
              weight: FontWeight.w700,
              color: PortalColors.forest,
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'First time logging in? ',
              style: PortalTheme.sans(size: 13.5, color: PortalColors.ink3),
            ),
            GestureDetector(
              onTap: () => _switchMode(_AuthMode.register),
              child: Text(
                'Register here',
                style: PortalTheme.sans(
                  size: 13.5,
                  weight: FontWeight.w700,
                  color: PortalColors.forest,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRegister() {
    final bdateText = _regBirthdate == null
        ? 'Select Birthdate'
        : DateFormat('MMMM d, yyyy').format(_regBirthdate!);

    return Column(
      children: [
        Text('Student Registration', style: PortalTheme.serif(size: 24)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: PortalColors.burgBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: PortalColors.burgBorder),
          ),
          child: Text(
            '⚠️ Your Birthdate and Password will be permanently locked to your ID. Ensure your details are correct.',
            style: PortalTheme.sans(
              size: 12,
              weight: FontWeight.w600,
              color: PortalColors.burg,
            ),
          ),
        ),
        _neumorphicInput(
          controller: _regIdCtrl,
          hint: 'Student ID',
          emoji: '🎓',
        ),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _regBirthdate ?? DateTime(2008, 1, 1),
              firstDate: DateTime(1985),
              lastDate: DateTime.now(),
            );
            if (picked != null) setState(() => _regBirthdate = picked);
          },
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x161A3A2A),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                const Text('📅', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 14),
                Text(
                  bdateText,
                  style: PortalTheme.sans(
                    size: 15,
                    color: _regBirthdate == null
                        ? PortalColors.ink3
                        : PortalColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
        _neumorphicInput(
          controller: _regPassCtrl,
          hint: 'Create Password',
          emoji: '🔒',
          obscure: true,
        ),
        const SizedBox(height: 8),
        _primaryButton(label: 'Register Account', onPressed: _handleRegister),
        const SizedBox(height: 14),
        TextButton(
          onPressed: () => _switchMode(_AuthMode.studentLogin),
          child: const Text('← Already registered? Log in here'),
        ),
      ],
    );
  }

  Widget _buildForgot() {
    return Column(
      children: [
        Text('Reset Password', style: PortalTheme.serif(size: 24)),
        const SizedBox(height: 14),
        if (_forgotStep == 1) ...[
          _neumorphicInput(
            controller: _forgotIdCtrl,
            hint: 'Student ID',
            emoji: '🎓',
          ),
          const SizedBox(height: 6),
          _primaryButton(label: 'Send OTP', onPressed: _handleForgotSendOtp),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: PortalColors.emeraldBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: PortalColors.emeraldBorder),
            ),
            child: Text(
              '✅ OTP sent to your registered email.',
              style: PortalTheme.sans(
                size: 12.5,
                weight: FontWeight.w600,
                color: PortalColors.emerald,
              ),
            ),
          ),
          _neumorphicInput(
            controller: _forgotOtpCtrl,
            hint: 'Enter 6-digit OTP',
            emoji: '🔢',
          ),
          _neumorphicInput(
            controller: _forgotNewPassCtrl,
            hint: 'New Password',
            emoji: '🔒',
            obscure: true,
          ),
          const SizedBox(height: 6),
          _primaryButton(
            label: 'Reset Password',
            onPressed: _handleForgotReset,
          ),
        ],
        const SizedBox(height: 14),
        TextButton(
          onPressed: () => _switchMode(_AuthMode.studentLogin),
          child: const Text('← Back to Login'),
        ),
      ],
    );
  }

  Widget _buildFacultyLogin() {
    return Column(
      children: [
        _neumorphicInput(
          controller: _facIdCtrl,
          hint: 'Faculty ID',
          emoji: '🏫',
        ),
        _neumorphicInput(
          controller: _facPassCtrl,
          hint: 'Password',
          emoji: '🔑',
          obscure: true,
        ),
        const SizedBox(height: 8),
        _primaryButton(
          label: 'Log In to LMS',
          background: PortalColors.burg,
          onPressed: _handleFacultyLogin,
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: PortalColors.parchment,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: PortalColors.ruleMed),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.verified_user_rounded,
                size: 18,
                color: PortalColors.forest,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Attendance & Recitation QR/NFC scanning is restricted to authenticated Faculty accounts (stays unlocked offline while signed in).',
                  style: PortalTheme.sans(size: 12, color: PortalColors.ink2),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
