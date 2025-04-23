const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const Post = require('../models/Post');
const Comment = require('../models/Comment')
const authMiddleware = require('../middleware/authMiddleware');
const router = express.Router();

// Registrazione
router.post('/register', async (req, res) => {
  const { username, email, password, profilePictureUrl } = req.body; // Ottieni l'URL dell'immagine

  // Verifica se l'URL dell'immagine è presente
  if (!profilePictureUrl) {
    return res.status(400).json({ message: 'L\'URL dell\'immagine del profilo è obbligatorio' });
  }

  try {
    // Controlla se l'email esiste già
    const existingMail = await User.findOne({ email });
    if (existingMail) {
      return res.status(400).json({ message: 'Email già in uso' });
    }

    const existingUsername = await User.findOne({ username });
    if (existingUsername) {
      return res.status(400).json({ message: 'Username già in uso' });
    }

    const user = new User({
      username,
      email,
      password,
      profilePictureUrl // Salva l'URL dell'immagine
    });

    // Salva l'utente nel database
    await user.save();

    res.status(201).json({ message: 'Utente registrato con successo' });

  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Errore del server' });
  }
});

// Login
router.post('/login', async (req, res) => {
  const { username, password } = req.body;

  try {
    // Trova l'utente con l'email
    const user = await User.findOne({ username });
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
    res.status(200).json({ token });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Errore del server' });
  }
});

// Aggiungo il posto al database
router.post('/addPost', async (req, res) => {
  const { imageUrl, description, author, breed } = req.body;

  try {
    // Crea un nuovo post
    const newPost = await Post.create({ imageUrl, description, author, breed});
    console.log(newPost);

    // Aggiungi l'ID del post appena creato nell'array 'posts' dell'utente
    const user = await User.findById(author);
    console.log(author);
    console.log(user)
    if (user) {
      user.posts.push(newPost._id);  // Aggiungi il nuovo post all'array posts
      await user.save();  // Salva l'utente con l'array aggiornato
    }

    res.status(201).json(newPost);
  } catch (error) {
    res.status(500).json({ error: 'Errore nella creazione del post' });
  }
});

// Recupero tutti i post dell'utente
router.get('/getUserPosts/:userId', async (req, res) => {
  const { userId } = req.params;
  try {
    const posts = await Post.find({ author: userId }).populate('author', 'username');
    res.status(200).json(posts);
  } catch (error) {
    res.status(500).json({ error: 'Errore nel recupero dei post' });
  }
});

