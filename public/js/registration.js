async function loadDeviceInfo() {
  const infoDiv = document.getElementById('registerInfo');
  const deviceInfoDiv = document.getElementById('deviceInfo');
  const personInput = document.getElementById('personName');
  const deviceInput = document.getElementById('deviceName');
  const submitBtn = document.getElementById('submitBtn');

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
      submitBtn.textContent = 'Update Registration';
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
  const submitBtn = document.getElementById('submitBtn');
  const infoDiv = document.getElementById('registerInfo');

  const person = personInput.value.trim();
  const device = deviceInput.value.trim();

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
      body: JSON.stringify({ person, device })
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

function initializeRegistration() {
  loadDeviceInfo();
}
