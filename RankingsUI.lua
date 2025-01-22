local rankings = {}
local processedPlayers = {}
local BACKDROP = {
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
  tile = true,
  tileSize = 32,
  edgeSize = 32,
  insets = { left = 11, right = 12, top = 12, bottom = 11 }
}

local RankingsUI = CreateFrame("Frame", "PocketMoneyRankingsFrame", UIParent, "BackdropTemplate")
RankingsUI:SetSize(300, 400)
RankingsUI:SetPoint("CENTER")
RankingsUI:SetMovable(true)
RankingsUI:EnableMouse(true)
RankingsUI:RegisterForDrag("LeftButton")
RankingsUI:SetScript("OnDragStart", RankingsUI.StartMoving)
RankingsUI:SetScript("OnDragStop", RankingsUI.StopMovingOrSizing)
RankingsUI:SetBackdrop(BACKDROP)
RankingsUI:Hide()

RankingsUI:SetBackdrop({
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
  tile = true,
  tileSize = 32,
  edgeSize = 32,
  insets = { left = 11, right = 12, top = 12, bottom = 11 }
})

local titleBar = RankingsUI:CreateTexture(nil, "ARTWORK")
titleBar:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
titleBar:SetPoint("TOP", 0, 12)
titleBar:SetSize(300, 64)

local titleText = RankingsUI:CreateFontString(nil, "OVERLAY", "GameFontNormal")
titleText:SetPoint("TOP", 0, 0)
titleText:SetText("Guild Pickpocket Rankings")

local closeButton = CreateFrame("Button", nil, RankingsUI, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT")

local serverCheckbox = CreateFrame("CheckButton", nil, RankingsUI, "UICheckButtonTemplate")
serverCheckbox:SetPoint("TOPLEFT", 20, -25)
serverCheckbox:SetSize(24, 24)

local serverLabel = RankingsUI:CreateFontString(nil, "OVERLAY", "GameFontNormal")
serverLabel:SetPoint("LEFT", serverCheckbox, "RIGHT", 5, 0)
serverLabel:SetText("Include Non-Guild Rogues")

serverCheckbox:SetScript("OnClick", function(self)
  local checked = self:GetChecked()
  PocketMoneyDB.settings = PocketMoneyDB.settings or {}
  PocketMoneyDB.settings.includeNearbyRogues = checked
  PocketMoneyRankings.RequestLatestData()
  PocketMoneyRankings.UpdateUI()
end)

local contentFrame = CreateFrame("Frame", nil, RankingsUI)
contentFrame:SetPoint("TOPLEFT", 20, -50)
contentFrame:SetPoint("BOTTOMRIGHT", -20, 10)

tinsert(UISpecialFrames, "PocketMoneyRankingsFrame")

PocketMoneyRankings.ToggleUI = function()
    if RankingsUI:IsShown() then
      RankingsUI:Hide()
    else
      RankingsUI:Show()
      PocketMoneyRankings.UpdateUI()
    end
end

PocketMoneyRankings.UpdateUI = function()
  local realmName = GetRealmName()
  local playerName = UnitName("player")

  PocketMoneyRankings.RequestLatestData()
  
  if not PocketMoneyDB or not PocketMoneyDB[realmName] or not PocketMoneyDB[realmName].guildRankings then return end

  for _, child in ipairs({contentFrame:GetChildren()}) do
    child:Hide()
    child:SetParent(nil)
  end

  local rankings = {}
  local processedPlayers = {}

  if PocketMoneyDB[realmName][playerName] then
    local myData = PocketMoneyDB[realmName][playerName]
    local total = (myData.lifetimeGold or 0) + (myData.lifetimeJunk or 0) + (myData.lifetimeBoxValue or 0)
    table.insert(rankings, {
      player = playerName,
      total = total,
      gold = myData.lifetimeGold or 0,
      junk = myData.lifetimeJunk or 0,
      boxValue = myData.lifetimeBoxValue or 0
    })
    processedPlayers[playerName] = true
  end

  for player, data in pairs(PocketMoneyDB[realmName].guildRankings) do
    if not processedPlayers[player] then
      local total = (data.gold or 0) + (data.junk or 0) + (data.boxValue or 0)
      table.insert(rankings, {
        player = player,
        total = total,
        gold = data.gold or 0,
        junk = data.junk or 0,
        boxValue = data.boxValue or 0
      })
      processedPlayers[player] = true
    end
  end
  if PocketMoneyDB.settings and PocketMoneyDB.settings.includeNearbyRogues then
    titleText:SetText("Server Pickpocket Rankings")
    for player, data in pairs(PocketMoneyDB[realmName].knownRogues) do
      if not processedPlayers[player] then
        local total = (data.gold or 0) + (data.junk or 0) + (data.boxValue or 0)
        table.insert(rankings, {
          player = player,
          total = total,
          gold = data.gold or 0,
          junk = data.junk or 0,
          boxValue = data.boxValue or 0,
          lastSeen = data.lastSeen
        })
        processedPlayers[player] = true
      end
    end
  end

  serverCheckbox:SetChecked(PocketMoneyDB.settings and PocketMoneyDB.settings.includeNearbyRogues or false)
  table.sort(rankings, function(a, b) return a.total > b.total end)
  
  for i, data in ipairs(rankings) do
    local entryFrame = CreateFrame("Frame", nil, contentFrame, "BackdropTemplate")
    entryFrame:SetSize(260, 20)
    entryFrame:SetPoint("TOPLEFT", 0, -((i-1) * 25))
    
    if i % 2 == 0 then
      entryFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        tile = true,
        tileSize = 16
      })
      entryFrame:SetBackdropColor(0.2, 0.2, 0.2, 0.3)
    else
      entryFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        tile = true,
        tileSize = 16
      })
      entryFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.2)
    end

    if i <= 3 then
      local border = entryFrame:CreateTexture(nil, "BORDER")
      border:SetAllPoints()
      
      if i == 1 then
        border:SetColorTexture(1, 0.84, 0, 0.3)
      elseif i == 2 then
        border:SetColorTexture(0.75, 0.75, 0.75, 0.3)
      elseif i == 3 then
        border:SetColorTexture(0.8, 0.5, 0.2, 0.3) 
      end
    end

    entryFrame:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(data.player .. "'s Breakdown:", 1, 0.84, 0)
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine("Raw Gold: " .. PocketMoneyCore.FormatMoney(data.gold))
      GameTooltip:AddLine("Junk Items: " .. PocketMoneyCore.FormatMoney(data.junk))
      GameTooltip:AddLine("Junkbox Value: " .. PocketMoneyCore.FormatMoney(data.boxValue))
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine("Total: " .. PocketMoneyCore.FormatMoney(data.total), 0, 1, 0)
      GameTooltip:Show()
    end)

    entryFrame:SetScript("OnLeave", function(self)
      GameTooltip:Hide()
    end)

    entryFrame:EnableMouse(true)
    
    local rankText = entryFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rankText:SetPoint("LEFT", 5, 0)
    rankText:SetText(i .. ".")
    
    local nameText = entryFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("LEFT", 35, 0)
    nameText:SetText(data.player)
    
    local goldText = entryFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    goldText:SetPoint("RIGHT", -5, 0)
    goldText:SetText(PocketMoneyCore.FormatMoney(data.total))
  end

  RankingsUI:RegisterEvent("PLAYER_REGEN_DISABLED")
  RankingsUI:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_DISABLED" then
      RankingsUI:Hide()
    end
  end)
end