// Pantalla «Deudas»: préstamos, tarjetas y deudas con personas, con abonos y saldo pendiente.

import * as D from '../datos.js';
import {
  esc, uuid, aIso, aFecha, aCampoFecha, deCampoFecha, textoNumero, dinero, porcentaje, fechaCorta
} from '../util.js';
import {
  TIPOS_DEUDA, tipoDeuda, totalAbonado, saldoPendiente, progresoDeuda, deudaSaldada, tieneInteresOCuotas,
  interesMensualEstimado, cuotaEstimada, cuotasRestantes, sumar
} from '../calculos.js';
import {
  acciones, toast, abrirHoja, confirmar, campo, campoMonto, campoNumero, campoNota, campoFecha, chips,
  leerCampos, iconoCirc, chipEstado, barraProgreso, estadoVacio, icono
} from '../ui.js';
import {
  montoPositivo, numeroOpcional, enteroEnRango, fechaOpcional, textoLimpio, notaLimpia, enlazarLocal,
  enlazarAtajos, porFechaDesc
} from './comun.js';

export const titulo = 'Deudas';

export function botones() {
  return `<button class="btn-icono vidrio" data-accion="deudaNueva" aria-label="Agregar deuda">${icono('mas')}</button>`;
}

function etiquetasDeuda(deuda) {
  const etiquetas = [];
  if (deudaSaldada(deuda)) {
    etiquetas.push(chipEstado('Saldada', 'var(--verde)', '✓'));
    return etiquetas.join('');
  }
  if (deuda.numeroCuotas > 0) {
    etiquetas.push(chipEstado(`Cuota ≈ ${dinero(cuotaEstimada(deuda))}`, 'var(--acento)'));
    etiquetas.push(chipEstado(`Quedan ${cuotasRestantes(deuda)} de ${deuda.numeroCuotas} cuotas`, 'var(--indigo)'));
  }
  if (deuda.tasaInteresAnual > 0) {
    etiquetas.push(chipEstado(`Interés ≈ ${dinero(interesMensualEstimado(deuda))}/mes`, 'var(--naranja)'));
  }
  if (deuda.diaPago > 0) etiquetas.push(chipEstado(`Paga el día ${deuda.diaPago}`, 'var(--turquesa)'));
  if (deuda.fechaLimite) etiquetas.push(chipEstado(`Límite ${fechaCorta(deuda.fechaLimite)}`, 'var(--gris)'));
  return etiquetas.join('');
}

export function render() {
  const d = D.datos();
  const lista = [...d.deudas].sort((a, b) => {
    const sa = deudaSaldada(a) ? 1 : 0;
    const sb = deudaSaldada(b) ? 1 : 0;
    return sa - sb || saldoPendiente(b) - saldoPendiente(a);
  });
  const pendiente = lista.reduce((acc, x) => acc + saldoPendiente(x), 0);
  const abonado = lista.reduce((acc, x) => acc + Math.min(totalAbonado(x), x.montoTotal), 0);
  const total = sumar(lista, 'montoTotal');
  const intereses = lista.reduce((acc, x) => acc + (deudaSaldada(x) ? 0 : interesMensualEstimado(x)), 0);

  const tarjetas = lista.map((x) => {
    const tipo = tipoDeuda(x.tipo);
    const saldada = deudaSaldada(x);
    return `
      <article class="tarjeta vidrio">
        <button type="button" class="fila-link" data-accion="deudaDetalle" data-id="${esc(x.id)}" style="width:100%">
          ${iconoCirc(tipo.emoji, tipo.color, 'grande')}
          <div class="cuerpo">
            <div class="titulo">${esc(x.nombre)}</div>
            <div class="sub">${esc(x.acreedor ? `${x.acreedor} · ${tipo.nombre}` : tipo.nombre)}</div>
          </div>
          <div class="lado">
            <span class="monto">${esc(dinero(saldoPendiente(x)))}</span>
            <span class="sub">pendiente</span>
          </div>
        </button>
        <div style="margin:12px 0 6px">${barraProgreso(progresoDeuda(x), saldada ? 'var(--verde)' : tipo.color)}</div>
        <div class="flex-entre peq sec">
          <span>Abonado ${esc(dinero(totalAbonado(x)))}</span>
          <span>de ${esc(dinero(x.montoTotal))} · ${esc(porcentaje(progresoDeuda(x)))}</span>
        </div>
        <div style="display:flex;flex-wrap:wrap;gap:6px;margin-top:10px">${etiquetasDeuda(x)}</div>
        ${saldada ? '' : `<div class="btns" style="margin-top:12px"><button type="button" class="btn relleno chico" data-accion="deudaAbonar" data-id="${esc(x.id)}">Abonar</button></div>`}
      </article>`;
  }).join('');

  return `
    <div class="apilar">
      ${lista.length ? `
      <section class="tarjeta vidrio">
        <div class="sec peq">Total que debes</div>
        <div class="monto-grande" style="color:${pendiente > 0 ? 'var(--rojo)' : 'var(--verde)'}">${esc(dinero(pendiente))}</div>
        <div style="margin:12px 0 8px">${barraProgreso(total > 0 ? abonado / total : 0, 'var(--verde)')}</div>
        <div class="flex-entre peq">
          <span><span class="sec">Abonado </span><b class="num">${esc(dinero(abonado))}</b></span>
          <span><span class="sec">De </span><b class="num">${esc(dinero(total))}</b></span>
        </div>
        ${intereses > 0 ? `<div class="peq sec" style="margin-top:8px">Intereses estimados este mes: ${esc(dinero(intereses))}</div>` : ''}
      </section>
      ${tarjetas}
      <p class="nota">El interés y las cuotas son estimaciones sencillas (cuotas iguales). Tu banco puede calcular distinto.</p>`
      : `<section class="tarjeta vidrio">${estadoVacio('💳', 'Sin deudas', 'Registra lo que debes y ve cómo baja con cada abono.',
        '<button type="button" class="btn relleno" data-accion="deudaNueva">Agregar deuda</button>')}</section>`}
    </div>`;
}

