// Service worker — no longer needed for MIME type fixing.
// All GWT scripts use .js extension natively.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});
