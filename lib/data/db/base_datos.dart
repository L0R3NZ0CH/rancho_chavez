import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../comun/fechas.dart';
import 'rutas.dart';
import 'tablas.dart';

part 'base_datos.g.dart';

const _uuid = Uuid();

/// Version 1: la bitacora de la prueba de campo de la fase 1.
/// Version 2: el esquema del hato. Aqui empieza el compromiso de no perder
///            datos nunca mas.
/// Version 3: lotes de compra, sus gastos y sus animales. Solo agrega tablas.
/// Version 4: ventas y bajas. Solo agrega tablas.
/// Version 5: repara la tabla de compras en los celulares que alcanzaron a
///            instalar la primera forma de la version 3.
const versionEsquema = 5;

@DriftDatabase(
  tables: [
    Animales,
    Aretes,
    Ubicaciones,
    Eventos,
    EventoMovimientos,
    EventoPesos,
    EventoPropositos,
    EventoCorreccionCategorias,
    Fotos,
    Configuracion,
    LotesCompra,
    LoteCompraAnimales,
    LotesVenta,
    LoteVentaAnimales,
    EventoBajas,
  ],
)
class BaseDatos extends _$BaseDatos {
  BaseDatos([QueryExecutor? ejecutor])
      : super(
          ejecutor ??
              driftDatabase(
                name: 'ganado',
                native: DriftNativeOptions(databasePath: rutaBaseDatos),
              ),
        );

