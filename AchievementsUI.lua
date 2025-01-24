local LibDeflate = LibStub and LibStub("LibDeflate")
if not LibDeflate then
    print("PCM Debug: LibDeflate not found!")
end

if not PocketMoneyAchievements then
  PocketMoneyAchievements = {}
end

local function GetIconByID(iconID)
  return select(3, GetSpellInfo(iconID)) or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local realmName = GetRealmName()
local playerName = UnitName("player")

-- Achievement UI window list
local BACKDROP = {
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
  tile = true,
  tileSize = 32,
  edgeSize = 32,
  insets = { left = 11, right = 12, top = 12, bottom = 11 }
}

-- Main achievement window
local AchievementsFrame = CreateFrame("Frame", "PocketMoneyAchievementsFrame", UIParent, "BackdropTemplate")
AchievementsFrame:SetSize(420, 500) 
AchievementsFrame:SetPoint("CENTER")
AchievementsFrame:SetMovable(true)
AchievementsFrame:EnableMouse(true)
AchievementsFrame:RegisterForDrag("LeftButton")
AchievementsFrame:SetScript("OnDragStart", AchievementsFrame.StartMoving)
AchievementsFrame:SetScript("OnDragStop", AchievementsFrame.StopMovingOrSizing)
AchievementsFrame:SetBackdrop(BACKDROP)
AchievementsFrame:Hide()
AchievementsFrame:SetScript("OnMouseDown", function(self, button)
  if button == "LeftButton" then
      self:StartMoving()
  end
end)

AchievementsFrame:SetScript("OnMouseUp", function(self, button)
  if button == "LeftButton" then
      self:StopMovingOrSizing()
  end
end)

-- Title
local titleBar = AchievementsFrame:CreateTexture(nil, "ARTWORK")
titleBar:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
titleBar:SetPoint("TOP", 0, 12)
titleBar:SetSize(300, 64)

local titleText = AchievementsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
titleText:SetPoint("TOP", 0, 0)
titleText:SetText("Achievements")

-- Progress Bar
local progressBarBorder = CreateFrame("Frame", nil, AchievementsFrame, "BackdropTemplate")
progressBarBorder:SetSize(300, 20)
progressBarBorder:SetPoint("TOP", titleText, "BOTTOM", 0, -60)
progressBarBorder:SetBackdrop({
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  edgeSize = 12,
  insets = { left = 2, right = 2, top = 2, bottom = 2 }
})

local progressBar = CreateFrame("StatusBar", nil, progressBarBorder)
progressBar:SetSize(296, 16)
progressBar:SetPoint("CENTER")
progressBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
progressBar:SetStatusBarColor(0, 0.8, 0)

-- Points Display
local pointsLabel = AchievementsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
pointsLabel:SetPoint("TOP", 0, -35)  -- Moved to left side

local pointsText = AchievementsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
pointsText:SetPoint("TOP", pointsLabel, "BOTTOM", 0, -5)
pointsText:SetFont(pointsText:GetFont(), 24)

