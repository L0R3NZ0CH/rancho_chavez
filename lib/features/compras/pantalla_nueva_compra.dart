import 'package:flutter/material.dart';

import '../../comun/fechas.dart';
import '../../comun/tema.dart';
import '../../data/db/base_datos.dart';

/// Registrar una compra.
///
/// Se captura **una vez por camion**, no una vez por animal. El vendedor, el
/// precio y los gastos son del lote; los animales se le meten despues
/// escaneando. Si esto viviera dentro del alta de cada animal habria que
/// teclear lo mismo ochenta veces.
class PantallaNuevaCompra extends StatefulWidget {
  const PantallaNuevaCompra({super.key, required this.db});

  final BaseDatos db;

  @override
  State<PantallaNuevaCompra> createState() => _PantallaNuevaCompraState();
}

class _PantallaNuevaCompraState extends State<PantallaNuevaCompra> {
  final _vendedor = TextEditingController();
  final _lugar = TextEditingController();
  final _monto = TextEditingController();
  final _precioKilo = TextEditingController();
  final _flete = TextEditingController();
  final _comision = TextEditingController();

  String _forma = 'porKilo';
  String _prorrateo = 'porCabeza';
  List<String> _vendedoresPrevios = const [];
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    widget.db.vendedoresUsados().then((v) {
      if (mounted) setState(() => _vendedoresPrevios = v);
    });
  }

  @override
  void dispose() {
    for (final c in [
      _vendedor,
      _lugar,
      _monto,
      _precioKilo,
      _flete,
      _comision,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double? get _montoTotal => double.tryParse(_monto.text.trim());

  bool get _listo =>
      _vendedor.text.trim().isNotEmpty &&
      (_montoTotal ?? 0) > 0 &&
      !_guardando;

  Future<void> _guardar() async {
    if (!_listo) return;
    setState(() => _guardando = true);

    try {
      final id = await widget.db.crearLoteCompra(
        fecha: hoyAaaammdd(),
        vendedor: _vendedor.text.trim(),
        lugar: _lugar.text.trim().isEmpty ? null : _lugar.text.trim(),
        formaCalculo: _forma,
        precioPorKilo: _forma == 'porKilo'
            ? double.tryParse(_precioKilo.text.trim())
            : null,
        montoTotal: _montoTotal!,
        formaProrrateoGastos: _prorrateo,
      );

      for (final (concepto, campo) in [
        ('flete', _flete),
        ('comision', _comision),
      ]) {
        final monto = double.tryParse(campo.text.trim());
        if (monto != null && monto > 0) {
          await widget.db.agregarGastoCompra(
            loteCompraId: id,
            concepto: concepto,
            monto: monto,
          );
        }
      }

      if (mounted) Navigator.pop(context, id);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva compra')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                children: [
                  _Campo(
                    titulo: 'A quien le compraste',
                    obligatorio: true,
                    hijo: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _vendedor,
                          style: const TextStyle(fontSize: 20),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Nombre del vendedor',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        // Autocompletado del historial: no hay catalogo que dar
                        // de alta antes de poder registrar la compra.
                        if (_vendedoresPrevios.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final v in _vendedoresPrevios)
                                  ActionChip(
                                    label: Text(
                                      v,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    onPressed: () => setState(() {
                                      _vendedor.text = v;
                                    }),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  _Campo(
                    titulo: 'Lugar',
                    hijo: TextField(
                      controller: _lugar,
                      style: const TextStyle(fontSize: 20),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Opcional',
                      ),
                    ),
                  ),
                  _Campo(
                    titulo: 'Como se cotizo',
                    obligatorio: true,
                    hijo: Row(
                      children: [
                        Expanded(
                          child: _Opcion(
                            etiqueta: 'POR KILO',
                            activo: _forma == 'porKilo',
                            onTap: () => setState(() => _forma = 'porKilo'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _Opcion(
                            etiqueta: 'POR CABEZA',
                            activo: _forma == 'porCabeza',
                            onTap: () => setState(() => _forma = 'porCabeza'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_forma == 'porKilo')
                    _Campo(
                      titulo: 'Precio por kilo',
                      subtitulo:
                          'Con esto el costo de cada animal sale de su peso de '
                          'recepcion, y es real en vez de un reparto.',
                      hijo: _Dinero(
                        controlador: _precioKilo,
                        sufijo: 'por kg',
                      ),
                    ),
                  _Campo(
                    titulo: 'Total pagado por los animales',
                    obligatorio: true,
                    subtitulo: 'Sin contar flete ni comision.',
                    hijo: _Dinero(
                      controlador: _monto,
                      onCambio: () => setState(() {}),
                    ),
                  ),
                  _Campo(
                    titulo: 'Gastos del lote',
                    subtitulo: 'Opcionales. Se reparten entre los animales.',
                    hijo: Column(
                      children: [
                        _Dinero(controlador: _flete, sufijo: 'flete'),
                        const SizedBox(height: 10),
                        _Dinero(controlador: _comision, sufijo: 'comision'),
                      ],
                    ),
                  ),
                  _Campo(
                    titulo: 'Como se reparten los gastos',
                    hijo: Row(
                      children: [
                        Expanded(
                          child: _Opcion(
                            etiqueta: 'POR CABEZA',
                            activo: _prorrateo == 'porCabeza',
                            onTap: () =>
                                setState(() => _prorrateo = 'porCabeza'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _Opcion(
                            etiqueta: 'POR KILO',
                            activo: _prorrateo == 'porKilo',
                            onTap: () =>
                                setState(() => _prorrateo = 'porKilo'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: BotonGrande(
                etiqueta: _guardando ? 'GUARDANDO...' : 'CREAR LA COMPRA',
                icono: Icons.check,
                onPressed: _listo ? _guardar : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dinero extends StatelessWidget {
  const _Dinero({required this.controlador, this.sufijo, this.onCambio});

  final TextEditingController controlador;
  final String? sufijo;
  final VoidCallback? onCambio;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controlador,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        prefixText: r'$ ',
        suffixText: sufijo,
        hintText: '0',
      ),
      onChanged: (_) => onCambio?.call(),
    );
  }
}

class _Campo extends StatelessWidget {
  const _Campo({
    required this.titulo,
    required this.hijo,
    this.subtitulo,
    this.obligatorio = false,
  });

  final String titulo;
  final String? subtitulo;
  final Widget hijo;
  final bool obligatorio;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (obligatorio)
                const Text(
                  ' *',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Paleta.alerta,
                  ),
                ),
            ],
          ),
          if (subtitulo != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitulo!,
                style: const TextStyle(fontSize: 15, color: Paleta.textoSuave),
              ),
            ),
          const SizedBox(height: 10),
          hijo,
        ],
      ),
    );
  }
}

class _Opcion extends StatelessWidget {
  const _Opcion({
    required this.etiqueta,
    required this.activo,
    required this.onTap,
  });

  final String etiqueta;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: alturaBoton,
      child: Material(
        color: activo ? Paleta.accion : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: activo ? Paleta.accion : Paleta.borde,
                width: 2.5,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                etiqueta,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: activo ? Colors.white : Paleta.texto,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
