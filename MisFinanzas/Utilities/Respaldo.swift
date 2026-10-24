import Foundation
import SwiftData

// MARK: - Formato del archivo de respaldo (JSON)

/// Contenido completo de una copia de seguridad. Se guarda como un archivo .json legible.
/// Si en el futuro se agregan datos nuevos, deben ser opcionales para que las copias viejas sigan abriendo.
struct RespaldoDatos: Codable {
    /// Marca interna del archivo. No se cambia a «Mivra» para que las copias hechas antes sigan abriendo.
    static let nombreFormato = "MisFinanzas"
    static let versionActual = 1

    var formato: String = RespaldoDatos.nombreFormato
    var version: Int = RespaldoDatos.versionActual
    var fecha: Date = Date.now
    var presupuestoDiario: Double = 0

    var gastos: [GastoRespaldo] = []
    var ingresos: [IngresoRespaldo] = []
    var pagosFijos: [PagoFijoRespaldo] = []
    var deudas: [DeudaRespaldo] = []
    var metas: [MetaRespaldo] = []
    var categorias: [CategoriaRespaldo] = []
    var presupuestos: [PresupuestoRespaldo] = []

    /// Líneas de texto con lo que contiene la copia: «128 gastos», «3 deudas»...
    var resumen: [String] {
        var lineas: [String] = []
        func agregar(_ cantidad: Int, _ singular: String, _ plural: String) {
            if cantidad > 0 { lineas.append("\(cantidad) \(cantidad == 1 ? singular : plural)") }
        }
        agregar(gastos.count, "gasto", "gastos")
        agregar(ingresos.count, "fuente de ingreso", "fuentes de ingreso")
        agregar(pagosFijos.count, "pago fijo", "pagos fijos")
        agregar(deudas.count, "deuda", "deudas")
        agregar(metas.count, "meta de ahorro", "metas de ahorro")
        agregar(categorias.count, "categoría propia", "categorías propias")
        agregar(presupuestos.count, "presupuesto", "presupuestos")
        return lineas
    }
}

struct GastoRespaldo: Codable {
    var concepto: String
    var monto: Double
    var fecha: Date
    var categoria: String
    var nota: String
}

struct IngresoRespaldo: Codable {
    var fuente: String
    var monto: Double
    var tipo: String
    var frecuencia: String
    var fecha: Date
    var nota: String
}

struct RegistroPagoRespaldo: Codable {
    var fecha: Date
    var monto: Double
}

struct PagoFijoRespaldo: Codable {
    var nombre: String
    var monto: Double
    var diaVencimiento: Int
    var categoria: String
    var ultimoPago: Date?
    var nota: String
    var historial: [RegistroPagoRespaldo]
}

/// Sirve tanto para los abonos de una deuda como para los movimientos de una meta.
struct MovimientoRespaldo: Codable {
    var monto: Double
    var fecha: Date
    var nota: String
}

struct DeudaRespaldo: Codable {
    var nombre: String
    var acreedor: String
    var tipo: String
    var montoTotal: Double
    var fechaCreacion: Date
    var fechaLimite: Date?
    var nota: String
    var tasaInteresAnual: Double
    var numeroCuotas: Int
    var diaPago: Int
    var abonos: [MovimientoRespaldo]
}

struct MetaRespaldo: Codable {
    var nombre: String
    var montoObjetivo: Double
    var icono: String
    var paleta: String
    var fechaObjetivo: Date?
    var fechaCreacion: Date
    var movimientos: [MovimientoRespaldo]
}

struct CategoriaRespaldo: Codable {
    var clave: String
    var nombre: String
    var icono: String
    var paleta: String
    var fechaCreacion: Date
}

struct PresupuestoRespaldo: Codable {
    var claveCategoria: String
    var montoMensual: Double
}

// MARK: - Errores

enum ErrorRespaldo: LocalizedError {
    case archivoInvalido
    case versionNueva(Int)

    var errorDescription: String? {
        switch self {
        case .archivoInvalido:
            return "Ese archivo no es una copia de seguridad de Mivra."
        case .versionNueva(let version):
            return "Esa copia (versión \(version)) es más nueva que esta app. Actualiza la app e inténtalo de nuevo."
        }
    }
}

// MARK: - Servicio

/// Crea, lee y restaura copias de seguridad. Todo ocurre en el iPhone.
/// Se llama siempre desde la interfaz (hilo principal), con el `ModelContext` de la app.
enum RespaldoServicio {

    // MARK: Crear

