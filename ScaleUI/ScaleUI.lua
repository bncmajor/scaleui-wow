------------------------------------------------------------------
-- ScaleUI - resolution-aware UI scale manager
--
-- /sui           open/toggle the control panel
-- /sui <n>       apply a custom scale (0.10-1.50)
-- /sui reset     back to 100%
-- /sui force     re-apply the saved scale
------------------------------------------------------------------

local MIN_SCALE, MAX_SCALE = 0.10, 1.50
local DEFAULT_SCALE = 1.00

-- Saved variables (declared in the TOC; loaded before this file runs).
local db = ScaleUIDB
if not db then
    -- First run: adopt the engine's current scale so nothing jumps visually.
    db = { scale = tonumber(C_CVar.GetCVar("uiScale")) or DEFAULT_SCALE }
    ScaleUIDB = db
    print("ScaleUI loaded - type /sui to configure.")
end

local function ClampScale(value)
    if value < MIN_SCALE then return MIN_SCALE end
    if value > MAX_SCALE then return MAX_SCALE end
    return value
end

-- Apply instantly (UIParent) and persist (CVar). The CVar write is skipped
-- during combat and picked up on the next explicit apply or relogin.
local function ApplyScale(value)
    value = ClampScale(value)
    local deferred = InCombatLockdown()
    if not deferred then
        C_CVar.SetCVar("uiScale", tostring(value))
    end
    UIParent:SetScale(value)
    db.scale = value
    return value, deferred
end

local function ParseScale(text)
    local value = tonumber(text)
    if value and value >= MIN_SCALE and value <= MAX_SCALE then
        return value
    end
    return nil
end

-- A preset is a screen height (px); on the current display it resolves to
-- preset / screenHeight. The 1080 preset on a 2160px-tall (4K) display
-- resolves to exactly 0.50 - that is why 0.5 is the natural 4K value.
local PRESETS = { 720, 768, 1080, 1440 }

local panel -- lazy singleton, built on first /sui

local function RefreshPanel()
    if not panel then return end
    local _, screenHeight = GetPhysicalScreenSize()
    panel.readout:SetText(("Current scale: %.3f"):format(db.scale))
    for index, presetHeight in ipairs(PRESETS) do
        panel.presetButtons[index]:SetText(("%d  %.2f"):format(presetHeight, presetHeight / screenHeight))
    end
    if not panel.editBox:HasFocus() then
        panel.editBox:SetText(("%.2f"):format(db.scale))
    end
end

local function ApplyFromInput()
    local value = ParseScale(panel.editBox:GetText())
    if not value then
        print(("ScaleUI: enter a scale between %.2f and %.2f."):format(MIN_SCALE, MAX_SCALE))
        return
    end
    local applied, deferred = ApplyScale(value)
    if deferred then
        print(("ScaleUI: %.2f applied (in combat - saved CVar write deferred)."):format(applied))
    else
        print(("ScaleUI: scale set to %.2f."):format(applied))
    end
    RefreshPanel()
end

