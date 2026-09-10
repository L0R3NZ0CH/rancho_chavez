import 'package:flutter/material.dart';

import '../../comun/fechas.dart';
import '../../comun/tema.dart';
import '../../data/db/base_datos.dart';

/// Los datos de la venta que no son animales: comprador, destino y fecha.
typedef DatosVenta = ({String? comprador, String? destino, int fecha});

/// Se piden en un diálogo y no en la pantalla principal a propósito.
///
/// La pantalla de venta es para pesar. El comprador se captura una vez y ya, y
/// robarle sitio permanente a la lista por un dato que se escribe una sola vez
/// sería quitarle renglones a lo que sí se mira treinta veces.
Future<DatosVenta?> mostrarFichaVenta(
  BuildContext context, {
  required LoteVenta venta,
  required List<String> compradoresPrevios,
}) {
  return showDialog<DatosVenta>(
    context: context,
    builder: (_) => _FichaVenta(
      venta: venta,
      compradoresPrevios: compradoresPrevios,
    ),
  );
}

class _FichaVenta extends StatefulWidget {
  const _FichaVenta({required this.venta, required this.compradoresPrevios});

  final LoteVenta venta;
  final List<String> compradoresPrevios;

  @override
  State<_FichaVenta> createState() => _FichaVentaState();
}

class _FichaVentaState extends State<_FichaVenta> {
  late final _comprador =
      TextEditingController(text: widget.venta.comprador ?? '');
  late final _destino = TextEditingController(text: widget.venta.destino ?? '');
  late int _fecha = widget.venta.fecha;

  @override
  void dispose() {
    _comprador.dispose();
    _destino.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: DateTime(
        _fecha ~/ 10000,
        (_fecha ~/ 100) % 100,
        _fecha % 100,
      ),
      firstDate: DateTime(hoy.year - 5),
      lastDate: DateTime(hoy.year + 1),
      helpText: 'Fecha de la venta',
    );
    if (elegida == null || !mounted) return;
    setState(() => _fecha = hoyAaaammdd(elegida));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Datos de la venta'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _comprador,
              style: const TextStyle(fontSize: 20),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'A quién le vendes',
              ),
            ),
            if (widget.compradoresPrevios.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in widget.compradoresPrevios)
                      ActionChip(
                        label: Text(c, style: const TextStyle(fontSize: 16)),
                        onPressed: () =>
                            setState(() => _comprador.text = c),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            TextField(
              controller: _destino,
              style: const TextStyle(fontSize: 20),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'A dónde van',
                hintText: 'Opcional',
              ),
            ),
            const SizedBox(height: 14),
            Material(
              color: Paleta.fondoSuave,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _elegirFecha,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 62),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.event,
                          size: 26, color: Paleta.textoSuave),
                      const SizedBox(width: 12),
                      const Text(
                        'Vendido el',
                        style: TextStyle(
                          fontSize: 17,
                          color: Paleta.textoSuave,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        formateaAaaammdd(_fecha),
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(fontSize: 18)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, (
            comprador: _comprador.text.trim().isEmpty
                ? null
                : _comprador.text.trim(),
            destino:
                _destino.text.trim().isEmpty ? null : _destino.text.trim(),
            fecha: _fecha,
          )),
          child: const Text(
            'Guardar',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
