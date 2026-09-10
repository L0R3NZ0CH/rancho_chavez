import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganado/data/db/base_datos.dart';
import 'package:ganado/data/repos/hato.dart';
import 'package:ganado/domain/modelos/tipos.dart';

/// El manejo es un **apunte**, no una edición: lo de antes no se toca. Y la
/// categoría se captura, así que la que manda es la última que se puso.
void main() {
  late BaseDatos db;

  setUp(() => db = BaseDatos(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<String> unAnimal({
    String origen = 'comprado',
    String? categoria,
    int? nace,
  }) =>
      db.altaAnimal(
        sexo: 'macho',
        origen: origen,
        proposito: 'comercial',
        fecha: 20260608,
        categoria: categoria,
        fechaNacimiento: nace,
      );

  group('la categoría se captura', () {
    test('se guarda al dar de alta y se puede leer', () async {
      final a = await unAnimal(categoria: 'becerro');
      expect(await db.categoriaDe(a), Categoria.becerro);
    });

    test('sin capturar queda sin clasificar', () async {
      final a = await unAnimal();
      expect(await db.categoriaDe(a), Categoria.sinClasificar);
    });

    test('la última que se pone es la que manda', () async {
      final a = await unAnimal(categoria: 'becerro');
      await db.asignarCategoria(
        animalId: a,
        categoria: 'torete',
        fecha: 20260908,
        motivo: 'ya creció',
      );

      expect(await db.categoriaDe(a), Categoria.torete);
    });

    test('la anterior no se borra: queda el rastro', () async {
      final a = await unAnimal(categoria: 'becerro');
      await db.asignarCategoria(
        animalId: a,
        categoria: 'torete',
        fecha: 20260908,
      );

      final todas = await db.select(db.eventoCorreccionCategorias).get();
      expect(todas, hasLength(2));
      expect(
        todas.map((c) => c.categoria).toSet(),
        {'becerro', 'torete'},
      );
    });
  });

  group('el cálculo solo aplica a los nacidos aquí', () {
    test('un comprado sin categoría capturada queda sin clasificar', () async {
      // Aunque traiga fecha de nacimiento: de un comprado no se sabe de verdad.
      await unAnimal(nace: 20260101);

      final hato = await RepoHato(db).verHato(hoy: 20260908).first;
      expect(hato.single.categoria, Categoria.sinClasificar);
    });

    test('un nacido aquí sí se calcula de su fecha', () async {
      await unAnimal(origen: 'nacido', nace: 20260801);

      final hato = await RepoHato(db).verHato(hoy: 20260908).first;
      expect(hato.single.categoria, Categoria.becerro);
    });

    test('lo capturado le gana al cálculo', () async {
      await unAnimal(
        origen: 'nacido',
        nace: 20260801,
        categoria: 'torete',
      );

      final hato = await RepoHato(db).verHato(hoy: 20260908).first;
      expect(hato.single.categoria, Categoria.torete);
      expect(hato.single.categoriaCorregida, isTrue);
    });
  });

  group('el aviso llega hasta la lista', () {
    test('un becerro capturado hace un año aparece con aviso', () async {
      final a = await unAnimal();
      await db.asignarCategoria(
        animalId: a,
        categoria: 'becerro',
        fecha: 20250901,
      );

      final hato = await RepoHato(db).verHato(hoy: 20260908).first;
      expect(hato.single.avisoCategoria, isNotNull);
      expect(hato.single.avisoCategoria!.meses, greaterThanOrEqualTo(12));
    });

    test('uno recién capturado no trae aviso', () async {
      await unAnimal(categoria: 'becerro');

      final hato = await RepoHato(db).verHato(hoy: 20260908).first;
      expect(hato.single.avisoCategoria, isNull);
    });
  });

  group('los apuntes de manejo se apilan', () {
    test('un baño queda con su fecha', () async {
      final a = await unAnimal();
      final evento = await db.registrarManejo(
        animalId: a,
        fecha: 20260908,
        banado: true,
      );

      final detalle = await db.detalleManejo(evento);
      expect(detalle!.banado, isTrue);
      expect(detalle.desparasitado, isFalse);
    });

    test('bañar dos veces deja dos apuntes, no uno pisado', () async {
      // Es la razon de ser de todo esto: un control es un historial, no una
      // casilla que alguien va sobrescribiendo.
      final a = await unAnimal();
      await db.registrarManejo(animalId: a, fecha: 20260801, banado: true);
      await db.registrarManejo(animalId: a, fecha: 20260908, banado: true);

      final manejos = (await db.verEventos(a).first)
          .where((e) => e.tipo == 'manejo')
          .toList();
      expect(manejos, hasLength(2));
      expect(manejos.first.fechaEvento, 20260908);
    });

    test('lo otro se guarda en palabras del rancho', () async {
      final a = await unAnimal();
      final evento = await db.registrarManejo(
        animalId: a,
        fecha: 20260908,
        otro: 'le curamos una pata',
      );

      expect((await db.detalleManejo(evento))!.otro, 'le curamos una pata');
    });
  });
}
