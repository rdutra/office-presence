// Real-time presence updates for the mapped devices table

const INACTIVE_THRESHOLD_MS = 10 * 60 * 1000; // 10 minutes (remove from table)
const POLL_INTERVAL_MS = 10 * 1000; // Poll every 10 seconds

function initializePresence() {
  const table = document.getElementById('mapped-table');
  if (!table) return; // Not on the page with the table

  // Poll the API for updates
  startPolling();
}

async function startPolling() {
  // Initial update - wait for it to complete before starting interval
  await fetchAndUpdateTable();

  // Poll every 10 seconds
  setInterval(fetchAndUpdateTable, POLL_INTERVAL_MS);
}

async function fetchAndUpdateTable() {
  try {
    const response = await fetch('/api/presence');
    if (!response.ok) {
      console.error('Failed to fetch presence data:', response.statusText);
      return;
    }

    const devices = await response.json();
    const mapped = devices.filter(d => d.mapped);

    updateTable(mapped);
  } catch (error) {
    console.error('Error fetching presence data:', error);
  }
}

function updateTable(devices) {
  const tbody = document.querySelector('#mapped-table tbody');
  if (!tbody) return;

  const now = new Date();

  const presentDevices = devices.filter(device => {
    if (!device.last_seen_utc) return false;
    const lastSeen = new Date(device.last_seen_utc);
    const timeDiff = now - lastSeen;
    return timeDiff < INACTIVE_THRESHOLD_MS;
  });

  // Update badge count
  const badge = document.querySelector('.section h2 .badge');
  if (badge) {
    badge.textContent = presentDevices.length;
  }

  // If no devices, show empty message
  if (presentDevices.length === 0) {
    tbody.innerHTML = '<tr><td colspan="7" class="muted">No mapped people seen recently.</td></tr>';
    return;
  }

  // Build a map of existing rows by MAC address
  const existingRows = new Map();
  tbody.querySelectorAll('tr[data-mac]').forEach(row => {
    const mac = row.getAttribute('data-mac');
    existingRows.set(mac, row);
  });

  // Update or create rows
  presentDevices.forEach(device => {
    const existingRow = existingRows.get(device.mac);

    if (existingRow) {
      // Update existing row
      updateRow(existingRow, device, now);
      existingRows.delete(device.mac); // Mark as processed
    } else {
      // Create new row
      const newRow = createRow(device, now);
      tbody.appendChild(newRow);
    }
  });

  // Remove rows that are no longer present
  existingRows.forEach(row => {
    row.remove();
  });
}

function updateRow(row, device, now) {
  // Update last seen timestamp
  row.setAttribute('data-last-seen', device.last_seen_utc);

  const timestampSpan = row.querySelector('.timestamp');
  if (timestampSpan) {
    timestampSpan.setAttribute('data-utc', device.last_seen_utc);
    timestampSpan.textContent = formatLocalTime(device.last_seen_utc) || '—';
  }

  // Update status indicator with server-calculated status
  const indicator = row.querySelector('.status-indicator');
  if (indicator && device.status) {
    indicator.setAttribute('data-status', device.status);
  }

  // Update other fields (IP, hostname might change)
  const cells = row.querySelectorAll('td');
  if (cells.length >= 7) {
    cells[4].textContent = device.ip || '—'; // IP
    cells[5].textContent = device.hostname || '—'; // Hostname
  }
}

function createRow(device, now) {
  const row = document.createElement('tr');
  row.setAttribute('data-mac', device.mac);
  row.setAttribute('data-last-seen', device.last_seen_utc);

  const formattedTime = formatLocalTime(device.last_seen_utc) || '—';
  const status = device.status || 'calculating';

  row.innerHTML = `
    <td><span class="status-indicator" data-status="${status}">●</span></td>
    <td><strong>${device.person || '—'}</strong></td>
    <td>${device.device || '—'}</td>
    <td><span class="timestamp" data-utc="${device.last_seen_utc || ''}">${formattedTime}</span></td>
    <td>${device.ip || '—'}</td>
    <td>${device.hostname || '—'}</td>
    <td class="mac">${device.mac || '—'}</td>
  `;

  return row;
}
