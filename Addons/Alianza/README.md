# Alianza — chat común entre hermandades (WoW Forever)

Un canal de chat con clave que comparten varias hermandades.
**Solo quien lo administra necesita el addon.** Los demás se unen al canal
como a cualquier otro canal del juego.

## Para ti (con el addon)

### Instalación

1. Copia la carpeta `Alianza` en `Interface\AddOns\` de WoW Forever.
2. Reinicia el juego y activa **Alianza** en la lista de AddOns.
   Si sale como incompatible, mira el número con `/dump select(4, GetBuildInfo())`
   y ponlo en `## Interface:` dentro de `Alianza.toc` (ahora `16001`).

### Crear el canal

```
/alianza canal NombreCanal Clave
```

Como entras primero, quedas como **dueño del canal**: puedes cambiar la clave y
expulsar gente. Después pasa la línea de unión a los líderes de las otras hermandades:

```
/alianza info       (te muestra la línea para copiarla)
/alianza anunciar   (la envía al chat de tu hermandad)
```

### Comandos

| Comando | Qué hace |
|---|---|
| `/a <mensaje>` | Escribir en el canal de alianza |
| `/alianza <mensaje>` | Igual que `/a` |
| `/alianza canal <nombre> [clave]` | Crear o unirte al canal |
| `/alianza info` | Ver la línea `/join` para pasársela a otros |
| `/alianza anunciar` | Enviar la línea `/join` al chat de tu hermandad |
| `/alianza clave <nueva>` | Cambiar la clave (si eres el dueño) |
| `/alianza expulsar <jugador>` | Expulsar a alguien del canal |
| `/alianza quien` | Ver quién está en el canal |
| `/alianza etiquetas` | Mostrar u ocultar `<Hermandad>` delante de los mensajes |
| `/alianza salir` | Salir del canal y borrar la configuración |

El addon te une al canal al conectarte, espera unos segundos para no cambiar el
número de General y Comercio, y lo muestra en tu ventana de chat.

## Para los demás (sin addon)

1. Escribir una vez:
   ```
   /join NombreCanal Clave
   ```
   El juego lo recuerda para las próximas sesiones.
2. Para hablar, usar el número del canal que aparece en el chat, por ejemplo
   `[5. NombreCanal]` → `/5 hola a todos`.
   Después de usarlo una vez, al pulsar Enter el chat sigue en ese canal.

`/a` solo funciona para quien tiene el addon. Sin addon se usa el número del canal.

## Etiqueta de hermandad

El juego no dice la hermandad en los mensajes de canal. El addon recuerda la
hermandad de los jugadores que ve: los de tu hermandad, tu grupo o banda, tu
objetivo, los que pasas con el ratón y las placas de nombre cercanas. A esos les
pone `<Hermandad>` delante del mensaje; a los que aún no ha visto, no.
Esto solo lo ves tú.

## Límites

- Cualquiera que sepa el nombre y la clave puede entrar. Si se filtra, cámbiala con
  `/alianza clave <nueva>` y vuelve a pasar la línea.
- Si dejas el canal, el siguiente en la lista pasa a ser el dueño.
