function checkPeopleListOverflow(list) {
  if (!list) return;

  const maxColumns = 3; // we can add more columns in the future if needed
  const columnClasses = ["cols-1", "cols-2", "cols-3"];

  for (let cols = 1; cols <= maxColumns; cols++) {
    list.classList.remove(...columnClasses);
    list.classList.add(`cols-${cols}`);
    void list.offsetHeight;

    const needsScroll = list.scrollHeight > list.clientHeight;

    if (!needsScroll) {
      break;
    }
  }
}

function getSectionElement(name) {
  return document.querySelector(`[data-section="${name}"]`);
}

function insertAfterHeader(section, element) {
  if (!section || !element) return;
  const header = section.querySelector(".section-header");
  if (header) {
    header.insertAdjacentElement("afterend", element);
  } else {
    section.insertBefore(element, section.firstChild);
  }
}

function ensureListElement(section, selector, className) {
  if (!section) return null;
  let list = section.querySelector(selector);
  if (!list) {
    list = document.createElement("div");
    list.className = className;
    insertAfterHeader(section, list);
  }
  return list;
}

function showEmptyState(section, message) {
  if (!section) return;
  let empty = section.querySelector(".empty-state");
  if (!empty) {
    empty = document.createElement("div");
    empty.className = "empty-state";
    insertAfterHeader(section, empty);
  }
  empty.textContent = message;
  empty.style.display = "";
}

function hideEmptyState(section) {
  const empty = section?.querySelector(".empty-state");
  if (empty) {
    empty.remove();
  }
}

function formatDisplayName(person) {
  if (!person) return "";
  const name = person.person || "Unknown";
  return person.medal ? `${name} ${person.medal}` : name;
}

function updateDashboard(data) {
  // Update time
  const timeElement = document.querySelector(".current-time");
  if (timeElement) {
    timeElement.setAttribute("data-utc", data.now);
    const fullTime = formatLocalTime(data.now);
    timeElement.textContent = fullTime.split(" ")[1]; // Extract just the HH:MM part
  }

  // Update stats using data attributes
  const presentStat = document.querySelector(
    '[data-stat="present"] .stat-number'
  );
  if (presentStat) presentStat.textContent = data.present_count;

  const totalStat = document.querySelector('[data-stat="total"] .stat-number');
  if (totalStat) totalStat.textContent = data.total_people;

  const dailyRecordStat = document.querySelector(
    '[data-stat="daily-record"] .stat-number'
  );
  if (dailyRecordStat && data.daily_record !== undefined) {
    dailyRecordStat.textContent = data.daily_record;
  }

  const allTimeRecordStat = document.querySelector(
    '[data-stat="all-time-record"] .stat-number'
  );
  if (allTimeRecordStat && data.all_time_record !== undefined) {
    allTimeRecordStat.textContent = data.all_time_record;
  }

  const weekRange = document.querySelector("[data-week-range]");
  if (
    weekRange &&
    data.current_week_start &&
    data.current_week_end
  ) {
    weekRange.textContent = `${data.current_week_start} to ${data.current_week_end}`;
  }

  const lastWeekBadge = document.querySelector("[data-last-week-winner]");
  if (lastWeekBadge) {
    if (data.last_week_winner) {
      lastWeekBadge.innerHTML = `
        <div class="badge-label">Last Week</div>
        <div class="badge-name">${data.last_week_winner.person}</div>
        <div class="badge-meta">${data.last_week_winner.days} days (${data.last_week_winner.week_start} to ${data.last_week_winner.week_end})</div>
      `;
    } else {
      lastWeekBadge.innerHTML = `<div class="badge-empty">No winner recorded last week</div>`;
    }
  }

  // Update currently in office
  const presentSection = getSectionElement("present");
  const peopleList = ensureListElement(
    presentSection,
    ".people-list",
    "people-list"
  );

  if (data.mapped_present.length === 0) {
    if (peopleList) {
      peopleList.innerHTML = "";
      peopleList.style.display = "none";
    }
    showEmptyState(presentSection, "No one here yet — be the first! ☕");
  } else {
    hideEmptyState(presentSection);
    if (peopleList) {
      peopleList.style.display = "";
      peopleList.innerHTML = data.mapped_present
        .map(
          (person) => `
        <div class="person-card status-${person.status || "inactive"}">
          <div class="person-avatar">
            ${
              person.person && person.person.length > 0
                ? person.person[0].toUpperCase()
                : "?"
            }
          </div>
          <div class="person-info">
            <div class="person-name">${formatDisplayName(person)}</div>
            <div class="person-device">${person.device || "Device"}</div>
          </div>
        </div>
      `
        )
        .join("");

      // Check if the list has overflow and needs two columns
      // Use requestAnimationFrame to ensure the DOM has been updated
      requestAnimationFrame(() => {
        requestAnimationFrame(() => {
          checkPeopleListOverflow(peopleList);
        });
      });
    }
  }

  // Update top 3 podium
  const podiumContainer = document.querySelector(".podium-container");
  if (podiumContainer && data.top_attendees.length > 0) {
    const medals = ["🥇", "🥈", "🥉"];
    podiumContainer.innerHTML = data.top_attendees
      .slice(0, 3)
      .map(
        (attendee, index) => `
      <div class="podium-item rank-${index + 1}">
        <div class="podium-rank">${medals[index]}</div>
        <div class="podium-info">
          <div class="podium-name">${formatDisplayName(attendee)}</div>
          <div class="podium-days">${attendee.days} days</div>
        </div>
      </div>
    `
      )
      .join("");
  }

  // Update earlier today
  const recentSection = getSectionElement("recent");
  const recentList = ensureListElement(
    recentSection,
    ".recent-list",
    "recent-list"
  );

  if (data.mapped_absent.length === 0) {
    if (recentList) {
      recentList.innerHTML = "";
      recentList.style.display = "none";
    }
    showEmptyState(recentSection, "No one has left yet");
  } else {
    hideEmptyState(recentSection);
    if (recentList) {
      recentList.style.display = "";
      recentList.innerHTML = data.mapped_absent
        .slice(0, 8)
      .map(
        (person) => `
        <div class="recent-item">
          <div class="recent-name">${formatDisplayName(person)}</div>
        </div>
      `
        )
        .join("");
      
      // Initialize auto-scroll for the recent list
      initializeAutoScroll(recentList);
    }
  }
}

