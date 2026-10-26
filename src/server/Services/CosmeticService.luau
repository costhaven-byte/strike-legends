-- Cosmetic looks (Addendum 2 step 12b, Config.Cosmetics): trails, strike banners, pin blasts and lane skins.
-- Bought with gems here (BuyCosmetic), or with Robux through StoreService (a product with Cosmetic = Id).
-- Saved: Cosmetics { Id = true } and EquippedCosmetics { Kind = Id } (v23). Published as the Player attributes
-- Cosmetics (";FireTrail;IceLane;") and Look_<Kind>, which every client reads (Shared.Modules.Cosmetics) to draw
-- the looks. Looks only: nothing here changes coins, XP or throws.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Cosmetics = require(Shared.Modules.Cosmetics)
local Analytics = require(script.Parent.Analytics)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RateLimit = require(script.Parent.Parent.Modules.RateLimit)
local SessionLog = require(script.Parent.Parent.Modules.SessionLog)

local LOOKS = Config.Cosmetics

local CosmeticService = {}

local function owned(player: Player): { [string]: boolean }?
	local value = PlayerDataService.Get(player, "Cosmetics")
	return if type(value) == "table" then value else nil
end

local function worn(player: Player): { [string]: string }?
	local value = PlayerDataService.Get(player, "EquippedCosmetics")
	return if type(value) == "table" then value else nil
end

local function publish(player: Player)
	local parts = {}
	for _, item in LOOKS.Items do
		local list = owned(player)
		if list and list[item.Id] then
			table.insert(parts, item.Id)
		end
	end
	player:SetAttribute("Cosmetics", if #parts > 0 then ";" .. table.concat(parts, ";") .. ";" else "")
	local equipped = worn(player) or {}
	for _, kind in LOOKS.Kinds do
		player:SetAttribute(Cosmetics.AttributeFor(kind.Id), equipped[kind.Id] or "")
	end
end

-- Gives a look (a Robux purchase) and wears it. True if the player has it now.
function CosmeticService.Give(player: Player, id: string): boolean
	local item = Cosmetics.Get(id)
	local list = owned(player)
	local equipped = worn(player)
	if not item or not list or not equipped then
		return false
	end
	list[item.Id] = true
	equipped[item.Kind] = item.Id
	publish(player)
	SessionLog.Moment(player, ("Look unlocked: %s"):format(item.Id))
	return true
end

-- The LOOKS card's gem BUY button. Returns what the client shows.
local function onBuy(player: Player, id: any)
	if not PlayerDataService.IsLoaded(player) or not RateLimit.Allow(player, "BuyCosmetic") then
		return { Ok = false, Error = "Try again" }
	end
	local item = type(id) == "string" and Cosmetics.Get(id)
	if not item or not item.Gems then
		return { Ok = false, Error = "Not for sale" }
	end
	local list = owned(player)
	if not list then
		return { Ok = false, Error = "Try again" }
	end
	if list[item.Id] then
		return { Ok = false, Error = "OWNED" }
	end
	if not PlayerDataService.Spend(player, "Gems", item.Gems) then
		return { Ok = false, Error = "Not enough gems" }
	end
	CosmeticService.Give(player, item.Id)
	Analytics.Currency(player, "Gems", -item.Gems, "Shop", "Look" .. item.Id)
	Analytics.Purchase(player, "Cosmetic", item.Id)
	return { Ok = true }
end

-- WEAR / TAKE OFF: wearing the look already worn takes it off
local function onEquip(player: Player, id: any)
	if not PlayerDataService.IsLoaded(player) or not RateLimit.Allow(player, "EquipCosmetic") then
		return { Ok = false }
	end
	local item = type(id) == "string" and Cosmetics.Get(id)
	local equipped = worn(player)
	if not item or not equipped or not Cosmetics.Owns(player, item.Id) then
		return { Ok = false }
	end
	if equipped[item.Kind] == item.Id then
		equipped[item.Kind] = nil
	else
		equipped[item.Kind] = item.Id
	end
	publish(player)
	return { Ok = true }
end

function CosmeticService:Start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local buy = Instance.new("RemoteFunction")
	buy.Name = "BuyCosmetic"
	buy.OnServerInvoke = onBuy
	buy.Parent = remotes
	local equip = Instance.new("RemoteFunction")
	equip.Name = "EquipCosmetic"
	equip.OnServerInvoke = onEquip
	equip.Parent = remotes

	-- Saved looks no longer in Config are kept in the save (just not shown), so bringing one back loses nothing
	PlayerDataService.OnLoaded(publish)
end

return CosmeticService
