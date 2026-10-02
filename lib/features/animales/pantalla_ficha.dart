import 'package:flutter/material.dart';

import '../../comun/arete_libre.dart';
import '../../comun/confirmar.dart';
import '../../comun/fechas.dart';
import '../../comun/tema.dart';
import '../../data/db/base_datos.dart';
import '../../data/repos/hato.dart';
import '../../data/repos/historial.dart';
import '../../domain/modelos/tipos.dart';
import '../../domain/reglas/estado_animal.dart';
import '../escaneo/pantalla_escaneo.dart';
import 'galeria_animal.dart';
import '../manejo/dialogo_manejo.dart';

/// La ficha de un animal.
///
/// Encabeza con el **peso**, no con la categoria: es lo que de verdad se mira
/// en este rancho. La categoria queda como etiqueta al lado.
class PantallaFicha extends StatelessWidget {
  const PantallaFicha({super.key, required this.db, required this.animalId});

  final BaseDatos db;
  final String animalId;

  @override
  Widget build(BuildContext context) {
    final repo = RepoHato(db);
    final hoy = hoyAaaammdd();

    return StreamBuilder<AnimalEnLista?>(
      stream: repo.verAnimal(animalId, hoy: hoy),
      builder: (context, snap) {
        final datos = snap.data;

        if (datos == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Animal')),
            body: const Center(
              child: Text('Sin datos', style: TextStyle(fontSize: 18)),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(datos.titulo),
            actions: [
              if (datos.pendienteDeAretar)
                IconButton(
                  tooltip: 'Ponerle arete',
                  iconSize: 30,
                  icon: const Icon(Icons.label_outline),
                  onPressed: () => _ponerArete(context),
                ),
              IconButton(
                tooltip: 'Borrar el animal',
                iconSize: 30,
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _borrar(context, datos.titulo),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GaleriaAnimal(
                  db: db,
                  animalId: animalId,
                  puedeEditar: !datos.deBaja,
                ),
                _Encabezado(datos: datos, hoy: hoy),
                const SizedBox(height: 20),
                _Acciones(db: db, animalId: animalId, datos: datos),
                const SizedBox(height: 24),
                const Text(
                  'Historial',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                _Historial(db: db, animalId: animalId),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Borrado logico: el animal sale de las listas pero su historial se queda
  /// en la base, porque nada se borra de verdad (regla 3).
  Future<void> _borrar(BuildContext context, String titulo) async {
    final confirmado = await confirmarBorrado(
      context,
      titulo: 'Borrar este animal',
      mensaje: '$titulo sale del hato y de los conteos.\n\nSu historial se '
          'conserva en la base por si hay que recuperarlo.',
    );
    if (!(confirmado ?? false) || !context.mounted) return;

    await db.eliminarAnimal(animalId);
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _ponerArete(BuildContext context) async {
    final numero = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const PantallaEscaneo()),
    );
    if (numero == null || !context.mounted) return;

    final libre = await areteSePuedeUsar(context, db, numero);
    if (!libre) return;

    await db.ponerArete(
      animalId: animalId,
      numero: numero,
      fecha: hoyAaaammdd(),
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.datos, required this.hoy});

  final AnimalEnLista datos;
  final int hoy;

  @override
  Widget build(BuildContext context) {
    final peso = datos.ultimoPesoKg;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (datos.deBaja)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Paleta.textoSuave,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'YA NO ESTÁ EN EL RANCHO\n'
              'Salió del hato y de los conteos. Su historial se conserva '
              'completo.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        if (datos.pendienteDeAretar)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Paleta.aviso,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'PENDIENTE DE ARETAR\n'
              'Usa el botón de arriba para ligarle el arete cuando se lo '
              'pongas.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        const Text(
          'ÚLTIMO PESO',
          style: TextStyle(
            fontSize: 14,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w800,
            color: Paleta.textoSuave,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              peso == null ? '—' : peso.toStringAsFixed(0),
              style: const TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              peso == null ? 'sin pesar' : 'kg',
              style: const TextStyle(
                fontSize: 22,
                color: Paleta.textoSuave,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        if (datos.ultimoPesoFecha != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Pesado el ${formateaAaaammdd(datos.ultimoPesoFecha!)}  ·  '
              '${diasEnPalabras(diasEntre(datos.ultimoPesoFecha!, hoy))}',
              style: const TextStyle(fontSize: 16, color: Paleta.textoSuave),
            ),
          ),
        const SizedBox(height: 18),
        // Solo cuando se sabe: ver "Sin clasificar" en cada ficha no le dice
        // nada a nadie.
        if (datos.categoria != Categoria.sinClasificar)
          _Dato(
            etiqueta: 'Categoría',
            valor: datos.categoria.etiqueta +
                (datos.categoriaCorregida ? '  (puesta a mano)' : ''),
          ),
        if (datos.proximoCambioCategoria != null)
          _Dato(
            etiqueta: 'Cambia de categoría',
            valor: formateaAaaammdd(datos.proximoCambioCategoria!),
          ),
        _Dato(
          etiqueta: 'Dónde está',
          valor: datos.ubicacionNombre == null
              ? 'Sin ubicación'
              : '${datos.ubicacionNombre}'
                  '${datos.enUbicacionDesde == null ? '' : '  ·  llego '
                      '${diasEnPalabras(diasEntre(datos.enUbicacionDesde!, hoy))}'}',
        ),
        _Dato(etiqueta: 'Sexo', valor: datos.animal.sexo),
        _Dato(etiqueta: 'Origen', valor: datos.animal.origen),
        if (datos.animal.apodo != null)
          _Dato(etiqueta: 'Apodo', valor: datos.animal.apodo!),
        if (datos.animal.descripcionFisica != null)
          _Dato(etiqueta: 'Señas', valor: datos.animal.descripcionFisica!),
        if (datos.animal.nacimientoNota != null)
          _Dato(etiqueta: 'Edad', valor: datos.animal.nacimientoNota!),
      ],
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              etiqueta,
              style: const TextStyle(fontSize: 17, color: Paleta.textoSuave),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Acciones extends StatelessWidget {
  const _Acciones({
    required this.db,
    required this.animalId,
    required this.datos,
  });

  final BaseDatos db;
  final String animalId;
  final AnimalEnLista datos;

  @override
  Widget build(BuildContext context) {
    // A un animal que ya salio del hato no se le apunta nada nuevo: su
    // historial quedo cerrado.
    if (datos.deBaja) return const SizedBox.shrink();

    return Column(
      children: [
        BotonGrande(
          etiqueta: 'REGISTRAR MANEJO',
          icono: Icons.edit_note,
          onPressed: () => _manejo(context),
        ),
      ],
    );
  }

  /// Apuntar lo que se le hizo hoy.
  ///
  /// Peso, bano, desparasitada, lo que sea, y de paso cambiarlo de lugar. Todo
  /// queda como apunte con su fecha: **nada se sobrescribe**.
  Future<void> _manejo(BuildContext context) async {
    final lugares = await db.verUbicaciones().first;
    if (!context.mounted) return;

    final apunte = await registrarManejo(
      context,
      titulo: datos.titulo,
      lugares: lugares,
      lugarActualId: datos.ubicacionId,
    );
    if (apunte == null) return;

    final hoy = hoyAaaammdd();

    if (apunte.pesoKg != null) {
      await db.registrarPeso(
        animalId: animalId,
        kilos: apunte.pesoKg!,
        fecha: hoy,
      );
    }

    if (apunte.banado || apunte.desparasitado || apunte.otro != null) {
      await db.registrarManejo(
        animalId: animalId,
        fecha: hoy,
        banado: apunte.banado,
        desparasitado: apunte.desparasitado,
        otro: apunte.otro,
      );
    }

    if (apunte.nuevoLugarId != null) {
      await db.registrarMovimiento(
        animalId: animalId,
        ubicacionDestinoId: apunte.nuevoLugarId!,
        ubicacionOrigenId: datos.ubicacionId,
        fecha: hoy,
      );
    }
  }

}

class _Historial extends StatelessWidget {
  const _Historial({required this.db, required this.animalId});

  final BaseDatos db;
  final String animalId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ApunteHistorial>>(
      stream: RepoHistorial(db).verStream(animalId),
      builder: (context, snap) {
        final apuntes = snap.data ?? const <ApunteHistorial>[];
        if (apuntes.isEmpty) {
          return const Text(
            'Sin apuntes todavía.',
            style: TextStyle(fontSize: 17, color: Paleta.textoSuave),
          );
        }

        return Column(
          children: [
            for (final a in apuntes)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 108,
                      child: Text(
                        a.fechaEnPalabras,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Paleta.textoSuave,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.titulo,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (a.detalle != null)
                            Text(
                              a.detalle!,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Paleta.textoSuave,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
