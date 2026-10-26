// Punto de entrada de Mivra web: pantalla de entrada (usuario y contraseña), barra de pestañas y arranque.

import * as auth from './auth.js';
import * as D from './datos.js';
import { hayCripto } from './cripto.js';
import { esc } from './util.js';
import {
  acciones, cambios, envios, registrarRender, toast, icono
} from './ui.js';
import * as hoy from './vistas/hoy.js';
import * as ingresos from './vistas/ingresos.js';
import * as fijos from './vistas/fijos.js';
import * as deudas from './vistas/deudas.js';
import * as metas from './vistas/metas.js';
import './vistas/ajustes.js';

const raiz = document.getElementById('app');

const PESTANAS = [
  { id: 'hoy', nombre: 'Hoy', icono: 'sol', vista: hoy },
  { id: 'ingresos', nombre: 'Ingresos', icono: 'ingresos', vista: ingresos },
  { id: 'fijos', nombre: 'Fijos', icono: 'fijos', vista: fijos },
  { id: 'deudas', nombre: 'Deudas', icono: 'deudas', vista: deudas },
  { id: 'metas', nombre: 'Metas', icono: 'metas', vista: metas }
];

const esIphone = /iphone|ipad|ipod/i.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
const instalada = (typeof matchMedia === 'function' && matchMedia('(display-mode: standalone)').matches) || navigator.standalone === true;

let pestana = leerPestana();
let modoEntrada = 'entrar';
let enApp = false;

function leerPestana() {
  try {
    const guardada = localStorage.getItem('mivra.pestana');
    if (PESTANAS.some((p) => p.id === guardada)) return guardada;
  } catch { /* sin almacenamiento */ }
  return 'hoy';
}

function guardarPestana() {
  try { localStorage.setItem('mivra.pestana', pestana); } catch { /* sin almacenamiento */ }
}

// ---------- Pantalla principal ----------

function dibujarApp() {
  if (!enApp || !D.datos()) return;
  const actual = PESTANAS.find((p) => p.id === pestana) || PESTANAS[0];
  const vista = actual.vista;
  const desplazamiento = window.scrollY;

  raiz.innerHTML = `
    <main class="contenedor">
      <div class="barra-titulo">
        <h1>${esc(vista.titulo)}</h1>
        <div class="barra-acciones">
          ${vista.botones ? vista.botones() : ''}
          <button type="button" class="btn-icono vidrio" data-accion="abrirAjustes" aria-label="Ajustes">${icono('ajustes')}</button>
        </div>
      </div>
      ${vista.render()}
    </main>
    <div class="pestanas">
      <nav class="vidrio" aria-label="Secciones">
        ${PESTANAS.map((p) => `
          <button type="button" class="${p.id === pestana ? 'activa' : ''}" data-accion="pestana" data-id="${p.id}"
            ${p.id === pestana ? 'aria-current="page"' : ''}>${icono(p.icono)}<span>${esc(p.nombre)}</span></button>`).join('')}
      </nav>
    </div>`;
  window.scrollTo(0, desplazamiento);
}

acciones.pestana = (el) => {
  if (el.dataset.id === pestana) { window.scrollTo({ top: 0, behavior: 'smooth' }); return; }
  pestana = el.dataset.id;
  guardarPestana();
  window.scrollTo(0, 0);
  dibujarApp();
};

registrarRender(dibujarApp);
let desuscribir = null;

function mostrarApp() {
  enApp = true;
  window.scrollTo(0, 0);
  if (desuscribir) desuscribir();
  desuscribir = D.suscribir(dibujarApp);
  D.alFallarGuardado((error) => {
    toast(error && error.message ? error.message : 'No se pudieron guardar los cambios.', 5000);
  });
  dibujarApp();
}

// ---------- Pantalla de entrada ----------

