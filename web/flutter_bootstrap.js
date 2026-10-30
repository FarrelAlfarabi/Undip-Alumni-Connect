{{flutter_js}}
{{flutter_build_config}}

// No service worker. Flutter's worker cached the app in the browser, so a
// new deploy only showed after several reloads. Remove any worker an
// earlier build installed (Flutter's own flutter_service_worker.js also
// unregisters itself), then load the app straight from the network.
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.getRegistrations().then(function (regs) {
    regs.forEach(function (r) { r.unregister(); });
  });
}

_flutter.loader.load();
