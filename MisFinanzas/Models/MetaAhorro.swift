import Foundation
import SwiftData

/// Una meta de ahorro (fondo de emergencia, viaje, laptop...).
///
/// Igual que en las deudas, el monto ahorrado se calcula sumando los movimientos
/// (aportes positivos y retiros negativos). Esto garantiza que el historial y el
/// saldo siempre coincidan, y que al borrar un movimiento el saldo se revierta solo.
@Model
final class MetaAhorro {
    var nombre: String
    var montoObjetivo: Double
    var iconoSistema: String
    var paletaRaw: String
    var fechaObjetivo: Date?
    var fechaCreacion: Date

    @Relationship(deleteRule: .cascade, inverse: \MovimientoMeta.meta)
    var movimientos: [MovimientoMeta] = []

    init(nombre: String,
         montoObjetivo: Double,
         iconoSistema: String = "target",
         paleta: PaletaColor = .azul,
         fechaObjetivo: Date? = nil,
         fechaCreacion: Date = .now) {
        self.nombre = nombre
        self.montoObjetivo = montoObjetivo
        self.iconoSistema = iconoSistema
        self.paletaRaw = paleta.rawValue
        self.fechaObjetivo = fechaObjetivo
        self.fechaCreacion = fechaCreacion
    }

    var paleta: PaletaColor {
        get { PaletaColor(rawValue: paletaRaw) ?? .azul }
        set { paletaRaw = newValue.rawValue }
    }

    // MARK: Cálculos

    var montoAhorrado: Double { movimientos.reduce(0) { $0 + $1.monto } }

    /// Avance entre 0 y 1 (se limita a 100 % para la barra).
    var progreso: Double {
        guard montoObjetivo > 0 else { return 0 }
        return min(max(montoAhorrado / montoObjetivo, 0), 1)
    }

    var faltante: Double { max(montoObjetivo - montoAhorrado, 0) }

    var estaCumplida: Bool { montoObjetivo > 0 && montoAhorrado >= montoObjetivo }

    var movimientosOrdenados: [MovimientoMeta] { movimientos.sorted { $0.fecha > $1.fecha } }

    /// Meses que faltan para la fecha objetivo (mínimo 1). Nil si no hay fecha o ya pasó.
    var mesesRestantes: Int? {
        guard let fecha = fechaObjetivo, fecha > Date.now else { return nil }
        let dias = fecha.timeIntervalSinceNow / 86_400
        return max(Int((dias / 30.4375).rounded(.up)), 1)
    }

    /// Cuánto aportar cada mes para llegar a la meta a tiempo (estimación sencilla,
    /// sin intereses). Nil si no hay fecha futura o si la meta ya se cumplió.
    var aporteMensualSugerido: Double? {
        guard !estaCumplida, faltante > 0, let meses = mesesRestantes else { return nil }
        return faltante / Double(meses)
    }

    /// Hay fecha objetivo, ya pasó y la meta todavía no se cumple.
    var fechaVencida: Bool {
        guard let fecha = fechaObjetivo else { return false }
        return fecha <= Date.now && !estaCumplida
    }

    // MARK: Operaciones

    /// Registra un movimiento: monto positivo = aporte, negativo = retiro.
    func registrar(_ monto: Double, nota: String = "", fecha: Date = .now, en contexto: ModelContext) {
        let movimiento = MovimientoMeta(monto: monto, fecha: fecha, nota: nota)
        contexto.insert(movimiento)
        movimiento.meta = self
    }
}

/// Un aporte (monto > 0) o retiro (monto < 0) de una meta de ahorro.
@Model
final class MovimientoMeta {
    var monto: Double
    var fecha: Date
    var nota: String
    var meta: MetaAhorro?

    init(monto: Double, fecha: Date = .now, nota: String = "") {
        self.monto = monto
        self.fecha = fecha
        self.nota = nota
    }

    var esAporte: Bool { monto >= 0 }
}
