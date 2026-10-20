class HalloweenDashboard {
  constructor() {
    this.refreshInterval = 5000;
    this.track = document.getElementById('floorTrack');
    this.floorWindow = document.getElementById('floorWindow');
    this.presentCount = document.getElementById('presentCount');
    this.floorIndicator = document.getElementById('floorIndicator');
    this.shortcutHint = document.getElementById('shortcutHint');
    this.previousButton = document.getElementById('previousFloor');
    this.nextButton = document.getElementById('nextFloor');
    this.currentFloor = 0;
    this.people = [];
    this.peopleKey = null;
    this.hasRendered = false;
    this.previewActive = false;
    this.previewOriginFloor = null;
    this.previewUpperWall = null;
    this.autoFloorDelay = 20000;
    this.autoFloorDirection = 1;
    this.autoFloorTimer = null;
    this.stairRise = this.getStairRise();
    this.floorCapacity = this.getFloorCapacity();
    this.scrollFrame = null;
    this.floorScrollFrame = null;

    if (typeof initializeTimezone === 'function') initializeTimezone();
    this.setupRegistrationModal();
    this.setupNavigation();
    this.startAutoFloorScroll();
    this.startAmbientBats();
    this.startWitchCackle();
    if (typeof loadDeviceInfo === 'function') loadDeviceInfo();

    if (!window.FIREBASE_MODE) {
      this.fetchDashboardData();
      this.pollTimer = window.setInterval(() => this.fetchDashboardData(), this.refreshInterval);
    }
  }

  getFloorCapacity() {
    return 7;
  }

  setupNavigation() {
    this.previousButton?.addEventListener('click', () => {
      this.goToFloor(this.currentFloor - 1);
      this.resetAutoFloorScroll();
    });
    this.nextButton?.addEventListener('click', () => {
      this.goToFloor(this.currentFloor + 1);
      this.resetAutoFloorScroll();
    });

    this.floorWindow?.addEventListener('scroll', () => {
      if (this.scrollFrame) cancelAnimationFrame(this.scrollFrame);
      this.scrollFrame = requestAnimationFrame(() => this.syncNavigationToScroll());
    }, { passive: true });
    this.floorWindow?.addEventListener('wheel', event => {
      this.cancelFloorScroll();
      this.resetAutoFloorScroll();
      if (Math.abs(event.deltaY) > Math.abs(event.deltaX)) {
        event.preventDefault();
        this.floorWindow.scrollLeft += event.deltaY;
      }
    }, { passive: false });
    this.floorWindow?.addEventListener('pointerdown', () => {
      this.cancelFloorScroll();
      this.resetAutoFloorScroll();
    }, { passive: true });

    this.floorWindow?.addEventListener('keydown', event => {
      if (event.key === 'ArrowRight') {
        event.preventDefault();
        this.goToFloor(this.currentFloor + 1);
        this.resetAutoFloorScroll();
      } else if (event.key === 'ArrowLeft') {
        event.preventDefault();
        this.goToFloor(this.currentFloor - 1);
        this.resetAutoFloorScroll();
      }
    });

    document.addEventListener('keydown', event => {
      if (event.altKey || event.ctrlKey || event.metaKey) return;
      if (event.target.matches('input, textarea, select, [contenteditable="true"]')) return;
      if (event.key.toLowerCase() === 'l') {
        event.preventDefault();
        this.toggleStairPreview();
        this.resetAutoFloorScroll();
      } else if (event.key.toLowerCase() === 'b') {
        this.sendBatPack?.();
      } else if (event.key === 'Escape' && this.previewActive) {
        this.returnToStairOrigin();
      }
    });

    window.addEventListener('resize', () => {
      const capacity = this.getFloorCapacity();
      this.floorCapacity = capacity;
      this.stairRise = this.getStairRise();
      if (this.hasRendered) this.renderFloors(this.people, this.currentFloor);
    }, { passive: true });
  }

  getStairRise() {
    return Math.min(430, Math.max(140, Math.round(window.innerWidth * 0.21)));
  }

  startAutoFloorScroll() {
    if (this.autoFloorTimer) window.clearInterval(this.autoFloorTimer);
    this.autoFloorTimer = window.setInterval(() => this.performAutoFloorScroll(), this.autoFloorDelay);
  }

  resetAutoFloorScroll() {
    this.startAutoFloorScroll();
  }

  performAutoFloorScroll() {
    if (document.hidden || this.previewActive) return;
    const floorCount = this.track?.querySelectorAll('[data-floor-index]').length || 1;
    if (floorCount <= 1) return;

    let nextFloor = this.currentFloor + this.autoFloorDirection;
    if (nextFloor < 0 || nextFloor >= floorCount) {
      this.autoFloorDirection *= -1;
      nextFloor = this.currentFloor + this.autoFloorDirection;
    }
    this.goToFloor(nextFloor);
  }

  async fetchDashboardData() {
    try {
      const response = await fetch('/api/dashboard');
      if (!response.ok) return;
      this.updateDashboard(await response.json());
    } catch (error) {
      console.warn('[Haunted House] Presence refresh failed:', error);
    }
  }

  updateDashboard(data) {
    if (!data) return;
    const people = (Array.isArray(data.mapped_present) ? data.mapped_present : [])
      .slice()
      .sort((a, b) => {
        const nameOrder = String(a?.person ?? '').localeCompare(String(b?.person ?? ''));
        return nameOrder || String(a?.mac ?? '').localeCompare(String(b?.mac ?? ''));
      });
    this.people = people;
    if (this.presentCount) this.presentCount.textContent = data.present_count ?? people.length;
    this.updateClock(data.now);
    this.renderWeeklyRanking(data.top_attendees);
    const peopleKey = JSON.stringify(people.map(person => [person?.person, person?.medal, person?.status, person?.image_url, person?.mac]));
    if (this.hasRendered && peopleKey === this.peopleKey) return;
    this.peopleKey = peopleKey;
    this.renderFloors(people, this.currentFloor, this.hasRendered);
  }

  renderWeeklyRanking(attendees) {
    const ranking = document.querySelector('#weeklyRanking ol');
    if (!ranking) return;
    if (!Array.isArray(attendees) || attendees.length === 0) {
      ranking.innerHTML = '<li class="weekly-ranking-empty">No standings yet</li>';
      return;
    }
    const rankMarks = ['♛', '✦', '✧'];
    ranking.innerHTML = attendees.slice(0, 3).map((attendee, index) => {
      const name = [attendee?.person, attendee?.medal].filter(Boolean).join(' ');
      const days = Number(attendee?.days) || 0;
      return `<li><span class="weekly-rank-mark" aria-label="Rank ${index + 1}">${rankMarks[index]}</span><span class="weekly-attendee-name" title="${this.escapeHtml(name)}">${this.escapeHtml(name || 'Unknown spirit')}</span><span class="weekly-attendance-days">${days}d</span></li>`;
    }).join('');
  }

  updateClock(utcNow) {
    const clock = document.getElementById('currentTime');
    if (!clock || !utcNow) return;
    clock.dataset.utc = utcNow;
    const normalizedUtc = /(?:Z|[+-]\d{2}:?\d{2})$/i.test(utcNow) ? utcNow : `${utcNow}Z`;
    const date = new Date(normalizedUtc);
    if (typeof formatLocalTime === 'function') {
      const formatted = formatLocalTime(utcNow);
      const match = formatted.match(/\b\d{1,2}:\d{2}\b/);
      if (match) clock.textContent = match[0];
    } else {
      clock.textContent = new Intl.DateTimeFormat(undefined, { hour: '2-digit', minute: '2-digit' }).format(date);
    }
    const dateEl = document.getElementById('currentDate');
    if (dateEl && !Number.isNaN(date.getTime())) {
      dateEl.textContent = new Intl.DateTimeFormat(undefined, { weekday: 'long', month: 'long', day: 'numeric' }).format(date);
    }
  }

  renderFloors(people, requestedFloor = 0, preserveScroll = false) {
    if (!this.track || !this.floorWindow) return;
    this.cancelFloorScroll();
    const previousScrollLeft = this.floorWindow.scrollLeft;
    const previousScrollTop = this.floorWindow.scrollTop;
    const pages = [];
    for (let start = 0; start < people.length; start += this.floorCapacity) {
      pages.push(people.slice(start, start + this.floorCapacity));
    }
    if (pages.length === 0) pages.push([]);
    // Keep the next landing and stair run visible even before the second floor
    // has residents. This is a real, empty floor that L can scroll to.
    if (pages.length === 1) pages.push([]);

    this.stairRise = this.getStairRise();
    this.track.style.setProperty('--floor-rise-total', `${(pages.length - 1) * this.stairRise}px`);
    this.track.style.setProperty('--stair-half-rise', `${Math.round(this.stairRise / 2)}px`);
    this.currentFloor = Math.max(0, Math.min(requestedFloor, pages.length - 1));
    this.track.innerHTML = pages.map((floorPeople, floorIndex) => {
      const floorTitle = floorIndex === 0 ? 'Ground floor' : this.floorName(floorIndex);
      const wallRise = (pages.length - 1 - floorIndex) * this.stairRise;
      const portraits = floorPeople.length
        ? floorPeople.map((person, index) => this.renderPortrait(person, floorIndex * this.floorCapacity + index)).join('')
        : '<div class="empty-gallery"><span aria-hidden="true">🕯</span><h3>The house is quiet</h3><p>When someone arrives, their portrait will appear here.</p></div>';
      const sconces = Array.from({ length: 2 }, (_, index) => `
        <span class="candle-sconce${index === 0 ? ' is-lit' : ''}">
          <img src="/img/halloween/haunted-house/candle-sconce.png" alt="">
        </span>`).join('');
      const wall = `
        <section class="floor-wall" data-floor-index="${floorIndex}" style="--panel-rise:${wallRise}px" aria-label="${this.escapeHtml(floorTitle)} portraits">
          <div class="portrait-grid">${portraits}</div>
          <div class="candle-row" aria-hidden="true">${sconces}</div>
          <img class="wall-guardrail" src="/img/halloween/haunted-house/wall-rail.png" alt="" aria-hidden="true">
          <div class="floor-plaque"><span>✦</span><span class="floor-label">${this.escapeHtml(floorTitle)}</span><span>✦</span></div>
        </section>`;
      const stairRise = (pages.length - 1 - floorIndex - 0.5) * this.stairRise;
      const stairs = floorIndex < pages.length - 1 ? this.renderStairwell(this.floorName(floorIndex + 1), false, stairRise) : '';
      return wall + stairs;
    }).join('');

    this.hasRendered = true;
    this.previewActive = false;
    this.previewOriginFloor = null;
    this.previewUpperWall = null;
    this.floorWindow.classList.remove('previewing');
    this.updateNavigation();
    if (preserveScroll) {
      this.floorWindow.scrollTo({ left: Math.min(previousScrollLeft, this.floorWindow.scrollWidth - this.floorWindow.clientWidth), top: previousScrollTop, behavior: 'auto' });
      this.syncNavigationToScroll();
    } else {
      const activeWall = this.track.querySelector(`[data-floor-index="${this.currentFloor}"]`);
      this.floorWindow.scrollTo({ left: activeWall?.offsetLeft || 0, top: this.getPanelRise(activeWall), behavior: 'auto' });
    }
  }

  renderPortrait(person, index) {
    const rawName = person?.person || 'Unknown Spirit';
    const name = person?.medal ? `${rawName} ${person.medal}` : rawName;
    const status = person?.status === 'active' ? 'active' : 'inactive';
    const frames = ['portrait-frame-autumn.png', 'portrait-frame-pumpkin.png', 'portrait-frame-moon.png', 'portrait-frame-ivy.png'];
    const frame = frames[index % frames.length];
    const image = person?.image_url
      ? `<img class="portrait-photo" src="${this.escapeHtml(person.image_url)}" alt="Portrait of ${this.escapeHtml(rawName)}" loading="eager" decoding="async" onerror="this.hidden=true;this.nextElementSibling.hidden=false"><span class="portrait-initial" hidden>${this.escapeHtml(rawName.trim().charAt(0).toUpperCase() || '?')}</span>`
      : `<span class="portrait-initial">${this.escapeHtml(rawName.trim().charAt(0).toUpperCase() || '?')}</span>`;

    return `
      <article class="portrait-card" title="${this.escapeHtml(name)}">
        <div class="portrait-frame">
          ${image}
          <img class="frame-art" src="/img/halloween/haunted-house/${frame}" alt="" aria-hidden="true">
          <span class="portrait-status status-${status}" title="${status === 'active' ? 'At the office' : 'Away'}"></span>
        </div>
        <div class="portrait-caption">${this.escapeHtml(name)}</div>
      </article>`;
  }

  syncNavigationToScroll() {
    const walls = [...(this.track?.querySelectorAll('[data-floor-index]') || [])];
    if (!walls.length) return;
    const left = this.floorWindow.scrollLeft;
    let nearest = 0;
    let distance = Infinity;
    walls.forEach((wall, index) => {
      const nextDistance = Math.abs(wall.offsetLeft - left);
      if (nextDistance < distance) {
        distance = nextDistance;
        nearest = index;
      }
    });
    const panels = [...(this.track?.children || [])];
    let lowerPanel = panels[0];
    let upperPanel = panels[panels.length - 1];
    for (let index = 0; index < panels.length - 1; index += 1) {
      if (left >= panels[index].offsetLeft && left < panels[index + 1].offsetLeft) {
        lowerPanel = panels[index];
        upperPanel = panels[index + 1];
        break;
      }
    }
    const span = Math.max(1, upperPanel.offsetLeft - lowerPanel.offsetLeft);
    const progress = Math.max(0, Math.min(1, (left - lowerPanel.offsetLeft) / span));
    const lowerRise = this.getPanelRise(lowerPanel);
    const upperRise = this.getPanelRise(upperPanel);
    const nextTop = lowerRise + (upperRise - lowerRise) * progress;
    if (Math.abs(this.floorWindow.scrollTop - nextTop) > 1) this.floorWindow.scrollTop = nextTop;

    if (this.previewUpperWall && left >= this.previewUpperWall.offsetLeft - 1) {
      this.previewActive = true;
      this.currentFloor = this.previewOriginFloor ?? 0;
      this.updateNavigation();
      return;
    }

    const nearestWall = walls[nearest];
    const stairPanel = lowerPanel.classList.contains('stairwell-panel') ? lowerPanel : upperPanel.classList.contains('stairwell-panel') ? upperPanel : null;
    if (stairPanel && left >= stairPanel.offsetLeft && left < stairPanel.offsetLeft + stairPanel.offsetWidth * 0.72) {
      if (!this.previewActive) this.previewOriginFloor = Number(stairPanel.previousElementSibling?.dataset.floorIndex ?? nearest);
      this.previewActive = true;
      this.currentFloor = this.previewOriginFloor ?? nearest;
    } else {
      this.previewActive = false;
      this.previewOriginFloor = null;
      this.currentFloor = nearest;
    }
    this.updateNavigation();
  }

  goToFloor(index) {
    const walls = this.track?.querySelectorAll('[data-floor-index]');
    if (!walls?.length) return;
    const next = Math.max(0, Math.min(index, walls.length - 1));
    this.currentFloor = next;
    this.previewActive = false;
    this.previewOriginFloor = null;
    this.updateNavigation();
    this.animateFloorScroll(walls[next]);
  }

  cancelFloorScroll() {
    if (this.floorScrollFrame) cancelAnimationFrame(this.floorScrollFrame);
    this.floorScrollFrame = null;
  }

  animateFloorScroll(targetWall) {
    this.cancelFloorScroll();
    const startLeft = this.floorWindow.scrollLeft;
    const startTop = this.floorWindow.scrollTop;
    const targetLeft = targetWall.offsetLeft;
    const targetTop = this.getPanelRise(targetWall);
    const distance = Math.abs(targetLeft - startLeft);
    const duration = Math.min(1650, Math.max(850, distance / Math.max(1, window.innerWidth) * 1100));
    let startedAt = null;

    const step = timestamp => {
      if (startedAt === null) startedAt = timestamp;
      const progress = Math.min(1, (timestamp - startedAt) / duration);
      const eased = progress < 0.5
        ? 4 * progress * progress * progress
        : 1 - Math.pow(-2 * progress + 2, 3) / 2;
      this.floorWindow.scrollLeft = startLeft + (targetLeft - startLeft) * eased;
      this.floorWindow.scrollTop = startTop + (targetTop - startTop) * eased;
      if (progress < 1) {
        this.floorScrollFrame = requestAnimationFrame(step);
      } else {
        this.floorScrollFrame = null;
        this.floorWindow.scrollLeft = targetLeft;
        this.floorWindow.scrollTop = targetTop;
      }
    };

    this.floorScrollFrame = requestAnimationFrame(step);
  }

  updateNavigation() {
    const floorCount = this.track?.querySelectorAll('[data-floor-index]').length || 1;
    if (this.previousButton) this.previousButton.disabled = this.currentFloor <= 0;
    if (this.nextButton) this.nextButton.disabled = this.currentFloor >= floorCount - 1;
    const onUpperFloorPreview = this.previewUpperWall && this.floorWindow.scrollLeft >= this.previewUpperWall.offsetLeft - 1;
    if (this.floorIndicator) this.floorIndicator.textContent = this.previewActive ? (onUpperFloorPreview ? 'Upstairs preview' : 'Stair landing') : this.floorName(this.currentFloor);
    if (this.shortcutHint) this.shortcutHint.textContent = 'L: climb stairs';
  }

  getPanelRise(panel) {
    return Number.parseFloat(panel?.style.getPropertyValue('--panel-rise')) || 0;
  }

  renderStairwell(nextFloor, preview = false, panelRise = 0) {
    return `
      <div class="stairwell-panel${preview ? ' stairwell-preview' : ''}" style="--panel-rise:${panelRise}px"${preview ? ' data-stair-preview="true"' : ''} aria-hidden="true">
        <div class="stairwell-note"><span>${preview ? 'Preview' : 'Continue upstairs'}</span><strong>${this.escapeHtml(nextFloor)}</strong></div>
        <img class="stairwell-art" src="/img/halloween/haunted-house/stair-handrail.png" alt="">
      </div>`;
  }

  toggleStairPreview() {
    const nextWall = this.track?.querySelector(`[data-floor-index="${this.currentFloor + 1}"]`);
    if (nextWall) {
      this.goToFloor(this.currentFloor + 1);
      return;
    }
  }

  returnToStairOrigin() {
    if (this.previewUpperWall) {
      this.previewUpperWall.remove();
      this.previewUpperWall = null;
      this.track.querySelector('[data-stair-preview="true"]')?.remove();
      this.track.style.setProperty('--floor-rise-total', '0px');
      const wall = this.track.querySelector('[data-floor-index="0"]');
      wall?.style.setProperty('--panel-rise', '0px');
    }
    const returnFloor = this.previewOriginFloor ?? this.currentFloor;
    this.previewActive = false;
    this.previewOriginFloor = null;
    this.floorWindow.classList.remove('previewing');
    this.goToFloor(returnFloor);
  }

  startAmbientBats() {
    const flock = document.getElementById('batFlock');
    if (!flock || window.matchMedia?.('(prefers-reduced-motion: reduce)').matches) return;
    this.batSound = new Audio('/audio/bat-fly.mp3');
    this.batSound.preload = 'auto';
    this.batSound.volume = 0.55;
    const playBatSound = () => {
      const sound = this.batSound;
      if (!sound) return;
      try { sound.currentTime = 0; } catch (error) { /* not seekable yet */ }
      const played = sound.play();
      if (played?.catch) {
        played.catch(() => {
          const retry = () => {
            document.removeEventListener('pointerdown', retry);
            document.removeEventListener('keydown', retry);
            try { sound.currentTime = 0; } catch (error) { /* ignore */ }
            sound.play().catch(() => {});
          };
          document.addEventListener('pointerdown', retry);
          document.addEventListener('keydown', retry);
        });
      }
    };
    const sendBat = () => {
      const pack = document.createElement('div');
      const duration = 13 + Math.random() * 10;
      pack.className = 'bat-pack';
      pack.style.setProperty('--bat-height', `${8 + Math.random() * 43}%`);
      pack.style.setProperty('--bat-duration', `${duration}s`);
      const batCount = 4 + Math.floor(Math.random() * 4);
      for (let i = 0; i < batCount; i += 1) {
        const bat = document.createElement('img');
        bat.className = 'flying-bat';
        bat.src = '/img/halloween/bat.png';
        bat.alt = '';
        bat.setAttribute('aria-hidden', 'true');
        const column = Math.ceil(i / 2);
        const side = i === 0 ? 0 : (i % 2 === 0 ? -1 : 1);
        bat.style.setProperty('--bat-x', `${side * (44 + Math.random() * 42) - column * 32}px`);
        bat.style.setProperty('--bat-y', `${side * (28 + Math.random() * 32) + (Math.random() * 30 - 15)}px`);
        bat.style.setProperty('--bat-size', `${50 + Math.random() * 34}px`);
        bat.style.setProperty('--bat-flap', `${0.35 + Math.random() * 0.3}s`);
        pack.appendChild(bat);
      }
      flock.appendChild(pack);
      window.setTimeout(() => pack.remove(), duration * 1000);
      playBatSound();
    };
    this.sendBatPack = sendBat;
    const unlockAudio = () => {
      this.batSound?.play().then(() => {
        this.batSound.pause();
        this.batSound.currentTime = 0;
      }).catch(() => {});
      document.removeEventListener('pointerdown', unlockAudio);
      document.removeEventListener('keydown', unlockAudio);
    };
    document.addEventListener('pointerdown', unlockAudio);
    document.addEventListener('keydown', unlockAudio);
    window.setTimeout(sendBat, 30000);
    window.setInterval(sendBat, 240000);
  }

  startWitchCackle() {
    this.cackleSound = new Audio('/audio/witch-cackle.mp3');
    this.cackleSound.volume = 0.3;
    const playCackle = () => {
      this.cackleSound.currentTime = 0;
      this.cackleSound.play().catch(() => {});
    };
    const scheduleCackle = () => {
      const delay = (15 + Math.random() * 15) * 60 * 1000;
      window.setTimeout(() => {
        if (!document.hidden) playCackle();
        scheduleCackle();
      }, delay);
    };
    scheduleCackle();
  }

  floorName(index) {
    if (index === 0) return 'Ground floor';
    const ordinals = ['First', 'Second', 'Third', 'Fourth', 'Fifth', 'Sixth', 'Seventh', 'Eighth', 'Ninth'];
    return `${ordinals[index - 1] || `${index}th`} floor`;
  }

  setupRegistrationModal() {
    const modal = document.getElementById('registrationModal');
    if (!modal) return;
    const open = () => {
      modal.classList.add('is-open');
      modal.setAttribute('aria-hidden', 'false');
      document.body.classList.add('modal-open');
      if (typeof loadDeviceInfo === 'function') loadDeviceInfo();
      if (typeof initializeRegistration === 'function') initializeRegistration();
    };
    const close = () => {
      modal.classList.remove('is-open');
      modal.setAttribute('aria-hidden', 'true');
      document.body.classList.remove('modal-open');
    };
    document.getElementById('openRegistrationBtn')?.addEventListener('click', open);
    document.getElementById('closeRegistrationBtn')?.addEventListener('click', close);
    modal.querySelector('[data-close-modal]')?.addEventListener('click', close);
    document.addEventListener('keydown', event => {
      if (event.key === 'Escape' && modal.classList.contains('is-open')) close();
    });
  }

  escapeHtml(value) {
    return String(value ?? '').replace(/[&<>"']/g, char => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
    })[char]);
  }
}

document.addEventListener('DOMContentLoaded', () => {
  window.halloweenDashboard = new HalloweenDashboard();
});
