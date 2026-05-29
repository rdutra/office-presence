/**
 * Stickers Dashboard Logic - Authentic Two-Page Album Redesign
 */

class StickersDashboard {
  constructor() {
    this.stickersContainerLeft = document.getElementById('stickers-container-left');
    this.stickersContainerRight = document.getElementById('stickers-container-right');
    this.presentCountEl = document.getElementById('st-present-count');
    this.totalPeopleEl = document.getElementById('st-total-people');
    this.completionEl = document.getElementById('sticker-completion');
    this.standingsBody = document.getElementById('st-standings-body');
    this.bookEl = document.querySelector('.book');
    
    this.refreshInterval = 30000; // 30 seconds
    this.data = null;
    this.currentPage = 0;
    this.stickersPerPage = 16;
    this.isFlipping = false;
    
    // Auto-flip properties
    this.autoFlipTimer = null;
    this.autoFlipDelay = 20000; // 20 seconds
    this.autoFlipDirection = 1; // 1 for next, -1 for prev

    this.init();
  }

  normalizeName(name) {
    if (!name) return '';
    return name.toLowerCase()
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .trim();
  }

  init() {
    if (window.FIREBASE_MODE) {
      console.log("Stickers Dashboard running in Firebase mode");
    }

    this.fetchData();
    if (!window.FIREBASE_MODE) {
      setInterval(() => this.fetchData(), this.refreshInterval);
    }

    if (typeof initializeTimezone === 'function') {
      initializeTimezone();
    }

    this.setupRegistrationModal();
    this.updateRegistrationButtonText();
    this.setupNavigation();
    this.startAutoFlip();
    
    if (typeof loadDeviceInfo === 'function') {
      loadDeviceInfo();
    }
  }

  setupNavigation() {
    const prevBtn = document.getElementById('prev-page');
    const nextBtn = document.getElementById('next-page');

    if (prevBtn) prevBtn.addEventListener('click', () => {
      this.changePage(-1);
      this.resetAutoFlip();
    });
    
    if (nextBtn) nextBtn.addEventListener('click', () => {
      this.changePage(1);
      this.resetAutoFlip();
    });

    document.addEventListener('keydown', (e) => {
      if (e.key === 'ArrowLeft') {
        this.changePage(-1);
        this.resetAutoFlip();
      }
      if (e.key === 'ArrowRight') {
        this.changePage(1);
        this.resetAutoFlip();
      }
    });
  }

  startAutoFlip() {
    this.stopAutoFlip();
    this.autoFlipTimer = setInterval(() => {
      this.performAutoFlip();
    }, this.autoFlipDelay);
  }

  stopAutoFlip() {
    if (this.autoFlipTimer) {
      clearInterval(this.autoFlipTimer);
      this.autoFlipTimer = null;
    }
  }

  resetAutoFlip() {
    this.startAutoFlip();
  }

  performAutoFlip() {
    if (!this.data || this.isFlipping) return;

    const candidates = (this.data.mapped_all || [])
      .filter(p => p.person && !p.person.startsWith('Anonymous'));
    
    // Sort: Present first, then Recent, then alphabetical
    candidates.sort((a, b) => {
      if (a.present !== b.present) return a.present ? -1 : 1;
      if (a.recent !== b.recent) return a.recent ? -1 : 1;
      return a.person.localeCompare(b.person);
    });

    const totalPages = Math.ceil(candidates.length / this.stickersPerPage);
    if (totalPages <= 1) return;

    // Logic: Only auto-flip if the TARGET page has at least one present person
    let nextPossiblePage = this.currentPage + this.autoFlipDirection;
    
    // Reverse direction if at bounds
    if (nextPossiblePage >= totalPages || nextPossiblePage < 0) {
      this.autoFlipDirection *= -1;
      nextPossiblePage = this.currentPage + this.autoFlipDirection;
    }

    // Check if the target page has any present people
    const targetStart = nextPossiblePage * this.stickersPerPage;
    const targetSquad = candidates.slice(targetStart, targetStart + this.stickersPerPage);
    const hasPresentPeople = targetSquad.some(p => p.present);

    if (hasPresentPeople) {
      this.changePage(this.autoFlipDirection);
    } else {
      // If no present people ahead, and we were moving forward, reverse to go back
      if (this.autoFlipDirection === 1 && this.currentPage > 0) {
        this.autoFlipDirection = -1;
      }
    }
  }