// Auto-scroll functionality for "Earlier Today" section
let autoScrollInterval = null;

function initializeAutoScroll(element) {
  if (!element) return;
  
  // Clear any existing interval
  if (autoScrollInterval) {
    clearInterval(autoScrollInterval);
    autoScrollInterval = null;
  }
  
  // Only auto-scroll if content overflows
  const hasOverflow = element.scrollHeight > element.clientHeight;
  if (!hasOverflow) return;
  
  let scrollingDown = true;
  const scrollStep = 1; // pixels per step
  const scrollDelay = 50; // milliseconds between steps
  const pauseAtEnd = 2000; // pause at top/bottom in milliseconds
  
  autoScrollInterval = setInterval(() => {
    const atBottom = element.scrollTop + element.clientHeight >= element.scrollHeight - 1;
    const atTop = element.scrollTop <= 1;
    
    if (scrollingDown) {
      if (atBottom) {
        // Pause at bottom, then reverse direction
        setTimeout(() => {
          scrollingDown = false;
        }, pauseAtEnd);
      } else {
        element.scrollTop += scrollStep;
      }
    } else {
      if (atTop) {
        // Pause at top, then reverse direction
        setTimeout(() => {
          scrollingDown = true;
        }, pauseAtEnd);
      } else {
        element.scrollTop -= scrollStep;
      }
    }
  }, scrollDelay);
}

async function fetchDashboardData() {
  try {
    const response = await fetch("/api/dashboard");
    if (response.ok) {
      const data = await response.json();
      updateDashboard(data);
    }
  } catch (error) {
    console.error("Error fetching dashboard data:", error);
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
  window.addEventListener("resize", () => {
    clearTimeout(resizeTimeout);
    resizeTimeout = setTimeout(() => {
      const list = document.querySelector(".people-list");
      if (list) {
        checkPeopleListOverflow(list);
      }
    }, 250);
  });
}

// Updates the registration button text based on current registration status
// Called on page load and ensures the button text stays in sync with the backend state
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
    // Fallback to default text on error
    openBtn.textContent = 'Register Your Device';
  }
}

function setupRegistrationModal() {
  const modal = document.getElementById("registrationModal");
  const openBtn = document.getElementById("openRegistrationBtn");
  const closeBtn = document.getElementById("closeRegistrationBtn");
  const overlay = modal?.querySelector(".modal-overlay");

  if (!modal || !openBtn) {
    return;
  }

  const openModal = () => {
    modal.classList.add("is-open");
    modal.setAttribute("aria-hidden", "false");
    document.body.classList.add("modal-open");

    if (typeof initializeRegistration === "function") {
      initializeRegistration();
    }
  };

  const closeModal = () => {
    modal.classList.remove("is-open");
    modal.setAttribute("aria-hidden", "true");
    document.body.classList.remove("modal-open");
  };

  openBtn.addEventListener("click", openModal);
  closeBtn?.addEventListener("click", closeModal);
  overlay?.addEventListener("click", closeModal);

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && modal.classList.contains("is-open")) {
      closeModal();
    }
  });
}

document.addEventListener("DOMContentLoaded", initializeDashboard);
