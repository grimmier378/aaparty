--[[ 
    Title: AA Party
    Author: Grimmier
    Description: This plugin is designed to help manage AA experience for a group of characters using Actors.
    It will display the current Exp Percent, Percent AA, as well as the Slider Value for AA XP Split.
    You can adjust the AA experience Slider setting for each character, from any characters GUI.

    Hover the AA XP bar to see the current AA XP percentage, as well as Unspent AA, Spent AA, and Total AA.
]]

local mq = require('mq')
local imgui = require 'ImGui'
local actors = require('actors')
local PctAA, SettingAA, PtsAA, PtsSpent, PtsTotal = 0, '0', 0, 0, 0
local LoadTheme = require('lib.theme_loader')
local themeID = 1
local theme, defaults, settings = {}, {}, {}
local themeFile = string.format('%s/MyThemeZ.lua', mq.configDir)
local configFile = mq.configDir .. '/myui/AA_Party_Configs.lua'
local themezDir = mq.luaDir .. '/themez/init.lua'
local themeName = 'Default'
local script = 'AA Party'
local ME = ''
local Actor -- preloaded variable outside of the function
local groupData, mailBox = {}, {}
local AAPartyShow, MailBoxShow,AAPartyConfigShow = false, false,false
local MeLevel = mq.TLO.Me.Level()
local PctExp = mq.TLO.Me.PctExp()
local expand, compact = {}, {}
local winFlags = bit32.bor(ImGuiWindowFlags.None)
local RUNNING, aSize, hasThemeZ, firstRun = false, false, false, false
local checkIn = os.time()
local scale = 1
local alphaSort, showTooltip = false, true

defaults = {
    Scale = 1,
    LoadTheme = 'Default',
    AutoSize = false,
    ShowTooltip = true,
    MaxRow = 1,
    AlphaSort = false,
}


---comment Check to see if the file we want to work on exists.
---@param name string -- Full Path to file
---@return boolean -- returns true if the file exists and false otherwise
local function File_Exists(name)
    local f=io.open(name,"r")
    if f~=nil then io.close(f) return true else return false end
end

local function loadTheme()
    if File_Exists(themeFile) then
        theme = dofile(themeFile)
        else
        theme = require('themes') -- your local themes file incase the user doesn't have one in config folder
    end
    themeName = settings[script].LoadTheme or 'Default'
    if theme and theme.Theme then
        for tID, tData in pairs(theme.Theme) do
            if tData['Name'] == themeName then
                themeID = tID
            end
        end
    end
end

local function loadSettings()
    -- Check if the dialog data file exists
    local newSetting = false
    if not File_Exists(configFile) then
        settings[script] = defaults
        mq.pickle(configFile, settings)
        loadSettings()
    else
			
        -- Load settings from the Lua config file
        settings = dofile(configFile)
        if settings[script] == nil then
            settings[script] = {}
            settings[script] = defaults 
            newSetting = true
        end
    end
		
    if settings[script].locked == nil then
        settings[script].locked = false
        newSetting = true
    end
	
    if settings[script].AlphaSort == nil then
        settings[script].AlphaSort = false
        newSetting = true
    end

    if settings[script].Scale == nil then
        settings[script].Scale = 1
        newSetting = true
    end

    if settings[script].ShowTooltip == nil then
        settings[script].ShowTooltip = true
        newSetting = true
    end

    if settings[script].MaxRow == nil then
        settings[script].MaxRow = 1
        newSetting = true
    end
	
    if settings[script].LoadTheme == nil then
        settings[script].LoadTheme = 'Default'
        newSetting = true
    end

    loadTheme()

    if settings[script].AutoSize == nil then
        settings[script].AutoSize = aSize
        newSetting = true
    end
		
    -- Set the settings to the variables
    alphaSort = settings[script].AlphaSort
    aSize = settings[script].AutoSize
    scale = settings[script].Scale
    showTooltip = settings[script].ShowTooltip
    themeName = settings[script].LoadTheme
    if newSetting then mq.pickle(configFile, settings) end
	
end

local function CheckIn()
    local now = os.time()
    if now - checkIn >= 60 or firstRun then
        checkIn = now
        return true
    end
    return false
end

