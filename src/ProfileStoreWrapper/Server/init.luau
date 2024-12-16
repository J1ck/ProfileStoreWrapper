local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ProfileStore = require(script:WaitForChild("ProfileStore"))
local DefaultData = require(script:WaitForChild("DefaultData"))
local Serializer = require(script:WaitForChild("Serializer"))

local PlayerDataChangedRemote = Instance.new("RemoteEvent")
PlayerDataChangedRemote.Name = "PLAYER_DATA_CHANGED"
PlayerDataChangedRemote.Parent = ReplicatedStorage

local SerializerModule = script:FindFirstChild("Serializer")
SerializerModule.Name = "PLAYER_DATA_SERIALIZER"
SerializerModule.Parent = ReplicatedStorage

local PlayerStore = ProfileStore.New("PlayerStore", DefaultData)

type ChangedPackage = {
	Callback : (NewValue : any) -> (),
	Path : {any}
}
type InternalProfileData = {
	_Player : Player,
	_IsUpdating : boolean,
	_ChangedPackages : {[ChangedPackage] : any},
	_UpdateQueue : {[number] : (Profile : Profile) -> ()}
}
type DataPath = {[number] : string}
type MiscTable = {[any] : any}
type DisconnectCallback = () -> ()

export type Profile = ProfileStore.Profile<typeof(DefaultData)> & InternalProfileData

local ProfileStoreWrapper = {}

local ActiveProfiles : {[Player] : Profile} = {}

local function DeepCopy<T>(Table : T & MiscTable) : T
	local Clone = table.clone(Table)

	for Index, Value in Clone do
		if typeof(Value) == "table" then
			Clone[Index] = DeepCopy(Value)
		end
	end

	return Clone
end

local function GetDiff(Previous : MiscTable, Current : MiscTable) : (MiscTable, MiscTable)
	local Added = {}
	local Removed = {}

	for Index, Value in Previous do
		if typeof(Value) == "table" and typeof(Current[Index]) == "table" then
			local NestedAddedDiff, NestedRemovedDiff = GetDiff(Value, Current[Index])

			if next(NestedAddedDiff) then
				Added[Index] = NestedAddedDiff
			end
			if next(NestedRemovedDiff) then
				Removed[Index] = NestedRemovedDiff
			end
		elseif Current[Index] ~= Value then
			if Current[Index] == nil then
				Removed[Index] = true
			else
				Added[Index] = Current[Index]
			end
		end
	end

	for Index, Value in Current do
		if Previous[Index] == nil then
			Added[Index] = Value
		end
	end

	return Added, Removed
end

local function ReplicateDataChange(Profile : Profile, Added : MiscTable, Removed : MiscTable)
	if not (next(Added) or next(Removed)) then
		return
	end

	Added = Serializer.encode(Added)
	Removed = Serializer.encode(Removed)

	PlayerDataChangedRemote:FireClient(Profile._Player, Added, Removed)
end

local function FireChangedCallbacks(Profile : Profile, Added : MiscTable, Removed : MiscTable)
	for Package : ChangedPackage in Profile._ChangedPackages do
		local AddedPath = ProfileStoreWrapper.GetDataFromPath(Added, Package.Path)
		local RemovedPath = ProfileStoreWrapper.GetDataFromPath(Removed, Package.Path)

		if AddedPath or RemovedPath then
			task.spawn(Package.Callback, ProfileStoreWrapper.GetDataFromPath(Profile.Data, Package.Path))
		end
	end
end

local function UpdateProfileWithCallback(Profile : Profile, Callback : (Profile : Profile) -> ())
	local PreviousDataVersion = DeepCopy(Profile.Data)

	local Status, Error = pcall(Callback, Profile)

	if Status == false then
		warn(`[ProfileStore] {Error}`)

		Profile.Data = PreviousDataVersion
	else
		local Added, Removed = GetDiff(PreviousDataVersion, Profile.Data)

		ReplicateDataChange(Profile, Added, Removed)
		FireChangedCallbacks(Profile, Added, Removed)
	end
