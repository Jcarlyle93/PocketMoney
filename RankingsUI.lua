local processedPlayers = {}
local BACKDROP = {
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
  tile = true,
  tileSize = 32,
  edgeSize = 32,
  insets = { left = 11, right = 12, top = 12, bottom = 11 }
}

local ROGUE_COLOR = {r = 1, g = 0.96, b = 0.41}

-- Helper Functions
local function addToRankings(entry)
  if type(entry) ~= "table" then
      return
  end
  if type(entry.player) ~= "string" then
      return
  end
  if type(entry.total) ~= "number" then
      return
  end
  table.insert(rankings, entry)
end

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
  PocketMoneyDB.settings.includeAllRogues = checked
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
    PocketMoneyRankings.RequestLatestData()
  end
end

PocketMoneyRankings.UpdateUI = function()
  
  if not PocketMoneyDB or not PocketMoneyDB[realmName] then return end
  local guild = GetGuildInfo("player")
  for _, child in ipairs({contentFrame:GetChildren()}) do
    child:Hide()
    child:SetParent(nil)
  end

  processedPlayers = {}
  rankings = {}  
  titleText:SetText("Guild Pickpocket Rankings")

  if PocketMoneyDB[realmName].main then
    local mainChar = PocketMoneyDB[realmName].main
    local myData = PocketMoneyDB[realmName][mainChar]
    local total = (myData.lifetimeGold or 0) + (myData.lifetimeJunk or 0) + (myData.lifetimeBoxValue or 0)
    
    if myData.main and myData.Alts then
      local altsBreakdown = {}
      for altName, altData in pairs(myData.Alts) do
        local altTotal = (altData.lifetimeGold or 0) + (altData.lifetimeJunk or 0) + (altData.lifetimeBoxValue or 0)
        total = total + altTotal
        table.insert(altsBreakdown, {
          alt = altName,
          gold = altData.lifetimeGold or 0,
          junk = altData.lifetimeJunk or 0,
          boxValue = altData.lifetimeBoxValue or 0
        })
        processedPlayers[altName] = true
      end
      local mainTotal = total
      addToRankings({
          player = playerName,
          total = mainTotal,
          gold = myData.lifetimeGold or 0,
          junk = myData.lifetimeJunk or 0,
          boxValue = myData.lifetimeBoxValue or 0,
          alts = altsBreakdown
      })
      processedPlayers[playerName] = true
    else
      local mainTotal = total
      addToRankings({
          player = playerName,
          total = mainTotal,
          gold = myData.lifetimeGold or 0,
          junk = myData.lifetimeJunk or 0,
          boxValue = myData.lifetimeBoxValue or 0,
          alts = {}
      })
      processedPlayers[playerName] = true
    end
  end

  -- Update rankings for all rogues
  if PocketMoneyDB.settings and PocketMoneyDB.settings.includeAllRogues then
    titleText:SetText("Server Pickpocket Rankings")
    for rogueName, rogueData in pairs(PocketMoneyDB[realmName].knownRogues) do
      local total = (rogueData.gold or 0) + (rogueData.junk or 0) + (rogueData.boxValue or 0)
      if rogueData.main and rogueData.Alts then
        local altsBreakdown = {}
        for altName, altData in pairs(rogueData.Alts) do
          local altTotalValue = (altData.gold or 0) + (altData.junk or 0) + (altData.boxValue or 0)
          total = total + altTotalValue
          
          table.insert(altsBreakdown, {
            alt = altName,
            gold = altData.gold or 0,
            junk = altData.junk or 0,
            boxValue = altData.boxValue or 0
          })
          processedPlayers[altName] = true
        end
  
        if total > 0 and not processedPlayers[rogueName] then
          addToRankings({
            player = rogueName,
            total = total,
            gold = rogueData.gold or 0,
            junk = rogueData.junk or 0,
            boxValue = rogueData.boxValue or 0,
            alts = altsBreakdown
          })
          processedPlayers[rogueName] = true
        end
      elseif total > 0 and not processedPlayers[rogueName] then
        addToRankings({
          player = rogueName,
          total = total,
          gold = rogueData.gold or 0,
          junk = rogueData.junk or 0,
          boxValue = rogueData.boxValue or 0,
          alts = {}
        })
        processedPlayers[rogueName] = true
      end
    end
  else
    for rogueName, rogueData in pairs(PocketMoneyDB[realmName].knownRogues) do
      if guild then
        if rogueData.Guild == guild then
          local total = (rogueData.gold or 0) + (rogueData.junk or 0) + (rogueData.boxValue or 0)
          if rogueData.main and rogueData.Alts then
            local altsBreakdown = {}
            for altName, altData in pairs(rogueData.Alts) do
              local altTotalValue = (altData.gold or 0) + (altData.junk or 0) + (altData.boxValue or 0)
              total = total + altTotalValue
              
              table.insert(altsBreakdown, {
                alt = altName,
                gold = altData.gold or 0,
                junk = altData.junk or 0,
                boxValue = altData.boxValue or 0
              })
              processedPlayers[altName] = true
            end
            if total > 0 and not processedPlayers[rogueName] then
              addToRankings({
                player = rogueName,
                total = total,
                gold = rogueData.gold or 0,
                junk = rogueData.junk or 0,
                boxValue = rogueData.boxValue or 0,
                alts = altsBreakdown
              })
              processedPlayers[rogueName] = true
            end
          elseif total > 0 and not processedPlayers[rogueName] then
            addToRankings({
              player = rogueName,
              total = total,
              gold = rogueData.gold or 0,
              junk = rogueData.junk or 0,
              boxValue = rogueData.boxValue or 0,
              alts = {}
            })
            processedPlayers[rogueName] = true
          end
        end
      end
    end
  end

  serverCheckbox:SetChecked(PocketMoneyDB.settings and PocketMoneyDB.settings.includeAllRogues or false)

  table.sort(rankings, function(a, b)
      if type(a) ~= "table" or type(b) ~= "table" then
          return false
      end
      if type(a.total) ~= "number" or type(b.total) ~= "number" then
          return false
      end
      return a.total > b.total
  end)
    
  for i, data in ipairs(rankings) do
    local entryFrame = CreateFrame("Frame", nil, contentFrame, "BackdropTemplate")
    entryFrame:SetSize(260, 20)
    entryFrame:SetPoint("TOPLEFT", 0, -((i-1) * 25))

    -- highlight us!
    local isOurCharacter = false
    if PocketMoneyDB[realmName].main then
      local mainChar = PocketMoneyDB[realmName].main
      if PocketMoneyCore.IsAltCharacter(playerName) then
        -- If we're an alt, highlight our main's entry
        isOurCharacter = (data.player == mainChar)
        -- Also use main's name for display
        playerName = mainChar
      else
        -- If we're the main, highlight our entry
        isOurCharacter = (data.player == playerName)
      end
    end
    if i % 2 == 0 then
      entryFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = true,
        tileSize = 16,
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
      })
      entryFrame:SetBackdropColor(0.2, 0.2, 0.2, 0.3)
    else
      entryFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = true,
        tileSize = 16,
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
      })
      entryFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.2)
    end
    
    if isOurCharacter then
      entryFrame:SetBackdropBorderColor(0, 1, 0, 0.5)
    else
      entryFrame:SetBackdropBorderColor(0, 0, 0, 0)
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

  local totalHeight = #rankings * 25
  scrollChild:SetHeight(totalHeight)

  -- Show/hide scrollbar based on content height
  if totalHeight <= scrollFrame:GetHeight() then
    -- Content fits, hide scrollbar
    local scrollBar = scrollFrame.ScrollBar or _G[scrollFrame:GetName().."ScrollBar"]
    if scrollBar then
      scrollBar:Hide()
    end
  else
    -- Content doesn't fit, show scrollbar
    local scrollBar = scrollFrame.ScrollBar or _G[scrollFrame:GetName().."ScrollBar"]
    if scrollBar then
      scrollBar:Show()
    end
  end

  -- Reset scroll position to top
  scrollFrame:SetVerticalScroll(0)

  RankingsUI:RegisterEvent("PLAYER_REGEN_DISABLED")
  RankingsUI:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_DISABLED" then
      RankingsUI:Hide()
    end
  end)
end