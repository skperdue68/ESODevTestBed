DevTestBed = DevTestBed or {}
DevTestBed.name = "DevTestBed"
DevTestBed.author = "@evainefaye"
DevTestBed.version = "1.0.0"

local DEFAULT_SAVED_VARIABLES = {
    debug = false,
    items = {},
    warTeams = {},
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
    DevTestBed.Print("/dtb war teams - List War teams")
    DevTestBed.Print("/dtb add <name> - Creates a team with the selected Item in its current state")
    DevTestBed.Print("/dtb war add <name> - Creates a War team with the selected item/current state")
    DevTestBed.Print("/dtb delete <name> - Delete a team")
    DevTestBed.Print("/dtb deleteall - Delete all teams")
    DevTestBed.Print("/dtb war delete <name> - Delete a War team")
    DevTestBed.Print("/dtb war deleteall - Delete all War teams")
    DevTestBed.Print("/dtb start threshold <count> [minutes] - Start threshold mode. Optional minutes must be 1-60 and enables timed/overtime scoring")
    DevTestBed.Print("/dtb start target <count> [minutes] - Start target mode. Randomly chooses count monitored items per team; optional minutes works like threshold")
    DevTestBed.Print("/dtb start war [minutes] - Start War mode. All matching items count; optional minutes works like threshold")
    DevTestBed.Print("/dtb reset - Stop the active game and set all team items to their non-winning state")
    DevTestBed.Print("/dtb window - Toggle the game status window")
    DevTestBed.Print("/dtb controls - Toggle the game control panel")
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

function DevTestBed.GetStateDisplayName(furnitureId, stateIndex)
    stateIndex = tonumber(stateIndex)

    if stateIndex == nil then
        return "Unknown"
    end

    if type(GetPlacedFurniturePreviewVariationDisplayName) == "function" then
        local displayIndex = stateIndex + 1
        local stateName = GetPlacedFurniturePreviewVariationDisplayName(furnitureId, displayIndex)

        if stateName and stateName ~= "" then
            return stateName
        end
    end

    return "State " .. tostring(stateIndex)
end

function DevTestBed.GetWarTeamTable()
    DevTestBed.savedVars = DevTestBed.savedVars or {}
    DevTestBed.savedVars.warTeams = DevTestBed.savedVars.warTeams or {}
    return DevTestBed.savedVars.warTeams
end

function DevTestBed.GetActiveGameTeamTable()
    if DevTestBed.game and DevTestBed.game.mode == "war" then
        return DevTestBed.GetWarTeamTable()
    end

    return DevTestBed.savedVars and DevTestBed.savedVars.items or {}
end

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

    if DevTestBed.ui and DevTestBed.ui.controlWindow then
        DevTestBed.PopulateControlCountDropdown()
        DevTestBed.RefreshControlWindow()
    end
end





--[[
    DevTestBed.AddSelectedWarTeam

    Creates or replaces a War team assignment.

    War team rules:
        - Multiple teams may use the same furnishing type
        - Each team using that furnishing type must have a different win state
        - The maximum number of teams for one furnishing type is the number of
          object states that furnishing supports
]]
function DevTestBed.AddSelectedWarTeam(name)
    name = tostring(name or ""):match("^%s*(.-)%s*$")

    if name == "" then
        DevTestBed.Print("Use: /dtb war add <name>")
        return
    end

    if not DevTestBed.IsInHouse(true) then return end

    if not HasAnyEditingPermissionsForCurrentHouse() then
        DevTestBed.Print("You must have housing editor permissions to use this command.")
        return
    end

    local furnitureId = HousingEditorGetSelectedFurnitureId()
    if not furnitureId then
        DevTestBed.Print("Open the housing editor and select an item first.")
        return
    end

    local numStates = GetPlacedHousingFurnitureNumObjectStates(furnitureId)
    if not numStates or numStates < 2 then
        DevTestBed.Print("War teams require an interactable object with at least two states.")
        return
    end

    local currentState = GetPlacedHousingFurnitureCurrentObjectStateIndex(furnitureId)
    if currentState == nil then
        DevTestBed.Print("Could not read the selected item's current state.")
        return
    end

    currentState = tonumber(currentState)

    local itemName, _, furnitureDataId = GetPlacedHousingFurnitureInfo(furnitureId)
    if not furnitureDataId then
        DevTestBed.Print("Could not read the selected item's furnitureDataId.")
        return
    end

    local warTeams = DevTestBed.GetWarTeamTable()
    local newKey = string.lower(name)
    local sameItemTeamCount = 0

    for existingKey, entry in pairs(warTeams) do
        if existingKey ~= newKey and tonumber(entry.furnitureDataId) == tonumber(furnitureDataId) then
            sameItemTeamCount = sameItemTeamCount + 1

            if tonumber(entry.state) == currentState then
                DevTestBed.Print(zo_strformat(
                    "War team not saved. |c00FF00<<1>>|r already uses |cFFFF00<<2>>|r for this item.",
                    tostring(entry.name or existingKey),
                    tostring(entry.stateName or ("State " .. tostring(currentState)))
                ))
                return
            end
        end
    end

    local existingEntry = warTeams[newKey]
    local isReplacingSameItem = existingEntry and tonumber(existingEntry.furnitureDataId) == tonumber(furnitureDataId)

    if not isReplacingSameItem and sameItemTeamCount >= tonumber(numStates) then
        DevTestBed.Print(zo_strformat(
            "War team not saved. This item has only |cFFFF00<<1>>|r state(s), so it can only support |cFFFF00<<1>>|r War team(s).",
            tostring(numStates)
        ))
        return
    end

    local matchingFurniture, matchingCount = DevTestBed.GetMatchingHouseFurniture(furnitureDataId)
    local stateName = DevTestBed.GetStateDisplayName(furnitureId, currentState)

    warTeams[newKey] = {
        name = name,
        itemName = itemName,
        furnitureDataId = furnitureDataId,
        state = currentState,
        stateName = stateName,
        numStates = numStates,
        matchingCount = matchingCount,
        furnitureIds = matchingFurniture,
    }

    DevTestBed.Print(zo_strformat(
        "Saved War team |c00FF00<<1>>|r as |c00FF00<<2>>|r - Win State |cFFFF00<<3>>|r - Found |c00FF00<<4>>|r matching item(s)",
        tostring(name),
        tostring(itemName),
        tostring(stateName),
        tostring(matchingCount)
    ))

    if DevTestBed.ui and DevTestBed.ui.controlWindow then
        DevTestBed.PopulateControlCountDropdown()
        DevTestBed.RefreshControlWindow()
    end
end

function DevTestBed.ListWarTeams()
    local warTeams = DevTestBed.GetWarTeamTable()
    local count = 0

    for key, entry in pairs(warTeams) do
        count = count + 1
        DevTestBed.Print(zo_strformat(
            "War Team: |c00FF00<<1>>|r - Item: |c00FF00<<2>>|r - Win State: |cFFFF00<<3>>|r (<<4>>) - Matching: |c00FF00<<5>>|r",
            tostring(entry.name or key),
            tostring(entry.itemName or "Unknown"),
            tostring(entry.stateName or "Unknown"),
            tostring(entry.state or "?"),
            tostring(entry.matchingCount or 0)
        ))
    end

    if count == 0 then
        DevTestBed.Print("No War teams have been created.")
        return
    end

    DevTestBed.Print("Listed " .. tostring(count) .. " War team(s).")
end

function DevTestBed.DeleteWarTeam(name)
    name = tostring(name or ""):match("^%s*(.-)%s*$")

    if name == "" then
        DevTestBed.Print("Use: /dtb war delete <name>")
        return
    end

    local warTeams = DevTestBed.GetWarTeamTable()
    local key = string.lower(name)
    local entry = warTeams[key]

    if not entry then
        DevTestBed.Print("No War team found with name: " .. tostring(name))
        return
    end

    warTeams[key] = nil

    DevTestBed.Print(zo_strformat(
        "Deleted War team |c00FF00<<1>>|r (Item: |c00FF00<<2>>|r)",
        tostring(entry.name or name),
        tostring(entry.itemName or "Unknown")
    ))

    if DevTestBed.ui and DevTestBed.ui.controlWindow then
        DevTestBed.PopulateControlCountDropdown()
        DevTestBed.RefreshControlWindow()
    end
end

function DevTestBed.DeleteAllWarTeams()
    local warTeams = DevTestBed.GetWarTeamTable()
    local count = 0

    for _ in pairs(warTeams) do
        count = count + 1
    end

    DevTestBed.savedVars.warTeams = {}

    if count == 0 then
        DevTestBed.Print("No War teams to delete.")
    else
        DevTestBed.Print("Deleted " .. tostring(count) .. " War team(s).")
    end

    if DevTestBed.ui and DevTestBed.ui.controlWindow then
        DevTestBed.PopulateControlCountDropdown()
        DevTestBed.RefreshControlWindow()
    end
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

    if DevTestBed.ui and DevTestBed.ui.controlWindow then
        DevTestBed.PopulateControlCountDropdown()
        DevTestBed.RefreshControlWindow()
    end
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

    if DevTestBed.ui and DevTestBed.ui.controlWindow then
        DevTestBed.PopulateControlCountDropdown()
        DevTestBed.RefreshControlWindow()
    end
end



--[[
    DevTestBed Game Status Window

    Creates and manages a small movable/resizable status window used while a
    game is running. The window shows:
        - Current game mode
        - Team name and item name
        - Current win count / required win count / percent complete
        - Winner information once a team wins

    The window can be toggled with:
        /dtb window
]]
DevTestBed.ui = DevTestBed.ui or {}

DevTestBed.GAME_STATUS_ROW_DATA_TYPE = 1
DevTestBed.GAME_STATUS_ROW_HEIGHT = 68

function DevTestBed.SetupGameStatusRow(control, data)
    if not control or not data then return end

    local percent = 0
    if tonumber(data.requiredCount or 0) > 0 then
        percent = math.floor((tonumber(data.currentCount or 0) / tonumber(data.requiredCount)) * 100)
    end

    control:SetFont("ZoFontGame")
    control:SetColor(1, 1, 1, 1)
    local winStateText = tostring(data.winStateName or "Unknown")
    if data.winState ~= nil then
        winStateText = winStateText .. " (" .. tostring(data.winState) .. ")"
    end

    control:SetText(zo_strformat(
        "|c00FF00<<1>>|r - <<2>> - Win State: |cFFFF00<<3>>|r\n<<4>> / <<5>>  <<6>>%",
        tostring(data.teamName or "Unknown"),
        tostring(data.itemName or "Unknown"),
        winStateText,
        tostring(data.currentCount or 0),
        tostring(data.requiredCount or 0),
        tostring(percent)
    ))

    if control.SetHorizontalAlignment then
        control:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    end

    if control.SetVerticalAlignment then
        control:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    end
end

function DevTestBed.CreateGameStatusWindow()
    if DevTestBed.ui.statusWindow then
        return DevTestBed.ui.statusWindow
    end

    local wm = WINDOW_MANAGER

    local window = wm:CreateTopLevelWindow("DevTestBedGameStatusWindow")
    window:SetDimensions(420, 360)
    window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    window:SetMouseEnabled(true)
    window:SetMovable(true)
    window:SetClampedToScreen(true)
    window:SetHidden(true)

    if window.SetResizable then
        window:SetResizable(true)
    end

    if window.SetResizeHandleSize then
        window:SetResizeHandleSize(16)
    end

    if window.SetDimensionConstraints then
        window:SetDimensionConstraints(300, 220, 900, 700)
    end

    local backdrop = wm:CreateControl("$(parent)Backdrop", window, CT_BACKDROP)
    backdrop:SetAnchorFill(window)
    backdrop:SetCenterColor(0, 0, 0, 0.82)
    backdrop:SetEdgeColor(0.25, 0.55, 1, 1)
    backdrop:SetEdgeTexture(nil, 1, 1, 2)

    local title = wm:CreateControl("$(parent)Title", window, CT_LABEL)
    title:SetAnchor(TOPLEFT, window, TOPLEFT, 12, 8)
    title:SetAnchor(TOPRIGHT, window, TOPRIGHT, -36, 8)
    title:SetFont("ZoFontWinH2")
    title:SetColor(0.75, 0.9, 1, 1)
    title:SetText("DevTestBed Game")

    local closeButton = wm:CreateControl("$(parent)Close", window, CT_BUTTON)
    closeButton:SetDimensions(24, 24)
    closeButton:SetAnchor(TOPRIGHT, window, TOPRIGHT, -8, 6)
    closeButton:SetFont("ZoFontGameBold")
    closeButton:SetText("X")
    closeButton:SetHandler("OnClicked", function()
        window:SetHidden(true)
    end)

    local modeLabel = wm:CreateControl("$(parent)Mode", window, CT_LABEL)
    modeLabel:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 0, 8)
    modeLabel:SetAnchor(TOPRIGHT, window, TOPRIGHT, -12, 40)
    modeLabel:SetFont("ZoFontGameBold")
    modeLabel:SetColor(1, 1, 1, 1)
    modeLabel:SetText("Mode: None")

    local winnerLabel = wm:CreateControl("$(parent)Winner", window, CT_LABEL)
    winnerLabel:SetAnchor(TOPLEFT, modeLabel, BOTTOMLEFT, 0, 6)
    winnerLabel:SetAnchor(TOPRIGHT, modeLabel, BOTTOMRIGHT, 0, 6)
    winnerLabel:SetFont("ZoFontGameBold")
    winnerLabel:SetColor(0, 1, 0, 1)
    winnerLabel:SetText("")

    local scrollList = wm:CreateControlFromVirtual("$(parent)ScrollList", window, "ZO_ScrollList")
    scrollList:SetAnchor(TOPLEFT, winnerLabel, BOTTOMLEFT, 0, 10)
    scrollList:SetAnchor(BOTTOMRIGHT, window, BOTTOMRIGHT, -12, -12)

    ZO_ScrollList_AddDataType(
        scrollList,
        DevTestBed.GAME_STATUS_ROW_DATA_TYPE,
        "ZO_SelectableLabel",
        DevTestBed.GAME_STATUS_ROW_HEIGHT,
        DevTestBed.SetupGameStatusRow
    )

    DevTestBed.ui.statusWindow = window
    DevTestBed.ui.statusTitle = title
    DevTestBed.ui.statusModeLabel = modeLabel
    DevTestBed.ui.statusWinnerLabel = winnerLabel
    DevTestBed.ui.statusScrollList = scrollList

    window:SetHandler("OnResizeStop", function()
        DevTestBed.RefreshGameStatusWindow()
    end)

    return window