  changePage(direction) {
    if (!this.data || this.isFlipping) return;
    
    const candidates = (this.data.mapped_all || [])
      .filter(p => p.person && !p.person.startsWith('Anonymous'));
    
    candidates.sort((a, b) => {
      if (a.present !== b.present) return a.present ? -1 : 1;
      if (a.recent !== b.recent) return a.recent ? -1 : 1;
      return a.person.localeCompare(b.person);
    });

    const totalPages = Math.ceil(candidates.length / this.stickersPerPage);
    const newPage = this.currentPage + direction;

    if (newPage >= 0 && newPage < totalPages) {
      const flipper = document.getElementById('page-flipper');
      const front = document.getElementById('flipper-front');
      const back = document.getElementById('flipper-back');
      const leftPage = document.querySelector('.left-page');
      const rightPage = document.querySelector('.right-page');
      const prevBtn = document.getElementById('prev-page');
      const nextBtn = document.getElementById('next-page');

      if (flipper && front && back) {
        this.isFlipping = true;
        if (prevBtn) prevBtn.classList.add('disabled');
        if (nextBtn) nextBtn.classList.add('disabled');

        // Prepare flipper
        if (direction > 0) {
          // Flip Next: Right page content moves to Left
          front.innerHTML = rightPage.innerHTML;
          this.currentPage = newPage;
          this.render(); // This updates the static pages to the new content
          back.innerHTML = leftPage.innerHTML;
          
          flipper.className = 'page-flipper active flip-next';
          setTimeout(() => flipper.classList.add('animate', 'flipping'), 50);
        } else {
          // Flip Prev: Left page content moves to Right
          front.innerHTML = leftPage.innerHTML;
          this.currentPage = newPage;
          this.render();
          back.innerHTML = rightPage.innerHTML;
          
          flipper.className = 'page-flipper active flip-prev';
          setTimeout(() => flipper.classList.add('animate', 'flipping'), 50);
        }

        setTimeout(() => {
          flipper.className = 'page-flipper';
          this.isFlipping = false;
          if (prevBtn) prevBtn.classList.remove('disabled');
          if (nextBtn) nextBtn.classList.remove('disabled');
        }, 650);
      } else {
        this.currentPage = newPage;
        this.render();
      }
    }
  }

  setupRegistrationModal() {
    const modal = document.getElementById("registrationModal");
    const openBtn = document.getElementById("openRegistrationBtn");
    const closeBtn = document.getElementById("closeRegistrationBtn");
    const overlay = modal?.querySelector(".modal-overlay");

    if (!modal) return;

    this.openModal = () => {
      modal.classList.add("is-open");
      modal.setAttribute("aria-hidden", "false");
      document.body.classList.add("modal-open");

      if (typeof loadDeviceInfo === "function") {
        loadDeviceInfo();
      }
    };

    this.closeModal = () => {
      modal.classList.remove("is-open");
      modal.setAttribute("aria-hidden", "true");
      document.body.classList.remove("modal-open");
    };

    if (openBtn) {
      openBtn.addEventListener("click", () => this.openModal());
    }
    
    if (closeBtn) closeBtn.addEventListener("click", () => this.closeModal());
    if (overlay) overlay.addEventListener("click", () => this.closeModal());

    document.addEventListener("keydown", (event) => {
      if (event.key === "Escape" && modal.classList.contains("is-open")) {
        this.closeModal();
      }
    });
  }

  async updateRegistrationButtonText() {
    const openBtn = document.getElementById('openRegistrationBtn');
    if (!openBtn) return;

    try {
      const response = await fetch('/api/my-device');
      const data = await response.json();

      if (data.registered) {
        openBtn.innerText = 'ACTUALIZAR FIGURITA';
      }
    } catch (error) {
      console.error('Error checking registration status:', error);
    }
  }

  async fetchData() {
    try {
      const response = await fetch('/api/dashboard');
      if (!response.ok) throw new Error('Failed to fetch dashboard data');
      this.data = await response.json();
      this.render();
    } catch (error) {
      console.error('Error fetching dashboard data:', error);
    }
  }

  render() {
    if (!this.data) return;

    this.renderStats();
    this.renderStickers();
    this.renderStandings();
    this.updateCompletion();
  }

