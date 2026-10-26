// Ajustes: moneda, copia de seguridad, instalación y cuenta (contraseña, cerrar sesión, borrar).

import * as D from '../datos.js';
import * as auth from '../auth.js';
import { esc, fijarMoneda, MONEDAS, aCampoFecha } from '../util.js';
import {
  acciones, cambios, toast, abrirHoja, confirmar, campo, leerCampos, campoSelect
} from '../ui.js';
import { enlazarLocal } from './comun.js';

const VERSION_APP = '1.0';

function hayInstalacionDirecta() {
  return Boolean(globalThis.__mivraInstalar);
}

function yaInstalada() {
  return (typeof matchMedia === 'function' && matchMedia('(display-mode: standalone)').matches)
    || globalThis.navigator?.standalone === true;
}

function cuerpoAjustes() {
  const sesion = auth.sesionActual();
  const moneda = D.datos().ajustes.moneda;
  const resumen = D.resumenDe(D.datos());
  const esIphone = /iphone|ipad|ipod/i.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);

  return `
    <div class="tarjeta vidrio mb">
      <div class="sec peq">Sesión iniciada como</div>
      <div style="font-weight:700;font-size:1.15rem;margin-bottom:12px">${esc(sesion ? sesion.usuario : '')}</div>
      <div class="btns">
        <button type="button" class="btn vidrio" data-local="salir">Cerrar sesión</button>
        <button type="button" class="btn vidrio" data-local="clave">Cambiar clave</button>
      </div>
    </div>

    <div class="tarjeta vidrio mb">
      <h2>Moneda</h2>
      ${campoSelect({ nombre: 'moneda', etiqueta: 'Moneda para mostrar los montos', valor: moneda, opciones: MONEDAS })}
      <p class="peq sec" style="margin:0">Solo cambia cómo se escriben los montos; no convierte valores.</p>
    </div>

    <div class="tarjeta vidrio mb">
      <h2>Copia de seguridad</h2>
      <p class="peq sec" style="margin-top:0">Tus datos viven solo en este dispositivo y no hay forma de recuperarlos si se pierde el teléfono o borras los datos del navegador. Guarda una copia de vez en cuando.</p>
      ${resumen.length ? `<p class="peq" style="margin:0 0 12px">Ahora tienes: ${esc(resumen.join(', '))}.</p>` : ''}
      <div class="btns">
        <button type="button" class="btn vidrio" data-local="exportar">Guardar copia</button>
        <button type="button" class="btn vidrio" data-local="importar">Abrir copia</button>
      </div>
      <input type="file" class="oculto" accept=".json,application/json" data-cambio="archivoCopia" aria-label="Archivo de copia de seguridad">
      <p class="peq sec" style="margin:12px 0 0">Las copias sirven entre esta página y la app de iPhone de Mivra: la hecha en una se puede abrir en la otra.</p>
    </div>

    <div class="tarjeta vidrio mb">
      <h2>Instalar en tu teléfono</h2>
      ${yaInstalada()
        ? '<p class="peq sec" style="margin:0">Ya estás usando Mivra como app instalada. 🎉</p>'
        : `
        ${hayInstalacionDirecta() ? '<button type="button" class="btn relleno ancho mb" data-local="instalar">Instalar Mivra</button>' : ''}
        <p class="peq" style="margin:0 0 6px"><b>Android (Chrome):</b> menú ⋮ → «Instalar app» o «Añadir a la pantalla de inicio».</p>
        <p class="peq" style="margin:0"><b>iPhone (Safari):</b> botón Compartir ⬆︎ → «Agregar a pantalla de inicio». Debe ser desde Safari. La app instalada guarda sus datos aparte de Safari: crea tu cuenta (o abre una copia) desde ella.</p>`}
    </div>

    <div class="tarjeta vidrio mb">
      <h2>Privacidad</h2>
      <p class="peq sec" style="margin:0 0 8px">No hay servidor ni cuentas en internet: el usuario y la contraseña solo existen en este dispositivo. Tus datos se guardan cifrados con tu contraseña y nunca salen de aquí.</p>
      <p class="peq sec" style="margin:0">Si olvidas la contraseña no se puede recuperar: tendrías que crear otra cuenta y abrir una copia de seguridad.</p>
    </div>

    <div class="tarjeta vidrio mb">
      <button type="button" class="btn peligro ancho" data-local="borrar">Borrar mi cuenta y mis datos</button>
    </div>

    <p class="pie-app">Mivra web · versión ${VERSION_APP}</p>`;
}

export function abrirAjustes() {
  abrirHoja({
    titulo: 'Ajustes',
    cuerpo: cuerpoAjustes(),
    alMontar: (hoja) => enlazarLocal(hoja, {
      salir: async () => {
        const ok = await confirmar({ titulo: '¿Cerrar sesión?', mensaje: 'Para volver a entrar necesitarás tu contraseña.', textoOk: 'Cerrar sesión' });
        if (!ok) return;
        hoja.cerrar();
        await cerrarSesion();
      },
      clave: () => formularioClave(),
      exportar: () => exportarCopia(),
      importar: () => hoja.cuerpo.querySelector('input[type="file"]').click(),
      instalar: async () => {
        const evento = globalThis.__mivraInstalar;
        if (!evento) return;
        evento.prompt();
        try { await evento.userChoice; } catch { /* sin respuesta */ }
        globalThis.__mivraInstalar = null;
        hoja.poner(cuerpoAjustes());
      },
      borrar: () => formularioBorrar(hoja)
    })
  });
}

