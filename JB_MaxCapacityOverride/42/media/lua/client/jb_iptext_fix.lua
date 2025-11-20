function ISInventoryPage:prerender()
    local playerObj = getSpecificPlayer(self.player)
    local textManager = getTextManager()
    local uiDelta = UIManager.getMillisSinceLastRender() / 33.3
    local width = self:getWidth()
    local titleBarHeight = self:titleBarHeight()
    local fontSizeReal = getCore():getOptionFontSizeReal()

    if self.blinkContainer then
        local alpha = self.blinkAlphaContainer or 0.7

        if not self.blinkAlphaIncreaseContainer then
            alpha = alpha - (0.04 * uiDelta)
            if alpha < 0.3 then
                alpha = 0.3
                self.blinkAlphaIncreaseContainer = true
            end
        else
            alpha = alpha + (0.04 * uiDelta)
            if alpha > 0.7 then
                alpha = 0.7
                self.blinkAlphaIncreaseContainer = false
            end
        end
        self.blinkAlphaContainer = alpha

        local blinkType = self.blinkContainerType
        local currentInv = self.inventoryPane.inventory

        for _, v in ipairs(self.backpacks) do
            if not blinkType or v.inventory:getType() == blinkType then
                local finalAlpha = (v.inventory == currentInv) and alpha or (alpha * 0.75)
                v:setBackgroundRGBA(1, 0, 0, finalAlpha)
            end
        end
    end

    local height = self.isCollapsed and titleBarHeight or self:getHeight()
    local bg = self.backgroundColor
    self:drawRect(0, 0, width, height, bg.a, bg.r, bg.g, bg.b)

    if not self.blink then
        self:drawTextureScaled(self.titlebarbkg, 2, 1, width - 4, titleBarHeight - 2, 1, 1, 1, 1)
    else
        local alpha = self.blinkAlpha or 1
        if not self.blinkAlphaIncrease then
            alpha = alpha - (0.1 * uiDelta)
            if alpha < 0 then
                alpha = 0; self.blinkAlphaIncrease = true
            end
        else
            alpha = alpha + (0.1 * uiDelta)
            if alpha > 1 then
                alpha = 1; self.blinkAlphaIncrease = false
            end
        end
        self.blinkAlpha = alpha
        self:drawRect(1, 1, width - 2, titleBarHeight - 2, alpha, 1, 1, 1)
    end

    local bc = self.borderColor
    self:drawRectBorder(0, 0, width, titleBarHeight, bc.a, bc.r, bc.g, bc.b)

    if not self.isCollapsed then
        self:drawRect(width - self.buttonSize, titleBarHeight, self.buttonSize, self.inventoryPane.height, bg.a, bg.r,
            bg.g, bg.b)
    end

    if self.title and self.onCharacter then
        self:drawText(self.title, self.infoButton:getRight() + (5 - fontSizeReal) * 2, 0, 1, 1, 1, 1)
    end

    self.totalWeight = ISInventoryPage.loadWeight(self.inventoryPane.inventory)
    local roundedWeight = round(self.totalWeight, 2)
    local weightLabel = roundedWeight .. ""
    local occupied = false
    local buttonOffset = 1 + (5 - fontSizeReal) * 2

    if self.capacity then
        local inventory = self.inventoryPane.inventory
        if inventory == playerObj:getInventory() then
            weightLabel = roundedWeight .. " / " .. playerObj:getMaxWeight()
        else
            local part = inventory:getVehiclePart()
            if part and part:getId():contains("Seat") and part:getVehicle():getCharacter(part:getContainerSeatNumber()) then
                weightLabel = roundedWeight .. " / " .. (self.capacity / 4)
                occupied = true
            else
                if isClient() then
                    local itemLimit = getServerOptions():getInteger("ItemNumbersLimitPerContainer")
                    if itemLimit > 0 then
                        weightLabel = string.format("%s / %s (%d / %d)", roundedWeight, self.capacity, self.totalItems,
                            itemLimit)
                    else
                        weightLabel = roundedWeight .. " / " .. self.capacity
                    end
                else
                    weightLabel = roundedWeight .. " / " .. self.capacity
                end
            end
        end
    end

    local pinX = self.pinButton:getX()
    self:drawTextRight(weightLabel, pinX - buttonOffset, 0, 1, 1, 1, 1)

    if self.title and not self.onCharacter then
        local text = self.title
        local inventory = self.inventoryPane.inventory

        if inventory and inventory:getParent() then
            local fireTile = inventory:getParent()
            local campfire = CCampfireSystem.instance:getLuaObjectOnSquare(fireTile:getSquare())

            if campfire then
                text = text .. ": " .. ISCampingMenu.timeString(luautils.round(campfire.fuelAmt))
            elseif fireTile:isFireInteractionObject() then
                -- shouldBeVisible = truev     it's preserved forever here
                if fireTile:isPropaneBBQ() and not fireTile:hasPropaneTank() then
                    text = text .. ": " .. getText("IGUI_BBQ_NeedsPropaneTank")
                else
                    text = text .. ": " .. tostring(ISCampingMenu.timeString(fireTile:getFuelAmount()))
                end
            end
        end

        if occupied then
            text = text .. " " .. getText("IGUI_invpage_Occupied")
        end

        local fontHgt = textManager:getFontHeight(self.font)
        local weightWid = textManager:MeasureStringX(UIFont.Small, weightLabel)

        local weightX = pinX - buttonOffset - weightWid - 7

        local centeredY = (titleBarHeight - fontHgt) / 2

        self:drawTextRight(text, weightX, centeredY, 1, 1, 1, 1)
    end

    self:setStencilRect(0, 0, width + 1, height)
    self.containerButtonPanel:keepSelectedButtonVisible()

    if playerObj and playerObj:isInvPageDirty() then
        playerObj:setInvPageDirty(false)
        ISInventoryPage.renderDirty = true
    end

    if ISInventoryPage.renderDirty then
        ISInventoryPage.renderDirty = false
        ISInventoryPage.dirtyUI()
    end
end