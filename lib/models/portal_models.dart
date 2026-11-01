import 'dart:math';

enum ScanMode {
  attendance,
  recitation;

  String get wireValue => name; // 'attendance' | 'recitation'

  String get displayLabel =>
      this == ScanMode.attendance ? 'Attendance' : 'Recitation';

  String get targetSheetTab =>
      this == ScanMode.attendance ? 'Attendance Log' : 'Recitation_Log';

  static ScanMode fromString(String raw) {
    return raw.trim().toLowerCase() == 'recitation'
        ? ScanMode.recitation
        : ScanMode.attendance;
  }
}

class LogIdGenerator {
  LogIdGenerator._();

  static const String _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static final Random _rng = Random.secure();

  /// Generates a randomized, collision-resistant Log_ID for Column A.
  static String generate(ScanMode mode) {
    final prefix = mode == ScanMode.attendance ? 'ATT' : 'REC';
    final buf = StringBuffer(prefix)..write('-');
    for (int i = 0; i < 10; i++) {
      buf.write(_alphabet[_rng.nextInt(_alphabet.length)]);
    }
    return buf.toString();
  }
}

class ScanLogEntry {
  final String logId;
  final ScanMode scanType;
  final String timestamp;
  final String studentId;
  final String? studentName;
  final String subject;
  final int? pointsAwarded;
  final String syncStatus; // 'pending' | 'syncing' | 'synced' | 'failed'
  final int retryCount;
  final String? errorMessage;
  final int createdAt;

  const ScanLogEntry({
    required this.logId,
    required this.scanType,
    required this.timestamp,
    required this.studentId,
    this.studentName,
    required this.subject,
    required this.pointsAwarded,
    this.syncStatus = 'pending',
    this.retryCount = 0,
    this.errorMessage,
    required this.createdAt,
  });

  factory ScanLogEntry.create({
    required ScanMode mode,
    required String timestamp,
    required String studentId,
    String? studentName,
    required String subject,
  }) {
    return ScanLogEntry(
      logId: LogIdGenerator.generate(mode),
      scanType: mode,
      timestamp: timestamp,
      studentId: studentId.trim(),
      studentName: studentName,
      subject: subject.trim(),
      // Recitation Column E (Points_Awarded) is ALWAYS 1; null for Attendance
      pointsAwarded: mode == ScanMode.recitation ? 1 : null,
      syncStatus: 'pending',
      retryCount: 0,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'log_id': logId,
      'scan_type': scanType.wireValue,
      'timestamp': timestamp,
      'student_id': studentId,
      'student_name': studentName,
      'subject': subject,
      'points_awarded': scanType == ScanMode.recitation ? 1 : null,
      'sync_status': syncStatus,
      'retry_count': retryCount,
      'error_message': errorMessage,
      'created_at': createdAt,
    };
  }

  factory ScanLogEntry.fromDbMap(Map<String, dynamic> map) {
    final mode = ScanMode.fromString(map['scan_type']?.toString() ?? '');
    return ScanLogEntry(
      logId: map['log_id']?.toString() ?? '',
      scanType: mode,
      timestamp: map['timestamp']?.toString() ?? '',
      studentId: map['student_id']?.toString() ?? '',
      studentName: map['student_name']?.toString(),
      subject: map['subject']?.toString() ?? '',
      pointsAwarded: mode == ScanMode.recitation ? 1 : null,
      syncStatus: map['sync_status']?.toString() ?? 'pending',
      retryCount: (map['retry_count'] as num?)?.toInt() ?? 0,
      errorMessage: map['error_message']?.toString(),
      createdAt: (map['created_at'] as num?)?.toInt() ?? 0,
    );
  }

  /// Payload format sent in batched JSON sync to code.gs `syncScanBatch`.
  Map<String, dynamic> toSyncJson() {
    return {
      'logId': logId,
      'scanType': scanType.wireValue,
      'timestamp': timestamp,
      'studentId': studentId,
      'subject': subject,
      if (scanType == ScanMode.recitation) 'pointsAwarded': 1,
    };
  }
}

