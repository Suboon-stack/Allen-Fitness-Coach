import 'package:allen/fitness/models/chat_message.dart';
import 'package:allen/fitness/theme/app_theme.dart';
import 'package:flutter/material.dart';

class AllenSparkle extends StatelessWidget {
  const AllenSparkle({super.key});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
      child: Container(
          width: 40,
          height: 40,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadii.control)),
          child: CustomPaint(
              painter:
                  _SparklePainter(Theme.of(context).colorScheme.secondary))));
}

class _SparklePainter extends CustomPainter {
  const _SparklePainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(w * .5, h * .03)
      ..cubicTo(w * .57, h * .34, w * .66, h * .43, w * .97, h * .5)
      ..cubicTo(w * .66, h * .57, w * .57, h * .66, w * .5, h * .97)
      ..cubicTo(w * .43, h * .66, w * .34, h * .57, w * .03, h * .5)
      ..cubicTo(w * .34, h * .43, w * .43, h * .34, w * .5, h * .03)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparklePainter oldDelegate) => oldDelegate.color != color;
}

/// Text-only formatting: paragraphs, lists, headings, bold and code. No HTML,
/// navigation, image loading, script execution, or provider-defined widgets.
class CoachReply extends StatelessWidget {
  const CoachReply(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context)
        .textTheme
        .bodyLarge!
        .copyWith(color: Theme.of(context).colorScheme.onSurface);
    final spans = <InlineSpan>[];
    var code = false;
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];
      if (line.trimLeft().startsWith('```')) {
        code = !code;
        continue;
      }
      var lineStyle = code ? style.copyWith(fontFamily: 'monospace') : style;
      if (!code) {
        if (RegExp(r'^\s{0,3}#{1,3}\s+').hasMatch(line)) {
          line = line.replaceFirst(RegExp(r'^\s{0,3}#{1,3}\s+'), '');
          lineStyle = style.copyWith(fontWeight: FontWeight.w600);
        }
        line = line.replaceFirst(RegExp(r'^\s*[-*+]\s+'), '• ');
      }
      if (code) {
        spans.add(TextSpan(text: line, style: lineStyle));
      } else {
        var end = 0;
        for (final match
            in RegExp(r'\*\*([^*\n]+)\*\*|`([^`\n]+)`').allMatches(line)) {
          if (match.start > end) {
            spans.add(TextSpan(
                text: line.substring(end, match.start), style: lineStyle));
          }
          spans.add(TextSpan(
              text: match[1] ?? match[2],
              style: match[1] != null
                  ? lineStyle.copyWith(fontWeight: FontWeight.w600)
                  : lineStyle.copyWith(fontFamily: 'monospace')));
          end = match.end;
        }
        spans.add(TextSpan(text: line.substring(end), style: lineStyle));
      }
      if (i < lines.length - 1) spans.add(const TextSpan(text: '\n'));
    }
    return SelectableText.rich(TextSpan(style: style, children: spans));
  }
}

class CoachMessageBubble extends StatelessWidget {
  const CoachMessageBubble({super.key, required this.message, this.onRetry});
  final ChatMessage message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), user = message.role == ChatRole.user;
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: LayoutBuilder(
            builder: (context, constraints) => Align(
                  alignment:
                      user ? Alignment.centerRight : Alignment.centerLeft,
                  child: ConstrainedBox(
                      constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth * (user ? 0.88 : 1)),
                      child: Column(
                          crossAxisAlignment: user
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Semantics(
                                container: true,
                                label: user ? 'You' : 'Allen',
                                child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.md,
                                        vertical: 12),
                                    decoration: BoxDecoration(
                                        color: user
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme.surface,
                                        borderRadius: BorderRadius.circular(
                                            AppRadii.panel)),
                                    child: user
                                        ? SelectableText(message.text,
                                            style: theme.textTheme.bodyLarge
                                                ?.copyWith(
                                                    color: theme
                                                        .colorScheme.onPrimary))
                                        : CoachReply(message.text))),
                            if (message.status == ChatMessageStatus.failed)
                              Padding(
                                  padding:
                                      const EdgeInsets.only(top: AppSpacing.sm),
                                  child: Semantics(
                                      liveRegion: true,
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                ChatException(message.failure ??
                                                        ChatFailure.unavailable)
                                                    .message,
                                                style: theme
                                                    .textTheme.bodyMedium
                                                    ?.copyWith(
                                                        color: theme.colorScheme
                                                            .error)),
                                            if (onRetry != null)
                                              TextButton(
                                                  onPressed: onRetry,
                                                  child: const Text('Retry')),
                                          ]))),
                          ])),
                )));
  }
}
