# AH Price Export for World of Warcraft: Forever

(Versión en español: LEEME.md)

Scans the auction house, keeps a price history per realm and faction, and builds a text ready to paste
into an AI (Claude, ChatGPT...) so it can tell you what to buy to resell, what is cheap and what is
expensive compared with the usual price.

## Install

Copy the `Subastas` folder into `Interface\AddOns` of WoW Forever, so you end up with
`Interface\AddOns\Subastas\Subastas.toc`. If it shows as "out of date", tick "Load out of date AddOns".

## Use

1. Open the auction house. The **Scan** and **AH Price Export** buttons appear above its window.
2. Press **Scan** and wait until it says "Scan finished".
   - The server only allows a full scan once every 15 minutes.
   - If the full scan doesn't work, `/subastas pages` scans page by page (slower, always works).
3. Press **AH Price Export** (or type `/subastas`), then **Export** and **Copy all**, and then **Ctrl+C**.
   WoW doesn't let addons write to the clipboard, so the button selects the text and you copy it.
4. Paste it into the AI. The text already includes the instructions on what to analyze.

The more days you scan, the better: the comparison with the "usual price" uses the previous days.
Ideally scan once a day for a week before trusting the comparisons.

## Options

- **Order:** Volume (items that move the most), Cheapest or Most expensive compared with their history.
- **Max items:** how many lines to export (1500 by default). A full auction house can have thousands of
  items; if the AI says the text is too long, lower this number.
- `/subastas days 30` changes how many days of history are kept (14 by default).
- `/subastas clear` deletes the data of the current realm and faction.

The history is saved in `WTF\Account\<account>\SavedVariables\Subastas.lua`.

Only buyout prices count; bid-only auctions add units but no price.