function mostrarEntrada(modo = 'entrar', usuario = '') {
  enApp = false;
  if (desuscribir) { desuscribir(); desuscribir = null; }
  modoEntrada = modo;
  const crear = modo === 'crear';
  document.body.classList.remove('sin-scroll');
  document.querySelectorAll('.capa').forEach((c) => c.remove());
  window.scrollTo(0, 0);

  raiz.innerHTML = `
    <div class="entrada">
      <img class="logo" src="icons/icon-192.png" alt="" width="92" height="92">
      <h1>Mivra</h1>
      <p class="lema">Tus finanzas, solo tuyas.</p>
      <div class="tarjeta vidrio">
        ${crear && esIphone && !instalada ? '<div class="aviso">📲 En iPhone, primero toca Compartir ⬆︎ → «Agregar a pantalla de inicio» y crea tu cuenta desde la app instalada. Safari guarda los datos aparte y puede borrarlos si no abres la página en una semana.</div>' : ''}
        ${hayCripto() ? '' : '<div class="aviso">Este navegador no permite el cifrado necesario. Abre Mivra desde su dirección https:// en un navegador actualizado (Chrome, Safari, Edge o Firefox).</div>'}
        <div class="segmentos" role="tablist">
          <button type="button" role="tab" class="${crear ? '' : 'activo'}" data-accion="modoEntrada" data-modo="entrar">Entrar</button>
          <button type="button" role="tab" class="${crear ? 'activo' : ''}" data-accion="modoEntrada" data-modo="crear">Crear cuenta</button>
        </div>
        <form data-envio="entrada" novalidate>
          <div class="error-form oculto" id="error-entrada" role="alert"></div>
          <label class="campo">
            <span class="etiqueta">Usuario</span>
            <input name="usuario" type="text" value="${esc(usuario)}" autocomplete="username" autocapitalize="none"
              autocorrect="off" spellcheck="false" maxlength="30" required>
            ${crear ? '<span class="ayuda">3 a 30 caracteres: letras, números y . _ - @</span>' : ''}
          </label>
          <label class="campo">
            <span class="etiqueta">Contraseña</span>
            <input name="clave" type="password" autocomplete="${crear ? 'new-password' : 'current-password'}" maxlength="128" required>
            ${crear ? '<span class="ayuda">Mínimo 8 caracteres, con letras y números.</span>' : ''}
          </label>
          ${crear ? `
          <label class="campo">
            <span class="etiqueta">Repite la contraseña</span>
            <input name="clave2" type="password" autocomplete="new-password" maxlength="128" required>
          </label>` : ''}
          <label class="check">
            <input type="checkbox" data-cambio="verClave">
            <span>Mostrar contraseña</span>
          </label>
          <label class="check">
            <input type="checkbox" name="recordar">
            <span>Mantener la sesión iniciada en este dispositivo. Úsalo solo en tu propio teléfono o computador.</span>
          </label>
          ${crear ? `
          <div class="aviso">Tu usuario y tu contraseña se guardan solo en este dispositivo y tus datos se cifran con ella. <b>Si la olvidas no hay forma de recuperarla</b>, y tus datos tampoco.</div>
          <label class="check">
            <input type="checkbox" name="entiendo">
            <span>Entiendo que no hay recuperación de contraseña.</span>
          </label>` : ''}
          <button type="submit" class="btn relleno ancho" id="boton-entrada">${crear ? 'Crear cuenta' : 'Entrar'}</button>
        </form>
      </div>
      <p class="pie-app">Sin servidor: tus datos no salen de este dispositivo.</p>
    </div>`;

  const campoUsuario = raiz.querySelector('[name="usuario"]');
  if (campoUsuario && !usuario) campoUsuario.focus({ preventScroll: true });
}

acciones.modoEntrada = (el) => {
  if (el.dataset.modo !== modoEntrada) mostrarEntrada(el.dataset.modo);
};

cambios.verClave = (el) => {
  raiz.querySelectorAll('input[name="clave"], input[name="clave2"]').forEach((c) => { c.type = el.checked ? 'text' : 'password'; });
};

function errorEntrada(mensaje) {
  const caja = document.getElementById('error-entrada');
  if (!caja) return;
  caja.textContent = mensaje;
  caja.classList.toggle('oculto', !mensaje);
}

