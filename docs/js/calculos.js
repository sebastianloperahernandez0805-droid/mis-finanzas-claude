// Catálogos y cálculos. Son los mismos que usa la app de iPhone, para que los números coincidan.

import {
  aFecha, aIso, uuid, inicioDia, inicioMes, sumarMeses, mismoMes, fechaEnMes
} from './util.js';

const MS_DIA = 86400000;

// ---------- Catálogos ----------

export const CATEGORIAS_GASTO = [
  { id: 'comida', nombre: 'Comida', emoji: '🍽️', color: 'var(--naranja)' },
  { id: 'transporte', nombre: 'Transporte', emoji: '🚌', color: 'var(--acento)' },
  { id: 'hogar', nombre: 'Hogar', emoji: '🏠', color: 'var(--cafe)' },
  { id: 'salud', nombre: 'Salud', emoji: '🩺', color: 'var(--rojo)' },
  { id: 'ocio', nombre: 'Ocio', emoji: '🍿', color: 'var(--rosa)' },
  { id: 'compras', nombre: 'Compras', emoji: '🛍️', color: 'var(--morado)' },
  { id: 'educacion', nombre: 'Educación', emoji: '📚', color: 'var(--turquesa)' },
  { id: 'otros', nombre: 'Otros', emoji: '⋯', color: 'var(--gris)' }
];

export const TIPOS_INGRESO = [
  { id: 'salario', nombre: 'Salario', emoji: '💵', color: 'var(--verde)' },
  { id: 'extra', nombre: 'Ingreso extra', emoji: '➕', color: 'var(--menta)' },
  { id: 'ventas', nombre: 'Ventas', emoji: '🛒', color: 'var(--naranja)' },
  { id: 'inversion', nombre: 'Inversiones', emoji: '📈', color: 'var(--indigo)' },
  { id: 'otros', nombre: 'Otros', emoji: '⋯', color: 'var(--gris)' }
];

export const FRECUENCIAS_INGRESO = [
  { id: 'unico', nombre: 'Único', veces: 0 },
  { id: 'semanal', nombre: 'Semanal', veces: 52 / 12 },
  { id: 'quincenal', nombre: 'Quincenal', veces: 2 },
  { id: 'mensual', nombre: 'Mensual', veces: 1 },
  { id: 'anual', nombre: 'Anual', veces: 1 / 12 }
];

export const CATEGORIAS_PAGO = [
  { id: 'suscripcion', nombre: 'Suscripción', emoji: '📺', color: 'var(--rosa)' },
  { id: 'servicios', nombre: 'Servicios', emoji: '💡', color: 'var(--amarillo)' },
  { id: 'arriendo', nombre: 'Arriendo', emoji: '🏠', color: 'var(--cafe)' },
  { id: 'seguro', nombre: 'Seguro', emoji: '🛡️', color: 'var(--acento)' },
  { id: 'educacion', nombre: 'Educación', emoji: '🎓', color: 'var(--turquesa)' },
  { id: 'otro', nombre: 'Otro', emoji: '⋯', color: 'var(--gris)' }
];

export const TIPOS_DEUDA = [
  { id: 'prestamo', nombre: 'Préstamo', emoji: '🏦', color: 'var(--naranja)' },
  { id: 'tarjeta', nombre: 'Tarjeta de crédito', emoji: '💳', color: 'var(--rojo)' },
  { id: 'persona', nombre: 'Deuda a persona', emoji: '👥', color: 'var(--indigo)' },
  { id: 'otra', nombre: 'Otra', emoji: '📄', color: 'var(--gris)' }
];

export const PALETAS = [
  { id: 'azul', nombre: 'Azul', color: 'var(--acento)' },
  { id: 'verde', nombre: 'Verde', color: 'var(--verde)' },
  { id: 'naranja', nombre: 'Naranja', color: 'var(--naranja)' },
  { id: 'morado', nombre: 'Morado', color: 'var(--morado)' },
  { id: 'rosa', nombre: 'Rosa', color: 'var(--rosa)' },
  { id: 'turquesa', nombre: 'Turquesa', color: 'var(--turquesa)' },
  { id: 'rojo', nombre: 'Rojo', color: 'var(--rojo)' }
];

// Los íconos de las metas se guardan con el nombre del símbolo de iPhone (así la copia sirve en ambos lados).
export const ICONOS_META = [
  ['shield.fill', '🛡️'], ['airplane', '✈️'], ['laptopcomputer', '💻'], ['house.fill', '🏠'],
  ['car.fill', '🚗'], ['graduationcap.fill', '🎓'], ['gift.fill', '🎁'], ['heart.fill', '❤️'],
  ['camera.fill', '📷'], ['gamecontroller.fill', '🎮'], ['bicycle', '🚲'], ['briefcase.fill', '💼']
];

