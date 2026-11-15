-- ProfitCraft - Core
-- Ceny z TSM / Auctioneer / Auctionator, recepty z naucenych profesii,
-- vypocet zisku pre predaj na AH alebo vendorovi.
-- Retazce: kazda surovina sa berie najlacnejsie z AH, od vendora alebo
-- z vlastneho craftu (aj viacstupnovo, napr. bar -> diel -> vyrobok).

local ADDON, ns = ...
local PC = CreateFrame("Frame")
ns.PC = PC
_G.ProfitCraft = PC

local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local RequestItem = (C_Item and C_Item.RequestLoadItemDataByID) or function() end
local BASIC = (Enum and Enum.CraftingReagentType and Enum.CraftingReagentType.Basic) or 1

local defaults = {
    source    = "auto",                          -- auto | tsm | auctioneer | auctionator
    tsmBuy    = "first(dbminbuyout, dbmarket)",  -- TSM cena pri nakupe surovin
    tsmSell   = "first(dbminbuyout, dbmarket)",  -- TSM cena pri predaji vyrobku
    ahCut     = 5,           -- % poplatok AH z predaja
    minProfit = 0,           -- v medi
    mode      = "ah",        -- ah | vendor | de
    chains    = true,        -- pouzivat vlastne crafty ako suroviny
    useAlts   = false,       -- zaratat aj recepty altov na tom istom realme
    chars     = {},
    vendor    = {},          -- itemID -> nakupna cena u vendora (za kus)
    castTime  = {},          -- recipeID -> dlzka craftu v sekundach (zbiera Timer)
    timer     = {},          -- pozicia/zamknutie okna casovaca
    minimap   = {},          -- ikona pri minimape (angle, hide)
    useStock  = true,        -- plan: najprv pouzit vlastne zasoby
    useAltStock = false,     -- plan: zaratat aj zasoby altov (cez TSM)
}

local function Print(msg) print("|cff33ff99ProfitCraft|r: " .. tostring(msg)) end
ns.Print = Print

function ns.Money(c)
    if not c then return "|cff888888?|r" end
    local neg = c < 0
    c = math.abs(math.floor(c + 0.5))
    local s = GetMoneyString and GetMoneyString(c, true) or (c .. "c")
    return neg and ("|cffff4040-|r" .. s) or s
end

local function ItemLabel(id, fallback)
    local _, link = GetItemInfo(id)
    return link or fallback or ("item:" .. id)
end
ns.ItemLabel = ItemLabel

---------------------------------------------------------------------------
-- Zdroje cien  (kind = "buy" | "sell")
---------------------------------------------------------------------------
local sources = {}

sources.tsm = {
    name = "TSM",
    available = function() return TSM_API and TSM_API.GetCustomPriceValue end,
    price = function(id, kind)
        local str = kind == "sell" and PC.db.tsmSell or PC.db.tsmBuy
        local ok, v = pcall(TSM_API.GetCustomPriceValue, str, "i:" .. id)
        if ok and v and v > 0 then return v end
    end,
}

sources.auctioneer = {
    name = "Auctioneer",
    available = function() return AucAdvanced and AucAdvanced.API and AucAdvanced.API.GetMarketValue end,
    price = function(id)
        local link = select(2, GetItemInfo(id)) or ("item:" .. id)
        local ok, v = pcall(AucAdvanced.API.GetMarketValue, link)
        if ok and v and v > 0 then return math.floor(v) end
    end,
}

sources.auctionator = {
    name = "Auctionator",
    available = function()
        return Auctionator and Auctionator.API and Auctionator.API.v1
            and Auctionator.API.v1.GetAuctionPriceByItemID
    end,
    price = function(id)
        local ok, v = pcall(Auctionator.API.v1.GetAuctionPriceByItemID, ADDON, id)
        if ok and v and v > 0 then return v end
    end,
}

local ORDER = { "tsm", "auctioneer", "auctionator" }
ns.sources, ns.ORDER = sources, ORDER

local priceCache

