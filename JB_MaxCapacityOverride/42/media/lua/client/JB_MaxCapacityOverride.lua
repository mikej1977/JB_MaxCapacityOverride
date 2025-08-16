local InventoryUI = require("Starlit/client/ui/InventoryUI") -- all praise albion

local JB_MaxCapacityOverride = {}
JB_MaxCapacityOverride.CONTAINERS_TO_OVERRIDE = JB_MaxCapacityOverride.CONTAINERS_TO_OVERRIDE or {}

-- July 31, 2025 :  added mod data support to change capacity on individual containers. big thanks to Eizen for the inspiration and testing!
--                  cleaned up the code a bit. comments are a little spicier.
--                  fixed up getEffectiveCapacity to not be stupid.

--------------------------------------------------------------------------------
---- Main function to add containers to the override table ---------------------
--------------------------------------------------------------------------------

JB_MaxCapacityOverride.addContainer = function(containerType, capacity, preventNesting, _equippedWeight, _transferTimeSpeed)
    -- we don't check if the item exists anymore because it's stupid

    -- this is not 100% working. whyyy (whispers "becawsitz in da javas")
--[[     if containerType == "playerinventorycontainer" then
        Events.OnGameStart.Add(function()
            getPlayer():getInventory():setType(containerType)
        end)
    end ]]

    if capacity == nil or type(capacity) ~= "number" then
        print("ERROR - JB_MaxCapacityOverride: capacity not specified or was not a number")
        return
    end

    if preventNesting == nil or type(preventNesting) ~= "boolean" then
        print("ERROR - JB_MaxCapacityOverride: preventNesting was not specified or was not true/false")
        return
    end

    if not JB_MaxCapacityOverride.CONTAINERS_TO_OVERRIDE[containerType] then
        JB_MaxCapacityOverride.CONTAINERS_TO_OVERRIDE[containerType] = {}
    end

    capacity = math.floor(capacity * 100) / 100

    JB_MaxCapacityOverride.CONTAINERS_TO_OVERRIDE[containerType] = {
        capacity = capacity,
        preventNesting = preventNesting,
        equippedWeight = _equippedWeight,         -- or nil
        transferTimeModifier = _transferTimeSpeed -- or nil
    }

    -- Thank you Nepenthe!
    if getScriptManager():getItemsByType(containerType) then
        local items = getScriptManager():getItemsByType(containerType)
        for i = 0, items:size() - 1 do
            items:get(i):DoParam("RunSpeedModifier = 1.0")
        end
    end
    -- print("JB_MaxCapacityOverride: Container override added succesfully: ", containerType)
end

--------------------------------------------------------------------------------
---  Function to modify the hover tooltip capacity #  --------------------------
--------------------------------------------------------------------------------

local function changeThatTooltip(tooltip, layout, container)
    local overrideData = JB_MaxCapacityOverride.CONTAINERS_TO_OVERRIDE[container:getType()]
    if not overrideData then return end

    local modData = container:getModData()["JB_MaxCapacityOverride"]
    local containerCapacity = (modData and modData.capacity) or overrideData.capacity

    for i = 0, layout.items:size() - 1 do
        local layoutItem = layout.items:get(i)
        if layoutItem.label == getText("Tooltip_container_Capacity") .. ":" then
            layoutItem:setValue(tostring(containerCapacity), 1, 1, 1, 1)
            break
        end
    end
end

InventoryUI.onFillItemTooltip:addListener(changeThatTooltip)

--------------------------------------------------------------------------------
--- ItemContainer Patches ------------------------------------------------------
--------------------------------------------------------------------------------

-- do we has room for the meats?
local ItemContainer_hasRoomFor = {}

function ItemContainer_hasRoomFor.GetClass()
    local class, methodName = ItemContainer.class, "hasRoomFor"
    local metatable = __classmetatables[class]
    local metatable__index = metatable.__index
    local original_function = metatable__index[methodName]
    metatable__index[methodName] = ItemContainer_hasRoomFor.PatchClass(original_function)
end

