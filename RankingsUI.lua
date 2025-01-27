local rankings = {}
local processedPlayers = {}
local BACKDROP = {
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
  edgeFile = "Interface\\Buttons\\WHITE8X8",
  tile = true,
  tileSize = 1,
  edgeSize = 1,
  insets = { left = 1, right = 1, top = 1, bottom = 1 }
}

local realmName = GetRealmName()
local playerName = UnitName("player")
local ROGUE_COLOR = {r = 1, g = 0.96, b = 0.41}

local RankingsUI = CreateFrame("Frame", "PocketMoneyRankingsFrame", UIParent, "BackdropTemplate")
RankingsUI:SetSize(325, 400)
RankingsUI:SetPoint("CENTER")
RankingsUI:SetMovable(true)
RankingsUI:EnableMouse(true)
RankingsUI:RegisterForDrag("LeftButton")
RankingsUI:SetScript("OnDragStart", RankingsUI.StartMoving)
RankingsUI:SetScript("OnDragStop", RankingsUI.StopMovingOrSizing)
RankingsUI:SetBackdrop(BACKDROP)
RankingsUI:SetBackdropBorderColor(ROGUE_COLOR.r, ROGUE_COLOR.g, ROGUE_COLOR.b, 1)
RankingsUI:Hide()

local titleBar = RankingsUI:CreateTexture(nil, "ARTWORK")
titleBar:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
titleBar:SetPoint("TOP", 0, 20)
titleBar:SetSize(310, 64)
titleBar:SetVertexColor(0.4, 0.4, 0.4, 1)

local titleText = RankingsUI:CreateFontString(nil, "OVERLAY", "GameFontNormal")
titleText:SetPoint("TOP", 0, 5)
titleText:SetText("Guild Pickpocket Rankings")

