import '../../comun/fechas.dart';
import '../../domain/modelos/tipos.dart';
import '../db/base_datos.dart';

/// Un renglón del historial, ya en palabras.
class ApunteHistorial {
  const ApunteHistorial({
    required this.fecha,
    required this.titulo,
    this.detalle,
  });

  final int fecha;
  final String titulo;
  final String? detalle;

  String get fechaEnPalabras => formateaAaaammdd(fecha);
}

/// Arma el historial de un animal con los datos adentro.
///
/// Un historial que solo dice "Pesaje" y "Movimiento" no sirve para nada: lo
/// que se quiere saber es **cuánto pesó** y **a dónde se movió**. Cada renglón
/// trae su detalle o no se pinta.
class RepoHistorial {
  RepoHistorial(this.db);

  final BaseDatos db;

  /// El historial, que se rehace solo cuando le pasa algo al animal.
  Stream<List<ApunteHistorial>> verStream(String animalId) async* {
    yield await ver(animalId);
    await for (final _ in db.verEventos(animalId).skip(1)) {
      yield await ver(animalId);
    }
  }

  Future<List<ApunteHistorial>> ver(String animalId) async {
    final eventos = await db.verEventos(animalId).first;
    if (eventos.isEmpty) return const [];

    final lugares = {
      for (final u in await db.verUbicaciones().first) u.id: u.nombre,
    };

    final apuntes = <ApunteHistorial>[];

    for (final e in eventos) {
      switch (e.tipo) {
        case 'peso':
          final p = await db.detallePeso(e.id);
          apuntes.add(
            ApunteHistorial(
              fecha: e.fechaEvento,
              titulo: p == null
                  ? 'Pesaje'
                  : '${p.kilos.toStringAsFixed(0)} kg',
              detalle: switch (p?.tipoPesaje) {
                'compra' => 'al recibirlo',
                'venta' => 'al venderlo',
                'nacimiento' => 'al nacer',
                'destete' => 'al destete',
                _ => null,
              },
            ),
          );

        case 'movimiento':
          final m = await db.detalleMovimiento(e.id);
          final destino = lugares[m?.ubicacionDestinoId] ?? 'otro lugar';
          apuntes.add(
            ApunteHistorial(
              fecha: e.fechaEvento,
              titulo: 'Se movió a $destino',
              detalle: m?.motivo,
            ),
          );

        case 'manejo':
          final man = await db.detalleManejo(e.id);
          final hechos = [
            if (man?.banado ?? false) 'bañado',
            if (man?.desparasitado ?? false) 'desparasitado',
            if ((man?.otro ?? '').isNotEmpty) man!.otro!,
          ];
          apuntes.add(
            ApunteHistorial(
              fecha: e.fechaEvento,
              titulo: hechos.isEmpty ? 'Manejo' : _primeraMayuscula(hechos),
            ),
          );

        case 'correccionCategoria':
          final c = await db.detalleCategoria(e.id);
          apuntes.add(
            ApunteHistorial(
              fecha: e.fechaEvento,
              titulo: c == null
                  ? 'Categoría'
                  : Categoria.desdeTexto(c.categoria).etiqueta,
              detalle: c?.motivo,
            ),
          );

        case 'baja':
          final b = await db.detalleBaja(e.id);
          apuntes.add(
            ApunteHistorial(
              fecha: e.fechaEvento,
              titulo: switch (b?.motivo) {
                'venta' => 'Vendido',
                'muerte' => 'Murió',
                'robo' => 'Robado',
                'sacrificio' => 'Sacrificado',
                _ => 'Salió del hato',
              },
              detalle: b?.causa,
            ),
          );

        case 'proposito':
          // No se pinta: es ruido. El proposito casi nunca cambia y ponerlo en
          // el historial de cada animal, desde su alta, tapa lo que si importa.
          break;

        case 'destete':
          apuntes.add(
            ApunteHistorial(fecha: e.fechaEvento, titulo: 'Destetado'),
          );

        case 'parto':
          apuntes.add(ApunteHistorial(fecha: e.fechaEvento, titulo: 'Parió'));

        default:
          apuntes.add(ApunteHistorial(fecha: e.fechaEvento, titulo: e.tipo));
      }
    }

    return apuntes;
  }

  static String _primeraMayuscula(List<String> partes) {
    final texto = partes.join(', ');
    return texto[0].toUpperCase() + texto.substring(1);
  }
}
