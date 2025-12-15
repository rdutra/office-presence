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

function formatDisplayName(person) {
  if (!person) return 'Unknown';
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

  // Update stats - only update numbers, preserve labels from template
  const statCards = document.querySelectorAll('.stat-card');
  statCards.forEach(card => {
    const stat = card.dataset.stat;
    const numberEl = card.querySelector('.stat-number');

    if (numberEl) {
      switch(stat) {
        case 'present':
          if (data.show_in_office_tile !== false) {
            numberEl.textContent = data.present_count ?? 0;
          } else {
            card.style.display = 'none';
          }
          break;
        case 'total':
          if (data.show_registered_users_tile !== false) {
            numberEl.textContent = data.total_people ?? 0;
          } else {
            card.style.display = 'none';
          }
          break;
        case 'daily-record':
          if (data.show_today_record_tile !== false) {
            numberEl.textContent = data.daily_record ?? 0;
          } else {
            card.style.display = 'none';
          }
          break;
        case 'all-time-record':
          if (data.show_all_time_record_tile !== false) {
            numberEl.textContent = data.all_time_record ?? 0;
          } else {
            card.style.display = 'none';
          }
          break;
        case 'last-week-winner':
          if (data.last_week_winner) {
            const winner = data.last_week_winner;
            const nameEl = card.querySelector('.badge-name');
            const metaEl = card.querySelector('.badge-meta');
            if (nameEl) nameEl.textContent = formatDisplayName(winner);
            if (metaEl) metaEl.textContent = `${winner.days ?? 0} days (${winner.week_start || '--'} to ${winner.week_end || '--'})`;
          } else {
            card.style.display = 'none';
          }
          break;
      }
    }
  });

  // Add last week winner if it doesn't exist and data has it
  if (data.last_week_winner && !document.querySelector('[data-stat="last-week-winner"]')) {
    const statsContainer = document.querySelector('.stats');
    if (statsContainer) {
      const winner = data.last_week_winner;
      const winnerCard = document.createElement('div');
      winnerCard.className = 'stat-card';
      winnerCard.dataset.stat = 'last-week-winner';
      winnerCard.innerHTML = `
        <div class="badge-label">🏆 Last Week Winner 🏆</div>
        <div class="badge-name">${formatDisplayName(winner)}</div>
        <div class="badge-meta">${winner.days ?? 0} days (${winner.week_start || '--'} to ${winner.week_end || '--'})</div>
      `;
      statsContainer.appendChild(winnerCard);
    }
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
          const baseName = person?.person || 'Unknown';
          const name = formatDisplayName(person);
          const device = person?.device || 'Device';
          const status = person?.status || 'inactive';
          const initial = baseName.trim().charAt(0).toUpperCase() || '?';
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
              <div class="podium-name">${formatDisplayName(attendee)}</div>
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
            <div class="recent-name">${formatDisplayName(person)}</div>
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
