import 'package:flutter_test/flutter_test.dart';
import 'package:ganado/domain/modelos/tipos.dart';
import 'package:ganado/domain/reglas/categoria.dart';

/// Hoy, para todas las pruebas: 8 de septiembre de 2026.
const hoy = 20260908;

DatosCategoria datos({
  Sexo sexo = Sexo.macho,
  int? nace,
  bool destete = false,
  bool parto = false,
  Categoria? correccion,
}) =>
    DatosCategoria(
      sexo: sexo,
      fechaNacimiento: nace,
      tieneDestete: destete,
      tieneParto: parto,
      correccionManual: correccion,
    );

Categoria calc(DatosCategoria d, {UmbralesCategoria? u}) => calcularCategoria(
      d,
      hoy: hoy,
      umbrales: u ?? const UmbralesCategoria(),
    );

void main() {
  group('sin fecha de nacimiento', () {
    test('queda sin clasificar en vez de inventar una categoria', () {
      expect(calc(datos(nace: null)), Categoria.sinClasificar);
      expect(calc(datos(sexo: Sexo.hembra, nace: null)),
          Categoria.sinClasificar);
    });

    test('pero si hay destete registrado ya se puede clasificar', () {
      expect(calc(datos(nace: null, destete: true)), Categoria.torete);
      expect(calc(datos(sexo: Sexo.hembra, nace: null, destete: true)),
          Categoria.vaquilla);
    });

    test('una hembra que ya pario es vaca aunque no se sepa su edad', () {
      expect(calc(datos(sexo: Sexo.hembra, nace: null, parto: true)),
          Categoria.vaca);
    });
  });

  group('por edad, sin destete registrado', () {
    test('antes del umbral es becerro o becerra', () {
      // Nacido hace 3 meses.
      expect(calc(datos(nace: 20260608)), Categoria.becerro);
      expect(calc(datos(sexo: Sexo.hembra, nace: 20260608)),
          Categoria.becerra);
    });

    test('justo en el umbral ya cuenta como destetado', () {
      // Nacido hace exactamente 8 meses.
      expect(calc(datos(nace: 20260108)), Categoria.torete);
    });

    test('un dia antes del umbral todavia es becerro', () {
      // Cumple 8 meses el 9 de septiembre, no el 8.
      expect(calc(datos(nace: 20260109)), Categoria.becerro);
    });

    test('macho adulto es toro', () {
      // Nacido hace 3 anios.
      expect(calc(datos(nace: 20230608)), Categoria.toro);
    });

    test('hembra destetada sin parto es vaquilla, tenga la edad que tenga', () {
      expect(calc(datos(sexo: Sexo.hembra, nace: 20230608)),
          Categoria.vaquilla);
    });
  });

  group('el destete registrado manda sobre la edad', () {
    test('un becerro destetado a los 6 meses ya es torete', () {
      // Nacido hace 6 meses: por edad seria becerro.
      expect(calc(datos(nace: 20260308)), Categoria.becerro);
      expect(calc(datos(nace: 20260308, destete: true)), Categoria.torete);
    });
  });

  group('el parto manda sobre la edad', () {
    test('una vaquilla joven que pario es vaca', () {
      // 18 meses: por edad seria vaquilla.
      expect(calc(datos(sexo: Sexo.hembra, nace: 20250308)),
          Categoria.vaquilla);
      expect(calc(datos(sexo: Sexo.hembra, nace: 20250308, parto: true)),
          Categoria.vaca);
    });

    test('en un macho el parto no cambia nada', () {
      expect(calc(datos(nace: 20230608, parto: true)), Categoria.toro);
    });
  });

  group('correccion a mano', () {
    test('gana sobre todo el calculo', () {
      final d = datos(nace: 20260608, correccion: Categoria.toro);
      expect(calc(d), Categoria.toro);
    });

    test('gana incluso sobre el parto', () {
      final d = datos(
        sexo: Sexo.hembra,
        nace: 20200101,
        parto: true,
        correccion: Categoria.vaquilla,
      );
      expect(calc(d), Categoria.vaquilla);
    });
  });

  group('umbrales configurables', () {
    test('mover el umbral de destete cambia la categoria', () {
      final d = datos(nace: 20260308); // 6 meses
      expect(calc(d), Categoria.becerro);
      expect(calc(d, u: const UmbralesCategoria(mesesDestete: 5)),
          Categoria.torete);
    });

    test('mover el umbral de adulto cambia torete por toro', () {
      final d = datos(nace: 20250308); // 18 meses
      expect(calc(d), Categoria.torete);
      expect(calc(d, u: const UmbralesCategoria(mesesAdulto: 18)),
          Categoria.toro);
    });
  });

  group('edad en meses', () {
    test('cuenta meses cumplidos, no empezados', () {
      expect(edadEnMeses(20260808, hoy), 1);
      expect(edadEnMeses(20260809, hoy), 0); // le falta un dia
    });

    test('es null cuando no se sabe la fecha', () {
      expect(edadEnMeses(null, hoy), isNull);
    });

    test('una fecha futura no da edad negativa', () {
      expect(edadEnMeses(20270101, hoy), 0);
    });

    test('cruza anios correctamente', () {
      expect(edadEnMeses(20240908, hoy), 24);
    });
  });

  group('proximo cambio de categoria', () {
    test('un becerro cambia el dia que cumple el umbral de destete', () {
      // Nacido el 1 de junio de 2026, umbral 8 meses.
      final d = datos(nace: 20260601);
      expect(proximoCambioDeCategoria(d, hoy: hoy), 20270201);
    });

    test('un torete cambia el dia que cumple el umbral de adulto', () {
      final d = datos(nace: 20250101, destete: true);
      expect(proximoCambioDeCategoria(d, hoy: hoy), 20270101);
    });

    test('una vaquilla no tiene cambio por calendario: depende del parto', () {
      final d = datos(sexo: Sexo.hembra, nace: 20250101);
      expect(proximoCambioDeCategoria(d, hoy: hoy), isNull);
    });

    test('un toro y una vaca ya no cambian', () {
      expect(proximoCambioDeCategoria(datos(nace: 20200101), hoy: hoy),
          isNull);
      expect(
        proximoCambioDeCategoria(
          datos(sexo: Sexo.hembra, nace: 20200101, parto: true),
          hoy: hoy,
        ),
        isNull,
      );
    });

    test('sin fecha de nacimiento no hay cambio previsible', () {
      expect(proximoCambioDeCategoria(datos(nace: null, destete: true),
          hoy: hoy), isNull);
    });

    test('con correccion a mano no hay cambio automatico', () {
      final d = datos(nace: 20260601, correccion: Categoria.toro);
      expect(proximoCambioDeCategoria(d, hoy: hoy), isNull);
    });
  });

  group('aritmetica de fechas', () {
    test('sumar meses recorta el dia cuando el mes destino es mas corto', () {
      expect(sumaMeses(20260131, 1), 20260228);
      expect(sumaMeses(20240131, 1), 20240229); // bisiesto
    });

    test('sumar meses cruza el fin de anio', () {
      expect(sumaMeses(20261101, 3), 20270201);
    });

    test('anios bisiestos', () {
      expect(esBisiesto(2024), isTrue);
      expect(esBisiesto(2026), isFalse);
      expect(esBisiesto(2000), isTrue);
      expect(esBisiesto(1900), isFalse);
    });
  });
}
