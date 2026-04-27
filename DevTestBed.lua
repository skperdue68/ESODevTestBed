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
    DevTestBed.Print("/dtb start threshold <count> [minutes] - Start threshold mode. Optional minutes must be 1-60 and enables timed/overtime scoring")
    DevTestBed.Print("/dtb start target <count> [minutes] - Start target mode. Randomly chooses count monitored items per team; optional minutes works like threshold")
    DevTestBed.Print("/dtb window - Toggle the game status window")
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
DevTestBed.GAME_STATUS_ROW_HEIGHT = 58

function DevTestBed.SetupGameStatusRow(control, data)
    if not control or not data then return end

    local percent = 0
    if tonumber(data.requiredCount or 0) > 0 then
        percent = math.floor((tonumber(data.currentCount or 0) / tonumber(data.requiredCount)) * 100)
    end

    control:SetFont("ZoFontGame")
    control:SetColor(1, 1, 1, 1)
    control:SetText(zo_strformat(
        "|c00FF00<<1>>|r - <<2>>\n<<3>> / <<4>>  <<5>>%",
        tostring(data.teamName or "Unknown"),
        tostring(data.itemName or "Unknown"),
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

    for key, entry in pairs(DevTestBed.savedVars.items or {}) do
        if entry.trackedFurnitureIds or game.active then
            table.insert(dataList, ZO_ScrollList_CreateDataEntry(
                DevTestBed.GAME_STATUS_ROW_DATA_TYPE,
                {
                    teamName = entry.name or key,
                    itemName = entry.itemName or "Unknown",
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
end

function DevTestBed.StopThresholdGame(clearWinner)
    EVENT_MANAGER:UnregisterForUpdate(DevTestBed.name .. "ThresholdWatcher")
    EVENT_MANAGER:UnregisterForUpdate(DevTestBed.name .. "TargetWatcher")
    EVENT_MANAGER:UnregisterForUpdate(DevTestBed.name .. "TargetDecoyRandomizer")
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

function DevTestBed.SeedRandomOnce()
    if DevTestBed.randomSeeded then
        return
    end

    local seed = 0

    if type(GetTimeStamp) == "function" then
        seed = seed + tonumber(GetTimeStamp())
    elseif os and type(os.time) == "function" then
        seed = seed + tonumber(os.time())
    end

    seed = seed + tonumber(DevTestBed.GetNowMs() or 0)
    math.randomseed(seed)
    math.random()
    math.random()
    math.random()

    DevTestBed.randomSeeded = true
end

function DevTestBed.CopyFurnitureList(source)
    local copied = {}

    for index, furnitureInfo in ipairs(source or {}) do
        if furnitureInfo and furnitureInfo.furnitureId then
            copied[index] = {
                furnitureId = furnitureInfo.furnitureId,
            }
        end
    end

    return copied
end

function DevTestBed.ShuffleFurnitureList(list)
    list = list or {}
    DevTestBed.SeedRandomOnce()

    for i = #list, 2, -1 do
        local j = math.random(i)
        list[i], list[j] = list[j], list[i]
    end

    return list
end

function DevTestBed.SplitRandomTargetAndDecoyFurniture(source, targetCount)
    local shuffled = DevTestBed.ShuffleFurnitureList(DevTestBed.CopyFurnitureList(source))
    local targets = {}
    local decoys = {}

    for index, furnitureInfo in ipairs(shuffled) do
        if index <= targetCount then
            table.insert(targets, furnitureInfo)
        else
            table.insert(decoys, furnitureInfo)
        end
    end

    return targets, decoys
end

function DevTestBed.ResetGameRuntimeState(mode, requiredCount, timeLimitMinutes)
    DevTestBed.game.active = true
    DevTestBed.game.mode = mode
    DevTestBed.game.threshold = requiredCount
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
end

function DevTestBed.UpdateGameTimerRefresh()
    local nowMs = DevTestBed.GetNowMs()
    local currentTimerSecond = math.floor(nowMs / 1000)

    if not DevTestBed.game.locked and DevTestBed.game.lastTimerRefreshSecond ~= currentTimerSecond then
        DevTestBed.game.lastTimerRefreshSecond = currentTimerSecond
        DevTestBed.RefreshGameStatusWindow()
    end
end

function DevTestBed.UpdateTrackedTeamCounts()
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
                    return true
                end
            end
        end
    end

    return false
end

function DevTestBed.ValidateGameStartCountAndTime(modeName, countText, timeLimitText)
    local count = tonumber(countText)
    local timeLimitMinutes = tonumber(timeLimitText)
    local usage = "/dtb start " .. tostring(modeName) .. " <count> [minutes]"

    if not count or count < 1 or count ~= math.floor(count) then
        DevTestBed.Print("Use: " .. usage)
        DevTestBed.Print("Count must be a whole number of at least 1.")
        return nil, nil
    end

    if timeLimitMinutes ~= nil then
        if timeLimitMinutes < 1 or timeLimitMinutes > 60 or timeLimitMinutes ~= math.floor(timeLimitMinutes) then
            DevTestBed.Print("Use: " .. usage)
            DevTestBed.Print("Optional minutes must be a whole number from 1 to 60.")
            return nil, nil
        end
    end

    return count, timeLimitMinutes
end

function DevTestBed.StartWinnerPulse(winnerKey)
    EVENT_MANAGER:UnregisterForUpdate(DevTestBed.name .. "WinnerPulse")

    local entry = DevTestBed.savedVars.items and DevTestBed.savedVars.items[winnerKey]
    if not entry or not entry.trackedFurnitureIds then
        return
    end

    DevTestBed.game.pulseTeamKey = winnerKey
    DevTestBed.game.pulseFurnitureLookup = {}
    DevTestBed.game.pulseSequence = {}
    DevTestBed.game.pulseIndex = 0
    DevTestBed.game.pulsePreviousFurnitureId = nil
    DevTestBed.game.pulseIntervalMs = 1500

    for _, furnitureInfo in ipairs(entry.trackedFurnitureIds) do
        if furnitureInfo and furnitureInfo.furnitureId then
            table.insert(DevTestBed.game.pulseSequence, furnitureInfo.furnitureId)
            DevTestBed.game.pulseFurnitureLookup[furnitureInfo.furnitureId] = true
        end
    end

    if #DevTestBed.game.pulseSequence == 0 then
        return
    end

    -- Pulse one item at a time instead of flashing the entire winning team at once.
    -- This keeps state-change requests much lower and creates a sequential chase effect.
    EVENT_MANAGER:RegisterForUpdate(DevTestBed.name .. "WinnerPulse", DevTestBed.game.pulseIntervalMs, function()
        local pulseEntry = DevTestBed.savedVars.items and DevTestBed.savedVars.items[winnerKey]
        local sequence = DevTestBed.game.pulseSequence or {}

        if not DevTestBed.game.locked or not pulseEntry or not pulseEntry.trackedFurnitureIds or #sequence == 0 then
            EVENT_MANAGER:UnregisterForUpdate(DevTestBed.name .. "WinnerPulse")
            return
        end

        local winningState = tonumber(pulseEntry.state)
        local nonWinningState = DevTestBed.GetNonWinningState(winningState)

        -- Turn the previously highlighted item back off before lighting the next one.
        if DevTestBed.game.pulsePreviousFurnitureId then
            HousingEditorRequestChangeState(DevTestBed.game.pulsePreviousFurnitureId, nonWinningState)
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

    for key, entry in pairs(DevTestBed.savedVars.items or {}) do
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

    DevTestBed.UpdateGameTimerRefresh()

    if DevTestBed.UpdateTrackedTeamCounts() then
        return
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

    DevTestBed.ResetGameRuntimeState("threshold", thresholdCount, timeLimitMinutes)

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

    targetCount, timeLimitMinutes = DevTestBed.ValidateGameStartCountAndTime("target", targetCount, timeLimitMinutes)
    if not targetCount then
        return
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

    DevTestBed.ResetGameRuntimeState("target", targetCount, timeLimitMinutes)

    decoyQueue = DevTestBed.ShuffleFurnitureList(decoyQueue)
    local decoyIndex = 0

    if #decoyQueue > 0 then
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

    DevTestBed.UpdateGameTimerRefresh()

    if DevTestBed.UpdateTrackedTeamCounts() then
        return
    end

    if not DevTestBed.game.locked then
        DevTestBed.CheckThresholdTimerExpired()
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
        local mode, countText = string.match(rest or "", "^(%S*)%s*(.-)$")
        mode = string.lower(mode or "")

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
        return
    end

    if cmd == "window" then
        DevTestBed.ToggleGameStatusWindow()
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

    EVENT_MANAGER:RegisterForEvent(DevTestBed.name, EVENT_PLAYER_ACTIVATED, DevTestBed.OnPlayerActivated)

    DevTestBed.Dbg("Initialized.")
end

EVENT_MANAGER:RegisterForEvent(DevTestBed.name, EVENT_ADD_ON_LOADED, DevTestBed.OnAddonLoaded)