  renderStats() {
    if (this.presentCountEl) this.presentCountEl.textContent = this.data.present_count;
    if (this.totalPeopleEl) this.totalPeopleEl.textContent = this.data.total_people;
  }

  createStickerElement(person, index, isPresent) {
    const slotEl = document.createElement('div');
    slotEl.className = 'sticker-slot';
    slotEl.innerHTML = `<div class="number">${index + 1}</div><div class="slot-name">${person.person}</div>`;

    const isRecent = person.recent;

    if (isPresent || isRecent) {
      const stickerEl = document.createElement('div');
      stickerEl.className = `sticker ${isPresent ? 'present' : 'recent'}`;
      
      const rotation = (Math.random() * 6 - 3).toFixed(1);
      stickerEl.style.transform = `rotate(${rotation}deg)`;
      if (isPresent) {
        stickerEl.style.setProperty('--shine-delay', `${(Math.random() * 4).toFixed(1)}s`);
        
        // Add random foil color
        const hues = [0, 45, 90, 135, 180, 225, 270, 315];
        const hue = hues[Math.floor(Math.random() * hues.length)];
        stickerEl.style.setProperty('--foil-hue', hue);
        stickerEl.style.setProperty('--foil-color', `hsl(${hue}, 80%, 90%)`);
        stickerEl.style.setProperty('--foil-color-bright', `hsl(${hue}, 100%, 95%)`);
        stickerEl.style.setProperty('--foil-color-dark', `hsl(${hue}, 70%, 40%)`);
      }
      stickerEl.onclick = () => this.openModal();

      const silhouetteSvg = `
        <div class="sticker-silhouette">
          <svg viewBox="0 0 100 100" preserveAspectRatio="xMidYMid meet">
            <circle cx="50" cy="35" r="20" fill="#ddd" />
            <path d="M20 90 Q20 60 50 60 Q80 60 80 90 Z" fill="#ddd" />
            <text x="50" y="55" font-family="Arial" font-size="30" font-weight="900" fill="#bbb" text-anchor="middle">?</text>
          </svg>
        </div>`;

      if (person.image_url) {
        const img = document.createElement('img');
        img.src = person.image_url;
        img.alt = person.person;
        img.addEventListener('error', function() {
          this.style.display = 'none';
          const sil = document.createElement('div');
          sil.className = 'sticker-silhouette';
          sil.innerHTML = silhouetteSvg;
          stickerEl.insertBefore(sil, stickerEl.firstChild);
        });
        stickerEl.appendChild(img);
        
        const info = document.createElement('div');
        info.className = 'sticker-info';
        const medal = person.medal ? `<div class="sticker-medal">${person.medal}</div>` : '';
        info.innerHTML = `<div class="sticker-name">${person.person}</div>${medal}`;
        stickerEl.appendChild(info);      } else {
        const medal = person.medal ? `<div class="sticker-medal">${person.medal}</div>` : '';
        stickerEl.innerHTML = `
          ${silhouetteSvg}
          <div class="sticker-info">
            <div class="sticker-name">${person.person}</div>${medal}
          </div>
        `;
      }
      slotEl.appendChild(stickerEl);
    } else {
      slotEl.style.cursor = 'pointer';
      slotEl.onclick = () => this.openModal();
    }
    return slotEl;
  }

