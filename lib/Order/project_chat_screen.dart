import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_application_1/Services/api_client.dart';
import 'package:flutter_application_1/Services/socket_client.dart';
import 'package:flutter_application_1/Order/order_models.dart';
import 'package:flutter_application_1/Order/project_unread_store.dart';

/// محادثة الزبون مع صاحب المشروع
class ProjectChatScreen extends StatefulWidget {
  final String projectId;
  final String customerId;
  final String ownerName;
  final bool locked;

  const ProjectChatScreen({
    super.key,
    required this.projectId,
    required this.customerId,
    required this.ownerName,
    required this.locked,
  });

  @override
  State<ProjectChatScreen> createState() => _ProjectChatScreenState();
}

class _ProjectChatScreenState extends State<ProjectChatScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    SocketClient.join('user_${widget.customerId}');
    SocketClient.on('project:message', _onMessage);
    _load();
  }

  @override
  void dispose() {
    SocketClient.off('project:message', _onMessage);
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onMessage(dynamic data) {
    final msg = (data as Map).cast<String, dynamic>();
    if (msg['projectId'] != widget.projectId) return;
    if (mounted) {
      setState(() => _messages.add(msg));
      _scrollToBottom();
    }
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.getList('/api/projects/${widget.projectId}/messages');
      ProjectUnreadStore.instance.markRead(widget.projectId);
      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending || widget.locked) return;
    setState(() => _sending = true);
    try {
      final msg = await ApiClient.post('/api/projects/${widget.projectId}/messages', {
        'text': text,
      });
      if (mounted) {
        _ctrl.clear();
        setState(() {
          _messages.add(Map<String, dynamic>.from(msg));
          _sending = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _fmtTime(dynamic ts) {
    try {
      final dt = DateTime.parse(ts.toString());
      return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        backgroundColor: kBgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: kPrimaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              widget.ownerName.isEmpty ? 'صاحب المشروع' : widget.ownerName,
              style: const TextStyle(fontFamily: 'Amiri', color: kTextColor, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.locked ? 'المحادثة مغلقة' : 'متصل الآن',
              style: TextStyle(fontFamily: 'Amiri', color: widget.locked ? kTextGrey : kPrimaryColor, fontSize: 11),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
                : _messages.isEmpty
                    ? Center(
                        child: Text(
                          widget.locked ? 'لا توجد رسائل' : 'ابدأ المحادثة مع صاحب المشروع',
                          style: const TextStyle(fontFamily: 'Amiri', color: kTextGrey, fontSize: 14),
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.all(14),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) => _bubble(_messages[i]),
                      ),
          ),
          if (widget.locked)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'تم إغلاق المحادثة بعد اكتمال الطلبية. يمكنك قراءة الرسائل السابقة.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Amiri', color: kTextGrey, fontSize: 12),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: TextField(
                        controller: _ctrl,
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                        maxLines: 4,
                        minLines: 1,
                        style: const TextStyle(fontFamily: 'Amiri', color: kTextColor, fontSize: 14),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'اكتب رسالة...',
                          hintStyle: TextStyle(fontFamily: 'Amiri', color: Colors.black38, fontSize: 13),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sending ? null : _send,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _ctrl.text.trim().isEmpty && !_sending
                            ? kPrimaryColor.withOpacity(0.35)
                            : kPrimaryColor,
                      ),
                      child: _sending
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _bubble(Map<String, dynamic> m) {
    final isMine = m['fromRole'] != 'owner';
    final time = _fmtTime(m['createdAt']);
    return Align(
      alignment: isMine ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(top: 6, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: isMine ? kPrimaryColor : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 4 : 18),
            bottomRight: Radius.circular(isMine ? 18 : 4),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              m['text'] ?? '',
              style: TextStyle(fontFamily: 'Amiri', color: isMine ? Colors.white : kTextColor, fontSize: 14),
            ),
            if (time.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  time,
                  style: TextStyle(fontFamily: 'Amiri', color: isMine ? Colors.white70 : kTextGrey, fontSize: 10),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
