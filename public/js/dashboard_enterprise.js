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

  // Calculate linear regression for trend line
  const n = dataPoints.length;
  let sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
  for (let i = 0; i < n; i++) {
    sumX += i;
    sumY += dataPoints[i];
    sumXY += i * dataPoints[i];
    sumX2 += i * i;
  }
  const m = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
  const b = (sumY - m * sumX) / n;
  
  const trendLineData = [];
  for (let i = 0; i < n; i++) {
    trendLineData.push(m * i + b);
  }

  // Create a gradient for the line chart fill
  const gradient = ctx.createLinearGradient(0, 0, 0, 300);
  gradient.addColorStop(0, 'rgba(59, 130, 246, 0.4)');
  gradient.addColorStop(1, 'rgba(59, 130, 246, 0.0)');

  new Chart(ctx, {
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
});
