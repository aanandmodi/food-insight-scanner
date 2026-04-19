// lib/presentation/ai_chat_assistant/ai_chat_assistant.dart

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../../core/app_export.dart';
import '../../services/cloud_function_service.dart';
import '../../models/user_profile.dart'; // Import the UserProfile model
import 'package:provider/provider.dart';
import '../../data/providers/user_profile_provider.dart';
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
  final GroqService _groqService = CloudFunctionService();

  bool _isLoading = false;
  bool _showTypingIndicator = false;
  String? _errorMessage;

  final List<Map<String, dynamic>> _messages = [];
  
  // REMOVED: The hardcoded user profile is no longer needed.
  // We will use `widget.userProfile` instead.

  List<String> _quickReplies = [];

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    setState(() {
      _isLoading = true;
      _showTypingIndicator = true;
    });

    // No client-side API key initialization needed — AI calls go through
    // Cloud Functions which hold the key server-side.
    final profile = context.read<UserProfileProvider>().profile;
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

  String _buildConversationHistory() {
    final historyMessages = _messages.length > 1 ? _messages.sublist(0, _messages.length -1) : _messages;
    final history = StringBuffer();
    
    for (final message in historyMessages) {
      final sender = (message["isUser"] as bool) ? "User" : "Assistant";
      final content = message["message"] as String;
      history.writeln("$sender: $content");
    }
    
    return history.toString();
  }
  
  Future<void> _updateQuickReplies() async {
    try {
      final lastMessage = _messages.last["message"] as String? ?? "Hello";
      
      final profile = context.read<UserProfileProvider>().profile;
      
      final newReplies = await _groqService.generateQuickReplies(
        lastUserMessage: lastMessage,
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

      // Use the meta variant so we can detect server-side meal logging
      final result = await _groqService.generateResponseWithMeta(
        userMessage: message,
        conversationHistory: conversationHistory,
        userProfile: profile?.toMap() ?? {},
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

        // Show a subtle toast if a meal was auto-logged server-side
        if (mealLogged) {
          final mealName = (result['mealData'] as Map?)?['name'] ?? 'Meal';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ "$mealName" logged to your diet!'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({
            "id": _messages.length + 1,
            "message": "I apologize, but I'm having trouble connecting. Please try again in a moment.",
            "isUser": false,
            "timestamp": DateTime.now(),
          });

          _errorMessage = 'Error communicating with AI. Please check your internet.';
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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          ChatHeaderWidget(
            onBackPressed: () => Navigator.pop(context),
          ),
          if (_errorMessage != null)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(3.w),
              margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 5.w),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade800, fontSize: 12.sp),
                    ),
                  ),
                  if (_errorMessage!.contains('internet') || _errorMessage!.contains('communicating'))
                    TextButton.icon(
                      onPressed: () {
                        setState(() => _errorMessage = null);
                        if (_messages.length <= 1) {
                            _initializeChat();
                        } else {
                            // Retry the last message by sending it again
                            // Could implement a resend feature, but basic init works too
                            _initializeChat();
                        }
                      },
                      icon: const Icon(Icons.refresh, color: Colors.red, size: 16),
                      label: const Text('Retry', style: TextStyle(color: Colors.red)),
                    ),
                  IconButton(
                    onPressed: () => setState(() => _errorMessage = null),
                    icon: Icon(Icons.close, color: Colors.red, size: 4.w),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).scaffoldBackgroundColor,
                    Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
                  ],
                ),
              ),
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.symmetric(vertical: 2.h),
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
            ),
          ),
          QuickReplyWidget(
            suggestions: _quickReplies,
            onSuggestionTap: _handleQuickReply,
          ),
          ChatInputWidget(
            textController: _messageController,
            onSendMessage: _sendMessage,
            onVoiceMessage: (text) => _sendMessage("🎤 (Voice) $text"),
            isLoading: _isLoading,
          ),
        ],
      ),
    );
  }
}
