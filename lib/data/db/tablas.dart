import 'package:drift/drift.dart';

/// Las cinco columnas que, por las reglas del proyecto, lleva todo registro que
/// algun dia se vaya a sincronizar entre celulares.
///
///   Regla 1 - [id] es un UUID generado en el dispositivo, nunca un contador.
///   Regla 2 - [creadoEn], [modificadoEn] y [dispositivoId] permiten saber cual
///             version es la buena cuando entre un segundo celular.
///   Regla 3 - [eliminadoEn] marca el borrado logico. Nada se borra de verdad,
///             porque un borrado real hace que el otro dispositivo reviva el
///             registro al sincronizar.
///
/// [creadoEn] y [modificadoEn] son instantes UTC en milisegundos. Las fechas de
/// los hechos del rancho no van aqui: esas se guardan como AAAAMMDD.
mixin Auditoria on Table {
  TextColumn get id => text()();
  IntColumn get creadoEn => integer()();
  IntColumn get modificadoEn => integer()();
  IntColumn get eliminadoEn => integer().nullable()();
  TextColumn get dispositivoId => text()();
}

/// El registro central. **Existe antes que el arete**, porque los lotes
/// comprados llegan sin identificar.
///
/// Lo que NO esta aqui importa tanto como lo que si. No hay columnas
/// `numeroArete`, `categoria`, `proposito`, `estado`, `ubicacionActual` ni
/// `pesoActual`: las seis se derivan de los aretes y de los eventos. Guardar
/// cualquiera de ellas romperia la regla 4 y nos condenaria a que dos celulares
/// se contradigan el dia que haya sincronizacion.
@DataClassName('Animal')
class Animales extends Table with Auditoria {
  TextColumn get apodo => text().nullable()();

  /// 'hembra' o 'macho'.
  TextColumn get sexo => text()();

  /// AAAAMMDD, o nulo cuando no se sabe.
  ///
  /// Se acepta que este vacia a proposito. Exigirla volveria laborioso el alta
  /// de un lote comprado, que llega sin papeles y habria que revisar diente por
  /// diente. Un animal sin fecha queda "sin clasificar" y ya.
  IntColumn get fechaNacimiento => integer().nullable()();

  /// Que tan confiable es la fecha: 'exacta', 'mes', 'anio', 'estimada' (por
  /// denticion o por dicho del vendedor) o 'desconocida'.
  TextColumn get nacimientoPrecision =>
      text().withDefault(const Constant('desconocida'))();

  /// De donde salio la estimacion: "2 dientes, ~18 meses al 3-mar-2026".
  TextColumn get nacimientoNota => text().nullable()();

  TextColumn get raza => text().nullable()();

  /// Color, senas, cuernos, marcas. Es lo que permite reconocer a un animal que
  /// todavia no trae arete.
  TextColumn get descripcionFisica => text().nullable()();

  /// 'comprado' o 'nacido'. Es un hecho inmutable del origen, por eso es
  /// columna y no evento.
  TextColumn get origen => text()();

  TextColumn get madreId => text().nullable()();
  TextColumn get padreId => text().nullable()();

