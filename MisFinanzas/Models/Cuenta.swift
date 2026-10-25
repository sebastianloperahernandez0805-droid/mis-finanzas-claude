import SwiftUI
import SwiftData

// MARK: - Tipos

/// Dónde tienes tu plata: efectivo, banco, billetera digital (Nequi, Daviplata...) o ahorros.
enum TipoCuenta: String, CaseIterable, OpcionVisual {
    case efectivo, banco, digital, ahorros

    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .efectivo: "Efectivo"
        case .banco: "Banco"
        case .digital: "Billetera digital"
        case .ahorros: "Ahorros"
        }
    }

    var icono: String {
        switch self {
        case .efectivo: "banknote.fill"
        case .banco: "building.columns.fill"
        case .digital: "iphone"
        case .ahorros: "lock.fill"
        }
    }

    var color: Color {
        switch self {
        case .efectivo: .green
        case .banco: .blue
        case .digital: .purple
        case .ahorros: .teal
        }
    }
}

enum TipoMovimientoCuenta: String {
    case ingreso, transferencia, ajuste
}

// MARK: - Cuenta

/// Una cuenta o bolsillo de dinero.
///
/// Igual que las deudas y las metas, el saldo NO se guarda: se calcula como
/// `saldo inicial + depósitos/transferencias/ajustes - gastos - pagos - abonos - aportes a metas`
/// de lo que esté asignado a la cuenta. Así siempre coincide con el historial.
/// Todas las propiedades tienen valor por defecto para que SwiftData pueda crear la tabla nueva.
@Model
final class Cuenta {
    /// Identificador estable que usan los gastos, pagos y abonos para apuntar a la cuenta.
    var identificador: String = UUID().uuidString
    var nombre: String = ""
    var tipoRaw: String = "efectivo"
    var saldoInicial: Double = 0
    var fechaCreacion: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \MovimientoCuenta.cuenta)
    var movimientos: [MovimientoCuenta] = []

    init(nombre: String,
         tipo: TipoCuenta = .efectivo,
         saldoInicial: Double = 0,
         fechaCreacion: Date = Date.now) {
        self.nombre = nombre
        self.tipoRaw = tipo.rawValue
        self.saldoInicial = saldoInicial
        self.fechaCreacion = fechaCreacion
    }

    var tipo: TipoCuenta {
        get { TipoCuenta(rawValue: tipoRaw) ?? .efectivo }
        set { tipoRaw = newValue.rawValue }
    }

    // MARK: Cuenta predeterminada

    static let clavePredeterminada = "cuentaPredeterminada"

    /// Cuenta que aparece ya elegida al registrar un gasto, un abono, etc. (nil = ninguna).
    static var predeterminadaId: String? {
        let valor = UserDefaults.standard.string(forKey: clavePredeterminada)
        return (valor?.isEmpty ?? true) ? nil : valor
    }

    static func establecerPredeterminada(_ identificador: String?) {
        UserDefaults.standard.set(identificador ?? "", forKey: clavePredeterminada)
    }

    // MARK: Saldo

    /// Suma de los movimientos propios de la cuenta (depósitos, transferencias y ajustes).
    var totalMovimientos: Double { movimientos.reduce(0) { $0 + $1.monto } }

    /// Saldo actual. Recibe todo lo que puede estar asignado a la cuenta y se queda con lo suyo.
    func saldo(gastos: [Gasto], pagos: [PagoRealizado], abonos: [AbonoDeuda], metas: [MovimientoMeta]) -> Double {
        let id = identificador
        var total = saldoInicial + totalMovimientos
        for gasto in gastos where gasto.cuentaId == id { total -= gasto.monto }
        for pago in pagos where pago.cuentaId == id { total -= pago.monto }
        for abono in abonos where abono.cuentaId == id { total -= abono.monto }
        // Un aporte (monto > 0) saca plata de la cuenta; un retiro (monto < 0) la devuelve.
        for movimiento in metas where movimiento.cuentaId == id { total -= movimiento.monto }
        return total
    }

    // MARK: Operaciones

    /// Plata que entra (por ejemplo, el salario que recibiste).
    func depositar(_ monto: Double, concepto: String, fecha: Date = Date.now, en contexto: ModelContext) {
        let movimiento = MovimientoCuenta(monto: monto, fecha: fecha, concepto: concepto, tipo: .ingreso)
        contexto.insert(movimiento)
        movimiento.cuenta = self
    }

    /// Deja el saldo en `nuevoSaldo` agregando un ajuste por la diferencia.
    func ajustar(a nuevoSaldo: Double, saldoActual: Double, fecha: Date = Date.now, en contexto: ModelContext) {
        let diferencia = nuevoSaldo - saldoActual
        guard abs(diferencia) >= 0.005 else { return }
        let movimiento = MovimientoCuenta(monto: diferencia, fecha: fecha, concepto: "Ajuste de saldo", tipo: .ajuste)
        contexto.insert(movimiento)
        movimiento.cuenta = self
    }

    /// Pasa plata de una cuenta a otra. Se guardan dos movimientos unidos por el mismo `grupo`.
    static func transferir(_ monto: Double,
                           de origen: Cuenta,
                           a destino: Cuenta,
                           fecha: Date = Date.now,
                           nota: String = "",
                           en contexto: ModelContext) {
        let grupo = UUID().uuidString
        let sufijo = nota.trimmingCharacters(in: .whitespaces).isEmpty ? "" : " · \(nota)"

        let salida = MovimientoCuenta(monto: -monto, fecha: fecha,
                                      concepto: "Transferencia a \(destino.nombre)\(sufijo)",
                                      tipo: .transferencia, grupo: grupo)
        contexto.insert(salida)
        salida.cuenta = origen

        let entrada = MovimientoCuenta(monto: monto, fecha: fecha,
                                       concepto: "Transferencia desde \(origen.nombre)\(sufijo)",
                                       tipo: .transferencia, grupo: grupo)
        contexto.insert(entrada)
        entrada.cuenta = destino
    }

    /// Borra un movimiento de la cuenta. Si es una transferencia, borra también la otra mitad.
    static func eliminar(_ movimiento: MovimientoCuenta, en contexto: ModelContext) {
        if let grupo = movimiento.grupo {
            let todos = (try? contexto.fetch(FetchDescriptor<MovimientoCuenta>())) ?? []
            for otro in todos where otro.grupo == grupo {
                contexto.delete(otro)
            }
        } else {
            contexto.delete(movimiento)
        }
    }
}

// MARK: - Movimiento de cuenta

/// Un movimiento propio de una cuenta: positivo entra plata, negativo sale.
@Model
final class MovimientoCuenta {
    var monto: Double = 0
    var fecha: Date = Date.now
    var concepto: String = ""
    var tipoRaw: String = "ajuste"
    /// Une las dos mitades de una transferencia (nil en los demás movimientos).
    var grupo: String?
    var cuenta: Cuenta?

    init(monto: Double,
         fecha: Date = Date.now,
         concepto: String = "",
         tipo: TipoMovimientoCuenta = .ajuste,
         grupo: String? = nil) {
        self.monto = monto
        self.fecha = fecha
        self.concepto = concepto
        self.tipoRaw = tipo.rawValue
        self.grupo = grupo
    }

    var tipo: TipoMovimientoCuenta {
        get { TipoMovimientoCuenta(rawValue: tipoRaw) ?? .ajuste }
        set { tipoRaw = newValue.rawValue }
    }
}
