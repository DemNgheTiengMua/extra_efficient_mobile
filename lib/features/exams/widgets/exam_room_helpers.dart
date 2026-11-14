import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../../theme/signage_theme.dart';
import '../../../widgets/signage_primitives.dart';

/// Formats a non-negative second count as `MM:SS` or `HH:MM:SS`.
String formatClock(int totalSeconds) {
  final safeSeconds = totalSeconds < 0 ? 0 : totalSeconds;
  final hours = safeSeconds ~/ 3600;
  final minutes = (safeSeconds % 3600) ~/ 60;
  final seconds = safeSeconds % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  if (hours > 0) {
    return '${two(hours)}:${two(minutes)}:${two(seconds)}';
  }
  return '${two(minutes)}:${two(seconds)}';
}

/// Counts whitespace-delimited words in [text].
int countWords(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return 0;
  return trimmed.split(RegExp(r'\s+')).length;
}

/// A learner-readable explanation of why a clip would not load.
///
/// `just_audio` reports a bare `Source error` with a code that means nothing to
/// a learner, and on Android the common cause is the platform refusing cleartext
/// HTTP for the media URL rather than anything the exam did.
String describeAudioFailure(Object error) {
  final raw = error.toString();
  if (raw.contains('Source error')) {
    return 'This question\'s audio could not be loaded. The question is still '
        'answerable — you can play it again, or continue.';
  }
  return 'Audio unavailable. The question is still answerable.';
}

/// Shows a signage-styled confirmation [FDialog] and returns `true` if the
/// primary action was pressed.
Future<bool> showExamConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  required Key confirmKey,
  PlacardButtonVariant confirmVariant = PlacardButtonVariant.primary,
  String cancelLabel = 'CANCEL',
}) async {
  final result = await showFDialog<bool>(
    context: context,
    builder: (dialogContext, style, animation) => FDialog(
      style: style,
      animation: animation,
      builder: (context, _) => PlacardPanel(
        title: title,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              message,
              style: SignageTypography.body(fontSize: 14),
            ),
            const SizedBox(height: 16),
            PlacardButton(
              key: confirmKey,
              label: confirmLabel,
              variant: confirmVariant,
              onPress: () => Navigator.of(dialogContext).pop(true),
            ),
            const SizedBox(height: 8),
            PlacardButton(
              label: cancelLabel,
              variant: PlacardButtonVariant.secondary,
              onPress: () => Navigator.of(dialogContext).pop(false),
            ),
          ],
        ),
      ),
    ),
  );
  return result == true;
}
