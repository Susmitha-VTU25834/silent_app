const express = require('express');
const admin = require('firebase-admin');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const path = require('path');
require('dotenv').config();

const nodemailer = require('nodemailer');

let transporter = null;
if (process.env.EMAIL_USER && process.env.EMAIL_PASS) {
  transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: {
      user: process.env.EMAIL_USER,
      pass: process.env.EMAIL_PASS
    }
  });
  console.log('✅ Mail transporter configured successfully.');
} else {
  console.warn('⚠️ WARNING: EMAIL_USER and EMAIL_PASS environment variables are not set. Verification emails will not be sent.');
}

async function sendOtpEmail(email, otp) {
  if (!transporter) {
    console.warn(`⚠️ [SMTP] Cannot send email to ${email}. Transporter not configured.`);
    return false;
  }

  const mailOptions = {
    from: `"Smart Silent Map" <${process.env.EMAIL_USER}>`,
    to: email,
    subject: "Smart Silent Map - Your 4-Digit Verification Code",
    html: `
      <div style="font-family: sans-serif; max-width: 500px; margin: 0 auto; padding: 20px; border: 1px solid #e0e0e0; border-radius: 12px; background-color: #fcfcfc;">
        <h2 style="color: #4f46e5; margin-bottom: 20px; text-align: center;">Smart Silent Map</h2>
        <p style="font-size: 16px; color: #374151;">Hello,</p>
        <p style="font-size: 16px; color: #374151; line-height: 1.5;">To complete your sign up, please enter the following 4-digit verification code:</p>
        <div style="text-align: center; margin: 30px 0;">
          <span style="font-size: 32px; font-weight: bold; color: #4f46e5; letter-spacing: 5px; background: #eeebff; padding: 10px 24px; border-radius: 8px; border: 1px dashed #4f46e5;">${otp}</span>
        </div>
        <p style="font-size: 14px; color: #6b7280; text-align: center; margin-top: 30px;">This code is valid for 5 minutes. If you did not request this code, please ignore this email.</p>
      </div>
    `
  };

  try {
    await transporter.sendMail(mailOptions);
    console.log(`[SMTP] Verification email sent to: ${email}`);
    return true;
  } catch (error) {
    console.error(`[SMTP] Error sending email to ${email}:`, error);
    return false;
  }
}

const { OAuth2Client } = require('google-auth-library');
const googleClient = new OAuth2Client();

const app = express();
app.use(express.json());
app.use(cors());

const JWT_SECRET = process.env.JWT_SECRET || 'super_secret_final_year_project_key';

// Initialize Firebase Admin SDK
let db;
try {
  if (process.env.FIREBASE_SERVICE_ACCOUNT_KEY) {
    const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_KEY);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });
    console.log('✅ Firebase initialized via service account key JSON env variable');
  } else if (process.env.FIREBASE_SERVICE_ACCOUNT_KEY_PATH) {
    const keyPath = process.env.FIREBASE_SERVICE_ACCOUNT_KEY_PATH;
    const resolvedPath = path.isAbsolute(keyPath) ? keyPath : path.resolve(__dirname, keyPath);
    admin.initializeApp({
      credential: admin.credential.cert(resolvedPath)
    });
    console.log(`✅ Firebase initialized via service account key file: ${resolvedPath}`);
  } else {
    // Attempt default initialization (works in GCP, Firebase Functions, or if GOOGLE_APPLICATION_CREDENTIALS is set)
    admin.initializeApp();
    console.log('✅ Firebase initialized via default credentials');
  }
  db = admin.firestore();
} catch (err) {
  console.error('❌ Firebase Admin Initialization Error:', err);
  console.log('⚠️ Server running, but Firebase database features will fail until valid credentials are provided.');
}

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

// Auth Routes

// 0. Send OTP Route
app.post('/api/auth/send-otp', async (req, res) => {
  console.log(`[${new Date().toISOString()}] Incoming OTP Request from: ${req.ip} - Email: ${req.body.email}`);
  if (!db) {
    return res.status(500).json({ error: "Firebase database not initialized" });
  }

  try {
    const { email } = req.body;
    if (!email) {
      return res.status(400).json({ error: "Email is required" });
    }

    // Generate random 4-digit code
    const otp = Math.floor(1000 + Math.random() * 9000).toString();
    const expiresAt = Date.now() + 5 * 60 * 1000; // 5 minutes expiry

    // Save to Firestore
    await db.collection('otps').doc(email).set({
      otp,
      expiresAt
    });

    console.log(`[OTP] Verification code for ${email} is: ${otp}`);

    let emailSent = false;
    if (transporter) {
      emailSent = await sendOtpEmail(email, otp);
    }

    res.status(200).json({ 
      success: true, 
      message: emailSent ? "Verification code sent to your email" : "OTP generated successfully", 
      otp: emailSent ? null : otp
    });
  } catch (err) {
    console.error("Send OTP error:", err);
    res.status(500).json({ error: err.message });
  }
});