acciones.deudaNueva = () => formulario(null);

acciones.deudaAbonar = (el) => {
  const x = D.datos().deudas.find((y) => y.id === el.dataset.id);
  if (x) formularioAbono(x.id);
};

// ---------- Abonar ----------

function formularioAbono(id) {
  const x = D.datos().deudas.find((y) => y.id === id);
  if (!x) return;
  const saldo = saldoPendiente(x);
  const cuota = cuotaEstimada(x);
  const atajos = [];
  if (tieneInteresOCuotas(x) && cuota > 0 && cuota < saldo) {
    atajos.push(`<button type="button" data-atajo="${Math.round(cuota * 100) / 100}">Cuota estimada · ${esc(dinero(cuota))}</button>`);
  }
  if (saldo > 0) atajos.push(`<button type="button" data-atajo="${saldo}">Saldo completo · ${esc(dinero(saldo))}</button>`);

  abrirHoja({
    titulo: `Abonar a ${x.nombre}`.slice(0, 40),
    cuerpo: `
      <p class="sec peq" style="margin-top:0">Saldo pendiente: <b class="num">${esc(dinero(saldo))}</b></p>
      ${campoMonto({ nombre: 'monto', etiqueta: 'Monto del abono' })}
      ${atajos.length ? `<div class="chips mb">${atajos.join('')}</div>` : ''}
      ${campoFecha({ nombre: 'fecha', etiqueta: 'Fecha', valor: aCampoFecha(new Date()), max: aCampoFecha(new Date()) })}
      ${campo({ nombre: 'nota', etiqueta: 'Nota (opcional)', maxlength: 120 })}`,
    alMontar: enlazarAtajos,
    alGuardar: (cuerpo) => {
      const v = leerCampos(cuerpo);
      const monto = montoPositivo(v.monto, 'El abono');
      if (monto > saldo + 0.009) throw new Error(`El abono no puede ser mayor que el saldo pendiente (${dinero(saldo)}).`);
      const fecha = deCampoFecha(v.fecha);
      if (!fecha) throw new Error('La fecha no es válida.');
      if (fecha.getTime() > Date.now() + 86400000) throw new Error('La fecha no puede ser futura.');
      D.cambiar((st) => {
        const y = st.deudas.find((z) => z.id === id);
        if (y) y.abonos.push({ id: uuid(), monto, fecha: aIso(fecha), nota: textoLimpio(v.nota, 120) });
      });
      toast('Abono registrado');
    }
  });
}

// ---------- Detalle ----------

