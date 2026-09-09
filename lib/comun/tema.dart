import 'package:flutter/material.dart';

/// Paleta pensada para leerse bajo el sol directo, con guantes y a un brazo de
/// distancia. Nada de grises medios ni de texto delgado: a mediodia en el
/// corral lo unico que salva una pantalla de celular es el contraste.
abstract final class Paleta {
  static const fondo = Color(0xFFFFFFFF);
  static const texto = Color(0xFF0D0D0D);
  static const textoSuave = Color(0xFF4A4A4A);
  static const accion = Color(0xFF0B5C2E);
  static const accionTexto = Color(0xFFFFFFFF);
  static const alerta = Color(0xFFB3261E);
  static const aviso = Color(0xFF8A5300);
  static const borde = Color(0xFFBDBDBD);
  static const fondoSuave = Color(0xFFF2F2F2);
}

/// Altura minima de cualquier boton de esta app.
///
/// El minimo tactil que recomienda Material son 48 dp. Con guantes de trabajo
/// y una sola mano se queda corto, asi que aqui el piso es bastante mas alto.
const double alturaBoton = 76;

ThemeData temaRancho() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Paleta.accion,
      brightness: Brightness.light,
    ).copyWith(surface: Paleta.fondo),
  );

  return base.copyWith(
    scaffoldBackgroundColor: Paleta.fondo,
    appBarTheme: const AppBarTheme(
      backgroundColor: Paleta.fondo,
      foregroundColor: Paleta.texto,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Paleta.texto,
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: Paleta.texto,
      displayColor: Paleta.texto,
    ),
  );
}

/// Boton de accion principal: ancho completo, alto de sobra y etiqueta grande.
class BotonGrande extends StatelessWidget {
  const BotonGrande({
    super.key,
    required this.etiqueta,
    required this.onPressed,
    this.icono,
    this.color = Paleta.accion,
    this.colorTexto = Paleta.accionTexto,
    this.contorno = false,
  });

  final String etiqueta;
  final VoidCallback? onPressed;
  final IconData? icono;
  final Color color;
  final Color colorTexto;
  final bool contorno;

  @override
  Widget build(BuildContext context) {
    final hijo = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icono != null) ...[
          Icon(icono, size: 30),
          const SizedBox(width: 12),
        ],
        // FittedBox y no Flexible a secas: sin esto, una etiqueta que no cabe
        // se parte letra por letra en vertical y el boton queda ilegible.
        // Aqui la palabra se encoge y se queda en un solo renglon.
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              etiqueta,
              maxLines: 1,
              softWrap: false,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );

    return SizedBox(
      height: alturaBoton,
      child: contorno
          ? OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color, width: 2.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: hijo,
            )
          : FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: color,
                foregroundColor: colorTexto,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: hijo,
            ),
    );
  }
}
