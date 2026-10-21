import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Copia de seguridad: guarda todos tus datos en un archivo .json (por ejemplo en Archivos,
/// iCloud Drive, AirDrop o WhatsApp) y permite restaurarlos desde ese archivo.
struct RespaldoView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar

    /// Archivo temporal con la copia lista para compartir.
    @State private var archivo: URL?
    @State private var contenido: [String] = []

    @State private var eligiendoArchivo = false
    @State private var respaldoLeido: RespaldoDatos?
    @State private var mensajeError: String?
    @State private var restaurado = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if contenido.isEmpty {
                        Text("Todavía no hay datos para guardar.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(contenido, id: \.self) { linea in
                            Label(linea, systemImage: "checkmark.circle")
                        }
                    }

                    if let archivo {
                        ShareLink(item: archivo) {
                            Label("Guardar o compartir copia", systemImage: "square.and.arrow.up")
                                .font(.body.weight(.semibold))
                        }
                    }
                } header: {
                    Text("Guardar copia")
                } footer: {
                    Text("Se crea un archivo con todo lo que tienes ahora. Elige «Guardar en Archivos» para dejarlo en tu iPhone o en iCloud Drive, o envíalo por AirDrop, WhatsApp o correo.")
                }

                Section {
                    Button {
                        eligiendoArchivo = true
                    } label: {
                        Label("Restaurar desde un archivo", systemImage: "arrow.counterclockwise")
                    }
                } header: {
                    Text("Restaurar")
                } footer: {
                    Text("Elige un archivo de copia que hayas guardado antes. Reemplaza todo lo que hay ahora en la app, así que guarda primero una copia de lo actual.")
                }

                Section {
                    Text("Como instalas la app con Sideloadly, si algún día la borras del iPhone se pierden sus datos. Guarda una copia de vez en cuando (por ejemplo cada semana) y envíatela por WhatsApp o déjala en iCloud Drive.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Consejo")
                }
            }
            .navigationTitle("Copia de seguridad")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { cerrar() }
                }
            }
            .onAppear { prepararArchivo() }
            .fileImporter(isPresented: $eligiendoArchivo, allowedContentTypes: [.json]) { resultado in
                leerArchivo(resultado)
            }
            .confirmationDialog(
                "¿Reemplazar tus datos actuales?",
                isPresented: Binding(
                    get: { respaldoLeido != nil },
                    set: { if !$0 { respaldoLeido = nil } }
                ),
                titleVisibility: .visible,
                presenting: respaldoLeido
            ) { copia in
                Button("Reemplazar con esta copia", role: .destructive) { restaurar(copia) }
                Button("Cancelar", role: .cancel) { }
            } message: { copia in
                Text("Se borrará todo lo que hay ahora en la app y se cargará la copia del \(copia.fecha.formatted(date: .long, time: .shortened)) (\(copia.resumen.joined(separator: ", "))). Esta acción no se puede deshacer.")
            }
            .alert("No se pudo completar", isPresented: Binding(
                get: { mensajeError != nil },
                set: { if !$0 { mensajeError = nil } }
            )) {
                Button("Entendido", role: .cancel) { }
            } message: {
                Text(mensajeError ?? "")
            }
            .alert("Copia restaurada", isPresented: $restaurado) {
                Button("Listo", role: .cancel) { }
            } message: {
                Text("Tus datos se cargaron desde la copia.")
            }
        }
    }

    // MARK: Acciones

    /// Genera el archivo con los datos actuales para que `ShareLink` pueda enviarlo.
    private func prepararArchivo() {
        do {
            let respaldo = try RespaldoServicio.crear(en: contexto)
            let datos = try RespaldoServicio.codificar(respaldo)

            let formateador = DateFormatter()
            formateador.locale = Locale(identifier: "en_US_POSIX")
            formateador.dateFormat = "yyyy-MM-dd"
            let nombre = "MisFinanzas-\(formateador.string(from: Date.now)).json"

            let url = FileManager.default.temporaryDirectory.appendingPathComponent(nombre)
            try datos.write(to: url, options: .atomic)

            archivo = url
            contenido = respaldo.resumen
        } catch {
            archivo = nil
            mensajeError = "No se pudo preparar la copia: \(error.localizedDescription)"
        }
    }

    /// Lee el archivo elegido y, si es válido, pide confirmación antes de reemplazar los datos.
    private func leerArchivo(_ resultado: Result<URL, Error>) {
        do {
            let url = try resultado.get()
            let conAcceso = url.startAccessingSecurityScopedResource()
            defer {
                if conAcceso { url.stopAccessingSecurityScopedResource() }
            }
            let datos = try Data(contentsOf: url)
            respaldoLeido = try RespaldoServicio.leer(datos)
        } catch {
            mensajeError = error.localizedDescription
        }
    }

    private func restaurar(_ copia: RespaldoDatos) {
        do {
            try RespaldoServicio.restaurar(copia, en: contexto)
            Recordatorios.actualizar(contexto: contexto)
            prepararArchivo()
            restaurado = true
        } catch {
            mensajeError = "No se pudo restaurar la copia: \(error.localizedDescription)"
        }
    }
}

#Preview {
    RespaldoView()
        .modelContainer(DatosEjemplo.contenedor)
}
