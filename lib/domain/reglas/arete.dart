/// Prefijo GS1 de Mexico.
///
/// Va codificado dentro del codigo de barras del arete pero no esta impreso en
/// la bandera. Salio en la primera lectura con aretes reales, el 7 de
/// septiembre de 2026: el codigo devolvio quince digitos y la bandera traia
/// doce.
const prefijoGs1Mexico = '484';

/// Largo del numero SINIIGA: dos de pais, dos de entidad y ocho del animal.
const largoSiniiga = 12;

/// Lo que devolvio el escaner, ya limpio.
typedef AreteLeido = ({String numero, String crudo, bool prefijoQuitado});

/// Deja solo digitos. Algunos lectores agregan prefijos, sufijos, espacios o un
/// salto de linea al final.
String soloDigitos(String valor) => valor.replaceAll(RegExp(r'\D'), '');

/// Si el numero tiene la forma de un SINIIGA.
///
/// No rechaza nada por si solo: sirve para avisar. Un codigo que no cumple es
/// un dato que hay que ver, no un error que haya que esconder.
bool pareceSiniiga(String valor) =>
    valor.length == largoSiniiga && RegExp(r'^\d{12}$').hasMatch(valor);

/// Convierte lo que devuelve el escaner en el numero que trae impreso el arete.
///
/// La identidad del animal son los **doce digitos impresos**, no los quince que
/// devuelve el codigo. No es una decision de estilo: el vaquero lee la bandera
/// con los ojos y teclea lo que ve cuando el arete esta demasiado sucio para
/// escanearse. Si el escaneo guardara quince digitos y la captura manual doce,
/// el mismo animal entraria dos veces con el historial partido, y nadie lo
/// notaria hasta tener cincuenta duplicados.
///
/// La regla lleva guarda a proposito. Solo quita el prefijo cuando el resultado
/// es exactamente el que esperamos:
///
///   - quince digitos que empiezan con 484  ->  se quitan los tres primeros
///   - cualquier otra cosa                  ->  no se toca
///
/// Asi un arete sin prefijo pasa derecho, y uno con un prefijo distinto se
/// muestra tal cual para que la persona decida, en vez de que la app adivine.
/// Solo se han visto dos aretes, probablemente del mismo lote, asi que todavia
/// no sabemos si el 484 sale en todos.
AreteLeido normalizaArete(String valorCrudo) {
  final digitos = soloDigitos(valorCrudo);

  if (digitos.length == largoSiniiga + prefijoGs1Mexico.length &&
      digitos.startsWith(prefijoGs1Mexico)) {
    return (
      numero: digitos.substring(prefijoGs1Mexico.length),
      crudo: valorCrudo,
      prefijoQuitado: true,
    );
  }

  return (numero: digitos, crudo: valorCrudo, prefijoQuitado: false);
}
