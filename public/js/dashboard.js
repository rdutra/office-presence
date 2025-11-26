function checkPeopleListOverflow(list) {
  if (!list) return;

  // Check if content height exceeds container height (i.e., would need scrolling)
  const needsScroll = list.scrollHeight > list.clientHeight;

  if (needsScroll) {
    list.classList.add('has-overflow');
  } else {
    list.classList.remove('has-overflow');
  }
}

function updateDashboard(data) {
  // Update time
  const timeElement = document.querySelector('.current-time');
  if (timeElement) {
    timeElement.setAttribute('data-utc', data.now);
    const fullTime = formatLocalTime(data.now);
    timeElement.textContent = fullTime.split(' ')[1]; // Extract just the HH:MM part
  }

  // Update stats using data attributes
  const presentStat = document.querySelector('[data-stat="present"] .stat-number');
  if (presentStat) presentStat.textContent = data.present_count;

  const totalStat = document.querySelector('[data-stat="total"] .stat-number');
  if (totalStat) totalStat.textContent = data.total_people;

  const dailyRecordStat = document.querySelector('[data-stat="daily-record"] .stat-number');
  if (dailyRecordStat && data.daily_record !== undefined) {
    dailyRecordStat.textContent = data.daily_record;
  }

  const allTimeRecordStat = document.querySelector('[data-stat="all-time-record"] .stat-number');
  if (allTimeRecordStat && data.all_time_record !== undefined) {
    allTimeRecordStat.textContent = data.all_time_record;
  }

  // Update currently in office
  const peopleList = document.querySelector('.people-list');
  const currentlyInOfficeColumn = peopleList?.parentElement;
  
  if (data.mapped_present.length === 0) {
    if (currentlyInOfficeColumn) {
      const emptyState = currentlyInOfficeColumn.querySelector('.empty-state');
      if (!emptyState) {
        if (peopleList) peopleList.remove();
        const div = document.createElement('div');
        div.className = 'empty-state';
        div.textContent = 'No one here yet — be the first! ☕';
        currentlyInOfficeColumn.appendChild(div);
      }
    }
  } else {
    if (currentlyInOfficeColumn) {
      const emptyState = currentlyInOfficeColumn.querySelector('.empty-state');
      if (emptyState) emptyState.remove();

      if (!peopleList) {
        const div = document.createElement('div');
        div.className = 'people-list';
        currentlyInOfficeColumn.appendChild(div);
      }
    }

    const list = document.querySelector('.people-list');
    if (list) {
      list.innerHTML = data.mapped_present.map(person => `
        <div class="person-card status-${person.status || 'inactive'}">
          <div class="person-avatar">
            ${person.person && person.person.length > 0 ? person.person[0].toUpperCase() : '?'}
          </div>
          <div class="person-info">
            <div class="person-name">${person.person}</div>
            <div class="person-device">${person.device || 'Device'}</div>
          </div>
        </div>
      `).join('');

      // Check if the list has overflow and needs two columns
      // Use requestAnimationFrame to ensure the DOM has been updated
      requestAnimationFrame(() => {
        requestAnimationFrame(() => {
          checkPeopleListOverflow(list);
        });
      });
    }
  }

  // Update top 3 podium
  const podiumContainer = document.querySelector('.podium-container');
  if (podiumContainer && data.top_attendees.length > 0) {
    const medals = ['🥇', '🥈', '🥉'];
    podiumContainer.innerHTML = data.top_attendees.slice(0, 3).map((attendee, index) => `
      <div class="podium-item rank-${index + 1}">
        <div class="podium-rank">${medals[index]}</div>
        <div class="podium-info">
          <div class="podium-name">${attendee.person}</div>
          <div class="podium-days">${attendee.days} days</div>
        </div>
      </div>
    `).join('');
  }

  // Update earlier today
  const recentList = document.querySelector('.recent-list');
  const recentlyLeftColumn = recentList?.parentElement;

  if (data.mapped_absent.length === 0) {
    if (recentlyLeftColumn) {
      const emptyState = recentlyLeftColumn.querySelector('.empty-state');
      if (!emptyState) {
        if (recentList) recentList.remove();
        const div = document.createElement('div');
        div.className = 'empty-state';
        div.textContent = 'No one has left yet';
        recentlyLeftColumn.appendChild(div);
      }
    }
  } else {
    if (recentlyLeftColumn) {
      const emptyState = recentlyLeftColumn.querySelector('.empty-state');
      if (emptyState) emptyState.remove();

      if (!recentList) {
        const div = document.createElement('div');
        div.className = 'recent-list';
        recentlyLeftColumn.appendChild(div);
      }
    }

    const list = document.querySelector('.recent-list');
    if (list) {
      list.innerHTML = data.mapped_absent.slice(0, 8).map(person => `
        <div class="recent-item">
          <div class="recent-name">${person.person}</div>
        </div>
      `).join('');
    }
  }
}

async function fetchDashboardData() {
  try {
    const response = await fetch('/api/dashboard');
    if (response.ok) {
      const data = await response.json();
      updateDashboard(data);
    }
  } catch (error) {
    console.error('Error fetching dashboard data:', error);
  }
}

function initializeDashboard() {
  initializeTimezone();
  fetchDashboardData();

  // Poll every 30 seconds
  setInterval(fetchDashboardData, 30000);

  setupRegistrationModal();
  updateRegistrationButtonText();

  // Monitor window resize to re-check overflow
  let resizeTimeout;
  window.addEventListener('resize', () => {
    clearTimeout(resizeTimeout);
    resizeTimeout = setTimeout(() => {
      const list = document.querySelector('.people-list');
      if (list) {
        checkPeopleListOverflow(list);
      }
    }, 250);
  });
}

async function updateRegistrationButtonText() {
  const openBtn = document.getElementById('openRegistrationBtn');
  if (!openBtn) return;

  try {
    const response = await fetch('/api/my-device');
    const data = await response.json();

    if (data.registered) {
      openBtn.textContent = 'Update Your Device';
    } else {
      openBtn.textContent = 'Register Your Device';
    }
  } catch (error) {
    console.error('Error checking registration status:', error);
  }
}

function setupRegistrationModal() {
  const modal = document.getElementById('registrationModal');
  const openBtn = document.getElementById('openRegistrationBtn');
  const closeBtn = document.getElementById('closeRegistrationBtn');
  const overlay = modal?.querySelector('.modal-overlay');

  if (!modal || !openBtn) {
    return;
  }

  const openModal = () => {
    modal.classList.add('is-open');
    modal.setAttribute('aria-hidden', 'false');
    document.body.classList.add('modal-open');

    if (typeof initializeRegistration === 'function') {
      initializeRegistration();
    }
  };

  const closeModal = () => {
    modal.classList.remove('is-open');
    modal.setAttribute('aria-hidden', 'true');
    document.body.classList.remove('modal-open');
  };

  openBtn.addEventListener('click', openModal);
  closeBtn?.addEventListener('click', closeModal);
  overlay?.addEventListener('click', closeModal);

  document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && modal.classList.contains('is-open')) {
      closeModal();
    }
  });
}

document.addEventListener('DOMContentLoaded', initializeDashboard);
