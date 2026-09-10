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
    required this.categoriaDesde,
    required this.avisoCategoria,
    required this.ubicacionId,
    required this.ubicacionNombre,
    required this.enUbicacionDesde,
    required this.ultimoPesoKg,
    required this.ultimoPesoFecha,
    required this.deBaja,
    required this.categoriaCorregida,
    required this.proximoCambioCategoria,
  });

  final Animal animal;

  /// Nulo cuando el animal esta **pendiente de aretar**. No es un error: los
  /// lotes comprados llegan sin identificar.
  final String? numeroArete;

  final Categoria categoria;

  /// Desde cuando trae esa categoria, en AAAAMMDD.
  ///
  /// Nulo cuando la categoria salio del calculo y no de una captura.
  final int? categoriaDesde;

  /// Cuando el animal lleva demasiado tiempo en la misma categoria.
  ///
  /// La app avisa; no cambia nada sola, porque el juicio de que un becerro ya
  /// es torete es del dueno, no de una formula.
  final ({int meses, int limite})? avisoCategoria;

  /// Verdadero cuando la categoria se capturo, en vez de deducirse de la fecha
  /// de nacimiento.
  final bool categoriaCorregida;

  /// AAAAMMDD en que le toca cambiar de categoria por edad.
  ///
  /// Solo aplica a los **nacidos en el rancho**, que son los unicos con fecha
  /// de nacimiento real. A un animal comprado no se le puede sugerir nada,
  /// porque no se sabe cuando nacio.
  final int? proximoCambioCategoria;

  final String? ubicacionId;
  final String? ubicacionNombre;
  final int? enUbicacionDesde;

  final double? ultimoPesoKg;
  final int? ultimoPesoFecha;

  /// El animal ya salio del hato: vendido, muerto, robado o sacrificado.
  final bool deBaja;

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

  /// Un solo animal, **aunque ya haya salido del hato**.
  ///
  /// La ficha no puede depender de la lista del hato: un animal vendido sale de
  /// esa lista, y es justo cuando mas se quiere ver su ficha —para saber que
  /// paso con el, cuanto peso, en cuanto se fue.
  Stream<AnimalEnLista?> verAnimal(
    String animalId, {
    required int hoy,
    UmbralesCategoria umbrales = const UmbralesCategoria(),
  }) async* {
    Future<AnimalEnLista?> armarUno() async {
      final todos = await _armar(
        hoy: hoy,
        umbrales: umbrales,
        incluirBajas: true,
      );
      return todos.where((a) => a.animal.id == animalId).firstOrNull;
    }

    yield await armarUno();
    await for (final _ in db.tableUpdates(
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
    )) {
      yield await armarUno();
    }
  }

  Future<List<AnimalEnLista>> _armar({
    required int hoy,
    required UmbralesCategoria umbrales,
    bool incluirBajas = false,
  }) async {
    final deBaja = await db.animalesDadosDeBaja();

    // Un animal vendido, muerto, robado o sacrificado deja de contar en el
    // inventario y en los potreros. No se borra ni se marca con una columna de
    // estado: se sabe porque tiene un evento de baja.
    final listaAnimales = (await (db.select(db.animales)
              ..where((a) => a.eliminadoEn.isNull()))
            .get())
        .where((a) => incluirBajas || !deBaja.contains(a.id))
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
          deBaja: deBaja.contains(animal.id),
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
    required bool deBaja,
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

    // La categoria capturada manda. Es un juicio de quien vio al animal, igual
    // que el precio, y ninguna formula le gana a eso.
    final capturada = masReciente(correcciones);

    final nacidoAqui = animal.origen == 'nacido';

    final datos = DatosCategoria(
      sexo: Sexo.desdeTexto(animal.sexo),
      fechaNacimiento: animal.fechaNacimiento,
      tieneDestete: tieneDestete,
      tieneParto: tieneParto,
      correccionManual: capturada?.categoria,
    );

    // Sin captura, el calculo solo sirve para los nacidos aqui: son los unicos
    // de los que se conoce la fecha de nacimiento de verdad. A un comprado no
    // se le inventa una categoria.
    final categoria = capturada?.categoria ??
        (nacidoAqui
            ? calcularCategoria(datos, hoy: hoy, umbrales: umbrales)
            : Categoria.sinClasificar);

    return AnimalEnLista(
      animal: animal,
      numeroArete: numeroArete,
      categoria: categoria,
      categoriaDesde: capturada?.fechaEvento,
      categoriaCorregida: capturada != null,
      avisoCategoria: avisoDeCategoria(
        categoria: categoria,
        desde: capturada?.fechaEvento,
        hoy: hoy,
        umbrales: umbrales,
      ),
      // Solo los nacidos aqui tienen fecha de nacimiento real, asi que solo a
      // ellos se les puede sugerir el siguiente cambio.
      proximoCambioCategoria: nacidoAqui
          ? proximoCambioDeCategoria(datos, hoy: hoy, umbrales: umbrales)
          : null,
      ubicacionId: donde?.ubicacionId,
      ubicacionNombre:
          donde == null ? null : nombreUbicacion[donde.ubicacionId],
      enUbicacionDesde: donde?.desde,
      ultimoPesoKg: peso?.kilos,
      ultimoPesoFecha: peso?.fechaEvento,
      deBaja: deBaja,
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
