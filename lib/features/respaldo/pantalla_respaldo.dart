import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../comun/fotos.dart';
import '../../comun/tema.dart';
import '../../data/db/base_datos.dart';
import '../../data/respaldo.dart';
import '../../data/restauracion.dart';

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
  int _bytesFotos = 0;
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
    final bytes = await bytesDeLasFotos();
    if (!mounted) return;
    setState(() {
      _animales = animales;
      _ultimo = ultimo;
      _bytesFotos = bytes;
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
          title: const Text('¿Ya salió del celular?'),
          content: const Text(
            'El archivo se guardó en el celular, pero no puedo saber si de '
            'verdad se envió. Si todavía no lo mandas, el aviso se queda.',
            style: TextStyle(fontSize: 17),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Todavía no', style: TextStyle(fontSize: 18)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Sí, ya salió', style: TextStyle(fontSize: 18)),
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

  /// Restaurar: elegir el archivo, **revisarlo**, y solo entonces reemplazar.
  ///
  /// El paso de revisar no es un adorno. Restaurar a ciegas y descubrir despues
  /// que el archivo venia truncado es perder el hato dos veces: una por el
  /// accidente y otra por la restauracion.
  Future<void> _restaurar() async {
    final elegido = await FilePicker.pickFile(
      dialogTitle: 'Elige el archivo de respaldo',
    );
    final camino = elegido?.path;
    if (camino == null || !mounted) return;

    setState(() {
      _trabajando = true;
      _error = null;
    });

    ResumenRespaldo? resumen;
    try {
      resumen = await revisarRespaldo(File(camino));
      if (!mounted) return;

      final confirmado = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          title: const Text('Revisa antes de restaurar'),
          content: Text(
            'Ese respaldo trae:\n\n'
            '   ${resumen!.animales} animales\n'
            '   ${resumen.eventos} eventos\n'
            '   ${resumen.fotos} fotos\n\n'
            'Al restaurar, TODO lo que tienes ahora en el celular se '
            'reemplaza por eso.\n\n'
            'Se guarda una copia de lo actual por si te arrepientes.',
            style: const TextStyle(fontSize: 17),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar', style: TextStyle(fontSize: 18)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text(
                'Restaurar',
                style: TextStyle(
                  fontSize: 18,
                  color: Paleta.alerta,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );

      if (!(confirmado ?? false)) {
        descartarRespaldo(resumen);
        return;
      }

      // La base tiene que estar cerrada antes de pisarla.
      await widget.db.close();
      await aplicarRespaldo(resumen);
      resumen = null;

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          title: const Text('Listo'),
          content: const Text(
            'Los datos quedaron restaurados.\n\n'
            'La app se va a cerrar. Ábrela otra vez para verlos.',
            style: TextStyle(fontSize: 17),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Cerrar la app',
                  style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      );
      // La base viva quedo cerrada y reemplazada; seguir aqui daria errores en
      // cada pantalla. Se cierra la app para que vuelva a abrir limpia.
      await SystemNavigator.pop();
    } on RespaldoInvalido catch (e) {
      if (mounted) setState(() => _error = e.motivo);
    } on Exception catch (e) {
      if (resumen != null) descartarRespaldo(resumen);
      if (mounted) setState(() => _error = '$e');
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
                      : 'Último respaldo: $_ultimo',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 17),
                ),
                // El peso de las fotos a la vista: cada foto engorda el ZIP, y
                // un respaldo que ya no se puede mandar es un respaldo que no
                // existe. Que la decision de guardar muchas se tome viendo el
                // costo, no el dia que el archivo ya no quepa.
                if (_bytesFotos > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Las fotos pesan ${pesoEnPalabras(_bytesFotos)}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: _bytesFotos > 100 * 1024 * 1024
                            ? Paleta.aviso
                            : Paleta.textoSuave,
                        fontWeight: _bytesFotos > 100 * 1024 * 1024
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                const Text(
                  'Todo el ganado vive en este teléfono. Si se moja, se rompe o '
                  'se pierde en el corral, se pierde con él. Manda el archivo a '
                  'WhatsApp, a tu correo o a donde lo puedas encontrar después.',
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
                // Salida. Antes no la habia y era una trampa: si el celular no
                // tiene con que compartir en ese momento, o simplemente hay
                // prisa, quedarse encerrado en esta pantalla no protege nada.
                //
                // La deuda no se limpia: sigue contando y el inicio la deja a
                // la vista con una franja roja hasta que se respalde.
                if (widget.bloqueante) ...[
                  const SizedBox(height: 10),
                  BotonGrande(
                    etiqueta: 'AHORA NO',
                    contorno: true,
                    color: Paleta.textoSuave,
                    onPressed: _trabajando
                        ? null
                        : () => Navigator.pop(context, false),
                  ),
                ],
                // Restaurar solo aparece cuando no hay trabajo sin respaldar.
                // Ofrecerlo en la pantalla que bloquea por deuda seria invitar
                // a pisar justo lo que todavia no se ha guardado.
                if (!widget.bloqueante) ...[
                  const SizedBox(height: 10),
                  BotonGrande(
                    etiqueta: 'RESTAURAR DE UN RESPALDO',
                    icono: Icons.restore,
                    contorno: true,
                    color: Paleta.textoSuave,
                    onPressed: _trabajando ? null : _restaurar,
                  ),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
