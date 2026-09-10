import 'package:drift/drift.dart';

import '../../domain/modelos/tipos.dart';
import '../../domain/reglas/categoria.dart';
import '../../domain/reglas/estado_animal.dart';
import '../db/base_datos.dart';

/// Un animal con todo su estado ya derivado, listo para pintarse.
///
/// Nada de esto esta guardado en ninguna columna: la ubicacion sale del ultimo
/// movimiento, el peso del ultimo pesaje y la categoria del sexo, la edad, el
/// destete y el parto. Se calcula cada vez, que es exactamente lo que mandan
/// las reglas 4 y 5.
class AnimalEnLista {
  const AnimalEnLista({
    required this.animal,
    required this.numeroArete,
    required this.categoria,
    required this.categoriaHaceUnMes,
    required this.ubicacionId,
    required this.ubicacionNombre,
    required this.enUbicacionDesde,
    required this.ultimoPesoKg,
    required this.ultimoPesoFecha,
    required this.categoriaCorregida,
    required this.proximoCambioCategoria,
  });

  final Animal animal;

  /// Nulo cuando el animal esta **pendiente de aretar**. No es un error: los
  /// lotes comprados llegan sin identificar.
  final String? numeroArete;

  final Categoria categoria;

  /// La categoria que tenia hace un mes.
  ///
  /// Sirve para avisar en el inicio cuando un animal cambio solo, sin guardar
  /// ninguna bandera: se calcula la categoria dos veces, con dos fechas, y se
  /// comparan. La regla 5 sigue intacta.
  final Categoria categoriaHaceUnMes;

  /// Cambio de categoria en el ultimo mes por puro paso del tiempo.
  bool get cambioReciente => categoria != categoriaHaceUnMes;

  /// Verdadero cuando la categoria la puso el dueno a mano y no el calculo.
  final bool categoriaCorregida;

  /// AAAAMMDD en que le toca cambiar de categoria por edad, si aplica.
  final int? proximoCambioCategoria;

  final String? ubicacionId;
  final String? ubicacionNombre;
  final int? enUbicacionDesde;

  final double? ultimoPesoKg;
  final int? ultimoPesoFecha;

  bool get pendienteDeAretar => numeroArete == null;

  /// Lo que se pinta en grande en la lista. El peso es lo que de verdad mira el
  /// ranchero, pero la identidad es el numero.
  String get titulo => numeroArete ?? (animal.apodo ?? 'Sin arete');
}

/// Arma el estado de todo el hato.
///
/// Carga los eventos de todos los animales de un jalon y agrupa en Dart, en vez
/// de hacer una consulta por animal. Para unos cientos de cabezas es de sobra, y
/// tiene la ventaja de que la lista usa exactamente las mismas funciones puras
/// que estan cubiertas por pruebas.
class RepoHato {
  RepoHato(this.db);

  final BaseDatos db;

  Stream<List<AnimalEnLista>> verHato({
    required int hoy,
    UmbralesCategoria umbrales = const UmbralesCategoria(),
  }) async* {
    // Se escuchan **todas** las tablas de las que depende el estado derivado.
    //
    // Antes solo se miraba la tabla de animales, y eso dejaba la pantalla
    // rezagada: mover un animal de potrero no cambia al animal, agrega un
    // evento. La lista se refrescaba hasta que se volvia a entrar, y parecia
    // que la app iba lenta cuando en realidad no se estaba enterando.
    final cambios = db.tableUpdates(
      TableUpdateQuery.onAllTables([
        db.animales,
        db.aretes,
        db.ubicaciones,
        db.eventos,
        db.eventoMovimientos,
        db.eventoPesos,
        db.eventoCorreccionCategorias,
        db.eventoBajas,
      ]),
    );

    yield await _armar(hoy: hoy, umbrales: umbrales);
    await for (final _ in cambios) {
      yield await _armar(hoy: hoy, umbrales: umbrales);
    }
  }