const EMOJI_SIMBOLO = {
  ...Object.fromEntries(ICONOS_META),
  'target': '🎯', 'pawprint.fill': '🐾', 'cart.fill': '🛒', 'fork.knife': '🍴', 'bus.fill': '🚌',
  'cross.case.fill': '🩺', 'popcorn.fill': '🍿', 'bag.fill': '🛍️', 'book.fill': '📚',
  'star.fill': '⭐', 'tag': '🏷️', 'tag.fill': '🏷️', 'gift': '🎁', 'leaf.fill': '🌿', 'music.note': '🎵',
  'tshirt.fill': '👕', 'pills.fill': '💊', 'fuelpump.fill': '⛽', 'wifi': '📶', 'phone.fill': '📞',
  'figure.run': '🏃', 'dumbbell.fill': '🏋️', 'cup.and.saucer.fill': '☕', 'wrench.fill': '🔧',
  'banknote.fill': '💵', 'creditcard.fill': '💳', 'building.columns.fill': '🏦', 'ellipsis.circle.fill': '⋯'
};

export function emojiDe(simbolo, porDefecto = '🏷️') {
  return EMOJI_SIMBOLO[simbolo] || porDefecto;
}

export function colorDePaleta(id) {
  return (PALETAS.find((p) => p.id === id) || PALETAS[0]).color;
}

const buscar = (lista, id, respaldo) => lista.find((x) => x.id === id) || respaldo || lista[lista.length - 1];

export const categoriaPago = (id) => buscar(CATEGORIAS_PAGO, id);
export const tipoIngreso = (id) => buscar(TIPOS_INGRESO, id);
export const tipoDeuda = (id) => buscar(TIPOS_DEUDA, id);
export const frecuenciaIngreso = (id) => buscar(FRECUENCIAS_INGRESO, id, FRECUENCIAS_INGRESO[3]);

/** Categorías de gasto de la app más las que creó la persona en el iPhone (vienen en la copia). */
export function categoriasDisponibles(personalizadas = []) {
  const propias = personalizadas.map((c) => ({
    id: c.clave,
    nombre: c.nombre,
    emoji: emojiDe(c.icono),
    color: colorDePaleta(c.paleta)
  }));
  return [...CATEGORIAS_GASTO.slice(0, -1), ...propias, CATEGORIAS_GASTO[CATEGORIAS_GASTO.length - 1]];
}

/** Una clave que no existe (por ejemplo, una categoría borrada) se muestra como «Otros». */
export function categoriaVisual(clave, personalizadas = []) {
  const otras = CATEGORIAS_GASTO[CATEGORIAS_GASTO.length - 1];
  return categoriasDisponibles(personalizadas).find((c) => c.id === clave) || otras;
}

// ---------- Gastos ----------

export function gastosEntre(gastos, desde, hastaExclusivo) {
  const d = desde.getTime();
  const h = hastaExclusivo.getTime();
  return gastos.filter((g) => {
    const t = aFecha(g.fecha).getTime();
    return t >= d && t < h;
  });
}

export const sumar = (lista, campo = 'monto') => lista.reduce((acc, x) => acc + (Number(x[campo]) || 0), 0);

export function agruparPorCategoria(gastos, personalizadas = []) {
  const total = sumar(gastos);
  const mapa = new Map();
  for (const g of gastos) {
    const cat = categoriaVisual(g.categoria, personalizadas);
    const previo = mapa.get(cat.id) || { categoria: cat, total: 0, cantidad: 0 };
    previo.total += g.monto;
    previo.cantidad += 1;
    mapa.set(cat.id, previo);
  }
  return [...mapa.values()]
    .map((f) => ({ ...f, porcentaje: total > 0 ? f.total / total : 0 }))
    .sort((a, b) => b.total - a.total);
}

// ---------- Ingresos ----------

/** Cuánto aporta un ingreso al mes de `referencia`. Un ingreso único solo cuenta en su mes. */
export function aporteMensual(ingreso, referencia = new Date()) {
  const fecha = aFecha(ingreso.fecha);
  if (ingreso.frecuencia === 'unico') return mismoMes(fecha, referencia) ? ingreso.monto : 0;
  const finDeMes = inicioMes(sumarMeses(referencia, 1));
  if (!(fecha < finDeMes)) return 0;
  return ingreso.monto * frecuenciaIngreso(ingreso.frecuencia).veces;
}

// ---------- Pagos fijos ----------

export function estaPagadoEsteMes(pago) {
  return Boolean(pago.ultimoPago) && mismoMes(aFecha(pago.ultimoPago), new Date());
}

export function fechaVencimiento(pago, referencia = new Date()) {
  return fechaEnMes(pago.diaVencimiento, referencia);
}

export function diasParaVencer(pago) {
  const vence = inicioDia(fechaVencimiento(pago));
  return Math.round((vence.getTime() - inicioDia(new Date()).getTime()) / MS_DIA);
}

export function estadoPago(pago) {
  if (estaPagadoEsteMes(pago)) return 'pagado';
  return diasParaVencer(pago) < 0 ? 'vencido' : 'pendiente';
}

export const ESTADOS_PAGO = {
  pagado: { nombre: 'Pagado', emoji: '✓', color: 'var(--verde)' },
  pendiente: { nombre: 'Pendiente', emoji: '◷', color: 'var(--naranja)' },
  vencido: { nombre: 'Vencido', emoji: '!', color: 'var(--rojo)' }
};

