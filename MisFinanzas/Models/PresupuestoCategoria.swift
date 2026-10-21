import Foundation
import SwiftData

/// Presupuesto mensual de una categoría de gasto (predeterminada o personalizada).
@Model
final class PresupuestoCategoria {
    /// Clave de la categoría (ver `CategoriaPersonalizada.clave`).
    var claveCategoria: String = ""
    var montoMensual: Double = 0

    init(claveCategoria: String, montoMensual: Double) {
        self.claveCategoria = claveCategoria
        self.montoMensual = montoMensual
    }
}
