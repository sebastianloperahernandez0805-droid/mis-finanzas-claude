// Componentes de interfaz compartidos: hojas, avisos, confirmaciones y campos de formulario.

import { esc } from './util.js';

/** Registro de acciones: los botones usan data-accion="nombre" y aquí se guarda qué hace cada una. */
export const acciones = {};
/** Igual, pero para eventos «change» (data-cambio="nombre"). */
export const cambios = {};
/** Formularios que se envían con Enter (data-envio="nombre"). */
export const envios = {};

// La pantalla actual se vuelve a dibujar cuando cambian los datos. app.js registra cómo hacerlo.
let funcionRender = () => {};
export function registrarRender(fn) { funcionRender = fn; }
export function renderizar() { funcionRender(); }

// ---------- Aviso breve ----------

let temporizadorAviso = null;

export function toast(mensaje, ms = 2600) {
  document.querySelectorAll('.toast').forEach((t) => t.remove());
  const el = document.createElement('div');
  el.className = 'toast vidrio';
  el.setAttribute('role', 'status');
  el.textContent = mensaje;
  document.body.appendChild(el);
  clearTimeout(temporizadorAviso);
  temporizadorAviso = setTimeout(() => el.remove(), ms);
}

// ---------- Hojas ----------

let hojasAbiertas = 0;

function bloquearScroll(delta) {
  hojasAbiertas = Math.max(hojasAbiertas + delta, 0);
  document.body.classList.toggle('sin-scroll', hojasAbiertas > 0);
}

/**
 * Abre una hoja (formulario o detalle).
 * - Con `alGuardar`: botones Cancelar / Guardar. Si `alGuardar` devuelve false, la hoja sigue abierta.
 * - Sin `alGuardar`: solo un botón «Listo» (hoja informativa).
 */
export function abrirHoja({
  titulo, cuerpo, textoGuardar = 'Guardar', textoCancelar = 'Cancelar',
  alGuardar = null, alMontar = null, alCerrar = null
}) {
  const capa = document.createElement('div');
  capa.className = 'capa';
  const informativa = typeof alGuardar !== 'function';
  capa.innerHTML = `
    <div class="hoja" role="dialog" aria-modal="true" aria-label="${esc(titulo)}">
      <div class="hoja-cab">
        ${informativa ? '<span style="min-width:74px"></span>' : `<button type="button" class="btn-texto" data-hoja="cancelar">${esc(textoCancelar)}</button>`}
        <h2>${esc(titulo)}</h2>
        <button type="button" class="btn-texto" data-hoja="${informativa ? 'cancelar' : 'guardar'}">${informativa ? 'Listo' : esc(textoGuardar)}</button>
      </div>
      <div class="hoja-cuerpo"></div>
    </div>`;
  const cuerpoEl = capa.querySelector('.hoja-cuerpo');
  cuerpoEl.innerHTML = cuerpo;

  let cerrada = false;
  const hoja = {
    el: capa,
    cuerpo: cuerpoEl,
    cerrar() {
      if (cerrada) return;
      cerrada = true;
      document.removeEventListener('keydown', teclado);
      capa.remove();
      bloquearScroll(-1);
      if (alCerrar) alCerrar();
    },
    poner(html) {
      const alto = cuerpoEl.scrollTop;
      cuerpoEl.innerHTML = html;
      cuerpoEl.scrollTop = alto;
      if (alMontar) alMontar(hoja);
    },
    error(mensaje) {
      let caja = cuerpoEl.querySelector('.error-form');
      if (!caja) {
        caja = document.createElement('div');
        caja.className = 'error-form';
        caja.setAttribute('role', 'alert');
        cuerpoEl.prepend(caja);
      }
      caja.textContent = mensaje;
      cuerpoEl.scrollTo({ top: 0, behavior: 'smooth' });
    }
  };

  function teclado(evento) {
    if (evento.key === 'Escape') {
      const ultima = [...document.querySelectorAll('.capa')].pop();
      if (ultima === capa) hoja.cerrar();
    }
  }

  async function guardar() {
    const boton = capa.querySelector('[data-hoja="guardar"]');
    if (!boton || boton.disabled) return;
    boton.disabled = true;
    try {
      const resultado = await alGuardar(cuerpoEl, hoja);
      if (resultado !== false) hoja.cerrar();
    } catch (error) {
      hoja.error(error && error.message ? error.message : 'No se pudo guardar.');
    } finally {
      boton.disabled = false;
    }
  }

  capa.addEventListener('click', (evento) => {
    const boton = evento.target.closest('[data-hoja]');
    if (boton) {
      if (boton.dataset.hoja === 'cancelar') hoja.cerrar();
      else guardar();
      return;
    }
    // Chips: eligen una opción y la guardan en el campo oculto de su grupo.
    const chip = evento.target.closest('.chips button[data-valor]');
    if (chip) {
      const grupo = chip.closest('.chips');
      grupo.querySelectorAll('button').forEach((b) => b.classList.toggle('activo', b === chip));
      const oculto = grupo.querySelector('input[type="hidden"]');
      if (oculto) {
        oculto.value = chip.dataset.valor;
        oculto.dispatchEvent(new Event('change', { bubbles: true }));
      }
      return;
    }
    if (evento.target === capa && informativa) hoja.cerrar();
  });

  // Enter en un campo de una hoja de formulario = Guardar.
  capa.addEventListener('keydown', (evento) => {
    if (evento.key !== 'Enter' || informativa || evento.isComposing) return;
    const el = evento.target;
    if (el.matches && el.matches('input:not([type="checkbox"]):not([type="hidden"]):not([type="file"])')) {
      evento.preventDefault();
      guardar();
    }
  });

  capa.addEventListener('submit', (evento) => {
    evento.preventDefault();
    if (!informativa) guardar();
  });

  document.addEventListener('keydown', teclado);
  document.body.appendChild(capa);
  bloquearScroll(1);
  if (alMontar) alMontar(hoja);
  return hoja;
}

