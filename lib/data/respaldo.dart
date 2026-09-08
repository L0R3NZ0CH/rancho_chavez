import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'db/base_datos.dart';
import 'db/rutas.dart';

/// Clave donde se guarda cuando fue el ultimo respaldo exitoso.
const claveUltimoRespaldo = 'ultimoRespaldoEn';

/// A partir de cuantos registros sin respaldar se bloquea la navegacion.
const umbralDeuda = 10;

/// Cuantos registros se han creado desde el ultimo respaldo.
///
/// **No hay contador guardado.** Se cuenta comparando el sello de creacion de
/// cada fila contra la fecha del ultimo respaldo, asi que la regla 5 se
/// respeta y la cuenta nunca se desincroniza: no hay nada que desincronizar.
///
/// La deuda vive en la base de datos, no en memoria. Si Android mata la app,
/// al volver a abrirla la deuda sigue ahi y la pantalla bloqueante es lo
/// primero que se ve.
Future<int> deudaDeRespaldo(BaseDatos db) async {
  final desde = int.tryParse(await db.leerAjuste(claveUltimoRespaldo) ?? '') ?? 0;

  final animalesNuevos = await (db.selectOnly(db.animales)
        ..addColumns([db.animales.id.count()])
        ..where(db.animales.creadoEn.isBiggerThanValue(desde)))
      .getSingle();
  final eventosNuevos = await (db.selectOnly(db.eventos)
        ..addColumns([db.eventos.id.count()])
        ..where(db.eventos.creadoEn.isBiggerThanValue(desde)))
      .getSingle();

  return (animalesNuevos.read(db.animales.id.count()) ?? 0) +
      (eventosNuevos.read(db.eventos.id.count()) ?? 0);
}

/// Cuantos animales se han dado de alta desde el ultimo respaldo.
///
/// Es lo que se le muestra al usuario: "83 eventos" no le dice nada, "12
/// animales nuevos" si.
Future<int> animalesSinRespaldar(BaseDatos db) async {
  final desde = int.tryParse(await db.leerAjuste(claveUltimoRespaldo) ?? '') ?? 0;
  final fila = await (db.selectOnly(db.animales)
        ..addColumns([db.animales.id.count()])
        ..where(db.animales.creadoEn.isBiggerThanValue(desde)))
      .getSingle();
  return fila.read(db.animales.id.count()) ?? 0;
}

/// Arma el ZIP del respaldo: la base de datos y todas las fotos.
///
/// Las fotos van dentro a proposito. La base guarda rutas, no imagenes, asi que
/// un respaldo que solo lleve el `.sqlite` restauraria un hato con todas las
/// fotos rotas, y las fotos son lo unico que identifica a un animal que
/// todavia no trae arete.
Future<File> crearRespaldo(BaseDatos db) async {
  // Antes de copiar el archivo hay que consolidar el diario de escritura.
  // SQLite deja las escrituras recientes en un archivo -wal aparte; sin este
  // paso, el ZIP puede llevarse una base sin los ultimos registros, que son
  // justamente los que se estan respaldando.
  await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');

  final rutaDb = await rutaBaseDatos();
  final fotos = await carpetaFotos();

  final ahora = DateTime.now();
  final sello = '${ahora.year}'
      '${ahora.month.toString().padLeft(2, '0')}'
      '${ahora.day.toString().padLeft(2, '0')}-'
      '${ahora.hour.toString().padLeft(2, '0')}'
      '${ahora.minute.toString().padLeft(2, '0')}';

  final destino = await _carpetaDeRespaldos();
  final archivo = File(p.join(destino.path, 'ganado-respaldo-$sello.zip'));

  final zip = ZipFileEncoder()..create(archivo.path);
  try {
    await zip.addFile(File(rutaDb), 'ganado.sqlite');
    if (fotos.existsSync()) {
      await zip.addDirectory(fotos, includeDirName: true);
    }
  } finally {
    await zip.close();
  }

  return archivo;
}

/// Marca el respaldo como hecho. Solo se llama cuando el usuario confirma que
/// el archivo salio del celular.
Future<void> marcarRespaldado(BaseDatos db) =>
    db.escribirAjuste(claveUltimoRespaldo, '${DateTime.now().toUtc()
        .millisecondsSinceEpoch}');

Future<String?> fechaUltimoRespaldo(BaseDatos db) async {
  final ms = int.tryParse(await db.leerAjuste(claveUltimoRespaldo) ?? '');
  if (ms == null || ms == 0) return null;
  final d = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
  return '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
}

/// Carpeta donde se deja el ZIP.
///
/// Se prefiere el almacenamiento externo de la app, que si se alcanza con un
/// explorador de archivos del celular. Si no existe, se cae a la carpeta
/// interna: el archivo igual se puede compartir, que es la salida que de
/// verdad importa.
Future<Directory> _carpetaDeRespaldos() async {
  Directory? externa;
  try {
    externa = await getExternalStorageDirectory();
  } on Exception {
    externa = null;
  }
  final base = externa ?? await getApplicationDocumentsDirectory();
  final carpeta = Directory(p.join(base.path, 'respaldos'));
  if (!carpeta.existsSync()) carpeta.createSync(recursive: true);
  return carpeta;
}
