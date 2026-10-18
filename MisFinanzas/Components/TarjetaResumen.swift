import SwiftUI

/// Tarjeta pequeña con un dato clave: ícono, título, valor grande y subtítulo opcional.
/// Se usa en pares (dos por fila) en los resúmenes de cada módulo.
struct TarjetaResumen: View {
    let titulo: String
    let valor: String
    var subtitulo: String? = nil
    let icono: String
    var color: Color = Tema.acento

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            IconoCirculo(sistema: icono, color: color, tamano: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(titulo)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text(valor)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())

                if let subtitulo {
                    Text(subtitulo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .estiloTarjeta()
        .animation(.snappy, value: valor)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HStack(spacing: 12) {
        TarjetaResumen(titulo: "Ingreso mensual", valor: "$3.200.000",
                       subtitulo: "estimado", icono: "arrow.down.circle.fill", color: Tema.ingreso)
        TarjetaResumen(titulo: "Fuentes", valor: "3", icono: "list.bullet", color: .indigo)
    }
    .padding()
    .background(Tema.fondo)
}
