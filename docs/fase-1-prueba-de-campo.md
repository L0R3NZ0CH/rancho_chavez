# Fase 1 — Prueba de campo de la lectura del arete

Esta app de una sola pantalla existe para contestar **una** pregunta antes de
construir nada más:

> ¿La cámara de este celular lee de forma confiable los códigos de barras de los
> aretes SINIIGA reales del rancho, incluyendo los sucios, rayados y
> decolorados por el sol?

Si la respuesta es que no, cambia el plan de hardware y hay que comprar un
lector óptico 2D antes de seguir. Por eso esto va primero.

---

## Antes de salir

1. Instala el APK en el celular.
2. **Pon el celular en modo avión.** No es un detalle: el rancho no tiene señal
   y hay que comprobar que la lectura funciona sin internet. La app trae el
   modelo de reconocimiento empaquetado dentro del APK justamente para eso, y
   esta es la prueba de que sí.
3. Carga la batería al cien. La cámara encendida consume mucho y ese consumo
   también es un dato.

## Qué hacer en el corral

Escoge **entre 40 y 60 aretes** y, muy importante, que no sean los bonitos.
La prueba solo sirve si la muestra se parece al ganado de verdad:

- unos cuantos aretes nuevos y limpios
- varios embarrados de lodo
- varios rayados
- varios decolorados por el sol
- alguno doblado o quebrado
- alguno de un animal inquieto, que no se deja

Con cada arete:

1. Toca **ESCANEAR** y acerca la cámara.
2. Si lee, revisa que el número en pantalla sea el mismo que está impreso en la
   bandera del arete y toca **GUARDAR**.
3. Si **no** lee en unos diez segundos, toca **NO SE PUDO LEER**, marca cómo
   estaba el arete y tómale una foto.
4. Si además necesitas el número, tecléalo con **ESCRIBIR A MANO**.

**El botón de NO SE PUDO LEER es el más importante de la app.** Sin él solo
sabríamos cuántos aretes se leyeron, no cuántos se intentaron, y la tasa de
lectura no se podría calcular. Si el arete no se deja, no lo saltes: repórtalo.

## Cosas que vale la pena probar aparte

- **Con guantes puestos.** Si los botones no se dejan picar con guante, se
  rediseñan.
- **A pleno sol de mediodía**, con el brillo al máximo. Si no se ve la
  pantalla, es un problema de diseño, no del sol.
- **Con la lámpara prendida y apagada** (el botón redondo de arriba a la
  derecha). En la sombra de la manga puede hacer toda la diferencia.
- **Limpiando el arete con un trapo** antes de reintentar uno que falló. Si
  limpiar lo arregla casi siempre, eso cambia el procedimiento de trabajo y
  quizá evita comprar equipo.

## Al terminar

Arriba de la pantalla está la **tasa de lectura**. Toca el ícono de copiar en
la barra de arriba y pega el resumen en WhatsApp para tenerlo a la mano.

Lo que hay que reportar:

| Dato | Dónde sale |
|---|---|
| Tasa de lectura | Arriba, en grande |
| Cuántos fallaron y por qué | Los renglones rojos de la lista |
| Simbología del código | En la tarjeta de resumen |
| Qué tan rápido lee | Tiempo mediano, en la tarjeta |
| Cuánta batería se fue | Del propio celular |
| Si los botones sirven con guantes | Tu impresión |
| Si se ve la pantalla al sol | Tu impresión |

## Cómo se interpreta el resultado

Esto es una guía, no una regla. La decisión es tuya.

- **Arriba del 90 %**: la cámara alcanza. No se compra escáner.
- **Entre 70 y 90 %**: probablemente alcance, sobre todo si los fallos se
  arreglan limpiando el arete. Vale la pena una segunda salida antes de gastar.
- **Abajo del 70 %**: hay que comprar un lector óptico 2D de imagen. Nunca
  láser, nunca radiofrecuencia. Ver la sección 3 de la especificación.

---

## Hallazgos

### El código de barras trae tres dígitos que no están impresos en el arete

Primera lectura con aretes reales, 7 de septiembre de 2026, sobre un Galaxy S21
(Android 15). La cámara leyó bien y los doce dígitos coincidieron con lo
impreso. Pero el código devolvió **quince** dígitos, no doce:

