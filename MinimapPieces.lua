-- spec 0007 §3: WIIIUI's own pieces of the minimap cluster, drawn on the
-- console art in place of Blizzard's hidden cluster. Plain frames, except the
-- calendar: a secure click-through to Blizzard's GameTimeFrame (spec 0007
-- §Risks). No method is ever called on a Blizzard frame.
-- Spec 0011 adds the day/night icon: Forever only, so it exists only where the
-- game provides the signal and the art.
local _, WIIIUI = ...

WIIIUI.MinimapPieces = WIIIUI.MinimapPieces or {}
local P = WIIIUI.MinimapPieces

-- Vanilla's mail icon and its empty-mailbox tint (e17c352 WIIIUI.xml:2103,
-- WIIIUI.lua:1871).
local MAIL_TEXTURE = "Interface\\Icons\\INV_Letter_15"
local MAIL_GREY = 0.25

-- Blizzard hides its own pieces through these rules (spec 0007 §1.4). The
-- Enum.GameRule members aren't in the generated docs, so any absent link
-- means "not disabled" rather than an error.
local function gameRuleActive(name)
  local rules = _G.C_GameRules
  local members = _G.Enum and _G.Enum.GameRule
  if not (rules and rules.IsGameRuleActive and members and members[name] ~= nil) then
    return false
  end
  return rules.IsGameRuleActive(members[name]) and true or false
end

-- Blizzard's Diel indicator art (Blizzard_Minimap/Camelot/Diel.lua:3-5, forever
-- e3ecc27). Forever only: spec 0011.
local DAY_NIGHT_ATLAS = {
  border = "UI-HUD-Minimap-Frame-Cycle",
  day = "UI-HUD-Minimap-DayCycle",
  night = "UI-HUD-Minimap-NightCycle",
}

-- RegisterEvent raises for an event the client doesn't know (wiki
-- API_Frame_RegisterEvent), so the event is checked before anything uses it.
local function dielEventValid()
  local events = _G.C_EventUtils
  return events ~= nil and events.IsEventValid ~= nil and events.IsEventValid("DIEL_CYCLE_CHANGED") == true
end

local function dayNightAtlasesResolve()
  local texture = _G.C_Texture
  if not (texture and texture.GetAtlasInfo) then
    return false
  end
  for _, atlas in pairs(DAY_NIGHT_ATLAS) do
    if not texture.GetAtlasInfo(atlas) then
      return false
    end
  end
  return true
end

-- One place answering "does this piece exist here": the API is present and
-- the game rule hasn't switched the feature off.
local function available(piece)
  if piece == "mail" then
    return _G.HasNewMail ~= nil and not gameRuleActive("IngameMailNotificationDisabled")
  end
  if piece == "tracking" then
    return _G.C_Minimap ~= nil and not gameRuleActive("IngameTrackingDisabled")
  end
  if piece == "calendar" then
    return _G.C_DateAndTime ~= nil and _G.GameTimeFrame ~= nil and not gameRuleActive("IngameCalendarDisabled")
  end
  if piece == "dayNight" then
    local dates = _G.C_DateAndTime
    return dates ~= nil and dates.IsDayTime ~= nil and dielEventValid() and dayNightAtlasesResolve()
  end
  return false
end

local function refreshMail()
  local mail = P.mail
  if not mail or not _G.HasNewMail then
    return
  end
  local lit = _G.HasNewMail() and 1 or MAIL_GREY
  mail.icon:SetVertexColor(lit, lit, lit, 1)
end

-- Blizzard's MinimapMailFrameUpdate (Minimap.lua, forever): same header rule,
-- same formatter. Only with mail waiting; the formatter is existence-checked
-- and its own body (FormattingUtil.lua:181) is the fallback.
local function showMailTooltip(self)
  if not (_G.HasNewMail and _G.HasNewMail()) then
    return
  end

  local senders = _G.GetLatestThreeSenders and { _G.GetLatestThreeSenders() } or {}
  local header = #senders >= 1 and _G.HAVE_MAIL_FROM or _G.HAVE_MAIL

  -- ANCHOR_LEFT opens over the minimap widget; the piece sits too close to the
  -- screen bottom for a below-anchor to stay clear of it.
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  if _G.FormatUnreadMailTooltip then
    _G.FormatUnreadMailTooltip(GameTooltip, header, senders)
  else
    GameTooltip:SetText(table.concat({ header, unpack(senders) }, "\n"))
  end
  GameTooltip:Show()
