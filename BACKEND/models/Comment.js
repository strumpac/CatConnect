const mongoose = require('mongoose');

// Definisco lo schema per il commento
const commentSchema = new mongoose.Schema({
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    text: { type: String, required: true },
    createdAt: { type: Date, default: Date.now }, 
});


const Post = mongoose.model('Comment', commentSchema);

module.exports = Post;