end

function DevTestBed.RefreshGameStatusWindow()
    if not DevTestBed.ui.statusWindow then
        return
    end

    local game = DevTestBed.game or {}
    local modeText = DevTestBed.GetGameModeDisplayText()

    DevTestBed.ui.statusModeLabel:SetText("Mode: " .. tostring(modeText))

    if game.winner then
        DevTestBed.ui.statusWinnerLabel:SetText("Winner: " .. tostring(game.winner))
    else
        DevTestBed.ui.statusWinnerLabel:SetText("")
    end

    local scrollList = DevTestBed.ui.statusScrollList
    if not scrollList then
        return
    end

    local dataList = ZO_ScrollList_GetDataList(scrollList)
    for i = #dataList, 1, -1 do
        dataList[i] = nil
    end

    for key, entry in pairs(DevTestBed.GetActiveGameTeamTable()) do
        if entry.trackedFurnitureIds or game.active then
            table.insert(dataList, ZO_ScrollList_CreateDataEntry(
                DevTestBed.GAME_STATUS_ROW_DATA_TYPE,
                {
                    teamName = entry.name or key,
                    itemName = entry.itemName or "Unknown",
                    winState = entry.state,
                    winStateName = entry.stateName or "Unknown",
                    currentCount = entry.currentWinCount or 0,
                    requiredCount = entry.requiredWinCount or game.threshold or 0,
                }
            ))
        end
    end

    ZO_ScrollList_Commit(scrollList)
end

function DevTestBed.ShowGameStatusWindow()
    local window = DevTestBed.CreateGameStatusWindow()
    window:SetHidden(false)
    DevTestBed.RefreshGameStatusWindow()
end

function DevTestBed.HideGameStatusWindow()
    if DevTestBed.ui.statusWindow then
        DevTestBed.ui.statusWindow:SetHidden(true)
    end
end

function DevTestBed.ToggleGameStatusWindow()
    local window = DevTestBed.CreateGameStatusWindow()

    if window:IsHidden() then
        window:SetHidden(false)
        DevTestBed.RefreshGameStatusWindow()
    else
        window:SetHidden(true)
    end
end


--[[
    DevTestBed Control Panel Window

    Admin-style window used to select game mode, required count, optional time
    limit, and to start/reset games without typing slash commands.
]]
DevTestBed.CONTROL_TIME_OPTIONS = {
    { label = "None", value = nil },
    { label = "1 minute", value = 1 },
    { label = "2 minutes", value = 2 },
    { label = "3 minutes", value = 3 },
    { label = "5 minutes", value = 5 },
    { label = "10 minutes", value = 10 },
    { label = "15 minutes", value = 15 },
    { label = "20 minutes", value = 20 },
    { label = "30 minutes", value = 30 },
    { label = "45 minutes", value = 45 },
    { label = "60 minutes", value = 60 },
}

function DevTestBed.CountSavedTeams()
    local count = 0
    for _ in pairs(DevTestBed.savedVars and DevTestBed.savedVars.items or {}) do
        count = count + 1
    end
    return count
end

function DevTestBed.RefreshTeamMatchingCounts()
    if not DevTestBed.savedVars then return end
    DevTestBed.savedVars.items = DevTestBed.savedVars.items or {}

    -- When in a house, rescan so the control panel count dropdown reflects the
    -- currently placed furnishings. Outside a house, fall back to saved counts.
    if not DevTestBed.IsInHouse(false) then
        return
    end

    for _, entry in pairs(DevTestBed.savedVars.items) do
        if entry.furnitureDataId then
            local matchingFurniture, matchingCount = DevTestBed.GetMatchingHouseFurniture(entry.furnitureDataId)
            entry.furnitureIds = matchingFurniture
            entry.matchingCount = matchingCount
        end
    end

    DevTestBed.savedVars.warTeams = DevTestBed.savedVars.warTeams or {}
    for _, entry in pairs(DevTestBed.savedVars.warTeams) do
        if entry.furnitureDataId then
            local matchingFurniture, matchingCount = DevTestBed.GetMatchingHouseFurniture(entry.furnitureDataId)
            entry.furnitureIds = matchingFurniture
            entry.matchingCount = matchingCount
        end
    end
end

function DevTestBed.GetControlPanelCountInfo(mode, skipRescan)
    mode = string.lower(tostring(mode or "threshold"))

    if not skipRescan then
        DevTestBed.RefreshTeamMatchingCounts()
    end

    if mode == "war" then
        local warTeamCount = 0
        local firstFurnitureDataId = nil
        local matchingCount = nil
        local sameItem = true

        for _, entry in pairs(DevTestBed.savedVars and DevTestBed.savedVars.warTeams or {}) do
            warTeamCount = warTeamCount + 1

            if firstFurnitureDataId == nil then
                firstFurnitureDataId = entry.furnitureDataId
                matchingCount = tonumber(entry.matchingCount or 0) or 0
            elseif tonumber(entry.furnitureDataId) ~= tonumber(firstFurnitureDataId) then
                sameItem = false
            end
        end

        if warTeamCount == 0 then
            return 0, "No War teams assigned", warTeamCount
        end

        if not sameItem then
            return 0, "War teams use different items", warTeamCount
        end

        if tonumber(matchingCount or 0) < 1 then
            return 0, "No matching items found", warTeamCount
        end

        return tonumber(matchingCount), nil, warTeamCount
    end

    local teamCount = 0
    local minCount = nil
    local firstCount = nil
    local countsAreEqual = true

    for _, entry in pairs(DevTestBed.savedVars and DevTestBed.savedVars.items or {}) do
        teamCount = teamCount + 1
        local count = tonumber(entry.matchingCount or 0) or 0

        if minCount == nil or count < minCount then
            minCount = count
        end

        if firstCount == nil then
            firstCount = count
        elseif count ~= firstCount then
            countsAreEqual = false
        end
    end

    if teamCount == 0 then
        return 0, "No teams assigned", teamCount
    end

    if mode == "threshold" then
        if not countsAreEqual then
            return 0, "Team counts do not match", teamCount
        end

        if tonumber(firstCount or 0) < 1 then
            return 0, "No matching items found", teamCount
        end

        return tonumber(firstCount), nil, teamCount
    end

    if tonumber(minCount or 0) < 1 then
        return 0, "No matching items found", teamCount
    end

    return tonumber(minCount), nil, teamCount
end

function DevTestBed.GetControlPanelSelectedMode()
    return DevTestBed.ui.selectedGameMode or "threshold"
end

function DevTestBed.GetControlPanelSelectedCount()
    return tonumber(DevTestBed.ui.selectedRequiredCount or 1) or 1
end

function DevTestBed.GetControlPanelSelectedMinutes()
    return DevTestBed.ui.selectedTimeLimitMinutes
end

function DevTestBed.SafeClearComboBox(comboBox)
    if not comboBox then return end

    if comboBox.ClearItems then
        comboBox:ClearItems()
    end
end

function DevTestBed.PopulateControlModeDropdown()
    local combo = DevTestBed.ui.controlModeCombo
    if not combo then return end

    DevTestBed.SafeClearComboBox(combo)

    local function addMode(label, value)
        combo:AddItem(combo:CreateItemEntry(label, function()
            DevTestBed.ui.selectedGameMode = value
            DevTestBed.PopulateControlCountDropdown()
            DevTestBed.RefreshControlWindow()
        end))
    end

    addMode("Threshold", "threshold")
    addMode("Target", "target")
    addMode("War", "war")

    DevTestBed.ui.selectedGameMode = DevTestBed.ui.selectedGameMode or "threshold"

    if combo.SelectItemByIndex then
        local selectedIndex = 1
        if DevTestBed.ui.selectedGameMode == "target" then
            selectedIndex = 2
        elseif DevTestBed.ui.selectedGameMode == "war" then
            selectedIndex = 3
        end
        combo:SelectItemByIndex(selectedIndex)
    elseif combo.SelectFirstItem then
        combo:SelectFirstItem()
    end
end