// 1. Signup Route (with OTP)
app.post('/api/auth/signup', async (req, res) => {
  console.log(`[${new Date().toISOString()}] Incoming Signup Request from: ${req.ip} - Email: ${req.body.email}`);
  if (!db) {
    return res.status(500).json({ error: "Firebase database not initialized" });
  }

  try {
    const { name, email, password, otp } = req.body;
    if (!name || !email || !password || !otp) {
      return res.status(400).json({ error: "All fields including OTP are required" });
    }

    // Verify OTP first
    const otpDoc = await db.collection('otps').doc(email).get();
    if (!otpDoc.exists) {
      return res.status(400).json({ error: "Verification code has expired or not found. Please request a new one." });
    }

    const otpData = otpDoc.data();
    if (otpData.expiresAt < Date.now()) {
      await db.collection('otps').doc(email).delete();
      return res.status(400).json({ error: "Verification code has expired. Please request a new one." });
    }

    if (otpData.otp !== otp) {
      return res.status(400).json({ error: "Invalid verification code. Please check and try again." });
    }

    // Check if user already exists
    const usersRef = db.collection('users');
    const snapshot = await usersRef.where('email', '==', email).limit(1).get();
    if (!snapshot.empty) {
      return res.status(400).json({ error: "User already exists with this email" });
    }

    // Delete OTP document since it's verified
    await db.collection('otps').doc(email).delete();

    // Hash Password and Save
    const hashedPassword = await bcrypt.hash(password, 12);
    const newUserRef = usersRef.doc();
    
    await newUserRef.set({
      name,
      email,
      password: hashedPassword,
      createdAt: new Date().toISOString()
    });

    res.status(201).json({ message: "User created successfully" });
  } catch (err) {
    console.error("Signup error:", err);
    res.status(500).json({ error: err.message });
  }
});

// 1b. Google Auth Route
app.post('/api/auth/google', async (req, res) => {
  console.log(`[${new Date().toISOString()}] Incoming Google Login Request from: ${req.ip}`);
  if (!db) {
    return res.status(500).json({ error: "Firebase database not initialized" });
  }

  try {
    const { idToken } = req.body;
    if (!idToken) {
      return res.status(400).json({ error: "Google ID Token is required" });
    }

    // Verify token using google-auth-library
    let payload;
    try {
      const ticket = await googleClient.verifyIdToken({
        idToken: idToken,
        audience: process.env.GOOGLE_CLIENT_ID ? process.env.GOOGLE_CLIENT_ID.split(',') : undefined
      });
      payload = ticket.getPayload();
    } catch (verifyErr) {
      console.error("Token verification failed:", verifyErr);
      return res.status(400).json({ error: "Invalid Google ID Token: " + verifyErr.message });
    }

    const { sub: googleId, email, name } = payload;
    if (!email) {
      return res.status(400).json({ error: "Email not provided by Google account" });
    }

    const usersRef = db.collection('users');
    let snapshot = await usersRef.where('email', '==', email).limit(1).get();
    let userId;
    let userName = name || email.split('@')[0];

    if (snapshot.empty) {
      // User doesn't exist, sign them up with Google
      const newUserRef = usersRef.doc();
      userId = newUserRef.id;

      // Hash a placeholder password since Google account won't use it directly
      const randomPassword = Math.random().toString(36).substring(2, 15);
      const hashedPassword = await bcrypt.hash(randomPassword, 12);

      await newUserRef.set({
        name: userName,
        email: email,
        googleId: googleId,
        password: hashedPassword,
        createdAt: new Date().toISOString()
      });
      console.log(`[Google Auth] Created new user: ${email}`);
    } else {
      // User exists, log them in
      const userDoc = snapshot.docs[0];
      userId = userDoc.id;
      const user = userDoc.data();
      userName = user.name || userName;

      // Update user with googleId if they signed up manually before but are now using Google
      if (!user.googleId) {
        await usersRef.doc(userId).update({ googleId });
        console.log(`[Google Auth] Linked Google ID to existing user: ${email}`);
      } else {
        console.log(`[Google Auth] Logged in existing user: ${email}`);
      }
    }

    const token = jwt.sign({ userId }, JWT_SECRET, { expiresIn: '7d' });
    res.json({ token, userId, name: userName, email });
  } catch (err) {
    console.error("Google Auth error:", err);
    res.status(500).json({ error: err.message });
  }
});

