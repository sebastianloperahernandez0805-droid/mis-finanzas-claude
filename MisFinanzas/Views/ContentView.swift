import SwiftUI
import SwiftData

/// Navegación principal: una pestaña por módulo.
struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Hoy", systemImage: "sun.max.fill") }

            IngresosView()
                .tabItem { Label("Ingresos", systemImage: "arrow.down.circle.fill") }

            PagosFijosView()
                .tabItem { Label("Fijos", systemImage: "calendar.badge.clock") }

            DeudasView()
                .tabItem { Label("Deudas", systemImage: "creditcard.fill") }

            MetasView()
                .tabItem { Label("Metas", systemImage: "target") }
        }
        .tint(Tema.acento)
    }
}

#Preview {
    ContentView()
        .modelContainer(DatosEjemplo.contenedor)
}

#Preview("Modo oscuro") {
    ContentView()
        .modelContainer(DatosEjemplo.contenedor)
        .preferredColorScheme(.dark)
}
