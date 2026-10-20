{{flutter_js}}
{{flutter_build_config}}

// Renderer and SDK-selected fallback fonts ship with the same release. Keep
// identity screens independent from renderer/font CDNs, including EN/ZH text.
// Paths resolve under the build base href, not against an external font host.
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: 'canvaskit/',
    fontFallbackBaseUrl: 'font-fallback/',
  },
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
});