end

local function FlushProfileUpdateQueue(Profile : Profile)
	while #Profile._UpdateQueue > 0 do
		local CallbackInQueue = table.remove(Profile._UpdateQueue, 1)

		UpdateProfileWithCallback(Profile, CallbackInQueue)
	end
end

function ProfileStoreWrapper.StartSessionAsync(Player : Player)
	if ActiveProfiles[Player] ~= nil then
		return
	end
	
	local Profile : Profile = PlayerStore:StartSessionAsync(`{Player.UserId}`, {
		Cancel = function()
			return Player.Parent ~= Players
		end,
	})

	if Profile == nil then
		return Player:Kick(`Data had Trouble Loading, Please Rejoin!`)
	end
	
	Profile:AddUserId(Player.UserId)
	Profile:Reconcile()

	Profile.OnSessionEnd:Connect(function()
		ActiveProfiles[Player] = nil
		
		Player:Kick(`Data was Loaded on Another Server!`)
	end)
	
	Profile._Player = Player
	Profile._IsUpdating = false
	Profile._UpdateQueue = {}
	Profile._ChangedPackages = {}
	
	ActiveProfiles[Player] = Profile
end

function ProfileStoreWrapper.EndSessionAsync(Player : Player)
	if ActiveProfiles[Player] == nil then
		return
	end
	
	while #ActiveProfiles[Player]._UpdateQueue > 0 do
		task.wait()
	end
	
	ActiveProfiles[Player]:EndSession()
	ActiveProfiles[Player] = nil
end

function ProfileStoreWrapper.GetProfileAsync(Player : Player) : Profile?
	while ActiveProfiles[Player] == nil and Player.Parent == Players do
		task.wait()
	end
	
	return ActiveProfiles[Player]
end

function ProfileStoreWrapper.GetProfile(Player : Player) : Profile?
	return ActiveProfiles[Player]
end

function ProfileStoreWrapper.UpdateProfileAsync(Player : Player, Callback : (Profile : Profile) -> ())
	local Profile = ProfileStoreWrapper.GetProfileAsync(Player)
	
	if Profile == nil then
		return
	end
	
	if Profile._IsUpdating then
		table.insert(Profile._UpdateQueue, Callback)
		
		while table.find(Profile._UpdateQueue, Callback) ~= nil do
			task.wait()
		end
	else
		Profile._IsUpdating = true
		
		UpdateProfileWithCallback(Profile, Callback)
		FlushProfileUpdateQueue(Profile)
		
		Profile._IsUpdating = false
	end
end

function ProfileStoreWrapper.UpdateProfile(Player : Player, Callback : (Profile : Profile) -> ())
	local Profile = ProfileStoreWrapper.GetProfile(Player)
	
	if Profile == nil then
		return
	end

	if Profile._IsUpdating then
		table.insert(Profile._UpdateQueue, Callback)
	else
		task.spawn(function()
			Profile._IsUpdating = true

			UpdateProfileWithCallback(Profile, Callback)
			FlushProfileUpdateQueue(Profile)

			Profile._IsUpdating = false
		end)
	end
end

function ProfileStoreWrapper.ListenToValueChanged(Player : Player, DataPath : DataPath, Callback : (NewValue : any) -> ()) : DisconnectCallback?
	local Profile = ProfileStoreWrapper.GetProfile(Player)
	
	if Profile == nil then
		-- will no longer matter as target player has left the game
		-- imo this is better than erroring as that can affect a lot more than the local scope
		-- other alternative are promises but i dont need more dependancies
		return nil
	end

	local Package = {
		Callback = Callback,
		Path = DataPath
	}

	local InitialPeek = ProfileStoreWrapper.GetDataFromPath(Profile.Data, DataPath)

	if InitialPeek ~= nil then
		task.spawn(Callback, InitialPeek)
	end

	Profile._ChangedPackages[Package] = true

	return function()
		Profile._ChangedPackages[Package] = nil
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

return ProfileStoreWrapper