local MODULE = game:GetService("ReplicatedStorage").ProfileStoreWrapper.Server
local PREFIX = "[ProfileStoreWrapperTest]:"

local Passed = 0
local Errored = 0
local Logs = 0

local function Assert<T>(Condition : any & T, Message : string) : T
    if Condition then
        print(`✅ (SUCCESS) {PREFIX} {Message}`)

        Passed += 1
    else
        print(`❌ (ERROR) {PREFIX} {Message}`)

        Errored += 1
    end

    return Condition
end

local function Log(Message : string)
    print(`⚠️ (LOG) {PREFIX} {Message}`)

    Logs += 1
end

local function AssertYielding(Callback : () -> (), Message : string)
    local Yielded = true

    task.spawn(function()
        Callback()

        Yielded = false
    end)

    Assert(Yielded == false, Message)

    while Yielded == true do
        task.wait()
    end
end

local function Finish()
    warn(`{Errored > 0 and "❌" or "✅"} {Passed} Tests Passed with {Errored} Errors`)
end

-- // -- // --

local ProfileStoreWrapper

AssertYielding(function()
    ProfileStoreWrapper = require(MODULE)
end, `module should not yield when requiring`)

-- // -- // --

local CanStartClientUnitTesting = false

local RemoteFunction = Instance.new("RemoteFunction")
RemoteFunction.Name = "UNIT_TESTING_START"
RemoteFunction.Parent = game:GetService("ReplicatedStorage")

RemoteFunction.OnServerInvoke = function()
    while CanStartClientUnitTesting == false do
        task.wait()
    end

    RemoteFunction.OnServerInvoke = function(Player, Index, Value)
        ProfileStoreWrapper.UpdateProfileAsync(Player, function(Profile)
            Log(`[CLIENT] Profile.Data.{Index} = {Profile.Data[Index]} -> {Value}`)

            Profile.Data[Index] = Value
        end)

        return true
    end

    return true
end

-- // -- // --

local Players = game:GetService("Players")
local Player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()

local IsPlayerLoaded = Assert(Player ~= nil, `player should exist`)

if not IsPlayerLoaded then
    error(`no player found, stopping unit testing early`)
end

task.spawn(function()
    Log(`[async] waiting for player's session to start`)

    Assert(ProfileStoreWrapper.GetProfileAsync(Player) ~= nil, `[async] profile should exist and guaranteed to have loaded`)

    Log(`[async] killing thread`)
end)

ProfileStoreWrapper.StartSessionAsync(Player)

Assert(ProfileStoreWrapper.GetProfile(Player) ~= nil, `profile should exist and guaranteed to have loaded`)

Log(`updating profile`)

AssertYielding(function()
    ProfileStoreWrapper.UpdateProfile(Player, function(Profile)
        Assert(Profile == ProfileStoreWrapper.GetProfile(Player), `profile should be the same table parsed into the update callback`)
    
        task.wait()

        Profile.Data.Value = true
    end)

    Assert(ProfileStoreWrapper.GetProfile(Player).Data.Value == nil, `profile data should not have updated yet`)
end, `UpdateProfile should not yield when called`)

ProfileStoreWrapper.UpdateProfileAsync(Player, function(Profile)
    task.wait()

    Profile.Data.Value2 = true
end)

Assert(ProfileStoreWrapper.GetProfile(Player).Data.Value2 == true, `profile data should be guaranteed to have updated`)

local function QueuedCallback(Profile)
    Assert(#Profile._UpdateQueue == 1 and Profile._UpdateQueue[1] == QueuedCallback, `callback should be in queue`)
end

ProfileStoreWrapper.UpdateProfile(Player, function(Profile)
    Assert(#Profile._UpdateQueue == 0, `no callbacks should be in queue`)

    task.wait()
end)
ProfileStoreWrapper.UpdateProfile(Player, QueuedCallback)

while ProfileStoreWrapper.GetProfile(Player)._IsUpdating do
    task.wait()
end

do
    local TimesFired = 0

    local Disconnect = ProfileStoreWrapper.ListenToValueChanged(Player, {"Value2"}, function(NewValue)
        TimesFired += 1

        if TimesFired == 1 then
            Assert(NewValue == true, `callback should have fired upon declaration`)
        elseif TimesFired == 2 then
            Assert(NewValue == nil, `callback should have fired when value was changed`)
        else
            Assert(false, `callback should have only fired twice`)
        end
    end)

    ProfileStoreWrapper.UpdateProfileAsync(Player, function(Profile)
        Profile.Data.Value2 = nil
    end)

    Disconnect()

    ProfileStoreWrapper.UpdateProfileAsync(Player, function(Profile)
        Profile.Data.Value2 = true
    end)

    Assert(TimesFired == 2, `callback should fire exactly twice`)
end

local MockTable = {
    Layer1 = {
        Layer2 = {
            Layer3 = true
        }
    },
    Layer1No2 = false
}

Assert(ProfileStoreWrapper.GetDataFromPath(MockTable, {"Layer1", "Layer2", "Layer3"}) == true, `data should be equal to true`)
Assert(ProfileStoreWrapper.GetDataFromPath(MockTable, {"Layer1No2"}) == false, `data should be equal to false`)
Assert(ProfileStoreWrapper.GetDataFromPath(MockTable, {"Layer1", "Layer2"}) == MockTable.Layer1.Layer2, `data should be equal to a table`)

Log(`starting client unit testing`)

CanStartClientUnitTesting = true

Log(`invoking client to finish server unit testing`)

RemoteFunction:InvokeClient(Player)

ProfileStoreWrapper.UpdateProfile(Player, function(Profile)
    task.wait()

    Assert(ProfileStoreWrapper.GetProfile(Player), `profile should still be available`)
end)

ProfileStoreWrapper.EndSessionAsync(Player)

Assert(ProfileStoreWrapper.GetProfile(Player) == nil, `profile should have unloaded`)

Finish()