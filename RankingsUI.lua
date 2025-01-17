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

local contentFrame = CreateFrame("Frame", nil, RankingsUI)
contentFrame:SetPoint("TOPLEFT", 20, -30)
contentFrame:SetPoint("BOTTOMRIGHT", -20, 10)

PocketMoneyRankings.ToggleUI = function()
    if RankingsUI:IsShown() then
        RankingsUI:Hide()
    else
        RankingsUI:Show()
        PocketMoneyRankings.UpdateUI()
    end
end

PocketMoneyRankings.UpdateUI = function()
  for _, child in ipairs({contentFrame:GetChildren()}) do
      child:Hide()
      child:SetParent(nil)
  end
  
  local rankings = {}
  for player, data in pairs(PocketMoneyDB.guildRankings) do
      table.insert(rankings, {player = player, gold = data.gold})
  end
  table.sort(rankings, function(a, b) return a.gold > b.gold end)
  
  for i, data in ipairs(rankings) do
    local entryFrame = CreateFrame("Frame", nil, contentFrame, "BackdropTemplate")
    entryFrame:SetSize(260, 20)
    entryFrame:SetPoint("TOPLEFT", 0, -((i-1) * 25))
    
    -- Basic alternating backgrounds
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
    
    -- Special borders for top 3
    if i <= 3 then
        local border = entryFrame:CreateTexture(nil, "OVERLAY")
        border:SetPoint("TOPLEFT", -2, 2)
        border:SetPoint("BOTTOMRIGHT", 2, -2)
        
        if i == 1 then
            -- Gold
            border:SetColorTexture(1, 0.84, 0, 0.3)
        elseif i == 2 then
            -- Silver
            border:SetColorTexture(0.75, 0.75, 0.75, 0.3)
        elseif i == 3 then
            -- Bronze
            border:SetColorTexture(0.8, 0.5, 0.2, 0.3)
        end
    end

    local rankText = entryFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rankText:SetPoint("LEFT", 5, 0)
    rankText:SetText(i .. ".")
    
    local nameText = entryFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("LEFT", 35, 0)
    nameText:SetText(data.player)
    
    local goldText = entryFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    goldText:SetPoint("RIGHT", -5, 0)
    goldText:SetText(PocketMoneyCore.FormatMoney(data.gold))
  end
end