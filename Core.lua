local ADDON, ns = ...

local defaults = {
	locked = true,
	hideBlizzard = true,
	latency = true,
	icon = true,
	time = true,
	scale = 1,
	player = { show = true, width = 260, height = 22, default = { "CENTER", "CENTER", 0, -210 } },
	target = { show = true, width = 220, height = 18, default = { "CENTER", "CENTER", 0, -120 } },
}

ACore.New(ADDON, ns, { db = "ACastDB", defaults = defaults, profile = true })

ACore.Register({
	name = "ACast",
	title = "ACast",
	slash = "/acast",
	desc = "cast bars",
	toggle = function() ns.OpenMenu() end,
})
