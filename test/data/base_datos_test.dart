// Se importa solo native.dart a proposito: package:drift/drift.dart exporta sus
// propios isNull e isNotNull, que son constructores de condiciones SQL y chocan
// con los del paquete de pruebas.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganado/data/db/base_datos.dart';

/// Estas pruebas corren contra SQLite de verdad, en memoria.
///
/// No verifican la interfaz: verifican que las reglas que se pueden romper sin
/// darse cuenta sigan puestas. Si alguna se cae, se cae callada, y solo se
/// notaria el dia que entre el segundo celular, que es cuando ya no tiene
/// arreglo.
void main() {
  late BaseDatos db;

  setUp(() => db = BaseDatos(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<String> unPotrero() =>
      db.crearUbicacion(nombre: 'El Zacatal', tipo: 'potrero', hectareas: 40);

  Future<String> unAnimal({
    String? arete,
    String sexo = 'macho',
    int? nace,
  }) async {
    final u = await unPotrero();
    return db.altaAnimal(
      sexo: sexo,
      origen: 'comprado',
      proposito: 'comercial',
      ubicacionId: u,
      fecha: 20260908,
      numeroArete: arete,
      fechaNacimiento: nace,
    );
  }

  test('el esquema se crea en la version 2', () async {
    expect(db.schemaVersion, 2);
    expect(await db.verAnimales().first, isEmpty);
  });

  group('alta de animal', () {
    test('crea el animal, su arete, su movimiento y su proposito', () async {
      final id = await unAnimal(arete: '001409870222');

      final animal = (await db.verAnimales().first).single;
      expect(animal.id, id);
      expect(animal.sexo, 'macho');

      final arete = await db.areteVigente(id);
      expect(arete!.numero, '001409870222');
      expect(arete.fechaRetiro, isNull);

      final eventos = await db.verEventos(id).first;
      expect(eventos.map((e) => e.tipo).toSet(), {'movimiento', 'proposito'});
    });

    test('el animal existe antes que el arete', () async {
      // Un lote comprado llega sin identificar. Tiene que poder darse de alta.
      final id = await unAnimal();
      expect((await db.verAnimales().first).single.id, id);
      expect(await db.areteVigente(id), isNull);
    });

    test('cada fila nace con UUID, sellos y dispositivo', () async {
      final id = await unAnimal(arete: '001409870222');
      final animal = (await db.verAnimales().first).single;

      expect(animal.id, matches(RegExp(r'^[0-9a-f-]{36}$')));
      expect(int.tryParse(animal.id), isNull); // no es un contador
      expect(animal.creadoEn, greaterThan(0));
      expect(animal.modificadoEn, animal.creadoEn);
      expect(animal.dispositivoId, isNotEmpty);
      expect(animal.eliminadoEn, isNull);

      final arete = await db.areteVigente(id);
      expect(arete!.dispositivoId, animal.dispositivoId);
    });

    test('no deja un animal a medias si el alta falla', () async {
      // La ubicacion no existe, asi que la llave foranea revienta a la mitad.
      await expectLater(
        db.altaAnimal(
          sexo: 'macho',
          origen: 'comprado',
          proposito: 'comercial',
          ubicacionId: 'no-existe',
          fecha: 20260908,
        ),
        throwsA(anything),
      );
      expect(await db.verAnimales().first, isEmpty);
    });
  });

  group('busqueda por arete', () {
    test('encuentra al animal por el numero impreso', () async {
      final id = await unAnimal(arete: '001409870222');
      final hallado = await db.animalPorArete('001409870222');
      expect(hallado!.id, id);
    });

    test('no encuentra nada con un numero que no existe', () async {
      await unAnimal(arete: '001409870222');
      expect(await db.animalPorArete('999999999999'), isNull);
    });

    test('un arete retirado ya no devuelve al animal', () async {
      // Se le cayo el arete y se le puso otro. El numero viejo no debe
      // seguir apuntando al animal como si fuera su identificacion vigente.
      final id = await unAnimal(arete: '001409870222');
      final viejo = await db.areteVigente(id);

      await db.retirarArete(
        areteId: viejo!.id,
        fecha: 20260910,
        motivo: 'perdido',
      );
      await db.ponerArete(
        animalId: id,
        numero: '001409870333',
        fecha: 20260910,
      );

      expect(await db.animalPorArete('001409870222'), isNull);
      expect((await db.animalPorArete('001409870333'))!.id, id);
      expect((await db.areteVigente(id))!.numero, '001409870333');
    });

    test('el arete retirado sigue en la base, no se borro', () async {
      final id = await unAnimal(arete: '001409870222');
      final arete = await db.areteVigente(id);
      await db.retirarArete(areteId: arete!.id, fecha: 20260910);

      final todos = await db.select(db.aretes).get();
      expect(todos, hasLength(1));
      expect(todos.single.fechaRetiro, 20260910);
    });
  });

  group('eventos', () {
    test('salen del mas reciente al mas viejo por fecha del hecho', () async {
      final id = await unAnimal();
      await db.registrarPeso(animalId: id, kilos: 180, fecha: 20260301);
      await db.registrarPeso(animalId: id, kilos: 215, fecha: 20260801);
      await db.registrarPeso(animalId: id, kilos: 200, fecha: 20260601);

      final pesos = (await db.verEventos(id).first)
          .where((e) => e.tipo == 'peso')
          .toList();
      expect(pesos.map((e) => e.fechaEvento),
          [20260801, 20260601, 20260301]);
    });

    test('un evento capturado hoy con fecha vieja entra en su lugar', () async {
      final id = await unAnimal();
      await db.registrarPeso(animalId: id, kilos: 215, fecha: 20260801);
      await db.registrarPeso(animalId: id, kilos: 150, fecha: 20260101);

      final pesos = (await db.verEventos(id).first)
          .where((e) => e.tipo == 'peso')
          .toList();
      expect(pesos.first.fechaEvento, 20260801);
    });

    test('destete y parto se guardan solo con su fecha', () async {
      final id = await unAnimal(sexo: 'hembra');
      await db.registrarDestete(animalId: id, fecha: 20260401);
      await db.registrarParto(animalId: id, fecha: 20260801);

      final tipos =
          (await db.verEventos(id).first).map((e) => e.tipo).toList();
      expect(tipos, contains('destete'));
      expect(tipos, contains('parto'));
    });

    test('la correccion de categoria queda con fecha y motivo', () async {
      final id = await unAnimal();
      await db.corregirCategoria(
        animalId: id,
        categoria: 'toro',
        fecha: 20260908,
        motivo: 'lo dejamos de semental',
      );

      final det = await db.select(db.eventoCorreccionCategorias).getSingle();
      expect(det.categoria, 'toro');
      expect(det.motivo, 'lo dejamos de semental');
    });
  });

  group('regla 3: borrado logico', () {
    test('eliminar un animal lo saca de la lista pero lo deja en la base',
        () async {
      final id = await unAnimal(arete: '001409870222');
      await db.eliminarAnimal(id);

      expect(await db.verAnimales().first, isEmpty);

      final crudo = await db.select(db.animales).getSingle();
      expect(crudo.id, id);
      expect(crudo.eliminadoEn, isNotNull);
    });
  });

  group('ajustes del dispositivo', () {
    test('el dispositivoId es estable entre llamadas', () async {
      expect(await db.dispositivoId(), await db.dispositivoId());
    });

    test('un ajuste se puede sobrescribir', () async {
      await db.escribirAjuste('mesesDestete', '8');
      await db.escribirAjuste('mesesDestete', '7');
      expect(await db.leerAjuste('mesesDestete'), '7');
    });
  });
}
