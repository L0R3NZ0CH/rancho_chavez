import 'package:flutter/material.dart';

import '../../comun/confirmar.dart';
import '../../comun/fechas.dart';
import '../../comun/tema.dart';
import '../../data/db/base_datos.dart';
import '../../data/repos/hato.dart';
import '../../data/repos/pendientes.dart';
import '../../data/respaldo.dart';
import '../animales/pantalla_alta.dart';
import '../animales/pantalla_ficha.dart';
import '../animales/pantalla_nacimiento.dart';
import '../compras/pantalla_compras.dart';
import '../compras/pantalla_recogida.dart';
import '../compras/pantalla_sin_costo.dart';
import '../escaneo/pantalla_escaneo.dart';
import '../manejo/pantalla_pasar_lista.dart';
import '../respaldo/pantalla_respaldo.dart';
import '../ventas/pantalla_ventas.dart';
import 'pantalla_animales_del_lugar.dart';

/// La pantalla de inicio: los lugares del rancho.
///
/// No es la lista de todos los animales revueltos. El rancho se camina por
/// lugares —el río, la yunta, el potrero— y así se piensa el ganado: "¿cuántos
/// tengo en el río?". Al picar un lugar se ven los animales que están ahí.
///
/// Arriba aparecen dos renglones especiales, y solo cuando hacen falta:
/// **Sin lugar**, para los que se escanearon de corrida y todavía no tienen
/// potrero asignado, y **Pendientes de aretar**. Sin ellos, un animal
/// capturado a las prisas se perdería sin que nadie lo notara.
class PantallaLugares extends StatefulWidget {
  const PantallaLugares({super.key, required this.db});

  final BaseDatos db;

  @override
  State<PantallaLugares> createState() => _PantallaLugaresState();
}

