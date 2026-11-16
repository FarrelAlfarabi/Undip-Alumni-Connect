// Takes the start screen away once Flutter has drawn its first frame.
//
// The start screen itself is plain HTML in index.html, so something shows
// at once while the app code downloads. This is a separate file because the
// Content-Security-Policy only allows scripts from this site.
(function () {
  'use strict';

  var done = false;

  function remove() {
    if (done) return;
    done = true;
    var el = document.getElementById('splash');
    if (!el) return;
    el.className = 'hide';
    setTimeout(function () {
      if (el.parentNode) el.parentNode.removeChild(el);
    }, 250);
  }

  window.addEventListener('flutter-first-frame', remove);
  // Safety net: never leave the start screen over a running app.
  window.addEventListener('load', function () {
    setTimeout(remove, 20000);
  });
})();
