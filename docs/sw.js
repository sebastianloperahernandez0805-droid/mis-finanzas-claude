// Service worker de Mivra: deja la app disponible sin conexión.
// Estrategia: primero la red (así siempre recibes la versión más nueva) y, si no hay internet,
// lo último que se guardó. Los datos del usuario NO pasan por aquí: viven cifrados en el dispositivo.
const VERSION = 'mivra-web-1';

const ARCHIVOS = [
  './',
  'index.html',
  'manifest.webmanifest',
  'css/app.css',
  'js/app.js',
  'js/util.js',
  'js/cripto.js',
  'js/auth.js',
  'js/datos.js',
  'js/calculos.js',
  'js/ui.js',
  'js/vistas/comun.js',
  'js/vistas/hoy.js',
  'js/vistas/ingresos.js',
  'js/vistas/fijos.js',
  'js/vistas/deudas.js',
  'js/vistas/metas.js',
  'js/vistas/ajustes.js',
  'icons/icon-192.png',
  'icons/icon-512.png',
  'icons/apple-touch-icon.png'
];

self.addEventListener('install', (evento) => {
  evento.waitUntil(
    caches.open(VERSION)
      .then((cache) => cache.addAll(ARCHIVOS))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (evento) => {
  evento.waitUntil(
    caches.keys()
      .then((nombres) => Promise.all(nombres.filter((n) => n !== VERSION).map((n) => caches.delete(n))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (evento) => {
  const peticion = evento.request;
  if (peticion.method !== 'GET') return;
  const url = new URL(peticion.url);
  if (url.origin !== self.location.origin) return;

  evento.respondWith(
    fetch(peticion)
      .then((respuesta) => {
        if (respuesta && respuesta.ok) {
          const copia = respuesta.clone();
          caches.open(VERSION).then((cache) => cache.put(peticion, copia));
        }
        return respuesta;
      })
      .catch(() =>
        caches.match(peticion).then((guardada) => guardada || caches.match('index.html'))
      )
  );
});