class _PantallaLugaresState extends State<PantallaLugares> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _revisarRespaldo());
  }

  int _deuda = 0;

  Future<void> _revisarRespaldo({bool abrir = true}) async {
    final deuda = await deudaDeRespaldo(widget.db);
    if (!mounted) return;
    setState(() => _deuda = deuda);

    if (deuda < umbralDeuda || !abrir) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PantallaRespaldo(db: widget.db),
      ),
    );
    // Se pudo haber salido con "ahora no": la cuenta se refresca para que la
    // franja siga a la vista.
    if (mounted) await _revisarRespaldo(abrir: false);
  }

  Future<void> _abrirRespaldo() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaRespaldo(db: widget.db, bloqueante: false),
      ),
    );
    if (mounted) await _revisarRespaldo(abrir: false);
  }

  /// MANEJO: escanear para abrir la ficha y apuntar lo que se le hizo.
  ///
  /// Escanear busca al animal en todo el rancho, sin importar donde este.
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
          builder: (_) => PantallaFicha(db: widget.db, animalId: animal.id),
        ),
      );
      return;
    }

    final alta = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Arete no registrado'),
        content: Text(
          'El arete $numero no está en el sistema. '
          'Puedes dar de alta un animal nuevo con ese número.',
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

    if ((alta ?? false) && mounted) await _alta(numeroArete: numero);
  }

  Future<void> _alta({String? numeroArete}) async {
    final id = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PantallaAlta(db: widget.db, numeroArete: numeroArete),
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

  /// Una compra nueva: se abre y se empieza a pesar de inmediato.
  ///
  /// No pide nada antes. El vendedor esta esperando su dinero.
  Future<void> _compra() async {
    final id = await widget.db.crearLoteCompra(
      fecha: hoyAaaammdd(),
      vendedor: '',
      formaCalculo: 'porKilo',
    );
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaRecogida(db: widget.db, compraId: id),
      ),
    );
  }

  Future<void> _venta() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PantallaVentas(db: widget.db)),
    );
  }

  Future<void> _nacimiento() async {
    final id = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => PantallaNacimiento(db: widget.db)),
    );
    if (id == null || !mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaFicha(db: widget.db, animalId: id),
      ),
    );
  }

  Future<void> _nuevoLugar() async {
    final nombre = await showDialog<String>(
      context: context,
      builder: (_) => const _DialogoLugar(),
    );
    if (nombre == null) return;
    await widget.db.crearUbicacion(nombre: nombre, tipo: 'potrero');
  }

  Future<void> _borrarLugar(Ubicacion u) async {
    final cuantos = await widget.db.animalesEnUbicacion(u.id);
    if (!mounted) return;

    if (cuantos > 0) {
      // No se borra un lugar con ganado parado: los animales quedarian sin
      // sitio y sin que nadie se entere.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Paleta.aviso,
          content: Text(
            '${u.nombre} tiene $cuantos ${cuantos == 1 ? 'animal' : 'animales'}. '
            'Muévelos antes de borrarlo.',
            style: const TextStyle(fontSize: 17),
          ),
        ),
      );
      return;
    }

    final confirmado = await confirmarBorrado(
      context,
      titulo: 'Borrar ${u.nombre}',
      mensaje: 'El lugar sale de la lista.\n\nEl historial de movimientos se '
          'conserva.',
    );
    if (!(confirmado ?? false)) return;
    await widget.db.eliminarUbicacion(u.id);
  }

  @override
  Widget build(BuildContext context) {
    final repo = RepoHato(widget.db);
    final hoy = hoyAaaammdd();

    return StreamBuilder<List<AnimalEnLista>>(
      stream: repo.verHato(hoy: hoy),
      builder: (context, snapHato) {
        final hato = snapHato.data ?? const <AnimalEnLista>[];

        return StreamBuilder<List<Ubicacion>>(
          stream: widget.db.verUbicaciones(),
          builder: (context, snapUbis) {
            final lugares = snapUbis.data ?? const <Ubicacion>[];

            return StreamBuilder<List<SinCosto>>(
              stream: RepoPendientes(widget.db).verSinCosto(),
              builder: (context, snapSinCosto) {

            final sinCosto = snapSinCosto.data?.length ?? 0;
            final porLugar = <String, int>{};
            var sinLugar = 0;
            var pendientes = 0;
            for (final a in hato) {
              final u = a.ubicacionId;
              if (u == null) {
                sinLugar++;
              } else {
                porLugar[u] = (porLugar[u] ?? 0) + 1;
              }
              if (a.pendienteDeAretar) pendientes++;
            }

            return Scaffold(
              appBar: AppBar(
                title: Text(
                  hato.isEmpty
                      ? 'El rancho'
                      : '${hato.length} ${hato.length == 1 ? 'animal' : 'animales'}',
                ),
                actions: [
                  // Comprar, vender y manejar bajaron a los tres botones
                  // grandes. Aqui arriba solo queda lo que no se usa a diario.
                  PopupMenuButton<String>(
                    tooltip: 'Más',
                    iconSize: 30,
                    onSelected: (opcion) => switch (opcion) {
                      'compras' => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PantallaCompras(db: widget.db),
                          ),
                        ),
                      'ventas' => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PantallaVentas(db: widget.db),
                          ),
                        ),
                      'lista' => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PantallaPasarLista(db: widget.db),
                          ),
                        ),
                      'nacimiento' => _nacimiento(),
                      _ => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PantallaRespaldo(
                              db: widget.db,
                              bloqueante: false,
                            ),
                          ),
                        ),
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'nacimiento',
                        child: ListTile(
                          leading: Icon(Icons.child_care_outlined),
                          title: Text(
                            'Nació en el rancho',
                            style: TextStyle(fontSize: 19),
                          ),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'lista',
                        child: ListTile(
                          leading: Icon(Icons.fact_check_outlined),
                          title: Text(
                            'Pasar lista',
                            style: TextStyle(fontSize: 19),
                          ),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'compras',
                        child: ListTile(
                          leading: Icon(Icons.local_shipping_outlined),
                          title: Text(
                            'Compras',
                            style: TextStyle(fontSize: 19),
                          ),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'ventas',
                        child: ListTile(
                          leading: Icon(Icons.receipt_long_outlined),
                          title: Text(
                            'Ventas',
                            style: TextStyle(fontSize: 19),
                          ),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'respaldo',
                        child: ListTile(
                          leading: Icon(Icons.backup_outlined),
                          title: Text(
                            'Respaldo',
                            style: TextStyle(fontSize: 19),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              body: SafeArea(
                child: Column(
                  children: [
                    // La deuda de respaldo se queda a la vista. Se puede salir
                    // de la pantalla que la pide, pero no desaparece hasta que
                    // el archivo salga del celular.
                    if (_deuda >= umbralDeuda)
                      _FranjaRespaldo(
                        deuda: _deuda,
                        onTap: _abrirRespaldo,
                      ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                        children: [
                          if (sinLugar > 0)
                            _Renglon(
                              nombre: 'Sin lugar',
                              cuantos: sinLugar,
                              destacado: true,
                              icono: Icons.help_outline,
                              onTap: () => _abrir(null, 'Sin lugar'),
                            ),
                          if (pendientes > 0)
                            _Renglon(
                              nombre: 'Pendientes de aretar',
                              cuantos: pendientes,
                              destacado: true,
                              icono: Icons.label_off_outlined,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PantallaAnimalesDelLugar(
                                    db: widget.db,
                                    titulo: 'Pendientes de aretar',
                                    soloPendientes: true,
                                  ),
                                ),
                              ),
                            ),
                          // Un hueco que nadie ve nunca se tapa. Estos
                          // animales salen en blanco en el resumen de la
                          // venta, y desde aqui se arreglan en un toque.
                          if (sinCosto > 0)
                            _Renglon(
                              nombre: 'Falta el costo',
                              cuantos: sinCosto,
                              destacado: true,
                              icono: Icons.attach_money,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      PantallaSinCosto(db: widget.db),
                                ),
                              ),
                            ),
                          if (sinLugar > 0 || pendientes > 0 || sinCosto > 0)
                            const SizedBox(height: 14),
                          if (lugares.isEmpty && hato.isEmpty)
                            const _Vacio()
                          else
                            for (final u in lugares)
                              _Renglon(
                                nombre: u.nombre,
                                cuantos: porLugar[u.id] ?? 0,
                                icono: Icons.grass,
                                onTap: () => _abrir(u.id, u.nombre),
                                onBorrar: () => _borrarLugar(u),
                              ),
                          const SizedBox(height: 10),
                          BotonGrande(
                            etiqueta: '+ NUEVO LUGAR',
                            contorno: true,
                            onPressed: _nuevoLugar,
                          ),
                        ],
                      ),
                    ),
                    // Los tres van fijos abajo y siempre visibles: son las
                    // tres cosas que se hacen en el rancho. Cualquiera de los
                    // tres abre camara, asi que se distinguen por lo que vas a
                    // hacer con lo que escanees, no por el escaneo.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: BotonGrande(
                              etiqueta: 'COMPRA',
                              icono: Icons.local_shipping_outlined,
                              onPressed: _compra,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: BotonGrande(
                              etiqueta: 'VENTA',
                              icono: Icons.sell_outlined,
                              onPressed: _venta,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: BotonGrande(
                              etiqueta: 'MANEJO',
                              icono: Icons.healing_outlined,
                              contorno: true,
                              onPressed: _escanear,
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
          },
        );
      },
    );
  }

  void _abrir(String? ubicacionId, String titulo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaAnimalesDelLugar(
          db: widget.db,
          ubicacionId: ubicacionId,
          titulo: titulo,
        ),
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 40, 16, 24),
      child: Text(
        'Todavía no hay lugares ni animales.\n\n'
        'Puedes empezar por donde quieras: crea un lugar aquí abajo, o escanea '
        'un arete y ponle el lugar después.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18, color: Paleta.textoSuave),
      ),
    );
  }
}

class _Renglon extends StatelessWidget {
  const _Renglon({
    required this.nombre,
    required this.cuantos,
    required this.icono,
    required this.onTap,
    this.onBorrar,
    this.destacado = false,
  });

  final String nombre;
  final int cuantos;
  final IconData icono;
  final VoidCallback onTap;
  final VoidCallback? onBorrar;

  /// Los renglones que piden atencion: sin lugar, pendientes de aretar.
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final color = destacado ? Paleta.aviso : Paleta.texto;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: destacado ? const Color(0xFFFFF4E0) : Paleta.fondoSuave,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            // Alto de sobra para picarle con guante.
            constraints: const BoxConstraints(minHeight: 88),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(
                color: destacado ? Paleta.aviso : Paleta.borde,
                width: destacado ? 2 : 1.5,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(icono, size: 30, color: color),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    nombre,
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
                Text(
                  '$cuantos',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                if (onBorrar != null)
                  IconButton(
                    tooltip: 'Borrar el lugar',
                    iconSize: 26,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onBorrar,
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.chevron_right, size: 28),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogoLugar extends StatefulWidget {
  const _DialogoLugar();

  @override
  State<_DialogoLugar> createState() => _DialogoLugarState();
}

class _DialogoLugarState extends State<_DialogoLugar> {
  final _nombre = TextEditingController();

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo lugar'),
      content: TextField(
        controller: _nombre,
        autofocus: true,
        style: const TextStyle(fontSize: 20),
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          // El nombre es el que usa el dueno, nunca "Potrero 1".
          hintText: 'El río, la yunta, a la vuelta...',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(fontSize: 18)),
        ),
        TextButton(
          onPressed: () {
            final n = _nombre.text.trim();
            if (n.isNotEmpty) Navigator.pop(context, n);
          },
          child: const Text('Crear', style: TextStyle(fontSize: 18)),
        ),
      ],
    );
  }
}

/// La franja roja que recuerda que hay trabajo sin respaldar.
///
/// Aparece cuando se sale de la pantalla de respaldo con "ahora no". No
/// estorba el paso —se puede seguir trabajando— pero no se quita hasta que el
/// archivo salga del celular.
class _FranjaRespaldo extends StatelessWidget {
  const _FranjaRespaldo({required this.deuda, required this.onTap});

  final int deuda;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Paleta.alerta,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.backup_outlined, color: Colors.white, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$deuda registros sin respaldar',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Text(
                'RESPALDAR',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
