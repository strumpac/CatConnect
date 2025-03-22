const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const cloudinary = require('cloudinary').v2;
const User = require('../models/User');
const router = express.Router();
const multer = require('multer');

// Configurazione di Cloudinary
cloudinary.config({
  cloud_name: 'dzyi6fulj',
  api_key: '786993869258579',
  api_secret: 'YY_QEG_u3Mjsoac4QQuVIot5PJw'
});

// Configurazione di Multer per il caricamento dei file
const storage = multer.memoryStorage(); // Usa la memoria per caricare i file temporaneamente
const upload = multer({ storage: storage });

// Registrazione
router.post('/register', upload.single('profileImage'), async (req, res) => {
  const { username, email, password } = req.body;
  const imageFile = req.file;

  try {
    // Controlla se l'email esiste già
    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({ message: 'Email già in uso' });
    }

    // Carica l'immagine su Cloudinary se presente
    let profileImageUrl = null;
    if (imageFile) {
      const result = await cloudinary.uploader.upload(imageFile.buffer, {
        folder: 'profile_images',
        resource_type: 'auto'
      });
      profileImageUrl = result.secure_url;  // Ottieni l'URL dell'immagine caricata
    }

    // Crea un nuovo utente
    const user = new User({
      username,
      email,
      password,
      profileImageUrl
    });

    // Cripta la password
    const salt = await bcrypt.genSalt(10);
    user.password = await bcrypt.hash(password, salt);

    // Salva l'utente nel database
    await user.save();

    // Invia una risposta di successo
    res.status(201).json({ message: 'Utente registrato con successo' });

  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Errore del server' });
  }
});

// Login
router.post('/login', async (req, res) => {
  const { email, password } = req.body;

  try {
    // Trova l'utente con l'email
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(400).json({ message: 'Credenziali errate' });
    }

    // Confronta la password
    const isMatch = await user.comparePassword(password);
    if (!isMatch) {
      return res.status(400).json({ message: 'Credenziali errate' });
    }

    // Crea un JWT
    const token = jwt.sign({ userId: user._id }, 'secretKey', { expiresIn: '1h' });

    // Invia il token come risposta
    res.status(200).json({ token, profileImageUrl: user.profileImageUrl });  // Aggiungi l'URL dell'immagine nel response
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Errore del server' });
  }
});

module.exports = router;
