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

const liveFixturesEl = document.getElementById('wc-live-fixtures');
const standingsEl = document.getElementById('wc-standings-body');
const concludedEl = document.getElementById('wc-concluded-results');

const presentCountEl = document.getElementById('wc-present-count');
const totalPeopleEl = document.getElementById('wc-total-people');
const dailyRecordEl = document.getElementById('wc-daily-record');
const allTimeRecordEl = document.getElementById('wc-all-time-record');

const winnerNameEl = document.getElementById('wc-winner-name');
const winnerMetaEl = document.getElementById('wc-winner-meta');

const timeEl = document.getElementById('wc-current-time');
const halfEl = document.getElementById('wc-match-half');

// Funny Uruguayan legends & Office rivals
const rivals = [
  { name: "Luis Suárez 🧉", device: "El Pistolero (Nacional)", goals: 4 },
  { name: "Diego Forlán 🏆", device: "Cachavacha (Independiente)", goals: 3 },
  { name: "Obdulio Varela 🛡️", device: "El Negro Jefe (Peñarol)", goals: 5 },
  { name: "Enzo Francescoli 🎩", device: "El Príncipe (River Plate)", goals: 3 },
  { name: "Fede Valverde 🏃‍♂️", device: "El Halcón (Real Madrid)", goals: 4 },
  { name: "Coffee Machine ☕", device: "Espresso Maker", goals: 5 },
  { name: "Unresolved Bugs 🐛", device: "Production Backlog", goals: 2 },
  { name: "Git Merge Conflict ⚠️", device: "Branch Master", goals: 3 },
  { name: "Standup Meeting 🕰️", device: "Daily Standup blocker", goals: 1 },
  { name: "The Main Router 📶", device: "Office WiFi 5G", goals: 4 }
];

function showDashboard() {
  loadingEl.style.display = 'none';
  errorEl.style.display = 'none';
  dashboardEl.style.display = 'block'; // using standard layout display for world cup
}

function showError(message) {
  errorEl.textContent = message;
  errorEl.style.display = 'block';
  dashboardEl.style.display = 'none';
  loadingEl.style.display = 'none';
}

function normalizeUtc(value) {
  if (!value) return null;
  return value.includes('Z') || value.includes('+') ? value : `${value}Z`;
}

function formatDisplayName(person) {
  if (!person) return '';
  const name = person.person || 'Unknown';
  return person.medal ? `${name} ${person.medal}` : name;
}

function formatClock(utcString) {
  const normalized = normalizeUtc(utcString);
  if (!normalized) return '--:--';
  const date = new Date(normalized);
  if (Number.isNaN(date.getTime())) return '--:--';
  const hours = String(date.getHours()).padStart(2, '0');
  const minutes = String(date.getMinutes()).padStart(2, '0');
  return `${hours}:${minutes}`;
}

function formatDisplayDate(utcString) {
  const normalized = normalizeUtc(utcString);
  const date = normalized ? new Date(normalized) : new Date();
  if (Number.isNaN(date.getTime())) return '';
  return date.toLocaleDateString(undefined, {
    weekday: 'long',
    month: 'long',
    day: 'numeric'
  });
}

// Simulates a football match clock (0' - 90') based on the current minute of the hour
function getSimulatedMatchClock() {
  const date = new Date();
  const realMin = date.getMinutes();
  
  // Scale 0-59 minutes of the hour to 0-90+ minutes of a football match
  const matchMin = Math.floor(realMin * 1.55); // 59 * 1.55 = 91 minutes
  
  if (matchMin === 0) {
    return { half: "1T", clock: "0'" };
  } else if (matchMin <= 45) {
    return { half: "1T", clock: `${matchMin}'` };
  } else if (matchMin <= 48) {
    return { half: "1T", clock: `45' + ${matchMin - 45}` };
  } else if (matchMin <= 90) {
    return { half: "2T", clock: `${matchMin}'` };
  } else {
    return { half: "2T", clock: `90' + ${matchMin - 90}` };
  }
}

function renderForm(days) {
  const totalDays = 5;
  const presentCount = Math.min(totalDays, Math.max(0, days));
  const absentCount = totalDays - presentCount;
  
  let html = '<div class="table-form-group">';
  for (let i = 0; i < presentCount; i++) {
    html += '<span class="form-bubble present" title="Present"></span>';
  }
  for (let i = 0; i < absentCount; i++) {
    html += '<span class="form-bubble absent" title="Absent"></span>';
  }
  html += '</div>';
  return html;
}