function ItemContainer_hasRoomFor.PatchClass(original_function)
    return function(self, chr, item)
        local containerType = self:getType()
        local overrideData = JB_MaxCapacityOverride.CONTAINERS_TO_OVERRIDE[containerType]

        if containerType == "ItemContainer" and not self:isItemAllowed(item) then
            return original_function(self, chr, item)
        end

        -- don't put that container in that container
        if overrideData and overrideData.preventNesting then
            if ISMouseDrag.dragging then
                local draggedItems = ISInventoryPane.getActualItems(ISMouseDrag.dragging)
                for i = 1, #draggedItems - 1 do
                    if JB_MaxCapacityOverride.CONTAINERS_TO_OVERRIDE[draggedItems[i]:getType()] and
                        draggedItems[i]:getType() == self:getType() then
                        return false
                    end
                end
            end

            if type(item) ~= "number" then
                if (item:getType() and JB_MaxCapacityOverride.CONTAINERS_TO_OVERRIDE[item:getType()]) and
                    (self:getType() == item:getType()) then
                    return false
                end
            end
        end

        if (self == chr:getInventory() and type(item) ~= "number") and
            (item:getType() and JB_MaxCapacityOverride.CONTAINERS_TO_OVERRIDE[item:getType()]) then
            return true
        end

        if overrideData then
            if type(item) == "number" then
                return item + self:getContentsWeight() <= self:getEffectiveCapacity(chr)
            elseif instanceof(item, "InventoryItem") then
                return self:getContentsWeight() + item:getUnequippedWeight() <= self:getEffectiveCapacity(chr)
            end
        end
        return original_function(self, chr, item) -- original recipe, son
    end
end

ItemContainer_hasRoomFor.GetClass()

--------------------------------------------------------------------------------

-- return our fat caps
local ItemContainer_getCapacity = {}
function ItemContainer_getCapacity.GetClass()
    local class, methodName = ItemContainer.class, "getCapacity"
    local metatable = __classmetatables[class]
    local metatable__index = metatable.__index
    local original_function = metatable__index[methodName]
    metatable__index[methodName] = ItemContainer_getCapacity.PatchClass(original_function)
end

function ItemContainer_getCapacity.PatchClass(original_function)
    return function(self)
        local containerType = self:getType()
        local overrideData = JB_MaxCapacityOverride.CONTAINERS_TO_OVERRIDE[containerType]
        if not overrideData then return original_function(self) end

        local item = instanceof(self, "ItemContainer") and self:getContainingItem() or self:getParent()
        local modData = item and item:getModData()["JB_MaxCapacityOverride"]
        return (modData and modData.capacity) or overrideData.capacity
    end
end

ItemContainer_getCapacity.GetClass()

--------------------------------------------------------------------------------

-- return modified fat caps if organized or disorganized
local ItemContainer_getEffectiveCapacity = {}
function ItemContainer_getEffectiveCapacity.GetClass()
    local class, methodName = ItemContainer.class, "getEffectiveCapacity"
    local metatable = __classmetatables[class]
    local metatable__index = metatable.__index
    local original_function = metatable__index[methodName]
    metatable__index[methodName] = ItemContainer_getEffectiveCapacity.PatchClass(original_function)
end

function ItemContainer_getEffectiveCapacity.PatchClass(original_function)
    return function(self, chr)
        local containerType = self:getType()
        local overrideData = JB_MaxCapacityOverride.CONTAINERS_TO_OVERRIDE[containerType]
        if not (overrideData and overrideData.capacity) then
            return original_function(self, chr)
        end

        -- print(getPlayer():getInventory():getEffectiveCapacity(getPlayer()))

        local containerCapacity = overrideData.capacity

        if instanceof(self, "ItemContainer") then
            local item = self:getContainingItem() or self:getParent()
            local modData = item and item:getModData()["JB_MaxCapacityOverride"]
            if modData and modData.capacity then
                containerCapacity = modData.capacity
            end
        end

        local effCap = math.min(self:getCapacity(), containerCapacity)

        local parent = self:getParent()
        
        if chr and (not instanceof(parent, "IsoPlayer") or instanceof(parent, "IsoDeadBody")) then
            local traits = chr:getTraits()
            local multiplier = traits:contains("Organized") and 1.3 or traits:contains("Disorganized") and 0.7
            if multiplier then
                local baseCap = self:getCapacity()
                effCap = math.max(effCap * multiplier, baseCap + (multiplier > 1 and 1 or 0))
            end
        end

        return math.ceil(effCap)
    end
