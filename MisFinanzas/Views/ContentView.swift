import SwiftUI
import SwiftData

/// Navegación principal: una pestaña por módulo.
struct ContentView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.scenePhase) private var faseEscena

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
        .barraDePestanasLiquida()
        // Los recordatorios se vuelven a programar al abrir la app y cada vez que vuelve a primer plano.
        // También se crean los gastos automáticos que ya tocaban.
        .task {
            GeneradorRecurrentes.generar(en: contexto)
            Recordatorios.actualizar(contexto: contexto)
        }
        .onChange(of: faseEscena) { _, nueva in
            if nueva == .active {
                GeneradorRecurrentes.generar(en: contexto)
                Recordatorios.actualizar(contexto: contexto)
            }
        }
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
