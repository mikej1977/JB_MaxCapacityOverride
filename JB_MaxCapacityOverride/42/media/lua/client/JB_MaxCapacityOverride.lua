local InventoryUI = require("Starlit/client/ui/InventoryUI") -- all praise albion

local JB_MaxCapacityOverride = {}
JB_MaxCapacityOverride.CONTAINERS_TO_OVERRIDE = JB_MaxCapacityOverride.CONTAINERS_TO_OVERRIDE or {}

--------------------------------------------------------------------------------
---- Main function to add containers to the override table ---------------------
--------------------------------------------------------------------------------

JB_MaxCapacityOverride.addContainer = function(containerType, capacity, preventNesting, _equippedWeight,
                                               _transferTimeSpeed)
    -- we don't check if the item exists because it's stupid

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
    JB_MaxCapacityOverride.CONTAINERS_TO_OVERRIDE[containerType] = {
        capacity = capacity,
        preventNesting = preventNesting,
        equippedWeight = _equippedWeight,         -- or nil if not used
        transferTimeModifier = _transferTimeSpeed -- or nil if not used
    }

    -- Thank you Nepenthe! Make sure y'all go to Nepenthe's workshop and drop a bunch of likes and awards on their superb mods!
    if getScriptManager():getItemsByType(containerType) then
        local items = getScriptManager():getItemsByType(containerType)
        for i = 0, items:size() - 1 do
            items:get(i):DoParam("RunSpeedModifier = 1.0")
        end
    end

    --print("JB_MaxCapacityOverride: Container override added succesfully: ", containerType)
end


--------------------------------------------------------------------------------
---  Function to modify the hover tooltip capacity #  --------------------------
--------------------------------------------------------------------------------

local function changeThatTooltip(tooltip, layout, container)
    local overrideData = JB_MaxCapacityOverride.CONTAINERS_TO_OVERRIDE[container:getType()]
    if overrideData then
        for i = 0, layout.items:size() - 1 do
            local layoutItem = layout.items:get(i)
            if layoutItem.label == getText("Tooltip_container_Capacity") .. ":" then
                layoutItem:setValue(tostring(overrideData.capacity), 1, 1, 1, 1)
                break
            end
        end
    end
end

InventoryUI.onFillItemTooltip:addListener(changeThatTooltip)

--------------------------------------------------------------------------------
--- ItemContainer Patches ------------------------------------------------------
--------------------------------------------------------------------------------

-- we has room for the meats?
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

        -- prevent nesting containers of the same type
        if overrideData and overrideData.preventNesting then
            if ISMouseDrag.dragging then
                local draggedItems = ISInventoryPane.getActualItems(ISMouseDrag.dragging)
                for i = 1, #draggedItems - 1 do
                    if JB_MaxCapacityOverride.CONTAINERS_TO_OVERRIDE[draggedItems[i]:getType()]
                        and draggedItems[i]:getType() == self:getType() then
                        return false
                    end
                end
            end

            if type(item) ~= "number" then
                if (item:getType() and JB_MaxCapacityOverride.CONTAINERS_TO_OVERRIDE[item:getType()])
                    and (self:getType() == item:getType()) then
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

--- when equipped, report the fake 'equipped' weight? hmmm

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
        if JB_MaxCapacityOverride.CONTAINERS_TO_OVERRIDE[self:getType()] then
            return JB_MaxCapacityOverride.CONTAINERS_TO_OVERRIDE[self:getType()].capacity
        end
        return original_function(self)
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

        if overrideData and overrideData.capacity then
            local containerCapacity = overrideData.capacity
            local effinCapacity = math.min(self:getCapacity(), containerCapacity)

            if chr ~= nil and not (instanceof(self:getParent(), "IsoPlayer") and not instanceof(self:getParent(), "IsoDeadBody")) then
                if chr:getTraits():contains("Organized") then
                    return math.max(effinCapacity * 1.3, self:getCapacity() + 1)
                elseif chr:getTraits():contains("Disorganized") then
                    return math.max(effinCapacity * 0.7, 1.0)
                end
            end

            return effinCapacity
        end

        return original_function(self, chr)
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
        if not JB_MaxCapacityOverride.CONTAINERS_TO_OVERRIDE[self:getId()] then
            return original_function(self, chr)
        end

        local function sickOfThis(maxCap, cond, min) -- public static float getNumberByCondition()
            cond = cond + 20 * (100 - cond) / 100
            local norm = cond / 100
            return math.max(min, (maxCap * norm) * 100 / 100)
        end

        if not self:isContainer() then
            return 0
        elseif self:getInventoryItem() ~= nil and self:getItemContainer() ~= nil then
            if self:getInventoryItem():isConditionAffectsCapacity() then
                return math.floor(sickOfThis(self:getItemContainer():getCapacity(), self:getCondition(), 5))
            else
                return self:getItemContainer():getCapacity()
            end
        else
            return original_function(self, chr)
        end
    end
