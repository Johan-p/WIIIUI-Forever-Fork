-- spec 0001 §Module split "Theme.lua": theme->path resolution, replacing
-- vanilla WIIIUI.lua's ChangeTheme (e17c352, theme fallback + SetTexture
-- path concatenation).
local _, WIIIUI = ...

WIIIUI.Theme = {}

-- The one theme list, in menu order (spec 0006): the settings schema
-- validates against it and Config builds one button per name.
WIIIUI.Theme.NAMES = { "human", "orc", "undead", "nightelf", "synthwave" }

-- The fork dropped upstream's custom1-custom8 slots (docs/decisions.md,
-- 2026-09-30); a save that still holds one resolves to the default theme.

-- The one owner of draw order (spec 0006). `relative` levels are
-- offsets from Console.left's own frame level: the console art shares its
-- strata with the bars and portrait, so they must clear it explicitly. A slot
-- with no strata leaves the frame's own (inherited) strata alone.
WIIIUI.Layers = {
  SLOTS = {
    ["console.right"] = { strata = "BACKGROUND" },
    ["console.left"] = { strata = "LOW" },
    ["console.grid"] = { strata = "MEDIUM" },
    ["config.hover"] = { strata = "HIGH" },
    ["config.cogwheel"] = { strata = "DIALOG" },
    ["config.panel"] = { strata = "DIALOG" },
    ["portrait.overlay"] = { strata = "LOW", relative = 1 },
    ["portrait.model"] = { strata = "LOW", relative = 2 },
    ["portrait.button"] = { strata = "LOW", relative = 3 },
    bars = { strata = "LOW", relative = 4 },
    ["xp.rested"] = { strata = "LOW", relative = 4 },
    ["xp.fill"] = { strata = "LOW", relative = 5 },
    minimap = { strata = "LOW", level = 1 },
    ["minimap.piece"] = { strata = "LOW", relative = 3 },
    ["infoicon.border"] = { level = 10 },
  },
}

-- Strata first, then level. A parent is applied before its children because
-- SetFrameLevel on a parent shifts the levels of its children.
function WIIIUI.Layers.Apply(frame, slot)
  local entry = WIIIUI.Layers.SLOTS[slot]
  assert(entry, "unknown Layers slot: " .. tostring(slot))

  if entry.strata then
    frame:SetFrameStrata(entry.strata)
  end

  if entry.relative then
    local left = WIIIUI.Console and WIIIUI.Console.left
    frame:SetFrameLevel((left and left:GetFrameLevel() or 1) + entry.relative)
  elseif entry.level then
    frame:SetFrameLevel(entry.level)
  end
end

WIIIUI.Theme.FONT_PATH = "Interface\\Addons\\WIIIUI\\art\\other\\fonts\\blq55.TTF"

-- CLAUDE.md "Tech stack quirks": SetFont returns success on Forever, so the
-- font object goes first as the safety net and is re-applied when SetFont
-- fails or GetFont confirms nothing (FontInstance:SetFontObject/GetFont,
-- warcraft.wiki.gg).
function WIIIUI.Theme.ApplyFont(fontString, size, fallbackObject)
  fontString:SetFontObject(fallbackObject)
  local applied = fontString:SetFont(WIIIUI.Theme.FONT_PATH, size, "")

  if not applied or not fontString:GetFont() then
    fontString:SetFontObject(fallbackObject)
  end
end

-- spec 0005 §Shape: option A lays out in the saved units with no root scale.
-- Returns (layoutUnits, rootScale). Option B (a root scale) was not needed:
-- measured in-game 2026-09-30, so this stays the identity.
function WIIIUI.Theme.SizeSplit(uiScale)
  return uiScale, 1
end

-- Text and the fixed-size text boxes grow past the size the layout was tuned
-- at; 1 up to WIIIUI.UI_SCALE_TUNED_MAX, so saves at 240-270 look unchanged.
function WIIIUI.Theme.ExtraScale(units)
  return math.max(1, units / WIIIUI.UI_SCALE_TUNED_MAX)
end

-- Font sizes are whole points (fractional sizes render soft); at or below the
-- tuned size the base is returned untouched so saved 240-270 layouts don't move.
function WIIIUI.Theme.ScaledSize(base, units)
  local extra = WIIIUI.Theme.ExtraScale(units)
  if extra == 1 then
    return base
  end
  return math.floor(base * extra + 0.5)
end

function WIIIUI.Theme.ResolveThemeName(theme)
  for _, name in ipairs(WIIIUI.Theme.NAMES) do
    if name == theme then
      return theme
    end
  end
  return "orc"
end

