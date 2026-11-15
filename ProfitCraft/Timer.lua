-- ProfitCraft - Timer (povodne samostatny addon CraftTimer)
-- Spocita, ako dlho bude trvat cely craft, odpocitava to a ukazuje odhadovany zisk.
-- Zaroven si pamata dlzku craftu kazdeho receptu (pre cas a zisk/hod v plane).

local ADDON, ns = ...
local PC = ns.PC

-- ak je stale zapnuty stary samostatny CraftTimer, tento modul sa nespusti
local IsLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
local function OldCraftTimerLoaded() return IsLoaded and IsLoaded("CraftTimer") end

local f = CreateFrame("Frame", "ProfitCraftTimerFrame", UIParent, "BackdropTemplate")

-- stav
local pending, pendingRecipe, pendingAt = nil, nil, 0
local active = false
local total, remaining = 0, 0
local castDur = 0
local endEstimate = 0
local itemName = ""
local recipeID = nil
local profitEach = nil      -- zisk za 1 craft (podla aktualneho rezimu)
local startedAt = 0
local disabled = false

local function TDB() return PC.db and PC.db.timer or {} end

------------------------------------------------------------
-- UI
------------------------------------------------------------
f:SetSize(290, 62)
f:SetFrameStrata("MEDIUM")
f:SetClampedToScreen(true)
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", function(self) if not TDB().locked then self:StartMoving() end end)
f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    TDB().point = { p, rp, x, y }
end)
if f.SetBackdrop then
    f:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(0, 0, 0, 0.75)
end

local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOPLEFT", 8, -7)
title:SetPoint("TOPRIGHT", -8, -7)
title:SetJustifyH("LEFT")
title:SetWordWrap(false)

local timeText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
timeText:SetPoint("TOPLEFT", 8, -24)

local countText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
countText:SetPoint("TOPRIGHT", -8, -27)

local profitText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
profitText:SetPoint("BOTTOMLEFT", 8, 7)
profitText:SetPoint("BOTTOMRIGHT", -8, 7)
profitText:SetJustifyH("LEFT")

f:Hide()

local function fmt(sec)
    if sec < 0 then sec = 0 end
    sec = math.floor(sec + 0.5)
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    local s = sec % 60
    if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
    return string.format("%02d:%02d", m, s)
end
ns.FormatTime = fmt

local function refresh()
    title:SetText(itemName ~= "" and itemName or "Craft")
    timeText:SetText("Zostava: " .. fmt(endEstimate - GetTime()))
    countText:SetText(string.format("%d / %d", total - remaining, total))
    if profitEach then
        local perHour = castDur > 0 and (profitEach / castDur * 3600) or nil
        profitText:SetText(("Zisk: %s  |  %s/hod"):format(ns.Money(profitEach * total), ns.Money(perHour)))
    else
        profitText:SetText("|cff888888Zisk: recept nie je v ProfitCraft|r")
    end
end

local acc = 0
f:SetScript("OnUpdate", function(self, el)
    acc = acc + el
    if acc < 0.2 then return end
    acc = 0
    if active then refresh() end
end)

local function Say(msg) print("|cff33ff99ProfitCraft Timer:|r " .. msg) end

local function stop(msg)
    if active and msg then Say(msg) end
    active = false
    pending, pendingRecipe = nil, nil
    f:Hide()
end

-- zisk za jeden craft daneho receptu podla ProfitCraft
local function LookupProfit(rid)
    if not rid or not PC.db then return nil end
    local ok, all = pcall(PC.Evaluate, PC)
    if not ok or not all then return nil end
    for _, e in ipairs(all) do
        if e.rid == rid then
            local p
            if PC.db.mode == "vendor" then p = e.profitVendor or e.profitAH
            elseif PC.db.mode == "de" then p = e.profitDE or e.profitAH
            else p = e.profitAH or e.profitVendor end
            return p
        end
    end
end

------------------------------------------------------------
-- Zachytenie poctu kusov (tlacidla Create / Create All)
------------------------------------------------------------
local function onCraftRequest(count, rid)
    if disabled then return end
    count = tonumber(count) or 1
    if count < 1 then count = 1 end
    pending = count
    pendingRecipe = rid
    pendingAt = GetTime()
