local _, ns = ...
local UI = ns.UI
local IsSecret = ns.IsSecret

local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
local COLORS = {
	cast = { 1, 0.72, 0.1 },
	channel = { 0.3, 0.78, 0.5 },
	shield = { 0.62, 0.63, 0.68 },
	fail = { 0.86, 0.2, 0.2 },
	done = { 0.35, 0.86, 0.35 },
	idle = { 0.3, 0.32, 0.38 },
}
local LABELS = { player = "Player cast bar", target = "Target cast bar" }

local bars = {}
local byUnit = {}
ns.bars = bars
ns.unlocked = false

local function setColor(b, key)
	local c = COLORS[key]
	b.bar:SetColor(c[1], c[2], c[3], 1)
end

local function same(a, b)
	if a == nil or b == nil then return false end
	if IsSecret(a) or IsSecret(b) then return false end
	return a == b
end

local function duration(fn, unit)
	if not fn then return nil end
	local ok, d = pcall(fn, unit)
	if ok then return d end
	return nil
end

local function read(unit)
	local name, text, tex, startMs, endMs, _, castID, shield = UnitCastingInfo(unit)
	local info = { channel = false }
	if name then
		info.castID = castID
		info.duration = duration(UnitCastingDuration, unit)
	else
		name, text, tex, startMs, endMs, _, shield = UnitChannelInfo(unit)
		if not name then return nil end
		info.channel = true
		info.duration = duration(UnitChannelDuration, unit)
	end
	if IsSecret(name) or IsSecret(text) then
		info.text = name
	elseif type(text) == "string" and text ~= "" then
		info.text = text
	else
		info.text = name
	end
	info.icon = tex
	if IsSecret(shield) then
		info.shield = false
	else
		info.shield = shield and true or false
	end
	if startMs == nil or endMs == nil or IsSecret(startMs) or IsSecret(endMs) then
		info.secret = true
	else
		info.start = startMs / 1000
		info.finish = endMs / 1000
	end
	return info
end

local function idle(b)
	b.mode = nil
	b.fade = nil
	b.test = nil
	b.castID = nil
	b.succeeded = nil
	b.lagValue = nil
	b.lag:Hide()
	if ns.unlocked then
		b:SetAlpha(1)
		b.bar:SetMinMaxValues(0, 1)
		b.bar:SetValue(1)
		b.bar.left:SetText(LABELS[b.key])
		b.bar.right:SetText("")
		b.icon:SetTexture(QUESTION)
		setColor(b, "idle")
		b:Show()
	else
		b:Hide()
	end
end

local function netLag()
	if not GetNetStats then return 0 end
	local _, _, home, world = GetNetStats()
	local ms = world or home or 0
	if IsSecret(ms) or type(ms) ~= "number" then return 0 end
	return ms / 1000
end

local function showLag(b, total)
	b.lag:Hide()
	if b.key ~= "player" or not ns.db.latency or not b.lagValue or total <= 0 then return end
	local frac = b.lagValue / total
	if frac <= 0 then return end
	if frac > 1 then frac = 1 end
	local width = (ns.db.player.width - 2) * frac
	if width < 1 then return end
	b.lag:ClearAllPoints()
	if b.mode == "channel" then
		b.lag:SetPoint("TOPLEFT")
		b.lag:SetPoint("BOTTOMLEFT")
	else
		b.lag:SetPoint("TOPRIGHT")
		b.lag:SetPoint("BOTTOMRIGHT")
	end
	b.lag:SetWidth(width)
	b.lag:Show()
end

local function begin(b, info)
	local continuing = b.mode and not b.fade and same(b.castID, info.castID)
	b.mode = info.channel and "channel" or "cast"
	b.fade = nil
	b.test = info.test
	b.castID = info.castID
	b.secret = info.secret
	b.poll = 0
	if not continuing then b.succeeded = nil end
	b:SetAlpha(1)
	pcall(b.bar.left.SetText, b.bar.left, info.text)
	if not pcall(b.icon.SetTexture, b.icon, info.icon) then b.icon:SetTexture(QUESTION) end
	setColor(b, info.shield and "shield" or b.mode)
	if info.secret then
		b.bar.right:SetText("")
		b.lag:Hide()
		local timed = false
		if info.duration and b.bar.SetTimerDuration then
			timed = pcall(b.bar.SetTimerDuration, b.bar, info.duration, 0, info.channel and 1 or 0)
		end
		if not timed then
			b.bar:SetMinMaxValues(0, 1)
			b.bar:SetValue(1)
		end
	else
		b.start = info.start
		b.finish = info.finish
		local total = math.max(0.01, b.finish - b.start)
		b.bar:SetMinMaxValues(0, total)
		if b.key == "player" and not continuing then
			local t = GetTime()
			local lag = b.sent and (t - b.sent)
			if not lag or lag < 0 or lag > 1.5 then lag = netLag() end
			b.lagValue = lag
			b.sent = nil
		end
		showLag(b, total)
	end
	b:Show()
