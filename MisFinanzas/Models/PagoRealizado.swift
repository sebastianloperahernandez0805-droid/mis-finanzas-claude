import Foundation
import SwiftData

/// Un pago registrado de un pago fijo: deja el historial mes por mes.
/// Se crea al marcar el pago fijo como «Pagado» y se borra si se vuelve a «Pendiente».
@Model
final class PagoRealizado {
    var fecha: Date = Date.now
    var monto: Double = 0
    var pago: PagoFijo?

    init(monto: Double, fecha: Date = Date.now) {
        self.monto = monto
        self.fecha = fecha
    }
}
