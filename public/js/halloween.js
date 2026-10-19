// ==========================================================================
// THE HAUNTED OFFICE — HALLOWEEN DASHBOARD CLIENT SCRIPT
// ==========================================================================

class HalloweenDashboard {
  constructor() {
    this.refreshInterval = 5000;
    this.pollTimer = null;
    this.data = null;
    this.previousPresentMacs = null;
    this.audioEnabled = false;
    this.audioContext = null;
    this.costumesEnabled = true;

    // Elements
    this.timeEl = document.querySelector('.current-time');
    this.dateEl = document.querySelector('.date');
    this.presentBadgeEl = document.getElementById('presentCountBadge');
    this.presentSection = document.querySelector('[data-section="present"]');
    this.topAttendeesSection = document.querySelector('[data-section="top-attendees"]');
    this.recentSection = document.querySelector('[data-section="recent"]');
    this.toastContainer = document.getElementById('spookyToastContainer');
    this.soundToggleBtn = document.getElementById('soundToggleBtn');
    this.costumeToggleBtn = document.getElementById('costumeToggleBtn');
    this.batsContainer = document.getElementById('batsContainer');

    this.init();
  }

  init() {
    // 1. Timezone initialization
    if (typeof initializeTimezone === 'function') {
      initializeTimezone();
    }

    // 2. Setup Registration Modal
    this.setupRegistrationModal();

    // 3. Setup Costumes Toggle
    this.setupCostumeToggle();

    // 4. Setup Audio Enabler
    this.setupAudio();

    // 5. Start Background Bats Ambient
    this.startAmbientBats();

    // 6. Device info if available
    if (typeof loadDeviceInfo === 'function') {
      loadDeviceInfo();
    }

    // 7. Initial Fetch and Periodic Polling
    if (!window.FIREBASE_MODE) {
      this.fetchDashboardData();
      this.pollTimer = setInterval(() => this.fetchDashboardData(), this.refreshInterval);
    }
  }

  // ==========================================================================
  // FETCH & DATA UPDATE
  // ==========================================================================
  async fetchDashboardData() {
    try {
      const response = await fetch('/api/dashboard');
      if (!response.ok) return;
      const data = await response.json();
      this.updateDashboard(data);
    } catch (err) {
      console.warn('[Halloween Dashboard] Polling failed:', err);
    }
  }

  updateDashboard(data) {
    if (!data) return;
    this.data = data;

    // 1. Update clock
    this.updateClock(data.now);

    // 2. Update stats cards
    this.updateStats(data);

    // 3. Check for new arrivals (to trigger spooky arrival chime & toast)
    this.checkNewArrivals(data.mapped_present || []);

    // 4. Render Haunted Gallery (Present People)
    this.renderPresentPeople(data.mapped_present || []);

    // 5. Render High Coven (Top Attendees Podium)
    this.renderTopAttendees(data.top_attendees || [], data.current_week_start, data.current_week_end);

    // 6. Render Departed Spirits (Earlier Today)
    this.renderDepartedSpirits(data.mapped_absent || []);
  }

  updateClock(utcNow) {
    if (!this.timeEl) return;
    if (utcNow) {
      this.timeEl.setAttribute('data-utc', utcNow);
      if (typeof formatLocalTime === 'function') {
        const fullTime = formatLocalTime(utcNow);
        const parts = fullTime.split(' ');
        if (parts[1]) this.timeEl.textContent = parts[1];
      } else {
        const d = new Date(utcNow + (utcNow.includes('Z') ? '' : 'Z'));
        const hrs = String(d.getHours()).padStart(2, '0');
        const mins = String(d.getMinutes()).padStart(2, '0');
        this.timeEl.textContent = `${hrs}:${mins}`;
      }
    }
  }

