import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'comun/tema.dart';
import 'data/db/base_datos.dart';
import 'data/db/rutas.dart';
import 'features/animales/pantalla_hato.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Se trabaja con una sola mano y el celular en vertical. Que la pantalla gire
  // mientras se acerca el arete solo estorba.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Antes de abrir nada: si hay una migracion pendiente, se copia el archivo.
  // Va aqui y no dentro de drift a proposito, porque copiar una base SQLite ya
  // abierta puede dejar una copia inconsistente.
  await respaldarAntesDeMigrar(
    ruta: await rutaBaseDatos(),
    versionObjetivo: versionEsquema,
  );

  runApp(AppGanado(db: BaseDatos()));
}

class AppGanado extends StatelessWidget {
  const AppGanado({super.key, required this.db});

  final BaseDatos db;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ganado',
      debugShowCheckedModeBanner: false,
      theme: temaRancho(),
      home: PantallaHato(db: db),
    );
  }
}
