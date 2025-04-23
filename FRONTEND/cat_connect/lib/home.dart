import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:http/http.dart' as http;

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> posts = [];
  List<String> following = [];
  String? _errorMessage;
  var id = '';

  @override
  void initState() {
    super.initState();
    _identifyUser();
  }

  Future<void> _identifyUser() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');

    if (token == null) {
      setState(() {
        _errorMessage = 'Non trovato il token. Effettua il login.';
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('http://10.1.0.13:5000/api/auth/me'),
        headers: {'Authorization': token},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          id = data['id'];
          following = List<String>.from(data['following'] ?? []);
          loadPosts();
        });
      } else {
        setState(() {
          _errorMessage =
              'Errore nel recupero dei dati utente: ${response.statusCode}, ${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Errore di rete: $e';
      });
    }
  }

  Future<void> loadPosts() async {
    try {
      final response = await http.post(
        Uri.parse('http://10.1.0.13:5000/api/auth/followingPosts'),
        body: json.encode({'id': id}),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          posts = List<Map<String, dynamic>>.from(data).reversed.toList();
        });
      } else {
        setState(() {
          _errorMessage =
              'Errore nel caricamento dei post: ${response.statusCode}, ${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Errore di rete: $e';
      });
    }
  }

  Future<void> toggleLike(String postId) async {
    final response = await http.post(
      Uri.parse('http://10.1.0.13:5000/api/auth/toggleLike/$postId'),
      body: json.encode({'id': id}),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      setState(() {
        final index = posts.indexWhere((post) => post['id'] == postId);
        if (index != -1) {
          List<dynamic> likes = posts[index]['likes'] ?? [];

          if (likes.contains(id)) {
            likes.remove(id); // Dislike
          } else {
            likes.add(id); // Like
          }

          posts[index]['likes'] = likes;
        }
      });
    } else {
      print('Errore nel like: ${response.statusCode}');
    }
  }

Future<void> viewComments(String postId) async {
  try {
    final response = await http.post(
      Uri.parse('http://10.1.0.13:5000/api/auth/getAllComments/$postId'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> comments = json.decode(response.body);

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text("Commenti"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: comments.length,
              itemBuilder: (context, index) {
                final comment = comments[index];
                return ListTile(
                  leading: Icon(Icons.comment),
                  title: Text(comment['text'] ?? 'Nessun testo'),
                  subtitle: Text('Autore: ${comment['author'] ?? 'Sconosciuto'}'),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Chiudi"),
            ),
          ],
        ),
      );
    } else {
      print("Errore nel caricamento dei commenti: ${response.statusCode}");
    }
  } catch (e) {
    print("Errore di rete: $e");
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : posts.isEmpty
              ? Center(
                  child: Text(
                    "Inizia a seguire qualcuno per visualizzarne i post",
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: AnimationLimiter(
                    child: ListView.builder(
                      itemCount: posts.length,
                      itemBuilder: (context, index) {
                        final post = posts[index];
                        final List<dynamic> likes = post['likes'] ?? [];
                        final bool isLiked = likes.contains(id);

                        return AnimationConfiguration.staggeredList(
                          position: index,
                          child: SlideAnimation(
                            verticalOffset: 50.0,
                            child: FadeInAnimation(
                              child: Card(
                                margin: EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                elevation: 8,
                                shadowColor: Colors.black54,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(20)),
                                      child: CachedNetworkImage(
                                        imageUrl: post['imageUrl'],
                                        height: 300,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            Container(
                                          color: Colors.grey[300],
                                          child: Icon(
                                            Icons.image,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        errorWidget: (context, url, error) =>
                                            Icon(Icons.error,
                                                color: Colors.red),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10),
                                      child: Row(
                                        children: [
                                          IconButton(
                                            icon:
                                                Icon(Icons.favorite, size: 30),
                                            color: isLiked
                                                ? Colors.red
                                                : Colors.grey[400],
                                            onPressed: () =>
                                                toggleLike(post['id']),
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.comment,
                                                size: 28,
                                                color: Colors.black54),
                                            onPressed: () =>
                                            viewComments(post['id']),
                                          ),
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
    );
  }
}
