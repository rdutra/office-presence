(function() {
  const presentEl = document.getElementById('geo-present-section-body');
  const championsEl = document.getElementById('geo-champions-section-body');
  const earlierEl = document.getElementById('geo-earlier-section-body');
  const statsPresentEl = document.getElementById('geo-present-count');
  const statsTotalEl = document.getElementById('geo-total-people');
  const statsDailyEl = document.getElementById('geo-daily-record');
  const statsAllTimeEl = document.getElementById('geo-all-time-record');
  const weekRangeEl = document.getElementById('geo-week-range');
  const timeEl = document.getElementById('geo-current-time');
  const dateEl = document.getElementById('geo-current-date');
  const hitCounterEl = document.querySelector('[data-hit-counter]');

  if (!presentEl) return; // only run on geocities page

  const medals = ['🥇', '🥈', '🥉'];
  const icons = [
    '/img/geocities/animated-computer-image-0120.gif',
    '/img/geocities/animated-sun-image-0251.gif',
    '/img/geocities/animated-smiley-image-0228.gif',
    '/img/geocities/animated-coffee-image-0007.gif',
    '/img/geocities/animated-star-image-0095.gif',
    '/img/geocities/animated-light-bulb-image-0001.gif'
  ];

  function normalizeUtc(value) {
    if (!value) return null;
    return value.includes('Z') || value.includes('+') ? value : `${value}Z`;
  }

  function formatClock(utcString) {
    const normalized = normalizeUtc(utcString);
    if (!normalized) return '--:--';
    const date = new Date(normalized);
    if (Number.isNaN(date.getTime())) return '--:--';
    const hours = String(date.getHours()).padStart(2, '0');
    const minutes = String(date.getMinutes()).padStart(2, '0');
    return `${hours}:${minutes}`;
  }

  function formatDisplayDate(utcString) {
    const normalized = normalizeUtc(utcString);
    const date = normalized ? new Date(normalized) : new Date();
    if (Number.isNaN(date.getTime())) return '';
    return date.toLocaleDateString(undefined, {
      weekday: 'long',
      month: 'long',
      day: 'numeric'
    });
  }

  function renderPresent(people) {
    if (!Array.isArray(people) || people.length === 0) {
      return '<div class="geo-empty">No one has plugged in yet. Tell your friends!</div>';
    }
    return people.map((person, index) => {
      const name = person?.person || 'Unknown';
      const device = person?.device || 'Device';
      const icon = icons[index % icons.length];
      return `
        <div class="geo-person">
          <img src="${icon}" alt="" class="geo-person-icon">
          <div class="geo-person-info">
            <div class="geo-person-name">${name}</div>
            <div class="geo-person-device">${device}</div>
          </div>
        </div>
      `;
    }).join('');
  }

  function renderChampions(attendees) {
    if (!Array.isArray(attendees) || attendees.length === 0) {
      return '<div class="geo-empty">Glory awaits brave visitors!</div>';
    }
    return attendees.slice(0, 3).map((attendee, index) => {
      const name = attendee?.person || 'Unknown';
      const days = attendee?.days || 0;
      const icon = medals[index] || '⭐';
      return `
        <div class="geo-champion">
          <div class="geo-champion-medal">${icon}</div>
          <div class="geo-champion-name">${name}</div>
          <div class="geo-champion-days">${days} days</div>
        </div>
      `;
    }).join('');
  }

  function renderEarlier(absent) {
    if (!Array.isArray(absent) || absent.length === 0) {
      return '<div class="geo-empty">No one has logged off yet.</div>';
    }
    return absent.slice(0, 8).map((person) => {
      const name = person?.person || 'Unknown';
      return `
        <div class="geo-earlier-item">
          <img src="/img/geocities/animated-clock-image-0156.gif" alt="" class="geo-person-icon">
          <span>${name}</span>
        </div>
      `;
    }).join('');
  }

  function setOdometerValue(el, value) {
    if (!el) return;
    const normalized = Math.max(0, value);
    el.dataset.value = String(normalized);
    const digits = String(normalized).padStart(6, '0').split('');
    el.querySelectorAll('.geo-digit-wheel').forEach((wheel, i) => {
      const target = parseInt(digits[i], 10);
      const delay = i * 60;
      setTimeout(() => {
        wheel.style.transition = 'transform 1.4s ease-in-out';
        wheel.style.transform = `translateY(-${target * 10}%)`;
      }, delay);
    });
  }

  async function fetchDashboard() {
    try {
      const res = await fetch('/api/dashboard');
      if (!res.ok) throw new Error('Failed to load dashboard');
      const data = await res.json();

      const nowUtc = data.now || data.last_updated;
      if (timeEl) {
        timeEl.dataset.utc = normalizeUtc(nowUtc) || '';
        timeEl.textContent = formatClock(nowUtc);
      }
      if (dateEl) {
        dateEl.textContent = formatDisplayDate(nowUtc);
      }

      if (statsPresentEl) statsPresentEl.textContent = data.present_count ?? 0;
      if (statsTotalEl) statsTotalEl.textContent = data.total_people ?? 0;
      if (statsDailyEl) statsDailyEl.textContent = data.daily_record ?? 0;
      if (statsAllTimeEl) statsAllTimeEl.textContent = data.all_time_record ?? 0;
      if (weekRangeEl && data.current_week_start && data.current_week_end) {
        weekRangeEl.textContent = `${data.current_week_start} to ${data.current_week_end}`;
      }

      if (presentEl) presentEl.innerHTML = renderPresent(data.mapped_present);
      if (championsEl) championsEl.innerHTML = renderChampions(data.top_attendees);
      if (earlierEl) earlierEl.innerHTML = renderEarlier(data.mapped_absent);

      if (hitCounterEl) {
        const nextValue = data.all_time_record ?? data.total_people ?? 0;
        setOdometerValue(hitCounterEl, nextValue);
      }
    } catch (e) {
      console.error('Geo dashboard update failed', e);
    }
  }

  fetchDashboard();
  setInterval(fetchDashboard, 30000);
})();
