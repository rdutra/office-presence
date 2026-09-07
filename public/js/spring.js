document.addEventListener('DOMContentLoaded', () => {
  const isMobile = window.innerWidth <= 768;
  const particleCount = isMobile ? 30 : 70; // High pelusa count

  // 1. Generate Pelusa
  for (let i = 0; i < particleCount; i++) {
    createPelusa(document.body);
  }

  // 2. Fetch Dashboard Data
  fetchDashboardData();
  setInterval(fetchDashboardData, 5000);
});

function createPelusa(container) {
  const pelusa = document.createElement('div');
  pelusa.classList.add('pelusa');
  
  // Plátano fluff size
  const size = Math.random() * 15 + 8;
  pelusa.style.width = `${size}px`;
  pelusa.style.height = `${size}px`;
  
  const startX = Math.random() * window.innerWidth;
  pelusa.style.left = `${startX}px`;
  
  const duration = Math.random() * 10 + 6;
  pelusa.style.animationDuration = `${duration}s`;
  
  const delay = Math.random() * 15;
  pelusa.style.animationDelay = `-${delay}s`;

  container.appendChild(pelusa);
}

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
  document.getElementById('spring-present-count').textContent = data.present_count;
  document.getElementById('spring-total-people').textContent = data.total_people;
  document.getElementById('spring-daily-record').textContent = data.daily_record;
  
  const now = new Date(data.now + "Z");
  const timeStr = now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  document.getElementById('spring-current-time').textContent = timeStr;

  renderFlowers(data.mapped_present);
  renderBees(data.top_attendees);
  renderLeaves(data.mapped_absent);
}

function renderFlowers(people) {
  const container = document.getElementById('spring-present-container');
  if (!people) return;

  // Track existing elements to remove ones that left
  const existingFlowers = Array.from(container.children);
  const currentMacs = new Set(people.map(p => p.mac));

  existingFlowers.forEach(el => {
    if (!currentMacs.has(el.dataset.mac)) {
      el.remove();
    }
  });

  const segmentWidth = 100 / (people.length || 1);

  people.forEach((person, i) => {
    // Check if flower already exists
    let flower = container.querySelector(`[data-mac="${person.mac}"]`);
    
    if (!flower) {
      // Create new stationary flower
      let avatar = person.image_url;
      if (!avatar) {
        avatar = `https://api.dicebear.com/7.x/micah/svg?seed=${encodeURIComponent(person.person)}&backgroundColor=transparent`;
      }

      const baseLeft = i * segmentWidth;
      const randomOffset = (Math.random() * (segmentWidth * 0.6)) - (segmentWidth * 0.3);
      let leftPos = baseLeft + (segmentWidth / 2) + randomOffset;
      leftPos = Math.max(5, Math.min(90, leftPos));

      const bottomPos = Math.random() * 25 + 5; // 5vh to 30vh
      const zIndex = 100 - Math.floor(bottomPos);

      flower = document.createElement('div');
      flower.dataset.mac = person.mac;
      flower.style.left = `${leftPos}vw`;
      flower.style.bottom = `${bottomPos}vh`;
      flower.style.zIndex = zIndex;

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
    const statusClass = person.present ? 'active' : 'inactive';
    flower.className = `flower-item status-${statusClass}`;
    
    const medal = person.medal ? ` ${person.medal}` : '';
    flower.querySelector('.flower-name').textContent = `${person.person}${medal}`;
  });
}

function renderBees(attendees) {
  const container = document.getElementById('spring-top-container');
  if (!attendees) return;

  const topFive = attendees.slice(0, 5);
  const currentMacs = new Set(topFive.map(a => a.mac || a.person));
  
  const existingBees = Array.from(container.children);
  existingBees.forEach(el => {
    if (!currentMacs.has(el.dataset.mac)) el.remove();
  });

  topFive.forEach((attendee, i) => {
    const id = attendee.mac || attendee.person;
    let bee = container.querySelector(`[data-mac="${id}"]`);
    
    if (!bee) {
      let avatar = attendee.image_url;
      if (!avatar) {
        avatar = `https://api.dicebear.com/7.x/micah/svg?seed=${encodeURIComponent(attendee.person)}&backgroundColor=transparent`;
      }

      const leftPos = Math.random() * 80 + 10;
      const topPos = Math.random() * 30 + 5;
      const animDelay = Math.random() * 2;

      bee = document.createElement('div');
      bee.className = 'bee-item';
      bee.dataset.mac = id;
      bee.style.left = `${leftPos}vw`;
      bee.style.top = `${topPos}vh`;
      bee.style.animationDelay = `-${animDelay}s`;

      bee.innerHTML = `
        <div class="bee-body">
          <div class="bee-wing wing-left"></div>
          <div class="bee-wing wing-right"></div>
          <img src="${avatar}" class="bee-face">
        </div>
        <div class="bee-label"></div>
      `;
      container.appendChild(bee);
    }
    
    bee.querySelector('.bee-label').textContent = `🏅${i+1} ${attendee.person}`;
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
