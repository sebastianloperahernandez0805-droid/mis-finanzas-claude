import Foundation
import SwiftData
import UserNotifications

/// Recordatorios locales de vencimientos (pagos fijos y deudas).
/// Son notificaciones del propio iPhone: no usan internet ni ningún servidor.
///
/// En cada actualización se borran todas las notificaciones pendientes y se vuelven a programar
/// las de los próximos meses (hasta 60, el iPhone permite 64). Por eso se llama al abrir la app
/// y cada vez que algo cambia (marcar un pago, editar un vencimiento, activar los recordatorios).
enum Recordatorios {
    static let claveActivos = "recordatoriosActivos"
    static let claveDiasAntes = "recordatorioDiasAntes"

    private struct Aviso {
        let fecha: Date
        let titulo: String
        let cuerpo: String
    }

    /// Cuenta cuántas reprogramaciones se han pedido. Si llegan dos casi a la vez, la más vieja
    /// se detiene sola para no dejar avisos repetidos o desactualizados.
    @MainActor private static var generacion = 0

    // MARK: Permiso

    /// Pide permiso para mostrar notificaciones. Devuelve `true` si el usuario lo concede.
    static func pedirPermiso() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func estadoDelPermiso() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    // MARK: Programación

    /// Reprograma los recordatorios en segundo plano. Se puede llamar desde cualquier parte.
    static func actualizar(contexto: ModelContext) {
        Task { @MainActor in
            await reprogramar(contexto: contexto)
        }
    }

    @MainActor
    static func reprogramar(contexto: ModelContext) async {
        generacion += 1
        let miGeneracion = generacion

        let centro = UNUserNotificationCenter.current()
        centro.removeAllPendingNotificationRequests()

        guard UserDefaults.standard.bool(forKey: claveActivos) else { return }

        let estado = await estadoDelPermiso()
        guard estado == .authorized || estado == .provisional else { return }
        guard miGeneracion == generacion else { return }

        let diasAntes = UserDefaults.standard.object(forKey: claveDiasAntes) as? Int ?? 1
        let calendario = Calendar.current
        let ahora = Date.now
        var avisos: [Aviso] = []

        // Pagos fijos: este mes (si todavía no se pagó) y los dos siguientes.
        let pagos = (try? contexto.fetch(FetchDescriptor<PagoFijo>())) ?? []
        for pago in pagos {
            for desplazamiento in 0...2 {
                guard let mes = calendario.date(byAdding: .month, value: desplazamiento, to: ahora) else { continue }
                if desplazamiento == 0 && pago.estaPagadoEsteMes { continue }
                let vence = pago.fechaVencimiento(en: mes)
                if let momento = momentoDeAviso(vence: vence, diasAntes: diasAntes, ahora: ahora) {
                    avisos.append(Aviso(
                        fecha: momento,
                        titulo: "Pago fijo por vencer",
                        cuerpo: "\(pago.nombre): \(Formato.moneda(pago.monto)) \(textoDeVencimiento(vence, diasAntes: diasAntes))"
                    ))
                }
            }
        }

        // Deudas: con día de pago mensual, o con fecha límite.
        let deudas = (try? contexto.fetch(FetchDescriptor<Deuda>())) ?? []
        for deuda in deudas where !deuda.estaSaldada {
            var vencimientos: [Date] = []
            if deuda.diaPago > 0 {
                for desplazamiento in 0...2 {
                    if let mes = calendario.date(byAdding: .month, value: desplazamiento, to: ahora) {
                        vencimientos.append(fecha(conDia: deuda.diaPago, en: mes))
                    }
                }
            } else if let limite = deuda.fechaLimite {
                vencimientos.append(limite)
            }
            for vence in vencimientos {
                if let momento = momentoDeAviso(vence: vence, diasAntes: diasAntes, ahora: ahora) {
                    let detalle = deuda.cuotaEstimada > 0
                        ? "cuota estimada \(Formato.moneda(deuda.cuotaEstimada))"
                        : "saldo \(Formato.moneda(deuda.saldoPendiente))"
                    avisos.append(Aviso(
                        fecha: momento,
                        titulo: "Pago de deuda por vencer",
                        cuerpo: "\(deuda.nombre): \(detalle) \(textoDeVencimiento(vence, diasAntes: diasAntes))"
                    ))
                }
            }
        }

        // Se programan los 60 más próximos.
        let ordenados = avisos.sorted { $0.fecha < $1.fecha }
        for (indice, aviso) in ordenados.prefix(60).enumerated() {
            guard miGeneracion == generacion else { return }
            let contenido = UNMutableNotificationContent()
            contenido.title = aviso.titulo
            contenido.body = aviso.cuerpo
            contenido.sound = .default

            let componentes = calendario.dateComponents([.year, .month, .day, .hour, .minute], from: aviso.fecha)
            let disparador = UNCalendarNotificationTrigger(dateMatching: componentes, repeats: false)
            let peticion = UNNotificationRequest(identifier: "mf-\(indice)", content: contenido, trigger: disparador)
            try? await centro.add(peticion)
        }
    }

    /// Programa un aviso de prueba para dentro de unos segundos.
    static func enviarPrueba() async {
        let contenido = UNMutableNotificationContent()
        contenido.title = "Mis Finanzas"
        contenido.body = "Así se verán tus recordatorios de vencimientos."
        contenido.sound = .default
        let disparador = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let peticion = UNNotificationRequest(identifier: "mf-prueba", content: contenido, trigger: disparador)
        try? await UNUserNotificationCenter.current().add(peticion)
    }

    // MARK: Utilidades

    /// A las 9:00 del día del aviso. Devuelve nil si ese momento ya pasó.
    private static func momentoDeAviso(vence: Date, diasAntes: Int, ahora: Date) -> Date? {
        let calendario = Calendar.current
        guard let dia = calendario.date(byAdding: .day, value: -diasAntes, to: vence),
              let momento = calendario.date(bySettingHour: 9, minute: 0, second: 0, of: dia),
              momento > ahora else { return nil }
        return momento
    }

    private static func textoDeVencimiento(_ vence: Date, diasAntes: Int) -> String {
        if diasAntes == 0 { return "vence hoy" }
        return "vence el \(vence.formatted(.dateTime.day().month(.wide)))"
    }

    /// Fecha con el día indicado en el mes de `referencia` (si el mes es más corto, el último día).
    private static func fecha(conDia dia: Int, en referencia: Date) -> Date {
        let calendario = Calendar.current
        let diasDelMes = calendario.range(of: .day, in: .month, for: referencia)?.count ?? 28
        var componentes = calendario.dateComponents([.year, .month], from: referencia)
        componentes.day = min(max(dia, 1), diasDelMes)
        return calendario.date(from: componentes) ?? referencia
    }
}

/// Permite que los avisos también se muestren (como banner) cuando la app está abierta.
final class DelegadoNotificaciones: NSObject, UNUserNotificationCenterDelegate {
    static let compartido = DelegadoNotificaciones()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
