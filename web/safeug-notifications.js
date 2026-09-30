self.addEventListener('install', event => event.waitUntil(self.skipWaiting()));
self.addEventListener('activate', event => event.waitUntil(self.clients.claim()));
self.addEventListener('notificationclick', event => {
  event.notification.close();
  const path = event.notification.data?.url === '/admin/' ? '/admin/' : '/';
  event.waitUntil((async () => {
    const windows = await self.clients.matchAll({type:'window',includeUncontrolled:true});
    const target = windows.find(client => new URL(client.url).pathname === path);
    if (target) return target.focus();
    return self.clients.openWindow(path);
  })());
});