-- Brief 0009: a theme listed here draws its own art but is cut to another
-- theme's shapes, so every per-theme geometry lookup (Theme.lua's nudge
-- tables and Console's layout-mode offsets) goes through GeometryTheme.
-- Texture paths never do; they use ResolveThemeName.
WIIIUI.Theme.GEOMETRY_BASE = { synthwave = "human" }

function WIIIUI.Theme.GeometryTheme(theme)
  local resolved = WIIIUI.Theme.ResolveThemeName(theme)
  return WIIIUI.Theme.GEOMETRY_BASE[resolved] or resolved
end

function WIIIUI.Theme.TexturePath(theme, folder, file)
  local resolved = WIIIUI.Theme.ResolveThemeName(theme)
  return "Interface\\Addons\\WIIIUI\\art\\" .. resolved .. "\\" .. folder .. "\\" .. file
end

-- Vanilla AlignMinimap (e17c352 WIIIUI.lua ~1807-1826): minimapFrame is uiScale
-- square; Minimap itself is 0.55 of that, offset from the frame center. Only
-- the unconditional math is ported here; theme/uiScale-threshold branches
-- (e.g. the mail-icon extraAlign stepping) are out of scope.
function WIIIUI.Theme.MinimapGeometry(uiScale)
  return {
    frameSize = uiScale,
    minimapSize = uiScale * 0.55,
    minimapOffsetX = uiScale * -0.189,
    minimapOffsetY = uiScale * -0.20,
    trackingOffsetX = uiScale * 0.14,
    trackingOffsetY = uiScale * -0.34,
  }
end

-- Vanilla AlignPortrait (e17c352 WIIIUI.lua ~1939-1954): portraitFrame is
-- uiScale square, anchored BOTTOMLEFT of minimapFrame's BOTTOMRIGHT with no
-- offset.
function WIIIUI.Theme.PortraitGeometry(uiScale)
  return {
    size = uiScale,
    anchorOffsetX = 0,
    anchorOffsetY = 0,
  }
end

-- Vanilla ModifyPlayerPortrait (e17c352 WIIIUI.lua:1799-1801): the 3D model
-- is a small window, not the whole portrait art -- anchored BOTTOMLEFT to the
-- minimap texture's BOTTOMLEFT at (uiScale*0.86 - (100 - alignX),
-- uiScale*0.10 - (100 - alignY)), uiScale*0.27 + portraitScale square.
function WIIIUI.Theme.PortraitModelGeometry(uiScale, portraitScale, alignX, alignY, lift)
  lift = lift or 0
  local width = uiScale * 0.27 + portraitScale
  return {
    width = width,
    height = width - lift,
    offsetX = uiScale * 0.86 - (100 - alignX),
    offsetY = uiScale * 0.10 + lift - (100 - alignY),
  }
end

-- Vanilla AlignActionBarUIGrid (e17c352 WIIIUI.lua ~2695-2739): the grid
-- frame is uiScale*0.91851 square, anchored BOTTOMLEFT of extensionBackground.
-- Slots 2-4 chain BOTTOMLEFT-to-BOTTOMRIGHT off the previous slot. Only the
-- unconditional numbers are ported here; hideGride (Console.BuildGrid) is
-- frame visibility, not geometry.
function WIIIUI.Theme.GridGeometry(uiScale)
  return {
    size = uiScale * 0.91851,
    originOffsetX = uiScale * 0.2 - uiScale * 0.01666666667,
    originOffsetY = 1,
    slot2OffsetX = uiScale * -0.4518,
    slot3OffsetX = uiScale * -0.4518,
    slot4OffsetX = uiScale * -0.6115 + 2,
  }
end

-- Vanilla AlignMiddleExtension's extensionBackground block (e17c352
-- WIIIUI.lua ~2795-2799, the tail of that function): extensionBackground is
-- uiScale*2.1 wide, uiScale*0.5 tall, anchored BOTTOMLEFT of the portrait's
-- BOTTOMRIGHT. The ext1/ext2/ext3 branchy positioning above it stays out of
-- scope.
function WIIIUI.Theme.ExtensionBackgroundGeometry(uiScale)
  return {
    width = uiScale * 2.1,
    height = uiScale * 0.5,
    offsetX = uiScale * -0.18,
    offsetY = 0,
  }
end

