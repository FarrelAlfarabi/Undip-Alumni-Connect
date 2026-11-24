// Zoom that never gets stuck.
//
// Flutter replaces the viewport meta tag in index.html with its own
// (maximum-scale=5.0), so phones can still zoom in: a tapped field on iOS, a
// double tap, or the "force enable zoom" accessibility setting on Android.
// Once the page is zoomed, a pinch lands on the Flutter canvas, which keeps
// the touches for itself, so the browser never zooms back out: the page stays
// zoomed with no way out (Farrel, 24 Nov 2026).
//
// Phones and tablets (any touch screen):
//   1. iOS pinch gesture events are blocked;
//   2. the viewport tag is kept at maximum-scale=1 (also after Flutter writes
//      its own), and whenever the page is zoomed past 100% while no field is
//      being typed in, the tag is written again, which snaps the page back;
//   3. (in index.html) touch-action: manipulation stops double-tap zoom.
//
// Computers: Ctrl + mouse wheel and a trackpad pinch are browser zoom. Flutter
// takes these wheel events for itself and cancels them, so zooming out with
// the trackpad did nothing. They are passed to the browser instead (the app
// has no pinch-to-zoom of its own). Ctrl + plus / minus keep working too.
//
// It is a separate file because the Content-Security-Policy only allows
// scripts from this site.
(function () {
  'use strict';

  var ua = navigator.userAgent || '';
  // An iPad asks for the desktop site and calls itself a Mac, but it is the
  // only "Mac" with a touch screen.
  var isIOS =
    /iPhone|iPad|iPod/.test(ua) ||
    (/Macintosh/.test(ua) && navigator.maxTouchPoints > 1);
  var isPhoneOrTablet =
    isIOS || /Android|Mobile/.test(ua) ||
    (navigator.maxTouchPoints > 0 && !window.matchMedia('(pointer: fine)').matches);

  if (!isPhoneOrTablet) {
    // Computer: let Ctrl + wheel and trackpad pinch zoom the page.
    window.addEventListener(
      'wheel',
      function (e) {
        if (e.ctrlKey) e.stopImmediatePropagation();
      },
      { capture: true, passive: true }
    );
    return;
  }

  var CONTENT =
    'width=device-width, initial-scale=1.0, maximum-scale=1.0, ' +
    'minimum-scale=1.0, user-scalable=no';
  var timer = null;
  var writing = false;

  function zoomed() {
    var vv = window.visualViewport;
    return !!vv && vv.scale > 1.01;
  }

  function typing() {
    var el = document.activeElement;
    if (!el) return false;
    var tag = (el.tagName || '').toLowerCase();
    return tag === 'input' || tag === 'textarea' || el.isContentEditable;
  }

  // Writes a fresh viewport tag. Replacing the element (not only its content)
  // is what makes iOS Safari snap back to 100%.
  function resetViewport() {
    writing = true;
    var metas = document.querySelectorAll('meta[name="viewport"]');
    var meta = document.createElement('meta');
    meta.name = 'viewport';
    meta.content = CONTENT;
    if (metas.length && metas[0].parentNode) {
      // Keep Flutter's marker so Flutter still finds "its" tag.
      if (metas[0].hasAttribute('flt-viewport')) {
        meta.setAttribute('flt-viewport', '');
      }
      metas[0].parentNode.replaceChild(meta, metas[0]);
      for (var i = 1; i < metas.length; i++) {
        if (metas[i].parentNode) metas[i].parentNode.removeChild(metas[i]);
      }
    } else if (document.head) {
      document.head.appendChild(meta);
    }
    writing = false;
  }

  function resetIfZoomed(delay) {
    clearTimeout(timer);
    timer = setTimeout(function () {
      if (zoomed() && !typing()) resetViewport();
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

  // Flutter writes its own tag (maximum-scale=5.0) while it starts. Put ours
  // back each time.
  if (window.MutationObserver) {
    new MutationObserver(function () {
      if (writing) return;
      var m = document.querySelector('meta[name="viewport"]');
      if (m && m.content !== CONTENT) resetViewport();
    }).observe(document.head || document.documentElement, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ['content'],
    });
  }
})();
