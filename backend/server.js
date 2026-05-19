const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
require('dotenv').config();

const app = express();
app.use(express.json());
app.use(cors());

const JWT_SECRET = process.env.JWT_SECRET || 'super_secret_final_year_project_key';

// User Schema
const UserSchema = new mongoose.Schema({
  name: String,
  email: { type: String, unique: true, required: true },
  password: { type: String, required: true }
});
const User = mongoose.model('User', UserSchema);

// Auth Routes
app.post('/api/auth/signup', async (req, res) => {
  console.log(`[${new Date().toISOString()}] Incoming Signup Request from: ${req.ip} - Email: ${req.body.email}`);
  try {
    const { name, email, password } = req.body;
    const hashedPassword = await bcrypt.hash(password, 12);
    const user = new User({ name, email, password: hashedPassword });
    await user.save();
    res.status(201).json({ message: "User created" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/auth/login', async (req, res) => {
  console.log(`[${new Date().toISOString()}] Incoming Login Request from: ${req.ip} - Email: ${req.body.email}`);
  try {
    const { email, password } = req.body;
    const user = await User.findOne({ email });
    if (!user) return res.status(404).json({ message: "User not found" });

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) return res.status(400).json({ message: "Invalid credentials" });

    const token = jwt.sign({ userId: user._id }, JWT_SECRET, { expiresIn: '7d' });
    res.json({ token, userId: user._id, name: user.name, email: user.email });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/auth/me', auth, async (req, res) => {
  try {
    const user = await User.findById(req.userId).select('-password');
    if (!user) return res.status(404).json({ message: "User not found" });
    res.json(user);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Connect to MongoDB Atlas
const MONGO_URI = process.env.MONGO_URI;

mongoose.connect(MONGO_URI)
  .then(() => console.log('✅ Connected to MongoDB Atlas'))
  .catch((err) => console.error('❌ MongoDB Connection Error:', err));

// Auth Middleware
function auth(req, res, next) {
  const token = req.header('Authorization')?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ message: "No token, authorization denied" });

  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    req.userId = decoded.userId;
    next();
  } catch (err) {
    res.status(401).json({ message: "Token is not valid" });
  }
}

// Schema for Saved Zones
const ZoneSchema = new mongoose.Schema({
  id: String,
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  name: String,
  type: String,
  points: [
    {
      lat: Number,
      lng: Number
    }
  ],
  radius: Number,
  createdAt: { type: Date, default: Date.now }
});

const Zone = mongoose.model('Zone', ZoneSchema);

// Endpoint to Sync/Save Zone
app.post('/api/zones/sync', auth, async (req, res) => {
  try {
    const zoneData = req.body;
    zoneData.userId = req.userId; // Ensure userId is set from token

    const updatedZone = await Zone.findOneAndUpdate(
      { id: zoneData.id, userId: req.userId }, // Ensure user owns the zone they are updating
      zoneData,
      { upsert: true, new: true }
    );
    res.status(200).json({ success: true, data: updatedZone });
  } catch (err) {
    console.error('Server sync error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// Endpoint to fetch all zones for the logged-in user
app.get('/api/zones', auth, async (req, res) => {
  try {
    const zones = await Zone.find({ userId: req.userId });
    res.status(200).json({ success: true, data: zones });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// Endpoint to delete a zone
app.delete('/api/zones/:id', auth, async (req, res) => {
  try {
    const { id } = req.params;
    const result = await Zone.findOneAndDelete({ id: id, userId: req.userId });
    if (!result) return res.status(404).json({ success: false, message: "Zone not found or unauthorized" });
    res.status(200).json({ success: true, message: "Zone deleted" });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

const PORT = process.env.PORT || 3000;
// Explicitly bind to 0.0.0.0 to accept connections from other devices on the network
app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Geofence Backend running on http://0.0.0.0:${PORT}`);
  console.log(`   (Accessible locally via http://localhost:${PORT})`);
});
