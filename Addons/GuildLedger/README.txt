GUILD CONTRIBUTION LEDGER (WoW Forever, interface 16001)
========================================================
(Versión en español: LEEME.txt)

INSTALL
1. Close the game.
2. Copy the whole "GuildLedger" folder into the WoW Forever addons folder:
     World of Warcraft\<Forever folder>\Interface\AddOns\GuildLedger\
   (The Forever folder is the one starting with an underscore. If "Interface\AddOns" doesn't exist, create it.)
3. Start the game and enable "Guild Contribution Ledger" in the AddOns button of the character screen.

USE
  /gl              open/close the window (also from the minimap addons button)
  /gl scan         read the roster again now
  /gl log          joins, leaves, rank changes and players reaching max level
  /gl export       all data as CSV (separated by ;) to paste into Excel/Sheets
  /gl bank         recorded guild bank transactions
  /gl help         command list
  /gl button       show or hide the floating button (click: open/close; right click:
                   history; drag it to move it)

WHAT IT COLLECTS (automatically whenever the game updates the guild list)
  Name, class, level, rank, zone, public note, officer note (if you can see it),
  last online, the date the addon first saw them, and level/rank changes.
  Players who leave the guild are kept as "former members" (their notes are not deleted).

RECORDING CONTRIBUTIONS
  Click a player. In the record on the right:
  - "Notes": free text (saved while you type).
  - "Add contribution": choose a category (left/right click the button), an optional value
    (gold, points, amount... whatever your guild uses) and a description. Enter or "Add".
  - Hover a contribution to see the details and who recorded it; the X deletes it.
  The "Contrib." column shows the number of contributions and (total value). Click the
  headers to sort.

GUILD BANK
  Each time you open the bank, the addon asks the game for the log of every tab and of
  the gold, and saves the new transactions (without duplicating the ones it already had).
  - Gold and item deposits are added automatically as the player's contributions
    (categories "Bank: gold" with the value in gold, and "Bank: items").
  - Withdrawals and repairs are not contributions, but they count in the record summary.
  - "Bank" button (or /gl bank): all transactions. "View bank" in the record: only that player's.
  - The game only keeps the latest transactions of each tab: open the bank often.
  - Times are approximate (the game only says "X hours ago").

SHIFT+CLICK
  Click a text box of the addon (search, notes or contribution description) and then
  Shift+click an item (bags, bank, chat, links...): its name is written.

IMPORTANT
  - Data is saved in WTF\Account\<account>\SavedVariables\GuildLedger.lua when you
    log out or /reload. If the game crashes, that session's data is lost.
  - Data is local: only you see it. To share it use /gl export.
