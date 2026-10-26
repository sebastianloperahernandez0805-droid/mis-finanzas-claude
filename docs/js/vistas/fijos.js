// Pantalla «Pagos fijos»: servicios, suscripciones y cuentas que se pagan cada mes.

import * as D from '../datos.js';
import {
  esc, uuid, aFecha, aCampoFecha, deCampoFecha, textoNumero, dinero, fechaCorta, fechaDiaMes, mismoMes
} from '../util.js';
import {
  CATEGORIAS_PAGO, ESTADOS_PAGO, categoriaPago, estadoPago, diasParaVencer, montoPagado, alternarPago,
  agregarRegistroPago, eliminarRegistroPago, sumar
} from '../calculos.js';
import {
  acciones, toast, abrirHoja, confirmar, campo, campoMonto, campoNumero, campoNota, campoFecha, chips,
  leerCampos, iconoCirc, chipEstado, barraProgreso, estadoVacio, icono
} from '../ui.js';
import { montoPositivo, enteroEnRango, textoLimpio, notaLimpia, enlazarLocal, porFechaDesc } from './comun.js';

export const titulo = 'Pagos fijos';

export function botones() {
  return `<button class="btn-icono vidrio" data-accion="pagoNuevo" aria-label="Agregar pago fijo">${icono('mas')}</button>`;
}

function textoVencimiento(p) {
  const estado = estadoPago(p);
  if (estado === 'pagado') return `Pagado el ${fechaDiaMes(p.ultimoPago)}`;
  const dias = diasParaVencer(p);
  if (estado === 'vencido') return `Venció hace ${-dias} ${-dias === 1 ? 'día' : 'días'}`;
  if (dias === 0) return 'Vence hoy';
  if (dias === 1) return 'Vence mañana';
  return `Vence en ${dias} días`;
}

export function render() {
  const d = D.datos();
  const lista = [...d.pagosFijos].sort((a, b) => {
    const pa = estadoPago(a) === 'pagado' ? 1 : 0;
    const pb = estadoPago(b) === 'pagado' ? 1 : 0;
    return pa - pb || a.diaVencimiento - b.diaVencimiento || a.nombre.localeCompare(b.nombre);
  });

  const total = sumar(lista);
  const pagado = lista.reduce((acc, p) => acc + (estadoPago(p) === 'pagado' ? p.monto : 0), 0);
  const pendiente = Math.max(total - pagado, 0);
  const vencidos = lista.filter((p) => estadoPago(p) === 'vencido').length;
  const cantPagados = lista.filter((p) => estadoPago(p) === 'pagado').length;

  const filas = lista.map((p) => {
    const cat = categoriaPago(p.categoria);
    const estado = estadoPago(p);
    const info = ESTADOS_PAGO[estado];
    const pagadoYa = estado === 'pagado';
    return `
      <div class="fila">
        <button type="button" class="check-pago ${pagadoYa ? 'marcado' : ''}" data-accion="pagoAlternar" data-id="${esc(p.id)}"
          role="checkbox" aria-checked="${pagadoYa}" aria-label="${pagadoYa ? 'Marcar como pendiente' : 'Marcar como pagado'}: ${esc(p.nombre)}">${pagadoYa ? '✓' : ''}</button>
        <button type="button" class="fila-link" data-accion="pagoDetalle" data-id="${esc(p.id)}">
          ${iconoCirc(cat.emoji, cat.color)}
          <div class="cuerpo">
            <div class="titulo">${esc(p.nombre)}</div>
            <div class="sub">${esc(textoVencimiento(p))}</div>
          </div>
          <div class="lado">
            <span class="monto">${esc(dinero(p.monto))}</span>
            ${chipEstado(info.nombre, info.color, info.emoji)}
          </div>
        </button>
      </div>`;
  }).join('');

  return `
    <div class="apilar">
      <section class="tarjeta vidrio">
        <div class="sec peq">Total de pagos fijos al mes</div>
        <div class="monto-grande">${esc(dinero(total))}</div>
        <div style="margin:12px 0 8px">${barraProgreso(total > 0 ? pagado / total : 0, 'var(--verde)')}</div>
        <div class="flex-entre peq">
          <span><span class="sec">Pagado </span><b class="num">${esc(dinero(pagado))}</b></span>
          <span><span class="sec">Falta </span><b class="num">${esc(dinero(pendiente))}</b></span>
        </div>
        ${lista.length ? `<div class="peq sec" style="margin-top:8px">${cantPagados} de ${lista.length} pagados este mes${vencidos ? ` · <span style="color:var(--rojo);font-weight:650">${vencidos} ${vencidos === 1 ? 'vencido' : 'vencidos'}</span>` : ''}</div>` : ''}
      </section>

      <section class="tarjeta vidrio tarjeta-lista">
        <div class="flex-entre" style="padding:10px 12px 4px">
          <h2 style="margin:0">Este mes</h2>
          <span class="sec peq">${lista.length}</span>
        </div>
        ${filas || estadoVacio('🗓️', 'Sin pagos fijos', 'Agrega tu arriendo, servicios o suscripciones para no olvidar ninguno.',
          '<button type="button" class="btn relleno" data-accion="pagoNuevo">Agregar pago fijo</button>')}
      </section>
      <p class="nota">Toca el círculo para marcar un pago como hecho este mes. Toca el pago para ver su historial.</p>
    </div>`;
}

