import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentAIChatPage extends StatefulWidget {
  const StudentAIChatPage({super.key});

  @override
  State<StudentAIChatPage> createState() => _StudentAIChatPageState();
}

class _StudentAIChatPageState extends State<StudentAIChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late final String _apiKey;
  final String _openAiUrl = 'https://api.openai.com/v1/chat/completions';

  @override
  void initState() {
    super.initState();
    _apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    // Initial Greeting
    _messages.add({
      'role': 'ai',
      'text': 'Hello! I am your AI Rental Robot. 🤖 I can help you find the perfect house based on your preferences. What are you looking for?'
    });
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

  Future<Map<String, dynamic>> _getPreferences() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return {};
    final doc = await _firestore.collection('students').doc(uid).get();
    if (!doc.exists) return {};
    return Map<String, dynamic>.from(doc.data()?['preferences'] ?? {});
  }

  Future<List<Map<String, dynamic>>> _getHouses() async {
    try {
      final snap = await _firestore
    .collection('houses')
    .where('availabilityStatus', isEqualTo: 'available')
    .limit(10)
    .get();
      return snap.docs.map((d) {
        final h = d.data();
        // SAFE CHECK: Use ?? '' to avoid "field does not exist" errors
        return {
          'title': h.containsKey('title') ? h['title'] : 'Unnamed House',
          'location': h.containsKey('location') ? h['location'] : (h.containsKey('address') ? h['address'] : 'No Location Provided'),
          'price': h.containsKey('price') ? h['price'] : 'Contact for price',
          'houseType': h.containsKey('houseType') ? h['houseType'] : 'Unknown Type',
          'gender': h.containsKey('genderPreference') ? h['genderPreference'] : 'Any',
        };
      }).toList();
    } catch (e) {
      debugPrint("Error fetching houses: $e");
      return [];
    }
  }

  Future<void> _sendMessage() async {
    final userText = _controller.text.trim();
    if (userText.isEmpty || _isLoading) return;

    setState(() {
      _messages.add({'role': 'user', 'text': userText});
      _controller.clear();
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final prefs = await _getPreferences();
      final houses = await _getHouses();

      final systemPrompt = '''
You are a helpful Robot AI Rental Assistant.
Context:
- Student Preferences: ${jsonEncode(prefs)}
- Available Houses: ${jsonEncode(houses)}

Rules:
1. Be friendly and helpful.
2. If the user asks for recommendations, prioritize houses that match their budget and houseType.
3. Keep responses concise.
''';

      final response = await http.post(
        Uri.parse(_openAiUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "model": "gpt-3.5-turbo",
          "messages": [
            {"role": "system", "content": systemPrompt},
            ..._messages.map((m) => {
              "role": m['role'] == 'user' ? "user" : "assistant",
              "content": m['text']
            }).toList(),
          ],
          "temperature": 0.7
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data['choices'][0]['message']['content'];
        setState(() {
          _messages.add({'role': 'ai', 'text': reply.trim()});
        });
      } else {
        setState(() {
          _messages.add({'role': 'ai', 'text': 'I am having trouble connecting to my brain right now. Please try again later.'});
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({'role': 'ai', 'text': 'Error: $e'});
      });
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('AI Rental Robot'),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _messages.clear()),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return _buildChatBubble(msg['text'] ?? '', isUser);
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(backgroundColor: Colors.transparent),
            ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildChatBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF1E88E5) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 0),
            bottomRight: Radius.circular(isUser ? 0 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black87,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Ask the Robot...',
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send_rounded, color: Color(0xFF1E88E5)),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}