acciones.deudaDetalle = (el) => {
  const id = el.dataset.id;
  if (!D.datos().deudas.some((y) => y.id === id)) return;
  let hoja;
  let cancelar = () => {};

  const contenido = () => {
    const x = D.datos().deudas.find((y) => y.id === id);
    if (!x) return '<p class="sec">Esta deuda ya no existe.</p>';
    const tipo = tipoDeuda(x.tipo);
    const saldada = deudaSaldada(x);
    const abonos = [...x.abonos].sort(porFechaDesc());
    const datos = [
      ['Monto total', dinero(x.montoTotal)],
      ['Abonado', dinero(totalAbonado(x))],
      ['Saldo pendiente', dinero(saldoPendiente(x))],
      x.tasaInteresAnual > 0 ? ['Interés anual', `${x.tasaInteresAnual}%`] : null,
      x.tasaInteresAnual > 0 && !saldada ? ['Interés estimado al mes', dinero(interesMensualEstimado(x))] : null,
      x.numeroCuotas > 0 ? ['Cuotas', `${x.numeroCuotas} · quedan ${cuotasRestantes(x)}`] : null,
      x.numeroCuotas > 0 ? ['Cuota estimada', dinero(cuotaEstimada(x))] : null,
      x.diaPago > 0 ? ['Día de pago', `Cada mes, el día ${x.diaPago}`] : null,
      x.fechaLimite ? ['Fecha límite', fechaCorta(x.fechaLimite)] : null,
      ['Creada', fechaCorta(x.fechaCreacion)]
    ].filter(Boolean);

    const filas = abonos.map((a) => `
      <div class="fila">
        <div class="cuerpo">
          <div class="titulo">${esc(fechaCorta(a.fecha))}</div>
          ${a.nota ? `<div class="sub">${esc(a.nota)}</div>` : ''}
        </div>
        <span class="monto">${esc(dinero(a.monto))}</span>
        <button type="button" class="btn-icono" data-local="borrarAbono" data-id="${esc(a.id)}" aria-label="Eliminar este abono" style="color:var(--rojo)">✕</button>
      </div>`).join('');

    return `
      <div class="tarjeta vidrio mb">
        <div style="display:flex;gap:12px;align-items:center">
          ${iconoCirc(tipo.emoji, tipo.color, 'grande')}
          <div style="min-width:0"><div style="font-weight:700;font-size:1.1rem">${esc(x.nombre)}</div>
            <div class="sec peq">${esc(x.acreedor ? `${x.acreedor} · ${tipo.nombre}` : tipo.nombre)}</div></div>
        </div>
        <div style="margin:14px 0 6px">${barraProgreso(progresoDeuda(x), saldada ? 'var(--verde)' : tipo.color)}</div>
        <div class="flex-entre peq sec"><span>${esc(porcentaje(progresoDeuda(x)))} pagado</span>${saldada ? chipEstado('Saldada', 'var(--verde)', '✓') : ''}</div>
        <div class="sep"></div>
        <table class="tabla">${datos.map(([k, v]) => `<tr><td class="sec">${esc(k)}</td><td>${esc(v)}</td></tr>`).join('')}</table>
        ${x.nota ? `<p class="peq" style="margin:10px 0 0;white-space:pre-wrap">${esc(x.nota)}</p>` : ''}
      </div>
      <div class="btns mb">
        ${saldada ? '' : '<button type="button" class="btn relleno" data-local="abonar">Abonar</button>'}
        <button type="button" class="btn vidrio" data-local="editar">Editar</button>
      </div>
      <div class="tarjeta vidrio tarjeta-lista mb">
        <h2 style="padding:8px 12px 0;margin:0">Abonos</h2>
        ${filas || '<p class="sec peq" style="padding:10px 12px">Todavía no hay abonos.</p>'}
      </div>
      <button type="button" class="btn peligro ancho" data-local="eliminar">Eliminar deuda</button>`;
  };

  hoja = abrirHoja({
    titulo: 'Deuda',
    cuerpo: contenido(),
    alCerrar: () => cancelar(),
    alMontar: (h) => enlazarLocal(h, {
      abonar: () => formularioAbono(id),
      editar: () => {
        const x = D.datos().deudas.find((y) => y.id === id);
        if (x) formulario(x);
      },
      borrarAbono: async (boton) => {
        const ok = await confirmar({ titulo: '¿Eliminar este abono?', mensaje: 'El saldo pendiente volverá a subir.', textoOk: 'Eliminar', peligro: true });
        if (!ok) return;
        D.cambiar((st) => {
          const x = st.deudas.find((y) => y.id === id);
          if (x) x.abonos = x.abonos.filter((a) => a.id !== boton.dataset.id);
        });
      },
      eliminar: async () => {
        const x = D.datos().deudas.find((y) => y.id === id);
        if (!x) return;
        const ok = await confirmar({
          titulo: `¿Eliminar «${x.nombre}»?`, mensaje: 'También se borran todos sus abonos.', textoOk: 'Eliminar', peligro: true
        });
        if (!ok) return;
        D.cambiar((st) => { st.deudas = st.deudas.filter((y) => y.id !== id); });
        h.cerrar();
        toast('Deuda eliminada');
      }
    })
  });
  cancelar = D.suscribir(() => { if (document.body.contains(hoja.el)) hoja.poner(contenido()); });
};