/** Pregunta de confirmación. Devuelve una promesa con true (aceptó) o false. */
export function confirmar({ titulo, mensaje = '', textoOk = 'Aceptar', peligro = false }) {
  return new Promise((resolver) => {
    const capa = document.createElement('div');
    capa.className = 'capa centrada';
    capa.innerHTML = `
      <div class="dialogo" role="alertdialog" aria-modal="true" aria-label="${esc(titulo)}">
        <h3>${esc(titulo)}</h3>
        ${mensaje ? `<p>${esc(mensaje)}</p>` : ''}
        <div class="btns">
          <button type="button" class="btn vidrio" data-resp="no">Cancelar</button>
          <button type="button" class="btn relleno ${peligro ? 'peligro' : ''}" data-resp="si">${esc(textoOk)}</button>
        </div>
      </div>`;
    const terminar = (valor) => {
      document.removeEventListener('keydown', teclado);
      capa.remove();
      bloquearScroll(-1);
      resolver(valor);
    };
    const teclado = (e) => { if (e.key === 'Escape') terminar(false); };
    capa.addEventListener('click', (e) => {
      const b = e.target.closest('[data-resp]');
      if (b) terminar(b.dataset.resp === 'si');
      else if (e.target === capa) terminar(false);
    });
    document.addEventListener('keydown', teclado);
    document.body.appendChild(capa);
    bloquearScroll(1);
    capa.querySelector('[data-resp="no"]').focus();
  });
}

// ---------- Campos de formulario (devuelven HTML) ----------

export function campo({
  nombre, etiqueta, valor = '', tipo = 'text', placeholder = '', ayuda = '',
  modo = '', max = '', min = '', autocompletar = 'off', requerido = false, maxlength = ''
}) {
  return `
    <label class="campo">
      <span class="etiqueta">${esc(etiqueta)}</span>
      <input name="${esc(nombre)}" type="${esc(tipo)}" value="${esc(valor)}" placeholder="${esc(placeholder)}"
        ${modo ? `inputmode="${esc(modo)}"` : ''} ${max !== '' ? `max="${esc(max)}"` : ''} ${min !== '' ? `min="${esc(min)}"` : ''}
        ${maxlength ? `maxlength="${esc(maxlength)}"` : ''}
        autocomplete="${esc(autocompletar)}" autocapitalize="${tipo === 'text' ? 'sentences' : 'off'}" ${requerido ? 'required' : ''}>
      ${ayuda ? `<span class="ayuda">${esc(ayuda)}</span>` : ''}
    </label>`;
}