/** Cuánto se pagó de este pago fijo en el mes de `mes` (según su historial). */
export function montoPagado(pago, mes = new Date()) {
  const delMes = (pago.historial || []).filter((r) => mismoMes(aFecha(r.fecha), mes));
  if (delMes.length) return sumar(delMes);
  if (pago.ultimoPago && mismoMes(aFecha(pago.ultimoPago), mes)) return pago.monto;
  return 0;
}

export function registrarPago(pago, fecha = new Date()) {
  pago.ultimoPago = aIso(fecha);
  pago.historial = pago.historial || [];
  pago.historial.push({ id: uuid(), fecha: aIso(fecha), monto: pago.monto });
}

function deshacerPagoEsteMes(pago) {
  const ahora = new Date();
  const historial = pago.historial || [];
  pago.historial = historial.filter((r) => !mismoMes(aFecha(r.fecha), ahora));
  pago.ultimoPago = ultimaFecha(pago.historial);
}

function ultimaFecha(registros) {
  if (!registros.length) return null;
  return aIso(new Date(Math.max(...registros.map((r) => aFecha(r.fecha).getTime()))));
}

/** Marca como pagado o vuelve a pendiente, y deja constancia en el historial. */
export function alternarPago(pago) {
  if (estaPagadoEsteMes(pago)) deshacerPagoEsteMes(pago);
  else registrarPago(pago);
}

export function agregarRegistroPago(pago, monto, fecha) {
  pago.historial = pago.historial || [];
  pago.historial.push({ id: uuid(), fecha: aIso(fecha), monto });
  const mayor = Math.max(aFecha(pago.ultimoPago || fecha).getTime(), new Date(fecha).getTime());
  pago.ultimoPago = aIso(new Date(mayor));
}

export function eliminarRegistroPago(pago, id) {
  pago.historial = (pago.historial || []).filter((r) => r.id !== id);
  pago.ultimoPago = ultimaFecha(pago.historial);
}

// ---------- Deudas ----------

export const totalAbonado = (deuda) => sumar(deuda.abonos || []);
export const saldoPendiente = (deuda) => Math.max(deuda.montoTotal - totalAbonado(deuda), 0);
export const progresoDeuda = (deuda) => (deuda.montoTotal > 0 ? Math.min(totalAbonado(deuda) / deuda.montoTotal, 1) : 0);
export const deudaSaldada = (deuda) => deuda.montoTotal > 0 && saldoPendiente(deuda) < 0.01;
export const tieneInteresOCuotas = (deuda) => deuda.tasaInteresAnual > 0 || deuda.numeroCuotas > 0;
export const interesMensualEstimado = (deuda) => saldoPendiente(deuda) * (deuda.tasaInteresAnual / 100 / 12);

/** Cuota fija con el sistema de cuotas iguales (si no hay interés, monto / cuotas). */
export function cuotaDe(monto, tasaAnual, cuotas) {
  if (!(cuotas > 0) || !(monto > 0)) return 0;
  const r = tasaAnual / 100 / 12;
  if (r < 0.0000001) return monto / cuotas;
  return (monto * r) / (1 - Math.pow(1 + r, -cuotas));
}

export const cuotaEstimada = (deuda) => cuotaDe(deuda.montoTotal, deuda.tasaInteresAnual, deuda.numeroCuotas);

export function cuotasRestantes(deuda) {
  const cuota = cuotaEstimada(deuda);
  if (!(deuda.numeroCuotas > 0) || !(cuota > 0)) return 0;
  const pagadas = Math.floor(totalAbonado(deuda) / cuota);
  return Math.max(deuda.numeroCuotas - pagadas, 0);
}

// ---------- Metas de ahorro ----------

export const montoAhorrado = (meta) => sumar(meta.movimientos || []);
export const progresoMeta = (meta) => (meta.montoObjetivo > 0 ? Math.min(Math.max(montoAhorrado(meta) / meta.montoObjetivo, 0), 1) : 0);
export const faltanteMeta = (meta) => Math.max(meta.montoObjetivo - montoAhorrado(meta), 0);
export const metaCumplida = (meta) => meta.montoObjetivo > 0 && montoAhorrado(meta) >= meta.montoObjetivo;

export function mesesRestantes(meta) {
  if (!meta.fechaObjetivo) return null;
  const fecha = aFecha(meta.fechaObjetivo);
  if (!(fecha.getTime() > Date.now())) return null;
  const dias = (fecha.getTime() - Date.now()) / MS_DIA;
  return Math.max(Math.ceil(dias / 30.4375), 1);
}

/** Cuánto aportar al mes para llegar a tiempo (estimación sencilla, sin intereses). */
export function aporteSugerido(meta) {
  const meses = mesesRestantes(meta);
  if (metaCumplida(meta) || faltanteMeta(meta) <= 0 || meses === null) return null;
  return faltanteMeta(meta) / meses;
}

export function fechaMetaVencida(meta) {
  if (!meta.fechaObjetivo) return false;
  return aFecha(meta.fechaObjetivo).getTime() <= Date.now() && !metaCumplida(meta);
}