end

local function ensureMail(parent)
  if P.mail then
    return P.mail
  end

  local mail = CreateFrame("Frame", nil, parent)
  mail.icon = mail:CreateTexture(nil, "ARTWORK")
  mail.icon:SetAllPoints(mail)
  mail.icon:SetTexture(MAIL_TEXTURE)
  mail:EnableMouse(true)
  mail:SetScript("OnEnter", showMailTooltip)
  mail:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  P.mail = mail
  return mail
end

-- Blizzard's own art for the default glyph (Minimap.xml:90 on forever) and
-- the TexCoord its menu applies to a spell icon (Minimap.lua:722-724).
local TRACKING_ATLAS = "ui-hud-minimap-tracking-up"
local TRACKING_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local SPELL_TEXCOORD = { 0.0625, 0.9 }

local function refreshTracking()
  local tracking = P.tracking
  if not (tracking and _G.C_Minimap) then
    return
  end

  local icon = tracking.icon
  for index = 1, _G.C_Minimap.GetNumTrackingTypes() do
    local info = _G.C_Minimap.GetTrackingInfo(index)
    if info and info.active and info.type == "spell" then
      icon:SetTexture(info.texture)
      icon:SetTexCoord(SPELL_TEXCOORD[1], SPELL_TEXCOORD[2], SPELL_TEXCOORD[1], SPELL_TEXCOORD[2])
      return
    end
  end

  icon:SetTexture(nil)
  if _G.C_Texture and _G.C_Texture.GetAtlasInfo and _G.C_Texture.GetAtlasInfo(TRACKING_ATLAS) then
    icon:SetAtlas(TRACKING_ATLAS)
  end
end

-- Blizzard's subType values (Minimap.lua:8-9). Its "show all" CVar mode isn't
-- ported: the plain menu is the one every player sees by default.
local HUNTER_TRACKING = 1
local TOWNSFOLK_TRACKING = 2

-- The state the player just asked for, held until the client confirms with
-- MINIMAP_UPDATE_TRACKING; some tracking needs a spell cast to finish before
-- GetTrackingInfo flips (same reason as Blizzard's CreatePredictedTrackingState,
-- Minimap.lua:43-80).
local predicted = {}

local function isTracked(index)
  if predicted[index] ~= nil then
    return predicted[index]
  end
  local info = _G.C_Minimap.GetTrackingInfo(index)
  return info ~= nil and info.active == true
end

-- Only C_Minimap.SetTracking acts. Blizzard's MinimapUtil path also writes its
-- Settings system from addon code, which WIIIUI never does (spec 0007 §1.4).
local function setTracked(index, on)
  predicted[index] = on
  _G.C_Minimap.SetTracking(index, on)
end

-- Blizzard's CanDisplayTrackingInfo (Minimap.lua:556-563). Without the
-- constants table nothing can be judged, so everything is listed.
local function displayable(index)
  local constants = _G.MinimapConstants
  if not (constants and constants.OPTIONAL_FILTERS) then
    return true
  end
  local filter = _G.C_Minimap.GetTrackingFilter(index)
  return filter ~= nil and (constants.OPTIONAL_FILTERS[filter.filterID] or filter.spellID) and true or false
end

-- Blizzard's Uncheck All (Minimap.lua:652-664): clear, then switch the
-- always-on and conditional filters back on.
local function uncheckAll()
  _G.C_Minimap.ClearAllTracking()
  local constants = _G.MinimapConstants
  local alwaysOn = constants and constants.ALWAYS_ON_FILTERS or {}
  local conditional = constants and constants.CONDITIONAL_FILTERS or {}
  for index = 1, _G.C_Minimap.GetNumTrackingTypes() do
    predicted[index] = false
    local filter = _G.C_Minimap.GetTrackingFilter(index)
    if filter and (alwaysOn[filter.filterID] or conditional[filter.filterID]) then
      setTracked(index, true)
    end
  end
  return _G.MenuResponse.Refresh
end

local function createTrackingCheckbox(description, info)
  description:CreateCheckbox(info.name, function(data)
    return isTracked(data.index)
  end, function(data)
    setTracked(data.index, not isTracked(data.index))
  end, info)
