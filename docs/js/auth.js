// Usuarios y contraseñas guardados SOLO en este dispositivo (no hay servidor).
//
// - La lista de usuarios (nombre, sal y número de iteraciones) está en localStorage.
// - Los datos de cada usuario están cifrados con una clave que sale de su contraseña.
//   La contraseña no se guarda en ningún lado: si se olvida, no hay forma de recuperar los datos.
// - Con «mantener la sesión» se guarda en IndexedDB la clave derivada (no extraíble), para no pedir
//   la contraseña cada vez que se abre la app en ese dispositivo.

import { aB64, deB64, saltNuevo, derivarClave, cifrar, descifrar, ITERACIONES, hayCripto } from './cripto.js';
import { uuid, aIso } from './util.js';

const CLAVE_USUARIOS = 'mivra.usuarios';
const PREFIJO_DATOS = 'mivra.datos.';
const MENSAJE_INVALIDO = 'Usuario o contraseña incorrectos.';

export class ErrorAuth extends Error {}

let sesion = null; // { id, usuario, clave }
const fallos = new Map();

// ---------- Lista de usuarios ----------

function leerUsuarios() {
  try {
    const lista = JSON.parse(localStorage.getItem(CLAVE_USUARIOS) || '[]');
    return Array.isArray(lista) ? lista : [];
  } catch {
    return [];
  }
}

function guardarUsuarios(lista) {
  try {
    localStorage.setItem(CLAVE_USUARIOS, JSON.stringify(lista));
  } catch {
    throw new ErrorAuth('No se pudo guardar en este dispositivo. Revisa que el navegador permita guardar datos y que no estés en una ventana privada.');
  }
}

export function hayUsuarios() {
  return leerUsuarios().length > 0;
}

export function sesionActual() {
  return sesion;
}

const normalizar = (nombre) => nombre.trim().toLowerCase();

export function validarUsuario(nombre) {
  const limpio = (nombre || '').trim();
  if (limpio.length < 3) return 'El usuario debe tener al menos 3 caracteres.';
  if (limpio.length > 30) return 'El usuario puede tener máximo 30 caracteres.';
  if (!/^[\p{L}\p{N}._@-]+$/u.test(limpio)) return 'Usa solo letras, números y los signos . _ - @ (sin espacios).';
  return null;
}

export function validarContrasena(contrasena, usuario = '') {
  if ((contrasena || '').length < 8) return 'La contraseña debe tener al menos 8 caracteres.';
  if (contrasena.length > 128) return 'La contraseña puede tener máximo 128 caracteres.';
  if (usuario && contrasena.trim().toLowerCase() === usuario.trim().toLowerCase()) {
    return 'La contraseña no puede ser igual al usuario.';
  }
  if (!/\d/.test(contrasena) || !/\p{L}/u.test(contrasena)) {
    return 'Combina letras y números para que sea más segura.';
  }
  return null;
}

// ---------- Sesión recordada (IndexedDB) ----------

function abrirDB() {
  return new Promise((resolver, rechazar) => {
    if (!('indexedDB' in globalThis)) { rechazar(new Error('sin indexedDB')); return; }
    const peticion = indexedDB.open('mivra-sesion', 1);
    peticion.onupgradeneeded = () => peticion.result.createObjectStore('claves');
    peticion.onsuccess = () => resolver(peticion.result);
    peticion.onerror = () => rechazar(peticion.error);
  });
}

async function guardarSesionRecordada(id, clave) {
  try {
    const db = await abrirDB();
    await new Promise((resolver, rechazar) => {
      const t = db.transaction('claves', 'readwrite');
      t.objectStore('claves').put({ id, clave }, 'actual');
      t.oncomplete = resolver;
      t.onerror = () => rechazar(t.error);
    });
    db.close();
  } catch {
    // Si el navegador no deja guardarla, simplemente se pedirá la contraseña la próxima vez.
  }
}

