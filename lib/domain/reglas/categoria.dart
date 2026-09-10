import '../modelos/tipos.dart';

/// A que edad deja de ser becerro y a que edad es adulto.
///
/// Viven en Ajustes y el dueno los puede mover cuando quiera. Los valores por
/// omision son un punto de partida, no una verdad: cada rancho maneja los
/// suyos.
class UmbralesCategoria {
  const UmbralesCategoria({this.mesesDestete = 8, this.mesesAdulto = 24});

  /// Edad a la que se da por destetado un animal del que no se registro el
  /// destete. Si el destete si esta registrado, manda el hecho, no la edad.
  final int mesesDestete;

  /// Edad a la que un macho destetado pasa de torete a toro.
  final int mesesAdulto;
}

/// Todo lo que hace falta para clasificar a un animal.
///
/// Es un tipo plano: no sabe de drift ni de Flutter. Quien lo arma es el
/// repositorio, leyendo los eventos del animal.
class DatosCategoria {
  const DatosCategoria({
    required this.sexo,
    required this.fechaNacimiento,
    required this.tieneDestete,
    required this.tieneParto,
    this.correccionManual,
  });

  final Sexo sexo;

  /// AAAAMMDD, o null cuando no se sabe.
  ///
  /// Se acepta que no se sepa a proposito. Exigirla volveria laborioso el alta
  /// de un lote comprado, que llega sin papeles y habria que revisar diente por
  /// diente. Un animal sin fecha simplemente queda sin clasificar.
  final int? fechaNacimiento;

  /// Hay un evento de destete registrado.
  final bool tieneDestete;

  /// Hay al menos un parto registrado. Es lo que separa vaca de vaquilla.
  final bool tieneParto;

  /// Categoria puesta a mano por el dueno, que gana sobre el calculo.
  ///
  /// No es una columna que se pise: viene del ultimo evento de correccion, con
  /// su fecha y su motivo, asi que la regla de eventos sigue en pie y queda el
  /// rastro de quien la puso y cuando.
  final Categoria? correccionManual;
}

/// Deriva la categoria del animal. Nunca se captura, siempre se calcula.
///
/// El orden de las reglas importa:
///
///   1. Una correccion a mano gana sobre todo lo demas.
///   2. Una hembra que ya pario es vaca, tenga la edad que tenga. El parto es
///      un hecho; la edad es una estimacion.
///   3. Sin fecha de nacimiento y sin destete no se puede decir nada, y decir
///      "becerro" seria inventar.
///   4. El destete registrado manda sobre la edad. Hay becerros destetados a
///      los seis meses y otros a los diez.
Categoria calcularCategoria(
  DatosCategoria datos, {
  required int hoy,
  UmbralesCategoria umbrales = const UmbralesCategoria(),
}) {
  final correccion = datos.correccionManual;
  if (correccion != null) return correccion;

  if (datos.sexo == Sexo.hembra && datos.tieneParto) return Categoria.vaca;

  final edad = edadEnMeses(datos.fechaNacimiento, hoy);

  if (edad == null && !datos.tieneDestete) return Categoria.sinClasificar;

  final destetado = datos.tieneDestete || (edad! >= umbrales.mesesDestete);

  if (!destetado) {
    return datos.sexo == Sexo.hembra ? Categoria.becerra : Categoria.becerro;
  }

  if (datos.sexo == Sexo.hembra) return Categoria.vaquilla;

  // Macho destetado. Sin edad no se puede saber si ya es adulto, y torete es
  // la respuesta prudente: se corrige sola en cuanto se capture la fecha.
  if (edad == null) return Categoria.torete;
  return edad >= umbrales.mesesAdulto ? Categoria.toro : Categoria.torete;
}

