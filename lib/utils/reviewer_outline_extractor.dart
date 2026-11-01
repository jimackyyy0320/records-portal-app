import 'package:intl/intl.dart';

/// Pure-Dart HTML Reviewer to `.txt` Study Outline extractor (App-only).
///
/// Strips all HTML/CSS/JS code, presentation controls, SVG icons, and boilerplate,
/// leaving ONLY the structured academic discussion outline in clean plain text.
class ReviewerOutlineExtractor {
  ReviewerOutlineExtractor._();

  static const String _slideBreakToken = '[[PORTAL_SLIDE_BREAK]]';

  static final Set<String> _uiChromeLabels = {
    'next',
    'prev',
    'previous',
    'next slide',
    'previous slide',
    'fullscreen',
    'exit fullscreen',
    'toggle fullscreen',
    'pin nav',
    'unpin nav',
    'menu',
    'close',
    'table of contents',
    'navigation',
    'press space or arrow keys',
    'use arrow keys to navigate',
    'swipe left or right',
    'click to reveal',
    'tap to flip',
    'loading...',
  };

  /// Produces a clean `.txt` file basename for a given reviewer file name.
  static String buildTxtFileName(String originalName) {
    final withoutExt = originalName.replaceFirst(
      RegExp(r'\.(html?|pdf|docx?)$', caseSensitive: false),
      '',
    );
    final cleaned = withoutExt
        .replaceAll(RegExp(r'[^A-Za-z0-9._ -]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
    final base = cleaned.isEmpty ? 'Reviewer' : cleaned;
    return '${base}_Outline.txt';
  }

  /// Extracts ONLY the structured discussion outline from raw HTML content.
  static String extractOutline({
    required String rawHtml,
    required String reviewerTitle,
    String? subjectName,
    DateTime? generatedAt,
  }) {
    String work = rawHtml;

    // 1. Capture <title> fallback before stripping <head>
    String? htmlTitle;
    final titleMatch = RegExp(
      r'<title\b[^>]*>(.*?)</title>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(work);
    if (titleMatch != null) {
      final candidate = _decodeEntities(
        titleMatch.group(1)!.replaceAll(RegExp(r'<[^>]+>'), ''),
      ).trim();
      if (candidate.isNotEmpty) htmlTitle = candidate;
    }

    // 2. Remove DOCTYPE, XML headers, HTML comments, and all code/script/style/UI blocks
    work = work.replaceAll(
      RegExp(r'<!DOCTYPE[^>]*>', caseSensitive: false, dotAll: true),
      '',
    );
    work = work.replaceAll(
      RegExp(r'<\?xml[^>]*\?>', caseSensitive: false, dotAll: true),
      '',
    );
    work = work.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

    const strippedBlockTags = <String>[
      'head',
      'script',
      'style',
      'noscript',
      'svg',
      'canvas',
      'template',
      'iframe',
      'audio',
      'video',
      'nav',
      'button',
      'select',
      'footer',
    ];
    for (final tag in strippedBlockTags) {
      work = work.replaceAll(
        RegExp('<$tag\\b[^>]*>.*?</$tag>', caseSensitive: false, dotAll: true),
        '',
      );
    }

    // Remove self-closing inputs / meta / link tags
    work = work.replaceAll(
      RegExp(r'<(?:meta|link|input|img|source|track)\b[^>]*/?>',
          caseSensitive: false),
      '',
    );

    // Remove known presentation navigation bars (#nav-panel, .nav-btn, etc.) when single-level
    work = work.replaceAll(
      RegExp(
        r'<(?:div|aside|span)\b[^>]*(?:id|class)\s*=\s*["\x27][^"\x27]*(?:nav-panel|nav-btn|btnNext|btnPrev|btnFullscreen|btnPinNav|slide-counter|deck-nav|progress-bar)[^"\x27]*["\x27][^>]*>[^<]*</(?:div|aside|span)>',
        caseSensitive: false,
        dotAll: true,
      ),
      '',
    );

    // 3. Mark slide boundaries without consuming nested content inside slides
    work = work.replaceAll(
      RegExp(
        r'<(?:div|section|article)\b[^>]*\bclass\s*=\s*["\x27][^"\x27]*\bslide\b[^"\x27]*["\x27][^>]*>',
        caseSensitive: false,
      ),
      '\n$_slideBreakToken\n',
    );

    // 4. Convert headings into clear academic outline hierarchy
    work = work.replaceAllMapped(
      RegExp(r'<h1\b[^>]*>(.*?)</h1>', caseSensitive: false, dotAll: true),
      (m) {
        final t = _cleanInlineText(m.group(1) ?? '');
        if (t.isEmpty) return '\n';
        return '\n\n■ ${t.toUpperCase()}\n────────────────────────────────────────────────────\n';
      },
    );
    work = work.replaceAllMapped(
      RegExp(r'<h2\b[^>]*>(.*?)</h2>', caseSensitive: false, dotAll: true),
      (m) {
        final t = _cleanInlineText(m.group(1) ?? '');
        return t.isEmpty ? '\n' : '\n\n▸ $t\n';
      },
    );
    work = work.replaceAllMapped(
      RegExp(r'<h3\b[^>]*>(.*?)</h3>', caseSensitive: false, dotAll: true),
      (m) {
        final t = _cleanInlineText(m.group(1) ?? '');
        return t.isEmpty ? '\n' : '\n  ▸ $t\n';
      },
    );
    work = work.replaceAllMapped(
      RegExp(r'<h[4-6]\b[^>]*>(.*?)</h[4-6]>',
          caseSensitive: false, dotAll: true),
      (m) {
        final t = _cleanInlineText(m.group(1) ?? '');
        return t.isEmpty ? '\n' : '\n  • $t\n';
      },
    );

    // 5. Convert lists, blockquotes, definition lists, tables, and line breaks
    work = work.replaceAll(
      RegExp(r'<li\b[^>]*>', caseSensitive: false),
      '\n  • ',
    );
    work = work.replaceAll(
      RegExp(r'</li>', caseSensitive: false),
      '\n',
    );
    work = work.replaceAll(
      RegExp(r'<dt\b[^>]*>', caseSensitive: false),
      '\n  • ',
    );
    work = work.replaceAll(
      RegExp(r'</dt>', caseSensitive: false),
      ': ',
    );
    work = work.replaceAll(
      RegExp(r'<dd\b[^>]*>', caseSensitive: false),
      '',
    );
    work = work.replaceAll(
      RegExp(r'</dd>', caseSensitive: false),
      '\n',
    );
    work = work.replaceAll(
      RegExp(r'<blockquote\b[^>]*>', caseSensitive: false),
      '\n  "',
    );
    work = work.replaceAll(
      RegExp(r'</blockquote>', caseSensitive: false),
      '"\n',
    );
    work = work.replaceAll(
      RegExp(r'<tr\b[^>]*>', caseSensitive: false),
      '\n  ',
    );
    work = work.replaceAll(
      RegExp(r'</tr>', caseSensitive: false),
      '\n',
    );
    work = work.replaceAll(
      RegExp(r'</t[hd]>', caseSensitive: false),
      ' | ',
    );
    work = work.replaceAll(
      RegExp(r'<br\s*/?>', caseSensitive: false),
      '\n',
    );
    work = work.replaceAll(
      RegExp(r'<hr\s*/?>', caseSensitive: false),
      '\n────────────────────────────────────────────────────\n',
    );
    work = work.replaceAll(
      RegExp(
        r'</(?:p|div|section|article|header|main|aside|ul|ol|dl|table|thead|tbody|figure|figcaption)>',
        caseSensitive: false,
      ),
      '\n',
    );

    // 6. Strip all remaining HTML tags completely
    work = work.replaceAll(RegExp(r'<[^>]+>', dotAll: true), '');

    // 7. Decode HTML entities
    work = _decodeEntities(work);

    // 8. Split into sections (if slide breaks exist) and clean discussion lines
    final rawSections = work.contains(_slideBreakToken)
        ? work.split(_slideBreakToken)
        : <String>[work];

    final cleanedSections = <String>[];
    for (final rawSec in rawSections) {
      final lines = _cleanSectionLines(rawSec);
      if (lines.isNotEmpty) {
        cleanedSections.add(lines.join('\n'));
      }
    }

    final cleanDisplayTitle = reviewerTitle
        .replaceFirst(RegExp(r'\.html?$', caseSensitive: false), '')
        .trim();
    final effectiveTitle =
        cleanDisplayTitle.isNotEmpty ? cleanDisplayTitle : (htmlTitle ?? 'Reviewer');
    final stamp = DateFormat('MMMM d, yyyy • h:mm a')
        .format(generatedAt ?? DateTime.now());

    final out = StringBuffer();
    out.writeln('============================================================');
    out.writeln('MIS-SHS LEARNER APP — STUDY REVIEWER OUTLINE');
    if (subjectName != null && subjectName.trim().isNotEmpty) {
      out.writeln('Subject  : ${subjectName.trim()}');
    }
    out.writeln('Reviewer : $effectiveTitle');
    out.writeln('Extracted: $stamp');
    out.writeln('============================================================');
    out.writeln();

    if (cleanedSections.isEmpty) {
      out.writeln('No extractable text discussion was found in this reviewer.');
      return out.toString().trimRight();
    }

    if (cleanedSections.length == 1) {
      out.writeln(cleanedSections.first);
    } else {
      for (int i = 0; i < cleanedSections.length; i++) {
        out.writeln('[PART ${i + 1} OF ${cleanedSections.length}]');
        out.writeln(cleanedSections[i]);
        if (i < cleanedSections.length - 1) {
          out.writeln();
          out.writeln('------------------------------------------------------------');
          out.writeln();
        }
      }
    }

    return out.toString().trimRight();
  }

  static String _cleanInlineText(String fragment) {
    final stripped = fragment
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<[^>]+>', dotAll: true), ' ');
    return _decodeEntities(stripped).replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static List<String> _cleanSectionLines(String rawSection) {
    final rawLines = rawSection.replaceAll('\r\n', '\n').split('\n');
    final result = <String>[];
    String? prevNormalized;

    for (final rawLine in rawLines) {
      // Preserve intentional list/heading indent while collapsing inner spaces
      final leadingIndent = rawLine.startsWith('  • ')
          ? '  • '
          : (rawLine.startsWith('  ▸ ')
              ? '  ▸ '
              : (rawLine.startsWith('  "') ? '  "' : ''));

      String body = leadingIndent.isNotEmpty
          ? rawLine.substring(leadingIndent.length)
          : rawLine;
      body = body.replaceAll(RegExp(r'[ \t]+'), ' ').trim();

      // Trim trailing table pipe separator
      if (body.endsWith('|')) {
        body = body.substring(0, body.length - 1).trim();
      }

      if (body.isEmpty) {
        if (result.isNotEmpty && result.last.isNotEmpty) {
          result.add('');
        }
        continue;
      }

      // Filter out leftover UI button text, slide numbers, or stray code artifacts
      if (_isCodeOrUiNoise(body)) {
        continue;
      }

      final fullLine = '$leadingIndent$body';
      final normalizedKey = body.toLowerCase();

      // Avoid repeating identical consecutive lines (common in responsive dual-DOM headers)
      if (prevNormalized != null &&
          prevNormalized == normalizedKey &&
          !body.startsWith('────')) {
        continue;
      }

      result.add(fullLine);
      prevNormalized = normalizedKey;
    }

    while (result.isNotEmpty && result.first.isEmpty) {
      result.removeAt(0);
    }
    while (result.isNotEmpty && result.last.isEmpty) {
      result.removeLast();
    }
    return result;
  }

  static bool _isCodeOrUiNoise(String text) {
    final lower = text.toLowerCase().trim();
    if (_uiChromeLabels.contains(lower)) return true;

    // Standalone slide counter e.g. "1 / 18" or "Slide 3 of 20"
    if (RegExp(r'^(?:slide\s*)?\d{1,3}\s*(?:/|of)\s*\d{1,3}$',
            caseSensitive: false)
        .hasMatch(lower)) {
      return true;
    }

    // Stray CSS / JS code lines if an HTML deck had unclosed tags
    if (RegExp(
      r'^(?:@media|@keyframes|:root\b|const\s+\w+\s*=|let\s+\w+\s*=|var\s+\w+\s*=|function\s+\w+\s*\(|document\.(?:getElementById|querySelector)|window\.addEventListener)',
    ).hasMatch(text)) {
      return true;
    }
    if (text.contains('{') &&
        text.contains('}') &&
        RegExp(r'[a-z-]+\s*:\s*[^;]+;').hasMatch(text)) {
      return true;
    }

    // Pure arrow/icon glyphs used as prev/next buttons
    if (RegExp(r'^[←→↑↓❮❯‹›«»▶◀▲▼✕✖☰⚙️🔍]+$').hasMatch(text)) {
      return true;
    }

    return false;
  }

  static String _decodeEntities(String input) {
    if (!input.contains('&')) return input;

    const named = <String, String>{
      '&nbsp;': ' ',
      '&amp;': '&',
      '&lt;': '<',
      '&gt;': '>',
      '&quot;': '"',
      '&#39;': "'",
      '&apos;': "'",
      '&mdash;': '—',
      '&ndash;': '–',
      '&minus;': '-',
      '&bull;': '•',
      '&middot;': '·',
      '&hellip;': '...',
      '&ldquo;': '"',
      '&rdquo;': '"',
      '&lsquo;': "'",
      '&rsquo;': "'",
      '&rarr;': '→',
      '&larr;': '←',
      '&uarr;': '↑',
      '&darr;': '↓',
      '&harr;': '↔',
      '&rArr;': '⇒',
      '&times;': '×',
      '&divide;': '÷',
      '&plusmn;': '±',
      '&ne;': '≠',
      '&le;': '≤',
      '&ge;': '≥',
      '&approx;': '≈',
      '&deg;': '°',
      '&copy;': '©',
      '&reg;': '®',
      '&trade;': '™',
    };

    String out = input;
    named.forEach((entity, char) {
      out = out.replaceAll(RegExp(entity, caseSensitive: false), char);
    });

    out = out.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
      final code = int.tryParse(m.group(1) ?? '');
      if (code == null || code <= 0) return '';
      return String.fromCharCode(code);
    });

    out = out.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
      final code = int.tryParse(m.group(1) ?? '', radix: 16);
      if (code == null || code <= 0) return '';
      return String.fromCharCode(code);
    });

    return out;
  }
}
