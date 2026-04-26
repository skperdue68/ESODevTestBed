DevTestBed = DevTestBed or {}
DevTestBed.name = "DevTestBed"
DevTestBed.author = "@evainefaye"
DevTestBed.version = "1.0.0"

local DEFAULT_SAVED_VARIABLES = {
    debug = false,
}

local function Dbg(message)
    if DevTestBed.savedVars and DevTestBed.savedVars.debug then
        d("|c66CCFF[DevTestBed]|r " .. tostring(message))
    end
end

local function Print(message)
    d("|c66CCFF[DevTestBed]|r " .. tostring(message))
end

local function ShowHelp()
    Print("Commands:")
    Print("/devtestbed - Show this help")
    Print("/dtb - Show this help")
    Print("/dtb debug - Toggle debug output")
    Print("/dtb ping - Confirm the add-on is loaded")
end

function DevTestBed.HandleSlashCommand(args)
    args = string.lower(args or "")

    if args == "" or args == "help" then
        ShowHelp()
        return
    end

    if args == "ping" then
        Print("Loaded and ready.")
        return
    end

    if args == "debug" then
        DevTestBed.savedVars.debug = not DevTestBed.savedVars.debug
        Print("Debug is now " .. (DevTestBed.savedVars.debug and "ON" or "OFF") .. ".")
        return
    end

    Print("Unknown command: " .. args)
    ShowHelp()
end

local function OnAddonLoaded(eventCode, addonName)
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

    Dbg("Initialized.")
end

EVENT_MANAGER:RegisterForEvent(DevTestBed.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)