acciones.pagoAlternar = (el) => {
  const id = el.dataset.id;
  D.cambiar((st) => {
    const p = st.pagosFijos.find((x) => x.id === id);
    if (p) alternarPago(p);
  });
};

acciones.pagoNuevo = () => formulario(null);

// ---------- Detalle con historial ----------

acciones.pagoDetalle = (el) => {
  const id = el.dataset.id;
  if (!D.datos().pagosFijos.some((x) => x.id === id)) return;
  let hoja;
  let cancelar = () => {};

  const contenido = () => {
    const p = D.datos().pagosFijos.find((x) => x.id === id);
    if (!p) return '<p class="sec">Este pago ya no existe.</p>';
    const cat = categoriaPago(p.categoria);
    const estado = estadoPago(p);
    const info = ESTADOS_PAGO[estado];
    const historial = [...(p.historial || [])].sort(porFechaDesc());
    const filas = historial.map((r) => `
      <div class="fila">
        <div class="cuerpo">
          <div class="titulo">${esc(fechaCorta(r.fecha))}</div>
          <div class="sub">${mismoMes(aFecha(r.fecha), new Date()) ? 'Este mes' : ''}</div>
        </div>
        <span class="monto">${esc(dinero(r.monto))}</span>
        <button type="button" class="btn-icono" data-local="borrarRegistro" data-id="${esc(r.id)}" aria-label="Eliminar este registro" style="color:var(--rojo)">✕</button>
      </div>`).join('');

    return `
      <div class="tarjeta vidrio mb">
        <div class="flex-entre" style="align-items:flex-start;gap:12px">
          <div style="display:flex;gap:12px;align-items:center;min-width:0">
            ${iconoCirc(cat.emoji, cat.color, 'grande')}
            <div style="min-width:0"><div style="font-weight:700;font-size:1.1rem">${esc(p.nombre)}</div><div class="sec peq">${esc(cat.nombre)} · cada mes el día ${p.diaVencimiento}</div></div>
          </div>
          ${chipEstado(info.nombre, info.color, info.emoji)}
        </div>
        <div class="monto-grande" style="margin-top:12px">${esc(dinero(p.monto))}</div>
        <div class="peq sec" style="margin-top:2px">${esc(textoVencimiento(p))}${montoPagado(p) > 0 ? ` · pagado este mes: ${esc(dinero(montoPagado(p)))}` : ''}</div>
        ${p.nota ? `<p class="peq" style="margin:10px 0 0;white-space:pre-wrap">${esc(p.nota)}</p>` : ''}
      </div>
      <div class="btns mb">
        <button type="button" class="btn vidrio" data-local="registrar">Registrar pago</button>
        <button type="button" class="btn vidrio" data-local="editar">Editar</button>
      </div>
      <div class="tarjeta vidrio tarjeta-lista mb">
        <h2 style="padding:8px 12px 0;margin:0">Historial de pagos</h2>
        ${filas || '<p class="sec peq" style="padding:10px 12px">Todavía no hay pagos registrados.</p>'}
      </div>
      <button type="button" class="btn peligro ancho" data-local="eliminar">Eliminar pago fijo</button>`;
  };

  hoja = abrirHoja({
    titulo: 'Pago fijo',
    cuerpo: contenido(),
    alCerrar: () => cancelar(),
    alMontar: (h) => enlazarLocal(h, {
      registrar: () => formularioRegistro(id),
      editar: () => {
        const p = D.datos().pagosFijos.find((x) => x.id === id);
        if (p) formulario(p);
      },
      borrarRegistro: async (boton) => {
        const ok = await confirmar({ titulo: '¿Eliminar este registro de pago?', textoOk: 'Eliminar', peligro: true });
        if (!ok) return;
        D.cambiar((st) => {
          const p = st.pagosFijos.find((x) => x.id === id);
          if (p) eliminarRegistroPago(p, boton.dataset.id);
        });
      },
      eliminar: async () => {
        const p = D.datos().pagosFijos.find((x) => x.id === id);
        if (!p) return;
        const ok = await confirmar({
          titulo: `¿Eliminar «${p.nombre}»?`, mensaje: 'También se borra su historial de pagos.', textoOk: 'Eliminar', peligro: true
        });
        if (!ok) return;
        D.cambiar((st) => { st.pagosFijos = st.pagosFijos.filter((x) => x.id !== id); });
        h.cerrar();
        toast('Pago fijo eliminado');
      }
    })
  });
  // Si los datos cambian con la hoja abierta (por ejemplo, tras editar), se vuelve a dibujar.
  cancelar = D.suscribir(() => { if (document.body.contains(hoja.el)) hoja.poner(contenido()); });
};