// 2. Login Route
app.post('/api/auth/login', async (req, res) => {
  console.log(`[${new Date().toISOString()}] Incoming Login Request from: ${req.ip} - Email: ${req.body.email}`);
  if (!db) {
    return res.status(500).json({ error: "Firebase database not initialized" });
  }

  try {
    const { email, password } = req.body;
    
    const usersRef = db.collection('users');
    const snapshot = await usersRef.where('email', '==', email).limit(1).get();
    
    if (snapshot.empty) {
      return res.status(404).json({ message: "User not found" });
    }

    const userDoc = snapshot.docs[0];
    const user = userDoc.data();

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(400).json({ message: "Invalid credentials" });
    }

    const token = jwt.sign({ userId: userDoc.id }, JWT_SECRET, { expiresIn: '7d' });
    res.json({ token, userId: userDoc.id, name: user.name, email: user.email });
  } catch (err) {
    console.error("Login error:", err);
    res.status(500).json({ error: err.message });
  }
});

// 3. Current User Profile
app.get('/api/auth/me', auth, async (req, res) => {
  if (!db) {
    return res.status(500).json({ error: "Firebase database not initialized" });
  }

  try {
    const userDoc = await db.collection('users').doc(req.userId).get();
    if (!userDoc.exists) {
      return res.status(404).json({ message: "User not found" });
    }

    const userData = userDoc.data();
    delete userData.password; // Do not send hashed password back to client

    res.json({ id: userDoc.id, ...userData });
  } catch (err) {
    console.error("Fetch current user error:", err);
    res.status(500).json({ error: err.message });
  }
});

// Zones Routes

// 1. Endpoint to Sync/Save Zone
app.post('/api/zones/sync', auth, async (req, res) => {
  if (!db) {
    return res.status(500).json({ success: false, error: "Firebase database not initialized" });
  }

  try {
    const zoneData = req.body;
    if (!zoneData.id) {
      return res.status(400).json({ success: false, error: "Zone ID is required" });
    }

    const zoneRef = db.collection('zones').doc(zoneData.id);
    const zoneDoc = await zoneRef.get();

    // Enforce user-specific access controls if the zone already exists
    if (zoneDoc.exists && zoneDoc.data().userId !== req.userId) {
      return res.status(403).json({ success: false, message: "Unauthorized to update this zone" });
    }

    const updatedZone = {
      id: zoneData.id,
      userId: req.userId,
      name: zoneData.name,
      type: zoneData.type,
      points: zoneData.points,
      radius: zoneData.radius !== undefined ? zoneData.radius : null,
      createdAt: zoneDoc.exists ? (zoneDoc.data().createdAt || new Date().toISOString()) : new Date().toISOString()
    };

    await zoneRef.set(updatedZone, { merge: true });
    res.status(200).json({ success: true, data: updatedZone });
  } catch (err) {
    console.error('Server sync error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// 2. Fetch all zones for the logged-in user
app.get('/api/zones', auth, async (req, res) => {
  if (!db) {
    return res.status(500).json({ success: false, error: "Firebase database not initialized" });
  }

  try {
    const snapshot = await db.collection('zones').where('userId', '==', req.userId).get();
    const zones = [];
    snapshot.forEach(doc => {
      zones.push(doc.data());
    });
    res.status(200).json({ success: true, data: zones });
  } catch (err) {
    console.error('Server fetch zones error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// 3. Endpoint to delete a zone
app.delete('/api/zones/:id', auth, async (req, res) => {
  if (!db) {
    return res.status(500).json({ success: false, error: "Firebase database not initialized" });
  }

  try {
    const { id } = req.params;
    const zoneRef = db.collection('zones').doc(id);
    const zoneDoc = await zoneRef.get();

    if (!zoneDoc.exists) {
      return res.status(404).json({ success: false, message: "Zone not found" });
    }

    if (zoneDoc.data().userId !== req.userId) {
      return res.status(403).json({ success: false, message: "Unauthorized to delete this zone" });
    }

    await zoneRef.delete();
    res.status(200).json({ success: true, message: "Zone deleted successfully" });
  } catch (err) {
    console.error('Server delete zone error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

const PORT = process.env.PORT || 3000;
// Bind to 0.0.0.0 for access across the local network (e.g. mobile devices)
app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Geofence Backend running on http://0.0.0.0:${PORT}`);
  console.log(`   (Accessible locally via http://localhost:${PORT})`);
});