local function CheckStale()
    local now = os.time()
    local found = false
    for i = 1, #groupData do
        if groupData[1].Check == nil then
            table.remove(groupData, i)
            found = true
            break
        else
            if now - groupData[i].Check > 120 then
                table.remove(groupData, i)
                found = true
                break
            end
        end
    end
    if found then CheckStale() end
end

local function GenerateContent(who,sub, what)
    local doWhat = what or nil
    local doWho = who or nil
    local Subject = sub or 'Update'
    if firstRun then Subject = 'Hello' firstRun = false end
    return {
        Subject = Subject,
        PctExp = PctExp,
        PctExpAA = PctAA,
        Level = MeLevel,
        Setting = SettingAA,
        DoWho = doWho,
        DoWhat = doWhat,
        Name = ME,
        Pts = PtsAA,
        PtsTotal = PtsTotal,
        PtsSpent = PtsSpent,
        Check = checkIn
    }
end

local function sortedBoxes(boxes)
    table.sort(boxes, function(a, b)
        return a.Name < b.Name
    end)
    return boxes
end

--create mailbox for actors to send messages to
function RegisterActor()
    Actor = actors.register('aa_party', function(message)
        local MemberEntry = message()
        local subject = MemberEntry.Subject or 'Update'
        local aaXP = MemberEntry.PctExpAA or 0
        local aaSetting = MemberEntry.Setting or '0'
        local who = MemberEntry.Name
        local pctXP = MemberEntry.PctExp or 0
        local pts = MemberEntry.Pts or 0
        local ptsTotal = MemberEntry.PtsTotal or 0
        local ptsSpent = MemberEntry.PtsSpent or 0
        local lvlWho = MemberEntry.Level or 0
        local dowhat = MemberEntry.DoWhat or 'N/A'
        local dowho = MemberEntry.DoWho or 'N/A'
        local check = MemberEntry.Check or os.time()
        local found = false
        if MailBoxShow then
            table.insert(mailBox, {Name = who, Subject = subject, Check = check, DoWho = dowho, DoWhat = dowhat, When = os.date("%H:%M:%S")})
        end
        --New member connected if Hello is true. Lets send them our data so they have it.
        if subject == 'Hello' then
            if who ~= mq.TLO.Me.Name() then
                Actor:send({mailbox='aa_party'}, GenerateContent(nil,'Welcome'))
            end
            checkIn = os.time()
        end
        -- Check for Execution commands in message and if DoWho is You then execute them.
        if subject == 'Action' then
            if dowho ~= 'N/A' then
                if MemberEntry.DoWho == ME then
                    if dowhat == 'Less' then
                        mq.TLO.Window("AAWindow/AAW_LessExpButton").LeftMouseUp()
                        return
                    elseif dowhat == 'More' then
                        mq.TLO.Window("AAWindow/AAW_MoreExpButton").LeftMouseUp()
                        return
                    end
                end
            end
        end
        if subject == 'Goodbye' then
            check = 0
        end
        -- if subject == 'Update' or subject == 'CheckIn' or subject == 'Welcome' or subject == 'Hello' then
        -- Process the rest of the message into the groupData table.
            for i = 1, #groupData do
                if groupData[i].Name == who then
                groupData[i].PctExpAA = aaXP
                groupData[i].PctExp = pctXP
                groupData[i].Setting = aaSetting
                groupData[i].Pts = pts
                groupData[i].PtsTotal = ptsTotal
                groupData[i].PtsSpent = ptsSpent
                groupData[i].Level = lvlWho
                groupData[i].Check = check
                found = true
                break
                end
            end
            if not found then
                table.insert(groupData, 
                    {Name = who,
                    Level = lvlWho,
                    PctExpAA = aaXP,
                    PctExp = pctXP,
                    DoWho = nil,
                    DoWhat = nil,
                    Setting = aaSetting,
                    Pts = pts,
                    PtsTotal = ptsTotal,
                    PtsSpent = ptsSpent,
                    Check = check})
            end
        -- end
        if alphaSort then groupData = sortedBoxes(groupData) end
        if check == 0 then CheckStale() end

    end)
end