    /// Lee todos los datos de la app y los junta en un `RespaldoDatos`.
    static func crear(en contexto: ModelContext) throws -> RespaldoDatos {
        var respaldo = RespaldoDatos()
        respaldo.presupuestoDiario = UserDefaults.standard.double(forKey: "presupuestoDiario")

        let gastos = try contexto.fetch(FetchDescriptor<Gasto>(sortBy: [SortDescriptor(\Gasto.fecha)]))
        respaldo.gastos = gastos.map { gasto in
            GastoRespaldo(concepto: gasto.concepto, monto: gasto.monto, fecha: gasto.fecha,
                          categoria: gasto.categoriaRaw, nota: gasto.nota)
        }

        let ingresos = try contexto.fetch(FetchDescriptor<Ingreso>(sortBy: [SortDescriptor(\Ingreso.fecha)]))
        respaldo.ingresos = ingresos.map { ingreso in
            IngresoRespaldo(fuente: ingreso.fuente, monto: ingreso.monto, tipo: ingreso.tipoRaw,
                            frecuencia: ingreso.frecuenciaRaw, fecha: ingreso.fecha, nota: ingreso.nota)
        }

        let pagos = try contexto.fetch(FetchDescriptor<PagoFijo>(sortBy: [SortDescriptor(\PagoFijo.nombre)]))
        respaldo.pagosFijos = pagos.map { pago in
            PagoFijoRespaldo(
                nombre: pago.nombre, monto: pago.monto, diaVencimiento: pago.diaVencimiento,
                categoria: pago.categoriaRaw, ultimoPago: pago.ultimoPago, nota: pago.nota,
                historial: pago.historial.map { RegistroPagoRespaldo(fecha: $0.fecha, monto: $0.monto) }
            )
        }

        let deudas = try contexto.fetch(FetchDescriptor<Deuda>(sortBy: [SortDescriptor(\Deuda.fechaCreacion)]))
        respaldo.deudas = deudas.map { deuda in
            DeudaRespaldo(
                nombre: deuda.nombre, acreedor: deuda.acreedor, tipo: deuda.tipoRaw,
                montoTotal: deuda.montoTotal, fechaCreacion: deuda.fechaCreacion,
                fechaLimite: deuda.fechaLimite, nota: deuda.nota,
                tasaInteresAnual: deuda.tasaInteresAnual, numeroCuotas: deuda.numeroCuotas,
                diaPago: deuda.diaPago,
                abonos: deuda.abonos.map { MovimientoRespaldo(monto: $0.monto, fecha: $0.fecha, nota: $0.nota) }
            )
        }

        let metas = try contexto.fetch(FetchDescriptor<MetaAhorro>(sortBy: [SortDescriptor(\MetaAhorro.fechaCreacion)]))
        respaldo.metas = metas.map { meta in
            MetaRespaldo(
                nombre: meta.nombre, montoObjetivo: meta.montoObjetivo, icono: meta.iconoSistema,
                paleta: meta.paletaRaw, fechaObjetivo: meta.fechaObjetivo, fechaCreacion: meta.fechaCreacion,
                movimientos: meta.movimientos.map { MovimientoRespaldo(monto: $0.monto, fecha: $0.fecha, nota: $0.nota) }
            )
        }

        let categorias = try contexto.fetch(
            FetchDescriptor<CategoriaPersonalizada>(sortBy: [SortDescriptor(\CategoriaPersonalizada.fechaCreacion)])
        )
        respaldo.categorias = categorias.map { categoria in
            CategoriaRespaldo(clave: categoria.clave, nombre: categoria.nombre, icono: categoria.iconoSistema,
                              paleta: categoria.paletaRaw, fechaCreacion: categoria.fechaCreacion)
        }

        let presupuestos = try contexto.fetch(FetchDescriptor<PresupuestoCategoria>())
        respaldo.presupuestos = presupuestos.map { presupuesto in
            PresupuestoRespaldo(claveCategoria: presupuesto.claveCategoria, montoMensual: presupuesto.montoMensual)
        }

        return respaldo
    }

    // MARK: Convertir a archivo y viceversa

    static func codificar(_ respaldo: RespaldoDatos) throws -> Data {
        let codificador = JSONEncoder()
        codificador.outputFormatting = [.prettyPrinted, .sortedKeys]
        codificador.dateEncodingStrategy = .iso8601
        return try codificador.encode(respaldo)
    }

    /// Interpreta el contenido de un archivo. No toca la base de datos: solo valida.
    static func leer(_ datos: Data) throws -> RespaldoDatos {
        let decodificador = JSONDecoder()
        decodificador.dateDecodingStrategy = .iso8601

        let respaldo: RespaldoDatos
        do {
            respaldo = try decodificador.decode(RespaldoDatos.self, from: datos)
        } catch {
            throw ErrorRespaldo.archivoInvalido
        }
        guard respaldo.formato == RespaldoDatos.nombreFormato else {
            throw ErrorRespaldo.archivoInvalido
        }
        guard respaldo.version <= RespaldoDatos.versionActual else {
            throw ErrorRespaldo.versionNueva(respaldo.version)
        }
        return respaldo
    }

