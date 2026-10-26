// Almacén de datos de la sesión abierta.
// Tiene el mismo formato que la copia de seguridad de la app de iPhone ("MisFinanzas", versión 1),
// así que una copia hecha en un lado se puede abrir en el otro.

import * as auth from './auth.js';
import { uuid, aIso, fijarMoneda } from './util.js';

const FORMATO = 'MisFinanzas';
const VERSION = 1;

let estado = null;
let temporizador = null;
let pendiente = false;
let guardando = Promise.resolve();
let manejadorError = null;
const oyentes = new Set();

// ---------- Normalización ----------

const texto = (v, defecto = '') => (typeof v === 'string' ? v : defecto);
const numero = (v, defecto = 0) => (Number.isFinite(Number(v)) && v !== null && v !== '' ? Number(v) : defecto);
const lista = (v) => (Array.isArray(v) ? v : []);

function iso(v, defecto = null) {
  if (typeof v === 'string' && !Number.isNaN(new Date(v).getTime())) return aIso(new Date(v));
  return defecto === 'ahora' ? aIso() : defecto;
}

function monedaPorDefecto() {
  const idioma = (typeof navigator !== 'undefined' && navigator.language) || 'es-CO';
  if (/-CO$/i.test(idioma) || /^es$/i.test(idioma)) return 'COP';
  if (/-MX$/i.test(idioma)) return 'MXN';
  if (/-AR$/i.test(idioma)) return 'ARS';
  if (/-CL$/i.test(idioma)) return 'CLP';
  if (/-PE$/i.test(idioma)) return 'PEN';
  if (/-BR$/i.test(idioma)) return 'BRL';
  if (/-GB$/i.test(idioma)) return 'GBP';
  if (/-(ES|DE|FR|IT|PT|NL)$/i.test(idioma)) return 'EUR';
  return 'USD';
}

function movimiento(m) {
  return { ...m, id: m.id || uuid(), monto: numero(m.monto), fecha: iso(m.fecha, 'ahora'), nota: texto(m.nota) };
}

export function normalizar(origen) {
  const o = origen && typeof origen === 'object' ? origen : {};
  return {
    ...o,
    formato: FORMATO,
    version: VERSION,
    fecha: iso(o.fecha, 'ahora'),
    presupuestoDiario: Math.max(numero(o.presupuestoDiario), 0),
    gastos: lista(o.gastos).map((g) => ({
      ...g,
      id: g.id || uuid(),
      concepto: texto(g.concepto),
      monto: numero(g.monto),
      fecha: iso(g.fecha, 'ahora'),
      categoria: texto(g.categoria, 'otros') || 'otros',
      nota: texto(g.nota)
    })),
    ingresos: lista(o.ingresos).map((i) => ({
      ...i,
      id: i.id || uuid(),
      fuente: texto(i.fuente),
      monto: numero(i.monto),
      tipo: texto(i.tipo, 'otros'),
      frecuencia: texto(i.frecuencia, 'mensual'),
      fecha: iso(i.fecha, 'ahora'),
      nota: texto(i.nota)
    })),
    pagosFijos: lista(o.pagosFijos).map((p) => ({
      ...p,
      id: p.id || uuid(),
      nombre: texto(p.nombre),
      monto: numero(p.monto),
      diaVencimiento: Math.min(Math.max(Math.round(numero(p.diaVencimiento, 1)), 1), 31),
      categoria: texto(p.categoria, 'otro'),
      ultimoPago: iso(p.ultimoPago, null),
      nota: texto(p.nota),
      historial: lista(p.historial).map((r) => ({
        ...r, id: r.id || uuid(), fecha: iso(r.fecha, 'ahora'), monto: numero(r.monto)
      }))
    })),
    deudas: lista(o.deudas).map((d) => ({
      ...d,
      id: d.id || uuid(),
      nombre: texto(d.nombre),
      acreedor: texto(d.acreedor),
      tipo: texto(d.tipo, 'otra'),
      montoTotal: numero(d.montoTotal),
      fechaCreacion: iso(d.fechaCreacion, 'ahora'),
      fechaLimite: iso(d.fechaLimite, null),
      nota: texto(d.nota),
      tasaInteresAnual: Math.max(numero(d.tasaInteresAnual), 0),
      numeroCuotas: Math.max(Math.round(numero(d.numeroCuotas)), 0),
      diaPago: Math.min(Math.max(Math.round(numero(d.diaPago)), 0), 31),
      abonos: lista(d.abonos).map(movimiento)
    })),
    metas: lista(o.metas).map((m) => ({
      ...m,
      id: m.id || uuid(),
      nombre: texto(m.nombre),
      montoObjetivo: numero(m.montoObjetivo),
      icono: texto(m.icono, 'target') || 'target',
      paleta: texto(m.paleta, 'azul'),
      fechaObjetivo: iso(m.fechaObjetivo, null),
      fechaCreacion: iso(m.fechaCreacion, 'ahora'),
      movimientos: lista(m.movimientos).map(movimiento)
    })),
    // Estas listas se crean en la app de iPhone. Aquí se conservan tal cual para no perderlas al exportar.
    categorias: lista(o.categorias),
    presupuestos: lista(o.presupuestos),
    recurrentes: lista(o.recurrentes),
    cuentas: lista(o.cuentas),
    cuentaPredeterminada: typeof o.cuentaPredeterminada === 'string' ? o.cuentaPredeterminada : null,
    ajustes: {
      moneda: texto(o.ajustes && o.ajustes.moneda, monedaPorDefecto())
    }
  };
}