  @override
  int get schemaVersion => versionEsquema;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, desde, hasta) async {
          // Nunca deleteAllTables(). Ese atajo borra los datos del rancho y es
          // facil dejarlo puesto sin darse cuenta.
          // Los pasos se aplican en orden y sin return temprano, para que una
          // base que se quedo en la version 1 pueda llegar hasta la ultima
          // pasando por todas las etapas.
          if (desde <= 1) {
            // La tabla de la prueba de campo era desechable por acuerdo: solo
            // guardaba lecturas de aretes para medir si la camara alcanzaba.
            // Es el unico borrado de datos que este proyecto va a hacer.
            await m.deleteTable('lecturas_prueba');
          }

          if (desde <= 2) {
            // Compras: solo agrega tablas, no toca ni una fila existente.
            //
            // El DROP es por si algun dispositivo alcanzo a instalar la primera
            // forma de la version 3, que modelaba la compra como un camion de
            // un solo dueno con gastos que repartir. Esa tabla desaparecio y
            // nunca guardo datos del rancho.
            await customStatement('DROP TABLE IF EXISTS lote_compra_gastos');
            await m.createTable(lotesCompra);
            await m.createTable(loteCompraAnimales);
          }

          if (desde <= 3) {
            // Ventas y bajas: solo agrega tablas, no toca una sola fila.
            await m.createTable(lotesVenta);
            await m.createTable(loteVentaAnimales);
            await m.createTable(eventoBajas);
          }

          if (desde <= 4) {
            await _repararComprasViejas(m);
          }

          if (hasta > versionEsquema) {
            throw UnsupportedError(
              'No hay migracion definida hasta la version $hasta. Toda '
              'migracion debe escribirse aqui, con su prueba, antes de subir '
              'schemaVersion.',
            );
          }

          // Crea lo que falte de las versiones intermedias.
          await m.createAll();
        },
        beforeOpen: (detalles) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Repara la tabla de compras que quedo con la forma vieja.
  ///
  /// La primera version 3 modelaba la compra como un camion de un solo dueno:
  /// `lotes_compra` traia `monto_total` y `forma_prorrateo_gastos`
  /// obligatorios, y habia una tabla de gastos que repartir. El dueno rechazo
  /// ese modelo y la version 3 se redefinio dando por hecho que nunca se habia
  /// instalado.
  ///
  /// Se habia instalado. Entro a un celular mientras `adb` decia "waiting for
  /// device", y como ese celular ya estaba en la version 3, ninguna migracion
  /// volvio a tocar la tabla. Crear una compra reventaba con
  /// SQLITE_CONSTRAINT_NOTNULL: la app ya no manda `monto_total`, pero la
  /// columna seguia siendo obligatoria.
  ///
  /// La leccion, escrita aqui para no repetirla: **una version de esquema que
  /// se compilo se da por publicada.** Redefinirla en vez de crear la
  /// siguiente solo es seguro si se puede probar que ningun dispositivo la
  /// recibio, y un `adb install` que parece fallar no es prueba de nada.
  Future<void> _repararComprasViejas(Migrator m) async {
    // La tabla de gastos ya no existe en el modelo.
    await customStatement('DROP TABLE IF EXISTS lote_compra_gastos');

    if (await _tieneColumna('lotes_compra', 'monto_total')) {
      // alterTable recrea la tabla con la forma nueva y copia las columnas que
      // siguen existiendo. Las que se fueron simplemente no se copian.
      await m.alterTable(TableMigration(lotesCompra));
    }

    if (await _tieneColumna('lote_compra_animales', 'costo_individual')) {
      await m.alterTable(
        TableMigration(
          loteCompraAnimales,
          newColumns: [
            loteCompraAnimales.vendedor,
            loteCompraAnimales.formaCalculo,
            loteCompraAnimales.precioPorKilo,
            loteCompraAnimales.precioPorCabeza,
          ],
          columnTransformer: {
            // El viejo "costo individual" era el precio negociado de ese
            // animal en concreto. Hoy ese concepto se llama precio por cabeza.
            loteCompraAnimales.precioPorCabeza:
                const CustomExpression<double>('costo_individual'),
          },
        ),
      );
    }
  }

  /// Si una tabla existe y trae esa columna.
  Future<bool> _tieneColumna(String tabla, String columna) async {
    final filas = await customSelect('PRAGMA table_info($tabla)').get();
    return filas.any((f) => f.read<String>('name') == columna);
  }

  /// Identificador de este celular (regla 2).
  ///
  /// Se genera una sola vez y se guarda. No se usa ningun identificador del
  /// sistema Android a proposito: esos cambian al reinstalar la app o al
  /// restablecer el telefono, y el historial quedaria atribuido a un
  /// dispositivo que ya no existe.
  Future<String> dispositivoId() async {
    final guardado = await leerAjuste('dispositivoId');
    if (guardado != null) return guardado;

    final nuevo = _uuid.v4();
    await escribirAjuste('dispositivoId', nuevo);
    return nuevo;
  }

  Future<String?> leerAjuste(String clave) async {
    final fila = await (select(configuracion)
          ..where((c) => c.clave.equals(clave)))
        .getSingleOrNull();
    return fila?.valor;
  }

  Future<void> escribirAjuste(String clave, String valor) async {
    await into(configuracion).insertOnConflictUpdate(
      ConfiguracionCompanion.insert(clave: clave, valor: valor),
    );
  }

  /// Los cinco campos de auditoria, ya listos, para insertar cualquier fila.
  Future<({String id, int ahora, String dispositivo})> _sello() async => (
        id: _uuid.v4(),
        ahora: ahoraUtcMs(),
        dispositivo: await dispositivoId(),
      );

  // -------------------------------------------------------------------------
  // Altas
  // -------------------------------------------------------------------------

  /// Da de alta un animal completo en una sola transaccion.
  ///
  /// Un alta nunca es una sola fila: es el animal, su arete si lo trae, el
  /// movimiento que lo pone en un potrero y su proposito. Si algo falla a la
  /// mitad no puede quedar un animal incompleto en la base, y por eso va todo
  /// dentro de una transaccion.
  ///
  /// El numero de arete es opcional porque **el animal existe antes que el
  /// arete**: los lotes comprados llegan sin identificar.
  ///
  /// La ubicacion tambien es opcional. En el corral se escanea de corrida y el
  /// lugar se asigna despues, con calma: obligar a elegir potrero en ese
  /// momento es lo que hace que el alta pase de quince segundos. Un animal sin
  /// ubicacion aparece en "Sin lugar" en el inicio, para que no se pierda.
  Future<String> altaAnimal({
    required String sexo,
    required String origen,
    required String proposito,
    required int fecha,
    String? ubicacionId,
    String? numeroArete,
    String tipoArete = 'siniiga',
    String? apodo,
    int? fechaNacimiento,
    String nacimientoPrecision = 'desconocida',
    String? nacimientoNota,
    String? raza,
    String? descripcionFisica,
    String? notas,
  }) async {
    return transaction(() async {
      final s = await _sello();

      await into(animales).insert(
        AnimalesCompanion.insert(
          id: s.id,
          creadoEn: s.ahora,
          modificadoEn: s.ahora,
          dispositivoId: s.dispositivo,
          sexo: sexo,
          origen: origen,
          apodo: Value(apodo),
          fechaNacimiento: Value(fechaNacimiento),
          nacimientoPrecision: Value(nacimientoPrecision),
          nacimientoNota: Value(nacimientoNota),
          raza: Value(raza),
          descripcionFisica: Value(descripcionFisica),
          notas: Value(notas),
        ),
      );

      if (numeroArete != null && numeroArete.isNotEmpty) {
        await ponerArete(
          animalId: s.id,
          numero: numeroArete,
          tipo: tipoArete,
          fecha: fecha,
        );
      }

      if (ubicacionId != null) {
        await registrarMovimiento(
          animalId: s.id,
          ubicacionDestinoId: ubicacionId,
          fecha: fecha,
        );
      }

      await registrarProposito(
        animalId: s.id,
        proposito: proposito,
        fecha: fecha,
      );

      return s.id;
    });
  }

  Future<String> ponerArete({
    required String animalId,
    required String numero,
    required int fecha,
    String tipo = 'siniiga',
  }) async {
    final s = await _sello();
    await into(aretes).insert(
      AretesCompanion.insert(
        id: s.id,
        creadoEn: s.ahora,
        modificadoEn: s.ahora,
        dispositivoId: s.dispositivo,
        animalId: animalId,
        numero: numero,
        tipo: Value(tipo),
        fechaColocacion: fecha,
      ),
    );
    return s.id;
  }

  /// Retira un arete sin borrarlo, para que una lectura del arete viejo siga
  /// encontrando al animal.
  Future<void> retirarArete({
    required String areteId,
    required int fecha,
    String? motivo,
  }) async {
    await (update(aretes)..where((a) => a.id.equals(areteId))).write(
      AretesCompanion(
        fechaRetiro: Value(fecha),
        motivoRetiro: Value(motivo),
        modificadoEn: Value(ahoraUtcMs()),
      ),
    );
  }

  /// Inserta el evento base y devuelve su id, para colgarle el detalle.
  Future<String> _evento({
    required String animalId,
    required String tipo,
    required int fecha,
    String? notas,
    String? loteTrabajoId,
  }) async {
    final s = await _sello();
    await into(eventos).insert(
      EventosCompanion.insert(
        id: s.id,
        creadoEn: s.ahora,
        modificadoEn: s.ahora,
        dispositivoId: s.dispositivo,
        animalId: animalId,
        tipo: tipo,
        fechaEvento: fecha,
        notas: Value(notas),
        loteTrabajoId: Value(loteTrabajoId),
      ),
    );
    return s.id;
  }

  Future<String> registrarMovimiento({
    required String animalId,
    required String ubicacionDestinoId,
    required int fecha,
    String? ubicacionOrigenId,
    String? motivo,
    String? loteTrabajoId,
  }) async {
    final eventoId = await _evento(
      animalId: animalId,
      tipo: 'movimiento',
      fecha: fecha,
      loteTrabajoId: loteTrabajoId,
    );
    await into(eventoMovimientos).insert(
      EventoMovimientosCompanion.insert(
        eventoId: eventoId,
        ubicacionDestinoId: ubicacionDestinoId,
        ubicacionOrigenId: Value(ubicacionOrigenId),
        motivo: Value(motivo),
      ),
    );
    return eventoId;
  }

  Future<String> registrarPeso({
    required String animalId,
    required double kilos,
    required int fecha,
    String tipoPesaje = 'rutina',
    String metodo = 'bascula',
    String? loteTrabajoId,
  }) async {
    final eventoId = await _evento(
      animalId: animalId,
      tipo: 'peso',
      fecha: fecha,
      loteTrabajoId: loteTrabajoId,
    );
    await into(eventoPesos).insert(
      EventoPesosCompanion.insert(
        eventoId: eventoId,
        kilos: kilos,
        tipoPesaje: Value(tipoPesaje),
        metodo: Value(metodo),
      ),
    );
    return eventoId;
  }

  Future<String> registrarProposito({
    required String animalId,
    required String proposito,
    required int fecha,
  }) async {
    final eventoId = await _evento(
      animalId: animalId,
      tipo: 'proposito',
      fecha: fecha,
    );
    await into(eventoPropositos).insert(
      EventoPropositosCompanion.insert(
        eventoId: eventoId,
        proposito: proposito,
      ),
    );
    return eventoId;
  }

  /// Destete y parto no tienen detalle: su unico dato es la fecha.
  Future<String> registrarDestete({
    required String animalId,
    required int fecha,
  }) =>
      _evento(animalId: animalId, tipo: 'destete', fecha: fecha);

  Future<String> registrarParto({
    required String animalId,
    required int fecha,
    String? notas,
  }) =>
      _evento(animalId: animalId, tipo: 'parto', fecha: fecha, notas: notas);

  Future<String> corregirCategoria({
    required String animalId,
    required String categoria,
    required int fecha,
    String? motivo,
  }) async {
    final eventoId = await _evento(
      animalId: animalId,
      tipo: 'correccionCategoria',
      fecha: fecha,
    );
    await into(eventoCorreccionCategorias).insert(
      EventoCorreccionCategoriasCompanion.insert(
        eventoId: eventoId,
        categoria: categoria,
        motivo: Value(motivo),
      ),
    );
    return eventoId;
  }

  // -------------------------------------------------------------------------
  // Consultas
  // -------------------------------------------------------------------------

  /// Busca al animal que trae puesto ese numero de arete.
  ///
  /// Solo mira aretes vigentes y no eliminados. Un numero que estuvo en un
  /// animal dado de baja y se reutilizo no debe devolver al animal viejo.
  Future<Animal?> animalPorArete(String numero) async {
    final consulta = select(aretes).join([
      innerJoin(animales, animales.id.equalsExp(aretes.animalId)),
    ])
      ..where(
        aretes.numero.equals(numero) &
            aretes.fechaRetiro.isNull() &
            aretes.eliminadoEn.isNull() &
            animales.eliminadoEn.isNull(),
      );

    final fila = await consulta.getSingleOrNull();
    return fila?.readTable(animales);
  }

  Future<Animal?> animal(String id) =>
      (select(animales)..where((a) => a.id.equals(id))).getSingleOrNull();

  /// Todos los eventos vivos de un animal, del mas reciente al mas viejo.
  ///
  /// El orden lleva tres criterios y los tres importan: la fecha del hecho es
  /// la verdad del rancho, [Eventos.creadoEn] desempata dos eventos capturados
  /// el mismo dia, y el id desempata lo que quede, para que dos celulares
  /// lleguen al mismo resultado el dia que haya sincronizacion.
  Stream<List<Evento>> verEventos(String animalId) {
    return (select(eventos)
          ..where((e) => e.animalId.equals(animalId) & e.eliminadoEn.isNull())
          ..orderBy([
            (e) =>
                OrderingTerm(expression: e.fechaEvento, mode: OrderingMode.desc),
            (e) => OrderingTerm(expression: e.creadoEn, mode: OrderingMode.desc),
            (e) => OrderingTerm(expression: e.id, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Stream<List<Animal>> verAnimales() {
    return (select(animales)
          ..where((a) => a.eliminadoEn.isNull())
          ..orderBy([
            (a) => OrderingTerm(expression: a.creadoEn, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// El arete vigente de un animal, si trae. Nulo mientras este pendiente de
  /// aretar.
  Future<Arete?> areteVigente(String animalId) {
    return (select(aretes)
          ..where(
            (a) =>
                a.animalId.equals(animalId) &
                a.fechaRetiro.isNull() &
                a.eliminadoEn.isNull(),
          ))
        .getSingleOrNull();
  }

  Stream<List<Ubicacion>> verUbicaciones() {
    return (select(ubicaciones)
          ..where((u) => u.eliminadoEn.isNull())
          ..orderBy([(u) => OrderingTerm(expression: u.nombre)]))
        .watch();
  }

  Future<String> crearUbicacion({
    required String nombre,
    required String tipo,
    double? hectareas,
    String? tipoPasto,
    int? capacidadMaxima,
    String? notas,
  }) async {
    final s = await _sello();
    await into(ubicaciones).insert(
      UbicacionesCompanion.insert(
        id: s.id,
        creadoEn: s.ahora,
        modificadoEn: s.ahora,
        dispositivoId: s.dispositivo,
        nombre: nombre,
        tipo: tipo,
        hectareas: Value(hectareas),
        tipoPasto: Value(tipoPasto),
        capacidadMaxima: Value(capacidadMaxima),
        notas: Value(notas),
      ),
    );
    return s.id;
  }

  // -------------------------------------------------------------------------
  // Compras
  // -------------------------------------------------------------------------

  Future<String> crearLoteCompra({
    required int fecha,
    required String vendedor,
    required String formaCalculo,
    double? precioPorKilo,
    String? lugar,
    String? notas,
  }) async {
    final s = await _sello();
    await into(lotesCompra).insert(
      LotesCompraCompanion.insert(
        id: s.id,
        creadoEn: s.ahora,
        modificadoEn: s.ahora,
        dispositivoId: s.dispositivo,
        fecha: fecha,
        vendedor: vendedor,
        formaCalculo: formaCalculo,
        precioPorKilo: Value(precioPorKilo),
        lugar: Value(lugar),
        notas: Value(notas),
      ),
    );
    return s.id;
  }

  Future<String> agregarAnimalALote({
    required String loteCompraId,
    required String animalId,
    String? vendedor,
    String? formaCalculo,
    double? precioPorKilo,
    double? precioPorCabeza,
  }) async {
    final s = await _sello();
    await into(loteCompraAnimales).insert(
      LoteCompraAnimalesCompanion.insert(
        id: s.id,
        creadoEn: s.ahora,
        modificadoEn: s.ahora,
        dispositivoId: s.dispositivo,
        loteCompraId: loteCompraId,
        animalId: animalId,
        vendedor: Value(vendedor),
        formaCalculo: Value(formaCalculo),
        precioPorKilo: Value(precioPorKilo),
        precioPorCabeza: Value(precioPorCabeza),
      ),
    );
    return s.id;
  }

  /// Encuentra la compra de ese dia con ese vendedor, o la crea.
  ///
  /// Un viaje es un dia y un vendedor. Cuando se dan de alta cinco becerros
  /// comprados el mismo dia al mismo senor, los cinco caen solos en la misma
  /// compra sin que nadie tenga que crearla ni elegirla. Si uno vino de otro
  /// dueno, se le abre la suya, tambien sola.
  Future<String> compraDelDia({
    required int fecha,
    required String vendedor,
    required String formaCalculo,
    double? precioPorKilo,
    String? lugar,
  }) async {
    final existente = await (select(lotesCompra)
          ..where((l) =>
              l.fecha.equals(fecha) &
              l.vendedor.equals(vendedor) &
              l.eliminadoEn.isNull()))
        .getSingleOrNull();
    if (existente != null) return existente.id;

    return crearLoteCompra(
      fecha: fecha,
      vendedor: vendedor,
      formaCalculo: formaCalculo,
      precioPorKilo: precioPorKilo,
      lugar: lugar,
    );
  }

  Stream<List<LoteCompra>> verLotesCompra() {
    return (select(lotesCompra)
          ..where((l) => l.eliminadoEn.isNull())
          ..orderBy([
            (l) => OrderingTerm(expression: l.fecha, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Future<LoteCompra?> loteCompra(String id) =>
      (select(lotesCompra)..where((l) => l.id.equals(id))).getSingleOrNull();

  Future<List<AnimalComprado>> animalesDelLote(String loteCompraId) =>
      (select(loteCompraAnimales)
            ..where((a) =>
                a.loteCompraId.equals(loteCompraId) & a.eliminadoEn.isNull()))
          .get();

  /// El peso de recepcion de un animal: su pesaje con tipo 'compra'.
  ///
  /// Es lo que vuelve real el costo por cabeza en las compras por kilo, en vez
  /// de un reparto del total del camion.
  Future<double?> pesoDeCompra(String animalId) async {
    final consulta = select(eventos).join([
      innerJoin(eventoPesos, eventoPesos.eventoId.equalsExp(eventos.id)),
    ])
      ..where(
        eventos.animalId.equals(animalId) &
            eventos.eliminadoEn.isNull() &
            eventoPesos.tipoPesaje.equals('compra'),
      )
      ..orderBy([
        OrderingTerm(expression: eventos.fechaEvento, mode: OrderingMode.desc),
        OrderingTerm(expression: eventos.creadoEn, mode: OrderingMode.desc),
      ])
      ..limit(1);

    final fila = await consulta.getSingleOrNull();
    return fila?.readTable(eventoPesos).kilos;
  }

  /// Cambia el trato de un animal dentro de una compra.
  ///
  /// Cada campo que se pase gana sobre lo heredado de la compra. Es lo que
  /// permite que en un mismo viaje dos becerros sean de un senor y tres de
  /// otro, cada uno a su precio.
  Future<void> ajustarTratoDelAnimal({
    required String loteCompraId,
    required String animalId,
    Value<String?> vendedor = const Value.absent(),
    Value<String?> formaCalculo = const Value.absent(),
    Value<double?> precioPorKilo = const Value.absent(),
    Value<double?> precioPorCabeza = const Value.absent(),
  }) async {
    await (update(loteCompraAnimales)
          ..where((t) =>
              t.loteCompraId.equals(loteCompraId) &
              t.animalId.equals(animalId)))
        .write(
      LoteCompraAnimalesCompanion(
        vendedor: vendedor,
        formaCalculo: formaCalculo,
        precioPorKilo: precioPorKilo,
        precioPorCabeza: precioPorCabeza,
        modificadoEn: Value(ahoraUtcMs()),
      ),
    );
  }

  /// En que compra vino un animal, si es que se compro.
  Future<AnimalComprado?> compraDelAnimal(String animalId) =>
      (select(loteCompraAnimales)
            ..where((a) => a.animalId.equals(animalId) & a.eliminadoEn.isNull())
            ..orderBy([(a) => OrderingTerm(expression: a.creadoEn)])
            ..limit(1))
          .getSingleOrNull();

  /// Vendedores ya usados, para autocompletar sin catalogo previo.
  Future<List<String>> vendedoresUsados() async {
    final filas = await (selectOnly(lotesCompra, distinct: true)
          ..addColumns([lotesCompra.vendedor])
          ..where(lotesCompra.eliminadoEn.isNull()))
        .get();
    final propios = await (selectOnly(loteCompraAnimales, distinct: true)
          ..addColumns([loteCompraAnimales.vendedor])
          ..where(loteCompraAnimales.eliminadoEn.isNull()))
        .get();

    return {
      ...filas.map((f) => f.read(lotesCompra.vendedor)).whereType<String>(),
      ...propios
          .map((f) => f.read(loteCompraAnimales.vendedor))
          .whereType<String>(),
    }.toList()
      ..sort();
  }

  /// Quita un animal de una compra, sin borrar al animal.
  ///
  /// Es el caso de haberlo metido por error al viaje equivocado: el animal
  /// sigue existiendo, solo deja de pertenecer a esa compra.
  Future<void> quitarAnimalDeCompra({
    required String loteCompraId,
    required String animalId,
  }) async {
    final ahora = ahoraUtcMs();
    await (update(loteCompraAnimales)
          ..where((t) =>
              t.loteCompraId.equals(loteCompraId) &
              t.animalId.equals(animalId)))
        .write(
      LoteCompraAnimalesCompanion(
        eliminadoEn: Value(ahora),
        modificadoEn: Value(ahora),
      ),
    );
  }

  /// Borrado logico de una compra (regla 3).
  ///
  /// Los animales que trajo **no** se borran: siguen en el hato. Lo que se
  /// pierde es el registro del viaje y de lo que costaron.
  Future<void> eliminarCompra(String id) async {
    final ahora = ahoraUtcMs();
    await transaction(() async {
      await (update(lotesCompra)..where((l) => l.id.equals(id))).write(
        LotesCompraCompanion(
          eliminadoEn: Value(ahora),
          modificadoEn: Value(ahora),
        ),
      );
      await (update(loteCompraAnimales)
            ..where((a) => a.loteCompraId.equals(id)))
          .write(
        LoteCompraAnimalesCompanion(
          eliminadoEn: Value(ahora),
          modificadoEn: Value(ahora),
        ),
      );
    });
  }

  /// Cuantos animales vivos hay en una ubicacion ahora mismo.
  ///
  /// Sirve para no dejar borrar un potrero que todavia tiene ganado parado.
  Future<int> animalesEnUbicacion(String ubicacionId) async {
    final movimientos = await (select(eventos).join([
      innerJoin(
        eventoMovimientos,
        eventoMovimientos.eventoId.equalsExp(eventos.id),
      ),
    ])
          ..where(eventos.eliminadoEn.isNull() &
              eventos.tipo.equals('movimiento')))
        .get();

    // Ultimo movimiento por animal: gana la fecha del hecho, luego la captura.
    final ultimo = <String, ({int fecha, int creado, String destino})>{};
    for (final fila in movimientos) {
      final e = fila.readTable(eventos);
      final m = fila.readTable(eventoMovimientos);
      final actual = ultimo[e.animalId];
      if (actual == null ||
          e.fechaEvento > actual.fecha ||
          (e.fechaEvento == actual.fecha && e.creadoEn > actual.creado)) {
        ultimo[e.animalId] = (
          fecha: e.fechaEvento,
          creado: e.creadoEn,
          destino: m.ubicacionDestinoId,
        );
      }
    }

    final vivos = await (select(animales)
          ..where((a) => a.eliminadoEn.isNull()))
        .get();
    // Un animal vendido o muerto ya no esta parado en ningun potrero.
    final deBaja = await animalesDadosDeBaja();
    final idsVivos =
        vivos.map((a) => a.id).where((id) => !deBaja.contains(id)).toSet();

    return ultimo.entries
        .where((e) => idsVivos.contains(e.key))
        .where((e) => e.value.destino == ubicacionId)
        .length;
  }

  /// Borrado logico de una ubicacion (regla 3).
  Future<void> eliminarUbicacion(String id) async {
    final ahora = ahoraUtcMs();
    await (update(ubicaciones)..where((u) => u.id.equals(id))).write(
      UbicacionesCompanion(
        eliminadoEn: Value(ahora),
        modificadoEn: Value(ahora),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Ventas
  // -------------------------------------------------------------------------

  /// Abre una venta en blanco. Nada obligatorio: se empieza a pesar de una vez.
  Future<String> crearVenta({required int fecha}) async {
    final s = await _sello();
    await into(lotesVenta).insert(
      LotesVentaCompanion.insert(
        id: s.id,
        creadoEn: s.ahora,
        modificadoEn: s.ahora,
        dispositivoId: s.dispositivo,
        fecha: fecha,
      ),
    );
    return s.id;
  }

  Future<void> actualizarVenta({
    required String ventaId,
    required String? comprador,
    required String? destino,
    required int fecha,
  }) async {
    await (update(lotesVenta)..where((l) => l.id.equals(ventaId))).write(
      LotesVentaCompanion(
        comprador: Value(comprador),
        destino: Value(destino),
        fecha: Value(fecha),
        modificadoEn: Value(ahoraUtcMs()),
      ),
    );
  }

  Future<String> agregarAnimalAVenta({
    required String ventaId,
    required String animalId,
    double? precioPorKilo,
  }) async {
    final s = await _sello();
    await into(loteVentaAnimales).insert(
      LoteVentaAnimalesCompanion.insert(
        id: s.id,
        creadoEn: s.ahora,
        modificadoEn: s.ahora,
        dispositivoId: s.dispositivo,
        loteVentaId: ventaId,
        animalId: animalId,
        precioPorKilo: Value(precioPorKilo),
      ),
    );
    return s.id;
  }

  Future<void> quitarAnimalDeVenta({
    required String ventaId,
    required String animalId,
  }) async {
    final ahora = ahoraUtcMs();
    await (update(loteVentaAnimales)
          ..where((t) =>
              t.loteVentaId.equals(ventaId) & t.animalId.equals(animalId)))
        .write(
      LoteVentaAnimalesCompanion(
        eliminadoEn: Value(ahora),
        modificadoEn: Value(ahora),
      ),
    );
  }

  /// Le pone precio a un animal de la venta.
  Future<void> fijarPrecioDeVenta({
    required String ventaId,
    required String animalId,
    required double? precioPorKilo,
  }) async {
    await (update(loteVentaAnimales)
          ..where((t) =>
              t.loteVentaId.equals(ventaId) & t.animalId.equals(animalId)))
        .write(
      LoteVentaAnimalesCompanion(
        precioPorKilo: Value(precioPorKilo),
        modificadoEn: Value(ahoraUtcMs()),
      ),
    );
  }

  /// Le pone el mismo precio a todos los de la venta.
  ///
  /// Es el boton que resuelve el caso normal: se acordo un precio para el
  /// camion completo. Los que se hayan negociado aparte se corrigen uno por uno
  /// despues.
  Future<void> precioParaTodos({
    required String ventaId,
    required double precioPorKilo,
    bool soloLosQueFaltan = false,
  }) async {
    final consulta = update(loteVentaAnimales)
      ..where((t) => t.loteVentaId.equals(ventaId) & t.eliminadoEn.isNull());
    if (soloLosQueFaltan) {
      consulta.where((t) => t.precioPorKilo.isNull());
    }
    await consulta.write(
      LoteVentaAnimalesCompanion(
        precioPorKilo: Value(precioPorKilo),
        modificadoEn: Value(ahoraUtcMs()),
      ),
    );
  }

  Future<List<AnimalVendido>> animalesDeVenta(String ventaId) =>
      (select(loteVentaAnimales)
            ..where((a) =>
                a.loteVentaId.equals(ventaId) & a.eliminadoEn.isNull())
            ..orderBy([(a) => OrderingTerm(expression: a.creadoEn)]))
          .get();

  Future<LoteVenta?> venta(String id) =>
      (select(lotesVenta)..where((l) => l.id.equals(id))).getSingleOrNull();

  Stream<List<LoteVenta>> verVentas() {
    return (select(lotesVenta)
          ..where((l) => l.eliminadoEn.isNull())
          ..orderBy([
            (l) => OrderingTerm(expression: l.fecha, mode: OrderingMode.desc),
            (l) => OrderingTerm(expression: l.creadoEn, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Future<List<String>> compradoresUsados() async {
    final filas = await (selectOnly(lotesVenta, distinct: true)
          ..addColumns([lotesVenta.comprador])
          ..where(lotesVenta.eliminadoEn.isNull()))
        .get();
    return filas
        .map((f) => f.read(lotesVenta.comprador))
        .whereType<String>()
        .toList()
      ..sort();
  }

  /// El peso con el que se va a vender: su pesaje mas reciente de tipo 'venta'.
  Future<double?> pesoDeVenta(String animalId) async {
    final consulta = select(eventos).join([
      innerJoin(eventoPesos, eventoPesos.eventoId.equalsExp(eventos.id)),
    ])
      ..where(
        eventos.animalId.equals(animalId) &
            eventos.eliminadoEn.isNull() &
            eventoPesos.tipoPesaje.equals('venta'),
      )
      ..orderBy([
        OrderingTerm(expression: eventos.fechaEvento, mode: OrderingMode.desc),
        OrderingTerm(expression: eventos.creadoEn, mode: OrderingMode.desc),
      ])
      ..limit(1);

    final fila = await consulta.getSingleOrNull();
    return fila?.readTable(eventoPesos).kilos;
  }

  /// Cierra la venta: da de baja a todos sus animales.
  ///
  /// Aqui es donde ira el candado del **tiempo de retiro**. La especificacion es
  /// tajante: si un animal trae retiro activo, la venta se bloquea y esa
  /// validacion no es opcional. Todavia no se puede consultar nada porque los
  /// tratamientos no existen (son otra fase), asi que por ahora no bloquea
  /// nada y el retiro lo cuida la persona, no la app. El dia que existan los
  /// tratamientos, la comprobacion va exactamente aqui, antes del primer
  /// registro de baja.
  Future<void> cerrarVenta(String ventaId) async {
    final venta = await this.venta(ventaId);
    if (venta == null) return;

    final enVenta = await animalesDeVenta(ventaId);

    await transaction(() async {
      for (final fila in enVenta) {
        await registrarBaja(
          animalId: fila.animalId,
          motivo: 'venta',
          fecha: venta.fecha,
          loteVentaId: ventaId,
        );
      }
      await (update(lotesVenta)..where((l) => l.id.equals(ventaId))).write(
        LotesVentaCompanion(
          cerradoEn: Value(ahoraUtcMs()),
          modificadoEn: Value(ahoraUtcMs()),
        ),
      );
    });
  }

  Future<String> registrarBaja({
    required String animalId,
    required String motivo,
    required int fecha,
    String? causa,
    String? loteVentaId,
  }) async {
    final eventoId = await _evento(
      animalId: animalId,
      tipo: 'baja',
      fecha: fecha,
    );
    await into(eventoBajas).insert(
      EventoBajasCompanion.insert(
        eventoId: eventoId,
        motivo: motivo,
        causa: Value(causa),
        loteVentaId: Value(loteVentaId),
      ),
    );
    return eventoId;
  }

  /// Los animales que ya salieron del hato.
  ///
  /// Se calcula, no se guarda: un animal esta de baja si tiene un evento de
  /// baja vivo. Se usa para sacarlo de las listas y de los conteos de los
  /// potreros sin borrarlo ni marcarlo con una columna de estado.
  Future<Set<String>> animalesDadosDeBaja() async {
    final filas = await (select(eventos).join([
      innerJoin(eventoBajas, eventoBajas.eventoId.equalsExp(eventos.id)),
    ])
          ..where(eventos.tipo.equals('baja') & eventos.eliminadoEn.isNull()))
        .get();
    return filas.map((f) => f.readTable(eventos).animalId).toSet();
  }

  Future<void> eliminarVenta(String id) async {
    final ahora = ahoraUtcMs();
    await transaction(() async {
      await (update(lotesVenta)..where((l) => l.id.equals(id))).write(
        LotesVentaCompanion(
          eliminadoEn: Value(ahora),
          modificadoEn: Value(ahora),
        ),
      );
      await (update(loteVentaAnimales)..where((a) => a.loteVentaId.equals(id)))
          .write(
        LoteVentaAnimalesCompanion(
          eliminadoEn: Value(ahora),
          modificadoEn: Value(ahora),
        ),
      );
    });
  }

  /// Borrado logico (regla 3). El renglon se queda; solo se marca la fecha.
  Future<void> eliminarAnimal(String id) async {
    final ahora = ahoraUtcMs();
    await (update(animales)..where((a) => a.id.equals(id))).write(
      AnimalesCompanion(
        eliminadoEn: Value(ahora),
        modificadoEn: Value(ahora),
      ),
    );
  }
}
