import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../theme/app_design_system.dart';

class MessageBubbleWidget extends StatefulWidget {
  final String message;
  final bool isUser;
  final DateTime timestamp;
  final bool isStreaming;

  const MessageBubbleWidget({
    super.key,
    required this.message,
    required this.isUser,
    required this.timestamp,
    this.isStreaming = false,
  });

  @override
  State<MessageBubbleWidget> createState() => _MessageBubbleWidgetState();
}

class _MessageBubbleWidgetState extends State<MessageBubbleWidget> {
  Widget? _body;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _body = null;
  }

  @override
  void didUpdateWidget(covariant MessageBubbleWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message != widget.message ||
        oldWidget.isUser != widget.isUser ||
        oldWidget.isStreaming != widget.isStreaming) {
      _body = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = FoodInsightTypography.body(size: 15).copyWith(height: 1.5);
    final hasBody = widget.message.trim().isNotEmpty;
    final displayText =
        widget.isStreaming && !widget.isUser ? '${widget.message} ▍' : widget.message;

    // Keep parsed Markdown stable when composer, suggestions or typing state changes.
    _body ??= widget.isUser
        ? Text(widget.message, style: style.copyWith(color: Colors.white))
        : (!hasBody && widget.isStreaming)
            ? Text('Thinking…',
                style: style.copyWith(color: FoodInsightColors.midGray))
            : MarkdownBody(
                data: displayText,
                selectable: false,
                styleSheet:
                    MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                  p: style,
                  strong: style.copyWith(fontWeight: FontWeight.w700),
                  listBullet: style.copyWith(color: FoodInsightColors.primary),
                  listIndent: 22,
                  blockSpacing: 12,
                ),
              );

    return RepaintBoundary(
        child: Padding(
      padding: EdgeInsets.fromLTRB(widget.isUser ? 56 : 16, 6, 16, 10),
      child: Align(
        alignment: widget.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: widget.isUser ? FoodInsightColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: widget.isUser
                ? null
                : Border.all(
                    color: FoodInsightColors.outlineGray.withValues(alpha: .45)),
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!widget.isUser)
                  Row(children: [
                    const Icon(Icons.auto_awesome_rounded,
                        size: 16, color: FoodInsightColors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(
                            widget.isStreaming
                                ? 'Food Insight AI · Streaming…'
                                : 'Food Insight AI',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: FoodInsightColors.primary))),
                    if (!widget.isStreaming)
                      IconButton(
                          tooltip: 'Copy reply',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          onPressed: () async {
                            await Clipboard.setData(
                                ClipboardData(text: widget.message));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Reply copied')));
                            }
                          }),
                  ]),
                _body!,
              ]),
        ),
      ),
    ));
  }
}