  Future<List<AnimalEnLista>> _armar({
    required int hoy,
    required UmbralesCategoria umbrales,
  }) async {
    final deBaja = await db.animalesDadosDeBaja();

    // Un animal vendido, muerto, robado o sacrificado deja de contar en el
    // inventario y en los potreros. No se borra ni se marca con una columna de
    // estado: se sabe porque tiene un evento de baja.
    final listaAnimales = (await (db.select(db.animales)
              ..where((a) => a.eliminadoEn.isNull()))
            .get())
        .where((a) => !deBaja.contains(a.id))
        .toList();
    if (listaAnimales.isEmpty) return const [];

    final listaAretes = await (db.select(db.aretes)
          ..where((a) => a.fechaRetiro.isNull() & a.eliminadoEn.isNull()))
        .get();
    final listaUbicaciones = await (db.select(db.ubicaciones)
          ..where((u) => u.eliminadoEn.isNull()))
        .get();

    final nombreUbicacion = {
      for (final u in listaUbicaciones) u.id: u.nombre,
    };
    final aretePorAnimal = {
      for (final a in listaAretes) a.animalId: a.numero,
    };

    final eventos = await (db.select(db.eventos)
          ..where((e) => e.eliminadoEn.isNull()))
        .get();

    final movimientos = await db.select(db.eventoMovimientos).get();
    final destinoPorEvento = {
      for (final m in movimientos) m.eventoId: m.ubicacionDestinoId,
    };
    final pesos = await db.select(db.eventoPesos).get();
    final kilosPorEvento = {for (final p in pesos) p.eventoId: p.kilos};
    final correcciones = await db.select(db.eventoCorreccionCategorias).get();
    final categoriaPorEvento = {
      for (final c in correcciones) c.eventoId: c.categoria,
    };

    final porAnimal = <String, List<Evento>>{};
    for (final e in eventos) {
      porAnimal.putIfAbsent(e.animalId, () => []).add(e);
    }

    return [
      for (final animal in listaAnimales)
        _uno(
          animal: animal,
          eventos: porAnimal[animal.id] ?? const [],
          numeroArete: aretePorAnimal[animal.id],
          nombreUbicacion: nombreUbicacion,
          destinoPorEvento: destinoPorEvento,
          kilosPorEvento: kilosPorEvento,
          categoriaPorEvento: categoriaPorEvento,
          hoy: hoy,
          umbrales: umbrales,
        ),
    ];
  }

  AnimalEnLista _uno({
    required Animal animal,
    required List<Evento> eventos,
    required String? numeroArete,
    required Map<String, String> nombreUbicacion,
    required Map<String, String> destinoPorEvento,
    required Map<String, double> kilosPorEvento,
    required Map<String, String> categoriaPorEvento,
    required int hoy,
    required UmbralesCategoria umbrales,
  }) {
    final movimientos = <Movimiento>[];
    final pesajes = <Pesaje>[];
    final correcciones = <_Correccion>[];
    var tieneDestete = false;
    var tieneParto = false;

    for (final e in eventos) {
      switch (e.tipo) {
        case 'movimiento':
          final destino = destinoPorEvento[e.id];
          if (destino != null) {
            movimientos.add(Movimiento(
              fechaEvento: e.fechaEvento,
              creadoEn: e.creadoEn,
              id: e.id,
              ubicacionDestinoId: destino,
            ));
          }
        case 'peso':
          final kilos = kilosPorEvento[e.id];
          if (kilos != null) {
            pesajes.add(Pesaje(
              fechaEvento: e.fechaEvento,
              creadoEn: e.creadoEn,
              id: e.id,
              kilos: kilos,
            ));
          }
        case 'destete':
          tieneDestete = true;
        case 'parto':
          tieneParto = true;
        case 'correccionCategoria':
          final cat = categoriaPorEvento[e.id];
          if (cat != null) {
            correcciones.add(_Correccion(
              fechaEvento: e.fechaEvento,
              creadoEn: e.creadoEn,
              id: e.id,
              categoria: Categoria.desdeTexto(cat),
            ));
          }
      }
    }

    final donde = ubicacionActual(movimientos);
    final peso = ultimoPeso(pesajes);
    final correccion = masReciente(correcciones)?.categoria;

    final datos = DatosCategoria(
      sexo: Sexo.desdeTexto(animal.sexo),
      fechaNacimiento: animal.fechaNacimiento,
      tieneDestete: tieneDestete,
      tieneParto: tieneParto,
      correccionManual: correccion,
    );

    return AnimalEnLista(
      animal: animal,
      numeroArete: numeroArete,
      categoria: calcularCategoria(datos, hoy: hoy, umbrales: umbrales),
      categoriaHaceUnMes: calcularCategoria(
        datos,
        hoy: sumaMeses(hoy, -1),
        umbrales: umbrales,
      ),
      categoriaCorregida: correccion != null,
      proximoCambioCategoria:
          proximoCambioDeCategoria(datos, hoy: hoy, umbrales: umbrales),
      ubicacionId: donde?.ubicacionId,
      ubicacionNombre:
          donde == null ? null : nombreUbicacion[donde.ubicacionId],
      enUbicacionDesde: donde?.desde,
      ultimoPesoKg: peso?.kilos,
      ultimoPesoFecha: peso?.fechaEvento,
    );
  }
}

class _Correccion extends EventoBase {
  const _Correccion({
    required super.fechaEvento,
    required super.creadoEn,
    required super.id,
    required this.categoria,
  });

  final Categoria categoria;
}
