import 'dart:async';

import 'package:flutter/material.dart';

import 'package:rumo_app/core/services/api_service.dart';
import 'package:rumo_app/core/services/auth_service.dart';

/// Chat entre passageiro e motorista durante a corrida.
class RideChatScreen extends StatefulWidget {
  final String rideId;

  const RideChatScreen({super.key, required this.rideId});

  @override
  State<RideChatScreen> createState() => _RideChatScreenState();
}

class _RideChatScreenState extends State<RideChatScreen> {
  final _api = ApiService();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  String? _error;
  Timer? _pollTimer;

  String get _currentUserId => AuthService().currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _loadMessages(silent: true));
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final list = await _api.getRideMessages(widget.rideId);
      if (!mounted) return;
      setState(() {
        _messages = list;
        _loading = false;
        _error = null;
      });
      if (list.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = !silent ? e.toString().replaceFirst('Exception: ', '') : null;
          _loading = false;
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    try {
      await _api.sendRideMessage(widget.rideId, text);
      await _loadMessages(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Chat com motorista'),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading && _messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                              const SizedBox(height: 12),
                              Text(_error!, style: TextStyle(color: Colors.red[300]), textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              TextButton.icon(
                                onPressed: () => _loadMessages(),
                                icon: const Icon(Icons.refresh),
                                label: const Text('Tentar novamente'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _messages.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[500]),
                                const SizedBox(height: 16),
                                Text(
                                  'Nenhuma mensagem ainda',
                                  style: TextStyle(color: Colors.grey[400], fontSize: 16),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Envie uma mensagem para o motorista',
                                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () => _loadMessages(),
                            color: const Color(0xFF00D95F),
                            child: ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(16),
                              itemCount: _messages.length,
                              itemBuilder: (context, i) {
                                final m = _messages[i];
                                final isMe = (m['userId'] ?? '') == _currentUserId;
                                final createdAt = m['createdAt'];
                                String timeStr = '—';
                                if (createdAt != null) {
                                  try {
                                    final dt = createdAt is DateTime ? createdAt : DateTime.tryParse(createdAt.toString());
                                    if (dt != null) {
                                      timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                                    }
                                  } catch (_) {}
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                                    children: [
                                      Flexible(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: isMe
                                                ? const Color(0xFF00D95F).withValues(alpha: 0.3)
                                                : const Color(0xFF2C2C2C),
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              if (!isMe)
                                                Padding(
                                                  padding: const EdgeInsets.only(bottom: 4),
                                                  child: Text(
                                                    (m['userName'] ?? '—') as String,
                                                    style: TextStyle(
                                                      color: Colors.grey[400],
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              Text(
                                                (m['text'] ?? '') as String,
                                                style: const TextStyle(color: Colors.white, fontSize: 15),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                timeStr,
                                                style: TextStyle(color: Colors.grey[500], fontSize: 11),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: 'Digite uma mensagem...',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        filled: true,
                        fillColor: const Color(0xFF2C2C2C),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      style: const TextStyle(color: Colors.white),
                      maxLines: 3,
                      minLines: 1,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton.filled(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF00D95F),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
