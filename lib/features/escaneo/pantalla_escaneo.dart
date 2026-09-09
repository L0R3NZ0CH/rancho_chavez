import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../comun/tema.dart';
import '../../domain/reglas/arete.dart';
import 'pantalla_teclado.dart';

/// Lee el numero de un arete, por camara o a mano.
///
/// Devuelve los **doce digitos impresos** en la bandera, o null si se cancelo.
/// Quien la llama no tiene que saber si vinieron del codigo de barras o del
/// teclado: los dos caminos entregan el mismo numero, que es justamente el
/// punto de la regla del prefijo 484.
class PantallaEscaneo extends StatefulWidget {
  const PantallaEscaneo({super.key});

  @override
  State<PantallaEscaneo> createState() => _PantallaEscaneoState();
}

class _PantallaEscaneoState extends State<PantallaEscaneo> {
  /// La resolucion se fija a proposito.
  ///
  /// En Android, mobile_scanner usa 640x480 cuando no se le dice nada. A esa
  /// resolucion un codigo de barras chico, sucio o rayado es ilegible.
  late final MobileScannerController _control = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    cameraResolution: const Size(1920, 1080),
    autoZoom: true,
  );

  AreteLeido? _leido;

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  void _alDetectar(BarcodeCapture captura) {
    if (_leido != null) return;
    final codigo = captura.barcodes
        .where((b) => (b.rawValue ?? '').isNotEmpty)
        .firstOrNull;
    if (codigo == null) return;

    setState(() => _leido = normalizaArete(codigo.rawValue!));
  }

  Future<void> _aMano() async {
    final numero = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const PantallaTeclado()),
    );
    if (numero != null && mounted) Navigator.pop(context, numero);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: _control,
              onDetect: _alDetectar,
              tapToFocus: true,
              errorBuilder: (context, error) => _SinCamara(
                error: error,
                onManual: _aMano,
              ),
            ),
            if (_leido == null) const _MiraDeEncuadre(),
            _BarraSuperior(control: _control),
            if (_leido == null) _BarraInferior(onManual: _aMano),
            if (_leido != null)
              _Confirmacion(
                leido: _leido!,
                onCorregir: () async {
                  final corregido = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PantallaTeclado(
                        inicial: _leido!.numero,
                      ),
                    ),
                  );
                  if (corregido != null && context.mounted) {
                    Navigator.pop(context, corregido);
                  }
                },
                onOtro: () {
                  setState(() => _leido = null);
                  _control.start().ignore();
                },
                onUsar: () => Navigator.pop(context, _leido!.numero),
              ),
          ],
        ),
      ),
    );
  }
}

class _SinCamara extends StatelessWidget {
  const _SinCamara({required this.error, required this.onManual});

  final MobileScannerException error;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography, color: Colors.white, size: 64),
              const SizedBox(height: 16),
              const Text(
                'No se pudo abrir la cámara',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                error.errorDetails?.message ?? error.errorCode.name,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Que falle la camara no puede dejar al usuario sin salida.
              BotonGrande(
                etiqueta: 'ESCRIBIR EL NÚMERO A MANO',
                icono: Icons.dialpad,
                onPressed: onManual,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiraDeEncuadre extends StatelessWidget {
  const _MiraDeEncuadre();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 300,
          height: 170,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 3),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

class _BarraSuperior extends StatelessWidget {
  const _BarraSuperior({required this.control});

  final MobileScannerController control;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            _BotonRedondo(
              icono: Icons.close,
              etiqueta: 'Cerrar',
              onPressed: () => Navigator.pop(context),
            ),
            const Spacer(),
            ValueListenableBuilder(
              valueListenable: control,
              builder: (context, estado, _) {
                if (estado.torchState == TorchState.unavailable) {
                  return const SizedBox.shrink();
                }
                final prendida = estado.torchState == TorchState.on;
                return _BotonRedondo(
                  icono: prendida ? Icons.flashlight_on : Icons.flashlight_off,
                  etiqueta: 'Lámpara',
                  resaltado: prendida,
                  onPressed: () => control.toggleTorch(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BotonRedondo extends StatelessWidget {
  const _BotonRedondo({
    required this.icono,
    required this.etiqueta,
    required this.onPressed,
    this.resaltado = false,
  });

  final IconData icono;
  final String etiqueta;
  final VoidCallback onPressed;
  final bool resaltado;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: etiqueta,
      button: true,
      child: SizedBox(
        width: 64,
        height: 64,
        child: Material(
          color: resaltado ? Paleta.aviso : Colors.black54,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Icon(icono, color: Colors.white, size: 32),
          ),
        ),
      ),
    );
  }
}

class _BarraInferior extends StatelessWidget {
  const _BarraInferior({required this.onManual});

  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: BotonGrande(
          etiqueta: 'ESCRIBIR A MANO',
          icono: Icons.dialpad,
          onPressed: onManual,
        ),
      ),
    );
  }
}

class _Confirmacion extends StatelessWidget {
  const _Confirmacion({
    required this.leido,
    required this.onUsar,
    required this.onOtro,
    required this.onCorregir,
  });

  final AreteLeido leido;
  final VoidCallback onUsar;
  final VoidCallback onOtro;
  final VoidCallback onCorregir;

  @override
  Widget build(BuildContext context) {
    final valido = pareceSiniiga(leido.numero);

    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.93),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 12),
                const Text(
                  'ARETE LEÍDO',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                FittedBox(
                  child: Text(
                    leido.numero.isEmpty ? leido.crudo : leido.numero,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 56,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Se dice lo que la app hizo con el numero. Si se ven doce
                // digitos donde el codigo traia quince, tiene que quedar claro
                // por que, y no parecer que la app perdio informacion.
                if (leido.prefijoQuitado)
                  const _Nota(
                    color: Colors.white24,
                    texto:
                        'Se le quitó el prefijo 484 de México, que viene dentro '
                        'del código de barras pero no está impreso en el arete. '
                        'Lo de arriba es lo que dice la bandera.',
                  ),
                if (!valido)
                  _Nota(
                    color: Paleta.aviso,
                    texto: 'Ojo: son ${leido.numero.length} dígitos, no '
                        '$largoSiniiga. Revisa contra la bandera antes de '
                        'usarlo.',
                  ),
                const SizedBox(height: 24),
                BotonGrande(
                  etiqueta: 'USAR ESTE NÚMERO',
                  icono: Icons.check,
                  onPressed: onUsar,
                ),
                const SizedBox(height: 10),
                BotonGrande(
                  etiqueta: 'LEER OTRO',
                  icono: Icons.refresh,
                  contorno: true,
                  color: Colors.white,
                  onPressed: onOtro,
                ),
                const SizedBox(height: 10),
                BotonGrande(
                  etiqueta: 'CORREGIR A MANO',
                  icono: Icons.dialpad,
                  contorno: true,
                  color: Colors.white,
                  onPressed: onCorregir,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Nota extends StatelessWidget {
  const _Nota({required this.texto, required this.color});

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        texto,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        textAlign: TextAlign.center,
      ),
    );
  }
}