end

ItemContainer_getEffectiveCapacity.GetClass()

--------------------------------------------------------------------------------

local VehiclePart_getContainerCapacity = {}

function VehiclePart_getContainerCapacity.GetClass()
    local class, methodName = VehiclePart.class, "getContainerCapacity"
    local metatable = __classmetatables[class]
    local metatable__index = metatable.__index
    local original_function = metatable__index[methodName]
    metatable__index[methodName] = VehiclePart_getContainerCapacity.PatchClass(original_function)
end

function VehiclePart_getContainerCapacity.PatchClass(original_function)
    return function(self, chr)

        local overrideData = JB_MaxCapacityOverride.CONTAINERS_TO_OVERRIDE[self:getId()]
        if not overrideData then return original_function(self, chr) end
        if not self:isContainer() then return 0 end

        local inventoryItem = self:getInventoryItem()
        local itemContainer = self:getItemContainer()
        if not (inventoryItem and itemContainer) then return original_function(self, chr) end

        local function sickOfThis(maxCap, cond, min)
            cond = cond + 20 * (100 - cond) / 100
            local normalized = cond / 100
            return math.max(min, maxCap * normalized)
        end

        if inventoryItem:isConditionAffectsCapacity() then
            return math.floor(sickOfThis(itemContainer:getCapacity(), self:getCondition(), 5))
        end

        return itemContainer:getCapacity()
    end
end

VehiclePart_getContainerCapacity.GetClass()

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--- ISEquipWeaponAction.complete Override --------------------------------------
--------------------------------------------------------------------------------

-- I am not sorry I did this. A little rewrite on the vanilla to make it easier to follow
local OG_ISEquipWeaponAction_complete = ISEquipWeaponAction.complete

function ISEquipWeaponAction:complete()
    if not JB_MaxCapacityOverride.CONTAINERS_TO_OVERRIDE[self.item:getType()] then
        return OG_ISEquipWeaponAction_complete(self)
    end

    if self:isAlreadyEquipped(self.item) then
        return false
    end

    local backItem = self.character:getClothingItem_Back()
    if backItem and backItem:hasTag("ReplacePrimary") and backItem:getClothingItemExtra() then
        local extraItem = backItem:getClothingItemExtra():get(0)
        if extraItem then
            ISClothingExtraAction:performNew(self.character, backItem, extraItem)
        end
    end

    local function updateClothing(item, forceDrop)
        self.character:removeWornItem(item, forceDrop)
        triggerEvent("OnClothingUpdated", self.character)
    end

    if self.character:isEquippedClothing(self.item) then
        updateClothing(self.item, false)
    end
    forceDropHeavyItems(self.character)

    local function handleHandItem(item, isPrimaryHand)
        local equippedItem = isPrimaryHand and self.character:getPrimaryHandItem() or
        self.character:getSecondaryHandItem()
        if equippedItem and (equippedItem == item or equippedItem:isRequiresEquippedBothHands()) then
            if isPrimaryHand then
                self.character:setPrimaryHandItem(nil)
            else
                self.character:setSecondaryHandItem(nil)
            end
        end
    end

    if not self.twoHands then
        if self.primary then
            handleHandItem(self.character:getSecondaryHandItem(), false, true)
            if instanceof(self.item, "HandWeapon") and self.item:getSwingAnim() == "Handgun" then
                handleHandItem(self.character:getSecondaryHandItem(), false, true)
            end
            if self.character:getPrimaryHandItem() ~= self.item then
                self.character:setPrimaryHandItem(self.item)
            end
        else
            handleHandItem(self.character:getPrimaryHandItem(), true, false)
            if not self.character:getSecondaryHandItem() then
                self.character:setSecondaryHandItem(self.item)
            end
        end
    else
        self.character:setPrimaryHandItem(self.item)
        self.character:setSecondaryHandItem(self.item)
    end

    if self.item:canBeActivated() and not self.item:hasTag("Lighter") and not instanceof(self.item, "HandWeapon") then
        self.item:setActivated(true)
        self.item:playActivateSound()
    end

    if not isServer() then
        getPlayerInventory(self.character:getPlayerNum()):refreshBackpacks()
    else
        sendEquip(self.character)
    end

    return true
