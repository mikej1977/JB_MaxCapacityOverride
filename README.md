Pure Lua Max Capacity Override (v1.1)
🚀 Now with 98.355% less jank!

Compatible ONLY with Build 42 — does NOT work with Build 41.

📝 Summary
This mod provides a pure Lua MAX_CAPACITY override without needing any Java mod installations. It works on:
"Equipable" Bags
Crates / Containers
Truck beds / Trunks
Sprite containers (with some limitations)

Regarding the "require=\StarlitLibrary" line in the mod.info: 
As of Build 42, the backslash is required.
https://pzwiki.net/wiki/Mod.info

⚠️ This mod does nothing on its own. It’s intended for your friendly neighborhood modder.

Requires Starlit Library by albion for correct tooltip capacity display.

🆕 07/31/25
Re-added mod data override for single containers. Example usage:
yourContainer:getModData()["JB_MaxCapacityOverride"] = { capacity = 75 }

✅ Works if the container type exists in the lookup table
✅ Compatible with bags and sprite containers
❌ Mod data override not yet compatible with trunks (WIP)

⚒️ Current To-Do List
[ ] Add equipped weight override
[ ] Handle right-click grab bug
[ ] Consider player inventory capacity override (probably not)
[ ] Fix transfer times for heavy items in world context (borked right now)

📌 Side note: The World Object Context Menu can eat me.

💨 Performance Boost
Includes Nepenthe's speed fix from Remove Bag Slowdown (used with permission).

💌 Drop likes and awards on Nepenthe’s workshop:
https://steamcommunity.com/id/drstalker/myworkshopfiles/

⚠️ This fix does NOT bypass the “Heavy Load” moodle slowdown.

🧪 Argument Structure (for addContainer)
("type", capacity, preventNesting, _equippedWeight, _transferTimeSpeed)

type | string | Container type (use getType() to find it)
capacity | number | Max weight container can hold
preventNesting | boolean | Prevents nesting same type containers
_equippedWeight | number | (optional) Weight of equipped container
_transferTimeSpeed | number | (optional) Transfer time override

✅ Error checking included for capacity and preventNesting.
❓ Equipped weight and transfer speed are optional — defaults to nil.

📦 How To Use
[ ] Create a new Lua file
[ ] Add and customize the following code:

local JB_MaxCapacityOverride = require("JB_MaxCapacityOverride")

JB_MaxCapacityOverride.addContainer("Bag_ShotgunDblSawnoffBag", 125, true, nil, 30)
JB_MaxCapacityOverride.addContainer("militarycrate", 180, true)
JB_MaxCapacityOverride.addContainer("TruckBedOpen", 500, false)

[ ] Add to your mod.info: require=JB_MaxCapacityOverride

[ ] Upload to the workshop
