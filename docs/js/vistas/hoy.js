// Pantalla «Hoy»: gastos del día, presupuesto diario, semana y totales.

import * as D from '../datos.js';
import {
  esc, uuid, aIso, aFecha, inicioDia, inicioMes, inicioSemana, inicioAnio, sumarDias, mismoDia,
  aCampoFecha, deCampoFecha, aCampoFechaHora, deCampoFechaHora, textoNumero, parseNumero,
  dinero, porcentaje, fechaLarga, fechaDiaMes, nombreMes, hora
} from '../util.js';
import {
  categoriasDisponibles, categoriaVisual, gastosEntre, sumar, agruparPorCategoria
} from '../calculos.js';
import {
  acciones, cambios, envios, toast, abrirHoja, confirmar, campo, campoMonto, campoNota, chips,
  leerCampos, iconoCirc, anillo, barraProgreso, estadoVacio, icono, renderizar
} from '../ui.js';
import { montoPositivo, textoLimpio, notaLimpia, enlazarLocal, porFechaDesc } from './comun.js';

export const titulo = 'Hoy';

let dia = inicioDia(new Date());
let ultimaCategoria = 'comida';

export function botones() {
  return `<button class="btn-icono vidrio" data-accion="gastoNuevo" aria-label="Agregar gasto">${icono('mas')}</button>`;
}

function diaMostrado() {
  const hoyDia = inicioDia(new Date());
  if (dia.getTime() > hoyDia.getTime()) dia = hoyDia;
  return dia;
}

/** Fecha para un gasto nuevo: ahora si se mira hoy; si se mira otro día, ese día a la hora actual. */
function fechaNueva() {
  const ahora = new Date();
  if (mismoDia(diaMostrado(), ahora)) return ahora;
  const f = new Date(diaMostrado());
  f.setHours(ahora.getHours(), ahora.getMinutes(), 0, 0);
  return f;
}

function colorPresupuesto(ratio) {
  if (ratio > 1) return 'var(--rojo)';
  if (ratio >= 0.8) return 'var(--naranja)';
  return 'var(--verde)';
}

// ---------- Dibujo ----------

