import '../../domain/reglas/costo_compra.dart';
import '../../domain/reglas/venta.dart';
import '../db/base_datos.dart';

/// Un animal dentro de una venta, con todo lo que hace falta para pintar su
/// renglón y su comparación contra lo que costó.
class RenglonVenta {
  const RenglonVenta({
    required this.animal,
    required this.numeroArete,
    required this.pesoVentaKg,
    required this.precioPorKilo,
    required this.datos,
    required this.resultado,
  });

  final Animal animal;
  final String? numeroArete;
  final double? pesoVentaKg;
  final double? precioPorKilo;
  final AnimalEnVenta datos;
  final ResultadoVenta resultado;

  String get titulo => numeroArete ?? (animal.apodo ?? 'Sin arete');
  bool get pesado => pesoVentaKg != null;
}

/// Una venta completa, con sus totales.
class VentaArmada {
  const VentaArmada({required this.venta, required this.renglones});

  final LoteVenta venta;
  final List<RenglonVenta> renglones;

  bool get cerrada => venta.cerradoEn != null;
  int get cabezas => renglones.length;
  int get sinPesar => renglones.where((r) => !r.pesado).length;

  ({
    double importe,
    double diferencia,
    double kilos,
    int conImporte,
    int sinImporte,
    int conDiferencia,
  }) get total => totalDeVenta(
        [for (final r in renglones) r.resultado],
        [for (final r in renglones) r.datos],
      );
}

class RepoVentas {
  RepoVentas(this.db);

  final BaseDatos db;

  /// Arma la venta con sus cuentas hechas.
  ///
  /// El cálculo vive en `domain/reglas/venta.dart`, sin drift ni Flutter, y
  /// está cubierto por pruebas. Aquí solo se juntan los datos: el peso de venta
  /// sale de su evento de pesaje, y lo que costó sale de su compra.
  Future<VentaArmada?> verVenta(String ventaId) async {
    final venta = await db.venta(ventaId);
    if (venta == null) return null;

    final filas = await db.animalesDeVenta(ventaId);
    final renglones = <RenglonVenta>[];

    for (final fila in filas) {
      final animal = await db.animal(fila.animalId);
      if (animal == null) continue;

      final pesoVenta = await db.pesoDeVenta(animal.id);
      final compra = await _compraDe(animal.id);

      final datos = AnimalEnVenta(
        animalId: animal.id,
        pesoVentaKg: pesoVenta,
        precioVentaPorKilo: fila.precioPorKilo,
        fechaVenta: venta.fecha,
        pesoCompraKg: compra?.pesoKg,
        costoCompra: compra?.costo,
        fechaCompra: compra?.fecha,
      );

      renglones.add(
        RenglonVenta(
          animal: animal,
          numeroArete: (await db.areteVigente(animal.id))?.numero,
          pesoVentaKg: pesoVenta,
          precioPorKilo: fila.precioPorKilo,
          datos: datos,
          resultado: calcularVenta(datos),
        ),
      );
    }

    return VentaArmada(venta: venta, renglones: renglones);
  }

  /// Lo que costó un animal, si es que se compró y se capturó el precio.
  Future<({double? costo, double? pesoKg, int? fecha})?> _compraDe(
    String animalId,
  ) async {
    final fila = await db.compraDelAnimal(animalId);
    if (fila == null) return null;

    final lote = await db.loteCompra(fila.loteCompraId);
    if (lote == null) return null;

    final peso = await db.pesoDeCompra(animalId);
    final forma = (fila.formaCalculo ?? lote.formaCalculo) == 'porCabeza'
        ? FormaCotizacion.porCabeza
        : FormaCotizacion.porKilo;

    final costo = costoDelAnimal(
      CompraDeAnimal(
        forma: forma,
        precioPorKilo: fila.precioPorKilo ?? lote.precioPorKilo,
        precioPorCabeza: fila.precioPorCabeza,
        pesoCompraKg: peso,
      ),
    );

    return (costo: costo.total, pesoKg: peso, fecha: lote.fecha);
  }
}
