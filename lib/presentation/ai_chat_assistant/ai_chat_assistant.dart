// lib/presentation/ai_chat_assistant/ai_chat_assistant.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';
import '../../core/app_export.dart';
import '../../core/services/groq_service.dart';
import '../../core/services/firestore_service.dart';
import '../../models/user_profile.dart'; // Import the UserProfile model
import './widgets/chat_header_widget.dart';
import './widgets/chat_input_widget.dart';
import './widgets/message_bubble_widget.dart';
import './widgets/quick_reply_widget.dart';
import './widgets/typing_indicator_widget.dart';


class AiChatAssistant extends StatefulWidget {
  // Add a userProfile parameter to the constructor
  final UserProfile userProfile;

  const AiChatAssistant({super.key, required this.userProfile});
  @override
  State<AiChatAssistant> createState() => _AiChatAssistantState();
}

class _AiChatAssistantState extends State<AiChatAssistant> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GroqService _groqService = GroqService();

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

    try {
      await _groqService.initialize();
      setState(() {
         _messages.add({
            "id": 1,
            // FIX: Use the user's actual name and health goal from the widget's userProfile
            "message": "Hello, ${widget.userProfile.name}! I'm your personal nutrition assistant. How can I assist you with your ${widget.userProfile.healthGoals} goal today?",
            "isUser": false,
            "timestamp": DateTime.now(),
          });
          _isLoading = false;
          _showTypingIndicator = false;
      });
      _updateQuickReplies();
    } catch (e) {
      final errorStr = e.toString();
      final isApiKeyMissing = errorStr.contains('GROQ_API_KEY') ||
          errorStr.contains('not found') ||
          errorStr.contains('not set');

      setState(() {
        _isLoading = false;
        _showTypingIndicator = false;

        if (isApiKeyMissing) {
          // Show a helpful welcome message with setup instructions
          _messages.add({
            "id": 1,
            "message":
                "👋 Hi ${widget.userProfile.name}! I'm NutriBot, your AI nutrition assistant.\n\n"
                "⚠️ **Setup Required:** To enable AI features, you need a free Groq API key.\n\n"
                "**Steps:**\n"
                "1. Go to **console.groq.com**\n"
                "2. Sign up and copy your API key\n"
                "3. Open `assets/env.json` in the project\n"
                "4. Replace `your-groq-api-key-here` with your key\n"
                "5. Rebuild the app\n\n"
                "In the meantime, you can still scan products, track nutrition, and manage your shopping list! 🛒",
            "isUser": false,
            "timestamp": DateTime.now(),
          });
          _errorMessage = null; // Don't show the red error banner
        } else {
          _messages.add({
            "id": 1,
            "message": "Hi ${widget.userProfile.name}! I'm having trouble connecting right now. Please check your internet and try again.",
            "isUser": false,
            "timestamp": DateTime.now(),
          });
          _errorMessage = 'Connection issue. Please check your internet.';
        }
      });
    }
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
      
      final newReplies = await _groqService.generateQuickReplies(
        lastUserMessage: lastMessage,
        // FIX: Use the user profile from the widget
        userProfile: widget.userProfile.toMap(),
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
      
      final aiResponse = await _groqService.generateResponse(
        userMessage: message,
        conversationHistory: conversationHistory,
        // FIX: Use the user profile from the widget
        userProfile: widget.userProfile.toMap(),
      );

      String displayMessage = aiResponse;

      // Extract conversational auto-log intent
      final logMatch = RegExp(r'\[LOG_MEAL:\s*({.*?})\s*\]', dotAll: true).firstMatch(displayMessage);
      if (logMatch != null) {
        try {
          final jsonStr = logMatch.group(1)!;
          final macros = jsonDecode(jsonStr);
          
          final dateString = DateFormat('yyyy-MM-dd').format(DateTime.now());
          final entry = {
            'name': macros['name'] ?? 'AI Logged Meal',
            'mealType': 'Snack',
            'calories': macros['calories'] ?? 0,
            'protein': (macros['protein'] ?? 0).toDouble(),
            'sugar': (macros['sugar'] ?? 0).toDouble(),
            'fat': (macros['fat'] ?? 0).toDouble(),
            'carbs': (macros['carbs'] ?? 0).toDouble(),
            'brand': 'Conversational AI',
            'time': DateFormat('HH:mm').format(DateTime.now()),
            'date': dateString,
          };
          
          FirestoreService().saveDietEntry(entry);
          
          // Remove the tag from the UI message smoothly
          displayMessage = displayMessage.replaceAll(logMatch.group(0)!, '').trim();
        } catch (e) {
          debugPrint('Failed to parse AI log intent: $e');
        }
      }

      if(mounted) {
        setState(() {
          _messages.add({
            "id": _messages.length + 1,
            "message": displayMessage,
            "isUser": false,
            "timestamp": DateTime.now(),
          });
        });
      }

    } catch (e) {
       if(mounted) {
        setState(() {
          _messages.add({
            "id": _messages.length + 1,
            "message": "I apologize, but I'm having trouble connecting. Please try again in a moment.",
            "isUser": false,
            "timestamp": DateTime.now(),
          });
          
          final errorString = e.toString();
          if (errorString.contains('401')) {
            _errorMessage = 'Invalid API Key. Please enter a valid Groq API key in assets/env.json and rebuild the app.';
          } else {
            _errorMessage = 'Error communicating with AI: $errorString';
          }
        });
      }
    }
    finally {
        if(mounted) {
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
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
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
                    AppTheme.lightTheme.scaffoldBackgroundColor,
                    AppTheme.lightTheme.colorScheme.surface.withValues(alpha: 0.5),
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