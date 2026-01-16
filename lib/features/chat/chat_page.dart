import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _conversationContext = [];
  bool _isTyping = false;

  final String _workerUrl = 'https://skimatt.rahmatyoung10.workers.dev/';

  @override
  void initState() {
    super.initState();
    _loadInitialContext();
  }

  // --- 1. MEMORY & SYSTEM PROMPT INITIALIZATION ---
  Future<void> _loadInitialContext() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // Load Memory & History (Termasuk indikasi scan struk)
    final memories = await Supabase.instance.client
        .from('user_memories')
        .select('memory_content')
        .eq('user_id', user.id);

    String memoryText = memories.isNotEmpty
        ? "\nFakta user: " + memories.map((m) => m['memory_content']).join(". ")
        : "";

    setState(() {
      _conversationContext.add({
        "role": "system",
        "content":
            """Nama kamu adalah **skie**. Kamu asisten pribadi yang ramah, hangat, dan sangat suportif.
Kepribadian: Teman dekat yang cerdas, empati tinggi, santai, dan tidak kaku.
Konteks Data: Kamu punya akses ke riwayat chat, preferensi, dan data scan struk user di database. Gunakan informasi ini jika user bertanya tentang pengeluaran mereka.

$memoryText

ATURAN OUTPUT:
1. Singkat, padat, hangat. Jangan bertele-tele agar respon cepat.
2. WAJIB tutup setiap jawaban dengan pertanyaan lanjutan yang relevan dan personal.
3. Jika ada transaksi (beli/bayar/terima uang), akhiri HANYA dengan: [TRANSACTION:{"amount": 0, "category": "", "description": ""}]
4. Gunakan sapaan hangat. Kamu adalah teman curhat sekaligus akuntan pintar.
""",
      });
    });
  }

  // --- 2. LOGIKA DATABASE (TIDAK BERUBAH) ---
  Future<void> _processTransaction(String aiResponse) async {
    try {
      final regExp = RegExp(r'\[TRANSACTION:(.*?)\]');
      final match = regExp.firstMatch(aiResponse);
      if (match == null) return;
      final data = jsonDecode(match.group(1)!);
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client.from('transactions').insert({
        'user_id': user.id,
        'amount': double.tryParse(data['amount'].toString()) ?? 0,
        'category': data['category'] ?? 'Lainnya',
        'description': data['description'] ?? 'Chat AI',
      });
      _showSuccessSnack(data['category'], data['amount']);
    } catch (e) {
      debugPrint('Error DB: $e');
    }
  }

  void _showSuccessSnack(String cat, dynamic amt) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: Text("✅ skie catat $cat: Rp $amt. Sudah masuk laporan ya!"),
      ),
    );
  }

  // --- 3. BACKGROUND MEMORY ---
  Future<void> _saveToLongTermMemory(String text) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final response = await http.post(
        Uri.parse(_workerUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "model": "google/gemini-2.0-flash-001",
          "messages": [
            {
              "role": "user",
              "content":
                  "Simpulkan fakta dari ini dalam 1 kalimat (jika tak ada balas NONE): $text",
            },
          ],
        }),
      );
      final data = jsonDecode(response.body);
      String fact = data['choices'][0]['message']['content'];
      if (fact.toUpperCase() != "NONE") {
        await Supabase.instance.client.from('user_memories').insert({
          'user_id': user.id,
          'memory_content': fact,
        });
      }
    } catch (_) {}
  }

  // --- 4. ENGINE CHAT CEPAT ---
  Future<void> _sendMessage() async {
    final prompt = _messageController.text.trim();
    if (prompt.isEmpty) return;

    setState(() {
      _conversationContext.add({"role": "user", "content": prompt});
      _isTyping = true;
    });
    _messageController.clear();
    _scrollToBottom();

    _saveToLongTermMemory(prompt);

    try {
      final response = await http.post(
        Uri.parse(_workerUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "model": "google/gemini-2.0-flash-001",
          "messages": _conversationContext,
          "format": "markdown",
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String raw =
            data['choices']?[0]['message']?['content'] ??
            "Duh, skie bingung bentar. Coba lagi?";
        await _processTransaction(raw);
        String clean = raw
            .replaceAll(RegExp(r'\[TRANSACTION:.*?\]'), '')
            .trim();

        setState(() {
          _conversationContext.add({"role": "assistant", "content": clean});
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      if (mounted) {
        setState(() => _isTyping = false);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: 250.ms,
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: _conversationContext.length <= 1
                ? _buildWelcomeHero()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(20),
                    itemCount: _conversationContext
                        .where((m) => m['role'] != 'system')
                        .length,
                    itemBuilder: (context, index) {
                      final msgs = _conversationContext
                          .where((m) => m['role'] != 'system')
                          .toList();
                      return _buildChatBubble(
                        msgs[index]['content']!,
                        msgs[index]['role'] == 'user',
                      );
                    },
                  ),
          ),
          if (_isTyping) _buildPulseIndicator(),
          _buildInputBar(),
        ],
      ),
    );
  }

  // --- UI COMPONENTS ---
  Widget _buildWelcomeHero() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.indigo.withOpacity(0.1),
                  blurRadius: 20,
                ),
              ],
            ),
            child: const Icon(
              LucideIcons.sparkles,
              color: Colors.indigoAccent,
              size: 40,
            ),
          ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds),
          const SizedBox(height: 20),
          const Text(
            "Hai! Aku skie",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Ada yang bisa skie bantu catat atau temani hari ini?",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ).animate().fadeIn().slideY(begin: 0.2),
    );
  }

  Widget _buildPulseIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 25, bottom: 15),
      child: Row(
        children: [
          Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.indigoAccent,
                  shape: BoxShape.circle,
                ),
              )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(duration: 600.ms, begin: const Offset(0.5, 0.5)),
          const SizedBox(width: 10),
          const Text(
            "skie lagi mikir...",
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF6366F1) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 0),
            bottomRight: Radius.circular(isUser ? 0 : 20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: MarkdownBody(
          data: text,
          styleSheet: MarkdownStyleSheet(
            p: TextStyle(
              color: isUser ? Colors.white : Colors.black87,
              fontSize: 15,
              height: 1.5,
            ),
            strong: TextStyle(
              fontWeight: FontWeight.bold,
              color: isUser ? Colors.white : Colors.indigoAccent,
            ),
          ),
        ),
      ).animate().fadeIn(duration: 300.ms).slideX(begin: isUser ? 0.1 : -0.1),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      title: const Text(
        "skie",
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      leading: IconButton(
        icon: const Icon(LucideIcons.chevronLeft, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 15,
        bottom: MediaQuery.of(context).padding.bottom + 15,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7FE),
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: "Sapa skie...",
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            onPressed: _sendMessage,
            icon: const Icon(LucideIcons.send, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
            ),
          ),
        ],
      ),
    );
  }
}
