async function loadDeviceInfo() {
  const infoDiv = document.getElementById('registerInfo');
  const deviceInfoDiv = document.getElementById('deviceInfo');
  const personInput = document.getElementById('personName');
  const deviceInput = document.getElementById('deviceName');
  const visibleCheckbox = document.getElementById('visibleCheckbox');
  const submitBtn = document.getElementById('submitBtn');
  const visibilityToggle = document.getElementById('visibilityToggle');
  const visibilityInfo = document.getElementById('visibilityInfo');

  try {
    const response = await fetch('/api/my-device');
    const data = await response.json();

    if (data.error) {
      infoDiv.className = 'register-info warning';
      infoDiv.textContent = data.error;
      submitBtn.disabled = true;
      return;
    }

    deviceInfoDiv.textContent = `Your IP: ${data.ip} | MAC: ${data.mac}`;

    if (data.registered) {
      infoDiv.className = 'register-info success';
      infoDiv.textContent = `✓ You're already registered as "${data.person}"${data.device ? ' with device "' + data.device + '"' : ''}`;
      personInput.value = data.person;
      deviceInput.value = data.device || '';
      visibleCheckbox.checked = data.visible;
      submitBtn.textContent = 'Update Registration';
      
      // Show visibility toggle section
      visibilityToggle.style.display = 'block';
      visibilityInfo.textContent = data.visible ? 
        '✓ You are currently visible on the presence list' : 
        '✗ You are currently hidden from the presence list';
    } else {
      infoDiv.className = 'register-info info';
      infoDiv.textContent = 'Your device is detected! Enter your name to register.';
    }
  } catch (e) {
    infoDiv.className = 'register-info error';
    infoDiv.textContent = 'Failed to load device info: ' + e.message;
    submitBtn.disabled = true;
  }
}

async function registerDevice(event) {
  event.preventDefault();
  
  const personInput = document.getElementById('personName');
  const deviceInput = document.getElementById('deviceName');
  const visibleCheckbox = document.getElementById('visibleCheckbox');
  const submitBtn = document.getElementById('submitBtn');
  const infoDiv = document.getElementById('registerInfo');

  const person = personInput.value.trim();
  const device = deviceInput.value.trim();
  const visible = visibleCheckbox.checked;

  if (!person) {
    infoDiv.className = 'register-info error';
    infoDiv.textContent = 'Please enter your name';
    return;
  }

  submitBtn.disabled = true;
  submitBtn.textContent = 'Registering...';

  try {
    const response = await fetch('/api/register', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ person, device, visible })
    });

    const data = await response.json();

    if (response.ok) {
      infoDiv.className = 'register-info success';
      infoDiv.textContent = `✓ ${data.message} Welcome, ${data.person}!`;
      submitBtn.textContent = 'Update Registration';
      setTimeout(() => window.location.reload(), 2000);
    } else {
      infoDiv.className = 'register-info error';
      infoDiv.textContent = `Error: ${data.error}`;
      submitBtn.disabled = false;
      submitBtn.textContent = 'Register';
    }
  } catch (e) {
    infoDiv.className = 'register-info error';
    infoDiv.textContent = 'Failed to register: ' + e.message;
    submitBtn.disabled = false;
    submitBtn.textContent = 'Register';
  }
}

async function toggleVisibility() {
  const toggleBtn = document.getElementById('toggleVisibilityBtn');
  const visibilityInfo = document.getElementById('visibilityInfo');
  const visibleCheckbox = document.getElementById('visibleCheckbox');

  toggleBtn.disabled = true;
  toggleBtn.textContent = 'Updating...';

  try {
    const response = await fetch('/api/toggle-visibility', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' }
    });

    const data = await response.json();

    if (response.ok) {
      visibleCheckbox.checked = data.visible;
      visibilityInfo.textContent = data.visible ? 
        '✓ You are now visible on the presence list' : 
        '✗ You are now hidden from the presence list';
      
      // Reload the page after a short delay to reflect changes
      setTimeout(() => window.location.reload(), 1500);
    } else {
      alert(`Error: ${data.error}`);
    }
  } catch (e) {
    alert('Failed to toggle visibility: ' + e.message);
  } finally {
    toggleBtn.disabled = false;
    toggleBtn.textContent = 'Toggle Visibility';
  }
}

function initializeRegistration() {
  loadDeviceInfo();
}
