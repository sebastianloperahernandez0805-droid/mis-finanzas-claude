// Piezas que comparten las pantallas: lectura de números de los formularios y botones dentro de las hojas.

import { parseNumero, deCampoFecha, textoNumero } from '../util.js';

const MAXIMO = 1e12;

/** Número mayor que cero, o un Error con un mensaje claro para mostrar en el formulario. */
export function montoPositivo(texto, etiqueta = 'El monto') {
  const n = parseNumero(texto);
  if (n === null || !(n > 0)) throw new Error(`${etiqueta} debe ser un número mayor que 0.`);
  if (n > MAXIMO) throw new Error(`${etiqueta} es demasiado grande.`);
  return n;
}

/** Número que puede quedar vacío (vale `defecto`) pero que, si se escribe, no puede ser negativo. */
export function numeroOpcional(texto, etiqueta, defecto = 0) {
  if (String(texto ?? '').trim() === '') return defecto;
  const n = parseNumero(texto);
  if (n === null || n < 0 || n > MAXIMO) throw new Error(`${etiqueta} no es válido.`);
  return n;
}

export function enteroEnRango(texto, etiqueta, minimo, maximo, defecto = minimo) {
  const n = numeroOpcional(texto, etiqueta, defecto);
  const entero = Math.round(n);
  if (entero < minimo || entero > maximo) throw new Error(`${etiqueta} debe estar entre ${minimo} y ${maximo}.`);
  return entero;
}

/** Campo de fecha opcional: vacío = null; con texto inválido = Error. */
export function fechaOpcional(texto, etiqueta = 'La fecha') {
  if (!texto) return null;
  const f = deCampoFecha(texto);
  if (!f) throw new Error(`${etiqueta} no es válida.`);
  return f;
}

export function textoLimpio(valor, maximo = 200) {
  return String(valor ?? '').trim().replace(/\s+/g, ' ').slice(0, maximo);
}

/** Notas: se conservan los saltos de línea. */
export function notaLimpia(valor, maximo = 500) {
  return String(valor ?? '').trim().slice(0, maximo);
}

/**
 * Conecta botones de una hoja marcados con data-local="nombre" a funciones.
 * Se llama desde `alMontar`, que se ejecuta otra vez cada vez que la hoja se vuelve a dibujar con `poner`.
 */
export function enlazarLocal(hoja, mapa) {
  hoja.cuerpo.querySelectorAll('[data-local]').forEach((boton) => {
    const fn = mapa[boton.dataset.local];
    if (!fn) return;
    boton.addEventListener('click', (evento) => {
      evento.preventDefault();
      Promise.resolve(fn(boton, evento)).catch((error) => {
        hoja.error(error && error.message ? error.message : 'No se pudo completar la acción.');
      });
    });
  });
}

/** Botones de atajo que rellenan un campo (data-atajo="valor" data-campo="monto"). */
export function enlazarAtajos(hoja) {
  hoja.cuerpo.querySelectorAll('[data-atajo]').forEach((boton) => {
    boton.addEventListener('click', () => {
      const campo = hoja.cuerpo.querySelector(`[name="${boton.dataset.campo || 'monto'}"]`);
      if (!campo) return;
      campo.value = textoNumero(Number(boton.dataset.atajo));
      campo.focus();
    });
  });
}

export function porFechaDesc(campo = 'fecha') {
  return (a, b) => new Date(b[campo]).getTime() - new Date(a[campo]).getTime();
}
