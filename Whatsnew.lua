local ADDON_VERSION = "1.6.7"

PocketMoneyWhatsNew = {}

local CHANGELOG = {
  ["1.6.7"] = [[
Pocket Money Updated to Version 1.6.X:

- No longer reguires you to see other rogues in game for them to be added to your list!
  This should allow the non-guild rogues toggle to populate with more usuers.

Apologies for the multiple upadates while we work on resolve bugs with the new data sharing method.

Coming soon - Rogue Pickpocket Achievements!

Enjoy the update!
Pocket Money, for rogues, by rogues.
]]
  
}

function PocketMoneyWhatsNew.GetChangelogText()
  return CHANGELOG[ADDON_VERSION] or "No changelog available."
end

local function CompareVersions(currentVersion, lastSeenVersion)
  local function splitVersion(version)
    local major, minor, patch = version:match("(%d+)%.(%d+)%.(%d+)")
    return {
      major = tonumber(major) or 0,
      minor = tonumber(minor) or 0,
      patch = tonumber(patch) or 0
    }
  end
  
  local current = splitVersion(currentVersion)
  local lastSeen = splitVersion(lastSeenVersion)
  
  if current.major > lastSeen.major then 
    return true 
  end
  if current.major < lastSeen.major then 
    return false 
  end
  
  if current.minor > lastSeen.minor then 
    return true 
  end
  
  return false
end

function PocketMoneyWhatsNew.CheckUpdateNotification()
  PocketMoneyDB = PocketMoneyDB or {}
  PocketMoneyDB.lastSeenVersion = PocketMoneyDB.lastSeenVersion or "0.0.0"
  
  local shouldShow = CompareVersions(ADDON_VERSION, PocketMoneyDB.lastSeenVersion)
  
  if shouldShow then
    -- Add a small delay to ensure UI is fully loaded
    C_Timer.After(2, function()
      PocketMoneyWhatsNew.CreateUpdateNotificationFrame()
      PocketMoneyDB.lastSeenVersion = ADDON_VERSION
    end)
  end
end

function PocketMoneyWhatsNew.CreateUpdateNotificationFrame()
 
  local frame = CreateFrame("Frame", "PocketMoneyUpdateNotificationFrame", UIParent, "BackdropTemplate")
  frame:SetSize(300, 200)
  
  frame:SetPoint("CENTER", UIParent, "CENTER", -250, 0)
  frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
  })
   
  frame:SetFrameStrata("DIALOG")
  frame:SetFrameLevel(255)

  local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  titleText:SetPoint("TOP", frame, "TOP", 0, -20)
  titleText:SetText("Pocket Money Update " .. ADDON_VERSION)
  titleText:SetTextColor(1, 1, 1, 1) 

  local contentText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  contentText:SetPoint("TOP", titleText, "BOTTOM", 0, -20)
  contentText:SetPoint("LEFT", frame, "LEFT", 20, 0)
  contentText:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
  contentText:SetWordWrap(true)
  contentText:SetText(PocketMoneyWhatsNew.GetChangelogText())
  contentText:SetTextColor(1, 1, 1, 1)

  local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  closeButton:SetPoint("TOPRIGHT")
  closeButton:SetScript("OnClick", function()
    frame:Hide()
  end)

  tinsert(UISpecialFrames, frame:GetName())
  
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:Show()
  C_Timer.After(1, function()
    print("DEBUG: Delayed Show Attempt")
    frame:Show()
  end)
end

-- Add a slash command for manual testing
SLASH_PMWHATS1 = "/pmwhats"
SlashCmdList["PMWHATS"] = function()
  print("Manually triggering What's New")
  PocketMoneyWhatsNew.CreateUpdateNotificationFrame()
end

function PocketMoneyWhatsNew.ForceShowNotification()
  PocketMoneyWhatsNew.CreateUpdateNotificationFrame()
end