router.get('/me', authMiddleware, async (req, res) => {
  try {
    const userId = req.user.id;

    const user = await User.findById(userId).populate('posts', 'imageUrl');
    
    if (!user) {
      return res.status(404).json({ message: 'Utente non trovato' });
    }
    res.json({
      id: userId,
      username: user.username,
      email: user.email,
      profilePictureUrl: user.profilePictureUrl,
      followers: user.followers,
      following: user.following,
      posts: user.posts.map(post => post.imageUrl), 
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});


router.get('/searchUsers', authMiddleware, async (req, res) => {
  try {
    const { query } = req.query;
    const userId = req.user.id;  // ID dell'utente loggato
    console.log(userId);
    if (!query) {
      return res.status(400).json({ message: 'Nessun termine di ricerca fornito' });
    }

    // Ricerca degli utenti, escludendo l'utente autenticato
    const users = await User.find({ 
      username: { $regex: query, $options: 'i' },
      _id: { $ne: userId }  // Esclude l'utente che sta effettuando la ricerca
    }).select('username profilePictureUrl');

    console.log(userId);
    res.json(users);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Errore nel recupero degli utenti' });
  }
});

router.get('/user/:userId', async (req, res) => {
  const { userId } = req.params;  // Ottieni l'userId dalla URL
  
  try {
    // Trova l'utente nel database con il suo userId
    const user = await User.findById(userId).populate('posts', 'imageUrl');

    // Se l'utente non esiste, restituisci un errore 404
    if (!user) {
      return res.status(404).json({ message: 'Utente non trovato' });
    }

    // Se l'utente esiste, restituisci i dettagli dell'utente
    res.status(200).json({
      username: user.username,
      email: user.email,
      profilePictureUrl: user.profilePictureUrl,
      followers: user.followers,
      following: user.following,
      posts: user.posts.map(post => post.imageUrl), 
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Errore nel recupero dell\'utente' });
  }
});

router.post('/follow', authMiddleware, async (req, res) => {
  const myId = req.user.id;
  const otherId = req.body.userId;

  console.log(myId, otherId);

  if (!myId || !otherId) {
    return res.status(400).json({ error: "Entrambi gli ID sono richiesti" });
  }

  try {
    const myUser = await User.findById(myId);
    const otherUser = await User.findById(otherId);

    if (!myUser || !otherUser) {
      return res.status(404).json({ error: "Utente non trovato" });
    }

    if (!myUser.following.includes(otherId)) {
      myUser.following.push(otherId);
      await myUser.save();
    }

    if (!otherUser.followers.includes(myId)) {
      otherUser.followers.push(myId);
      await otherUser.save();
    }

    res.status(200).json({ message: "Seguito con successo", myUser, otherUser });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: "Errore nel follow" });
  }
});

router.post('/unfollow', authMiddleware, async (req, res) => {
  const myId = req.user.id;
  const otherId = req.body.userId;

  console.log(myId, otherId);

  if (!myId || !otherId) {
    return res.status(400).json({ error: "Entrambi gli ID sono richiesti" });
  }

  try {
    const myUser = await User.findById(myId);
    const otherUser = await User.findById(otherId);

    if (!myUser || !otherUser) {
      return res.status(404).json({ error: "Utente non trovato" });
    }

    // Rimuovi l'ID di otherId dalla lista 'following' di myUser
    myUser.following = myUser.following.filter(id => id.toString() !== otherId);
    await myUser.save();

    // Rimuovi l'ID di myId dalla lista 'followers' di otherUser
    otherUser.followers = otherUser.followers.filter(id => id.toString() !== myId);
    await otherUser.save();

    res.status(200).json({ message: "Unfollow effettuato con successo", myUser, otherUser });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: "Errore nell'unfollow" });
  }
});

router.post('/followingPosts', async (req, res) => {
  try {
    const userId = req.body.id;

    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ message: "Utente non trovato" });
    }

    const posts = await Post.find({ author: { $in: user.following } });

    // Filtra i post a cui l'utente NON ha messo like
    const filteredPosts = posts.filter(post => !post.likes.includes(userId));

    // Include ID e URL immagine
    const formattedPosts = filteredPosts.map(post => ({
      id: post._id,
      imageUrl: post.imageUrl
    }));

    res.status(200).json(formattedPosts);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: "Errore nel recupero dei post" });
  }
});



router.post('/toggleLike/:postId', async (req, res) => {
  const userId = req.body.id;
  const { postId } = req.params;

  console.log(userId, postId);

  try {
    const post = await Post.findById(postId);
    if (!post) return res.status(404).json({ message: 'Post non trovato' });

    const alreadyLiked = post.likes.includes(userId);

    if (alreadyLiked) {
      console.log(`Aggiunto: ${post.likes}`);
      post.likes = post.likes.filter(id => id.toString() !== userId);
    } else {
      post.likes.push(userId);
      console.log(`Rimosso: ${post.likes}`);
    }

    await post.save();
    res.status(200).json({ liked: !alreadyLiked, likesCount: post.likes.length });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Errore nel mettere/togliere il like' });
  }
});

router.post('/getAllComments/:postId', async (req, res) => {
  const { postId } = req.params;

  try {
    const post = await Post.findById(postId);
    if(!post) return res.status(404).json({message: 'Post non trovato'});

    res.status(200).json(post.comments);
  }catch(error){
    res.status(500);
  }
});


module.exports = router;