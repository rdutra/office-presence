document.addEventListener('DOMContentLoaded', function() {
  const tabButtons = document.querySelectorAll('.tab-button');
  const tabContents = document.querySelectorAll('.tab-content');
  let statsLoaded = false;

  tabButtons.forEach(button => {
    button.addEventListener('click', () => {
      tabButtons.forEach(btn => btn.classList.remove('active'));
      tabContents.forEach(content => {
        content.classList.remove('active');
        content.style.display = 'none';
      });

      button.classList.add('active');
      const targetId = button.getAttribute('data-target');
      const targetView = document.getElementById(targetId);
      if (targetView) {
        targetView.classList.add('active');
        targetView.style.display = 'block';

        if (targetId === 'stats-view' && !statsLoaded) {
          loadStatistics();
        }
      }
    });
  });

  async function loadStatistics() {
    try {
      const authHeader = 'Basic ' + window.btoa('admin:admin');
      const response = await fetch('/api/admin/stats', {
        headers: { 'Authorization': authHeader }
      });
      
      if (!response.ok) throw new Error('Failed to fetch statistics');
      
      const data = await response.json();
      renderSummaryTable(data.summary);
      renderTimelineTable(data.timeline);
      statsLoaded = true;
    } catch (error) {
      console.error(error);
      const errorRow = `<tr><td colspan="3" class="error">Failed to load statistics. ${error.message}</td></tr>`;
      document.querySelector('#statsSummaryTable tbody').innerHTML = errorRow;
      document.querySelector('#statsTimelineTable tbody').innerHTML = errorRow;
    }
  }

  function renderSummaryTable(summary) {
    const tbody = document.querySelector('#statsSummaryTable tbody');
    if (!summary || summary.length === 0) {
      tbody.innerHTML = '<tr><td colspan="3" class="muted">No attendance records found.</td></tr>';
      return;
    }

    tbody.innerHTML = summary.map(row => `
      <tr>
        <td><strong>${row.person || 'Unknown'}</strong></td>
        <td>${row.days_attended}</td>
        <td>${row.total_hours.toFixed(1)} hrs</td>
      </tr>
    `).join('');
  }

  function renderTimelineTable(timeline) {
    const tbody = document.querySelector('#statsTimelineTable tbody');
    if (!timeline || timeline.length === 0) {
      tbody.innerHTML = '<tr><td colspan="3" class="muted">No timeline records found.</td></tr>';
      return;
    }

    tbody.innerHTML = timeline.map(row => `
      <tr>
        <td><strong>${row.date}</strong></td>
        <td>${row.unique_people}</td>
        <td>${row.total_hours.toFixed(1)} hrs</td>
      </tr>
    `).join('');
  }
});