class AnnouncementItem {
  final String date;
  final String message;
  final String degree;

  const AnnouncementItem({
    required this.date,
    required this.message,
    required this.degree,
  });

  factory AnnouncementItem.fromJson(Map<String, dynamic> json) {
    return AnnouncementItem(
      date: json['date']?.toString() ?? 'Notice',
      message: json['message']?.toString() ?? '',
      degree: (json['degree']?.toString() ?? 'CASUAL').toUpperCase(),
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'message': message,
        'degree': degree,
      };
}

class SystemStatus {
  final String status;
  final List<String> releasedSubjects;
  final List<AnnouncementItem> announcements;

  const SystemStatus({
    required this.status,
    required this.releasedSubjects,
    required this.announcements,
  });

  bool get isOfflineOrMaintenance =>
      status.toUpperCase() == 'MAINTENANCE' || status.toUpperCase() == 'CLOSED';

  factory SystemStatus.fromJson(Map<String, dynamic> json) {
    final rel = (json['releasedSubjects'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];
    final ann = (json['announcements'] as List?)
            ?.whereType<Map>()
            .map((e) => AnnouncementItem.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        const <AnnouncementItem>[];
    return SystemStatus(
      status: json['status']?.toString() ?? 'OPEN',
      releasedSubjects: rel,
      announcements: ann,
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status,
        'releasedSubjects': releasedSubjects,
        'announcements': announcements.map((a) => a.toJson()).toList(),
      };
}

class SubjectItem {
  final String code;
  final String name;

  const SubjectItem({required this.code, required this.name});

  factory SubjectItem.fromJson(Map<String, dynamic> json) {
    return SubjectItem(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'code': code, 'name': name};
}

class ClassScheduleItem {
  final String subjectCode;
  final String day;
  final String timeIn;
  final String timeOut;

  const ClassScheduleItem({
    required this.subjectCode,
    required this.day,
    required this.timeIn,
    required this.timeOut,
  });

  factory ClassScheduleItem.fromJson(Map<String, dynamic> json) {
    return ClassScheduleItem(
      subjectCode: json['subjectCode']?.toString() ?? '',
      day: json['day']?.toString() ?? '',
      timeIn: json['timeIn']?.toString() ?? '',
      timeOut: json['timeOut']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'subjectCode': subjectCode,
        'day': day,
        'timeIn': timeIn,
        'timeOut': timeOut,
      };
}

class StudentProfile {
  final String fatherName;
  final String fatherContact;
  final String motherName;
  final String motherContact;
  final String address;
  final String email;

  const StudentProfile({
    this.fatherName = '',
    this.fatherContact = '',
    this.motherName = '',
    this.motherContact = '',
    this.address = '',
    this.email = '',
  });

  bool get isComplete =>
      fatherName.trim().isNotEmpty &&
      fatherContact.trim().isNotEmpty &&
      motherName.trim().isNotEmpty &&
      motherContact.trim().isNotEmpty &&
      address.trim().isNotEmpty &&
      email.trim().isNotEmpty;

  factory StudentProfile.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const StudentProfile();
    return StudentProfile(
      fatherName: json['fatherName']?.toString() ?? '',
      fatherContact: json['fatherContact']?.toString() ?? '',
      motherName: json['motherName']?.toString() ?? '',
      motherContact: json['motherContact']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'fatherName': fatherName,
        'fatherContact': fatherContact,
        'motherName': motherName,
        'motherContact': motherContact,
        'address': address,
        'email': email,
      };
}

class UserSession {
  final String id;
  final String name;
  final bool isFaculty;
  final List<SubjectItem> subjects;
  final List<ClassScheduleItem> schedule;
  final StudentProfile profile;
  final String? avatarDataUrl;
  final String? scannerAuthToken;

  const UserSession({
    required this.id,
    required this.name,
    required this.isFaculty,
    required this.subjects,
    this.schedule = const [],
    this.profile = const StudentProfile(),
    this.avatarDataUrl,
    this.scannerAuthToken,
  });

  String get firstNameGreeting {
    if (name.contains(',')) {
      final parts = name.split(',');
      if (parts.length > 1 && parts[1].trim().isNotEmpty) {
        return parts[1].trim();
      }
    }
    return name.split(' ').first;
  }

  UserSession copyWith({
    StudentProfile? profile,
    String? avatarDataUrl,
    bool clearAvatar = false,
    String? scannerAuthToken,
  }) {
    return UserSession(
      id: id,
      name: name,
      isFaculty: isFaculty,
      subjects: subjects,
      schedule: schedule,
      profile: profile ?? this.profile,
      avatarDataUrl: clearAvatar ? null : (avatarDataUrl ?? this.avatarDataUrl),
      scannerAuthToken: scannerAuthToken ?? this.scannerAuthToken,
    );
  }

  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      isFaculty: json['isFaculty'] == true,
      subjects: (json['subjects'] as List?)
              ?.whereType<Map>()
              .map((e) => SubjectItem.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          const [],
      schedule: (json['schedule'] as List?)
              ?.whereType<Map>()
              .map(
                (e) => ClassScheduleItem.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList() ??
          const [],
      profile: StudentProfile.fromJson(
        json['profile'] is Map
            ? Map<String, dynamic>.from(json['profile'] as Map)
            : null,
      ),
      avatarDataUrl: json['avatarDataUrl']?.toString(),
      scannerAuthToken: json['scannerAuthToken']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isFaculty': isFaculty,
        'subjects': subjects.map((s) => s.toJson()).toList(),
        'schedule': schedule.map((s) => s.toJson()).toList(),
        'profile': profile.toJson(),
        'avatarDataUrl': avatarDataUrl,
        'scannerAuthToken': scannerAuthToken,
      };
}

class DailyProgressItem {
  final String name;
  final String? score;
  final String week;
  final String? maxScore;

  const DailyProgressItem({
    required this.name,
    required this.score,
    required this.week,
    this.maxScore,
  });

  bool get isMissing {
    if (score == null) return true;
    final s = score!.trim();
    return s.isEmpty || s.toLowerCase() == 'undefined' || s.toLowerCase() == 'null';
  }

  double get numericScore => double.tryParse(score ?? '') ?? 0;

  factory DailyProgressItem.fromJson(Map<String, dynamic> json) {
    return DailyProgressItem(
      name: json['name']?.toString() ?? '',
      score: json['score']?.toString(),
      week: json['week']?.toString() ?? 'Other',
      maxScore: json['maxScore']?.toString(),
    );
  }
}

class MajorScore {
  final String label;
  final String? score;
  final String? maxScore;

  const MajorScore({
    required this.label,
    this.score,
    this.maxScore,
  });

  bool get isMissing {
    if (score == null) return true;
    final s = score!.trim();
    return s.isEmpty || s.toLowerCase() == 'undefined' || s.toLowerCase() == 'null';
  }

  factory MajorScore.fromDynamic(String label, dynamic raw) {
    if (raw is Map) {
      return MajorScore(
        label: label,
        score: raw['score']?.toString(),
        maxScore: raw['maxScore']?.toString(),
      );
    }
    return MajorScore(label: label, score: raw?.toString());
  }
}

class AttendanceRecordItem {
  final String date;
  final String status; // 'present' | 'absent'

  const AttendanceRecordItem({required this.date, required this.status});

  bool get isPresent => status.toLowerCase() == 'present';

  String get monthPrefix => date.split(' ').first;

  factory AttendanceRecordItem.fromJson(Map<String, dynamic> json) {
    return AttendanceRecordItem(
      date: json['date']?.toString() ?? '',
      status: json['status']?.toString() ?? 'absent',
    );
  }
}

class ComparativeEvaluation {
  final String status;
  final String details;

  const ComparativeEvaluation({required this.status, required this.details});

  factory ComparativeEvaluation.fromJson(Map<String, dynamic> json) {
    return ComparativeEvaluation(
      status: json['status']?.toString() ?? 'Not Evaluated',
      details: json['details']?.toString() ?? '',
    );
  }
}

class SubjectDashboardData {
  final String studentName;
  final String subjectName;
  final String subjectCode;
  final String recitations;
  final List<DailyProgressItem> dailyProgress;
  final bool hasMajors;
  final List<MajorScore> majors;
  final int totalPresent;
  final int totalAbsent;
  final List<AttendanceRecordItem> attendanceRecords;
  final ComparativeEvaluation? evaluation;
  final Map<String, String> alternatives;

  const SubjectDashboardData({
    required this.studentName,
    required this.subjectName,
    required this.subjectCode,
    required this.recitations,
    required this.dailyProgress,
    required this.hasMajors,
    required this.majors,
    required this.totalPresent,
    required this.totalAbsent,
    required this.attendanceRecords,
    this.evaluation,
    required this.alternatives,
  });

  factory SubjectDashboardData.fromJson(Map<String, dynamic> json) {
    final majorsMap = json['majors'] is Map
        ? Map<String, dynamic>.from(json['majors'] as Map)
        : <String, dynamic>{};
    final majorsList = <MajorScore>[];
    for (final key in ['SA1', 'SA2', 'PE']) {
      if (majorsMap.containsKey(key) && majorsMap[key] != null) {
        majorsList.add(MajorScore.fromDynamic(key, majorsMap[key]));
      }
    }

    final attMap = json['attendance'] is Map
        ? Map<String, dynamic>.from(json['attendance'] as Map)
        : <String, dynamic>{};
    final attRecords = (attMap['records'] as List?)
            ?.whereType<Map>()
            .map((e) =>
                AttendanceRecordItem.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        const <AttendanceRecordItem>[];

    final altRaw = json['alternatives'] is Map
        ? Map<String, dynamic>.from(json['alternatives'] as Map)
        : <String, dynamic>{};
    final altMap = <String, String>{};
    altRaw.forEach((k, v) {
      if (v != null && v.toString().trim().isNotEmpty) {
        altMap[k.toUpperCase()] = v.toString().trim();
      }
    });

    return SubjectDashboardData(
      studentName: json['studentName']?.toString() ?? '',
      subjectName: json['subjectName']?.toString() ?? '',
      subjectCode: json['subjectCode']?.toString() ?? '',
      recitations: (json['recitations'] ?? '0').toString(),
      dailyProgress: (json['dailyProgress'] as List?)
              ?.whereType<Map>()
              .map(
                (e) => DailyProgressItem.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList() ??
          const [],
      hasMajors: json['hasMajors'] == true && majorsList.isNotEmpty,
      majors: majorsList,
      totalPresent: (attMap['totalPresent'] as num?)?.toInt() ?? 0,
      totalAbsent: (attMap['totalAbsent'] as num?)?.toInt() ?? 0,
      attendanceRecords: attRecords,
      evaluation: json['evaluation'] is Map
          ? ComparativeEvaluation.fromJson(
              Map<String, dynamic>.from(json['evaluation'] as Map),
            )
          : null,
      alternatives: altMap,
    );
  }
}

class ReviewerFile {
  final String id;
  final String name;
  final String mimeType;
  final String url;

  const ReviewerFile({
    required this.id,
    required this.name,
    required this.mimeType,
    required this.url,
  });

  String get weekGroup {
    final match = RegExp(r'W(\d+)', caseSensitive: false).firstMatch(name);
    return match != null ? 'Week ${match.group(1)}' : 'Other';
  }

  String get shortTypeLabel {
    if (mimeType.isEmpty) return 'UNK';
    final sub = mimeType.split('/').last.toUpperCase();
    final short = sub.length > 3 ? sub.substring(0, 3) : sub;
    return short == 'VND' ? 'DOC' : short;
  }

  bool get isHtml {
    final lowerName = name.toLowerCase();
    final lowerMime = mimeType.toLowerCase();
    return shortTypeLabel == 'HTM' ||
        lowerName.endsWith('.html') ||
        lowerName.endsWith('.htm') ||
        lowerMime.contains('html');
  }

  factory ReviewerFile.fromJson(Map<String, dynamic> json) {
    return ReviewerFile(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      mimeType: json['mimeType']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
    );
  }
}
