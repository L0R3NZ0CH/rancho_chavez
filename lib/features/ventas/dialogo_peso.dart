import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../comun/tema.dart';

/// Pide el peso de un animal con el teclado ya abierto y el foco puesto.
///
/// Se usa treinta veces seguidas en una venta, así que cada toque de más aquí
/// se paga treinta veces. Por eso el campo abre con el teclado numérico
/// desplegado, con el texto seleccionado para escribir encima, y con el ENTER
/// del teclado ya conectado a guardar: se puede pesar sin tocar la pantalla más
/// que para escribir.
Future<double?> pedirPeso(
  BuildContext context, {
  required String titulo,
  double? inicial,
}) {
  return showDialog<double>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DialogoNumero(
      titulo: titulo,
      explicacion: 'Peso de venta',
      sufijo: 'kg',
      inicial: inicial,
    ),
  );
}

/// Pide un número cualquiera, con la misma comodidad.
Future<double?> pedirNumero(
  BuildContext context, {
  required String titulo,
  String? explicacion,
  String? sufijo,
  String? prefijo,
  double? inicial,
}) {
  return showDialog<double>(
    context: context,
    builder: (_) => _DialogoNumero(
      titulo: titulo,
      explicacion: explicacion,
      sufijo: sufijo,
      prefijo: prefijo,
      inicial: inicial,
    ),
  );
}

class _DialogoNumero extends StatefulWidget {
  const _DialogoNumero({
    required this.titulo,
    this.explicacion,
    this.sufijo,
    this.prefijo,
    this.inicial,
  });

  final String titulo;
  final String? explicacion;
  final String? sufijo;
  final String? prefijo;
  final double? inicial;

  @override
  State<_DialogoNumero> createState() => _DialogoNumeroState();
}

class _DialogoNumeroState extends State<_DialogoNumero> {
  late final TextEditingController _campo = TextEditingController(
    text: widget.inicial == null ? '' : _sinDecimalesVacios(widget.inicial!),
  )..selection = TextSelection(
      baseOffset: 0,
      extentOffset:
          widget.inicial == null ? 0 : _sinDecimalesVacios(widget.inicial!).length,
    );

  static String _sinDecimalesVacios(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  void _guardar() {
    final v = double.tryParse(_campo.text.trim().replaceAll(',', '.'));
    if (v != null && v > 0) Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo, style: const TextStyle(fontSize: 22)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.explicacion != null) ...[
            Text(
              widget.explicacion!,
              style: const TextStyle(fontSize: 16, color: Paleta.textoSuave),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _campo,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _guardar(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              prefixText: widget.prefijo,
              suffixText: widget.sufijo,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(fontSize: 18)),
        ),
        TextButton(
          onPressed: _guardar,
          child: const Text(
            'Guardar',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