local function BuildPanel()
    local p = CreateFrame("Frame", "ScaleUIPanel", UIParent, "BackdropTemplate")
    p:SetSize(330, 188)
    p:SetPoint("CENTER")
    p:SetBackdrop(BACKDROP_DIALOG_32_32)
    p:SetMovable(true)
    p:EnableMouse(true)
    p:RegisterForDrag("LeftButton")
    p:SetScript("OnDragStart", p.StartMoving)
    p:SetScript("OnDragStop", p.StopMovingOrSizing)
    p:SetClampedToScreen(true)
    p:SetToplevel(true)
    p:Hide()

    -- Title
    local title = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", p, "TOP", 0, -10)
    title:SetText("ScaleUI")

    -- Current-scale readout
    local readout = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    readout:SetPoint("TOP", p, "TOP", 0, -30)
    p.readout = readout

    local presetsLabel = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    presetsLabel:SetPoint("TOP", p, "TOP", 0, -52)
    presetsLabel:SetText("Presets - scale 1.0 on a shorter screen")

    -- Preset buttons; labels show the value each preset resolves to here
    local presetButtons = {}
    for index, presetHeight in ipairs(PRESETS) do
        local button = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
        button:SetSize(70, 22)
        if index == 1 then
            button:SetPoint("TOPLEFT", p, "TOPLEFT", 19, -72)
        else
            button:SetPoint("LEFT", presetButtons[index - 1], "RIGHT", 4, 0)
        end
        local _, screenHeight = GetPhysicalScreenSize()
        button:SetText(("%d  %.2f"):format(presetHeight, presetHeight / screenHeight))
        button:SetScript("OnClick", function()
            local _, h = GetPhysicalScreenSize()
            local applied, deferred = ApplyScale(presetHeight / h)
            if deferred then
                print(("ScaleUI: preset %dpx applied as %.2f (in combat - saved CVar write deferred)."):format(presetHeight, applied))
            else
                print(("ScaleUI: preset %dpx applied as %.2f."):format(presetHeight, applied))
            end
            RefreshPanel()
        end)
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(("Screen height %d px"):format(presetHeight), 1, 1, 1)
            local _, h = GetPhysicalScreenSize()
            GameTooltip:AddLine(("Resolves to %.3f on your %dpx-tall display."):format(presetHeight / h, h))
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        presetButtons[index] = button
    end
    p.presetButtons = presetButtons

    -- Custom scale row: label + editbox (Enter applies) + Apply button
    local customLabel = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    customLabel:SetPoint("TOPLEFT", p, "TOPLEFT", 22, -108)
    customLabel:SetText("Custom:")

    local editBox = CreateFrame("EditBox", nil, p, "InputBoxTemplate")
    editBox:SetPoint("LEFT", customLabel, "RIGHT", 10, 0)
    editBox:SetSize(84, 22)
    editBox:SetAutoFocus(false)
    editBox:SetCursorPosition(0)
    p.editBox = editBox

    local applyButton = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    applyButton:SetPoint("LEFT", editBox, "RIGHT", 12, 0)
    applyButton:SetSize(64, 22)
    applyButton:SetText("Apply")
    applyButton:SetScript("OnClick", ApplyFromInput)
    editBox:SetScript("OnEnterPressed", ApplyFromInput)
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    -- Reset row
    local resetButton = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    resetButton:SetPoint("TOP", p, "TOP", 0, -138)
    resetButton:SetSize(160, 22)
    resetButton:SetText("Reset to 100%")
    resetButton:SetScript("OnClick", function()
        ApplyScale(DEFAULT_SCALE)
        print("ScaleUI: scale reset to 100%.")
        RefreshPanel()
    end)

    -- Command hint
    local hint = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    hint:SetPoint("TOP", p, "TOP", 0, -168)
    hint:SetText("/sui <n>  |  /sui reset  |  /sui force")

    -- Close button
    local closeButton = CreateFrame("Button", nil, p, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", p, "TOPRIGHT", 2, 2)

    return p
end

SLASH_SCALEUI1, SLASH_SCALEUI2 = "/sui", "/scaleui"
SlashCmdList.SCALEUI = function(msg)
    local arg = (msg or ""):match("^%s*(.-)%s*$"):lower()
    if arg == "" then
        if not panel then
            panel = BuildPanel()
        end
        if panel:IsShown() then
            panel:Hide()
        else
            RefreshPanel()
            panel:Show()
        end
    elseif arg == "reset" then
        ApplyScale(DEFAULT_SCALE)
        print("ScaleUI: scale reset to 100%.")
        RefreshPanel()
    elseif arg == "force" then
        local applied, deferred = ApplyScale(db.scale)
        if deferred then
            print("ScaleUI: saved scale reapplied (in combat - CVar write deferred).")
        else
            print(("ScaleUI: saved scale reapplied (%.2f)."):format(applied))
        end
        RefreshPanel()
    elseif arg == "help" then
        print("ScaleUI: /sui (panel) | /sui <n> | /sui reset | /sui force")
    else
        local value = ParseScale(arg)
        if value then
            ApplyScale(value)
            print(("ScaleUI: scale set to %.2f."):format(value))
            RefreshPanel()
        else
            print("ScaleUI: unknown option - /sui help")
        end
    end
end

-- Assert the saved scale on login; adopt external scale changes (e.g. the
-- system settings slider) instead of fighting them; re-assert the saved
-- scale whenever the display resolution actually changes.
local width, height = GetPhysicalScreenSize()

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("UI_SCALE_CHANGED")
eventFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")
eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        C_Timer.After(0.5, function()
            ApplyScale(db.scale)
            RefreshPanel()
        end)
    elseif event == "UI_SCALE_CHANGED" then
        local current = tonumber(C_CVar.GetCVar("uiScale"))
        if current and math.abs(current - db.scale) > 0.001 then
            db.scale = ClampScale(current)
            RefreshPanel()
        end
    elseif event == "DISPLAY_SIZE_CHANGED" then
        local newWidth, newHeight = GetPhysicalScreenSize()
        if newWidth ~= width or newHeight ~= height then
            width, height = newWidth, newHeight
            ApplyScale(db.scale)
            RefreshPanel()
            print(("ScaleUI: display %dx%d - saved scale reapplied (%.2f)."):format(width, height, db.scale))
        end
    end
end)
