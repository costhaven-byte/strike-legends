-- Draws the leaderboard wall screens (built in Studio): every Model tagged "LeaderboardWall" (one per zone,
-- lobby = Workspace.Leaderboards), each with Screen.Board. Colours are set in Studio per zone; the wall's
-- "Accent" attribute (Color3) colours your own name in the top 10.
-- One panel per board in Board.Panels: Row1-3 are the crown rows, Row4-10 plain rows, You is pinned at the bottom.
-- The server shares the top scores in ReplicatedStorage.Leaderboards; this script adds your own live
-- score on top, so your row and position update right away instead of waiting for the next refresh.
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Currency = require(Shared.Modules.Currency)
local Calendar = require(Shared.Modules.Calendar)
local Rebirth = require(Shared.Modules.Rebirth)

local player = Players.LocalPlayer

local LB = Config.Leaderboards
local WALL_TAG = "LeaderboardWall"
local ME_COLOR = Color3.fromRGB(60, 230, 255)
local NAME_COLOR = Color3.fromRGB(255, 255, 255)

local LeaderboardController = {}

local lastUpdate = 0 -- server time of the newest board refresh

-- 1234567 -> "1,234,567"
-- Every number on screen uses the shared formatter (Config.Numbers)
local formatNumber = Currency.Format

