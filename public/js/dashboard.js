function initializeDashboard() {
  initializeTimezone();
  
  // Auto-refresh every 60 seconds
  setInterval(() => {
    window.location.reload();
  }, 60000);
}

document.addEventListener('DOMContentLoaded', initializeDashboard);
