{{flutter_js}}
{{flutter_build_config}}

// The production image already contains the renderer under /canvaskit. Keep
// hosted login independent from an external renderer CDN so an identity flow
// cannot fail because that CDN is unavailable or the network changes.
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: 'canvaskit/',
  },
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
});
