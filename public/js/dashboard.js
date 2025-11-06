function updateDashboard(data) {
  // Update time
  const timeElement = document.querySelector('.current-time');
  if (timeElement) {
    timeElement.setAttribute('data-utc', data.now);
    timeElement.textContent = formatLocalTime(data.now);
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
        div.textContent = 'Nobody here yet today';
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
        <div class="person-card">
          <div class="person-avatar">${person.person[0].toUpperCase()}</div>
          <div class="person-info">
            <div class="person-name">${person.person}</div>
            <div class="person-device">${person.device || 'Device'}</div>
          </div>
          <div class="person-time timestamp" data-utc="${person.last_seen_utc}">
            ${formatLocalTime(person.last_seen_utc)}
          </div>
        </div>
      `).join('');
    }
  }

  // Update leaderboard
  const leaderboard = document.querySelector('.leaderboard');
  if (leaderboard) {
    leaderboard.innerHTML = data.top_attendees.map((attendee, index) => `
      <div class="leaderboard-item">
        <div class="rank rank-${index + 1}">${index + 1}</div>
        <div class="attendee-info">
          <div class="attendee-name">${attendee.person}</div>
          <div class="attendee-stats">${attendee.days} days</div>
        </div>
      </div>
    `).join('');
  }

  // Update recently left
  const recentList = document.querySelector('.recent-list');
  const recentlyLeftColumn = recentList?.parentElement;
  
  if (data.mapped_absent.length === 0) {
    if (recentlyLeftColumn) {
      const emptyState = recentlyLeftColumn.querySelector('.empty-state');
      if (!emptyState) {
        if (recentList) recentList.remove();
        const div = document.createElement('div');
        div.className = 'empty-state';
        div.textContent = 'No recent activity';
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
      list.innerHTML = data.mapped_absent.map(person => `
        <div class="recent-item">
          <div class="recent-name">${person.person}</div>
          <div class="recent-time timestamp" data-utc="${person.last_seen_utc}">
            ${formatLocalTime(person.last_seen_utc)}
          </div>
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
  
  // Poll every 10 seconds
  setInterval(fetchDashboardData, 10000);
}

document.addEventListener('DOMContentLoaded', initializeDashboard);