-- Vanilla AlignRightPart, the rightPart_middle/rightPart_left block
-- (e17c352 WIIIUI.lua:3438-3456): rightPart_middle is (uiScale +
-- uiScale*0.01851) wide, uiScale tall, anchored BOTTOMLEFT to
-- actionSlotGrid_4's BOTTOMRIGHT. rightPart_left is uiScale/2 wide, uiScale
-- tall, anchored BOTTOMRIGHT to rightPart_middle's BOTTOMLEFT at
-- rightPart_left:GetWidth()/2 (i.e. uiScale/4) + uiScale*0.1. Per-theme
-- pixel nudges (human -2/-2, orc -1/-1, undead -1/-0, confirmed at
-- WIIIUI.lua:3446-3456) subtract from both offsets; nightelf has no branch
-- in vanilla and any other theme name resolves like TexturePath does (bogus
-- -> orc), so both fall through to the orc/default nudge via
-- GeometryTheme.
local RIGHT_PART_NUDGES = {
  human = { middle = 2, left = 2 },
  orc = { middle = 1, left = 1 },
  undead = { middle = 1, left = 0 },
}

-- Vanilla AlignRightPart, the WIIIUI_rightpartBackground block (e17c352
-- WIIIUI.lua:3495-3497): width is the caller-resolved rightPartWidth
-- (uiScale*2.2 derived default when unset, e17c352 WIIIUI.lua:4545-4546 --
-- resolved by the caller, not here, since the derivation reads
-- wc3UI_Options directly and this function stays a pure uiScale/theme-free
-- calculation like the other *Geometry functions); height is
-- uiScale*0.5578 + moveChatAreaUp; anchored BOTTOMLEFT to rightPart_left's
-- BOTTOMRIGHT at a constant offset of 3,0 (not per-theme, not uiScale-scaled).
function WIIIUI.Theme.RightPartBackgroundGeometry(uiScale, rightPartWidth, moveChatAreaUp)
  return {
    width = rightPartWidth,
    height = uiScale * 0.5578 + moveChatAreaUp,
    offsetX = 3,
    offsetY = 0,
  }
end

-- Vanilla AlignRightPart, the lid block (e17c352 WIIIUI.lua:3485-3493):
-- Wc3_UI_right_lid is uiScale square, anchored BOTTOMLEFT to
-- rightPart_middle's BOTTOMLEFT at offset (uiScale*0.2833333333 -
-- shiftWidth, uiScale*-0.3166 + moveChatAreaUp). shiftWidth subtracts from
-- the x offset for undead only (e17c352 WIIIUI.lua:3486-3488); no branch
-- for any other theme.
local RIGHT_LID_SHIFT_WIDTH_THEMES = {
  undead = true,
}

function WIIIUI.Theme.RightLidGeometry(uiScale, theme, moveChatAreaUp)
  local resolved = WIIIUI.Theme.GeometryTheme(theme)
  local shiftWidth = RIGHT_LID_SHIFT_WIDTH_THEMES[resolved] and uiScale * 0.0185185 or 0

  return {
    size = uiScale,
    offsetX = uiScale * 0.2833333333 - shiftWidth,
    offsetY = uiScale * -0.3166 + moveChatAreaUp,
  }
end

-- Vanilla AlignRightPart, the "Increase the size of the lower right area
-- (chat area)" block (e17c352 WIIIUI.lua:3457-3483): Wc3_UI_bottom_right_
-- top/middle/bottom all anchor BOTTOMLEFT to UIParent's own BOTTOMRIGHT
-- corner (not a WIIIUI frame). Top and bottom are theme-independent.
-- Middle's height carries a human/undead extraHeight term
-- (uiScale*0.022222, e17c352 WIIIUI.lua:3464-3468); the trailing
-- +uiScale*0.0208333 term (e17c352 WIIIUI.lua:3472) is dropped only for
-- human (e17c352 WIIIUI.lua:3476-3478), kept for every other theme.
local CHAT_AREA_EXTRA_HEIGHT_THEMES = {
  human = true,
  undead = true,
}

function WIIIUI.Theme.ChatAreaGeometry(uiScale, theme, moveChatAreaUp)
  local resolved = WIIIUI.Theme.GeometryTheme(theme)
  local extraHeight = CHAT_AREA_EXTRA_HEIGHT_THEMES[resolved] and uiScale * 0.022222 or 0
  local middleHeight = uiScale - uiScale * 0.5 + moveChatAreaUp + extraHeight

  if resolved ~= "human" then
    middleHeight = middleHeight + uiScale * 0.0208333
  end

  return {
    topWidth = uiScale,
    topHeight = uiScale / 4,
    topOffsetX = uiScale * -0.7259,
    topOffsetY = uiScale * 0.5208 + moveChatAreaUp,
    middleWidth = uiScale / 16,
    middleHeight = middleHeight,
    middleOffsetX = uiScale * -0.0625,
    middleOffsetY = 0,
    bottomWidth = uiScale,
    bottomHeight = uiScale / 8,
    bottomOffsetX = uiScale * -0.7259,
    bottomOffsetY = 0,
  }
