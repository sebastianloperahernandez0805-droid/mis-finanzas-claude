import SwiftUI
import SwiftData
import UserNotifications

/// Ajustes de los recordatorios de vencimientos (pagos fijos y deudas).
struct RecordatoriosView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar
    @Environment(\.openURL) private var abrirURL

    @AppStorage(Recordatorios.claveActivos) private var activos = false
    @AppStorage(Recordatorios.claveDiasAntes) private var diasAntes = 1

    @State private var permisoDenegado = false
    @State private var programados = 0
    @State private var pruebaEnviada = false

    /// El interruptor pide el permiso de notificaciones al encenderse.
    private var interruptor: Binding<Bool> {
        Binding(
            get: { activos },
            set: { nuevo in
                if nuevo {
                    Task { await activar() }
                } else {
                    activos = false
                    programados = 0
                    Recordatorios.actualizar(contexto: contexto)
                }
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Avisarme de vencimientos", isOn: interruptor)

                    if activos {
                        Picker("Cuándo avisar", selection: $diasAntes) {
                            Text("El mismo día").tag(0)
                            Text("1 día antes").tag(1)
                            Text("2 días antes").tag(2)
                            Text("3 días antes").tag(3)
                            Text("1 semana antes").tag(7)
                        }
                    }
                } footer: {
                    Text("Recibirás un aviso a las 9:00 a. m. por cada pago fijo pendiente y por cada deuda con día de pago o fecha límite. Todo ocurre en tu iPhone, sin internet.")
                }

                if permisoDenegado {
                    Section {
                        Text("Las notificaciones están desactivadas para esta app. Actívalas en Ajustes para recibir los avisos.")
                            .font(.subheadline)
                        Button("Abrir Ajustes") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                abrirURL(url)
                            }
                        }
                    }
                }

                if activos {
                    Section {
                        LabeledContent("Avisos programados") {
                            Text("\(programados)")
                        }

                        Button {
                            Task {
                                await Recordatorios.enviarPrueba()
                                pruebaEnviada = true
                            }
                        } label: {
                            Label("Enviar un aviso de prueba", systemImage: "bell.badge")
                        }
                    } footer: {
                        Text(pruebaEnviada
                             ? "Llegará en unos 5 segundos. Si no lo ves, revisa que las notificaciones estén permitidas y que no tengas activo un modo de concentración."
                             : "La prueba llega en unos 5 segundos.")
                    }
                }
            }
            .navigationTitle("Recordatorios")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { cerrar() }
                }
            }
            .task {
                let estado = await Recordatorios.estadoDelPermiso()
                permisoDenegado = (estado == .denied)
                await contarProgramados()
            }
            .onChange(of: diasAntes) { _, _ in
                Task {
                    await Recordatorios.reprogramar(contexto: contexto)
                    await contarProgramados()
                }
            }
        }
    }

    // MARK: Acciones

    @MainActor
    private func activar() async {
        let concedido = await Recordatorios.pedirPermiso()
        permisoDenegado = !concedido
        activos = concedido
        if concedido {
            await Recordatorios.reprogramar(contexto: contexto)
            await contarProgramados()
        }
    }

    @MainActor
    private func contarProgramados() async {
        let pendientes = await UNUserNotificationCenter.current().pendingNotificationRequests()
        programados = pendientes.filter { $0.identifier != "mf-prueba" }.count
    }
}

#Preview {
    RecordatoriosView()
        .modelContainer(DatosEjemplo.contenedor)
}
