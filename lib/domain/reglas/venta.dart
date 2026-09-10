/// Qué hizo un animal entre que se compró y que se vende.
///
/// Este archivo no sabe de drift ni de Flutter. De aquí sale la cifra con la
/// que se juzga si una engorda valió la pena, y una cifra así tiene que poder
/// leerse y probarse sin entender SQL.
library;

import 'estado_animal.dart';

/// Los datos de un animal que se está vendiendo.
class AnimalEnVenta {
  const AnimalEnVenta({
    required this.animalId,
    this.pesoVentaKg,
    this.precioVentaPorKilo,
    this.fechaVenta,
    this.pesoCompraKg,
    this.costoCompra,
    this.fechaCompra,
  });

  final String animalId;

  /// Lo que pesó al venderse. Nulo mientras no se pese.
  final double? pesoVentaKg;

  /// Lo acordado con el comprador. Nulo mientras no se capture: la columna
  /// empieza vacía a propósito, porque el precio puede llegar después.
  final double? precioVentaPorKilo;

  final int? fechaVenta;

  /// Lo que pesaba al recibirlo, y lo que costó. Nulos cuando el animal nació
  /// en el rancho o cuando se compró sin capturar el precio.
  final double? pesoCompraKg;
  final double? costoCompra;
  final int? fechaCompra;
}

/// El resultado de vender un animal.
class ResultadoVenta {
  const ResultadoVenta({
    required this.animalId,
    required this.importe,
    required this.diferencia,
    required this.kilosGanados,
    required this.dias,
  });

  final String animalId;

  /// Lo que se cobra por este animal. Nulo cuando falta el peso o el precio:
  /// **no se inventa un cero**, porque un cero se lee como si el animal se
  /// hubiera regalado.
  final double? importe;

  /// Importe menos lo que costó. Nulo cuando no hay con qué comparar: el animal
  /// nació aquí, o se compró sin capturar el precio.
  final double? diferencia;

  /// Lo que engordó. Nulo si falta alguno de los dos pesajes.
  final double? kilosGanados;

  /// Días entre la compra y la venta.
  final int? dias;

  /// Kilos por día. Nulo si no se puede saber, o si los días son cero: dividir
  /// entre cero daría infinito y se pintaría como un número.
  double? get gananciaDiaria {
    final kilos = kilosGanados;
    final d = dias;
    if (kilos == null || d == null || d <= 0) return null;
    return kilos / d;
  }

  bool get seSabeImporte => importe != null;
}

ResultadoVenta calcularVenta(AnimalEnVenta a) {
  final peso = a.pesoVentaKg;
  final precio = a.precioVentaPorKilo;

  final double? importe;
  if (peso != null && peso > 0 && precio != null && precio > 0) {
    importe = peso * precio;
  } else {
    importe = null;
  }

  final costo = a.costoCompra;
  final diferencia = (importe != null && costo != null) ? importe - costo : null;

  final pesoCompra = a.pesoCompraKg;
  final kilosGanados =
      (peso != null && pesoCompra != null) ? peso - pesoCompra : null;

  final desde = a.fechaCompra;
  final hasta = a.fechaVenta;
  final dias = (desde != null && hasta != null) ? diasEntre(desde, hasta) : null;

  return ResultadoVenta(
    animalId: a.animalId,
    importe: importe,
    diferencia: diferencia,
    kilosGanados: kilosGanados,
    dias: dias,
  );
}

/// El total de una venta.
///
/// Los animales sin importe quedan **fuera** de la suma y se cuentan aparte.
/// Un total que los metiera como cero se leería como si estuviera completo, y
/// esa es justo la cifra con la que se cierra un trato.
({
  double importe,
  double diferencia,
  double kilos,
  int conImporte,
  int sinImporte,
  int conDiferencia,
}) totalDeVenta(List<ResultadoVenta> resultados, List<AnimalEnVenta> animales) {
  var importe = 0.0;
  var diferencia = 0.0;
  var conImporte = 0;
  var sinImporte = 0;
  var conDiferencia = 0;

  for (final r in resultados) {
    final i = r.importe;
    if (i == null) {
      sinImporte++;
    } else {
      importe += i;
      conImporte++;
    }
    final d = r.diferencia;
    if (d != null) {
      diferencia += d;
      conDiferencia++;
    }
  }

  final kilos = animales.fold<double>(
    0,
    (s, a) => s + (a.pesoVentaKg ?? 0),
  );

  return (
    importe: importe,
    diferencia: diferencia,
    kilos: kilos,
    conImporte: conImporte,
    sinImporte: sinImporte,
    conDiferencia: conDiferencia,
  );
}
