-- Draws the leaderboard wall screen (Workspace.Leaderboards.Screen.Board, built in Studio).
-- One panel per board in Board.Panels: Row1-3 are the crown rows, Row4-10 plain rows, You is pinned at the bottom.
-- The server shares the top scores in ReplicatedStorage.Leaderboards; this script adds your own live
-- score on top, so your row and position update right away instead of waiting for the next refresh.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Calendar = require(Shared.Modules.Calendar)

local player = Players.LocalPlayer

local LB = Config.Leaderboards
local ME_COLOR = Color3.fromRGB(60, 230, 255)
local NAME_COLOR = Color3.fromRGB(255, 255, 255)

local LeaderboardController = {}

local lastUpdate = 0 -- server time of the newest board refresh

-- 1234567 -> "1,234,567"
local function formatNumber(n: number): string
	local text = tostring(math.floor(n))
	repeat
		local count
		text, count = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
	until count == 0
	return text
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

local function setupPanel(board, panel: Frame, data: Folder)
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
			loading.Text = if raw then "Leaderboard unavailable" else "Loading..."
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
			row.PlayerName.Text = if not entry
				then "-"
				elseif entry.Me then player.DisplayName
				else decoded.Names[tostring(entry.UserId)] or "Player"
			row.PlayerName.TextColor3 = if entry and entry.Me then ME_COLOR else NAME_COLOR
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

function LeaderboardController:Start()
	local data = ReplicatedStorage:WaitForChild("Leaderboards") :: Folder
	local screen = Workspace:WaitForChild("Leaderboards"):WaitForChild("Screen", 10)
	local surface = screen and screen:WaitForChild("Board", 10)
	if not surface then
		warn("[LeaderboardController] Missing Workspace.Leaderboards.Screen.Board")
		return
	end
	local panels = surface:WaitForChild("Panels")
	for _, board in LB.Boards do
		local panel = panels:WaitForChild(board.Id, 10)
		if panel then
			task.spawn(setupPanel, board, panel, data)
		else
			warn("[LeaderboardController] Missing leaderboard panel: " .. board.Id)
		end
	end
	task.spawn(runLiveLabel, surface.Header.Live.Updated)
end

return LeaderboardController
