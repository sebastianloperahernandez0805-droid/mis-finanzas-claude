// Pantalla «Metas»: objetivos de ahorro con aportes y retiros.

import * as D from '../datos.js';
import {
  esc, uuid, aIso, aFecha, aCampoFecha, deCampoFecha, textoNumero, dinero, porcentaje, fechaCorta
} from '../util.js';
import {
  PALETAS, ICONOS_META, emojiDe, colorDePaleta, montoAhorrado, progresoMeta, faltanteMeta, metaCumplida,
  aporteSugerido, mesesRestantes, fechaMetaVencida, sumar
} from '../calculos.js';
import {
  acciones, toast, abrirHoja, confirmar, campo, campoMonto, campoNota, campoFecha, chips, leerCampos,
  iconoCirc, chipEstado, barraProgreso, estadoVacio, icono
} from '../ui.js';
import {
  montoPositivo, numeroOpcional, fechaOpcional, textoLimpio, notaLimpia, enlazarLocal, porFechaDesc
} from './comun.js';

export const titulo = 'Metas';

export function botones() {
  return `<button class="btn-icono vidrio" data-accion="metaNueva" aria-label="Agregar meta">${icono('mas')}</button>`;
}

function etiquetasMeta(m) {
  const etiquetas = [];
  if (metaCumplida(m)) {
    etiquetas.push(chipEstado('¡Meta cumplida!', 'var(--verde)', '🎉'));
    return etiquetas.join('');
  }
  etiquetas.push(chipEstado(`Faltan ${dinero(faltanteMeta(m))}`, 'var(--acento)'));
  if (m.fechaObjetivo) {
    if (fechaMetaVencida(m)) etiquetas.push(chipEstado(`Venció el ${fechaCorta(m.fechaObjetivo)}`, 'var(--rojo)', '!'));
    else etiquetas.push(chipEstado(`Para el ${fechaCorta(m.fechaObjetivo)}`, 'var(--gris)'));
  }
  const sugerido = aporteSugerido(m);
  if (sugerido !== null) etiquetas.push(chipEstado(`Aporta ≈ ${dinero(sugerido)} al mes`, 'var(--morado)'));
  return etiquetas.join('');
}

export function render() {
  const d = D.datos();
  const lista = [...d.metas].sort((a, b) => {
    const ca = metaCumplida(a) ? 1 : 0;
    const cb = metaCumplida(b) ? 1 : 0;
    return ca - cb || new Date(a.fechaCreacion).getTime() - new Date(b.fechaCreacion).getTime();
  });
  const ahorrado = lista.reduce((acc, m) => acc + Math.max(montoAhorrado(m), 0), 0);
  const objetivo = sumar(lista, 'montoObjetivo');

  const tarjetas = lista.map((m) => {
    const color = colorDePaleta(m.paleta);
    const cumplida = metaCumplida(m);
    return `
      <article class="tarjeta vidrio">
        <button type="button" class="fila-link" data-accion="metaDetalle" data-id="${esc(m.id)}" style="width:100%">
          ${iconoCirc(emojiDe(m.icono, '🎯'), color, 'grande')}
          <div class="cuerpo">
            <div class="titulo">${esc(m.nombre)}</div>
            <div class="sub">${esc(porcentaje(progresoMeta(m)))} de la meta</div>
          </div>
          <div class="lado">
            <span class="monto">${esc(dinero(montoAhorrado(m)))}</span>
            <span class="sub">de ${esc(dinero(m.montoObjetivo))}</span>
          </div>
        </button>
        <div style="margin:12px 0 10px">${barraProgreso(progresoMeta(m), cumplida ? 'var(--verde)' : color)}</div>
        <div style="display:flex;flex-wrap:wrap;gap:6px">${etiquetasMeta(m)}</div>
        <div class="btns" style="margin-top:12px">
          <button type="button" class="btn relleno chico" data-accion="metaAportar" data-id="${esc(m.id)}">Aportar</button>
          <button type="button" class="btn vidrio chico" data-accion="metaRetirar" data-id="${esc(m.id)}" ${montoAhorrado(m) > 0 ? '' : 'disabled'}>Retirar</button>
        </div>
      </article>`;
  }).join('');

  return `
    <div class="apilar">
      ${lista.length ? `
      <section class="tarjeta vidrio">
        <div class="sec peq">Total ahorrado en tus metas</div>
        <div class="monto-grande" style="color:var(--verde)">${esc(dinero(ahorrado))}</div>
        <div style="margin:12px 0 8px">${barraProgreso(objetivo > 0 ? ahorrado / objetivo : 0, 'var(--verde)')}</div>
        <div class="peq sec">de ${esc(dinero(objetivo))} que quieres juntar</div>
      </section>
      ${tarjetas}
      <p class="nota">El aporte mensual sugerido es una estimación simple: lo que falta dividido entre los meses que quedan.</p>`
      : `<section class="tarjeta vidrio">${estadoVacio('🎯', 'Sin metas', 'Crea una meta (un viaje, un fondo de emergencia, un computador) y ve cómo avanzas.',
        '<button type="button" class="btn relleno" data-accion="metaNueva">Agregar meta</button>')}</section>`}
    </div>`;
}

