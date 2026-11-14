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
        b:SetSize(170, 22)
        b:SetPoint("TOPLEFT", x, -30)
        b:SetText(label)
        b:SetScript("OnClick", function() PC.db.mode = mode; ns.RefreshUI() end)
        modeBtns[mode] = b
    end
    MakeBtn("Craft -> predaj na AH", "ah", 12)
    MakeBtn("AH -> craft -> vendor", "vendor", 186)

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
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Klik: plan - co kupit a co vyrobit", 0.6, 0.6, 0.6)
    GameTooltip:AddLine("Shift+klik: vlozit link do chatu", 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

---------------------------------------------------------------------------
-- Plan: nakupny zoznam + poradie craftov
---------------------------------------------------------------------------
local plan, planEntry, planCount = nil, nil, 1

local function Collect(parts, mult, depth, buy, craft)
    for _, p in ipairs(parts) do
        local q = p.qty * mult
        if p.from == "craft" and p.sub then
            local c = q / (p.subQty or 1)
            local k = craft[p.id]
            if not k then k = { n = 0, depth = 0, prof = p.prof, subQty = p.subQty or 1 }; craft[p.id] = k end
            k.n = k.n + c
            if depth > k.depth then k.depth = depth end
            Collect(p.sub, c, depth + 1, buy, craft)
        else
            local b = buy[p.id]
            if not b then b = { n = 0, unit = p.unit, from = p.from }; buy[p.id] = b end
            b.n = b.n + q
        end
    end
end

local function Name(id)
    local _, link = GetItemInfo(id)
    return link or ("item:" .. id)
end

local function BuildPlanText(e, count)
    local mode = PC.db.mode
    local buy, craft = {}, {}
    Collect(e.parts, count, 1, buy, craft)
    local L = {}
    local function add(s) L[#L + 1] = s end

    add(("|cffffd100%dx craft:|r %s"):format(count, Name(e.out)))
    add(("|cff888888%s, vyrobis cca %s ks|r"):format(e.prof, math.floor(e.qty * count + 0.5)))
    add(" ")

    -- nakup
    add("|cff33ff991) KUPIT|r")
    local blist = {}
    for id, b in pairs(buy) do blist[#blist + 1] = { id = id, b = b } end
    table.sort(blist, function(a, b) return a.b.from == b.b.from and a.id < b.id or a.b.from < b.b.from end)
    local total = 0
    for _, x in ipairs(blist) do
        local n = math.ceil(x.b.n - 0.001)
        total = total + n * x.b.unit
        local where = x.b.from == "vendor" and "|cffffff00vendor|r" or "|cff66ccffAH|r"
        add(("   %dx %s  %s/ks = %s  (%s)"):format(n, Name(x.id), ns.Money(x.b.unit), ns.Money(n * x.b.unit), where))
    end
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
    add("|cff33ff993) PREDAT|r")
    local n = math.floor(e.qty * count + 0.5)
    if mode == "vendor" then
        add(("   %dx %s vendorovi po %s = %s"):format(n, Name(e.out), ns.Money(e.venUnit),
            ns.Money(e.venUnit and e.venUnit * e.qty * count)))
    else
        add(("   %dx %s na AH po %s (min. buyout)"):format(n, Name(e.out), ns.Money(e.ahUnit)))
        add(("   po %d%% poplatku: %s"):format(PC.db.ahCut, ns.Money(e.ahUnit and e.ahUnit * e.qty * count * (1 - PC.db.ahCut / 100))))
    end
    add(" ")
    add(("|cffffd100Odhadovany zisk: %s|r"):format(ns.Money(e.profit and e.profit * count)))
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

    local x = 12
    for _, n in ipairs({ 1, 5, 10, 20 }) do
        local b = CreateFrame("Button", nil, plan, "UIPanelButtonTemplate")
        b:SetSize(50, 22); b:SetPoint("TOPLEFT", x, -30); b:SetText("x" .. n)
        b:SetScript("OnClick", function() planCount = n; ns.ShowPlan(planEntry) end)
        x = x + 54
    end

    local sf = CreateFrame("ScrollFrame", nil, plan, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 12, -60)
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

function ns.ShowPlan(e)
    if not e then return end
    if not plan then CreatePlan() end
    planEntry = e
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
        local unit = mode == "vendor" and e.venUnit or e.ahUnit
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