```
Código de barras:        484 001409870222     (15 dígitos)
Impreso en la bandera:       001409870222     (12 dígitos)
```

El `484` es el **prefijo GS1 de México**. Va codificado dentro del código de
barras y no aparece impreso en ninguna parte del arete.

**Por qué importa.** La sección 3 de la especificación dice que la ventaja del
código de barras sobre la radiofrecuencia es que hay un solo identificador y no
hay dos números que reconciliar. Resulta que sí hay dos. Si no se corrige, un
animal escaneado queda como `484001409870222` y el mismo animal capturado a
mano —cuando el arete esté sucio— queda como `001409870222`. La app no los
reconoce como el mismo, crea un animal nuevo, y el historial se parte en dos sin
que nadie se dé cuenta hasta que ya son muchos.

**Regla acordada.** La identidad del animal son los **doce dígitos impresos**,
que son los que el vaquero puede leer con los ojos y teclear. Al escanear:

> Si el valor leído trae exactamente 15 dígitos y empieza con `484`, se le
> quitan esos tres. En cualquier otro caso no se toca y se muestra tal cual,
> con su aviso.

La regla está escrita con guarda a propósito: si aparece un arete sin prefijo,
no se activa y los doce dígitos pasan derecho. Si aparece con otro prefijo, la
app avisa en vez de adivinar. El valor crudo se guarda completo siempre.

**Pendiente de confirmar.** Sólo se probaron dos aretes, probablemente del mismo
lote. Falta ver si el `484` sale en todos.

**Resuelto.** La regla quedó implementada en `normalizaArete`, con pruebas que
cubren los casos en que **no** debe activarse: prefijo distinto, longitud
distinta, y un arete cuyo propio número empiece con 484.

### La simbología es Code 128

El arete SINIIGA está impreso en **Code 128**.

Esto simplifica la decisión de hardware. Code 128 es la simbología lineal más
universalmente soportada que existe: la lee cualquier lector 2D de imagen, y
hasta los láser baratos. Si algún día hay que comprar escáner, **no hay ningún
requisito especial** más allá de los que ya trae la sección 3: que sea de imagen
y no láser, por la curvatura del arete de bandera, no por la simbología.

La contra viene de ser un código **lineal**: la información está en el ancho de
las barras, así que un rayón que cruce las barras a lo largo lo puede volver
ilegible aunque el resto del arete se vea bien. Un código bidimensional
aguantaría eso; Code 128 no. Es otra razón para probar aretes rayados de verdad.

### Tiempos de lectura

| Lecturas | Mediana |
|---|---|
| 2 aretes limpios, en interior | 1 276 ms |
| 1 arete, tras la regla del 484 | 2 299 ms |

Ambas cifras son de muestras minúsculas y no son comparables entre sí: una
mediana de una sola lectura es esa lectura. Sirven para decir que la lectura
tarda **del orden de uno a dos segundos**, no para afirmar una tendencia.

### Cierre de la fase: la prueba en el corral no se hizo

El 8 de septiembre de 2026 el dueño decidió **dar el riesgo por despejado** con
la evidencia de escritorio y arrancar la fase 2, sin la salida al corral que
contemplaba el plan.

Queda constancia de con qué se cerró, porque es poco:

- **Dos aretes**, limpios, en interior, probablemente del mismo lote
- Tasa de lectura del 100 %, sobre esas dos lecturas
- **Cero** aretes sucios, rayados, decolorados o doblados
- Sin probar a pleno sol, sin probar con guantes, sin medir batería en jornada

Lo que sí quedó comprobado y no depende del tamaño de la muestra: la cámara
decodifica el Code 128 del arete, los dígitos coinciden con lo impreso, la app
no truena y los datos sobreviven a que Android mate el proceso.

**Lo que sigue sin conocerse es la tasa de lectura con aretes en mal estado**,
que era la pregunta original. Si en el uso real resulta mala, la salida ya está
construida: la captura manual está a un toque, y el hallazgo de que la
simbología es Code 128 significa que cualquier lector 2D de imagen serviría.

---

## Advertencia

**No captures animales de verdad en esta app.** Es una bitácora de prueba y su
tabla se elimina al entrar a la fase 2. Los datos de la fase 1 son
desechables a propósito; los de la fase 2 en adelante ya no, y ahí sí hay
migraciones sin pérdida y respaldo obligatorio.
