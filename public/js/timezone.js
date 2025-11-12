// Convert UTC timestamps to local timezone
function formatLocalTime(utcString) {
  if (!utcString || utcString === '—') return utcString;
  try {
    // Parse the UTC time - it already has Z suffix if in ISO8601 format
    // Otherwise add Z to indicate UTC
    const dateString = utcString.includes('Z') || utcString.includes('+')
      ? utcString
      : utcString + 'Z';
    const date = new Date(dateString);
    if (isNaN(date.getTime())) return utcString;

    // Format as YYYY-MM-DD HH:MM in local timezone
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    const hours = String(date.getHours()).padStart(2, '0');
    const minutes = String(date.getMinutes()).padStart(2, '0');

    return `${year}-${month}-${day} ${hours}:${minutes}`;
  } catch (e) {
    return utcString;
  }
}

function getTimezoneAbbr() {
  const date = new Date();
  const timeZone = Intl.DateTimeFormat().resolvedOptions().timeZone;
  const short = date.toLocaleTimeString('en-us', { timeZoneName: 'short' }).split(' ')[2];
  return short || timeZone;
}

function initializeTimezone() {
  document.querySelectorAll('.timestamp').forEach(function(el) {
    const utcTime = el.getAttribute('data-utc');
    el.textContent = formatLocalTime(utcTime);
  });

  const currentTimeEl = document.querySelector('.current-time');
  if (currentTimeEl) {
    const utcTime = currentTimeEl.getAttribute('data-utc');
    const fullTime = formatLocalTime(utcTime);
    currentTimeEl.textContent = fullTime.split(' ')[1]; // Extract just the HH:MM part
  }

  const tzLabel = document.querySelector('.tz-label');
  if (tzLabel) {
    tzLabel.textContent = getTimezoneAbbr();
  }
}