end

local function finish(b, key, text, hold)
	if b.test then key, text = "done", nil end
	b.mode = nil
	b.test = nil
	b.lag:Hide()
	setColor(b, key)
	if text then
		b.bar.left:SetText(text)
		b.bar.right:SetText("")
	end
	if key ~= "channel" then
		b.bar:SetMinMaxValues(0, 1)
		b.bar:SetValue(1)
	end
	b.fadeTime = hold
	b.fade = GetTime() + hold
end

local function refresh(b)
	if not ns.db[b.key].show then
		if b.mode or b.fade then idle(b) end
		return
	end
	local info = read(b.unit)
	if info then
		begin(b, info)
	elseif b.mode and not b.test then
		idle(b)
	end
end

local function onUpdate(b, elapsed)
	local t = GetTime()
	if b.fade then
		local left = b.fade - t
		if left <= 0 then
			idle(b)
		else
			local a = left / b.fadeTime
			b:SetAlpha(a > 1 and 1 or a)
		end
		return
	end
	if not b.mode then return end
	if b.secret then
		b.poll = b.poll + (elapsed or 0)
		if b.poll >= 0.15 then
			b.poll = 0
			if not read(b.unit) then finish(b, b.mode, nil, 0.25) end
		end
		return
	end
	local total = b.finish - b.start
	local left = b.finish - t
	if left < 0 then left = 0 end
	if b.mode == "cast" then
		local v = t - b.start
		if v > total then v = total end
		b.bar:SetValue(v)
	else
		b.bar:SetValue(left)
	end
	if ns.db.time then
		b.bar.right:SetFormattedText("%.1f / %.1f", left, total)
	else
		b.bar.right:SetText("")
	end
	if b.test then
		if t >= b.finish then finish(b, "done", nil, 0.4) end
	elseif b.mode == "channel" then
		if t >= b.finish then finish(b, "channel", nil, 0.2) end
	elseif t > b.finish + 0.6 then
		if read(b.unit) then refresh(b) else finish(b, "done", nil, 0.3) end
	end
end

local function layout(b)
	local db = ns.db[b.key]
	db.scale = ns.db.scale
	db.locked = ns.db.locked
	b:SetSize(db.width, db.height)
	b.icon:SetSize(db.height, db.height)
	b.icon:SetShown(ns.db.icon)
	b:EnableMouse(ns.unlocked)
	b:Restore()
end

local function create(key, unit)
	local name = key == "player" and "ACastPlayerBar" or "ACastTargetBar"
	local b = CreateFrame("Frame", name, UIParent)
	b.key = key
	b.unit = unit
	b:SetFrameStrata("MEDIUM")
	UI.Fill(b, { 0.04, 0.04, 0.05, 0.88 })
	UI.Border(b, { 0, 0, 0, 1 })
	b.bar = UI.Bar(b, 10)
	b.bar:SetPoint("TOPLEFT", 1, -1)
	b.bar:SetPoint("BOTTOMRIGHT", -1, 1)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetPoint("RIGHT", b, "LEFT", -3, 0)
	b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	b.lag = UI.Tex(b.bar, "OVERLAY", { 0.9, 0.15, 0.15, 0.5 })
	b.lag:Hide()
	UI.Movable(b, ns.db[key])
	b:RegisterForDrag("LeftButton")
	b:SetScript("OnDragStart", function(self) self:StartDrag() end)
	b:SetScript("OnDragStop", function(self) self:StopDrag() end)
	b:SetScript("OnUpdate", onUpdate)
	b:Hide()
	bars[key] = b
	byUnit[unit] = b
	layout(b)
	return b