  TextColumn get notas => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// El historial de aretes de cada animal.
///
/// Es tabla aparte y no un campo dentro del animal porque **los aretes se caen
/// y se reponen**. Con un campo, reponer un arete borraria el numero anterior y
/// una lectura de un arete viejo ya no encontraria al animal. Con tabla, el
/// numero viejo queda marcado como retirado y se sigue pudiendo buscar.
///
/// El tipo 'particular' es el numero provisional que se pone con marcador o con
/// un arete barato al descargar el camion: sin el, encontrar despues a un
/// animal entre ochenta becerros pardos que en foto se ven identicos es puro
/// optimismo.
@DataClassName('Arete')
class Aretes extends Table with Auditoria {
  TextColumn get animalId => text().references(Animales, #id)();

  /// Los doce digitos impresos en la bandera, no los quince que devuelve el
  /// codigo de barras: el prefijo 484 de Mexico se quita al escanear, para que
  /// el escaneo y la captura manual lleguen al mismo numero.
  TextColumn get numero => text()();

  /// 'siniiga', 'rfid' o 'particular'.
  TextColumn get tipo => text().withDefault(const Constant('siniiga'))();

  IntColumn get fechaColocacion => integer()();

  /// Nulo mientras el arete siga puesto. La unicidad del numero aplica solo
  /// entre los vigentes.
  IntColumn get fechaRetiro => integer().nullable()();

  /// Perdido, ilegible, repuesto.
  TextColumn get motivoRetiro => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Potreros, corrales, cuarentena, manga y lugares fuera del rancho.
///
/// El nombre es el que usa el dueno: "El Zacatal", "Potrero del arroyo".
/// Nunca "Potrero 1".
@DataClassName('Ubicacion')
class Ubicaciones extends Table with Auditoria {
  TextColumn get nombre => text()();

  /// 'potrero', 'corral', 'cuarentena', 'manga' o 'fueraDelRancho'.
  TextColumn get tipo => text()();

  RealColumn get hectareas => real().nullable()();
  TextColumn get tipoPasto => text().nullable()();
  IntColumn get capacidadMaxima => integer().nullable()();
  TextColumn get notas => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Todo lo que le pasa a un animal, con su fecha.
///
/// Los eventos solo se agregan, nunca se pisan. De aqui sale el estado actual
/// del animal y, de regalo, su historial completo.
@DataClassName('Evento')
class Eventos extends Table with Auditoria {
  TextColumn get animalId => text().references(Animales, #id)();

  /// 'movimiento', 'peso', 'destete', 'parto', 'proposito' o
  /// 'correccionCategoria'.
  ///
  /// Destete y parto no tienen tabla de detalle: su unico dato es la fecha, que
  /// ya vive en [fechaEvento]. Crear una tabla vacia para ellos seria ruido.
  TextColumn get tipo => text()();

  /// La fecha del hecho en AAAAMMDD, que puede ser anterior a hoy: se captura
  /// el trabajo de ayer sin problema y entra en su lugar de la historia.
  IntColumn get fechaEvento => integer()();

  TextColumn get notas => text().nullable()();

  /// Agrupa los eventos creados de un golpe en un trabajo por lote, para poder
  /// deshacerlos juntos cuando alguien se los aplique al potrero equivocado.
  TextColumn get loteTrabajoId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// De donde a donde se movio. La ubicacion actual es el destino del movimiento
/// mas reciente.
@DataClassName('EventoMovimiento')
class EventoMovimientos extends Table {
  TextColumn get eventoId => text().references(Eventos, #id)();
  TextColumn get ubicacionOrigenId => text().nullable()();
  TextColumn get ubicacionDestinoId => text().references(Ubicaciones, #id)();
  TextColumn get motivo => text().nullable()();

  @override
  Set<Column> get primaryKey => {eventoId};
}

/// Cuanto peso y de que tipo de pesaje se trata.
@DataClassName('EventoPeso')
class EventoPesos extends Table {
  TextColumn get eventoId => text().references(Eventos, #id)();
  RealColumn get kilos => real()();

  /// 'nacimiento', 'destete', 'rutina', 'compra' o 'venta'.
  TextColumn get tipoPesaje => text().withDefault(const Constant('rutina'))();

  /// 'bascula' o 'estimado'.
  TextColumn get metodo => text().withDefault(const Constant('bascula'))();

  @override
  Set<Column> get primaryKey => {eventoId};
}

/// Comercial o pie de cria. Se puede cambiar, y por eso es evento: una becerra
/// comprada para vender puede quedarse de reemplazo.
@DataClassName('EventoProposito')
class EventoPropositos extends Table {
  TextColumn get eventoId => text().references(Eventos, #id)();
  TextColumn get proposito => text()();

  @override
  Set<Column> get primaryKey => {eventoId};
}

/// La categoria puesta a mano por el dueno.
///
/// Es evento y no columna a proposito: asi la regla 4 sigue en pie, queda la
/// fecha y el motivo, y la ficha puede mostrar que ese animal trae una
/// categoria corregida en vez de calculada.
@DataClassName('EventoCorreccionCategoria')
class EventoCorreccionCategorias extends Table {
  TextColumn get eventoId => text().references(Eventos, #id)();
  TextColumn get categoria => text()();
  TextColumn get motivo => text().nullable()();

  @override
  Set<Column> get primaryKey => {eventoId};
}

/// Fotos de un animal. El archivo vive en la carpeta de la app y aqui se guarda
/// la ruta relativa, porque la absoluta cambia al reinstalar y al restaurar un
/// respaldo.
@DataClassName('Foto')
class Fotos extends Table with Auditoria {
  TextColumn get animalId => text().references(Animales, #id)();
  TextColumn get rutaRelativa => text()();
  BoolColumn get esPrincipal => boolean().withDefault(const Constant(false))();
  IntColumn get tomadaEn => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Ajustes locales del celular: el dispositivoId, los umbrales de categoria,
/// los datos del rancho.
///
/// Es la unica tabla sin columnas de auditoria, y es una excepcion deliberada:
/// describe a este dispositivo, no al ganado, asi que nunca se sincroniza.
@DataClassName('Ajuste')
class Configuracion extends Table {
  TextColumn get clave => text()();
  TextColumn get valor => text()();

  @override
  Set<Column> get primaryKey => {clave};
}

/// Un lote de compra: lo que llego en un camion, de un vendedor, un dia.
///
/// La compra se captura una vez y los animales se le van metiendo escaneando.
/// Si el vendedor y el precio vivieran dentro del alta de cada animal, habria
/// que teclear lo mismo ochenta veces y se perderian los quince segundos por
/// cabeza que costo ganar.
@DataClassName('LoteCompra')
class LotesCompra extends Table with Auditoria {
  IntColumn get fecha => integer()();

  /// Texto libre con autocompletado del historial, no catalogo: dar de alta un
  /// proveedor antes de poder registrar la compra es friccion sin beneficio.
  TextColumn get vendedor => text()();

  TextColumn get lugar => text().nullable()();

  /// 'porKilo' o 'porCabeza'.
  TextColumn get formaCalculo => text()();

  /// Cuando la compra fue por kilo. Es lo que multiplica al peso de recepcion.
  RealColumn get precioPorKilo => real().nullable()();

  /// Lo pagado por los animales, sin contar flete ni comision.
  RealColumn get montoTotal => real()();

  /// Como se reparten los gastos: 'porKilo' o 'porCabeza'. Se elige lote por
  /// lote, no es una regla del rancho.
  TextColumn get formaProrrateoGastos =>
      text().withDefault(const Constant('porCabeza'))();

  TextColumn get notas => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Flete, comision, documentacion. Se reparten entre los animales del lote,
/// aparte del precio de los animales.
@DataClassName('GastoCompra')
class LoteCompraGastos extends Table with Auditoria {
  TextColumn get loteCompraId => text().references(LotesCompra, #id)();
  TextColumn get concepto => text()();
  RealColumn get monto => real()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Que animales trajo el lote.
///
/// El peso de recepcion no vive aqui: es un evento de peso con tipo 'compra',
/// porque es una medicion y le toca la regla 4. Lo que si vive aqui es el
/// precio individual, que es una condicion del trato y no una medicion.
@DataClassName('AnimalComprado')
class LoteCompraAnimales extends Table with Auditoria {
  TextColumn get loteCompraId => text().references(LotesCompra, #id)();
  TextColumn get animalId => text().references(Animales, #id)();

  /// Precio negociado para este animal en concreto, cuando lo hubo. El precio
  /// varia por temporada y por peso final, asi que dentro de un mismo lote
  /// puede haber animales a precios distintos.
  RealColumn get costoIndividual => real().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
