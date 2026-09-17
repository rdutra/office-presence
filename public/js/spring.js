document.addEventListener('DOMContentLoaded', () => {
  // Render the server snapshot immediately, then keep it live.
  if (window.springInitialData) updateDashboard(window.springInitialData);

  // Fetch Dashboard Data
  fetchDashboardData();
  setInterval(fetchDashboardData, 5000);
});

async function fetchDashboardData() {
  try {
    const response = await fetch('/api/dashboard');
    if (!response.ok) return;
    const data = await response.json();
    updateDashboard(data);
  } catch (error) {
    console.error('Error fetching dashboard data:', error);
  }
}

function updateDashboard(data) {
  // Update stats
  const presentCount = document.getElementById('spring-present-count');
  const totalPeople = document.getElementById('spring-total-people');
  const dailyRecord = document.getElementById('spring-daily-record');
  if (presentCount) presentCount.textContent = data.present_count;
  if (totalPeople) totalPeople.textContent = data.total_people;
  if (dailyRecord) dailyRecord.textContent = data.daily_record;
  
  const now = new Date(data.now + "Z");
  const timeStr = now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  const currentTime = document.getElementById('spring-current-time');
  if (currentTime) currentTime.textContent = timeStr;
  const trayTime = document.getElementById('xp-tray-time');
  if (trayTime) trayTime.textContent = timeStr;

  renderFlowers(data.mapped_present);
  renderRankingNotes(data.top_attendees);
  renderLeaves(data.mapped_absent);
}

function renderFlowers(people) {
  const container = document.getElementById('spring-present-container');
  if (!people) return;

  // Track existing elements to remove ones that left
  const existingFlowers = Array.from(container.children);
  const currentMacs = new Set(people.map(p => p.mac || p.person));

  existingFlowers.forEach(el => {
    if (!currentMacs.has(el.dataset.mac)) {
      el.remove();
    }
  });

  people.forEach((person, i) => {
    // Check if flower already exists
    const personId = person.mac || person.person;
    let flower = container.querySelector(`[data-mac="${CSS.escape(personId)}"]`);
    
    if (!flower) {
      // Create new stationary flower
      let avatar = person.image_url;
      if (!avatar) {
        avatar = `https://api.dicebear.com/7.x/micah/svg?seed=${encodeURIComponent(person.person)}&backgroundColor=transparent`;
      }

      flower = document.createElement('div');
      flower.dataset.mac = personId;

      flower.innerHTML = `
        <div class="flower-petals">
           <div class="petal p1"></div><div class="petal p2"></div><div class="petal p3"></div><div class="petal p4"></div>
           <div class="petal p5"></div><div class="petal p6"></div><div class="petal p7"></div><div class="petal p8"></div>
        </div>
        <div class="flower-center" style="background-image: url('${avatar}')">
          <div class="fluff-overlay-avatar"></div>
        </div>
        <div class="flower-info">
          <div class="flower-name"></div>
        </div>
        <div class="flower-stem"></div>
      `;
      container.appendChild(flower);
    }

    // Update dynamic properties on existing or new flower
    // mapped_present is already filtered to people currently in the office;
    // older API payloads may not include the optional `present` flag.
    const statusClass = person.present === false ? 'inactive' : 'active';
    flower.className = `desktop-icon status-${statusClass}`;
    
    const medal = person.medal ? ` ${person.medal}` : '';
    flower.querySelector('.flower-name').textContent = `${person.person}${medal}`;
  });
}

function renderRankingNotes(attendees) {
  const window = document.getElementById('spring-top-container');
  const container = window?.querySelector('.ranking-list');
  if (!container) return;
  if (!attendees) return;

  const topFour = attendees.slice(0, 4);
  const currentMacs = new Set(topFour.map(a => a.mac || a.person));
  
  const existingNotes = Array.from(container.children);
  existingNotes.forEach(el => {
    if (!currentMacs.has(el.dataset.mac)) el.remove();
  });

  topFour.forEach((attendee, i) => {
    const id = attendee.mac || attendee.person;
    let note = container.querySelector(`[data-mac="${id}"]`);
    
    if (!note) {
      let avatar = attendee.image_url;
      if (!avatar) {
        avatar = `https://api.dicebear.com/7.x/micah/svg?seed=${encodeURIComponent(attendee.person)}&backgroundColor=transparent`;
      }

      note = document.createElement('div');
      note.className = 'ranking-note';
      note.dataset.mac = id;
      note.style.setProperty('--note-rotation', `${Math.random() * 8 - 4}deg`);

      note.innerHTML = `
        <div class="note-pin">📌</div>
        <img src="${avatar}" class="note-avatar" alt="">
        <div class="note-rank"></div>
        <div class="note-name"></div>
      `;
      container.appendChild(note);
    }
    
    note.querySelector('.note-rank').textContent = `#${i + 1}`;
    note.querySelector('.note-name').textContent = attendee.person;
  });
}

function renderLeaves(absentees) {
  const container = document.getElementById('spring-recent-container');
  if (!absentees) return;

  const maxLeaves = absentees.slice(0, 8);
  const currentMacs = new Set(maxLeaves.map(a => a.mac));

  const existingLeaves = Array.from(container.children);
  existingLeaves.forEach(el => {
    if (!currentMacs.has(el.dataset.mac)) el.remove();
  });

  maxLeaves.forEach((person, i) => {
    let leaf = container.querySelector(`[data-mac="${person.mac}"]`);
    
    if (!leaf) {
      let avatar = person.image_url;
      if (!avatar) {
        avatar = `https://api.dicebear.com/7.x/micah/svg?seed=${encodeURIComponent(person.person)}&backgroundColor=transparent`;
      }

      const isLeft = i % 2 === 0;
      const leftPos = isLeft ? (Math.random() * 15 + 2) : (Math.random() * 15 + 80);
      const bottomPos = Math.random() * 15 + 2;
      const rotation = Math.random() * 120 - 60;

      leaf = document.createElement('div');
      leaf.className = 'fallen-leaf';
      leaf.dataset.mac = person.mac;
      leaf.style.left = `${leftPos}vw`;
      leaf.style.bottom = `${bottomPos}vh`;
      leaf.style.transform = `rotate(${rotation}deg)`;

      leaf.innerHTML = `
        <img src="${avatar}" alt="${person.person}">
        <span></span>
      `;
      container.appendChild(leaf);
    }
    
    leaf.querySelector('span').textContent = person.person;
  });
}