export function render() {
  const d = D.datos();
  const actual = diaMostrado();
  const hoyDia = inicioDia(new Date());
  const esHoy = mismoDia(actual, hoyDia);
  const gastosDia = gastosEntre(d.gastos, actual, sumarDias(actual, 1)).sort(porFechaDesc());
  const total = sumar(gastosDia);
  const presupuesto = d.presupuestoDiario;
  const ratio = presupuesto > 0 ? total / presupuesto : 0;

  let mensaje;
  if (presupuesto > 0) {
    const resto = presupuesto - total;
    mensaje = resto >= 0
      ? `Te quedan ${dinero(resto)} de ${dinero(presupuesto)}`
      : `Te pasaste por ${dinero(-resto)} (presupuesto ${dinero(presupuesto)})`;
  } else {
    mensaje = 'Define un presupuesto diario para ver cuánto te queda.';
  }

  const inicioSem = inicioSemana(actual);
  const dias = Array.from({ length: 7 }, (_, i) => sumarDias(inicioSem, i));
  const totales = dias.map((f) => sumar(gastosEntre(d.gastos, f, sumarDias(f, 1))));
  const maximo = Math.max(...totales, 1);
  const nombreDia = new Intl.DateTimeFormat(navigator.language || 'es', { weekday: 'short' });
  const totalSemana = totales.reduce((a, b) => a + b, 0);

  const columnas = dias.map((f, i) => {
    const futuro = f.getTime() > hoyDia.getTime();
    const alto = totales[i] > 0 ? Math.max(6, Math.round((totales[i] / maximo) * 84)) : 4;
    return `
      <button type="button" class="col ${mismoDia(f, actual) ? 'activa' : ''}" data-accion="elegirDia"
        data-fecha="${aCampoFecha(f)}" ${futuro ? 'disabled' : ''} aria-label="${esc(fechaLarga(f))}: ${esc(dinero(totales[i]))}">
        <span class="barra" style="height:${alto}px;${futuro ? 'opacity:.35' : ''}"></span>
        <span class="dia">${esc(nombreDia.format(f).replace('.', '').slice(0, 3))}</span>
      </button>`;
  }).join('');

  const filas = gastosDia.map((g) => {
    const cat = categoriaVisual(g.categoria, d.categorias);
    return `
      <button type="button" class="fila fila-click" data-accion="gastoEditar" data-id="${esc(g.id)}">
        ${iconoCirc(cat.emoji, cat.color)}
        <div class="cuerpo">
          <div class="titulo">${esc(g.concepto || cat.nombre)}</div>
          <div class="sub">${esc(cat.nombre)} · ${esc(hora(g.fecha))}</div>
        </div>
        <span class="monto">${esc(dinero(g.monto))}</span>
      </button>`;
  }).join('');

  return `
    <div class="apilar">
      <div class="selector-dia vidrio">
        <button type="button" class="btn-icono" data-accion="diaAnterior" aria-label="Día anterior">${icono('izq')}</button>
        <label class="pill-fecha">
          ${esHoy ? 'Hoy · ' : ''}${esc(fechaLarga(actual))}
          <input type="date" value="${aCampoFecha(actual)}" max="${aCampoFecha(hoyDia)}" data-cambio="diaElegido" aria-label="Elegir otro día">
        </label>
        <button type="button" class="btn-icono" data-accion="diaSiguiente" aria-label="Día siguiente" ${esHoy ? 'disabled' : ''}>${icono('der')}</button>
      </div>

      <section class="tarjeta vidrio">
        <div class="flex-entre" style="gap:16px">
          <div style="min-width:0">
            <div class="sec peq">${esHoy ? 'Gastado hoy' : 'Gastado ese día'}</div>
            <div class="monto-grande">${esc(dinero(total))}</div>
            <div class="peq sec" style="margin-top:4px">${esc(mensaje)}</div>
          </div>
          ${presupuesto > 0 ? anillo(Math.min(ratio, 1), colorPresupuesto(ratio), esc(porcentaje(ratio))) : ''}
        </div>
        <div class="espacio"></div>
        <div class="btns">
          <button type="button" class="btn vidrio" data-accion="presupuestoDiario">Presupuesto</button>
          <button type="button" class="btn vidrio" data-accion="totales">Ver totales</button>
        </div>
      </section>

      <form class="tarjeta vidrio" data-envio="gastoRapido" autocomplete="off">
        <h2>Agregar gasto</h2>
        <div class="rapido mb">
          <input class="concepto" name="concepto" placeholder="¿En qué gastaste?" maxlength="80" aria-label="Concepto">
          <input class="monto" name="monto" inputmode="decimal" placeholder="0" aria-label="Monto">
        </div>
        ${chips({ nombre: 'categoria', opciones: categoriasDisponibles(d.categorias), valor: ultimaCategoria })}
        <button type="submit" class="btn relleno ancho">Agregar</button>
      </form>

      <section class="tarjeta vidrio">
        <div class="flex-entre"><h2 style="margin:0">Esta semana</h2><span class="sec peq num">${esc(dinero(totalSemana))}</span></div>
        <div class="semana">${columnas}</div>
      </section>

      <section class="tarjeta vidrio tarjeta-lista">
        <div class="flex-entre" style="padding:10px 12px 4px">
          <h2 style="margin:0">${esHoy ? 'Gastos de hoy' : 'Gastos del día'}</h2>
          <span class="sec peq">${gastosDia.length} ${gastosDia.length === 1 ? 'gasto' : 'gastos'}</span>
        </div>
        ${filas || estadoVacio('🧾', 'Sin gastos', esHoy ? 'Todavía no has registrado gastos hoy.' : 'No hay gastos registrados ese día.')}
      </section>
    </div>`;
}

// ---------- Navegación entre días ----------

acciones.diaAnterior = () => { dia = sumarDias(diaMostrado(), -1); renderizar(); };
acciones.diaSiguiente = () => {
  const siguiente = sumarDias(diaMostrado(), 1);
  if (siguiente.getTime() <= inicioDia(new Date()).getTime()) { dia = siguiente; renderizar(); }
};
acciones.elegirDia = (el) => {
  const f = deCampoFecha(el.dataset.fecha);
  if (f) { dia = inicioDia(f); renderizar(); }
};
cambios.diaElegido = (el) => {
  const f = deCampoFecha(el.value);
  if (f) { dia = inicioDia(f); renderizar(); }
};

// ---------- Agregar rápido ----------

