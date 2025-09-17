import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:desktop_window/desktop_window.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DesktopWindow.setMinWindowSize(const Size(400, 600));
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Token Creation App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const AuthScreen(),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  AuthScreenState createState() => AuthScreenState();
}

class AuthScreenState extends State<AuthScreen> {
  final _subscriptionIdController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _expiresInController = TextEditingController();
  String _token = '';
  String _error = '';

  Future<void> _login() async {
    setState(() {
      _token = '';
      _error = '';
    });

    // Trim whitespace from all input fields
    final trimmedSubscriptionId = _subscriptionIdController.text.trim();
    final trimmedUsername = _usernameController.text.trim();
    final trimmedPassword = _passwordController.text.trim();
    final trimmedExpiresIn = _expiresInController.text.trim();

    if (trimmedSubscriptionId.isEmpty || trimmedUsername.isEmpty || trimmedPassword.isEmpty) {
      setState(() {
        _error = 'All fields (Subscription ID, Username, Password) are required';
      });
      return;
    }

    // Validate and parse expires_in
    int? expiresIn;
    if (trimmedExpiresIn.isNotEmpty) {
      expiresIn = int.tryParse(trimmedExpiresIn);
      if (expiresIn == null || expiresIn <= 0) {
        setState(() {
          _error = 'Expires In must be a positive number of seconds';
        });
        return;
      }
    } else {
      expiresIn = 7200; // Default to 2 hours (7200 seconds) if empty
    }

    final username = '$trimmedSubscriptionId;$trimmedUsername';
    final password = trimmedPassword;
    String basicAuth = base64Encode(utf8.encode('$username:$password'));
    final url = Uri.parse('https://acas.acuant.net/oauth/token');
    debugPrint('Requesting token with URL: $url, Raw Username: $username, Raw Password: $password, Expires In: $expiresIn, Basic Auth: Basic $basicAuth');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Basic $basicAuth',
          'User-Agent': 'curl/8.7.1',
          'Accept': '*/*',
          'Expect': '',
          'Host': 'acas.acuant.net',
          'Connection': 'keep-alive',
          'Accept-Encoding': 'gzip, deflate, br',
          'Accept-Language': 'en-US,en;q=0.9',
        },
        body: {
          'grant_type': 'client_credentials',
          'audience': 'https://assureid.acuant.net',
          'scope': 'RESTRICTED ACCESS',
          'expires_in': expiresIn.toString(),
        }.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&'),
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        throw Exception('Connection timed out');
      });
      debugPrint('Response status: ${response.statusCode}, body: ${response.body}, headers: ${response.headers}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['access_token'] ?? data['token'];
        setState(() {
          _token = token;
        });
      } else {
        setState(() {
          _error = 'Error: ${response.statusCode} - ${response.body}';
        });
      }
    } catch (e) {
      debugPrint('Exception: $e');
      setState(() {
        _error = 'Network error: $e';
      });
    }
  }

  void _copyToClipboard() {
    if (_token.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: _token));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token copied to clipboard!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Token Creation App')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _subscriptionIdController,
              decoration: const InputDecoration(labelText: 'Subscription ID'),
            ),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            TextField(
              controller: _expiresInController,
              decoration: const InputDecoration(labelText: 'Expires In (seconds)'),
              keyboardType: TextInputType.number, // Suggests numeric input
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _login, child: const Text('Get Bearer Token')),
            const SizedBox(height: 20),
            if (_token.isNotEmpty)
              Card(
                elevation: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          _token,
                          style: const TextStyle(fontFamily: 'monospace'),
                          maxLines: null, // Allow wrapping
                          overflow: TextOverflow.visible, // Ensure text wraps naturally
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _copyToClipboard,
                        child: const Text('Copy'),
                      ),
                    ],
                  ),
                ),
              ),
            if (_error.isNotEmpty) Text(_error, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _subscriptionIdController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _expiresInController.dispose();
    super.dispose();
  }
}