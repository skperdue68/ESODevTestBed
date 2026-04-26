DevTestBed = DevTestBed or {}
DevTestBed.name = "DevTestBed"
DevTestBed.author = "@evainefaye"
DevTestBed.version = "1.0.0"

local DEFAULT_SAVED_VARIABLES = {
    debug = false,
}

function DevTestBed.Dbg(message)
    if DevTestBed.savedVars and DevTestBed.savedVars.debug then
        d("|c66CCFF[DevTestBed]|r " .. tostring(message))
    end
end

function DevTestBed.Print(message)
    d("|c66CCFF[DevTestBed]|r " .. tostring(message))
end

function DevTestBed.ShowHelp()
   DevTestBed.Print("|cFFFF00Commands:|r")
    DevTestBed.Print("/devtestbed or /dtb - Show this help")
    DevTestBed.Print("/dtb - Show this help")
    DevTestBed.Print("/dtb debug - Toggle debug output")
    DevTestBed.Print("/dtb ping  - Confirm the add-on is loaded")
    DevTestBed.Print("/dtb count - Count all placed furnishings in the current house")
    DevTestBed.Print("/dtb list  - List placed furnishings with furnitureId and furnitureDataId")
end


--[[
    DevTestBed.IsInHouse

    Determines whether the player is currently inside a player house.

    This function checks the current zone's house ID using the ESO API:
        GetCurrentZoneHouseId()

    Parameters:
        showMessage (boolean, optional)
            true  - Print "House Zone Only Function" if not in a house
            false - Do not print any message (default behavior)

    Returns:
        boolean
            true  - Player is inside a house
            false - Player is not inside a house

    Behavior:
        - Returns true if inside a house
        - Returns false if not in a house
        - Optionally prints a message when not in a house

    Notes:
        - Keeps messaging logic centralized
        - Prevents repeating error messages across functions

    Example:
        if not DevTestBed.IsInHouse(true) then return end
]]
function DevTestBed.IsInHouse(showMessage)
    local inHouse = GetCurrentZoneHouseId() ~= 0

    if not inHouse and showMessage then
        DevTestBed.Print("House Zone Only Function")
    end
    
    return inHouse
end



--[[
    HouseFurnishingCount

    Counts the total number of placed furnishings in the current house.

    This function uses the ESO housing iterator:
        GetNextPlacedHousingFurnitureId(previousFurnitureId)

    The iterator works by:
        - Passing nil to retrieve the first furnishing
        - Passing the last returned furnitureId to retrieve the next
        - Continuing until the API returns nil or 0, indicating the end

    Behavior:
        - Requires the player to be inside a house
        - Iterates through ALL placed furnishings
        - Increments a counter for each valid furnishing found
        - Prints the final count to chat

    Returns:
        nil (prints result via DevTestBed.Print())

    Notes:
        - furnitureId is a unique identifier for each placed instance
        - This function does NOT inspect furnishing types or states,
          it only counts total placed objects
        - This is the most reliable way to enumerate all furnishings
          in the current house using the ESO API

    Example Output:
        Total Furnishings in House: 159
]]
function DevTestBed.HouseFurnishingCount()

    -- Ensure the player is currently inside a house before running
    if not DevTestBed.IsInHouse(true) then
        return
    end

    -- Iterator state: holds the previously returned furnitureId
    -- Starts as nil to retrieve the first furnishing
    local previousId = nil

    -- Running total of furnishings found
    local count = 0

    -- Iterate through all placed furnishings
    while true do
        -- Get the next furnishing in the sequence
        local furnitureId = GetNextPlacedHousingFurnitureId(previousId)

        -- Stop when no more furnishings are returned
        if not furnitureId or furnitureId == 0 then
            break
        end

        -- Increment count for each valid furnishing
        count = count + 1

        -- Update iterator to continue traversal
        previousId = furnitureId
    end

    -- Output the total count to chat
    DevTestBed.Print("Total Furnishings in House: " .. count)
end