function PC:AHPrice(id, kind)
    kind = kind or "buy"
    local ck = kind .. id
    if priceCache and priceCache[ck] ~= nil then
        return priceCache[ck] or nil
    end
    local v
    if self.db.source ~= "auto" then
        local s = sources[self.db.source]
        if s and s.available() then v = s.price(id, kind) end
    else
        for _, k in ipairs(ORDER) do
            local s = sources[k]
            if s.available() then
                v = s.price(id, kind)
                if v then break end
            end
        end
    end
    if priceCache then priceCache[ck] = v or false end
    return v
end

function PC:ActiveSourceNames()
    local t = {}
    for _, k in ipairs(ORDER) do
        if sources[k].available() then t[#t + 1] = sources[k].name end
    end
    return #t > 0 and table.concat(t, ", ") or "|cffff4040ziadny|r"
end

function PC:VendorBuy(id)
    local v = self.db.vendor[id]
    if v then return v end
    if sources.tsm.available() then
        local ok, x = pcall(TSM_API.GetCustomPriceValue, "vendorbuy", "i:" .. id)
        if ok and x and x > 0 then return x end
    end
end

-- predajna cena u vendora; nil = item este nie je nacitany
function PC:VendorSell(id)
    local name, _, _, _, _, _, _, _, _, _, sell = GetItemInfo(id)
    if not name then
        RequestItem(id)
        self.pending = true
        return nil
    end
    return sell
end

---------------------------------------------------------------------------
-- Disenchant: ocakavane suroviny podla "Requires Level" vyrobku
---------------------------------------------------------------------------
local NEXUS = 20725
-- max = horna hranica required levelu; dust/ess = { itemID, priemerny pocet }
local DE_TABLE = {
    { max = 10, dust = { 10940, 1.5 }, ess = { 10938, 1.5 } },                 -- Strange / Lesser Magic
    { max = 15, dust = { 10940, 2.5 }, ess = { 10939, 1.5 }, shard = 10978 },  -- Greater Magic / Small Glimmering
    { max = 20, dust = { 10940, 5 },   ess = { 10998, 1.5 }, shard = 10978 },  -- Lesser Astral
    { max = 25, dust = { 11083, 1.5 }, ess = { 11082, 1.5 }, shard = 11084 },  -- Soul / Greater Astral / Large Glimmering
    { max = 30, dust = { 11083, 3.5 }, ess = { 11134, 1.5 }, shard = 11138 },  -- Lesser Mystic / Small Glowing
    { max = 35, dust = { 11137, 1.5 }, ess = { 11135, 1.5 }, shard = 11139 },  -- Vision / Greater Mystic / Large Glowing
    { max = 40, dust = { 11137, 3.5 }, ess = { 11174, 1.5 }, shard = 11177 },  -- Lesser Nether / Small Radiant
    { max = 45, dust = { 11176, 1.5 }, ess = { 11175, 1.5 }, shard = 11178 },  -- Dream / Greater Nether / Large Radiant
    { max = 50, dust = { 11176, 3.5 }, ess = { 16202, 1.5 }, shard = 14343 },  -- Lesser Eternal / Small Brilliant
    { max = 55, dust = { 16204, 1.5 }, ess = { 16203, 1.5 }, shard = 14344, nexus = true }, -- Illusion / Greater Eternal / Large Brilliant
    { max = 60, dust = { 16204, 3.5 }, ess = { 16203, 2 },   shard = 14344, nexus = true },
}
local NO_DE_SLOT = { [""] = true, INVTYPE_BODY = true, INVTYPE_TABARD = true, INVTYPE_NON_EQUIP_IGNORE = true }

function PC:DEMaterialIDs()
    local t = { NEXUS }
    for _, r in ipairs(DE_TABLE) do
        t[#t + 1] = r.dust[1]; t[#t + 1] = r.ess[1]
        if r.shard then t[#t + 1] = r.shard end
    end
    return t
end

-- zoznam { id, chance, avg, qty = chance*avg } ; false = neda sa rozlozit ; nil = item este nie je nacitany
function PC:DisenchantOutcomes(id)
    local name, _, quality, _, reqLevel, _, _, _, equipLoc, _, _, classID = GetItemInfo(id)
    if not name then
        RequestItem(id)
        self.pending = true
        return nil
    end
    if not quality or quality < 2 or quality > 4 then return false end
    if classID ~= 2 and classID ~= 4 then return false end
    if NO_DE_SLOT[equipLoc or ""] then return false end

    local lvl = math.max(reqLevel or 0, 1)
    local row = DE_TABLE[#DE_TABLE]
    for _, r in ipairs(DE_TABLE) do
        if lvl <= r.max then row = r; break end
    end

    local out = {}
    local function add(itemID, chance, avg)
        if itemID and chance > 0 then
            out[#out + 1] = { id = itemID, chance = chance, avg = avg, qty = chance * avg }
        end
    end
    if quality == 2 then
        -- zelene: zbroj ~75% dust / 20% essence / 5% shard, zbrane naopak
        local weapon = classID == 2
        local pShard = row.shard and 0.05 or 0
        local pMinor = 0.20
        local pMajor = 1 - pShard - pMinor
        add(row.dust[1], weapon and pMinor or pMajor, row.dust[2])
        add(row.ess[1], weapon and pMajor or pMinor, row.ess[2])
        add(row.shard, pShard, 1)
    elseif quality == 3 then
        -- modre: shard (lvl 51+ obcas Nexus Crystal)
        local shard = row.shard or 10978
        if row.nexus then
            add(shard, 0.995, 1)
            add(NEXUS, 0.005, 1)
        else
            add(shard, 1, 1)
        end
    else
        -- fialove: lvl 51+ 1-2 Nexus Crystal, nizsie 2-4 shardy
        if row.nexus then add(NEXUS, 1, 1.5) else add(row.shard or 10978, 1, 3) end
    end
    return out
end

-- hodnota rozlozenia 1 kusu (po poplatku AH za predaj surovin)
-- vrati value|nil, outs|false|nil
function PC:DisenchantValue(id)
    local outs = self:DisenchantOutcomes(id)
    if not outs then return nil, outs end
    local cut = 1 - (self.db.ahCut or 5) / 100
    local total, have = 0, false
    for _, o in ipairs(outs) do
        o.unit = self:AHPrice(o.id, "sell")
        if o.unit then
            total = total + o.unit * o.qty * cut
            have = true
        end
    end
    if not have then return nil, outs end
    return math.floor(total), outs
end

---------------------------------------------------------------------------
-- Vlastne zasoby: tasky + banka + posta (cez TSM, inak vlastny sken posty)
---------------------------------------------------------------------------
local GetCount = (C_Item and C_Item.GetItemCount) or GetItemCount

function PC:Owned(id)
    if TSM_API and TSM_API.GetPlayerTotals then
        local ok, player, alts = pcall(TSM_API.GetPlayerTotals, "i:" .. id)
        if ok and type(player) == "number" then
            local n = player
            if self.db.useAltStock and type(alts) == "number" then n = n + alts end
            return n
        end
    end
    local n = 0
    if GetCount then
        local ok, c = pcall(GetCount, id, true, false, true, true)
        if ok and c then n = c end
    end
    local mail = self.char and self.char.mail
    if mail and mail[id] then n = n + mail[id] end
    return n
end

-- najlacnejsia cena 1 kusu (pre hodnotu pouzitych zasob)
function PC:CostOf(id)
    return self:VendorBuy(id) or self:AHPrice(id, "buy")
end

function PC:ScanMail()
    if not GetInboxNumItems then return end
    local mail = {}
    local maxAtt = ATTACHMENTS_MAX_RECEIVE or 16
    for i = 1, GetInboxNumItems() do
        for j = 1, maxAtt do
            local name, itemID, _, count = GetInboxItem(i, j)
            if name and itemID then mail[itemID] = (mail[itemID] or 0) + (count or 1) end
        end
    end
    self.char.mail = mail
end

---------------------------------------------------------------------------
-- Skenovanie profesii (spusti sa pri otvoreni okna profesie)
---------------------------------------------------------------------------
function PC:ScanProfession()
    local T = C_TradeSkillUI
    if not T or not T.GetAllRecipeIDs then return end
    if T.IsTradeSkillReady and not T.IsTradeSkillReady() then return end
    if T.IsTradeSkillLinked and T.IsTradeSkillLinked() then return end
    if T.IsTradeSkillGuild and T.IsTradeSkillGuild() then return end
    if T.IsNPCCrafting and T.IsNPCCrafting() then return end

    local info = T.GetBaseProfessionInfo and T.GetBaseProfessionInfo()
    local prof = info and info.professionName
    if not prof or prof == "" then return end

    local recipes, n = {}, 0
    for _, rid in ipairs(T.GetAllRecipeIDs() or {}) do
        local ri = T.GetRecipeInfo(rid)
        if ri and ri.learned then
            local s = T.GetRecipeSchematic(rid, false)
            if s and s.outputItemID then
                local reagents = {}
                for _, slot in ipairs(s.reagentSlotSchematics or {}) do
                    if slot.reagentType == BASIC and slot.reagents and slot.reagents[1]
                        and slot.reagents[1].itemID then
                        reagents[#reagents + 1] = { id = slot.reagents[1].itemID, qty = slot.quantityRequired or 1 }
                    end
                end
                recipes[rid] = {
                    name = ri.name,
                    out = s.outputItemID,
                    qmin = s.quantityMin or 1,
                    qmax = s.quantityMax or s.quantityMin or 1,
                    reagents = reagents,
                }
                n = n + 1
            end
        end
    end

    if n > 0 then
        local old = self.char.profs[prof]
        local oldN = 0
        if old then for _ in pairs(old) do oldN = oldN + 1 end end
        self.char.profs[prof] = recipes
        if oldN ~= n then Print(("%s: ulozenych %d receptov."):format(prof, n)) end
        self:PreloadItems()
        if ns.RefreshUI then ns.RefreshUI() end
    end
end

---------------------------------------------------------------------------
-- Zber nakupnych cien u vendora (thready, vialy, flux...)
---------------------------------------------------------------------------
function PC:ScanMerchant()
    local count = GetMerchantNumItems and GetMerchantNumItems() or 0
    local added = 0
    for i = 1, count do
        local id = GetMerchantItemID and GetMerchantItemID(i)
        local price, stack, extCost
        if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
            local inf = C_MerchantFrame.GetItemInfo(i)
            if inf then price, stack, extCost = inf.price, inf.stackCount, inf.hasExtendedCost end
        elseif GetMerchantItemInfo then
            local _, _, p, q, _, _, _, ext = GetMerchantItemInfo(i)
            price, stack, extCost = p, q, ext
        end
        if id and price and price > 0 and not extCost then
            local unit = math.floor(price / math.max(stack or 1, 1) + 0.5)
            if self.db.vendor[id] ~= unit then added = added + 1 end
            self.db.vendor[id] = unit
        end
    end
    if added > 0 then Print(("Ulozenych %d vendor cien."):format(added)) end
end

---------------------------------------------------------------------------
-- Index receptov: outputItemID -> { {rid, r, prof}, ... }
---------------------------------------------------------------------------
function PC:BuildIndex()
    local idx, seen = {}, {}
    local realm = "-" .. GetRealmName()
    local function add(key, isMe)
        local c = self.db.chars[key]
        for prof, recipes in pairs(c and c.profs or {}) do
            local label = isMe and prof or (prof .. " (" .. (key:match("^[^-]+") or key) .. ")")
            for rid, r in pairs(recipes) do
                if not seen[rid] and r.out then
                    seen[rid] = true
                    idx[r.out] = idx[r.out] or {}
                    table.insert(idx[r.out], { rid = rid, r = r, prof = label })
                end
            end
        end
    end
    add(self.charKey, true)
    if self.db.useAlts then
        for key in pairs(self.db.chars) do
            if key ~= self.charKey and key:sub(-#realm) == realm then add(key, false) end
        end
    end
    return idx
end

function PC:PreloadItems()
    for _, id in ipairs(self:DEMaterialIDs()) do
        if not GetItemInfo(id) then RequestItem(id) end
    end
    for _, c in pairs(self.db.chars) do
        for _, recipes in pairs(c.profs or {}) do
            for _, r in pairs(recipes) do
                if r.out and not GetItemInfo(r.out) then RequestItem(r.out) end
                for _, rg in ipairs(r.reagents or {}) do
                    if not GetItemInfo(rg.id) then RequestItem(rg.id) end
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Vypocet nakladov (rekurzivne cez vlastne crafty)
---------------------------------------------------------------------------
local index, costMemo

local function AvgQty(r) return ((r.qmin or 1) + (r.qmax or r.qmin or 1)) / 2 end

-- naklad na jeden craft receptu; vrati cost|nil, parts, missing(list itemID)
function PC:RecipeCost(rec, visiting)
    local cost, parts, missing = 0, {}, nil
    for _, rg in ipairs(rec.r.reagents) do
        local best = self:BestCost(rg.id, visiting)
        if not best then
            missing = missing or {}
            missing[#missing + 1] = rg.id
        else
            cost = cost + best.unit * rg.qty
            parts[#parts + 1] = {
                id = rg.id, qty = rg.qty, unit = best.unit, from = best.from,
                sub = best.sub, prof = best.prof, subQty = best.subQty, rid = best.rid,
            }
        end
    end
    if #rec.r.reagents == 0 then missing = missing or {} end
    if missing then return nil, parts, missing end
    return cost, parts
end

-- najlacnejsi sposob ziskania 1 kusu itemu: AH / vendor / craft
function PC:BestCost(id, visiting)
    local m = costMemo[id]
    if m ~= nil then return m or nil end

    local best
    local ah = self:AHPrice(id, "buy")
    if ah then best = { unit = ah, from = "AH" } end
    local vb = self:VendorBuy(id)
    if vb and (not best or vb < best.unit) then best = { unit = vb, from = "vendor" } end

    local inCycle = false
    if self.db.chains and index[id] then
        if visiting[id] then
            inCycle = true
        else
            visiting[id] = true
            for _, rec in ipairs(index[id]) do
                local c, parts = self:RecipeCost(rec, visiting)
                if c then
                    local q = AvgQty(rec.r)
                    local unit = c / q
                    if not best or unit < best.unit then
                        best = { unit = unit, from = "craft", sub = parts, prof = rec.prof, subQty = q, rid = rec.rid }
                    end
                end
            end
            visiting[id] = nil
        end
    end

    -- vysledok pocitany pocas cyklu neukladame, mohol by byt neuplny
    if not inCycle then costMemo[id] = best or false end
    return best
end

-- vrati zoznam vysledkov a pocet receptov bez ceny
function PC:Evaluate()
    priceCache, costMemo = {}, {}
    index = self:BuildIndex()
    self.pending = false
    local results, incomplete = {}, 0
    local cut = 1 - (self.db.ahCut or 5) / 100

    for outId, recs in pairs(index) do
        for _, rec in ipairs(recs) do
            local cost, parts, missing = self:RecipeCost(rec, { [outId] = true })
            if not cost then
                incomplete = incomplete + 1
            else
                local r = rec.r
                local qty = AvgQty(r)
                local ahUnit = self:AHPrice(outId, "sell")
                local venUnit = self:VendorSell(outId)
                local chain = false
                for _, p in ipairs(parts) do if p.from == "craft" then chain = true end end
                local e = {
                    prof = rec.prof, rid = rec.rid, name = r.name, out = outId, qty = qty,
                    cost = cost, parts = parts, ahUnit = ahUnit, venUnit = venUnit, chain = chain,
                }
                if ahUnit then e.profitAH = math.floor(ahUnit * qty * cut - cost) end
                if venUnit and venUnit > 0 then e.profitVendor = math.floor(venUnit * qty - cost) end
                local deUnit, deOuts = self:DisenchantValue(outId)
                e.deUnit, e.deOuts = deUnit, deOuts or nil
                if deUnit then e.profitDE = math.floor(deUnit * qty - cost) end
                results[#results + 1] = e
            end
        end
    end
    priceCache, costMemo = nil, nil
    return results, incomplete
end

function PC:Top(mode, limit)
    mode = mode or self.db.mode
    local key = (mode == "vendor" and "profitVendor") or (mode == "de" and "profitDE") or "profitAH"
    local all, incomplete = self:Evaluate()
    local list = {}
    for _, e in ipairs(all) do
        if e[key] and e[key] >= (self.db.minProfit or 0) then
            e.profit = e[key]
            list[#list + 1] = e
        end
    end
    table.sort(list, function(a, b) return a.profit > b.profit end)
    if limit and #list > limit then
        for i = #list, limit + 1, -1 do list[i] = nil end
    end
    return list, incomplete
end

---------------------------------------------------------------------------
-- /pc why <item> - preco craft nie je v zozname
---------------------------------------------------------------------------
local function PrintParts(parts, indent, mult)
    for _, p in ipairs(parts) do
        local src = p.from == "craft" and ("craft: " .. (p.prof or "?")) or p.from
        print(("%s%sx %s  %s/ks  |cff888888(%s)|r"):format(indent, (p.qty * mult) % 1 == 0 and (p.qty * mult) or
            ("%.1f"):format(p.qty * mult), ItemLabel(p.id), ns.Money(p.unit), src))
        if p.sub then PrintParts(p.sub, indent .. "    ", p.qty * mult / (p.subQty or 1)) end
    end
end
ns.PrintParts = PrintParts

function PC:Why(query)
    local qid = tonumber(query) or tonumber((query or ""):match("item:(%d+)"))
    local q = (query or ""):lower():gsub("|c%x+|h", ""):gsub("|h|r", ""):gsub("[%[%]]", "")
    priceCache, costMemo = {}, {}
    index = self:BuildIndex()
    local found = 0
    for outId, recs in pairs(index) do
        local name = (GetItemInfo(outId) or recs[1].r.name or ""):lower()
        if (qid and outId == qid) or (not qid and q ~= "" and name:find(q, 1, true)) then
            for _, rec in ipairs(recs) do
                found = found + 1
                if found > 5 then break end
                local r = rec.r
                Print(("%s  |cff888888[%s]|r"):format(ItemLabel(outId, r.name), rec.prof))
                local cost, parts, missing = self:RecipeCost(rec, { [outId] = true })
                PrintParts(parts, "   ", 1)
                if missing then
                    for _, id in ipairs(missing) do
                        print("   |cffff4040CHYBA CENA:|r " .. ItemLabel(id) ..
                            " - ziadna cena z AH ani od vendora (naskenuj AH alebo navstiv vendora)")
                    end
                end
                local qty = AvgQty(r)
                local ahUnit, venUnit = self:AHPrice(outId, "sell"), self:VendorSell(outId)
                local deUnit, deOuts = self:DisenchantValue(outId)
                print(("   Naklad: %s | AH: %s/ks | vendor: %s/ks | DE: %s/ks | ks z craftu: %.1f"):format(
                    ns.Money(cost), ns.Money(ahUnit), ns.Money(venUnit),
                    deOuts == false and "|cff888888neda sa rozlozit|r" or ns.Money(deUnit), qty))
                for _, o in ipairs(deOuts or {}) do
                    print(("      DE: %.0f%% x %.1f %s  %s/ks"):format(o.chance * 100, o.avg, ItemLabel(o.id), ns.Money(o.unit)))
                end
                if cost then
                    local cut = 1 - (self.db.ahCut or 5) / 100
                    local pa = ahUnit and math.floor(ahUnit * qty * cut - cost)
                    local pv = venUnit and venUnit > 0 and math.floor(venUnit * qty - cost)
                    local pd = deUnit and math.floor(deUnit * qty - cost)
                    print(("   Zisk AH: %s | Zisk vendor: %s | Zisk DE: %s | min. zisk filter: %s"):format(
                        ns.Money(pa), pv and ns.Money(pv) or "|cff888888nepredajne|r",
                        pd and ns.Money(pd) or "|cff888888-|r", ns.Money(self.db.minProfit)))
                    if not venUnit then print("   |cffffff00Item este nie je nacitany, skus o chvilu znova.|r") end
                end
            end
        end
    end
    priceCache, costMemo = nil, nil
    if found == 0 then
        Print("Ziadny naucany recept nevyraba '" .. (query or "") ..
            "'. Otvoril si okno tej profesie? (/pc status ukaze ulozene profesie)")
    end
end

---------------------------------------------------------------------------
-- Slash prikazy
---------------------------------------------------------------------------
ns.MODE_LABEL = { ah = "craft -> AH", vendor = "AH -> craft -> vendor", de = "craft -> disenchant" }

local function PrintTop(mode, n)
    local list = PC:Top(mode, n)
    if #list == 0 then
        Print("Nic vyhodne. (Otvor okno profesie, aby sa ulozili recepty, a skontroluj, ci mas ceny z AH addonu.)")
        return
    end
    Print(("Top %d - %s:"):format(#list, ns.MODE_LABEL[mode] or ns.MODE_LABEL.ah))
    for i, e in ipairs(list) do
        print(("%2d. %s%s  zisk %s  (naklad %s)"):format(i, ItemLabel(e.out, e.name),
            e.chain and " |cff66ccff[retazec]|r" or "", ns.Money(e.profit), ns.Money(e.cost)))
    end
end

local function OnOff(arg, cur)
    if arg == "on" then return true elseif arg == "off" then return false end
    return not cur
end

SLASH_PROFITCRAFT1, SLASH_PROFITCRAFT2 = "/pc", "/profitcraft"
SlashCmdList.PROFITCRAFT = function(msg)
    local cmd, arg = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = cmd:lower()
    local db = PC.db
    local function R() if ns.RefreshUI then ns.RefreshUI() end end
    if cmd == "" then
        if ns.ToggleUI then ns.ToggleUI() end
    elseif cmd == "top" then
        PrintTop(db.mode, tonumber(arg) or 10)
    elseif cmd == "vendor" then
        PrintTop("vendor", tonumber(arg) or 10)
    elseif cmd == "stock" or cmd == "zasoby" then
        db.useStock = OnOff(arg, db.useStock ~= false); Print("Plan pocita so zasobami: " .. (db.useStock and "ano" or "nie")); R()
    elseif cmd == "altstock" then
        db.useAltStock = OnOff(arg, db.useAltStock); Print("Zasoby altov (TSM): " .. (db.useAltStock and "ano" or "nie")); R()
    elseif cmd == "minimap" or cmd == "ikona" then
        if ns.ToggleMinimap then ns.ToggleMinimap(arg) end
    elseif cmd == "timer" or cmd == "ct" then
        if ns.TimerCmd then ns.TimerCmd(arg) end
    elseif cmd == "de" or cmd == "disenchant" then
        PrintTop("de", tonumber(arg) or 10)
    elseif cmd == "why" or cmd == "preco" then
        PC:Why(arg)
    elseif cmd == "mode" and (arg == "ah" or arg == "vendor" or arg == "de") then
        db.mode = arg; Print("Rezim: " .. arg); R()
    elseif cmd == "chains" or cmd == "retazce" then
        db.chains = OnOff(arg, db.chains); Print("Retazce: " .. (db.chains and "zapnute" or "vypnute")); R()
    elseif cmd == "alts" then
        db.useAlts = OnOff(arg, db.useAlts); Print("Recepty altov: " .. (db.useAlts and "zapnute" or "vypnute")); R()
    elseif cmd == "source" and (arg == "auto" or sources[arg]) then
        db.source = arg; Print("Zdroj cien: " .. arg); R()
    elseif cmd == "tsmbuy" and arg ~= "" then
        db.tsmBuy = arg; Print("TSM nakup: " .. arg); R()
    elseif cmd == "tsmsell" and arg ~= "" then
        db.tsmSell = arg; Print("TSM predaj: " .. arg); R()
    elseif cmd == "cut" and tonumber(arg) then
        db.ahCut = tonumber(arg); Print("AH poplatok: " .. db.ahCut .. "%"); R()
    elseif cmd == "min" and tonumber(arg) then
        db.minProfit = math.floor(tonumber(arg) * 10000); Print("Min. zisk: " .. ns.Money(db.minProfit)); R()
    elseif cmd == "reset" then
        PC.char.profs = {}; Print("Recepty tejto postavy vymazane. Otvor znova okna profesii.")
    elseif cmd == "status" then
        Print("Zdroje cien: " .. PC:ActiveSourceNames() .. " | zvoleny: " .. db.source)
        print(("  TSM nakup: %s | TSM predaj: %s | retazce: %s | alty: %s"):format(
            db.tsmBuy, db.tsmSell, db.chains and "on" or "off", db.useAlts and "on" or "off"))
        for prof, rec in pairs(PC.char.profs) do
            local n = 0; for _ in pairs(rec) do n = n + 1 end
            print(("  %s: %d receptov"):format(prof, n))
        end
    else
        Print("Prikazy:")
        print("  /pc - okno | /pc top [n] | /pc vendor [n] | /pc de [n]")
        print("  /pc why <nazov itemu alebo shift-klik link> - preco craft nie je v zozname")
        print("  /pc mode ah|vendor|de | /pc chains on|off | /pc alts on|off")
        print("  /pc source auto|tsm|auctioneer|auctionator")
        print("  /pc tsmbuy <price string> | /pc tsmsell <price string>")
        print("  /pc cut <percent> | /pc min <goldy> | /pc status | /pc reset")
        print("  /pc timer test|lock|unlock|reset  (alebo /ct ...)")
        print("  /pc minimap [on|off] - ikona pri minimape")
        print("  /pc zasoby on|off | /pc altstock on|off - plan s vlastnymi zasobami")
    end
end

---------------------------------------------------------------------------
-- Eventy
---------------------------------------------------------------------------
local scanQueued, refreshQueued = false, false
local function QueueScan()
    if scanQueued then return end
    scanQueued = true
    C_Timer.After(0.5, function() scanQueued = false; PC:ScanProfession() end)
end

PC:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        ProfitCraftDB = ProfitCraftDB or {}
        ProfitCraftDB.tsmPrice = nil -- stare nastavenie z v0.1
        for k, v in pairs(defaults) do
            if ProfitCraftDB[k] == nil then
                ProfitCraftDB[k] = type(v) == "table" and {} or v
            end
        end
        self.db = ProfitCraftDB
        self.charKey = UnitName("player") .. "-" .. GetRealmName()
        self.db.chars[self.charKey] = self.db.chars[self.charKey] or { profs = {} }
        self.char = self.db.chars[self.charKey]
    elseif event == "PLAYER_LOGIN" then
        C_Timer.After(3, function() PC:PreloadItems() end)
    elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_LIST_UPDATE"
        or event == "TRADE_SKILL_DATA_SOURCE_CHANGED" then
        QueueScan()
    elseif event == "MAIL_INBOX_UPDATE" then
        PC:ScanMail()
    elseif event == "MERCHANT_SHOW" then
        C_Timer.After(0.3, function() PC:ScanMerchant() end)
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        if self.pending and not refreshQueued and ns.IsUIShown and ns.IsUIShown() then
            refreshQueued = true
            C_Timer.After(1, function() refreshQueued = false; ns.RefreshUI() end)
        end
    end
end)

for _, e in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE",
    "TRADE_SKILL_DATA_SOURCE_CHANGED", "MERCHANT_SHOW", "GET_ITEM_INFO_RECEIVED", "MAIL_INBOX_UPDATE" }) do
    pcall(PC.RegisterEvent, PC, e)
end
