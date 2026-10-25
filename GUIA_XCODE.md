# Mivra — guía para montar el proyecto en Xcode

App de finanzas personales para iPhone, en **Swift + SwiftUI + SwiftData**, 100 % offline.
Requisitos: **Xcode 15 o superior** y **iOS 17+** como versión mínima (SwiftData y `@Query` lo exigen).

---

## 1. Crear el proyecto

1. Xcode → **File ▸ New ▸ Project… ▸ iOS ▸ App**.
2. Datos del proyecto:
   - **Product Name:** `MisFinanzas`
   - **Interface:** SwiftUI
   - **Language:** Swift
   - **Storage:** *None* (el contenedor de SwiftData se crea a mano en `MisFinanzasApp.swift`)
   - Desmarca *Include Tests* si no los vas a usar.
3. Borra los archivos que genera Xcode: `MisFinanzasApp.swift` y `ContentView.swift` (los reemplazan los de esta carpeta).

## 2. Configurar el target (solo iPhone, offline)

En el target `MisFinanzas` ▸ pestaña **General**:

- **Minimum Deployments:** iOS 17.0
- **Supported Destinations:** deja solo **iPhone** (quita iPad y Mac).
- **Device Orientation:** marca solo **Portrait** (opcional, recomendado).

No hace falta ninguna capability: **no actives iCloud ni Push**. La app no usa red, no pide permisos y no necesita cambios en `Info.plist`.

## 3. Estructura de carpetas

Crea estos *groups* (clic derecho ▸ New Group) y arrastra los archivos de cada carpeta de esta entrega:

```
MisFinanzas/
├── MisFinanzasApp.swift          ← punto de entrada + contenedor SwiftData
├── Models/                       ← Esquema de datos (SwiftData)
│   ├── Enums.swift               ← categorías, tipos, frecuencias, colores
│   ├── Gasto.swift
│   ├── Ingreso.swift
│   ├── PagoFijo.swift
│   ├── Deuda.swift               ← Deuda + AbonoDeuda
│   └── MetaAhorro.swift          ← MetaAhorro + MovimientoMeta
├── Utilities/
│   ├── Tema.swift                ← colores, estilo de tarjeta, diálogo de borrado
│   ├── Formato.swift             ← moneda, porcentajes, lectura de números
│   └── DatosEjemplo.swift        ← datos solo para las vistas previas
├── Components/                   ← piezas visuales reutilizables
│   ├── BarraProgreso.swift
│   ├── AnilloProgreso.swift
│   ├── IconoCirculo.swift
│   ├── TarjetaResumen.swift
│   ├── BotonAccion.swift
│   ├── ChipEstado.swift
│   ├── EstadoVacio.swift
│   ├── CampoMonto.swift
│   └── SelectoresVisuales.swift  ← chips, selector de color y de ícono
└── Views/
    ├── ContentView.swift         ← TabView con los 5 módulos
    ├── Dashboard/                ← Hoy: gastos del día
    ├── Ingresos/
    ├── PagosFijos/
    ├── Deudas/
    └── Metas/
```

Al arrastrar los archivos, marca **Copy items if needed** y que el target `MisFinanzas` esté seleccionado.

## 4. Compilar y probar

1. Elige un simulador de iPhone (iOS 17+) y pulsa **⌘R**.
2. Para ver el diseño sin ejecutar la app, abre cualquier vista y usa el **Canvas (⌥⌘↩)**: todas las pantallas tienen `#Preview` con datos de ejemplo. `ContentView` incluye una vista previa en **Modo Oscuro**.
3. Para alternar Claro/Oscuro en el simulador: *Settings ▸ Developer ▸ Dark Appearance*.

---

## Cómo funciona (resumen para entender el código)

**Datos.** Todo se guarda en el iPhone con SwiftData. En `MisFinanzasApp.swift` el contenedor se crea con `cloudKitDatabase: .none`, así que nunca sale nada del dispositivo. El único dato fuera de SwiftData es el presupuesto diario, que vive en `UserDefaults` (`@AppStorage`), también local.

**CRUD.** Cada módulo tiene su lista y un formulario modal que sirve para crear y editar (si recibe un objeto, edita; si no, crea). Para borrar: deslizar la fila a la izquierda, mantener pulsada la tarjeta, o el botón *Eliminar* dentro del formulario. SwiftData guarda solo, no hay que llamar a `save()`.

**Valores calculados en lugar de guardados.** Para que nada se desincronice:
- Saldo de una deuda = monto total − suma de sus abonos.
- Ahorrado de una meta = suma de sus aportes (positivos) y retiros (negativos).
- «Pagado / Pendiente» de un pago fijo se calcula con la fecha del último pago y el mes actual; por eso se reinicia solo al cambiar de mes.
- Ingreso mensual estimado = cada ingreso convertido a su equivalente mensual según la frecuencia.