acciones.metaNueva = () => formulario(null);
acciones.metaAportar = (el) => formularioMovimiento(el.dataset.id, 1);
acciones.metaRetirar = (el) => formularioMovimiento(el.dataset.id, -1);

// ---------- Aportar / retirar ----------

function formularioMovimiento(id, signo) {
  const m = D.datos().metas.find((x) => x.id === id);
  if (!m) return;
  const ahorrado = montoAhorrado(m);
  const aportar = signo > 0;
  const sugerido = aportar ? aporteSugerido(m) : null;

  abrirHoja({
    titulo: aportar ? `Aportar a ${m.nombre}`.slice(0, 40) : `Retirar de ${m.nombre}`.slice(0, 40),
    cuerpo: `
      <p class="sec peq" style="margin-top:0">Llevas <b class="num">${esc(dinero(ahorrado))}</b> de ${esc(dinero(m.montoObjetivo))}.</p>
      ${campoMonto({ nombre: 'monto', etiqueta: aportar ? 'Monto a aportar' : 'Monto a retirar', ayuda: sugerido !== null ? `Sugerido este mes: ${dinero(sugerido)}` : '' })}
      ${campoFecha({ nombre: 'fecha', etiqueta: 'Fecha', valor: aCampoFecha(new Date()), max: aCampoFecha(new Date()) })}
      ${campo({ nombre: 'nota', etiqueta: 'Nota (opcional)', maxlength: 120 })}`,
    alGuardar: (cuerpo) => {
      const v = leerCampos(cuerpo);
      const monto = montoPositivo(v.monto);
      if (!aportar && monto > ahorrado + 0.009) throw new Error(`Solo hay ${dinero(ahorrado)} ahorrados en esta meta.`);
      const fecha = deCampoFecha(v.fecha);
      if (!fecha) throw new Error('La fecha no es válida.');
      if (fecha.getTime() > Date.now() + 86400000) throw new Error('La fecha no puede ser futura.');
      D.cambiar((st) => {
        const x = st.metas.find((y) => y.id === id);
        if (x) x.movimientos.push({ id: uuid(), monto: signo * monto, fecha: aIso(fecha), nota: textoLimpio(v.nota, 120) });
      });
      toast(aportar ? 'Aporte registrado' : 'Retiro registrado');
    }
  });
}

// ---------- Detalle ----------

acciones.metaDetalle = (el) => {
  const id = el.dataset.id;
  if (!D.datos().metas.some((y) => y.id === id)) return;
  let hoja;
  let cancelar = () => {};

  const contenido = () => {
    const m = D.datos().metas.find((y) => y.id === id);
    if (!m) return '<p class="sec">Esta meta ya no existe.</p>';
    const color = colorDePaleta(m.paleta);
    const meses = mesesRestantes(m);
    const movimientos = [...m.movimientos].sort(porFechaDesc());
    const filas = movimientos.map((mov) => `
      <div class="fila">
        <div class="cuerpo">
          <div class="titulo">${esc(fechaCorta(mov.fecha))}</div>
          <div class="sub">${esc(mov.monto >= 0 ? 'Aporte' : 'Retiro')}${mov.nota ? ` · ${esc(mov.nota)}` : ''}</div>
        </div>
        <span class="monto" style="color:${mov.monto >= 0 ? 'var(--verde)' : 'var(--rojo)'}">${esc(dinero(mov.monto))}</span>
        <button type="button" class="btn-icono" data-local="borrarMovimiento" data-id="${esc(mov.id)}" aria-label="Eliminar este movimiento" style="color:var(--rojo)">✕</button>
      </div>`).join('');

    return `
      <div class="tarjeta vidrio mb">
        <div style="display:flex;gap:12px;align-items:center">
          ${iconoCirc(emojiDe(m.icono, '🎯'), color, 'grande')}
          <div style="min-width:0"><div style="font-weight:700;font-size:1.1rem">${esc(m.nombre)}</div>
            <div class="sec peq">Meta de ${esc(dinero(m.montoObjetivo))}</div></div>
        </div>
        <div class="monto-grande" style="margin-top:14px">${esc(dinero(montoAhorrado(m)))}</div>
        <div style="margin:10px 0 8px">${barraProgreso(progresoMeta(m), metaCumplida(m) ? 'var(--verde)' : color)}</div>
        <div class="peq sec">${esc(porcentaje(progresoMeta(m)))} · ${metaCumplida(m) ? '¡cumplida!' : `faltan ${esc(dinero(faltanteMeta(m)))}`}</div>
        <div style="display:flex;flex-wrap:wrap;gap:6px;margin-top:10px">${etiquetasMeta(m)}</div>
        ${meses !== null && !metaCumplida(m) ? `<div class="peq sec" style="margin-top:8px">Quedan unos ${meses} ${meses === 1 ? 'mes' : 'meses'} para la fecha objetivo.</div>` : ''}
      </div>
      <div class="btns mb">
        <button type="button" class="btn relleno" data-local="aportar">Aportar</button>
        <button type="button" class="btn vidrio" data-local="retirar" ${montoAhorrado(m) > 0 ? '' : 'disabled'}>Retirar</button>
        <button type="button" class="btn vidrio" data-local="editar">Editar</button>
      </div>
      <div class="tarjeta vidrio tarjeta-lista mb">
        <h2 style="padding:8px 12px 0;margin:0">Movimientos</h2>
        ${filas || '<p class="sec peq" style="padding:10px 12px">Todavía no hay movimientos.</p>'}
      </div>
      <button type="button" class="btn peligro ancho" data-local="eliminar">Eliminar meta</button>`;
  };

  hoja = abrirHoja({
    titulo: 'Meta',
    cuerpo: contenido(),
    alCerrar: () => cancelar(),
    alMontar: (h) => enlazarLocal(h, {
      aportar: () => formularioMovimiento(id, 1),
      retirar: () => formularioMovimiento(id, -1),
      editar: () => {
        const m = D.datos().metas.find((y) => y.id === id);
        if (m) formulario(m);
      },
      borrarMovimiento: async (boton) => {
        const ok = await confirmar({ titulo: '¿Eliminar este movimiento?', textoOk: 'Eliminar', peligro: true });
        if (!ok) return;
        D.cambiar((st) => {
          const m = st.metas.find((y) => y.id === id);
          if (m) m.movimientos = m.movimientos.filter((x) => x.id !== boton.dataset.id);
        });
      },
      eliminar: async () => {
        const m = D.datos().metas.find((y) => y.id === id);
        if (!m) return;
        const ok = await confirmar({
          titulo: `¿Eliminar «${m.nombre}»?`, mensaje: 'También se borran todos sus aportes y retiros.', textoOk: 'Eliminar', peligro: true
        });
        if (!ok) return;
        D.cambiar((st) => { st.metas = st.metas.filter((y) => y.id !== id); });
        h.cerrar();
        toast('Meta eliminada');
      }
    })
  });
  cancelar = D.suscribir(() => { if (document.body.contains(hoja.el)) hoja.poner(contenido()); });
};

