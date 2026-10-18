import Foundation
import SwiftData

/// Un gasto individual (aparece en el resumen diario).
///
/// Nota: la categoría se guarda como `String` (`categoriaRaw`) y se expone como enum
/// mediante `categoria`. Es la forma más estable con SwiftData: permite migrar el
/// esquema sin dolores de cabeza si algún día se agregan categorías nuevas.
@Model
final class Gasto {
    var concepto: String
    var monto: Double
    var fecha: Date
    var categoriaRaw: String
    var nota: String

    init(concepto: String,
         monto: Double,
         fecha: Date = .now,
         categoria: CategoriaGasto = .otros,
         nota: String = "") {
        self.concepto = concepto
        self.monto = monto
        self.fecha = fecha
        self.categoriaRaw = categoria.rawValue
        self.nota = nota
    }

    var categoria: CategoriaGasto {
        get { CategoriaGasto(rawValue: categoriaRaw) ?? .otros }
        set { categoriaRaw = newValue.rawValue }
    }
}
