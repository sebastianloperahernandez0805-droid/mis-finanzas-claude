import SwiftUI

// MARK: - Protocolo común

/// Cualquier opción que se pueda mostrar como "chip" (ícono SF Symbol + nombre + color).
/// Lo usan las categorías y tipos para poder reutilizar el mismo selector visual.
protocol OpcionVisual: Identifiable, Hashable {
    var nombre: String { get }
    var icono: String { get }
    var color: Color { get }
}

// MARK: - Gastos

enum CategoriaGasto: String, CaseIterable, OpcionVisual {
    case comida, transporte, hogar, salud, ocio, compras, educacion, otros

    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .comida: "Comida"
        case .transporte: "Transporte"
        case .hogar: "Hogar"
        case .salud: "Salud"
        case .ocio: "Ocio"
        case .compras: "Compras"
        case .educacion: "Educación"
        case .otros: "Otros"
        }
    }

    var icono: String {
        switch self {
        case .comida: "fork.knife"
        case .transporte: "bus.fill"
        case .hogar: "house.fill"
        case .salud: "cross.case.fill"
        case .ocio: "popcorn.fill"
        case .compras: "bag.fill"
        case .educacion: "book.fill"
        case .otros: "ellipsis.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .comida: .orange
        case .transporte: .blue
        case .hogar: .brown
        case .salud: .red
        case .ocio: .pink
        case .compras: .purple
        case .educacion: .teal
        case .otros: .gray
        }
    }
}

// MARK: - Ingresos

enum TipoIngreso: String, CaseIterable, OpcionVisual {
    case salario, extra, ventas, inversion, otros

    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .salario: "Salario"
        case .extra: "Ingreso extra"
        case .ventas: "Ventas"
        case .inversion: "Inversiones"
        case .otros: "Otros"
        }
    }

    var icono: String {
        switch self {
        case .salario: "banknote.fill"
        case .extra: "plus.circle.fill"
        case .ventas: "cart.fill"
        case .inversion: "chart.line.uptrend.xyaxis"
        case .otros: "ellipsis.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .salario: .green
        case .extra: .mint
        case .ventas: .orange
        case .inversion: .indigo
        case .otros: .gray
        }
    }
}

enum FrecuenciaIngreso: String, CaseIterable, Identifiable {
    case unico, semanal, quincenal, mensual, anual

    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .unico: "Único"
        case .semanal: "Semanal"
        case .quincenal: "Quincenal"
        case .mensual: "Mensual"
        case .anual: "Anual"
        }
    }

    /// Cuántas veces equivale al mes. Sirve para estimar el ingreso mensual total.
    var vecesPorMes: Double {
        switch self {
        case .unico: 0          // se trata aparte: cuenta solo en el mes en que se recibió
        case .semanal: 52.0 / 12.0
        case .quincenal: 2
        case .mensual: 1
        case .anual: 1.0 / 12.0
        }
    }
}

// MARK: - Pagos fijos

enum CategoriaPagoFijo: String, CaseIterable, OpcionVisual {
    case suscripcion, servicios, arriendo, seguro, educacion, otro

    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .suscripcion: "Suscripción"
        case .servicios: "Servicios"
        case .arriendo: "Arriendo"
        case .seguro: "Seguro"
        case .educacion: "Educación"
        case .otro: "Otro"
        }
    }

    var icono: String {
        switch self {
        case .suscripcion: "play.rectangle.fill"
        case .servicios: "bolt.fill"
        case .arriendo: "house.fill"
        case .seguro: "shield.fill"
        case .educacion: "graduationcap.fill"
        case .otro: "ellipsis.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .suscripcion: .pink
        case .servicios: .yellow
        case .arriendo: .brown
        case .seguro: .blue
        case .educacion: .teal
        case .otro: .gray
        }
    }
}

/// Estado de un pago fijo en el mes actual.
enum EstadoPago {
    case pagado, pendiente, vencido

    var nombre: String {
        switch self {
        case .pagado: "Pagado"
        case .pendiente: "Pendiente"
        case .vencido: "Vencido"
        }
    }

    var icono: String {
        switch self {
        case .pagado: "checkmark.circle.fill"
        case .pendiente: "clock.fill"
        case .vencido: "exclamationmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .pagado: .green
        case .pendiente: .orange
        case .vencido: .red
        }
    }
}

// MARK: - Deudas

enum TipoDeuda: String, CaseIterable, OpcionVisual {
    case prestamo, tarjeta, persona, otra

    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .prestamo: "Préstamo"
        case .tarjeta: "Tarjeta de crédito"
        case .persona: "Deuda a persona"
        case .otra: "Otra"
        }
    }

    var icono: String {
        switch self {
        case .prestamo: "building.columns.fill"
        case .tarjeta: "creditcard.fill"
        case .persona: "person.2.fill"
        case .otra: "doc.text.fill"
        }
    }

    var color: Color {
        switch self {
        case .prestamo: .orange
        case .tarjeta: .red
        case .persona: .indigo
        case .otra: .gray
        }
    }
}

// MARK: - Metas de ahorro

/// Paleta de colores para personalizar cada meta. Se guarda como texto (rawValue) en SwiftData.
enum PaletaColor: String, CaseIterable, Identifiable {
    case azul, verde, naranja, morado, rosa, turquesa, rojo

    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .azul: "Azul"
        case .verde: "Verde"
        case .naranja: "Naranja"
        case .morado: "Morado"
        case .rosa: "Rosa"
        case .turquesa: "Turquesa"
        case .rojo: "Rojo"
        }
    }

    var color: Color {
        switch self {
        case .azul: .blue
        case .verde: .green
        case .naranja: .orange
        case .morado: .purple
        case .rosa: .pink
        case .turquesa: .teal
        case .rojo: .red
        }
    }
}

/// Íconos (SF Symbols) disponibles al crear una meta.
enum IconosMeta {
    static let todos: [String] = [
        "shield.fill", "airplane", "laptopcomputer", "house.fill",
        "car.fill", "graduationcap.fill", "gift.fill", "heart.fill",
        "camera.fill", "gamecontroller.fill", "bicycle", "briefcase.fill"
    ]
}

enum TipoMovimientoMeta {
    case aporte, retiro

    var titulo: String { self == .aporte ? "Aportar" : "Retirar" }
    var icono: String { self == .aporte ? "plus.circle.fill" : "minus.circle.fill" }
}
