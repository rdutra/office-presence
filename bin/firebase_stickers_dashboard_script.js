import { initializeApp } from "https://www.gstatic.com/firebasejs/9.6.1/firebase-app.js";
import { getDatabase, ref, onValue } from "https://www.gstatic.com/firebasejs/9.6.1/firebase-database.js";

// Firebase config placeholders (will be replaced by firebase_deploy.sh)
const firebaseConfig = {
  apiKey: "YOUR_API_KEY_HERE",
  authDomain: "YOUR_PROJECT_ID.firebaseapp.com",
  databaseURL: "https://YOUR_PROJECT_ID-default-rtdb.firebaseio.com/",
  projectId: "YOUR_PROJECT_ID",
  storageBucket: "YOUR_PROJECT_ID.appspot.com",
  messagingSenderId: "YOUR_MESSAGING_SENDER_ID",
  appId: "YOUR_APP_ID"
};

const app = initializeApp(firebaseConfig);
const db = getDatabase(app);

// Stickers Dashboard Firebase Integration
const dashboardRef = ref(db, 'dashboard');

// Instantiate the dashboard logic
window.FIREBASE_MODE = true;
const dashboard = new StickersDashboard();

onValue(dashboardRef, (snapshot) => {
  const data = snapshot.val();
  if (data) {
    dashboard.data = data;
    dashboard.render();
    
    const loadingEl = document.getElementById('loading');
    const albumEl = document.getElementById('album-container');
    
    if (loadingEl) loadingEl.style.display = 'none';
    if (albumEl) albumEl.style.display = 'flex';
  }
});
