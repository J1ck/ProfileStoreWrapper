local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Serializer = require(ReplicatedStorage:WaitForChild("PLAYER_DATA_SERIALIZER"))

local PlayerDataChangedRemote = ReplicatedStorage:WaitForChild("PLAYER_DATA_CHANGED")

type ChangedPackage = {
	Callback : (NewValue : any) -> (),
	Path : {any}
}
type DataPath = {[number] : string}
type MiscTable = {[any] : any}
type DisconnectCallback = () -> ()

local ProfileStoreWrapper = {}

local ChangedPackages : {[ChangedPackage] : any} = {}
local ProfileData : MiscTable = {}
local LastProfileDataDeepCopy : MiscTable = {}

local function DeepCopy<T>(Table : T & MiscTable) : T
	local Clone = table.clone(Table)

	for Index, Value in Clone do
		if typeof(Value) == "table" then
			Clone[Index] = DeepCopy(Value)
		end
	end

	return Clone
end

local function MergeDiff(ParentTable : {any}, Added : {any}, Removed : {any})
	for Index, Value in Added do
		if typeof(Value) == "table" and typeof(ParentTable[Index]) == "table" then
			MergeDiff(ParentTable[Index], Value, {})
		else
			ParentTable[Index] = Value
		end
	end
	for Index, Value in Removed do
		if typeof(Value) == "table" and typeof(ParentTable[Index]) == "table" then
			MergeDiff(ParentTable[Index], {}, Value)
		else
			ParentTable[Index] = nil
		end
	end
end

local function FireChangedCallbacks(Added : MiscTable, Removed : MiscTable)
	for Package : ChangedPackage in ChangedPackages do
		local AddedPath = ProfileStoreWrapper.GetDataFromPath(Added, Package.Path)
		local RemovedPath = ProfileStoreWrapper.GetDataFromPath(Removed, Package.Path)

		if AddedPath or RemovedPath then
			task.spawn(Package.Callback, ProfileStoreWrapper.GetDataFromPath(ProfileStoreWrapper.GetDataAsync(), Package.Path))
		end
	end
end

local function ListenToDataChanges()
	PlayerDataChangedRemote.OnClientEvent:Connect(function(Added, Removed)
		Added, Removed = Serializer.decode(Added), Serializer.decode(Removed)

		MergeDiff(ProfileData, Added, Removed)

		LastProfileDataDeepCopy = DeepCopy(ProfileData)

		FireChangedCallbacks(Added, Removed)
	end)
end

function ProfileStoreWrapper.GetDataAsync() : MiscTable
	while not LastProfileDataDeepCopy do
		task.wait()
	end
	
	return LastProfileDataDeepCopy
end

function ProfileStoreWrapper.GetData() : MiscTable?
	return LastProfileDataDeepCopy
end

function ProfileStoreWrapper.ListenToValueChanged(DataPath : DataPath, Callback : (NewValue : any) -> ()) : DisconnectCallback?
	local ProfileData = ProfileStoreWrapper.GetData()
	
	if ProfileData == nil then
		-- imo this is better than erroring as that can affect a lot more than the local scope
		-- id also rather this not yield
		-- other alternative are promises but i dont need more dependancies
		return nil
	end

	local Package : ChangedPackage = {
		Callback = Callback,
		Path = DataPath
	}

	local InitialPeek = ProfileStoreWrapper.GetDataFromPath(ProfileData, DataPath)

	if InitialPeek ~= nil then
		task.spawn(Callback, InitialPeek)
	end

	ChangedPackages[Package] = true

	return function()
		ChangedPackages[Package] = nil
	end
end

function ProfileStoreWrapper.GetDataFromPath(RootTable : MiscTable, DataPath : DataPath) : any?
	for _, Index : any in DataPath do
		RootTable = RootTable[Index]

		if RootTable == nil then
			return nil
		end
	end

	return RootTable
end

ListenToDataChanges()

return ProfileStoreWrapper