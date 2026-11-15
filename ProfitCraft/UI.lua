-- ProfitCraft - UI
local ADDON, ns = ...
local PC = ns.PC
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local GetIcon = (C_Item and C_Item.GetItemIconByID) or GetItemIcon

local ROW_H, NUM_LIMIT = 22, 200
local f, scroll, content, statusText, modeBtns
local rows = {}

local function CreateMain()
    f = CreateFrame("Frame", "ProfitCraftFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(680, 460)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("HIGH")
    f:Hide()
    tinsert(UISpecialFrames, "ProfitCraftFrame")

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.title:SetPoint("TOP", 0, -5)
    f.title:SetText("ProfitCraft")

    modeBtns = {}
    local function MakeBtn(label, mode, x)
        local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        b:SetSize(168, 22)
        b:SetPoint("TOPLEFT", x, -30)
        b:SetText(label)
        b:SetScript("OnClick", function() PC.db.mode = mode; ns.RefreshUI() end)
        modeBtns[mode] = b
    end
    MakeBtn("Craft -> predaj na AH", "ah", 12)
    MakeBtn("AH -> craft -> vendor", "vendor", 184)
    MakeBtn("Craft -> disenchant", "de", 356)

    local refresh = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    refresh:SetSize(90, 22)
    refresh:SetPoint("TOPRIGHT", -12, -30)
    refresh:SetText("Obnovit")
    refresh:SetScript("OnClick", function() ns.RefreshUI() end)

    -- hlavicka
    local hdr = CreateFrame("Frame", nil, f)
    hdr:SetPoint("TOPLEFT", 14, -58)
    hdr:SetPoint("TOPRIGHT", -34, -58)
    hdr:SetHeight(16)
    local function H(text, x, w, j)
        local fs = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("LEFT", x, 0); fs:SetWidth(w); fs:SetJustifyH(j or "LEFT"); fs:SetText(text)
    end
    H("Item", 24, 200)
    H("Profesia", 228, 150)
    H("Naklad", 380, 80, "RIGHT")
    H("Predaj", 462, 80, "RIGHT")
    H("Zisk", 544, 86, "RIGHT")

    scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -76)
    scroll:SetPoint("BOTTOMRIGHT", -32, 32)
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(630, 1)
    scroll:SetScrollChild(content)

    statusText = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    statusText:SetPoint("BOTTOMLEFT", 14, 12)
    statusText:SetPoint("BOTTOMRIGHT", -14, 12)
    statusText:SetJustifyH("LEFT")
end

