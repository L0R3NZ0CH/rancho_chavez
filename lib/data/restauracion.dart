import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'db/base_datos.dart';
import 'db/rutas.dart';

/// Lo que trae un archivo de respaldo, leído **antes** de tocar nada.
class ResumenRespaldo {
  const ResumenRespaldo({
    required this.animales,
    required this.eventos,
    required this.fotos,
    required this.version,
    required this.rutaDbExtraida,
    required this.carpetaExtraida,
  });

  final int animales;
  final int eventos;
  final int fotos;
  final int version;

  /// Donde quedó la base extraída, lista para copiarse encima si el usuario
  /// confirma.
  final String rutaDbExtraida;
  final Directory carpetaExtraida;
}

/// El respaldo no sirve para esto.
class RespaldoInvalido implements Exception {
  const RespaldoInvalido(this.motivo);
  final String motivo;

  @override
  String toString() => motivo;
}

/// Abre el respaldo y dice qué trae, **sin tocar los datos del celular**.
///
/// Esta es la parte que vuelve confiable a un respaldo. Restaurar a ciegas y
/// descubrir después que el archivo venía truncado es perder el hato dos veces:
/// una por el accidente y otra por la restauración. Aquí se abre la base
/// extraída, se comprueba que tenga las tablas del hato y se cuenta lo que
/// trae, para que el usuario decida viendo números y no un nombre de archivo.
Future<ResumenRespaldo> revisarRespaldo(File zip) async {
  if (!zip.existsSync()) {
    throw const RespaldoInvalido('El archivo ya no existe.');
  }

  final destino = await Directory.systemTemp.createTemp('ganado_restaurar');

  try {
    await extractFileToDisk(zip.path, destino.path);
  } on Exception {
    destino.deleteSync(recursive: true);
    throw const RespaldoInvalido(
      'El archivo no se pudo abrir. ¿Seguro que es un respaldo de Ganado?',
    );
  }

  final db = File(p.join(destino.path, 'ganado.sqlite'));
  if (!db.existsSync()) {
    destino.deleteSync(recursive: true);
    throw const RespaldoInvalido(
      'El archivo no trae la base de datos adentro.',
    );
  }

  final int animales;
  final int eventos;
  final int version;
  try {
    final crudo = sqlite3.open(db.path, mode: OpenMode.readOnly);
    try {
      final tablas = crudo
          .select("SELECT name FROM sqlite_master WHERE type='table'")
          .map((f) => f['name'] as String)
          .toSet();
      if (!tablas.contains('animales')) {
        throw const RespaldoInvalido(
          'La base del respaldo no tiene el hato adentro.',
        );
      }

      version = crudo.userVersion;
      animales = crudo
          .select('SELECT COUNT(*) AS n FROM animales WHERE eliminado_en IS NULL')
          .first['n'] as int;
      eventos = crudo
          .select('SELECT COUNT(*) AS n FROM eventos WHERE eliminado_en IS NULL')
          .first['n'] as int;
    } finally {
      crudo.close();
    }
  } on RespaldoInvalido {
    destino.deleteSync(recursive: true);
    rethrow;
  } on SqliteException {
    destino.deleteSync(recursive: true);
    throw const RespaldoInvalido('La base del respaldo está dañada.');
  }

  if (version > versionEsquema) {
    destino.deleteSync(recursive: true);
    throw RespaldoInvalido(
      'Ese respaldo viene de una versión más nueva de la app (versión '
      '$version). Actualiza la app antes de restaurarlo.',
    );
  }

  final carpetaFotosZip = Directory(p.join(destino.path, 'fotos'));
  final fotos = carpetaFotosZip.existsSync()
      ? carpetaFotosZip.listSync().whereType<File>().length
      : 0;

  return ResumenRespaldo(
    animales: animales,
    eventos: eventos,
    fotos: fotos,
    version: version,
    rutaDbExtraida: db.path,
    carpetaExtraida: destino,
  );
}

/// Reemplaza los datos del celular con los del respaldo.
///
/// Antes de pisar nada guarda lo que hay ahora en `.antes_de_restaurar`, para
/// que restaurar el respaldo equivocado no sea el final del camino.
///
/// La base tiene que estar **cerrada** antes de llamar aquí.
Future<String> aplicarRespaldo(ResumenRespaldo resumen) async {
  final rutaActual = await rutaBaseDatos();
  final actual = File(rutaActual);

  final rollback = '$rutaActual.antes_de_restaurar';
  if (actual.existsSync()) {
    actual.copySync(rollback);
  }

  // Los archivos -wal y -shm son el diario de escritura de la base que se esta
  // reemplazando. Si se quedan, SQLite los va a querer aplicar sobre la base
  // nueva y el resultado es una base corrupta. Se borran a proposito.
  for (final sufijo in ['-wal', '-shm']) {
    final diario = File('$rutaActual$sufijo');
    if (diario.existsSync()) diario.deleteSync();
  }

  File(resumen.rutaDbExtraida).copySync(rutaActual);

  // Las fotos: se reemplaza la carpeta completa.
  final fotosDestino = await carpetaFotos();
  final fotosOrigen = Directory(
    p.join(resumen.carpetaExtraida.path, 'fotos'),
  );
  if (fotosOrigen.existsSync()) {
    for (final f in fotosOrigen.listSync().whereType<File>()) {
      f.copySync(p.join(fotosDestino.path, p.basename(f.path)));
    }
  }

  resumen.carpetaExtraida.deleteSync(recursive: true);
  return rollback;
}

/// Tira lo extraído cuando el usuario se arrepiente.
void descartarRespaldo(ResumenRespaldo resumen) {
  if (resumen.carpetaExtraida.existsSync()) {
    resumen.carpetaExtraida.deleteSync(recursive: true);
  }
}
