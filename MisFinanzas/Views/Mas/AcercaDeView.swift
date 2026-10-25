import SwiftUI

/// Información de la app: versión, privacidad y avisos importantes sobre las estimaciones.
struct AcercaDeView: View {
    @Environment(\.dismiss) private var cerrar

    private var version: String {
        let numero = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let compilacion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(numero) (\(compilacion))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                            .background(Tema.ingreso.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Mivra")
                                .font(.title3.weight(.bold))
                            Text("Tus finanzas personales, sin internet")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    LabeledContent("Versión") {
                        Text(version)
                    }
                }

                Section {
                    Label("Todo se guarda solo en tu iPhone.", systemImage: "iphone")
                    Label("No hay cuentas ni registro de usuario.", systemImage: "person.crop.circle.badge.xmark")
                    Label("No se envía información a internet ni a terceros.", systemImage: "wifi.slash")
                    Label("Sin anuncios ni rastreadores.", systemImage: "eye.slash")
                } header: {
                    Text("Tu privacidad")
                } footer: {
                    Text("Las únicas notificaciones son las que activas tú en «Recordatorios», y se generan en tu propio teléfono.")
                }

                Section {
                    Text("Los ingresos mensuales, los intereses, las cuotas y los aportes sugeridos a las metas son estimaciones para ayudarte a organizarte; pueden diferir de lo que cobra tu banco o acreedor. Mivra no ofrece asesoría financiera, legal ni tributaria. Para decisiones importantes consulta a un profesional o a tu entidad financiera.")
                        .font(.subheadline)
                } header: {
                    Text("Importante")
                }

                Section {
                    Text("Si borras la app del iPhone, sus datos se pierden. Guarda una copia de vez en cuando desde «Copia de seguridad».")
                        .font(.subheadline)
                } header: {
                    Text("Tus datos")
                }
            }
            .navigationTitle("Acerca de Mivra")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { cerrar() }
                }
            }
        }
    }
}

#Preview {
    AcercaDeView()
}
