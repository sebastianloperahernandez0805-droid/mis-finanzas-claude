import Foundation
import SwiftData

/// Una categoría de gasto creada por el usuario (además de las predeterminadas).
///
/// Cada gasto guarda en `Gasto.categoriaRaw` la `clave` de su categoría: el nombre interno
/// de una predeterminada («comida») o la `clave` de una personalizada («personalizada:UUID»).
/// Todas las propiedades tienen valor por defecto para que SwiftData pueda migrar el esquema solo.
@Model
final class CategoriaPersonalizada {
    /// Identificador estable que se guarda en los gastos. No cambia aunque se renombre la categoría.
    var clave: String = ""
    var nombre: String = ""
    var iconoSistema: String = "tag.fill"
    var paletaRaw: String = "azul"
    var fechaCreacion: Date = Date.now

    init(nombre: String, iconoSistema: String = "tag.fill", paleta: PaletaColor = .azul) {
        self.clave = "personalizada:" + UUID().uuidString
        self.nombre = nombre
        self.iconoSistema = iconoSistema
        self.paletaRaw = paleta.rawValue
        self.fechaCreacion = Date.now
    }

    var paleta: PaletaColor {
        get { PaletaColor(rawValue: paletaRaw) ?? .azul }
        set { paletaRaw = newValue.rawValue }
    }
}
