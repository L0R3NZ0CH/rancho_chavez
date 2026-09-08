/// Cuanto costo un animal comprado.
///
/// Este archivo no sabe de drift ni de Flutter. Recibe datos planos y devuelve
/// numeros, porque de aqui sale la cifra con la que se decide si una compra
/// estuvo bien hecha, y una cifra asi tiene que poder leerse y probarse sin
/// entender SQL.
///
/// **No hay prorrateo.** Cada animal se compra a un vendedor, a un precio, y su
/// costo sale de su propio peso. Repartir el total de un lote entre sus
/// animales solo tendria sentido si se comprara el bulto sin saber que le toco
/// a cada quien, y asi no se compra en este rancho: en un mismo viaje se le
/// pueden comprar dos becerros a un senor y tres a otro, cada uno con su trato.
library;

/// Como se cotizo el animal.
enum FormaCotizacion { porKilo, porCabeza }

/// Por que no se puede saber cuanto costo un animal.
enum FaltaDato {
  /// Se cotizo por kilo y no se ha pesado.
  peso,

  /// No se ha capturado el precio.
  precio,
}

/// Los datos de compra de un animal, ya resueltos.
///
/// "Resueltos" quiere decir que quien arma esto ya decidio si el vendedor y el
/// precio son los propios del animal o los que heredo de la compra.
class CompraDeAnimal {
  const CompraDeAnimal({
    required this.forma,
    this.precioPorKilo,
    this.precioPorCabeza,
    this.pesoCompraKg,
  });

  final FormaCotizacion forma;
  final double? precioPorKilo;
  final double? precioPorCabeza;

  /// Peso de recepcion. Nulo cuando todavia no se pesa.
  final double? pesoCompraKg;
}

/// Lo que costo un animal, o por que no se sabe.
class CostoAnimal {
  const CostoAnimal._({this.total, this.falta});

  const CostoAnimal.conocido(double monto) : this._(total: monto);
  const CostoAnimal.desconocido(FaltaDato falta) : this._(falta: falta);

  /// Nulo cuando no se puede saber. **No se inventa un numero.**
  ///
  /// Un hueco visible es mejor que una cifra que parece cierta y no lo es: el
  /// hueco se tapa yendo a pesar al animal o capturando el precio, y la cifra
  /// falsa se arrastra a todas las cuentas de ahi en adelante sin que nadie lo
  /// note.
  final double? total;

  final FaltaDato? falta;

  bool get seSabe => total != null;
}

/// Calcula lo que costo un animal.
CostoAnimal costoDelAnimal(CompraDeAnimal compra) {
  switch (compra.forma) {
    case FormaCotizacion.porKilo:
      final precio = compra.precioPorKilo;
      if (precio == null || precio <= 0) {
        return const CostoAnimal.desconocido(FaltaDato.precio);
      }
      final peso = compra.pesoCompraKg;
      if (peso == null || peso <= 0) {
        return const CostoAnimal.desconocido(FaltaDato.peso);
      }
      return CostoAnimal.conocido(peso * precio);

    case FormaCotizacion.porCabeza:
      final precio = compra.precioPorCabeza;
      if (precio == null || precio < 0) {
        return const CostoAnimal.desconocido(FaltaDato.precio);
      }
      return CostoAnimal.conocido(precio);
  }
}

/// Suma lo que se sabe de una lista de costos.
///
/// Los que no se saben quedan fuera de la suma y se cuentan aparte, para que la
/// pantalla pueda decir "llevas tanto, y faltan tres por saber" en vez de dar
/// un total que se lee como si estuviera completo.
({double total, int conocidos, int desconocidos}) sumaCostos(
  List<CostoAnimal> costos,
) {
  var total = 0.0;
  var conocidos = 0;
  var desconocidos = 0;

  for (final c in costos) {
    final monto = c.total;
    if (monto == null) {
      desconocidos++;
    } else {
      total += monto;
      conocidos++;
    }
  }

  return (total: total, conocidos: conocidos, desconocidos: desconocidos);
}

/// Resuelve un valor propio del animal, o el heredado de la compra.
T? propioOHeredado<T>(T? propio, T? deLaCompra) => propio ?? deLaCompra;
