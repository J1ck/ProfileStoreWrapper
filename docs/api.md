!!! tip
    Just like ProfileStore, any method that has ``Async`` in it's name will potentially yield. Read each API entry for more information on how each method yields

## Types

```luau
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

type Profile =
    ProfileStore.Profile<typeof(DefaultData)>
    & InternalProfileData
```

## Client

### GetDataAsync
```luau
.GetDataAsync() : MiscTable
```
Get's the ``LocalPlayer``'s ``Profile.Data``.
If their Profile hasn't been loaded, this method will yield until it has loaded

### GetData
```luau
.GetData() : MiscTable?
```
Get's the given ``LocalPlayer``'s ``Profile.Data``
	
!!! warning
    This method will potentially return ``nil`` if the ``LocalPlayer``'s Profile hasn't been loaded yet.
	You should use ``GetDataAsync`` if the Profile isn't guaranteed to be loaded

### ListenToValueChanged
``` luau
.ListenToValueChanged(
    DataPath : DataPath,
    Callback : (NewValue : any) -> ()
) : DisconnectCallback
```
Listens to any data changed in the specified ``DataPath`` and will fire the given callback.
This method also works for tables and will fire when anything inside the table is changed.
Returns a function to disconnect the listener

!!! warning
    This method will yield if the ``LocalPlayer``'s Profile hasn't been loaded yet

**Example Usage**
``` luau linenums="1"
local Disconnect = nil

Disconnect = ProfileStoreWrapper.ListenToValueChanged({"Statistics", "DistanceTravelled"}, function(DistanceTravelled : number)
    Path.To.UI.Text = `Distance: {DistanceTravelled}`
end)

-- call to disconnect the listener
Disconnect()

-- listening to the whole Statistics table will also work
Disconnect = ProfileStoreWrapper.ListenToValueChanged({"Statistics"}, function(Statistics)
    Path.To.UI.Text = `Distance: {Statistics.DistanceTravelled}`
end)
```

### GetDataFromPath
```luau
.GetDataFromPath(RootTable : MiscTable, DataPath : DataPath) : any?
```
Used internally to get the current value of a ``DataPath`` in a specified table, usually ``Profile.Data``.

**Example Usage**
``` luau linenums="1"
local DataPath = {"Statistics", "TimesJoined"}
local ProfileData = ProfileStoreWrapper.GetDataAsync()
local CurrentValue = ProfileStoreWrapper.GetDataFromPath(ProfileData, DataPath)

if CurrentValue > 100 then
    Path.To.UI.Visible = true
end
```

## Server

### StartSessionAsync
```luau
.StartSessionAsync(Player : Player)
```
Starts a session with the given ``Player`` if one hasn't already been started.
Should be called when a ``Player`` joines the game through events such as ``Players.PlayerAdded``

**Example Usage**
```luau linenums="1"
local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(Player : Player)
    ProfileStoreWrapper.StartSessionAsync(Player)
    
    local Profile = ProfileStoreWrapper.GetProfile(Player) -- as CreateProfileAsync doesn't return anything, we can use this method instead
end)
```

### EndSessionAsync
```luau
.EndSessionAsync(Player : Player)
```
Ends the given ``Player``'s session and will subsequently kick them

!!! tip
    This method will wait for the update queue to be completely flushed before ending the session

**Example Usage**
```luau linenums="1"
local Players = game:GetService("Players")

Players.PlayerRemoving:Connect(function(Player : Player)
    ProfileStoreWrapper.UpdateProfile(Player, function(Profile)
        task.wait(1)
        
        Profile.Data.Coins += 100
    end)

    ProfileStoreWrapper.EndSessionAsync(Player) -- will wait for all callbacks to run before ending the player's session
end)
```

### GetProfileAsync
```luau
.GetProfileAsync(Player : Player) : Profile?
```
Get's the given ``Player``'s Profile.
If their Profile hasn't been loaded, this method will yield until it has loaded

!!! warning
    If a ``Player`` leaves while this method is being called, it will return ``nil``. If you want to safely update a ``Player``'s data, consider using ``.UpdateProfile`` or ``.UpdateProfileAsync``

!!! danger
    Updating a Profile's data outside of using ``.UpdateProfile`` or ``.UpdateProfileAsync`` will not replicate until the ``Player`` rejoins the game. Treat the Profile's ``Profile.Data`` returned from this method as read-only 

