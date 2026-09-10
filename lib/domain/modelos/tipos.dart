/// Los terminos del dominio van en espanol porque son el vocabulario real del
/// rancho y no tienen equivalente claro en ingles.
library;

enum Sexo {
  hembra,
  macho;

  static Sexo desdeTexto(String v) =>
      v == 'hembra' ? Sexo.hembra : Sexo.macho;

  String get texto => name;
}

/// La categoria del animal.
///
/// **Se captura, no se calcula.** Esto rompe a proposito la regla original del
/// proyecto, y la razon es la misma por la que el precio tampoco se calcula:
/// es un juicio de quien esta viendo al animal. Un animal es becerro porque lo
/// ves y es becerro, no porque una formula lo deduzca de una fecha de
/// nacimiento que casi nunca se conoce.
///
/// El riesgo que advertia la especificacion —"en seis meses hay becerros de
/// tres anios porque nadie los actualizo"— sigue siendo real, y por eso la
/// categoria se guarda **con su fecha** y la app avisa cuando un animal lleva
/// demasiado tiempo en la misma. Avisa; no decide.
///
/// Para los animales **nacidos en el rancho** si se conoce la fecha real, asi
/// que ahi el calculo sigue sirviendo como sugerencia.
enum Categoria {
  /// Las dos de diario. Van a la vista en la captura, sin abrir nada.
  becerro,
  becerra,

  /// Las demas, detras de un "+ otras". Con guante, dos botones son dos
  /// oportunidades de picar mal; seis son seis.
  vaquilla,
  vaca,
  torete,
  toro,

  /// No se ha capturado ni se puede deducir.
  sinClasificar;

  static Categoria desdeTexto(String v) =>
      Categoria.values.firstWhere(
        (c) => c.name == v,
        orElse: () => Categoria.sinClasificar,
      );

  String get texto => name;

  /// Las que se ofrecen al capturar, en orden.
  static const principales = [Categoria.becerro, Categoria.becerra];
  static const otras = [
    Categoria.vaquilla,
    Categoria.vaca,
    Categoria.torete,
    Categoria.toro,
  ];

  /// El sexo sale de la categoria, asi que no hay que preguntarlo aparte.
  ///
  /// Es un toque menos por animal cuando hay un vendedor esperando su dinero,
  /// y ademas no se puede capturar mal: nadie va a marcar "becerro" y "hembra".
  Sexo? get sexo => switch (this) {
        Categoria.becerro || Categoria.torete || Categoria.toro => Sexo.macho,
        Categoria.becerra || Categoria.vaquilla || Categoria.vaca =>
          Sexo.hembra,
        Categoria.sinClasificar => null,
      };

  String get etiqueta => switch (this) {
        Categoria.becerro => 'Becerro',
        Categoria.becerra => 'Becerra',
        Categoria.vaquilla => 'Vaquilla',
        Categoria.vaca => 'Vaca',
        Categoria.torete => 'Torete',
        Categoria.toro => 'Toro',
        Categoria.sinClasificar => 'Sin clasificar',
      };
}

/// Como entro el animal al rancho. Es un hecho inmutable, por eso es columna y
/// no evento.
enum Origen { comprado, nacido }

enum Proposito { comercial, pieDeCria }

enum TipoUbicacion { potrero, corral, cuarentena, manga, fueraDelRancho }

/// El arete SINIIGA es el normal. El particular es el numero provisional que se
/// le pone con marcador o con un arete barato al descargar el camion.
enum TipoArete { siniiga, rfid, particular }

enum TipoEvento {
  movimiento,
  peso,
  destete,
  parto,
  proposito,
  categoria,
  manejo,
  baja,
}

enum TipoPesaje { nacimiento, destete, rutina, compra, venta }
