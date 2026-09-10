import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganado/data/db/base_datos.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

/// La primera forma de la versión 3 sí llegó a un celular.
///
/// Modelaba la compra como un camión de un solo dueño: la tabla traía
/// `monto_total` y `forma_prorrateo_gastos` obligatorios, y una tabla de
/// gastos. Cuando el dueño la rechazó, redefiní la versión 3 dando por hecho
/// que nunca se había instalado. Me equivoqué: se instaló mientras `adb` decía
/// "waiting for device", y ese celular se quedó con la tabla vieja. Como ya
/// estaba en la versión 3, ninguna migración volvió a tocarla.
///
/// El resultado es que crear una compra reventaba con `SQLITE_CONSTRAINT_NOTNULL`
/// (1299): la app ya no manda `monto_total`, pero la columna seguía siendo
/// obligatoria.
///
/// Estas pruebas arman esa base exacta y comprueban que ahora se repare sola.
void main() {
  late Directory temporal;

  setUp(() => temporal = Directory.systemTemp.createTempSync('ganado_v3'));
  tearDown(() => temporal.deleteSync(recursive: true));

  String ruta(String n) => p.join(temporal.path, n);

  /// Arma una base tal como la dejó la primera versión 3.
  void crearV3Vieja(String rutaDb, {bool conDatos = false}) {
    final db = sqlite3.open(rutaDb);
    db
      ..execute('''
        CREATE TABLE configuracion (
          clave TEXT NOT NULL PRIMARY KEY,
          valor TEXT NOT NULL
        );
      ''')
      ..execute('''
        CREATE TABLE animales (
          id TEXT NOT NULL PRIMARY KEY,
          creado_en INTEGER NOT NULL,
          modificado_en INTEGER NOT NULL,
          eliminado_en INTEGER,
          dispositivo_id TEXT NOT NULL,
          apodo TEXT,
          sexo TEXT NOT NULL,
          fecha_nacimiento INTEGER,
          nacimiento_precision TEXT NOT NULL DEFAULT 'desconocida',
          nacimiento_nota TEXT,
          raza TEXT,
          descripcion_fisica TEXT,
          origen TEXT NOT NULL,
          madre_id TEXT,
          padre_id TEXT,
          notas TEXT
        );
      ''')
      // Aqui esta el problema: monto_total y forma_prorrateo_gastos.
      ..execute('''
        CREATE TABLE lotes_compra (
          id TEXT NOT NULL PRIMARY KEY,
          creado_en INTEGER NOT NULL,
          modificado_en INTEGER NOT NULL,
          eliminado_en INTEGER,
          dispositivo_id TEXT NOT NULL,
          fecha INTEGER NOT NULL,
          vendedor TEXT NOT NULL,
          lugar TEXT,
          forma_calculo TEXT NOT NULL,
          precio_por_kilo REAL,
          monto_total REAL NOT NULL,
          forma_prorrateo_gastos TEXT NOT NULL DEFAULT 'porCabeza',
          notas TEXT
        );
      ''')
      ..execute('''
        CREATE TABLE lote_compra_animales (
          id TEXT NOT NULL PRIMARY KEY,
          creado_en INTEGER NOT NULL,
          modificado_en INTEGER NOT NULL,
          eliminado_en INTEGER,
          dispositivo_id TEXT NOT NULL,
          lote_compra_id TEXT NOT NULL,
          animal_id TEXT NOT NULL,
          costo_individual REAL
        );
      ''')
      ..execute('''
        CREATE TABLE lote_compra_gastos (
          id TEXT NOT NULL PRIMARY KEY,
          creado_en INTEGER NOT NULL,
          modificado_en INTEGER NOT NULL,
          eliminado_en INTEGER,
          dispositivo_id TEXT NOT NULL,
          lote_compra_id TEXT NOT NULL,
          concepto TEXT NOT NULL,
          monto REAL NOT NULL
        );
      ''')
      ..execute('''
        INSERT INTO configuracion (clave, valor)
        VALUES ('dispositivoId', 'el-mismo-de-siempre');
      ''');

    if (conDatos) {
      db
        ..execute('''
          INSERT INTO animales
            (id, creado_en, modificado_en, dispositivo_id, sexo, origen)
          VALUES ('animal-1', 1, 1, 'disp', 'macho', 'comprado');
        ''')
        ..execute('''
          INSERT INTO lotes_compra
            (id, creado_en, modificado_en, dispositivo_id, fecha, vendedor,
             forma_calculo, precio_por_kilo, monto_total)
          VALUES ('compra-1', 1, 1, 'disp', 20260908, 'Don Chuy',
                  'porKilo', 62, 13144);
        ''')
        ..execute('''
          INSERT INTO lote_compra_animales
            (id, creado_en, modificado_en, dispositivo_id, lote_compra_id,
             animal_id, costo_individual)
          VALUES ('en-lote-1', 1, 1, 'disp', 'compra-1', 'animal-1', 9500);
        ''');
    }

    db.userVersion = 3;
    db.close();
  }

  test('sin el arreglo, crear una compra reventaba con NOT NULL', () async {
    // Se comprueba contra la tabla cruda, para dejar constancia de cual era el
    // error exacto que veia el dueno.
    final rutaDb = ruta('viejo.sqlite');
    crearV3Vieja(rutaDb);

    final crudo = sqlite3.open(rutaDb);
    addTearDown(crudo.close);

    expect(
      () => crudo.execute('''
        INSERT INTO lotes_compra
          (id, creado_en, modificado_en, dispositivo_id, fecha, vendedor,
           forma_calculo)
        VALUES ('x', 1, 1, 'disp', 20260908, 'Don Chuy', 'porKilo');
      '''),
      throwsA(
        isA<SqliteException>().having(
          (e) => e.extendedResultCode,
          'extendedResultCode',
          1299,
        ),
      ),
    );
  });

  test('la app repara la tabla vieja y ya se puede crear una compra', () async {
    final rutaDb = ruta('ganado.sqlite');
    crearV3Vieja(rutaDb);

    final db = BaseDatos(NativeDatabase(File(rutaDb)));
    addTearDown(db.close);

    final compra = await db.crearLoteCompra(
      fecha: 20260908,
      vendedor: 'Don Chuy',
      formaCalculo: 'porKilo',
      precioPorKilo: 62,
    );

    expect((await db.verLotesCompra().first).single.id, compra);
  });

  test('la reparacion no pierde las compras que ya estaban', () async {
    final rutaDb = ruta('ganado.sqlite');
    crearV3Vieja(rutaDb, conDatos: true);

    final db = BaseDatos(NativeDatabase(File(rutaDb)));
    addTearDown(db.close);

    final lotes = await db.verLotesCompra().first;
    expect(lotes, hasLength(1));
    expect(lotes.single.vendedor, 'Don Chuy');
    expect(lotes.single.precioPorKilo, 62);

    // El precio que se habia negociado aparte para un animal era
    // costo_individual; ahora ese concepto se llama precio por cabeza.
    final enLote = await db.animalesDelLote('compra-1');
    expect(enLote, hasLength(1));
    expect(enLote.single.precioPorCabeza, 9500);

    expect(await db.leerAjuste('dispositivoId'), 'el-mismo-de-siempre');
  });

  test('la tabla de gastos desaparece', () async {
    final rutaDb = ruta('ganado.sqlite');
    crearV3Vieja(rutaDb, conDatos: true);

    final db = BaseDatos(NativeDatabase(File(rutaDb)));
    await db.verLotesCompra().first;
    await db.close();

    final crudo = sqlite3.open(rutaDb);
    final tablas = crudo
        .select("SELECT name FROM sqlite_master WHERE type='table'")
        .map((f) => f['name'] as String)
        .toSet();
    crudo.close();

    expect(tablas, isNot(contains('lote_compra_gastos')));
    expect(tablas, contains('lotes_venta'));
  });
}
