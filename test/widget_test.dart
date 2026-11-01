import 'package:flutter_test/flutter_test.dart';
import 'package:student_portal_app/models/portal_models.dart';

void main() {
  test('ScanLogEntry enforces Points_Awarded = 1 for recitation and null for attendance', () {
    final att = ScanLogEntry.create(
      mode: ScanMode.attendance,
      timestamp: '2026-11-01 08:00:00',
      studentId: '2024-00142',
      subject: 'PHILO',
    );
    expect(att.logId.startsWith('ATT-'), isTrue);
    expect(att.pointsAwarded, isNull);
    expect(att.toSyncJson().containsKey('pointsAwarded'), isFalse);

    final rec = ScanLogEntry.create(
      mode: ScanMode.recitation,
      timestamp: '2026-11-01 08:05:00',
      studentId: '2024-00142',
      subject: 'PHILO',
    );
    expect(rec.logId.startsWith('REC-'), isTrue);
    expect(rec.pointsAwarded, 1);
    expect(rec.toSyncJson()['pointsAwarded'], 1);
  });

  test('UserSession preserves Faculty access and scannerAuthToken across JSON serialization', () {
    const session = UserSession(
      id: 'FAC-001',
      name: 'Prof. Reyes',
      isFaculty: true,
      subjects: [SubjectItem(code: 'PHILO', name: 'Philosophy')],
      scannerAuthToken: 'test-hmac-token',
    );

    final restored = UserSession.fromJson(session.toJson());
    expect(restored.isFaculty, isTrue);
    expect(restored.scannerAuthToken, 'test-hmac-token');
    expect(restored.subjects.first.code, 'PHILO');
  });
}
