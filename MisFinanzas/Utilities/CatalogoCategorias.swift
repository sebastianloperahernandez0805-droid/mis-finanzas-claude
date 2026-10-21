import SwiftUI

/// Una categoría lista para mostrarse: puede venir de las predeterminadas (`CategoriaGasto`)
/// o de las que creó el usuario (`CategoriaPersonalizada`). Así el resto de la app trata a las
/// dos igual (chips, filas, barras).
struct CategoriaVisual: OpcionVisual {
    /// Es la `clave` que se guarda en cada gasto: «comida» o «personalizada:UUID».
    let id: String
    let nombre: String
    let icono: String
    let color: Color
    let esPersonalizada: Bool

    static func == (izquierda: CategoriaVisual, derecha: CategoriaVisual) -> Bool {
        izquierda.id == derecha.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Busca categorías por su clave y arma la lista completa (predeterminadas + personalizadas).
enum CatalogoCategorias {

    static func visual(de categoria: CategoriaGasto) -> CategoriaVisual {
        CategoriaVisual(id: categoria.rawValue, nombre: categoria.nombre, icono: categoria.icono,
                        color: categoria.color, esPersonalizada: false)
    }

    static func visual(de categoria: CategoriaPersonalizada) -> CategoriaVisual {
        CategoriaVisual(id: categoria.clave, nombre: categoria.nombre, icono: categoria.iconoSistema,
                        color: categoria.paleta.color, esPersonalizada: true)
    }

    /// Las predeterminadas primero y luego las personalizadas, en el orden en que se crearon.
    static func todas(_ personalizadas: [CategoriaPersonalizada]) -> [CategoriaVisual] {
        let propias = personalizadas
            .sorted { $0.fechaCreacion < $1.fechaCreacion }
            .map { visual(de: $0) }
        return CategoriaGasto.allCases.map { visual(de: $0) } + propias
    }

    /// Categoría que corresponde a una clave. Si la clave ya no existe (por ejemplo, una categoría
    /// borrada), se muestra como «Otros» para que ningún gasto quede sin categoría visible.
    static func visual(para clave: String, _ personalizadas: [CategoriaPersonalizada]) -> CategoriaVisual {
        if let predeterminada = CategoriaGasto(rawValue: clave) {
            return visual(de: predeterminada)
        }
        if let propia = personalizadas.first(where: { $0.clave == clave }) {
            return visual(de: propia)
        }
        return visual(de: .otros)
    }
}

/// Íconos (SF Symbols) entre los que se puede elegir al crear una categoría propia.
enum IconosCategoria {
    static let todos: [String] = [
        "tag.fill", "pawprint.fill", "gift.fill", "car.fill",
        "fuelpump.fill", "cart.fill", "tshirt.fill", "scissors",
        "wrench.and.screwdriver.fill", "gamecontroller.fill", "music.note", "airplane",
        "figure.run", "heart.fill", "leaf.fill", "drop.fill"
    ]
}