local function RowTooltip(row)
    local e = row.entry
    if not e then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(e.out)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("ProfitCraft - suroviny:", 0.2, 1, 0.6)
    local function AddParts(parts, indent, mult)
        for _, p in ipairs(parts) do
            local name = GetItemInfo(p.id) or ("item:" .. p.id)
            local q = p.qty * mult
            local qs = q % 1 == 0 and tostring(q) or ("%.1f"):format(q)
            local src = p.from == "craft" and ("|cff66ccffcraft: " .. (p.prof or "?") .. "|r") or p.from
            GameTooltip:AddDoubleLine(("%s%sx %s |cff888888(%s)|r"):format(indent, qs, name, src),
                ns.Money(p.unit * q), 1, 1, 1, 1, 1, 1)
            if p.sub then AddParts(p.sub, indent .. "    ", q / (p.subQty or 1)) end
        end
    end
    AddParts(e.parts, "", 1)
    GameTooltip:AddDoubleLine("Naklad spolu", ns.Money(e.cost), 1, 0.82, 0, 1, 1, 1)
    if e.qty ~= 1 then GameTooltip:AddLine(("Priemerne %.1f ks z craftu"):format(e.qty), 0.7, 0.7, 0.7) end
    GameTooltip:AddDoubleLine("Cena AH (kus)", ns.Money(e.ahUnit), 1, 0.82, 0, 1, 1, 1)
    GameTooltip:AddDoubleLine("Cena vendor (kus)", ns.Money(e.venUnit), 1, 0.82, 0, 1, 1, 1)
    GameTooltip:AddDoubleLine("Zisk AH (po " .. PC.db.ahCut .. "% poplatku)", ns.Money(e.profitAH), 1, 0.82, 0, 1, 1, 1)
    GameTooltip:AddDoubleLine("Zisk vendor", ns.Money(e.profitVendor), 1, 0.82, 0, 1, 1, 1)
    if e.deOuts then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Disenchant (ocakavane z 1 ks):", 0.2, 1, 0.6)
        for _, o in ipairs(e.deOuts) do
            local name = GetItemInfo(o.id) or ("item:" .. o.id)
            GameTooltip:AddDoubleLine(("%.0f%%  %.1fx %s"):format(o.chance * 100, o.avg, name),
                ns.Money(o.unit), 1, 1, 1, 1, 1, 1)
        end
        GameTooltip:AddDoubleLine("Hodnota DE (kus, po poplatku)", ns.Money(e.deUnit), 1, 0.82, 0, 1, 1, 1)
        GameTooltip:AddDoubleLine("Zisk DE", ns.Money(e.profitDE), 1, 0.82, 0, 1, 1, 1)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Klik: plan - co kupit a co vyrobit", 0.6, 0.6, 0.6)
    GameTooltip:AddLine("Shift+klik: vlozit link do chatu", 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

---------------------------------------------------------------------------
-- Plan: nakupny zoznam + poradie craftov
---------------------------------------------------------------------------
local plan, planEntry, planCount = nil, nil, 1
local lastShop = {}

-- rozpis surovin; ak je stock (tabulka itemID -> volne kusy), najprv sa beru vlastne zasoby
-- na kazdom stupni retazca a craftuje/kupuje sa len zvysok
local function Collect(parts, mult, depth, buy, craft, stock, used)
    for _, p in ipairs(parts) do
        local q = p.qty * mult
        if stock then
            local have = stock[p.id]
            if have == nil then have = PC:Owned(p.id); stock[p.id] = have end
            local take = math.min(have, q)
            if take > 0 then
                stock[p.id] = have - take
                used[p.id] = (used[p.id] or 0) + take
                q = q - take
            end
        end
        if q > 0.0001 then
            if p.from == "craft" and p.sub then
                local c = q / (p.subQty or 1)
                local k = craft[p.id]
                if not k then k = { n = 0, depth = 0, prof = p.prof, subQty = p.subQty or 1, rid = p.rid }; craft[p.id] = k end
                k.n = k.n + c
                if depth > k.depth then k.depth = depth end
                Collect(p.sub, c, depth + 1, buy, craft, stock, used)
            else
                local b = buy[p.id]
                if not b then b = { n = 0, unit = p.unit, from = p.from }; buy[p.id] = b end
                b.n = b.n + q
            end
        end
    end
end

local function Name(id)
    local _, link = GetItemInfo(id)
    return link or ("item:" .. id)
end

local function BuildPlanText(e, count)
    local mode = PC.db.mode
    local buy, craft, used = {}, {}, {}
    local useStock = PC.db.useStock ~= false
    Collect(e.parts, count, 1, buy, craft, useStock and {} or nil, used)
    local L = {}
    local function add(s) L[#L + 1] = s end

    add(("|cffffd100%dx craft:|r %s"):format(count, Name(e.out)))
    add(("|cff888888%s, vyrobis cca %s ks|r"):format(e.prof, math.floor(e.qty * count + 0.5)))
    if not useStock then add("|cff888888Zasoby sa nerataju (vypnute).|r") end
    add(" ")

    -- vlastne zasoby
    local ulist = {}
    for id, n in pairs(used) do ulist[#ulist + 1] = { id = id, n = n } end
    if #ulist > 0 then
        table.sort(ulist, function(a, b) return a.id < b.id end)
        add("|cff33ff990) POUZIJES ZO ZASOB|r |cff888888(tasky, banka, posta)|r")
        local saved = 0
        for _, x in ipairs(ulist) do
            local n = math.floor(x.n + 0.5)
            local best = PC:CostOf(x.id)
            if best then saved = saved + best * x.n end
            add(("   %dx %s  |cff888888(mas %d)|r"):format(n, Name(x.id), PC:Owned(x.id)))
        end
        if saved > 0 then add(("   |cff888888Hodnota pouzitych zasob: %s|r"):format(ns.Money(saved))) end
        add(" ")
    end

    -- nakup
    add("|cff33ff991) KUPIT|r")
    local blist = {}
    for id, b in pairs(buy) do blist[#blist + 1] = { id = id, b = b } end
    table.sort(blist, function(a, b) return a.b.from == b.b.from and a.id < b.id or a.b.from < b.b.from end)
    local total = 0
    local shop = {}
    for _, x in ipairs(blist) do
        local n = math.ceil(x.b.n - 0.001)
        if n > 0 then
            total = total + n * x.b.unit
            local where = x.b.from == "vendor" and "|cffffff00vendor|r" or "|cff66ccffAH|r"
            add(("   %dx %s  %s/ks = %s  (%s)"):format(n, Name(x.id), ns.Money(x.b.unit), ns.Money(n * x.b.unit), where))
            shop[#shop + 1] = { id = x.id, need = n, owned = 0, from = x.b.from }
        end
    end
    if #shop == 0 then add("   |cff33ff99Nic - vsetko mas.|r") end
    lastShop = shop
    add(("   |cffffd100Spolu nakup: %s|r"):format(ns.Money(total)))
    add(" ")

    -- crafty: najhlbsie najprv
    add("|cff33ff992) VYROBIT (v tomto poradi)|r")
    local clist = {}
    for id, c in pairs(craft) do clist[#clist + 1] = { id = id, c = c } end
    table.sort(clist, function(a, b) return a.c.depth > b.c.depth end)
    local step = 0
    for _, x in ipairs(clist) do
        step = step + 1
        local crafts = math.ceil(x.c.n - 0.001)
        local extra = x.c.subQty ~= 1 and (" |cff888888(cca %.1f ks/craft)|r"):format(x.c.subQty) or ""
        add(("   %d. %dx craft %s  |cff888888[%s]|r%s"):format(step, crafts, Name(x.id), x.c.prof or "?", extra))
    end
    step = step + 1
    add(("   %d. %dx craft %s  |cff888888[%s]|r"):format(step, count, Name(e.out), e.prof))
    add(" ")

    -- predaj
    add(mode == "de" and "|cff33ff993) ROZLOZIT a predat suroviny|r" or "|cff33ff993) PREDAT|r")
    local n = math.floor(e.qty * count + 0.5)
    if mode == "de" then
        add(("   %dx %s rozlozit (disenchant), ocakavane:"):format(n, Name(e.out)))
        local mult = e.qty * count
        for _, o in ipairs(e.deOuts or {}) do
            add(("     ~%.1fx %s  po %s"):format(o.qty * mult, Name(o.id), ns.Money(o.unit)))
        end
        add(("   suroviny na AH po %d%% poplatku: %s"):format(PC.db.ahCut, ns.Money(e.deUnit and e.deUnit * mult)))
    elseif mode == "vendor" then
        add(("   %dx %s vendorovi po %s = %s"):format(n, Name(e.out), ns.Money(e.venUnit),
            ns.Money(e.venUnit and e.venUnit * e.qty * count)))
    else
        add(("   %dx %s na AH po %s (min. buyout)"):format(n, Name(e.out), ns.Money(e.ahUnit)))
        add(("   po %d%% poplatku: %s"):format(PC.db.ahCut, ns.Money(e.ahUnit and e.ahUnit * e.qty * count * (1 - PC.db.ahCut / 100))))
    end
    add(" ")
    add(("|cffffd100Odhadovany zisk: %s|r |cff888888(pri trhovych cenach surovin)|r"):format(ns.Money(e.profit and e.profit * count)))

    -- cas craftenia (dlzky craftov zbiera casovac)
    local ct = PC.db.castTime or {}
    local secs, unknown = 0, 0
    for _, x in ipairs(clist) do
        local t = x.c.rid and ct[x.c.rid]
        if t then secs = secs + t * math.ceil(x.c.n - 0.001) else unknown = unknown + 1 end
    end
    if ct[e.rid] then secs = secs + ct[e.rid] * count else unknown = unknown + 1 end
    local fmtT = ns.FormatTime or function(v) return math.floor(v) .. "s" end
    if unknown == 0 and secs > 0 then
        local gph = e.profit and (e.profit * count / secs * 3600)
        add(("|cffffd100Cas craftenia: %s  |  %s/hod|r"):format(fmtT(secs), ns.Money(gph)))
    elseif secs > 0 then
        add(("|cff888888Cas craftenia: aspon %s (%d recept(y) este nemam zmerane)|r"):format(fmtT(secs), unknown))
    else
        add("|cff888888Cas craftenia: zatial nezmerany - vycraftuj to raz a casovac si ho zapamata.|r")
    end
    if not e.chain then
        add(" ")
        add("|cff888888Bez retazca - vsetky suroviny sa oplati kupit.|r")
    end
    return table.concat(L, "\n")
end

local function CreatePlan()
    plan = CreateFrame("Frame", "ProfitCraftPlan", f, "BasicFrameTemplateWithInset")
    plan:SetSize(400, 460)
    plan:SetPoint("TOPLEFT", f, "TOPRIGHT", 2, 0)
    plan.title = plan:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    plan.title:SetPoint("TOP", 0, -5)
    plan.title:SetText("Plan")

    -- pole na pocet craftov + potvrdenie (Enter alebo OK)
    local lbl = plan:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("TOPLEFT", 14, -35)
    lbl:SetText("Pocet craftov:")

    local eb = CreateFrame("EditBox", nil, plan, "InputBoxTemplate")
    eb:SetSize(70, 22)
    eb:SetPoint("LEFT", lbl, "RIGHT", 12, 0)
    eb:SetAutoFocus(false)
    eb:SetNumeric(true)
    eb:SetMaxLetters(5)
    eb:SetText(tostring(planCount))
    plan.countBox = eb

    local function Confirm()
        local n = tonumber(eb:GetText())
        if not n or n < 1 then n = 1 end
        planCount = math.floor(n)
        eb:SetText(tostring(planCount))
        eb:ClearFocus()
        ns.ShowPlan(planEntry)
    end
    eb:SetScript("OnEnterPressed", Confirm)
    eb:SetScript("OnEscapePressed", function(self) self:SetText(tostring(planCount)); self:ClearFocus() end)

    local ok = CreateFrame("Button", nil, plan, "UIPanelButtonTemplate")
    ok:SetSize(60, 22)
    ok:SetPoint("LEFT", eb, "RIGHT", 8, 0)
    ok:SetText("OK")
    ok:SetScript("OnClick", Confirm)

    local tsm = CreateFrame("Button", nil, plan, "UIPanelButtonTemplate")
    tsm:SetSize(120, 22)
    tsm:SetPoint("TOPLEFT", 12, -58)
    tsm:SetText("TSM string")
    tsm:SetScript("OnClick", function() ns.ShowTSMString() end)
    tsm:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("TSM nakupny string")
        GameTooltip:AddLine("Suroviny z AH na tento pocet craftov,", 1, 1, 1)
        GameTooltip:AddLine("bez toho, co uz mas v taskach a banke.", 1, 1, 1)
        GameTooltip:Show()
    end)
    tsm:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local atr = CreateFrame("Button", nil, plan, "UIPanelButtonTemplate")
    atr:SetSize(150, 22)
    atr:SetPoint("LEFT", tsm, "RIGHT", 8, 0)
    atr:SetText("Auctionator zoznam")
    atr:SetScript("OnClick", function() ns.ShowAuctionatorList() end)
    atr:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Auctionator nakupny zoznam")
        GameTooltip:AddLine("Vytvori zoznam priamo v Auctionatore", 1, 1, 1)
        GameTooltip:AddLine("(Shopping) a ukaze aj string na import.", 1, 1, 1)
        GameTooltip:Show()
    end)
    atr:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local cb = CreateFrame("CheckButton", nil, plan, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb:SetPoint("LEFT", atr, "RIGHT", 6, 0)
    cb:SetChecked(PC.db.useStock ~= false)
    cb.label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cb.label:SetPoint("LEFT", cb, "RIGHT", 0, 1)
    cb.label:SetText("Zasoby")
    cb:SetScript("OnClick", function(self)
        PC.db.useStock = self:GetChecked() and true or false
        ns.ShowPlan(planEntry)
    end)
    cb:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Pocitat s mojimi zasobami")
        GameTooltip:AddLine("Najprv sa pouziju itemy z tasiek, banky a posty,", 1, 1, 1)
        GameTooltip:AddLine("craftuje a kupuje sa len zvysok.", 1, 1, 1)
        GameTooltip:AddLine("Alty: /pc altstock on", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    cb:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local sf = CreateFrame("ScrollFrame", nil, plan, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 12, -88)
    sf:SetPoint("BOTTOMRIGHT", -32, 12)
    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(350, 1)
    sf:SetScrollChild(child)
    plan.text = child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    plan.text:SetPoint("TOPLEFT")
    plan.text:SetWidth(350)
    plan.text:SetJustifyH("LEFT")
    plan.text:SetSpacing(2)
    plan.child = child
end

---------------------------------------------------------------------------
-- TSM nakupny string:  i:ID/xPOCET;i:ID/xPOCET
---------------------------------------------------------------------------
local tsmPopup

local function CreateTSMPopup()
    local p = CreateFrame("Frame", "ProfitCraftTSMString", UIParent, "BasicFrameTemplateWithInset")
    p:SetSize(480, 230)
    p:SetPoint("CENTER", 0, 120)
    p:SetFrameStrata("DIALOG")
    p:SetMovable(true)
    p:EnableMouse(true)
    p:RegisterForDrag("LeftButton")
    p:SetScript("OnDragStart", p.StartMoving)
    p:SetScript("OnDragStop", p.StopMovingOrSizing)
    tinsert(UISpecialFrames, "ProfitCraftTSMString")

    p.title = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    p.title:SetPoint("TOP", 0, -5)
    p.title:SetText("Nakupny string")

    p.info = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p.info:SetPoint("TOPLEFT", 14, -32)
    p.info:SetPoint("TOPRIGHT", -14, -32)
    p.info:SetJustifyH("LEFT")

    local sf = CreateFrame("ScrollFrame", nil, p, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 14, -62)
    sf:SetPoint("BOTTOMRIGHT", -34, 40)
    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true)
    eb:SetFontObject(ChatFontNormal)
    eb:SetWidth(420)
    eb:SetAutoFocus(false)
    eb:SetScript("OnEscapePressed", function() p:Hide() end)
    -- len na citanie: kazda zmena sa vrati spat
    eb:SetScript("OnTextChanged", function(self, userInput)
        if userInput then self:SetText(self.orig or ""); self:HighlightText() end
    end)
    eb:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    eb:SetScript("OnMouseUp", function(self) self:HighlightText() end)
    sf:SetScrollChild(eb)
    p.eb = eb

    p.hint = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    p.hint:SetPoint("BOTTOMLEFT", 14, 14)
    p.hint:SetText("Ctrl+C skopiruje  |  Esc zavrie")

    local close = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    close:SetSize(80, 22)
    close:SetPoint("BOTTOMRIGHT", -12, 10)
    close:SetText("Zavriet")
    close:SetScript("OnClick", function() p:Hide() end)

    tsmPopup = p
end

-- suroviny na kupu z AH (odratane zasoby); vrati list {id, n}, skipped, vendorItems
local function ShopList()
    local list, skipped, vendorItems = {}, 0, 0
    for _, x in ipairs(lastShop or {}) do
        if x.from == "vendor" then
            vendorItems = vendorItems + 1
        else
            local n = x.need - (x.owned or 0)
            if n > 0 then list[#list + 1] = { id = x.id, n = n } else skipped = skipped + 1 end
        end
    end
    return list, skipped, vendorItems
end

local function OpenPopup(title, str, info)
    if not tsmPopup then CreateTSMPopup() end
    tsmPopup.title:SetText(title)
    tsmPopup.info:SetText(info)
    tsmPopup.eb.orig = str
    tsmPopup.eb:SetText(str)
    tsmPopup:Show()
    tsmPopup.eb:SetFocus()
    tsmPopup.eb:HighlightText()
end

local function BaseInfo(count, skipped, vendorItems)
    local info = ("Pocet craftov: %d  |  itemov na kupu: %d"):format(planCount, count)
    if skipped > 0 then info = info .. ("  |  uz mas: %d"):format(skipped) end
    if vendorItems > 0 then info = info .. ("\n|cffffff00%d surovin(y) kup u vendora, v zozname nie su.|r"):format(vendorItems) end
    return info
end

-- TSM:  i:ID/xPOCET;i:ID/xPOCET
function ns.ShowTSMString()
    local list, skipped, vendorItems = ShopList()
    local parts = {}
    for _, x in ipairs(list) do parts[#parts + 1] = ("i:%d/x%d"):format(x.id, x.n) end
    local info = BaseInfo(#parts, skipped, vendorItems)
    if #parts == 0 then info = info .. "\n|cff33ff99Vsetko potrebne uz mas - netreba nic kupovat.|r" end
    OpenPopup("TSM nakupny string", table.concat(parts, ";"), info)
end

-- Auctionator:  Nazov zoznamu^"Item";;;;;;;;;;;;;POCET^...
-- (14 poli oddelenych ";" - nazov v uvodzovkach = presne vyhladavanie, posledne pole = mnozstvo)
local function AtrSearchString(name, n)
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    if api and api.ConvertToSearchString then
        local ok, str = pcall(api.ConvertToSearchString, ADDON,
            { searchString = name, isExact = true, categoryKey = "", quantity = n })
        if ok and type(str) == "string" then return str end
    end
    return ('"%s";;;;;;;;;;;;;%d'):format(name, n)
end

function ns.ShowAuctionatorList()
    local list, skipped, vendorItems = ShopList()
    local outName = planEntry and (GetItemInfo(planEntry.out) or planEntry.name) or "craft"
    local listName = ("ProfitCraft - %s x%d"):format(outName, planCount)

    local strings, missing = {}, 0
    for _, x in ipairs(list) do
        local name = GetItemInfo(x.id)
        if name then
            strings[#strings + 1] = AtrSearchString(name, x.n)
        else
            missing = missing + 1
            if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(x.id) end
        end
    end

    local info = BaseInfo(#strings, skipped, vendorItems)
    if missing > 0 then
        info = info .. ("\n|cffff4040%d item(y) este nie su nacitane - klikni znova o chvilu.|r"):format(missing)
    end

    -- priamo vytvorit zoznam v Auctionatore
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    if #strings > 0 and api and api.CreateShoppingList then
        local ok, err = pcall(api.CreateShoppingList, ADDON, listName, strings)
        if ok then
            info = info .. ("\n|cff33ff99Zoznam '%s' je vytvoreny v Auctionatore (Shopping).|r"):format(listName)
        else
            info = info .. "\n|cffff4040Vytvorenie zoznamu zlyhalo - pouzi import stringu.|r"
            ns.Print("Auctionator chyba: " .. tostring(err))
        end
    elseif #strings > 0 then
        info = info .. "\n|cffffff00Auctionator nie je zapnuty - string vloz cez Shopping -> Import.|r"
    else
        info = info .. "\n|cff33ff99Vsetko potrebne uz mas - netreba nic kupovat.|r"
    end

    local str = #strings > 0 and (listName .. "^" .. table.concat(strings, "^")) or ""
    OpenPopup("Auctionator nakupny zoznam", str, info)
end

function ns.ShowPlan(e)
    if not e then return end
    if not plan then CreatePlan() end
    planEntry = e
    if plan.countBox and not plan.countBox:HasFocus() then plan.countBox:SetText(tostring(planCount)) end
    plan.text:SetText(BuildPlanText(e, planCount))
    plan.child:SetHeight(plan.text:GetStringHeight() + 10)
    plan:Show()
end

local function GetRow(i)
    if rows[i] then return rows[i] end
    local r = CreateFrame("Button", nil, content)
    r:SetSize(630, ROW_H)
    r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
    r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    if i % 2 == 0 then
        local bg = r:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(); bg:SetColorTexture(1, 1, 1, 0.04)
    end
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(18, 18); r.icon:SetPoint("LEFT", 2, 0)
    local function FS(x, w, j)
        local fs = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", x, 0); fs:SetWidth(w); fs:SetJustifyH(j or "LEFT"); fs:SetWordWrap(false)
        return fs
    end
    r.name = FS(24, 200)
    r.prof = FS(228, 150)
    r.cost = FS(380, 80, "RIGHT")
    r.sell = FS(462, 80, "RIGHT")
    r.profit = FS(544, 86, "RIGHT")
    r:SetScript("OnEnter", RowTooltip)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:SetScript("OnClick", function(self)
        if IsModifiedClick("CHATLINK") and self.entry then
            local _, link = GetItemInfo(self.entry.out)
            if link then ChatEdit_InsertLink(link) end
        elseif self.entry then
            ns.ShowPlan(self.entry)
        end
    end)
    rows[i] = r
    return r
end

function ns.RefreshUI()
    if not f or not f:IsShown() then return end
    local mode = PC.db.mode
    for m, b in pairs(modeBtns) do
        if m == mode then b:LockHighlight() else b:UnlockHighlight() end
    end

    local list, incomplete = PC:Top(mode, NUM_LIMIT)
    for i, e in ipairs(list) do
        local r = GetRow(i)
        r.entry = e
        local name, _, quality = GetItemInfo(e.out)
        local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
        r.name:SetText((color and color.hex or "|cffffffff") .. (name or e.name or "?") .. "|r")
        r.icon:SetTexture(GetIcon(e.out))
        r.prof:SetText(e.chain and (e.prof .. " |cff66ccff+retazec|r") or e.prof)
        r.cost:SetText(ns.Money(e.cost))
        local unit = (mode == "vendor" and e.venUnit) or (mode == "de" and e.deUnit) or (mode == "ah" and e.ahUnit) or nil
        r.sell:SetText(ns.Money(unit and unit * e.qty))
        r.profit:SetText(ns.Money(e.profit))
        r:Show()
    end
    for i = #list + 1, #rows do rows[i]:Hide(); rows[i].entry = nil end

    -- obnov otvoreny plan s novymi cenami
    if plan and plan:IsShown() and planEntry then
        local found
        for _, e in ipairs(list) do if e.rid == planEntry.rid then found = e end end
        if found then ns.ShowPlan(found) else plan:Hide() end
    end
    content:SetHeight(math.max(1, #list * ROW_H))

    local nProf = 0
    for _ in pairs(PC.char.profs) do nProf = nProf + 1 end
    local msg = ("Zdroje cien: %s  |  Profesie: %d  |  Vyhodnych: %d  |  Bez ceny: %d"):format(
        PC:ActiveSourceNames(), nProf, #list, incomplete)
    if nProf == 0 then msg = "Otvor okno kazdej svojej profesie (napr. K), aby sa nacitali recepty." end
    statusText:SetText(msg)
end

function ns.IsUIShown() return f and f:IsShown() end

function ns.ToggleUI()
    if not f then CreateMain() end
    if f:IsShown() then f:Hide() else f:Show(); ns.RefreshUI() end
end