end

-- Vanilla AlignRightPart, the extension-filler block (e17c352
-- WIIIUI.lua:3496-3550): the 6 filler textures anchor off rightPart_middle
-- (top1/bottom1) then chain off each other's bottom piece (top2/bottom2 off
-- bottom1, top3/bottom3 off bottom2). alignExtraHorizontal
-- (e17c352 WIIIUI.lua:3496-3505) is unconditional uiScale-threshold position
-- math (not a Show/Hide quirk), so it's in scope for "base position": 0
-- below 250, -3 from 250-259, -6 above 259. The Show/Hide toggles guarding
-- filler visibility (e17c352 WIIIUI.lua:3515-3560) and the undead-only
-- re-aligner (e17c352 WIIIUI.lua:3562+) that resizes/repositions these same
-- textures per exact uiScale value are a documented deferral, not
-- built here.
function WIIIUI.Theme.RightFillerGeometry(uiScale, moveChatAreaUp)
  local alignExtraHorizontal = 0

  if uiScale >= 250 and uiScale <= 259 then
    alignExtraHorizontal = -3
  elseif uiScale > 259 then
    alignExtraHorizontal = -6
  end

  return {
    topWidth = uiScale / 2,
    topHeight = uiScale / 4,
    bottomWidth = uiScale / 2,
    bottomHeight = uiScale / 16,

    top1OffsetX = uiScale * -0.09 + alignExtraHorizontal,
    top1OffsetY = uiScale * 0.5206 + moveChatAreaUp,
    bottom1OffsetX = uiScale * -0.03703,
    bottom1OffsetY = 0,

    top2OffsetX = uiScale * 0.2291 + alignExtraHorizontal,
    top2OffsetY = uiScale * 0.5206 + moveChatAreaUp,
    bottom2OffsetX = uiScale * 0.2768,
    bottom2OffsetY = 0,

    top3OffsetX = uiScale * 0.2291 + alignExtraHorizontal,
    top3OffsetY = uiScale * 0.5206 + moveChatAreaUp,
    bottom3OffsetX = uiScale * 0.2768,
    bottom3OffsetY = 0,
  }
end

-- Vanilla AlignHealthMana (e17c352 WIIIUI.lua:1987-1992, 2009-2014): both
-- bars anchor BOTTOMLEFT to minimapFrame's BOTTOMRIGHT (minimapFrame there
-- is Wc3_UI_minimap itself, per Console.lua's BuildLeft's own citation of
-- this same vanilla naming quirk -- the minimap texture, not the left
-- console frame) at uiScale*-0.147, <Y>;
-- width uiScale*0.27, height uiScale*0.03. Y is uiScale*0.07 for the health
-- bar (slot 1) and uiScale*0.02 for the power bar (slot 2) -- a
-- uiScale*0.05 step down per slot, derived from those two known offsets so
-- slotIndex generalizes to a later inserted bar (0002's druid "form" bar,
-- spec 0004 §Phase-boundary) without a new hardcoded constant per bar.
function WIIIUI.Theme.BarGeometry(uiScale, slotIndex, slotCount, lift)
  slotCount = slotCount or 2
  lift = lift or 0
  -- Slots stack from the bottom (spec 0002 §3): r = slots above this one.
  local r = slotCount - slotIndex
  local offsetY = uiScale * 0.02
  if r >= 1 then
    offsetY = offsetY + uiScale * 0.05
  end
  if r >= 2 then
    offsetY = offsetY + lift
  end
  return {
    width = uiScale * 0.27,
    height = uiScale * 0.03,
    offsetX = uiScale * -0.147,
    offsetY = offsetY,
  }
end

-- Art px of 512 by which the druid left art raises the bars' stack, measured
-- from the committed *_druid art by dev/scripts/make_druid_art.py (b1 - b0 per
-- theme). A hand touch-up that changes a theme's pitch must update its value;
-- the in-game check is the link (spec 0002 §3).
WIIIUI.Theme.DRUID_LIFT_PX = { human = 30, orc = 26, undead = 29, nightelf = 28 }

function WIIIUI.Theme.DruidLift(uiScale, theme)
  -- A theme missing a lift entry degrades to no lift rather than erroring.
  return uiScale * (WIIIUI.Theme.DRUID_LIFT_PX[WIIIUI.Theme.GeometryTheme(theme)] or 0) / 512
end

function WIIIUI.Theme.LeftArtFile(base, slotCount)
  if slotCount == 3 then
    return base .. "_druid"
  end
  return base