-- Names go into rich text (the rank colour), so < > & in a name must not read as tags
local function escape(text: string): string
	return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local function headshot(userId: number): string
	return ("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(userId)
end

-- Your current score for a board, straight from your Player attributes
local function myScore(board): number
	if board.Weekly and player:GetAttribute("WeeklyCoinsWeek") ~= Calendar.Week(Workspace:GetServerTimeNow()) then
		return 0
	end
	return math.floor(player:GetAttribute(board.Stat) or 0)
end

local function setValue(holder: Frame, score: number?, showCoin: boolean)
	holder.Score.Text = if score then formatNumber(score) else ""
	holder.Coin.Visible = showCoin and score ~= nil
end

local function setupPanel(board, panel: Frame, data: Folder, meColor: Color3)
	local rows = panel:WaitForChild("Rows")
	local you = panel:WaitForChild("You")
	local loading = panel:WaitForChild("Loading") :: TextLabel
	local subtitle = panel:WaitForChild("Subtitle") :: TextLabel
	panel:WaitForChild("Title").Text = board.Title
	panel.Columns.ValueLabel.Text = board.Column

	local rowFrames = {}
	for i = 1, LB.ShowTop do
		rowFrames[i] = rows:WaitForChild("Row" .. i)
	end
	you.AvatarFrame.Avatar.Image = headshot(player.UserId)
	you.PlayerName.Text = player.DisplayName

	local function render()
		local raw = data:GetAttribute(board.Id)
		local ok, decoded = pcall(function()
			return if raw then HttpService:JSONDecode(raw) else nil
		end)
		if not ok or not decoded then
			loading.Visible = true
			loading.Text = if raw then "Leaderboard is down right now" else "Loading..."
			return
		end
		loading.Visible = false
		lastUpdate = math.max(lastUpdate, decoded.UpdatedAt or 0)

		-- Server list with your own entry swapped for your live score
		local entries = {}
		for _, entry in decoded.Entries do
			if entry[1] ~= player.UserId then
				table.insert(entries, { UserId = entry[1], Score = entry[2] })
			end
		end
		local score = myScore(board)
		if score > 0 then
			table.insert(entries, { UserId = player.UserId, Score = score, Me = true })
		end
		table.sort(entries, function(a, b)
			if a.Score ~= b.Score then
				return a.Score > b.Score
			end
			return a.Me == true -- ties: you first, so your own number never looks "behind"
		end)

		local myPlace = nil
		for i, entry in entries do
			if entry.Me then
				myPlace = i
				break
			end
		end
		-- The server only reads the top scores, so a place below the last of them isn't known exactly
		if myPlace and decoded.Full and myPlace > #decoded.Entries then
			myPlace = nil
		end

		for i, row in rowFrames do
			local entry = entries[i]
			-- Empty places keep their frame so the board never looks broken
			local shownName = if not entry
				then "-"
				elseif entry.Me then player.DisplayName
				else decoded.Names[tostring(entry.UserId)] or "Player"
			-- Addendum 6 2.4: the player's rebirth rank after the name, in the rank's colour
			local rebirths = if not entry
				then nil
				elseif entry.Me then player:GetAttribute("Rebirths") or 0
				else decoded.Rebirths and decoded.Rebirths[tostring(entry.UserId)]
			if rebirths ~= nil and Rebirth.CoreOn() then
				local rank = Rebirth.Rank(rebirths)
				row.PlayerName.RichText = true
				row.PlayerName.Text = ('%s <font color="#%s">· %s</font>'):format(
					escape(shownName),
					rank.Color:ToHex(),
					escape(rank.Name)
				)
			else
				row.PlayerName.RichText = true
				row.PlayerName.Text = escape(shownName)
			end
			row.PlayerName.TextColor3 = if entry and entry.Me then meColor else NAME_COLOR
			row.AvatarFrame.Avatar.Image = if entry then headshot(entry.UserId) else ""
			setValue(row.Value, entry and entry.Score, board.ShowCoin == true and i <= 3)
		end

		you.Rank.Text = if score <= 0
			then "-"
			elseif myPlace then "#" .. formatNumber(myPlace)
			else "#" .. LB.FetchSize .. "+"
		setValue(you.Value, score, board.ShowCoin == true)
	end

	local function renderSubtitle()
		if board.Weekly then
			local left = Calendar.SecondsUntilNextWeek(Workspace:GetServerTimeNow())
			subtitle.Text = "Resets in " .. Calendar.FormatCountdown(left)
		else
			subtitle.Text = "All time"
		end
	end

	data:GetAttributeChangedSignal(board.Id):Connect(render)
	player:GetAttributeChangedSignal(board.Stat):Connect(render)
	if board.Weekly then
		player:GetAttributeChangedSignal("WeeklyCoinsWeek"):Connect(render)
	end
	render()
	renderSubtitle()
	task.spawn(function()
		while true do
			task.wait(30)
			renderSubtitle()
		end
	end)
end

-- "Updated 12s ago" in the header
local function runLiveLabel(label: TextLabel)
	while true do
		if lastUpdate <= 0 then
			label.Text = "Loading..."
		else
			local ago = math.max(0, math.floor(Workspace:GetServerTimeNow() - lastUpdate))
			label.Text = if ago < 60 then ("Updated %ds ago"):format(ago) else ("Updated %dm ago"):format(ago // 60)
		end
		task.wait(1)
	end
end

local function setupWall(wall: Instance, data: Folder)
	local screen = wall:WaitForChild("Screen", 10)
	local surface = screen and screen:WaitForChild("Board", 10)
	if not surface then
		warn("[LeaderboardController] Missing Screen.Board in " .. wall:GetFullName())
		return
	end
	local accent = wall:GetAttribute("Accent")
	local meColor = if typeof(accent) == "Color3" then accent else ME_COLOR
	local panels = surface:WaitForChild("Panels")
	for _, board in LB.Boards do
		local panel = panels:WaitForChild(board.Id, 10)
		if panel then
			task.spawn(setupPanel, board, panel, data, meColor)
		else
			warn("[LeaderboardController] Missing leaderboard panel: " .. board.Id)
		end
	end
	task.spawn(runLiveLabel, surface.Header.Live.Updated)
end

function LeaderboardController:Start()
	local data = ReplicatedStorage:WaitForChild("Leaderboards") :: Folder
	local walls = CollectionService:GetTagged(WALL_TAG)
	if #walls == 0 then
		-- Older place copies: only the lobby wall, untagged
		table.insert(walls, Workspace:WaitForChild("Leaderboards"))
	end
	for _, wall in walls do
		task.spawn(setupWall, wall, data)
	end
	CollectionService:GetInstanceAddedSignal(WALL_TAG):Connect(function(wall)
		if wall:IsDescendantOf(Workspace) then
			task.spawn(setupWall, wall, data)
		end
	end)
end

return LeaderboardController
