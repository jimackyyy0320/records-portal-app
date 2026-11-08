import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/portal_models.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/portal_theme.dart';
import '../widgets/common_widgets.dart';

enum _AuthMode { studentLogin, register, forgot, facultyLogin }

class AuthScreen extends StatefulWidget {
  final ValueChanged<UserSession> onAuthenticated;
  final List<AnnouncementItem> announcements;
  final bool initialFacultyMode;

  const AuthScreen({
    super.key,
    required this.onAuthenticated,
    this.announcements = const [],
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
  String _loadingMessage = 'Authenticating...';
  String? _loadingSubtitle;
  String? _message;
  bool _isSuccessMsg = false;

  bool _obscureStudentPass = true;
  bool _obscureRegPass = true;
  bool _obscureForgotPass = true;
  bool _obscureFacPass = true;
  bool _staySignedIn = true;

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
  void initState() {
    super.initState();
    _loadSavedAuthPrefs();
  }

  Future<void> _loadSavedAuthPrefs() async {
    final stay = await SessionService.instance.getStaySignedInPreference();
    final lastId = await SessionService.instance.getLastStudentId();
    if (!mounted) return;
    setState(() {
      _staySignedIn = stay;
      if (_loginIdCtrl.text.isEmpty && lastId != null) {
        _loginIdCtrl.text = lastId;
      }
    });
  }

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
    FocusScope.of(context).unfocus();
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

  void _beginLoading(String title, [String? subtitle]) {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _loadingMessage = title;
      _loadingSubtitle = subtitle;
      _message = null;
    });
  }

