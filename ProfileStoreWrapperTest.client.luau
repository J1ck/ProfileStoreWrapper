local MODULE = game:GetService("ReplicatedStorage").ProfileStoreWrapper.Client
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

local ClientUnitTestingFinished = false

local RemoteFunction = game:GetService("ReplicatedStorage"):WaitForChild("UNIT_TESTING_START")

RemoteFunction.OnClientInvoke = function()
    while ClientUnitTestingFinished == false do
        task.wait()
    end

    return true
end

Log(`invoking server to start client unit testing`)

RemoteFunction:InvokeServer()

-- // -- // --

local ProfileStoreWrapper

AssertYielding(function()
    ProfileStoreWrapper = require(MODULE)
end, `module should not yield when requiring`)

-- // -- // --

Assert(ProfileStoreWrapper.GetDataAsync() ~= nil, `[async] profile data should exist and guaranteed to have loaded`)

AssertYielding(function()
    Assert(ProfileStoreWrapper.GetData() ~= nil, `profile data should exist and guaranteed to have loaded`)
end, `GetData should not yield when called`)

do
    RemoteFunction:InvokeServer("Value3", true)

    task.wait()

    local TimesFired = 0

    local Disconnect = ProfileStoreWrapper.ListenToValueChanged({"Value3"}, function(NewValue)
        TimesFired += 1

        if TimesFired == 1 then
            Assert(NewValue == true, `callback should have fired upon declaration`)
        elseif TimesFired == 2 then
            Assert(NewValue == nil, `callback should have fired when value was changed`)
        else
            Assert(false, `callback should have only fired twice`)
        end
    end)

    RemoteFunction:InvokeServer("Value3", nil)

    task.wait()

    Disconnect()

    RemoteFunction:InvokeServer("Value3", true)

    task.wait()

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

Log(`finishing client unit testing`)

ClientUnitTestingFinished = true

Finish()