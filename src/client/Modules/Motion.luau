-- Polish v2 D1 (ANIMATION_POLISH_PLAN.md rule 1): one motion module for the whole game.
-- Springs for anything you touch (buttons, cards, panels): a new target bends the motion already running, so a fast
-- tap never leaves something stuck half-way. Named presets so every screen moves the same way:
--   Snap   buttons going down (stiff, no bounce)
--   Pop    small rewards, buttons coming back up (gentle overshoot)
--   Window windows opening (a little overshoot)
--   Slam   big moments (heavy overshoot)
--   Shut   windows and popups closing (a short one-shot ease in)
--   Float  idle bobbing loops; Drift soft fades
-- It also remembers the last button you pressed, so a window grows out of that button and shrinks back into it.
-- Numbers live in Config.Motion.
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local MOTION = Config.Motion

local Motion = {}
Motion.Presets = MOTION.Presets

type State = {
	Spring: boolean,
	X: number,
	V: number,
	To: number,
	W: number, -- spring: angular frequency
	Z: number, -- spring: damping ratio
	From: number, -- tween
	T: number,
	Time: number,
	Style: Enum.EasingStyle,
	Dir: Enum.EasingDirection,
	Apply: (number) -> (),
	Done: (() -> ())?,
}

-- Everything moving right now: active[owner][name] = state (weak keys: a destroyed owner is dropped)
local active: { [any]: { [string]: State } } = setmetatable({}, { __mode = "k" }) :: any
local running = false

local STEP = 1 / 240 -- spring sub-step (stable for stiff springs at any frame rate)

local function step(dt: number)
	dt = math.min(dt, 0.1)
	local any = false
	for owner, states in active do
		for name, s in states do
			any = true
			if s.Spring then
				local left = dt
				while left > 0 do
					local h = math.min(STEP, left)
					local a = -s.W * s.W * (s.X - s.To) - 2 * s.Z * s.W * s.V
					s.V += a * h
					s.X += s.V * h
					left -= h
				end
				if math.abs(s.X - s.To) < 0.0005 and math.abs(s.V) < 0.005 then
					s.X = s.To
				end
			else
				s.T += dt
				local alpha = math.clamp(s.T / s.Time, 0, 1)
				s.X = s.From + (s.To - s.From) * TweenService:GetValue(alpha, s.Style, s.Dir)
			end
			local ok, err = pcall(s.Apply, s.X)
			local settled = (s.Spring and s.X == s.To) or (not s.Spring and s.T >= s.Time)
			if not ok then
				warn("[Motion]", err)
				states[name] = nil
			elseif settled then
				states[name] = nil
				if s.Done then
					task.spawn(s.Done)
				end
			end
		end
		if next(states) == nil then
			active[owner] = nil
		end
	end
	if not any then
		running = false
	end
end

local connection: RBXScriptConnection? = nil
local function wake()
	if not running then
		running = true
		if not connection then
			connection = RunService.RenderStepped:Connect(function(dt)
				if running then
					step(dt)
				end
			end)
		end
	end
end

local function preset(name: string | { [string]: any }): { [string]: any }
	if type(name) == "table" then
		return name
	end
	return MOTION.Presets[name] or MOTION.Presets.Pop
end

-- Drive a number from `from` to `to` with a preset; apply(value) runs every frame, done() once it settles.
-- owner + name identify it: a new Drive with the same owner + name takes over (a spring keeps its speed).
-- opts.Velocity = a starting kick (springs).
function Motion.Drive(
	owner: any,
	name: string,
	from: number?,
	to: number,
	presetName: string | { [string]: any },
	apply: (number) -> (),
	done: (() -> ())?,
	opts: { [string]: any }?
)
	local p = preset(presetName)
	local states = active[owner]
	if not states then
		states = {}
		active[owner] = states
	end
	local old = states[name]
	local x = if from ~= nil then from elseif old then old.X else to
	if p.Freq then
		local v = if from == nil and old and old.Spring then old.V else 0
		if opts and opts.Velocity then
			v += opts.Velocity
		end
		states[name] = {
			Spring = true,
			X = x,
			V = v,
			To = to,
			W = 2 * math.pi * p.Freq,
			Z = p.Damp or 1,
			Apply = apply,
			Done = done,
		} :: any
	else
		states[name] = {
			Spring = false,
			X = x,
			From = x,
			To = to,
			T = 0,
			Time = math.max(p.Time or 0.2, 0.001),
			Style = p.Style or Enum.EasingStyle.Quad,
			Dir = p.Dir or Enum.EasingDirection.Out,
			Apply = apply,
			Done = done,
		} :: any
	end
	wake()
end

