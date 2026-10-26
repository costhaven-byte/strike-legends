-- Cosmetic looks both server and client use (Addendum 2 step 12b, Config.Cosmetics): trails, strike banners,
-- pin blasts and lane skins. Looks only: nothing here changes coins, XP or throws.
-- The server (CosmeticService) publishes what a player owns as the Player attribute Cosmetics (";FireTrail;IceLane;")
-- and what they wear as Look_<Kind> (Look_Trail = "FireTrail"), so every client can draw other players' looks too.
local Config = require(script.Parent.Parent.Config)
local Store = require(script.Parent.Store)

local LOOKS = Config.Cosmetics

local Cosmetics = {}

local items = {}
for _, item in LOOKS.Items do
	items[item.Id] = item
end
local kinds = {}
for _, kind in LOOKS.Kinds do
	kinds[kind.Id] = kind
end

function Cosmetics.Get(id: string)
	return items[id]
end

function Cosmetics.Kind(id: string)
	return kinds[id]
end

-- The Player attribute that holds the look worn for this kind
function Cosmetics.AttributeFor(kind: string): string
	return "Look_" .. kind
end

-- The Robux product that unlocks this look (a Config.Monetization.Products row), if it's a Robux look
function Cosmetics.Product(item)
	return item and item.Product and Store.Product(item.Product)
end

-- True when the player owns this look (VIP looks come with the VIP pass)
function Cosmetics.Owns(player: Player, id: string): boolean
	local item = items[id]
	if not item then
		return false
	end
	if item.Vip then
		return Store.HasTrail(player)
	end
	local text = player:GetAttribute("Cosmetics")
	return type(text) == "string" and string.find(text, ";" .. id .. ";", 1, true) ~= nil
end

-- The look this player wears for a kind (an item row), or nil. A VIP wearing no trail gets VIP GOLD.
function Cosmetics.Worn(player: Player, kind: string)
	if LOOKS.Enabled ~= true then
		return nil
	end
	local id = player:GetAttribute(Cosmetics.AttributeFor(kind))
	local item = type(id) == "string" and items[id]
	if item and item.Kind == kind and Cosmetics.Owns(player, item.Id) then
		return item
	end
	if kind == "Trail" and Store.HasTrail(player) then
		for _, row in LOOKS.Items do
			if row.Vip and row.Kind == "Trail" then
				return row
			end
		end
	end
	return nil
end

-- A look's colours as a ColorSequence (one colour = flat)
function Cosmetics.Sequence(item): ColorSequence
	local colors = item.Colors or { Color3.new(1, 1, 1) }
	if #colors == 1 then
		return ColorSequence.new(colors[1])
	end
	local points = {}
	for index, color in colors do
		table.insert(points, ColorSequenceKeypoint.new((index - 1) / (#colors - 1), color))
	end
	return ColorSequence.new(points)
end

return Cosmetics
