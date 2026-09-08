import 'package:flutter/material.dart';

import '../../comun/fechas.dart';
import '../../comun/tema.dart';
import '../../data/db/base_datos.dart';

/// Registrar una compra: un viaje, un dia, un lugar.
///
/// Lo que se captura aqui es **lo que se repite**: el lugar, y el vendedor y el
/// precio mas probables del viaje. Cada animal los hereda y a cualquiera se le
/// pueden cambiar, porque en un mismo viaje se le pueden comprar dos becerros a
/// un senor y tres a otro.
///
/// No se pregunta el total pagado ni los gastos que repartir: con precio por
/// animal no hay nada que prorratear.
class PantallaNuevaCompra extends StatefulWidget {
  const PantallaNuevaCompra({super.key, required this.db});

  final BaseDatos db;

  @override
  State<PantallaNuevaCompra> createState() => _PantallaNuevaCompraState();
}

class _PantallaNuevaCompraState extends State<PantallaNuevaCompra> {
  final _vendedor = TextEditingController();
  final _lugar = TextEditingController();
  final _precioKilo = TextEditingController();

  String _forma = 'porKilo';
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
    for (final c in [_vendedor, _lugar, _precioKilo]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _listo => _vendedor.text.trim().isNotEmpty && !_guardando;

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
      );

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
                            hintText: 'El vendedor mas comun del viaje',
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
                      subtitulo: 'El costo de cada animal sale de su peso de '
                          'recepcion por este precio. A quien se le haya '
                          'comprado a otro precio, se le cambia despues.',
                      hijo: _Dinero(
                        controlador: _precioKilo,
                        sufijo: 'por kg',
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
  const _Dinero({required this.controlador, this.sufijo});

  final TextEditingController controlador;
  final String? sufijo;

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
