import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http_parser/http_parser.dart';

class LoginScreen extends StatefulWidget {
  final Function(bool) onLogin;

  const LoginScreen({Key? key, required this.onLogin}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isRegistering = false;
  bool _isLoading = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  // Aggiunta per la gestione dell'immagine
  XFile? _imageFile;
  final ImagePicker _picker = ImagePicker();

  // Funzione per caricare l'immagine
  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = pickedFile;
      });
    }
  }

  // Funzione per inviare l'immagine a Cloudinary
  Future<String?> _uploadImageToCloudinary() async {
  if (_imageFile == null) return null;

  final cloudinaryUrl = "https://api.cloudinary.com/v1_1/dzyi6fulj/image/upload";

  final request = http.MultipartRequest('POST', Uri.parse(cloudinaryUrl));

  request.fields['upload_preset'] = 'preset';

  final mimeType = 'image/jpeg';
  final imageStream = http.ByteStream(_imageFile!.openRead());
  final length = await _imageFile!.length();
  final multipartFile = http.MultipartFile(
    'profileImage', // Modifica qui
    imageStream,
    length,
    filename: _imageFile!.path.split('/').last,
    contentType: MediaType.parse(mimeType),
  );

  request.files.add(multipartFile);

  try {
    final response = await request.send();
    final respStr = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final data = json.decode(respStr);
      return data['secure_url'];
    } else {
      print('Errore nel caricamento dell\'immagine: ${response.statusCode}');
      print('Risposta: $respStr');
      return null;
    }
  } catch (e) {
    print('Errore nell\'upload dell\'immagine: $e');
    return null;
  }
}

Future<void> _register() async {
  setState(() {
    _isLoading = true;
  });

  //String? imageUrl = await _uploadImageToCloudinary(); // Carica immagine su Cloudinary. Inutile ora

  final response = await http.post(
    Uri.parse('https://catconnect-7yg6.onrender.com/api/auth/register'),
    body: json.encode({
      'username': _usernameController.text,
      'email': _emailController.text,
      'password': _passwordController.text,
      //'image_url': imageUrl, // Aggiungi l'URL dell'immagine. Rimosso.
    }),
    headers: {'Content-Type': 'application/json'},
  );

  setState(() {
    _isLoading = false;
  });

  if (response.statusCode == 201) {
    print('Registrazione avvenuta con successo');
    _login(); // Effettua il login automatico
  } else {
    print('Errore nella registrazione');
  }
}

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
    });

    final response = await http.post(
      Uri.parse('https://catconnect-7yg6.onrender.com/api/auth/login'),
      body: json.encode({
        'email': _emailController.text,
        'password': _passwordController.text,
      }),
      headers: {'Content-Type': 'application/json'},
    );

    setState(() {
      _isLoading = false;
    });

    if (response.statusCode == 200) {
      widget.onLogin(true);
    } else {
      print('Errore nel login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFFF3E0),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _isRegistering ? 'Registrati' : 'Accedi',
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              if (_isRegistering)
                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    labelStyle: TextStyle(color: Colors.black),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue),
                    ),
                  ),
                ),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(color: Colors.black),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(color: Colors.black),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue),
                  ),
                ),
                obscureText: true,
              ),
              if (_isRegistering)
                Column(
                  children: [
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _pickImage,
                      child: Text('Carica un\'immagine'),
                    ),
                    if (_imageFile != null)
                      Image.file(
                        File(_imageFile!.path),
                        width: 100,
                        height: 100,
                      ),
                  ],
                ),
              SizedBox(height: 20),
              _isLoading
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _isRegistering ? _register : _login,
                      child: Text(
                        _isRegistering ? 'Registrati' : 'Accedi',
                        style: TextStyle(color: Colors.black),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding:
                            EdgeInsets.symmetric(vertical: 15, horizontal: 40),
                        textStyle: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isRegistering = !_isRegistering;
                  });
                },
                child: Text(
                  _isRegistering
                      ? 'Hai già un account? Accedi'
                      : 'Non hai un account? Registrati',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
