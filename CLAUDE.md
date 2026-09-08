# Aplicación de control de ganado

Aplicación móvil para el control del ganado de un rancho en México. Uso interno de un solo rancho, no es un producto comercial.

La especificación completa está en `docs/proyecto-app-ganado.md`. **Léela antes de proponer cualquier cambio de arquitectura.** Si algo de este archivo contradice la especificación, la especificación gana y hay que avisarme.

## Stack

- Flutter, Android únicamente
- Base de datos local con `drift` sobre SQLite
- Sin servidor y sin backend. Todo funciona sin internet.
- Lectura de códigos de barras con la cámara mediante `mobile_scanner`

Cualquier dependencia nueva se propone y se justifica antes de agregarla. Preferimos pocas dependencias bien elegidas.

## Reglas que no se rompen

Estas cinco existen para que en el futuro se pueda sincronizar entre varios celulares. Hoy solo hay uno, pero romperlas obliga a rehacer todo después.

1. **Identificadores únicos globales.** Toda llave primaria es un UUID generado en el dispositivo. Nunca un entero autoincremental.
2. **Auditoría en cada registro.** Todo lleva `creadoEn`, `modificadoEn` y `dispositivoId`.
3. **Borrado lógico.** Nada se elimina de la base. Se marca con `eliminadoEn`. Toda consulta filtra los eliminados.
4. **Eventos, no estados.** El estado actual de un animal siempre se deriva de sus eventos ordenados por fecha. Prohibido guardar columnas como `pesoActual`, `ubicacionActual` o `ultimoTratamiento`. Si una consulta se vuelve lenta, se optimiza con índices o una vista, nunca desnormalizando a una columna mutable.
5. **Cero totales guardados.** Conteos, inventario, carga animal y márgenes se calculan al momento.

## Reglas de dominio

- **El animal existe antes que el arete.** Los lotes comprados llegan sin identificar y se registran con foto, descripción física y vendedor. El número de arete es un campo opcional que se llena después. Nunca uses el número de arete como llave primaria ni como requisito para crear un animal.
- **La categoría se calcula, no se captura.** Becerro, becerra, destete, novillo, vaquilla, vaca y toro se derivan de sexo, fecha de nacimiento y estado reproductivo. No existe un campo `categoria` editable.
- **La fecha de nacimiento puede ser estimada.** Los animales comprados se calculan por dentición. Debe existir una marca de fecha real contra fecha estimada, y aceptar una edad aproximada.
- **Un animal está en una sola ubicación, pero puede estar en varios apartados.**
- **El tiempo de retiro bloquea la venta.** Si un animal tiene retiro activo, la aplicación impide meterlo a un lote de venta. Esta validación no es opcional ni se puede saltar.
- **Los gastos de alimento no se ligan a ningún animal.** Es un módulo aislado, sin relación con el resto del sistema.

## Nombres

Los términos del dominio van en español porque no tienen equivalente claro en inglés y son el vocabulario real del rancho: `Animal`, `Potrero`, `Arete`, `Apartado`, `LoteCompra`, `LoteVenta`, `Evento`, `Tratamiento`, `TiempoRetiro`.

Todo lo demás sigue las convenciones normales de Dart.

## Diseño de la interfaz

El usuario trabaja con guantes, con una mano, bajo el sol directo, con polvo y sin señal.

- Botones grandes, mínimo 48 dp de área táctil
- Alto contraste, legible bajo el sol
- El botón de escanear va fijo abajo y siempre visible
- **La captura manual del número siempre está a un toque de distancia**, con teclado numérico grande. El código de barras falla seguido con aretes sucios o rayados.
- Meta de rendimiento: registrar un animal debe tomar menos de quince segundos. Si una pantalla no cumple, se rediseña.

## Cómo trabajamos

- **No escribas código antes de acordar el plan.** Propón, espera confirmación, luego implementa.
- Una fase a la vez. Al terminar cada fase, para y avisa antes de seguir.
- Pruebas obligatorias para la lógica de dominio: cálculo de categoría, cálculo de tiempo de retiro, cálculo de margen, derivación de ubicación actual. La interfaz no necesita pruebas por ahora.
- No agregues funcionalidad que no esté en el alcance de la versión 1. Si se te ocurre algo útil, dilo y déjalo anotado, no lo construyas.
- Si algo de la especificación está ambiguo, pregunta. No inventes la respuesta.