async function leerSesionRecordada() {
  try {
    const db = await abrirDB();
    const valor = await new Promise((resolver, rechazar) => {
      const t = db.transaction('claves', 'readonly');
      const p = t.objectStore('claves').get('actual');
      p.onsuccess = () => resolver(p.result || null);
      p.onerror = () => rechazar(p.error);
    });
    db.close();
    return valor;
  } catch {
    return null;
  }
}

async function borrarSesionRecordada() {
  try {
    const db = await abrirDB();
    await new Promise((resolver) => {
      const t = db.transaction('claves', 'readwrite');
      t.objectStore('claves').delete('actual');
      t.oncomplete = resolver;
      t.onerror = resolver;
    });
    db.close();
  } catch {
    // nada que borrar
  }
}

export async function hayRecordada() {
  return Boolean(await leerSesionRecordada());
}

// ---------- Registro y entrada ----------

export async function registrar(usuario, contrasena, recordar, datosIniciales) {
  if (!hayCripto()) {
    throw new ErrorAuth('Este navegador no permite el cifrado necesario. Abre Mivra desde su dirección https:// en un navegador actualizado.');
  }
  const errorUsuario = validarUsuario(usuario);
  if (errorUsuario) throw new ErrorAuth(errorUsuario);
  const errorClave = validarContrasena(contrasena, usuario);
  if (errorClave) throw new ErrorAuth(errorClave);

  const lista = leerUsuarios();
  const norm = normalizar(usuario);
  if (lista.some((u) => u.norm === norm)) {
    throw new ErrorAuth('Ese usuario ya existe en este dispositivo. Elige otro o entra con él.');
  }

  const id = uuid();
  const salt = saltNuevo();
  const clave = await derivarClave(contrasena, salt, ITERACIONES);
  const blob = await cifrar(clave, JSON.stringify(datosIniciales));

  try {
    localStorage.setItem(PREFIJO_DATOS + id, blob);
  } catch {
    throw new ErrorAuth('No se pudo guardar en este dispositivo. Revisa que el navegador permita guardar datos y que no estés en una ventana privada.');
  }
  lista.push({ id, usuario: usuario.trim(), norm, salt: aB64(salt), iter: ITERACIONES, creado: aIso() });
  guardarUsuarios(lista);

  sesion = { id, usuario: usuario.trim(), clave };
  if (recordar) await guardarSesionRecordada(id, clave);
  try { await navigator.storage?.persist?.(); } catch { /* opcional */ }
  return sesion;
}

function anotarFallo(norm) {
  const previo = fallos.get(norm) || { n: 0, hasta: 0 };
  const n = previo.n + 1;
  // Desde el 4.º intento fallido se espera cada vez más (2, 4, 8... hasta 60 segundos).
  const espera = n >= 4 ? Math.min(2 ** (n - 3), 60) * 1000 : 0;
  fallos.set(norm, { n, hasta: Date.now() + espera });
}

export async function entrar(usuario, contrasena, recordar) {
  if (!hayCripto()) {
    throw new ErrorAuth('Este navegador no permite el cifrado necesario. Abre Mivra desde su dirección https:// en un navegador actualizado.');
  }
  const norm = normalizar(usuario || '');
  const estado = fallos.get(norm);
  if (estado && estado.hasta > Date.now()) {
    throw new ErrorAuth(`Demasiados intentos. Espera ${Math.ceil((estado.hasta - Date.now()) / 1000)} segundos.`);
  }

  const registro = leerUsuarios().find((u) => u.norm === norm);
  if (!registro) {
    anotarFallo(norm);
    throw new ErrorAuth(MENSAJE_INVALIDO);
  }

  const clave = await derivarClave(contrasena || '', deB64(registro.salt), registro.iter);
  const blob = localStorage.getItem(PREFIJO_DATOS + registro.id);
  if (!blob) throw new ErrorAuth('No se encontraron los datos de este usuario en el dispositivo.');
  try {
    await descifrar(clave, blob);
  } catch {
    anotarFallo(norm);
    throw new ErrorAuth(MENSAJE_INVALIDO);
  }

  fallos.delete(norm);
  sesion = { id: registro.id, usuario: registro.usuario, clave };
  if (recordar) await guardarSesionRecordada(registro.id, clave);
  else await borrarSesionRecordada();
  return sesion;
}