-- Stop a drive without finishing it (its done() never runs)
function Motion.Stop(owner: any, name: string?)
	local states = active[owner]
	if states then
		if name then
			states[name] = nil
		else
			active[owner] = nil
		end
	end
end

-- Spring (or ease) one number property to a target: Motion.Spring(scale, "Scale", 1, "Pop")
-- (a spring already running on it keeps its speed; opts.From = start value, opts.Velocity = kick, opts.Done)
function Motion.Spring(object: Instance, prop: string, to: number, presetName: string?, opts: { [string]: any }?)
	local states = active[object]
	local running = states and states[prop]
	local from = if opts and opts.From then opts.From elseif running then nil else (object :: any)[prop]
	Motion.Drive(object, prop, from, to, presetName or "Pop", function(x)
		(object :: any)[prop] = x
	end, opts and opts.Done, opts)
end

-- Pop in from small: a red dot showing up, a badge, a new card (scale from -> overshoot -> 1)
function Motion.PopIn(scale: UIScale, from: number?, presetName: string?)
	scale.Scale = from or 0.2
	Motion.Spring(scale, "Scale", 1, presetName or "Pop", { From = from or 0.2 })
end

-- A quick bump: 1 -> to -> 1 on a spring (counters, a re-popping dot)
function Motion.Bump(scale: UIScale, kick: number?)
	Motion.Spring(scale, "Scale", 1, "Pop", { Velocity = kick or 2.5 })
end

-- Stagger: fn(item, i) for each item, gap seconds apart (Config.Motion.Stagger by default)
function Motion.Stagger(items: { any }, fn: (any, number) -> (), gap: number?, delay: number?)
	local g = gap or MOTION.Stagger
	for i, item in items do
		task.delay((delay or 0) + g * (i - 1), fn, item, i)
	end
end

-- ===== Float: an idle bob on a small curve (hint arrows, ready cards), all on one clock =====
local floats: { [GuiObject]: { Base: UDim2, Px: number, Period: number, Phase: number } } =
	setmetatable({}, { __mode = "k" }) :: any
local floatConnection: RBXScriptConnection? = nil
local function floatStep()
	local now = os.clock()
	local any = false
	for object, f in floats do
		any = true
		if object.Parent == nil then
			floats[object] = nil
			continue
		end
		local t = (now + f.Phase) / f.Period * 2 * math.pi
		-- up and down, with a little sideways sway so it moves on a curve, not a line
		local y = -f.Px * (0.5 - 0.5 * math.cos(t))
		local x = f.Px * MOTION.FloatSway * math.sin(t)
		object.Position = f.Base + UDim2.fromOffset(x, y)
	end
	if not any and floatConnection then
		floatConnection:Disconnect()
		floatConnection = nil
	end
end

-- Returns stop() (puts the object back where it was)
function Motion.Float(object: GuiObject, px: number?, period: number?): () -> ()
	local old = floats[object]
	local base = if old then old.Base else object.Position
	floats[object] = { Base = base, Px = px or 8, Period = period or 0.8, Phase = math.random() * 0.2 }
	if not floatConnection then
		floatConnection = RunService.RenderStepped:Connect(floatStep)
	end
	return function()
		if floats[object] then
			floats[object] = nil
			object.Position = base
		end
	end
end

-- ===== Windows grow out of the button you pressed and shrink back into it =====
local lastPress: { Button: GuiObject?, At: number } = { Button = nil, At = 0 }

-- Called on every button press (UiFxController)
function Motion.NotePress(button: GuiObject)
	lastPress.Button = button
	lastPress.At = os.clock()
end

local function layerOf(object: Instance): LayerCollector?
	return object:FindFirstAncestorWhichIsA("LayerCollector")
end

-- Screen-space shift of a ScreenGui's AbsolutePosition (guis that respect the top bar start under it)
local function shift(object: Instance): number
	local layer = layerOf(object)
	if layer and layer:IsA("ScreenGui") and not layer.IgnoreGuiInset then
		return GuiService:GetGuiInset().Y
	end
	return 0
end

local function centre(object: GuiObject): Vector2
	return object.AbsolutePosition + object.AbsoluteSize / 2 + Vector2.new(0, shift(object))
end

local function usable(button: GuiObject?): boolean
	if not button or not button.Parent or not button:IsDescendantOf(game) then
		return false
	end
	local node: Instance? = button
	while node and node:IsA("GuiObject") do
		if not node.Visible then
			return false
		end
		node = node.Parent
	end
	return node ~= nil and (not node:IsA("LayerCollector") or node.Enabled)
end

