![WIIIUI Forever](addonbanner.webp)

# WIIIUI (Warcraft III - UI) for World of Warcraft: Forever and retail

A full replacement for the bottom of your screen, styled after the Warcraft III in-game console: minimap and portrait on the left, your action bars in the middle, a chat panel on the right, plus an experience bar and health and power readouts.

## About this fork

This is a **separate build of WIIIUI made for World of Warcraft: Forever and retail**. It is not compatible with vanilla (1.12) clients. If you play vanilla, use the original addon instead.

**The concept and the art are the work of Fiur**, who created WIIIUI. Thank you, Fiur, for a wonderful addon. Original repository: https://github.com/Fiurs-Hearth/WIIIUI

The original has not been updated in over a year and was written for vanilla. This fork carries the same look over to the current game clients.

**Retail status:** WIIIUI is built for World of Warcraft: Forever, and it also loads on retail. Retail support covers the same console plus retail-specific handling (class resources above the portrait, skyriding on the bottom action row, and a few info-icon differences). **It has not been tested in-game on retail yet**, so please report any problems on the issues page below.

## Screenshots

*Taken on World of Warcraft: Forever at 1920×1080, UI Scale 290 with Ultra-Wide Mode on (the defaults), with WIIIUI's Edit Mode layout imported (see [Edit Mode layout](#edit-mode-layout-optional-one-time-setup)). Most show the config menu open.*

**Human**
![Human theme](screenshots/human.webp)

**Orc**
![Orc theme](screenshots/orc.webp)

**Undead**
![Undead theme](screenshots/undead.webp)

**Night Elf**
![Night Elf theme](screenshots/nightelf.webp)

## Features

* Four faction themes from Warcraft III: Human, Orc (the default), Undead and Night Elf.
* Replaces Blizzard's bottom action bars with its own, so you do not need Bartender or a similar addon.
* 3 extra action slots next to the minimap (your hearthstone is placed in the top one automatically) and 6 extra "inventory" slots for spells, items and consumables. You can bind keys to all nine in the game's Key Bindings screen, under the "Warcraft III - UI" heading.
* Health and power display, an experience bar, and a low-health warning.
* **Druid resource bar:** for druids, an extra bar keeps your mana visible while the middle bar shows your current form's resource (rage or energy). Switch it with the **Druid resource bar** checkbox (shown for druids only).
* **Minimap pieces** in the console art: a mail icon (lights up when you have mail; hover it to see the senders), a tracking button in the round slot (click it for the tracking menu), the zone name above the minimap, a clock (click it for the time manager) and a calendar button. Blizzard's own minimap corner at the top right is hidden; the **Show Blizzard's Minimap Corner** checkbox brings it back.
* **UI Scale** sets the overall size of the console, from 240 to 300 (290 by default). Above 270 the text grows along with the console.
* Icons that show information about your character, such as weapon damage and armor. On retail: Block shows your block chance in %, Ranged works without a ranged slot, and Healing is shown as spell power (retail merged the two).
* Layout options (three checkboxes in the General tab, see below). Changing these no longer needs a reload.
* A Customize tab in the config menu to adjust the position, size, transparency and look of individual parts of the UI. It only takes effect while **Enable Customizer** (a checkbox on the General tab) is ticked.
* Your settings are saved per character.

Custom themes (your own art folders) are **not supported** in this fork. If you would like them, please open an issue.

## Installation

Requires **World of Warcraft: Forever** or **retail**. Vanilla 1.12 and unofficial clients are not supported.

### Install by hand

