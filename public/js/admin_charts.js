document.addEventListener('DOMContentLoaded', function() {
  const tabButtons = document.querySelectorAll('.tab-button');
  let chartsLoaded = false;
  let timelineChartInstance = null;
  let summaryChartInstance = null;

  tabButtons.forEach(button => {
    button.addEventListener('click', () => {
      const targetId = button.getAttribute('data-target');
      if (targetId === 'charts-view' && !chartsLoaded) {
        loadCharts();
      }
    });
  });

  async function loadCharts() {
    try {
      const authHeader = 'Basic ' + window.btoa('admin:admin');
      // Fetch 90 days for a good line chart, and top 20 for summary
      const response = await fetch('/api/admin/stats?limit=90&offset=0', {
        headers: { 'Authorization': authHeader }
      });
      
      if (!response.ok) throw new Error('Failed to fetch statistics for charts');
      
      const data = await response.json();
      renderTimelineChart(data.timeline);
      renderSummaryChart(data.summary);
      chartsLoaded = true;
    } catch (error) {
      console.error('Error loading charts:', error);
      // Display error message in the UI
      const chartsView = document.getElementById('charts-view');
      if (chartsView) {
        const errorDiv = document.createElement('div');
        errorDiv.className = 'error';
        errorDiv.style.textAlign = 'center';
        errorDiv.style.padding = '2rem';
        errorDiv.textContent = 'Failed to load chart data: ' + error.message;
        chartsView.prepend(errorDiv);
      }
    }
  }

  function renderTimelineChart(timeline) {
    if (!timeline || timeline.length === 0) return;
    
    const ctx = document.getElementById('timelineChart').getContext('2d');
    
    // Timeline is returned in descending order (newest first). 
    // For a line chart, we usually want chronological (left to right = oldest to newest).
    const sortedTimeline = [...timeline].reverse();

    const labels = sortedTimeline.map(row => row.date);
    const uniquePeopleData = sortedTimeline.map(row => row.unique_people);
    const totalHoursData = sortedTimeline.map(row => row.total_hours);

    timelineChartInstance = new Chart(ctx, {
      type: 'line',
      data: {
        labels: labels,
        datasets: [
          {
            label: 'Total Hours',
            data: totalHoursData,
            borderColor: '#2da44e',
            backgroundColor: 'rgba(45, 164, 78, 0.1)',
            yAxisID: 'y',
            tension: 0.3,
            fill: true
          },
          {
            label: 'Unique People',
            data: uniquePeopleData,
            borderColor: '#0969da',
            backgroundColor: 'rgba(9, 105, 218, 0.1)',
            yAxisID: 'y',
            tension: 0.3,
            fill: true
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
          title: {
            display: false
          },
          tooltip: {
            callbacks: {
              label: function(context) {
                let label = context.dataset.label || '';
                if (label) {
                  label += ': ';
                }
                if (context.parsed.y !== null) {
                  label += context.parsed.y;
                  if (context.dataset.label === 'Total Hours') {
                    label += ' hrs';
                  }
                }
                return label;
              }
            }
          }
        },
        scales: {
          x: {
            display: true,
            title: {
              display: true,
              text: 'Date'
            }
          },
          y: {
            type: 'linear',
            display: true,
            position: 'left',
            title: {
              display: true,
              text: 'Count / Hours'
            },
            min: 0
          }
        }
      }
    });
  }

  function renderSummaryChart(summary) {
    if (!summary || summary.length === 0) return;
    
    const ctx = document.getElementById('summaryChart').getContext('2d');
    
    // Sort summary by total_hours descending, then take top 20
    const sortedSummary = [...summary].sort((a, b) => b.total_hours - a.total_hours).slice(0, 20);
    
    const labels = sortedSummary.map(row => row.person || 'Unknown');
    const totalHoursData = sortedSummary.map(row => row.total_hours);

    summaryChartInstance = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: labels,
        datasets: [{
          label: 'Total Hours',
          data: totalHoursData,
          backgroundColor: 'rgba(9, 105, 218, 0.7)',
          borderColor: '#0969da',
          borderWidth: 1
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: false
          },
          tooltip: {
            callbacks: {
              label: function(context) {
                let label = context.dataset.label || '';
                if (label) {
                  label += ': ';
                }
                if (context.parsed.y !== null) {
                  label += context.parsed.y + ' hrs';
                }
                return label;
              }
            }
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            title: {
              display: true,
              text: 'Total Hours'
            }
          },
          x: {
            ticks: {
              autoSkip: false,
              maxRotation: 45,
              minRotation: 45
            }
          }
        }
      }
    });
  }
});