local closeButton = CreateFrame("Button", nil, RankingsUI, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", -5, -5)

local serverCheckbox = CreateFrame("CheckButton", nil, RankingsUI, "UICheckButtonTemplate")
serverCheckbox:SetPoint("TOPLEFT", 20, -25)
serverCheckbox:SetSize(24, 24)

local serverLabel = RankingsUI:CreateFontString(nil, "OVERLAY", "GameFontNormal")
serverLabel:SetPoint("LEFT", serverCheckbox, "RIGHT", 5, 0)
serverLabel:SetText("Include Non-Guild Rogues")

serverCheckbox:SetScript("OnClick", function(self)
  local checked = self:GetChecked()
  PocketMoneyDB.settings = PocketMoneyDB.settings or {}
  PocketMoneyDB.settings.includeAllRogues = checked
  PocketMoneyRankings.RequestLatestData()
  PocketMoneyRankings.UpdateUI()
end)

local scrollFrame = CreateFrame("ScrollFrame", nil, RankingsUI, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 20, -50)
scrollFrame:SetPoint("BOTTOMRIGHT", -45, 10)

local scrollChild = CreateFrame("Frame")
scrollChild:SetSize(255, 390) -- Set this dynamically if needed
scrollFrame:SetScrollChild(scrollChild)

local contentFrame = scrollChild

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
  -- Get most up todate values
  PocketMoneyRankings.RequestLatestData()
  
  if not PocketMoneyDB or not PocketMoneyDB[realmName] then return end

  for _, child in ipairs({contentFrame:GetChildren()}) do
    child:Hide()
    child:SetParent(nil)
  end

  local rankings = {}
  local processedPlayers = {}
  titleText:SetText("Guild Pickpocket Rankings")

  -- Let's start with our own rogues!
  if PocketMoneyDB[realmName][playerName] then
    local myData
    if PocketMoneyDB[realmName][playerName].AltOf then
      local mainChar = PocketMoneyDB[realmName][playerName].AltOf
      myData = PocketMoneyDB[realmName][mainChar]
      playerName = mainChar  -- Use main's name for display
    else
        myData = PocketMoneyDB[realmName][playerName]
    end
    local total = (myData.lifetimeGold or 0) + (myData.lifetimeJunk or 0) + (myData.lifetimeBoxValue or 0)
    
    -- Add alt totals if this is a main character with alts
    local altsBreakdown = {}
    if myData.main and myData.Alts then
      for altName, altData in pairs(myData.Alts) do
        local altTotal = (altData.lifetimeGold or 0) + (altData.lifetimeJunk or 0) + (altData.lifetimeBoxValue or 0)
        total = total + altTotal
        table.insert(altsBreakdown, {
          alt = altName,
          gold = altData.lifetimeGold or 0,
          junk = altData.lifetimeJunk or 0,
          boxValue = altData.lifetimeBoxValue or 0
        })
      end
    end

    local mainTotal = total
    table.insert(rankings, {
        player = playerName,
        total = mainTotal,
        gold = myData.lifetimeGold or 0,
        junk = myData.lifetimeJunk or 0,
        boxValue = myData.lifetimeBoxValue or 0,
        alts = altsBreakdown
    })
    processedPlayers[playerName] = true
  end

  -- Update rankings for all rogues
  if PocketMoneyDB.settings and PocketMoneyDB.settings.includeAllRogues then
    titleText:SetText("Server Pickpocket Rankings")
    for rogueName, rogueData in pairs(PocketMoneyDB[realmName].knownRogues) do
      local total = (rogueData.gold or 0) + (rogueData.junk or 0) + (rogueData.boxValue or 0)
      if total > 0 and not processedPlayers[rogueName] then
        local altTotal = 0
        local altsBreakdown = {}
        if rogueData.Alt then
          for _, altName in ipairs(rogueData.Alts) do
            local altData = PocketMoneyDB[realmName].knownRogues[altName] or {}
            local altTotalValue = (altData.gold or 0) + (altData.junk or 0) + (altData.boxValue or 0)
            altTotal = altTotal + altTotalValue
            table.insert(altsBreakdown, {
              alt = altName,
              gold = altData.gold or 0,
              junk = altData.junk or 0,
              boxValue = altData.boxValue or 0
            })
            processedPlayers[altName] = true
          end
        end

        local mainTotal = total + altTotal
        table.insert(rankings, {
          player = rogueName,
          total = mainTotal,
          gold = rogueData.gold or 0,
          junk = rogueData.junk or 0,
          boxValue = rogueData.boxValue or 0,
          alts = altsBreakdown
        })
        processedPlayers[rogueName] = true
      end
    end
  else
    for rogueName, rogueData in pairs(PocketMoneyDB[realmName].knownRogues) do
      if localPlayerGuild then
        if rogueData.Guild == localPlayerGuild then
          local total = (rogueData.gold or 0) + (rogueData.junk or 0) + (rogueData.boxValue or 0)
          if total > 0 and not processedPlayers[rogueName] then
            local altTotal = 0
            local altsBreakdown = {}
    
            if rogueData.Alts then
              for _, altName in ipairs(rogueData.Alts) do
                local altData = PocketMoneyDB[realmName].knownRogues[altName] or {}
                local altTotalValue = (altData.gold or 0) + (altData.junk or 0) + (altData.boxValue or 0)
                altTotal = altTotal + altTotalValue
                table.insert(altsBreakdown, {
                  alt = altName,
                  gold = altData.gold or 0,
                  junk = altData.junk or 0,
                  boxValue = altData.boxValue or 0
                })
                processedPlayers[altName] = true
              end
            end
    
            local mainTotal = total + altTotal
            table.insert(rankings, {
              player = rogueName,
              total = mainTotal,
              gold = rogueData.gold or 0,
              junk = rogueData.junk or 0,
              boxValue = rogueData.boxValue or 0,
              alts = altsBreakdown
            })
            processedPlayers[rogueName] = true
          end
        end
      end
    end
  end

  serverCheckbox:SetChecked(PocketMoneyDB.settings and PocketMoneyDB.settings.includeAllRogues or false)
  table.sort(rankings, function(a, b) return a.total > b.total end)
  
  for i, data in ipairs(rankings) do
    local entryFrame = CreateFrame("Frame", nil, contentFrame, "BackdropTemplate")
    entryFrame:SetSize(260, 20)
    entryFrame:SetPoint("TOPLEFT", 0, -((i-1) * 25))

    -- highlight us!
    local isOurCharacter = false
    if PocketMoneyDB[realmName][playerName].AltOf then
        isOurCharacter = (data.player == PocketMoneyDB[realmName][playerName].AltOf)
    else
        isOurCharacter = (data.player == playerName)
    end

    if i % 2 == 0 then
      entryFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",  -- Added this
        tile = true,
        tileSize = 16,
        edgeSize = 1,   -- Added this
        insets = { left = 0, right = 0, top = 0, bottom = 0 }  -- Added this
      })
      entryFrame:SetBackdropColor(0.2, 0.2, 0.2, 0.3)
    else
      entryFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",  -- Added this
        tile = true,
        tileSize = 16,
        edgeSize = 1,   -- Added this
        insets = { left = 0, right = 0, top = 0, bottom = 0 }  -- Added this
      })
      entryFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.2)
    end
    
    if isOurCharacter then
      entryFrame:SetBackdropBorderColor(0, 1, 0, 0.5)
    else
      entryFrame:SetBackdropBorderColor(0, 0, 0, 0)  -- Invisible border
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

      -- Display the main player's data
      GameTooltip:AddLine("Raw Gold: " .. PocketMoneyCore.FormatMoney(data.gold))
      GameTooltip:AddLine("Junk Items: " .. PocketMoneyCore.FormatMoney(data.junk))
      GameTooltip:AddLine("Junkbox Value: " .. PocketMoneyCore.FormatMoney(data.boxValue))

      -- If there are alts, display their breakdown as well
      if data.alts and #data.alts > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Alts Breakdown:", 1, 0.84, 0)
        
        local altTotal = 0
        for _, altData in ipairs(data.alts) do
          GameTooltip:AddLine(altData.alt .. ":")
          GameTooltip:AddLine("  Raw Gold: " .. PocketMoneyCore.FormatMoney(altData.gold))
          GameTooltip:AddLine("  Junk Items: " .. PocketMoneyCore.FormatMoney(altData.junk))
          GameTooltip:AddLine("  Junkbox Value: " .. PocketMoneyCore.FormatMoney(altData.boxValue))
          altTotal = altTotal + (altData.gold or 0) + (altData.junk or 0) + (altData.boxValue or 0)
        end

        -- Display total of alts
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Total Alt Value: " .. PocketMoneyCore.FormatMoney(altTotal), 0, 1, 0)
      end

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