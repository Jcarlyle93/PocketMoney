local ldb = LibStub:GetLibrary("LibDataBroker-1.1")
local icon = LibStub:GetLibrary("LibDBIcon-1.0")
local playerName = UnitName("player")
local realmName = GetRealmName()

-- Functions for prepop
local function GetLocalRogues()
  local rogues = {}
  if PocketMoneyDB and PocketMoneyDB[realmName] then
    for charName, charData in pairs(PocketMoneyDB[realmName]) do
      if type(charData) == "table" and charData.class == "ROGUE" then
        table.insert(rogues, charName)
      end
    end
  end
  return rogues
end

local function UpdateCheckboxVisuals(checkbox, enabled)
  local normalTexture = checkbox:GetNormalTexture()
  local pushedTexture = checkbox:GetPushedTexture()
  local disabledTexture = checkbox:GetDisabledTexture()
  
  if normalTexture then normalTexture:SetDesaturated(not enabled) end
  if pushedTexture then pushedTexture:SetDesaturated(not enabled) end
  if disabledTexture then disabledTexture:SetDesaturated(not enabled) end
end

local SettingsUI = CreateFrame("Frame", "PocketMoneySettingsFrame", UIParent, "BackdropTemplate")
SettingsUI:SetSize(380, 430)
SettingsUI:SetPoint("CENTER")
SettingsUI:SetMovable(true)
SettingsUI:EnableMouse(true)
SettingsUI:RegisterForDrag("LeftButton")
SettingsUI:SetScript("OnDragStart", SettingsUI.StartMoving)
SettingsUI:SetScript("OnDragStop", SettingsUI.StopMovingOrSizing)
SettingsUI:SetBackdrop({
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
  tile = true,
  tileSize = 32,
  edgeSize = 32,
  insets = { left = 11, right = 12, top = 12, bottom = 11 }
})
SettingsUI:SetBackdropBorderColor(1, 0.96, 0.41, 1)
SettingsUI:Hide()

-- Lib Icon Stuff
local ldb = LibStub:GetLibrary("LibDataBroker-1.1")
local icon = LibStub:GetLibrary("LibDBIcon-1.0")

PocketMoneyDB.minimap = PocketMoneyDB.minimap or {
  hide = false,
}

-- Create the broker object
local PocketMoneyLDB = ldb:NewDataObject("PocketMoney", {
  type = "launcher",
  icon = "Interface\\Icons\\INV_Misc_Bag_11",
  OnClick = function(_, button)
    if button == "LeftButton" then
      if SettingsUI:IsShown() then
        SettingsUI:Hide()
      else
        SettingsUI:Show()
      end
    end
  end,
  OnTooltipShow = function(tooltip)
    tooltip:AddLine("Pocket Money")
    tooltip:AddLine("Left-click to open settings", 1, 1, 1)
  end,
})

icon:Register("PocketMoney", PocketMoneyLDB, PocketMoneyDB.minimap)

local titleBar = CreateFrame("Frame", nil, SettingsUI)
titleBar:SetSize(250, 40)
titleBar:SetPoint("TOP", 0, 5)

local titleTexture = titleBar:CreateTexture(nil, "ARTWORK")
titleTexture:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
titleTexture:SetAllPoints()
titleBar:EnableMouse(true)
titleBar:RegisterForDrag("LeftButton")
titleBar:SetScript("OnDragStart", function() SettingsUI:StartMoving() end)
titleBar:SetScript("OnDragStop", function() SettingsUI:StopMovingOrSizing() end)

local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
titleText:SetPoint("TOP", titleBar, "TOP", 0, -8)
titleText:SetText("Pocket Money Settings")

local globalFrame = CreateFrame("Frame", nil, SettingsUI)
globalFrame:SetSize(350, 150)
globalFrame:SetPoint("TOP", 0, -40)

local globalHeader = globalFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
globalHeader:SetPoint("TOPLEFT", 20, 0)
globalHeader:SetText("Global Settings")

local mainSelectLabel = globalFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
mainSelectLabel:SetPoint("TOPLEFT", 20, -30)
mainSelectLabel:SetText("Select Main Character")

