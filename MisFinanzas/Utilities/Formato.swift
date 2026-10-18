import Foundation

/// Formateo de dinero, porcentajes y números según la región del iPhone.
/// La moneda se toma del idioma/región del dispositivo (en Colombia: COP).
enum Formato {

    static var codigoMoneda: String {
        Locale.current.currency?.identifier ?? "USD"
    }

    static var simboloMoneda: String {
        Locale.current.currencySymbol ?? "$"
    }

    /// 1500.5 -> "$1.500,50" (los decimales solo aparecen si hacen falta).
    static func moneda(_ valor: Double) -> String {
        valor.formatted(
            .currency(code: codigoMoneda).precision(.fractionLength(0...2))
        )
    }

    /// 0.5 -> "50 %"
    static func porcentaje(_ valor: Double) -> String {
        valor.formatted(.percent.precision(.fractionLength(0)))
    }

    /// Convierte el texto de un campo ("1.250,50" o "1,250.50" según la región) en Double.
    static func numero(desde texto: String) -> Double? {
        let limpio = texto.trimmingCharacters(in: .whitespaces)
        guard !limpio.isEmpty else { return nil }
        let formateador = NumberFormatter()
        formateador.numberStyle = .decimal
        formateador.locale = .current
        return formateador.number(from: limpio)?.doubleValue
    }

    /// Convierte un Double en texto editable (sin separador de miles).
    static func texto(desde valor: Double) -> String {
        let formateador = NumberFormatter()
        formateador.numberStyle = .decimal
        formateador.locale = .current
        formateador.usesGroupingSeparator = false
        formateador.maximumFractionDigits = 2
        return formateador.string(from: NSNumber(value: valor)) ?? ""
    }
}