// ---------- Formulario ----------

function formulario(m) {
  const nuevo = !m;
  const iconos = ICONOS_META.map(([id, emoji]) => ({ id, nombre: '', emoji }));
  // Una meta creada en el iPhone puede traer un ícono que no está en la lista: se conserva.
  if (m && !iconos.some((i) => i.id === m.icono)) iconos.unshift({ id: m.icono, nombre: '', emoji: emojiDe(m.icono, '🎯') });
  const paletaActual = m && PALETAS.some((p) => p.id === m.paleta) ? m.paleta : 'azul';

  abrirHoja({
    titulo: nuevo ? 'Nueva meta' : 'Editar meta',
    cuerpo: `
      ${campo({ nombre: 'nombre', etiqueta: 'Nombre de la meta', valor: m ? m.nombre : '', placeholder: 'Ej. Viaje, fondo de emergencia', maxlength: 60 })}
      ${campoMonto({ nombre: 'objetivo', etiqueta: 'Cuánto quieres juntar', valor: m ? textoNumero(m.montoObjetivo) : '' })}
      ${nuevo ? campoMonto({ nombre: 'inicial', etiqueta: 'Ya ahorrado hasta hoy (opcional)', ayuda: 'Si ya tienes algo apartado para esta meta.' }) : ''}
      ${chips({ nombre: 'icono', etiqueta: 'Ícono', opciones: iconos, valor: m ? m.icono : ICONOS_META[0][0], envuelto: true })}
      ${chips({ nombre: 'paleta', etiqueta: 'Color', opciones: PALETAS, valor: paletaActual, envuelto: true })}
      ${campoFecha({ nombre: 'fecha', etiqueta: 'Fecha objetivo (opcional)', valor: m && m.fechaObjetivo ? aCampoFecha(aFecha(m.fechaObjetivo)) : '' })}`,
    alGuardar: (cuerpo) => {
      const v = leerCampos(cuerpo);
      const nombre = textoLimpio(v.nombre, 60);
      if (!nombre) throw new Error('Escribe un nombre para la meta.');
      const objetivo = montoPositivo(v.objetivo, 'El monto objetivo');
      const inicial = nuevo ? numeroOpcional(v.inicial, 'Lo ahorrado') : 0;
      const fecha = fechaOpcional(v.fecha, 'La fecha objetivo');
      const datos = {
        nombre,
        montoObjetivo: objetivo,
        icono: v.icono || 'target',
        paleta: PALETAS.some((p) => p.id === v.paleta) ? v.paleta : 'azul',
        fechaObjetivo: fecha ? aIso(fecha) : null
      };
      D.cambiar((st) => {
        if (nuevo) {
          const ahora = aIso();
          st.metas.push({
            id: uuid(), ...datos, fechaCreacion: ahora,
            movimientos: inicial > 0 ? [{ id: uuid(), monto: inicial, fecha: ahora, nota: 'Ahorro inicial' }] : []
          });
        } else {
          const x = st.metas.find((y) => y.id === m.id);
          if (x) Object.assign(x, datos);
        }
      });
      toast(nuevo ? 'Meta agregada' : 'Cambios guardados');
    }
  });
}
