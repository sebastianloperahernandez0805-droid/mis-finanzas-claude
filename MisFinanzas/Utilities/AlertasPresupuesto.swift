import Foundation
import SwiftData
import UserNotifications

/// Avisos de presupuesto: una notificación cuando un gasto hace que una categoría llegue al 80 %
/// de su límite mensual, y otra cuando lo supera. Ocurre en el iPhone, sin internet.
enum AlertasPresupuesto {
    static let clave = "alertasPresupuestoActivas"

    /// Debe llamarse al guardar un gasto, ANTES de aplicar el cambio al gasto.
    /// - Parameters:
    ///   - categoriaClave: categoría que quedará en el gasto.
    ///   - fecha: fecha que quedará en el gasto.
    ///   - editado: el gasto que se está editando (nil si es nuevo).
    ///   - nuevoMonto: el monto que quedará en el gasto.
    static func revisar(categoriaClave: String,
                        fecha: Date,
                        editado: Gasto?,
                        nuevoMonto: Double,
                        en contexto: ModelContext) {
        guard UserDefaults.standard.bool(forKey: clave) else { return }

        let calendario = Calendar.current
        // Solo se avisa por gastos del mes en curso.
        guard calendario.isDate(fecha, equalTo: Date.now, toGranularity: .month),
              let intervalo = calendario.dateInterval(of: .month, for: fecha) else { return }

        let presupuestos = (try? contexto.fetch(FetchDescriptor<PresupuestoCategoria>())) ?? []
        guard let presupuesto = presupuestos.first(where: { $0.claveCategoria == categoriaClave }),
              presupuesto.montoMensual > 0 else { return }
        let limite = presupuesto.montoMensual

        let inicio = intervalo.start
        let fin = intervalo.end
        let descriptor = FetchDescriptor<Gasto>(
            predicate: #Predicate<Gasto> { $0.fecha >= inicio && $0.fecha < fin }
        )
        let delMes = ((try? contexto.fetch(descriptor)) ?? [])
            .filter { $0.categoriaRaw == categoriaClave }

        let antes = delMes.reduce(0) { $0 + $1.monto }
        let sinEste = delMes
            .filter { gasto in
                if let editado { return gasto !== editado }
                return true
            }
            .reduce(0) { $0 + $1.monto }
        let despues = sinEste + nuevoMonto

        let personalizadas = (try? contexto.fetch(FetchDescriptor<CategoriaPersonalizada>())) ?? []
        let nombre = CatalogoCategorias.visual(para: categoriaClave, personalizadas).nombre

        let titulo: String
        let cuerpo: String
        let nivel: String
        if antes < limite && despues >= limite {
            nivel = "limite"
            titulo = "Superaste el presupuesto de \(nombre)"
            cuerpo = "Llevas \(Formato.moneda(despues)) de \(Formato.moneda(limite)) este mes: \(Formato.moneda(despues - limite)) por encima."
        } else if antes < limite * 0.8 && despues >= limite * 0.8 && despues < limite {
            nivel = "ochenta"
            titulo = "Vas en \(Formato.porcentaje(despues / limite)) en \(nombre)"
            cuerpo = "Llevas \(Formato.moneda(despues)) de \(Formato.moneda(limite)). Te quedan \(Formato.moneda(limite - despues)) este mes."
        } else {
            return
        }

        let identificador = "mf-presupuesto-\(categoriaClave)-\(nivel)"
        Task {
            await notificar(identificador: identificador, titulo: titulo, cuerpo: cuerpo)
        }
    }

    private static func notificar(identificador: String, titulo: String, cuerpo: String) async {
        let estado = await Recordatorios.estadoDelPermiso()
        guard estado == .authorized || estado == .provisional else { return }

        let contenido = UNMutableNotificationContent()
        contenido.title = titulo
        contenido.body = cuerpo
        contenido.sound = .default
        let disparador = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let peticion = UNNotificationRequest(identifier: identificador, content: contenido, trigger: disparador)
        try? await UNUserNotificationCenter.current().add(peticion)
    }
}