end

-- Vanilla AlignActionBars (e17c352 WIIIUI.lua:2639-2667): button size and
-- row stacking. row2/row3 stack the multi-bar rows above the bottom row by
-- one button height plus a fixed uiScale-scaled gap each (e17c352
-- WIIIUI.lua:2660, 2665: extraY = actionButton:GetHeight() + uiScale*0.0667,
-- then + actionButton:GetHeight() + uiScale*0.04444); actionButton:GetHeight()
-- there equals size, so the port computes both purely from uiScale rather
-- than reading a built button's height back.
--
-- Column spacing is NOT vanilla's uiScale*0.159259 chain (WIIIUI.lua:2632,
-- 2637): that pitch is 0.6 units/cell wider than the art's cell pitch and the
-- buttons drifted off the last columns. Vanilla hid the drift with
-- per-index nudges (WIIIUI.lua:2540-2574: -3 at 4, +2 at 5, +1 at 10, +1 at
-- 12) tuned by eye at uiScale 240-260; they are replaced by columnOffsetX,
-- each column's centre taken from the grid art itself so it holds at every
-- uiScale. actionslots_grid.tga (512x512) shows 4 cells per tile, centred at
-- x = 39 / 126 / 213 / 300 px (woven lines at 82.5 / 169.7 / 256.5 px), and
-- the next tile starts on the previous tile's 4th cell: columns 1-3 come from
-- tile1, 4-6 from tile2, 7-9 from tile3 and 10-12 from tile4 (its cells 2-4).
-- Tile origins are GridGeometry's own, so the two cannot disagree. Offsets are
-- the button's left edge relative to the grid's left (column centre minus half
-- the button), so column 1 needs no separate origin.
local GRID_ART_CELL_X = { 39, 126, 213, 39, 126, 213, 39, 126, 213, 126, 213, 300 }

function WIIIUI.Theme.ActionButtonGeometry(uiScale)
  local size = uiScale * 0.11111
  local grid = WIIIUI.Theme.GridGeometry(uiScale)
  local artUnit = grid.size / 512
  local tileLeft = { 0 }
  tileLeft[2] = tileLeft[1] + grid.size + grid.slot2OffsetX
  tileLeft[3] = tileLeft[2] + grid.size + grid.slot3OffsetX
  tileLeft[4] = tileLeft[3] + grid.size + grid.slot4OffsetX

  local columnOffsetX = {}
  for column = 1, 12 do
    local tile = column <= 9 and math.floor((column - 1) / 3) + 1 or 4
    columnOffsetX[column] = tileLeft[tile] + GRID_ART_CELL_X[column] * artUnit - size / 2
  end

  return {
    size = size,
    columnOffsetX = columnOffsetX,
    -- A fixed 5 units drifts off its art cell as the art grows past the tuned
    -- size (spec 0005 spike), so it scales with ExtraScale.
    row1OffsetY = 5 * WIIIUI.Theme.ExtraScale(uiScale),
    row2OffsetY = size + uiScale * 0.0667,
    row3OffsetY = size + uiScale * 0.0667 + size + uiScale * 0.04444,
  }
end

-- Vanilla zoomed every action-button icon by uiScale*0.01851 pixels on each
-- side (e17c352 WIIIUI.lua:2585-2592, 1596-1602: zoomInPixels /
-- actionButtonIcon:GetWidth() into SetTexCoord). The icon fills its button, so
-- its width is the button size.
function WIIIUI.Theme.IconZoom(uiScale, buttonSize)
  return uiScale * 0.01851 / buttonSize
end

-- Vanilla AlignXPBar (e17c352 WIIIUI.lua:2094-2113, 2190-2192): the XP bar
-- anchors BOTTOMLEFT to portraitFrame's own BOTTOMLEFT (Console.lua's
-- left.portraitTexture here -- Bars.lua's low-HP overlay already anchors to
-- the same texture) at uiScale*0.23, uiScale*0.3. Vanilla builds the bar
-- from three endcap-plus-middle textures scaled by xpScaling=0.375; this
-- port's XP bar is one plain StatusBar (Bars.lua's health/power bar
-- convention, no left/right endcap art).
-- width is the real vanilla fill-texture max width, xpProgBarMax =
-- uiScale*0.6814 (e17c352 WIIIUI.lua:3828, 4539) -- the COMBINED width of
-- left+middle+right endcap segments (uiScale*0.375*(0.05924+1.70+0.05924)),
-- not just the middle piece's own uiScale*1.70*0.375, which rendered ~6.9%
-- narrower than intended. The progress fill's own height
-- (uiScale*0.083, WIIIUI.lua:2113) is unchanged.
function WIIIUI.Theme.XPBarGeometry(uiScale)
  return {
    width = uiScale * 0.375 * (0.05924 + 1.70 + 0.05924),
    height = uiScale * 0.083,
    anchorOffsetX = uiScale * 0.23,
    anchorOffsetY = uiScale * 0.3,
  }