export function datosVacios() {
  return normalizar({});
}

// ---------- Sesión ----------

export async function abrir() {
  const plano = await auth.leerTexto();
  let objeto = {};
  try { objeto = JSON.parse(plano); } catch { objeto = {}; }
  estado = normalizar(objeto);
  fijarMoneda(estado.ajustes.moneda);
  return estado;
}

export function cerrar() {
  clearTimeout(temporizador);
  temporizador = null;
  pendiente = false;
  estado = null;
}

export function datos() {
  return estado;
}

export function alFallarGuardado(fn) {
  manejadorError = fn;
}

export function suscribir(fn) {
  oyentes.add(fn);
  return () => oyentes.delete(fn);
}

function avisar() {
  oyentes.forEach((fn) => fn());
}

/** Cambia los datos dentro de `fn` (que recibe el estado), guarda cifrado y avisa a las pantallas. */
export function cambiar(fn) {
  if (!estado) return;
  fn(estado);
  estado.fecha = aIso();
  programarGuardado();
  avisar();
}

function programarGuardado() {
  pendiente = true;
  clearTimeout(temporizador);
  temporizador = setTimeout(guardarYa, 250);
}

/** Guarda ahora mismo lo que falte (se llama al cerrar sesión o al salir de la página). */
export function guardarYa() {
  clearTimeout(temporizador);
  temporizador = null;
  if (!pendiente || !estado) return guardando;
  pendiente = false;
  const plano = JSON.stringify(estado);
  guardando = guardando
    .then(() => auth.guardarTexto(plano))
    .catch((error) => { if (manejadorError) manejadorError(error); });
  return guardando;
}

export function textoActual() {
  return JSON.stringify(estado);
}

// ---------- Copia de seguridad ----------

export function exportarTexto() {
  return JSON.stringify(estado, null, 2);
}

export function resumenDe(d) {
  const lineas = [];
  const agregar = (n, singular, plural) => { if (n > 0) lineas.push(`${n} ${n === 1 ? singular : plural}`); };
  agregar(d.gastos.length, 'gasto', 'gastos');
  agregar(d.ingresos.length, 'fuente de ingreso', 'fuentes de ingreso');
  agregar(d.pagosFijos.length, 'pago fijo', 'pagos fijos');
  agregar(d.deudas.length, 'deuda', 'deudas');
  agregar(d.metas.length, 'meta de ahorro', 'metas de ahorro');
  agregar(d.categorias.length, 'categoría propia', 'categorías propias');
  agregar(d.presupuestos.length, 'presupuesto', 'presupuestos');
  agregar(d.recurrentes.length, 'gasto automático', 'gastos automáticos');
  agregar(d.cuentas.length, 'cuenta', 'cuentas');
  return lineas;
}

/** Lee el texto de un archivo de copia (de la web o del iPhone). No toca los datos actuales. */
export function interpretarCopia(plano) {
  let objeto;
  try {
    objeto = JSON.parse(plano);
  } catch {
    throw new Error('Ese archivo no es una copia de seguridad de Mivra.');
  }
  if (!objeto || typeof objeto !== 'object' || objeto.formato !== FORMATO) {
    throw new Error('Ese archivo no es una copia de seguridad de Mivra.');
  }
  if (Number(objeto.version) > VERSION) {
    throw new Error(`Esa copia (versión ${objeto.version}) es más nueva que esta página. Recarga Mivra e inténtalo de nuevo.`);
  }
  const nuevos = normalizar(objeto);
  return { datos: nuevos, resumen: resumenDe(nuevos), fecha: nuevos.fecha };
}

/** Reemplaza TODOS los datos por los de la copia, conservando la moneda elegida en este dispositivo. */
export function reemplazarTodo(nuevos) {
  cambiar((actual) => {
    const moneda = actual.ajustes.moneda;
    for (const clave of Object.keys(actual)) delete actual[clave];
    Object.assign(actual, normalizar({ ...nuevos, ajustes: { moneda } }));
  });
}