export function campoMonto({ nombre, etiqueta, valor = '', placeholder = '0', ayuda = '' }) {
  return `
    <label class="campo campo-monto">
      <span class="etiqueta">${esc(etiqueta)}</span>
      <input name="${esc(nombre)}" type="text" inputmode="decimal" value="${esc(valor)}" placeholder="${esc(placeholder)}" autocomplete="off">
      ${ayuda ? `<span class="ayuda">${esc(ayuda)}</span>` : ''}
    </label>`;
}

export function campoNumero({ nombre, etiqueta, valor = '', placeholder = '0', ayuda = '', max = '', min = '0' }) {
  return `
    <label class="campo">
      <span class="etiqueta">${esc(etiqueta)}</span>
      <input name="${esc(nombre)}" type="text" inputmode="decimal" value="${esc(valor)}" placeholder="${esc(placeholder)}"
        data-max="${esc(max)}" data-min="${esc(min)}" autocomplete="off">
      ${ayuda ? `<span class="ayuda">${esc(ayuda)}</span>` : ''}
    </label>`;
}

export function campoFecha({ nombre, etiqueta, valor = '', max = '', min = '', ayuda = '' }) {
  return campo({ nombre, etiqueta, valor, tipo: 'date', max, min, ayuda });
}

export function campoNota({ nombre = 'nota', etiqueta = 'Nota (opcional)', valor = '' }) {
  return `
    <label class="campo">
      <span class="etiqueta">${esc(etiqueta)}</span>
      <textarea name="${esc(nombre)}" rows="2" autocomplete="off">${esc(valor)}</textarea>
    </label>`;
}

export function campoSelect({ nombre, etiqueta, valor = '', opciones, ayuda = '' }) {
  const items = opciones
    .map(([v, t]) => `<option value="${esc(v)}" ${String(v) === String(valor) ? 'selected' : ''}>${esc(t)}</option>`)
    .join('');
  return `
    <label class="campo">
      <span class="etiqueta">${esc(etiqueta)}</span>
      <select name="${esc(nombre)}">${items}</select>
      ${ayuda ? `<span class="ayuda">${esc(ayuda)}</span>` : ''}
    </label>`;
}

export function chips({ nombre, etiqueta = '', opciones, valor, envuelto = false }) {
  const botones = opciones.map((o) => `
      <button type="button" data-valor="${esc(o.id)}" class="${o.id === valor ? 'activo' : ''}" style="--c:${o.color || 'var(--acento)'}">
        ${o.emoji ? `<span aria-hidden="true">${o.emoji}</span>` : ''}${esc(o.nombre)}
      </button>`).join('');
  return `
    <div class="campo">
      ${etiqueta ? `<span class="etiqueta">${esc(etiqueta)}</span>` : ''}
      <div class="chips ${envuelto ? 'envuelto' : ''}" data-chips="${esc(nombre)}">
        <input type="hidden" name="${esc(nombre)}" value="${esc(valor)}">
        ${botones}
      </div>
    </div>`;
}

export function interruptor({ nombre, etiqueta, marcado = false, ayuda = '' }) {
  return `
    <div class="campo">
      <label class="interruptor">
        <span>${esc(etiqueta)}</span>
        <input type="checkbox" name="${esc(nombre)}" ${marcado ? 'checked' : ''}>
      </label>
      ${ayuda ? `<span class="ayuda">${esc(ayuda)}</span>` : ''}
    </div>`;
}

