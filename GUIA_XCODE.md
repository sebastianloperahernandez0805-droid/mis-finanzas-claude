# Mis Finanzas — guía para montar el proyecto en Xcode

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

## Ideas para siguientes versiones

- Registrar automáticamente un gasto al marcar un pago fijo como pagado.
- Notificaciones locales (no requieren servidor) para recordar vencimientos.
- Resumen mensual con gráfico por categoría.
- Exportar los datos a CSV desde la propia app.
