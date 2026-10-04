-- spec 0001 §Module split "Bars.lua": health/power bars + text, power
-- colour by UnitPowerType token (C1), plus §1.2's secret-safe % text, HP
-- gradient. Vanilla AlignHealthMana (e17c352
-- WIIIUI.lua:1980-2059) reused Blizzard's PlayerFrameHealthBar/
-- PlayerFrameManaBar, reparented to UIParent; PlayerFrame is now retired
-- (R2, Core.lua's WIIIUI.Retire), which hides its children too, so this
-- file builds WIIIUI's own StatusBar frames at the same position/size
-- instead. The raw "cur / max" text (default) is CLAUDE.md's own sanctioned
-- unguarded route (concatenation, SetValue and SetMinMaxValues are all
-- secret-tolerant); % text and the gradient go through WIIIUI.Secret
-- (Core.lua) since they touch UnitHealthPercent/UnitPowerPercent's
-- SecretReturns results.
local _, WIIIUI = ...

WIIIUI.Bars = WIIIUI.Bars or {}

-- WIIIUI ships no bar art of its own (vanilla borrowed Blizzard's own
-- PlayerFrameHealthBar/PlayerFrameManaBar texture, which is gone once
-- PlayerFrame is retired). WHITE8X8 is the universal Blizzard texture the
-- maintainer's DruidHUD project already validated in-game on Forever for
-- exactly this purpose (sister project, same Forever/retail standards,
-- CLAUDE.md status header).
local BAR_TEXTURE = "Interface\\Buttons\\WHITE8X8"

-- Unlike the health/power bars above, WIIIUI's own themed XP art already ships in art/other/ (xp1/xp2/xp3.tga,
-- xpProgressBar.tga) -- vanilla's XP bar was always WIIIUI's own art, not
-- borrowed from Blizzard, and CLAUDE.md's "the look is the specification"
-- says not to minimise it. Staying inside the plain-StatusBar convention
-- (no 3-piece endcap reconstruction, out of scope), the fill piece alone
-- uses xpProgressBar.tga instead of WHITE8X8.
local XP_BAR_TEXTURE = "Interface\\Addons\\WIIIUI\\art\\other\\xpProgressBar"

-- xpProgressBar.tga is a grayscale bevel/gloss mask, not pre-coloured art,
-- so the texture swap above needs the same fixed purple tint vanilla
-- AlignXPBar applied on top of its own art (e17c352 WIIIUI.lua:2129,
-- "xpProgBar:SetVertexColor(0.5, 0, 0.5, 1)") -- both together, not either
-- alone. The rested overlay's colour stays user-configurable via
-- wc3UI_Options.xpRestedXpColor (CLAUDE.md Domain model), not this constant.
local XP_BAR_MAIN_COLOR_R, XP_BAR_MAIN_COLOR_G, XP_BAR_MAIN_COLOR_B = 0.5, 0, 0.5

-- Vanilla never sets a static health-bar colour in AlignHealthMana itself
-- (Blizzard's own texture supplied it). This is the fallback colour the bar
-- keeps whenever the secret-guarded HP gradient (below) fails to build or
-- apply -- vanilla HPBarDamageGradiant's own 100%-health colour (e17c352
-- WIIIUI.lua:3975-4003: g=1 at healthPercent=1).
local HEALTH_BAR_DEFAULT_COLOR_R, HEALTH_BAR_DEFAULT_COLOR_G, HEALTH_BAR_DEFAULT_COLOR_B = 0, 1, 0

-- Vanilla AlignHealthMana (e17c352 WIIIUI.lua:1999, 2018): health text at
-- font size 10, power text at 9, same theme font as the rest of the console
-- (CLAUDE.md "the look is the specification").
local FONT_SIZES = { health = 10, power = 9, mana = 9 }

-- spec 0002 §1 layout gate: class and toggle only, never form. PlayerClassToken
-- yields nil for an unknown, secret or erroring class; only a plain token is
-- cached, so an early unknown read is retried.
local isDruidCache
local function isDruid()
  if isDruidCache == nil then
    local token = WIIIUI.PlayerClassToken()
    if token == nil then
      return false
    end
    isDruidCache = token == "DRUID"
  end
  return isDruidCache
end

function WIIIUI.Bars.IsDruid()
  return isDruid()
end

function WIIIUI.Bars.SlotCount()
  if isDruid() and wc3UI_Options and wc3UI_Options.druidResourceBar then
    return 3
  end
  return 2
end

