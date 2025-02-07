PocketMoneyPopoutUI = {}
local wasShownBeforeCombat = false

local function UpdateFrameWidth()
  local PopUI = PocketMoneyPopoutUI.PopUI
  if not PopUI then return end
  
  local padding = 40
  local maxWidth = 0
  local textElements = {
    PopUI.rawGoldLifetime,
    PopUI.junkLifetime,
    PopUI.boxValueLifetime,
    PopUI.rawGoldSession,
    PopUI.junkSession,
    PopUI.boxValueSession
  }
  
  for _, fontString in ipairs(textElements) do
    if fontString and fontString.GetStringWidth then
      local width = fontString:GetStringWidth() + (fontString.label and fontString.label:len() * 6 or 0)
      maxWidth = math.max(maxWidth, width)
    end
  end
  
  PopUI:SetWidth(math.max(maxWidth + padding, 150))
end

local function CreatePopoutFrame()
  PocketMoneyPopoutUI.PopUI = CreateFrame("Frame", "PocketMoneyPopoutFrame", UIParent, "BackdropTemplate")
  local PopUI = PocketMoneyPopoutUI.PopUI
  PopUI:SetHeight(180)
  PopUI:SetPoint("CENTER")
  PopUI:SetMovable(true)
  PopUI:EnableMouse(true)
  PopUI:RegisterForDrag("LeftButton")
  PopUI:SetScript("OnDragStart", PopUI.StartMoving)
  PopUI:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if not PocketMoneyDB then PocketMoneyDB = {} end
    local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint()
    PocketMoneyDB.popoutPosition = { point, "UIParent", relativePoint, xOfs, yOfs }
  end)
  PopUI:SetScript("OnShow", function()
    PocketMoneyDB.popoutWasVisible = true
  end)
  PopUI:Hide()
  
  -- Backdrop styling
  PopUI:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
  })
  PopUI:SetBackdropBorderColor(1, 0.96, 0.41, 1)
  
  -- Title
  local title = PopUI:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", PopUI, "TOP", 0, -15)
  title:SetText("Pocket Money Stats")
  
  -- Lifetime Section
  local lifetimeHeader = PopUI:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  lifetimeHeader:SetPoint("TOPLEFT", 20, -40)
  lifetimeHeader:SetText("|cFF9370DB[Lifetime]|r")
  
  local rawGoldLifetime = PopUI:CreateFontString(nil, "OVERLAY", "GameFontWhiteSmall")
  rawGoldLifetime:SetPoint("TOPLEFT", lifetimeHeader, "BOTTOMLEFT", 10, -5)
  rawGoldLifetime.label = "  Raw Gold:"
  
  local junkLifetime = PopUI:CreateFontString(nil, "OVERLAY", "GameFontWhiteSmall")
  junkLifetime:SetPoint("TOPLEFT", rawGoldLifetime, "BOTTOMLEFT", 0, -2)
  junkLifetime.label = "  Junk Items:"
  
  local boxValueLifetime = PopUI:CreateFontString(nil, "OVERLAY", "GameFontWhiteSmall")
  boxValueLifetime:SetPoint("TOPLEFT", junkLifetime, "BOTTOMLEFT", 0, -2)
  boxValueLifetime.label = "  Junk Box Value:"
  
  -- Session Section
  local sessionHeader = PopUI:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  sessionHeader:SetPoint("TOPLEFT", boxValueLifetime, "BOTTOMLEFT", -10, -10)
  sessionHeader:SetText("|cFF00FF00[Session]|r")
  
  local rawGoldSession = PopUI:CreateFontString(nil, "OVERLAY", "GameFontWhiteSmall")
  rawGoldSession:SetPoint("TOPLEFT", sessionHeader, "BOTTOMLEFT", 10, -5)
  rawGoldSession.label = "  Raw Gold:"
  
  local junkSession = PopUI:CreateFontString(nil, "OVERLAY", "GameFontWhiteSmall")
  junkSession:SetPoint("TOPLEFT", rawGoldSession, "BOTTOMLEFT", 0, -2)
  junkSession.label = "  Junk Items:"
  
  local boxValueSession = PopUI:CreateFontString(nil, "OVERLAY", "GameFontWhiteSmall")
  boxValueSession:SetPoint("TOPLEFT", junkSession, "BOTTOMLEFT", 0, -2)
  boxValueSession.label = "  Junk Box Value:"
  
  -- Close Button
  local closeButton = CreateFrame("Button", nil, PopUI, "UIPanelCloseButton")
  closeButton:SetPoint("TOPRIGHT", -5, -5)
  
  -- Store references for updating
  PopUI.rawGoldLifetime = rawGoldLifetime
  PopUI.junkLifetime = junkLifetime
  PopUI.boxValueLifetime = boxValueLifetime
  PopUI.rawGoldSession = rawGoldSession
  PopUI.junkSession = junkSession
  PopUI.boxValueSession = boxValueSession

  UpdateFrameWidth()

  C_Timer.After(0.5, function()
    if PocketMoneyDB and PocketMoneyDB.popoutPosition then
      local position = PocketMoneyDB.popoutPosition
      PopUI:ClearAllPoints()
      PopUI:SetPoint(unpack(position))
    else
      PopUI:SetPoint("CENTER")
    end
    if PocketMoneyDB.popoutWasVisible then
      PopUI:Show()
    else
      PopUI:Hide()
    end
  end)

  PopUI:SetScript("OnHide", function()
    PocketMoneyDB.popoutWasVisible = false
  end)
  return PopUI
