import SwiftUI
import SwiftData
import UserNotifications

/// Punto de entrada de la app.
///
/// Crea el contenedor de SwiftData con todos los modelos y lo inyecta en el entorno,
/// de modo que cualquier vista pueda usar `@Query` y `@Environment(\.modelContext)`.
/// `cloudKitDatabase: .none` garantiza que los datos viven SOLO en el iPhone:
/// sin servidores, sin iCloud, 100% offline.
@main
struct MisFinanzasApp: App {

    private let contenedor: ModelContainer = {
        let esquema = Schema([
            Gasto.self,
            Ingreso.self,
            PagoFijo.self,
            Deuda.self,
            AbonoDeuda.self,
            MetaAhorro.self,
            MovimientoMeta.self,
            CategoriaPersonalizada.self,
            PresupuestoCategoria.self,
            PagoRealizado.self
        ])
        let configuracion = ModelConfiguration(
            schema: esquema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: esquema, configurations: [configuracion])
        } catch {
            fatalError("No se pudo crear el almacenamiento local: \(error)")
        }
    }()

    init() {
        // Permite que los recordatorios también se vean cuando la app está abierta.
        UNUserNotificationCenter.current().delegate = DelegadoNotificaciones.compartido
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(contenedor)
    }
}
