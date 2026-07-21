import 'package:flutter/material.dart';
import 'package:flutter_application_1/Services/api_client.dart';
import 'package:flutter_application_1/Services/socket_client.dart';
import 'package:flutter_application_1/Order/order_models.dart';

class MessagesScreen extends StatefulWidget {
  final String userId;
  final String? userName;
  const MessagesScreen({super.key, required this.userId, this.userName});
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  final _replyCtrl = TextEditingController();
  bool _sendingReply = false;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
    SocketClient.on('new_message', _onNewMessage);
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    _scrollCtrl.dispose();
    SocketClient.off('new_message', _onNewMessage);
    super.dispose();
  }

  void _onNewMessage(dynamic data) {
    if (data is Map<String, dynamic> && data['userId'] == widget.userId) {
      _messages.add(data.cast<String, dynamic>());
      if (mounted) setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
  }

  Future<void> _load() async {
    try {
      final list = await ApiClient.getList('/api/users/${widget.userId}/messages');
      if (!mounted) return;
      setState(() {
        _messages = list.cast<Map<String, dynamic>>();
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendReply() async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sendingReply = true);
    try {
      await ApiClient.post('/api/users/${widget.userId}/messages/reply', {'text': text});
      _replyCtrl.clear();
      await _load();
    } catch (_) {}
    if (mounted) setState(() => _sendingReply = false);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.userName ?? 'المحادثة مع الإدارة',
            style: const TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 15),
          ),
          centerTitle: true,
        ),
        body: Stack(
          children: [
            statusBarGradient(context),
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _messages.isEmpty
                            ? const Center(
                                child: Text(
                                  'لا توجد رسائل بعد',
                                  style: TextStyle(fontFamily: 'Amiri', fontSize: 14, color: Colors.grey),
                                ),
                              )
                            : ListView.builder(
                                controller: _scrollCtrl,
                                padding: const EdgeInsets.all(16),
                                itemCount: _messages.length,
                                itemBuilder: (_, i) {
                                  final m = _messages[i];
                                  final text = m['text'] ?? '';
                                  final fromAdmin = m['from'] == 'admin';
                                  final time = m['createdAt'] ?? '';
                                  final date = time is String && time.isNotEmpty
                                      ? DateTime.tryParse(time)
                                      : null;
                                  final formatted = date != null
                                      ? '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}  ${date.day}/${date.month}'
                                      : '';
                                  return Align(
                                    alignment: fromAdmin ? Alignment.centerRight : Alignment.centerLeft,
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(12),
                                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                                      decoration: BoxDecoration(
                                        color: fromAdmin ? const Color(0xFF2D2A3A) : Colors.white,
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(16),
                                          topRight: const Radius.circular(16),
                                          bottomLeft: fromAdmin ? const Radius.circular(16) : const Radius.circular(4),
                                          bottomRight: fromAdmin ? const Radius.circular(4) : const Radius.circular(16),
                                        ),
                                        boxShadow: [
                                          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: fromAdmin ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            fromAdmin ? 'الإدارة' : 'أنت',
                                            style: TextStyle(
                                              fontFamily: 'Amiri',
                                              fontSize: 10,
                                              color: fromAdmin ? Colors.white70 : Colors.grey,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            text,
                                            style: TextStyle(
                                              fontFamily: 'Amiri',
                                              fontSize: 14,
                                              color: fromAdmin ? Colors.white : const Color(0xFF2D2A3A),
                                            ),
                                            textAlign: fromAdmin ? TextAlign.right : TextAlign.left,
                                          ),
                                          if (formatted.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: Text(
                                          formatted,
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: fromAdmin ? Colors.white38 : Colors.grey.shade400,
                                            fontFamily: 'Amiri',
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2)),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _replyCtrl,
                        textAlign: TextAlign.right,
                        maxLines: 3,
                        minLines: 1,
                        style: const TextStyle(fontFamily: 'Amiri', fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'اكتب رسالتك...',
                          hintStyle: const TextStyle(fontFamily: 'Amiri', fontSize: 12, color: Colors.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF0F0F0),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _sendingReply ? null : _sendReply,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D2A3A),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: _sendingReply
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  ),
),
);
  }
}