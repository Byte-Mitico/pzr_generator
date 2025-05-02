require "TimedActions/ISFixGenerator"

ISFixGeneratorWithScrewdriver = ISFixGenerator:derive("ISFixGeneratorWithScrewdriver")

function ISFixGeneratorWithScrewdriver.getMaxCondition(character)
    return character:getPerkLevel(Perks.Electricity) * 10
end

function ISFixGeneratorWithScrewdriver.validate(generator, character)
    return generator:getObjectIndex() ~= -1 and
            not generator:isActivated() and
            generator:getCondition() < ISFixGeneratorWithScrewdriver.getMaxCondition(character) and
            character:getInventory():containsTypeRecurse("Screwdriver") and
            not character:getInventory():getFirstTypeRecurse("Screwdriver"):isBroken() and
            character:getInventory():containsTypeRecurse("ElectronicsScrap")
end

function ISFixGeneratorWithScrewdriver:isValid()
    return ISFixGeneratorWithScrewdriver.validate(self.generator, self.character)
end

function ISFixGeneratorWithScrewdriver:perform()
    self.character:stopOrTriggerSound(self.sound)

    local screwdriverItem = self.character:getInventory():getFirstTypeRecurse("Screwdriver")
    if not screwdriverItem or screwdriverItem:isBroken() then return; end

    local scrapItem = self.character:getInventory():getFirstTypeRecurse("ElectronicsScrap");
    if not scrapItem then return; end;

    local max_condition = ISFixGeneratorWithScrewdriver.getMaxCondition(self.character)
    if self.generator:getCondition() >= max_condition then return; end

    self.character:removeFromHands(scrapItem)
    self.character:getInventory():Remove(scrapItem)

    self.generator:setCondition(max_condition)
    self.character:getXp():AddXP(Perks.Electricity, 5)

    -- needed to remove from queue / start next.
    ISBaseTimedAction.perform(self);
end

-- Extends the ISWorldObjectContextMenu.onFixGenerator function to check for Screwdriver
function ISFixGeneratorWithScrewdriver.onFixGeneratorWithScrewdriver(worldobjects, generator, character)
    if luautils.walkAdj(character, generator:getSquare()) then
        local screwdriverItem = character:getInventory():getFirstTagRecurse("Screwdriver")
        local scrapItem = character:getInventory():getFirstTypeRecurse("ElectronicsScrap");
        if screwdriverItem and scrapItem then
            ISInventoryPaneContextMenu.transferIfNeeded(character, screwdriverItem);
            ISInventoryPaneContextMenu.transferIfNeeded(character, scrapItem);
            -- Create the action
            ISTimedActionQueue.add(ISFixGeneratorWithScrewdriver:new(character, generator, 500));
        end;
    end
end

function ISFixGeneratorWithScrewdriver.onFillWorldObjectContextMenu(player, context, worldobjects, test)
    -- Remove the original Fix Generator option
    context:removeOptionByName(getText("ContextMenu_GeneratorFix"))

    -- Detect if the selected object is a generator
    local containsGenerator = false
    local generator = nil
    for _,obj in ipairs(worldobjects) do
        if obj:getObjectName() == "IsoGenerator" then
            containsGenerator = true
            generator = obj
            break
        end
    end

    if not containsGenerator or not generator then return; end

    -- Check if condition is less than max condition
    local character = getSpecificPlayer(player);
    if generator:getCondition() >= ISFixGeneratorWithScrewdriver.getMaxCondition(character) then return; end
    
    -- Add the new Fix Generator option
    local option = context:addOption(getText("ContextMenu_GeneratorFix"), worldobjects, ISFixGeneratorWithScrewdriver.onFixGeneratorWithScrewdriver, generator, character)
    if not character:isRecipeKnown("Generator") then
        local tooltip = ISWorldObjectContextMenu.addToolTip()
        option.notAvailable = true
        tooltip.description = getText("ContextMenu_GeneratorPlugTT")
        option.toolTip = tooltip
    end
    local containsElectronics = character:getInventory():containsTypeRecurse("ElectronicsScrap")
    local containsScrewdriver = character:getInventory():containsTypeRecurse("Screwdriver")
    local screwdriverIsBroken = false
    if containsScrewdriver then
        local screwdriverItem = character:getInventory():getFirstTypeRecurse("Screwdriver")
        if screwdriverItem and screwdriverItem:isBroken() then
            screwdriverIsBroken = true
        end
    end
    if not containsElectronics or not containsScrewdriver or screwdriverIsBroken then
        local tooltip = ISWorldObjectContextMenu.addToolTip()
        option.notAvailable = true
        tooltip.description = "Screwdriver and Scrap Electronics required for repairs."
        option.toolTip = tooltip
    end
end

Events.OnFillWorldObjectContextMenu.Add(ISFixGeneratorWithScrewdriver.onFillWorldObjectContextMenu);