/** Lee los campos con `name` de un contenedor: texto, casillas y chips. */
export function leerCampos(raiz) {
  const valores = {};
  raiz.querySelectorAll('[name]').forEach((el) => {
    if (el.type === 'checkbox') valores[el.name] = el.checked;
    else valores[el.name] = el.value;
  });
  return valores;
}

// ---------- Piezas visuales (devuelven HTML) ----------

export function iconoCirc(emoji, color = 'var(--acento)', tam = '') {
  return `<span class="icono-circ ${tam}" style="--c:${color}" aria-hidden="true">${emoji}</span>`;
}

export function chipEstado(texto, color = 'var(--acento)', emoji = '') {
  return `<span class="chip" style="--c:${color}">${emoji ? `<span aria-hidden="true">${emoji}</span>` : ''}${esc(texto)}</span>`;
}

export function barraProgreso(valor, color = 'var(--acento)', fina = false) {
  const pct = Math.round(Math.min(Math.max(valor || 0, 0), 1) * 1000) / 10;
  return `<div class="barra-prog ${fina ? 'fina' : ''}" role="progressbar" aria-valuemin="0" aria-valuemax="100" aria-valuenow="${Math.round(pct)}"><span style="width:${pct}%;--c:${color}"></span></div>`;
}

export function anillo(valor, color = 'var(--acento)', centro = '') {
  const radio = 44;
  const circ = 2 * Math.PI * radio;
  const v = Math.min(Math.max(valor || 0, 0), 1);
  return `
    <div class="anillo" style="--c:${color}">
      <svg viewBox="0 0 104 104" aria-hidden="true">
        <circle class="pista" cx="52" cy="52" r="${radio}" fill="none" stroke-width="10"></circle>
        <circle class="valor" cx="52" cy="52" r="${radio}" fill="none" stroke-width="10" stroke-linecap="round"
          stroke-dasharray="${circ.toFixed(2)}" stroke-dashoffset="${(circ * (1 - v)).toFixed(2)}"></circle>
      </svg>
      <div class="centro">${centro}</div>
    </div>`;
}

export function estadoVacio(emoji, titulo, mensaje, botonHtml = '') {
  return `
    <div class="vacio">
      <span class="emoji" aria-hidden="true">${emoji}</span>
      <h3>${esc(titulo)}</h3>
      <p>${esc(mensaje)}</p>
      ${botonHtml}
    </div>`;
}

// ---------- Íconos (SVG) ----------

const trazo = 'fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"';
const ICONOS = {
  mas: `<svg viewBox="0 0 24 24" ${trazo}><circle cx="12" cy="12" r="9.5"/><path d="M12 8v8M8 12h8"/></svg>`,
  ajustes: `<svg viewBox="0 0 24 24" ${trazo}><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/></svg>`,
  tabla: `<svg viewBox="0 0 24 24" ${trazo}><rect x="3" y="4" width="18" height="16" rx="3"/><path d="M3 10h18M3 15h18M9 4v16"/></svg>`,
  izq: `<svg viewBox="0 0 24 24" ${trazo}><path d="M15 5l-7 7 7 7"/></svg>`,
  der: `<svg viewBox="0 0 24 24" ${trazo}><path d="M9 5l7 7-7 7"/></svg>`,
  sol: `<svg viewBox="0 0 24 24" ${trazo}><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/></svg>`,
  ingresos: `<svg viewBox="0 0 24 24" ${trazo}><circle cx="12" cy="12" r="9.5"/><path d="M12 7v10M8 13l4 4 4-4"/></svg>`,
  fijos: `<svg viewBox="0 0 24 24" ${trazo}><rect x="3" y="5" width="18" height="16" rx="3"/><path d="M3 10h18M8 3v4M16 3v4"/><circle cx="12" cy="15.5" r="2.2"/></svg>`,
  deudas: `<svg viewBox="0 0 24 24" ${trazo}><rect x="2.5" y="5" width="19" height="14" rx="3"/><path d="M2.5 10h19M6 15h4"/></svg>`,
  metas: `<svg viewBox="0 0 24 24" ${trazo}><circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1.2"/></svg>`
};

export function icono(nombre) {
  return ICONOS[nombre] || '';
}
