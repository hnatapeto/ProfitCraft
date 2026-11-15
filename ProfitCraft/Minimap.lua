-- ProfitCraft - ikona pri minimape
-- Lavy klik: okno ProfitCraft | Pravy klik: prepnut rezim AH / vendor | Tahanie: posun okolo minimapy

local ADDON, ns = ...
local PC = ns.PC
local btn

local function MDB()
    PC.db.minimap = PC.db.minimap or {}
    return PC.db.minimap
end

local function UpdatePosition()
    if not btn then return end
    local angle = math.rad(MDB().angle or 225)
    local r = (Minimap:GetWidth() / 2) + 5
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

local function OnDragUpdate()
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    px, py = px / scale, py / scale
    MDB().angle = math.deg(math.atan2(py - my, px - mx))
    UpdatePosition()
end

local MODE_NAME = { ah = "Craft -> predaj na AH", vendor = "AH -> craft -> vendor", de = "Craft -> disenchant" }
local NEXT_MODE = { ah = "vendor", vendor = "de", de = "ah" }

local function ShowTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("ProfitCraft")
    GameTooltip:AddLine("Rezim: " .. (MODE_NAME[PC.db.mode] or MODE_NAME.ah), 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Lavy klik: otvorit / zavriet", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Pravy klik: prepnut rezim AH / vendor / disenchant", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Tahanie: posunut ikonu", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

local function ToggleMode()
    PC.db.mode = NEXT_MODE[PC.db.mode] or "ah"
    ns.Print("Rezim: " .. MODE_NAME[PC.db.mode])
    if ns.RefreshUI then ns.RefreshUI() end
end

local function Create()
    btn = CreateFrame("Button", "ProfitCraftMinimapButton", Minimap)
    btn:SetSize(31, 31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetSize(20, 20)
    bg:SetPoint("TOPLEFT", 7, -5)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
    icon:SetSize(17, 17)
    icon:SetPoint("TOPLEFT", 7, -6)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")

    btn:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            ToggleMode()
            ShowTooltip(self)
        elseif ns.ToggleUI then
            ns.ToggleUI()
        end
    end)
    btn:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", OnDragUpdate)
        GameTooltip:Hide()
    end)
    btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    btn:SetScript("OnEnter", ShowTooltip)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    UpdatePosition()
    if MDB().hide then btn:Hide() else btn:Show() end
end

function ns.ToggleMinimap(arg)
    local db = MDB()
    if arg == "on" then db.hide = false
    elseif arg == "off" then db.hide = true
    else db.hide = not db.hide end
    if not btn then Create() end
    if db.hide then btn:Hide() else btn:Show() end
    ns.Print("Ikona pri minimape: " .. (db.hide and "skryta" or "zobrazena"))
end

-- addon menu vedla minimapy (moderny klient)
function ProfitCraft_OnAddonCompartmentClick(addonName, button)
    if button == "RightButton" then ToggleMode()
    elseif ns.ToggleUI then ns.ToggleUI() end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
    if PC.db then Create() end
end)
