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

/// La categoria del animal. Se calcula, nunca se captura.
///
/// No existe "novillo": en este rancho no se castra, asi que la categoria no
/// aplica y tampoco existiria el dato que la sustentaria.
///
/// Tampoco existe "destete" como categoria propia. El destete es un hecho con
/// fecha, y un animal destetado pasa directo a torete o vaquilla.
enum Categoria {
  becerro,
  becerra,
  torete,
  vaquilla,
  toro,
  vaca,

  /// No se sabe la edad y no hay destete registrado.
  ///
  /// Existe a proposito. Un lote comprado llega sin papeles y exigir la fecha
  /// de nacimiento para poder darlo de alta volveria laborioso justo lo que
  /// tiene que ser rapido. Es mas honesto decir que no se sabe que inventar un
  /// "becerro".
  sinClasificar;

  static Categoria desdeTexto(String v) =>
      Categoria.values.firstWhere((c) => c.name == v);

  String get texto => name;

  String get etiqueta => switch (this) {
        Categoria.becerro => 'Becerro',
        Categoria.becerra => 'Becerra',
        Categoria.torete => 'Torete',
        Categoria.vaquilla => 'Vaquilla',
        Categoria.toro => 'Toro',
        Categoria.vaca => 'Vaca',
        Categoria.sinClasificar => 'Sin clasificar',
      };
}

/// Como entro el animal al rancho. Es un hecho inmutable, por eso es columna y
/// no evento.
enum Origen { comprado, nacido }

enum Proposito { comercial, pieDeCria }

enum TipoUbicacion { potrero, corral, cuarentena, manga, fueraDelRancho }

/// El arete SINIIGA es el normal. El particular es el numero provisional que se
/// le pone con marcador o con un arete barato al descargar el camion, para
/// poder encontrar despues a un animal entre ochenta becerros pardos que en
/// foto se ven identicos.
enum TipoArete { siniiga, rfid, particular }

enum TipoEvento {
  movimiento,
  peso,
  destete,
  parto,
  proposito,
  correccionCategoria,
}

enum TipoPesaje { nacimiento, destete, rutina, compra, venta }
