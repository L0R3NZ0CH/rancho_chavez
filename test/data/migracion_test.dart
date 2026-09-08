import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganado/data/db/base_datos.dart';
import 'package:ganado/data/db/rutas.dart';
import 'package:sqlite3/sqlite3.dart';

/// La prueba que sostiene el compromiso de no perder datos.
///
/// No comprueba que el codigo de migracion compile: crea una base en la version
/// vieja, la llena, la migra de verdad y verifica que lo que debia sobrevivir
/// sobrevivio. Una migracion que borre de mas falla aqui, en la maquina de
/// desarrollo, y no en el celular a media jornada en el corral.
void main() {
  late Directory temporal;

  setUp(() => temporal = Directory.systemTemp.createTempSync('ganado_mig'));
  tearDown(() => temporal.deleteSync(recursive: true));

  String rutaNueva(String nombre) => '${temporal.path}${Platform.pathSeparator}$nombre';

  /// Arma a mano una base tal como la dejaba la fase 1.
  void crearBaseVersion1(String ruta) {
    final db = sqlite3.open(ruta);
    db
      ..execute('''
        CREATE TABLE lecturas_prueba (
          id TEXT NOT NULL PRIMARY KEY,
          creado_en INTEGER NOT NULL,
          modificado_en INTEGER NOT NULL,
          eliminado_en INTEGER,
          dispositivo_id TEXT NOT NULL,
          fecha INTEGER NOT NULL,
          resultado TEXT NOT NULL,
          numero TEXT
        );
      ''')
      ..execute('''
        CREATE TABLE configuracion (
          clave TEXT NOT NULL PRIMARY KEY,
          valor TEXT NOT NULL
        );
      ''')
      ..execute('''
        INSERT INTO lecturas_prueba
          (id, creado_en, modificado_en, dispositivo_id, fecha, resultado, numero)
        VALUES ('abc', 1, 1, 'disp-1', 20260908, 'camara', '001409870222');
      ''')
      ..execute('''
        INSERT INTO configuracion (clave, valor)
        VALUES ('dispositivoId', 'el-mismo-de-siempre');
      ''')
      ..userVersion = 1;
    db.close();
  }

  test('migrar de la version 1 a la 2 conserva los ajustes del dispositivo',
      () async {
    final ruta = rutaNueva('ganado.sqlite');
    crearBaseVersion1(ruta);

    final db = BaseDatos(NativeDatabase(File(ruta)));
    addTearDown(db.close);

    // Abrir dispara la migracion.
    expect(await db.verAnimales().first, isEmpty);

    // El dispositivoId es lo unico de la fase 1 que NO puede perderse: si
    // cambiara, el historial viejo quedaria atribuido a un celular distinto.
    expect(await db.leerAjuste('dispositivoId'), 'el-mismo-de-siempre');
    expect(await db.dispositivoId(), 'el-mismo-de-siempre');
  });

  test('la tabla de la prueba de campo se elimina, como estaba acordado',
      () async {
    final ruta = rutaNueva('ganado.sqlite');
    crearBaseVersion1(ruta);

    final db = BaseDatos(NativeDatabase(File(ruta)));
    await db.verAnimales().first;
    await db.close();

    final crudo = sqlite3.open(ruta);
    final tablas = crudo
        .select("SELECT name FROM sqlite_master WHERE type='table'")
        .map((f) => f['name'] as String)
        .toSet();
    crudo.close();

    expect(tablas, isNot(contains('lecturas_prueba')));
  });

  test('despues de migrar quedan las tablas del hato y se puede trabajar',
      () async {
    final ruta = rutaNueva('ganado.sqlite');
    crearBaseVersion1(ruta);

    final db = BaseDatos(NativeDatabase(File(ruta)));
    addTearDown(db.close);

    final potrero = await db.crearUbicacion(
      nombre: 'El Zacatal',
      tipo: 'potrero',
    );
    final animal = await db.altaAnimal(
      sexo: 'hembra',
      origen: 'comprado',
      proposito: 'comercial',
      ubicacionId: potrero,
      fecha: 20260908,
      numeroArete: '001409870222',
    );

    expect((await db.animalPorArete('001409870222'))!.id, animal);
  });

  test('la base sube a la version 2 y no vuelve a migrar al reabrir', () async {
    final ruta = rutaNueva('ganado.sqlite');
    crearBaseVersion1(ruta);

    final primera = BaseDatos(NativeDatabase(File(ruta)));
    await primera.verAnimales().first;
    await primera.close();

    final crudo = sqlite3.open(ruta);
    final version = crudo.userVersion;
    crudo.close();
    expect(version, versionEsquema);

    // Reabrir no debe disparar onUpgrade otra vez: si lo hiciera, volveria a
    // intentar borrar una tabla que ya no existe.
    final segunda = BaseDatos(NativeDatabase(File(ruta)));
    addTearDown(segunda.close);
    expect(await segunda.leerAjuste('dispositivoId'), 'el-mismo-de-siempre');
  });

  group('de la version 2 a la 3: compras', () {
    /// Deja una base ya migrada a la version 2, con datos del rancho dentro.
    Future<String> baseVersion2ConDatos(String ruta) async {
      crearBaseVersion1(ruta);
      final db = BaseDatos(NativeDatabase(File(ruta)));
      final potrero =
          await db.crearUbicacion(nombre: 'El Zacatal', tipo: 'potrero');
      final animal = await db.altaAnimal(
        sexo: 'hembra',
        origen: 'comprado',
        proposito: 'comercial',
        ubicacionId: potrero,
        fecha: 20260908,
        numeroArete: '001409870222',
      );
      await db.registrarPeso(
        animalId: animal,
        kilos: 212,
        fecha: 20260908,
        tipoPesaje: 'compra',
      );
      await db.close();
      return animal;
    }

    test('no pierde ni un animal, ni un arete, ni un pesaje', () async {
      // Esta es la primera migracion que corre sobre datos reales del rancho.
      // De la version 2 en adelante, perder una fila es inaceptable.
      final ruta = rutaNueva('ganado.sqlite');
      final animal = await baseVersion2ConDatos(ruta);

      final db = BaseDatos(NativeDatabase(File(ruta)));
      addTearDown(db.close);

      expect((await db.verAnimales().first).single.id, animal);
      expect((await db.animalPorArete('001409870222'))!.id, animal);
      expect(await db.pesoDeCompra(animal), 212);
      expect(await db.leerAjuste('dispositivoId'), 'el-mismo-de-siempre');
    });

    test('deja listas las tablas de compras y se puede registrar una',
        () async {
      final ruta = rutaNueva('ganado.sqlite');
      final animal = await baseVersion2ConDatos(ruta);

      final db = BaseDatos(NativeDatabase(File(ruta)));
      addTearDown(db.close);

      final lote = await db.crearLoteCompra(
        fecha: 20260908,
        vendedor: 'Don Chuy',
        formaCalculo: 'porKilo',
        precioPorKilo: 62,
        montoTotal: 13144,
      );
      await db.agregarAnimalALote(loteCompraId: lote, animalId: animal);
      await db.agregarGastoCompra(
        loteCompraId: lote,
        concepto: 'flete',
        monto: 1500,
      );

      expect((await db.verLotesCompra().first).single.vendedor, 'Don Chuy');
      expect(await db.animalesDelLote(lote), hasLength(1));
      expect((await db.gastosDelLote(lote)).single.monto, 1500);
      expect(await db.vendedoresUsados(), ['Don Chuy']);
    });

    test('una base que se quedo en la version 1 llega hasta la 3', () async {
      // Alguien que no abrio la app en dos versiones tiene que poder ponerse
      // al dia de un jalon, pasando por todos los pasos intermedios.
      final ruta = rutaNueva('ganado.sqlite');
      crearBaseVersion1(ruta);

      final db = BaseDatos(NativeDatabase(File(ruta)));
      addTearDown(db.close);
      await db.verAnimales().first;

      expect(await db.leerAjuste('dispositivoId'), 'el-mismo-de-siempre');
      expect(await db.verLotesCompra().first, isEmpty);
    });
  });

  group('respaldo previo a migrar', () {
    test('copia el archivo cuando hay una migracion pendiente', () async {
      final ruta = rutaNueva('ganado.sqlite');
      crearBaseVersion1(ruta);

      final copia = await respaldarAntesDeMigrar(
        ruta: ruta,
        versionObjetivo: versionEsquema,
      );

      expect(copia, isNotNull);
      expect(File(copia!).existsSync(), isTrue);
      expect(copia, endsWith('previo_v1'));

      // La copia tiene que ser utilizable, no un archivo truncado.
      final vieja = sqlite3.open(copia);
      final cuantas = vieja
          .select('SELECT COUNT(*) AS n FROM lecturas_prueba')
          .first['n'] as int;
      vieja.close();
      expect(cuantas, 1);
    });

    test('no copia nada si la base ya esta en la version buena', () async {
      final ruta = rutaNueva('ganado.sqlite');
      crearBaseVersion1(ruta);

      final db = BaseDatos(NativeDatabase(File(ruta)));
      await db.verAnimales().first;
      await db.close();

      expect(
        await respaldarAntesDeMigrar(
          ruta: ruta,
          versionObjetivo: versionEsquema,
        ),
        isNull,
      );
    });

    test('no copia nada si la base todavia no existe', () async {
      expect(
        await respaldarAntesDeMigrar(
          ruta: rutaNueva('no-existe.sqlite'),
          versionObjetivo: versionEsquema,
        ),
        isNull,
      );
    });
  });
}
