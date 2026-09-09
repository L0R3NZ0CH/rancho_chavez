import 'package:flutter/material.dart';

import '../../comun/fechas.dart';
import '../../comun/tema.dart';
import '../../data/db/base_datos.dart';
import '../../data/repos/hato.dart';
import '../../domain/reglas/estado_animal.dart';
import '../animales/pantalla_ficha.dart';

/// Los animales que están en un lugar.
///
/// Cuando [ubicacionId] es null, muestra los que **no tienen lugar asignado**:
/// los que se escanearon de corrida en el corral y todavía falta acomodar.
class PantallaAnimalesDelLugar extends StatefulWidget {
  const PantallaAnimalesDelLugar({
    super.key,
    required this.db,
    required this.titulo,
    this.ubicacionId,
    this.soloPendientes = false,
  });

  final BaseDatos db;
  final String titulo;
  final String? ubicacionId;

  /// Ignora el lugar y muestra los que no traen arete.
  final bool soloPendientes;

  @override
  State<PantallaAnimalesDelLugar> createState() =>
      _PantallaAnimalesDelLugarState();
}

class _PantallaAnimalesDelLugarState extends State<PantallaAnimalesDelLugar> {
  String _filtro = '';

  /// Mueve de un jalon a todos los animales de la lista.
  ///
  /// Es la operacion que ahorra horas: acomodar a mano veinte animales que se
  /// escanearon sin lugar seria veinte viajes a la ficha.
  Future<void> _moverTodos(List<AnimalEnLista> lista) async {
    final lugares = await widget.db.verUbicaciones().first;
    if (!mounted) return;

    if (lugares.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Paleta.aviso,
          content: Text(
            'Todavía no hay lugares. Crea uno en la pantalla de inicio.',
            style: TextStyle(fontSize: 17),
          ),
        ),
      );
      return;
    }

    final destino = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text('Mover ${lista.length} a...'),
        children: [
          for (final u in lugares)
            if (u.id != widget.ubicacionId)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(c, u.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(u.nombre, style: const TextStyle(fontSize: 21)),
                ),
              ),
        ],
      ),
    );
    if (destino == null) return;

    final hoy = hoyAaaammdd();
    for (final a in lista) {
      await widget.db.registrarMovimiento(
        animalId: a.animal.id,
        ubicacionDestinoId: destino,
        ubicacionOrigenId: a.ubicacionId,
        fecha: hoy,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final repo = RepoHato(widget.db);
    final hoy = hoyAaaammdd();

    return StreamBuilder<List<AnimalEnLista>>(
      stream: repo.verHato(hoy: hoy),
      builder: (context, snap) {
        final todos = snap.data ?? const <AnimalEnLista>[];

        final delLugar = todos.where((a) {
          if (widget.soloPendientes) return a.pendienteDeAretar;
          return a.ubicacionId == widget.ubicacionId;
        }).toList();

        final lista = _filtro.isEmpty
            ? delLugar
            : delLugar
                .where((a) =>
                    (a.numeroArete ?? '').contains(_filtro) ||
                    (a.animal.apodo ?? '').toLowerCase().contains(_filtro))
                .toList();

        return Scaffold(
          appBar: AppBar(
            title: Text('${widget.titulo}  ·  ${delLugar.length}'),
          ),
          body: SafeArea(
            child: Column(
              children: [
                if (delLugar.length > 4)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: TextField(
                      style: const TextStyle(fontSize: 19),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search, size: 26),
                        border: OutlineInputBorder(),
                        hintText: 'Buscar por número o apodo',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      onChanged: (v) =>
                          setState(() => _filtro = v.trim().toLowerCase()),
                    ),
                  ),
                Expanded(
                  child: lista.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Text(
                              delLugar.isEmpty
                                  ? 'No hay animales aquí.'
                                  : 'Ninguno coincide con la búsqueda.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 18,
                                color: Paleta.textoSuave,
                              ),
                            ),
                          ),
                        )
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
                if (delLugar.isNotEmpty && !widget.soloPendientes)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: BotonGrande(
                      etiqueta: widget.ubicacionId == null
                          ? 'ASIGNARLES UN LUGAR'
                          : 'MOVERLOS A OTRO LUGAR',
                      icono: Icons.swap_horiz,
                      contorno: widget.ubicacionId != null,
                      onPressed: () => _moverTodos(delLugar),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
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
                '${datos.ultimoPesoFecha == null ? '' : '  ·  '
                    '${diasEnPalabras(diasEntre(datos.ultimoPesoFecha!, hoy))}'}',
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
              datos.categoria.etiqueta +
                  (datos.categoriaCorregida ? ' (a mano)' : ''),
              style: const TextStyle(fontSize: 16, color: Paleta.textoSuave),
            ),
          ],
        ),
      ),
      trailing: const Icon(Icons.chevron_right, size: 30),
    );
  }
}
