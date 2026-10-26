// Utilidades generales: texto seguro, fechas, dinero y números.

export function esc(texto) {
  return String(texto ?? '').replace(/[&<>"']/g, (c) => (
    { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]
  ));
}

export function uuid() {
  if (globalThis.crypto && typeof crypto.randomUUID === 'function') return crypto.randomUUID().toUpperCase();
  const bytes = crypto.getRandomValues(new Uint8Array(16));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const h = [...bytes].map((b) => b.toString(16).padStart(2, '0')).join('');
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20)}`.toUpperCase();
}

// ---------- Fechas ----------
// En los datos las fechas se guardan como texto ISO sin milisegundos (ej. 2026-10-25T18:15:00Z),
// que es lo que entiende la app de iPhone en sus copias de seguridad.

export function aIso(fecha = new Date()) {
  return new Date(fecha).toISOString().replace(/\.\d{3}Z$/, 'Z');
}

export function aFecha(iso) {
  const f = new Date(iso);
  return Number.isNaN(f.getTime()) ? new Date(0) : f;
}

export function inicioDia(fecha) {
  const f = new Date(fecha);
  f.setHours(0, 0, 0, 0);
  return f;
}

export function sumarDias(fecha, n) {
  const f = new Date(fecha);
  f.setDate(f.getDate() + n);
  return f;
}

export function sumarMeses(fecha, n) {
  const f = new Date(fecha);
  f.setDate(1);
  f.setMonth(f.getMonth() + n);
  return f;
}

export function inicioMes(fecha) {
  const f = inicioDia(fecha);
  f.setDate(1);
  return f;
}

export function inicioSemana(fecha) {
  // La semana empieza el lunes.
  const f = inicioDia(fecha);
  const dia = (f.getDay() + 6) % 7;
  f.setDate(f.getDate() - dia);
  return f;
}

export function inicioAnio(fecha) {
  const f = inicioMes(fecha);
  f.setMonth(0);
  return f;
}

export function mismoDia(a, b) {
  return inicioDia(a).getTime() === inicioDia(b).getTime();
}

export function mismoMes(a, b) {
  const x = new Date(a);
  const y = new Date(b);
  return x.getFullYear() === y.getFullYear() && x.getMonth() === y.getMonth();
}

export function diasDelMes(fecha) {
  const f = new Date(fecha);
  return new Date(f.getFullYear(), f.getMonth() + 1, 0).getDate();
}

/** Fecha con el día pedido dentro del mes de `referencia` (si el mes es más corto, el último día). */
export function fechaEnMes(dia, referencia) {
  const f = new Date(referencia);
  const d = Math.min(Math.max(dia, 1), diasDelMes(f));
  return new Date(f.getFullYear(), f.getMonth(), d, 12, 0, 0);
}

/** "2026-10-25" (campo de fecha) -> Date al mediodía local. */
export function deCampoFecha(texto) {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(texto || '');
  if (!m) return null;
  return new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]), 12, 0, 0);
}

/** Date -> "2026-10-25" para un campo de fecha. */
export function aCampoFecha(fecha) {
  const f = new Date(fecha);
  const mm = String(f.getMonth() + 1).padStart(2, '0');
  const dd = String(f.getDate()).padStart(2, '0');
  return `${f.getFullYear()}-${mm}-${dd}`;
}

/** Date -> "2026-10-25T18:15" para un campo de fecha y hora. */
export function aCampoFechaHora(fecha) {
  const f = new Date(fecha);
  const hh = String(f.getHours()).padStart(2, '0');
  const mi = String(f.getMinutes()).padStart(2, '0');
  return `${aCampoFecha(f)}T${hh}:${mi}`;
}

export function deCampoFechaHora(texto) {
  const m = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})/.exec(texto || '');
  if (!m) return null;
  return new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]), Number(m[4]), Number(m[5]), 0);
}

export function mayuscula(texto) {
  return texto.charAt(0).toUpperCase() + texto.slice(1);
}

const idioma = () => (typeof navigator !== 'undefined' && navigator.language) || 'es-CO';

export function fechaCorta(fecha) {
  return new Intl.DateTimeFormat(idioma(), { day: 'numeric', month: 'short', year: 'numeric' }).format(new Date(fecha));
}

export function fechaDiaMes(fecha) {
  return new Intl.DateTimeFormat(idioma(), { day: 'numeric', month: 'short' }).format(new Date(fecha));
}

export function fechaLarga(fecha) {
  return mayuscula(new Intl.DateTimeFormat(idioma(), { weekday: 'long', day: 'numeric', month: 'long' }).format(new Date(fecha)));
}

export function nombreMes(fecha) {
  return mayuscula(new Intl.DateTimeFormat(idioma(), { month: 'long', year: 'numeric' }).format(new Date(fecha)));
}

export function hora(fecha) {
  return new Intl.DateTimeFormat(idioma(), { hour: 'numeric', minute: '2-digit' }).format(new Date(fecha));
}

// ---------- Dinero y números ----------

let codigoMoneda = 'COP';

export const MONEDAS = [
  ['COP', 'Peso colombiano (COP)'],
  ['USD', 'Dólar (USD)'],
  ['EUR', 'Euro (EUR)'],
  ['MXN', 'Peso mexicano (MXN)'],
  ['ARS', 'Peso argentino (ARS)'],
  ['CLP', 'Peso chileno (CLP)'],
  ['PEN', 'Sol peruano (PEN)'],
  ['BRL', 'Real (BRL)'],
  ['GBP', 'Libra (GBP)']
];

export function fijarMoneda(codigo) {
  if (MONEDAS.some(([c]) => c === codigo)) codigoMoneda = codigo;
}

export function monedaActual() {
  return codigoMoneda;
}

function localeDinero() {
  return codigoMoneda === 'COP' ? 'es-CO' : idioma();
}

export function dinero(valor) {
  const v = Number.isFinite(valor) ? valor : 0;
  // Sin decimales si el monto es entero; con dos si no (así se ve 4,50 y no 4,5).
  const entero = Math.abs(v - Math.round(v)) < 0.005;
  try {
    return new Intl.NumberFormat(localeDinero(), {
      style: 'currency', currency: codigoMoneda, minimumFractionDigits: entero ? 0 : 2, maximumFractionDigits: 2
    }).format(v);
  } catch {
    return `$${v.toFixed(2)}`;
  }
}

export function simboloMoneda() {
  try {
    const partes = new Intl.NumberFormat(localeDinero(), { style: 'currency', currency: codigoMoneda }).formatToParts(0);
    return partes.find((p) => p.type === 'currency')?.value || '$';
  } catch {
    return '$';
  }
}

export function porcentaje(valor) {
  return new Intl.NumberFormat(idioma(), { style: 'percent', maximumFractionDigits: 0 }).format(Number.isFinite(valor) ? valor : 0);
}

function separadores() {
  const partes = new Intl.NumberFormat(localeDinero()).formatToParts(12345.6);
  return {
    grupo: partes.find((p) => p.type === 'group')?.value || ',',
    decimal: partes.find((p) => p.type === 'decimal')?.value || '.'
  };
}

/** Convierte lo que escribe la persona ("1.250,50", "1250.5", "$ 3.000") en un número. null si no es válido. */
export function parseNumero(texto) {
  let s = String(texto ?? '').trim().replace(/[^\d.,-]/g, '');
  if (!s) return null;
  const negativo = s.startsWith('-');
  s = s.replace(/-/g, '');
  if (!s) return null;

  const { grupo } = separadores();
  const ultimoPunto = s.lastIndexOf('.');
  const ultimaComa = s.lastIndexOf(',');
  let decimal = null;

  if (ultimoPunto >= 0 && ultimaComa >= 0) {
    decimal = ultimoPunto > ultimaComa ? '.' : ',';
  } else if (ultimoPunto >= 0 || ultimaComa >= 0) {
    const sep = ultimoPunto >= 0 ? '.' : ',';
    const partes = s.split(sep);
    if (partes.length > 2) {
      decimal = null; // 1.234.567 -> miles
    } else if (partes[1].length === 3 && sep === grupo) {
      decimal = null; // 1.234 en Colombia -> miles
    } else {
      decimal = sep;
    }
  }

  let limpio = s;
  if (decimal) {
    const otro = decimal === '.' ? ',' : '.';
    limpio = limpio.split(otro).join('');
    const i = limpio.lastIndexOf(decimal);
    limpio = limpio.slice(0, i).split(decimal).join('') + '.' + limpio.slice(i + 1);
  } else {
    limpio = limpio.replace(/[.,]/g, '');
  }
  const numero = Number(limpio);
  if (!Number.isFinite(numero)) return null;
  return negativo ? -numero : numero;
}

/** Número -> texto editable (sin separador de miles, con la coma o el punto de la región). */
export function textoNumero(valor) {
  if (!Number.isFinite(valor)) return '';
  const { decimal } = separadores();
  return String(Math.round(valor * 100) / 100).replace('.', decimal);
}