end

local hooked = {}
local function hideDefault()
	if not ns.db.hideBlizzard then return end
	local names = { "PlayerCastingBarFrame", "CastingBarFrame" }
	if ns.db.target.show then names[#names + 1] = "TargetFrameSpellBar" end
	for _, name in ipairs(names) do
		local f = _G[name]
		if type(f) == "table" and f.UnregisterAllEvents and not hooked[name] then
			hooked[name] = true
			pcall(f.UnregisterAllEvents, f)
			pcall(f.Hide, f)
			if f.HookScript then
				pcall(f.HookScript, f, "OnShow", function(self)
					if ns.db.hideBlizzard then self:Hide() end
				end)
			end
		end
	end
end

function ns.Apply()
	for _, b in pairs(bars) do
		layout(b)
		if not ns.db[b.key].show or not (b.mode or b.fade) then idle(b) end
		if not ns.db[b.key].show then b:Hide() end
	end
	hideDefault()
end

function ns.SetLocked(locked)
	ns.db.locked = locked and true or false
	ns.unlocked = not ns.db.locked
	ns.Apply()
end

function ns.Reset()
	ns.db.player.pos = nil
	ns.db.target.pos = nil
	ns.db.scale = 1
	ns.Apply()
end

function ns.Test()
	local t = GetTime()
	for key, b in pairs(bars) do
		if ns.db[key].show then
			b.sent = t - 0.12
			begin(b, {
				test = true, channel = key == "target", text = "Test cast", icon = QUESTION,
				start = t, finish = t + (key == "target" and 2.5 or 3), shield = false,
			})
		end
	end
end

local function cast(event)
	return function(unit, castID)
		local b = byUnit[unit]
		if not b or b.test then return end
		if event == "refresh" then
			refresh(b)
		elseif event == "stop" then
			if b.mode ~= "cast" then return end
			if read(unit) then
				refresh(b)
			else
				finish(b, b.succeeded and "done" or "cast", nil, 0.3)
			end
		elseif event == "channelstop" then
			if b.mode == "channel" then finish(b, "channel", nil, 0.2) end
		elseif event == "succeeded" then
			if b.mode == "cast" and (b.secret or same(b.castID, castID)) then b.succeeded = true end
		elseif event == "failed" then
			if b.mode == "cast" and same(b.castID, castID) then
				finish(b, "fail", FAILED or "Failed", 0.8)
			end
		elseif event == "interrupted" then
			local known = same(b.castID, castID) or b.secret or IsSecret(castID) or castID == nil
			if (b.mode or b.fade) and known then
				finish(b, "fail", INTERRUPTED or "Interrupted", 0.9)
			end
		end
	end
end

ns:Listen("LOGIN", function()
	ns.unlocked = not ns.db.locked
	create("player", "player")
	create("target", "target")
	ns.Apply()

	local map = {
		UNIT_SPELLCAST_START = "refresh",
		UNIT_SPELLCAST_DELAYED = "refresh",
		UNIT_SPELLCAST_CHANNEL_START = "refresh",
		UNIT_SPELLCAST_CHANNEL_UPDATE = "refresh",
		UNIT_SPELLCAST_INTERRUPTIBLE = "refresh",
		UNIT_SPELLCAST_NOT_INTERRUPTIBLE = "refresh",
		UNIT_SPELLCAST_STOP = "stop",
		UNIT_SPELLCAST_CHANNEL_STOP = "channelstop",
		UNIT_SPELLCAST_SUCCEEDED = "succeeded",
		UNIT_SPELLCAST_FAILED = "failed",
		UNIT_SPELLCAST_INTERRUPTED = "interrupted",
	}
	for event, kind in pairs(map) do ns:On(event, cast(kind)) end

	ns:On("UNIT_SPELLCAST_SENT", function(unit)
		if unit == "player" then bars.player.sent = GetTime() end
	end)
	ns:On("PLAYER_TARGET_CHANGED", function()
		local b = bars.target
		if b.test then return end
		if b.mode or b.fade then idle(b) end
		refresh(b)
	end)
	ns:On("PLAYER_ENTERING_WORLD", function()
		hideDefault()
		for _, b in pairs(bars) do
			if not b.test then refresh(b) end
		end
	end)
end)