  updateStats(data) {
    const presentEl = document.querySelector('[data-stat="present"] .stat-number');
    if (presentEl && data.present_count !== undefined) {
      presentEl.textContent = data.present_count;
    }

    const totalEl = document.querySelector('[data-stat="total"] .stat-number');
    if (totalEl && data.total_people !== undefined) {
      totalEl.textContent = data.total_people;
    }

    const dailyEl = document.querySelector('[data-stat="daily-record"] .stat-number');
    if (dailyEl && data.daily_record !== undefined) {
      dailyEl.textContent = data.daily_record;
    }

    const allTimeEl = document.querySelector('[data-stat="all-time-record"] .stat-number');
    if (allTimeEl && data.all_time_record !== undefined) {
      allTimeEl.textContent = data.all_time_record;
    }

    if (this.presentBadgeEl && data.present_count !== undefined) {
      this.presentBadgeEl.textContent = `${data.present_count} present`;
    }

    // Last week winner card
    const winnerCard = document.querySelector('[data-stat="last-week-winner"]');
    if (winnerCard && data.last_week_winner) {
      const winner = data.last_week_winner;
      const nameEl = winnerCard.querySelector('.badge-name');
      const metaEl = winnerCard.querySelector('.badge-meta');
      const photoEl = winnerCard.querySelector('.winner-photo');
      const initialsEl = winnerCard.querySelector('.winner-initials-avatar');

      if (nameEl) nameEl.textContent = winner.person;
      if (metaEl) {
        metaEl.textContent = `${winner.days || 0} days (${winner.week_start || '--'} to ${winner.week_end || '--'})`;
      }
      if (winner.image_url && photoEl) {
        photoEl.src = winner.image_url;
        photoEl.style.display = 'block';
        if (initialsEl) initialsEl.style.display = 'none';
      } else if (initialsEl) {
        initialsEl.textContent = (winner.person || '?')[0].toUpperCase();
        initialsEl.style.display = 'flex';
        if (photoEl) photoEl.style.display = 'none';
      }
    }
  }

  // ==========================================================================
  // RENDER PRESENT PEOPLE (The Haunted Gallery)
  // ==========================================================================
  renderPresentPeople(people) {
    if (!this.presentSection) return;

    let list = this.presentSection.querySelector('.people-list');
    let empty = this.presentSection.querySelector('.empty-state');

    if (people.length === 0) {
      if (list) list.style.display = 'none';
      if (!empty) {
        empty = document.createElement('div');
        empty.className = 'empty-state';
        empty.innerHTML = `
          <div class="empty-icon">🏚️</div>
          <div class="empty-title">The manor is dead silent...</div>
          <div class="empty-desc">No souls are here yet — be the first to awaken the spirits! ☕🕯️</div>
        `;
        this.presentSection.appendChild(empty);
      }
      empty.style.display = '';
      return;
    }

    if (empty) empty.style.display = 'none';

    if (!list) {
      list = document.createElement('div');
      list.className = 'people-list';
      this.presentSection.appendChild(list);
    }
    list.style.display = '';

    list.innerHTML = people.map((person, idx) => {
      const name = this.formatDisplayName(person);
      const rawName = person.person || 'Unknown Spirit';
      const device = person.device || 'Mortal Device';
      const status = person.status || 'active';
      const initial = rawName.trim().charAt(0).toUpperCase() || '?';
      const days = person.days || 1;
      const daysText = `${days} ${days === 1 ? 'day' : 'days'}`;
      const costumeIdx = idx % 6;
      const monsterIdx = idx % 8;

      let photoHtml = '';
      if (person.image_url) {
        photoHtml = `
          <img class="person-photo" src="${this.escapeHtml(person.image_url)}" alt="${this.escapeHtml(rawName)}" loading="lazy" onerror="this.style.display='none'; this.nextElementSibling.style.display='flex';"/>
          <div class="spooky-avatar-fallback monster-${monsterIdx}" style="display:none;">
            <span class="spooky-initials">${initial}</span>
          </div>
        `;
      } else {
        photoHtml = `
          <div class="spooky-avatar-fallback monster-${monsterIdx}">
            <span class="spooky-initials">${initial}</span>
          </div>
        `;
      }

      return `
        <div class="person-card status-${status}" data-mac="${this.escapeHtml(person.mac || '')}" data-person-name="${this.escapeHtml(rawName)}">
          <div class="portrait-container">
            <div class="vintage-frame">
              <div class="costume-overlay costume-${costumeIdx}" aria-hidden="true"></div>
              ${photoHtml}
              <div class="aura-glow"></div>
              <span class="corner-web" aria-hidden="true">🕸️</span>
            </div>
          </div>
          <div class="person-info">
            <div class="person-header-line">
              <div class="person-name">${this.escapeHtml(name)}</div>
              <span class="status-wisp status-${status}" title="Status: ${status}"></span>
            </div>
            <div class="person-device">
              <span class="device-icon">💻</span>
              <span>${this.escapeHtml(device)}</span>
            </div>
            <div class="person-days-tag">
              <span class="pumpkin-tag">🎃 ${daysText}</span>
            </div>
          </div>
        </div>
      `;
    }).join('');
  }

