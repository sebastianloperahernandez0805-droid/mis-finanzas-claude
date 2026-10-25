import SwiftUI

/// Las pantallas extra que se abren desde el menú «Más» de la pestaña Hoy.
enum PantallaExtra: String, Identifiable, CaseIterable {
    case resumenMes, tendencias, presupuestos, buscar, categorias, recordatorios, respaldo, acerca

    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .resumenMes: "Resumen del mes"
        case .tendencias: "Tendencias"
        case .presupuestos: "Presupuestos"
        case .buscar: "Buscar gastos"
        case .categorias: "Categorías"
        case .recordatorios: "Recordatorios y avisos"
        case .respaldo: "Copia de seguridad y Excel"
        case .acerca: "Acerca de Mivra"
        }
    }

    var icono: String {
        switch self {
        case .resumenMes: "chart.bar.doc.horizontal"
        case .tendencias: "chart.xyaxis.line"
        case .presupuestos: "chart.pie"
        case .buscar: "magnifyingglass"
        case .categorias: "tag"
        case .recordatorios: "bell"
        case .respaldo: "externaldrive"
        case .acerca: "info.circle"
        }
    }
}

/// Muestra la pantalla que corresponde a cada opción del menú.
struct PantallaExtraView: View {
    let pantalla: PantallaExtra

    var body: some View {
        switch pantalla {
        case .resumenMes: ResumenMesView()
        case .tendencias: TendenciasView()
        case .presupuestos: PresupuestosView()
        case .buscar: BuscarGastosView()
        case .categorias: CategoriasView()
        case .recordatorios: RecordatoriosView()
        case .respaldo: RespaldoView()
        case .acerca: AcercaDeView()
        }
    }
}