end

local function OnCombatEvent()
  local PopUI = PocketMoneyPopoutUI.PopUI
  if not PopUI then return end
  
  if InCombatLockdown() then
    if PocketMoneyDB.HidePopoutInCombat then
      wasShownBeforeCombat = PopUI:IsShown()
      if wasShownBeforeCombat then
        PopUI:Hide()
      end
    end
  else
    if PocketMoneyDB.HidePopoutInCombat and wasShownBeforeCombat then
      PopUI:Show()
      PocketMoneyPopoutUI.Update()
      wasShownBeforeCombat = false
    end
  end
end

function PocketMoneyPopoutUI.Toggle()
  if not PocketMoneyPopoutUI.PopUI then
    return -- Wait until the event initializes the frame.
  end
  local PopUI = PocketMoneyPopoutUI.PopUI
  if PopUI:IsShown() then
    PopUI:Hide()
  else
    PopUI:Show()
    PocketMoneyPopoutUI.Update()
  end
end

function PocketMoneyPopoutUI.Update()
  local PopUI = PocketMoneyPopoutUI.PopUI
  if not PopUI then return end

  local playerName = UnitName("player")
  local realmName = GetRealmName()
  local statsData
  
  if PocketMoneyCore.IsAltCharacter(playerName) then
      local mainChar = PocketMoneyDB[realmName][playerName].AltOf
      statsData = PocketMoneyDB[realmName][mainChar].Alts[playerName]
  else
      statsData = PocketMoneyDB[realmName][playerName]
  end
  
  -- Add nil checks for statsData fields
  local lifetimeGold = (statsData and statsData.lifetimeGold) or 0
  local lifetimeJunk = (statsData and statsData.lifetimeJunk) or 0
  local lifetimeBoxValue = (statsData and statsData.lifetimeBoxValue) or 0
  
  PopUI.rawGoldLifetime:SetText(PopUI.rawGoldLifetime.label .. " " .. PocketMoneyCore.FormatMoney(lifetimeGold))
  PopUI.junkLifetime:SetText(PopUI.junkLifetime.label .. " " .. PocketMoneyCore.FormatMoney(lifetimeJunk))
  PopUI.boxValueLifetime:SetText(PopUI.boxValueLifetime.label .. " " .. PocketMoneyCore.FormatMoney(lifetimeBoxValue))
  
  -- Use global session variables directly from Core.lua
  PopUI.rawGoldSession:SetText(PopUI.rawGoldSession.label .. " " .. PocketMoneyCore.FormatMoney(_G.sessionGold or 0))
  PopUI.junkSession:SetText(PopUI.junkSession.label .. " " .. PocketMoneyCore.FormatMoney(_G.sessionJunk or 0))
  PopUI.boxValueSession:SetText(PopUI.boxValueSession.label .. " " .. PocketMoneyCore.FormatMoney(_G.sessionBoxValue or 0))
  UpdateFrameWidth()
end

-- Create an update ticker
C_Timer.NewTicker(1, PocketMoneyPopoutUI.Update)

local function OnEvent(self, event, arg1)
  if event == "PLAYER_LOGIN" then
    CreatePopoutFrame()
  end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", OnEvent)
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
  if event == "PLAYER_LOGIN" then
    CreatePopoutFrame()
  elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
    OnCombatEvent()
  end
end)