-- spec 0001 §Module split "Customizer.lua": the Customize tab (last phase;
-- overrides-only storage). §Customizer (decision 17, amended 2026-09-29):
-- "an explicit, static registry ... keyed by WIIIUI table path IDs ...
-- rather than frame names." Every entry below is one of the 57 IDs the
-- amendment's own Contents table lists, mapped 1:1 onto what the modules
-- actually built (Console.lua/Bars.lua/Portrait.lua/Buttons.lua/
-- InfoIcons.lua) -- no naming pass, no edit to any of those files.
local _, WIIIUI = ...

WIIIUI.Customizer = WIIIUI.Customizer or {}

-- spec 0001 §Customizer: "WIIIUI.registry is this list; the parent
-- guardrail reads it." Top-level WIIIUI field (not WIIIUI.Customizer.*) --
-- named exactly as the spec cites it, since the parent guardrail depends on this name.
local registry = {}
local registryById = {}

local function addEntry(id, kind, opts)
  local entry = { id = id, kind = kind }
  if opts then
    entry.secure = opts.secure
    entry.backdrop = opts.backdrop
    entry.combatToggled = opts.combatToggled
  end
  registry[#registry + 1] = entry
  registryById[id] = entry
end

-- frame kind (Contents table row 1-2, "Portrait.model"): Console.lua's three
-- art-root frames, Bars.lua's four StatusBar frames, Portrait.lua's
-- PlayerModel. Bars.xp/Bars.xpRested carry combatToggled = true (spec 0001
-- §Customizer "Combat and implicit protection", second round): Bars.lua
-- Show()s/Hide()s them from an event handler outside ApplyOrQueue, so a
-- customizer edit that made either implicitly protected would lock in
-- combat. Console.right is NOT flagged: its own Show/Hide (Console.lua)
-- runs inside Layout, which is always out of combat.
addEntry("Console.left", "frame")
addEntry("Console.grid", "frame")
addEntry("Console.right", "frame")
addEntry("Bars.health", "frame")
-- Bars.power and Bars.mana are Show()n/Hide()n by Bars.lua's middle-bar
-- gate from an event handler (spec 0002 §1); only power is toggled by it, but
-- mana is hidden by Layout when the toggle turns off, which is out of combat.
addEntry("Bars.power", "frame", { combatToggled = true })
addEntry("Bars.mana", "frame")
addEntry("Bars.xp", "frame", { combatToggled = true })
addEntry("Bars.xpRested", "frame", { combatToggled = true })
addEntry("Portrait.model", "frame")

-- button/secure (Contents table row 5): the portrait's secure unit button
-- and the 9 LibActionButton-1.0 extra slots. "secure entries offer no
-- ParentOf and no Hide field" (§Customizer Fields) -- WIIIUI.Customizer.
-- Fields, below, is what actually withholds those two fields; `secure = true`
-- here is the one flag that drives it.
addEntry("Portrait.button", "button", { secure = true })
for i = 1, 9 do
  addEntry("Buttons.extras." .. i, "button", { secure = true })
end

-- texture kind (Contents table row 6): Console.lua's art textures, derived
-- from its declared piece tables (WIIIUI.Console.ART) in declaration order.
-- The region list is explicit and static, never a walk over the frames'
-- children, so the registry order stays deterministic.
for _, region in ipairs({ "left", "grid", "right" }) do
  for _, piece in ipairs(WIIIUI.Console.ART[region]) do
    addEntry("Console." .. region .. "." .. piece.key, "texture")
  end
end

-- fontstring kind (Contents table row 7): the two bar texts, the XP bar's
-- level text, and each of the 4 InfoIcons slots' label/value pair.
addEntry("Bars.health.text", "fontstring")
addEntry("Bars.power.text", "fontstring")
addEntry("Bars.mana.text", "fontstring")
addEntry("Bars.xp.levelText", "fontstring")

-- InfoIcons.lua's 3 weapon slots (numeric keys) plus the armor slot (string
-- key "armor", ensureIconWidgets' own WIIIUI.InfoIcons["armor"] convention).
-- frame + border (backdrop = true, the "today, the four InfoIcons borders"
-- Backdrop-field exception) + label/value fontstrings, per slot. Only
-- ".frame" carries combatToggled = true (spec 0001 §Customizer "Combat and
-- implicit protection", second round: "Bars.xp, Bars.xpRested, and
-- InfoIcons.1.frame, .2.frame, .3.frame and .armor.frame") -- ".border" is
-- InfoIcons.lua's RefreshSlot backdrop rewrite, never shown/hidden/
-- reparented itself.
local INFO_ICON_SLOTS = { "1", "2", "3", "armor" }
for _, slot in ipairs(INFO_ICON_SLOTS) do
  addEntry("InfoIcons." .. slot .. ".frame", "frame", { combatToggled = true })
  addEntry("InfoIcons." .. slot .. ".border", "frame", { backdrop = true })
  addEntry("InfoIcons." .. slot .. ".label", "fontstring")
  addEntry("InfoIcons." .. slot .. ".value", "fontstring")
end

-- spec 0007 §6: plain frame, no flag -- Show/Hide happens only inside Layout
-- and the events only recolour, so it isn't combatToggled.
addEntry("MinimapPieces.mail", "frame")
addEntry("MinimapPieces.tracking", "frame")
addEntry("MinimapPieces.zone", "frame")
addEntry("MinimapPieces.zone.text", "fontstring")
addEntry("MinimapPieces.clock", "frame")
addEntry("MinimapPieces.clock.text", "fontstring")
addEntry("MinimapPieces.calendar", "frame", { secure = true })
addEntry("MinimapPieces.dayNight", "frame")

WIIIUI.registry = registry
WIIIUI.Customizer.byId = registryById

-- spec 0001 §Customizer "Combat and implicit protection" (second round): the
-- fixed set of combatToggled ids, computed once so applyEntry's protection
-- check (below) doesn't re-walk the whole registry on every entry.
local combatToggledIds = {}
for _, entry in ipairs(registry) do
  if entry.combatToggled then
    combatToggledIds[#combatToggledIds + 1] = entry.id
  end
end

-- spec 0001 §Customizer: "WIIIUI.Customizer.Resolve(id) splits the ID on '.'
-- and walks down from the WIIIUI table. A numeric segment is tried as a
-- number first (InfoIcons.1 -> WIIIUI.InfoIcons[1], Buttons.extras.3 ->
-- WIIIUI.Buttons.extras[3]). If any step is missing, it returns nil, and the
-- entry is skipped rather than raising an error." Walking from WIIIUI itself
-- (not a special-cased first segment) works uniformly because every module
-- (Console, Bars, Portrait, Buttons, InfoIcons) is itself a plain field on
-- WIIIUI -- "Console.left" is just a two-segment walk, same as any other id.
function WIIIUI.Customizer.Resolve(id)
  local current = WIIIUI

  for segment in id:gmatch("[^.]+") do
    if type(current) ~= "table" then
      return nil
    end

    local value
    local numeric = tonumber(segment)

    if numeric ~= nil and current[numeric] ~= nil then
      value = current[numeric]
    else
      value = current[segment]
    end

    if value == nil then
      return nil
    end

    current = value
  end

  return current
end

-- spec 0001 §Customizer "Fields": the field list a kind offers. Declared as
-- flat arrays (not a set) so WIIIUI.Customizer.Fields below can return them
-- in a stable, spec-ordered sequence -- the editor renders one row per field
-- in this order.
local BASE_FIELDS = { "ParentPosOf", "Point", "RelativePoint", "PosX", "PosY", "Width", "Height", "Transparency" }
local NON_SECURE_FIELDS = { "ParentOf", "Hide" }
local FRAME_FIELDS = { "FrameStrata", "FrameLevel" }
local BACKDROP_FIELDS = { "Backdrop" }
local TEXTURE_FIELDS = { "Texture", "SetDrawLayer", "TexCoordLeft", "TexCoordRight", "TexCoordTop", "TexCoordBottom" }

-- spec 0001 §Customizer "Fields": "every kind: ...; every non-secure kind:
-- ParentOf, Hide; frame and button: FrameStrata, FrameLevel; Backdrop: only
-- where the object has SetBackdrop ...; texture kind: Texture, SetDrawLayer,
-- TexCoordLeft/Right/Top/Bottom; secure entries offer no ParentOf and no
-- Hide field." acceptance criterion (g) reads this list directly.
function WIIIUI.Customizer.Fields(entry)
  local fields = {}

  for _, f in ipairs(BASE_FIELDS) do
    fields[#fields + 1] = f
  end

  if not entry.secure then
    for _, f in ipairs(NON_SECURE_FIELDS) do
      fields[#fields + 1] = f
    end
  end

  if entry.kind == "frame" or entry.kind == "button" then
    for _, f in ipairs(FRAME_FIELDS) do
      fields[#fields + 1] = f
    end
  end

  if entry.backdrop then
    for _, f in ipairs(BACKDROP_FIELDS) do
      fields[#fields + 1] = f
    end
  end

  if entry.kind == "texture" then
    for _, f in ipairs(TEXTURE_FIELDS) do
      fields[#fields + 1] = f
    end
  end

  return fields
end

--------------------------------------------------------------------------
-- Apply
--------------------------------------------------------------------------

-- spec 0001 §Customizer "Apply" (amended 2026-09-29, second round): "revert,
-- then re-apply" replaces the old "Layout re-applies anchor and size, only
-- parent/strata/... need a baseline" model, which was false as built
-- (several objects -- Console.right, Bars.xp.levelText, Bars.health/power.text,
-- the InfoIcons label/value heights -- are anchored/sized only when created). One rule
-- covers every field the same way: "Just before Apply writes a field on an
-- object, it records the object's current value in the module-local
-- baseline[id], which is never saved." Module-local, not on WIIIUI or
-- wc3UI_Options -- session-only restore state, the same convention Core.lua's
-- own ApplyOrQueue pending/order upvalues use. baseline[id].captured[field]
-- disambiguates "not yet captured" from a legitimately falsy captured value
-- (0, false, an unset "" texture path).
local baseline = {}

-- Reverting must
-- undo mutations in the REVERSE of the order they were applied -- two
-- mutual ParentPosOf overrides (each anchored to the other's post-apply
-- object) revert safely only in that order; pairs(baseline) gives no
-- ordering guarantee at all and can hit WoW's real "Cannot anchor to a
-- region dependent on it" SetPoint error mid-Revert(). captureOrder records
-- each id once, the first time capture() opens its baseline record for that
-- id -- i.e. in first-applied order, so Revert() below can walk it
-- last-to-first.
local captureOrder = {}

local function capture(id, key, value)
  local data = baseline[id]
  if not data then
    data = { captured = {} }
    baseline[id] = data
    captureOrder[#captureOrder + 1] = id
  end
  if not data.captured[key] then
    data.captured[key] = true
    data[key] = value
  end
end

-- Recorded
-- (never saved) the same way lastErrors already records Apply()'s own
-- per-entry pcall failures, so a revertOne failure -- in Revert() below or
-- in revertEntry() -- is never completely silent. Reset at the start of
-- every Revert() call, the same convention lastErrors uses at the start of
-- every Apply() call.
WIIIUI.Customizer.lastRevertErrors = {}

-- revertEntry (Apply()'s per-entry pcall failure branch) is always called
-- for the entry Apply() is CURRENTLY processing, and Apply() always calls
-- Revert() (which empties captureOrder) before its loop starts, so in
-- practice this id is always the last element. Removed by value anyway,
-- not by assuming that position, since a future revertEntry call site (or a
-- change to Apply()'s own Revert()-first guarantee) could make that
-- assumption false.
local function removeFromCaptureOrder(id)
  for i, capturedId in ipairs(captureOrder) do
    if capturedId == id then
      table.remove(captureOrder, i)
      return
    end
  end
end

-- Shared write-back for one object's captured baseline -- every key is an
-- independent restore, so order doesn't matter. Used by both
-- WIIIUI.Customizer.Revert() (the whole session baseline) and
-- revertEntry() below (one entry's rollback-on-error, spec 0001 §Customizer
-- "Apply": "An entry that errors is rolled back to its uncustomized state").
local function revertOne(id, data)
  local obj = WIIIUI.Customizer.Resolve(id)
  if not obj then
    return
  end

  local c = data.captured

  if c.parent then
    obj:SetParent(data.parent)
  end
  if c.points then
    obj:ClearAllPoints()
    for _, p in ipairs(data.points) do
      obj:SetPoint(p[1], p[2], p[3], p[4], p[5])
    end
  end
  if c.width then
    obj:SetWidth(data.width)
  end
  if c.height then
    obj:SetHeight(data.height)
  end
  if c.texture then
    obj:SetTexture(data.texture)
  end
  if c.frameStrata then
    obj:SetFrameStrata(data.frameStrata)
  end
  if c.frameLevel then
    obj:SetFrameLevel(data.frameLevel)
  end
  if c.transparency then
    obj:SetAlpha(data.transparency)
  end
  if c.drawLayer then
    obj:SetDrawLayer(data.drawLayer[1], data.drawLayer[2])
  end
  if c.texCoord then
    local tc = data.texCoord
    obj:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
  end
  if c.backdrop then
    obj:SetBackdrop(data.backdrop)
  end
end

-- spec 0001 §Customizer "Apply": "An entry that errors is rolled back to its
-- uncustomized state (the per-entry part of Revert, below) ... The pcall
-- rollback then reverts this entry, which puts the graph back in the state
-- from before the entry, and that state had passed the check." Narrower
-- than WIIIUI.Customizer.Revert(): only this one id's baseline, so a failed
-- entry doesn't undo fields already written by earlier entries in the same
-- Apply() loop.
-- Wrapped the
-- same way Revert()'s own loop below is, for the same reason -- a bad
-- revertOne here can't wedge this specific rollback path either. Doesn't
-- change the caller's contract: baseline[id]/captureOrder are still cleared
-- unconditionally, so a failed revert here still can't leave a stale
-- baseline entry behind for a later Revert() to trip over.
local function revertEntry(id)
  local data = baseline[id]
  if not data then
    return
  end
  local ok, err = pcall(revertOne, id, data)
  if not ok then
    WIIIUI.Customizer.lastRevertErrors[id] = err
  end
  baseline[id] = nil
  removeFromCaptureOrder(id)
end

-- spec 0001 §Customizer "Apply", second round: "WIIIUI.Customizer.Revert()
-- writes back every value the customizer wrote since the last revert, then
-- empties the session baseline." Registered with first = true, so WIIIUI.Layout()
-- runs it before every other step, and called first in Apply() itself -- when Layout
-- already reverted, the second call finds an empty baseline and does
-- nothing.
--
-- Walks
-- captureOrder LAST to FIRST -- the exact reverse of the order Apply()
-- captured (== applied) each id -- so a set of mutual anchor overrides
-- unwinds in the same order a real anchor graph mutation must: undo the
-- most recent change first. Each revertOne is its own pcall so one bad
-- entry (any cause, not only ordering) can never leave baseline/
-- captureOrder non-empty -- Revert() is the unprotected first line of
-- WIIIUI.Layout(), so a stuck entry there would otherwise fail identically
-- on every later Layout() call until /reload.
-- Console's anchor companions mirror the textures' live points and size
-- (Console.lua "Anchor companions"), so they are re-mirrored whenever the
-- customizer changes or restores a texture.
local function syncConsoleAnchors()
  if WIIIUI.Console and WIIIUI.Console.SyncAnchors then
    return WIIIUI.Console.SyncAnchors()
  end
  return true
end

-- Raising variant for applyEntry: a companion that cannot mirror an override
-- (an anchor cycle) rolls that entry back through Apply's own pcall.
local function syncConsoleAnchorsOrRaise()
  local ok, err = syncConsoleAnchors()
  if not ok then
    error("Customizer: companion anchor sync failed: " .. tostring(err), 0)
  end
end

function WIIIUI.Customizer.Revert()
  WIIIUI.Customizer.lastRevertErrors = {}

  for i = #captureOrder, 1, -1 do
    local id = captureOrder[i]
    local data = baseline[id]
    if data then
      local ok, err = pcall(revertOne, id, data)
      if not ok then
        WIIIUI.Customizer.lastRevertErrors[id] = err
      end

      -- A reverted texture's companion must follow before the next entry
      -- reverts: a secure frame put back on that companion would otherwise
      -- meet a companion still mirroring the override, possibly anchored back
      -- onto that same frame -- a cycle the client rejects.
      syncConsoleAnchors()
    end
  end

  baseline = {}
  captureOrder = {}
end

-- spec 0001 §Customizer "Apply": "Each entry is wrapped in its own pcall, so
-- a bad saved value skips that entry and never aborts Layout." Recorded here
-- (never saved, id -> error message, reset at the start of every Apply()
-- call) so a future debug session -- or a later editor polish pass -- can
-- surface which entries are currently failing, and so the headless tests can prove an entry was actually skipped via a pcall
-- failure, not merely absent for an unrelated reason.
WIIIUI.Customizer.lastErrors = {}

local EMPTY_OVERRIDES = {}

local VALID_POINTS = {
  TOPLEFT = true, TOP = true, TOPRIGHT = true,
  LEFT = true, CENTER = true, RIGHT = true,
  BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
}

local ANCHOR_FIELDS = { "Point", "ParentPosOf", "RelativePoint", "PosX", "PosY" }
local TEXCOORD_FIELDS = { "TexCoordLeft", "TexCoordRight", "TexCoordTop", "TexCoordBottom" }

local function anyFieldSet(overrides, fields)
  for _, f in ipairs(fields) do
    if overrides[f] ~= nil then
      return true
    end
  end
  return false
end

local CHAIN_HOPS = 12

local function isRegionObject(object)
  local objectType = object.GetObjectType and object:GetObjectType()
  return objectType == "Texture" or objectType == "FontString"
end

-- Does following `object`'s first anchor upward reach a Texture/FontString?
local function anchorChainHitsRegion(object)
  local current = object

  for _ = 1, CHAIN_HOPS do
    local _, relativeTo = current:GetPoint(1)
    if not relativeTo then
      return false
    end
    if isRegionObject(relativeTo) then
      return true
    end
    current = relativeTo
  end

  return false
end

-- ParentPosOf accepts any registry object (a texture is a perfectly good
-- anchor reference) or the literal "UIParent".
local function resolveAnchorTarget(value)
  if value == "UIParent" then
    return UIParent
  end
  if not registryById[value] then
    return nil
  end
  return WIIIUI.Customizer.Resolve(value)
end

-- ParentOf (an actual SetParent target) is narrower: "a texture cannot be a
-- parent" (§Customizer "Parent of / Parent position of") -- only a
-- frame/button registry entry, or "UIParent".
local function resolveParentOfTarget(value)
  if value == "UIParent" then
    return UIParent
  end
  local entry = registryById[value]
  if not entry or (entry.kind ~= "frame" and entry.kind ~= "button") then
    return nil
  end
  return WIIIUI.Customizer.Resolve(value)
end

-- spec 0001 §Customizer "Parent of / Parent position of": a value
-- outside the registry (or of the wrong kind) is never an error -- it falls
-- back to UIParent with a warning. SetOverride (below) is the normal
-- catcher and stores "UIParent" instead; this Apply-time path only matters
-- for a bad value that reached the saved table another way (a hand edit),
-- where Apply must still never write the saved table. lastWarnings is
-- recorded the way lastErrors is (never saved, reset every Apply, keyed
-- id.."."..field so ParentOf and ParentPosOf on one id don't collide), so
-- SetOverride can surface each new one once.
WIIIUI.Customizer.lastWarnings = {}

-- Registry membership + kind only, deliberately not Resolve(): a valid id
-- whose object does not exist yet is Apply's fallback to handle, never a
-- reason to overwrite what the user typed. Returns nil (fine), "unknown" or
-- "texture" (a valid id, wrong kind for ParentOf).
--
-- A protected frame cannot anchor to a region ("Cannot anchor protected frames
-- to regions", in-game error on Forever 1.60.1), so a secure entry's
-- ParentPosOf is also a "texture" problem when it names a texture entry. This
-- static check is only the store-time catcher; applyAnchor repeats it against
-- the object's live IsProtected(), which also covers the implicitly protected
-- frames (Console.grid/left/right) a secure frame anchors to.
local function targetProblem(id, field, value)
  if field ~= "ParentOf" and field ~= "ParentPosOf" then
    return nil
  end
  if value == "UIParent" then
    return nil
  end
  local entry = registryById[value]
  if not entry then
    return "unknown"
  end
  if field == "ParentOf" and entry.kind ~= "frame" and entry.kind ~= "button" then
    return "texture"
  end
  local own = registryById[id]
  if field == "ParentPosOf" and own and own.secure and entry.kind == "texture" then
    return "texture"
  end
  return nil
end

local function invalidTargetMessage(id, field, value)
  local reason
  if registryById[value] and registryById[value].kind ~= "texture" then
    reason = "'" .. tostring(value) .. "' is anchored to a texture; " .. field
      .. " needs a frame whose own anchors are frames for a secure or protected frame; using UIParent"
  elseif registryById[value] then
    reason = "'" .. tostring(value) .. "' is a texture; " .. field .. " needs a frame or button"
      .. (field == "ParentPosOf" and " for a secure or protected frame" or "") .. "; using UIParent"
  else
    reason = field .. " '" .. tostring(value)
      .. "' is not one of the customizer IDs shown as block titles (Blizzard frames are not allowed); using UIParent"
  end
  return id .. ": " .. reason
end

-- spec 0001 §Customizer "Apply": "Hide = true reparents the object to
-- WIIIUI.hider; it does not call Hide() ... Only true is stored ... Hide
-- wins over ParentOf." Never called for a secure entry (applyEntry's own
-- guard) -- LAB keeps its buttons parented to their header. Capture happens
-- via the shared capture() helper -- Revert() above writes data.parent back.
local function applyParent(id, obj, overrides)
  local hide = overrides.Hide == true
  local parentOf = overrides.ParentOf

  if hide or parentOf ~= nil then
    capture(id, "parent", obj:GetParent())

    if hide then
      obj:SetParent(WIIIUI.hider)
    else
      local target = resolveParentOfTarget(parentOf)
      if not target then
        WIIIUI.Customizer.lastWarnings[id .. ".ParentOf"] = invalidTargetMessage(id, "ParentOf", parentOf)
        target = UIParent
      end
      obj:SetParent(target)
    end
  end
end

-- spec 0001 §Customizer "Apply": "capture on write ... Anchor: all points:
-- GetNumPoints(), then GetPoint(i) for each. To revert: ClearAllPoints, then
-- one SetPoint per captured point." Captured once per baseline cycle, right
-- before the mutating ClearAllPoints/SetPoint below.
local function captureAnchor(id, obj)
  if baseline[id] and baseline[id].captured.points then
    return
  end

  local points = {}
  local n = obj.GetNumPoints and obj:GetNumPoints() or 0
  for i = 1, n do
    local p, relativeTo, relativePoint, x, y = obj:GetPoint(i)
    points[#points + 1] = { p, relativeTo, relativePoint, x, y }
  end

  capture(id, "points", points)
end

-- spec 0001 §Customizer "Apply": "Anchor merge. If any of Point,
-- ParentPosOf, RelativePoint, PosX or PosY is overridden, Apply reads point 1
-- of the reverted base, replaces only the overridden parts, then calls
-- ClearAllPoints and SetPoint ... Because the merge starts from the base,
-- clearing one part of a partial override ... returns that part to the base
-- value." Reading GetPoint(1) here is safe precisely because Revert() (the
-- first step of Layout()/Apply()) already put every object back at its
-- uncustomized base before this runs.
local function applyAnchor(id, obj, overrides)
  if not anyFieldSet(overrides, ANCHOR_FIELDS) then
    return
  end

  local point, relativeTo, relativePoint, x, y = obj:GetPoint(1)
  if not point then
    return
  end

  local newPoint = overrides.Point or point
  if not VALID_POINTS[newPoint] then
    error("Customizer: invalid Point '" .. tostring(newPoint) .. "' for " .. id, 0)
  end

  local newRelativePoint = overrides.RelativePoint or relativePoint or newPoint
  if not VALID_POINTS[newRelativePoint] then
    error("Customizer: invalid RelativePoint '" .. tostring(newRelativePoint) .. "' for " .. id, 0)
  end

  local newRelativeTo = relativeTo
  if overrides.ParentPosOf ~= nil then
    newRelativeTo = resolveAnchorTarget(overrides.ParentPosOf)

    -- Regions may anchor to regions; only a frame that is protected (itself
    -- or implicitly, via IsProtected) is barred from a texture target.
    -- A frame target counts too when its own anchor chain runs through a
    -- region: the protected obj would make it implicitly protected, and it
    -- would then anchor to that region (chain walk, bounded).
    local targetEntry = registryById[overrides.ParentPosOf]
    if newRelativeTo and targetEntry
        and registryById[id].kind ~= "texture" and registryById[id].kind ~= "fontstring"
        and (targetEntry.kind == "texture" or anchorChainHitsRegion(newRelativeTo))
        and obj:IsProtected() then
      newRelativeTo = nil
    end

    if not newRelativeTo then
      WIIIUI.Customizer.lastWarnings[id .. ".ParentPosOf"] = invalidTargetMessage(id, "ParentPosOf", overrides.ParentPosOf)
      newRelativeTo = UIParent
    end
  end

  -- Overrides are stored in 240-units (the original default), not in the current default's.
  local scale = WIIIUI.LayoutUnits() / WIIIUI.CUSTOMIZER_BASE_UNITS
  local newX = overrides.PosX ~= nil and (overrides.PosX * scale) or x
  local newY = overrides.PosY ~= nil and (overrides.PosY * scale) or y

  -- Capture only after every validation above has had the chance to error:
  -- an invalid override must leave nothing in the baseline to roll back.
  captureAnchor(id, obj)

  obj:ClearAllPoints()
  obj:SetPoint(newPoint, newRelativeTo, newRelativePoint, newX, newY)
end

-- spec 0001 §Customizer "Combat and implicit protection" (second round):
-- "In applyEntry, after the parent and anchor steps, Apply calls
-- IsProtected() on every resolved combatToggled object. It does this only
-- when the entry has a ParentOf or ParentPosOf override, because only those
-- change the protection graph." Runs for every entry with such an override,
-- not only combatToggled entries themselves -- protection flows from a
-- protected source TO its parent and TO what it anchors to (Patch 2.0.1/API
-- changes; API_ScriptRegion_IsProtected), so an unrelated entry's ParentOf/
-- ParentPosOf can point a secure chain at a combat-toggled frame. Raising
-- here (inside applyEntry's own pcall, Apply() below) rolls this entry back
-- to the pre-entry state, which had already passed the check. If
-- IsProtected() itself returns a secret value (SecretReturnsForAspect =
-- ObjectSecurity on WIIIUI's own frames should never happen, but the check
-- fails closed regardless), testing it in a boolean context throws the same
-- way and the entry still rolls back -- no special-casing needed.
--
-- Takes the entry's
-- own id (so the message names which entry's edit was rejected, not only
-- the combat-toggled frame that would have locked) and a single fieldName
-- rather than choosing between two -- applyEntry below calls this once right
-- after applyParent (only when ParentOf is set) and once right after
-- applyAnchor (only when ParentPosOf is set), so fieldName always names the
-- field whose own step actually just ran, never a guess between two fields
-- that happen to both be set.
local function checkCombatToggledProtection(id, fieldName)
  for _, ctId in ipairs(combatToggledIds) do
    local obj = WIIIUI.Customizer.Resolve(ctId)
    if obj and obj:IsProtected() then
      error("Customizer: " .. fieldName .. " would lock " .. ctId .. " in combat; entry (" .. id .. ") skipped", 0)
    end
  end
end

-- Width/Height: capture the explicit size only (GetSize(true), the
-- ignoreRect form -- 0 when no explicit size was ever set,
-- API_ScriptRegion_GetSize), for the overridden dimension only, matching
-- Revert()'s per-dimension SetWidth/SetHeight above.
local function applySize(id, obj, overrides)
  local scale = WIIIUI.LayoutUnits() / WIIIUI.CUSTOMIZER_BASE_UNITS

  if overrides.Width ~= nil then
    local w = obj:GetSize(true)
    capture(id, "width", w)
    obj:SetWidth(overrides.Width * scale)
  end
  if overrides.Height ~= nil then
    local _, h = obj:GetSize(true)
    capture(id, "height", h)
    obj:SetHeight(overrides.Height * scale)
  end
end

-- TexCoordLeft/Right/Top/Bottom collapse to one SetTexCoord(left, right,
-- top, bottom) call, captured as a single 4-value group.
local function applyTexCoord(id, obj, overrides)
  if not anyFieldSet(overrides, TEXCOORD_FIELDS) then
    return
  end

  local left, right, top, bottom = 0, 1, 0, 1
  if obj.GetTexCoord then
    local ok, ulx, uly, _, lly, urx = pcall(obj.GetTexCoord, obj)
    if ok and ulx then
      left, right, top, bottom = ulx, urx, uly, lly
    end
  end

  capture(id, "texCoord", { left, right, top, bottom })

  local newLeft = overrides.TexCoordLeft or left
  local newRight = overrides.TexCoordRight or right
  local newTop = overrides.TexCoordTop or top
  local newBottom = overrides.TexCoordBottom or bottom

  obj:SetTexCoord(newLeft, newRight, newTop, newBottom)
end

-- spec 0001 §Customizer "Apply": "Order within one entry: parent (Hide,
-- ParentOf), then anchor, then the protection check, then size, then
-- texture, then strata, level, alpha, draw layer, tex coords and backdrop."
-- The protection
-- check now runs twice -- right after parent (ParentOf only) and right
-- after anchor (ParentPosOf only) -- both still strictly before size, so
-- checkCombatToggledProtection's fieldName always names the step that just
-- ran instead of guessing between two fields that happen to both be set.
local function applyEntry(entry, overrides)
  local id = entry.id
  local obj = WIIIUI.Customizer.Resolve(id)
  if not obj then
    return
  end

  local isRegionEntry = entry.kind == "texture" or entry.kind == "fontstring"

  if not entry.secure then
    applyParent(id, obj, overrides)
    -- A texture's companion is a protected frame that follows its parent and
    -- anchors, so a texture's ParentOf/anchor change reaches the protection
    -- graph only once the companion is re-mirrored: sync before the check.
    if isRegionEntry and overrides.ParentOf ~= nil then
      syncConsoleAnchorsOrRaise()
    end
    if overrides.ParentOf ~= nil then
      checkCombatToggledProtection(id, "ParentOf")
    end
  end

  applyAnchor(id, obj, overrides)
  if isRegionEntry and anyFieldSet(overrides, ANCHOR_FIELDS) then
    syncConsoleAnchorsOrRaise()
  end
  if overrides.ParentPosOf ~= nil then
    checkCombatToggledProtection(id, "ParentPosOf")
  end

  applySize(id, obj, overrides)

  if entry.kind == "texture" and overrides.Texture ~= nil then
    capture(id, "texture", obj:GetTexture())
    obj:SetTexture(overrides.Texture)
  end

  if entry.kind == "frame" or entry.kind == "button" then
    if overrides.FrameStrata ~= nil then
      capture(id, "frameStrata", obj:GetFrameStrata())
      obj:SetFrameStrata(overrides.FrameStrata)
    end
    if overrides.FrameLevel ~= nil then
      capture(id, "frameLevel", obj:GetFrameLevel())
      obj:SetFrameLevel(overrides.FrameLevel)
    end
  end

  if overrides.Transparency ~= nil then
    capture(id, "transparency", obj:GetAlpha())
    obj:SetAlpha(overrides.Transparency)
  end

  if entry.kind == "texture" and overrides.SetDrawLayer ~= nil then
    -- Both returns: a bare layer would reset the sublayer to 0 on revert.
    if obj.GetDrawLayer then
      capture(id, "drawLayer", { obj:GetDrawLayer() })
    end
    obj:SetDrawLayer(overrides.SetDrawLayer)
  end

  if entry.kind == "texture" then
    applyTexCoord(id, obj, overrides)
  end

  if entry.backdrop and overrides.Backdrop ~= nil then
    local current = obj.GetBackdrop and obj:GetBackdrop()
    capture(id, "backdrop", current)
    obj:SetBackdrop(overrides.Backdrop)
  end
end

-- spec 0001 §Customizer "Apply": "WIIIUI.Customizer.Apply() is the last step
-- of WIIIUI.Layout() ... It iterates the registry, never the saved table,
-- and never writes the saved table. When EnableCustomize is false, every
-- entry is applied as if it had no overrides." Revert() first (second
-- round): a no-op when Layout already reverted, but Apply() is also called
-- directly from SetOverride's queued closure below, where nothing else
-- reverted first.
function WIIIUI.Customizer.Apply()
  WIIIUI.Customizer.Revert()

  local enabled = wc3UI_Options.EnableCustomize
  wc3UI_Options.edit_theme_settings = wc3UI_Options.edit_theme_settings or {}

  local themeSettings = enabled and wc3UI_Options.edit_theme_settings[wc3UI_Options.theme]

  WIIIUI.Customizer.lastErrors = {}
  WIIIUI.Customizer.lastWarnings = {}

  for _, entry in ipairs(registry) do
    local overrides = (themeSettings and themeSettings[entry.id]) or EMPTY_OVERRIDES
    local ok, err = pcall(applyEntry, entry, overrides)
    if not ok then
      revertEntry(entry.id)
      syncConsoleAnchors()
      WIIIUI.Customizer.lastErrors[entry.id] = err
    end
  end

  syncConsoleAnchors()
end

--------------------------------------------------------------------------
-- Storage
--------------------------------------------------------------------------

-- The one chat-warning seam of this file. DEFAULT_CHAT_FRAME is
-- existence-checked (absent under the headless stub unless a test installs
-- one), like every other optional Blizzard global here.
local function say(message)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("WIIIUI: " .. message)
  end
end

-- spec 0001 §Customizer "Storage": "edit_theme_settings[theme][id] = {
-- [field] = value }, overridden fields only." value == nil clears the field
-- (and drops the id's table once empty) rather than writing a nil.
function WIIIUI.Customizer.GetOverride(id, field)
  local themeSettings = wc3UI_Options.edit_theme_settings and wc3UI_Options.edit_theme_settings[wc3UI_Options.theme]
  local entry = themeSettings and themeSettings[id]
  return entry and entry[field]
end

local function applyAndReport()
  local beforeWarn = WIIIUI.Customizer.lastWarnings
  local beforeApply = WIIIUI.Customizer.lastErrors
  local beforeRevert = WIIIUI.Customizer.lastRevertErrors
  WIIIUI.Customizer.Apply()
  local afterApply = WIIIUI.Customizer.lastErrors
  local afterRevert = WIIIUI.Customizer.lastRevertErrors
  local afterWarn = WIIIUI.Customizer.lastWarnings

  for errId, message in pairs(afterApply) do
    if not beforeApply[errId] then
      say(tostring(message))
    end
  end
  for errId, message in pairs(afterRevert) do
    if not beforeRevert[errId] then
      say("revert failed for " .. errId .. ": " .. tostring(message))
    end
  end
  for warnKey, message in pairs(afterWarn) do
    if not beforeWarn[warnKey] then
      say(message)
    end
  end
end

-- spec 0001 §Customizer "Combat and implicit protection": "Every customizer
-- apply goes through ApplyOrQueue, not only the secure entries ... An editor
-- edit calls ApplyOrQueue('custom:'..id, ...)." Console.grid's 36 secure
-- grid buttons (Buttons.lua's anchorRow) are anchored to it, and the
-- portrait's secure button anchors to Console.left.portraitTexture -- per
-- warcraft.wiki.gg's Patch_2.0.1/API_changes page, "the parent of a
-- protected frame is implicitly protected also, as are any frames which it
-- is anchored to" (https://warcraft.wiki.gg/wiki/Patch_2.0.1/API_changes;
-- https://warcraft.wiki.gg/wiki/API_ScriptRegion_IsProtected), so a
-- non-secure ancestor of a secure frame is locked in combat too, not only
-- the secure frame itself.
--
-- "Player feedback. Apply does not write to wc3UI_Options: the override
-- stays saved but has no effect ... SetOverride's queued closure runs Apply,
-- then prints one chat line for each ID that has a new entry in lastErrors,
-- found by comparing before and after." DEFAULT_CHAT_FRAME is
-- existence-checked (absent under the headless stub, so tests stay silent)
-- the same way every other optional Blizzard global in this codebase is.
--
-- The same
-- before/after diff, applied to lastRevertErrors -- Apply() always calls
-- Revert() first, so a revert failure surfaced by this same edit is no more
-- silent than an apply failure already was.
function WIIIUI.Customizer.SetOverride(id, field, value)
  if value ~= nil and targetProblem(id, field, value) then
    say(invalidTargetMessage(id, field, value))
    value = "UIParent"
  end

  wc3UI_Options.edit_theme_settings = wc3UI_Options.edit_theme_settings or {}
  local theme = wc3UI_Options.theme
  wc3UI_Options.edit_theme_settings[theme] = wc3UI_Options.edit_theme_settings[theme] or {}
  local themeSettings = wc3UI_Options.edit_theme_settings[theme]

  if value == nil then
    if themeSettings[id] then
      themeSettings[id][field] = nil
      if next(themeSettings[id]) == nil then
        themeSettings[id] = nil
      end
    end
  else
    themeSettings[id] = themeSettings[id] or {}
    themeSettings[id][field] = value
  end

  WIIIUI.ApplyOrQueue("custom:" .. id, applyAndReport)
end

-- spec 0001 §Customizer "Storage": "Reset wipes edit_theme_settings[theme]"
-- -- the current theme only. The saved wipe is immediate (a table write,
-- combat-safe); the revert-and-reapply goes through the same ApplyOrQueue
-- key SetOverride uses, so protected frames (the grid, extras, portrait
-- button) are only touched out of combat.
function WIIIUI.Customizer.ResetTheme()
  if wc3UI_Options.edit_theme_settings then
    wc3UI_Options.edit_theme_settings[wc3UI_Options.theme] = nil
  end

  WIIIUI.ApplyOrQueue("custom:reset", applyAndReport)
  WIIIUI.Customizer.RefreshEditor()
end

-- Confirmation for the editor's Reset button, through Blizzard's own generic
-- confirm so no key is written onto a Blizzard table (CLAUDE.md R1).
-- Gethe/wow-ui-source Blizzard_StaticPopup/StaticPopup.lua,
-- StaticPopup_ShowCustomGenericConfirmation(customData): forever :241, live
-- :232 (customData keys .text, .text_arg1, .callback documented just above
-- it); GENERIC_CONFIRMATION in SharedDialogDefs.lua supplies YES/NO,
-- timeout 0, whileDead, hideOnEscape and calls data.callback() on accept.
function WIIIUI.Customizer.ConfirmReset()
  StaticPopup_ShowCustomGenericConfirmation({
    text = "Reset all Customize overrides for the %s theme?",
    text_arg1 = wc3UI_Options.theme,
    callback = function() WIIIUI.Customizer.ResetTheme() end,
  })
end

--------------------------------------------------------------------------
-- Editor
--------------------------------------------------------------------------

-- spec 0001 §Customizer "Editor": "It pages with the mouse wheel through an
-- OnMouseWheel(self, delta) script, with no OnUpdate. It shows 3 entries per
-- page, as vanilla did (WIIIUI.lua:1096). Each block's title is the ID,
-- followed by GetName() in brackets when the object has a name."
local PAGE_SIZE = 3

-- The widest field set any registry entry offers -- computed, not a magic
-- number, so a later registry addition (a new kind or a texture entry with
-- more fields) can't silently drop rows the way a stale hardcoded count
-- would (a texture entry's own 16 fields -- base 8 + ParentOf/Hide 2 +
-- Texture/SetDrawLayer/TexCoord*4 6 -- already exceeds vanilla's own 3-line
-- editor box, e17c352 WIIIUI.lua:1096).
local function computeMaxFields()
  local max = 0
  for _, entry in ipairs(registry) do
    local count = #WIIIUI.Customizer.Fields(entry)
    if count > max then
      max = count
    end
  end
  return max
end

local MAX_FIELDS_PER_BLOCK = computeMaxFields()
local BLOCK_WIDTH = 190
local FIELD_ROW_HEIGHT = 16
local FIELD_BOX_WIDTH = 90
local FIELD_LABEL_WIDTH = 90

-- An unconstrained title
-- FontString renders at natural width and can bleed into the next block --
-- blocks sit edge-to-edge with no gap (RefreshEditor below:
-- (blockIndex - 1) * BLOCK_WIDTH). SetWidth(BLOCK_WIDTH) + SetWordWrap(true)
-- is the same pattern Config.lua's buildNote already uses for the same
-- reason (Config.lua's own "Width/wrap guard" comment).
--
-- SetWordWrap alone
-- only breaks at whitespace. Every registry id is dot-separated with zero
-- whitespace, so as one unbreakable "word" it never wrapped -- it silently
-- truncated on line 1 instead, defeating the title reservation below.
-- SetNonSpaceWrap(true) (warcraft.wiki.gg API_FontString_SetNonSpaceWrap:
-- "sets whether long strings without spaces are wrapped or truncated",
-- default off) is the separate toggle that makes a spaceless string actually
-- wrap; both calls are needed together.
--
-- Two rows are reserved unconditionally rather than measuring and
-- repositioning the field rows per refresh: the longest registry id
-- ("Console.left.extensionBackgroundTexture", 39 chars) wraps to 2 lines at
-- BLOCK_WIDTH (190px) under GameFontHighlightSmall's rough ~5.5px/char --
-- ~215px total, well inside the ~380px two-line capacity even with mid-word
-- breaking's worse line-fill than word breaking. The next-longest ids
-- ("Portrait.button [WIIIUI_Portrait]", 33 chars, "Console.right.
-- rightPartMiddle", 29) have even more margin, and named entries
-- ("Buttons.extras.9 [WIIIUI_Extra9]") carry a space so word-wrap alone
-- already handled them -- none of these combine into something that needs a
-- third line -- tester should still eyeball the widest titles in-game since
-- exact font metrics aren't provable headlessly.
local TITLE_ROWS = 2
local TITLE_HEIGHT = FIELD_ROW_HEIGHT * TITLE_ROWS

-- PosX/PosY/Width/Height/FrameLevel/Transparency/TexCoord* are numeric
-- fields; every other field (Point/RelativePoint/ParentPosOf/ParentOf/
-- Texture/FrameStrata) is a plain string; Hide is the one boolean field
-- (only `true` is ever stored, spec 0001 §Customizer "Apply").
local NUMERIC_FIELDS = {
  PosX = true, PosY = true, Width = true, Height = true,
  FrameLevel = true, Transparency = true,
  TexCoordLeft = true, TexCoordRight = true, TexCoordTop = true, TexCoordBottom = true,
}

-- A second return value,
-- `ok`, distinguishes "empty string -> intentionally clear" (ok = true,
-- value = nil) from "non-empty text tonumber couldn't parse -> reject the
-- edit" (ok = false) -- both previously collapsed to the same nil,
-- indistinguishable to SetOverride, which reads nil as "clear this field".
-- OnEnterPressed below never calls SetOverride when ok is false.
local function parseFieldValue(field, text)
  if text == nil or text == "" then
    return nil, true
  end
  if field == "Hide" then
    return (text == "true") or nil, true
  end
  if NUMERIC_FIELDS[field] then
    local n = tonumber(text)
    return n, n ~= nil
  end
  return text, true
end

local function fieldValueToText(value)
  if value == nil then
    return ""
  end
  return tostring(value)
end

local function pageCount()
  return math.max(1, math.ceil(#registry / PAGE_SIZE))
end

local function ensureBlock(index)
  WIIIUI.Customizer.blocks = WIIIUI.Customizer.blocks or {}
  local blocks = WIIIUI.Customizer.blocks
  local block = blocks[index]
  if block then
    return block
  end

  local editor = WIIIUI.Customizer.editor
  local container = CreateFrame("Frame", nil, editor)
  container:SetSize(BLOCK_WIDTH, MAX_FIELDS_PER_BLOCK * FIELD_ROW_HEIGHT + TITLE_HEIGHT)

  local title = container:CreateFontString(nil, "OVERLAY")
  title:SetFontObject(GameFontHighlightSmall)
  title:SetWidth(BLOCK_WIDTH)
  title:SetWordWrap(true)
  title:SetNonSpaceWrap(true)
  title:SetJustifyH("LEFT")
  title:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)

  local rows = {}
  for i = 1, MAX_FIELDS_PER_BLOCK do
    local label = container:CreateFontString(nil, "OVERLAY")
    label:SetFontObject(GameFontHighlightSmall)
    label:SetWidth(FIELD_LABEL_WIDTH)
    label:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -(TITLE_HEIGHT + FIELD_ROW_HEIGHT * (i - 1)))

    local box = CreateFrame("EditBox", nil, container, "InputBoxTemplate")
    box:SetAutoFocus(false)
    box:SetSize(FIELD_BOX_WIDTH, 16)
    box:SetPoint("TOPLEFT", label, "TOPRIGHT", 4, 0)

    local row = { label = label, box = box, id = nil, field = nil }

    box:SetScript("OnEscapePressed", function(self)
      self:SetText(row.id and row.field and fieldValueToText(WIIIUI.Customizer.GetOverride(row.id, row.field)) or "")
      self:ClearFocus()
    end)
    -- An unparseable
    -- numeric edit (ok = false) skips SetOverride entirely rather than
    -- silently clearing the field, then re-syncs the box from the actual
    -- saved state (like OnEscapePressed already does) so it never keeps
    -- showing rejected/untrusted text -- also true on the accepted path,
    -- since GetOverride's formatted echo can differ from raw typed text.
    box:SetScript("OnEnterPressed", function(self)
      if row.id and row.field then
        local value, ok = parseFieldValue(row.field, self:GetText())
        if ok then
          WIIIUI.Customizer.SetOverride(row.id, row.field, value)
        end
        self:SetText(fieldValueToText(WIIIUI.Customizer.GetOverride(row.id, row.field)))
      end
      self:ClearFocus()
    end)

    rows[i] = row
  end

  block = { container = container, title = title, rows = rows }
  blocks[index] = block
  return block
end

-- spec 0001 §Customizer "Editor": "Each block's title is the ID, followed by
-- GetName() in brackets when the object has a name."
local function blockTitle(entry)
  local obj = WIIIUI.Customizer.Resolve(entry.id)
  local name = obj and obj.GetName and obj:GetName()
  if name then
    return entry.id .. " [" .. name .. "]"
  end
  return entry.id
end

function WIIIUI.Customizer.RefreshEditor()
  local editor = WIIIUI.Customizer.editor
  if not editor then
    return
  end

  local startIndex = (editor.page - 1) * PAGE_SIZE + 1

  for blockIndex = 1, PAGE_SIZE do
    local entry = registry[startIndex + blockIndex - 1]
    local block = ensureBlock(blockIndex)

    block.container:ClearAllPoints()
    block.container:SetPoint("TOPLEFT", editor, "TOPLEFT", (blockIndex - 1) * BLOCK_WIDTH, 0)

    if entry then
      block.container:Show()
      block.title:SetText(blockTitle(entry))

      local fields = WIIIUI.Customizer.Fields(entry)
      for i, row in ipairs(block.rows) do
        local field = fields[i]
        if field then
          row.id = entry.id
          row.field = field
          row.label:SetText(field)
          row.label:Show()
          row.box:Show()
          row.box:SetText(fieldValueToText(WIIIUI.Customizer.GetOverride(entry.id, field)))
        else
          row.id = nil
          row.field = nil
          row.label:Hide()
          row.box:Hide()
        end
      end
    else
      block.container:Hide()
    end
  end

  -- A page-count indicator,
  -- same precedent this file's own header comment already cites
  -- (e17c352 WIIIUI.lua ~1092-1112, WIIIUI_pagesFrame's "cur / max" text) but
  -- hadn't built. One SetText call per refresh -- no OnUpdate, no new
  -- performance concern.
  if editor.pageIndicator then
    editor.pageIndicator:SetText(editor.page .. " / " .. pageCount())
  end
end

-- spec 0001 §Customizer "Editor": event-driven wheel paging, no OnUpdate.
-- Built once, parented to WIIIUI.Config.panel (Config.lua's own tab switch
-- shows/hides it); re-anchored and refreshed on every call, matching every
-- other Build* function's idempotent convention.
function WIIIUI.Customizer.BuildEditor(panel)
  local editor = WIIIUI.Customizer.editor

  if not editor then
    editor = CreateFrame("Frame", nil, panel)
    editor.page = 1
    editor:EnableMouseWheel(true)
    editor:SetScript("OnMouseWheel", function(self, delta)
      local page = self.page - delta
      local maxPage = pageCount()
      if page < 1 then
        page = 1
      elseif page > maxPage then
        page = maxPage
      end
      self.page = page
      WIIIUI.Customizer.RefreshEditor()
    end)

    -- "N / max" page-count
    -- indicator, bottom-center of the editor (vanilla's own WIIIUI_pagesFrame
    -- placement, e17c352 WIIIUI.lua ~1101: SetPoint("BOTTOM", 0, -30)).
    -- Whether a tall block's own field rows (a texture entry's own
    -- MAX_FIELDS_PER_BLOCK count) can visually reach this far down is an
    -- in-game check, not provable from the headless stub. RefreshEditor
    -- keeps its text current; set once here too so it never renders empty
    -- for a frame before the first refresh.
    local pageIndicator = editor:CreateFontString(nil, "OVERLAY")
    pageIndicator:SetFontObject(GameFontHighlightSmall)
    pageIndicator:SetPoint("BOTTOM", editor, "BOTTOM", 0, 0)
    pageIndicator:SetText(editor.page .. " / " .. pageCount())
    editor.pageIndicator = pageIndicator

    -- Reset (spec 0001 §Customizer "Storage"). Bottom-right of
    -- the editor: the blocks fill the top-left (3 x BLOCK_WIDTH wide, one
    -- block tall) and the page indicator sits bottom-center, so neither
    -- overlaps this corner. In-game only: visual clearance at real font
    -- metrics.
    local resetButton = CreateFrame("Button", nil, editor, "UIPanelButtonTemplate")
    resetButton:SetSize(120, 22)
    resetButton:SetText("Reset overrides")
    resetButton:SetPoint("BOTTOMRIGHT", editor, "BOTTOMRIGHT", 0, 0)
    resetButton:SetScript("OnClick", function() WIIIUI.Customizer.ConfirmReset() end)
    editor.resetButton = resetButton

    WIIIUI.Customizer.editor = editor
  end

  editor:ClearAllPoints()
  editor:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -74)
  editor:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16, 16)

  WIIIUI.Customizer.RefreshEditor()
  return editor
end

-- Revert runs before every Build* so each sees uncustomized objects; Apply
-- registers last (Customizer.lua is the last TOC file) so it layers over them
-- (spec 0001 §Customizer "Apply").
WIIIUI.RegisterBuild("Customizer.Revert", WIIIUI.Customizer.Revert, { first = true })
WIIIUI.RegisterBuild("Customizer.Apply", WIIIUI.Customizer.Apply)
