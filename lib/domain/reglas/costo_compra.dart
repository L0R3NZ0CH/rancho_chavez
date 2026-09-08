/// Cuanto costo cada animal de un lote de compra.
///
/// Este archivo no sabe de drift ni de Flutter. Recibe datos planos y devuelve
/// numeros, porque de aqui sale la cifra con la que se decide si una compra
/// estuvo bien hecha, y una cifra asi tiene que poder leerse y probarse sin
/// entender SQL.
library;

/// Como se cotizo la compra.
enum FormaCalculo {
  /// Tanto el kilo, sobre el peso de recepcion.
  porKilo,

  /// Tanto la cabeza, sin importar el peso.
  porCabeza,
}

/// Como se reparten los gastos del lote: flete, comision, documentacion.
enum FormaProrrateo { porKilo, porCabeza }

/// Un animal dentro del lote, con lo que se sabe de el.
class AnimalDelLote {
  const AnimalDelLote({
    required this.animalId,
    this.pesoCompraKg,
    this.costoIndividual,
  });

  final String animalId;

  /// Peso al recibirlo. Nulo cuando no se peso.
  final double? pesoCompraKg;

  /// Precio negociado para este animal en concreto, cuando lo hubo.
  ///
  /// El precio varia por temporada y por peso final, asi que dentro de un mismo
  /// lote puede haber animales a precios distintos.
  final double? costoIndividual;
}

/// Lo que costo un animal, y que tan confiable es esa cifra.
class CostoAnimal {
  const CostoAnimal({
    required this.animalId,
    required this.costoBase,
    required this.gastosAsignados,
    required this.esProrrateado,
  });

  final String animalId;

  /// Lo que costo el animal sin contar los gastos del lote.
  final double costoBase;

  /// La parte de flete, comision y documentacion que le toca.
  final double gastosAsignados;

  double get total => costoBase + gastosAsignados;

  /// Verdadero cuando el costo base **no** es un dato real de este animal sino
  /// un reparto del total del lote.
  ///
  /// Se marca en pantalla a proposito. Una compra por cabeza siempre reparte;
  /// una compra por kilo solo reparte cuando falto pesar al animal, y ese caso
  /// hay que poder verlo, porque es un hueco que se puede tapar yendo a pesar.
  final bool esProrrateado;
}

/// Reparte el costo de un lote entre sus animales.
///
/// El orden de las reglas es el que importa:
///
///   1. Un precio individual gana siempre. Es el dato mas fiel que existe.
///   2. Por kilo, con peso de recepcion, da un costo **real**.
///   3. Por kilo **sin** peso, o por cabeza, obliga a repartir. Se marca.
///
/// Lo que queda del total del lote despues de descontar los precios
/// individuales y los costos por kilo es lo que se reparte entre los que no
/// tienen dato propio. Asi la suma de los costos siempre cuadra con el total
/// pagado, que es la propiedad que hace que la cifra sirva para algo.
List<CostoAnimal> calcularCostosLote({
  required List<AnimalDelLote> animales,
  required FormaCalculo forma,
  required double montoTotal,
  double precioPorKilo = 0,
  double gastos = 0,
  FormaProrrateo prorrateoGastos = FormaProrrateo.porCabeza,
}) {
  if (animales.isEmpty) return const [];

  final costosBase = <String, double>{};
  final prorrateados = <String>{};

  // Paso 1: lo que ya tiene precio propio.
  var asignado = 0.0;
  final sinDatoPropio = <AnimalDelLote>[];

  for (final a in animales) {
    final individual = a.costoIndividual;
    if (individual != null) {
      costosBase[a.animalId] = individual;
      asignado += individual;
      continue;
    }

    if (forma == FormaCalculo.porKilo &&
        a.pesoCompraKg != null &&
        precioPorKilo > 0) {
      final costo = a.pesoCompraKg! * precioPorKilo;
      costosBase[a.animalId] = costo;
      asignado += costo;
      continue;
    }

    sinDatoPropio.add(a);
  }

  // Paso 2: lo que sobra del total se reparte por cabeza entre los que no
  // tienen dato propio. Si el total no alcanza (por ejemplo, porque los
  // precios individuales ya lo cubrieron), el reparto es cero y no negativo:
  // un costo negativo no significa nada y ensuciaria todas las sumas.
  if (sinDatoPropio.isNotEmpty) {
    final resto = montoTotal - asignado;
    final porCabeza = resto <= 0 ? 0.0 : resto / sinDatoPropio.length;
    for (final a in sinDatoPropio) {
      costosBase[a.animalId] = porCabeza;
      prorrateados.add(a.animalId);
    }
  }

  // Paso 3: los gastos del lote, repartidos aparte.
  final gastosPorAnimal = _repartirGastos(
    animales: animales,
    gastos: gastos,
    forma: prorrateoGastos,
  );

  return [
    for (final a in animales)
      CostoAnimal(
        animalId: a.animalId,
        costoBase: costosBase[a.animalId] ?? 0,
        gastosAsignados: gastosPorAnimal[a.animalId] ?? 0,
        esProrrateado: prorrateados.contains(a.animalId),
      ),
  ];
}

Map<String, double> _repartirGastos({
  required List<AnimalDelLote> animales,
  required double gastos,
  required FormaProrrateo forma,
}) {
  if (gastos <= 0 || animales.isEmpty) {
    return {for (final a in animales) a.animalId: 0.0};
  }

  if (forma == FormaProrrateo.porKilo) {
    final kilosTotales = animales.fold<double>(
      0,
      (suma, a) => suma + (a.pesoCompraKg ?? 0),
    );
    // Sin pesos no se puede repartir por kilo. Se cae a por cabeza en vez de
    // dividir entre cero o dejar los gastos fuera de la cuenta.
    if (kilosTotales > 0) {
      return {
        for (final a in animales)
          a.animalId: gastos * ((a.pesoCompraKg ?? 0) / kilosTotales),
      };
    }
  }

  final porCabeza = gastos / animales.length;
  return {for (final a in animales) a.animalId: porCabeza};
}

/// Lo que se pago en total por el lote, ya con gastos.
double totalDelLote({required double montoTotal, double gastos = 0}) =>
    montoTotal + gastos;