local function getMyAA()
    local changed = false
    local tmpExpAA = mq.TLO.Me.PctAAExp() or 0
    local tmpSettingAA = mq.TLO.Window("AAWindow/AAW_PercentCount").Text() or '0'
    local tmpPts = mq.TLO.Me.AAPoints() or 0
    local tmpPtsTotal = mq.TLO.Me.AAPointsTotal() or 0
    local tmpPtsSpent = mq.TLO.Me.AAPointsSpent() or 0
    local tmpPctXP = mq.TLO.Me.PctExp() or 0
    local tmpLvl = mq.TLO.Me.Level() or 0
    if firstRun or (PctAA ~= tmpExpAA or SettingAA ~= tmpSettingAA or PtsAA ~= tmpPts or
        PtsSpent ~= tmpPtsSpent or PtsTotal ~= tmpPtsTotal or tmpLvl ~= MeLevel or tmpPctXP ~= PctExp) then
            PctAA = tmpExpAA
            SettingAA = tmpSettingAA
            PtsAA = tmpPts
            PtsTotal = tmpPtsTotal
            PtsSpent = tmpPtsSpent
            MeLevel = tmpLvl
            PctExp = tmpPctXP
            changed = true
    end
    if not changed and CheckIn() then
        Actor:send({mailbox='aa_party'}, GenerateContent(nil,'CheckIn'))
        checkIn = os.time()
    end
    if changed then
        Actor:send({mailbox='aa_party'}, GenerateContent())
        checkIn = os.time()
        changed = false
    end
end

local function SayGoodBye()
    Actor:send({mailbox='aa_party'}, {
    Subject = 'Goodbye',
    Name = ME,
    Check = 0})
end

