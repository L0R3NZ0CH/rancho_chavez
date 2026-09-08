import 'package:flutter/material.dart';

import '../../comun/fechas.dart';
import '../../comun/tema.dart';
import '../../data/db/base_datos.dart';
import '../../data/repos/hato.dart';
import '../../domain/reglas/estado_animal.dart';
import '../escaneo/pantalla_escaneo.dart';

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

    return StreamBuilder<List<AnimalEnLista>>(
      stream: repo.verHato(hoy: hoy),
      builder: (context, snap) {
        final datos =
            snap.data?.where((a) => a.animal.id == animalId).firstOrNull;

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
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
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

  Future<void> _ponerArete(BuildContext context) async {
    final numero = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const PantallaEscaneo()),
    );
    if (numero == null || !context.mounted) return;

    final ocupado = await db.animalPorArete(numero);
    if (!context.mounted) return;

    if (ocupado != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Paleta.alerta,
          content: Text(
            'El arete $numero ya lo trae otro animal.',
            style: const TextStyle(fontSize: 17),
          ),
        ),
      );
      return;
    }

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
              'Usa el boton de arriba para ligarle el arete cuando se lo '
              'pongas.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        const Text(
          'ULTIMO PESO',
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
              'Pesado el ${formateaAaaammdd(datos.ultimoPesoFecha!)}  ·  hace '
              '${diasEntre(datos.ultimoPesoFecha!, hoy)} dias',
              style: const TextStyle(fontSize: 16, color: Paleta.textoSuave),
            ),
          ),
        const SizedBox(height: 18),
        _Dato(
          etiqueta: 'Categoria',
          valor: datos.categoria.etiqueta +
              (datos.categoriaCorregida ? '  (puesta a mano)' : ''),
        ),
        if (datos.proximoCambioCategoria != null)
          _Dato(
            etiqueta: 'Cambia de categoria',
            valor: formateaAaaammdd(datos.proximoCambioCategoria!),
          ),
        _Dato(
          etiqueta: 'Donde esta',
          valor: datos.ubicacionNombre == null
              ? 'Sin ubicacion'
              : '${datos.ubicacionNombre}'
                  '${datos.enUbicacionDesde == null ? '' : '  ·  desde hace '
                      '${diasEntre(datos.enUbicacionDesde!, hoy)} dias'}',
        ),
        _Dato(etiqueta: 'Sexo', valor: datos.animal.sexo),
        _Dato(etiqueta: 'Origen', valor: datos.animal.origen),
        if (datos.animal.apodo != null)
          _Dato(etiqueta: 'Apodo', valor: datos.animal.apodo!),
        if (datos.animal.descripcionFisica != null)
          _Dato(etiqueta: 'Senas', valor: datos.animal.descripcionFisica!),
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
    return Column(
      children: [
        BotonGrande(
          etiqueta: 'PESAR',
          icono: Icons.monitor_weight_outlined,
          onPressed: () => _pesar(context),
        ),
        const SizedBox(height: 10),
        BotonGrande(
          etiqueta: 'MOVER DE POTRERO',
          icono: Icons.swap_horiz,
          contorno: true,
          onPressed: () => _mover(context),
        ),
      ],
    );
  }

  Future<void> _pesar(BuildContext context) async {
    final kilos = await showDialog<double>(
      context: context,
      builder: (_) => const _DialogoPeso(),
    );
    if (kilos == null) return;
    await db.registrarPeso(
      animalId: animalId,
      kilos: kilos,
      fecha: hoyAaaammdd(),
    );
  }

  Future<void> _mover(BuildContext context) async {
    final ubicaciones = await db.verUbicaciones().first;
    if (!context.mounted) return;

    final destino = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Mover a'),
        children: [
          for (final u in ubicaciones)
            if (u.id != datos.ubicacionId)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, u.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(u.nombre, style: const TextStyle(fontSize: 20)),
                ),
              ),
        ],
      ),
    );
    if (destino == null) return;

    await db.registrarMovimiento(
      animalId: animalId,
      ubicacionDestinoId: destino,
      ubicacionOrigenId: datos.ubicacionId,
      fecha: hoyAaaammdd(),
    );
  }
}

class _Historial extends StatelessWidget {
  const _Historial({required this.db, required this.animalId});

  final BaseDatos db;
  final String animalId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Evento>>(
      stream: db.verEventos(animalId),
      builder: (context, snap) {
        final eventos = snap.data ?? const <Evento>[];
        if (eventos.isEmpty) {
          return const Text(
            'Sin eventos todavia.',
            style: TextStyle(fontSize: 17, color: Paleta.textoSuave),
          );
        }

        return Column(
          children: [
            for (final e in eventos)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(
                        formateaAaaammdd(e.fechaEvento),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Paleta.textoSuave,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _describe(e.tipo),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
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

  String _describe(String tipo) => switch (tipo) {
        'movimiento' => 'Movimiento',
        'peso' => 'Pesaje',
        'destete' => 'Destete',
        'parto' => 'Parto',
        'proposito' => 'Cambio de proposito',
        'correccionCategoria' => 'Categoria corregida a mano',
        _ => tipo,
      };
}

class _DialogoPeso extends StatefulWidget {
  const _DialogoPeso();

  @override
  State<_DialogoPeso> createState() => _DialogoPesoState();
}

class _DialogoPesoState extends State<_DialogoPeso> {
  final _kilos = TextEditingController();

  @override
  void dispose() {
    _kilos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Peso en kilos'),
      content: TextField(
        controller: _kilos,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          suffixText: 'kg',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(fontSize: 18)),
        ),
        TextButton(
          onPressed: () {
            final v = double.tryParse(_kilos.text.trim());
            if (v != null && v > 0) Navigator.pop(context, v);
          },
          child: const Text('Guardar', style: TextStyle(fontSize: 18)),
        ),
      ],
    );
  }
}
