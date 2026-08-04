import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class SafeDiagnostics {
  const SafeDiagnostics._();

  static String errorCode(Object error) {
    if (error is FirebaseException) return _safeCode(error.code);
    return _safeCode(error.runtimeType.toString());
  }

  static String redactText(String value) {
    var safe = value;
    safe = safe.replaceAll(
      RegExp(r'bearer\s+[a-z0-9._~+/-]+=*', caseSensitive: false),
      'Bearer [REDACTED]',
    );
    safe = safe.replaceAll(
      RegExp(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}'),
      '[REDACTED_EMAIL]',
    );
    safe = safe.replaceAll(
      RegExp(r'(?<!\d)\+?\d[\d ()-]{7,}\d(?!\d)'),
      '[REDACTED_PHONE]',
    );
    safe = safe.replaceAll(
      RegExp(r'(?<!\d)-?\d{1,3}\.\d{4,}\s*[,;]\s*-?\d{1,3}\.\d{4,}(?!\d)'),
      '[REDACTED_COORDINATES]',
    );
    safe = safe.replaceAll(
      RegExp(r'(token|secret|code|uid)=\S+', caseSensitive: false),
      r'$1=[REDACTED]',
    );
    return safe.length <= 240 ? safe : '${safe.substring(0, 240)}…';
  }

  static void log(
    String event, {
    Map<String, Object?> fields = const {},
    StackTrace? stackTrace,
  }) {
    if (!kDebugMode) return;
    final suffix = fields.entries
        .map(
          (entry) => '${_safeCode(entry.key)}=${redactText('${entry.value}')}',
        )
        .join(' ');
    debugPrint('[$event]${suffix.isEmpty ? '' : ' $suffix'}');
    if (stackTrace != null) debugPrintStack(stackTrace: stackTrace);
  }

  static String _safeCode(String value) =>
      value.replaceAll(RegExp(r'[^A-Za-z0-9_.:-]'), '-');
}
