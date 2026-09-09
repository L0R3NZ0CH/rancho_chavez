import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganado/data/db/base_datos.dart';

/// Todos los borrados de esta app son logicos (regla 3): el renglon se queda en
/// la base con su fecha de eliminado. Estas pruebas verifican las dos mitades
/// que importan: que desaparezca de las listas, y que **no** se lleve por
/// delante cosas que no le tocan.
void main() {
  late BaseDatos db;

  setUp(() => db = BaseDatos(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<String> unPotrero([String nombre = 'El Zacatal']) =>
      db.crearUbicacion(nombre: nombre, tipo: 'potrero');

  Future<String> unAnimal(String potrero, {String? arete}) => db.altaAnimal(
        sexo: 'macho',
        origen: 'comprado',
        proposito: 'comercial',
        ubicacionId: potrero,
        fecha: 20260908,
        numeroArete: arete,
      );

  group('borrar un animal', () {
    test('sale de la lista pero su historial se queda', () async {
      final p = await unPotrero();
      final a = await unAnimal(p, arete: '001409870222');
      await db.registrarPeso(animalId: a, kilos: 212, fecha: 20260908);

      await db.eliminarAnimal(a);

      expect(await db.verAnimales().first, isEmpty);
      expect(await db.animalPorArete('001409870222'), isNull);

      // El renglon y sus eventos siguen ahi.
      final crudo = await db.select(db.animales).getSingle();
      expect(crudo.eliminadoEn, isNotNull);
      expect(await db.select(db.eventos).get(), isNotEmpty);
    });

    test('no se lleva a los demas animales', () async {
      final p = await unPotrero();
      final a = await unAnimal(p, arete: '111111111111');
      await unAnimal(p, arete: '222222222222');

      await db.eliminarAnimal(a);

      final vivos = await db.verAnimales().first;
      expect(vivos, hasLength(1));
      expect((await db.animalPorArete('222222222222')), isNotNull);
    });
  });

  group('borrar una compra', () {
    test('se lleva el viaje pero NO a los animales', () async {
      // Es la duda inmediata de quien pica el boton, y la respuesta tiene que
      // ser que no: los animales ya estan en el rancho.
      final p = await unPotrero();
      final a = await unAnimal(p, arete: '001409870222');
      final compra = await db.crearLoteCompra(
        fecha: 20260908,
        vendedor: 'Don Chuy',
        formaCalculo: 'porKilo',
        precioPorKilo: 62,
      );
      await db.agregarAnimalALote(loteCompraId: compra, animalId: a);

      await db.eliminarCompra(compra);

      expect(await db.verLotesCompra().first, isEmpty);
      expect(await db.animalesDelLote(compra), isEmpty);

      // El animal sigue vivo y buscable.
      expect((await db.verAnimales().first).single.id, a);
      expect((await db.animalPorArete('001409870222'))!.id, a);
    });

    test('no toca otras compras', () async {
      final unaCompra = await db.crearLoteCompra(
        fecha: 20260908,
        vendedor: 'Don Chuy',
        formaCalculo: 'porKilo',
      );
      await db.crearLoteCompra(
        fecha: 20260909,
        vendedor: 'Don Beto',
        formaCalculo: 'porCabeza',
      );

      await db.eliminarCompra(unaCompra);

      final quedan = await db.verLotesCompra().first;
      expect(quedan, hasLength(1));
      expect(quedan.single.vendedor, 'Don Beto');
    });
  });

  group('quitar un animal de una compra', () {
    test('lo saca del viaje sin borrarlo', () async {
      final p = await unPotrero();
      final a = await unAnimal(p, arete: '001409870222');
      final compra = await db.crearLoteCompra(
        fecha: 20260908,
        vendedor: 'Don Chuy',
        formaCalculo: 'porKilo',
      );
      await db.agregarAnimalALote(loteCompraId: compra, animalId: a);

      await db.quitarAnimalDeCompra(loteCompraId: compra, animalId: a);

      expect(await db.animalesDelLote(compra), isEmpty);
      expect((await db.verAnimales().first).single.id, a);
      expect((await db.verLotesCompra().first).single.id, compra);
    });

    test('no saca a los demas del viaje', () async {
      final p = await unPotrero();
      final a = await unAnimal(p, arete: '111111111111');
      final b = await unAnimal(p, arete: '222222222222');
      final compra = await db.crearLoteCompra(
        fecha: 20260908,
        vendedor: 'Don Chuy',
        formaCalculo: 'porKilo',
      );
      await db.agregarAnimalALote(loteCompraId: compra, animalId: a);
      await db.agregarAnimalALote(loteCompraId: compra, animalId: b);

      await db.quitarAnimalDeCompra(loteCompraId: compra, animalId: a);

      final quedan = await db.animalesDelLote(compra);
      expect(quedan, hasLength(1));
      expect(quedan.single.animalId, b);
    });
  });

  group('borrar un potrero', () {
    test('cuenta los animales que tiene parados ahora', () async {
      final zacatal = await unPotrero();
      final loma = await unPotrero('La Loma');
      final a = await unAnimal(zacatal);
      await unAnimal(zacatal);

      expect(await db.animalesEnUbicacion(zacatal), 2);
      expect(await db.animalesEnUbicacion(loma), 0);

      // Al mover uno, el conteo sigue al animal.
      await db.registrarMovimiento(
        animalId: a,
        ubicacionDestinoId: loma,
        ubicacionOrigenId: zacatal,
        fecha: 20260910,
      );

      expect(await db.animalesEnUbicacion(zacatal), 1);
      expect(await db.animalesEnUbicacion(loma), 1);
    });

    test('un animal borrado deja de contar en su potrero', () async {
      final p = await unPotrero();
      final a = await unAnimal(p);
      expect(await db.animalesEnUbicacion(p), 1);

      await db.eliminarAnimal(a);
      expect(await db.animalesEnUbicacion(p), 0);
    });

    test('sale de la lista pero el historial de movimientos se queda',
        () async {
      final p = await unPotrero();
      await unAnimal(p);

      await db.eliminarUbicacion(p);

      expect(await db.verUbicaciones().first, isEmpty);
      expect(await db.select(db.eventoMovimientos).get(), isNotEmpty);
    });
  });
}
