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
local ME = mq.TLO.Me.Name()
local Actor -- preloaded variable outside of the function
local groupData = {}
local RUNNING = false
local showGUI = false
local MeLevel = mq.TLO.Me.Level()
local PctExp = mq.TLO.Me.PctExp()

--create mailbox for actors to send messages to
function RegisterActor()
    Actor = actors.register('aa_party', function(message)
    local MemberEntry = message()
        if MemberEntry.Hello then
            Actor:send({mailbox='aa_party'}, {PctExp = PctExp,
            PctExpAA = PctAA,
            Level = MeLevel,
            Setting = SettingAA,
            DoWho = nil,
            DoWhat = nil,
            Name = ME,
            Pts = PtsAA,
            PtsTotal = PtsTotal,
            PtsSpent = PtsSpent})
            MemberEntry.Hello = false
        end
        local aaXP = MemberEntry.PctExpAA or 0
        local aaSetting = MemberEntry.Setting or '0'
        local who = MemberEntry.Name
        local pctXP = MemberEntry.PctExp or 0
        local pts = MemberEntry.Pts or 0
        local ptsTotal = MemberEntry.PtsTotal or 0
        local ptsSpent = MemberEntry.PtsSpent or 0
        local lvlWho = MemberEntry.Level or 0
        local found = false
        if MemberEntry.DoWho ~= nil then
            if MemberEntry.DoWho == ME then
                local doWhat = MemberEntry.DoWhat
                if doWhat == 'Less' then
                    mq.TLO.Window("AAWindow/AAW_LessExpButton").LeftMouseUp()
                elseif doWhat == 'More' then
                    mq.TLO.Window("AAWindow/AAW_MoreExpButton").LeftMouseUp()
                end
            end
        end
        for i = 1, #groupData do
            if groupData[i].Name == who then
            groupData[i].PctExpAA = aaXP
            groupData[i].PctExp = pctXP
            groupData[i].Setting = aaSetting
            groupData[i].Pts = pts
            groupData[i].PtsTotal = ptsTotal
            groupData[i].PtsSpent = ptsSpent
            groupData[i].Level = lvlWho

            found = true
            break
            end
        end
        if not found then
            table.insert(groupData, {Name = who,Level = lvlWho, PctExpAA = aaXP, PctExp = pctXP, DoWho = nil, DoWhat = nil, Setting = aaSetting, Pts = pts, PtsTotal = ptsTotal, PtsSpent = ptsSpent})
        end
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
    if (PctAA ~= tmpExpAA or SettingAA ~= tmpSettingAA or PtsAA ~= tmpPts or
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
    if changed then
        Actor:send({mailbox='aa_party'}, {PctExp = PctExp,
        PctExpAA = PctAA,
        Level = MeLevel,
        Setting = SettingAA,
        DoWho = nil,
        DoWhat = nil,
        Name = ME,
        Pts = PtsAA,
        PtsTotal = PtsTotal,
        PtsSpent = PtsSpent,
        Hello = false})
    end
end

local function AA_Party_GUI(openGUI)
    if not showGUI then return end
    imgui.SetNextWindowSize(185, 480, ImGuiCond.Appearing)
    local show = false
    openGUI, show = imgui.Begin("AA Party##AA_Party", openGUI, ImGuiWindowFlags.None)
    if show then
        if #groupData > 0 then
            for i = 1, #groupData do
                if groupData[i] ~= nil then
                    ImGui.BeginGroup()
                    ImGui.PushID(groupData[i].Name)
                    ImGui.SeparatorText("%s (%s)", groupData[i].Name, groupData[i].Level)
                    ImGui.PushStyleColor(ImGuiCol.PlotHistogram,ImVec4(1, 0.9, 0.4, 0.5))
                    ImGui.ProgressBar(groupData[i].PctExp/100,ImVec2(165,5),"##PctXP"..groupData[i].Name)
                    ImGui.PopStyleColor()
                    ImGui.PushStyleColor(ImGuiCol.PlotHistogram,ImVec4(0.2, 0.9, 0.9, 0.5))
                    ImGui.ProgressBar(groupData[i].PctExpAA/100,ImVec2(165,5),"##AAXP"..groupData[i].Name)
                    ImGui.PopStyleColor()
                    if ImGui.Button("<##Decrease"..groupData[i].Name) then
                        Actor:send({mailbox='aa_party'}, {PctExp = PctExp, PctExpAA = PctAA, Level = MeLevel, DoWho = groupData[i].Name, DoWhat = 'Less',Setting = SettingAA, Name = ME, Pts = PtsAA, PtsTotal = PtsTotal, PtsSpent = PtsSpent})
                    end
                    ImGui.SameLine()
                    local tmp = groupData[i].Setting
                    tmp = tmp:gsub("%%", "")
                    local AA_Set = tonumber(tmp) or 0
                    -- this is for my OCD on spacing
                    if AA_Set < 10 then
                        ImGui.Text("\tAA Setting:   %d", AA_Set)
                    elseif AA_Set < 100 then
                        ImGui.Text("\tAA Setting:  %d", AA_Set)
                    else
                        ImGui.Text("\tAA Setting: %d", AA_Set)
                    end
                    ImGui.SameLine()
                    ImGui.SetCursorPosX(158)
                    if ImGui.Button(">##Increase"..groupData[i].Name) then
                        Actor:send({mailbox='aa_party'}, {PctExp = PctExp, PctExpAA = PctAA, Level = MeLevel, DoWho = groupData[i].Name, DoWhat = 'More',Setting = SettingAA, Name = ME, Pts = PtsAA, PtsTotal = PtsTotal, PtsSpent = PtsSpent})
                    end
                    ImGui.PopID()
                    ImGui.EndGroup()
                    if ImGui.IsItemHovered() then
                        ImGui.BeginTooltip()
                        local tTipTxt = "\t\t"..groupData[i].Name
                        ImGui.TextColored(ImVec4(1, 1, 1, 1),tTipTxt)
                        ImGui.Separator()
                        tTipTxt = string.format("Exp:\t\t\t%.2f %%",groupData[i].PctExp)
                        ImGui.TextColored(ImVec4(1, 0.9, 0.4, 1),tTipTxt)
                        tTipTxt = string.format("AA Exp: \t%.2f %%",groupData[i].PctExpAA)
                        ImGui.TextColored(ImVec4(0.2, 0.9, 0.9, 1),tTipTxt)
                        tTipTxt = string.format("Avail:  \t\t%d",groupData[i].Pts)
                        ImGui.TextColored(ImVec4(0, 1, 0, 1),tTipTxt)
                        tTipTxt = string.format("Spent:\t\t%d",groupData[i].PtsSpent)
                        ImGui.TextColored(ImVec4(0.9, 0.4, 0.4, 1),tTipTxt)
                        tTipTxt = string.format("Total:\t\t%d",groupData[i].PtsTotal)
                        ImGui.TextColored(ImVec4(0.8, 0.0, 0.8, 1.0),tTipTxt)
                        ImGui.EndTooltip()
                    end
                end
            end
        end
    end
    imgui.End()
end

local args = {...}
local function checkArgs(args)
    if #args > 0 then
        if args[1] == 'driver' then
            showGUI = true
            print('\ayAA Party:\ao Setting \atDriver\ax Mode. UI will be displayed.')
        elseif args[1] == 'client' then
            showGUI = false
            print('\ayAA Party:\ao Setting \atClient\ax Mode. UI will not be displayed.')
        end
    else
        showGUI = true
        print('\ayAA Party: \aoNo arguments passed, defaulting to \atDriver\ax Mode. UI will be displayed.')
        print('\ayAA Party: \aoTo change to \atClient\ax Mode, pass \atclient\ax as an argument when loading the plugin.')
    end
end

local function processCommand(...)
    local args = {...}
    if #args > 0 then
        if args[1] == 'gui' then
            showGUI = not showGUI
            if showGUI then
                print('\ayAA Party:\ao Toggling GUI \atOpen\ax.')
            else
                print('\ayAA Party:\ao Toggling GUI \atClosed\ax.')
            end
        elseif args[1] == 'exit' then
            print('\ayAA Party:\ao Exiting.')
            RUNNING = false
        end
    else
        print('\ayAA Party:\ao No command given.')
        print('\ayAA Party:\ag /aaparty gui \ao- Toggles the GUI on and off.')
        print('\ayAA Party:\ag /aaparty exit \ao- Exits the plugin.')
    end
end

local function init()
    mq.delay(10000, function () return mq.TLO.Me.Zoning() == false end )
    checkArgs(args)
    mq.bind('/aaparty', processCommand)
    RegisterActor()
    getMyAA()
    mq.delay(5)
    --send message to the mailbox from this character
    Actor:send({mailbox='aa_party'}, {PctExp = PctExp,
        PctExpAA = PctAA,
        Level = MeLevel,
        Setting = SettingAA,
        DoWho = nil,
        DoWhat = nil,
        Name = ME,
        Pts = PtsAA,
        PtsTotal = PtsTotal,
        PtsSpent = PtsSpent,
        Hello = true,})
    RUNNING = true
    mq.imgui.init('AA_Party', AA_Party_GUI)
end

local function mainLoop()
    while RUNNING do
        getMyAA()
        mq.delay(10)
    end
    mq.exit()
end

init()
mainLoop()