import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/modelos/tipos.dart';
import 'fotos.dart';
import 'tema.dart';

/// Lo que se captura de un animal con el vendedor esperando su dinero.
typedef CapturaRapida = ({
  double? pesoKg,
  Categoria categoria,
  String? sena,
  String? rutaFoto,
});

/// Peso y categoría, en dos toques.
///
/// Es la pantalla que se repite treinta veces en una recogida, así que cada
/// toque de más aquí se paga treinta veces — y no lo paga el usuario: lo paga
/// el vendedor que está esperando, y ese es el que se desespera.
///
/// Por eso:
///
///   - El teclado abre solo, con el foco puesto y el número seleccionado.
///   - **Becerro y becerra van a la vista**; las otras cuatro detrás de un
///     `+ otras`. Con guante, seis botones son seis oportunidades de picar el
///     equivocado.
///   - Picar la categoría **es** el guardar. No hay botón de aceptar aparte.
///   - El sexo no se pregunta: sale de la categoría.
///   - La foto es **un botón, no un paso**. Si hay prisa se ignora y no cuesta
///     nada; si no la hay, queda registrada de una vez. Obligar a tomarla
///     convertiría una recogida de veinte en veinte interrupciones, porque una
///     foto no es un toque: es encuadrar, esperar a que el animal se quede
///     quieto y ver si salió.
Future<CapturaRapida?> capturaRapida(
  BuildContext context, {
  required String titulo,
  bool pedirSena = false,
  double? pesoInicial,
  Categoria? categoriaInicial,
}) {
  return showDialog<CapturaRapida>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DialogoCaptura(
      titulo: titulo,
      pedirSena: pedirSena,
      pesoInicial: pesoInicial,
      categoriaInicial: categoriaInicial,
    ),
  );
}

class _DialogoCaptura extends StatefulWidget {
  const _DialogoCaptura({
    required this.titulo,
    required this.pedirSena,
    this.pesoInicial,
    this.categoriaInicial,
  });

  final String titulo;
  final bool pedirSena;
  final double? pesoInicial;
  final Categoria? categoriaInicial;

  @override
  State<_DialogoCaptura> createState() => _DialogoCapturaState();
}

class _DialogoCapturaState extends State<_DialogoCaptura> {
  late final _peso = TextEditingController(
    text: widget.pesoInicial == null
        ? ''
        : widget.pesoInicial!.toStringAsFixed(0),
  )..selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.pesoInicial == null
          ? 0
          : widget.pesoInicial!.toStringAsFixed(0).length,
    );
  final _sena = TextEditingController();
  String? _rutaFoto;
  late bool _abiertas = widget.categoriaInicial != null &&
      Categoria.otras.contains(widget.categoriaInicial);

  @override
  void dispose() {
    _peso.dispose();
    _sena.dispose();
    super.dispose();
  }

  void _guardar(Categoria categoria) {
    Navigator.pop(context, (
      pesoKg: double.tryParse(_peso.text.trim().replaceAll(',', '.')),
      categoria: categoria,
      sena: _sena.text.trim().isEmpty ? null : _sena.text.trim(),
      rutaFoto: _rutaFoto,
    ));
  }

  Future<void> _foto() async {
    final ruta = await tomarFoto();
    if (ruta == null || !mounted) return;
    setState(() => _rutaFoto = ruta);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text(widget.titulo, style: const TextStyle(fontSize: 22)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _peso,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              style:
                  const TextStyle(fontSize: 40, fontWeight: FontWeight.w900),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                suffixText: 'kg',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
            if (widget.pedirSena) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _sena,
                style: const TextStyle(fontSize: 19),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Seña',
                  hintText: 'la cachetona, pinta blanca...',
                ),
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              height: 56,
              child: OutlinedButton.icon(
                onPressed: _foto,
                icon: Icon(
                  _rutaFoto == null ? Icons.photo_camera : Icons.check_circle,
                  size: 24,
                ),
                label: Text(
                  _rutaFoto == null ? 'TOMARLE FOTO' : 'FOTO TOMADA',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      _rutaFoto == null ? Paleta.textoSuave : Paleta.accion,
                  side: BorderSide(
                    color: _rutaFoto == null ? Paleta.borde : Paleta.accion,
                    width: 2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            for (final c in Categoria.principales) ...[
              _BotonCategoria(
                categoria: c,
                onTap: () => _guardar(c),
              ),
              const SizedBox(height: 10),
            ],
            if (_abiertas)
              for (final c in Categoria.otras) ...[
                _BotonCategoria(
                  categoria: c,
                  secundaria: true,
                  onTap: () => _guardar(c),
                ),
                const SizedBox(height: 10),
              ]
            else
              SizedBox(
                height: 56,
                child: OutlinedButton(
                  onPressed: () => setState(() => _abiertas = true),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Paleta.textoSuave,
                    side: const BorderSide(color: Paleta.borde, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '+ otras',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
      ],
    );
  }
}

class _BotonCategoria extends StatelessWidget {
  const _BotonCategoria({
    required this.categoria,
    required this.onTap,
    this.secundaria = false,
  });

  final Categoria categoria;
  final VoidCallback onTap;
  final bool secundaria;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: alturaBoton,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: secundaria ? Colors.white : Paleta.accion,
          foregroundColor: secundaria ? Paleta.texto : Colors.white,
          side: secundaria
              ? const BorderSide(color: Paleta.borde, width: 2)
              : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          categoria.etiqueta.toUpperCase(),
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
