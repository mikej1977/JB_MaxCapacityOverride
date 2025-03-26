local InventoryUI = require("Starlit/client/ui/InventoryUI") -- all praise albion

local JB_MaxCapacityOverride = {}
JB_MaxCapacityOverride.CONTAINERS_TO_OVERRIDE = JB_MaxCapacityOverride.CONTAINERS_TO_OVERRIDE or {}

-- to do:
--   set up an equipped weight override?
--   vehicle trunk/seat damage lowers capacity like vanilla
--   vehicle info shows wrong capacity
--   Need to add a check when right click grab container for preventNesting

JB_MaxCapacityOverride.addContainer = function(containerType, capacity, preventNesting, _equippedWeight)
    if not getScriptManager():getItem(containerType) then
        print("ERROR - JB_MaxCapacityOverride: containerType is not a valid container")
    end
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
        equippedWeight = _equippedWeight -- or nil if not used?
    }
    --print("JB_MaxCapacityOverride: Container override added succesfully: ", containerType)
end

local function changeThatTooltip(tooltip, layout, container)
    local containerType = container:getType()
    local overrideData = JB_MaxCapacityOverride.CONTAINERS_TO_OVERRIDE[containerType]
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

---------------------------------------------------------------------------------------------------
--- ItemContainer Patches -------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------

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
        if self == chr:getInventory() and type(item) ~= "number" then
            local itemType = item:getType()
            if itemType and JB_MaxCapacityOverride.CONTAINERS_TO_OVERRIDE[itemType] then
                return true
            end
        end
        if overrideData and overrideData.preventNesting then
            if ISMouseDrag.dragging then
                local draggedItems = ISInventoryPane.getActualItems(ISMouseDrag.dragging)
                --for _, draggedItem in ipairs(draggedItems) do
                for i = 1, #draggedItems -1 do
                    if JB_MaxCapacityOverride.CONTAINERS_TO_OVERRIDE[draggedItems[i]:getType()] then
                        return false
                    end
                end
            end
            if type(item) ~= "number" then
                if item:getType() and JB_MaxCapacityOverride.CONTAINERS_TO_OVERRIDE[item:getType()] then
                    return false
                end
            end
        end
        if overrideData then
            local effectiveCapacity = self:getEffectiveCapacity(chr)
            if type(item) == "number" then
                return item + self:getContentsWeight() <= effectiveCapacity
            end
            if instanceof(item, "InventoryItem") then
                return self:getContentsWeight() + item:getUnequippedWeight() <= effectiveCapacity
            end
        end
        return original_function(self, chr, item)
    end
end

ItemContainer_hasRoomFor.GetClass()

---------------------------------------------------------------------------------------------------

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

---------------------------------------------------------------------------------------------------

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

---------------------------------------------------------------------------------------------------
--- ISEquipWeaponAction.complete Override ---------------------------------------------------------
---------------------------------------------------------------------------------------------------

local OG_ISEquipWeaponAction_complete = ISEquipWeaponAction.complete

function ISEquipWeaponAction:complete()
    
    -- this is not the container you're looking for
    --[[ if self.item:getType() ~= CONTAINER_TO_CHANGE then
        return OG_ISEquipWeaponAction_complete(self)
    end ]]

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
        self.character:removeWornItem(self.item, false)     -- this is seriously the only thing that needed changed to make this work ugh
        triggerEvent("OnClothingUpdated", self.character)
    end

    forceDropHeavyItems(self.character)

    if self.character:isEquippedClothing(self.item) then
        self.character:removeWornItem(self.item)
        triggerEvent("OnClothingUpdated", self.character)
    end

    if not self.twoHands then
        -- equip primary weapon
        if (self.primary) then
            -- if the previous weapon need to be equipped in both hands, we then remove it
            if self.character:getSecondaryHandItem() and self.character:getSecondaryHandItem():isRequiresEquippedBothHands() then
                self.character:setSecondaryHandItem(nil);
            end
            -- if this weapon is already equipped in the 2nd hand, we remove it
            if (self.character:getSecondaryHandItem() == self.item or self.character:getSecondaryHandItem() == self.character:getPrimaryHandItem()) then
                self.character:setSecondaryHandItem(nil);
            end
            -- if we are equipping a handgun and there is a weapon in the secondary hand we remove it
            if instanceof(self.item, "HandWeapon") and self.item:getSwingAnim() and self.item:getSwingAnim() == "Handgun" then
                if self.character:getSecondaryHandItem() and instanceof(self.character:getSecondaryHandItem(), "HandWeapon") then
                    self.character:setSecondaryHandItem(nil);
                end
            end
            if not self.character:getPrimaryHandItem() or self.character:getPrimaryHandItem() ~= self.item then
                self.character:setPrimaryHandItem(nil);
                self.character:setPrimaryHandItem(self.item);
            end
        else -- second hand weapon
            -- if the previous weapon need to be equipped in both hands, we then remove it
            if self.character:getPrimaryHandItem() and self.character:getPrimaryHandItem():isRequiresEquippedBothHands() then
                self.character:setPrimaryHandItem(nil);
            end
            -- if this weapon is already equipped in the 1st hand, we remove it
            if (self.character:getPrimaryHandItem() == self.item or self.character:getSecondaryHandItem() == self.character:getPrimaryHandItem()) then
                self.character:setPrimaryHandItem(nil);
            end
            -- if we are equipping a weapon and there is a handgun in the primary hand we remove it
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

    --if self.item:canBeActivated() and ((instanceof("Drainable", self.item) and self.item:getCurrentUsesFloat() > 0) or not instanceof("Drainable", self.item)) then
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

return JB_MaxCapacityOverride

---------------------------------------------------------------------------------------------------