    // MARK: Restaurar

    /// Reemplaza TODOS los datos actuales por los de la copia.
    static func restaurar(_ respaldo: RespaldoDatos, en contexto: ModelContext) throws {
        try borrarTodo(en: contexto)

        for g in respaldo.gastos {
            let gasto = Gasto(concepto: g.concepto, monto: g.monto, fecha: g.fecha, nota: g.nota)
            gasto.categoriaRaw = g.categoria
            contexto.insert(gasto)
        }

        for i in respaldo.ingresos {
            contexto.insert(
                Ingreso(fuente: i.fuente, monto: i.monto,
                        tipo: TipoIngreso(rawValue: i.tipo) ?? .otros,
                        frecuencia: FrecuenciaIngreso(rawValue: i.frecuencia) ?? .mensual,
                        fecha: i.fecha, nota: i.nota)
            )
        }

        for p in respaldo.pagosFijos {
            let pago = PagoFijo(nombre: p.nombre, monto: p.monto, diaVencimiento: p.diaVencimiento,
                                categoria: CategoriaPagoFijo(rawValue: p.categoria) ?? .otro,
                                ultimoPago: p.ultimoPago, nota: p.nota)
            contexto.insert(pago)
            for h in p.historial {
                let registro = PagoRealizado(monto: h.monto, fecha: h.fecha)
                contexto.insert(registro)
                registro.pago = pago
            }
        }

        for d in respaldo.deudas {
            let deuda = Deuda(nombre: d.nombre, acreedor: d.acreedor,
                              tipo: TipoDeuda(rawValue: d.tipo) ?? .otra,
                              montoTotal: d.montoTotal, fechaCreacion: d.fechaCreacion,
                              fechaLimite: d.fechaLimite, nota: d.nota,
                              tasaInteresAnual: d.tasaInteresAnual, numeroCuotas: d.numeroCuotas,
                              diaPago: d.diaPago)
            contexto.insert(deuda)
            for a in d.abonos {
                deuda.abonar(a.monto, fecha: a.fecha, nota: a.nota, en: contexto)
            }
        }

        for m in respaldo.metas {
            let meta = MetaAhorro(nombre: m.nombre, montoObjetivo: m.montoObjetivo,
                                  iconoSistema: m.icono,
                                  paleta: PaletaColor(rawValue: m.paleta) ?? .azul,
                                  fechaObjetivo: m.fechaObjetivo, fechaCreacion: m.fechaCreacion)
            contexto.insert(meta)
            for mov in m.movimientos {
                meta.registrar(mov.monto, nota: mov.nota, fecha: mov.fecha, en: contexto)
            }
        }

        for c in respaldo.categorias {
            let categoria = CategoriaPersonalizada(nombre: c.nombre, iconoSistema: c.icono,
                                                   paleta: PaletaColor(rawValue: c.paleta) ?? .azul)
            // Se conserva la clave original: los gastos de la copia apuntan a ella.
            categoria.clave = c.clave
            categoria.fechaCreacion = c.fechaCreacion
            contexto.insert(categoria)
        }

        for p in respaldo.presupuestos {
            contexto.insert(PresupuestoCategoria(claveCategoria: p.claveCategoria, montoMensual: p.montoMensual))
        }

        try contexto.save()
        UserDefaults.standard.set(respaldo.presupuestoDiario, forKey: "presupuestoDiario")
    }

    /// Borra todos los registros. Los abonos, movimientos e historiales se borran en cascada.
    private static func borrarTodo(en contexto: ModelContext) throws {
        for x in try contexto.fetch(FetchDescriptor<Gasto>()) { contexto.delete(x) }
        for x in try contexto.fetch(FetchDescriptor<Ingreso>()) { contexto.delete(x) }
        for x in try contexto.fetch(FetchDescriptor<PagoFijo>()) { contexto.delete(x) }
        for x in try contexto.fetch(FetchDescriptor<Deuda>()) { contexto.delete(x) }
        for x in try contexto.fetch(FetchDescriptor<MetaAhorro>()) { contexto.delete(x) }
        for x in try contexto.fetch(FetchDescriptor<CategoriaPersonalizada>()) { contexto.delete(x) }
        for x in try contexto.fetch(FetchDescriptor<PresupuestoCategoria>()) { contexto.delete(x) }
    }
}