-- spec 0002 §4: the slot list follows SlotCount(); mana exists only in the
-- druid layout, so a non-druid never builds it.
local builtSlotCount = 2

local function barDefs()
  if WIIIUI.Bars.SlotCount() == 3 then
    return { "health", "power", "mana" }
  end
  return { "health", "power" }
end

-- Vanilla xpCurrLevel (e17c352 WIIIUI.lua:2213: SetFont(..., 12, "")).
local LEVEL_TEXT_FONT_SIZE = 12

-- spec 0001 §1.2: "Health % text (HealthPercent) ... fs:SetFormattedText(
-- '%.0f%%', UnitHealthPercent('player', true, CurveConstants.ScaleTo100))
-- inside pcall ... Fallback: falls back to cur / max text." The guard seam
-- is a plain pcall here (the % text is a degrade, not a decision) with
-- WIIIUI.Secret.PairText (Core.lua) as the fallback; CurveConstants.ScaleTo100 is Blizzard's own
-- pre-built curve (Blizzard_SharedXMLBase/CurveConstants.lua), not one
-- WIIIUI builds.
local function setHealthText(bar)
  if wc3UI_Options.HealthPercent then
    local ok = pcall(function()
      bar.text:SetFormattedText("%.0f%%", UnitHealthPercent("player", true, CurveConstants.ScaleTo100))
    end)
    if ok then
      return
    end
  end

  WIIIUI.Secret.PairText(bar.text, UnitHealth("player"), UnitHealthMax("player"))
end

-- Enum.PowerType.Mana, with the documented literal 0 as the fallback when the
-- enum is missing (spec 0002 §1).
local function manaPowerType()
  return Enum and Enum.PowerType and Enum.PowerType.Mana or 0
end

-- spec 0001 §1.2: "Power % text (PowerPercent) ... Same with
-- UnitPowerPercent('player', nil, false, CurveConstants.ScaleTo100)."
-- spec 0002 §4: `powerType` is nil for the primary power (today's call) and
-- Enum.PowerType.Mana for the druid mana bar; the values go only to
-- SetText/concatenation, never compared.
local function setPowerText(bar, powerType)
  if wc3UI_Options.PowerPercent then
    local ok = pcall(function()
      bar.text:SetFormattedText("%.0f%%", UnitPowerPercent("player", powerType, false, CurveConstants.ScaleTo100))
    end)
    if ok then
      return
    end
  end

  WIIIUI.Secret.PairText(bar.text, UnitPower("player", powerType), UnitPowerMax("player", powerType))
end

-- spec 0001 §1.2: "HP gradient ... One ColorCurve built at login: 0 -> red,
-- 0.5 -> yellow, 1 -> green (the vanilla r,g formula sampled at 0/0.5/1,
-- linear)." Vanilla HPBarDamageGradiant (e17c352 WIIIUI.lua:3975-4003):
-- healthPercent<0.5 -> r=1,g=2*healthPercent,b=0 (0%=red, 50%=yellow);
-- else -> r=2*(1-healthPercent),g=1,b=0 (50%=yellow, 100%=green) -- exactly
-- the three sampled points below. Built lazily (not at file/module load)
-- and cached, so a missing C_CurveUtil/AddPoint/CreateColor API (spec 0001
-- §1.2's own "Unverified" list) degrades this one feature via Secret.CachedCurve
-- instead of erroring Bars.lua's whole load. ScriptObject_ColorCurveObject
-- (warcraft.wiki.gg): "AddPoint takes an x and y value; ... the y should be
-- a ColorMixin structure", built via CreateColor(r,g,b) (SharedXML/
-- Color.lua via FrameXML/Util.lua).
-- The build failure is cached against a cheap existence check of the two
-- globals the build needs (Secret.CachedCurve), so a known-failing build isn't
-- retried on every UNIT_HEALTH/UNIT_MAXHEALTH event but is retried as soon as
-- those globals reappear (spec 0001 §1.2 degrade-and-recover).
local getHealthColorCurve = WIIIUI.Secret.CachedCurve(function()
  local c = C_CurveUtil.CreateColorCurve()
  c:AddPoint(0, CreateColor(1, 0, 0))
  c:AddPoint(0.5, CreateColor(1, 1, 0))
  c:AddPoint(1, CreateColor(0, 1, 0))
  return c
end, function()
  return C_CurveUtil ~= nil and CreateColor ~= nil
end)

-- spec 0001 §1.2: "local c = UnitHealthPercent('player', true, curve) ->
-- bar:GetStatusBarTexture():SetVertexColor(c:GetRGB()) in pcall." Leaves
-- the bar's own static SetStatusBarColor (BuildBars) untouched on failure
-- -- that's the "Static vanilla green" fallback the spec's own table names.
local function updateHealthGradient(bar)
  local curve = getHealthColorCurve()
  if not curve then
    return
  end

  -- Degrade, not a decision: the result is secret and only handed on.
  pcall(function()
    local color = UnitHealthPercent("player", true, curve)
    bar:GetStatusBarTexture():SetVertexColor(color:GetRGB())
  end)
end

local function updateHealth()
  local bar = WIIIUI.Bars.health
  if not bar then
    return
  end

  bar:SetMinMaxValues(0, UnitHealthMax("player"))
  bar:SetValue(UnitHealth("player"))

  if bar.text then
    setHealthText(bar)
  end

  updateHealthGradient(bar)
end

local function updatePower()
  local bar = WIIIUI.Bars.power
  if not bar then
    return
  end

  bar:SetMinMaxValues(0, UnitPowerMax("player"))
  bar:SetValue(UnitPower("player"))

  if bar.text then
    setPowerText(bar)
  end

  -- spec 0001 §Event -> widget wiring: "colour by UnitPowerType token
  -- (vanilla colours)". PowerBarColor is Blizzard's own table
  -- (Blizzard_UnitFrame/Mainline/PowerBarColorUtil.lua on the forever
  -- branch) -- its MANA/RAGE/ENERGY entries (r=0,g=0,b=1 / r=1,g=0,b=0 /
  -- r=1,g=1,b=0) are exactly vanilla's ResetPowerBarColor (e17c352
  -- WIIIUI.lua:3862-3873), and it covers every other power type too without
  -- inventing new colours. Existence-checked: PowerBarColor is a Blizzard
  -- global, not guaranteed by the test stub.
  local _, token = UnitPowerType("player")
  local color = PowerBarColor and PowerBarColor[token]

  if color then
    bar:SetStatusBarColor(color.r, color.g, color.b, 1)
  end

  -- spec 0002 §1 middle-bar gate: in the druid layout the power bar shows
  -- whatever the main resource is, unless that is mana (the mana bar below
  -- already shows it). Show/Hide, not SetAlpha, so the customizer's
  -- Transparency isn't fought; Bars.power carries combatToggled for it.
  -- Gated on what BuildBars built, not the live SlotCount(): the class token
  -- or toggle can change between a queued Layout and this event.
  if builtSlotCount == 3 then
    local powerType = UnitPowerType("player")
    if powerType == nil then
      bar:Hide()
    elseif not WIIIUI.Secret.IsSecret(powerType) then
      if powerType ~= manaPowerType() then
        bar:Show()
      else
        bar:Hide()
      end
    end
  end
