import { initializeApp } from 'https://www.gstatic.com/firebasejs/10.7.1/firebase-app.js';
import { getDatabase, ref, onValue } from 'https://www.gstatic.com/firebasejs/10.7.1/firebase-database.js';

// IMPORTANT: Replace these placeholders with your actual Firebase config
// Get your config from: Firebase Console > Project Settings > General > Your apps
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
  dashboardEl.style.display = 'flex';
  dashboardEl.style.flexDirection = 'column';
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

function updateDashboard(data) {
  if (!data) {
    showError('No data available. Make sure the sync script is running.');
    return;
  }

  showDashboard();

  // Update time and date
  const nowUtc = data.now || data.last_updated;
  const timeEl = document.querySelector('.current-time');
  if (timeEl) {
    timeEl.dataset.utc = normalizeUtc(nowUtc) || '';
    timeEl.textContent = formatClock(nowUtc);
  }

  const dateEl = document.querySelector('.date');
  if (dateEl) {
    dateEl.textContent = formatDisplayDate(nowUtc);
  }

  // Update stats
  const statsContainer = document.querySelector('.stats');
  if (statsContainer) {
    const stats = [];

    if (data.show_in_office_tile !== false) {
      stats.push(`
        <div class="stat-card" data-stat="present">
          <div class="stat-number">${data.present_count ?? 0}</div>
          <div class="stat-label">In the Office 🎉</div>
        </div>
      `);
    }

    if (data.show_registered_users_tile !== false) {
      stats.push(`
        <div class="stat-card" data-stat="total">
          <div class="stat-number">${data.total_people ?? 0}</div>
          <div class="stat-label">Registered Users 👥</div>
        </div>
      `);
    }

    if (data.show_today_record_tile !== false) {
      stats.push(`
        <div class="stat-card" data-stat="daily-record">
          <div class="stat-number">${data.daily_record ?? 0}</div>
          <div class="stat-label">Today's Record 🏆</div>
        </div>
      `);
    }

    if (data.show_all_time_record_tile !== false) {
      stats.push(`
        <div class="stat-card" data-stat="all-time-record">
          <div class="stat-number">${data.all_time_record ?? 0}</div>
          <div class="stat-label">All-Time Record 🌟</div>
        </div>
      `);
    }

    if (data.last_week_winner) {
      const winner = data.last_week_winner;
      stats.push(`
        <div class="stat-card" data-stat="last-week-winner">
          <div class="badge-label">🏆 Last Week Winner 🏆</div>
          <div class="badge-name">${winner.person || 'Unknown'}</div>
          <div class="badge-meta">${winner.days ?? 0} days (${winner.week_start || '--'} to ${winner.week_end || '--'})</div>
        </div>
      `);
    }

    statsContainer.innerHTML = stats.join('');
  }

  // Update week range
  const weekRangeEl = document.querySelector('[data-week-range]');
  if (weekRangeEl && data.current_week_start && data.current_week_end) {
    weekRangeEl.textContent = `${data.current_week_start} to ${data.current_week_end}`;
  }

  // Update people present
  const presentSection = document.querySelector('[data-section="present"]');
  if (presentSection) {
    const contentArea = presentSection.querySelector('.section-header').nextElementSibling;
    if (contentArea) {
      if (!Array.isArray(data.mapped_present) || data.mapped_present.length === 0) {
        contentArea.innerHTML = '<div class="empty-state">No one here yet — be the first! ☕</div>';
      } else {
        const cards = data.mapped_present.map(person => {
          const name = person?.person || 'Unknown';
          const device = person?.device || 'Device';
          const status = person?.status || 'inactive';
          const initial = name.trim().charAt(0).toUpperCase() || '?';
          return `
            <div class="person-card status-${status}">
              <div class="person-avatar">${initial}</div>
              <div class="person-info">
                <div class="person-name">${name}</div>
                <div class="person-device">${device}</div>
              </div>
            </div>
          `;
        }).join('');
        contentArea.innerHTML = `<div class="people-list">${cards}</div>`;
      }
    }
  }

  // Update top attendees
  const championsSection = document.querySelector('[data-section="top-attendees"]');
  if (championsSection) {
    const medals = ['🥇', '🥈', '🥉'];
    const contentArea = Array.from(championsSection.querySelectorAll('div')).find(el =>
      el.classList.contains('podium-container') || el.classList.contains('empty-state')
    )?.parentElement;

    if (contentArea) {
      if (!Array.isArray(data.top_attendees) || data.top_attendees.length === 0) {
        contentArea.innerHTML = '<div class="empty-state">No data yet</div>';
      } else {
        const podium = data.top_attendees.slice(0, 3).map((attendee, index) => `
          <div class="podium-item rank-${index + 1}">
            <div class="podium-rank">${medals[index] || ''}</div>
            <div class="podium-info">
              <div class="podium-name">${attendee?.person || 'Unknown'}</div>
              <div class="podium-days">${attendee?.days || 0} days</div>
            </div>
          </div>
        `).join('');
        contentArea.innerHTML = `<div class="podium-container">${podium}</div>`;
      }
    }
  }

  // Update earlier today
  const recentSection = document.querySelector('[data-section="recent"]');
  if (recentSection) {
    const contentArea = recentSection.querySelector('.section-header').nextElementSibling;
    if (contentArea) {
      if (!Array.isArray(data.mapped_absent) || data.mapped_absent.length === 0) {
        contentArea.innerHTML = '<div class="empty-state">No one has left yet</div>';
      } else {
        const recent = data.mapped_absent.slice(0, 8).map(person => `
          <div class="recent-item">
            <div class="recent-name">${person?.person || 'Unknown'}</div>
          </div>
        `).join('');
        contentArea.innerHTML = `<div class="recent-list">${recent}</div>`;
      }
    }
  }
}

const dashboardRef = ref(database, 'dashboard');
onValue(dashboardRef, (snapshot) => {
  updateDashboard(snapshot.val());
}, (error) => {
  console.error('Firebase error:', error);
  showError(`Error loading data: ${error.message}`);
});
