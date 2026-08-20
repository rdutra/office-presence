(function setupYouTubePlaylist() {
  const iframeId = 'nostalgia-youtube-player';
  let player;
  let advancingAfterError = false;

  function initializePlayer() {
    const iframe = document.getElementById(iframeId);
    if (!iframe || !window.YT?.Player) return;

    player = new window.YT.Player(iframeId, {
      events: {
        onReady(event) {
          event.target.setShuffle(true);
        },
        onError(event) {
          if (advancingAfterError) return;

          advancingAfterError = true;
          try {
            event.target.nextVideo();
          } catch (error) {
            console.error('No se pudo avanzar la playlist de YouTube:', error);
          } finally {
            // Give YouTube time to emit the next video's state/error events.
            window.setTimeout(() => {
              advancingAfterError = false;
            }, 1000);
          }
        }
      }
    });
  }

  const previousReadyCallback = window.onYouTubeIframeAPIReady;
  window.onYouTubeIframeAPIReady = () => {
    if (typeof previousReadyCallback === 'function') previousReadyCallback();
    initializePlayer();
  };

  if (window.YT?.Player) {
    initializePlayer();
    return;
  }

  if (!document.getElementById('youtube-iframe-api')) {
    const script = document.createElement('script');
    script.id = 'youtube-iframe-api';
    script.src = 'https://www.youtube.com/iframe_api';
    document.head.appendChild(script);
  }
})();