end

--------------------------------------------------------------------------------

-- not sorry I did this either. like vanilla+ transfer times
local OG_ISInventoryTransferAction_new = ISInventoryTransferAction.new

function ISInventoryTransferAction:new(character, item, srcContainer, destContainer, time)
    local f = OG_ISInventoryTransferAction_new(self, character, item, srcContainer, destContainer, time)
    if f.maxTime <= 1 then
        return f
    end

    local CONFIG = {
        timeMultiplier = 8,
        backpackModifier = 0.5,
        defaultWeight = 2
    }

    local function getTransferTime(container)
        local modifiedWeight = math.max(item:getActualWeight(), CONFIG.defaultWeight)
        local containerMaxCapacity = math.max(container:getEffectiveCapacity(), 1)
        local capacityContribution = (container:getCapacityWeight() / containerMaxCapacity)
        local equippedBackpackModifier = (getPlayerInventory(character:getPlayerNum()).inventory == container) and
        CONFIG.backpackModifier or 1
        return modifiedWeight * (equippedBackpackModifier + capacityContribution) * CONFIG.timeMultiplier
    end

    local function getOverrideType(container)
        return JB_MaxCapacityOverride.CONTAINERS_TO_OVERRIDE[container:getType()]
    end

    local overrideType = getOverrideType(destContainer) or getOverrideType(srcContainer)
    if overrideType then
        f.maxTime = overrideType.transferTimeModifier or getTransferTime(destContainer or srcContainer)
    end

    local dextrousModifier = character:HasTrait("Dextrous") and 0.5 or 1
    local clumsyModifier = (character:HasTrait("AllThumbs") or character:isWearingAwkwardGloves()) and 2.0 or 1
    f.maxTime = math.min(f.maxTime * dextrousModifier * clumsyModifier, f.maxTime)

    return f
end

--------------------------------------------------------------------------------

-- don't put that container in that container
local function canWeGrabThatInvContext(playerNum, context, items)
    local containerloot = getPlayerLoot(playerNum)
    local playerLoot = getPlayerInventory(playerNum)
    local lootContainerType = containerloot.inventory:getType()
    local playerContainerType = playerLoot.inventory:getType()

    local grabOptions = { getText("ContextMenu_Grab"), getText("ContextMenu_Grab_one"),
        getText("ContextMenu_Grab_half"),
        getText("ContextMenu_Grab_all") }

    local function markOptionNotavailable(optionName, message)
        local option = context:getOptionFromName(optionName)
        if option then
            local tooltip = ISInventoryPaneContextMenu.addToolTip()
            tooltip.description = message
            option.toolTip = tooltip
            option.notAvailable = true
        end
    end

    local function processItem(item)
        local itemType = item:getType()
        local message = getText("RD_6fee6c8a-0cbd-4d13-bc9d-5ec5828e746f") -- use radio text that's already translated
        local overrideData = JB_MaxCapacityOverride.CONTAINERS_TO_OVERRIDE[itemType]
        if not (overrideData and overrideData.preventNesting) then
            return
        end

        if item:isInPlayerInventory() and JB_MaxCapacityOverride.CONTAINERS_TO_OVERRIDE[lootContainerType] then
            if itemType ~= lootContainerType then
                return
            end
            markOptionNotavailable(
            getText("ContextMenu_PutInContainer", item:getDisplayName()) or getText("ContextMenu_Put_in_Container"),
                message)
        elseif not item:isInPlayerInventory() and JB_MaxCapacityOverride.CONTAINERS_TO_OVERRIDE[playerContainerType] then
            if itemType ~= playerContainerType then
                return
            end
            for i = 1, #grabOptions do
                markOptionNotavailable(grabOptions[i], message)
            end
        end
    end

    -- combo stacks can eat me
    for i = 1, #items do
        local item = items[i]
        local comboItems = instanceof(item, "InventoryItem") and { item } or item.items
        for j = 1, #comboItems do
            processItem(comboItems[j])
        end
    end
end

Events.OnFillInventoryObjectContextMenu.Add(canWeGrabThatInvContext)

--------------------------------------------------------------------------------

return JB_MaxCapacityOverride -- always return the meats