end

function WIIIUI.Theme.RightPartGeometry(uiScale, theme)
  local nudge = RIGHT_PART_NUDGES[WIIIUI.Theme.GeometryTheme(theme)] or { middle = 0, left = 0 }
  local leftWidth = uiScale / 2

  return {
    middleWidth = uiScale + uiScale * 0.01851,
    middleHeight = uiScale,
    middleOffsetX = uiScale * -0.2479 - nudge.middle,
    middleOffsetY = -1,
    leftWidth = leftWidth,
    leftHeight = uiScale,
    leftOffsetX = leftWidth / 2 + uiScale * 0.1 - nudge.left,
    leftOffsetY = 0,
  }
end

-- Vanilla AlignWeaponFrame (e17c352 WIIIUI.lua:2258-2281, 2297, 2365): the
-- weapon-icon frame is (xpBarLeft+xpBarMiddle+xpBarRight width)*0.17 square,
-- anchored BOTTOMLEFT to xpBarLeft's own BOTTOMLEFT at (1, uiScale*-0.14),
-- offset per slot (slot 2: +uiScale*0.3607 X; slot 3: +uiScale*0.3607 X,
-- -uiScale*0.1412 Y). This port's XP bar is one plain StatusBar anchored at
-- XPBarGeometry's own anchorOffsetX/Y off left.portraitTexture
-- (Bars.lua's buildXPBar) -- its BOTTOMLEFT is the same point vanilla's
-- xpBarLeft (the bar's own left endcap) anchored from, so InfoIcons.lua
-- anchors weapon icons to that same StatusBar instead of a separate
-- xpBarLeft frame. Size reuses XPBarGeometry's total width, which is
-- already the combined left+middle+right span (see above). Label/value
-- text offsets port weaponDamageText/weaponNumbersText's own anchors
-- (BOTTOMLEFT to the icon frame's TOPLEFT); extraSpace/the uiScale<=210
-- nudge are the exact vanilla thresholds, kept even though the uiScale range
-- floor (Core.lua, 240) makes the <=210 branch unreachable today.
local WEAPON_ICON_SLOT_OFFSETS = {
  { x = 0, y = 0 },
  { x = 0.3607, y = 0 },
  { x = 0.3607, y = -0.1412 },
}

function WIIIUI.Theme.WeaponIconGeometry(uiScale, slotIndex)
  local slotOffset = WEAPON_ICON_SLOT_OFFSETS[slotIndex] or WEAPON_ICON_SLOT_OFFSETS[1]
  local extraSpace = uiScale <= 250 and 1 or 0
  local lowScaleNudge = uiScale <= 210 and -3 or 0
  local labelOffsetXFraction = 0.1294

  return {
    size = WIIIUI.Theme.XPBarGeometry(uiScale).width * 0.17,
    offsetX = 1 + uiScale * slotOffset.x,
    offsetY = uiScale * -0.14 + uiScale * slotOffset.y,
    labelOffsetX = uiScale * labelOffsetXFraction,
    labelOffsetY = uiScale * -0.065,
    valueOffsetX = uiScale * labelOffsetXFraction,
    valueOffsetY = uiScale * -0.1667 - extraSpace + lowScaleNudge,
    -- Label/value FontStrings had
    -- no SetWidth, so a long value (e.g. a high main-hand damage range) could
    -- visually run into slot 2/3's icon, which sits only
    -- WEAPON_ICON_SLOT_OFFSETS[2].x * uiScale to the right of slot 1's icon
    -- (0.3607). Vanilla used a flat SetWidth(100) regardless of uiScale
    -- (e17c352 WIIIUI.lua:2293, 2367); at this port's uiScale floor (240,
    -- Core.lua's clamp) that constant is already wider than the gap to the
    -- next icon's own label start, so porting it unchanged would still
    -- overlap. This constrains to the actual horizontal room before the next
    -- icon's label begins (next icon's X offset minus this label's own X
    -- offset, both in uiScale fractions).
    labelWidth = uiScale * (WEAPON_ICON_SLOT_OFFSETS[2].x - labelOffsetXFraction),
  }
end

--- WIIIUI.Theme.ArmorIconGeometry (spec 0001 §Phased plan "F. Info icons"
--- F2; vanilla AlignArmorFrame, e17c352 WIIIUI.lua:2407-2426): one permanent
--- icon, not a 3-slot row -- armorIconFrame anchored BOTTOMLEFT to
--- xpBarLeft's own BOTTOMLEFT at (1, uiScale*-0.280), one row below
--- WeaponIconGeometry's own row (uiScale*-0.14), same size formula (17% of
--- the XP bar's total width, e17c352 WIIIUI.lua:2414). Label/value anchor
--- TOPLEFT off the icon frame with the armor row's own vanilla offsets
--- (0.14 X; -0.065 / -0.1111111111111 Y, same <=210 low-scale nudge as
--- WeaponIconGeometry, e17c352 WIIIUI.lua:2434, 2449). No labelWidth here:
--- unlike the 3 weapon slots there's no neighbour icon to its right to
--- overlap into, so InfoIcons.lua keeps vanilla's own flat SetWidth(100)
--- (e17c352 WIIIUI.lua:2438, 2444) directly, matching this geometry
--- function's own "pure uiScale-fraction position math" scope.
function WIIIUI.Theme.ArmorIconGeometry(uiScale)
  local lowScaleNudge = uiScale <= 210 and -3 or 0

  return {
    size = WIIIUI.Theme.XPBarGeometry(uiScale).width * 0.17,
    offsetX = 1,
    offsetY = uiScale * -0.280,
    labelOffsetX = uiScale * 0.14,
    labelOffsetY = uiScale * -0.065,
    valueOffsetX = uiScale * 0.14,
    valueOffsetY = uiScale * -0.1111111111111 + lowScaleNudge,
  }
end

-- Vanilla Minimap_ActionButtons's per-theme resize (e17c352 WIIIUI.lua:
-- 1547-1568): only the orc/human/undead/nightelf branches set a delta; any
-- other theme name (GeometryTheme folds unknown names to orc before this
-- table is consulted) falls through with all three deltas at 0.
local MINIMAP_SLOT_NUDGES = {
  orc = { resize = 3, width = 2, height = 1 },
  human = { resize = 4, width = 2, height = 2 },
  undead = { resize = 4, width = 2, height = 2 },
  nightelf = { resize = 4, width = 2, height = 2 },
}

-- Vanilla Minimap_ActionButtons (e17c352 WIIIUI.lua:1536-1607): number =
-- 1-3, square at uiScale*0.08518 minus the per-theme resize, anchored
-- BOTTOMLEFT to Minimap's own BOTTOMRIGHT at (uiScale*0.01851 + addWidth,
-- uiScale*0.455555 - (number-1)*(uiScale*0.08518) - floor(number*0.34) +
-- addHeight). Ported relative to `minimapTexture`'s CENTER instead of the
-- live Minimap widget (spec 0001: "never anchor to Blizzard's
-- Minimap widget itself" -- a secure button anchored to it would make
-- Minimap implicitly protected in combat, warcraft.wiki.gg
-- Patch_2.0.1/API_changes + API_ScriptRegion_IsProtected)
-- by folding in Minimap's own CENTER-relative offset from Blizzard.lua's
-- BuildMinimap (this file's own MinimapGeometry) -- Minimap's BOTTOMRIGHT,
-- in minimapTexture-CENTER-relative coordinates, is
-- (minimapOffsetX + minimapSize/2, minimapOffsetY - minimapSize/2).
local function minimapSlotGeometry(uiScale, theme, number)
  local resolved = WIIIUI.Theme.GeometryTheme(theme)
  local nudge = MINIMAP_SLOT_NUDGES[resolved] or { resize = 0, width = 0, height = 0 }
  local minimap = WIIIUI.Theme.MinimapGeometry(uiScale)
  local minimapRight = minimap.minimapOffsetX + minimap.minimapSize / 2
  local minimapBottom = minimap.minimapOffsetY - minimap.minimapSize / 2

  return {
    kind = "minimap",
    size = uiScale * 0.08518 - nudge.resize,
    point = "BOTTOMLEFT",
    relativeKey = "minimapTexture",
    relativePoint = "CENTER",
    offsetX = minimapRight + uiScale * 0.01851 + nudge.width,
    offsetY = minimapBottom + uiScale * 0.455555
      - (number - 1) * (uiScale * 0.08518) - math.floor(number * 0.34) + nudge.height,
  }
end

-- Vanilla InventorySlots's zigzag column/row sequence for inventoryNumber
-- 1-6 (e17c352 WIIIUI.lua:2814-2875): the loop's own SetPoint call uses
-- column/row *before* that same iteration mutates them, so slot i actually
-- positions at the pair left over from slot i-1 -- traced by hand into this
-- static table rather than re-implementing the mutating loop.
local INVENTORY_SLOT_GRID = {
  { col = 0, row = 0 },
  { col = 1, row = 0 },
  { col = 1, row = 1 },
  { col = 0, row = 1 },
  { col = 1, row = 2 },
  { col = 0, row = 2 },
}

-- Vanilla InventorySlots (e17c352 WIIIUI.lua:2814-2875) + AlignInventorySlots
-- (WIIIUI.lua:2809-2812): each button anchors BOTTOMLEFT to the
-- WIIIUI_inventorySlots frame's CENTER at (column*(uiScale*0.156)-(1-column),
-- row*(uiScale*0.148)); that frame is itself a 1x1-pixel frame (e17c352
-- WIIIUI.xml:3313-3314) anchored BOTTOMLEFT to rightPart_middle at
-- (uiScale*0.02, uiScale*0.016). Ported directly onto rightPartMiddle per
-- spec 0001 ("Inventory six: anchor to Console.right.
-- rightPartMiddle"), folding in both offsets plus the 1x1 frame's own
-- half-pixel CENTER-vs-BOTTOMLEFT difference (0.5, 0.5).
local function inventorySlotGeometry(uiScale, inventoryNumber)
  local grid = INVENTORY_SLOT_GRID[inventoryNumber]
  local columnOffset = (grid.col == 1) and (uiScale * 0.156) or -1

  return {
    kind = "inventory",
    size = uiScale * 0.1185185,
    point = "BOTTOMLEFT",
    relativeKey = "rightPartMiddle",
    relativePoint = "BOTTOMLEFT",
    offsetX = uiScale * 0.02 + 0.5 + columnOffset,
    offsetY = uiScale * 0.016 + 0.5 + grid.row * (uiScale * 0.148),
  }
end

-- spec 0001: one geometry entry point for the 9 extra slots
-- (WIIIUI_Extra1..9 -- Buttons.lua's EXTRA_SLOT_BASE order, minimap 1-3 then
-- inventory 1-6, matching vanilla Bindings.xml's own ordering and Core.lua's
-- BINDING_NAME_CLICK strings). Returns nil for an out-of-range index.
function WIIIUI.Theme.ExtraSlotGeometry(uiScale, theme, i)
  if i >= 1 and i <= 3 then
    return minimapSlotGeometry(uiScale, theme, i)
  elseif i >= 4 and i <= 9 then
    return inventorySlotGeometry(uiScale, i - 3)
  end
  return nil
end

-- spec 0007 §3.5: every offset is relative to minimapTexture's CENTER, in the
-- layout units, so the pieces follow the console through resize and the
-- centring modes. Mail continues the art's side column onto its fourth square
-- (the extras' rule, nudges included); tracking is vanilla's own centre, which
-- lands in the art's round hole in all four themes (spec 0007 §1.5).
function WIIIUI.Theme.MinimapPieceGeometry(uiScale, theme)
  local m = WIIIUI.Theme.MinimapGeometry(uiScale)
  local top = m.minimapOffsetY + m.minimapSize / 2
  local bottom = m.minimapOffsetY - m.minimapSize / 2
  local right = m.minimapOffsetX + m.minimapSize / 2
  local left = m.minimapOffsetX - m.minimapSize / 2

  return {
    mail = minimapSlotGeometry(uiScale, theme, 4),
    tracking = {
      point = "CENTER",
      relativePoint = "CENTER",
      offsetX = m.trackingOffsetX,
      offsetY = m.trackingOffsetY,
      size = uiScale * 0.07,
    },
    zone = {
      point = "CENTER",
      relativePoint = "CENTER",
      offsetX = m.minimapOffsetX,
      offsetY = top + uiScale * 0.03,
      width = m.minimapSize,
    },
    clock = {
      point = "BOTTOM",
      relativePoint = "CENTER",
      offsetX = m.minimapOffsetX,
      offsetY = bottom + uiScale * 0.01,
      width = m.minimapSize,
    },
    calendar = {
      point = "TOPRIGHT",
      relativePoint = "CENTER",
      offsetX = right - uiScale * 0.01,
      offsetY = top - uiScale * 0.01,
      size = uiScale * 0.075,
    },
    -- spec 0011: clear of the top bar and the tallest left ornament, the same
    -- for every theme (the art above the map is transparent).
    dayNight = {
      point = "BOTTOMLEFT",
      relativePoint = "CENTER",
      offsetX = left,
      offsetY = top + uiScale * 0.125,
      size = uiScale * 0.075,
    },
  }
end