local function AA_Party_GUI()

    if AAPartyShow then
        imgui.SetNextWindowSize(185, 480, ImGuiCond.FirstUseEver)
        if aSize then
            winFlags = bit32.bor(ImGuiWindowFlags.AlwaysAutoResize)
        else
            winFlags = bit32.bor(ImGuiWindowFlags.None)
        end
        local ColorCount, StyleCount =LoadTheme.StartTheme(theme.Theme[themeID])
        local openGUI, showGUI = imgui.Begin("AA Party##AA_Party_"..ME, true, winFlags)
        if not openGUI then
            AAPartyShow = false
        end
        if showGUI then
            if #groupData > 0 then
                local windowWidth = imgui.GetWindowWidth() - 4
                local currentX, currentY = imgui.GetCursorPosX(), imgui.GetCursorPosY()
                local itemWidth = 150 -- approximate width
                local padding = 2 -- padding between items
                for i = 1, #groupData do
                    if i == 1 then currentY = imgui.GetCursorPosY() end
                    if groupData[i] ~= nil then
                        if expand[groupData[i].Name] == nil then expand[groupData[i].Name] = false end
                        if compact[groupData[i].Name] == nil then compact[groupData[i].Name] = false end

                        if currentX + itemWidth > windowWidth then
                            imgui.NewLine()
                            currentY = imgui.GetCursorPosY()
                            currentX = imgui.GetCursorPosX()
                            -- currentY = imgui.GetCursorPosY()
                            ImGui.SetCursorPosY(currentY - 20)
                        else
                            if i > 1 then
                                imgui.SameLine()
                                -- ImGui.SetCursorPosY(currentY)
                            end
                        end
                        local childY = 68
                        if not expand[groupData[i].Name] then childY = 42 end
                        if compact[groupData[i].Name] then childY = 25 end
                        if compact[groupData[i].Name] and expand[groupData[i].Name] then childY = 51 end
                        ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 2,2)
                        imgui.BeginChild(groupData[i].Name,145, childY, bit32.bor(ImGuiChildFlags.Border,ImGuiChildFlags.AutoResizeY))
                        -- Start of grouped Whole Elements
                        ImGui.BeginGroup()
                        -- Start of subgrouped Elements for tooltip
                        imgui.PushID(groupData[i].Name)
                        imgui.SetCursorPosX(ImGui.GetCursorPosX() + 2)
                        imgui.Text("%s (%s)", groupData[i].Name, groupData[i].Level)
                    if not compact[groupData[i].Name] then
                        imgui.PushStyleColor(ImGuiCol.PlotHistogram, ImVec4(1, 0.9, 0.4, 0.5))
                        imgui.SetCursorPosX(ImGui.GetCursorPosX() + 2)
                        imgui.ProgressBar(groupData[i].PctExp / 100, ImVec2(137, 5), "##PctXP" .. groupData[i].Name)
                        imgui.PopStyleColor()
                        imgui.PushStyleColor(ImGuiCol.PlotHistogram, ImVec4(0.2, 0.9, 0.9, 0.5))
                        imgui.SetCursorPosX(ImGui.GetCursorPosX() + 2)
                        imgui.ProgressBar(groupData[i].PctExpAA / 100, ImVec2(137, 5), "##AAXP" .. groupData[i].Name)
                        imgui.PopStyleColor()
                    end
                        imgui.PopID()
                        ImGui.EndGroup()
                        -- end of subgrouped Elements for tooltip begin tooltip
                        if ImGui.IsItemHovered() and showTooltip then
                            imgui.BeginTooltip()
                            local tTipTxt = "\t\t" .. groupData[i].Name
                            imgui.TextColored(ImVec4(1, 1, 1, 1), tTipTxt)
                            imgui.Separator()
                            tTipTxt = string.format("Exp:\t\t\t%.2f %%", groupData[i].PctExp)
                            imgui.TextColored(ImVec4(1, 0.9, 0.4, 1), tTipTxt)
                            tTipTxt = string.format("AA Exp: \t%.2f %%", groupData[i].PctExpAA)
                            imgui.TextColored(ImVec4(0.2, 0.9, 0.9, 1), tTipTxt)
                            tTipTxt = string.format("Avail:  \t\t%d", groupData[i].Pts)
                            imgui.TextColored(ImVec4(0, 1, 0, 1), tTipTxt)
                            tTipTxt = string.format("Spent:\t\t%d", groupData[i].PtsSpent)
                            imgui.TextColored(ImVec4(0.9, 0.4, 0.4, 1), tTipTxt)
                            tTipTxt = string.format("Total:\t\t%d", groupData[i].PtsTotal)
                            imgui.TextColored(ImVec4(0.8, 0.0, 0.8, 1.0), tTipTxt)
                            imgui.EndTooltip()
                        end
                        if imgui.IsItemHovered() then
                            if imgui.IsMouseReleased(0) then
                                expand[groupData[i].Name] = not expand[groupData[i].Name]
                            end
                            if imgui.IsMouseReleased(1) then
                                compact[groupData[i].Name] = not compact[groupData[i].Name]
                            end
                        end
                        -- end tooltip

                        -- expanded section for adjusting AA settings
                        
                        if expand[groupData[i].Name] then
                            imgui.SetCursorPosX(ImGui.GetCursorPosX() + 12)
                            if imgui.Button("<##Decrease" .. groupData[i].Name) then
                                Actor:send({mailbox = 'aa_party'}, GenerateContent(groupData[i].Name,'Action', 'Less'))
                            end
                            imgui.SameLine()
                            local tmp = groupData[i].Setting
                            tmp = tmp:gsub("%%", "")
                            local AA_Set = tonumber(tmp) or 0
                            -- this is for my OCD on spacing
                            if AA_Set == 0 then
                                imgui.Text("AA Set:    %d", AA_Set)
                                imgui.SameLine()
                                imgui.SetCursorPosX(ImGui.GetCursorPosX() + 7)
                            elseif AA_Set < 100 then
                                imgui.Text("AA Set:   %d", AA_Set)
                                imgui.SameLine()
                                imgui.SetCursorPosX(ImGui.GetCursorPosX() + 2)
                            else
                                imgui.Text("AA Set: %d", AA_Set)
                                imgui.SameLine()
                                imgui.SetCursorPosX(ImGui.GetCursorPosX())
                            end

                            if imgui.Button(">##Increase" .. groupData[i].Name) then
                                Actor:send({mailbox = 'aa_party'}, GenerateContent(groupData[i].Name,'Action', 'More'))
                            end
                        end
                        
                        ImGui.Separator()
                        imgui.EndChild()
                        ImGui.PopStyleVar()
                        -- End of grouped items
                        -- Left Click to expand the group for AA settings
                        currentX = currentX + itemWidth + padding
                    end
                end
            end
            if ImGui.BeginPopupContextWindow() then
                if ImGui.MenuItem("Config##Config_"..ME) then
                    AAPartyConfigShow = not AAPartyConfigShow
                end
                if ImGui.MenuItem("Toggle Auto Size##Size_"..ME) then
                    aSize = not aSize
                end
                if ImGui.MenuItem("Toggle Tooltip##Tooltip_"..ME) then
                    showTooltip = not showTooltip
                end
                ImGui.EndPopup()
            end
        end
        LoadTheme.EndTheme(ColorCount, StyleCount)
        imgui.End()
    end


    if MailBoxShow then
        local ColorCount, StyleCount =LoadTheme.StartTheme(theme.Theme[themeID])
        local openMail, showMail = imgui.Begin("AA Party MailBox##MailBox_"..ME, true, ImGuiWindowFlags.None)
        if not openMail then
            MailBoxShow = false
            mailBox = {}
        end
        if showMail then
            ImGui.BeginTable("Mail Box##AAparty", 6, bit32.bor(ImGuiTableFlags.Borders,ImGuiTableFlags.Resizable,ImGuiTableFlags.ScrollY), ImVec2(0.0, 0.0))
            ImGui.TableSetupScrollFreeze(0, 1)
            ImGui.TableSetupColumn("Sender", ImGuiTableColumnFlags.WidthFixed, 100)
            ImGui.TableSetupColumn("Subject", ImGuiTableColumnFlags.WidthFixed, 100)
            ImGui.TableSetupColumn("TimeStamp", ImGuiTableColumnFlags.WidthFixed, 100)
            ImGui.TableSetupColumn("DoWho", ImGuiTableColumnFlags.WidthFixed, 100)
            ImGui.TableSetupColumn("DoWhat", ImGuiTableColumnFlags.WidthFixed, 100)
            ImGui.TableSetupColumn("CheckIn", ImGuiTableColumnFlags.WidthFixed, 100)
            ImGui.TableHeadersRow()
            for i = 1, #mailBox do
                ImGui.TableNextRow()
                ImGui.TableNextColumn()
                ImGui.Text(mailBox[i].Name)
                ImGui.TableNextColumn()
                ImGui.Text(mailBox[i].Subject)
                ImGui.TableNextColumn()
                ImGui.Text(mailBox[i].When)
                ImGui.TableNextColumn()
                ImGui.Text(mailBox[i].DoWho)
                ImGui.TableNextColumn()
                ImGui.Text(mailBox[i].DoWhat)
                ImGui.TableNextColumn()
                ImGui.Text(tostring(mailBox[i].Check))
            end
            ImGui.EndTable()
        end
        LoadTheme.EndTheme(ColorCount, StyleCount)
        imgui.End()
    else
        mailBox = {}
    end

    if AAPartyConfigShow then
        local ColorCountTheme, StyleCountTheme = LoadTheme.StartTheme(theme.Theme[themeID])
        local openTheme, showConfig = ImGui.Begin('Config##MySpells_',true,bit32.bor(ImGuiWindowFlags.NoCollapse, ImGuiWindowFlags.AlwaysAutoResize))
        if not openTheme then
            AAPartyConfigShow = false
        end
        if showConfig then
            ImGui.SeparatorText("Theme##MySpells")
            ImGui.Text("Cur Theme: %s", themeName)
            -- Combo Box Load Theme
            if ImGui.BeginCombo("Load Theme##MySpells", themeName) then
                    
                for k, data in pairs(theme.Theme) do
                    local isSelected = data.Name == themeName
                    if ImGui.Selectable(data.Name, isSelected) then
                        theme.LoadTheme = data.Name
                        themeID = k
                        themeName = theme.LoadTheme
                    end
                end
                ImGui.EndCombo()
            end
            
            scale = ImGui.SliderFloat("Scale##DialogDB", scale, 0.5, 2)
            if scale ~= settings[script].Scale then
                if scale < 0.5 then scale = 0.5 end
                if scale > 2 then scale = 2 end
            end
        
            if hasThemeZ then
                if ImGui.Button('Edit ThemeZ') then
                    mq.cmd("/lua run themez")
                end
                ImGui.SameLine()
            end
        
            if ImGui.Button('Reload Theme File') then
                loadTheme()
            end

            MailBoxShow = ImGui.Checkbox("Show MailBox##MySpells", MailBoxShow)
            ImGui.SameLine()
            alphaSort = ImGui.Checkbox("Alpha Sort##MySpells", alphaSort)
            showTooltip = ImGui.Checkbox("Show Tooltip##MySpells", showTooltip)

            if ImGui.Button("Save & Close") then
                settings = dofile(configFile)
                settings[script].Scale = scale
                settings[script].AlphaSort = alphaSort
                settings[script].LoadTheme = themeName
                settings[script].ShowTooltip = showTooltip
                mq.pickle(configFile, settings)
                AAPartyConfigShow = false
            end
        end
        LoadTheme.EndTheme(ColorCountTheme, StyleCountTheme)
        ImGui.End()
    end
