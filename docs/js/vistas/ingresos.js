// Pantalla «Ingresos»: fuentes de ingreso y cuánto aportan al mes.

import * as D from '../datos.js';
import {
  esc, uuid, aIso, aFecha, inicioMes, sumarMeses, aCampoFecha, deCampoFecha, textoNumero,
  dinero, fechaCorta
} from '../util.js';
import {
  TIPOS_INGRESO, FRECUENCIAS_INGRESO, tipoIngreso, frecuenciaIngreso, aporteMensual, gastosEntre, sumar
} from '../calculos.js';
import {
  acciones, toast, abrirHoja, confirmar, campo, campoMonto, campoNota, campoFecha, chips, leerCampos,
  iconoCirc, estadoVacio, icono
} from '../ui.js';
import { montoPositivo, textoLimpio, notaLimpia, enlazarLocal } from './comun.js';

export const titulo = 'Ingresos';

export function botones() {
  return `<button class="btn-icono vidrio" data-accion="ingresoNuevo" aria-label="Agregar ingreso">${icono('mas')}</button>`;
}

/** Cuánto sumaría en un año completo (los únicos solo cuentan si son de este año). */
function proyeccionAnual(lista) {
  const anio = new Date().getFullYear();
  return lista.reduce((acc, i) => {
    if (i.frecuencia === 'unico') return acc + (aFecha(i.fecha).getFullYear() === anio ? i.monto : 0);
    return acc + i.monto * frecuenciaIngreso(i.frecuencia).veces * 12;
  }, 0);
}

export function render() {
  const d = D.datos();
  const ahora = new Date();
  const lista = [...d.ingresos].sort((a, b) => b.monto - a.monto);
  const estimado = sumar(lista.map((i) => ({ monto: aporteMensual(i, ahora) })));
  const gastosMes = sumar(gastosEntre(d.gastos, inicioMes(ahora), inicioMes(sumarMeses(ahora, 1))));
  const diferencia = estimado - gastosMes;

  const filas = lista.map((i) => {
    const tipo = tipoIngreso(i.tipo);
    const frec = frecuenciaIngreso(i.frecuencia);
    const aporte = aporteMensual(i, ahora);
    const extra = i.frecuencia !== 'mensual' && i.frecuencia !== 'unico' ? `≈ ${dinero(aporte)} al mes` : '';
    return `
      <button type="button" class="fila fila-click" data-accion="ingresoEditar" data-id="${esc(i.id)}">
        ${iconoCirc(tipo.emoji, tipo.color)}
        <div class="cuerpo">
          <div class="titulo">${esc(i.fuente || tipo.nombre)}</div>
          <div class="sub">${esc(frec.nombre)} · ${esc(fechaCorta(i.fecha))}</div>
        </div>
        <div class="lado">
          <span class="monto">${esc(dinero(i.monto))}</span>
          ${extra ? `<span class="sub">${esc(extra)}</span>` : ''}
        </div>
      </button>`;
  }).join('');

  return `
    <div class="apilar">
      <section class="tarjeta vidrio">
        <div class="sec peq">Ingresos estimados este mes</div>
        <div class="monto-grande" style="color:var(--verde)">${esc(dinero(estimado))}</div>
        <div class="sep"></div>
        <table class="tabla">
          <tr><td class="sec">Gastos de este mes</td><td>${esc(dinero(gastosMes))}</td></tr>
          <tr><td class="sec">${diferencia >= 0 ? 'Te sobran (aprox.)' : 'Te faltan (aprox.)'}</td>
              <td style="color:${diferencia >= 0 ? 'var(--verde)' : 'var(--rojo)'}">${esc(dinero(Math.abs(diferencia)))}</td></tr>
          <tr><td class="sec">Proyección de este año</td><td>${esc(dinero(proyeccionAnual(lista)))}</td></tr>
        </table>
      </section>

      <section class="tarjeta vidrio tarjeta-lista">
        <div class="flex-entre" style="padding:10px 12px 4px">
          <h2 style="margin:0">Fuentes de ingreso</h2>
          <span class="sec peq">${lista.length}</span>
        </div>
        ${filas || estadoVacio('💵', 'Sin ingresos', 'Agrega tu salario u otras fuentes para ver cuánto entra cada mes.',
          '<button type="button" class="btn relleno" data-accion="ingresoNuevo">Agregar ingreso</button>')}
      </section>
      <p class="nota">Los valores son estimaciones: un ingreso semanal cuenta 52/12 veces al mes y uno anual, 1/12.</p>
    </div>`;
}

acciones.ingresoNuevo = () => formulario(null);
acciones.ingresoEditar = (el) => {
  const i = D.datos().ingresos.find((x) => x.id === el.dataset.id);
  if (i) formulario(i);
};

function formulario(i) {
  const nuevo = !i;
  abrirHoja({
    titulo: nuevo ? 'Nuevo ingreso' : 'Editar ingreso',
    cuerpo: `
      ${campo({ nombre: 'fuente', etiqueta: 'Fuente', valor: i ? i.fuente : '', placeholder: 'Ej. Salario, ventas', maxlength: 60 })}
      ${campoMonto({ nombre: 'monto', etiqueta: 'Monto', valor: i ? textoNumero(i.monto) : '' })}
      ${chips({ nombre: 'tipo', etiqueta: 'Tipo', opciones: TIPOS_INGRESO, valor: i ? tipoIngreso(i.tipo).id : 'salario', envuelto: true })}
      ${chips({ nombre: 'frecuencia', etiqueta: 'Cada cuánto llega', opciones: FRECUENCIAS_INGRESO.map((f) => ({ id: f.id, nombre: f.nombre })), valor: i ? frecuenciaIngreso(i.frecuencia).id : 'mensual', envuelto: true })}
      ${campoFecha({ nombre: 'fecha', etiqueta: 'Fecha', valor: aCampoFecha(i ? aFecha(i.fecha) : new Date()), ayuda: 'En un ingreso recurrente, es desde cuándo empieza a contar.' })}
      ${campoNota({ valor: i ? i.nota : '' })}
      ${nuevo ? '' : '<button type="button" class="btn peligro ancho" data-local="eliminar">Eliminar ingreso</button>'}`,
    alGuardar: (cuerpo) => {
      const v = leerCampos(cuerpo);
      const monto = montoPositivo(v.monto);
      const fecha = deCampoFecha(v.fecha);
      if (!fecha) throw new Error('La fecha no es válida.');
      const tipo = tipoIngreso(v.tipo);
      const datos = {
        fuente: textoLimpio(v.fuente, 60) || tipo.nombre,
        monto,
        tipo: tipo.id,
        frecuencia: frecuenciaIngreso(v.frecuencia).id,
        fecha: aIso(fecha),
        nota: notaLimpia(v.nota)
      };
      D.cambiar((st) => {
        if (nuevo) st.ingresos.push({ id: uuid(), ...datos });
        else {
          const x = st.ingresos.find((y) => y.id === i.id);
          if (x) Object.assign(x, datos);
        }
      });
      toast(nuevo ? 'Ingreso agregado' : 'Cambios guardados');
    },
    alMontar: (hoja) => enlazarLocal(hoja, {
      eliminar: async () => {
        const ok = await confirmar({
          titulo: '¿Eliminar este ingreso?', mensaje: `${i.fuente || 'Ingreso'} · ${dinero(i.monto)}`, textoOk: 'Eliminar', peligro: true
        });
        if (!ok) return;
        D.cambiar((st) => { st.ingresos = st.ingresos.filter((y) => y.id !== i.id); });
        hoja.cerrar();
        toast('Ingreso eliminado');
      }
    })
  });
}