-- ScrollFrame for achievements
local scrollFrame = CreateFrame("ScrollFrame", nil, AchievementsFrame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", progressBarBorder, "BOTTOMLEFT", 0, -10)
scrollFrame:SetPoint("BOTTOMRIGHT", -45, 20)  

local scrollChild = CreateFrame("Frame", nil, scrollFrame)
scrollFrame:SetScrollChild(scrollChild)
scrollChild:SetWidth(scrollFrame:GetWidth())
scrollChild:SetHeight(1)

-- Close button
local closeButton = CreateFrame("Button", nil, AchievementsFrame, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", -5, -5)  -- Added explicit offset

function LoadAchievements()
  if not PocketMoneyEncryptedAchievements then 
      print("PCM Debug: No encrypted achievements found")
      return {} 
  end
  
  local decoded = LibDeflate:DecodeForWoWAddonChannel(PocketMoneyEncryptedAchievements)
  if not decoded then
      print("PCM Debug: Decoding failed")
      return {}
  end
  
  local decompressed = LibDeflate:DecompressDeflate(decoded)
  if not decompressed then
      print("PCM Debug: Decompression failed")
      return {}
  end
  
  local func, err = loadstring(decompressed)
  if not func then
      print("PCM Debug: Loadstring error: " .. tostring(err))
      return {}
  end
  
  local success, result = pcall(func)
  if not success then
      print("PCM Debug: PCall error: " .. tostring(result))
      return {}
  end
  
  return result
end

local function CreateAchievementEntry(achievement, isCompleted, parent, yOffset)
  local entry = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  entry:SetSize(parent:GetWidth() - 20, 50)
  entry:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -yOffset)

  entry:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
  })
  entry:SetBackdropColor(0.1, 0.1, 0.1, 0.3)
  entry:SetBackdropBorderColor(0.6, 0.6, 0.6)

  local icon = entry:CreateTexture(nil, "ARTWORK")
  icon:SetSize(32, 32)
  icon:SetPoint("LEFT", 5, 0)

  local nameText = entry:CreateFontString(nil, "OVERLAY", isCompleted and "GameFontNormal" or "GameFontDisable")
  nameText:SetPoint("LEFT", icon, "RIGHT", 10, 0)
  nameText:SetText(achievement.name)
  nameText:SetWidth(parent:GetWidth() - 80) -- Limit name text width

  local pointsText = entry:CreateFontString(nil, "OVERLAY", isCompleted and "GameFontHighlight" or "GameFontDisable")
  pointsText:SetPoint("RIGHT", -10, 0)

  if isCompleted then
    icon:SetTexture(GetIconByID(achievement.icon))
    pointsText:SetText(tostring(achievement.points))
  else
    icon:SetTexture("Interface\\Icons\\inv_misc_questionmark")
    icon:SetVertexColor(0.5, 0.5, 0.5)
    pointsText:SetText("?")
  end

  entry:Show()
  return 55
end

local function PopulateAchievements()

  for _, child in ipairs({scrollChild:GetChildren()}) do
    child:Hide()
  end

  local achievements = LoadAchievements()
  local playerAchievements = PocketMoneyDB[realmName][playerName].achievements.completed or {}
  local entryPool = {}
  local yOffset = 0
  local totalAchievements = 0
  local completedAchievements = 0

  for id, achievement in pairs(achievements) do
    if playerAchievements[id] then
      yOffset = yOffset + CreateAchievementEntry(achievement, true, scrollChild, yOffset)
      completedAchievements = completedAchievements + 1
      totalAchievements = totalAchievements + 1
    end
  end

  for id, achievement in pairs(achievements) do
    if not playerAchievements[id] then
      yOffset = yOffset + CreateAchievementEntry(achievement, false, scrollChild, yOffset)
      totalAchievements = totalAchievements + 1
    end
  end

  progressBar:SetMinMaxValues(0, totalAchievements)
  progressBar:SetValue(completedAchievements)
  local progressText = progressBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  progressText:SetPoint("CENTER", progressBar, "CENTER")
  progressText:SetText(completedAchievements .. " / " .. totalAchievements)
  
  scrollChild:SetHeight(yOffset)
  scrollFrame:UpdateScrollChildRect()
end

PocketMoneyAchievements.ToggleUI = function()
  if not PocketMoneyDB[realmName][playerName].achievements then
    PocketMoneyDB[realmName][playerName].achievements = {
      progress = {},
      completed = {},
      bosses = {},
      checksum = nil
    }
  end
  if AchievementsFrame:IsShown() then
    AchievementsFrame:Hide()
  else
    PopulateAchievements()
    AchievementsFrame:Show()
  end
end

