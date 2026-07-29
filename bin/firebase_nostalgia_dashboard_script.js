import { initializeApp } from 'https://www.gstatic.com/firebasejs/10.7.1/firebase-app.js';
import { getDatabase, ref, onValue } from 'https://www.gstatic.com/firebasejs/10.7.1/firebase-database.js';

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

function normalizeUtc(value) {
  if (!value) return null;
  return value.includes('Z') || value.includes('+') ? value : `${value}Z`;
}

function formatClock(utcString) {
  const normalized = normalizeUtc(utcString);
  const date = normalized ? new Date(normalized) : new Date();
  if (Number.isNaN(date.getTime())) return '--:--';
  return `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`;
}

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

function setupDiscoDrop() {
  const ball = document.querySelector('.drop-disco-ball');
  const layer = document.querySelector('.nostalgia-bg');
  if (!ball || !layer) return;

  const prefersReducedMotion = window.matchMedia?.('(prefers-reduced-motion: reduce)').matches;
  if (prefersReducedMotion) return;

  const triggerDrop = () => {
    const x = 18 + Math.random() * 64;
    layer.style.setProperty('--drop-x', `${x}%`);
    document.body.classList.add('scene-lit');
    ball.classList.remove('is-dropping');
    void ball.offsetWidth;
    ball.classList.add('is-dropping');

    window.setTimeout(() => {
      ball.classList.remove('is-dropping');
      document.body.classList.remove('scene-lit');
    }, 8500);
  };

  const schedule = (initial = false) => {
    const minDelay = initial ? 35000 : 120000;
    const maxDelay = initial ? 75000 : 300000;
    window.setTimeout(() => {
      triggerDrop();
      schedule();
    }, minDelay + Math.random() * (maxDelay - minDelay));
  };

  schedule(true);

  document.addEventListener('keydown', (event) => {
    if (event.key?.toLowerCase() !== 'f') return;
    if (event.metaKey || event.ctrlKey || event.altKey) return;
    triggerDrop();
  });
}

function renderTracks(data) {
  const trackListEl = document.getElementById('ns-track-list');
  if (!trackListEl) return;

  const people = (data.mapped_present || [])
    .filter((person) => person.person && !person.person.startsWith('Anonymous'))
    .sort((a, b) => {
      return a.person.localeCompare(b.person);
    });

  trackListEl.innerHTML = '';
  trackListEl.classList.toggle('is-dense', people.length > 28);
  trackListEl.classList.toggle('is-ultra-dense', people.length > 36);
  const totalPeopleEl = document.getElementById('ns-total-people');
  if (totalPeopleEl) totalPeopleEl.textContent = people.length;
  const presentCountEl = document.getElementById('ns-present-count');
  if (presentCountEl) presentCountEl.textContent = people.length;

  if (people.length === 0) {
    trackListEl.innerHTML = '<li><span class="track-num">00</span><span class="track-name">Nadie en la pista</span><span class="track-status">silencio</span></li>';
    return;
  }

  people.forEach((person, index) => {
    const row = document.createElement('li');
    row.classList.add('is-present');
    const status = 'sonando';
    const name = [person.person, person.medal].filter(Boolean).join(' ');
    row.innerHTML = `<span class="track-num">${String(index + 1).padStart(2, '0')}</span><span class="track-name"></span><span class="track-status">${status}</span>`;
    row.querySelector('.track-name').textContent = name;
    trackListEl.appendChild(row);
  });
}

function renderTopAttendees(data) {
  const topAttendeesEl = document.getElementById('ns-top-attendees');
  if (!topAttendeesEl) return;

  const attendees = data.top_attendees || [];
  topAttendeesEl.innerHTML = '';

  if (attendees.length === 0) {
    topAttendeesEl.innerHTML = '<div class="spin-row"><b>-</b><span>Sin ranking</span><em>0</em></div>';
    return;
  }

  attendees.slice(0, 6).forEach((attendee, index) => {
    const row = document.createElement('div');
    row.className = 'spin-row';
    row.innerHTML = `<b>${index + 1}</b><span></span><em>${attendee.days}</em>`;
    row.querySelector('span').textContent = attendee.person;
    topAttendeesEl.appendChild(row);
  });
}

function renderLastWeekWinner(data) {
  const nameEl = document.getElementById('ns-last-winner-name');
  const metaEl = document.getElementById('ns-last-winner-meta');
  if (!nameEl || !metaEl) return;

  const winner = data.last_week_winner;
  if (!winner) {
    nameEl.textContent = 'Sin ganador';
    metaEl.textContent = '--';
    return;
  }

  nameEl.textContent = [winner.person, winner.medal].filter(Boolean).join(' ');
  metaEl.textContent = `${winner.days || 0} días`;
}

function updateDashboard(data) {
  if (!data) {
    showError('No hay datos disponibles. Verifica que el script de sincronización esté activo.');
    return;
  }

  showDashboard();

  const nowUtc = data.now || data.last_updated;
  const timeEl = document.getElementById('ns-current-time');
  if (timeEl) {
    timeEl.dataset.utc = normalizeUtc(nowUtc) || '';
    timeEl.textContent = formatClock(nowUtc);
  }

  const presentCountEl = document.getElementById('ns-present-count');
  const totalPeopleEl = document.getElementById('ns-total-people');
  const dailyRecordEl = document.getElementById('ns-daily-record');
  const allTimeRecordEl = document.getElementById('ns-all-time-record');

  if (presentCountEl) presentCountEl.textContent = data.present_count ?? 0;
  if (totalPeopleEl) totalPeopleEl.textContent = data.total_people ?? 0;
  if (dailyRecordEl) dailyRecordEl.textContent = data.daily_record ?? 0;
  if (allTimeRecordEl) allTimeRecordEl.textContent = data.all_time_record ?? 0;

  renderTracks(data);
  renderTopAttendees(data);
  renderLastWeekWinner(data);
}

window.FIREBASE_MODE = true;
setupDiscoDrop();

const dashboardRef = ref(database, 'dashboard');
onValue(dashboardRef, (snapshot) => {
  updateDashboard(snapshot.val());
}, (error) => {
  showError(`Error de conexión con Firebase: ${error.message}`);
});
