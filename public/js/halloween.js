// ==========================================================================
// THE HAUNTED OFFICE — HALLOWEEN DASHBOARD CLIENT SCRIPT (RADICAL REDESIGN)
// Boiling Cauldron • Git Webs • Animated Spiders • Big Portraits • Eerie SFX
// ==========================================================================

class HalloweenDashboard {
  constructor() {
    this.refreshInterval = 5000;
    this.pollTimer = null;
    this.ambientSoundTimer = null;
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
    this.triggerSpookBtn = document.getElementById('triggerSpookBtn');
    this.costumeToggleBtn = document.getElementById('costumeToggleBtn');
    this.batsContainer = document.getElementById('batsContainer');
    this.danglingSpider = document.getElementById('danglingSpider');
    this.cauldronStage = document.getElementById('cauldronStage');

    this.spookyRoles = [
      'High Sorcerer', 'Phantom Lead', 'Crypt Architect',
      'Witch of Quality', 'Necromancer', 'Werewolf Dev',
      'Shadow Weaver', 'Alchemist', 'Vampire Lord', 'Banshee Coder'
    ];

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

    // 4. Setup Audio & Periodic Creepy SFX
    this.setupAudio();

    // 5. Setup Interactive Elements (Dangling spider & cauldron)
    this.setupInteractivity();

    // 6. Start Background Ambient Flying Bats
    this.startAmbientBats();

    // 7. Device info
    if (typeof loadDeviceInfo === 'function') {
      loadDeviceInfo();
    }

    // 8. Polling
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

    // 2. Update stats cards (Cauldron + Altar Flasks)
    this.updateStats(data);

    // 3. Check for new arrivals (to trigger spooky arrival chime & toast)
    this.checkNewArrivals(data.mapped_present || []);

    // 4. Render Haunted Gallery (Big Portraits Grid)
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
    // 1. Cauldron Count
    const cauldronCountEl = document.querySelector('.cauldron-count');
    if (cauldronCountEl && data.present_count !== undefined) {
      cauldronCountEl.textContent = data.present_count;
    }

    // 2. Flask stats
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
      this.presentBadgeEl.textContent = `${data.present_count} in the crypt`;
    }