local mainDropdown = CreateFrame("Frame", "PocketMoneyMainDropdown", globalFrame, "UIDropDownMenuTemplate")
mainDropdown:SetPoint("TOPLEFT", mainSelectLabel, "BOTTOMLEFT", -15, -10)
UIDropDownMenu_SetWidth(mainDropdown, 160)
UIDropDownMenu_JustifyText(mainDropdown, "LEFT")

local setMainButton = CreateFrame("Button", nil, globalFrame, "UIPanelButtonTemplate")
setMainButton:SetSize(80, 22)
setMainButton:SetPoint("LEFT", mainDropdown, "RIGHT", 0, 2)
setMainButton:SetText("Set Main")
setMainButton:SetScript("OnClick", function()
  local selectedName = UIDropDownMenu_GetText(mainDropdown)
  if selectedName and selectedName ~= "Select Character" then
    local success, message = PocketMoneyCore.SetNewMain(selectedName)
    if success then
      if playerName == selectedName then
        setAltCheckbox:Disable()
        setAltLabel:SetText("Set as Alt Character (Cannot set main character as alt)")
      else
        setAltCheckbox:Enable()
        setAltLabel:SetText("Set as Alt Character")
        local isAlt = PocketMoneyCore.IsAltCharacter(playerName)
        setAltCheckbox:SetChecked(isAlt)
      end
    else
      print("Error: " .. message)
    end
  end
end)

local function InitializeMainDropdown(self, level) 
  local rogues = GetLocalRogues()  
  for _, rogueName in ipairs(rogues) do
    local info = UIDropDownMenu_CreateInfo()
    info.text = rogueName
    info.value = rogueName
    info.checked = nil
    info.func = function(self)
      UIDropDownMenu_SetSelectedValue(mainDropdown, rogueName)
      UIDropDownMenu_SetText(mainDropdown, rogueName)
      if rogueName == currentMain then
        setMainButton:Disable()
      else
        setMainButton:Enable()
      end
    end
    UIDropDownMenu_AddButton(info)
  end
end

local function UpdateMainDropdown()
  UIDropDownMenu_Initialize(mainDropdown, InitializeMainDropdown)
  if PocketMoneyDB[realmName] and PocketMoneyDB[realmName].main then
    local mainChar = PocketMoneyDB[realmName].main  
    UIDropDownMenu_SetSelectedValue(mainDropdown, mainChar)
    UIDropDownMenu_SetText(mainDropdown, mainChar)
    setMainButton:Disable()
  else
    UIDropDownMenu_SetSelectedValue(mainDropdown, nil)
    UIDropDownMenu_SetText(mainDropdown, "Select Character")
  end
  DropDownList1:Hide()
end

local valueDisplayCheckbox = CreateFrame("CheckButton", nil, globalFrame, "UICheckButtonTemplate")
valueDisplayCheckbox:SetPoint("TOPLEFT", mainDropdown, "BOTTOMLEFT", 15, -20)
valueDisplayCheckbox:SetSize(24, 24)

local combatHideCheckbox = CreateFrame("CheckButton", nil, globalFrame, "UICheckButtonTemplate")
combatHideCheckbox:SetPoint("TOPLEFT", valueDisplayCheckbox, "BOTTOMLEFT", 20, -5) 
combatHideCheckbox:SetSize(24, 24)

local valueDisplayLabel = globalFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
valueDisplayLabel:SetPoint("LEFT", valueDisplayCheckbox, "RIGHT", 5, 0)
valueDisplayLabel:SetText("Use Popout Values Display for /pm")

local combatHideLabel = globalFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
combatHideLabel:SetPoint("LEFT", combatHideCheckbox, "RIGHT", 5, 0)
combatHideLabel:SetText("Hide During Combat")


