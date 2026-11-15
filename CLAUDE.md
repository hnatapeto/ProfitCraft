# ProfitCraft – pokyny pre Claude Code

## Projekt
ProfitCraft je addon pre **World of Warcraft: Forever** (Blizzard Classic+ na modernom Mainline klientovi, API z Midnight 12.1.x, Interface 16001).
Hľadá výhodné crafty podľa cien z TSM / Auctioneer / Auctionator, skladá reťazce craftov, ukazuje plán nákupu a craftu, TSM nákupný string, časovač craftu a ikonu pri minimape.

Repo: https://github.com/hnatapeto/ProfitCraft
Komunikuj so mnou (Peťo) **po slovensky**.

## Štruktúra
- `ProfitCraft/ProfitCraft.toc` – manifest (Interface, verzia, poradie súborov, SavedVariables `ProfitCraftDB`)
- `ProfitCraft/Core.lua` – zdroje cien, sken profesií a vendorov, rekurzívny výpočet nákladov (`BestCost`/`RecipeCost`), `Evaluate`/`Top`, `/pc` príkazy, eventy
- `ProfitCraft/UI.lua` – hlavné okno, tooltipy, plán (pole na počet craftov), TSM string popup
- `ProfitCraft/Timer.lua` – časovač craftu (bývalý CraftTimer), meria `castTime` receptov
- `ProfitCraft/Minimap.lua` – ikona pri minimape + AddonCompartment

## Pravidlá pre kód
- Lua 5.1 (WoW). Žiadne externé knižnice (žiadne Ace3/LibStub), kým to Peťo neschváli.
- Iba **moderné API**: `C_TradeSkillUI`, `C_Item`, `C_MerchantFrame`, `C_Timer`… Staré Classic API (`GetTradeSkillInfo` a pod.) nepoužívaj. Pri nejasnosti over API na https://warcraft.wiki.gg a napíš, že je to neoverené vo Forever.
- Volania cudzích addonov (TSM_API, AucAdvanced, Auctionator.API) vždy cez `pcall`.
- Žiadne globálne premenné okrem: `ProfitCraft`, `ProfitCraftDB`, `SLASH_*`, `ProfitCraft_OnAddonCompartmentClick`, názvov rámov `ProfitCraft*`.
- Texty v hre bez diakritiky (font nemusí mať č, ť, ľ…).
- Nové nastavenie = položka v `defaults` v Core.lua (migrácia sa deje sama, chýbajúce kľúče sa doplnia).
- Nový `.lua` súbor = pridať do `.toc` a upozorniť Peťa, že treba **reštart hry** (nie /reload).
- Pri každej zmene zvýš `## Version` v `.toc` (semver: oprava = patch, funkcia = minor).
- Nič nesmie posielať dáta mimo hru (WoW to ani nedovolí – ale žiadne pokusy o obchádzanie).

## Spolupráca s Codexom (povinné)
Codex CLI je nainštalovaný a slúži ako **nezávislý QA / reviewer**. Postup pri každej netriviálnej zmene:

1. **Plán** – krátko napíš Peťovi, čo ideš meniť. Pri väčšej zmene si plán najprv nechaj skontrolovať od Codexu:
   `codex exec --sandbox read-only "Si reviewer WoW addonu ProfitCraft (pozri AGENTS.md). Posúď tento plán, nájdi riziká a chýbajúce prípady: <plán>"`
2. **Implementácia** – urob zmenu.
3. **Kontrola** – spusti `luacheck ProfitCraft` (ak je nainštalovaný) a potom review od Codexu (príkaz `/codex-review`).
4. **Oprava** – zapracuj nálezy, s ktorými súhlasíš. S ktorými nesúhlasíš, zdôvodni. Max. **2 kolá** review, potom rozhodne Peťo.
5. **Test v hre** – napíš Peťovi presne, čo má v hre otestovať (kroky + očakávaný výsledok). Kým to nepotvrdí, **nepushuj**.
6. **Commit** – po potvrdení commit so správou v tvare `vX.Y.Z: čo sa zmenilo`. Push iba keď to Peťo povie.

Codex v review móde **nikdy needituje súbory** (vždy `--sandbox read-only`). Úpravy robíš iba ty.

## Testovanie v hre
- Addon priečinok je prepojený (junction) z `_forever_\Interface\AddOns\ProfitCraft` na `ProfitCraft/` v tomto repe – zmeny sú v hre po `/reload` (nové súbory po reštarte).
- Užitočné príkazy: `/pc`, `/pc why <item>`, `/pc status`, `/ct test`, `/pc minimap`.
- Lua chyby zachytáva BugSack – keď Peťo pošle chybu, najprv nájdi príčinu, až potom opravuj.

## Známe otvorené veci
- Časovač: dĺžka craftu z `UnitCastingInfo` vo Forever ešte nie je overená (podozrenie na ~25 s/craft pri Gold Power Core).
- Hĺbka trhu sa nerieši (či sa daný počet kusov reálne predá).
- Enchanty bez výsledného itemu sa preskakujú.
