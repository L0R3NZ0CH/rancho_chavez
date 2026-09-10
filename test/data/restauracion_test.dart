import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganado/data/db/base_datos.dart';
import 'package:ganado/data/restauracion.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

/// Un respaldo que nadie ha probado que sirva no es un respaldo: es un archivo
/// que da tranquilidad falsa. Estas pruebas hacen el viaje completo —crear la
/// base, meterla en un ZIP, revisarla y leer lo que trae— y sobre todo
/// verifican que un archivo malo se **rechace antes** de tocar nada.
void main() {
  late Directory temporal;

  setUp(() => temporal = Directory.systemTemp.createTempSync('ganado_restaurar'));
  tearDown(() {
    if (temporal.existsSync()) temporal.deleteSync(recursive: true);
  });

  String ruta(String nombre) => p.join(temporal.path, nombre);

  /// Crea una base con animales y la empaqueta como respaldo.
  Future<File> respaldoCon(int cuantosAnimales) async {
    final rutaDb = ruta('ganado.sqlite');
    final db = BaseDatos(NativeDatabase(File(rutaDb)));
    final potrero = await db.crearUbicacion(nombre: 'El Río', tipo: 'potrero');
    for (var i = 0; i < cuantosAnimales; i++) {
      await db.altaAnimal(
        sexo: 'macho',
        origen: 'comprado',
        proposito: 'comercial',
        ubicacionId: potrero,
        fecha: 20260908,
        numeroArete: '00140987${i.toString().padLeft(4, '0')}',
      );
    }
    await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    await db.close();

    final zip = File(ruta('respaldo.zip'));
    final enc = ZipFileEncoder()..create(zip.path);
    await enc.addFile(File(rutaDb), 'ganado.sqlite');
    await enc.close();
    return zip;
  }

  group('revisar un respaldo bueno', () {
    test('dice cuantos animales trae, sin tocar nada', () async {
      final zip = await respaldoCon(3);

      final resumen = await revisarRespaldo(zip);
      addTearDown(() => descartarRespaldo(resumen));

      expect(resumen.animales, 3);
      // Cada alta deja movimiento y proposito.
      expect(resumen.eventos, 6);
      expect(resumen.version, versionEsquema);
    });

    test('un respaldo vacio se puede revisar igual', () async {
      final zip = await respaldoCon(0);
      final resumen = await revisarRespaldo(zip);
      addTearDown(() => descartarRespaldo(resumen));

      expect(resumen.animales, 0);
    });

    test('la base extraida se puede abrir y consultar', () async {
      final zip = await respaldoCon(2);
      final resumen = await revisarRespaldo(zip);
      addTearDown(() => descartarRespaldo(resumen));

      final db = BaseDatos(NativeDatabase(File(resumen.rutaDbExtraida)));
      addTearDown(db.close);
      expect(await db.verAnimales().first, hasLength(2));
    });
  });

  group('un respaldo malo se rechaza ANTES de tocar los datos', () {
    test('un archivo que no existe', () async {
      expect(
        () => revisarRespaldo(File(ruta('no-existe.zip'))),
        throwsA(isA<RespaldoInvalido>()),
      );
    });

    test('un archivo que no es un ZIP', () async {
      final basura = File(ruta('basura.zip'))
        ..writeAsStringSync('esto no es un respaldo');
      expect(
        () => revisarRespaldo(basura),
        throwsA(isA<RespaldoInvalido>()),
      );
    });

    test('un ZIP sin la base adentro', () async {
      final zip = File(ruta('vacio.zip'));
      final enc = ZipFileEncoder()..create(zip.path);
      await enc.addFile(
        File(ruta('cualquiera.txt'))..writeAsStringSync('hola'),
        'cualquiera.txt',
      );
      await enc.close();

      expect(() => revisarRespaldo(zip), throwsA(isA<RespaldoInvalido>()));
    });

    test('un ZIP con una base que no es de Ganado', () async {
      final ajena = File(ruta('ganado.sqlite'));
      final crudo = sqlite3.open(ajena.path);
      crudo.execute('CREATE TABLE recetas (id INTEGER PRIMARY KEY)');
      crudo.close();

      final zip = File(ruta('ajena.zip'));
      final enc = ZipFileEncoder()..create(zip.path);
      await enc.addFile(ajena, 'ganado.sqlite');
      await enc.close();

      expect(() => revisarRespaldo(zip), throwsA(isA<RespaldoInvalido>()));
    });

    test('un respaldo de una version mas nueva de la app', () async {
      // Restaurarlo dejaria la base en un esquema que esta app no entiende.
      final futura = File(ruta('ganado.sqlite'));
      final crudo = sqlite3.open(futura.path);
      crudo
        ..execute('CREATE TABLE animales (id TEXT, eliminado_en INTEGER)')
        ..execute('CREATE TABLE eventos (id TEXT, eliminado_en INTEGER)')
        ..userVersion = versionEsquema + 5;
      crudo.close();

      final zip = File(ruta('futuro.zip'));
      final enc = ZipFileEncoder()..create(zip.path);
      await enc.addFile(futura, 'ganado.sqlite');
      await enc.close();

      expect(() => revisarRespaldo(zip), throwsA(isA<RespaldoInvalido>()));
    });

    test('ningun rechazo deja basura en el temporal', () async {
      final basura = File(ruta('basura.zip'))
        ..writeAsStringSync('esto no es un respaldo');
      final antes = Directory.systemTemp
          .listSync()
          .whereType<Directory>()
          .where((d) => p.basename(d.path).startsWith('ganado_restaurar'))
          .length;

      await expectLater(
        revisarRespaldo(basura),
        throwsA(isA<RespaldoInvalido>()),
      );

      final despues = Directory.systemTemp
          .listSync()
          .whereType<Directory>()
          .where((d) => p.basename(d.path).startsWith('ganado_restaurar'))
          .length;
      expect(despues, antes);
    });
  });
}
