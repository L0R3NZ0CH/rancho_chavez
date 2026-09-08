import '../../domain/reglas/costo_compra.dart';
import '../db/base_datos.dart';

/// Un animal dentro de una compra, con su trato ya resuelto y su costo.
class RenglonCompra {
  const RenglonCompra({
    required this.animal,
    required this.numeroArete,
    required this.vendedor,
    required this.forma,
    required this.precioPorKilo,
    required this.precioPorCabeza,
    required this.pesoCompraKg,
    required this.costo,
    required this.tratoPropio,
  });

  final Animal animal;
  final String? numeroArete;

  /// Ya resuelto: el propio del animal, o el heredado de la compra.
  final String vendedor;
  final FormaCotizacion forma;
  final double? precioPorKilo;
  final double? precioPorCabeza;
  final double? pesoCompraKg;
  final CostoAnimal costo;

  /// Verdadero cuando este animal trae vendedor o precio propios, distintos de
  /// los de la compra. Se marca en pantalla para que se vea de un vistazo
  /// cuales se negociaron aparte.
  final bool tratoPropio;

  String get titulo => numeroArete ?? (animal.apodo ?? 'Sin arete');
}

/// Una compra completa, con lo que se sabe y lo que falta.
class CompraConCostos {
  const CompraConCostos({required this.lote, required this.renglones});

  final LoteCompra lote;
  final List<RenglonCompra> renglones;

  int get cabezas => renglones.length;

  double get kilosTotales => renglones.fold<double>(
        0,
        (s, r) => s + (r.pesoCompraKg ?? 0),
      );

  ({double total, int conocidos, int desconocidos}) get resumen =>
      sumaCostos([for (final r in renglones) r.costo]);

  /// Cuantos animales no tienen costo porque falta pesarlos.
  int get faltaPesar =>
      renglones.where((r) => r.costo.falta == FaltaDato.peso).length;

  /// Cuantos no tienen costo porque falta el precio.
  int get faltaPrecio =>
      renglones.where((r) => r.costo.falta == FaltaDato.precio).length;
}

class RepoCompras {
  RepoCompras(this.db);

  final BaseDatos db;

  /// Arma la compra con los costos ya calculados.
  ///
  /// El calculo vive en `domain/reglas/costo_compra.dart`, sin drift ni
  /// Flutter, y esta cubierto por pruebas. Aqui solo se resuelve que dato usar:
  /// el propio del animal o el heredado de la compra.
  Future<CompraConCostos?> verCompra(String loteId) async {
    final lote = await db.loteCompra(loteId);
    if (lote == null) return null;

    final filas = await db.animalesDelLote(loteId);
    final renglones = <RenglonCompra>[];

    for (final fila in filas) {
      final animal = await db.animal(fila.animalId);
      if (animal == null) continue;

      final vendedor = propioOHeredado(fila.vendedor, lote.vendedor)!;
      final formaTexto = propioOHeredado(fila.formaCalculo, lote.formaCalculo);
      final forma = formaTexto == 'porCabeza'
          ? FormaCotizacion.porCabeza
          : FormaCotizacion.porKilo;
      final precioKilo = propioOHeredado(fila.precioPorKilo, lote.precioPorKilo);
      final peso = await db.pesoDeCompra(animal.id);

      renglones.add(
        RenglonCompra(
          animal: animal,
          numeroArete: (await db.areteVigente(animal.id))?.numero,
          vendedor: vendedor,
          forma: forma,
          precioPorKilo: precioKilo,
          precioPorCabeza: fila.precioPorCabeza,
          pesoCompraKg: peso,
          tratoPropio: fila.vendedor != null ||
              fila.formaCalculo != null ||
              fila.precioPorKilo != null,
          costo: costoDelAnimal(
            CompraDeAnimal(
              forma: forma,
              precioPorKilo: precioKilo,
              precioPorCabeza: fila.precioPorCabeza,
              pesoCompraKg: peso,
            ),
          ),
        ),
      );
    }

    return CompraConCostos(lote: lote, renglones: renglones);
  }
}