function DevTestBed.PopulateControlTimeDropdown()
    local combo = DevTestBed.ui.controlTimeCombo
    if not combo then return end

    DevTestBed.SafeClearComboBox(combo)

    for _, option in ipairs(DevTestBed.CONTROL_TIME_OPTIONS) do
        combo:AddItem(combo:CreateItemEntry(option.label, function()
            DevTestBed.ui.selectedTimeLimitMinutes = option.value
            DevTestBed.RefreshControlWindow()
        end))
    end

    if combo.SelectItemByIndex then
        combo:SelectItemByIndex(1)
    elseif combo.SelectFirstItem then
        combo:SelectFirstItem()
    end
end

function DevTestBed.PopulateControlCountDropdown()
    local combo = DevTestBed.ui.controlCountCombo
    if not combo then return end

    DevTestBed.SafeClearComboBox(combo)

    local mode = DevTestBed.GetControlPanelSelectedMode()
    local maxCount = DevTestBed.GetControlPanelCountInfo(mode)

    if tonumber(maxCount or 0) < 1 then
        DevTestBed.ui.selectedRequiredCount = nil
        combo:AddItem(combo:CreateItemEntry("No valid count", function()
            DevTestBed.ui.selectedRequiredCount = nil
        end))

        if combo.SelectFirstItem then
            combo:SelectFirstItem()
        end
        return
    end

    if mode == "war" then
        DevTestBed.ui.selectedRequiredCount = maxCount
        combo:AddItem(combo:CreateItemEntry("All Items (" .. tostring(maxCount) .. ")", function()
            DevTestBed.ui.selectedRequiredCount = maxCount
            DevTestBed.RefreshControlWindow()
        end))

        if combo.SelectFirstItem then
            combo:SelectFirstItem()
        end
        return
    end

    for count = 1, maxCount do
        local label = tostring(count)

        -- UX upgrade: mark the last value so the user can see the highest valid
        -- dynamic value without needing to count the dropdown entries.
        if count == maxCount then
            if mode == "threshold" then
                label = label .. " (All Items)"
            else
                label = label .. " (Max)"
            end
        end

        combo:AddItem(combo:CreateItemEntry(label, function()
            DevTestBed.ui.selectedRequiredCount = count
            DevTestBed.RefreshControlWindow()
        end))
    end

    if not DevTestBed.ui.selectedRequiredCount or DevTestBed.ui.selectedRequiredCount > maxCount then
        DevTestBed.ui.selectedRequiredCount = 1
    end

    if combo.SelectItemByIndex then
        combo:SelectItemByIndex(DevTestBed.ui.selectedRequiredCount)
    elseif combo.SelectFirstItem then
        combo:SelectFirstItem()
    end
end

function DevTestBed.SetControlButtonEnabled(button, enabled)
    if not button then return end

    if button.SetEnabled then
        button:SetEnabled(enabled)
    end

    button:SetMouseEnabled(enabled)

    if enabled then
        button:SetNormalFontColor(1, 1, 1, 1)
        button:SetMouseOverFontColor(0.75, 0.9, 1, 1)
    else
        button:SetNormalFontColor(0.45, 0.45, 0.45, 1)
        button:SetMouseOverFontColor(0.45, 0.45, 0.45, 1)
    end
end

function DevTestBed.CreateControlLabel(parent, name, text, anchorTo, offsetY)
    local label = WINDOW_MANAGER:CreateControl(name, parent, CT_LABEL)
    label:SetFont("ZoFontGameBold")
    label:SetColor(0.75, 0.9, 1, 1)
    label:SetText(text)

    if anchorTo then
        label:SetAnchor(TOPLEFT, anchorTo, BOTTOMLEFT, 0, offsetY or 12)
    else
        label:SetAnchor(TOPLEFT, parent, TOPLEFT, 14, offsetY or 12)
    end

    return label
end

function DevTestBed.CreateControlButton(parent, name, text, width, height)
    local button = WINDOW_MANAGER:CreateControl(name, parent, CT_BUTTON)
    button:SetDimensions(width or 130, height or 30)
    button:SetFont("ZoFontGameBold")
    button:SetText(text)
    button:SetNormalFontColor(1, 1, 1, 1)
    button:SetMouseOverFontColor(0.75, 0.9, 1, 1)
    button:SetPressedFontColor(0.5, 0.8, 1, 1)
    return button
end

function DevTestBed.CreateControlWindow()
    if DevTestBed.ui.controlWindow then
        return DevTestBed.ui.controlWindow
    end

    local wm = WINDOW_MANAGER

    local window = wm:CreateTopLevelWindow("DevTestBedControlWindow")
    window:SetDimensions(360, 390)
    window:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -40, 100)
    window:SetMouseEnabled(true)
    window:SetMovable(true)
    window:SetClampedToScreen(true)
    window:SetHidden(true)

    if window.SetResizable then
        window:SetResizable(true)
    end

    if window.SetResizeHandleSize then
        window:SetResizeHandleSize(16)
    end

    if window.SetDimensionConstraints then
        window:SetDimensionConstraints(320, 360, 620, 620)
    end

    local backdrop = wm:CreateControl("$(parent)Backdrop", window, CT_BACKDROP)
    backdrop:SetAnchorFill(window)
    backdrop:SetCenterColor(0, 0, 0, 0.85)
    backdrop:SetEdgeColor(0.25, 0.55, 1, 1)
    backdrop:SetEdgeTexture(nil, 1, 1, 2)

    local title = wm:CreateControl("$(parent)Title", window, CT_LABEL)
    title:SetAnchor(TOPLEFT, window, TOPLEFT, 14, 10)
    title:SetAnchor(TOPRIGHT, window, TOPRIGHT, -40, 10)
    title:SetFont("ZoFontWinH2")
    title:SetColor(0.75, 0.9, 1, 1)
    title:SetText("DevTestBed Controls")

    local closeButton = wm:CreateControl("$(parent)Close", window, CT_BUTTON)
    closeButton:SetDimensions(24, 24)
    closeButton:SetAnchor(TOPRIGHT, window, TOPRIGHT, -8, 6)
    closeButton:SetFont("ZoFontGameBold")
    closeButton:SetText("X")
    closeButton:SetHandler("OnClicked", function()
        window:SetHidden(true)
    end)

    local modeLabel = DevTestBed.CreateControlLabel(window, "$(parent)ModeLabel", "Game Mode", title, 16)
    local modeDropdown = wm:CreateControlFromVirtual("$(parent)ModeDropdown", window, "ZO_ComboBox")
    modeDropdown:SetDimensions(180, 28)
    modeDropdown:SetAnchor(TOPLEFT, modeLabel, BOTTOMLEFT, 0, 4)

    local countLabel = DevTestBed.CreateControlLabel(window, "$(parent)CountLabel", "Required Count", modeDropdown, 14)
    local countDropdown = wm:CreateControlFromVirtual("$(parent)CountDropdown", window, "ZO_ComboBox")
    countDropdown:SetDimensions(180, 28)
    countDropdown:SetAnchor(TOPLEFT, countLabel, BOTTOMLEFT, 0, 4)

    local timeLabel = DevTestBed.CreateControlLabel(window, "$(parent)TimeLabel", "Time Limit", countDropdown, 14)
    local timeDropdown = wm:CreateControlFromVirtual("$(parent)TimeDropdown", window, "ZO_ComboBox")
    timeDropdown:SetDimensions(180, 28)
    timeDropdown:SetAnchor(TOPLEFT, timeLabel, BOTTOMLEFT, 0, 4)

    local startButton = DevTestBed.CreateControlButton(window, "$(parent)StartButton", "Start Game", 135, 32)
    startButton:SetAnchor(TOPLEFT, timeDropdown, BOTTOMLEFT, 0, 18)
    startButton:SetHandler("OnClicked", function()
        local mode = DevTestBed.GetControlPanelSelectedMode()
        local count = DevTestBed.GetControlPanelSelectedCount()
        local minutes = DevTestBed.GetControlPanelSelectedMinutes()
        local maxCount, reason = DevTestBed.GetControlPanelCountInfo(mode)

        if not count or not maxCount or maxCount < 1 then
            DevTestBed.Print(reason or "No valid game count is available.")
            DevTestBed.RefreshControlWindow()
            return
        end

        if mode == "war" then
            DevTestBed.StartWarMode(minutes)
        elseif mode == "target" then
            DevTestBed.StartTargetMode(count, minutes)
        else
            DevTestBed.StartThresholdMode(count, minutes)
        end

        DevTestBed.RefreshControlWindow()
    end)

    local resetButton = DevTestBed.CreateControlButton(window, "$(parent)ResetButton", "Reset Game", 135, 32)
    resetButton:SetAnchor(LEFT, startButton, RIGHT, 16, 0)
    resetButton:SetHandler("OnClicked", function()
        DevTestBed.ResetGame()
        DevTestBed.RefreshControlWindow()
    end)

    local statusButton = DevTestBed.CreateControlButton(window, "$(parent)StatusButton", "Toggle Status", 135, 32)
    statusButton:SetAnchor(TOPLEFT, startButton, BOTTOMLEFT, 0, 12)
    statusButton:SetHandler("OnClicked", function()
        DevTestBed.ToggleGameStatusWindow()
        DevTestBed.RefreshControlWindow()
    end)

    local refreshButton = DevTestBed.CreateControlButton(window, "$(parent)RefreshButton", "Refresh Counts", 135, 32)
    refreshButton:SetAnchor(LEFT, statusButton, RIGHT, 16, 0)
    refreshButton:SetHandler("OnClicked", function()
        DevTestBed.PopulateControlCountDropdown()
        DevTestBed.RefreshControlWindow()
    end)

    local currentTitle = DevTestBed.CreateControlLabel(window, "$(parent)CurrentTitle", "Current Game", statusButton, 18)

    local currentInfo = wm:CreateControl("$(parent)CurrentInfo", window, CT_LABEL)
    currentInfo:SetAnchor(TOPLEFT, currentTitle, BOTTOMLEFT, 0, 6)
    currentInfo:SetAnchor(BOTTOMRIGHT, window, BOTTOMRIGHT, -14, -14)
    currentInfo:SetFont("ZoFontGame")
    currentInfo:SetColor(1, 1, 1, 1)
    currentInfo:SetText("")

    DevTestBed.ui.controlWindow = window
    DevTestBed.ui.controlModeDropdown = modeDropdown
    DevTestBed.ui.controlCountDropdown = countDropdown
    DevTestBed.ui.controlTimeDropdown = timeDropdown
    DevTestBed.ui.controlModeCombo = ZO_ComboBox_ObjectFromContainer(modeDropdown)
    DevTestBed.ui.controlCountCombo = ZO_ComboBox_ObjectFromContainer(countDropdown)
    DevTestBed.ui.controlTimeCombo = ZO_ComboBox_ObjectFromContainer(timeDropdown)
    DevTestBed.ui.controlStartButton = startButton
    DevTestBed.ui.controlResetButton = resetButton
    DevTestBed.ui.controlStatusButton = statusButton
    DevTestBed.ui.controlRefreshButton = refreshButton
    DevTestBed.ui.controlCurrentInfo = currentInfo

    DevTestBed.PopulateControlModeDropdown()
    DevTestBed.PopulateControlTimeDropdown()
    DevTestBed.PopulateControlCountDropdown()
    DevTestBed.RefreshControlWindow()

    return window
end

