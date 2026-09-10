import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../comun/tema.dart';
import '../../domain/reglas/costo_compra.dart';

/// Lo que se acordó por un animal.
typedef TratoDePrecio = ({FormaCotizacion forma, double precio});

/// Cuánto se pagó por este animal, y de qué forma.
///
/// **Por kilo o por cabeza**, porque no todo se compra igual. Un becerro de
/// engorda se cotiza a tanto el kilo; una vaca de pie de cría se compra por
/// cabeza y ni siquiera se pesa. Sin esta opción, el animal de pie de cría
/// aparecería para siempre en los pendientes diciendo "falta pesarlo", y nunca
/// se va a pesar porque no se compró así.
Future<TratoDePrecio?> pedirPrecioDeCompra(
  BuildContext context, {
  required String titulo,
  required FormaCotizacion formaInicial,
  double? precioInicial,
  double? pesoCompraKg,
}) {
  return showDialog<TratoDePrecio>(
    context: context,
    builder: (_) => _DialogoPrecio(
      titulo: titulo,
      formaInicial: formaInicial,
      precioInicial: precioInicial,
      pesoCompraKg: pesoCompraKg,
    ),
  );
}

class _DialogoPrecio extends StatefulWidget {
  const _DialogoPrecio({
    required this.titulo,
    required this.formaInicial,
    this.precioInicial,
    this.pesoCompraKg,
  });

  final String titulo;
  final FormaCotizacion formaInicial;
  final double? precioInicial;
  final double? pesoCompraKg;

  @override
  State<_DialogoPrecio> createState() => _DialogoPrecioState();
}

class _DialogoPrecioState extends State<_DialogoPrecio> {
  late FormaCotizacion _forma = widget.formaInicial;
  late final _campo = TextEditingController(
    text: widget.precioInicial == null
        ? ''
        : widget.precioInicial!.toStringAsFixed(2),
  );

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  double? get _precio =>
      double.tryParse(_campo.text.trim().replaceAll(',', '.'));

  /// Lo que costaría con lo capturado hasta ahora.
  double? get _total {
    final p = _precio;
    if (p == null || p <= 0) return null;
    if (_forma == FormaCotizacion.porCabeza) return p;
    final peso = widget.pesoCompraKg;
    if (peso == null || peso <= 0) return null;
    return peso * p;
  }

  @override
  Widget build(BuildContext context) {
    final porKilo = _forma == FormaCotizacion.porKilo;
    final total = _total;

    return AlertDialog(
      title: Text(widget.titulo, style: const TextStyle(fontSize: 22)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<FormaCotizacion>(
              segments: const [
                ButtonSegment(
                  value: FormaCotizacion.porKilo,
                  label: Text('Por kilo'),
                ),
                ButtonSegment(
                  value: FormaCotizacion.porCabeza,
                  label: Text('Por cabeza'),
                ),
              ],
              selected: {_forma},
              onSelectionChanged: (s) => setState(() => _forma = s.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _campo,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              style:
                  const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                prefixText: r'$ ',
                suffixText: porKilo ? 'por kg' : 'este animal',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            if (porKilo && widget.pesoCompraKg == null)
              const Text(
                'Falta pesarlo para poder sacar la cuenta. Si lo compraste por '
                'cabeza, cámbiale arriba y no hace falta el peso.',
                style: TextStyle(fontSize: 15, color: Paleta.aviso),
              )
            else if (total != null)
              Text(
                porKilo
                    ? '${widget.pesoCompraKg!.toStringAsFixed(0)} kg  ×  '
                        '\$${_precio!.toStringAsFixed(2)}  =  '
                        '\$${total.toStringAsFixed(2)}'
                    : 'Costó \$${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Paleta.accion,
                ),
              ),
            const SizedBox(height: 6),
            const Text(
              'Se arrastra a los de abajo que no hayas marcado como listos.',
              style: TextStyle(fontSize: 14, color: Paleta.textoSuave),
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
          onPressed: () {
            final p = _precio;
            if (p != null && p > 0) {
              Navigator.pop(context, (forma: _forma, precio: p));
            }
          },
          child: const Text(
            'Guardar',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