  renderStickers() {
    if (!this.stickersContainerLeft || !this.stickersContainerRight) return;

    // 1. Get all candidates (non-anonymous)
    let candidates = (this.data.mapped_all || [])
      .filter(p => p.person && !p.person.startsWith('Anonymous'));

    // 2. Sort: Present first, then by name
    candidates.sort((a, b) => {
      if (a.present !== b.present) return a.present ? -1 : 1;
      if (a.recent !== b.recent) return a.recent ? -1 : 1;
      return a.person.localeCompare(b.person);
    });

    // 3. Slice for current page
    const start = this.currentPage * this.stickersPerPage;
    let squad = candidates.slice(start, start + this.stickersPerPage);

    // 4. If on the first page, shuffle the squad to spread active people (present + recent)
    if (this.currentPage === 0 && squad.length > 0) {
      const active = squad.filter(p => p.present || p.recent);
      const inactive = squad.filter(p => !p.present && !p.recent);
      
      const slots = new Array(16).fill(null);
      
      const getSlotIndex = (name, attempt = 0) => {
        let hash = 0;
        const seed = name + attempt;
        for (let i = 0; i < seed.length; i++) {
          hash = ((hash << 5) - hash) + seed.charCodeAt(i);
          hash |= 0;
        }
        return Math.abs(hash) % 16;
      };

      active.forEach(person => {
        let attempt = 0;
        let idx = getSlotIndex(person.person, attempt);
        while (slots[idx] !== null && attempt < 32) {
          attempt++;
          idx = getSlotIndex(person.person, attempt);
        }
        if (slots[idx] !== null) idx = slots.findIndex(s => s === null);
        slots[idx] = person;
      });

      inactive.forEach(person => {
        const idx = slots.findIndex(s => s === null);
        if (idx !== -1) slots[idx] = person;
      });

      squad = slots.filter(p => p !== null);
    }

    // 5. Update navigation buttons
    const prevBtn = document.getElementById('prev-page');
    const nextBtn = document.getElementById('next-page');
    const totalPages = Math.ceil(candidates.length / this.stickersPerPage);

    if (prevBtn) prevBtn.style.display = this.currentPage > 0 ? 'flex' : 'none';
    if (nextBtn) nextBtn.style.display = (this.currentPage < totalPages - 1) ? 'flex' : 'none';

    // 6. Update page numbers
    const leftPageNum = document.getElementById('left-page-num');
    const rightPageNum = document.getElementById('right-page-num');
    if (leftPageNum) leftPageNum.textContent = `PÁG ${24 + (this.currentPage * 2)}`;
    if (rightPageNum) rightPageNum.textContent = `PÁG ${25 + (this.currentPage * 2)}`;

    this.stickersContainerLeft.innerHTML = '';
    this.stickersContainerRight.innerHTML = '';
    
    if (squad.length === 0) {
      this.stickersContainerLeft.innerHTML = '<div class="loading-stickers">No hay jugadores.</div>';
      return;
    }

    const leftPagePeople = squad.slice(0, 8);
    const rightPagePeople = squad.slice(8);

    leftPagePeople.forEach((person, index) => {
      this.stickersContainerLeft.appendChild(this.createStickerElement(person, start + index, person.present));
    });

    rightPagePeople.forEach((person, index) => {
      this.stickersContainerRight.appendChild(this.createStickerElement(person, start + 8 + index, person.present));
    });
  }

  renderStandings() {
    if (!this.standingsBody || !this.data.top_attendees) return;

    this.standingsBody.innerHTML = '';
    this.data.top_attendees.slice(0, 10).forEach((attendee, index) => {
      const row = document.createElement('div');
      row.className = 'standing-row';
      row.innerHTML = `
        <span>${index + 1}. ${attendee.person}</span>
        <span>${attendee.days} PTS</span>
      `;
      this.standingsBody.appendChild(row);
    });
  }

  updateCompletion() {
    if (!this.completionEl || !this.data) return;
    const total = this.data.total_people || 1; 
    const present = this.data.present_count || 0;
    const percentage = Math.min(100, Math.round((present / total) * 100));
    this.completionEl.textContent = `${percentage}%`;
  }

  setupEasterEgg() {
    const bielsaContainer = document.getElementById('bielsa-easter-egg');
    if (!bielsaContainer) return;

    // Create audio object
    const toastyAudio = new Audio('/img/worldcup/toasty.mp3');
    let isRunning = false;

    const triggerToasty = () => {
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
    };

    const scheduleNextToasty = () => {
      // Random time between 3 and 10 minutes
      const minTime = 3 * 60 * 1000;
      const maxTime = 10 * 60 * 1000;
      const nextTime = Math.random() * (maxTime - minTime) + minTime;

      setTimeout(() => {
        triggerToasty();
        scheduleNextToasty();
      }, nextTime);
    };

    // Manual trigger with 'f' key
    document.addEventListener('keydown', (e) => {
      if (e.key.toLowerCase() === 'f') {
        triggerToasty();
      }
    });

    // Start random schedule
    scheduleNextToasty();
  }
}

document.addEventListener('DOMContentLoaded', () => {
  window.stickersDashboard = new StickersDashboard();
  window.stickersDashboard.setupEasterEgg();
});
