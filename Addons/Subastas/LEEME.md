# Subastas para World of Warcraft: Forever

Escanea la casa de subastas, guarda un historial de precios por reino y facción, y genera un texto
listo para pegarlo en una IA (Claude, ChatGPT...) para que te diga qué comprar para revender, qué está
barato y qué está caro respecto a lo habitual.

## Instalar

Copia la carpeta `Subastas` en `Interface\AddOns` de WoW Forever, de modo que
quede `Interface\AddOns\Subastas\Subastas.toc`. Si sale como «desactualizado», marca «Cargar AddOns desactualizados».

## Usar

1. Abre la casa de subastas. Encima de su ventana aparecen los botones **Escanear** y **Subastas**.
2. Pulsa **Escanear** y espera a que diga «Escaneo terminado».
   - El escaneo completo lo limita el servidor a una vez cada 15 minutos.
   - Si el escaneo completo no funciona, `/subastas paginas` escanea página a página (más lento, siempre funciona).
3. Pulsa **Subastas** (o escribe `/subastas`), luego **Exportar** y **Copiar todo**, y después **Ctrl+C**.
   WoW no deja a los addons escribir en el portapapeles, así que el botón deja el texto seleccionado y tú lo copias.
4. Pégalo en la IA. El texto ya incluye las instrucciones de qué analizar, así que no hace falta escribir nada más.

Cuantos más días escanees, mejor: la comparación con el «precio habitual» usa los días anteriores.
Lo ideal es escanear una vez al día durante una semana antes de fiarte de las comparaciones.

## Opciones

- **Orden:** Volumen (los objetos que más se mueven), Más baratos o Más caros respecto a su histórico.
- **Máx. objetos:** cuántas líneas exportar (1500 por defecto). Una casa entera puede tener miles de objetos;
  si la IA dice que el texto es demasiado largo, baja este número.
- `/subastas dias 30` cambia cuántos días de historial se guardan (14 por defecto).
- `/subastas borrar` borra los datos del reino y facción actuales.
- Botón flotante: clic abre o cierra la ventana, clic derecho escanea (con la casa de subastas abierta), arrástralo para moverlo. `/subastas boton` lo muestra u oculta.

## Datos que se exportan

Por objeto: número de subastas, unidades, vendedores distintos, precio mínimo, percentil 25 y mediana
(por unidad), el p25 habitual de los días anteriores, precio de venta al vendedor NPC, la desviación del
mínimo frente al habitual y los tres precios más bajos con sus unidades (sirve para ver si comprar el
más barato compensa o si detrás hay un muro de precios altos).

El historial se guarda en `WTF\Account\<cuenta>\SavedVariables\Subastas.lua`.

## Notas

- El addon detecta qué API de subastas tiene el cliente (la moderna `C_AuctionHouse` o la clásica
  `QueryAuctionItems`) y usa la que haya.
- Solo cuentan los precios de compra inmediata; las subastas solo con puja suman unidades pero no precio.