valueDisplayCheckbox:SetScript("OnClick", function(self)
  local isChecked = self:GetChecked()
  PocketMoneyDB.UsePopoutDisplay = isChecked
  combatHideCheckbox:SetEnabled(isChecked)
    UpdateCheckboxVisuals(combatHideCheckbox, isChecked)
    
    if not isChecked then
        combatHideCheckbox:SetChecked(false)
        PocketMoneyDB.HidePopoutInCombat = false
        combatHideLabel:SetTextColor(0.5, 0.5, 0.5)
    else
        combatHideLabel:SetTextColor(1, 1, 1)
    end
end)

combatHideCheckbox:SetScript("OnClick", function(self)
  local isChecked = self:GetChecked()
  PocketMoneyDB.HidePopoutInCombat = isChecked
end)

function togglePopoutFlag()
  PocketMoneyDB.UsePopoutDisplay = not PocketMoneyDB.UsePopoutDisplay
  local status = PocketMoneyDB.UsePopoutDisplay and "enabled" or "disabled"
  return PocketMoneyDB.UsePopoutDisplay
end

local UpdateCombatHideState = function()
  local popoutEnabled = valueDisplayCheckbox:GetChecked()
  
  if combatHideCheckbox then
    if not popoutEnabled then
      combatHideCheckbox:SetChecked(false)
      PocketMoneyDB.HidePopoutInCombat = false
      combatHideLabel:SetTextColor(0.5, 0.5, 0.5)
    else
      combatHideLabel:SetTextColor(1, 1, 1)
    end
    
    combatHideCheckbox:SetEnabled(popoutEnabled)
    UpdateCheckboxVisuals(combatHideCheckbox, popoutEnabled)
  end
end

local autoFlagCheckbox = CreateFrame("CheckButton", nil, globalFrame, "UICheckButtonTemplate")
autoFlagCheckbox:SetPoint("TOPLEFT", combatHideCheckbox, "BOTTOMLEFT", 0, -10)
autoFlagCheckbox:SetSize(24, 24)
autoFlagCheckbox:SetChecked(PocketMoneyDB.AutoFlag or false)
autoFlagCheckbox:SetScript("OnClick", function(self)
  local isChecked = self:GetChecked()
  PocketMoneyDB.AutoFlag = isChecked
  print("Auto-flag for new rogues " .. (isChecked and "enabled" or "disabled"))
end)

local autoFlagLabel = globalFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
autoFlagLabel:SetPoint("LEFT", autoFlagCheckbox, "RIGHT", 5, 0)
autoFlagLabel:SetText("Auto-Flag New Rogues as Alts")

function toggleAutoFlag()
  PocketMoneyDB.AutoFlag = not PocketMoneyDB.AutoFlag
  local status = PocketMoneyDB.AutoFlag and "enabled" or "disabled"
  return PocketMoneyDB.AutoFlag
end

local divider = SettingsUI:CreateTexture(nil, "ARTWORK")
divider:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Divider")
divider:SetSize(300, 16)
divider:SetPoint("TOP", globalFrame, "BOTTOM", 35, -50)
divider:SetPoint("CENTER", SettingsUI, "CENTER", 0, divider:GetTop())

local characterFrame = CreateFrame("Frame", nil, SettingsUI)
characterFrame:SetSize(280, 100)
characterFrame:SetPoint("TOP", divider, "BOTTOM", -70, 0)

local characterHeader = characterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
characterHeader:SetPoint("TOPLEFT", 20, 0)
characterHeader:SetText("Character Settings")

local setAltCheckbox = CreateFrame("CheckButton", nil, characterFrame, "UICheckButtonTemplate")
setAltCheckbox:SetPoint("TOPLEFT", characterHeader, "BOTTOMLEFT", 0, -10)
setAltCheckbox:SetSize(24, 24)

setAltCheckbox:SetChecked(isAlt)

local setAltLabel = characterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
setAltLabel:SetPoint("LEFT", setAltCheckbox, "RIGHT", 5, 0)
setAltLabel:SetText("Set as Alt Character")
setAltCheckbox:SetScript("OnClick", function(self)
  local isChecked = self:GetChecked()
  if isChecked then
    if not PocketMoneyCore.SetAsAlt(playerName) then
      self:SetChecked(false)
    end
  else
    if not PocketMoneyCore.RemoveAlt(playerName) then
      self:SetChecked(true)
    end
  end
end)