local rests: { [GuiObject]: UDim2 } = setmetatable({}, { __mode = "k" }) :: any
local origins: { [GuiObject]: GuiObject? } = setmetatable({}, { __mode = "k" }) :: any

type Geometry = { Centre: Vector2, Size: Vector2, Anchor: Vector2, K: number, Rest: UDim2 }

-- Where the window sits at rest, measured in screen pixels (scale must be 1 and the window at rest)
local function measure(holder: GuiObject, rest: UDim2): Geometry
	holder.Position = rest
	local c = holder.AbsolutePosition + holder.AbsoluteSize / 2 + Vector2.new(0, shift(holder))
	local size = holder.AbsoluteSize
	-- screen pixels per offset pixel (window shrunk to fit a phone, nested UIScales)
	local x0 = holder.AbsolutePosition.X
	holder.Position = rest + UDim2.fromOffset(100, 0)
	local k = (holder.AbsolutePosition.X - x0) / 100
	holder.Position = rest
	return { Centre = c, Size = size, Anchor = holder.AnchorPoint, K = if math.abs(k) > 0.01 then k else 1, Rest = rest }
end

-- Puts the window at progress p (0 = at the button, small; 1 = at rest, full size)
local function place(holder: GuiObject, scale: UIScale, geo: Geometry, from: Vector2?, s0: number, p: number)
	local s = s0 + (1 - s0) * p
	scale.Scale = math.max(s, 0.01)
	if from then
		local q = math.clamp(p, 0, 1)
		local c = from:Lerp(geo.Centre, q)
		-- UIScale shrinks toward the anchor point, so put the anchor where the centre lands at c
		local anchorAt = c - (Vector2.new(0.5, 0.5) - geo.Anchor) * geo.Size * s
		local anchorRest = geo.Centre - (Vector2.new(0.5, 0.5) - geo.Anchor) * geo.Size
		local d = (anchorAt - anchorRest) / geo.K
		holder.Position = geo.Rest + UDim2.fromOffset(d.X, d.Y)
	else
		-- in place: keep the centre still while the scale changes
		local d = -(Vector2.new(0.5, 0.5) - geo.Anchor) * geo.Size * (s - 1) / geo.K
		holder.Position = geo.Rest + UDim2.fromOffset(d.X, d.Y)
	end
end

-- Open: holder = the window frame (already parented), scale = its open UIScale. Makes it visible.
local function restOf(holder: GuiObject): UDim2
	-- mid-animation the window is off its spot: keep the saved one; at rest take the caller's (it may refit)
	local moving = active[holder] and active[holder].Window
	if not moving or not rests[holder] then
		rests[holder] = holder.Position
	end
	return rests[holder]
end

function Motion.WindowOpen(holder: GuiObject, scale: UIScale)
	local rest = restOf(holder)
	Motion.Stop(holder, "Window")
	scale.Scale = 1
	holder.Visible = true
	local button = if os.clock() - lastPress.At <= MOTION.PressMemory then lastPress.Button else nil
	if button and (button == holder or button:IsDescendantOf(holder) or not usable(button)) then
		button = nil
	end
	origins[holder] = button
	local geo = measure(holder, rest)
	local from = if button then centre(button) else nil -- (screen space, like the geometry)
	local s0 = if button then MOTION.FromButtonScale else MOTION.InPlaceScale
	place(holder, scale, geo, from, s0, 0)
	Motion.Drive(holder, "Window", 0, 1, "Window", function(p)
		place(holder, scale, geo, from, s0, p)
	end, function()
		holder.Position = rest
		scale.Scale = 1
	end)
end

-- Close: shrinks back into the button that opened it (or in place), then done() (hide it there)
function Motion.WindowClose(holder: GuiObject, scale: UIScale, done: (() -> ())?)
	local rest = restOf(holder)
	Motion.Stop(holder, "Window")
	local button = origins[holder]
	if not usable(button) then
		button = nil
	end
	local current = scale.Scale
	scale.Scale = 1
	local geo = measure(holder, rest)
	local from = if button then centre(button :: GuiObject) else nil
	local s0 = if button then MOTION.FromButtonScale else MOTION.CloseScale
	-- start from where it is now (a close during the open)
	local p0 = math.clamp((current - s0) / (1 - s0), 0, 1)
	place(holder, scale, geo, from, s0, p0)
	Motion.Drive(holder, "Window", p0, 0, "Shut", function(p)
		place(holder, scale, geo, from, s0, p)
	end, function()
		holder.Position = rest
		scale.Scale = 1
		if done then
			done()
		end
	end)
end

-- The rest position a window was first opened at (callers that move windows themselves)
function Motion.Rest(holder: GuiObject): UDim2?
	return rests[holder]
end

return Motion
