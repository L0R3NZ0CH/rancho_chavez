import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../comun/tema.dart';
import '../../data/db/base_datos.dart';
import '../../data/respaldo.dart';

/// La pantalla que no deja seguir hasta respaldar.
///
/// Un solo celular es un solo punto de falla, y se puede mojar, romper o perder
/// en el corral. Como no hay servidor, "respaldo automatico" no puede
/// significar que algo lo suba solo; lo que si se puede es poner **friccion
/// dura**: cuando se acumulan registros sin respaldar, esta pantalla aparece y
/// no tiene boton de regresar.
///
/// Dos limites que no se pueden esquivar y que conviene tener presentes:
///
/// 1. **Android no deja atrapar al usuario.** El boton de inicio y el
///    cambiador de aplicaciones siempre ganan. Lo que si se garantiza es que la
///    deuda vive en la base de datos: al volver a abrir la app, esta pantalla
///    es lo primero que aparece, con la misma cuenta.
/// 2. **No se puede verificar que el archivo se haya enviado.** Android no le
///    avisa a la app si WhatsApp mando el respaldo. Se verifica que el ZIP se
///    escribio, que eso si es seguro, y se le pregunta al usuario. Si dice que
///    todavia no, la deuda no se limpia.
class PantallaRespaldo extends StatefulWidget {
  const PantallaRespaldo({
    super.key,
    required this.db,
    this.bloqueante = true,
  });

  final BaseDatos db;

  /// Cuando es false se puede salir: es el respaldo que se pide a mano.
  final bool bloqueante;

  @override
  State<PantallaRespaldo> createState() => _PantallaRespaldoState();
}

class _PantallaRespaldoState extends State<PantallaRespaldo> {
  int _animales = 0;
  String? _ultimo;
  bool _trabajando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final animales = await animalesSinRespaldar(widget.db);
    final ultimo = await fechaUltimoRespaldo(widget.db);
    if (!mounted) return;
    setState(() {
      _animales = animales;
      _ultimo = ultimo;
    });
  }

  Future<void> _respaldar() async {
    setState(() {
      _trabajando = true;
      _error = null;
    });

    try {
      final archivo = await crearRespaldo(widget.db);
      if (!mounted) return;

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(archivo.path)],
          text: 'Respaldo del hato',
        ),
      );
      if (!mounted) return;

      final salio = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          title: const Text('¿Ya salio del celular?'),
          content: const Text(
            'El archivo se guardo en el celular, pero no puedo saber si de '
            'verdad se envio. Si todavia no lo mandas, el aviso se queda.',
            style: TextStyle(fontSize: 17),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Todavia no', style: TextStyle(fontSize: 18)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Si, ya salio', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      );

      if (salio ?? false) {
        await marcarRespaldado(widget.db);
        if (mounted) Navigator.pop(context, true);
        return;
      }
      await _cargar();
    } on Exception catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Dentro de la app no hay salida: ni boton de regresar ni gesto.
      canPop: !widget.bloqueante,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Respaldo'),
          automaticallyImplyLeading: !widget.bloqueante,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                if (widget.bloqueante)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Paleta.alerta,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'HAY TRABAJO SIN RESPALDAR',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                const SizedBox(height: 28),
                Text(
                  '$_animales',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 88,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const Text(
                  'animales nuevos sin respaldar',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 19, color: Paleta.textoSuave),
                ),
                const SizedBox(height: 20),
                Text(
                  _ultimo == null
                      ? 'Nunca se ha respaldado este celular.'
                      : 'Ultimo respaldo: $_ultimo',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 17),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Todo el ganado vive en este telefono. Si se moja, se rompe o '
                  'se pierde en el corral, se pierde con el. Manda el archivo a '
                  'WhatsApp, a tu correo o a donde lo puedas encontrar despues.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17, color: Paleta.textoSuave),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Paleta.alerta,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'No se pudo hacer el respaldo:\n$_error',
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ),
                ],
                const Spacer(),
                BotonGrande(
                  etiqueta:
                      _trabajando ? 'PREPARANDO...' : 'RESPALDAR AHORA',
                  icono: Icons.backup,
                  onPressed: _trabajando ? null : _respaldar,
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