// ---------- Formulario ----------

function formulario(x) {
  const nuevo = !x;
  abrirHoja({
    titulo: nuevo ? 'Nueva deuda' : 'Editar deuda',
    cuerpo: `
      ${campo({ nombre: 'nombre', etiqueta: 'Nombre', valor: x ? x.nombre : '', placeholder: 'Ej. Préstamo del carro', maxlength: 60 })}
      ${campo({ nombre: 'acreedor', etiqueta: 'A quién se le debe (opcional)', valor: x ? x.acreedor : '', placeholder: 'Banco, persona...', maxlength: 60 })}
      ${chips({ nombre: 'tipo', etiqueta: 'Tipo', opciones: TIPOS_DEUDA, valor: x ? tipoDeuda(x.tipo).id : 'prestamo', envuelto: true })}
      ${campoMonto({ nombre: 'total', etiqueta: 'Monto total de la deuda', valor: x ? textoNumero(x.montoTotal) : '' })}
      ${nuevo ? campoMonto({ nombre: 'abonado', etiqueta: 'Ya abonado hasta hoy (opcional)', ayuda: 'Si ya pagaste una parte, escríbela aquí.' }) : ''}
      ${campoNumero({ nombre: 'interes', etiqueta: 'Interés anual % (opcional)', valor: x && x.tasaInteresAnual > 0 ? textoNumero(x.tasaInteresAnual) : '', placeholder: 'Ej. 24' })}
      ${campoNumero({ nombre: 'cuotas', etiqueta: 'Número de cuotas (opcional)', valor: x && x.numeroCuotas > 0 ? String(x.numeroCuotas) : '', placeholder: 'Ej. 12' })}
      ${campoNumero({ nombre: 'diaPago', etiqueta: 'Día del mes en que pagas (opcional)', valor: x && x.diaPago > 0 ? String(x.diaPago) : '', placeholder: '1 – 31' })}
      ${campoFecha({ nombre: 'limite', etiqueta: 'Fecha límite (opcional)', valor: x && x.fechaLimite ? aCampoFecha(aFecha(x.fechaLimite)) : '' })}
      ${campoNota({ valor: x ? x.nota : '' })}`,
    alGuardar: (cuerpo) => {
      const v = leerCampos(cuerpo);
      const nombre = textoLimpio(v.nombre, 60);
      if (!nombre) throw new Error('Escribe un nombre para la deuda.');
      const montoTotal = montoPositivo(v.total, 'El monto total');
      const abonado = nuevo ? numeroOpcional(v.abonado, 'Lo abonado') : 0;
      if (abonado > montoTotal) throw new Error('Lo abonado no puede ser mayor que el monto total.');
      const tasa = numeroOpcional(v.interes, 'El interés');
      if (tasa > 1000) throw new Error('El interés no es válido.');
      const cuotas = enteroEnRango(v.cuotas, 'El número de cuotas', 0, 600, 0);
      const diaPago = enteroEnRango(v.diaPago, 'El día de pago', 0, 31, 0);
      const limite = fechaOpcional(v.limite, 'La fecha límite');
      const tipo = tipoDeuda(v.tipo);
      const datos = {
        nombre,
        acreedor: textoLimpio(v.acreedor, 60),
        tipo: tipo.id,
        montoTotal,
        fechaLimite: limite ? aIso(limite) : null,
        nota: notaLimpia(v.nota),
        tasaInteresAnual: tasa,
        numeroCuotas: cuotas,
        diaPago
      };
      D.cambiar((st) => {
        if (nuevo) {
          const ahora = aIso();
          st.deudas.push({
            id: uuid(), ...datos, fechaCreacion: ahora,
            abonos: abonado > 0 ? [{ id: uuid(), monto: abonado, fecha: ahora, nota: 'Abono inicial' }] : []
          });
        } else {
          const y = st.deudas.find((z) => z.id === x.id);
          if (y) Object.assign(y, datos);
        }
      });
      toast(nuevo ? 'Deuda agregada' : 'Cambios guardados');
    }
  });
}
