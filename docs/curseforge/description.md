**Summary**

Find gear for your class, role and equipment slot and see where it comes from: boss and drop chance, quest or profession. From the character window, a search button on every slot lists the upgrades and alternatives to what you wear.

---

# Forever Loot Finder

A gear finder for **WoW: Forever**. Pick a class, a role and a slot, and the list shows every dungeon and raid drop, quest reward and crafted item that suits them, with where to get it. English, Deutsch.

## Requirements
- [AtlasLoot Classic Forever](https://www.curseforge.com/wow/addons/atlasloot-forever)
- [DungeonJournal](https://www.curseforge.com/wow/addons/dungeonjournal)

Install both, and keep AtlasLoot's Dungeons and Raids and Crafting modules enabled. The boss drops and the crafts come from AtlasLoot Classic Forever; the quest rewards, the dungeon entrances and the boss models from DungeonJournal.

## Classes and roles
- Each class has its own roles: Priest **Healer** and **DPS**; Paladin **Healer**, **Tank** and **DPS**; Druid **Healer**, **Caster DPS**, **Tank** and **Melee DPS**; Shaman **Healer**, **Caster DPS** and **Melee DPS**; Warrior **Tank** and **DPS**; Hunter, Rogue, Mage and Warlock **DPS**. One role is looked at at a time, since each is measured differently.
- Items are judged by their stats, with weights per class and role: an item must have a stat the role wants and none the role excludes. Casters never see attack power or defense items, tanks never see spell power (except paladin tank sets).
- Tanks get their heaviest armor type preselected and no two-handers (bears excepted); damage roles get no defense, dodge, parry or block items.
- Bear tanks count armor, stamina, agility, defense and dodge, but no parry or block. School spell damage (fire, frost, shadow, ...) counts only for the classes that cast that school.
- Spell damage items count for healers too, since they carry the same healing. Healing items do not count for casters.

## Filters
- **Wearable now**: only items for your level and the armor types you have learned.
- **Best armor only**: body armor of your class's heaviest type only (mail or plate from level 40 on); cloaks, jewelry and trinkets always count. Not shown for cloth wearers.
- **Dungeons**, **raids**, **quests** and **crafting**, each on or off. Crafted items show the profession and the skill needed; the panel lists the reagents. Quest rewards (blue and better) show the quest instead of the boss; quests of the other faction or another class are left out.
- Trinkets and other items without plain stats are judged by their Use, Equip and Chance-on-hit texts: a weapon proc is out for healers, a Fire spell effect is out for priests.
- **Better than worn** compares every item with what you wear in its slot (only for your own class); **Alternatives** adds the ones about as good. What you wear is not listed.
- **Hit items** (tanks only): also lists items with hit that no tank stat would bring in, and marks the hit of every item.
- A **name search**.
- All 15 **equipment slots**, each showing the icon of what you wear there; the picked slot is framed and underlined.
- **Sort** by item level, quality or name.

## From the character window
- A small **search button** on every equipment slot opens the list for that slot and compares it with what you wear:
  - **Upgrades**: more points for your role and no less of its main stat.
  - **Alternatives**: about as good, or better in total but with less of the main stat (less healing but more spirit, for example). Items whose effects are not plain stats, like trinkets with a Use effect, are listed here too.
- The button's tooltip tells how many upgrades and alternatives there are.
- Size, anchor point and X/Y offset of the buttons can be set in the options.

## The list
- Each row shows the item level, the value that matters for the role and an **Upgrade** or **Alternative** mark.
- **Click** a row to see all its drop locations: boss and instance, with the drop chance when it is known.
- A **panel** opens beside the list: the zone's map with the dungeon's entrance marked, and the boss as a 3D model you can turn (for a quest reward: the quest and who gives it). Raids have no entrance on the map yet. For a crafted item the panel shows an animated scene of the profession instead: a forge, a sewing machine, a tanning rack, an enchanting altar or a gnomish workbench (made for this addon).
- **Hover** a row for the item's tooltip and, under it, what it gives or takes against what you wear, stat by stat (+14 Spirit, -7 Healing). Hover **Worn now** for the worn item's tooltip.
- **Shift-click** links the item in chat, **ctrl-click** tries it on.

## Where to find it
The minimap button, `/flf`, or Blizzard's addon compartment.

## Themes
Styled like the other Forever addons, with all Forever themes and their colors. With the Forever Themes addon installed, it follows the central theme.

## Data
- The items and drop locations come from the dungeon and raid tables of **AtlasLoot Classic Forever**, the quest rewards, entrances and boss models from **DungeonJournal**, both read while you play. Nothing is copied from them.
- Items the client does not know yet (some new Forever items) are left out until it does; the footer counts them.

## Commands
`/flf` opens the finder, `/flf options` the options.

## Notes
- Made for WoW: Forever 1.60.1 (Interface 16001).
- Bug reports and ideas are welcome on the project's issue tracker.