end

if C_TradeSkillUI and C_TradeSkillUI.CraftRecipe then
    hooksecurefunc(C_TradeSkillUI, "CraftRecipe", function(rid, count) onCraftRequest(count, rid) end)
end
if DoTradeSkill then
    hooksecurefunc("DoTradeSkill", function(index, count) onCraftRequest(count) end)
end
if StopTradeSkillRepeat then
    hooksecurefunc("StopTradeSkillRepeat", function() if not disabled then stop("craft zruseny.") end end)
end

------------------------------------------------------------
-- Eventy kuzla
------------------------------------------------------------
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("UNIT_SPELLCAST_START")
f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
f:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")

f:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_LOGIN" then
        if OldCraftTimerLoaded() then
            disabled = true
            Say("je zapnuty aj stary addon CraftTimer - casovac v ProfitCraft je vypnuty. " ..
                "Vypni CraftTimer v zozname addonov a daj /reload.")
            return
        end
        local pt = TDB().point
        f:ClearAllPoints()
        if pt then f:SetPoint(pt[1], UIParent, pt[2], pt[3], pt[4])
        else f:SetPoint("CENTER", UIParent, "CENTER", 0, 200) end
        return
    end

    if disabled or arg1 ~= "player" then return end

    if event == "UNIT_SPELLCAST_START" then
        local name, _, _, startMS, endMS, isTradeSkill = UnitCastingInfo("player")
        if not name or not startMS then return end

        local fresh = pending and (GetTime() - pendingAt) < 3
        if fresh and (isTradeSkill or isTradeSkill == nil) then
            active = true
            total, remaining = pending, pending
            itemName = name
            recipeID = pendingRecipe
            profitEach = LookupProfit(recipeID)
            startedAt = GetTime()
            pending, pendingRecipe = nil, nil
        elseif not active then
            return
        end

        castDur = (endMS - startMS) / 1000
        if recipeID and castDur > 0 and PC.db then
            PC.db.castTime[recipeID] = castDur
        end
        endEstimate = endMS / 1000 + (remaining - 1) * castDur
        refresh()
        f:Show()

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if not active then return end
        remaining = remaining - 1
        if remaining <= 0 then
            local extra = profitEach and (" Odhadovany zisk: " .. ns.Money(profitEach * total) .. ".") or ""
            stop(("hotovo! Vyrobenych %dx %s za %s.%s"):format(total, itemName, fmt(GetTime() - startedAt), extra))
        else
            endEstimate = GetTime() + remaining * castDur
            refresh()
        end

    elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
        if active then
            stop(string.format("prerusene. Vyrobene %d / %d.", total - remaining, total))
        end
    end
end)

------------------------------------------------------------
-- /ct lock | unlock | test | reset   (aj /pc timer ...)
------------------------------------------------------------
local function TimerCmd(msg)
    msg = (msg or ""):lower()
    if disabled then
        Say("vypnuty, lebo je zapnuty stary CraftTimer. Vypni ho a daj /reload.")
        return
    end
    if msg == "lock" then
        TDB().locked = true; Say("okno zamknute.")
    elseif msg == "unlock" then
        TDB().locked = false; Say("okno odomknute, mozes ho tahat mysou.")
    elseif msg == "test" then
        active, total, remaining, castDur, itemName = true, 10, 10, 3, "Test craft"
        profitEach, startedAt = 1234, GetTime()
        endEstimate = GetTime() + 30
        refresh(); f:Show()
        C_Timer.After(10, function() if itemName == "Test craft" then stop() end end)
    elseif msg == "reset" then
        TDB().point = nil
        f:ClearAllPoints()
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
        Say("pozicia resetnuta.")
    else
        Say("/ct test | lock | unlock | reset")
    end
end
ns.TimerCmd = TimerCmd

-- /ct registrujeme len ak ho uz nema stary CraftTimer
if not SlashCmdList.CRAFTTIMER then
    SLASH_CRAFTTIMER1, SLASH_CRAFTTIMER2 = "/ct", "/crafttimer"
    SlashCmdList.CRAFTTIMER = TimerCmd
end
