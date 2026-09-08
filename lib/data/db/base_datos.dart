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
const versionEsquema = 3;

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
    LoteCompraGastos,
    LoteCompraAnimales,
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
            await m.createTable(lotesCompra);
            await m.createTable(loteCompraGastos);
            await m.createTable(loteCompraAnimales);
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
  Future<String> altaAnimal({
    required String sexo,
    required String origen,
    required String proposito,
    required String ubicacionId,
    required int fecha,
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

      await registrarMovimiento(
        animalId: s.id,
        ubicacionDestinoId: ubicacionId,
        fecha: fecha,
      );

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
    required double montoTotal,
    double? precioPorKilo,
    String? lugar,
    String formaProrrateoGastos = 'porCabeza',
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
        montoTotal: montoTotal,
        precioPorKilo: Value(precioPorKilo),
        lugar: Value(lugar),
        formaProrrateoGastos: Value(formaProrrateoGastos),
        notas: Value(notas),
      ),
    );
    return s.id;
  }

  Future<String> agregarGastoCompra({
    required String loteCompraId,
    required String concepto,
    required double monto,
  }) async {
    final s = await _sello();
    await into(loteCompraGastos).insert(
      LoteCompraGastosCompanion.insert(
        id: s.id,
        creadoEn: s.ahora,
        modificadoEn: s.ahora,
        dispositivoId: s.dispositivo,
        loteCompraId: loteCompraId,
        concepto: concepto,
        monto: monto,
      ),
    );
    return s.id;
  }

  Future<String> agregarAnimalALote({
    required String loteCompraId,
    required String animalId,
    double? costoIndividual,
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
        costoIndividual: Value(costoIndividual),
      ),
    );
    return s.id;
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

  Future<List<GastoCompra>> gastosDelLote(String loteCompraId) =>
      (select(loteCompraGastos)
            ..where((g) =>
                g.loteCompraId.equals(loteCompraId) & g.eliminadoEn.isNull()))
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

  /// Fija el precio negociado de un animal dentro de un lote.
  ///
  /// Gana sobre el calculo del lote, porque el precio varia por temporada y
  /// por peso final y dentro de un mismo camion puede haber tratos distintos.
  Future<void> fijarCostoIndividual({
    required String loteCompraId,
    required String animalId,
    required double? costo,
  }) async {
    await (update(loteCompraAnimales)
          ..where((t) =>
              t.loteCompraId.equals(loteCompraId) &
              t.animalId.equals(animalId)))
        .write(
      LoteCompraAnimalesCompanion(
        costoIndividual: Value(costo),
        modificadoEn: Value(ahoraUtcMs()),
      ),
    );
  }

  /// Vendedores ya usados, para autocompletar sin catalogo previo.
  Future<List<String>> vendedoresUsados() async {
    final filas = await (selectOnly(lotesCompra, distinct: true)
          ..addColumns([lotesCompra.vendedor])
          ..where(lotesCompra.eliminadoEn.isNull()))
        .get();
    return filas
        .map((f) => f.read(lotesCompra.vendedor))
        .whereType<String>()
        .toList();
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