function renderLiveFixtures(people, clockInfo) {
  if (!Array.isArray(people) || people.length === 0) {
    return `
      <div class="empty-pitch">
        <div class="pitch-circle">⚽</div>
        <h3>Estadio Vacío</h3>
        <p>No hay jugadores en la cancha todavía. ¡Sé el primero en entrar a jugar!</p>
      </div>
    `;
  }

  let html = '<div class="fixtures-list">';
  
  // Pair people 2-by-2
  for (let i = 0; i < people.length; i += 2) {
    const p1 = people[i];
    const name1 = formatDisplayName(p1);
    const dev1 = p1.device || 'Device';
    const goals1 = p1.days || 1;
    
    let name2, dev2, goals2, avatar2, isRivalClass = "";
    
    if (i + 1 < people.length) {
      const p2 = people[i + 1];
      name2 = formatDisplayName(p2);
      dev2 = p2.device || 'Device';
      goals2 = p2.days || 1;
      avatar2 = `<div class="player-jersey">${p2.person ? p2.person[0].toUpperCase() : '?' }</div>`;
    } else {
      const rivalIdx = (new Date().getDate() + i) % rivals.length;
      const rival = rivals[rivalIdx];
      name2 = rival.name;
      dev2 = rival.device;
      
      goals2 = Math.max(0, Math.floor(goals1 + (Math.random() * 3 - 1.5)));
      avatar2 = `<div class="player-jersey">🇺🇾</div>`;
      isRivalClass = "is-rival";
    }

    const avatar1 = `<div class="player-jersey">${p1.person ? p1.person[0].toUpperCase() : '?' }</div>`;

    html += `
      <div class="match-card ${isRivalClass}">
        <div class="match-card-grid">
          <div class="team-column">
            ${avatar1}
            <div class="player-details">
              <div class="player-name">${name1}</div>
              <div class="player-device">${dev1}</div>
            </div>
          </div>

          <div class="score-box">
            <div class="score-digits">
              <span>${goals1}</span>
              <span class="score-separator">-</span>
              <span>${goals2}</span>
            </div>
            <div class="match-status-badge live">${clockInfo.clock}</div>
          </div>

          <div class="team-column team-right ${isRivalClass ? 'is-opponent' : ''}">
            ${avatar2}
            <div class="player-details">
              <div class="player-name">${name2}</div>
              <div class="player-device">${dev2}</div>
            </div>
          </div>
        </div>
      </div>
    `;
  }

  html += '</div>';
  return html;
}

function renderStandings(attendees) {
  if (!Array.isArray(attendees) || attendees.length === 0) {
    return `
      <tr>
        <td colspan="5" style="text-align: center; padding: 2rem; color: var(--text-secondary);">Sin datos del torneo todavía.</td>
      </tr>
    `;
  }

  const medals = ['🥇', '🥈', '🥉'];
  return attendees.slice(0, 5).map((attendee, index) => {
    const name = formatDisplayName(attendee);
    const days = attendee.days || 0;
    const rank = medals[index] || `${index + 1}`;
    const topClass = index === 0 ? 'top-spot' : '';
    const initial = attendee.person ? attendee.person[0].toUpperCase() : '?';

    return `
      <tr class="${topClass}">
        <td class="table-rank">${rank}</td>
        <td class="table-team">
          <div class="table-avatar">${initial}</div>
          <span>${name}</span>
        </td>
        <td class="table-num points" style="text-align: center;">${days}</td>
        <td class="table-num" style="text-align: center;">${days * 2}</td>
        <td style="padding-left: 1.5rem;">
          ${renderForm(days)}
        </td>
      </tr>
    `;
  }).join('');
}

function renderConcluded(absent) {
  if (!Array.isArray(absent) || absent.length === 0) {
    return `
      <div class="empty-pitch" style="padding: 2rem 1rem;">
        <div class="pitch-circle" style="width: 50px; height: 50px; font-size: 1.2rem;">⏱️</div>
        <p>Ningún jugador ha abandonado la cancha hoy. ¡Todos siguen en el vestuario!</p>
      </div>
    `;
  }

  let html = '<div class="results-list">';
  absent.slice(0, 6).map((person) => {
    const name = formatDisplayName(person);
    const initial = person.person ? person.person[0].toUpperCase() : '?';
    const goals = person.days || 1;
    const exitScore = 0;

    html += `
      <div class="result-card">
        <div class="result-team-info">
          <div class="result-avatar">${initial}</div>
          <div class="result-name">${name}</div>
        </div>
        <div class="result-score-info">
          <div class="result-score">${goals} - ${exitScore}</div>
          <span class="result-badge-ft">FT</span>
        </div>
      </div>
    `;
  });
  html += '</div>';
  return html;
}

function updateDashboard(data) {
  if (!data) {
    showError('No data available. Make sure the sync script is running.');
    return;
  }

  showDashboard();

  const nowUtc = data.now || data.last_updated;
  const clockInfo = getSimulatedMatchClock();

  // Update time & simulated match half
  if (timeEl) {
    timeEl.dataset.utc = normalizeUtc(nowUtc) || '';
    timeEl.textContent = formatClock(nowUtc);
  }
  if (halfEl) {
    halfEl.textContent = clockInfo.half;
  }

  // Update date
  const dateEl = document.querySelector('.date');
  if (dateEl) {
    dateEl.textContent = formatDisplayDate(nowUtc);
  }

  // Update scoreboards
  if (presentCountEl) presentCountEl.textContent = data.present_count ?? 0;
  if (totalPeopleEl) totalPeopleEl.textContent = data.total_people ?? 0;
  if (dailyRecordEl) dailyRecordEl.textContent = data.daily_record ?? 0;
  if (allTimeRecordEl) allTimeRecordEl.textContent = data.all_time_record ?? 0;

  // Update winner badge if available
  if (data.last_week_winner) {
    if (winnerNameEl) winnerNameEl.textContent = data.last_week_winner.person || 'Unknown';
    if (winnerMetaEl) {
      winnerMetaEl.textContent = `${data.last_week_winner.days || 0} goles (${data.last_week_winner.week_start} to ${data.last_week_winner.week_end})`;
    }
  }

  // Render fixtures, standings, and early exits
  if (liveFixturesEl) {
    liveFixturesEl.innerHTML = renderLiveFixtures(data.mapped_present, clockInfo);
  }
  if (standingsEl) {
    standingsEl.innerHTML = renderStandings(data.top_attendees);
  }
  if (concludedEl) {
    concludedEl.innerHTML = renderConcluded(data.mapped_absent);
  }
}

const dashboardRef = ref(database, 'dashboard');
onValue(dashboardRef, (snapshot) => {
  updateDashboard(snapshot.val());
}, (error) => {
  console.error('Firebase error:', error);
  showError(`Error loading data: ${error.message}`);
});
