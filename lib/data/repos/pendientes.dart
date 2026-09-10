import 'package:drift/drift.dart' show TableUpdateQuery;

import '../../domain/reglas/costo_compra.dart';
import '../db/base_datos.dart';

/// Un animal comprado al que no se le puede sacar el costo.
class SinCosto {
  const SinCosto({
    required this.animal,
    required this.numeroArete,
    required this.loteCompraId,
    required this.vendedor,
    required this.falta,
    required this.forma,
  });

  final Animal animal;
  final String? numeroArete;
  final String loteCompraId;
  final String vendedor;

  /// Qué es lo que falta: el peso o el precio.
  final FaltaDato falta;

  final FormaCotizacion forma;

  String get titulo => numeroArete ?? (animal.apodo ?? 'Sin arete');

  String get queFalta => switch (falta) {
        FaltaDato.peso => 'falta pesarlo',
        FaltaDato.precio => 'falta el precio',
      };
}

/// Los huecos que dejan una compra a medias.
///
/// Un animal sin costo sale **en blanco** en el resumen de la venta, y en
/// blanco es lo correcto: no se sabe. Pero un hueco que nadie ve nunca se tapa,
/// y por eso el inicio lo saca a la luz, igual que hace con los que no tienen
/// lugar y con los que están pendientes de aretar.
///
/// Solo se cuentan los animales que **siguen en el rancho**. A uno que ya se
/// vendió también se le puede poner el precio, pero desde su compra: meterlo
/// aquí convertiría la lista en un archivo histórico en vez de una lista de
/// pendientes.
class RepoPendientes {
  RepoPendientes(this.db);

  final BaseDatos db;

  Stream<List<SinCosto>> verSinCosto() async* {
    yield await _armar();
    await for (final _ in db.tableUpdates(
      TableUpdateQuery.onAllTables([
        db.animales,
        db.aretes,
        db.eventos,
        db.eventoPesos,
        db.eventoBajas,
        db.lotesCompra,
        db.loteCompraAnimales,
      ]),
    )) {
      yield await _armar();
    }
  }

  Future<List<SinCosto>> _armar() async {
    final deBaja = await db.animalesDadosDeBaja();
    final filas = await (db.select(db.loteCompraAnimales)
          ..where((a) => a.eliminadoEn.isNull()))
        .get();

    final pendientes = <SinCosto>[];

    for (final fila in filas) {
      if (deBaja.contains(fila.animalId)) continue;

      final animal = await db.animal(fila.animalId);
      if (animal == null || animal.eliminadoEn != null) continue;

      final lote = await db.loteCompra(fila.loteCompraId);
      if (lote == null || lote.eliminadoEn != null) continue;

      final forma = (fila.formaCalculo ?? lote.formaCalculo) == 'porCabeza'
          ? FormaCotizacion.porCabeza
          : FormaCotizacion.porKilo;

      final costo = costoDelAnimal(
        CompraDeAnimal(
          forma: forma,
          precioPorKilo: fila.precioPorKilo ?? lote.precioPorKilo,
          precioPorCabeza: fila.precioPorCabeza,
          pesoCompraKg: await db.pesoDeCompra(animal.id),
        ),
      );

      final falta = costo.falta;
      if (falta == null) continue;

      pendientes.add(
        SinCosto(
          animal: animal,
          numeroArete: (await db.areteVigente(animal.id))?.numero,
          loteCompraId: fila.loteCompraId,
          vendedor: fila.vendedor ?? lote.vendedor,
          falta: falta,
          forma: forma,
        ),
      );
    }

    return pendientes;
  }
}