end

local function updateMana()
  local bar = WIIIUI.Bars.mana
  if not bar or not bar:IsShown() then
    return
  end

  local manaType = manaPowerType()
  bar:SetMinMaxValues(0, UnitPowerMax("player", manaType))
  bar:SetValue(UnitPower("player", manaType))

  if bar.text then
    setPowerText(bar, manaType)
  end
end

local function updatePowerBars()
  updatePower()
  updateMana()
end

-- spec 0010: BreakUpLargeNumbers is native but not in the generated API
-- docs, so it is resolved per call and falls back to plain digits.
local function fmt(value)
  local breakUp = _G.BreakUpLargeNumbers
  if type(breakUp) == "function" then
    return breakUp(value)
  end
  return tostring(value)
end

local XP_LABEL_COLOR = "|cffffd100"

local function goldLine(label, value)
  return XP_LABEL_COLOR .. label .. ":|r " .. value
end

-- Pure: nil at max level (UnitXPMax == 0), so the caller shows nothing.
-- Rested is a raw amount, never a percentage (spec 0010).
function WIIIUI.Bars.XPTooltipLines(cur, max, rested)
  if type(max) ~= "number" or max <= 0 then
    return nil
  end
  cur = cur or 0
  local togo = max - cur
  return {
    goldLine("Experience required to level up", fmt(max)),
    goldLine("Experience until next level",
      fmt(togo) .. string.format(" (%.2f %%)", togo / max * 100)),
    goldLine("Current Experience",
      fmt(cur) .. string.format(" (%.2f %%)", cur / max * 100)),
    goldLine("Rested Experience", fmt(rested or 0)),
  }
end