function formularioRegistro(id) {
  const p = D.datos().pagosFijos.find((x) => x.id === id);
  if (!p) return;
  abrirHoja({
    titulo: 'Registrar pago',
    cuerpo: `
      ${campoMonto({ nombre: 'monto', etiqueta: 'Monto pagado', valor: textoNumero(p.monto) })}
      ${campoFecha({ nombre: 'fecha', etiqueta: 'Fecha del pago', valor: aCampoFecha(new Date()), max: aCampoFecha(new Date()) })}`,
    alGuardar: (cuerpo) => {
      const v = leerCampos(cuerpo);
      const monto = montoPositivo(v.monto);
      const fecha = deCampoFecha(v.fecha);
      if (!fecha) throw new Error('La fecha no es válida.');
      if (fecha.getTime() > Date.now() + 86400000) throw new Error('La fecha no puede ser futura.');
      D.cambiar((st) => {
        const x = st.pagosFijos.find((y) => y.id === id);
        if (x) agregarRegistroPago(x, monto, fecha);
      });
      toast('Pago registrado');
    }
  });
}

// ---------- Formulario ----------

function formulario(p) {
  const nuevo = !p;
  abrirHoja({
    titulo: nuevo ? 'Nuevo pago fijo' : 'Editar pago fijo',
    cuerpo: `
      ${campo({ nombre: 'nombre', etiqueta: 'Nombre', valor: p ? p.nombre : '', placeholder: 'Ej. Arriendo, Netflix', maxlength: 60 })}
      ${campoMonto({ nombre: 'monto', etiqueta: 'Monto mensual', valor: p ? textoNumero(p.monto) : '' })}
      ${campoNumero({ nombre: 'dia', etiqueta: 'Día del mes en que vence', valor: p ? String(p.diaVencimiento) : '', placeholder: '1 – 31', ayuda: 'Si el mes es más corto, vence el último día.' })}
      ${chips({ nombre: 'categoria', etiqueta: 'Categoría', opciones: CATEGORIAS_PAGO, valor: p ? categoriaPago(p.categoria).id : 'servicios', envuelto: true })}
      ${campoNota({ valor: p ? p.nota : '' })}`,
    alGuardar: (cuerpo) => {
      const v = leerCampos(cuerpo);
      const nombre = textoLimpio(v.nombre, 60);
      if (!nombre) throw new Error('Escribe un nombre para el pago.');
      const monto = montoPositivo(v.monto);
      if (String(v.dia).trim() === '') throw new Error('Indica el día del mes en que vence.');
      const dia = enteroEnRango(v.dia, 'El día de vencimiento', 1, 31);
      const datos = { nombre, monto, diaVencimiento: dia, categoria: categoriaPago(v.categoria).id, nota: notaLimpia(v.nota) };
      D.cambiar((st) => {
        if (nuevo) st.pagosFijos.push({ id: uuid(), ...datos, ultimoPago: null, historial: [] });
        else {
          const x = st.pagosFijos.find((y) => y.id === p.id);
          if (x) Object.assign(x, datos);
        }
      });
      toast(nuevo ? 'Pago fijo agregado' : 'Cambios guardados');
    }
  });
}
