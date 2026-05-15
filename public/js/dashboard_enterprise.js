document.addEventListener('DOMContentLoaded', function() {
  if (typeof initializeTimezone === 'function') {
    initializeTimezone();
  }

  const trendData = window.attendanceTrend;
  if (!trendData || trendData.length === 0) {
    const container = document.querySelector('.chart-container');
    if (container) {
      container.innerHTML = '<div class="empty-state">No attendance data available yet.</div>';
    }
    return;
  }

  // Trend data is sorted by date descending (newest first). 
  // Reverse it to plot chronologically (left to right).
  const sortedTrend = [...trendData].reverse();
  const labels = sortedTrend.map(row => row.date);
  const dataPoints = sortedTrend.map(row => row.unique_people);

  const ctx = document.getElementById('trendChart').getContext('2d');

  // Calculate 7-day moving average for trend line
  const n = dataPoints.length;
  const trendLineData = [];
  const windowSize = 7;
  
  for (let i = 0; i < n; i++) {
    if (i < windowSize - 1) {
      // Not enough data for a full window, just use the growing average
      let sum = 0;
      for (let j = 0; j <= i; j++) {
        sum += dataPoints[j];
      }
      trendLineData.push(sum / (i + 1));
    } else {
      let sum = 0;
      for (let j = 0; j < windowSize; j++) {
        sum += dataPoints[i - j];
      }
      trendLineData.push(sum / windowSize);
    }
  }

  // Create a gradient for the line chart fill
  const gradient = ctx.createLinearGradient(0, 0, 0, 300);
  gradient.addColorStop(0, 'rgba(59, 130, 246, 0.4)');
  gradient.addColorStop(1, 'rgba(59, 130, 246, 0.0)');

  window.trendChartInstance = new Chart(ctx, {
    type: 'line',
    data: {
      labels: labels,
      datasets: [
        {
          label: 'Trend',
          data: trendLineData,
          borderColor: '#ef4444',
          borderWidth: 2,
          borderDash: [5, 5],
          pointRadius: 0,
          pointHoverRadius: 0,
          fill: false,
          tension: 0,
          order: 1
        },
        {
          label: 'Unique People',
          data: dataPoints,
          borderColor: '#3b82f6',
          backgroundColor: gradient,
          borderWidth: 3,
          pointBackgroundColor: '#0f1115',
          pointBorderColor: '#3b82f6',
          pointBorderWidth: 2,
          pointRadius: 4,
          pointHoverRadius: 6,
          fill: true,
          tension: 0.4,
          order: 2
        }
      ]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      interaction: {
        mode: 'index',
        intersect: false,
      },
      plugins: {
        legend: {
          display: false
        },
        tooltip: {
          backgroundColor: 'rgba(15, 17, 21, 0.9)',
          titleColor: '#94a3b8',
          bodyColor: '#f8fafc',
          borderColor: 'rgba(255, 255, 255, 0.1)',
          borderWidth: 1,
          padding: 12,
          displayColors: false,
          callbacks: {
            label: function(context) {
              return context.parsed.y + ' people';
            }
          }
        }
      },
      scales: {
        x: {
          grid: {
            color: 'rgba(255, 255, 255, 0.03)',
            drawBorder: false
          },
          ticks: {
            color: '#94a3b8',
            maxTicksLimit: 7
          }
        },
        y: {
          beginAtZero: true,
          grid: {
            color: 'rgba(255, 255, 255, 0.03)',
            drawBorder: false
          },
          ticks: {
            color: '#94a3b8',
            stepSize: 1
          }
        }
      }
    }
  });

  // Auto-refresh logic
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
      if (typeof formatLocalTime === 'function') {
        const fullTime = formatLocalTime(data.now);
        timeElement.textContent = fullTime.split(" ")[1];
      }
    }

    const dateElement = document.querySelector(".current-date");
    if (dateElement && typeof formatLocalTime === 'function') {
      const parts = new Date(data.now + "Z").toLocaleDateString('en-US', {
        weekday: 'long', year: 'numeric', month: 'long', day: 'numeric'
      });
      dateElement.textContent = parts;
    }

    // Update In Office count
    const countElement = document.querySelector(".card-title");
    if (countElement && countElement.textContent.includes("Currently in Office")) {
      countElement.textContent = `Currently in Office (${data.present_count})`;
    }

    // Update people list
    const leftColumnCard = document.querySelector(".dashboard-grid .card:first-child");
    if (leftColumnCard) {
      let peopleList = leftColumnCard.querySelector(".people-list");
      let emptyState = leftColumnCard.querySelector(".empty-state");

      if (data.mapped_present.length === 0) {
        if (peopleList) peopleList.remove();
        if (!emptyState) {
          emptyState = document.createElement("div");
          emptyState.className = "empty-state";
          emptyState.innerHTML = `
            <div style="font-size: 2rem; margin-bottom: 1rem;">🏢</div>
            <div>The office is currently empty.</div>
          `;
          // insert after card-header
          const header = leftColumnCard.querySelector(".card-header");
          header.insertAdjacentElement("afterend", emptyState);
        }
      } else {
        if (emptyState) emptyState.remove();
        if (!peopleList) {
          peopleList = document.createElement("div");
          peopleList.className = "people-list";
          const header = leftColumnCard.querySelector(".card-header");
          header.insertAdjacentElement("afterend", peopleList);
        }

        peopleList.innerHTML = data.mapped_present.map(person => `
          <div class="person-card status-${person.status || 'inactive'}">
            <div class="person-avatar">
              ${person.person && person.person.length > 0 ? person.person[0].toUpperCase() : '?'}
            </div>
            <div class="person-info">
              <div class="person-name">${formatDisplayName(person)}</div>
              <div class="person-device">${person.device || 'Device'}</div>
            </div>
            <div class="status-indicator" title="${person.status ? person.status.charAt(0).toUpperCase() + person.status.slice(1) : 'Inactive'}"></div>
          </div>
        `).join("");
      }
    }

    // Update Award History
    const awardCard = document.querySelector(".dashboard-grid .card:nth-child(2)");
    if (awardCard) {
      let winnersList = awardCard.querySelector(".winners-list");
      let emptyState = awardCard.querySelector(".empty-state");

      if (data.aggregated_winners.length === 0) {
        if (winnersList) winnersList.remove();
        if (!emptyState) {
          emptyState = document.createElement("div");
          emptyState.className = "empty-state";
          emptyState.innerHTML = `<div>No awards have been given out yet.</div>`;
          const header = awardCard.querySelector(".card-header");
          header.insertAdjacentElement("afterend", emptyState);
        }
      } else {
        if (emptyState) emptyState.remove();
        if (!winnersList) {
          winnersList = document.createElement("div");
          winnersList.className = "winners-list";
          const header = awardCard.querySelector(".card-header");
          header.insertAdjacentElement("afterend", winnersList);
        }

        winnersList.innerHTML = `
          <table class="winners-table">
            <thead>
              <tr>
                <th>Champion</th>
                <th>Times Won</th>
              </tr>
            </thead>
            <tbody>
              ${data.aggregated_winners.map(winner => `
                <tr>
                  <td>
                    <div class="winner-name-cell">
                      <span class="winner-medal">🥇</span>
                      <strong>${winner.person}</strong>
                    </div>
                  </td>
                  <td>${winner.count}x</td>
                </tr>
              `).join('')}
            </tbody>
          </table>
        `;
      }
    }

    // Update Trend Chart
    if (data.attendance_trend && window.trendChartInstance) {
      const sortedTrend = [...data.attendance_trend].reverse();
      const labels = sortedTrend.map(row => row.date);
      const dataPoints = sortedTrend.map(row => row.unique_people);

      const n = dataPoints.length;
      const trendLineData = [];
      const windowSize = 7;
      
      for (let i = 0; i < n; i++) {
        if (i < windowSize - 1) {
          let sum = 0;
          for (let j = 0; j <= i; j++) { sum += dataPoints[j]; }
          trendLineData.push(sum / (i + 1));
        } else {
          let sum = 0;
          for (let j = 0; j < windowSize; j++) { sum += dataPoints[i - j]; }
          trendLineData.push(sum / windowSize);
        }
      }

      window.trendChartInstance.data.labels = labels;
      window.trendChartInstance.data.datasets[0].data = trendLineData;
      window.trendChartInstance.data.datasets[1].data = dataPoints;
      window.trendChartInstance.update();
    }
  }

  setInterval(fetchDashboardData, 30000);
});