-- Degrade, not a decision (as InfoIcons.ShowTooltip): any missing API leaves
-- the tooltip unshown rather than raising from a mouse script.
local function showXPTooltip(bar)
  pcall(function()
    local lines = WIIIUI.Bars.XPTooltipLines(UnitXP("player"), UnitXPMax("player"), GetXPExhaustion())
    if not lines then
      if GameTooltip:GetOwner() == bar then
        GameTooltip:Hide()
      end
      return
    end
    GameTooltip:SetOwner(bar, "ANCHOR_TOP")
    for _, line in ipairs(lines) do
      GameTooltip:AddLine(line, 1, 1, 1)
    end
    GameTooltip:Show()
  end)
end

-- spec 0001 §Phased plan "C4 XP bar + tracking-bar starve/hide". Builds two
-- plain StatusBars (Bars.lua's health/power convention -- no left/right
-- endcap art, spec 0001 §1.2's "one plain StatusBar" deferral noted in
-- Theme.XPBarGeometry above): xpRested behind xp so the rested portion shows
-- past the current-XP fill, matching vanilla's own draw order (xpProgBarRested
-- built before xpProgBar is drawn over it, e17c352 WIIIUI.lua:2113 vs 2190).
local function buildXPBar(anchor, uiScale)
  local rested = WIIIUI.Bars.xpRested
  local bar = WIIIUI.Bars.xp

  if not rested then
    rested = CreateFrame("StatusBar", nil, UIParent)
    rested:SetStatusBarTexture(XP_BAR_TEXTURE)
    WIIIUI.Bars.xpRested = rested
  end

  if not bar then
    bar = CreateFrame("StatusBar", nil, UIParent)
    bar:SetStatusBarTexture(XP_BAR_TEXTURE)
    bar:SetStatusBarColor(XP_BAR_MAIN_COLOR_R, XP_BAR_MAIN_COLOR_G, XP_BAR_MAIN_COLOR_B, 1)

    bar.levelText = bar:CreateFontString(nil, "OVERLAY")
    bar.levelText:SetPoint("CENTER", bar, "CENTER", 0, 0)

    -- The explicit flags are set after the scripts so they win whatever the
    -- scripts imply (SetScript enables the mouse, API_ScriptRegion_EnableMouse
    -- on warcraft.wiki.gg); the bar must not take the portrait's clicks
    -- (spec 0010 Option A).
    bar:SetScript("OnEnter", function(self) showXPTooltip(self) end)
    bar:SetScript("OnLeave", function() GameTooltip:Hide() end)
    bar:SetMouseMotionEnabled(true)
    bar:SetMouseClickEnabled(false)

    WIIIUI.Bars.xp = bar
  end

  -- Text grows with the console above the tuned size, so it is re-applied on
  -- every build (spec 0005).
  WIIIUI.Theme.ApplyFont(bar.levelText, WIIIUI.Theme.ScaledSize(LEVEL_TEXT_FONT_SIZE, uiScale), GameFontHighlightSmall)

  local geometry = WIIIUI.Theme.XPBarGeometry(uiScale)

  -- MergeDefaults resets a malformed colour to the default (spec 0006), so the saved table always holds 4 numbers here.
  local restColor = wc3UI_Options.xpRestedXpColor
  rested:SetStatusBarColor(restColor[1], restColor[2], restColor[3], restColor[4])

  -- Both bars share UIParent, and warcraft.wiki.gg's UI_rendering_process
  -- defines no render order for identical strata+level, so the Layers slots
  -- give the fill a level strictly above the rested overlay.
  WIIIUI.Layers.Apply(rested, "xp.rested")
  WIIIUI.Layers.Apply(bar, "xp.fill")
  for _, xpBar in ipairs({ rested, bar }) do
    xpBar:SetSize(geometry.width, geometry.height)
    xpBar:ClearAllPoints()
    if anchor then
      xpBar:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", geometry.anchorOffsetX, geometry.anchorOffsetY)
    end
  end
end

