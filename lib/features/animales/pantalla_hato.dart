import 'package:flutter/material.dart';

import '../../comun/fechas.dart';
import '../../comun/tema.dart';
import '../../data/db/base_datos.dart';
import '../../data/repos/hato.dart';
import '../../domain/reglas/estado_animal.dart';
import '../../data/respaldo.dart';
import '../escaneo/pantalla_escaneo.dart';
import '../respaldo/pantalla_respaldo.dart';
import 'pantalla_alta.dart';
import 'pantalla_ficha.dart';

/// La pantalla de inicio: el hato completo.
///
/// El boton de escanear va fijo abajo y siempre visible. Es el ochenta por
/// ciento del uso real: llegar a la manga, escanear, ver al animal.
class PantallaHato extends StatefulWidget {
  const PantallaHato({super.key, required this.db});

  final BaseDatos db;

  @override
  State<PantallaHato> createState() => _PantallaHatoState();
}

class _PantallaHatoState extends State<PantallaHato> {
  String _filtro = '';
  _Apartado _apartado = _Apartado.todos;

  @override
  void initState() {
    super.initState();
    // Al abrir la app, si quedo trabajo sin respaldar de una sesion anterior,
    // la pantalla bloqueante es lo primero que se ve. La deuda vive en la base
    // de datos, asi que salirse por el boton de inicio no la borra.
    WidgetsBinding.instance.addPostFrameCallback((_) => _revisarRespaldo());
  }

