import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../data/db/rutas.dart';

/// Lo más grande que se guarda una foto.
///
/// **Cada foto hace el respaldo más pesado, y el respaldo es lo que salva el
/// hato si se pierde el celular.** Una foto del celular tal cual sale pesa unos
/// 4 MB: cuatrocientos animales serían 1.6 GB, un archivo que ya no se puede
/// mandar por WhatsApp ni guardar en ningún lado. Y un respaldo que no se puede
/// mandar es un respaldo que no existe.
///
/// A 1200 píxeles una foto pesa unos 200 KB y se reconoce a un animal de sobra.
/// Cuatrocientos animales caben en unos 80 MB, que sí se manda.
const _anchoMaximo = 1200.0;
const _calidad = 82;

/// Toma una foto con la cámara del sistema y la guarda.
///
/// Se usa la cámara de Android y no una propia a propósito: su botón es enorme
/// y el usuario ya sabe usarla. Con guantes, cualquier cosa que yo dibujara
/// sería peor.
///
/// Devuelve la ruta **relativa** a la carpeta de fotos, nunca la absoluta: la
/// carpeta de datos de la app cambia de lugar al reinstalar y al restaurar un
/// respaldo, y una ruta absoluta quedaría rota.
Future<String?> tomarFoto() => _guardar(ImageSource.camera);

/// Elige una foto de la galería, para cuando ya se tomó con otra app.
Future<String?> elegirFoto() => _guardar(ImageSource.gallery);

Future<String?> _guardar(ImageSource origen) async {
  final tomada = await ImagePicker().pickImage(
    source: origen,
    maxWidth: _anchoMaximo,
    imageQuality: _calidad,
  );
  if (tomada == null) return null;

  final carpeta = await carpetaFotos();
  final nombre = '${const Uuid().v4()}.jpg';
  await File(tomada.path).copy(p.join(carpeta.path, nombre));

  return p.join('fotos', nombre);
}

/// La ruta completa de una foto, para poder pintarla.
Future<File> archivoDeFoto(String rutaRelativa) async {
  final carpeta = await carpetaFotos();
  return File(p.join(carpeta.parent.path, rutaRelativa));
}

/// Borra el archivo de una foto del almacenamiento.
///
/// El renglón de la base se marca como eliminado y se queda —regla 3— pero el
/// archivo sí se va. La regla protege los **datos** para poder sincronizar
/// algún día; los bytes de una foto que el dueño decidió tirar no son un dato
/// que haya que reconciliar, y dejarlos solo engordaría el respaldo, que es
/// justo lo que se quiso evitar al poder borrarlas.
Future<void> borrarArchivoDeFoto(String rutaRelativa) async {
  final archivo = await archivoDeFoto(rutaRelativa);
  if (archivo.existsSync()) await archivo.delete();
}

/// Cuánto pesan todas las fotos juntas.
///
/// Se enseña en la pantalla de respaldo para que la decisión de guardar muchas
/// fotos se tome viendo el costo, y no se descubra el día que el ZIP ya no se
/// pueda mandar.
Future<int> bytesDeLasFotos() async {
  final carpeta = await carpetaFotos();
  if (!carpeta.existsSync()) return 0;

  var total = 0;
  for (final f in carpeta.listSync().whereType<File>()) {
    total += await f.length();
  }
  return total;
}

String pesoEnPalabras(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
