import 'dart:io';

import 'package:flutter/material.dart';

import '../../comun/confirmar.dart';
import '../../comun/fotos.dart';
import '../../comun/tema.dart';
import '../../data/db/base_datos.dart';

/// Las fotos de un animal.
///
/// La principal se ve en grande y las demás abajo, chiquitas. Se toman, se
/// cambian, se agregan más y se borran — todo desde aquí, en cualquier momento.
///
/// Un animal sin foto no se ve vacío: se ve un botón grande que invita a
/// tomarla. La foto importa sobre todo en los que no traen arete, que son los
/// que no hay otra forma de reconocer.
class GaleriaAnimal extends StatelessWidget {
  const GaleriaAnimal({
    super.key,
    required this.db,
    required this.animalId,
    this.puedeEditar = true,
  });

  final BaseDatos db;
  final String animalId;

  /// Un animal que ya salió del hato no recibe fotos nuevas.
  final bool puedeEditar;

  Future<void> _tomar(BuildContext context) async {
    final ruta = await tomarFoto();
    if (ruta == null) return;
    await db.agregarFoto(animalId: animalId, rutaRelativa: ruta);
  }

  Future<void> _elegir(BuildContext context) async {
    final ruta = await elegirFoto();
    if (ruta == null) return;
    await db.agregarFoto(animalId: animalId, rutaRelativa: ruta);
  }

  Future<void> _borrar(BuildContext context, Foto foto) async {
    final ok = await confirmarBorrado(
      context,
      titulo: 'Borrar esta foto',
      mensaje: 'La foto se borra del celular y deja de pesar en el '
          'respaldo.\n\nEl animal no se toca.',
    );
    if (!(ok ?? false)) return;

    await db.eliminarFoto(animalId: animalId, fotoId: foto.id);
    await borrarArchivoDeFoto(foto.rutaRelativa);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Foto>>(
      stream: db.verFotos(animalId),
      builder: (context, snap) {
        final lista = snap.data ?? const <Foto>[];

        if (lista.isEmpty) {
          if (!puedeEditar) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: BotonGrande(
              etiqueta: 'TOMARLE FOTO',
              icono: Icons.photo_camera,
              contorno: true,
              onPressed: () => _tomar(context),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Grande(
                foto: lista.first,
                onBorrar:
                    puedeEditar ? () => _borrar(context, lista.first) : null,
              ),
              if (lista.length > 1) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 92,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: lista.length - 1,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, i) {
                      final foto = lista[i + 1];
                      return _Chica(
                        foto: foto,
                        onPrincipal: puedeEditar
                            ? () => db.marcarFotoPrincipal(
                                  animalId: animalId,
                                  fotoId: foto.id,
                                )
                            : null,
                        onBorrar:
                            puedeEditar ? () => _borrar(context, foto) : null,
                      );
                    },
                  ),
                ),
              ],
              if (puedeEditar) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _tomar(context),
                        icon: const Icon(Icons.photo_camera, size: 22),
                        label: const Text(
                          'OTRA FOTO',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          foregroundColor: Paleta.texto,
                          side: const BorderSide(
                            color: Paleta.borde,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _elegir(context),
                        icon: const Icon(Icons.photo_library_outlined,
                            size: 22),
                        label: const Text(
                          'DE LA GALERÍA',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          foregroundColor: Paleta.textoSuave,
                          side: const BorderSide(
                            color: Paleta.borde,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Grande extends StatelessWidget {
  const _Grande({required this.foto, this.onBorrar});

  final Foto foto;
  final VoidCallback? onBorrar;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          _Imagen(ruta: foto.rutaRelativa, alto: 260),
          if (onBorrar != null)
            Positioned(
              top: 6,
              right: 6,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onBorrar,
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.delete_outline,
                        color: Colors.white, size: 24),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Chica extends StatelessWidget {
  const _Chica({required this.foto, this.onPrincipal, this.onBorrar});

  final Foto foto;
  final VoidCallback? onPrincipal;
  final VoidCallback? onBorrar;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Un toque la pone de principal; mantener apretado la borra.
      onTap: onPrincipal,
      onLongPress: onBorrar,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 92,
          child: _Imagen(ruta: foto.rutaRelativa, alto: 92),
        ),
      ),
    );
  }
}

class _Imagen extends StatelessWidget {
  const _Imagen({required this.ruta, required this.alto});

  final String ruta;
  final double alto;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File>(
      future: archivoDeFoto(ruta),
      builder: (context, snap) {
        final archivo = snap.data;
        if (archivo == null || !archivo.existsSync()) {
          // La foto se perdio: puede pasar si se restauro un respaldo viejo
          // que no la traia. Se dice, en vez de dejar un hueco gris.
          return Container(
            height: alto,
            width: double.infinity,
            color: Paleta.fondoSuave,
            alignment: Alignment.center,
            child: const Text(
              'Falta el archivo',
              style: TextStyle(fontSize: 14, color: Paleta.textoSuave),
            ),
          );
        }
        return Image.file(
          archivo,
          height: alto,
          width: double.infinity,
          fit: BoxFit.cover,
        );
      },
    );
  }
}
