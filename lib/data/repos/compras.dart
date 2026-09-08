import '../../domain/reglas/costo_compra.dart';
import '../db/base_datos.dart';

/// Un animal del lote con su costo ya calculado y con lo que hace falta para
/// pintarlo.
class RenglonCompra {
  const RenglonCompra({
    required this.animal,
    required this.numeroArete,
    required this.pesoCompraKg,
    required this.costo,
  });

  final Animal animal;
  final String? numeroArete;
  final double? pesoCompraKg;
  final CostoAnimal costo;

  String get titulo => numeroArete ?? (animal.apodo ?? 'Sin arete');
}

/// El lote completo, con sus costos repartidos.
class LoteConCostos {
  const LoteConCostos({
    required this.lote,
    required this.renglones,
    required this.gastos,
  });

  final LoteCompra lote;
  final List<RenglonCompra> renglones;
  final double gastos;

  int get cabezas => renglones.length;

  double get total => lote.montoTotal + gastos;

  double get kilosTotales => renglones.fold<double>(
        0,
        (s, r) => s + (r.pesoCompraKg ?? 0),
      );

  /// Cuantos animales tienen un costo repartido en vez de real.
  ///
  /// Se muestra en pantalla porque es un hueco que se puede tapar: en una
  /// compra por kilo, basta con ir a pesar al animal que falto.
  int get prorrateados => renglones.where((r) => r.costo.esProrrateado).length;

  double get costoPromedio =>
      renglones.isEmpty ? 0 : total / renglones.length;
}

class RepoCompras {
  RepoCompras(this.db);

  final BaseDatos db;

  /// Arma el lote con los costos ya calculados.
  ///
  /// El calculo en si vive en `domain/reglas/costo_compra.dart`, sin drift ni
  /// Flutter, y esta cubierto por pruebas. Aqui solo se juntan los datos.
  Future<LoteConCostos?> verLote(String loteId) async {
    final lote = await db.loteCompra(loteId);
    if (lote == null) return null;

    final enLote = await db.animalesDelLote(loteId);
    final gastos = await db.gastosDelLote(loteId);
    final sumaGastos = gastos.fold<double>(0, (s, g) => s + g.monto);

    final animales = <Animal>[];
    final pesos = <String, double?>{};
    final aretes = <String, String?>{};

    for (final fila in enLote) {
      final animal = await (db.select(db.animales)
            ..where((a) => a.id.equals(fila.animalId)))
          .getSingleOrNull();
      if (animal == null) continue;
      animales.add(animal);
      pesos[animal.id] = await db.pesoDeCompra(animal.id);
      aretes[animal.id] = (await db.areteVigente(animal.id))?.numero;
    }

    final costos = calcularCostosLote(
      animales: [
        for (final fila in enLote)
          if (animales.any((a) => a.id == fila.animalId))
            AnimalDelLote(
              animalId: fila.animalId,
              pesoCompraKg: pesos[fila.animalId],
              costoIndividual: fila.costoIndividual,
            ),
      ],
      forma: lote.formaCalculo == 'porKilo'
          ? FormaCalculo.porKilo
          : FormaCalculo.porCabeza,
      precioPorKilo: lote.precioPorKilo ?? 0,
      montoTotal: lote.montoTotal,
      gastos: sumaGastos,
      prorrateoGastos: lote.formaProrrateoGastos == 'porKilo'
          ? FormaProrrateo.porKilo
          : FormaProrrateo.porCabeza,
    );

    final porAnimal = {for (final c in costos) c.animalId: c};

    return LoteConCostos(
      lote: lote,
      gastos: sumaGastos,
      renglones: [
        for (final a in animales)
          if (porAnimal[a.id] != null)
            RenglonCompra(
              animal: a,
              numeroArete: aretes[a.id],
              pesoCompraKg: pesos[a.id],
              costo: porAnimal[a.id]!,
            ),
      ],
    );
  }
}