---------------------------------
-- Achievement UI Banner Popup --
---------------------------------
local bannerFrame = CreateFrame("Frame", "PocketMoneyAchievementBanner", UIParent, "BackdropTemplate")
bannerFrame:SetSize(300, 60)
bannerFrame:SetPoint("TOP", 0, -100)
bannerFrame:SetBackdrop({
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
  edgeFile = "Interface\\AchievementFrame\\UI-Achievement-WoodBorder",
  tile = true,
  tileSize = 32,
  edgeSize = 16,
  insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
bannerFrame:Hide()

local glowTexture = bannerFrame:CreateTexture(nil, "BACKGROUND")
glowTexture:SetTexture("Interface\\SpellActivationOverlay\\IconAlert")
glowTexture:SetSize(520, 100)
glowTexture:SetPoint("CENTER")
glowTexture:SetBlendMode("ADD")
glowTexture:SetTexCoord(0.00781250, 0.50781250, 0.27734375, 0.52734375)
glowTexture:SetAlpha(0)

-- Title decoration with rogue icon
local titleBar = bannerFrame:CreateTexture(nil, "ARTWORK")
titleBar:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
titleBar:SetPoint("TOP", 0, 12)
titleBar:SetSize(33, 33)

local rogueIcon = bannerFrame:CreateTexture(nil, "OVERLAY")
rogueIcon:SetSize(32, 32)
rogueIcon:SetPoint("TOP", 0, 14)
rogueIcon:SetTexture("Interface\\Icons\\ClassIcon_Rogue")

-- Achievement icon on left
local achievementIcon = bannerFrame:CreateTexture("PocketMoneyAchievementBannerIcon", "ARTWORK")  -- Give it a name
achievementIcon:SetSize(32, 32)
achievementIcon:SetPoint("LEFT", 15, 0)
achievementIcon:SetTexCoord(0, 1, 0, 1)
achievementIcon:Show()

-- Points text
local pointsText = bannerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
pointsText:SetPoint("RIGHT", -15, 0)
pointsText:SetJustifyH("RIGHT")

-- Achievement text
local achievementText = bannerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
achievementText:SetPoint("LEFT", achievementIcon, "RIGHT", 10, 0)
achievementText:SetPoint("RIGHT", pointsText, "LEFT", -10, 0)
achievementText:SetJustifyH("LEFT")
achievementText:SetJustifyV("MIDDLE")

-- Achievement text
local achievementText = bannerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
achievementText:SetPoint("LEFT", achievementIcon, "RIGHT", 10, 0)

bannerFrame:EnableMouse(true)
bannerFrame:SetScript("OnMouseUp", function(self)
  -- Clear any existing fade timer
  if self.fadeTimer then
    self.fadeTimer:Cancel()
    self.fadeTimer = nil
  end
  
  -- Start fade out when clicked
  local startTime = GetTime()
  self:SetScript("OnUpdate", function(self, elapsed)
    local alpha = 1 - ((GetTime() - startTime) / 0.5)
    if alpha <= 0 then
      self:Hide()
      self:SetScript("OnUpdate", nil)
    else
      self:SetAlpha(alpha)
    end
  end)
end)

local function AnimateGlow()
  local elapsed = 0
  local duration = 0.5
  bannerFrame:SetScript("OnUpdate", function(self, delta)
      elapsed = elapsed + delta
      local progress = elapsed / duration
      if progress <= 1 then
          glowTexture:SetAlpha(math.sin(progress * math.pi))
      else
          glowTexture:SetAlpha(0)
          self:SetScript("OnUpdate", nil)
      end
  end)
end

-- In ShowBanner, store the timer reference
PocketMoneyAchievements.ShowBanner = function(achievementData)
  local iconTexture = achievementData.iconID and GetIconByID(achievementData.iconID)
  print("PCM Debug: Setting icon using ID:", achievementData.iconID, "Texture:", iconTexture)
  achievementIcon:SetTexture(iconTexture)
  
  achievementText:SetText(achievementData.name)
  pointsText:SetText(achievementData.points)
  
  -- Reset position and show
  bannerFrame:ClearAllPoints()
  bannerFrame:SetPoint("TOP", UIParent, "TOP", 0, -100)
  bannerFrame:Show()
  bannerFrame:SetAlpha(0)

  -- Slide in
  local slideInTime = 0
  local finalY = -50
  bannerFrame:SetScript("OnUpdate", function(self, elapsed)
    slideInTime = slideInTime + elapsed
    local progress = slideInTime / 0.5 -- 0.5 seconds for slide in
    
    if progress >= 1 then
      -- Animation complete
      self:SetPoint("TOP", UIParent, "TOP", 0, finalY)
      self:SetAlpha(1)
      self:SetScript("OnUpdate", nil)
      AnimateGlow()
      -- Start the display timer
      C_Timer.After(5, function()
        if self:IsShown() then
          -- Start fade out
          local fadeTime = 0
          self:SetScript("OnUpdate", function(self, elapsed)
            fadeTime = fadeTime + elapsed
            local fadeProgress = fadeTime / 0.5
            if fadeProgress >= 1 then
              self:Hide()
              self:SetScript("OnUpdate", nil)
            else
              self:SetAlpha(1 - fadeProgress)
            end
          end)
        end
      end)
    else
      -- During slide in
      local currentY = -100 + (50 * progress)
      self:SetPoint("TOP", UIParent, "TOP", 0, currentY)
      self:SetAlpha(progress)
    end
  end)

  PlaySound(834)
end