end

VehiclePart_getContainerCapacity.GetClass()

--------------------------------------------------------------------------------



--------------------------------------------------------------------------------
--- ISEquipWeaponAction.complete Override --------------------------------------
--------------------------------------------------------------------------------

-- I am not sorry I did this
local OG_ISEquipWeaponAction_complete = ISEquipWeaponAction.complete

function ISEquipWeaponAction:complete()
    -- this is not the container you're looking for so buh bye
    if not JB_MaxCapacityOverride.CONTAINERS_TO_OVERRIDE[self.item:getType()] then
        return OG_ISEquipWeaponAction_complete(self)
    end
    if self:isAlreadyEquipped(self.item) then
        return false
    end
    if self.character:getClothingItem_Back() and self.character:getClothingItem_Back():hasTag("ReplacePrimary") and self.character:getClothingItem_Back():getClothingItemExtra() and self.character:getClothingItem_Back():getClothingItemExtra():get(0) then
        ISClothingExtraAction:performNew(self.character, self.character:getClothingItem_Back(),
            self.character:getClothingItem_Back():getClothingItemExtra():get(0))
    end
    if self.character:isEquippedClothing(self.item) then
        -- self.character:removeWornItem(self.item)         -- I guess forceDrop is true by default, so we just make it false
        self.character:removeWornItem(self.item, false) -- this is seriously the only thing that needed changed to make this work ugh
        triggerEvent("OnClothingUpdated", self.character)
    end
    forceDropHeavyItems(self.character)
    if self.character:isEquippedClothing(self.item) then
        self.character:removeWornItem(self.item)
        triggerEvent("OnClothingUpdated", self.character)
    end
    if not self.twoHands then
        if (self.primary) then
            if self.character:getSecondaryHandItem() and self.character:getSecondaryHandItem():isRequiresEquippedBothHands() then
                self.character:setSecondaryHandItem(nil);
            end
            if (self.character:getSecondaryHandItem() == self.item or self.character:getSecondaryHandItem() == self.character:getPrimaryHandItem()) then
                self.character:setSecondaryHandItem(nil);
            end
            if instanceof(self.item, "HandWeapon") and self.item:getSwingAnim() and self.item:getSwingAnim() == "Handgun" then
                if self.character:getSecondaryHandItem() and instanceof(self.character:getSecondaryHandItem(), "HandWeapon") then
                    self.character:setSecondaryHandItem(nil);
                end
            end
            if not self.character:getPrimaryHandItem() or self.character:getPrimaryHandItem() ~= self.item then
                self.character:setPrimaryHandItem(nil);
                self.character:setPrimaryHandItem(self.item);
            end
        else
            if self.character:getPrimaryHandItem() and self.character:getPrimaryHandItem():isRequiresEquippedBothHands() then
                self.character:setPrimaryHandItem(nil);
            end
            if (self.character:getPrimaryHandItem() == self.item or self.character:getSecondaryHandItem() == self.character:getPrimaryHandItem()) then
                self.character:setPrimaryHandItem(nil);
            end
            if instanceof(self.item, "HandWeapon") and self.character:getPrimaryHandItem() then
                local primary = self.character:getPrimaryHandItem()
                if instanceof(primary, "HandWeapon") and primary:getSwingAnim() and primary:getSwingAnim() == "Handgun" then
                    self.character:setPrimaryHandItem(nil);
                end
            end
            if not self.character:getSecondaryHandItem() or self.character:getSecondaryHandItem() ~= self.item then
                self.character:setSecondaryHandItem(nil);
                self.character:setSecondaryHandItem(self.item);
            end
        end
    else
        self.character:setPrimaryHandItem(nil);
        self.character:setSecondaryHandItem(nil);
        self.character:setPrimaryHandItem(self.item);
        self.character:setSecondaryHandItem(self.item);
    end
    if self.item:canBeActivated() and not self.item:hasTag("Lighter") and not instanceof(self.item, "HandWeapon") then
        self.item:setActivated(true);
        self.item:playActivateSound();
    end
    if not isServer() then
        getPlayerInventory(self.character:getPlayerNum()):refreshBackpacks()
    else
        sendEquip(self.character)
    end
    return true;
