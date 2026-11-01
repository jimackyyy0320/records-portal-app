import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:student_portal_app/models/portal_models.dart';
import 'package:student_portal_app/screens/auth_screen.dart';
import 'package:student_portal_app/utils/reviewer_outline_extractor.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  test(
    'ScanLogEntry enforces Points_Awarded = 1 for recitation and null for attendance',
    () {
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
    },
  );

  test(
    'UserSession preserves Faculty access and scannerAuthToken across JSON serialization',
    () {
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
    },
  );

  test(
    'ReviewerOutlineExtractor strips HTML/CSS/JS/nav chrome and preserves clean discussion outline',
    () {
      const sampleDeckHtml = '''
<!DOCTYPE html>
<html>
<head>
  <title>W1 - Introduction to Philosophy</title>
  <style>
    body { background: #111; color: #fff; }
    .slide { display: flex; }
  </style>
  <script>
    const totalSlides = 2;
    function nextSlide() { document.getElementById('s2').classList.add('active'); }
  </script>
</head>
<body>
  <div id="nav-panel"><button id="btnPrev">Previous</button><button id="btnNext">Next</button></div>
  <div class="slide active">
    <h1>Branches of Philosophy</h1>
    <p>Philosophy examines existence, knowledge &amp; ethics.</p>
    <ul>
      <li><strong>Metaphysics</strong> &mdash; study of ultimate reality</li>
      <li><strong>Epistemology</strong> &mdash; theory of knowledge</li>
    </ul>
    <div>1 / 2</div>
  </div>
  <div class="slide">
    <h2>Socratic Method</h2>
    <p>Disciplined questioning used to examine foundational beliefs.</p>
  </div>
</body>
</html>
''';

      final txt = ReviewerOutlineExtractor.extractOutline(
        rawHtml: sampleDeckHtml,
        reviewerTitle: 'W1_Philosophy_Deck.html',
        subjectName: 'Introduction to the Philosophy of the Human Person',
        generatedAt: DateTime(2026, 11, 1, 9, 30),
      );

      expect(txt.contains('BRANCHES OF PHILOSOPHY'), isTrue);
      expect(txt.contains('Philosophy examines existence, knowledge & ethics.'), isTrue);
      expect(txt.contains('• Metaphysics — study of ultimate reality'), isTrue);
      expect(txt.contains('▸ Socratic Method'), isTrue);
      expect(txt.contains('[PART 1 OF 2]'), isTrue);
      expect(txt.contains('[PART 2 OF 2]'), isTrue);

      // Ensure zero HTML/CSS/JS/UI chrome leaked into the .txt outline
      expect(txt.contains('<div'), isFalse);
      expect(txt.contains('background: #111'), isFalse);
      expect(txt.contains('nextSlide'), isFalse);
      expect(txt.contains('1 / 2'), isFalse);
      expect(
        ReviewerOutlineExtractor.buildTxtFileName('W1 Philosophy.html'),
        'W1_Philosophy_Outline.txt',
      );
    },
  );

  testWidgets(
    'AuthScreen hides Apps Script endpoint settings button from students',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AuthScreen(
            onAuthenticated: (_) {},
          ),
        ),
      );

      expect(find.byIcon(Icons.settings_ethernet_rounded), findsNothing);
      expect(find.text('SIGN IN TO PORTAL'), findsOneWidget);
    },
  );
}