end

local args = {...}
local function checkArgs(args)
    if #args > 0 then
        if args[1] == 'driver' then
            AAPartyShow = true
            if args[2] ~= nil and args[2] == 'mailbox' then
                MailBoxShow = true
            end
            print('\ayAA Party:\ao Setting \atDriver\ax Mode. UI will be displayed.')
            print('\ayAA Party:\ao Type \at/aaparty show\ax. to Toggle the UI')
        elseif args[1] == 'client' then
            AAPartyShow = false
            print('\ayAA Party:\ao Setting \atClient\ax Mode. UI will not be displayed.')
            print('\ayAA Party:\ao Type \at/aaparty show\ax. to Toggle the UI')
        end
    else
        AAPartyShow = true
        print('\ayAA Party: \aoNo arguments passed, defaulting to \atDriver\ax Mode. UI will be displayed.')
        print('\ayAA Party: \aoUse \at/lua run aaparty client\ax To start with the UI Off.')
        print('\ayAA Party:\ao Type \at/aaparty show\ax. to Toggle the UI')
    end
end

local function processCommand(...)
    local args = {...}
    if #args > 0 then
        if args[1] == 'gui' or args[1] == 'show' or args[1] == 'open' then
            AAPartyShow = not AAPartyShow
            if AAPartyShow then
                print('\ayAA Party:\ao Toggling GUI \atOpen\ax.')
            else
                print('\ayAA Party:\ao Toggling GUI \atClosed\ax.')
            end
        elseif args[1] == 'exit' or args[1] == 'quit'  then
            print('\ayAA Party:\ao Exiting.')
            SayGoodBye()
            RUNNING = false
        elseif args[1] == 'mailbox' then
            MailBoxShow = not MailBoxShow
            if MailBoxShow then
                print('\ayAA Party:\ao Toggling MailBox \atOpen\ax.')
            else
                print('\ayAA Party:\ao Toggling MailBox \atClosed\ax.')
            end
        else
            print('\ayAA Party:\ao Invalid command given.')
        end
    else
        print('\ayAA Party:\ao No command given.')
        print('\ayAA Party:\ag /aaparty gui \ao- Toggles the GUI on and off.')
        print('\ayAA Party:\ag /aaparty exit \ao- Exits the plugin.')
    end
end

local function init()
    ME = mq.TLO.Me.DisplayName()
    firstRun = true
    mq.delay(10000, function () return mq.TLO.Me.Zoning() == false end )
    checkArgs(args)
    mq.bind('/aaparty', processCommand)
    loadSettings()
    RegisterActor()
    mq.delay(250)
    getMyAA()
    RUNNING = true
    if File_Exists(themezDir) then
        hasThemeZ = true
    end
    mq.imgui.init('AA_Party', AA_Party_GUI)
end

local function mainLoop()
    while RUNNING do
        if  mq.TLO.EverQuest.GameState() ~= "INGAME" then SayGoodBye() print("\aw[\atAA Party\ax] \arNot in game, \aoSaying \ayGoodbye\ax and Shutting Down...") mq.exit() end
        mq.delay(10000, function () return mq.TLO.Me.Zoning() == false end )
        getMyAA()       
        mq.delay(50)
        CheckStale()
    end
    mq.exit()
end

if mq.TLO.EverQuest.GameState() ~= "INGAME" then print("\aw[\atAA Party\ax] \arNot in game, \ayTry again later...") mq.exit() end
init()
mainLoop()