  /// Muestra la pantalla bloqueante si la deuda paso del umbral.
  Future<void> _revisarRespaldo() async {
    final deuda = await deudaDeRespaldo(widget.db);
    if (deuda < umbralDeuda || !mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PantallaRespaldo(db: widget.db),
      ),
    );
  }

  /// Escanear busca al animal. Si el arete no esta registrado, ofrece darlo de
  /// alta con ese numero ya puesto.
  Future<void> _escanear() async {
    final numero = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const PantallaEscaneo()),
    );
    if (numero == null || !mounted) return;

    final animal = await widget.db.animalPorArete(numero);
    if (!mounted) return;

    if (animal != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PantallaFicha(db: widget.db, animalId: animal.id),
        ),
      );
      return;
    }

    final darDeAlta = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Arete no registrado'),
        content: Text(
          'El arete $numero no esta en el sistema. '
          'Puedes dar de alta un animal nuevo con ese numero.',
          style: const TextStyle(fontSize: 17),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar', style: TextStyle(fontSize: 18)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Dar de alta', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );

    if ((darDeAlta ?? false) && mounted) await _alta(numeroArete: numero);
  }

  Future<void> _alta({String? numeroArete}) async {
    final id = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaAlta(
          db: widget.db,
          numeroArete: numeroArete,
        ),
      ),
    );
    if (id == null || !mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaFicha(db: widget.db, animalId: id),
      ),
    );

    if (mounted) await _revisarRespaldo();
  }

  @override
  Widget build(BuildContext context) {
    final repo = RepoHato(widget.db);
    final hoy = hoyAaaammdd();

    return StreamBuilder<List<AnimalEnLista>>(
      stream: repo.verHato(hoy: hoy),
      builder: (context, snap) {
        final todo = snap.data ?? const <AnimalEnLista>[];
        final lista = _filtrar(todo, hoy);

        return Scaffold(
          appBar: AppBar(
            title: Text(
              todo.isEmpty ? 'El hato' : '${todo.length} animales',
            ),
            actions: [
              IconButton(
                tooltip: 'Respaldar',
                iconSize: 30,
                icon: const Icon(Icons.backup_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PantallaRespaldo(
                      db: widget.db,
                      bloqueante: false,
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                _FranjaApartados(
                  actual: _apartado,
                  conteos: {
                    for (final a in _Apartado.values)
                      a: _filtrarPor(todo, a, hoy).length,
                  },
                  onCambio: (a) => setState(() => _apartado = a),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: TextField(
                    style: const TextStyle(fontSize: 19),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search, size: 26),
                      border: OutlineInputBorder(),
                      hintText: 'Buscar por numero o apodo',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 16),
                    ),
                    onChanged: (v) =>
                        setState(() => _filtro = v.trim().toLowerCase()),
                  ),
                ),
                Expanded(
                  child: lista.isEmpty
                      ? _Vacio(hayAnimales: todo.isNotEmpty)
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: lista.length,
                          separatorBuilder: (_, _) =>
                              const Divider(height: 1, color: Paleta.borde),
                          itemBuilder: (context, i) => _Renglon(
                            datos: lista[i],
                            hoy: hoy,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PantallaFicha(
                                  db: widget.db,
                                  animalId: lista[i].animal.id,
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: BotonGrande(
                          etiqueta: 'ESCANEAR',
                          icono: Icons.qr_code_scanner,
                          onPressed: _escanear,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: BotonGrande(
                          etiqueta: 'NUEVO',
                          icono: Icons.add,
                          contorno: true,
                          onPressed: () => _alta(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<AnimalEnLista> _filtrar(List<AnimalEnLista> todo, int hoy) {
    var lista = _filtrarPor(todo, _apartado, hoy);
    if (_filtro.isEmpty) return lista;
    return lista
        .where((a) =>
            (a.numeroArete ?? '').contains(_filtro) ||
            (a.animal.apodo ?? '').toLowerCase().contains(_filtro))
        .toList();
  }

  List<AnimalEnLista> _filtrarPor(
    List<AnimalEnLista> todo,
    _Apartado apartado,
    int hoy,
  ) =>
      switch (apartado) {
        _Apartado.todos => todo,
        _Apartado.pendientes =>
          todo.where((a) => a.pendienteDeAretar).toList(),
        // Los que cambiaron solos en el ultimo mes. Sale de comparar la
        // categoria de hoy contra la de hace un mes: nada guardado.
        _Apartado.cambiaron => todo.where((a) => a.cambioReciente).toList(),
      };
}

enum _Apartado {
  todos('Todos'),
  pendientes('Pendientes de aretar'),
  cambiaron('Cambiaron de categoria');

  const _Apartado(this.etiqueta);
  final String etiqueta;
}

class _FranjaApartados extends StatelessWidget {
  const _FranjaApartados({
    required this.actual,
    required this.conteos,
    required this.onCambio,
  });

  final _Apartado actual;
  final Map<_Apartado, int> conteos;
  final ValueChanged<_Apartado> onCambio;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          for (final a in _Apartado.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _ChipApartado(
                etiqueta: '${a.etiqueta}  ${conteos[a] ?? 0}',
                activo: actual == a,
                onTap: () => onCambio(a),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChipApartado extends StatelessWidget {
  const _ChipApartado({
    required this.etiqueta,
    required this.activo,
    required this.onTap,
  });

  final String etiqueta;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: activo ? Paleta.accion : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(
              color: activo ? Paleta.accion : Paleta.borde,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              etiqueta,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: activo ? Colors.white : Paleta.texto,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.hayAnimales});

  final bool hayAnimales;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          hayAnimales
              ? 'Ningun animal cae en este apartado.'
              : 'Todavia no hay animales.\n\n'
                  'Escanea un arete para dar de alta al primero, o usa NUEVO '
                  'si el animal llego sin identificar.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, color: Paleta.textoSuave),
        ),
      ),
    );
  }
}

class _Renglon extends StatelessWidget {
  const _Renglon({
    required this.datos,
    required this.hoy,
    required this.onTap,
  });

  final AnimalEnLista datos;
  final int hoy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final peso = datos.ultimoPesoKg;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      title: Row(
        children: [
          Flexible(
            child: Text(
              datos.titulo,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: datos.pendienteDeAretar ? 0 : 1.5,
                color: datos.pendienteDeAretar ? Paleta.aviso : Paleta.texto,
              ),
            ),
          ),
          if (datos.pendienteDeAretar)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child:
                  Icon(Icons.label_off_outlined, size: 22, color: Paleta.aviso),
            ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // El peso va primero y en grande: es lo que de verdad se mira.
            if (peso != null)
              Text(
                '${peso.toStringAsFixed(0)} kg'
                '${datos.ultimoPesoFecha == null ? '' : '  ·  hace '
                    '${diasEntre(datos.ultimoPesoFecha!, hoy)} dias'}',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: Paleta.texto,
                ),
              )
            else
              const Text(
                'Sin pesar',
                style: TextStyle(fontSize: 17, color: Paleta.textoSuave),
              ),
            const SizedBox(height: 2),
            Text(
              [
                datos.categoria.etiqueta +
                    (datos.categoriaCorregida ? ' (a mano)' : ''),
                if (datos.ubicacionNombre != null) datos.ubicacionNombre!,
              ].join('  ·  '),
              style: const TextStyle(fontSize: 16, color: Paleta.textoSuave),
            ),
          ],
        ),
      ),
      trailing: const Icon(Icons.chevron_right, size: 30),
    );
  }
}