envios.entrada = async (form) => {
  const boton = document.getElementById('boton-entrada');
  if (boton.disabled) return;
  const crear = modoEntrada === 'crear';
  const usuario = form.elements.usuario.value;
  const clave = form.elements.clave.value;
  const recordar = form.elements.recordar.checked;
  errorEntrada('');

  if (crear) {
    if (form.elements.clave2.value !== clave) { errorEntrada('Las contraseñas no coinciden.'); return; }
    if (!form.elements.entiendo.checked) { errorEntrada('Marca la casilla que confirma que entiendes que no hay recuperación de contraseña.'); return; }
  } else if (!usuario.trim() || !clave) {
    errorEntrada('Escribe tu usuario y tu contraseña.');
    return;
  }

  const textoOriginal = boton.textContent;
  boton.disabled = true;
  boton.textContent = crear ? 'Creando…' : 'Entrando…';
  try {
    if (crear) await auth.registrar(usuario, clave, recordar, D.datosVacios());
    else await auth.entrar(usuario, clave, recordar);
    await D.abrir();
    mostrarApp();
  } catch (error) {
    errorEntrada(error instanceof auth.ErrorAuth ? error.message : 'No se pudo completar. Inténtalo de nuevo.');
    boton.disabled = false;
    boton.textContent = textoOriginal;
    const campoClave = form.elements.clave;
    if (campoClave) { campoClave.value = ''; if (!crear) campoClave.focus(); }
    if (crear && form.elements.clave2) form.elements.clave2.value = '';
  }
};

document.addEventListener('mivra:salir', () => mostrarEntrada('entrar'));

// ---------- Eventos globales ----------

document.addEventListener('click', (evento) => {
  const el = evento.target.closest('[data-accion]');
  if (el) {
    const fn = acciones[el.dataset.accion];
    if (fn) {
      evento.preventDefault();
      Promise.resolve(fn(el, evento)).catch(() => toast('No se pudo completar la acción.'));
    }
    return;
  }
  // Chips fuera de las hojas (las hojas manejan los suyos).
  const chip = evento.target.closest('.chips button[data-valor]');
  if (chip && !chip.closest('.capa')) {
    const grupo = chip.closest('.chips');
    grupo.querySelectorAll('button').forEach((b) => b.classList.toggle('activo', b === chip));
    const oculto = grupo.querySelector('input[type="hidden"]');
    if (oculto) oculto.value = chip.dataset.valor;
  }
});

document.addEventListener('change', (evento) => {
  const el = evento.target.closest('[data-cambio]');
  if (!el) return;
  const fn = cambios[el.dataset.cambio];
  if (fn) Promise.resolve(fn(el, evento)).catch(() => toast('No se pudo completar la acción.'));
});

document.addEventListener('submit', (evento) => {
  const form = evento.target.closest('form[data-envio]');
  if (!form) return;
  evento.preventDefault();
  const fn = envios[form.dataset.envio];
  if (fn) Promise.resolve(fn(form, evento)).catch(() => toast('No se pudo completar la acción.'));
});

// Guardar antes de que la página se oculte o se cierre.
document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'hidden') D.guardarYa();
});
window.addEventListener('pagehide', () => { D.guardarYa(); });

// Instalación como app (Android/Chrome).
window.addEventListener('beforeinstallprompt', (evento) => {
  evento.preventDefault();
  globalThis.__mivraInstalar = evento;
});
window.addEventListener('appinstalled', () => { globalThis.__mivraInstalar = null; });

// Si cambió el día mientras la app estaba abierta en segundo plano, se redibuja al volver.
document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'visible' && enApp) dibujarApp();
});

// ---------- Arranque ----------

async function iniciar() {
  if ('serviceWorker' in navigator && location.protocol !== 'file:') {
    try { await navigator.serviceWorker.register('sw.js'); } catch { /* sin modo sin conexión */ }
  }
  try {
    const sesion = await auth.restaurarSesion();
    if (sesion) {
      await D.abrir();
      mostrarApp();
      return;
    }
  } catch {
    // Si la sesión recordada no se puede abrir, se pide la contraseña.
  }
  mostrarEntrada(auth.hayUsuarios() ? 'entrar' : 'crear');
}

iniciar();
