# ProfitCraft

Addon pre **World of Warcraft: Forever**, ktorý hľadá výhodné crafty podľa aktuálnych cien v aukcii.

## Čo robí

- Berie ceny z **TSM**, **Auctioneer** alebo **Auctionator** (čo máš nainštalované).
- Načíta naučené recepty z tvojich profesií (stačí raz otvoriť okno profesie).
- Zapamätá si nákupné ceny u vendorov (thready, vialy, flux…) pri otvorení obchodníka.
- Dva režimy:
  - **Craft → predaj na AH** (zisk po 5 % poplatku AH)
  - **AH → craft → vendor** (kúpiš suroviny v aukcii, výrobok predáš vendorovi)
- **Reťazce:** každú surovinu berie najlacnejšie z AH, od vendora alebo z vlastného craftu,
  aj cez viac krokov (napr. bar → diel → výrobok).
- **Plán:** klik na riadok ukáže, čo kúpiť, čo vyrobiť a v akom poradí (x1 / x5 / x10 / x20).

## Inštalácia

Rozbaľ priečinok `ProfitCraft` do:

```
World of Warcraft\_forever_\Interface\AddOns\
```

V hre `/reload`, potom otvor okno každej svojej profesie a napíš `/pc`.

## Príkazy

| Príkaz | Popis |
|---|---|
| `/pc` | otvorí okno |
| `/pc top [n]` / `/pc vendor [n]` | top crafty do chatu |
| `/pc why <item>` | prečo craft nie je v zozname (aj Shift+klik link) |
| `/pc mode ah\|vendor` | režim |
| `/pc chains on\|off` | reťazce cez vlastné crafty |
| `/pc alts on\|off` | zarátať recepty altov na rovnakom realme |
| `/pc source auto\|tsm\|auctioneer\|auctionator` | zdroj cien |
| `/pc tsmbuy <price>` / `/pc tsmsell <price>` | TSM price string (default `first(dbminbuyout, dbmarket)`) |
| `/pc cut <percent>` | poplatok AH |
| `/pc min <goldy>` | minimálny zisk |
| `/pc status` / `/pc reset` | stav / vymazať recepty postavy |

## Poznámky

- Ceny sú také čerstvé, aký je posledný sken tvojho AH addonu.
- Neráta s hĺbkou trhu (či sa daný počet kusov reálne predá).
- Enchanty bez výsledného itemu sa preskakujú.
