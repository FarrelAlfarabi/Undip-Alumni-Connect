// Keeps the page at 100% on iPhones.
//
// Tapping a field in a long form (Register a business) could zoom the page in
// on iOS and leave it zoomed: the right side cut off, no way to pinch out, and
// the Submit button out of reach. The viewport meta tag alone did not stop it.
// So this does three things:
//   1. blocks pinch zoom (iOS Safari's gesture events);
//   2. after a field loses focus, or whenever the visual viewport is zoomed
//      past 100%, replaces the viewport meta tag, which makes iOS snap back;
//   3. (in index.html) touch-action: manipulation stops double-tap zoom.
// It is a separate file because the Content-Security-Policy only allows
// scripts from this site.
(function () {
  'use strict';

  var CONTENT =
    'width=device-width, initial-scale=1.0, maximum-scale=1.0, ' +
    'minimum-scale=1.0, user-scalable=no';
  var timer = null;

  function zoomed() {
    var vv = window.visualViewport;
    return !!vv && vv.scale > 1.01;
  }

  function resetViewport() {
    var old = document.querySelector('meta[name="viewport"]');
    var meta = document.createElement('meta');
    meta.name = 'viewport';
    meta.content = CONTENT;
    if (old && old.parentNode) {
      old.parentNode.replaceChild(meta, old);
    } else if (document.head) {
      document.head.appendChild(meta);
    }
  }

  function resetIfZoomed(delay) {
    clearTimeout(timer);
    timer = setTimeout(function () {
      if (zoomed()) resetViewport();
    }, delay);
  }

  ['gesturestart', 'gesturechange', 'gestureend'].forEach(function (name) {
    document.addEventListener(
      name,
      function (e) {
        e.preventDefault();
      },
      { passive: false }
    );
  });

  document.addEventListener('focusout', function () {
    resetIfZoomed(300);
  }, true);

  if (window.visualViewport) {
    window.visualViewport.addEventListener('resize', function () {
      resetIfZoomed(150);
    });
  }
})();