end

--------------------------------------------------------------------------------

-- not sorry I did this either
local OG_ISInventoryTransferAction_new = ISInventoryTransferAction.new
function ISInventoryTransferAction:new(character, item, srcContainer, destContainer, time)
    local f = OG_ISInventoryTransferAction_new(self, character, item, srcContainer, destContainer, time)
    if f.maxTime <= 1 then
        return f
    end
    local oldMaxTime = f.maxTime
    local timeOverride
    local CONFIG = {
        weightModifier = 1.0,
        capacityModifier = 1,
        timeMultiplier = 8,
        backpackModifier = .5,
        defaultWeight = 3
    }

    local function getTransferTime(container)
        local modifiedWeight = item:getActualWeight() > 3 and item:getActualWeight() * CONFIG.weightModifier or
        CONFIG.defaultWeight
        local containerMaxCapacity = container:getEffectiveCapacity() == 0 and 1 or container:getEffectiveCapacity()
        local containerCurrentWeight = container:getCapacityWeight()
        local backpack = getPlayerInventory(character:getPlayerNum()).inventory
        local backpackModifier = backpack == container and CONFIG.backpackModifier or 1
        local capacityContribution = CONFIG.capacityModifier * (containerCurrentWeight / containerMaxCapacity)
        local transferTime = modifiedWeight * (backpackModifier + capacityContribution)
        return transferTime * CONFIG.timeMultiplier
    end

    local function getOverrideType(container)
        -- we may want to check if equipped backpack, and get a delta
        -- from combined dest and src container combined capacity weight
        return JB_MaxCapacityOverride.CONTAINERS_TO_OVERRIDE[container:getType()]
    end

    local overrideType = getOverrideType(destContainer) or getOverrideType(srcContainer)
    if overrideType then
        if overrideType.transferTimeModifier then
            timeOverride = overrideType.transferTimeModifier
        end
        f.maxTime = getTransferTime(overrideType == getOverrideType(destContainer) and destContainer or srcContainer)
    end

    local dextrousModifier = character:HasTrait("Dextrous") and 0.5 or 1
    local clumsyModifier = (character:HasTrait("AllThumbs") or character:isWearingAwkwardGloves()) and 2.0 or 1
    f.maxTime = f.maxTime * dextrousModifier * clumsyModifier
    if oldMaxTime < f.maxTime then
        f.maxTime = oldMaxTime
    end
    if timeOverride then
        f.maxTime = timeOverride
    end
    --print("New maxTime: ", f.maxTime)
    return f
end

--------------------------------------------------------------------------------

-- don't put that container in that container
local function canWeGrabThatInvContext(playerNum, context, items)
    local containerloot = getPlayerLoot(playerNum)
    local playerLoot = getPlayerInventory(playerNum)
    local lootContainerType = containerloot.inventory:getType()
    local playerContainerType = playerLoot.inventory:getType()

    local grabOptions = {
        getText("ContextMenu_Grab"),
        getText("ContextMenu_Grab_one"),
        getText("ContextMenu_Grab_half"),
        getText("ContextMenu_Grab_all")
    }

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
        --local itemName = item:getDisplayName()
        local message = getText("RD_6fee6c8a-0cbd-4d13-bc9d-5ec5828e746f")
        local overrideData = JB_MaxCapacityOverride.CONTAINERS_TO_OVERRIDE[itemType]
        if not (overrideData and overrideData.preventNesting) then
            return
        end

        if item:isInPlayerInventory() and JB_MaxCapacityOverride.CONTAINERS_TO_OVERRIDE[lootContainerType] then
            if itemType ~= lootContainerType then return end
            markOptionNotavailable(
                getText("ContextMenu_PutInContainer", item:getDisplayName()) or
                getText("ContextMenu_Put_in_Container"), message
            )
        elseif not item:isInPlayerInventory() and JB_MaxCapacityOverride.CONTAINERS_TO_OVERRIDE[playerContainerType] then
            if itemType ~= playerContainerType then return end
            for i = 1, #grabOptions do
                markOptionNotavailable(grabOptions[i], message)
            end
        end
    end

    -- look at that code below... combo stacks can eat me
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