envios.gastoRapido = (form) => {
  const d = D.datos();
  const v = leerCampos(form);
  let monto;
  try {
    monto = montoPositivo(v.monto);
  } catch (error) {
    toast(error.message);
    form.querySelector('[name="monto"]').focus();
    return;
  }
  const categoria = categoriaVisual(v.categoria, d.categorias);
  const concepto = textoLimpio(v.concepto, 80) || categoria.nombre;
  ultimaCategoria = categoria.id;
  D.cambiar((st) => {
    st.gastos.push({
      id: uuid(), concepto, monto, fecha: aIso(fechaNueva()), categoria: categoria.id, nota: ''
    });
  });
  toast('Gasto agregado');
};

acciones.gastoNuevo = () => formularioGasto(null);
acciones.gastoEditar = (el) => {
  const g = D.datos().gastos.find((x) => x.id === el.dataset.id);
  if (g) formularioGasto(g);
};

// ---------- Formulario de gasto ----------

function formularioGasto(g) {
  const d = D.datos();
  const nuevo = !g;
  const fecha = g ? aFecha(g.fecha) : fechaNueva();
  const categoriaActual = g ? categoriaVisual(g.categoria, d.categorias).id : ultimaCategoria;

  abrirHoja({
    titulo: nuevo ? 'Nuevo gasto' : 'Editar gasto',
    cuerpo: `
      ${campo({ nombre: 'concepto', etiqueta: 'Concepto', valor: g ? g.concepto : '', placeholder: 'Ej. Almuerzo', maxlength: 80 })}
      ${campoMonto({ nombre: 'monto', etiqueta: 'Monto', valor: g ? textoNumero(g.monto) : '' })}
      ${chips({ nombre: 'categoria', etiqueta: 'Categoría', opciones: categoriasDisponibles(d.categorias), valor: categoriaActual, envuelto: true })}
      ${campo({ nombre: 'fecha', etiqueta: 'Fecha y hora', tipo: 'datetime-local', valor: aCampoFechaHora(fecha) })}
      ${campoNota({ valor: g ? g.nota : '' })}
      ${nuevo ? '' : '<button type="button" class="btn peligro ancho" data-local="eliminar">Eliminar gasto</button>'}`,
    alGuardar: (cuerpo) => {
      const v = leerCampos(cuerpo);
      const monto = montoPositivo(v.monto);
      const f = deCampoFechaHora(v.fecha);
      if (!f) throw new Error('La fecha y la hora no son válidas.');
      if (f.getTime() > Date.now() + 5 * 60000) throw new Error('La fecha no puede ser futura.');
      const categoria = categoriaVisual(v.categoria, d.categorias);
      const concepto = textoLimpio(v.concepto, 80) || categoria.nombre;
      ultimaCategoria = categoria.id;
      dia = inicioDia(f); // antes de guardar, para que la lista ya muestre el día del gasto
      D.cambiar((st) => {
        if (nuevo) {
          st.gastos.push({
            id: uuid(), concepto, monto, fecha: aIso(f), categoria: categoria.id, nota: notaLimpia(v.nota)
          });
        } else {
          const x = st.gastos.find((y) => y.id === g.id);
          if (x) Object.assign(x, { concepto, monto, fecha: aIso(f), categoria: categoria.id, nota: notaLimpia(v.nota) });
        }
      });
      toast(nuevo ? 'Gasto agregado' : 'Cambios guardados');
    },
    alMontar: (hoja) => enlazarLocal(hoja, {
      eliminar: async () => {
        const ok = await confirmar({
          titulo: '¿Eliminar este gasto?', mensaje: `${g.concepto || 'Gasto'} · ${dinero(g.monto)}`, textoOk: 'Eliminar', peligro: true
        });
        if (!ok) return;
        D.cambiar((st) => { st.gastos = st.gastos.filter((y) => y.id !== g.id); });
        hoja.cerrar();
        toast('Gasto eliminado');
      }
    })
  });
}

// ---------- Presupuesto diario ----------