/// Cuando le toca cambiar de categoria, si es que le toca.
///
/// Sirve para avisar en la pantalla de inicio sin guardar nada: la fecha del
/// cambio es la de nacimiento mas el umbral, asi que se calcula, y hasta se
/// puede saber por adelantado.
///
/// Devuelve null cuando no hay cambio previsible: sin fecha de nacimiento, con
/// correccion a mano puesta, o cuando ya llego a su categoria final.
int? proximoCambioDeCategoria(
  DatosCategoria datos, {
  required int hoy,
  UmbralesCategoria umbrales = const UmbralesCategoria(),
}) {
  if (datos.correccionManual != null) return null;
  if (datos.fechaNacimiento == null) return null;
  if (datos.sexo == Sexo.hembra && datos.tieneParto) return null;

  final actual = calcularCategoria(datos, hoy: hoy, umbrales: umbrales);

  final cumple = switch (actual) {
    Categoria.becerro || Categoria.becerra => umbrales.mesesDestete,
    Categoria.torete => umbrales.mesesAdulto,
    // Vaquilla pasa a vaca por un parto, no por el calendario. Toro y vaca ya
    // son finales.
    _ => null,
  };
  if (cumple == null) return null;

  return sumaMeses(datos.fechaNacimiento!, cumple);
}

/// Edad en meses cumplidos, o null si no se sabe la fecha de nacimiento.
///
/// Trabaja sobre AAAAMMDD directamente para no pasar por DateTime, que
/// arrastraria zona horaria a un calculo que es puro calendario.
int? edadEnMeses(int? fechaNacimiento, int hoy) {
  if (fechaNacimiento == null) return null;

  final anioN = fechaNacimiento ~/ 10000;
  final mesN = (fechaNacimiento ~/ 100) % 100;
  final diaN = fechaNacimiento % 100;

  final anioH = hoy ~/ 10000;
  final mesH = (hoy ~/ 100) % 100;
  final diaH = hoy % 100;

  var meses = (anioH - anioN) * 12 + (mesH - mesN);
  // Si todavia no llega al dia del mes, el mes no esta cumplido.
  if (diaH < diaN) meses--;

  return meses < 0 ? 0 : meses;
}

/// Suma meses a una fecha AAAAMMDD, recortando el dia cuando el mes destino es
/// mas corto (un 31 de enero mas un mes cae el 28 o 29 de febrero).
int sumaMeses(int fecha, int meses) {
  final anio = fecha ~/ 10000;
  final mes = (fecha ~/ 100) % 100;
  final dia = fecha % 100;

  final total = (anio * 12 + (mes - 1)) + meses;
  final anioDestino = total ~/ 12;
  final mesDestino = total % 12 + 1;

  final diaDestino = dia > diasDelMes(anioDestino, mesDestino)
      ? diasDelMes(anioDestino, mesDestino)
      : dia;

  return anioDestino * 10000 + mesDestino * 100 + diaDestino;
}

int diasDelMes(int anio, int mes) {
  const dias = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  if (mes == 2 && esBisiesto(anio)) return 29;
  return dias[mes - 1];
}

bool esBisiesto(int anio) =>
    (anio % 4 == 0 && anio % 100 != 0) || anio % 400 == 0;

/// Cuando avisar que un animal lleva demasiado tiempo en la misma categoria.
///
/// Un becerro no se queda becerro para siempre. Como la categoria se captura y
/// nadie la va a andar actualizando, la app avisa —no cambia nada sola, porque
/// el juicio es del dueno.
///
/// Los meses son los mismos umbrales configurables de la categoria: si un
/// animal lleva mas de [UmbralesCategoria.mesesDestete] como becerro o becerra,
/// o mas de [UmbralesCategoria.mesesAdulto] como torete o vaquilla, ya se
/// quedo corto el nombre.
int? mesesLimitePara(Categoria categoria, UmbralesCategoria umbrales) =>
    switch (categoria) {
      Categoria.becerro || Categoria.becerra => umbrales.mesesDestete,
      Categoria.torete || Categoria.vaquilla => umbrales.mesesAdulto,
      // Vaca y toro ya son finales; sin clasificar no tiene de que avisar.
      _ => null,
    };

/// Cuantos meses lleva el animal en su categoria, y si ya es demasiado.
///
/// [desde] es la fecha en que se le puso esa categoria, en AAAAMMDD. Devuelve
/// null cuando no hay nada que avisar.
({int meses, int limite})? avisoDeCategoria({
  required Categoria categoria,
  required int? desde,
  required int hoy,
  UmbralesCategoria umbrales = const UmbralesCategoria(),
}) {
  if (desde == null) return null;

  final limite = mesesLimitePara(categoria, umbrales);
  if (limite == null) return null;

  final meses = edadEnMeses(desde, hoy);
  if (meses == null || meses < limite) return null;

  return (meses: meses, limite: limite);
}
