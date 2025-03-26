# JB_MaxCapacityOverride

Max Capacity Override for Project Zomboid

This is a pure Lua override that does not require any manual "java mod" installation.
It works with bags, crates, truck beds, etc

This mod requires Starlit Library by albion / demiurgeQuantified to fix up the tool tips to show the correct capacity.
https://github.com/demiurgeQuantified/StarlitLibrary

The addContainer args are formatted as ("type", capacity, preventNesting, equippedWeight)

 -- "type" = string - The item type to change. If you're unsure, you can getType() on your item to get it

 -- capacity = number - That is the max weight your container can hold

 -- preventNesting = true/false - Prevents putting the same "type" items in each other

 -- equippedWeight = number - Not used currently but will be the weight of the container when equipped on a character

It is recommended to use this with your own container / type to prevent overwriting someone else's glorious work.

There is some error checking:
If your item type doesn't exist, nope.
If a capacity is not passed or it's not a number, nope.
if preventNesting is not passed or it's not a boolean, nope.
We don't care about equippedWeight right now, it can be nil. This will change in the near future though.

An example of how to use this mod with your container/bag/vehicle:

Make sure to add require=\JB_MaxCapacityOverride to your mod.info

local JB_MaxCapacityOverride = require("JB_MaxCapacityOverride")

JB_MaxCapacityOverride.addContainer("Bag_ShotgunDblSawnoffBag", 125, true, 25)
JB_MaxCapacityOverride.addContainer("militarycrate", 180, true)
JB_MaxCapacityOverride.addContainer("TruckBedOpen", 500, false)

Available on the Steam Workshop at:
https://steamcommunity.com/sharedfiles/filedetails/?id=3452113500
