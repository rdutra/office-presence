import { initializeApp } from 'https://www.gstatic.com/firebasejs/10.7.1/firebase-app.js';
import { getDatabase, ref, onValue } from 'https://www.gstatic.com/firebasejs/10.7.1/firebase-database.js';

// IMPORTANT: Replace these placeholders with your actual Firebase config
const firebaseConfig = {
  apiKey: "YOUR_API_KEY_HERE",
  authDomain: "YOUR_PROJECT_ID.firebaseapp.com",
  databaseURL: "https://YOUR_PROJECT_ID-default-rtdb.firebaseio.com",
  projectId: "YOUR_PROJECT_ID",
  storageBucket: "YOUR_PROJECT_ID.appspot.com",
  messagingSenderId: "YOUR_MESSAGING_SENDER_ID",
  appId: "YOUR_APP_ID"
};

const app = initializeApp(firebaseConfig);
const database = getDatabase(app);

const dashboardEl = document.getElementById('dashboard');
const loadingEl = document.getElementById('loading');
const errorEl = document.getElementById('error');

function showDashboard() {
  loadingEl.style.display = 'none';
  errorEl.style.display = 'none';
  dashboardEl.style.display = 'block';
}

function showError(message) {
  errorEl.textContent = message;
  errorEl.style.display = 'block';
  dashboardEl.style.display = 'none';
  loadingEl.style.display = 'none';
}

function updateDashboard(data) {
  if (!data) {
    showError('No data available. Make sure the sync script is running.');
    return;
  }

  showDashboard();
  
  // Call the shared update function in worldcup-dashboard.js
  if (typeof window.updateWorldCupDashboard === 'function') {
    window.updateWorldCupDashboard(data);
  } else {
    console.error('window.updateWorldCupDashboard not found!');
  }
}

// Set Firebase mode flag for the shared script
window.FIREBASE_MODE = true;

const dashboardRef = ref(database, 'dashboard');
onValue(dashboardRef, (snapshot) => {
  updateDashboard(snapshot.val());
}, (error) => {
  console.error('Firebase error:', error);
  showError(`Error loading data: ${error.message}`);
});