**Diseño.** Colores semánticos del sistema (`systemGroupedBackground`, etc.), tarjetas de 20 pt con esquinas continuas, SF Symbols en todo, animaciones de resorte en barras y anillos, y números que cambian con `contentTransition(.numericText())`. Modo Claro/Oscuro es automático.

**Moneda.** Se toma de la región del iPhone (en Colombia aparecerá en COP). Para fijar una moneda concreta, cambia `codigoMoneda` en `Formato.swift`.

## Funciones extra (menú «Más» de la pestaña Hoy)

El botón con tres puntos (arriba a la izquierda en *Hoy*) abre estas pantallas:

- **Resumen del mes**: ingresos, gastos, pagos fijos (pagados y pendientes), abonos a deudas y lo apartado en metas; al final, cuánto te queda. Compara contra el mes anterior y, si registraste depósitos, muestra los ingresos recibidos frente a los estimados.
- **Cuentas y saldos**: efectivo, banco, Nequi, ahorros... Cada una tiene saldo inicial, depósitos, transferencias entre cuentas y «Ajustar saldo». Al registrar un gasto, pago fijo, abono, aporte a meta o gasto automático puedes elegir la cuenta, y su saldo se calcula solo. En *Ingresos*, desliza una fuente hacia la derecha («Lo recibí») para depositar lo que de verdad llegó.
- **Tendencias**: barras de los últimos 12 meses (gastos, pagos fijos y deudas) y dona de gastos del mes por categoría.
- **Presupuestos**: un límite mensual por categoría, con barra que se pone naranja al 80 % y roja al pasarte.
- **Gastos automáticos**: gastos que se repiten cada semana o cada mes (transporte, mercado). Se crean solos al abrir la app.
- **Buscar gastos**: por concepto, nota, categoría o monto exacto, con filtro por categoría.
- **Categorías**: crea las tuyas (nombre, color e ícono). Al borrar una, sus gastos pasan a «Otros».
- **Recordatorios y avisos**: avisos locales a las 9:00 a. m. de pagos fijos pendientes y deudas con día de pago o fecha límite, y un aviso opcional al llegar al 80 % de un presupuesto o pasarte. Se reprograman al abrir la app y al cambiar datos.
- **Copia de seguridad y Excel**: exporta todo a un archivo `.json` (compartir o guardar en Archivos) y restaura desde él; también crea un `.csv` con tus movimientos para abrirlo en Excel. Restaurar reemplaza los datos actuales.
- **Acerca de Mivra**: versión, resumen de privacidad y aviso de que las cifras son estimaciones.

Además: cada pago fijo tiene un **historial mes por mes** (mantén pulsada la fila o ábrelo desde el formulario), las deudas aceptan **interés anual, número de cuotas y día de pago**, con cuota e interés mensual estimados, y las metas con fecha objetivo muestran **cuánto aportar al mes** para llegar a tiempo.

**Datos nuevos.** `CategoriaPersonalizada`, `PresupuestoCategoria` y `PagoRealizado` son modelos nuevos; `Deuda` ganó `tasaInteresAnual`, `numeroCuotas` y `diaPago`, y `PagoFijo` ganó `historial`. Todos tienen valores por defecto, así que SwiftData migra la base existente sin perder nada. Después se sumaron `GastoRecurrente`, `Cuenta` y `MovimientoCuenta` (modelos nuevos) y la propiedad opcional `cuentaId` en `Gasto`, `PagoRealizado`, `AbonoDeuda`, `MovimientoMeta`, `PagoFijo` y `GastoRecurrente`. El saldo de una cuenta no se guarda: se calcula con lo asignado a ella. Regla para el futuro: nunca renombrar ni borrar propiedades ya guardadas; solo agregar con valor por defecto.

**Para la App Store.** El proyecto ya incluye `PrivacyInfo.xcprivacy` (sin rastreo ni datos recopilados; declara el uso de `UserDefaults`) y la clave `ITSAppUsesNonExemptEncryption = NO`. Faltan, entre otros, la política de privacidad publicada en una URL, el programa de Apple Developer (de pago), capturas de pantalla y la firma con tu propio certificado. Dejar la base de datos versionada (`VersionedSchema`) para cuando haya un cambio que SwiftData no pueda migrar solo: hacerlo ahora, con datos ya guardados en el teléfono, sería más riesgoso que útil.

---

## Ideas para siguientes versiones

- Registrar automáticamente un gasto al marcar un pago fijo como pagado.
- Traducción al inglés.
- Bloqueo con Face ID o código (se dejó fuera a pedido).
