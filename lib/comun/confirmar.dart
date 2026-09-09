import 'package:flutter/material.dart';

import 'tema.dart';

/// Pregunta antes de borrar.
///
/// Todos los borrados de esta app son **logicos**: el renglon se queda en la
/// base con su fecha de eliminado y desaparece de las listas. Aun asi se
/// pregunta, porque con guantes y en movimiento un dedo se resbala, y volver a
/// capturar un animal cuesta mas que un toque de confirmacion.
///
/// El mensaje siempre dice **que se lleva y que no**: la duda inmediata de
/// quien va a picar el boton es si tambien se va a llevar algo mas.
Future<bool?> confirmarBorrado(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  String etiquetaBoton = 'Borrar',
}) {
  return showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(titulo, style: const TextStyle(fontSize: 22)),
      content: Text(mensaje, style: const TextStyle(fontSize: 17)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Cancelar', style: TextStyle(fontSize: 18)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(c, true),
          child: Text(
            etiquetaBoton,
            style: const TextStyle(
              fontSize: 18,
              color: Paleta.alerta,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}
