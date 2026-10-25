import SwiftUI
import SwiftData

/// Sección de un formulario para elegir de qué cuenta sale (o a cuál entra) el dinero.
/// Si todavía no hay cuentas creadas, no se muestra nada: la app funciona igual que antes.
struct SeccionCuenta: View {
    @Binding var cuentaId: String?
    var titulo: String = "Cuenta"
    var pie: String? = nil

    @Query(sort: \Cuenta.fechaCreacion) private var cuentas: [Cuenta]

    /// Si la cuenta elegida ya no existe (se borró), el selector queda en «Sin cuenta».
    private var seleccion: Binding<String?> {
        Binding(
            get: {
                guard let cuentaId, cuentas.contains(where: { $0.identificador == cuentaId }) else { return nil }
                return cuentaId
            },
            set: { cuentaId = $0 }
        )
    }

    var body: some View {
        if !cuentas.isEmpty {
            Section {
                Picker(titulo, selection: seleccion) {
                    Text("Sin cuenta").tag(String?.none)
                    ForEach(cuentas) { cuenta in
                        Label(cuenta.nombre, systemImage: cuenta.tipo.icono)
                            .tag(String?.some(cuenta.identificador))
                    }
                }
            } footer: {
                if let pie {
                    Text(pie)
                }
            }
        }
    }
}
