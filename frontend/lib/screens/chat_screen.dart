import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sartaroshxona/providers/theme_provider.dart';
import 'package:sartaroshxona/services/api_service.dart';

class ChatScreen extends StatefulWidget {
  final int userId;
  final int receiverId;
  final String receiverName;
  final bool isBarber;

  const ChatScreen({
    super.key,
    required this.userId,
    required this.receiverId,
    required this.receiverName,
    this.isBarber = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isSending = false;
  bool _isLoading = true;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadMessages(initial: true);
    // Har 4 soniyada yangi xabarlarni tekshirib turish (oddiy polling)
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _loadMessages());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _fmtTime(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  Future<void> _loadMessages({bool initial = false}) async {
    final data = await ApiService().getMessages(widget.userId, widget.receiverId);
    if (!mounted) return;
    final hadMessages = _messages.length;
    setState(() {
      _isLoading = false;
      _messages
        ..clear()
        ..addAll(data.map((m) => _ChatMessage(
              text: m['body']?.toString() ?? '',
              isMine: m['sender_id'] == widget.userId,
              time: _fmtTime(m['created_at']?.toString()),
            )));
    });
    // Yangi xabar kelsa yoki birinchi yuklanishda pastga aylantirish
    if (initial || _messages.length != hadMessages) {
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
      // Optimistik ko'rsatish — darhol ekranga qo'shamiz
      _messages.add(_ChatMessage(
        text: text,
        isMine: true,
        time: _fmtTime(DateTime.now().toIso8601String()),
      ));
      _msgController.clear();
    });
    _scrollToBottom();

    final sent = await ApiService().sendMessage(widget.userId, widget.receiverId, text);
    if (!mounted) return;
    setState(() => _isSending = false);

    if (sent == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Xabar yuborilmadi. Internetni tekshiring."),
        behavior: SnackBarBehavior.floating,
      ));
    } else {
      // Serverdagi haqiqiy holat bilan sinxronlash
      _loadMessages();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [colors.primary, colors.primaryLight]),
              ),
              child: Center(
                child: Text(
                  widget.receiverName.isNotEmpty ? widget.receiverName[0].toUpperCase() : 'S',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.receiverName, style: TextStyle(color: colors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                Text("Online", style: TextStyle(color: colors.success, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Xabarlar ro'yxati
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded, size: 56, color: colors.textTertiary),
                            const SizedBox(height: 12),
                            Text(
                              "Hali xabarlar yo'q.\nBirinchi xabarni yozing!",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: colors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) => _buildMessage(colors, _messages[i]),
                      ),
          ),

          // Xabar yozish
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 24),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(top: BorderSide(color: colors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: colors.surfaceVariant,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _msgController,
                      style: TextStyle(color: colors.textPrimary),
                      decoration: InputDecoration(
                        hintText: "Xabar yozing...",
                        hintStyle: TextStyle(color: colors.textTertiary),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [colors.primary, colors.primaryLight]),
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(AppColors colors, _ChatMessage message) {
    return Align(
      alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: message.isMine ? colors.primary : colors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(message.isMine ? 16 : 4),
            bottomRight: Radius.circular(message.isMine ? 4 : 16),
          ),
          border: message.isMine ? null : Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: message.isMine ? Colors.white : colors.textPrimary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message.time,
              style: TextStyle(
                color: message.isMine ? Colors.white70 : colors.textTertiary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isMine;
  final String time;

  _ChatMessage({required this.text, required this.isMine, required this.time});
}