acciones.abrirAjustes = abrirAjustes;

// ---------- Cerrar sesión ----------

export async function cerrarSesion() {
  await D.guardarYa();
  await auth.salir();
  D.cerrar();
  document.dispatchEvent(new CustomEvent('mivra:salir'));
}

// ---------- Moneda ----------

cambios.moneda = (el) => {
  const codigo = el.value;
  fijarMoneda(codigo);
  D.cambiar((st) => { st.ajustes.moneda = codigo; });
  toast('Moneda cambiada');
};

// ---------- Cambiar contraseña ----------

function formularioClave() {
  abrirHoja({
    titulo: 'Cambiar contraseña',
    textoGuardar: 'Cambiar',
    cuerpo: `
      ${campo({ nombre: 'actual', etiqueta: 'Contraseña actual', tipo: 'password', autocompletar: 'current-password' })}
      ${campo({ nombre: 'nueva', etiqueta: 'Contraseña nueva', tipo: 'password', autocompletar: 'new-password', ayuda: 'Mínimo 8 caracteres, con letras y números.' })}
      ${campo({ nombre: 'repetir', etiqueta: 'Repite la contraseña nueva', tipo: 'password', autocompletar: 'new-password' })}`,
    alGuardar: async (cuerpo) => {
      const v = leerCampos(cuerpo);
      if (!v.actual) throw new Error('Escribe tu contraseña actual.');
      if (v.nueva !== v.repetir) throw new Error('Las contraseñas nuevas no coinciden.');
      if (v.nueva === v.actual) throw new Error('La contraseña nueva debe ser distinta de la actual.');
      try {
        await D.guardarYa();
        await auth.cambiarContrasena(v.actual, v.nueva, D.textoActual());
      } catch (error) {
        throw error instanceof auth.ErrorAuth ? error : new Error('No se pudo cambiar la contraseña.');
      }
      toast('Contraseña cambiada');
    }
  });
}

// ---------- Borrar cuenta ----------

function formularioBorrar(hojaAjustes) {
  abrirHoja({
    titulo: 'Borrar cuenta',
    textoGuardar: 'Borrar',
    cuerpo: `
      <div class="aviso">Se borrarán tu usuario y todos tus datos de este dispositivo. No se puede deshacer. Si quieres conservarlos, guarda antes una copia de seguridad.</div>
      ${campo({ nombre: 'clave', etiqueta: 'Escribe tu contraseña para confirmar', tipo: 'password', autocompletar: 'current-password' })}`,
    alGuardar: async (cuerpo, hoja) => {
      const { clave } = leerCampos(cuerpo);
      if (!clave) throw new Error('Escribe tu contraseña.');
      const ok = await confirmar({ titulo: '¿Borrar definitivamente?', mensaje: 'Esta acción no se puede deshacer.', textoOk: 'Borrar todo', peligro: true });
      if (!ok) return false;
      try {
        await auth.borrarCuenta(clave);
      } catch (error) {
        throw error instanceof auth.ErrorAuth ? error : new Error('No se pudo borrar la cuenta.');
      }
      D.cerrar();
      hoja.cerrar();
      hojaAjustes.cerrar();
      document.dispatchEvent(new CustomEvent('mivra:salir'));
      toast('Cuenta borrada');
      return true;
    }
  });
}

// ---------- Copia de seguridad ----------

function nombreArchivo() {
  return `mivra-copia-${aCampoFecha(new Date())}.json`;
}

async function exportarCopia() {
  await D.guardarYa();
  const texto = D.exportarTexto();
  const nombre = nombreArchivo();
  const archivo = new File([texto], nombre, { type: 'application/json' });

  // En teléfonos se usa el menú de compartir (permite «Guardar en Archivos»); en computador, descarga directa.
  const tactil = typeof matchMedia === 'function' && matchMedia('(pointer: coarse)').matches;
  if (tactil && navigator.canShare && navigator.canShare({ files: [archivo] })) {
    try {
      await navigator.share({ files: [archivo], title: 'Copia de seguridad de Mivra' });
      toast('Copia lista');
      return;
    } catch (error) {
      if (error && error.name === 'AbortError') return;
      // Si falla, se intenta la descarga normal.
    }
  }
  const url = URL.createObjectURL(archivo);
  const a = document.createElement('a');
  a.href = url;
  a.download = nombre;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 10000);
  toast('Copia descargada');
}

cambios.archivoCopia = async (input) => {
  const archivo = input.files && input.files[0];
  input.value = '';
  if (!archivo) return;
  if (archivo.size > 20 * 1024 * 1024) { toast('Ese archivo es demasiado grande.'); return; }

  let copia;
  try {
    copia = D.interpretarCopia(await archivo.text());
  } catch (error) {
    toast(error.message || 'No se pudo leer el archivo.', 4200);
    return;
  }

  const lineas = copia.resumen.length ? copia.resumen.join(', ') : 'sin datos';
  const ok = await confirmar({
    titulo: '¿Reemplazar tus datos?',
    mensaje: `Esta copia trae: ${lineas}. Se reemplazará TODO lo que tienes ahora en esta cuenta.`,
    textoOk: 'Reemplazar',
    peligro: true
  });
  if (!ok) return;
  D.reemplazarTodo(copia.datos);
  toast('Copia abierta');
};
