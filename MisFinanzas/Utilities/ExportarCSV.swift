import Foundation
import SwiftData

/// Crea un archivo CSV con tus movimientos de dinero, para abrirlo en Excel, Numbers o Google Sheets.
///
/// El separador se ajusta a la región del iPhone: en Colombia los decimales llevan coma, así que
/// las columnas se separan con punto y coma (así Excel en español las reconoce sin configurar nada).
enum ExportarCSV {

    struct Resultado {
        let url: URL
        let filas: Int
    }

    private struct Fila {
        let fecha: Date
        let tipo: String
        let detalle: String
        let categoria: String
        let monto: Double
    }

    /// Junta gastos, pagos fijos pagados, abonos a deudas y aportes/retiros de metas en un solo archivo.
    static func crearMovimientos(en contexto: ModelContext) throws -> Resultado {
        let personalizadas = (try? contexto.fetch(FetchDescriptor<CategoriaPersonalizada>())) ?? []
        let gastos = try contexto.fetch(FetchDescriptor<Gasto>())
        let pagos = try contexto.fetch(FetchDescriptor<PagoRealizado>())
        let abonos = try contexto.fetch(FetchDescriptor<AbonoDeuda>())
        let movimientos = try contexto.fetch(FetchDescriptor<MovimientoMeta>())

        var filas: [Fila] = []

        for gasto in gastos {
            let categoria = CatalogoCategorias.visual(para: gasto.categoriaRaw, personalizadas).nombre
            filas.append(Fila(fecha: gasto.fecha, tipo: "Gasto", detalle: gasto.concepto,
                              categoria: categoria, monto: gasto.monto))
        }
        for pago in pagos {
            filas.append(Fila(fecha: pago.fecha, tipo: "Pago fijo",
                              detalle: pago.pago?.nombre ?? "Pago fijo",
                              categoria: pago.pago?.categoria.nombre ?? "", monto: pago.monto))
        }
        for abono in abonos {
            filas.append(Fila(fecha: abono.fecha, tipo: "Abono a deuda",
                              detalle: abono.deuda?.nombre ?? "Deuda", categoria: "", monto: abono.monto))
        }
        for movimiento in movimientos {
            filas.append(Fila(fecha: movimiento.fecha,
                              tipo: movimiento.esAporte ? "Aporte a meta" : "Retiro de meta",
                              detalle: movimiento.meta?.nombre ?? "Meta", categoria: "",
                              monto: abs(movimiento.monto)))
        }

        filas.sort { $0.fecha > $1.fecha }

        let decimal = Locale.current.decimalSeparator ?? "."
        let separador = decimal == "," ? ";" : ","

        let formateadorFecha = DateFormatter()
        formateadorFecha.locale = Locale(identifier: "en_US_POSIX")
        formateadorFecha.dateFormat = "yyyy-MM-dd HH:mm"

        var lineas: [String] = [
            ["Fecha", "Tipo", "Detalle", "Categoría", "Monto"].joined(separator: separador)
        ]
        for fila in filas {
            let campos = [
                formateadorFecha.string(from: fila.fecha),
                fila.tipo,
                escapar(fila.detalle, separador: separador),
                escapar(fila.categoria, separador: separador),
                Formato.texto(desde: fila.monto)
            ]
            lineas.append(campos.joined(separator: separador))
        }

        // El BOM al inicio hace que Excel lea bien las tildes y la «ñ».
        let texto = "\u{FEFF}" + lineas.joined(separator: "\r\n") + "\r\n"

        let nombreFecha = DateFormatter()
        nombreFecha.locale = Locale(identifier: "en_US_POSIX")
        nombreFecha.dateFormat = "yyyy-MM-dd"
        let nombre = "Mivra-movimientos-\(nombreFecha.string(from: Date.now)).csv"

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(nombre)
        try Data(texto.utf8).write(to: url, options: .atomic)
        return Resultado(url: url, filas: filas.count)
    }

    /// Protege el texto para el CSV: comillas si hace falta y sin fórmulas ocultas.
    private static func escapar(_ texto: String, separador: String) -> String {
        var valor = texto.replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        // Un texto que empieza con = + - @ lo tomaría Excel como una fórmula.
        if let primero = valor.first, "=+-@".contains(primero) {
            valor = "'" + valor
        }
        if valor.contains(separador) || valor.contains("\"") {
            valor = "\"" + valor.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return valor
    }
}