  // ==========================================================================
  // RENDER TOP ATTENDEES (High Coven Podium)
  // ==========================================================================
  renderTopAttendees(attendees, weekStart, weekEnd) {
    if (!this.topAttendeesSection) return;

    const weekRangeEl = this.topAttendeesSection.querySelector('[data-week-range]');
    if (weekRangeEl && weekStart && weekEnd) {
      weekRangeEl.textContent = `${weekStart} to ${weekEnd}`;
    }

    let podiumContainer = this.topAttendeesSection.querySelector('.coven-podium-container');
    let empty = this.topAttendeesSection.querySelector('.empty-state');

    if (attendees.length === 0) {
      if (podiumContainer) podiumContainer.style.display = 'none';
      if (!empty) {
        empty = document.createElement('div');
        empty.className = 'empty-state';
        empty.textContent = 'No spells cast this week yet 🔮';
        this.topAttendeesSection.appendChild(empty);
      }
      empty.style.display = '';
      return;
    }

    if (empty) empty.style.display = 'none';

    if (!podiumContainer) {
      podiumContainer = document.createElement('div');
      podiumContainer.className = 'coven-podium-container';
      this.topAttendeesSection.appendChild(podiumContainer);
    }
    podiumContainer.style.display = '';

    const rankClasses = ['rank-first', 'rank-second', 'rank-third'];
    const rankEmojis = ['🥇', '🥈', '🥉'];
    const rankTitles = ['Grand Sorcerer', 'Arch-Phantom', 'Crypt Keeper'];

    podiumContainer.innerHTML = attendees.slice(0, 3).map((attendee, index) => {
      const name = this.formatDisplayName(attendee);
      const rawName = attendee.person || 'Unknown';
      const initial = rawName.trim().charAt(0).toUpperCase() || '?';
      const days = attendee.days || 1;
      const daysText = `${days} ${days === 1 ? 'day' : 'days'}`;

      let photoHtml = '';
      if (attendee.image_url) {
        photoHtml = `
          <img class="podium-photo" src="${this.escapeHtml(attendee.image_url)}" alt="${this.escapeHtml(rawName)}" onerror="this.style.display='none'; this.nextElementSibling.style.display='flex';"/>
          <div class="podium-initials" style="display:none;">${initial}</div>
        `;
      } else {
        photoHtml = `<div class="podium-initials">${initial}</div>`;
      }

      return `
        <div class="podium-card ${rankClasses[index] || ''}">
          <div class="podium-rank-badge">
            <span class="rank-medal">${rankEmojis[index] || '⭐'}</span>
          </div>
          <div class="podium-portrait-frame">
            ${photoHtml}
            <div class="podium-halo"></div>
          </div>
          <div class="podium-info">
            <div class="podium-name">${this.escapeHtml(name)}</div>
            <div class="podium-title">${rankTitles[index] || 'Coven Member'}</div>
            <div class="podium-days">
              <span class="flame-icon">🔥</span>
              <strong>${days}</strong> ${days === 1 ? 'day' : 'days'}
            </div>
          </div>
        </div>
      `;
    }).join('');
  }

  // ==========================================================================
  // RENDER DEPARTED SPIRITS (Graveyard - Earlier Today)
  // ==========================================================================
  renderDepartedSpirits(absentPeople) {
    if (!this.recentSection) return;

    let graveyard = this.recentSection.querySelector('.departed-graveyard');
    let empty = this.recentSection.querySelector('.empty-state');

    if (absentPeople.length === 0) {
      if (graveyard) graveyard.style.display = 'none';
      if (!empty) {
        empty = document.createElement('div');
        empty.className = 'empty-state';
        empty.textContent = 'No spirits have departed into the shadows yet 👻';
        this.recentSection.appendChild(empty);
      }
      empty.style.display = '';
      return;
    }

    if (empty) empty.style.display = 'none';

    if (!graveyard) {
      graveyard = document.createElement('div');
      graveyard.className = 'recent-list departed-graveyard';
      this.recentSection.appendChild(graveyard);
    }
    graveyard.style.display = '';

    graveyard.innerHTML = absentPeople.slice(0, 8).map((person) => {
      const name = this.formatDisplayName(person);
      const rawName = person.person || 'Departed Soul';
      const initial = rawName.trim().charAt(0).toUpperCase() || '?';

      let photoHtml = '';
      if (person.image_url) {
        photoHtml = `
          <img class="ghost-photo" src="${this.escapeHtml(person.image_url)}" alt="${this.escapeHtml(rawName)}" onerror="this.style.display='none'; this.nextElementSibling.style.display='flex';"/>
          <div class="ghost-initials" style="display:none;">${initial}</div>
        `;
      } else {
        photoHtml = `<div class="ghost-initials">${initial}</div>`;
      }

      return `
        <div class="departed-tombstone">
          <div class="tombstone-top">
            <span class="rip-text">R.I.P</span>
          </div>
          <div class="tombstone-content">
            <div class="ghost-portrait">
              ${photoHtml}
            </div>
            <div class="departed-info">
              <div class="departed-name">${this.escapeHtml(name)}</div>
              <div class="departed-status">👻 Left the crypt</div>
            </div>
          </div>
        </div>
      `;
    }).join('');
  }

