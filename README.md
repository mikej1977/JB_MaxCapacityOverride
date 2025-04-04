# JB_MaxCapacityOverride

Pure Lua Max Capacity Override with 92% less jank!

NOTE: This mod does nothing by itself. It is meant for the hard working modders, whom you should treat well.

This is a pure Lua MAX_CAPACITY override that does not require any manual "java mod" installation. It works with bags, crates, truck beds, etc

This mod requires Starlit Library by albion to fix up the tool tips to show the correct capacity in tooltips.

This is still a WIP. Things that need added or addressed are:

Set up an equipped weight override (if I can)
Vehicle trunk/seat damage should lower capacity like vanilla (will probably be a flag)
Vehicle Info still shows the wrong capacity
Check for when a player "right-click grabs" a container instead of letting it "bug" out.

Side note regarding the World Object Context Menu: It sucks

Includes Nepenthe's speed fix from "Remove Bag Slowdown" with permission
Make sure y'all go to Nepenthe's workshop and drop a ton of likes and awards on their superb mods!
https://steamcommunity.com/id/drstalker/myworkshopfiles/

This fix will NOT keep you moving fast if you're overloaded and have the "Heavy Load" moodle

What you should know

The addContainer args are formatted as ("type", capacity, preventNesting, _equippedWeight. _transferTimeSpeed)

"type" = string - The item type to change. If you're unsure, you can getType() on your container to get it
capacity = number - That is the max weight your container can hold
preventNesting = true/false - Prevents putting the same "type" containers in each other
_equippedWeight = number - Can be nil. Not used currently but will be the weight of the container when equipped on a character
_transferTimeSpeed = number - Can be nil. An action "time" override when transferring an item to/from your fancy container

It's recommended to use this with your own container / type to prevent overwriting someone else's glorious work

There is some error checking:
If a capacity is not passed or it's not a number, then nope
If preventNesting is not passed or it's not a boolean, then nope
We don't care about equippedWeight or _transferTimeSpeed right now. They can be nil. This might change in the near future

How To Use

An example of how to use this mod with your container/bag/vehicle:

1) Make a separate Lua file:

2) Add the code below. Replace the args with whatever you need

local JB_MaxCapacityOverride = require("JB_MaxCapacityOverride")

JB_MaxCapacityOverride.addContainer("Bag_ShotgunDblSawnoffBag", 125, true, nil, 30)
JB_MaxCapacityOverride.addContainer("militarycrate", 180, true)
JB_MaxCapacityOverride.addContainer("TruckBedOpen", 500, false)

3) Make sure to add require=\JB_MaxCapacityOverride to your mod.info
4) upload it to the workshop.
5) Bam
6) 
Available on the Steam Workshop at:
https://steamcommunity.com/sharedfiles/filedetails/?id=3452113500
