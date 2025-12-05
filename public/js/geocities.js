(function() {
  const modal = document.getElementById('registrationModal');
  const openLink = document.querySelector('[data-guestbook-link]');
  const closeBtn = document.getElementById('closeRegistrationBtn');
  const overlay = modal?.querySelector('.modal-overlay');

  const openModal = (event) => {
    event?.preventDefault();
    modal?.classList.add('is-open');
    modal?.setAttribute('aria-hidden', 'false');
    document.body.classList.add('modal-open');
    if (typeof initializeRegistration === 'function') {
      initializeRegistration();
    }
  };

  const closeModal = () => {
    modal?.classList.remove('is-open');
    modal?.setAttribute('aria-hidden', 'true');
    document.body.classList.remove('modal-open');
  };

  openLink?.addEventListener('click', openModal);
  closeBtn?.addEventListener('click', closeModal);
  overlay?.addEventListener('click', closeModal);
  document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && modal?.classList.contains('is-open')) {
      closeModal();
    }
  });

  function buildOdometer(el, value) {
    if (!el) return;
    const digits = String(Math.max(0, value)).padStart(6, '0').split('');
    el.innerHTML = digits.map((d, idx) => {
      return `
        <span class="geo-digit" data-digit-index="${idx}">
          <span class="geo-digit-wheel">
            <span>0</span><span>1</span><span>2</span><span>3</span><span>4</span><span>5</span><span>6</span><span>7</span><span>8</span><span>9</span>
          </span>
        </span>
      `;
    }).join('');

    requestAnimationFrame(() => {
      el.querySelectorAll('.geo-digit-wheel').forEach((wheel, i) => {
        const target = parseInt(digits[i], 10);
        const delay = i * 80;
        setTimeout(() => {
          wheel.style.transition = 'transform 1.2s ease-in-out';
          wheel.style.transform = `translateY(-${target * 10}%)`;
        }, delay);
      });
    });
  }

  function setOdometerValue(el, value) {
    if (!el) return;
    const normalized = Math.max(0, value);
    el.dataset.value = String(normalized);
    const digits = String(normalized).padStart(6, '0').split('');
    el.querySelectorAll('.geo-digit-wheel').forEach((wheel, i) => {
      const target = parseInt(digits[i], 10);
      const delay = i * 60;
      setTimeout(() => {
        wheel.style.transition = 'transform 1.4s ease-in-out';
        wheel.style.transform = `translateY(-${target * 10}%)`;
      }, delay);
    });
  }

  const counterEl = document.querySelector('[data-hit-counter]');
  const counterValue = parseInt(counterEl?.dataset.value || '0', 10);
  buildOdometer(counterEl, counterValue);

  let odometerTimer = null;
  function startOdometer() {
    if (!counterEl) return;
    if (odometerTimer) clearInterval(odometerTimer);
    odometerTimer = setInterval(() => {
      const current = parseInt(counterEl.dataset.value || '0', 10) || 0;
      const increment = Math.floor(Math.random() * 3) + 1; // 1-3 visitors
      const next = current + increment;
      setOdometerValue(counterEl, next);
    }, 4500);
  }
  startOdometer();

  function tickClock() {
    const el = document.getElementById('geo-current-time');
    if (!el || !el.dataset.utc) return;
    const iso = el.dataset.utc;
    const date = new Date(iso);
    if (Number.isNaN(date.getTime())) return;
    date.setSeconds(date.getSeconds() + 1);
    el.dataset.utc = date.toISOString();
    const hours = String(date.getHours()).padStart(2, '0');
    const minutes = String(date.getMinutes()).padStart(2, '0');
    el.textContent = `${hours}:${minutes}`;
  }
  setInterval(tickClock, 1000);
})();