  // ==========================================================================
  // SPOOKY ARRIVALS DETECTION & TOAST
  // ==========================================================================
  checkNewArrivals(presentPeople) {
    const currentMacs = presentPeople.map(p => p.mac || p.person).filter(Boolean);

    if (this.previousPresentMacs !== null) {
      const arrivals = presentPeople.filter(p => !this.previousPresentMacs.includes(p.mac || p.person));
      if (arrivals.length > 0) {
        arrivals.forEach(person => {
          if (person.person && !person.person.startsWith('Anonymous')) {
            this.showArrivalToast(person);
            if (this.audioEnabled) {
              this.playSpookyChime();
            }
          }
        });
      }
    }

    this.previousPresentMacs = currentMacs;
  }

  showArrivalToast(person) {
    if (!this.toastContainer) return;

    const toast = document.createElement('div');
    toast.className = 'spooky-toast';

    const rawName = person.person || 'A wandering soul';
    const initial = rawName.trim().charAt(0).toUpperCase() || '?';

    let avatarHtml = '';
    if (person.image_url) {
      avatarHtml = `
        <img src="${this.escapeHtml(person.image_url)}" alt="${this.escapeHtml(rawName)}" onerror="this.style.display='none'; this.nextElementSibling.style.display='flex';">
        <div class="toast-fallback" style="display:none;">${initial}</div>
      `;
    } else {
      avatarHtml = `<div class="toast-fallback">${initial}</div>`;
    }

    toast.innerHTML = `
      <div class="toast-avatar">
        ${avatarHtml}
      </div>
      <div class="toast-message">
        🦇 <strong>${this.escapeHtml(rawName)}</strong> has entered the Haunted Office!
      </div>
    `;

    this.toastContainer.appendChild(toast);
    setTimeout(() => toast.remove(), 5000);
  }

  // ==========================================================================
  // WEB AUDIO SYNTHESIZED SPOOKY SOUNDS (Zero External Dependencies)
  // ==========================================================================
  setupAudio() {
    if (!this.soundToggleBtn) return;

    // Check stored state
    const saved = localStorage.getItem('spooky_audio_enabled');
    if (saved === 'true') {
      this.audioEnabled = true;
      this.soundToggleBtn.classList.add('active');
      this.soundToggleBtn.querySelector('.btn-icon').textContent = '🔊';
    }

    this.soundToggleBtn.addEventListener('click', () => {
      this.audioEnabled = !this.audioEnabled;
      localStorage.setItem('spooky_audio_enabled', String(this.audioEnabled));

      if (this.audioEnabled) {
        this.soundToggleBtn.classList.add('active');
        this.soundToggleBtn.querySelector('.btn-icon').textContent = '🔊';
        this.playSpookyChime();
      } else {
        this.soundToggleBtn.classList.remove('active');
        this.soundToggleBtn.querySelector('.btn-icon').textContent = '🔇';
      }
    });
  }

  getAudioContext() {
    if (!this.audioContext) {
      const AudioCtx = window.AudioContext || window.webkitAudioContext;
      if (AudioCtx) this.audioContext = new AudioCtx();
    }
    if (this.audioContext && this.audioContext.state === 'suspended') {
      this.audioContext.resume();
    }
    return this.audioContext;
  }