-- spec 0001 §Event -> widget wiring: "PLAYER_XP_UPDATE, UPDATE_EXHAUSTION,
-- PLAYER_LEVEL_UP | XP bar, rested, level text (XP is not secret, but the
-- update is still wrapped in a pcall)". Not a secret-value guard (XP is never secret, CLAUDE.md "Secret
-- values") -- a plain pcall: degrade, not a decision. It covers a
-- missing UnitXP/UnitXPMax/GetXPExhaustion/UnitClass or a UnitXPMax==0 edge
-- case without taking down the rest of WIIIUI.Layout().
local function updateXP()
  local bar = WIIIUI.Bars.xp
  local rested = WIIIUI.Bars.xpRested
  if not bar or not rested then
    return
  end

  local ok = pcall(function()
    local maxXP = UnitXPMax("player")
    local curXP = UnitXP("player")

    -- At max level UnitXPMax returns 0;
    -- this re-derives a full-bar result for that case (maxXP/curXP both 1,
    -- so the StatusBar's own min/max/value math reads "full") rather than
    -- porting vanilla's own guard, which tested UnitXP()==0 plus a
    -- MAX_LEVEL check (e17c352 WIIIUI.lua:2119-2124) -- a different
    -- condition this port doesn't need, since it avoids requiring an
    -- unverified MAX_LEVEL constant on the target client.
    if maxXP == 0 then
      maxXP = 1
      curXP = 1
    end

    bar:SetMinMaxValues(0, maxXP)
    bar:SetValue(curXP)

    rested:SetMinMaxValues(0, maxXP)

    local restedValue = curXP + (GetXPExhaustion() or 0)
    if restedValue > maxXP then
      restedValue = maxXP
    end
    rested:SetValue(restedValue)

    if bar.levelText then
      local className = UnitClass("player")
      bar.levelText:SetText("Level " .. UnitLevel("player") .. " " .. tostring(className))
    end
  end)

  if ok then
    bar:Show()
    rested:Show()
  else
    bar:Hide()
    rested:Hide()
    if GameTooltip and GameTooltip:GetOwner() == bar then
      GameTooltip:Hide()
    end
  end

  -- IsShown: Hide() need not clear the owner, so ownership alone could re-show
  -- a tooltip after OnLeave. Never take over another frame's tooltip.
  if ok and GameTooltip and GameTooltip:IsShown() and GameTooltip:GetOwner() == bar then
    showXPTooltip(bar)
  end
end

-- Vanilla AlignHealthMana (e17c352 WIIIUI.lua:1987-1992, 2009-2014): both
-- bars anchor to minimapFrame (the minimap art texture, WIIIUI.Console.left.
-- minimapTexture -- see BuildLeft's own citation of this same vanilla
-- naming quirk). Console.BuildLeft/BuildGrid/BuildRight already ran earlier
-- in this same WIIIUI.Layout() call (TOC order; this step registers
-- after Console.BuildRight), so the minimap texture exists by the time this
-- runs.
function WIIIUI.Bars.BuildBars()
  local uiScale = WIIIUI.LayoutUnits()
  local left = WIIIUI.Console.left
  local minimapTexture = left and left.minimapTexture

  local defs = barDefs()
  local slotCount = #defs
  builtSlotCount = slotCount
  local lift = slotCount == 3 and WIIIUI.Theme.DruidLift(uiScale, wc3UI_Options.theme) or 0

  for slotIndex, key in ipairs(defs) do
    local bar = WIIIUI.Bars[key]

    if not bar then
      bar = CreateFrame("StatusBar", nil, UIParent)
      bar:SetStatusBarTexture(BAR_TEXTURE)
      bar.text = bar:CreateFontString(nil, "OVERLAY")
      bar.text:SetPoint("CENTER", bar, "CENTER", 0, 0)

      WIIIUI.Bars[key] = bar
    end

    WIIIUI.Theme.ApplyFont(bar.text, WIIIUI.Theme.ScaledSize(FONT_SIZES[key], uiScale), GameFontHighlightSmall)

    local geometry = WIIIUI.Theme.BarGeometry(uiScale, slotIndex, slotCount, lift)

    -- Same strata as the left console art, so the level must clear it.
    WIIIUI.Layers.Apply(bar, "bars")
    bar:SetSize(geometry.width, geometry.height)
    bar:ClearAllPoints()
    bar:SetPoint("BOTTOMLEFT", minimapTexture, "BOTTOMRIGHT", geometry.offsetX, geometry.offsetY)
  end

  local mana = WIIIUI.Bars.mana
  if slotCount == 3 then
    -- PowerBarColor is a Blizzard global (spec 0002 §4); blue as the fallback.
    local color = PowerBarColor and PowerBarColor.MANA
    if color then
      mana:SetStatusBarColor(color.r, color.g, color.b, 1)
    else
      mana:SetStatusBarColor(0, 0, 1, 1)
    end
    mana:Show()
  else
    if mana then
      mana:Hide()
    end
    WIIIUI.Bars.power:Show()
  end

  WIIIUI.Bars.health:SetStatusBarColor(
    HEALTH_BAR_DEFAULT_COLOR_R,
    HEALTH_BAR_DEFAULT_COLOR_G,
    HEALTH_BAR_DEFAULT_COLOR_B,
    1
  )

  buildXPBar(left and left.portraitTexture, uiScale)

  updateHealth()
  updatePowerBars()
  updateXP()
end

-- spec 0001 §Event -> widget wiring, all via RegisterUnitEvent(event,
-- "player") (WIIIUI.On's unit form). Registered once at file scope, like
-- Core.lua's own ADDON_LOADED/PLAYER_LOGIN/UI_SCALE_CHANGED handlers --
-- BuildBars() itself stays idempotent and event-free, matching Console.lua's
-- Build* convention.
WIIIUI.On("UNIT_HEALTH", updateHealth, "player")
WIIIUI.On("UNIT_MAXHEALTH", updateHealth, "player")
-- UNIT_POWER_FREQUENT alone: same payload as UNIT_POWER_UPDATE, fires on every
-- change and more often while regenerating; registering both repaints twice.
WIIIUI.On("UNIT_POWER_FREQUENT", updatePowerBars, "player")
WIIIUI.On("UNIT_MAXPOWER", updatePowerBars, "player")
WIIIUI.On("UNIT_DISPLAYPOWER", updatePowerBars, "player")
-- No payload, so a plain registration; InfoIcons registers it the same way,
-- and WIIIUI.On rejects one event under two unit filters (spec 0002 §1.2).
WIIIUI.On("UPDATE_SHAPESHIFT_FORM", updatePowerBars)

-- PLAYER_XP_UPDATE/UPDATE_EXHAUSTION/PLAYER_LEVEL_UP are plain RegisterEvent
-- calls, not RegisterUnitEvent, despite this file's other events using the
-- unit form: Blizzard's own XP bar uses plain RegisterEvent for these same
-- three events (Blizzard_StatusTrackingBar/Shared/ExpBar.lua:53,119-121 on
-- the forever branch), matching this port's choice. RegisterUnitEvent isn't
-- restricted to a fixed event list (Blizzard_EditMode/Shared/
-- EditModeManager.lua:65 on live calls RegisterUnitEvent with
-- PLAYER_SPECIALIZATION_CHANGED, a non-UNIT_-prefixed event) -- the reason
-- for RegisterEvent here is simply that none of the three carries a
-- leading unit-token payload the unit form is for: PLAYER_XP_UPDATE's own
-- payload is a unitTarget string, not a leading unit token
-- (PLAYER_XP_UPDATE, warcraft.wiki.gg); UPDATE_EXHAUSTION carries no
-- payload at all (UPDATE_EXHAUSTION, warcraft.wiki.gg); PLAYER_LEVEL_UP's
-- payload leads with `level` (PLAYER_LEVEL_UP, warcraft.wiki.gg). Matches
-- Portrait.lua's PORTRAIT_PLAIN_EVENTS convention for player-scoped events
-- that aren't UNIT_* (e.g. PLAYER_ENTERING_WORLD).
WIIIUI.On("PLAYER_XP_UPDATE", updateXP)
WIIIUI.On("UPDATE_EXHAUSTION", updateXP)
WIIIUI.On("PLAYER_LEVEL_UP", updateXP)

-- spec 0001 §1.1 R3 / CLAUDE.md "Starving StatusTrackingBarManager is not
-- enough on Forever": UnregisterAllEvents() + Hide() the manager itself (a
-- plain frame, not an Edit Mode system) -- never Main/SecondaryStatusTracking
-- BarContainer. Out of combat only, through its own ApplyOrQueue key
-- ("trackingBarStarve", distinct from Core.lua's "retire") -- registered as
-- an additional PLAYER_LOGIN handler (WIIIUI.On's dispatch loop runs every
-- handler registered for an event, Core.lua), the same convention Buttons.lua
-- already uses for its own hearthstone placement, so Bars.lua owns this
-- without editing Core.lua's PLAYER_LOGIN handler body.
local function starveTrackingBars()
  local manager = StatusTrackingBarManager
  if not manager then
    return
  end

  manager:UnregisterAllEvents()
  manager:Hide()
end

WIIIUI.On("PLAYER_LOGIN", function()
  WIIIUI.ApplyOrQueue("trackingBarStarve", starveTrackingBars)
end)

WIIIUI.RegisterBuild("Bars.BuildBars", WIIIUI.Bars.BuildBars, { after = { "Console.BuildRight" } })
