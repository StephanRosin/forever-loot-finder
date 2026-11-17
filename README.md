# Forever Loot Finder

A gear finder for WoW: Forever. Pick a class, one of its roles and an equipment slot, and the list shows every
dungeon and raid drop, world drop, dungeon quest reward (blue and better) and crafted item that suits them, sorted by
points for the role (trinkets' Use effects counted at 75%), with where to get it. "Better than worn" compares each item with what you wear in that slot: **Upgrade**
(more for the role, no less of its main stat) or **Alternative** (about as good, or a judgement call such as less
healing but more spirit). A search button on every slot of the character window opens the list for that slot.

Clicking a row opens a panel beside the list: the zone's map with the dungeon's entrance marked and the boss as a
3D model, or the quest and its giver, or the profession, skill and reagents under an animated
scene of the profession, with the reagents' auction house prices (Auctionator's, or the addon's own Scan button
on the auction house). Hovering a row shows what it gives or
takes against the worn item, stat by stat. Styled like the other Forever addons, registered with Forever Themes.
English and German.

## Data

Nothing is copied: the tables are read while playing.

- **AtlasLoot Classic Forever** (required): boss drops from `AtlasLootClassic_DungeonsAndRaids` and crafted items
  from `AtlasLootClassic_Crafting`, world epics from `AtlasLootClassic_Collections` (all load on demand, not in
  combat), drop chances from its drop rate data.
- **Wowhead Forever** (snapshot in `Source.lua`): blue and purple world drops from level 30; trinkets' Use effects
  as stats in `Rules.lua` (`Rules.ON_USE`), both read by hand from its tooltips.
- **DungeonJournal** (required): its dungeons' quests and their reward items, the dungeon entrances on the world
  map, the bosses' model ids.

Roles are judged by item stats (`Rules.lua`); items without plain stats by their Use, Equip and Chance-on-hit
texts (words per role, spell schools per class). Items the client does not know yet are left out until it does.

## Development

    tests/run                    # Lua 5.1, as in the game
    ./install "<WoW>/_forever_/Interface/AddOns"
    tools/package                # dist/ForeverLootFinder-<version>.zip
    blender -b --factory-startup -P art/<profession>.py -- <dir>   # 40 frames, 512x384 (Cycles)
    python3 art/pack.py <dir> <profession> Media/Professions       # two 2048 sheets
    tools/release release "<changelog>"    # bump ## Version first; needs ## X-Curse-Project-ID in the TOC
