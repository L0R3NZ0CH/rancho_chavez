import 'package:flutter/material.dart';

import '../../comun/tema.dart';
import '../../domain/reglas/arete.dart';

/// Captura manual del numero de arete.
///
/// Teclado propio en vez del teclado del sistema: las teclas del sistema son
/// chicas para un dedo con guante y su distribucion cambia de un celular a
/// otro. Aqui cada tecla mide casi un tercio del ancho de la pantalla.
///
/// Esta pantalla no es una alternativa escondida. El codigo de barras falla
/// seguido con aretes sucios o rayados, y el dia que fallen tres seguidos, si
/// hay que navegar tres pantallas para escribir un numero, se abandona la app.
class PantallaTeclado extends StatefulWidget {
  const PantallaTeclado({super.key, this.inicial = ''});

  final String inicial;

  @override
  State<PantallaTeclado> createState() => _PantallaTecladoState();
}

class _PantallaTecladoState extends State<PantallaTeclado> {
  late String _numero = widget.inicial;

  void _teclear(String d) {
    if (_numero.length >= largoSiniiga) return;
    setState(() => _numero += d);
  }

  void _borrarUno() {
    if (_numero.isEmpty) return;
    setState(() => _numero = _numero.substring(0, _numero.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final completo = pareceSiniiga(_numero);

    return Scaffold(
      appBar: AppBar(title: const Text('Escribir el numero')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    height: 92,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Paleta.fondoSuave,
                      border: Border.all(
                        color: completo ? Paleta.accion : Paleta.borde,
                        width: completo ? 3 : 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: FittedBox(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          _numero.isEmpty ? '____________' : _numero,
                          style: TextStyle(
                            fontSize: 46,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                            color:
                                _numero.isEmpty ? Paleta.borde : Paleta.texto,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_numero.length} de $largoSiniiga digitos',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: completo ? Paleta.accion : Paleta.textoSuave,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: _Teclado(
                  onDigito: _teclear,
                  onBorrar: _borrarUno,
                  onLimpiar: () => setState(() => _numero = ''),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: BotonGrande(
                etiqueta: 'LISTO',
                icono: Icons.check,
                onPressed: _numero.isEmpty
                    ? null
                    : () => Navigator.pop(context, _numero),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Teclado extends StatelessWidget {
  const _Teclado({
    required this.onDigito,
    required this.onBorrar,
    required this.onLimpiar,
  });

  final void Function(String) onDigito;
  final VoidCallback onBorrar;
  final VoidCallback onLimpiar;

  @override
  Widget build(BuildContext context) {
    final filas = <List<Widget>>[
      [_tecla('1'), _tecla('2'), _tecla('3')],
      [_tecla('4'), _tecla('5'), _tecla('6')],
      [_tecla('7'), _tecla('8'), _tecla('9')],
      [
        _TeclaAccion(
          etiqueta: 'BORRA\nTODO',
          onPressed: onLimpiar,
          color: Paleta.textoSuave,
        ),
        _tecla('0'),
        _TeclaAccion(
          icono: Icons.backspace_outlined,
          onPressed: onBorrar,
          color: Paleta.alerta,
        ),
      ],
    ];

    return Column(
      children: [
        for (final fila in filas)
          Expanded(
            child: Row(
              children: [
                for (final tecla in fila)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: tecla,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _tecla(String d) => _TeclaDigito(digito: d, onPressed: onDigito);
}

class _TeclaDigito extends StatelessWidget {
  const _TeclaDigito({required this.digito, required this.onPressed});

  final String digito;
  final void Function(String) onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Paleta.fondoSuave,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onPressed(digito),
        child: Center(
          child: Text(
            digito,
            style: const TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w800,
              color: Paleta.texto,
            ),
          ),
        ),
      ),
    );
  }
}

class _TeclaAccion extends StatelessWidget {
  const _TeclaAccion({
    this.etiqueta,
    this.icono,
    required this.onPressed,
    required this.color,
  });

  final String? etiqueta;
  final IconData? icono;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: icono != null
                ? Icon(icono, size: 32, color: color)
                : Text(
                    etiqueta!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
