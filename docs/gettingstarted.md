## Installation

### [Get from the Roblox Toolbox]("https://create.roblox.com/store/asset/104280357701717") or [Download from Github]("https://github.com/J1ck/ProfileStoreWrapper/releases/tag/Release")

## Usage

Place the module anywhere where both the Client and Server can access it. There is no need to extract the underlying Client and Server modules, however the wrapper will work perfectly fine if you decide to do so.

### Client
```luau linenums="1"
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileStoreWrapper = require(ReplicatedStorage.ProfileStoreWrapper)

-- nothing more is required, feel free to interact with the Client API however you want!

local Profile = ProfileStoreWrapper.GetDataAsync()

ProfileStoreWrapper.ListenToValueChanged({"Coins"}, function(Coins : number)
    Path.To.UI.Text = `Coins: {Coins}`
end)
```

### Server
```luau linenums="1"
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local BadgeService = game:GetService("BadgeService")

local ProfileStoreWrapper = require(ReplicatedStorage.ProfileStoreWrapper)

-- as the wrapper doesn't handle stopping and starting sessions, it is our job to handle that

local function OnPlayerAdded(Player : Player)
    ProfileStoreWrapper.StartSessionAsync(Player)

    -- youre free to do whatever you want with this player's profile from this point on!

    local Profile = ProfileStoreWrapper.GetProfile(Player)

    ProfileStoreWrapper.ListenToValueChanged(Player, {"Coins"}, function(Coins : number)
        if Coins > 100 then
            BadgeService:AwardBadge(Player, BADGE_ID)
        end
    end)
end

local function OnPlayerRemoving(Player : Player)
    ProfileStoreWrapper.EndSessionAsync(Player)
end

for _, Player in Players:GetPlayers() do
    task.spawn(OnPlayerAdded, Player)
end

Players.PlayerAdded:Connect(OnPlayerAdded)
Players.PlayerRemoving:Connect(OnPlayerRemoving)
```