import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

/// Donde vive la base de datos.
///
/// La ruta se fija aqui y no se deja al valor por omision de drift_flutter,
/// porque hace falta poder abrir el archivo por fuera para respaldarlo antes de
/// migrar y para meterlo en el ZIP del respaldo.
Future<String> rutaBaseDatos() async {
  final dir = await getApplicationDocumentsDirectory();
  return p.join(dir.path, 'ganado.sqlite');
}

/// Carpeta de las fotos. Se guarda la ruta relativa a esta carpeta, nunca la
/// absoluta: al reinstalar la app o al restaurar un respaldo, la carpeta de
/// datos cambia de lugar y las rutas absolutas quedarian rotas.
Future<Directory> carpetaFotos() async {
  final dir = await getApplicationDocumentsDirectory();
  final fotos = Directory(p.join(dir.path, 'fotos'));
  if (!fotos.existsSync()) fotos.createSync(recursive: true);
  return fotos;
}

/// Copia la base de datos antes de migrarla.
///
/// Es la tercera pata del compromiso de no perder datos, junto con las
/// migraciones paso a paso y las pruebas de migracion. Las otras dos evitan que
/// una migracion mala llegue al celular; esta es la red por si alguna se cuela.
///
/// Se hace **antes** de que drift abra el archivo, a proposito: copiar una base
/// SQLite abierta puede dejar una copia inconsistente si hay un diario sin
/// consolidar.
///
/// Devuelve la ruta de la copia, o null si no hubo nada que respaldar: base
/// nueva, o ya en la version buena.
Future<String?> respaldarAntesDeMigrar({
  required String ruta,
  required int versionObjetivo,
}) async {
  final archivo = File(ruta);
  if (!archivo.existsSync()) return null;

  final int versionActual;
  try {
    final db = sqlite3.open(ruta, mode: OpenMode.readOnly);
    try {
      versionActual = db.userVersion;
    } finally {
      db.close();
    }
  } on SqliteException {
    // Si el archivo esta corrupto o no se puede leer, no se toca. Que falle la
    // apertura de verdad, con su error, en vez de sobrescribir algo a ciegas.
    return null;
  }

  if (versionActual == 0 || versionActual >= versionObjetivo) return null;

  final destino = '$ruta.previo_v$versionActual';
  archivo.copySync(destino);
  return destino;
}
