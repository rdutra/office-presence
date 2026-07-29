class NostalgiaDashboard {
  constructor() {
    this.trackListEl = document.getElementById('ns-track-list');
    this.presentCountEl = document.getElementById('ns-present-count');
    this.totalPeopleEl = document.getElementById('ns-total-people');
    this.dailyRecordEl = document.getElementById('ns-daily-record');
    this.allTimeRecordEl = document.getElementById('ns-all-time-record');
    this.topAttendeesEl = document.getElementById('ns-top-attendees');
    this.lastWinnerNameEl = document.getElementById('ns-last-winner-name');
    this.lastWinnerMetaEl = document.getElementById('ns-last-winner-meta');
    this.currentTimeEl = document.getElementById('ns-current-time');
    this.refreshInterval = 30000;
    this.data = null;

    this.init();
  }

  init() {
    this.fetchData();

    if (!window.FIREBASE_MODE) {
      setInterval(() => this.fetchData(), this.refreshInterval);
    }

    if (typeof initializeTimezone === 'function') {
      initializeTimezone();
    }

    this.setupRegistrationModal();
    this.updateRegistrationButtonText();

    if (typeof loadDeviceInfo === 'function') {
      loadDeviceInfo();
    }
  }

  async fetchData() {
    try {
      const response = await fetch('/api/dashboard');
      if (!response.ok) throw new Error('Failed to fetch dashboard data');
      this.data = await response.json();
      this.render();
    } catch (error) {
      console.error('Error fetching nostalgia dashboard data:', error);
    }
  }

  render() {
    if (!this.data) return;

    if (this.presentCountEl) this.presentCountEl.textContent = this.data.present_count || 0;
    if (this.totalPeopleEl) this.totalPeopleEl.textContent = this.data.total_people || 0;
    if (this.dailyRecordEl) this.dailyRecordEl.textContent = this.data.daily_record || 0;
    if (this.allTimeRecordEl) this.allTimeRecordEl.textContent = this.data.all_time_record || 0;

    this.renderTracks();
    this.renderTopAttendees();
    this.renderLastWeekWinner();
    this.updateTime();
  }

  renderTracks() {
    if (!this.trackListEl) return;

    const people = (this.data.mapped_all || [])
      .filter((person) => person.person && !person.person.startsWith('Anonymous'))
      .sort((a, b) => {
        if (a.present !== b.present) return a.present ? -1 : 1;
        if (a.recent !== b.recent) return a.recent ? -1 : 1;
        return a.person.localeCompare(b.person);
      });

    this.trackListEl.innerHTML = '';
    this.trackListEl.classList.toggle('is-dense', people.length > 28);
    this.trackListEl.classList.toggle('is-ultra-dense', people.length > 36);
    if (this.totalPeopleEl) this.totalPeopleEl.textContent = people.length;

    if (people.length === 0) {
      const empty = document.createElement('li');
      empty.innerHTML = '<span class="track-num">00</span><span class="track-name">No office tracks yet</span><span class="track-status">silence</span>';
      this.trackListEl.appendChild(empty);
      return;
    }

    people.forEach((person, index) => {
      const row = document.createElement('li');
      if (person.present) row.classList.add('is-present');

      const status = person.present ? 'playing' : (person.recent ? 'rewind' : 'archive');
      const name = [person.person, person.medal].filter(Boolean).join(' ');

      row.innerHTML = `
        <span class="track-num">${String(index + 1).padStart(2, '0')}</span>
        <span class="track-name"></span>
        <span class="track-status">${status}</span>
      `;
      row.querySelector('.track-name').textContent = name;
      this.trackListEl.appendChild(row);
    });
  }

  renderTopAttendees() {
    if (!this.topAttendeesEl) return;

    const attendees = this.data.top_attendees || [];
    this.topAttendeesEl.innerHTML = '';

    if (attendees.length === 0) {
      const empty = document.createElement('div');
      empty.className = 'spin-row';
      empty.innerHTML = '<b>-</b><span>No spins yet</span><em>0</em>';
      this.topAttendeesEl.appendChild(empty);
      return;
    }

    attendees.slice(0, 6).forEach((attendee, index) => {
      const row = document.createElement('div');
      row.className = 'spin-row';
      row.innerHTML = `<b>${index + 1}</b><span></span><em>${attendee.days}</em>`;
      row.querySelector('span').textContent = attendee.person;
      this.topAttendeesEl.appendChild(row);
    });
  }

  renderLastWeekWinner() {
    if (!this.lastWinnerNameEl || !this.lastWinnerMetaEl) return;

    const winner = this.data.last_week_winner;
    if (!winner) {
      this.lastWinnerNameEl.textContent = 'Sin ganador';
      this.lastWinnerMetaEl.textContent = '--';
      return;
    }

    this.lastWinnerNameEl.textContent = [winner.person, winner.medal].filter(Boolean).join(' ');
    this.lastWinnerMetaEl.textContent = `${winner.days || 0} dias`;
  }

  updateTime() {
    if (!this.currentTimeEl) return;

    const source = this.data.last_updated || this.data.now;
    const date = source ? new Date(source) : new Date();
    if (Number.isNaN(date.getTime())) return;

    const hours = String(date.getHours()).padStart(2, '0');
    const minutes = String(date.getMinutes()).padStart(2, '0');
    this.currentTimeEl.textContent = `${hours}:${minutes}`;
  }

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
    };

    const closeModal = () => {
      modal.classList.remove('is-open');
      modal.setAttribute('aria-hidden', 'true');
      document.body.classList.remove('modal-open');
    };

    if (openBtn) openBtn.addEventListener('click', openModal);
    if (closeBtn) closeBtn.addEventListener('click', closeModal);
    if (overlay) overlay.addEventListener('click', closeModal);

    document.addEventListener('keydown', (event) => {
      if (event.key === 'Escape' && modal.classList.contains('is-open')) {
        closeModal();
      }
    });
  }

  async updateRegistrationButtonText() {
    const openBtn = document.getElementById('openRegistrationBtn');
    if (!openBtn || window.FIREBASE_MODE) return;

    try {
      const response = await fetch('/api/my-device');
      const data = await response.json();

      if (data.registered) {
        openBtn.textContent = 'Update Track';
      }
    } catch (error) {
      console.error('Error checking registration status:', error);
    }
  }
}

document.addEventListener('DOMContentLoaded', () => {
  new NostalgiaDashboard();
});
