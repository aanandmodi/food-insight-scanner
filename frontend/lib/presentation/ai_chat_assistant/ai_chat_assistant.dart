// lib/presentation/ai_chat_assistant/ai_chat_assistant.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';

import '../../data/providers/user_profile_provider.dart';
import '../../models/user_profile.dart';
import '../../services/cloud_function_service.dart';
import '../../services/crash_reporting_service.dart';
import '../../services/feature_flag_service.dart';
import '../../services/user_data_service.dart';
import '../../services/user_session.dart';
import '../../theme/app_design_system.dart';
import './widgets/chat_header_widget.dart';
import './widgets/chat_input_widget.dart';
import './widgets/message_bubble_widget.dart';
import './widgets/quick_reply_widget.dart';
import './widgets/typing_indicator_widget.dart';

class AiChatAssistant extends StatefulWidget {
  final VoidCallback? onExitRequested;
  const AiChatAssistant({super.key, this.onExitRequested});
  @override
  State<AiChatAssistant> createState() => _AiChatAssistantState();
}

class _AiChatAssistantState extends State<AiChatAssistant> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _latestReplyKey = GlobalKey();
  final CloudFunctionService _cloudFunctionService = CloudFunctionService();

  bool _isLoading = false;
  bool _showTypingIndicator = false;
  bool _routeInitialized = false;
  String? _errorMessage;

  String _sessionId = 'default';
  List<Map<String, dynamic>> _sessions = [];
  Map<String, dynamic>? _activeProduct;
  Map<String, dynamic>? _activeFoodFit;

  final List<Map<String, dynamic>> _messages = [];
  bool _initializedGreeting = false;
  bool _historyLoaded = false;

  List<String> _quickReplies = [];
  String? _lastFailedMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeInitialized) return;
    _routeInitialized = true;
    final rawArgs = ModalRoute.of(context)?.settings.arguments;
    final args = rawArgs is Map ? Map<String, dynamic>.from(rawArgs) : null;
    _initSessionFromRoute(args);
  }

  Future<void> _initSessionFromRoute(Map<String, dynamic>? args) async {
    final productArg =
        args?['product'] is Map ? Map<String, dynamic>.from(args!['product'] as Map) : null;
    final fitArg =
        args?['foodFit'] is Map ? Map<String, dynamic>.from(args!['foodFit'] as Map) : null;
    final requestedSession = args?['sessionId']?.toString().trim();

    if (productArg != null) {
      _activeProduct = productArg;
      _activeFoodFit = fitArg;
      final barcode = productArg['barcode']?.toString().trim() ?? '';
      _sessionId = barcode.isNotEmpty
          ? 'product_$barcode'
          : 'product_${UserDataService.newId()}';
      await _loadSessionMessages();
      return;
    }

    if (requestedSession != null && requestedSession.isNotEmpty) {
      _sessionId = requestedSession;
      await _loadSessionMessages();
      return;
    }

    try {
      final session = UserSession.instance.capture();
      final existingSessions = await UserDataService().getChatSessions();
      if (!mounted || !session.isActive) return;
      _sessions = existingSessions;
      if (existingSessions.isNotEmpty) {
        final latest = existingSessions.first;
        _sessionId = latest['id']?.toString() ?? 'default';
        _restoreProductFromSession(latest);
      } else {
        _sessionId = 'default';
      }
    } catch (_) {
      _sessionId = 'default';
    }
    await _loadSessionMessages();
  }

  void _restoreProductFromSession(Map<String, dynamic> sessionMeta) {
    if (sessionMeta['product'] is Map) {
      _activeProduct = Map<String, dynamic>.from(sessionMeta['product'] as Map);
      _activeFoodFit = sessionMeta['foodFit'] is Map
          ? Map<String, dynamic>.from(sessionMeta['foodFit'] as Map)
          : null;
    } else {
      _activeProduct = null;
      _activeFoodFit = null;
    }
  }

  Future<void> _loadSessionMessages() async {
    setState(() {
      _historyLoaded = false;
      _initializedGreeting = false;
      _messages.clear();
      _errorMessage = null;
      _quickReplies = [];
    });

    try {
      final session = UserSession.instance.capture();
      final results = await Future.wait([
        UserDataService().getChatMessages(sessionId: _sessionId),
        UserDataService().getChatSessions(),
      ]);
      if (!mounted || !session.isActive) return;
      final messages = results[0];
      final sessions = results[1];
      setState(() {
        _sessions = sessions;
        _messages.addAll(messages.map((m) => {
              ...m,
              'timestamp':
                  DateTime.tryParse('${m['timestamp']}') ?? DateTime.now(),
              'isStreaming': false,
            }));
        _initializedGreeting = _messages.isNotEmpty;
      });
    } catch (error) {
      debugPrint('Chat history unavailable: $error');
    }
    if (mounted) {
      setState(() => _historyLoaded = true);
      _scrollToBottom(animate: false);
    }
  }

  Future<void> _initializeChat(UserProfile? profile) async {
    final productName = _activeProduct?['name']?.toString().trim();
    final greeting = productName != null && productName.isNotEmpty
        ? "Hello, ${profile?.name ?? 'User'}! Let's inspect **$productName** against your allergies, health goals, and nutrition targets. What would you like to know?"
        : "Hello, ${profile?.name ?? 'User'}! I'm your personal nutrition assistant. "
            "How can I assist you with your ${profile?.healthGoals ?? 'general wellness'} goal today?";

    setState(() {
      _messages.add({
        "id": 'greeting_$_sessionId',
        "isGreeting": true,
        "message": greeting,
        "isUser": false,
        "isStreaming": false,
        "timestamp": DateTime.now(),
      });
      _quickReplies = productName != null && productName.isNotEmpty
          ? [
              'Is this suitable for my goals?',
              'Check ingredients & additives',
              'How much can I safely eat today?',
            ]
          : [
              'What can I eat tonight?',
              'How much protein is left today?',
              'Review my week',
            ];
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _buildConversationHistory() {
    final meaningful = <Map<String, dynamic>>[];
    for (var i = 0; i < _messages.length; i++) {
      final m = _messages[i];
      if (m['isGreeting'] == true ||
          m['isError'] == true ||
          m['isStreaming'] == true ||
          m['isRejected'] == true ||
          m['isFailed'] == true) {
        continue;
      }
      final nextIsError =
          i + 1 < _messages.length && _messages[i + 1]['isError'] == true;
      if (m['isUser'] == true && nextIsError) {
        continue;
      }
      meaningful.add(m);
    }
    final historyMessages =
        meaningful.isNotEmpty && meaningful.last['isUser'] == true
            ? meaningful.sublist(0, meaningful.length - 1)
            : meaningful;
    final history = StringBuffer();

    for (final message in historyMessages
        .skip((historyMessages.length - 12).clamp(0, historyMessages.length))) {
      final sender = (message["isUser"] as bool) ? "User" : "Assistant";
      final content = message["message"] as String;
      history.writeln("$sender: $content");
    }

    return history.toString();
  }

  Future<void> _updateQuickReplies() async {
    if (!mounted || !context.read<FeatureFlagService>().aiQuickRepliesEnabled) {
      return;
    }
    if (_messages.isEmpty ||
        _messages.last['isError'] == true ||
        _messages.last['isGreeting'] == true) {
      return;
    }
    final session = UserSession.instance.capture();
    try {
      final lastMessage = _messages.last["message"] as String? ?? "Hello";
      final profile = context.read<UserProfileProvider>().profile;

      final newReplies = await _cloudFunctionService.generateQuickReplies(
        lastMessage: lastMessage,
        userProfile: profile?.toMap() ?? {},
      );

      if (mounted && session.isActive) {
        setState(() => _quickReplies = newReplies);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _quickReplies = [
              "Help me with my diet",
              "What are some healthy snacks?"
            ]);
      }
    }
  }

  Future<void> _upsertSessionMetadata({
    required SessionToken session,
    required String firstOrTitleText,
    required String previewText,
  }) async {
    final existing = _sessions
        .where((s) => s['id']?.toString() == _sessionId)
        .firstOrNull;
    final productName = _activeProduct?['name']?.toString().trim() ?? '';
    final fallbackTitle = productName.isNotEmpty
        ? productName
        : firstOrTitleText.trim().length > 44
            ? '${firstOrTitleText.trim().substring(0, 44)}…'
            : firstOrTitleText.trim();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final barcode = _activeProduct?['barcode']?.toString().trim();

    await UserDataService().saveChatSession({
      'id': _sessionId,
      'title': (existing?['title']?.toString().trim().isNotEmpty == true)
          ? existing!['title']
          : (fallbackTitle.isEmpty ? 'Nutrition Chat' : fallbackTitle),
      'kind': _activeProduct != null ? 'product' : 'general',
      if (barcode != null && barcode.isNotEmpty) 'barcode': barcode,
      if (_activeProduct != null) 'product': _activeProduct,
      if (_activeFoodFit != null) 'foodFit': _activeFoodFit,
      'lastMessage': previewText.trim().length > 90
          ? '${previewText.trim().substring(0, 90)}…'
          : previewText.trim(),
      'createdAt': existing?['createdAt'] ?? nowIso,
      'updatedAt': nowIso,
    }, session);
    if (mounted && session.isActive) {
      final refreshed = await UserDataService().getChatSessions();
      if (mounted && session.isActive) {
        setState(() => _sessions = refreshed);
      }
    }
  }

  Future<void> _sendMessage(String message, {bool retry = false}) async {
    if (message.trim().isEmpty || _isLoading) return;
    final session = UserSession.instance.capture();
    final userMsgId = UserDataService.newId();
    final assistantMsgId = UserDataService.newId();

    setState(() {
      if (!retry) {
        _messages.add({
          "id": userMsgId,
          "sessionId": _sessionId,
          "message": message,
          "isUser": true,
          "isStreaming": false,
          "timestamp": DateTime.now(),
        });
      } else {
        final retryIdx = _messages.lastIndexWhere(
            (m) => m['isUser'] == true && m['message'] == message);
        if (retryIdx >= 0) {
          _messages[retryIdx] = {
            ..._messages[retryIdx],
            'isFailed': false,
          };
        }
      }
      _messages.add({
        "id": assistantMsgId,
        "sessionId": _sessionId,
        "message": "",
        "isUser": false,
        "isStreaming": true,
        "timestamp": DateTime.now(),
      });
      _isLoading = true;
      _showTypingIndicator = false;
      _errorMessage = null;
      _quickReplies = [];
    });

    _scrollToBottom();

    try {
      session.check();
      if (!mounted) return;
      final conversationHistory = _buildConversationHistory();
      final profile = context.read<UserProfileProvider>().profile;

      ChatStreamChunk? finalChunk;
      await for (final chunk in _cloudFunctionService.streamChatWithAI(
        currentProduct: _activeProduct,
        foodFit: _activeFoodFit,
        sessionId: _sessionId,
        message: message,
        conversationHistory: conversationHistory,
        userProfile: profile?.toMap() ?? {},
      )) {
        session.check();
        if (!mounted) return;
        final idx = _messages.indexWhere((m) => m['id'] == assistantMsgId);
        if (idx >= 0) {
          setState(() {
            _messages[idx] = {
              ..._messages[idx],
              'message': chunk.reply,
              'isStreaming': !chunk.isFinal,
            };
          });
        }
        if (chunk.isFinal) {
          finalChunk = chunk;
        } else {
          final follow = !_scrollController.hasClients ||
              _scrollController.position.extentAfter < 180;
          if (follow) _scrollToBottom(animate: false);
        }
      }

      final displayMessage = (finalChunk?.reply.trim().isNotEmpty == true)
          ? finalChunk!.reply
          : 'Sorry, I could not generate a response.';

      final finalizeIdx = _messages.indexWhere((m) => m['id'] == assistantMsgId);
      if (mounted && finalizeIdx >= 0) {
        setState(() {
          _messages[finalizeIdx] = {
            ..._messages[finalizeIdx],
            'message': displayMessage,
            'isStreaming': false,
          };
        });
      }

      session.check();
      _lastFailedMessage = null;
      await UserDataService().saveChatMessage({
        'id': userMsgId,
        'sessionId': _sessionId,
        'message': message,
        'isUser': true,
        'timestamp': DateTime.now().toIso8601String(),
      }, session);
      await UserDataService().saveChatMessage({
        'id': assistantMsgId,
        'sessionId': _sessionId,
        'message': displayMessage,
        'isUser': false,
        'timestamp': DateTime.now().toIso8601String(),
      }, session);

      await _upsertSessionMetadata(
        session: session,
        firstOrTitleText: message,
        previewText: displayMessage,
      );
      session.check();

      if (mounted) {
        final followReply = !_scrollController.hasClients ||
            _scrollController.position.extentAfter < 160;
        if (followReply) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final replyContext = _latestReplyKey.currentContext;
            if (mounted && replyContext != null) {
              Scrollable.ensureVisible(replyContext,
                  alignment: 0,
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic);
            }
          });
        }

        if (finalChunk?.mealData != null) {
          await _confirmMeal(finalChunk!.mealData!, session);
        }
      }
    } catch (e, st) {
      debugPrint('AI chat error (${e.runtimeType}): $e');
      if (e is! AiRequestException) {
        CrashReportingService.record(e, st);
      }
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m['id'] == assistantMsgId);
          final isRetryable = e is AiRequestException ? e.isRetryable : true;
          final userMsg = e is AiRequestException
              ? e.message
              : 'AI could not complete this request. Please retry.';
          final userIdx = _messages.lastIndexWhere(
              (m) => m['isUser'] == true && m['message'] == message);
          if (isRetryable) {
            if (userIdx >= 0) {
              _messages[userIdx] = {
                ..._messages[userIdx],
                'isFailed': true,
              };
            }
            _lastFailedMessage = message;
            _errorMessage = userMsg;
          } else {
            if (userIdx >= 0) {
              _messages[userIdx] = {
                ..._messages[userIdx],
                'isRejected': true,
              };
            }
            _lastFailedMessage = null;
            _errorMessage = null;
            _messages.add({
              "id": 'err_${UserDataService.newId()}',
              "message": userMsg,
              "isError": true,
              "isStreaming": false,
              "isUser": false,
              "timestamp": DateTime.now(),
            });
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _showTypingIndicator = false;
        });
        await _updateQuickReplies();
      }
    }
  }

  void _startNewChat() {
    if (_isLoading) return;
    setState(() {
      _sessionId = 'session_${UserDataService.newId()}';
      _activeProduct = null;
      _activeFoodFit = null;
      _messages.clear();
      _errorMessage = null;
      _lastFailedMessage = null;
      _initializedGreeting = false;
      _historyLoaded = true;
    });
    final profile = context.read<UserProfileProvider>().profile;
    _initializeChat(profile);
  }

  Future<void> _switchToSession(Map<String, dynamic> target) async {
    if (_isLoading) return;
    final id = target['id']?.toString().trim();
    if (id == null || id.isEmpty) return;
    setState(() {
      _sessionId = id;
      _restoreProductFromSession(target);
    });
    await _loadSessionMessages();
  }

  Future<void> _deleteSession(String sessionId) async {
    final session = UserSession.instance.capture();
    await UserDataService().deleteChatSession(sessionId, session);
    if (!mounted || !session.isActive) return;
    final refreshed = await UserDataService().getChatSessions();
    if (!mounted || !session.isActive) return;
    setState(() => _sessions = refreshed);
    if (sessionId == _sessionId) {
      _startNewChat();
    }
  }

  Future<void> _openHistorySheet() async {
    try {
      final refreshed = await UserDataService().getChatSessions();
      if (mounted) setState(() => _sessions = refreshed);
    } catch (_) {}
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Conversations',
                    style: FoodInsightTypography.heading(
                      size: 18,
                      weight: FontWeight.w800,
                      color: FoodInsightColors.deepCharcoal,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetCtx);
                      _startNewChat();
                    },
                    icon: const Icon(Icons.add_comment_outlined, size: 18),
                    label: const Text('New Chat'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_sessions.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Your saved AI conversations and product threads will appear here.',
                      textAlign: TextAlign.center,
                      style: FoodInsightTypography.body(
                        size: 14,
                        color: FoodInsightColors.midGray,
                      ),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _sessions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, idx) {
                      final s = _sessions[idx];
                      final id = s['id']?.toString() ?? '';
                      final isProduct = s['kind'] == 'product';
                      final isCurrent = id == _sessionId;
                      final stamp = DateTime.tryParse(
                          '${s['updatedAt'] ?? s['createdAt'] ?? ''}');
                      final dateLabel = stamp == null
                          ? ''
                          : DateFormat('MMM d, HH:mm').format(stamp.toLocal());
                      return ListTile(
                        selected: isCurrent,
                        leading: CircleAvatar(
                          backgroundColor: isProduct
                              ? FoodInsightColors.scannerGreenLight
                              : FoodInsightColors.warmWhite,
                          child: Icon(
                            isProduct
                                ? Icons.qr_code_2_rounded
                                : Icons.chat_bubble_outline_rounded,
                            color: FoodInsightColors.scannerGreenDark,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          s['title']?.toString() ?? 'Nutrition Chat',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          [
                            if ((s['lastMessage']?.toString() ?? '').isNotEmpty)
                              s['lastMessage'].toString(),
                            if (dateLabel.isNotEmpty) dateLabel,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          tooltip: 'Delete thread',
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 20, color: FoodInsightColors.midGray),
                          onPressed: () async {
                            Navigator.pop(sheetCtx);
                            await _deleteSession(id);
                          },
                        ),
                        onTap: () async {
                          Navigator.pop(sheetCtx);
                          await _switchToSession(s);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmMeal(
      Map<String, dynamic> meal, SessionToken session) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: const Text('Add this meal?'),
              content: Text(
                  '${meal['name']}\n${meal['calories']} kcal (AI estimate)\nCheck the portion before adding it to today’s log.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Not now')),
                FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Add meal'))
              ],
            ));
    if (confirmed != true || !mounted || !session.isActive) return;
    final id = UserDataService.newId();
    await UserDataService().saveDietEntry({
      ...meal,
      'id': id,
      'brand': 'AI estimate',
      'nutritionSource': 'ai_estimate'
    });
    if (!mounted || !session.isActive) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text("Meal added to today's log"),
      action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            if (session.isActive) await UserDataService().deleteDietEntry(id);
          }),
    ));
  }

  void _handleQuickReply(String suggestion) {
    _sendMessage(suggestion);
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (!animate || MediaQuery.disableAnimationsOf(context)) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          return;
        }
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<UserProfileProvider>().profile;
    if (_historyLoaded && !_initializedGreeting) {
      _initializedGreeting = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _messages.isEmpty) {
          _initializeChat(profile);
        }
      });
    }

    final productTitle = _activeProduct?['name']?.toString().trim() ?? '';

    return Scaffold(
      backgroundColor: FoodInsightColors.warmWhite,
      body: Column(
        children: [
          RepaintBoundary(
            child: ChatHeaderWidget(
              title: productTitle.isNotEmpty ? productTitle : 'Food Insight AI',
              subtitle: productTitle.isNotEmpty
                  ? 'Product discussion'
                  : 'Nutrition assistant',
              onBackPressed:
                  widget.onExitRequested ?? () => Navigator.maybePop(context),
              onHistoryPressed: _openHistorySheet,
              onNewChatPressed: _isLoading ? null : _startNewChat,
            ),
          ),
          if (productTitle.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: FoodInsightColors.scannerGreenLight,
              child: Row(
                children: [
                  const Icon(Icons.qr_code_2_rounded,
                      size: 16, color: FoodInsightColors.scannerGreenDark),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Focused on $productTitle',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FoodInsightTypography.caption(
                        size: 12,
                        weight: FontWeight.w700,
                        color: FoodInsightColors.scannerGreenDark,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _isLoading ? null : _startNewChat,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('Switch to General'),
                  ),
                ],
              ),
            ),
          if (_errorMessage != null)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(3.w),
              margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
              decoration: BoxDecoration(
                color: FoodInsightColors.healthRedLight,
                borderRadius: FoodInsightRadius.smAll,
                border: Border.all(
                  color: FoodInsightColors.healthRed.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded,
                      color: FoodInsightColors.healthRed, size: 5.w),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: FoodInsightTypography.caption(
                        size: 12,
                        color: FoodInsightColors.healthRed,
                      ),
                    ),
                  ),
                  if (_lastFailedMessage != null && !_isLoading)
                    TextButton.icon(
                      onPressed: () {
                        setState(() => _errorMessage = null);
                        _sendMessage(_lastFailedMessage!, retry: true);
                      },
                      icon: const Icon(Icons.refresh_rounded,
                          color: FoodInsightColors.healthRed, size: 16),
                      label: Text('Retry',
                          style: FoodInsightTypography.caption(
                            size: 12,
                            weight: FontWeight.w700,
                            color: FoodInsightColors.healthRed,
                          )),
                    ),
                  IconButton(
                    onPressed: () => setState(() => _errorMessage = null),
                    icon: Icon(Icons.close_rounded,
                        color: FoodInsightColors.healthRed, size: 4.w),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: FoodInsightColors.warmBackground,
              ),
              child: Column(
                children: [
                  Expanded(
                      child: RepaintBoundary(
                          child: ListView.builder(
                    controller: _scrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemCount:
                        _messages.length + (_showTypingIndicator ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return _showTypingIndicator
                            ? const TypingIndicatorWidget()
                            : const SizedBox.shrink();
                      }
                      final message = _messages[index];
                      final bubble = MessageBubbleWidget(
                        key: ValueKey(
                            '${message['id']}-${message['timestamp']}'),
                        message: message["message"] as String,
                        isUser: message["isUser"] as bool,
                        isStreaming: message["isStreaming"] == true,
                        timestamp: message["timestamp"] as DateTime,
                      );
                      return index == _messages.length - 1 &&
                              message['isUser'] != true
                          ? KeyedSubtree(key: _latestReplyKey, child: bubble)
                          : bubble;
                    },
                  ))),
                  RepaintBoundary(
                      child: QuickReplyWidget(
                    suggestions: _quickReplies,
                    onSuggestionTap: _handleQuickReply,
                  )),
                ],
              ),
            ),
          ),
          RepaintBoundary(
              child: Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
            child: ChatInputWidget(
              textController: _messageController,
              onSendMessage: _sendMessage,
              isLoading: _isLoading,
            ),
          )),
        ],
      ),
    );
  }
}
