// Service Worker for Paw Feed PWA
const CACHE_NAME = 'pawfeed-v1';
const urlsToCache = [
  '/',
  '/fone.css',
  '/logo.png',
  '/default_beep.mp3',
  '/chime.mp3',
  '/bark.mp3',
  '/meow.mp3',
  '/birds.mp3'
];

// Install event - cache resources
self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => cache.addAll(urlsToCache))
  );
  self.skipWaiting();
});

// Activate event - clean old caches
self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(cacheNames => {
      return Promise.all(
        cacheNames.map(cacheName => {
          if (cacheName !== CACHE_NAME) {
            return caches.delete(cacheName);
          }
        })
      );
    })
  );
  self.clients.claim();
});

// Fetch event - serve from cache when offline
self.addEventListener('fetch', event => {
  event.respondWith(
    caches.match(event.request)
      .then(response => response || fetch(event.request))
  );
});

// Handle push notifications
self.addEventListener('push', event => {
  const data = event.data.json();
  const options = {
    body: data.body,
    icon: '/icon-192.png',
    badge: '/icon-192.png',
    vibrate: [200, 100, 200],
    tag: 'feeding-alarm',
    requireInteraction: true,
    actions: [
      { action: 'fed', title: 'Mark as Fed' },
      { action: 'snooze', title: 'Snooze 5 min' }
    ]
  };
  
  event.waitUntil(
    self.registration.showNotification(data.title, options)
  );
});

// Handle notification clicks
self.addEventListener('notificationclick', event => {
  event.notification.close();
  
  if (event.action === 'fed') {
    // Handle "Mark as Fed" action
    event.waitUntil(
      clients.openWindow('/?action=fed')
    );
  } else if (event.action === 'snooze') {
    // Handle "Snooze" action
    event.waitUntil(
      clients.openWindow('/?action=snooze')
    );
  } else {
    // Open app
    event.waitUntil(
      clients.openWindow('/')
    );
  }
});