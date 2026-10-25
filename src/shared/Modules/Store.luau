-- Robux store rules both server and client use (Addendum 2 step 12a, Config.Monetization).
-- The server (StoreService) publishes the game passes a player owns as the Player attribute Passes (";VIP;PetSlots;");
-- every perk reads it through here, so a perk only works while the store is switched on.
local RunService = game:GetService("RunService")

local Config = require(script.Parent.Parent.Config)

local MONEY = Config.Monetization

local Store = {}

local passes = {}
for _, pass in MONEY.Passes do
	passes[pass.Id] = pass
end
local products = {}
for _, product in MONEY.Products do
	products[product.Id] = product
end

-- True when the store is on: the real switch, or Studio's free preview (never in the live game)
function Store.Active(): boolean
	return MONEY.Enabled == true or (RunService:IsStudio() and MONEY.StudioPreview == true)
end

-- True when buying is free and fake (Studio preview with the real switch off)
function Store.IsPreview(): boolean
	return MONEY.Enabled ~= true and RunService:IsStudio() and MONEY.StudioPreview == true
end

function Store.Pass(id: string)
	return passes[id]
end

function Store.Product(id: string)
	return products[id]
end

-- True when this player owns this game pass (and the store is on)
function Store.Owns(player: Player, passId: string): boolean
	if not Store.Active() then
		return false
	end
	local text = player:GetAttribute("Passes")
	return type(text) == "string" and string.find(text, ";" .. passId .. ";", 1, true) ~= nil
end

-- Every owned pass's `field` multiplied together (1 with none)
local function product(player: Player, field: string): number
	local multiplier = 1
	for _, pass in MONEY.Passes do
		if pass[field] and Store.Owns(player, pass.Id) then
			multiplier *= pass[field]
		end
	end
	return multiplier
end

-- Coin multiplier from owned passes (2X COINS + 2X XP x2, VIP x1.25, together x2.5)
function Store.CoinMultiplier(player: Player): number
	return product(player, "Coins")
end

-- XP multiplier from owned passes
function Store.XpMultiplier(player: Player): number
	return product(player, "Xp")
end

-- The COIN BOOST bought with the cheap products: x1 + every buy (saved RobuxBoost, mirrored as an attribute).
-- Kept even if the store is switched off again: it was paid for.
function Store.BoostMultiplier(player: Player): number
	return 1 + math.max(0, tonumber(player:GetAttribute("RobuxBoost")) or 0)
end

-- Luck from owned passes (LUCKY x1.5, SUPER LUCKY x2, both x3)
function Store.Luck(player: Player): number
	return product(player, "Luck")
end

-- Eggs and crates opened at once (TRIPLE HATCH = 3)
function Store.HatchCount(player: Player): number
	local count = 1
	for _, pass in MONEY.Passes do
		if pass.Hatch and Store.Owns(player, pass.Id) then
			count = math.max(count, pass.Hatch)
		end
	end
	return count
end

-- Odds with luck: every rarity from Config.Monetization.LuckFrom up is multiplied by luck, then the total is scaled
-- back to what it was. odds = { Common = 60, Rare = 10, ... } (percent). Returns a new table (the same one at luck 1).
function Store.LuckyOdds(odds: { [string]: number }, luck: number): { [string]: number }
	if luck == 1 then
		return odds
	end
	local fromIndex = 1
	for index, rarity in Config.Rarities do
		if rarity.Name == MONEY.LuckFrom then
			fromIndex = index
		end
	end
	local total, boosted = 0, 0
	local result = {}
	for index, rarity in Config.Rarities do
		local chance = odds[rarity.Name] or 0
		total += chance
		result[rarity.Name] = if index >= fromIndex then chance * luck else chance
		boosted += result[rarity.Name]
	end
	if boosted <= 0 then
		return odds
	end
	for name, chance in result do
		result[name] = chance * total / boosted
	end
	return result
end

-- True when this player's rolling ball gets the VIP gold trail
function Store.HasTrail(player: Player): boolean
	for _, pass in MONEY.Passes do
		if pass.Trail and Store.Owns(player, pass.Id) then
			return true
		end
	end
	return false
end

-- Extra pet slots from owned passes
function Store.PetSlots(player: Player): number
	local extra = 0
	for _, pass in MONEY.Passes do
		if pass.PetSlots and Store.Owns(player, pass.Id) then
			extra += pass.PetSlots
		end
	end
	return extra
end

-- "R$ 399"
function Store.PriceText(robux: number): string
	return "R$ " .. tostring(robux)
end

return Store
