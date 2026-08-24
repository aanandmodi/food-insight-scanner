// lib/presentation/ai_chat_assistant/ai_chat_assistant.dart

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../../services/cloud_function_service.dart';
import '../../services/local_database_service.dart';
import '../../services/firestore_service.dart';
import '../../models/user_profile.dart';
import 'package:provider/provider.dart';
import '../../data/providers/user_profile_provider.dart';
import '../../theme/app_design_system.dart';
import './widgets/chat_header_widget.dart';
import './widgets/chat_input_widget.dart';
import './widgets/message_bubble_widget.dart';
import './widgets/quick_reply_widget.dart';
import './widgets/typing_indicator_widget.dart';

import 'package:image_picker/image_picker.dart';

class AiChatAssistant extends StatefulWidget {
  final XFile? initialImage;
  const AiChatAssistant({super.key, this.initialImage});
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

  List<String> _quickReplies = [];
  String _mealLogContext = '';

  @override
  void initState() {
    super.initState();
    _loadTodaysMealLogs();
  }

  /// Load today's meal logs to provide context to the AI
  Future<void> _loadTodaysMealLogs() async {
    try {
      final now = DateTime.now();
      final dateString =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      List<Map<String, dynamic>> entries = [];
      try {
        entries = await FirestoreService().getDietLog(dateString);
      } catch (e) {
        debugPrint('Firestore diet log query failed: $e');
        try {
          entries = await LocalDatabaseService().getDietLogByDate(dateString);
        } catch (e2) {
          debugPrint('Local diet log query failed: $e2');
        }
      }

      if (entries.isNotEmpty) {
        final buffer = StringBuffer();
        buffer.writeln("Today's meal log:");
        int totalCals = 0;
        double totalProtein = 0;
        for (var entry in entries) {
          final name = entry['name'] ?? 'Unknown meal';
          final cals = (entry['calories'] as num?)?.toInt() ?? 0;
          final protein = (entry['protein'] as num?)?.toDouble() ?? 0;
          final time = entry['time'] ?? '';
          buffer.writeln("- $name: $cals kcal, ${protein.toStringAsFixed(1)}g protein${time.isNotEmpty ? ' (at $time)' : ''}");
          totalCals += cals;
          totalProtein += protein;
        }
        buffer.writeln("Total so far: $totalCals kcal, ${totalProtein.toStringAsFixed(1)}g protein");
        _mealLogContext = buffer.toString();
      }
    } catch (e) {
      debugPrint('Error loading meal logs for chat context: $e');
    }
  }

