Pure Lua Max Capacity Override for PZ B42+

Requires Starlit Library by albion for correct tooltip capacity display

Includes Nepenthe's speed fix from Remove Bag Slowdown (used with permission)

This fix does NOT bypass the “Heavy Load” moodle slowdown.

Argument Structure (for addContainer)
("type", capacity, preventNesting, _equippedWeight, _transferTimeSpeed)

type | string | Container type (use getType() to find it)
capacity | number | Max weight container can hold
preventNesting | boolean | Prevents nesting same type containers
_equippedWeight | number | (optional) Weight of equipped container
_transferTimeSpeed | number | (optional) Transfer time override

Sample Usage:

local JB_MaxCapacityOverride = require("JB_MaxCapacityOverride")

JB_MaxCapacityOverride.addContainer("Bag_ShotgunDblSawnoffBag", 125, true, nil, 30)
JB_MaxCapacityOverride.addContainer("militarycrate", 180, true)
JB_MaxCapacityOverride.addContainer("TruckBedOpen", 500, false)
