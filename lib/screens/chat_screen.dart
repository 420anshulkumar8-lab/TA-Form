// lib/screens/chat_screen.dart
// Section 9 — AI Chat Screen (TA + Contingent tabs)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ta_session.dart';
import '../providers/app_provider.dart';
import '../services/hive_service.dart';
import '../services/api_service.dart';
import '../services/pdf_service.dart';
import '../widgets/chat_bubble_widget.dart';
import '../widgets/status_badge_widget.dart';

class ChatScreen extends StatefulWidget {
  final TaSession session;

  const ChatScreen({super.key, required this.session});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollTa = ScrollController();
  final ScrollController _scrollCont = ScrollController();

  bool _isTaTab = true;
  bool _isLoading = false;

  bool get _taFinalized =>
      widget.session.formDataTa != null &&
      (widget.session.formDataTa!['status'] == 'submitted' ||
          widget.session.formDataTa!['status'] == 'pending');

  bool get _bothSelected =>
      widget.session.selectTa && widget.session.selectContingent;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _bothSelected ? 2 : 1,
      vsync: this,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _isTaTab = _tabController.index == 0);
      }
    });

    // Auto-send first greeting if chat is empty
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isTaTab &&
          widget.session.chatHistoryTa.isEmpty) {
        _autoGreet();
      } else if (!_isTaTab &&
          widget.session.chatHistoryContingent.isEmpty) {
        _autoGreet();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _inputCtrl.dispose();
    _scrollTa.dispose();
    _scrollCont.dispose();
    super.dispose();
  }

  // ── Auto-trigger greeting from AI ─────────────────────────────────────────
  Future<void> _autoGreet() async {
    final profile = context.read<AppProvider>().profile;
    final greeting = _isTaTab
        ? 'Namaste ${profile.name.split(' ').first}!'
        : 'Start contingent';
    await _sendMessage(greeting, skipDisplay: true);
  }

  // ── Send message ──────────────────────────────────────────────────────────
  Future<void> _sendMessage(String text,
      {bool skipDisplay = false}) async {
    if (text.trim().isEmpty) return;

    final provider = context.read<AppProvider>();
    final apiKey = provider.apiKey;
    final model = provider.model;

    if (apiKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'API config load nahi ho saki. Internet check karein.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final profile = provider.profile;
    final userMsg = ChatMessage(
      role: 'user',
      content: text.trim(),
      timestamp: DateTime.now().toIso8601String(),
    );

    setState(() {
      if (!skipDisplay) {
        if (_isTaTab) {
          widget.session.chatHistoryTa.add(userMsg);
        } else {
          widget.session.chatHistoryContingent.add(userMsg);
        }
      }
      _isLoading = true;
    });
    _inputCtrl.clear();
    _scrollToBottom();

    // Save immediately
    HiveService.saveSession(widget.session);

    final apiService =
        ApiService(apiKey: apiKey, model: model);

    ApiResponse response;
    if (_isTaTab) {
      response = await apiService.sendTaMessage(
        session: widget.session,
        profile: profile,
        newUserMessage: text.trim(),
      );
    } else {
      response = await apiService.sendContingentMessage(
        session: widget.session,
        profile: profile,
        newUserMessage: text.trim(),
      );
    }

    if (!mounted) return;

    // DEBUG: agar API call fail ho to asli reason dikhao (sirf debugging ke liye)
    if (response.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Debug error: ${response.error}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 8),
        ),
      );
    }

    final aiMsg = ChatMessage(
      role: 'assistant',
      content: response.cleanMessage,
      timestamp: DateTime.now().toIso8601String(),
    );

    setState(() {
      _isLoading = false;
      if (_isTaTab) {
        widget.session.chatHistoryTa.add(aiMsg);
      } else {
        widget.session.chatHistoryContingent.add(aiMsg);
      }
    });

    // ── Persist extracted form data ────────────────────────────────────────
    bool updated = false;

    if (response.taFormData != null) {
      widget.session.formDataTa = response.taFormData;
      widget.session.status = SessionStatus.draft;
      updated = true;

      // If TA submitted → unlock contingent
      if (response.taFormData!['status'] == 'submitted' &&
          _bothSelected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'TA complete! Ab contingent fill kar sakte hain.'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {});
      }
    }

    if (response.contingentFormData != null) {
      widget.session.formDataContingent =
          response.contingentFormData;
      updated = true;

      // If both finalized → generate PDF
      if (response.contingentFormData!['status'] == 'submitted' &&
          widget.session.formDataTa?['status'] == 'submitted') {
        await _finalize();
        return;
      }
      // If only contingent selected and finalized
      if (!widget.session.selectTa &&
          response.contingentFormData!['status'] == 'submitted') {
        await _finalize();
        return;
      }
    }

    // If only TA selected and TA finalized
    if (!widget.session.selectContingent &&
        response.taFormData?['status'] == 'submitted') {
      await _finalize();
      return;
    }

    if (updated) {
      widget.session.lastUpdated =
          DateTime.now().toIso8601String();
    }

    if (response.hasError) {
      _showRetrySnackbar(text);
    }

    HiveService.saveSession(widget.session);
    _scrollToBottom();
  }

  // ── Finalize: PDF + submit ─────────────────────────────────────────────────
  Future<void> _finalize() async {
    setState(() => _isLoading = true);

    try {
      final profile = context.read<AppProvider>().profile;
      widget.session.status = SessionStatus.submitted;
      widget.session.lastUpdated =
          DateTime.now().toIso8601String();

      final pdfPath = await PdfService.generatePdf(
        session: widget.session,
        profile: profile,
      );

      widget.session.pdfPath = pdfPath;
      HiveService.saveSession(widget.session);

      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/pdf-preview',
          arguments: {
            'pdfPath': pdfPath,
            'title': '${widget.session.displayLabel} TA Form',
          },
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF generation failed: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _finalize,
            ),
          ),
        );
      }
    }
  }

  void _showRetrySnackbar(String lastMessage) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
            'AI se connection nahi ho pa raha. Dobara try karein.'),
        action: SnackBarAction(
          label: 'Retry',
          onPressed: () => _sendMessage(lastMessage),
        ),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = _isTaTab ? _scrollTa : _scrollCont;
      if (controller.hasClients) {
        controller.animateTo(
          controller.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Build chat list ───────────────────────────────────────────────────────
  Widget _buildChatList(List<ChatMessage> messages,
      ScrollController scroll) {
    return ListView.builder(
      controller: scroll,
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == messages.length && _isLoading) {
          return const _TypingIndicator();
        }
        final msg = messages[i];
        return ChatBubbleWidget(
          message: msg.content,
          role: msg.role == 'user' ? BubbleRole.user : BubbleRole.assistant,
          timestamp: DateTime.tryParse(msg.timestamp),
        );
      },
    );
  }

  // ── Build input bar ───────────────────────────────────────────────────────
  Widget _buildInputBar() {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, -2),
          )
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputCtrl,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Apni journey batayein...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
                onSubmitted: (v) => _sendMessage(v),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              icon: const Icon(Icons.send),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
              ),
              onPressed: _isLoading
                  ? null
                  : () => _sendMessage(_inputCtrl.text),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title =
        '${widget.session.displayLabel} TA';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(title),
            const SizedBox(width: 8),
            StatusBadgeWidget(status: widget.session.status),
          ],
        ),
        bottom: _bothSelected
            ? TabBar(
                controller: _tabController,
                tabs: [
                  const Tab(
                    icon: Icon(Icons.flight_takeoff),
                    text: 'TA',
                  ),
                  Tab(
                    icon: Stack(
                      children: [
                        const Icon(Icons.receipt_long),
                        if (!_taFinalized)
                          const Positioned(
                            right: 0,
                            bottom: 0,
                            child: Icon(Icons.lock,
                                size: 12, color: Colors.orange),
                          ),
                      ],
                    ),
                    text: 'Contingent',
                  ),
                ],
                onTap: (i) {
                  if (i == 1 && !_taFinalized) {
                    _tabController.index = 0;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Pehle TA complete karein'),
                      ),
                    );
                  }
                },
              )
            : null,
      ),
      body: Column(
        children: [
          Expanded(
            child: _bothSelected
                ? TabBarView(
                    controller: _tabController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildChatList(
                          widget.session.chatHistoryTa, _scrollTa),
                      _buildChatList(
                          widget.session.chatHistoryContingent,
                          _scrollCont),
                    ],
                  )
                : _buildChatList(
                    widget.session.selectTa
                        ? widget.session.chatHistoryTa
                        : widget.session.chatHistoryContingent,
                    _scrollTa,
                  ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Typing dots animation
// ─────────────────────────────────────────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            3,
            (i) => AnimatedBuilder(
              animation: _anim,
              builder: (_, __) {
                final delay = i * 0.3;
                final val = ((_anim.value - delay).clamp(0, 1) *
                        3.14159)
                    .toDouble();
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 7,
                  height: 7 + 4 * (val > 0 ? val.clamp(0, 1) : 0),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade500,
                    shape: BoxShape.circle,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
