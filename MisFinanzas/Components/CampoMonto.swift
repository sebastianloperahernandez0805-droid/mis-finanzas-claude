import SwiftUI

/// Fila de formulario para escribir un monto con teclado numérico decimal.
/// Trabaja con texto (`String`) para respetar el separador decimal de la región del iPhone;
/// luego se convierte con `Formato.numero(desde:)`.
struct CampoMonto: View {
    let titulo: String
    @Binding var texto: String

    var body: some View {
        HStack {
            Text(titulo)
            Spacer()
            Text(Formato.simboloMoneda)
                .foregroundStyle(.secondary)
            TextField("0", text: $texto)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(minWidth: 90)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    Form {
        CampoMonto(titulo: "Monto", texto: .constant("25000"))
    }
}
