import '../../services/feature_flag_service.dart';
import '../../services/user_session.dart';
// lib/presentation/ai_chat_assistant/ai_chat_assistant.dart

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../../services/cloud_function_service.dart';
import '../../services/user_data_service.dart';
import '../../models/user_profile.dart';
import 'package:provider/provider.dart';
import '../../data/providers/user_profile_provider.dart';
import '../../theme/app_design_system.dart';
import './widgets/chat_header_widget.dart';
import './widgets/chat_input_widget.dart';
import './widgets/message_bubble_widget.dart';
import './widgets/quick_reply_widget.dart';
import './widgets/typing_indicator_widget.dart';

class AiChatAssistant extends StatefulWidget {
  const AiChatAssistant({super.key});
  @override
  State<AiChatAssistant> createState() => _AiChatAssistantState();
}

class _AiChatAssistantState extends State<AiChatAssistant> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final CloudFunctionService _cloudFunctionService = CloudFunctionService();

  bool _isLoading = false;
  bool _showTypingIndicator = false;
  String? _errorMessage;

  final List<Map<String, dynamic>> _messages = [];
  bool _initializedGreeting = false;
  bool _historyLoaded = false;

  List<String> _quickReplies = [];
  String? _lastFailedMessage;

  @override
  void initState() {
    super.initState();
    _restoreHistory();
  }

  Future<void> _restoreHistory() async {
    try {
      final session = UserSession.instance.capture();
      final messages = await UserDataService().getChatMessages();
      if (!mounted || !session.isActive) return;
      setState(() {
        _messages.addAll(messages.map((m) => {
              ...m,
              'timestamp':
                  DateTime.tryParse('${m['timestamp']}') ?? DateTime.now()
            }));
        _initializedGreeting = _messages.isNotEmpty;
      });
    } catch (error) {
      debugPrint('Chat history unavailable: $error');
    }
    if (mounted) setState(() => _historyLoaded = true);
  }

  Future<void> _initializeChat(UserProfile? profile) async {
    setState(() {
      _isLoading = true;
      _showTypingIndicator = true;
    });

    setState(() {
      _messages.add({
        "id": 1,
        "isGreeting": true,
        "message":
            "Hello, ${profile?.name ?? 'User'}! I'm your personal nutrition assistant. "
                "How can I assist you with your ${profile?.healthGoals ?? 'general wellness'} goal today?",
        "isUser": false,
        "timestamp": DateTime.now(),
      });
      _isLoading = false;
      _showTypingIndicator = false;
    });
    setState(() => _quickReplies = [
          'What can I eat tonight?',
          'How much protein is left today?',
          'Review my week'
        ]);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _buildConversationHistory() {
    final meaningful = _messages
        .where((m) => m['isGreeting'] != true && m['isError'] != true)
        .toList();
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
    } catch (e) {
      if (mounted) {
        setState(() => _quickReplies = [
              "Help me with my diet",
              "What are some healthy snacks?"
            ]);
      }
    }
  }

  Future<void> _sendMessage(String message, {bool retry = false}) async {
    if (message.trim().isEmpty || _isLoading) return;
    final session = UserSession.instance.capture();
    final messageId = UserDataService.newId();

    setState(() {
      if (!retry) {
        _messages.add({
          "id": messageId,
          "message": message,
          "isUser": true,
          "timestamp": DateTime.now(),
        });
      }
      _isLoading = true;
      _showTypingIndicator = true;
      _errorMessage = null;
      _quickReplies = [];
    });

    _scrollToBottom();

    try {
      if (!retry) {
        await UserDataService().saveChatMessage({
          'id': messageId,
          'message': message,
          'isUser': true,
          'timestamp': DateTime.now().toIso8601String()
        }, session);
      }
      session.check();
      if (!mounted) return;
      final conversationHistory = _buildConversationHistory();
      final profile = context.read<UserProfileProvider>().profile;

      final result = await _cloudFunctionService.chatWithAI(
        currentProduct: (ModalRoute.of(context)?.settings.arguments
            as Map?)?['product'] as Map<String, dynamic>?,
        foodFit: (ModalRoute.of(context)?.settings.arguments
            as Map?)?['foodFit'] as Map<String, dynamic>?,
        message: message,
        conversationHistory: conversationHistory,
        userProfile: profile?.toMap() ?? {},
      );

      session.check();
      _lastFailedMessage = null;
      final displayMessage = result['reply'] as String? ??
          'Sorry, I could not generate a response.';
      await UserDataService().saveChatMessage({
        'message': displayMessage,
        'isUser': false,
        'timestamp': DateTime.now().toIso8601String()
      }, session);
      session.check();

      if (mounted) {
        setState(() {
          _messages.add({
            "id": _messages.length + 1,
            "message": displayMessage,
            "isUser": false,
            "timestamp": DateTime.now(),
          });
        });

        if (result['mealData'] is Map) {
          await _confirmMeal(
              Map<String, dynamic>.from(result['mealData'] as Map), session);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          final userMsg = e is AiRequestException
              ? e.message
              : 'AI could not complete this request. Please retry.';
          final bannerMsg = userMsg;
          _lastFailedMessage = message;

          _messages.add({
            "id": _messages.length + 1,
            "message": userMsg,
            "isError": true,
            "isUser": false,
            "timestamp": DateTime.now(),
          });

          _errorMessage = bannerMsg;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _showTypingIndicator = false;
        });
        _scrollToBottom();
        await _updateQuickReplies();
      }
    }
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
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

    return Scaffold(
      backgroundColor: FoodInsightColors.warmWhite,
      body: Column(
        children: [
          ChatHeaderWidget(
            onBackPressed: () => Navigator.maybePop(context),
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
                  Icon(Icons.error_outline,
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
                      icon: const Icon(Icons.refresh,
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
                    icon: Icon(Icons.close,
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
              child: Stack(
                children: [
                  ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.only(top: 2.h, bottom: 8.h),
                    itemCount:
                        _messages.length + (_showTypingIndicator ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return _showTypingIndicator
                            ? const TypingIndicatorWidget()
                            : const SizedBox.shrink();
                      }
                      final message = _messages[index];
                      return MessageBubbleWidget(
                        message: message["message"] as String,
                        isUser: message["isUser"] as bool,
                        timestamp: message["timestamp"] as DateTime,
                      );
                    },
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: QuickReplyWidget(
                      suggestions: _quickReplies,
                      onSuggestionTap: _handleQuickReply,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: 10.h),
            child: ChatInputWidget(
              textController: _messageController,
              onSendMessage: _sendMessage,
              onVoiceMessage: (text) => _sendMessage("🎤 (Voice) $text"),
              isLoading: _isLoading,
            ),
          ),
        ],
      ),
    );
  }
}