/** Si en este dispositivo se eligió mantener la sesión, la reabre sin pedir la contraseña. */
export async function restaurarSesion() {
  const guardada = await leerSesionRecordada();
  if (!guardada) return null;
  const registro = leerUsuarios().find((u) => u.id === guardada.id);
  const blob = registro ? localStorage.getItem(PREFIJO_DATOS + registro.id) : null;
  if (!registro || !blob) { await borrarSesionRecordada(); return null; }
  try {
    await descifrar(guardada.clave, blob);
  } catch {
    await borrarSesionRecordada();
    return null;
  }
  sesion = { id: registro.id, usuario: registro.usuario, clave: guardada.clave };
  return sesion;
}

export async function salir() {
  sesion = null;
  await borrarSesionRecordada();
}

// ---------- Datos cifrados del usuario ----------

export async function leerTexto() {
  if (!sesion) throw new ErrorAuth('No hay una sesión abierta.');
  const blob = localStorage.getItem(PREFIJO_DATOS + sesion.id);
  if (!blob) throw new ErrorAuth('No se encontraron los datos de este usuario.');
  return descifrar(sesion.clave, blob);
}

export async function guardarTexto(texto) {
  if (!sesion) throw new ErrorAuth('No hay una sesión abierta.');
  const blob = await cifrar(sesion.clave, texto);
  try {
    localStorage.setItem(PREFIJO_DATOS + sesion.id, blob);
  } catch {
    throw new ErrorAuth('No hay espacio para guardar. Exporta una copia de seguridad y borra datos viejos.');
  }
}

// ---------- Cuenta ----------

async function verificar(registro, contrasena) {
  const clave = await derivarClave(contrasena || '', deB64(registro.salt), registro.iter);
  const blob = localStorage.getItem(PREFIJO_DATOS + registro.id);
  if (!blob) throw new ErrorAuth('No se encontraron los datos de este usuario.');
  try {
    await descifrar(clave, blob);
  } catch {
    throw new ErrorAuth('La contraseña actual no es correcta.');
  }
}

/** Cambia la contraseña y vuelve a cifrar los datos con la nueva. `textoActual` son los datos en pantalla. */
export async function cambiarContrasena(actual, nueva, textoActual) {
  if (!sesion) throw new ErrorAuth('No hay una sesión abierta.');
  const lista = leerUsuarios();
  const registro = lista.find((u) => u.id === sesion.id);
  if (!registro) throw new ErrorAuth('No se encontró el usuario.');

  const errorClave = validarContrasena(nueva, registro.usuario);
  if (errorClave) throw new ErrorAuth(errorClave);
  await verificar(registro, actual);

  const salt = saltNuevo();
  const clave = await derivarClave(nueva, salt, ITERACIONES);
  const blob = await cifrar(clave, textoActual);
  try {
    localStorage.setItem(PREFIJO_DATOS + registro.id, blob);
  } catch {
    throw new ErrorAuth('No se pudo guardar en este dispositivo.');
  }
  registro.salt = aB64(salt);
  registro.iter = ITERACIONES;
  guardarUsuarios(lista);

  const estabaRecordada = await hayRecordada();
  sesion.clave = clave;
  if (estabaRecordada) await guardarSesionRecordada(sesion.id, clave);
}

/** Borra el usuario y todos sus datos de este dispositivo. */
export async function borrarCuenta(contrasena) {
  if (!sesion) throw new ErrorAuth('No hay una sesión abierta.');
  const lista = leerUsuarios();
  const registro = lista.find((u) => u.id === sesion.id);
  if (!registro) throw new ErrorAuth('No se encontró el usuario.');
  await verificar(registro, contrasena).catch(() => {
    throw new ErrorAuth('La contraseña no es correcta.');
  });
  localStorage.removeItem(PREFIJO_DATOS + registro.id);
  guardarUsuarios(lista.filter((u) => u.id !== registro.id));
  await salir();
}
