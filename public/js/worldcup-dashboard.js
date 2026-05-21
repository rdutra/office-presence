(function() {
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

  // Prevent script running on other templates
  if (!liveFixturesEl && !standingsEl) return;

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
      // First half injury time
      return { half: "1T", clock: `45' + ${matchMin - 45}` };
    } else if (matchMin <= 90) {
      return { half: "2T", clock: `${matchMin}'` };
    } else {
      // Second half injury time
      return { half: "2T", clock: `90' + ${matchMin - 90}` };
    }
  }

  function renderForm(wins) {
    // Generate up to 5 green bubbles for weekly wins
    const winCount = parseInt(wins) || 0;
    const displayCount = Math.min(5, winCount);
    const extraCount = winCount > 5 ? winCount - 5 : 0;
    
    let html = '<div class="table-form-group">';
    if (winCount === 0) {
      html += '<span class="form-bubble absent" title="No wins yet"></span>';
    } else {
      for (let i = 0; i < displayCount; i++) {
        html += '<span class="form-bubble present" title="Weekly Winner"></span>';
      }
      if (extraCount > 0) {
        html += `<span style="font-size: 0.75rem; color: var(--uruguay-gold); font-weight: 800; margin-left: 2px;">+${extraCount}</span>`;
      }
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
      
      // Goals are represented by the attendee's score or a simulated metric (e.g. days present, default to 1)
      const goals1 = p1.days || 1;
      
      let name2, dev2, goals2, avatar2, isRivalClass = "";
      
      if (i + 1 < people.length) {
        // We have a pair!
        const p2 = people[i + 1];
        name2 = formatDisplayName(p2);
        dev2 = p2.device || 'Device';
        goals2 = p2.days || 1;
        avatar2 = `<div class="player-jersey">${p2.person ? p2.person[0].toUpperCase() : '?' }</div>`;
      } else {
        // Odd player out: Pair with a funny AI Uruguayan rival / Office appliance
        const rivalIdx = (new Date().getDate() + i) % rivals.length;
        const rival = rivals[rivalIdx];
        name2 = rival.name;
        dev2 = rival.device;
        
        // Simulating rival goals (a fun dynamic value around player goals)
        goals2 = Math.max(0, Math.floor(goals1 + (Math.random() * 3 - 1.5)));
        avatar2 = `<div class="player-jersey">🇺🇾</div>`;
        isRivalClass = "is-rival";
      }

      const avatar1 = `<div class="player-jersey">${p1.person ? p1.person[0].toUpperCase() : '?' }</div>`;

      html += `
        <div class="match-card ${isRivalClass}">
          <div class="match-card-grid">
            <!-- Team 1 / Player 1 -->
            <div class="team-column">
              ${avatar1}
              <div class="player-details">
                <div class="player-name">${name1}</div>
                <div class="player-device">${dev1}</div>
              </div>
            </div>

            <!-- Scoreboard Box -->
            <div class="score-box">
              <div class="score-digits">
                <span>${goals1}</span>
                <span class="score-separator">-</span>
                <span>${goals2}</span>
              </div>
              <div class="match-status-badge live">${clockInfo.clock}</div>
            </div>

            <!-- Team 2 / Player 2 -->
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

    return attendees.slice(0, 5).map((attendee, index) => {
      const name = attendee.person || 'Unknown';
      const days = attendee.days || 0;
      const wins = attendee.weekly_wins || 0;
      const rank = index + 1;
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
            ${renderForm(wins)}
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
      
      // Opponent for early departures is Home/Early exit
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

  async function fetchDashboard() {
    try {
      const res = await fetch('/api/dashboard');
      if (!res.ok) throw new Error('Failed to load dashboard data');
      const data = await res.json();

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

    } catch (e) {
      console.error('World Cup dashboard update failed', e);
    }
  }

  // Setup registration button text check (analogous to standard dashboard.js)
  async function updateRegistrationButtonText() {
    const openBtn = document.getElementById('openRegistrationBtn');
    if (!openBtn) return;
    try {
      const response = await fetch('/api/my-device');
      const data = await response.json();
      if (data.registered) {
        openBtn.innerHTML = '<span>🎟️</span> Update Device';
      } else {
        openBtn.innerHTML = '<span>🎟️</span> Register Device';
      }
    } catch (error) {
      console.error('Error checking registration status:', error);
    }
  }

  // Setup modal functions analogous to standard dashboard.js
  function setupRegistrationModal() {
    const modal = document.getElementById("registrationModal");
    const openBtn = document.getElementById("openRegistrationBtn");
    const closeBtn = document.getElementById("closeRegistrationBtn");
    const overlay = modal?.querySelector(".modal-overlay");

    if (!modal || !openBtn) return;

    const openModal = () => {
      modal.classList.add("is-open");
      modal.setAttribute("aria-hidden", "false");
      document.body.classList.add("modal-open");
      if (typeof initializeRegistration === "function") {
        initializeRegistration();
      }
    };

    const closeModal = () => {
      modal.classList.remove("is-open");
      modal.setAttribute("aria-hidden", "true");
      document.body.classList.remove("modal-open");
    };

    openBtn.addEventListener("click", openModal);
    closeBtn?.addEventListener("click", closeModal);
    overlay?.addEventListener("click", closeModal);

    document.addEventListener("keydown", (event) => {
      if (event.key === "Escape" && modal.classList.contains("is-open")) {
        closeModal();
      }
    });
  }

  // Marcelo Bielsa "Toasty!" Easter Egg
  function setupEasterEgg() {
    const bielsaContainer = document.getElementById('bielsa-easter-egg');
    if (!bielsaContainer) return;

    // Create audio object
    const toastyAudio = new Audio('/img/worldcup/toasty.mp3');
    let isRunning = false;

    function triggerToasty() {
      if (isRunning) return;
      isRunning = true;

      // Play audio
      toastyAudio.currentTime = 0;
      toastyAudio.play().catch(e => console.log("Audio play failed:", e));

      // Show Bielsa
      bielsaContainer.classList.add('active');

      // Hide after animation
      setTimeout(() => {
        bielsaContainer.classList.remove('active');
        setTimeout(() => {
          isRunning = false;
        }, 500);
      }, 1500);
    }

    function scheduleNextToasty() {
      // Random time between 3 and 10 minutes
      const minTime = 3 * 60 * 1000;
      const maxTime = 10 * 60 * 1000;
      const nextTime = Math.random() * (maxTime - minTime) + minTime;

      setTimeout(() => {
        triggerToasty();
        scheduleNextToasty();
      }, nextTime);
    }

    // Manual trigger with 'f' key
    document.addEventListener('keydown', (e) => {
      if (e.key.toLowerCase() === 'f') {
        triggerToasty();
      }
    });

    // Start random schedule
    scheduleNextToasty();
  }

  // Initialization
  document.addEventListener("DOMContentLoaded", () => {
    fetchDashboard();
    setInterval(fetchDashboard, 30000);
    setupRegistrationModal();
    updateRegistrationButtonText();
    setupEasterEgg();
  });
})();