acciones.presupuestoDiario = () => {
  const actual = D.datos().presupuestoDiario;
  abrirHoja({
    titulo: 'Presupuesto diario',
    cuerpo: `
      <p class="sec peq" style="margin-top:0">Cuánto quieres gastar como máximo cada día. Con esto verás cuánto te queda. Deja en 0 para quitarlo.</p>
      ${campoMonto({ nombre: 'monto', etiqueta: 'Monto por día', valor: actual > 0 ? textoNumero(actual) : '' })}`,
    alGuardar: (cuerpo) => {
      const texto = leerCampos(cuerpo).monto;
      let valor = 0;
      if (String(texto).trim() !== '') {
        valor = parseNumero(texto);
        if (valor === null || valor < 0 || valor > 1e12) throw new Error('El monto no es válido.');
      }
      D.cambiar((st) => { st.presupuestoDiario = valor; });
      toast(valor > 0 ? 'Presupuesto guardado' : 'Presupuesto quitado');
    }
  });
};

// ---------- Totales ----------

acciones.totales = () => {
  let periodo = 'dia';
  const base = diaMostrado();

  function rango() {
    const y = base.getFullYear();
    if (periodo === 'dia') return { desde: base, hasta: sumarDias(base, 1), titulo: fechaLarga(base) };
    if (periodo === 'semana') {
      const desde = inicioSemana(base);
      const hasta = sumarDias(desde, 7);
      return { desde, hasta, titulo: `${fechaDiaMes(desde)} – ${fechaDiaMes(sumarDias(hasta, -1))}` };
    }
    if (periodo === 'mes') {
      const desde = inicioMes(base);
      return { desde, hasta: new Date(desde.getFullYear(), desde.getMonth() + 1, 1), titulo: nombreMes(desde) };
    }
    const desde = inicioAnio(base);
    return { desde, hasta: new Date(y + 1, 0, 1), titulo: String(y) };
  }

  function contenido() {
    const d = D.datos();
    const { desde, hasta, titulo: t } = rango();
    const lista = gastosEntre(d.gastos, desde, hasta);
    const total = sumar(lista);
    const grupos = agruparPorCategoria(lista, d.categorias);
    const finEfectivo = Math.min(hasta.getTime(), sumarDias(inicioDia(new Date()), 1).getTime());
    const diasTranscurridos = Math.max(Math.round((finEfectivo - desde.getTime()) / 86400000), 1);
    const opciones = [['dia', 'Día'], ['semana', 'Semana'], ['mes', 'Mes'], ['anio', 'Año']];

    const filas = grupos.map((f) => `
      <div class="fila" style="flex-wrap:wrap">
        ${iconoCirc(f.categoria.emoji, f.categoria.color, 'chico')}
        <div class="cuerpo">
          <div class="titulo">${esc(f.categoria.nombre)}</div>
          <div class="sub">${f.cantidad} ${f.cantidad === 1 ? 'gasto' : 'gastos'} · ${esc(porcentaje(f.porcentaje))}</div>
        </div>
        <span class="monto">${esc(dinero(f.total))}</span>
        <div style="flex-basis:100%">${barraProgreso(f.porcentaje, f.categoria.color, true)}</div>
      </div>`).join('');

    return `
      <div class="segmentos" role="tablist">
        ${opciones.map(([id, nombre]) => `<button type="button" role="tab" class="${id === periodo ? 'activo' : ''}" data-local="periodo" data-periodo="${id}">${nombre}</button>`).join('')}
      </div>
      <div class="tarjeta vidrio mb">
        <div class="sec peq">${esc(t)}</div>
        <div class="monto-grande">${esc(dinero(total))}</div>
        <div class="peq sec" style="margin-top:4px">
          ${lista.length} ${lista.length === 1 ? 'gasto' : 'gastos'}${periodo !== 'dia' && lista.length ? ` · promedio ${esc(dinero(total / diasTranscurridos))} por día` : ''}
        </div>
      </div>
      ${grupos.length ? `<div class="tarjeta vidrio tarjeta-lista"><h2 style="padding:8px 12px 0;margin:0">Por categoría</h2>${filas}</div>` : estadoVacio('📊', 'Sin gastos', 'No hay gastos en este período.')}`;
  }

  let hojaTotales;
  const ligar = (hoja) => enlazarLocal(hoja, {
    periodo: (boton) => { periodo = boton.dataset.periodo; hoja.poner(contenido()); }
  });
  hojaTotales = abrirHoja({ titulo: 'Totales', cuerpo: contenido(), alMontar: ligar });
  return hojaTotales;
};
