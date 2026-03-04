console.log('Easter template loaded! 🐰');

// Feature: "Toasty" style Jesus popup
document.addEventListener('DOMContentLoaded', () => {
    const toastyImg = document.createElement('img');
    toastyImg.src = '/img/easter/Jesus.jpg';
    toastyImg.id = 'jesus-toasty';
    document.body.appendChild(toastyImg);

    function triggerToasty() {
        toastyImg.classList.add('show');

        // Hide after an appropriate amount of time (1.5 seconds)
        setTimeout(() => {
            toastyImg.classList.remove('show');
        }, 1500);
    }

    function scheduleNextToasty() {
        // Random time between 1 and 4 minutes to pop up
        const minTime = 1 * 60 * 1000;
        const maxTime = 4 * 60 * 1000;
        const nextTime = Math.random() * (maxTime - minTime) + minTime;

        setTimeout(() => {
            triggerToasty();
            scheduleNextToasty();
        }, nextTime);
    }

    // Kick off the schedule after first load
    scheduleNextToasty();

    // Also trigger it manually maybe if someone clicks on a certain stat card?
    // Could add more triggers here if they want, later.
});