    // 3. Last week winner flask
    const winnerCard = document.querySelector('[data-stat="last-week-winner"]');
    if (winnerCard && data.last_week_winner) {
      const winner = data.last_week_winner;
      const nameEl = winnerCard.querySelector('.badge-name');
      const metaEl = winnerCard.querySelector('.badge-meta');
      const photoEl = winnerCard.querySelector('.winner-photo');
      const initialsEl = winnerCard.querySelector('.winner-initials-avatar');

      if (nameEl) nameEl.textContent = winner.person;
      if (metaEl) {
        metaEl.textContent = `${winner.days || 0} days`;
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
  // RENDER PRESENT PEOPLE (BIG PICTURES IN HAUNTED PORTRAIT GALLERY)
  // ==========================================================================
  renderPresentPeople(people) {
    if (!this.presentSection) return;

    let list = this.presentSection.querySelector('.people-list');
    let empty = this.presentSection.querySelector('.empty-state');

    if (people.length === 0) {
      if (list) list.style.display = 'none';
      if (!empty) {
        empty = document.createElement('div');
        empty.className = 'empty-state grand-empty-state';
        empty.innerHTML = `
          <div class="empty-ghost-graphic">👻</div>
          <div class="empty-title">The crypt is dead silent...</div>
          <div class="empty-desc">No souls have arrived yet! Grab a coffee and be the first to awaken the spirits ☕🕯️</div>
        `;
        this.presentSection.appendChild(empty);
      }
      empty.style.display = '';
      return;
    }

    if (empty) empty.style.display = 'none';

    if (!list) {
      list = document.createElement('div');
      list.className = 'people-list big-portraits-grid';
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
      const daysText = `${days} ${days === 1 ? 'day this week' : 'days this week'}`;
      const costumeIdx = idx % 6;
      const monsterIdx = idx % 8;
      const roleTitle = this.spookyRoles[idx % this.spookyRoles.length];

      let photoHtml = '';
      if (person.image_url) {
        photoHtml = `
          <img class="person-photo big-photo" src="${this.escapeHtml(person.image_url)}" alt="${this.escapeHtml(rawName)}" loading="lazy" onerror="this.style.display='none'; this.nextElementSibling.style.display='flex';"/>
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
        <div class="person-card hero-portrait-card status-${status}" data-mac="${this.escapeHtml(person.mac || '')}" data-person-name="${this.escapeHtml(rawName)}">
          <div class="portrait-container hero-portrait">
            <div class="vintage-frame hero-frame">
              <div class="costume-overlay costume-${costumeIdx}" aria-hidden="true"></div>
              ${photoHtml}
              <div class="aura-glow"></div>
              <span class="corner-web" aria-hidden="true">🕸️</span>
            </div>
            <div class="status-soul-flame status-${status}" title="Status: ${status}"></div>
          </div>
          <div class="person-info-compact">
            <h3 class="person-name-compact">${this.escapeHtml(name)}</h3>
            <div class="person-role-tag">${roleTitle}</div>
            <div class="person-device-line">
              <span class="device-icon">💻</span>
              <span class="device-text">${this.escapeHtml(device)}</span>
            </div>
            <div class="pumpkin-days-tag">🎃 ${days} ${days === 1 ? 'day' : 'days'}</div>
          </div>
        </div>
      `;
    }).join('');
  }

  // ==========================================================================
  // RENDER TOP ATTENDEES (High Council Podium)
  // ==========================================================================
  renderTopAttendees(attendees, weekStart, weekEnd) {
    if (!this.topAttendeesSection) return;

    const weekRangeEl = this.topAttendeesSection.querySelector('[data-week-range]');
    if (weekRangeEl && weekStart && weekEnd) {
      weekRangeEl.textContent = `${weekStart} to ${weekEnd}`;
    }

    let podiumContainer = this.topAttendeesSection.querySelector('.coven-podium-cards');
    let empty = this.topAttendeesSection.querySelector('.empty-state-compact');

    if (attendees.length === 0) {
      if (podiumContainer) podiumContainer.style.display = 'none';
      if (!empty) {
        empty = document.createElement('div');
        empty.className = 'empty-state-compact';
        empty.textContent = 'No spells cast yet 🔮';
        this.topAttendeesSection.appendChild(empty);
      }
      empty.style.display = '';
      return;
    }

    if (empty) empty.style.display = 'none';

    if (!podiumContainer) {
      podiumContainer = document.createElement('div');
      podiumContainer.className = 'coven-podium-cards compact-podium';
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
        <div class="podium-card-compact ${rankClasses[index] || ''}">
          <span class="podium-rank-emoji">${rankEmojis[index] || '⭐'}</span>
          <div class="podium-frame-compact">
            ${photoHtml}
          </div>
          <div class="podium-info-compact">
            <div class="podium-name-compact">${this.escapeHtml(name)}</div>
            <div class="podium-meta-compact">
              <span class="podium-title-text">${rankTitles[index] || 'Coven Member'}</span>
              <span class="flame-days">🔥 <strong>${days}</strong>d</span>
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

    let graveyard = this.recentSection.querySelector('.departed-graveyard-compact');
    let empty = this.recentSection.querySelector('.empty-state-compact');

    if (absentPeople.length === 0) {
      if (graveyard) graveyard.style.display = 'none';
      if (!empty) {
        empty = document.createElement('div');
        empty.className = 'empty-state-compact';
        empty.textContent = 'No spirits departed yet 👻';
        this.recentSection.appendChild(empty);
      }
      empty.style.display = '';
      return;
    }

    if (empty) empty.style.display = 'none';

    if (!graveyard) {
      graveyard = document.createElement('div');
      graveyard.className = 'recent-list departed-graveyard-compact';
      this.recentSection.appendChild(graveyard);
    }
    graveyard.style.display = '';

    graveyard.innerHTML = absentPeople.slice(0, 6).map((person) => {
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
        <div class="departed-tombstone-compact">
          <span class="rip-tag">RIP</span>
          <div class="ghost-portrait-compact">
            ${photoHtml}
          </div>
          <div class="departed-name-compact">${this.escapeHtml(name)}</div>
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
              this.playSpookyArrival();
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
  // PERIODIC CREEPY SOUNDS (Cackle, Creaking Door, Ghost, Thunder, Cauldron)
  // ==========================================================================
  setupAudio() {
    // Check saved state or default to true on interaction
    const saved = localStorage.getItem('spooky_audio_enabled');
    this.audioEnabled = saved !== 'false';

    this.updateSoundButtonUI();

    if (this.soundToggleBtn) {
      this.soundToggleBtn.addEventListener('click', () => {
        this.audioEnabled = !this.audioEnabled;
        localStorage.setItem('spooky_audio_enabled', String(this.audioEnabled));
        this.updateSoundButtonUI();

        if (this.audioEnabled) {
          this.playRandomSpookySound();
          this.startAmbientSoundLoop();
        } else {
          this.stopAmbientSoundLoop();
        }
      });
    }

    if (this.triggerSpookBtn) {
      this.triggerSpookBtn.addEventListener('click', () => {
        this.playRandomSpookySound();
      });
    }

    // Auto-unlock Web Audio on first click anywhere
    const unlockAudio = () => {
      this.getAudioContext();
      if (this.audioEnabled) {
        this.startAmbientSoundLoop();
      }
      document.body.removeEventListener('click', unlockAudio);
    };
    document.body.addEventListener('click', unlockAudio, { once: true });
  }

  updateSoundButtonUI() {
    if (!this.soundToggleBtn) return;
    const icon = this.soundToggleBtn.querySelector('.btn-icon');
    const label = this.soundToggleBtn.querySelector('.btn-label');
    if (this.audioEnabled) {
      this.soundToggleBtn.classList.add('active');
      if (icon) icon.textContent = '🔊';
      if (label) label.textContent = 'SFX: On';
    } else {
      this.soundToggleBtn.classList.remove('active');
      if (icon) icon.textContent = '🔇';
      if (label) label.textContent = 'SFX: Muted';
    }
  }

  startAmbientSoundLoop() {
    this.stopAmbientSoundLoop();
    // Trigger a random creepy sound every 40 to 80 seconds
    const scheduleNext = () => {
      const delay = 40000 + Math.random() * 40000;
      this.ambientSoundTimer = setTimeout(() => {
        if (this.audioEnabled) {
          this.playRandomSpookySound();
          scheduleNext();
        }
      }, delay);
    };
    scheduleNext();
  }

  stopAmbientSoundLoop() {
    if (this.ambientSoundTimer) {
      clearTimeout(this.ambientSoundTimer);
      this.ambientSoundTimer = null;
    }
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

  playRandomSpookySound() {
    const sounds = ['cackle', 'creak', 'ghost', 'thunder', 'cauldron'];
    const pick = sounds[Math.floor(Math.random() * sounds.length)];
    switch (pick) {
      case 'cackle':
        this.playWitchCackle();
        break;
      case 'creak':
        this.playCreakingDoor();
        break;
      case 'ghost':
        this.playGhostMoan();
        break;
      case 'thunder':
        this.playThunderCrash();
        break;
      case 'cauldron':
        this.playCauldronBubbles();
        break;
    }
  }

  // 1. Witch Cackle (Hehehe HAHAHA!)
  playWitchCackle() {
    try {
      const ctx = this.getAudioContext();
      if (!ctx) return;
      const now = ctx.currentTime;
      // Staccato cascading laughs
      const laughs = [
        { freq: 587.33, dur: 0.12, del: 0.0 }, // D5
        { freq: 698.46, dur: 0.14, del: 0.14 }, // F5
        { freq: 880.00, dur: 0.18, del: 0.30 }, // A5
        { freq: 1046.5, dur: 0.22, del: 0.50 }, // C6
        { freq: 987.77, dur: 0.20, del: 0.74 }, // B5
        { freq: 880.00, dur: 0.25, del: 0.96 }, // A5
        { freq: 659.25, dur: 0.35, del: 1.23 }  // E5
      ];

      laughs.forEach(l => {
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();
        osc.type = 'sawtooth';
        osc.frequency.setValueAtTime(l.freq, now + l.del);
        osc.frequency.exponentialRampToValueAtTime(l.freq * 0.85, now + l.del + l.dur);

        gain.gain.setValueAtTime(0.001, now + l.del);
        gain.gain.exponentialRampToValueAtTime(0.08, now + l.del + 0.03);
        gain.gain.exponentialRampToValueAtTime(0.001, now + l.del + l.dur);

        osc.connect(gain);
        gain.connect(ctx.destination);
        osc.start(now + l.del);
        osc.stop(now + l.del + l.dur);
      });
    } catch (e) {
      console.warn('Witch cackle sound error:', e);
    }
  }

  // 2. Creaking Door (Screeching rusty hinge and heavy thud)
  playCreakingDoor() {
    try {
      const ctx = this.getAudioContext();
      if (!ctx) return;
      const now = ctx.currentTime;

      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      const filter = ctx.createBiquadFilter();

      osc.type = 'sawtooth';
      filter.type = 'bandpass';
      filter.frequency.setValueAtTime(450, now);
      filter.Q.setValueAtTime(8, now);

      // Slow irregular frequency pitch jitter simulating friction
      osc.frequency.setValueAtTime(80, now);
      osc.frequency.linearRampToValueAtTime(140, now + 0.4);
      osc.frequency.linearRampToValueAtTime(95, now + 0.8);
      osc.frequency.linearRampToValueAtTime(160, now + 1.3);
      osc.frequency.linearRampToValueAtTime(70, now + 1.8);

      gain.gain.setValueAtTime(0.001, now);
      gain.gain.exponentialRampToValueAtTime(0.09, now + 0.3);
      gain.gain.exponentialRampToValueAtTime(0.01, now + 1.7);
      gain.gain.exponentialRampToValueAtTime(0.0001, now + 1.9);

      osc.connect(filter);
      filter.connect(gain);
      gain.connect(ctx.destination);

      osc.start(now);
      osc.stop(now + 1.95);
    } catch (e) {
      console.warn('Creaking door sound error:', e);
    }
  }

  // 3. Ghost Moan (Eerie phantom wail)
  playGhostMoan() {
    try {
      const ctx = this.getAudioContext();
      if (!ctx) return;
      const now = ctx.currentTime;

      const osc = ctx.createOscillator();
      const vibrato = ctx.createOscillator();
      const vibGain = ctx.createGain();
      const gain = ctx.createGain();

      osc.type = 'sine';
      vibrato.type = 'sine';
      vibrato.frequency.setValueAtTime(5.5, now);
      vibGain.gain.setValueAtTime(18, now);

      vibrato.connect(osc.frequency);

      // Pitch glide up and then trailing down
      osc.frequency.setValueAtTime(260, now);
      osc.frequency.exponentialRampToValueAtTime(520, now + 1.2);
      osc.frequency.exponentialRampToValueAtTime(180, now + 2.8);

      gain.gain.setValueAtTime(0.001, now);
      gain.gain.exponentialRampToValueAtTime(0.08, now + 0.8);
      gain.gain.exponentialRampToValueAtTime(0.0001, now + 2.85);

      osc.connect(gain);
      gain.connect(ctx.destination);

      vibrato.start(now);
      osc.start(now);
      vibrato.stop(now + 2.9);
      osc.stop(now + 2.9);
    } catch (e) {
      console.warn('Ghost moan sound error:', e);
    }
  }

  // 4. Thunder Crash & Roll
  playThunderCrash() {
    try {
      const ctx = this.getAudioContext();
      if (!ctx) return;
      const now = ctx.currentTime;

      // Flash background slightly
      document.body.style.filter = 'brightness(1.5) contrast(1.2)';
      setTimeout(() => { document.body.style.filter = ''; }, 120);

      const bufferSize = ctx.sampleRate * 2.5;
      const buffer = ctx.createBuffer(1, bufferSize, ctx.sampleRate);
      const output = buffer.getChannelData(0);
      for (let i = 0; i < bufferSize; i++) {
        output[i] = (Math.random() * 2 - 1) * Math.exp(-i / (ctx.sampleRate * 0.8));
      }

      const whiteNoise = ctx.createBufferSource();
      whiteNoise.buffer = buffer;

      const filter = ctx.createBiquadFilter();
      filter.type = 'lowpass';
      filter.frequency.setValueAtTime(280, now);
      filter.frequency.exponentialRampToValueAtTime(70, now + 2.2);

      const gain = ctx.createGain();
      gain.gain.setValueAtTime(0.18, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 2.4);

      whiteNoise.connect(filter);
      filter.connect(gain);
      gain.connect(ctx.destination);

      whiteNoise.start(now);
      whiteNoise.stop(now + 2.45);
    } catch (e) {
      console.warn('Thunder sound error:', e);
    }
  }

  // 5. Cauldron Bubbling
  playCauldronBubbles() {
    try {
      const ctx = this.getAudioContext();
      if (!ctx) return;
      const now = ctx.currentTime;

      for (let i = 0; i < 7; i++) {
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();
        const del = i * 0.16 + (Math.random() * 0.08);

        osc.type = 'sine';
        const startFreq = 400 + Math.random() * 300;
        osc.frequency.setValueAtTime(startFreq, now + del);
        osc.frequency.exponentialRampToValueAtTime(startFreq * 1.6, now + del + 0.09);

        gain.gain.setValueAtTime(0.001, now + del);
        gain.gain.exponentialRampToValueAtTime(0.06, now + del + 0.04);
        gain.gain.exponentialRampToValueAtTime(0.0001, now + del + 0.11);

        osc.connect(gain);
        gain.connect(ctx.destination);

        osc.start(now + del);
        osc.stop(now + del + 0.12);
      }
    } catch (e) {
      console.warn('Cauldron bubbles sound error:', e);
    }
  }

  // 6. Arrival Chime
  playSpookyArrival() {
    try {
      const ctx = this.getAudioContext();
      if (!ctx) return;
      const now = ctx.currentTime;
      const freqs = [138.59, 164.81, 207.65, 277.18];
      freqs.forEach((freq, idx) => {
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();
        osc.type = idx % 2 === 0 ? 'sine' : 'triangle';
        osc.frequency.setValueAtTime(freq, now);
        gain.gain.setValueAtTime(0.01, now);
        gain.gain.exponentialRampToValueAtTime(0.07 / (idx + 1), now + 0.12);
        gain.gain.exponentialRampToValueAtTime(0.0001, now + 1.8);
        osc.connect(gain);
        gain.connect(ctx.destination);
        osc.start(now);
        osc.stop(now + 1.9);
      });
    } catch (e) {
      console.warn('Arrival chime error:', e);
    }
  }

  // ==========================================================================
  // INTERACTIVE SPIDER & CAULDRON
  // ==========================================================================
  setupInteractivity() {
    // 1. Dangling Spider Click / Hover
    if (this.danglingSpider) {
      this.danglingSpider.addEventListener('click', () => {
        this.danglingSpider.classList.add('scurry');
        this.playCreakingDoor();
        setTimeout(() => {
          this.danglingSpider.classList.remove('scurry');
        }, 1200);
      });
    }

    // 2. Boiling Cauldron Click
    if (this.cauldronStage) {
      this.cauldronStage.addEventListener('click', () => {
        this.playCauldronBubbles();
        // Trigger temporary furious bubble animation
        const rim = this.cauldronStage.querySelector('.potion-surface');
        if (rim) {
          rim.style.filter = 'drop-shadow(0 0 25px #39ff14) brightness(1.5)';
          setTimeout(() => { rim.style.filter = ''; }, 1000);
        }
      });
    }
  }

  // ==========================================================================
  // COSTUMES TOGGLE
  // ==========================================================================
  setupCostumeToggle() {
    if (!this.costumeToggleBtn) return;
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

    for (let i = 0; i < 3; i++) {
      setTimeout(spawnBat, i * 3500);
    }
    setInterval(spawnBat, 8500);
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
