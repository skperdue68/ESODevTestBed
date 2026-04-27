DevTestBed = DevTestBed or {}
DevTestBed.name = "DevTestBed"
DevTestBed.author = "@evainefaye"
DevTestBed.version = "1.0.0"

local DEFAULT_SAVED_VARIABLES = {
    debug = false,
    items = {},
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
    DevTestBed.Print("/dtb debug - Toggle debug output")
    DevTestBed.Print("/dtb ping  - Confirm the add-on is loaded")
    DevTestBed.Print("/dtb count - Count all placed furnishings in the current house")
    DevTestBed.Print("/dtb list  - List placed furnishings with furnitureId and furnitureDataId")
    DevTestBed.Print("/dtb teams - List created teams and assigned items / state")
    DevTestBed.Print("/dtb add <name> - Creates a team with the selected Item in its current state")
    DevTestBed.Print("/dtb delete <name> - Delete a team")
    DevTestBed.Print("/dtb deleteall - Delete all teams")
    DevTestBed.Print("/dtb start - Rescan team items and place them in their non-winning state")
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
            "name: |c00FF00<<1>>|r - furnitureId (unique): |c00FF00<<2>>|r - furnitureDataId (shared): |c00FF00<<3>>|r",
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
    if not DevTestBed.IsInHouse(false) then
        return false
    end

    -- Then check edit permissions
    return HasAnyEditingPermissionsForCurrentHouse()
end




--[[
    DevTestBed.GetMatchingHouseFurniture

    Scans all placed furnishings in the current house and returns every
    furnishing instance that matches the provided furnitureDataId.

    Parameters:
        targetFurnitureDataId (number)
            The shared furnitureDataId to search for

    Returns:
        table, number
            matches - table of matching placed furniture instances
            count   - number of matches found
]]
function DevTestBed.GetMatchingHouseFurniture(targetFurnitureDataId)

    local matches = {}
    local count = 0
    local previousFurnitureId = nil

    while true do
        local furnitureId = GetNextPlacedHousingFurnitureId(previousFurnitureId)

        if not furnitureId or furnitureId == 0 then
            break
        end

        local itemName, _, furnitureDataId = GetPlacedHousingFurnitureInfo(furnitureId)

        if tonumber(furnitureDataId) == tonumber(targetFurnitureDataId) then
            count = count + 1

            matches[count] = {
                furnitureId = furnitureId,
            }
        end

        previousFurnitureId = furnitureId
    end

    return matches, count
end




--[[
    DevTestBed.AddSelectedFurniture

    Assigns the currently selected housing furnishing to a named entry
    and stores its identifying information and current state.

    This function performs the following steps:
        1. Validates and normalizes the provided name
        2. Confirms the player is inside a house
        3. Confirms the player has housing edit permissions
        4. Retrieves the currently selected furnishing from the housing editor
        5. Validates the furnishing is a 2-state interactable object
        6. Reads the current state (0-based index)
        7. Retrieves furnishing identity data (name and furnitureDataId)
        8. Attempts to resolve a human-readable state name
        9. Ensures uniqueness of furnitureDataId across all saved entries
        10. Saves or replaces the entry in SavedVariables

    Parameters:
        name (string)
            A user-defined label used to identify the entry (e.g., team name)

    Returns:
        nil (results are stored in SavedVariables and confirmed via chat output)

    Behavior:
        - Requires the player to be inside a house
        - Requires housing edit permissions
        - Requires a furnishing to be selected in the housing editor
        - Only accepts interactable furnishings with exactly two states
        - Removes any existing entry using the same furnitureDataId
        - Overwrites existing entries using the same name (case-insensitive)

    Data Stored:
        name              : User-defined label for the entry
        itemName          : Display name of the furnishing
        furnitureDataId   : Shared identifier for all copies of this furnishing type
        state             : Current state index (0-based)
        stateName         : Human-readable state label (if available)

    Notes:
        - furnitureId is instance-specific and used only to read state
        - furnitureDataId is type-specific and used for long-term tracking
        - State indices are 0-based (typically 0 = OFF, 1 = ON)
        - Display state names may require a 1-based index (state + 1)
        - Not all ESO API versions expose state display names
        - Fallback labeling ("State X") is used when display names are unavailable

    Example:
        /dtb add TeamAlpha

        -- With a valid item selected, this will:
        -- 1. Capture its current ON/OFF state
        -- 2. Store the furnishing type (furnitureDataId)
        -- 3. Associate it with "TeamAlpha"
]]
function DevTestBed.AddSelectedFurniture(name)

    -- Normalize and trim the provided name
    name = tostring(name or ""):match("^%s*(.-)%s*$")

    -- Validate name input
    if name == "" then
        DevTestBed.Print("Use: /dtb add <name>")
        return
    end

    -- Ensure player is inside a house
    if not DevTestBed.IsInHouse(true) then return end

    -- Ensure player has permission to edit the house
    if not HasAnyEditingPermissionsForCurrentHouse() then
        DevTestBed.Print("You must have housing editor permissions to use this command.")
        return
    end

    -- Get the currently selected furnishing from the housing editor
    local furnitureId = HousingEditorGetSelectedFurnitureId()
    if not furnitureId then
        DevTestBed.Print("Open the housing editor and select an item first.")
        return
    end

    -- Ensure the selected object is a 2-state interactable (e.g., ON/OFF)
    local numStates = GetPlacedHousingFurnitureNumObjectStates(furnitureId)
    if not numStates or numStates ~= 2 then
        DevTestBed.Print("This command works only with interactable objects that have exactly two states.")
        return
    end

    -- Get the current state index of the selected furnishing
    -- NOTE: This is 0-based (typically 0 = OFF, 1 = ON)
    local currentState = GetPlacedHousingFurnitureCurrentObjectStateIndex(furnitureId)
    if currentState == nil then
        DevTestBed.Print("Could not read the selected item's current state.")
        return
    end

    -- Retrieve identifying information for the furnishing
    -- furnitureDataId is shared across all items of this type
    local itemName, _, furnitureDataId = GetPlacedHousingFurnitureInfo(furnitureId)
    if not furnitureDataId then
        DevTestBed.Print("Could not read the selected item's furnitureDataId.")
        return
    end

    -- Determine a readable state name
    -- ESO uses 0-based indexing for state, but display APIs are often 1-based
    local stateName = "Unknown"

    if type(GetPlacedFurniturePreviewVariationDisplayName) == "function" then
        -- Convert 0-based state to 1-based index for display lookup
        local displayIndex = currentState + 1

        -- Attempt to retrieve a readable state name from the API
        -- NOTE: Uses furnitureId (instance-level), not furnitureDataId (item-level)
        stateName = GetPlacedFurniturePreviewVariationDisplayName(furnitureId, displayIndex)
            or ("State " .. tostring(currentState))

        -- Debug output for verification
        DevTestBed.Dbg("furnitureDataId: " .. tostring(furnitureDataId))
        DevTestBed.Dbg("currentState: " .. tostring(currentState))
        DevTestBed.Dbg("displayIndex: " .. tostring(displayIndex))
        DevTestBed.Dbg("stateName: " .. tostring(stateName))
    else
        -- Fallback if API function is unavailable
        stateName = "State " .. tostring(currentState)
    end

    -- Ensure saved variables table exists
    DevTestBed.savedVars.items = DevTestBed.savedVars.items or {}

    -- Normalize key for storage (case-insensitive)
    local newKey = string.lower(name)

    -- Enforce uniqueness:
    -- If another entry already uses this furnitureDataId, remove it
    for existingKey, entry in pairs(DevTestBed.savedVars.items) do
        if existingKey ~= newKey and tonumber(entry.furnitureDataId) == tonumber(furnitureDataId) then
            DevTestBed.savedVars.items[existingKey] = nil
            DevTestBed.Print("Removed duplicate assignment from: " .. tostring(entry.name or existingKey))
        end
    end

    -- Scan the house for all placed furnishings with this same furnitureDataId
    local matchingFurniture, matchingCount = DevTestBed.GetMatchingHouseFurniture(furnitureDataId)

    -- Save or overwrite the entry for this team/name
    DevTestBed.savedVars.items[newKey] = {
        name = name,                         -- User-defined label
        itemName = itemName,                 -- ESO display name
        furnitureDataId = furnitureDataId,   -- Type identifier
        state = currentState,                -- Winning state value
        stateName = stateName,               -- Winning state display label
        matchingCount = matchingCount,       -- Number of matching placed items
        furnitureIds = matchingFurniture,    -- Sub-table of matching placed furnitureIds
    }

    -- Confirmation output to chat
    DevTestBed.Print(zo_strformat(
        "Saved |c00FF00<<1>>|r as |c00FF00<<2>>|r - State |c00FF00<<3>>|r - Found |c00FF00<<4>>|r matching item(s)",
        tostring(name),
        tostring(itemName),
        tostring(stateName),
        tostring(matchingCount)
    ))
end



--[[
    DevTestBed.ListTeams

    Lists all saved team/item assignments.

    For each saved team, this prints:
        - Team name
        - Assigned furnishing name
        - Winning state name
        - Number of matching placed furnishings

    Returns:
        nil
]]
function DevTestBed.ListTeams()

    DevTestBed.savedVars.items = DevTestBed.savedVars.items or {}

    local count = 0

    for key, entry in pairs(DevTestBed.savedVars.items) do
        count = count + 1

        DevTestBed.Print(zo_strformat(
            "Team: |c00FF00<<1>>|r - Item: |c00FF00<<2>>|r - State: |c00FF00<<3>>|r - Matching: |c00FF00<<4>>|r",
            tostring(entry.name or key),
            tostring(entry.itemName or "Unknown"),
            tostring(entry.stateName or "Unknown"),
            tostring(entry.matchingCount or 0)
        ))
    end

    if count == 0 then
        DevTestBed.Print("No teams have been created.")
        return
    end

    DevTestBed.Print("Listed " .. tostring(count) .. " team(s).")
end


--[[
    DevTestBed.DeleteTeam

    Removes a saved team assignment by name.

    Parameters:
        name (string)
            The name of the team to delete

    Returns:
        nil

    Behavior:
        - Normalizes the provided name (trim + lowercase key)
        - Checks if the team exists
        - Deletes the team if found
        - Prints confirmation or error message

    Example:
        /dtb delete TeamAlpha
]]
function DevTestBed.DeleteTeam(name)

    -- Normalize and trim input
    name = tostring(name or ""):match("^%s*(.-)%s*$")

    if name == "" then
        DevTestBed.Print("Use: /dtb delete <name>")
        return
    end

    DevTestBed.savedVars.items = DevTestBed.savedVars.items or {}

    local key = string.lower(name)
    local entry = DevTestBed.savedVars.items[key]

    if not entry then
        DevTestBed.Print("No team found with name: " .. tostring(name))
        return
    end

    -- Remove the team
    DevTestBed.savedVars.items[key] = nil

    DevTestBed.Print(zo_strformat(
        "Deleted team |c00FF00<<1>>|r (Item: |c00FF00<<2>>|r)",
        tostring(entry.name or name),
        tostring(entry.itemName or "Unknown")
    ))
end


--[[
    DevTestBed.DeleteAllTeams

    Removes ALL saved team assignments.

    Returns:
        nil

    Behavior:
        - Clears the entire items table in SavedVariables
        - Prints how many teams were removed
        - Safe to call even if no teams exist

    Example:
        /dtb deleteall
]]
function DevTestBed.DeleteAllTeams()

    DevTestBed.savedVars.items = DevTestBed.savedVars.items or {}

    local count = 0
    for _ in pairs(DevTestBed.savedVars.items) do
        count = count + 1
    end

    -- Clear all teams
    DevTestBed.savedVars.items = {}

    if count == 0 then
        DevTestBed.Print("No teams to delete.")
    else
        DevTestBed.Print("Deleted " .. tostring(count) .. " team(s).")
    end
end



--[[
    DevTestBed.Start

    Starts the team setup by:
        1. Rescanning the house for each team's furnitureDataId
        2. Saving the current matching furnitureIds
        3. Confirming all teams have the same number of matching items
        4. Setting all matching items to the non-winning state

    If team item counts do not match, processing stops.
]]
function DevTestBed.Start()

    if not DevTestBed.IsInHouse(true) then return end

    if not HasAnyEditingPermissionsForCurrentHouse() then
        DevTestBed.Print("You must have housing editor permissions to use this command.")
        return
    end

    DevTestBed.savedVars.items = DevTestBed.savedVars.items or {}

    local teamCount = 0
    local expectedMatchCount = nil
    local countsAreEqual = true

    -- First pass:
    -- Rescan every team and update saved matching furniture data.
    for key, entry in pairs(DevTestBed.savedVars.items) do
        teamCount = teamCount + 1

        local furnitureDataId = entry.furnitureDataId

        if furnitureDataId then
            local matchingFurniture, matchingCount = DevTestBed.GetMatchingHouseFurniture(furnitureDataId)

            entry.furnitureIds = matchingFurniture
            entry.matchingCount = matchingCount

            if expectedMatchCount == nil then
                expectedMatchCount = matchingCount
            elseif matchingCount ~= expectedMatchCount then
                countsAreEqual = false
            end
        else
            entry.furnitureIds = {}
            entry.matchingCount = 0
            countsAreEqual = false
        end
    end

    if teamCount == 0 then
        DevTestBed.Print("No teams have been created.")
        return
    end

    -- Stop if not all teams have the same number of matching items.
    if not countsAreEqual then
        DevTestBed.Print("|cFF0000Item counts are not equal. Start cancelled.|r")

        for key, entry in pairs(DevTestBed.savedVars.items) do
            DevTestBed.Print(zo_strformat(
                "Team: |c00FF00<<1>>|r - Item: |c00FF00<<2>>|r - Matching Count: |cFFFF00<<3>>|r",
                tostring(entry.name or key),
                tostring(entry.itemName or "Unknown"),
                tostring(entry.matchingCount or 0)
            ))
        end

        return
    end

    local changedCount = 0

    -- Second pass:
    -- Only now that counts are valid, set all items to non-winning state.
    for key, entry in pairs(DevTestBed.savedVars.items) do
        local winningState = tonumber(entry.state)

        if winningState ~= nil and entry.furnitureIds then
            local nonWinningState = winningState == 0 and 1 or 0

            for _, furnitureInfo in ipairs(entry.furnitureIds) do
                local furnitureId = furnitureInfo.furnitureId

                if furnitureId then
                    local numStates = GetPlacedHousingFurnitureNumObjectStates(furnitureId)

                    if numStates == 2 then
                        local currentState = GetPlacedHousingFurnitureCurrentObjectStateIndex(furnitureId)

                        if tonumber(currentState) ~= tonumber(nonWinningState) then
                            local result = HousingEditorRequestChangeState(furnitureId, nonWinningState)

                            DevTestBed.Dbg(zo_strformat(
                                "Team <<1>> furnitureId <<2>> set to state <<3>> result <<4>>",
                                tostring(entry.name or key),
                                tostring(furnitureId),
                                tostring(nonWinningState),
                                tostring(result)
                            ))

                            changedCount = changedCount + 1
                        end
                    end
                end
            end
        end
    end

    DevTestBed.Print(zo_strformat(
        "Started game setup. Refreshed |c00FF00<<1>>|r team(s), verified |c00FF00<<2>>|r matching item(s) per team, and placed |c00FF00<<3>>|r item(s) into their non-winning state.",
        tostring(teamCount),
        tostring(expectedMatchCount or 0),
        tostring(changedCount)
    ))
end


function DevTestBed.HandleSlashCommand(args)
    local cmd, rest = string.match(args or "", "^%s*(%S*)%s*(.-)%s*$")
    cmd = string.lower(cmd or "")

    if cmd == "" or cmd == "help" then
        DevTestBed.ShowHelp()
        return
    end

    if cmd == "ping" then
        DevTestBed.Print("Loaded and ready.")
        return
    end

    if cmd == "count" then
        DevTestBed.HouseFurnishingCount()
        return
    end

    if cmd == "list" then
        DevTestBed.ListHouseItems()
        return
    end

    if cmd == "teams" then
        DevTestBed.ListTeams()
        return
    end

    if cmd == "add" then
        DevTestBed.AddSelectedFurniture(rest)
        return
    end

    if cmd == "delete" then
        DevTestBed.DeleteTeam(rest)
        return
    end


    if cmd == "deleteall" then
        DevTestBed.DeleteAllTeams()
        return
    end

    if cmd == "start" then
        DevTestBed.Start()
        return
    end

    if cmd == "debug" then
        DevTestBed.savedVars.debug = not DevTestBed.savedVars.debug
        DevTestBed.Print("Debug is now " .. (DevTestBed.savedVars.debug and "ON" or "OFF") .. ".")
        return
    end

    DevTestBed.Print("Unknown command: " .. tostring(cmd))
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