--[[
    ListHouseItems

    Iterates through ALL placed furnishings in the current house and prints
    identifying information for each item to the chat window.

    This function uses the ESO housing iterator:
        GetNextPlacedHousingFurnitureId(previousFurnitureId)

    Iterator Behavior:
        - Pass nil to retrieve the first placed furnishing
        - Pass the previously returned furnitureId to retrieve the next
        - Continue until the API returns nil or 0 (end of list)

    Important:
        - This iterator traverses EVERY placed furnishing in the house
        - This is the most reliable way to enumerate house contents

    For each furnishing, the function retrieves:
        - name               : Display name of the furnishing
        - furnitureId        : Unique identifier for this specific placed instance
        - furnitureDataId    : Shared identifier for all copies of this furnishing type

    Output Format:
        <Name> | furnitureID (unique): <id> | furnitureDataId (shared): <id>

    Behavior:
        - Requires the player to be inside a house
        - Iterates through every placed furnishing
        - Prints each furnishing’s identifying information
        - Tracks and prints the total number of furnishings scanned

    Returns:
        nil (results are printed to chat using DevTestBed.Print())

    Notes:
        - furnitureId is unique per placed object (instance-specific)
        - furnitureDataId is consistent across identical furnishing types
        - furnitureDataId should be used for grouping/matching items
        - This function is intended for debugging and validation

    Example Output:
        Alinor Sconce, Wall | furnitureID (unique): 123456789 | furnitureDataId (shared): 9876
        Scanned 159 placed furnishing(s).
]]
function DevTestBed.ListHouseItems()

    -- Ensure the player is currently inside a house before running
    if not DevTestBed.IsInHouse(true) then
        return
    end

    -- Iterator state: holds the previously returned furnitureId
    -- Starts as nil to retrieve the first furnishing
    local previousFurnitureId = nil

    -- Running count of scanned furnishings
    local scannedCount = 0

    -- Iterate through all placed furnishings
    while true do
        -- Retrieve the next furnishing in the sequence
        local furnitureId = GetNextPlacedHousingFurnitureId(previousFurnitureId)

        -- Exit loop when no more furnishings are returned
        if not furnitureId or furnitureId == 0 then
            break
        end

        -- Retrieve furnishing information
        local name, _, furnitureDataId = GetPlacedHousingFurnitureInfo(furnitureId)

        -- Output furnishing details to chat
        DevTestBed.Print(zo_strformat(
            "name: |c00FF00<<1>>|r - furnitureID (unique): |c00FF00<<2>>|r - furnitureDataId (shared): |c00FF00<<3>>|r",
            tostring(name),
            tostring(furnitureId),
            tostring(furnitureDataId)
        ))

        -- Advance iterator to next furnishing
        previousFurnitureId = furnitureId

        -- Increment scanned count
        scannedCount = scannedCount + 1
    end

    -- Output total number of furnishings scanned
    DevTestBed.Print("Scanned " .. tostring(scannedCount) .. " placed furnishing(s).")
end

--[[
    DevTestBed.CanEditHouse

    Determines whether the player currently has permission to edit (decorate)
    the active house.

    This function performs two checks in order:
        1. Confirms the player is inside a house
        2. Checks if the player has editing permissions

    Returns:
        boolean
            true  - Player is inside a house AND has editing permissions
            false - Player is not in a house OR lacks editing permissions

    Behavior:
        - Immediately returns false if the player is not inside a house
        - Uses HasAnyEditingPermissionsForCurrentHouse() for permission check
        - Covers owner, decorator, and any role with edit access

    Notes:
        - This is the recommended ESO API for checking housing edit permissions
        - Safe to call from anywhere without additional guards

    Example:
        if not DevTestBed.CanEditHouse() then
            DevTestBed.Print("Must be in a house with edit permissions.")
            return
        end
]]
function DevTestBed.CanEditHouse()
    -- First ensure we are inside a house
    if not DevTestBed.IsInHouse(true) then
        return false
    end

    -- Then check edit permissions
    return HasAnyEditingPermissionsForCurrentHouse()
end


function DevTestBed.HandleSlashCommand(args)
    args = string.lower(args or "")

    if args == "" or args == "help" then
        DevTestBed.ShowHelp()
        return
    end

    if args == "ping" then
        DevTestBed.Print("Loaded and ready.")
        return
    end

    if args == "count" then
        DevTestBed.HouseFurnishingCount()
        return
    end

   if args == "list" then
        DevTestBed.ListHouseItems()
        return
   end

    if args == "debug" then
        DevTestBed.savedVars.debug = not DevTestBed.savedVars.debug
        DevTestBed.Print("Debug is now " .. (DevTestBed.savedVars.debug and "ON" or "OFF") .. ".")
        return
    end

    DevTestBed.Print("Unknown command: " .. args)
    DevTestBed.ShowHelp()
end

function DevTestBed.OnAddonLoaded(eventCode, addonName)
    if addonName ~= DevTestBed.name then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(DevTestBed.name, EVENT_ADD_ON_LOADED)

    DevTestBed.savedVars = ZO_SavedVars:NewAccountWide(
        "DevTestBedSavedVariables",
        1,
        nil,
        DEFAULT_SAVED_VARIABLES
    )

    SLASH_COMMANDS["/devtestbed"] = DevTestBed.HandleSlashCommand
    SLASH_COMMANDS["/dtb"] = DevTestBed.HandleSlashCommand

    DevTestBed.Dbg("Initialized.")
end

EVENT_MANAGER:RegisterForEvent(DevTestBed.name, EVENT_ADD_ON_LOADED, DevTestBed.OnAddonLoaded)