if playerName == PocketMoneyDB[realmName].main then
  UpdateCheckboxVisuals(setAltCheckbox, true)
  setAltCheckbox:Disable()
  setAltLabel:SetText("Set as alt (Cannot set main character as alt)")
end

local dividerTwo = SettingsUI:CreateTexture(nil, "ARTWORK")
dividerTwo:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Divider")
dividerTwo:SetSize(300, 16)
dividerTwo:SetPoint("TOP", globalFrame, "BOTTOM", 35, -120)
dividerTwo:SetPoint("CENTER", SettingsUI, "CENTER", 0, dividerTwo:GetTop())

local auditButton = CreateFrame("Button", nil, characterFrame, "UIPanelButtonTemplate")
auditButton:SetSize(280, 34)
auditButton:SetPoint("TOPLEFT", dividerTwo, "BOTTOMLEFT", -30, -10)
auditButton:SetText("Audit Local Characters")

auditButton:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:AddLine("Audit Local Characters")
  GameTooltip:AddLine("Cleans up character data by removing non-rogues and fixing alt relationships.", 1, 1, 1, true)
  GameTooltip:AddLine("Use with caution!", 1, 0.1, 0.1)
  GameTooltip:Show()
end)
auditButton:SetScript("OnLeave", function(self)
  GameTooltip:Hide()
end)

auditButton:SetScript("OnClick", function()
  StaticPopupDialogs["POCKETMONEY_CONFIRM_AUDIT"] = {
      text = "Are you sure you want to audit local characters?\nThis will remove non-rogues and fix alt relationships.",
      button1 = "Yes",
      button2 = "No",
      OnAccept = function()
          PocketMoneyCore.AuditLocal()
          C_Timer.After(0.1, function()
              pcall(UpdateMainDropdown)
          end)
      end,
      timeout = 0,
      whileDead = true,
      hideOnEscape = true,
      preferredIndex = 3,
  }
  StaticPopup_Show("POCKETMONEY_CONFIRM_AUDIT")
end)

local resetButton = CreateFrame("Button", nil, characterFrame, "UIPanelButtonTemplate")
resetButton:SetSize(280, 34)
resetButton:SetPoint("TOPLEFT", auditButton, "BOTTOMLEFT", 0, -5)
resetButton:SetText("Reset All Local Pockmoney Data!")

local closeButton = CreateFrame("Button", nil, SettingsUI, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", -5, -5)

tinsert(UISpecialFrames, "PocketMoneySettingsFrame")

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, addonName)
  if event == "ADDON_LOADED" and addonName == "PocketMoney" then
    local isAlt = PocketMoneyCore.IsAltCharacter(playerName)
    setAltCheckbox:SetChecked(isAlt)
    autoFlagCheckbox:SetChecked(PocketMoneyDB.AutoFlag or false)
    valueDisplayCheckbox:SetChecked(PocketMoneyDB.UsePopoutDisplay or false)
    combatHideCheckbox:SetChecked(PocketMoneyDB.HidePopoutInCombat or false)
    UpdateCombatHideState() 
    C_Timer.After(0.1, function()
      pcall(UpdateMainDropdown)
    end)
    if PocketMoneyDB[realmName] and PocketMoneyDB[realmName].main and playerName == PocketMoneyDB[realmName].main then
      setAltCheckbox:Disable()
      UpdateCheckboxVisuals(setAltCheckbox, false)
      setAltLabel:SetText("Cannot set main character as alt")
    else
      setAltCheckbox:Enable()
      UpdateCheckboxVisuals(setAltCheckbox, true)
      setAltLabel:SetText("Set as alt")
    end
  end
end)

SLASH_POCKETMONEYSETTINGS1 = "/pmset"
SLASH_POCKETMONEYSETTINGS2 = "/pmsettings"
SlashCmdList["POCKETMONEYSETTINGS"] = function()
    if SettingsUI:IsShown() then
        SettingsUI:Hide()
    else
        SettingsUI:Show()
    end
end