  playSpookyChime() {
    try {
      const ctx = this.getAudioContext();
      if (!ctx) return;

      const now = ctx.currentTime;
      // Synthesize a gothic organ / eerie chime chord: C# minor with vibrato
      const freqs = [138.59, 164.81, 207.65, 277.18]; // C#3, E3, G#3, C#4

      freqs.forEach((freq, idx) => {
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();

        osc.type = idx % 2 === 0 ? 'sine' : 'triangle';
        osc.frequency.setValueAtTime(freq, now);

        // Subtle spooky detune
        osc.detune.setValueAtTime((Math.random() - 0.5) * 15, now);

        gain.gain.setValueAtTime(0.01, now);
        gain.gain.exponentialRampToValueAtTime(0.06 / (idx + 1), now + 0.15);
        gain.gain.exponentialRampToValueAtTime(0.0001, now + 1.8);

        osc.connect(gain);
        gain.connect(ctx.destination);

        osc.start(now);
        osc.stop(now + 1.9);
      });
    } catch (e) {
      console.warn('Audio synthesis note failed:', e);
    }
  }

  // ==========================================================================
  // COSTUMES TOGGLE
  // ==========================================================================
  setupCostumeToggle() {
    if (!this.costumeToggleBtn) return;

    // Check stored state or default to true
    const saved = localStorage.getItem('spooky_costumes_enabled');
    this.costumesEnabled = saved !== 'false';

    if (this.costumesEnabled) {
      document.body.classList.add('show-costumes');
      this.costumeToggleBtn.classList.add('active');
    } else {
      document.body.classList.remove('show-costumes');
      this.costumeToggleBtn.classList.remove('active');
    }

    this.costumeToggleBtn.addEventListener('click', () => {
      this.costumesEnabled = !this.costumesEnabled;
      localStorage.setItem('spooky_costumes_enabled', String(this.costumesEnabled));

      if (this.costumesEnabled) {
        document.body.classList.add('show-costumes');
        this.costumeToggleBtn.classList.add('active');
      } else {
        document.body.classList.remove('show-costumes');
        this.costumeToggleBtn.classList.remove('active');
      }
    });
  }

  // ==========================================================================
  // AMBIENT FLYING BATS GENERATOR
  // ==========================================================================
  startAmbientBats() {
    if (!this.batsContainer) return;
    const prefersReducedMotion = window.matchMedia?.('(prefers-reduced-motion: reduce)').matches;
    if (prefersReducedMotion) return;

    const spawnBat = () => {
      const bat = document.createElement('div');
      bat.className = 'floating-bat';
      bat.textContent = Math.random() > 0.4 ? '🦇' : '🎃';

      const duration = 12 + Math.random() * 14;
      const startY = 40 + Math.random() * (window.innerHeight * 0.45);
      const scale = 0.6 + Math.random() * 0.6;

      bat.style.setProperty('--start-y', `${startY}px`);
      bat.style.setProperty('--scale', scale);
      bat.style.animationDuration = `${duration}s`;

      this.batsContainer.appendChild(bat);

      setTimeout(() => bat.remove(), duration * 1000);
    };

    // Initial batch
    for (let i = 0; i < 3; i++) {
      setTimeout(spawnBat, i * 3500);
    }

    // Recurring spawn
    setInterval(spawnBat, 8000);
  }

  // ==========================================================================
  // REGISTRATION MODAL
  // ==========================================================================
  setupRegistrationModal() {
    const modal = document.getElementById('registrationModal');
    const openBtn = document.getElementById('openRegistrationBtn');
    const closeBtn = document.getElementById('closeRegistrationBtn');
    const overlay = modal?.querySelector('.modal-overlay');

    if (!modal) return;

    const openModal = () => {
      modal.classList.add('is-open');
      modal.setAttribute('aria-hidden', 'false');
      document.body.classList.add('modal-open');

      if (typeof loadDeviceInfo === 'function') {
        loadDeviceInfo();
      }
      if (typeof initializeRegistration === 'function') {
        initializeRegistration();
      }
    };

    const closeModal = () => {
      modal.classList.remove('is-open');
      modal.setAttribute('aria-hidden', 'true');
      document.body.classList.remove('modal-open');
    };

    if (openBtn) openBtn.addEventListener('click', openModal);
    if (closeBtn) closeBtn.addEventListener('click', closeModal);
    if (overlay) overlay.addEventListener('click', closeModal);

    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && modal.classList.contains('is-open')) {
        closeModal();
      }
    });
  }

  // ==========================================================================
  // HELPERS
  // ==========================================================================
  formatDisplayName(person) {
    if (!person) return 'Unknown Spirit';
    const name = person.person || 'Unknown Spirit';
    return person.medal ? `${name} ${person.medal}` : name;
  }

  escapeHtml(str) {
    if (!str) return '';
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }
}

document.addEventListener('DOMContentLoaded', () => {
  window.halloweenDashboard = new HalloweenDashboard();
});
