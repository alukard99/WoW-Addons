# Guild Alliance Chat — a shared chat for several guilds (WoW Forever)

*(Versión en español más abajo.)*

A password-protected chat channel shared by several guilds.
**Only the person who runs it needs the addon.** Everyone else joins the channel
like any other game channel.

## For you (with the addon)

### Install

1. Copy the `Alianza` folder into `Interface\AddOns\` of WoW Forever.
2. Restart the game and enable **Guild Alliance Chat** in the AddOns list.

### Create the channel

```
/alianza channel ChannelName Password
```

Since you join first, you become the **channel owner**: you can change the password and
kick people. Then send the join line to the leaders of the other guilds:

```
/alianza info       (shows the line so you can copy it)
/alianza announce   (sends it to your guild chat)
```

### Commands

| Command | What it does |
|---|---|
| `/a <message>` | Write in the alliance channel |
| `/alianza <message>` | Same as `/a` |
| `/alianza channel <name> [password]` | Create or join the channel |
| `/alianza info` | Show the `/join` line to share with others |
| `/alianza announce` | Send the `/join` line to your guild chat |
| `/alianza password <new>` | Change the password (if you are the owner) |
| `/alianza kick <player>` | Kick someone from the channel |
| `/alianza who` | See who is in the channel |
| `/alianza tags` | Show or hide `<Guild>` in front of messages |
| `/alianza leave` | Leave the channel and clear the settings |

The Spanish commands (`canal`, `anunciar`, `clave`, `expulsar`, `quien`, `etiquetas`, `salir`) also work.

## For everyone else (no addon)

1. Type once: `/join ChannelName Password` (the game remembers it).
2. To talk, use the channel number shown in chat, for example `[5. ChannelName]` → `/5 hello everyone`.

## Guild tag

The game doesn't say the guild in channel messages. The addon remembers the guild of the players
it sees (your guild, group or raid, target, mouseover and nearby nameplates) and puts `<Guild>`
in front of their messages. Only you see this.

---

# Alianza — chat común entre hermandades (WoW Forever)

Un canal de chat con clave que comparten varias hermandades.
**Solo quien lo administra necesita el addon.** Los demás se unen al canal
como a cualquier otro canal del juego.

## Para ti (con el addon)

### Instalación

1. Copia la carpeta `Alianza` en `Interface\AddOns\` de WoW Forever.
2. Reinicia el juego y activa **Guild Alliance Chat** en la lista de AddOns.
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