  Future<void> _initializeChat(UserProfile? profile) async {
    setState(() {
      _isLoading = true;
      _showTypingIndicator = true;
    });

    setState(() {
      _messages.add({
        "id": 1,
        "message":
            "Hello, ${profile?.name ?? 'User'}! I'm your personal nutrition assistant. "
            "How can I assist you with your ${profile?.healthGoals ?? 'general wellness'} goal today?",
        "isUser": false,
        "timestamp": DateTime.now(),
      });
      _isLoading = false;
      _showTypingIndicator = false;
    });
    _updateQuickReplies();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Structured prior turns for the model.
  ///
  /// The old string transcript ("User: …\nAssistant: …") split every reply on
  /// newlines, so any multi-line answer was shredded into bogus turns and the
  /// 20-turn window cap counted lines instead of messages.
  List<Map<String, String>> _buildConversationHistory() {
    // The just-added user message is passed separately as `message`.
    final historyMessages =
        _messages.length > 1 ? _messages.sublist(0, _messages.length - 1) : _messages;

    final history = <Map<String, String>>[];
    for (final message in historyMessages) {
      final content = (message['message'] as String?)?.trim() ?? '';
      if (content.isEmpty) continue;
      history.add({
        'role': (message['isUser'] as bool? ?? false) ? 'user' : 'assistant',
        'content': content,
      });
    }
    return history;
  }
  
  Future<void> _updateQuickReplies() async {
    try {
      final lastMessage = _messages.last["message"] as String? ?? "Hello";
      
      final profile = context.read<UserProfileProvider>().profile;
      
      final newReplies = await _cloudFunctionService.generateQuickReplies(
        lastMessage: lastMessage,
        userProfile: profile?.toMap() ?? {},
      );

      if (mounted) {
        setState(() => _quickReplies = newReplies);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _quickReplies = [ "Help me with my diet", "What are some healthy snacks?"]);
      }
    }
  }
  
  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty || _isLoading) return;

    setState(() {
      _messages.add({
        "id": _messages.length + 1,
        "message": message,
        "isUser": true,
        "timestamp": DateTime.now(),
      });
      _isLoading = true;
      _showTypingIndicator = true;
      _errorMessage = null;
      _quickReplies = [];
    });

    _scrollToBottom();

    try {
      final conversationHistory = _buildConversationHistory();
      final profile = context.read<UserProfileProvider>().profile;

      final result = await _cloudFunctionService.chatWithAI(
        message: message,
        history: conversationHistory,
        userProfile: profile?.toMap() ?? {},
        mealLogContext: _mealLogContext,
      );

      final displayMessage = result['reply'] as String? ?? 'Sorry, I could not generate a response.';
      final mealLogged = result['mealLogged'] as bool? ?? false;

      if (mounted) {
        setState(() {
          _messages.add({
            "id": _messages.length + 1,
            "message": displayMessage,
            "isUser": false,
            "timestamp": DateTime.now(),
          });
        });

        if (mealLogged) {
          final mealName = (result['mealData'] as Map?)?['name'] ?? 'Meal';
          // Refresh meal log context after logging
          await _loadTodaysMealLogs();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ "$mealName" logged to your diet!'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          String userMsg = "I apologize, but I'm having trouble connecting. Please try again in a moment.";
          String bannerMsg = 'Error communicating with AI. Please check your internet.';

          // Type-check instead of substring-matching. These exceptions stringify
          // to a human-readable sentence that never contains the raw status code
          // or the words "api key", so the old contains('429')/contains('api key')
          // tests could never fire — every failure, including a rejected key or a
          // rate limit, told the user to check their internet.
          if (e is AiUnavailableException) {
            bannerMsg = e.message;
            userMsg =
                "My AI brain isn't set up right now! ${e.message}";
          } else if (e is AiRequestException) {
            bannerMsg = e.message;
            if (e.isAuthFailure) {
              userMsg =
                  "My AI brain isn't authorized right now! Please check the API key in the app Settings.";
            } else if (e.isRateLimited) {
              userMsg =
                  "Whoa, slow down! I'm getting too many requests right now. Please give me a moment to catch my breath.";
            } else {
              userMsg = e.message;
            }
          }

          _messages.add({
            "id": _messages.length + 1,
            "message": userMsg,
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
    if (!_initializedGreeting) {
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
                  Icon(Icons.error_outline, color: FoodInsightColors.healthRed, size: 5.w),
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
                  if (_errorMessage!.contains('internet') || _errorMessage!.contains('communicating'))
                    TextButton.icon(
                      onPressed: () {
                        setState(() => _errorMessage = null);
                        _initializeChat(profile);
                      },
                      icon: Icon(Icons.refresh, color: FoodInsightColors.healthRed, size: 16),
                      label: Text('Retry', style: FoodInsightTypography.caption(
                        size: 12,
                        weight: FontWeight.w700,
                        color: FoodInsightColors.healthRed,
                      )),
                    ),
                  IconButton(
                    onPressed: () => setState(() => _errorMessage = null),
                    icon: Icon(Icons.close, color: FoodInsightColors.healthRed, size: 4.w),
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
                    itemCount: _messages.length + (_showTypingIndicator ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return _showTypingIndicator ? const TypingIndicatorWidget() : const SizedBox.shrink();
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
