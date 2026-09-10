import 'package:flutter_test/flutter_test.dart';
import 'package:ganado/domain/modelos/tipos.dart';
import 'package:ganado/domain/reglas/categoria.dart';

/// La categoría se captura porque es un juicio de quien ve al animal, igual que
/// el precio. El riesgo que eso trae —que nadie la actualice— se cubre con un
/// aviso, no cambiándola sola.
void main() {
  const hoy = 20260908;

  group('el sexo sale de la categoría', () {
    test('los machos', () {
      expect(Categoria.becerro.sexo, Sexo.macho);
      expect(Categoria.torete.sexo, Sexo.macho);
      expect(Categoria.toro.sexo, Sexo.macho);
    });

    test('las hembras', () {
      expect(Categoria.becerra.sexo, Sexo.hembra);
      expect(Categoria.vaquilla.sexo, Sexo.hembra);
      expect(Categoria.vaca.sexo, Sexo.hembra);
    });

    test('sin clasificar no dice nada del sexo', () {
      expect(Categoria.sinClasificar.sexo, isNull);
    });

    test('todas las capturables dicen su sexo', () {
      // Si se agrega una categoria nueva y se olvida su sexo, esto lo caza.
      for (final c in [
        ...Categoria.principales,
        ...Categoria.otras,
      ]) {
        expect(c.sexo, isNotNull, reason: '${c.name} no dice su sexo');
      }
    });
  });

  group('las dos de diario van a la vista', () {
    test('becerro y becerra son las principales', () {
      expect(Categoria.principales, [Categoria.becerro, Categoria.becerra]);
    });

    test('las otras cuatro van detrás del +', () {
      expect(Categoria.otras, hasLength(4));
      expect(Categoria.otras, isNot(contains(Categoria.becerro)));
      expect(Categoria.otras, isNot(contains(Categoria.sinClasificar)));
    });

    test('entre las dos listas están todas las capturables', () {
      final capturables = Categoria.values
          .where((c) => c != Categoria.sinClasificar)
          .toSet();
      expect(
        {...Categoria.principales, ...Categoria.otras},
        capturables,
      );
    });
  });

  group('un texto raro no revienta', () {
    test('una categoría desconocida cae en sin clasificar', () {
      // Si un respaldo viejo trae "novillo", que la app no truene.
      expect(Categoria.desdeTexto('novillo'), Categoria.sinClasificar);
    });

    test('las conocidas se leen bien', () {
      expect(Categoria.desdeTexto('vaquilla'), Categoria.vaquilla);
    });
  });

  group('aviso de que ya se quedó corto el nombre', () {
    test('un becerro recién capturado no avisa nada', () {
      final aviso = avisoDeCategoria(
        categoria: Categoria.becerro,
        desde: 20260901,
        hoy: hoy,
      );
      expect(aviso, isNull);
    });

    test('un becerro de más de ocho meses sí avisa', () {
      final aviso = avisoDeCategoria(
        categoria: Categoria.becerro,
        desde: 20251001,
        hoy: hoy,
      );
      expect(aviso, isNotNull);
      expect(aviso!.meses, 11);
      expect(aviso.limite, 8);
    });

    test('justo en el umbral ya avisa', () {
      final aviso = avisoDeCategoria(
        categoria: Categoria.becerra,
        desde: 20260108,
        hoy: hoy,
      );
      expect(aviso, isNotNull);
      expect(aviso!.meses, 8);
    });

    test('un día antes del umbral todavía no', () {
      final aviso = avisoDeCategoria(
        categoria: Categoria.becerra,
        desde: 20260109,
        hoy: hoy,
      );
      expect(aviso, isNull);
    });

    test('una vaca y un toro nunca avisan: ya son finales', () {
      for (final c in [Categoria.vaca, Categoria.toro]) {
        expect(
          avisoDeCategoria(categoria: c, desde: 20200101, hoy: hoy),
          isNull,
          reason: '${c.name} no deberia avisar',
        );
      }
    });

    test('un torete avisa a los dos años, no a los ocho meses', () {
      expect(
        avisoDeCategoria(
          categoria: Categoria.torete,
          desde: 20251001,
          hoy: hoy,
        ),
        isNull,
      );
      expect(
        avisoDeCategoria(
          categoria: Categoria.torete,
          desde: 20230101,
          hoy: hoy,
        ),
        isNotNull,
      );
    });

    test('sin fecha de captura no hay de qué avisar', () {
      expect(
        avisoDeCategoria(
          categoria: Categoria.becerro,
          desde: null,
          hoy: hoy,
        ),
        isNull,
      );
    });

    test('sin clasificar tampoco avisa', () {
      expect(
        avisoDeCategoria(
          categoria: Categoria.sinClasificar,
          desde: 20200101,
          hoy: hoy,
        ),
        isNull,
      );
    });

    test('los umbrales se pueden mover', () {
      final aviso = avisoDeCategoria(
        categoria: Categoria.becerro,
        desde: 20260401,
        hoy: hoy,
        umbrales: const UmbralesCategoria(mesesDestete: 5),
      );
      expect(aviso, isNotNull);
      expect(aviso!.limite, 5);
    });
  });
}
