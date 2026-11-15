# ProfitCraft

Addon pre **World of Warcraft: Forever**, ktorý hľadá výhodné crafty podľa aktuálnych cien v aukcii.

## Čo robí

- Berie ceny z **TSM**, **Auctioneer** alebo **Auctionator** (čo máš nainštalované).
- Načíta všetky recepty tvojich profesií – naučené aj nenaučené (stačí raz otvoriť okno profesie).
  Nenaučené sú označené **[nenaučený]**; ako medzikrok v reťazci sa použijú len naučené.
- Zapamätá si nákupné ceny u vendorov (thready, vialy, flux…) pri otvorení obchodníka.
- Tri režimy:
  - **Craft → predaj na AH** (zisk po 5 % poplatku AH)
  - **AH → craft → vendor** (kúpiš suroviny v aukcii, výrobok predáš vendorovi)
  - **Craft → disenchant** (výrobok rozložíš a dust/essence/shardy predáš na AH po poplatku)
- **Reťazce:** každú surovinu berie najlacnejšie z AH, od vendora alebo z vlastného craftu,
  aj cez viac krokov (napr. bar → diel → výrobok).
- **Plán:** klik na riadok ukáže, čo kúpiť, čo vyrobiť a v akom poradí (x1 / x5 / x10 / x20),
  aj celkový čas craftenia a zisk za hodinu.
- **Časovač craftu** (bývalý CraftTimer): odpočítava zostávajúci čas dávky a ukazuje odhadovaný zisk.

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
| `/pc top [n]` / `/pc vendor [n]` / `/pc de [n]` | top crafty do chatu |
| `/pc why <item>` | prečo craft nie je v zozname (aj Shift+klik link) |
| `/pc mode ah\|vendor\|de` | režim |
| `/pc chains on\|off` | reťazce cez vlastné crafty |
| `/pc alts on\|off` | zarátať recepty altov na rovnakom realme |
| `/pc unlearned on\|off` | zobraziť aj nenaučené recepty (default zapnuté) |
| `/pc source auto\|tsm\|auctioneer\|auctionator` | zdroj cien |
| `/pc tsmbuy <price>` / `/pc tsmsell <price>` | TSM price string (default `first(dbminbuyout, dbmarket)`) |
| `/pc cut <percent>` | poplatok AH |
| `/pc min <goldy>` | minimálny zisk |
| `/pc status` / `/pc reset` | stav / vymazať recepty postavy |
| `/ct test\|lock\|unlock\|reset` | časovač craftu (aj `/pc timer ...`) |

## Poznámky

- Ceny sú také čerstvé, aký je posledný sken tvojho AH addonu.
- Neráta s hĺbkou trhu (či sa daný počet kusov reálne predá).
- Enchanty bez výsledného itemu sa preskakujú.
- Ak máš ešte samostatný addon CraftTimer, vypni ho alebo zmaž, časovač je už súčasťou ProfitCraftu.
- Známy problém (0.4.0): dĺžka craftu, a teda čas a zisk za hodinu v časovači, môže byť vo Forever nepresná.
- Disenchant počíta s **očakávanou hodnotou** podľa *Requires Level* výrobku:
  zelené zbroje ~75 % dust / 20 % essence / 5 % shard, zelené zbrane 20 % dust / 75 % essence / 5 % shard,
  modré = shard (lvl 51+ 0,5 % Nexus Crystal), fialové lvl 51+ = 1–2 Nexus Crystal.
  Biele itemy, košele a tabardy sa rozložiť nedajú. Ak surovina nemá cenu na AH, ráta sa ako 0.
