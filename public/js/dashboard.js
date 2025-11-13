function updateDashboard(data) {
  // Update time
  const timeElement = document.querySelector('.current-time');
  if (timeElement) {
    timeElement.setAttribute('data-utc', data.now);
    const fullTime = formatLocalTime(data.now);
    timeElement.textContent = fullTime.split(' ')[1]; // Extract just the HH:MM part
  }

  // Update stats
  document.querySelector('.stat-card:nth-child(1) .stat-number').textContent = data.present_count;
  document.querySelector('.stat-card:nth-child(2) .stat-number').textContent = data.total_people;

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
  
  // Poll every 30 seconds
  setInterval(fetchDashboardData, 30000);
}

document.addEventListener('DOMContentLoaded', initializeDashboard);

