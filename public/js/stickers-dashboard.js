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
    
    this.refreshInterval = 30000; // 30 seconds
    this.data = null;

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
    this.fetchData();
    setInterval(() => this.fetchData(), this.refreshInterval);
    
    // Setup timezone handling for the clock
    if (typeof initializeTimezone === 'function') {
      initializeTimezone();
    }

    this.setupRegistrationModal();
    this.updateRegistrationButtonText();
    
    // Proactively load device info for pre-filling
    if (typeof loadDeviceInfo === 'function') {
      loadDeviceInfo();
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

    if (isPresent) {
      const stickerEl = document.createElement('div');
      stickerEl.className = 'sticker present';
      
      const rotation = (Math.random() * 6 - 3).toFixed(1);
      stickerEl.style.transform = `rotate(${rotation}deg)`;
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
    let candidates = this.data.mapped_all || [];
    candidates = candidates.filter(p => p.person && !p.person.startsWith('Anonymous'));

    // 2. Separate into present and absent
    const present = candidates.filter(p => p.present);
    const absent = candidates.filter(p => !p.present);

    // 3. Select the squad of 16:
    // We want ALL present people first. If there are more than 16 present, we take the most frequent 16.
    // If fewer than 16 present, we fill with the most frequent absent people.
    let squad = [];
    
    // Sort present by frequency to pick the top ones if > 16
    present.sort((a, b) => (b.days || 0) - (a.days || 0));
    squad = present.slice(0, 16);

    if (squad.length < 16) {
      // Sort absent by frequency to fill remaining slots
      absent.sort((a, b) => (b.days || 0) - (a.days || 0));
      const remainingSlots = 16 - squad.length;
      squad = squad.concat(absent.slice(0, remainingSlots));
    }

    // 4. Sort the final squad by name to keep their positions relatively stable
    squad.sort((a, b) => a.person.localeCompare(b.person));

    this.stickersContainerLeft.innerHTML = '';
    this.stickersContainerRight.innerHTML = '';
    
    if (squad.length === 0) {
      this.stickersContainerLeft.innerHTML = '<div class="loading-stickers">No hay jugadores registrados.</div>';
      return;
    }

    const half = Math.ceil(squad.length / 2);
    const leftPagePeople = squad.slice(0, half);
    const rightPagePeople = squad.slice(half);

    leftPagePeople.forEach((person, index) => {
      this.stickersContainerLeft.appendChild(this.createStickerElement(person, index, person.present));
    });

    rightPagePeople.forEach((person, index) => {
      this.stickersContainerRight.appendChild(this.createStickerElement(person, half + index, person.present));
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
}

document.addEventListener('DOMContentLoaded', () => {
  window.stickersDashboard = new StickersDashboard();
});