function DevTestBed.RefreshControlWindow()
    if not DevTestBed.ui.controlWindow then
        return
    end

    local mode = DevTestBed.GetControlPanelSelectedMode()
    local maxCount, reason, teamCount = DevTestBed.GetControlPanelCountInfo(mode, true)
    local canStart = teamCount > 0 and tonumber(maxCount or 0) >= 1

    DevTestBed.SetControlButtonEnabled(DevTestBed.ui.controlStartButton, canStart)

    if DevTestBed.ui.controlCurrentInfo then
        local game = DevTestBed.game or {}
        local modeText = DevTestBed.GetGameModeDisplayText()
        local timerText = DevTestBed.GetGameTimerDisplayText()
        local statusText = "Inactive"

        if game.winner then
            statusText = "Winner: " .. tostring(game.winner)
        elseif game.active then
            statusText = game.overtime and "Overtime" or "Active"
        end

        local countText = ""
        if canStart then
            local suffix = "Max"
            local rangeText = "1 - " .. tostring(maxCount)
            if mode == "threshold" then
                suffix = "All Items"
            elseif mode == "war" then
                suffix = "All Items"
                rangeText = tostring(maxCount)
            end
            countText = zo_strformat("Teams: <<1>>\nAvailable Count: <<2>> (<<3>>)\n", tostring(teamCount), rangeText, suffix)
        else
            countText = zo_strformat("Teams: <<1>>\nAvailable Count: <<2>>\n", tostring(teamCount or 0), tostring(reason or "Unavailable"))
        end

        DevTestBed.ui.controlCurrentInfo:SetText(zo_strformat(
            "<<1>>Selected: <<2>>\nMode: <<3>>\nTimer: <<4>>\nStatus: <<5>>",
            countText,
            DevTestBed.TitleCaseFirst(mode),
            tostring(modeText),
            timerText ~= "" and timerText or "None",
            tostring(statusText)
        ))
    end
end

function DevTestBed.ShowControlWindow()
    local window = DevTestBed.CreateControlWindow()
    window:SetHidden(false)
    DevTestBed.PopulateControlCountDropdown()
    DevTestBed.RefreshControlWindow()
end

function DevTestBed.HideControlWindow()
    if DevTestBed.ui.controlWindow then
        DevTestBed.ui.controlWindow:SetHidden(true)
    end
end

function DevTestBed.ToggleControlWindow()
    local window = DevTestBed.CreateControlWindow()

    if window:IsHidden() then
        window:SetHidden(false)
        DevTestBed.PopulateControlCountDropdown()
        DevTestBed.RefreshControlWindow()
    else
        window:SetHidden(true)
    end
end

DevTestBed.game = DevTestBed.game or {
    active = false,
    mode = nil,
    threshold = 0,
    winner = nil,
    locked = false,
    pulseState = false,
    pulseIntervalMs = 1500,
    pulseSequence = {},
    pulseIndex = 0,
    pulsePreviousFurnitureId = nil,
    startTimeMs = nil,
    endTimeMs = nil,
    frozenTimeMs = nil,
    timeLimitMinutes = nil,
    overtime = false,
    lastTimerRefreshSecond = nil,
}

function DevTestBed.GetNowMs()
    if type(GetGameTimeMilliseconds) == "function" then
        return GetGameTimeMilliseconds()
    end

    if type(GetFrameTimeMilliseconds) == "function" then
        return GetFrameTimeMilliseconds()
    end

    return math.floor(GetFrameTimeSeconds() * 1000)
end

function DevTestBed.FormatTimerFromSeconds(totalSeconds)
    totalSeconds = math.max(0, math.floor(tonumber(totalSeconds or 0)))

    local minutes = math.floor(totalSeconds / 60)
    local seconds = totalSeconds % 60

    return string.format("%02d:%02d", minutes, seconds)
end

function DevTestBed.TitleCaseFirst(value)
    value = tostring(value or "")

    if value == "" then
        return "None"
    end

    return string.upper(string.sub(value, 1, 1)) .. string.sub(value, 2)
end

function DevTestBed.GetGameTimerDisplayText()
    local game = DevTestBed.game or {}

    if not game.startTimeMs then
        return ""
    end

    if game.overtime and not game.winner then
        return "Overtime"
    end

    local nowMs = game.frozenTimeMs or DevTestBed.GetNowMs()

    if game.endTimeMs then
        local remainingSeconds = math.ceil((game.endTimeMs - nowMs) / 1000)
        return DevTestBed.FormatTimerFromSeconds(remainingSeconds)
    end

    local elapsedSeconds = math.floor((nowMs - game.startTimeMs) / 1000)
    return DevTestBed.FormatTimerFromSeconds(elapsedSeconds)
end

function DevTestBed.GetGameModeDisplayText()
    local game = DevTestBed.game or {}

    if not game.mode then
        return "None"
    end

    local text = DevTestBed.TitleCaseFirst(game.mode)

    if game.threshold and tonumber(game.threshold or 0) > 0 then
        text = text .. " (" .. tostring(game.threshold) .. ")"
    end

    local timerText = DevTestBed.GetGameTimerDisplayText()
    if timerText ~= "" then
        text = text .. " " .. timerText
    end

    return text
end

function DevTestBed.ClearRuntimeTeamGameData()
    for _, entry in pairs(DevTestBed.savedVars and DevTestBed.savedVars.items or {}) do
        entry.trackedFurnitureIds = nil
        entry.targetFurnitureIds = nil
        entry.decoyFurnitureIds = nil
        entry.requiredWinCount = nil
        entry.currentWinCount = nil
        entry.lastStates = nil
    end

    for _, entry in pairs(DevTestBed.savedVars and DevTestBed.savedVars.warTeams or {}) do
        entry.trackedFurnitureIds = nil
        entry.requiredWinCount = nil
        entry.currentWinCount = nil
        entry.lastStates = nil
        entry.pendingStates = nil
        entry.pendingSinceMs = nil
        entry.appliedStates = nil
    end
end

function DevTestBed.StopThresholdGame(clearWinner)
    EVENT_MANAGER:UnregisterForUpdate(DevTestBed.name .. "ThresholdWatcher")
    EVENT_MANAGER:UnregisterForUpdate(DevTestBed.name .. "TargetWatcher")
    EVENT_MANAGER:UnregisterForUpdate(DevTestBed.name .. "TargetDecoyRandomizer")
    EVENT_MANAGER:UnregisterForUpdate(DevTestBed.name .. "WarWatcher")
    EVENT_MANAGER:UnregisterForUpdate(DevTestBed.name .. "WinnerPulse")
    DevTestBed.ClearRuntimeTeamGameData()

    DevTestBed.game = DevTestBed.game or {}
    DevTestBed.game.active = false
    DevTestBed.game.mode = nil
    DevTestBed.game.threshold = 0
    DevTestBed.game.locked = false
    DevTestBed.game.pulseState = false
    DevTestBed.game.pulseTeamKey = nil
    DevTestBed.game.pulseFurnitureLookup = {}
    DevTestBed.game.pulseSequence = {}
    DevTestBed.game.pulseIndex = 0
    DevTestBed.game.pulsePreviousFurnitureId = nil
    DevTestBed.game.pulseIntervalMs = 1500
    DevTestBed.game.warNeutralState = nil
    DevTestBed.game.startTimeMs = nil
    DevTestBed.game.endTimeMs = nil
    DevTestBed.game.frozenTimeMs = nil
    DevTestBed.game.timeLimitMinutes = nil
    DevTestBed.game.overtime = false
    DevTestBed.game.lastTimerRefreshSecond = nil

    if clearWinner then
        DevTestBed.game.winner = nil
        DevTestBed.game.winnerKey = nil
    end
end

function DevTestBed.ShowThresholdCountMismatch()
    DevTestBed.Print("|cFF0000Item counts are not equal. Start cancelled.|r")

    for key, entry in pairs(DevTestBed.savedVars.items or {}) do
        DevTestBed.Print(zo_strformat(
            "Team: |c00FF00<<1>>|r - Item: |c00FF00<<2>>|r - Matching Count: |cFFFF00<<3>>|r",
            tostring(entry.name or key),
            tostring(entry.itemName or "Unknown"),
            tostring(entry.matchingCount or 0)
        ))
    end
end

function DevTestBed.GetNonWinningState(winningState)
    winningState = tonumber(winningState)

    if winningState == 0 then
        return 1
    end

    return 0
end

function DevTestBed.TryShowWinnerAnnouncement(message)
    if CENTER_SCREEN_ANNOUNCE and CENTER_SCREEN_ANNOUNCE.AddMessage then
        pcall(function()
            CENTER_SCREEN_ANNOUNCE:AddMessage(EVENT_DISPLAY_ANNOUNCEMENT, CSA_EVENT_SMALL_TEXT, nil, message)
        end)
    end
end

function DevTestBed.TryPlayWinnerSound()
    if type(PlaySound) == "function" and type(SOUNDS) == "table" then
        pcall(function()
            PlaySound(SOUNDS.DUEL_WON or SOUNDS.QUEST_COMPLETE or SOUNDS.OBJECTIVE_COMPLETE)
        end)
    end
end

function DevTestBed.GetWinnerPulseFurnitureIds(winnerKey, entry)
    local pulseIds = {}

    if not entry or not entry.trackedFurnitureIds then
        return pulseIds
    end

    local winningState = tonumber(entry.state)

    -- War mode should only pulse the items that are actually counted for the
    -- winning team: the furnishings whose applied/stable state is currently
    -- that team's win state. This prevents the full War item set from flashing.
    if DevTestBed.game and DevTestBed.game.mode == "war" then
        local appliedStates = entry.appliedStates or {}

        for _, furnitureInfo in ipairs(entry.trackedFurnitureIds or {}) do
            local furnitureId = furnitureInfo and furnitureInfo.furnitureId

            if furnitureId and appliedStates[furnitureId] ~= nil and tonumber(appliedStates[furnitureId]) == winningState then
                table.insert(pulseIds, furnitureId)
            end
        end

        return pulseIds
    end

    -- Threshold/Target keep the existing behavior: pulse the winning team's
    -- tracked items in sequence.
    for _, furnitureInfo in ipairs(entry.trackedFurnitureIds or {}) do
        local furnitureId = furnitureInfo and furnitureInfo.furnitureId

        if furnitureId then
            table.insert(pulseIds, furnitureId)
        end
    end

    return pulseIds
end

