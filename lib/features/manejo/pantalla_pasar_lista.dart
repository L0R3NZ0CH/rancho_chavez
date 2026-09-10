import 'package:flutter/material.dart';

import '../../comun/fechas.dart';
import '../../comun/tema.dart';
import '../../data/db/base_datos.dart';
import '../escaneo/pantalla_escaneo.dart';

/// Pasar lista en un lugar.
///
/// Eliges un lugar y escaneas de corrida: **cada animal que escaneas queda
/// ahí**. Sirve para dos cosas que pasan seguido:
///
///   - Se rompió la cerca y los animales de dos potreros quedaron revueltos.
///     Cuando los separas, los vuelves a repartir escaneando.
///   - Simplemente quieres contar un potrero de verdad y cuadrarlo contra lo
///     que dice la app.
///
/// La app puede decirte que hay doce en el Río, pero eso es lo que se dedujo de
/// los movimientos. Esta pantalla es para cuando quieres saberlo por haberlos
/// visto.
class PantallaPasarLista extends StatefulWidget {
  const PantallaPasarLista({super.key, required this.db});

  final BaseDatos db;

  @override
  State<PantallaPasarLista> createState() => _PantallaPasarListaState();
}

class _PantallaPasarListaState extends State<PantallaPasarLista> {
  Ubicacion? _lugar;
  final _pasados = <String, String>{};
  final _desconocidos = <String>[];

  Future<void> _elegirLugar() async {
    final lugares = await widget.db.verUbicaciones().first;
    if (!mounted) return;

    if (lugares.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Paleta.aviso,
          content: Text(
            'Todavía no hay lugares. Crea uno en la pantalla de inicio.',
            style: TextStyle(fontSize: 17),
          ),
        ),
      );
      return;
    }

    final elegido = await showDialog<Ubicacion>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('¿En qué lugar estás parado?'),
        children: [
          for (final u in lugares)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, u),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(u.nombre, style: const TextStyle(fontSize: 21)),
              ),
            ),
        ],
      ),
    );
    if (elegido == null || !mounted) return;
    setState(() => _lugar = elegido);
  }

  /// Escanear de corrida: cada uno que pase queda en el lugar.
  Future<void> _ciclo() async {
    final lugar = _lugar;
    if (lugar == null) return;

    var seguir = true;
    while (seguir) {
      if (!mounted) return;
      final numero = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const PantallaEscaneo()),
      );
      if (numero == null) return;

      final animal = await widget.db.animalPorArete(numero);
      if (!mounted) return;

      if (animal == null) {
        setState(() {
          if (!_desconocidos.contains(numero)) _desconocidos.add(numero);
        });
        continue;
      }

      if (_pasados.containsKey(animal.id)) {
        // Ya pasó. Se dice, para que no se cuente dos veces sin querer.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Paleta.aviso,
            content: Text(
              'El $numero ya lo habías pasado.',
              style: const TextStyle(fontSize: 17),
            ),
          ),
        );
        continue;
      }

      await widget.db.registrarMovimiento(
        animalId: animal.id,
        ubicacionDestinoId: lugar.id,
        fecha: hoyAaaammdd(),
        motivo: 'pasar lista',
      );
      if (!mounted) return;
      setState(() => _pasados[animal.id] = numero);
      seguir = mounted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lugar = _lugar;

    return Scaffold(
      appBar: AppBar(
        title: Text(lugar == null ? 'Pasar lista' : 'Lista · ${lugar.nombre}'),
      ),
      body: SafeArea(
        child: lugar == null
            ? _ElegirLugar(onElegir: _elegirLugar)
            : Column(
                children: [
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Paleta.fondoSuave,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_pasados.length}',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        Text(
                          'pasados y puestos en ${lugar.nombre}',
                          style: const TextStyle(
                            fontSize: 17,
                            color: Paleta.textoSuave,
                          ),
                        ),
                        if (_desconocidos.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Paleta.aviso,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${_desconocidos.length} aretes que no están en '
                              'el sistema: ${_desconocidos.join(', ')}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: _pasados.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(28),
                              child: Text(
                                'Escanea de corrida. Cada animal que pases '
                                'queda registrado en este lugar.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Paleta.textoSuave,
                                ),
                              ),
                            ),
                          )
                        : ListView(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            children: [
                              for (final numero in _pasados.values.toList()
                                ..sort())
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.check_circle,
                                        color: Paleta.accion,
                                        size: 26,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        numero,
                                        style: const TextStyle(
                                          fontSize: 21,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: BotonGrande(
                      etiqueta: 'ESCANEAR',
                      icono: Icons.qr_code_scanner,
                      onPressed: _ciclo,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ElegirLugar extends StatelessWidget {
  const _ElegirLugar({required this.onElegir});

  final VoidCallback onElegir;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Elige el lugar donde estás parado.\n\n'
            'Todo lo que escanees de ahí en adelante va a quedar registrado '
            'ahí. Sirve para reacomodar después de que se rompe una cerca, o '
            'para contar un potrero de verdad.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: Paleta.textoSuave),
          ),
          const SizedBox(height: 28),
          BotonGrande(
            etiqueta: 'ELEGIR LUGAR',
            icono: Icons.place_outlined,
            onPressed: onElegir,
          ),
        ],
      ),
    );
  }
}
