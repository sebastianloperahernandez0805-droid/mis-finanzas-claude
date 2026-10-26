// Cifrado de los datos con la contraseña de la persona.
// Contraseña -> clave con PBKDF2 (SHA-256) -> los datos se cifran con AES-GCM de 256 bits.
// Todo ocurre en el dispositivo con la API nativa del navegador (WebCrypto): no se envía nada.

const codificador = new TextEncoder();
const decodificador = new TextDecoder();

export const ITERACIONES = 310000;

export function hayCripto() {
  return Boolean(globalThis.crypto && crypto.subtle && globalThis.isSecureContext);
}

export function aB64(buffer) {
  const bytes = new Uint8Array(buffer);
  let texto = '';
  for (let i = 0; i < bytes.length; i += 0x8000) {
    texto += String.fromCharCode.apply(null, bytes.subarray(i, i + 0x8000));
  }
  return btoa(texto);
}

export function deB64(texto) {
  const binario = atob(texto);
  const bytes = new Uint8Array(binario.length);
  for (let i = 0; i < binario.length; i++) bytes[i] = binario.charCodeAt(i);
  return bytes;
}

export function saltNuevo() {
  return crypto.getRandomValues(new Uint8Array(16));
}

/** Deriva la clave AES a partir de la contraseña. La clave no se puede exportar. */
export async function derivarClave(contrasena, salt, iteraciones = ITERACIONES) {
  const base = await crypto.subtle.importKey(
    'raw', codificador.encode(contrasena.normalize('NFKC')), 'PBKDF2', false, ['deriveKey']
  );
  return crypto.subtle.deriveKey(
    { name: 'PBKDF2', salt, iterations: iteraciones, hash: 'SHA-256' },
    base,
    { name: 'AES-GCM', length: 256 },
    false,
    ['encrypt', 'decrypt']
  );
}

export async function cifrar(clave, texto) {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const cifrado = await crypto.subtle.encrypt({ name: 'AES-GCM', iv }, clave, codificador.encode(texto));
  return JSON.stringify({ v: 1, iv: aB64(iv), ct: aB64(cifrado) });
}

/** Devuelve el texto original, o lanza un error si la clave no es la correcta. */
export async function descifrar(clave, blob) {
  const { iv, ct } = JSON.parse(blob);
  const plano = await crypto.subtle.decrypt({ name: 'AES-GCM', iv: deB64(iv) }, clave, deB64(ct));
  return decodificador.decode(plano);
}