function DevTestBed.StartWinnerPulse(winnerKey)
    EVENT_MANAGER:UnregisterForUpdate(DevTestBed.name .. "WinnerPulse")

    local entry = DevTestBed.GetActiveGameTeamTable()[winnerKey]
    if not entry or not entry.trackedFurnitureIds then
        return
    end

    DevTestBed.game.pulseTeamKey = winnerKey
    DevTestBed.game.pulseFurnitureLookup = {}
    DevTestBed.game.pulseSequence = DevTestBed.GetWinnerPulseFurnitureIds(winnerKey, entry)
    DevTestBed.game.pulseIndex = 0
    DevTestBed.game.pulsePreviousFurnitureId = nil
    DevTestBed.game.pulseIntervalMs = 1500

    for _, furnitureId in ipairs(DevTestBed.game.pulseSequence or {}) do
        if furnitureId then
            DevTestBed.game.pulseFurnitureLookup[furnitureId] = true
        end
    end

    if #(DevTestBed.game.pulseSequence or {}) == 0 then
        DevTestBed.Dbg("Winner pulse skipped because no winning-state furniture was found.")
        return
    end

    -- Pulse one item at a time instead of flashing the entire winning team at once.
    -- For War mode, the sequence contains only the items that were in the
    -- winning team's stable win state when the winner was declared.
    EVENT_MANAGER:RegisterForUpdate(DevTestBed.name .. "WinnerPulse", DevTestBed.game.pulseIntervalMs, function()
        local pulseEntry = DevTestBed.GetActiveGameTeamTable()[winnerKey]
        local sequence = DevTestBed.game.pulseSequence or {}

        if not DevTestBed.game.locked or not pulseEntry or not pulseEntry.trackedFurnitureIds or #sequence == 0 then
            EVENT_MANAGER:UnregisterForUpdate(DevTestBed.name .. "WinnerPulse")
            return
        end

        local winningState = tonumber(pulseEntry.state)
        local flashState = DevTestBed.GetNonWinningState(winningState)

        -- War mode can have an unused/neutral state. When present, use that
        -- neutral state as the flash-away state instead of another team's color.
        if DevTestBed.game.mode == "war" and DevTestBed.game.warNeutralState ~= nil then
            flashState = tonumber(DevTestBed.game.warNeutralState)
        end

        -- Turn the previously highlighted item back to the flash-away state
        -- before lighting the next one.
        if DevTestBed.game.pulsePreviousFurnitureId then
            HousingEditorRequestChangeState(DevTestBed.game.pulsePreviousFurnitureId, flashState)
        end

        DevTestBed.game.pulseIndex = (tonumber(DevTestBed.game.pulseIndex or 0) % #sequence) + 1

        local furnitureId = sequence[DevTestBed.game.pulseIndex]
        if furnitureId then
            HousingEditorRequestChangeState(furnitureId, winningState)
            DevTestBed.game.pulsePreviousFurnitureId = furnitureId
        end
    end)
end

function DevTestBed.ClearActiveGameDueToLeavingHouse()
    if not DevTestBed.game or not DevTestBed.game.active then
        return
    end

    DevTestBed.StopThresholdGame(true)
    DevTestBed.HideGameStatusWindow()
    DevTestBed.Print("Game cleared because you left the house.")
end

function DevTestBed.GetHighestPercentTeams()
    local highestPercent = nil
    local leaders = {}

    for key, entry in pairs(DevTestBed.GetActiveGameTeamTable()) do
        if entry.trackedFurnitureIds then
            local currentCount = tonumber(entry.currentWinCount or 0) or 0
            local requiredCount = tonumber(entry.requiredWinCount or DevTestBed.game.threshold or 0) or 0
            local percent = 0

            if requiredCount > 0 then
                percent = (currentCount / requiredCount) * 100
            end

            if highestPercent == nil or percent > highestPercent then
                highestPercent = percent
                leaders = {
                    {
                        key = key,
                        entry = entry,
                        percent = percent,
                    }
                }
            elseif percent == highestPercent then
                table.insert(leaders, {
                    key = key,
                    entry = entry,
                    percent = percent,
                })
            end
        end
    end

    return leaders, highestPercent or 0
end

function DevTestBed.CheckThresholdTimerExpired()
    local game = DevTestBed.game or {}

    if game.locked or not game.endTimeMs then
        return false
    end

    local nowMs = DevTestBed.GetNowMs()
    if nowMs < game.endTimeMs and not game.overtime then
        return false
    end

    local leaders = DevTestBed.GetHighestPercentTeams()

    if #leaders == 1 then
        DevTestBed.DeclareThresholdWinner(leaders[1].key, leaders[1].entry)
        return true
    end

    if #leaders > 1 then
        if not game.overtime then
            DevTestBed.Print("Time expired with a tie. Overtime continues until one team has the highest percentage.")
        end

        game.overtime = true
        DevTestBed.RefreshGameStatusWindow()
    end

    return false
end

function DevTestBed.OnPlayerActivated()
    DevTestBed.ClearActiveGameDueToLeavingHouse()
end

function DevTestBed.DeclareThresholdWinner(winnerKey, entry)
    if DevTestBed.game.locked then
        return
    end

    local winnerName = tostring(entry.name or winnerKey)

    DevTestBed.game.winner = winnerName
    DevTestBed.game.winnerKey = winnerKey
    DevTestBed.game.locked = true
    DevTestBed.game.active = true
    DevTestBed.game.frozenTimeMs = DevTestBed.GetNowMs()

    local message = zo_strformat("|c00FF00<<1>> wins!|r", winnerName)

    DevTestBed.Print(message)
    DevTestBed.TryShowWinnerAnnouncement(zo_strformat("<<1>> wins!", winnerName))
    DevTestBed.TryPlayWinnerSound()
    DevTestBed.RefreshGameStatusWindow()
    DevTestBed.StartWinnerPulse(winnerKey)
end

function DevTestBed.CheckThresholdGameState()
    if not DevTestBed.game or not DevTestBed.game.active or DevTestBed.game.mode ~= "threshold" then
        EVENT_MANAGER:UnregisterForUpdate(DevTestBed.name .. "ThresholdWatcher")
        return
    end

    if not DevTestBed.IsInHouse(false) then
        DevTestBed.ClearActiveGameDueToLeavingHouse()
        return
    end

    local nowMs = DevTestBed.GetNowMs()
    local currentTimerSecond = math.floor(nowMs / 1000)
    if not DevTestBed.game.locked and DevTestBed.game.lastTimerRefreshSecond ~= currentTimerSecond then
        DevTestBed.game.lastTimerRefreshSecond = currentTimerSecond
        DevTestBed.RefreshGameStatusWindow()
        DevTestBed.RefreshControlWindow()
    end

    local pulseLookup = DevTestBed.game.pulseFurnitureLookup or {}

    for key, entry in pairs(DevTestBed.savedVars.items or {}) do
        if entry.trackedFurnitureIds and entry.lastStates then
            local winningState = tonumber(entry.state)
            local currentWinCount = 0

            for _, furnitureInfo in ipairs(entry.trackedFurnitureIds) do
                local furnitureId = furnitureInfo and furnitureInfo.furnitureId

                if furnitureId then
                    local currentState = GetPlacedHousingFurnitureCurrentObjectStateIndex(furnitureId)
                    local previousState = entry.lastStates[furnitureId]

                    if currentState ~= nil then
                        currentState = tonumber(currentState)

                        if DevTestBed.game.locked then
                            if not pulseLookup[furnitureId] and previousState ~= nil and tonumber(previousState) ~= currentState then
                                HousingEditorRequestChangeState(furnitureId, previousState)
                                currentState = tonumber(previousState)
                            end
                        else
                            entry.lastStates[furnitureId] = currentState
                        end

                        if currentState == winningState then
                            currentWinCount = currentWinCount + 1
                        end
                    end
                end
            end

            if not DevTestBed.game.locked then
                entry.currentWinCount = currentWinCount
                DevTestBed.RefreshGameStatusWindow()

                if currentWinCount >= tonumber(entry.requiredWinCount or DevTestBed.game.threshold or 0) then
                    DevTestBed.DeclareThresholdWinner(key, entry)
                    return
                end
            end
        end
    end

    if not DevTestBed.game.locked then
        DevTestBed.CheckThresholdTimerExpired()
    end
end

--[[
    DevTestBed.StartThresholdMode

    Starts threshold mode.

    Usage:
        /dtb start threshold <count> [minutes]

    Rules:
        - Rescans matching items for every team
        - Requires all teams to have the same number of matching items
        - count must be at least 1
        - count cannot exceed the matching item count
        - All matching items are tracked
        - A team wins when count tracked items are in that team's saved winning state
]]
function DevTestBed.StartThresholdMode(thresholdCount, timeLimitMinutes)
    if not DevTestBed.IsInHouse(true) then return end

    if not HasAnyEditingPermissionsForCurrentHouse() then
        DevTestBed.Print("You must have housing editor permissions to use this command.")
        return
    end

    thresholdCount = tonumber(thresholdCount)
    timeLimitMinutes = tonumber(timeLimitMinutes)

    if not thresholdCount or thresholdCount < 1 or thresholdCount ~= math.floor(thresholdCount) then
        DevTestBed.Print("Use: /dtb start threshold <count> [minutes]")
        DevTestBed.Print("Count must be a whole number of at least 1.")
        return
    end

    if timeLimitMinutes ~= nil then
        if timeLimitMinutes < 1 or timeLimitMinutes > 60 or timeLimitMinutes ~= math.floor(timeLimitMinutes) then
            DevTestBed.Print("Use: /dtb start threshold <count> [minutes]")
            DevTestBed.Print("Optional minutes must be a whole number from 1 to 60.")
            return
        end
    end

    DevTestBed.savedVars.items = DevTestBed.savedVars.items or {}

    local teamCount = 0
    local expectedMatchCount = nil
    local countsAreEqual = true

    -- Stop any prior threshold watcher/pulse before starting a new game.
    DevTestBed.StopThresholdGame(true)

    for key, entry in pairs(DevTestBed.savedVars.items) do
        teamCount = teamCount + 1

        local furnitureDataId = entry.furnitureDataId

        if furnitureDataId then
            local matchingFurniture, matchingCount = DevTestBed.GetMatchingHouseFurniture(furnitureDataId)

            entry.furnitureIds = matchingFurniture
            entry.trackedFurnitureIds = matchingFurniture
            entry.matchingCount = matchingCount
            entry.requiredWinCount = thresholdCount
            entry.currentWinCount = 0
            entry.lastStates = {}

            if expectedMatchCount == nil then
                expectedMatchCount = matchingCount
            elseif matchingCount ~= expectedMatchCount then
                countsAreEqual = false
            end
        else
            entry.furnitureIds = {}
            entry.trackedFurnitureIds = {}
            entry.matchingCount = 0
            entry.requiredWinCount = thresholdCount
            entry.currentWinCount = 0
            entry.lastStates = {}
            countsAreEqual = false
        end
    end

    if teamCount == 0 then
        DevTestBed.Print("No teams have been created.")
        return
    end

    if not countsAreEqual then
        DevTestBed.ShowThresholdCountMismatch()
        DevTestBed.ClearRuntimeTeamGameData()
        return
    end

    expectedMatchCount = tonumber(expectedMatchCount or 0)

    if thresholdCount > expectedMatchCount then
        DevTestBed.Print(zo_strformat(
            "Threshold mode cancelled. Count must be between 1 and <<1>>.",
            tostring(expectedMatchCount)
        ))
        DevTestBed.ClearRuntimeTeamGameData()
        return
    end

    local changedCount = 0

    for key, entry in pairs(DevTestBed.savedVars.items) do
        local winningState = tonumber(entry.state)
        local nonWinningState = DevTestBed.GetNonWinningState(winningState)

        for _, furnitureInfo in ipairs(entry.trackedFurnitureIds or {}) do
            local furnitureId = furnitureInfo and furnitureInfo.furnitureId

            if furnitureId then
                local numStates = GetPlacedHousingFurnitureNumObjectStates(furnitureId)

                if numStates == 2 then
                    local currentState = GetPlacedHousingFurnitureCurrentObjectStateIndex(furnitureId)

                    if tonumber(currentState) ~= tonumber(nonWinningState) then
                        HousingEditorRequestChangeState(furnitureId, nonWinningState)
                        changedCount = changedCount + 1
                    end

                    entry.lastStates[furnitureId] = nonWinningState
                end
            end
        end
    end

    DevTestBed.game.active = true
    DevTestBed.game.mode = "threshold"
    DevTestBed.game.threshold = thresholdCount
    DevTestBed.game.winner = nil
    DevTestBed.game.winnerKey = nil
    DevTestBed.game.locked = false
    DevTestBed.game.pulseFurnitureLookup = {}
    DevTestBed.game.pulseSequence = {}
    DevTestBed.game.pulseIndex = 0
    DevTestBed.game.pulsePreviousFurnitureId = nil
    DevTestBed.game.pulseIntervalMs = 1500
    DevTestBed.game.startTimeMs = DevTestBed.GetNowMs()
    DevTestBed.game.timeLimitMinutes = timeLimitMinutes
    DevTestBed.game.endTimeMs = timeLimitMinutes and (DevTestBed.game.startTimeMs + (timeLimitMinutes * 60 * 1000)) or nil
    DevTestBed.game.frozenTimeMs = nil
    DevTestBed.game.overtime = false
    DevTestBed.game.lastTimerRefreshSecond = nil

    EVENT_MANAGER:UnregisterForUpdate(DevTestBed.name .. "ThresholdWatcher")
    EVENT_MANAGER:RegisterForUpdate(DevTestBed.name .. "ThresholdWatcher", 250, DevTestBed.CheckThresholdGameState)

    DevTestBed.ShowGameStatusWindow()

    DevTestBed.Print(zo_strformat(
        "Started threshold mode. Refreshed |c00FF00<<1>>|r team(s), tracking |c00FF00<<2>>|r item(s) per team. First team with |c00FF00<<3>>|r item(s) in the winning state wins.",
        tostring(teamCount),
        tostring(expectedMatchCount),
        tostring(thresholdCount)
    ))

    if changedCount > 0 then
        DevTestBed.Dbg("Placed " .. tostring(changedCount) .. " item(s) into their non-winning state.")
    end

    if DevTestBed.ui and DevTestBed.ui.controlWindow then
        DevTestBed.RefreshControlWindow()
    end
end

function DevTestBed.SeedRandomOnce()
    if DevTestBed.randomSeeded then
        return
    end

    local seed = 0

    if type(GetTimeStamp) == "function" then
        seed = seed + tonumber(GetTimeStamp() or 0)
    end

    if type(GetGameTimeMilliseconds) == "function" then
        seed = seed + tonumber(GetGameTimeMilliseconds() or 0)
    end

    math.randomseed(seed)
    math.random()
    math.random()
    math.random()

    DevTestBed.randomSeeded = true
end

function DevTestBed.ShuffleFurnitureList(source)
    DevTestBed.SeedRandomOnce()

    local shuffled = {}

    for index, value in ipairs(source or {}) do
        shuffled[index] = value
    end

    for index = #shuffled, 2, -1 do
        local swapIndex = math.random(index)
        shuffled[index], shuffled[swapIndex] = shuffled[swapIndex], shuffled[index]
    end

    return shuffled
end

function DevTestBed.SplitRandomTargetAndDecoyFurniture(source, targetCount)
    local shuffled = DevTestBed.ShuffleFurnitureList(source)
    local targets = {}
    local decoys = {}

    for index, furnitureInfo in ipairs(shuffled) do
        if index <= tonumber(targetCount or 0) then
            table.insert(targets, furnitureInfo)
        else
            table.insert(decoys, furnitureInfo)
        end
    end

    return targets, decoys
end

function DevTestBed.CheckTargetGameState()
    if not DevTestBed.game or not DevTestBed.game.active or DevTestBed.game.mode ~= "target" then
        EVENT_MANAGER:UnregisterForUpdate(DevTestBed.name .. "TargetWatcher")
        return
    end

    if not DevTestBed.IsInHouse(false) then
        DevTestBed.ClearActiveGameDueToLeavingHouse()
        return
    end

    local nowMs = DevTestBed.GetNowMs()
    local currentTimerSecond = math.floor(nowMs / 1000)
    if not DevTestBed.game.locked and DevTestBed.game.lastTimerRefreshSecond ~= currentTimerSecond then
        DevTestBed.game.lastTimerRefreshSecond = currentTimerSecond
        DevTestBed.RefreshGameStatusWindow()
        DevTestBed.RefreshControlWindow()
    end

    local pulseLookup = DevTestBed.game.pulseFurnitureLookup or {}

    for key, entry in pairs(DevTestBed.savedVars.items or {}) do
        if entry.trackedFurnitureIds and entry.lastStates then
            local winningState = tonumber(entry.state)
            local currentWinCount = 0

            for _, furnitureInfo in ipairs(entry.trackedFurnitureIds) do
                local furnitureId = furnitureInfo and furnitureInfo.furnitureId

                if furnitureId then
                    local currentState = GetPlacedHousingFurnitureCurrentObjectStateIndex(furnitureId)
                    local previousState = entry.lastStates[furnitureId]

                    if currentState ~= nil then
                        currentState = tonumber(currentState)

                        if DevTestBed.game.locked then
                            if not pulseLookup[furnitureId] and previousState ~= nil and tonumber(previousState) ~= currentState then
                                HousingEditorRequestChangeState(furnitureId, previousState)
                                currentState = tonumber(previousState)
                            end
                        else
                            entry.lastStates[furnitureId] = currentState
                        end

                        if currentState == winningState then
                            currentWinCount = currentWinCount + 1
                        end
                    end
                end
            end

            if not DevTestBed.game.locked then
                entry.currentWinCount = currentWinCount
                DevTestBed.RefreshGameStatusWindow()

                if currentWinCount >= tonumber(entry.requiredWinCount or DevTestBed.game.threshold or 0) then
                    DevTestBed.DeclareThresholdWinner(key, entry)
                    return
                end
            end
        end
    end

    if not DevTestBed.game.locked then
        DevTestBed.CheckThresholdTimerExpired()
    end
end

--[[
    DevTestBed.StartTargetMode

    Starts target mode.

    Usage:
        /dtb start target <count> [minutes]

    Rules:
        - Rescans matching items for every team
        - Randomly selects count furnishingIds per team as monitored targets
        - Only monitored targets count toward completion and winning
        - Non-monitored decoys are randomly set to win/non-win states one by one
        - Optional minutes works the same as threshold mode, including overtime ties
]]
function DevTestBed.StartTargetMode(targetCount, timeLimitMinutes)
    if not DevTestBed.IsInHouse(true) then return end

    if not HasAnyEditingPermissionsForCurrentHouse() then
        DevTestBed.Print("You must have housing editor permissions to use this command.")
        return
    end

    targetCount = tonumber(targetCount)
    timeLimitMinutes = tonumber(timeLimitMinutes)

    if not targetCount or targetCount < 1 or targetCount ~= math.floor(targetCount) then
        DevTestBed.Print("Use: /dtb start target <count> [minutes]")
        DevTestBed.Print("Count must be a whole number of at least 1.")
        return
    end

    if timeLimitMinutes ~= nil then
        if timeLimitMinutes < 1 or timeLimitMinutes > 60 or timeLimitMinutes ~= math.floor(timeLimitMinutes) then
            DevTestBed.Print("Use: /dtb start target <count> [minutes]")
            DevTestBed.Print("Optional minutes must be a whole number from 1 to 60.")
            return
        end
    end

    DevTestBed.savedVars.items = DevTestBed.savedVars.items or {}

    local teamCount = 0
    local decoyQueue = {}
    local totalDecoyCount = 0
    local targetChangedCount = 0

    DevTestBed.StopThresholdGame(true)

    for key, entry in pairs(DevTestBed.savedVars.items) do
        teamCount = teamCount + 1

        local furnitureDataId = entry.furnitureDataId
        if furnitureDataId then
            local matchingFurniture, matchingCount = DevTestBed.GetMatchingHouseFurniture(furnitureDataId)
            entry.furnitureIds = matchingFurniture
            entry.matchingCount = matchingCount

            if targetCount > matchingCount then
                DevTestBed.Print(zo_strformat(
                    "Target mode cancelled. Team |c00FF00<<1>>|r only has |cFFFF00<<2>>|r matching item(s); count must be between 1 and <<2>>.",
                    tostring(entry.name or key),
                    tostring(matchingCount)
                ))
                DevTestBed.ClearRuntimeTeamGameData()
                return
            end

            local targets, decoys = DevTestBed.SplitRandomTargetAndDecoyFurniture(matchingFurniture, targetCount)
            entry.trackedFurnitureIds = targets
            entry.targetFurnitureIds = targets
            entry.decoyFurnitureIds = decoys
            entry.requiredWinCount = targetCount
            entry.currentWinCount = 0
            entry.lastStates = {}

            local winningState = tonumber(entry.state)
            local nonWinningState = DevTestBed.GetNonWinningState(winningState)

            for _, furnitureInfo in ipairs(targets) do
                local furnitureId = furnitureInfo and furnitureInfo.furnitureId

                if furnitureId then
                    local numStates = GetPlacedHousingFurnitureNumObjectStates(furnitureId)
                    if numStates == 2 then
                        local currentState = GetPlacedHousingFurnitureCurrentObjectStateIndex(furnitureId)

                        if tonumber(currentState) ~= tonumber(nonWinningState) then
                            HousingEditorRequestChangeState(furnitureId, nonWinningState)
                            targetChangedCount = targetChangedCount + 1
                        end

                        entry.lastStates[furnitureId] = nonWinningState
                    end
                end
            end

            for _, furnitureInfo in ipairs(decoys) do
                local furnitureId = furnitureInfo and furnitureInfo.furnitureId
                if furnitureId then
                    table.insert(decoyQueue, {
                        furnitureId = furnitureId,
                        winningState = winningState,
                        nonWinningState = nonWinningState,
                    })
                    totalDecoyCount = totalDecoyCount + 1
                end
            end
        else
            DevTestBed.Print(zo_strformat(
                "Target mode cancelled. Team |c00FF00<<1>>|r does not have a furnitureDataId.",
                tostring(entry.name or key)
            ))
            DevTestBed.ClearRuntimeTeamGameData()
            return
        end
    end

    if teamCount == 0 then
        DevTestBed.Print("No teams have been created.")
        return
    end

    DevTestBed.game.active = true
    DevTestBed.game.mode = "target"
    DevTestBed.game.threshold = targetCount
    DevTestBed.game.winner = nil
    DevTestBed.game.winnerKey = nil
    DevTestBed.game.locked = false
    DevTestBed.game.pulseFurnitureLookup = {}
    DevTestBed.game.pulseSequence = {}
    DevTestBed.game.pulseIndex = 0
    DevTestBed.game.pulsePreviousFurnitureId = nil
    DevTestBed.game.pulseIntervalMs = 1500
    DevTestBed.game.startTimeMs = DevTestBed.GetNowMs()
    DevTestBed.game.timeLimitMinutes = timeLimitMinutes
    DevTestBed.game.endTimeMs = timeLimitMinutes and (DevTestBed.game.startTimeMs + (timeLimitMinutes * 60 * 1000)) or nil
    DevTestBed.game.frozenTimeMs = nil
    DevTestBed.game.overtime = false
    DevTestBed.game.lastTimerRefreshSecond = nil

    decoyQueue = DevTestBed.ShuffleFurnitureList(decoyQueue)
    local decoyIndex = 0

    if #decoyQueue > 0 then
        EVENT_MANAGER:UnregisterForUpdate(DevTestBed.name .. "TargetDecoyRandomizer")
        EVENT_MANAGER:RegisterForUpdate(DevTestBed.name .. "TargetDecoyRandomizer", 500, function()
            if not DevTestBed.game or not DevTestBed.game.active or DevTestBed.game.mode ~= "target" or DevTestBed.game.locked then
                EVENT_MANAGER:UnregisterForUpdate(DevTestBed.name .. "TargetDecoyRandomizer")
                return
            end

            if not DevTestBed.IsInHouse(false) then
                DevTestBed.ClearActiveGameDueToLeavingHouse()
                return
            end

            decoyIndex = decoyIndex + 1
            local decoy = decoyQueue[decoyIndex]

            if not decoy then
                EVENT_MANAGER:UnregisterForUpdate(DevTestBed.name .. "TargetDecoyRandomizer")
                return
            end

            local targetState = math.random(0, 1) == 1 and decoy.winningState or decoy.nonWinningState
            HousingEditorRequestChangeState(decoy.furnitureId, targetState)
        end)
    end

    EVENT_MANAGER:UnregisterForUpdate(DevTestBed.name .. "TargetWatcher")
    EVENT_MANAGER:RegisterForUpdate(DevTestBed.name .. "TargetWatcher", 250, DevTestBed.CheckTargetGameState)

    DevTestBed.ShowGameStatusWindow()

    DevTestBed.Print(zo_strformat(
        "Started target mode. Refreshed |c00FF00<<1>>|r team(s), randomly selected |c00FF00<<2>>|r monitored target item(s) per team, and queued |c00FF00<<3>>|r decoy item(s) for random states.",
        tostring(teamCount),
        tostring(targetCount),
        tostring(totalDecoyCount)
    ))

    if targetChangedCount > 0 then
        DevTestBed.Dbg("Placed " .. tostring(targetChangedCount) .. " monitored target item(s) into their non-winning state.")
    end

    if DevTestBed.ui and DevTestBed.ui.controlWindow then
        DevTestBed.RefreshControlWindow()
    end
end




function DevTestBed.GetUnusedWarState(numStates, usedStates)
    numStates = tonumber(numStates or 0) or 0
    usedStates = usedStates or {}

    for state = 0, numStates - 1 do
        if not usedStates[state] then
            return state
        end
    end

    return nil
end

function DevTestBed.GetBalancedWarStateAssignments(matchingFurniture, availableStates)
    local assignments = {}
    local shuffledFurniture = DevTestBed.ShuffleFurnitureList(matchingFurniture or {})
    local shuffledStates = DevTestBed.ShuffleFurnitureList(availableStates or {})

    if #shuffledStates == 0 then
        return assignments
    end

    -- Assign states in a shuffled round-robin pattern. This keeps counts as
    -- equal as possible while still making the starting layout feel random.
    for index, furnitureInfo in ipairs(shuffledFurniture) do
        local stateIndex = ((index - 1) % #shuffledStates) + 1
        table.insert(assignments, {
            furnitureInfo = furnitureInfo,
            state = shuffledStates[stateIndex],
        })
    end

    return assignments
end

function DevTestBed.GetRandomWarState(numStates)
    numStates = tonumber(numStates or 0) or 0
    if numStates < 1 then
        return 0
    end

    return math.random(0, numStates - 1)
end

function DevTestBed.GetWarStableDelayMs()
    return 5000
end

function DevTestBed.UpdateWarAppliedState(entry, furnitureId, currentState, nowMs)
    if not entry or not furnitureId or currentState == nil then
        return nil
    end

    entry.pendingStates = entry.pendingStates or {}
    entry.pendingSinceMs = entry.pendingSinceMs or {}
    entry.appliedStates = entry.appliedStates or {}

    currentState = tonumber(currentState)
    local pendingState = entry.pendingStates[furnitureId]

    -- A new observed state starts/restarts the five-second stability timer.
    if pendingState == nil or tonumber(pendingState) ~= currentState then
        entry.pendingStates[furnitureId] = currentState
        entry.pendingSinceMs[furnitureId] = nowMs
        return entry.appliedStates[furnitureId]
    end

    local sinceMs = tonumber(entry.pendingSinceMs[furnitureId] or nowMs) or nowMs
    if nowMs - sinceMs >= DevTestBed.GetWarStableDelayMs() then
        entry.appliedStates[furnitureId] = currentState
    end

    return entry.appliedStates[furnitureId]
end

function DevTestBed.CheckWarGameState()
    if not DevTestBed.game or not DevTestBed.game.active or DevTestBed.game.mode ~= "war" then
        EVENT_MANAGER:UnregisterForUpdate(DevTestBed.name .. "WarWatcher")
        return
    end

    if not DevTestBed.IsInHouse(false) then
        DevTestBed.ClearActiveGameDueToLeavingHouse()
        return
    end

    local nowMs = DevTestBed.GetNowMs()
    local currentTimerSecond = math.floor(nowMs / 1000)
    if not DevTestBed.game.locked and DevTestBed.game.lastTimerRefreshSecond ~= currentTimerSecond then
        DevTestBed.game.lastTimerRefreshSecond = currentTimerSecond
        DevTestBed.RefreshGameStatusWindow()
        DevTestBed.RefreshControlWindow()
    end

    local pulseLookup = DevTestBed.game.pulseFurnitureLookup or {}

    for key, entry in pairs(DevTestBed.GetWarTeamTable()) do
        if entry.trackedFurnitureIds then
            local winningState = tonumber(entry.state)
            local currentWinCount = 0

            entry.lastStates = entry.lastStates or {}
            entry.pendingStates = entry.pendingStates or {}
            entry.pendingSinceMs = entry.pendingSinceMs or {}
            entry.appliedStates = entry.appliedStates or {}

            for _, furnitureInfo in ipairs(entry.trackedFurnitureIds) do
                local furnitureId = furnitureInfo and furnitureInfo.furnitureId

                if furnitureId then
                    local currentState = GetPlacedHousingFurnitureCurrentObjectStateIndex(furnitureId)

                    if currentState ~= nil then
                        currentState = tonumber(currentState)

                        if DevTestBed.game.locked then
                            local previousState = entry.lastStates[furnitureId]
                            if not pulseLookup[furnitureId] and previousState ~= nil and tonumber(previousState) ~= currentState then
                                HousingEditorRequestChangeState(furnitureId, previousState)
                                currentState = tonumber(previousState)
                            end
                        else
                            entry.lastStates[furnitureId] = currentState

                            -- War mode only counts a state after the item has remained
                            -- unchanged in that state for five seconds. If the state changes
                            -- again before the delay expires, the pending timer restarts.
                            DevTestBed.UpdateWarAppliedState(entry, furnitureId, currentState, nowMs)
                        end

                        local appliedState = entry.appliedStates[furnitureId]
                        if appliedState ~= nil and tonumber(appliedState) == winningState then
                            currentWinCount = currentWinCount + 1
                        end
                    end
                end
            end

            if not DevTestBed.game.locked then
                entry.currentWinCount = currentWinCount
                DevTestBed.RefreshGameStatusWindow()

                if currentWinCount >= tonumber(entry.requiredWinCount or DevTestBed.game.threshold or 0) then
                    DevTestBed.DeclareThresholdWinner(key, entry)
                    return
                end
            end
        end
    end

    if not DevTestBed.game.locked then
        DevTestBed.CheckThresholdTimerExpired()
    end
end

function DevTestBed.StartWarMode(timeLimitMinutes)
    if not DevTestBed.IsInHouse(true) then return end

    if not HasAnyEditingPermissionsForCurrentHouse() then
        DevTestBed.Print("You must have housing editor permissions to use this command.")
        return
    end

    timeLimitMinutes = tonumber(timeLimitMinutes)

    if timeLimitMinutes ~= nil then
        if timeLimitMinutes < 1 or timeLimitMinutes > 60 or timeLimitMinutes ~= math.floor(timeLimitMinutes) then
            DevTestBed.Print("Use: /dtb start war [minutes]")
            DevTestBed.Print("Optional minutes must be a whole number from 1 to 60.")
            return
        end
    end

    local warTeams = DevTestBed.GetWarTeamTable()
    local teamCount = 0
    local firstFurnitureDataId = nil
    local sameItem = true
    local matchingFurniture = nil
    local matchingCount = 0
    local numStates = nil

    DevTestBed.StopThresholdGame(true)

    for key, entry in pairs(warTeams) do
        teamCount = teamCount + 1

        if firstFurnitureDataId == nil then
            firstFurnitureDataId = entry.furnitureDataId
        elseif tonumber(entry.furnitureDataId) ~= tonumber(firstFurnitureDataId) then
            sameItem = false
        end
    end

    if teamCount == 0 then
        DevTestBed.Print("No War teams have been created.")
        return
    end

    if not sameItem then
        DevTestBed.Print("War mode cancelled. All War teams must use the same furnishing item.")
        return
    end

    matchingFurniture, matchingCount = DevTestBed.GetMatchingHouseFurniture(firstFurnitureDataId)

    if matchingCount < 1 then
        DevTestBed.Print("War mode cancelled. No matching placed items were found for the War item.")
        return
    end

    local firstFurnitureId = matchingFurniture[1] and matchingFurniture[1].furnitureId
    if firstFurnitureId then
        numStates = GetPlacedHousingFurnitureNumObjectStates(firstFurnitureId)
    end

    if not numStates or numStates < 2 then
        DevTestBed.Print("War mode cancelled. The War item must have at least two states.")
        return
    end

    if teamCount > numStates then
        DevTestBed.Print(zo_strformat(
            "War mode cancelled. This item has |cFFFF00<<1>>|r state(s), so it can only support |cFFFF00<<1>>|r War team(s).",
            tostring(numStates)
        ))
        return
    end

    local usedStates = {}
    for key, entry in pairs(warTeams) do
        local state = tonumber(entry.state)

        if state == nil or state < 0 or state >= numStates then
            DevTestBed.Print(zo_strformat(
                "War mode cancelled. Team |c00FF00<<1>>|r has an invalid win state.",
                tostring(entry.name or key)
            ))
            DevTestBed.ClearRuntimeTeamGameData()
            return
        end

        if usedStates[state] then
            DevTestBed.Print("War mode cancelled. Two War teams are using the same win state.")
            DevTestBed.ClearRuntimeTeamGameData()
            return
        end

        usedStates[state] = true

        entry.furnitureIds = matchingFurniture
        entry.trackedFurnitureIds = matchingFurniture
        entry.matchingCount = matchingCount
        entry.requiredWinCount = matchingCount
        entry.currentWinCount = 0
        entry.lastStates = {}
        entry.pendingStates = {}
        entry.pendingSinceMs = {}
        entry.appliedStates = {}
    end

    local changedStartStateCount = 0
    local randomizeStartMs = DevTestBed.GetNowMs()
    local neutralState = DevTestBed.GetUnusedWarState(numStates, usedStates)
    local startAssignments = {}

    DevTestBed.SeedRandomOnce()

    if neutralState ~= nil then
        -- If there is an unused state, use it as a neutral starting color for
        -- every item. It is also used later as the winner flash-away state.
        for _, furnitureInfo in ipairs(matchingFurniture) do
            table.insert(startAssignments, {
                furnitureInfo = furnitureInfo,
                state = neutralState,
            })
        end
    else
        -- If every state is owned by a War team, assign starting states using
        -- a shuffled round-robin distribution so the colors stay as equal as
        -- possible while still being randomized.
        local availableStates = {}
        for state = 0, numStates - 1 do
            table.insert(availableStates, state)
        end

        startAssignments = DevTestBed.GetBalancedWarStateAssignments(matchingFurniture, availableStates)
    end

    for _, assignment in ipairs(startAssignments) do
        local furnitureInfo = assignment.furnitureInfo
        local furnitureId = furnitureInfo and furnitureInfo.furnitureId
        local startState = tonumber(assignment.state)

        if furnitureId and startState ~= nil then
            HousingEditorRequestChangeState(furnitureId, startState)
            changedStartStateCount = changedStartStateCount + 1

            for _, entry in pairs(warTeams) do
                entry.lastStates[furnitureId] = startState
                entry.pendingStates[furnitureId] = startState
                entry.pendingSinceMs[furnitureId] = randomizeStartMs
                entry.appliedStates[furnitureId] = nil
            end
        end
    end

    DevTestBed.game.active = true
    DevTestBed.game.mode = "war"
    DevTestBed.game.threshold = matchingCount
    DevTestBed.game.winner = nil
    DevTestBed.game.winnerKey = nil
    DevTestBed.game.locked = false
    DevTestBed.game.pulseFurnitureLookup = {}
    DevTestBed.game.pulseSequence = {}
    DevTestBed.game.pulseIndex = 0
    DevTestBed.game.pulsePreviousFurnitureId = nil
    DevTestBed.game.pulseIntervalMs = 1500
    DevTestBed.game.warNeutralState = neutralState
    DevTestBed.game.startTimeMs = DevTestBed.GetNowMs()
    DevTestBed.game.timeLimitMinutes = timeLimitMinutes
    DevTestBed.game.endTimeMs = timeLimitMinutes and (DevTestBed.game.startTimeMs + (timeLimitMinutes * 60 * 1000)) or nil
    DevTestBed.game.frozenTimeMs = nil
    DevTestBed.game.overtime = false
    DevTestBed.game.lastTimerRefreshSecond = nil

    EVENT_MANAGER:UnregisterForUpdate(DevTestBed.name .. "WarWatcher")
    EVENT_MANAGER:RegisterForUpdate(DevTestBed.name .. "WarWatcher", 250, DevTestBed.CheckWarGameState)

    DevTestBed.ShowGameStatusWindow()

    local startModeText = "balanced random starting states"
    if neutralState ~= nil then
        startModeText = "neutral state " .. tostring(neutralState)
    end

    DevTestBed.Print(zo_strformat(
        "Started War mode. Tracking |c00FF00<<1>>|r War team(s) across |c00FF00<<2>>|r item(s). Starting with |cFFFF00<<3>>|r. States count only after remaining unchanged for 5 seconds.",
        tostring(teamCount),
        tostring(matchingCount),
        tostring(startModeText)
    ))

    if changedStartStateCount > 0 then
        DevTestBed.Dbg("Set " .. tostring(changedStartStateCount) .. " War item(s) to their starting state.")
    end

    if DevTestBed.ui and DevTestBed.ui.controlWindow then
        DevTestBed.RefreshControlWindow()
    end
end

--[[
    DevTestBed.Start

    Starts the team setup by:
        1. Rescanning the house for each team's furnitureDataId
        2. Saving the current matching furnitureIds
        3. Setting all matching items to the non-winning state
]]
function DevTestBed.Start()

    DevTestBed.StopThresholdGame(true)

    if not DevTestBed.IsInHouse(true) then return end

    if not HasAnyEditingPermissionsForCurrentHouse() then
        DevTestBed.Print("You must have housing editor permissions to use this command.")
        return
    end

    DevTestBed.savedVars.items = DevTestBed.savedVars.items or {}

    local teamCount = 0
    local changedCount = 0

    for key, entry in pairs(DevTestBed.savedVars.items) do
        teamCount = teamCount + 1

        local furnitureDataId = entry.furnitureDataId
        local winningState = tonumber(entry.state)

        if furnitureDataId and winningState ~= nil then
            -- Refresh matching furniture list for this team
            local matchingFurniture, matchingCount = DevTestBed.GetMatchingHouseFurniture(furnitureDataId)

            entry.furnitureIds = matchingFurniture
            entry.matchingCount = matchingCount

            -- Since this command only supports 2-state objects:
            -- if winning state is 0, non-winning is 1
            -- if winning state is 1, non-winning is 0
            local nonWinningState = winningState == 0 and 1 or 0

            for _, furnitureInfo in ipairs(matchingFurniture) do
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

    if teamCount == 0 then
        DevTestBed.Print("No teams have been created.")
        return
    end

    DevTestBed.Print(zo_strformat(
        "Started game setup. Refreshed |c00FF00<<1>>|r team(s) and placed |c00FF00<<2>>|r item(s) into their non-winning state.",
        tostring(teamCount),
        tostring(changedCount)
    ))
end

--[[
    DevTestBed.ResetGame

    Stops any active game, watcher updates, winner pulse, and target decoy cycling,
    then sets every placed furnishing belonging to every saved team to that team's
    non-winning state.

    Usage:
        /dtb reset

    Behavior:
        - Requires the player to be inside a house
        - Requires housing editor permissions
        - Stops threshold watcher, target watcher, target decoy randomizer, and winner pulse
        - Clears active winner/game state
        - Rescans all saved team furnitureDataIds
        - Sets all matching 2-state furnishings to the non-winning state
        - Hides the status window after reset
]]
function DevTestBed.ResetGame()
    if not DevTestBed.IsInHouse(true) then
        return
    end

    if not HasAnyEditingPermissionsForCurrentHouse() then
        DevTestBed.Print("You must have housing editor permissions to use this command.")
        return
    end

    DevTestBed.savedVars.items = DevTestBed.savedVars.items or {}

    local teamCount = 0
    local scannedCount = 0
    local changedCount = 0

    -- Stop all active game update loops before making reset state changes.
    -- This unregisters threshold, target, decoy randomizer, and winner pulse updates.
    DevTestBed.StopThresholdGame(true)

    for key, entry in pairs(DevTestBed.savedVars.items) do
        teamCount = teamCount + 1

        local furnitureDataId = entry.furnitureDataId
        local winningState = tonumber(entry.state)

        if furnitureDataId and winningState ~= nil then
            local matchingFurniture, matchingCount = DevTestBed.GetMatchingHouseFurniture(furnitureDataId)
            local nonWinningState = DevTestBed.GetNonWinningState(winningState)

            entry.furnitureIds = matchingFurniture
            entry.matchingCount = matchingCount

            for _, furnitureInfo in ipairs(matchingFurniture or {}) do
                local furnitureId = furnitureInfo and furnitureInfo.furnitureId

                if furnitureId then
                    local numStates = GetPlacedHousingFurnitureNumObjectStates(furnitureId)

                    if numStates == 2 then
                        scannedCount = scannedCount + 1

                        local currentState = GetPlacedHousingFurnitureCurrentObjectStateIndex(furnitureId)

                        if tonumber(currentState) ~= tonumber(nonWinningState) then
                            HousingEditorRequestChangeState(furnitureId, nonWinningState)
                            changedCount = changedCount + 1
                        end
                    end
                end
            end
        else
            DevTestBed.Dbg(zo_strformat(
                "Reset skipped team <<1>> because furnitureDataId or winning state was missing.",
                tostring(entry.name or key)
            ))
        end
    end

    for key, entry in pairs(DevTestBed.savedVars.warTeams or {}) do
        teamCount = teamCount + 1

        if entry.furnitureDataId then
            local matchingFurniture, matchingCount = DevTestBed.GetMatchingHouseFurniture(entry.furnitureDataId)
            entry.furnitureIds = matchingFurniture
            entry.matchingCount = matchingCount

            for _, furnitureInfo in ipairs(matchingFurniture) do
                local furnitureId = furnitureInfo and furnitureInfo.furnitureId
                if furnitureId then
                    scannedCount = scannedCount + 1
                    HousingEditorRequestChangeState(furnitureId, 0)
                    changedCount = changedCount + 1
                end
            end
        end
    end

    DevTestBed.HideGameStatusWindow()

    if teamCount == 0 then
        DevTestBed.Print("No teams have been created.")
        return
    end

    DevTestBed.Print(zo_strformat(
        "Reset complete. Stopped the active game and set |c00FF00<<1>>|r of |c00FF00<<2>>|r team item(s) to their non-winning state.",
        tostring(changedCount),
        tostring(scannedCount)
    ))

    if DevTestBed.ui and DevTestBed.ui.controlWindow then
        DevTestBed.PopulateControlCountDropdown()
        DevTestBed.RefreshControlWindow()
    end
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

    if cmd == "war" then
        local subCmd, subRest = string.match(rest or "", "^(%S*)%s*(.-)%s*$")
        subCmd = string.lower(subCmd or "")

        if subCmd == "add" then
            DevTestBed.AddSelectedWarTeam(subRest)
            return
        end

        if subCmd == "teams" or subCmd == "list" then
            DevTestBed.ListWarTeams()
            return
        end

        if subCmd == "delete" then
            DevTestBed.DeleteWarTeam(subRest)
            return
        end

        if subCmd == "deleteall" then
            DevTestBed.DeleteAllWarTeams()
            return
        end

        DevTestBed.Print("Use: /dtb war add <name>")
        DevTestBed.Print("Use: /dtb war teams")
        DevTestBed.Print("Use: /dtb war delete <name>")
        DevTestBed.Print("Use: /dtb war deleteall")
        return
    end

    if cmd == "reset" then
        DevTestBed.ResetGame()
        return
    end

    if cmd == "start" then
        local mode, countText = string.match(rest or "", "^(%S*)%s*(.-)$")
        mode = string.lower(mode or "")

        if mode == "war" then
            local minutesText, extraText = string.match(countText or "", "^(%S*)%s*(.-)%s*$")

            if extraText and extraText ~= "" then
                DevTestBed.Print("Use: /dtb start war [minutes]")
                return
            end

            if minutesText == "" then
                minutesText = nil
            end

            DevTestBed.StartWarMode(minutesText)
            return
        end

        if mode == "threshold" or mode == "target" then
            local countValue, minutesText, extraText = string.match(countText or "", "^(%S*)%s*(%S*)%s*(.-)%s*$")

            if extraText and extraText ~= "" then
                DevTestBed.Print("Use: /dtb start " .. tostring(mode) .. " <count> [minutes]")
                return
            end

            if minutesText == "" then
                minutesText = nil
            end

            if mode == "threshold" then
                DevTestBed.StartThresholdMode(countValue, minutesText)
            else
                DevTestBed.StartTargetMode(countValue, minutesText)
            end

            return
        end

        if mode ~= "" then
            DevTestBed.Print("Unknown start mode: " .. tostring(mode))
        end

        DevTestBed.Print("Use: /dtb start threshold <count> [minutes]")
        DevTestBed.Print("Use: /dtb start target <count> [minutes]")
        DevTestBed.Print("Use: /dtb start war [minutes]")
        return
    end

    if cmd == "window" then
        DevTestBed.ToggleGameStatusWindow()
        return
    end

    if cmd == "controls" or cmd == "control" then
        DevTestBed.ToggleControlWindow()
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

    DevTestBed.savedVars.warTeams = DevTestBed.savedVars.warTeams or {}

    SLASH_COMMANDS["/devtestbed"] = DevTestBed.HandleSlashCommand
    SLASH_COMMANDS["/dtb"] = DevTestBed.HandleSlashCommand

    EVENT_MANAGER:RegisterForEvent(DevTestBed.name, EVENT_PLAYER_ACTIVATED, DevTestBed.OnPlayerActivated)

    DevTestBed.Dbg("Initialized.")
end

EVENT_MANAGER:RegisterForEvent(DevTestBed.name, EVENT_ADD_ON_LOADED, DevTestBed.OnAddonLoaded)