end

-- Blizzard's grouping (Minimap.lua:667-684, 738-764), ascending index inside
-- each group: hunter entries (a submenu when there are several), townsfolk,
-- then the rest.
local function trackingMenu(_, root)
  root:CreateButton(_G.UNCHECK_ALL, uncheckAll)

  local isHunter = WIIIUI.PlayerClassToken() == "HUNTER"
  local hunter, townsfolk, regular = {}, {}, {}
  for index = 1, _G.C_Minimap.GetNumTrackingTypes() do
    local info = displayable(index) and _G.C_Minimap.GetTrackingInfo(index)
    if info then
      info.index = index
      local group = regular
      if isHunter and info.subType == HUNTER_TRACKING then
        group = hunter
      elseif info.subType == TOWNSFOLK_TRACKING then
        group = townsfolk
      end
      group[#group + 1] = info
    end
  end

  local hunterParent = root
  if #hunter > 1 then
    hunterParent = root:CreateButton(_G.HUNTER_TRACKING_TEXT)
  end
  for _, info in ipairs(hunter) do
    createTrackingCheckbox(hunterParent, info)
  end
  for _, info in ipairs(townsfolk) do
    createTrackingCheckbox(root, info)
  end
  for _, info in ipairs(regular) do
    createTrackingCheckbox(root, info)
  end
end

local function openTrackingMenu(self)
  if _G.MenuUtil and _G.C_Minimap then
    _G.MenuUtil.CreateContextMenu(self, trackingMenu)
  end
end

-- Blizzard's tooltip (Minimap.lua:826-831); ANCHOR_LEFT for the same reason as
-- the mail piece.
local function showTrackingTooltip(self)
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:SetText(_G.TRACKING or "", 1, 1, 1)
  GameTooltip:AddLine(_G.MINIMAP_TRACKING_TOOLTIP_NONE or "", nil, nil, nil, true)
  GameTooltip:Show()
end

local function ensureTracking(parent)
  if P.tracking then
    return P.tracking
  end

  local tracking = CreateFrame("Button", nil, parent)
  tracking:RegisterForClicks("AnyUp")
  tracking:SetScript("OnClick", openTrackingMenu)
  tracking:SetScript("OnEnter", showTrackingTooltip)
  tracking:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  tracking.icon = tracking:CreateTexture(nil, "ARTWORK")
  tracking.icon:SetAllPoints(tracking)
  local mask = tracking:CreateMaskTexture()
  mask:SetTexture(TRACKING_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  mask:SetAllPoints(tracking.icon)
  tracking.icon:AddMaskTexture(mask)
  P.tracking = tracking
  return tracking
end

-- Square pieces only (uses g.size for both axes); the width entries (zone,
-- clock) go through placeWide.
local function place(frame, anchor, g)
  frame:ClearAllPoints()
  frame:SetPoint(g.point, anchor, g.relativePoint, g.offsetX, g.offsetY)
  frame:SetSize(g.size, g.size)
end

-- Blizzard draws both atlases at native size, and the sun/moon atlas is smaller
-- than the border's, so the sun/moon is scaled by the same ratio to stay inside
-- the ring at any frame size (spec 0011 Option A). The atlas of the current
-- state is used, so a flip refits.
local function fitDayNight(frame)
  local info = _G.C_Texture and _G.C_Texture.GetAtlasInfo
  if not (info and frame.iconAtlas) then
    return
  end
  local borderInfo = info(DAY_NIGHT_ATLAS.border)
  local iconInfo = info(frame.iconAtlas)
  if not (borderInfo and iconInfo) then
    return
  end
  local width, height = frame:GetSize(true)
  frame.icon:SetSize(width * iconInfo.width / borderInfo.width, height * iconInfo.height / borderInfo.height)
end

-- Blizzard's composition: border over the sun/moon, both centred (Diel.lua:25-26,
-- 38-44).
local function ensureDayNight(parent)
  if P.dayNight then
    return P.dayNight
  end

  local frame = CreateFrame("Frame", nil, parent)
  frame:EnableMouse(false)
  frame.border = frame:CreateTexture(nil, "OVERLAY", nil, 1)
  frame.border:SetAllPoints(frame)
  frame.icon = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
  frame.icon:SetPoint("CENTER", frame, "CENTER")
  frame:SetScript("OnSizeChanged", fitDayNight)
  P.dayNight = frame
  return frame
end

local function setDayNight(isDay)
  local frame = P.dayNight
  if frame then
    frame.iconAtlas = isDay and DAY_NIGHT_ATLAS.day or DAY_NIGHT_ATLAS.night
    frame.icon:SetAtlas(frame.iconAtlas)
    fitDayNight(frame)
  end
end

local function refreshDayNight()
  if available("dayNight") then
    setDayNight(_G.C_DateAndTime.IsDayTime())
  end
end

-- Font base sizes at uiScale 240, grown through Theme.ScaledSize like the other
-- console text (spec 0007 §3.5; the maintainer confirms them in-game).
local ZONE_FONT_SIZE = 10
local CLOCK_FONT_SIZE = 10

local function applyPieceFont(fontString, base)
  local Theme = WIIIUI.Theme
  local size = Theme.ScaledSize(base, WIIIUI.LayoutUnits())
  Theme.ApplyFont(fontString, size, _G.GameFontNormalSmall)
  return size
end

-- Blizzard's zone colours (Minimap.lua:162-176, forever 966519c). A "combat"
-- zone is red only in the tooltip (Minimap.lua:206-208); its name keeps the
-- default colour, as there.
local ZONE_COLORS = {
  sanctuary = { 0.41, 0.8, 0.94 },
  arena = { 1.0, 0.1, 0.1 },
  friendly = { 0.1, 1.0, 0.1 },
  hostile = { 1.0, 0.1, 0.1 },
  contested = { 1.0, 0.7, 0.0 },
}
local COMBAT_ZONE_COLOR = { 1.0, 0.1, 0.1 }

local function defaultColor()
  local normal = _G.NORMAL_FONT_COLOR
  if normal then
    return { normal.r, normal.g, normal.b }
  end
  return { 1.0, 0.82, 0.0 }
end

function P.zoneColor(pvpType)
  return ZONE_COLORS[pvpType] or defaultColor()
end

-- Territory line per zone type (Minimap.lua:180-216). Friendly and hostile
-- zones name their faction and show nothing more without one.
local function territoryLine(pvpType, factionName)
  if pvpType == "sanctuary" then
    return _G.SANCTUARY_TERRITORY
  elseif pvpType == "arena" then
    return _G.FREE_FOR_ALL_TERRITORY
  elseif pvpType == "friendly" or pvpType == "hostile" then
    if factionName and factionName ~= "" and _G.FACTION_CONTROLLED_TERRITORY then
      return string.format(_G.FACTION_CONTROLLED_TERRITORY, factionName)
    end
  elseif pvpType == "contested" then
    return _G.CONTESTED_TERRITORY
  elseif pvpType == "combat" then
    return _G.COMBAT_ZONE
  end
  return nil
end

-- Pure: { { text, r, g, b }, ... } for the zone tooltip. A subzone equal to its
-- zone is dropped, and so is an empty line.
function P.zoneTooltipLines(pvpType, factionName, zone, subzone)
  local lines = { { zone, 1, 1, 1 } }
  if (pvpType == "friendly" or pvpType == "hostile") and not (factionName and factionName ~= "") then
    return lines
  end

  local color = pvpType == "combat" and COMBAT_ZONE_COLOR or P.zoneColor(pvpType)
  if subzone and subzone ~= "" and subzone ~= zone then
    lines[#lines + 1] = { subzone, color[1], color[2], color[3] }
  end
  local territory = territoryLine(pvpType, factionName)
  if territory and territory ~= "" then
    lines[#lines + 1] = { territory, color[1], color[2], color[3] }
  end
  return lines
end

-- C_PvP.GetZonePVPInfo isn't flagged secret, but the value is a table key, so
-- it goes through the one secret seam: absent, erroring or secret all read as
-- "no zone type" (spec 0007 §3.3).
local function readZoneType()
  local pvp = _G.C_PvP
  if not (pvp and pvp.GetZonePVPInfo) then
    return nil, nil
  end
  local pvpType, _, factionName = WIIIUI.Secret.Read(pvp.GetZonePVPInfo)
  return pvpType, factionName
end

local function refreshZone()
  local zone = P.zone
  if not zone then
    return
  end
  zone.text:SetText(_G.GetMinimapZoneText and _G.GetMinimapZoneText() or "")
  local color = P.zoneColor((readZoneType()))
  zone.text:SetTextColor(color[1], color[2], color[3])
end

local function showZoneTooltip(self)
  local pvpType, factionName = readZoneType()
  local lines = P.zoneTooltipLines(
    pvpType,
    factionName,
    _G.GetZoneText and _G.GetZoneText() or "",
    _G.GetSubZoneText and _G.GetSubZoneText() or ""
  )
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  for _, line in ipairs(lines) do
    GameTooltip:AddLine(line[1], line[2], line[3], line[4])
  end
  GameTooltip:Show()
end

local function ensureZone(parent)
  if P.zone then
    return P.zone
  end

  local zone = CreateFrame("Frame", nil, parent)
  zone.text = zone:CreateFontString(nil, "OVERLAY")
  zone.text:SetAllPoints(zone)
  zone.text:SetWordWrap(false)
  if zone.text.SetMaxLines then
    zone.text:SetMaxLines(1)
  end
  zone.text:SetShadowOffset(1, -1)
  zone:EnableMouse(true)
  zone:SetScript("OnEnter", showZoneTooltip)
  zone:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  P.zone = zone
  return zone
end

-- Width entries (zone, clock): the height follows the text, so only the width
-- comes from the geometry.
local function placeWide(frame, anchor, g, height)
  frame:ClearAllPoints()
  frame:SetPoint(g.point, anchor, g.relativePoint, g.offsetX, g.offsetY)
  frame:SetSize(g.width, height)
end

-- Blizzard's own day icon: one atlas per day of the month, in three states
-- (GameTime.lua:119-127, forever 966519c).
local CALENDAR_ATLAS = "ui-hud-calendar-%d-%s"

local function currentMonthDay()
  local dates = _G.C_DateAndTime
  local now = dates and dates.GetCurrentCalendarTime and dates.GetCurrentCalendarTime()
  return now and now.monthDay
end

-- Without the atlas (a client that lacks it) the day is drawn as a number, so
-- the piece still says something.
local function refreshCalendar()
  local calendar = P.calendar
  local day = currentMonthDay()
  if not (calendar and day) then
    return
  end
  P.calendarDay = day

  local up = string.format(CALENDAR_ATLAS, day, "up")
  if _G.C_Texture and _G.C_Texture.GetAtlasInfo and _G.C_Texture.GetAtlasInfo(up) then
    calendar:SetNormalTexture(up)
    calendar:SetPushedTexture(string.format(CALENDAR_ATLAS, day, "down"))
    calendar:SetHighlightTexture(string.format(CALENDAR_ATLAS, day, "mouseover"))
    if calendar.dayText then
      calendar.dayText:Hide()
    end
    return
  end

  if not calendar.dayText then
    calendar.dayText = calendar:CreateFontString(nil, "OVERLAY")
    calendar.dayText:SetAllPoints(calendar)
    calendar.dayText:SetShadowOffset(1, -1)
    applyPieceFont(calendar.dayText, CLOCK_FONT_SIZE)
  end
  calendar.dayText:SetText(tostring(day))
  calendar.dayText:Show()
end

local function showCalendarTooltip(self)
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:AddLine(_G.GAMETIME_TOOLTIP_TOGGLE_CALENDAR or "")
  GameTooltip:Show()
end

-- ToggleCalendar ends in ShowUIPanel(CalendarFrame), which refuses in combat
-- unless the call stack is secure (UIParentPanelManager.lua
-- CheckProtectedFunctionsAllowed). So the button never calls it: a secure
-- "click" action clicks Blizzard's own GameTimeFrame, whose OnClick
-- (GameTimeFrame_OnClick) then runs ToggleCalendar from a secure stack
-- (SecureTemplates.lua SECURE_ACTIONS.click; spec 0007 §Risks fallback).
local function ensureCalendar(parent)
  if P.calendar then
    return P.calendar
  end

  local calendar = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
  -- Both edges: SecureActionButton_OnClick only acts on the one matching the
  -- ActionButtonUseKeyDown CVar (SecureTemplates.lua), and an addon button
  -- is treated as a key press, so registering one edge could swallow clicks.
  calendar:RegisterForClicks("AnyUp", "AnyDown")
  -- No SetScript("OnClick"): it would replace the template's secure handler.
  calendar:SetScript("OnEnter", showCalendarTooltip)
  calendar:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  P.calendar = calendar
  return calendar
end

-- Attributes are only writable out of combat; Build runs through ApplyOrQueue.
-- Without GameTimeFrame the button just has no click action.
local function bindCalendarClick(calendar)
  local target = _G.GameTimeFrame
  if target and calendar:GetAttribute("clickbutton") ~= target then
    calendar:SetAttribute("type", "click")
    calendar:SetAttribute("clickbutton", target)
  end
end

-- GameTime_GetTime honours the player's local/realm and 24-hour settings
-- (GameTimeUtil.lua:87); GetGameTime is the plain realm-time fallback.
local function formattedTime()
  if _G.GameTime_GetTime then
    return _G.GameTime_GetTime(false)
  end
  if _G.GetGameTime then
    return string.format("%d:%02d", _G.GetGameTime())
  end
  return ""
end

-- The Button hugs the text so its hit rect doesn't swallow minimap pings along
-- the bottom strip; the FontString stays centred on the BOTTOM anchor.
local function sizeClock(clock)
  local height = clock:GetHeight()
  clock:SetSize(clock.text:GetStringWidth() + (P.clockPad or 0), height)
end

-- Returns whether the string changed.
local function refreshClock()
  local clock = P.clock
  if not clock then
    return false
  end
  local time = formattedTime()
  if time == clock.text:GetText() then
    return false
  end
  clock.text:SetText(time)
  sizeClock(clock)
  return true
end

-- Blizzard's TimeManagerClockButton_OnClick (Blizzard_TimeManager.lua:378-389).
-- Any missing function leaves the clock display-only.
local function clockClicked()
  if _G.TimeManager_IsAlarmFiring and _G.TimeManager_IsAlarmFiring() then
    if _G.TimeManager_TurnOffAlarm then
      _G.TimeManager_TurnOffAlarm()
    end
  elseif _G.ToggleTimeManager then
    _G.ToggleTimeManager()
  end
end

-- Blizzard's TimeManagerClockButton_OnEnter (Blizzard_TimeManager.lua:493-505).
local function showClockTooltip(self)
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  if _G.GameTime_UpdateTooltip then
    _G.GameTime_UpdateTooltip()
  end
  GameTooltip:AddLine(_G.GAMETIME_TOOLTIP_TOGGLE_CLOCK or "")
  GameTooltip:Show()
end

-- The one OnUpdate-style exception (spec 0007 §3.4): no event carries the
-- time, and Blizzard's own clock ticks at 1 s for the same reason
-- (Blizzard_TimeManager.lua:352-361). The calendar day is checked on its own
-- visibility so a hidden clock doesn't leave a stale day; the clock text idles
-- while hidden.
local function tick()
  local calendar = P.calendar
  if calendar and calendar:IsVisible() and currentMonthDay() ~= P.calendarDay then
    refreshCalendar()
  end
  local clock = P.clock
  if not (clock and clock:IsVisible()) then
    return
  end
  refreshClock()
end

local function ensureClock(parent)
  if P.clock then
    return P.clock
  end

  local clock = CreateFrame("Button", nil, parent)
  clock:RegisterForClicks("AnyUp")
  clock.text = clock:CreateFontString(nil, "OVERLAY")
  clock.text:SetAllPoints(clock)
  clock.text:SetShadowOffset(1, -1)
  clock:SetScript("OnClick", clockClicked)
  clock:SetScript("OnEnter", showClockTooltip)
  clock:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  P.clock = clock
  if _G.C_Timer then
    P.ticker = _G.C_Timer.NewTicker(1, tick)
  end
  return clock
end

function P.Build()
  local left = WIIIUI.Console.left
  local minimapTexture = left and left.minimapTexture
  if not minimapTexture then
    return
  end

  local units = WIIIUI.LayoutUnits()
  local geometry = WIIIUI.Theme.MinimapPieceGeometry(units, wc3UI_Options.theme)

  local mail = ensureMail(left)
  mail:SetParent(left)
  WIIIUI.Layers.Apply(mail, "minimap.piece")
  place(mail, minimapTexture, geometry.mail)
  local zoom = WIIIUI.Theme.IconZoom(units, geometry.mail.size)
  mail.icon:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)
  -- Show/Hide only here, inside Layout; events only recolour (spec 0007 §6).
  mail:SetShown(available("mail"))
  refreshMail()

  local tracking = ensureTracking(left)
  tracking:SetParent(left)
  WIIIUI.Layers.Apply(tracking, "minimap.piece")
  place(tracking, minimapTexture, geometry.tracking)
  tracking:SetShown(available("tracking"))
  refreshTracking()

  local zone = ensureZone(left)
  zone:SetParent(left)
  WIIIUI.Layers.Apply(zone, "minimap.piece")
  placeWide(zone, minimapTexture, geometry.zone, applyPieceFont(zone.text, ZONE_FONT_SIZE) + 2)
  zone:Show()
  refreshZone()

  local clock = ensureClock(left)
  clock:SetParent(left)
  WIIIUI.Layers.Apply(clock, "minimap.piece")
  placeWide(clock, minimapTexture, geometry.clock, applyPieceFont(clock.text, CLOCK_FONT_SIZE) + 2)
  clock:Show()
  P.clockPad = 0.02 * units
  refreshClock()
  sizeClock(clock)

  local calendar = ensureCalendar(left)
  -- The calendar is a protected child: `left` only changes through Layout/ApplyOrQueue.
  calendar:SetParent(left)
  WIIIUI.Layers.Apply(calendar, "minimap.piece")
  -- A protected frame anchors to a frame, not a texture region.
  place(calendar, WIIIUI.Console.AnchorFrame(minimapTexture), geometry.calendar)
  bindCalendarClick(calendar)
  calendar:SetShown(available("calendar"))
  if calendar.dayText then
    applyPieceFont(calendar.dayText, CLOCK_FONT_SIZE)
  end
  refreshCalendar()

  local dayNight = ensureDayNight(left)
  dayNight:SetParent(left)
  WIIIUI.Layers.Apply(dayNight, "minimap.piece")
  place(dayNight, minimapTexture, geometry.dayNight)
  local present = available("dayNight")
  dayNight:SetShown(present)
  if present then
    dayNight.border:SetAtlas(DAY_NIGHT_ATLAS.border)
  end
  refreshDayNight()
end

-- Not unit events, so plain registration. Nothing polls: the mail state only
-- changes on these (spec 0007 §3.1).
for _, event in ipairs({ "UPDATE_PENDING_MAIL", "MAIL_INBOX_UPDATE", "PLAYER_ENTERING_WORLD" }) do
  WIIIUI.On(event, refreshMail)
end

-- Some tracking needs a cast to finish, so the event can arrive before
-- GetTrackingInfo flips: keep a prediction until the live state equals it
-- (Blizzard's CreatePredictedTrackingState, Minimap.lua:43-80, forever 966519c).
local function onTrackingChanged()
  for index, value in pairs(predicted) do
    local info = _G.C_Minimap and _G.C_Minimap.GetTrackingInfo(index)
    if info and (info.active == true) == value then
      predicted[index] = nil
    end
  end
  refreshTracking()
end

-- A full reset: nothing the player just asked for can still be pending.
local function resetTracking()
  predicted = {}
  refreshTracking()
end

WIIIUI.On("MINIMAP_UPDATE_TRACKING", onTrackingChanged)
for _, event in ipairs({ "SPELLS_CHANGED", "PLAYER_ENTERING_WORLD" }) do
  WIIIUI.On(event, resetTracking)
end

-- The zone name only changes on these; nothing polls (spec 0007 §3.3).
for _, event in ipairs({ "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD" }) do
  WIIIUI.On(event, refreshZone)
end

-- The day also rolls over from the clock tick, at midnight (spec 0007 §3.4).
WIIIUI.On("PLAYER_ENTERING_WORLD", refreshCalendar)

-- A flip during a loading screen sends no event (spec 0011 §Answers 2).
WIIIUI.On("PLAYER_ENTERING_WORLD", refreshDayNight)

-- Guarded at file scope: on retail the unknown event would raise and abort
-- this file before its RegisterBuild (spec 0011 §Answers 1).
if dielEventValid() then
  WIIIUI.On("DIEL_CYCLE_CHANGED", function(isDayTime)
    setDayNight(isDayTime)
  end)
end

WIIIUI.RegisterBuild("MinimapPieces.Build", P.Build, { after = { "Console.BuildLeft", "Blizzard.BuildMinimap" } })
