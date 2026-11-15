---
description: Nechaj Codex skontrolovať aktuálne zmeny v ProfitCraft (read-only)
---

1. Zisti zmeny: `git diff HEAD --stat` a `git diff HEAD` (ak nie je nič necommitnuté, použi posledný commit: `git show HEAD`).
2. Spusti Codex ako reviewera v read-only sandboxe:

```
codex exec --sandbox read-only "Si QA reviewer podľa AGENTS.md. Skontroluj necommitnuté zmeny v tomto repe (spusti si git diff HEAD). Kontext od autora: $ARGUMENTS"
```

3. Výstup Codexu mi zhrň po slovensky:
   - nálezy podľa závažnosti (KRITICKÉ / STREDNÉ / DROBNÉ),
   - pri každom: súhlasíš / nesúhlasíš a prečo,
   - čo navrhuješ opraviť.
4. Kritické nálezy, s ktorými súhlasíš, oprav hneď a spusti review ešte raz (max. 2 kolá spolu).
5. Na konci mi napíš konkrétne kroky na test v hre.