1. [Download the addon](https://github.com/Johan-p/WIIIUI-Forever-Fork/archive/refs/heads/master.zip)
2. Unpack the zip. Inside is a folder named `WIIIUI-Forever-Fork-master`.
3. Rename that folder to `WIIIUI`. The folder name must be exactly `WIIIUI`, or the game ignores the addon.
4. Put the renamed folder into your AddOns folder, so that `...\Interface\AddOns\WIIIUI\WIIIUI.toc` exists:
   * **WoW Forever (beta):** `World of Warcraft\_classic_beta_\Interface\AddOns`
   * **Retail:** `World of Warcraft\_retail_\Interface\AddOns` (not yet tested in-game on retail)
5. Start the game, or restart it if it was running. A new addon needs a full restart, not just `/reload`.
6. Make sure **WIIIUI** is ticked in the AddOns list on the character select screen.

### Install with git

For players who have git installed. No renaming is needed, and updating later is one command.

1. Open a terminal in your AddOns folder:
   * **WoW Forever (beta):** `World of Warcraft\_classic_beta_\Interface\AddOns`
   * **Retail:** `World of Warcraft\_retail_\Interface\AddOns`
2. Run:

   ```
   git clone https://github.com/Johan-p/WIIIUI-Forever-Fork.git WIIIUI
   ```

   The trailing `WIIIUI` sets the folder name. It must be exactly `WIIIUI`, so you do not need to rename anything.
3. Start the game, or restart it if it was running. Then make sure **WIIIUI** is ticked in the AddOns list on the character select screen.

On Windows, if the game is installed under `C:\Program Files (x86)`, open the terminal as administrator, or git cannot write there.

### Updating

**If you installed with git:** from your AddOns folder, run:

```
git -C WIIIUI pull
```

This does the same as running `git pull` inside the `WIIIUI` folder. Then restart the game. A new or renamed file needs a full restart, not just `/reload`.

**If you installed by hand:** download the zip again and replace the `WIIIUI` folder with the new one, repeating the rename from the steps above. Your settings are kept, because the game stores them outside the addon folder.

## Getting started

* **Open the config menu:** move your mouse into the bottom-right corner of the screen. A cogwheel appears; click it. There are no slash commands. The menu has a General tab and a Customize tab, and a Reload UI button.
* **Some options live in Edit Mode.** On current game clients, Blizzard controls where things like the buff icons, the cast bar, the bags and the shapeshift bar sit. In the config menu those options show a "set in Edit Mode" note instead of a control. Move those pieces with the game's own Edit Mode.
* **Layout modes.** Three checkboxes in the General tab:
  * **Ultra-Wide Mode** shifts the chat panel's edges to suit very wide screens. It is on by default.
  * **Center Slim Mode** hides the chat area but keeps the inventory panel.
  * **Center Slim (No Inventory)** hides the whole right-hand panel, chat area and inventory both.
  If both Center Slim boxes are ticked, Center Slim Mode wins.
* **The extra slots share action bar page 2.** The 9 extra slots (3 by the minimap, 6 in the inventory) are action slots 13 to 21, which is page 2 of the main bar. If you page your main bar to page 2 (for example with Shift+2), you see the same actions, and changing them there changes the minimap and inventory slots too. This is intended.
* **Optional: import WIIIUI's Edit Mode layout.** Until you do, Blizzard's own pieces (chat, bags, micro menu, buffs) sit where Blizzard puts them and can overlap the console. See [Edit Mode layout](#edit-mode-layout-optional-one-time-setup) below.
* **Saved settings may not stick on some Forever beta builds.** WIIIUI works with default settings on every login, so if your choices are forgotten, that is why. Settings also cannot be saved if the game's saved-settings files are read-only, so check that too.

## Edit Mode layout (optional, one-time setup)

**The layout string below is for Forever only.** On retail, the "Copy layout string" box in the config menu shows "Not available in this build" until a retail layout is published. Do not import the Forever string on retail: the two clients number their Edit Mode pieces differently, so it will not import correctly there.

WIIIUI replaces the bottom of your screen, but Blizzard still owns chat, bags, the micro menu, the cast bar, buffs and the stance and pet bars. This layout places them around the WIIIUI console. Importing it is up to you, and you only do it once.

1. Copy the string below (GitHub shows a copy button on the block). The same string is also in WIIIUI's config menu, in the "Copy layout string" box.
2. In game, open the Game Menu (Esc) and choose **Edit Mode**.
3. Open the layout dropdown at the top, choose **Import**, paste the string, give the layout a name, and click the import button. If Import is greyed out, you already have the maximum number of layouts; delete one first.

```
4 0 59 0 0 0 7 7 UIParent -83.0 2.0 -1 ##$$%/&('%)$+#,$ 0 1 0 8 2 MainActionBar 0.0 4.0 -1 ##$$%/&('%(#,$ 0 2 0 0 0 UIParent 318.7 -935.0 -1 ##$$%/&('%(#,$ 0 3 1 5 5 UIParent -5.0 -77.0 -1 #$$$%/&('%(#,$ 0 4 1 5 5 UIParent -5.0 -77.0 -1 #$$$%/&('%(#,$ 0 5 1 1 4 UIParent 0.0 0.0 -1 ##$$%/&('%(#,$ 0 6 1 1 4 UIParent 0.0 -50.0 -1 ##$$%/&('%(#,$ 0 7 1 1 4 UIParent 0.0 -100.0 -1 ##$$%/&('%(#,$ 0 10 0 1 1 UIParent -407.6 -872.0 -1 ##$$&-'% 0 11 1 7 7 UIParent 0.0 -4.0 -1 ##$$&('%,# 0 12 1 7 7 UIParent 0.0 -4.0 -1 ##$$&('% 1 -1 0 7 7 UIParent -200.5 224.0 -1 ##$#%# 2 -1 1 2 2 UIParent 0.0 0.0 -1 ##$#%(&( 3 0 0 0 0 UIParent 1380.0 -308.0 -1 $#3# 3 1 0 1 1 UIParent -356.0 -636.0 -1 %#3# 3 2 0 4 4 UIParent -330.0 -275.5 -1 %#&#3# 3 3 0 0 0 UIParent 1410.0 -322.0 -1 '#(#)#-=.+/#1$3$5#6(7-7$8(9( 3 4 0 0 0 UIParent 1412.0 -322.0 -1 ,#-=.+/#0#1#2(3#5#6(7-7$8(9( 3 5 0 2 2 UIParent -296.0 -2.0 -1 &#*$3# 3 6 1 5 5 UIParent 0.0 0.0 -1 -=.+/#4$5#6(7-7$8(9( 3 7 1 4 4 UIParent 0.0 0.0 -1 3# 4 -1 0 0 0 UIParent 861.0 -824.0 -1 # 5 -1 0 4 4 UIParent 17.0 -220.0 -1 # 6 0 0 1 1 UIParent -670.5 -2.0 -1 ##$#%#&C(()( 6 1 0 0 6 BuffFrame 0.0 -4.0 -1 ##$#%#'3(()(-$ 6 2 1 1 1 UIParent 0.0 -25.0 -1 ##$#%$&.(()(+#,-,$ 7 -1 1 7 7 UIParent 0.0 -4.0 -1 # 8 -1 0 7 7 UIParent 614.5 34.0 -1 #($m%$&P 9 -1 0 7 1 UIParent 6.0 -1.0 -1 # 10 -1 1 0 0 UIParent 16.0 -116.0 -1 # 11 -1 0 8 2 ChatFrame1 25.0 64.0 -1 # 12 -1 0 1 1 UIParent 828.0 -2.0 -1 #<$#%# 13 -1 0 5 3 ChatFrame1 -36.0 61.6 -1 ##$#%) 14 -1 0 2 0 MicroMenuContainer -3.8 0.2 -1 ##$#%& 15 0 0 8 2 SecondaryStatusTrackingBarContainer 0.0 4.0 -1 &# 15 1 0 4 4 UIParent -600.0 100.0 -1 &# 16 -1 0 0 0 UIParent 251.9 -842.0 -1 #( 17 -1 1 1 1 UIParent 0.0 -100.0 -1 ## 18 -1 1 5 5 UIParent 0.0 0.0 -1 #- 19 -1 1 7 7 UIParent 0.0 0.0 -1 ## 20 0 1 7 7 UIParent 0.0 310.0 -1 ##$/%$&('%(-($)#+$,$-$ 20 1 1 7 7 UIParent 0.0 240.0 -1 ##$*%$&('%(-($)#+$,$-$ 20 2 1 7 7 UIParent 0.0 370.0 -1 ##$$%$&('((-($)#+$,$-$ 20 3 1 7 7 UIParent 420.0 430.0 -1 #$$$%#&('((-($)#*#+$,$-$.-.$ 21 -1 1 7 7 UIParent -410.0 380.0 -1 ##%#&#'((()#*-*$+#,&-#.#/(0#1# 22 0 1 8 7 UIParent -457.0 336.0 -1 #$$$%#&('((#)U*$+%,$-#.#/U0% 22 1 1 1 1 UIParent 0.0 -40.0 -1 &('()U*#+% 22 2 1 1 1 UIParent 0.0 -90.0 -1 &('()U*#+% 22 3 1 1 1 UIParent 0.0 -130.0 -1 &('()U*#+% 23 -1 1 0 0 UIParent 0.0 0.0 -1 ##$#%$&7&%'7(%)U+$,$-$.(/U 24 -1 1 1 1 UIParent 0.0 -182.0 -1 # 25 -1 0 6 0 StanceBar 0.0 4.0 -1 # 26 0 0 8 6 MainActionBar 30.0 -2.0 -1 #$ 26 1 0 6 8 MainActionBar -30.0 -2.0 -1 #$ 27 -1 0 4 4 UIParent -735.5 -330.0 -1 #- 28 -1 0 4 4 UIParent 0.0 141.0 -1 #( 29 0 1 7 7 UIParent 0.0 450.0 -1 #($U%#&D&%'2($)$ 29 1 1 7 7 UIParent 0.0 425.0 -1 #($U%#&D&%'2($)$ 29 2 1 7 7 UIParent 0.0 400.0 -1 #($U%#&D&%'2($)$
```

It was made at UI Scale 290 with Ultra-Wide Mode on, at 1920×1080. On other screens some pieces may need a nudge in Edit Mode. Config rows that say "set in Edit Mode" refer to this layout.

## Known issues

**Class resources on retail (combo points, runes, holy power, soul shards, chi, arcane charges, essence).** WIIIUI moves Blizzard's class-resource display above the portrait. Two of Blizzard's own settings can get in the way:

* If your **Pet Frame** is still in its default spot (attached under the player frame), WIIIUI leaves the class resources hidden instead of moving them, so that it does not break Blizzard's pet frame.
* If the **Cast Bar** is set to **Lock to Player Frame** in Edit Mode, the same applies.

**What to do:** open Edit Mode (Esc, then Edit Mode), click the Pet Frame and drag it anywhere, so it is no longer in its default spot. Then click the Cast Bar and untick **Lock to Player Frame**. Save the layout and type `/reload`. WIIIUI's own retail Edit Mode layout, once available, will do both of these for you.

If you ever see "Interface action failed because of an AddOn" after entering a vehicle or when clicking a totem, do the two steps above, `/reload`, and please report it on the issues page below.

## Support and feedback

Found a problem or want a feature? Please open an issue: https://github.com/Johan-p/WIIIUI-Forever-Fork/issues
