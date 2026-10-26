# Mivra web (Android y iPhone)

Versión de Mivra que se abre en el navegador y se instala como app. Vive en la carpeta `docs/` y se publica con **GitHub Pages**.

Dirección: https://sebastianloperahernandez0805-droid.github.io/mis-finanzas-claude/

## Activar la publicación (una sola vez)

1. En GitHub, entra al repositorio ▸ **Settings** ▸ **Pages**.
2. En *Build and deployment*, **Source = Deploy from a branch**.
3. **Branch = main** y carpeta **/docs** ▸ **Save**.
4. En uno o dos minutos la dirección de arriba queda activa.

## Cómo funciona la cuenta

- Al abrir por primera vez se crea un **usuario y contraseña**. Para entrar se piden siempre (salvo que marques «Mantener la sesión iniciada»).
- **No hay servidor.** El usuario y la contraseña existen solo en ese dispositivo y los datos se guardan **cifrados** con la contraseña (AES-GCM de 256 bits; la clave sale de la contraseña con PBKDF2, 310 000 iteraciones).
- **Si se olvida la contraseña no se puede recuperar** ni los datos. Por eso existe la copia de seguridad (Ajustes ▸ Guardar copia).
- Cada dispositivo tiene sus propios datos: el teléfono y el computador no se sincronizan solos. Se pasan datos con una copia de seguridad.
- Las copias sirven entre la web y la app de iPhone: la hecha en una se abre en la otra (Ajustes ▸ Abrir copia).

## Instalar en el teléfono

- **Android (Chrome):** menú ⋮ ▸ *Instalar app*.
- **iPhone (Safari):** Compartir ▸ *Agregar a pantalla de inicio*. Crea la cuenta **desde la app instalada**: en iPhone la app instalada guarda sus datos aparte de Safari.

## Qué incluye

Hoy (gastos del día, presupuesto diario, semana y totales), Ingresos, Pagos fijos, Deudas, Metas y Ajustes (moneda, copia de seguridad, cambiar contraseña, cerrar sesión, borrar cuenta). Funciona sin internet una vez abierta.

Todavía no tiene (sí están en la app de iPhone): cuentas con saldos, presupuestos por categoría, tendencias, gastos automáticos y exportar a Excel. Si una copia del iPhone los trae, se conservan intactos al volver a guardarla.

## Para quien edite el código

- Sin compilación ni librerías externas: HTML + CSS + módulos JavaScript en `docs/`.
- Los datos tienen el mismo formato que la copia de seguridad del iPhone (`formato "MisFinanzas"`, versión 1).
- El service worker (`docs/sw.js`) usa red primero y caché de respaldo. Si se agrega un archivo `.js` nuevo, hay que añadirlo a su lista `ARCHIVOS`.
- Los cambios en `docs/` no lanzan la compilación de la app de iPhone.