### GetProfile
```luau
.GetProfile(Player : Player) : Profile?
```
Get's the given ``Player``'s Profile.
	
!!! warning
    This method will potentially return ``nil`` if the given ``Player``'s Profile hasn't been loaded yet.
	You should use ``GetProfileAsync`` if the Profile isn't guaranteed to be loaded

!!! danger
    Updating a Profile's data outside of using ``.UpdateProfile`` or ``.UpdateProfileAsync`` will not replicate until the ``Player`` rejoins the game. Treat the Profile's ``Profile.Data`` returned from this method as read-only

### UpdateProfileAsync
```luau
.UpdateProfileAsync(Player : Player, Callback : (Profile : Profile) -> ())
```
Updates the given ``Player``'s Profile using the provided callback.
Will yield until the provided callback has completed

**Example Usage**
```luau linenums="1"
RemoteEvent.OnServerEvent:Connect(function(Player : Player)
    ProfileStoreWrapper.UpdateProfileAsync(Player, function(Profile : ProfileStoreWrapper.Profile)
        task.wait(1)
    
        Profile.Data.Coins += 100
    end)
    
    -- Player will now guaranteed have 100 more coins
end)
```

### UpdateProfile
```luau
.UpdateProfile(Player : Player, Callback : (Profile : Profile) -> ())
```
Updates the given ``Player``'s Profile using the provided callback.
	
!!! warning
    This method will not yield at all, which means that the ``Player``'s data may not be updated even after the method was called. You should use ``UpdateProfileAsync`` if you need the provided callback to also yield the called method's scope

**Example Usage**
```luau linenums="1"
RemoteEvent.OnServerEvent:Connect(function(Player : Player)
    ProfileStoreWrapper.UpdateProfile(Player, function(Profile : ProfileStoreWrapper.Profile)
        task.wait(1)
    
        Profile.Data.Coins += 100
    end)
    
    -- Player will NOT have 100 more coins as these 2 scopes are now running in parallel
end)
```

### ListenToValueChanged
```luau
.ListenToValueChanged(
    Player : Player,
    DataPath : DataPath,
    Callback : (NewValue : any) -> ()
) : DisconnectCallback?
```
Listens to any data changed in the specified ``DataPath`` and will fire the given callback.
This method also works for tables and will fire when anything inside the table is changed.
Returns a function to disconnect the listener

!!! warning
    This method will return ``nil`` if there is no Profile attached to the given ``Player``, including if the ``Player``'s Profile hasn't loaded yet

**Example Usage**
```luau linenums="1"
local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(Player : Player)
    ProfileStoreWrapper.StartSessionAsync(Player)
    
    local Disconnect = nil

    Disconnect = ProfileStoreWrapper.ListenToValueChanged(Player, {"Statistics", "DistanceTravelled"}, function(DistanceTravelled : number)
        if DistanceTravelled > 100 then
            ProfileStoreWrapper.UpdateProfile(Player, function(Profile : ProfileStoreWrapper.Profile)
                Profile.Data.Coins += 50
                Profile.Data.Statistics.DistanceTravelled = 0
            end)
        end
    end)

    -- call to disconnect the listener
    Disconnect()
    
    -- listening to the whole Statistics table will also work
    Disconnect = ProfileStoreWrapper.ListenToValueChanged(Player, {"Statistics"}, function(Statistics)
        if Statistics.DistanceTravelled > 100 then
            ProfileStoreWrapper.UpdateProfile(Player, function(Profile : ProfileStoreWrapper.Profile)
                Profile.Data.Coins += 50
                Profile.Data.Statistics.DistanceTravelled = 0
            end)
        end
    end)
end)
```

### GetDataFromPath
```luau
.GetDataFromPath(RootTable : MiscTable, DataPath : DataPath) : any?
```
Used internally to get the current value of a DataPath in a specified table, usually ``Profile.Data``

**Example Usage**	
```luau
local Players = game:GetService("Players")
local BadgeService = game:GetService("BadgeService")

Players.PlayerAdded:Connect(function(Player : Player)
    ProfileStoreWrapper.StartSessionAsync(Player)

    local DataPath = {"Statistics", "TimesJoined"}
    local Profile = ProfileStoreWrapper.GetProfile(Player)
    local CurrentValue = ProfileStoreWrapper.GetDataFromPath(Profile.Data, DataPath)
    
    if CurrentValue > 100 then
        BadgeService:AwardBadge(Player, BADGE_ID)
    end
end)
```