  Future<void> _handleStudentLogin() async {
    final id = _loginIdCtrl.text.trim();
    final pass = _loginPassCtrl.text;
    if (id.isEmpty || pass.isEmpty) {
      _setFeedback('Please enter both your Student ID and Password.');
      return;
    }

    _beginLoading(
      'Authenticating Student...',
      'Loading your enrolled subjects & profile',
    );
    try {
      final res =
          await ApiService.instance.loginStudent(id: id, password: pass);
      if (res['success'] != true) {
        _setFeedback(res['message']?.toString() ?? 'Invalid ID or Password.');
        return;
      }
      if (mounted) {
        setState(() {
          _loadingMessage = 'Preparing Student Workspace...';
          _loadingSubtitle = 'Syncing profile photo & class schedule';
        });
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
                (e) =>
                    ClassScheduleItem.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList() ??
          const <ClassScheduleItem>[];
      final profile = StudentProfile.fromJson(
        res['profile'] is Map
            ? Map<String, dynamic>.from(res['profile'] as Map)
            : null,
      );

      final studentSession = UserSession(
        id: id,
        name: res['studentName']?.toString() ?? id,
        isFaculty: false,
        subjects: subjects,
        schedule: schedule,
        profile: profile,
        avatarDataUrl: avatar,
      );

      await SessionService.instance.saveSession(
        studentSession,
        staySignedIn: _staySignedIn,
      );
      widget.onAuthenticated(studentSession);
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
      _setFeedback('Fill out all fields including your Birthdate.');
      return;
    }
    final bdateStr = DateFormat('yyyy-MM-dd').format(_regBirthdate!);

    _beginLoading(
      'Registering Account...',
      'Verifying Student ID & locking credentials',
    );
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
        res['message']?.toString() ?? 'Registration successful! Please log in.',
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
    _beginLoading(
      'Sending Security OTP...',
      'Dispatching 6-digit code to your registered email',
    );
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
    _beginLoading(
      'Updating Password...',
      'Verifying OTP & saving new credentials',
    );
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
      _setFeedback('Please enter both your Faculty ID and Password.');
      return;
    }
    _beginLoading(
      'Authenticating Faculty...',
      'Verifying LMS credentials & scanner access',
    );
    try {
      final res =
          await ApiService.instance.loginFaculty(id: id, password: pass);
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

      await SessionService.instance.saveSession(
        facSession,
        staySignedIn: _staySignedIn,
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
    VoidCallback? onToggleObscure,
    TextInputAction textInputAction = TextInputAction.next,
    VoidCallback? onSubmitted,
    TextInputType? keyboardType,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: PortalColors.activeCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PortalColors.activeRule),
        boxShadow: const [
          BoxShadow(
            color: Color(0x141A3A2A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        autocorrect: false,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted != null ? (_) => onSubmitted() : null,
        enableSuggestions: !obscure && onToggleObscure == null,
        style: PortalTheme.sans(size: 15, weight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: PortalTheme.sans(size: 14.5, color: PortalColors.ink3),
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(emoji, style: const TextStyle(fontSize: 18)),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 48),
          suffixIcon: onToggleObscure != null
              ? IconButton(
                  tooltip: obscure ? 'Show Password' : 'Hide Password',
                  onPressed: onToggleObscure,
                  icon: Icon(
                    obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 19,
                    color: PortalColors.ink3,
                  ),
                )
              : null,
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
    IconData? icon,
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: PortalColors.gold),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                _loading ? 'PLEASE WAIT…' : label.toUpperCase(),
                overflow: TextOverflow.ellipsis,
                style: PortalTheme.sans(
                  size: 14,
                  weight: FontWeight.w700,
                  letterSpacing: 0.7,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showToggle =
        _mode == _AuthMode.studentLogin || _mode == _AuthMode.facultyLogin;

    return ParchmentScaffold(
      isLoading: _loading,
      loadingMessage: _loadingMessage,
      loadingSubtitle: _loadingSubtitle,
      topBanner: widget.announcements.isNotEmpty
          ? AnnouncementMarqueeBanner(announcements: widget.announcements)
          : null,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              children: [
                // Top-right Dark Mode Toggle (Endpoint configuration button intentionally omitted)
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: PortalColors.isDark
                        ? 'Switch to Light Mode'
                        : 'Switch to Dark Mode',
                    onPressed: () async {
                      await ThemeController.instance.toggleDarkMode();
                      if (mounted) setState(() {});
                    },
                    icon: Icon(
                      PortalColors.isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      color: PortalColors.isDark
                          ? PortalColors.gold
                          : PortalColors.forest,
                    ),
                  ),
                ),
                const PortalHeader(),
                Container(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 26),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: PortalColors.isDark
                          ? const [PortalColors.darkSurface, PortalColors.darkCard]
                          : const [Colors.white, PortalColors.parchment],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: PortalColors.isDark
                          ? PortalColors.darkRule
                          : Colors.white,
                      width: 4,
                    ),
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
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: PortalColors.forestFaint,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _toggleTab(
                                  label: '🎓 Student',
                                  active: _mode == _AuthMode.studentLogin,
                                  onTap: () =>
                                      _switchMode(_AuthMode.studentLogin),
                                ),
                              ),
                              Expanded(
                                child: _toggleTab(
                                  label: '🏫 Faculty',
                                  active: _mode == _AuthMode.facultyLogin,
                                  onTap: () =>
                                      _switchMode(_AuthMode.facultyLogin),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                      ],
                      if (_message != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: _isSuccessMsg
                                ? PortalColors.emeraldBg
                                : PortalColors.burgBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _isSuccessMsg
                                  ? PortalColors.emeraldBorder
                                  : PortalColors.burgBorder,
                            ),
                          ),
                          child: Text(
                            '${_isSuccessMsg ? "✅" : "⚠️"} $_message',
                            textAlign: TextAlign.center,
                            style: PortalTheme.sans(
                              size: 12.5,
                              weight: FontWeight.w700,
                              color: _isSuccessMsg
                                  ? PortalColors.emerald
                                  : PortalColors.burg,
                            ),
                          ),
                        ),
                      ],
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: _buildActiveForm(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveForm() {
    switch (_mode) {
      case _AuthMode.studentLogin:
        return KeyedSubtree(
          key: const ValueKey('form_student'),
          child: _buildStudentLogin(),
        );
      case _AuthMode.register:
        return KeyedSubtree(
          key: const ValueKey('form_register'),
          child: _buildRegister(),
        );
      case _AuthMode.forgot:
        return KeyedSubtree(
          key: const ValueKey('form_forgot'),
          child: _buildForgot(),
        );
      case _AuthMode.facultyLogin:
        return KeyedSubtree(
          key: const ValueKey('form_faculty'),
          child: _buildFacultyLogin(),
        );
    }
  }

  Widget _toggleTab({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: active ? PortalColors.forest : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
          boxShadow: active
              ? const [
                  BoxShadow(
                    color: Color(0x221A3A2A),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: PortalTheme.sans(
            size: 14,
            weight: FontWeight.w700,
            color: active ? PortalColors.gold : PortalColors.ink3,
          ),
        ),
      ),
    );
  }

  Widget _buildStaySignedInRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final next = !_staySignedIn;
          setState(() => _staySignedIn = next);
          await SessionService.instance.setStaySignedInPreference(next);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _staySignedIn,
                  activeColor: PortalColors.forest,
                  checkColor: PortalColors.gold,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  onChanged: (val) async {
                    final next = val ?? true;
                    setState(() => _staySignedIn = next);
                    await SessionService.instance
                        .setStaySignedInPreference(next);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Stay signed in on this device',
                  style: PortalTheme.sans(
                    size: 13,
                    weight: FontWeight.w600,
                    color: PortalColors.ink2,
                  ),
                ),
              ),
            ],
          ),
        ),
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
          obscure: _obscureStudentPass,
          onToggleObscure: () =>
              setState(() => _obscureStudentPass = !_obscureStudentPass),
          textInputAction: TextInputAction.done,
          onSubmitted: _handleStudentLogin,
        ),
        _buildStaySignedInRow(),
        const SizedBox(height: 4),
        _primaryButton(
          label: 'Sign In to Portal',
          icon: Icons.login_rounded,
          onPressed: _handleStudentLogin,
        ),
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
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
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
                  weight: FontWeight.w800,
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
        Text('Student Registration', style: PortalTheme.serif(size: 25)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: PortalColors.burgBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: PortalColors.burgBorder),
          ),
          child: Text(
            '⚠️ Your Birthdate and Password will be permanently locked to your ID. Ensure your details are accurate.',
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
              border: Border.all(color: PortalColors.rule),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x141A3A2A),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                const Text('📅', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    bdateText,
                    style: PortalTheme.sans(
                      size: 14.5,
                      color: _regBirthdate == null
                          ? PortalColors.ink3
                          : PortalColors.ink,
                    ),
                  ),
                ),
                const Icon(
                  Icons.calendar_month_rounded,
                  size: 18,
                  color: PortalColors.ink3,
                ),
              ],
            ),
          ),
        ),
        _neumorphicInput(
          controller: _regPassCtrl,
          hint: 'Create Password',
          emoji: '🔒',
          obscure: _obscureRegPass,
          onToggleObscure: () =>
              setState(() => _obscureRegPass = !_obscureRegPass),
          textInputAction: TextInputAction.done,
          onSubmitted: _handleRegister,
        ),
        const SizedBox(height: 8),
        _primaryButton(
          label: 'Register Account',
          icon: Icons.how_to_reg_rounded,
          onPressed: _handleRegister,
        ),
        const SizedBox(height: 14),
        TextButton(
          onPressed: () => _switchMode(_AuthMode.studentLogin),
          child: const Text('← Already registered? Sign in here'),
        ),
      ],
    );
  }

  Widget _buildForgot() {
    return Column(
      children: [
        Text('Reset Password', style: PortalTheme.serif(size: 25)),
        const SizedBox(height: 14),
        if (_forgotStep == 1) ...[
          _neumorphicInput(
            controller: _forgotIdCtrl,
            hint: 'Student ID',
            emoji: '🎓',
            textInputAction: TextInputAction.done,
            onSubmitted: _handleForgotSendOtp,
          ),
          const SizedBox(height: 6),
          _primaryButton(
            label: 'Send 6-Digit OTP',
            icon: Icons.mark_email_read_outlined,
            onPressed: _handleForgotSendOtp,
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: PortalColors.emeraldBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: PortalColors.emeraldBorder),
            ),
            child: Text(
              '✅ OTP sent to your registered email address.',
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
            keyboardType: TextInputType.number,
          ),
          _neumorphicInput(
            controller: _forgotNewPassCtrl,
            hint: 'New Password',
            emoji: '🔒',
            obscure: _obscureForgotPass,
            onToggleObscure: () =>
                setState(() => _obscureForgotPass = !_obscureForgotPass),
            textInputAction: TextInputAction.done,
            onSubmitted: _handleForgotReset,
          ),
          const SizedBox(height: 6),
          _primaryButton(
            label: 'Reset Password',
            icon: Icons.lock_reset_rounded,
            onPressed: _handleForgotReset,
          ),
        ],
        const SizedBox(height: 14),
        TextButton(
          onPressed: () => _switchMode(_AuthMode.studentLogin),
          child: const Text('← Back to Sign In'),
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
          obscure: _obscureFacPass,
          onToggleObscure: () =>
              setState(() => _obscureFacPass = !_obscureFacPass),
          textInputAction: TextInputAction.done,
          onSubmitted: _handleFacultyLogin,
        ),
        _buildStaySignedInRow(),
        const SizedBox(height: 4),
        _primaryButton(
          label: 'Sign In to Faculty LMS',
          background: PortalColors.burg,
          icon: Icons.verified_user_outlined,
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
                Icons.qr_code_scanner_rounded,
                size: 18,
                color: PortalColors.forest,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Attendance & Recitation QR/NFC scanning is exclusive to Faculty accounts and stays unlocked offline while signed in.',
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
