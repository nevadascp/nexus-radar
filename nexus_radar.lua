-- NEXUS Radar 1.0.0 | independent protocol 2 sender | GitHub Pages + your Firebase
--[[
     ~ qLocalization
     ~ automatic localization wrapper for Lua menu interfaces

     ~ author: qfun (qfun_g9s)
]]

local qLocalization = (function()
	local lib = {}

	local a = function(...)
		return ...
	end

	local state = {
		lang = Menu.Find("SettingsHidden", "", "", "", "Main", "Language"),
		instances = {},
	}

	local setters = {
		ToolTip = "tooltip",
	}

	local helpers
	do
		helpers = {
			resolve = a(function(root, path)
				for key in path:gmatch("[^.]+") do
					if type(root) ~= "table" then
						return
					end

					root = root[key]
				end

				return root
			end),

			is_object = a(function(value)
				return type(value) == "table" or type(value) == "userdata"
			end),

			has_method = a(function(object, name)
				return helpers.is_object(object) and type(object[name]) == "function"
			end),

			is_menu_object = a(function(value)
				return helpers.has_method(value, "Name") and helpers.has_method(value, "Type")
			end),

			is_list = a(function(value)
				if type(value) ~= "table" or #value == 0 then
					return false
				end

				for i = 1, #value do
					if type(value[i]) ~= "string" then
						return false
					end
				end

				return true
			end),

			is_indexed_list = a(function(object)
				return helpers.has_method(object, "List") and not helpers.has_method(object, "ListEnabled")
			end),
		}
	end

	function lib.new(translations)
		local languages = {}

		for i, name in ipairs(state.lang and state.lang:List() or {}) do
			local code = name:match("%a+")

			if code and translations[code] then
				languages[i - 1] = code
			end
		end

		local localization = {
			translations = translations,
			languages = languages,
			objects = {},
		}

		local methods
		do
			methods = {
				get_language = a(function(language_index)
					if language_index == nil and state.lang then
						language_index = state.lang:Get()
					end

					return localization.languages[language_index] or "en"
				end),

				localize = a(function(path, language_index)
					if type(path) ~= "string" then
						return path
					end

					local language = methods.get_language(language_index)

					return helpers.resolve(localization.translations[language], path)
						or helpers.resolve(localization.translations.en, path)
						or path
				end),

				has = a(function(path)
					if type(path) ~= "string" then
						return false
					end

					return helpers.resolve(localization.translations.en, path) ~= nil
						or helpers.resolve(localization.translations[methods.get_language()], path) ~= nil
				end),

				localize_items = a(function(items, language_index)
					local result, localized = {}, false

					for i = 1, #items do
						local value = items[i]

						if methods.has(value) then
							result[i] = methods.localize(value, language_index)
							localized = true
						else
							result[i] = value
						end
					end

					return result, localized
				end),

				apply = a(function(object, kind, path, language_index)
					if kind == "label" then
						object:ForceLocalization(methods.localize(path, language_index))
					elseif kind == "tooltip" then
						object:ToolTip(methods.localize(path, language_index))
					elseif kind == "items" then
						local value = object:Get()

						object:Update((methods.localize_items(path, language_index)))
						object:Set(value)
					end
				end),

				track = a(function(object, kind, path, apply_now)
					local record = localization.objects[object]

					if record == nil then
						record = {}
						localization.objects[object] = record
					end

					record[kind] = path

					if apply_now then
						methods.apply(object, kind, path)
					end
				end),

				register = a(function(object, path)
					if not methods.has(path) or not helpers.has_method(object, "ForceLocalization") then
						return
					end

					methods.track(object, "label", path, true)
				end),

				update = a(function(language_index)
					for object, record in pairs(localization.objects) do
						for kind, path in pairs(record) do
							methods.apply(object, kind, path, language_index)
						end
					end
				end),

				wrap = a(function(target, bind_self)
					if not helpers.is_object(target) then
						return target
					end

					local proxy

					proxy = setmetatable({}, {
						__index = function(_, key)
							local member = target[key]

							if type(member) ~= "function" then
								return member
							end

							return function(...)
								local args = table.pack(...)

								if bind_self and args[1] == proxy then
									table.remove(args, 1)
									args.n = args.n - 1
								end

								if key == "Switch" and args.n < 2 then
									args[2] = false
									args.n = 2
								end

								local name_path, item_paths

								if setters[key] then
									if methods.has(args[1]) then
										methods.track(target, setters[key], args[1], false)

										args[1] = methods.localize(args[1])
									end
								else
									local name_index = bind_self and 1 or args.n

									if methods.has(args[name_index]) then
										name_path = args[name_index]
									end

									local items_index

									if key == "Combo" then
										items_index = 2
									elseif key == "Update" and helpers.is_indexed_list(target) then
										items_index = 1
									end

									if items_index ~= nil and helpers.is_list(args[items_index]) then
										local items, localized = methods.localize_items(args[items_index])

										if localized then
											item_paths = args[items_index]
											args[items_index] = items
										end
									end
								end

								local results

								if bind_self then
									results = table.pack(member(target, table.unpack(args, 1, args.n)))
								else
									results = table.pack(member(table.unpack(args, 1, args.n)))
								end

								for i = 1, results.n do
									local result = results[i]

									if helpers.is_menu_object(result) then
										if name_path then
											methods.register(result, name_path)
										end

										if item_paths then
											methods.track(result, "items", item_paths, false)
											item_paths = nil
										end

										results[i] = methods.wrap(result, true)
									end
								end

								if item_paths then
									methods.track(target, "items", item_paths, false)
								end

								return table.unpack(results, 1, results.n)
							end
						end,

						__newindex = function(_, key, value)
							target[key] = value
						end,
					})

					return proxy
				end),
			}
		end

		state.instances[methods] = true

		return {
			GetLanguage = methods.get_language,

			Get = methods.localize,
			Localize = methods.localize,

			Update = methods.update,
			Register = methods.register,

			Wrap = methods.wrap,

			WrapLibrary = function(library)
				return methods.wrap(library, false)
			end,
		}
	end

	if state.lang then
		state.lang:SetCallback(function(this)
			local language_index = this:Get()

			for methods in pairs(state.instances) do
				methods.update(language_index)
			end
		end, true)
	else
		Log.Write("[qLocalization] Language widget not found, using English fallback")
	end

	return lib
end)()

local localization = qLocalization.new({
    en = {
        cr_group_main = "NEXUS Radar",
        cr_group_link = "Link for friends",
        cr_group_objects = "Map objects",
        cr_group_details = "Hero info",
        cr_group_events = "Event types",
        cr_group_extras = "Units and camps",
        cr_enabled = "Enable NEXUS Radar",
        cr_enabled_tip = "Turn it on, then press Start.\nStop closes the session and the old link.",
        cr_gear_extra = "Diagnostics",
        cr_debug = "Log unknown effects",
        cr_debug_tip = "Writes unknown particles and freezes\nto the AI bridge log",
        cr_pause_eco = "Save resources while the match is paused",
        cr_pause_eco_tip = "Reduce sampling and network traffic during a game pause",
        cr_prediction = "Estimate creep waves",
        cr_prediction_tip = "Predict unseen waves from known lanes.\nTurn off to show observations only and reduce work.",
        cr_status = "Status: %s",
        cr_start = "Start",
        cr_stop = "Stop",
        cr_link = "Link",
        cr_link_tip = "Full link for friends.\nCopy it whole from this field.",
        cr_get_link = "Show link",
        cr_get_link_tip = "Puts the current link\ninto the field above",
        cr_new_link = "New link",
        cr_new_link_tip = "Creates a new link,\nthe old one stops working",
        cr_heroes = "Heroes",
        cr_wards = "Wards",
        cr_wisdom = "Wisdom shrines",
        cr_buildings = "Towers",
        cr_roshan = "Roshan",
        cr_tormentors = "Tormentor",
        cr_runes = "Runes",
        cr_effects = "Send events",
        cr_layer_couriers = "Couriers",
        cr_layer_creeps = "Lane creeps",
        cr_layer_neutrals = "Neutral creeps",
        cr_layer_camps = "Neutral camps",
        cr_camps_tip = "Shows camps and seen neutrals.\nNo visible creeps does not mean farmed.",
        cr_items = "Items",
        cr_abilities = "Abilities and cooldowns",
        cr_modifiers = "Modifiers",
        cr_stats = "Player stats",
        cr_buybacks = "Buyback",
        cr_buybacks_tip = "Real cooldown from Player Resource.\nA ready buyback does not mean enough gold.",
        cr_teleports = "Teleports",
        cr_ultimates = "Ultimates",
        cr_active_items = "Active items",
        cr_casts = "Other abilities",
        cr_scans = "Scan",
        cr_profile = "Send rate",
        cr_profile_tip = "How often data goes to the site.\nLimited by collection rate and network response time.\nTURBO uses its own collection settings; one upload per game frame at most.",
        cr_profiles_eco = "Eco, 3 Hz",
        cr_profiles_balanced = "Balanced, 5 Hz",
        cr_profiles_fast = "Fast, 10 Hz",
        cr_profiles_smooth = "Smooth, 20 Hz",
        cr_profiles_turbo = "TURBO, maximum speed",
        cr_collect = "Collection rate",
        cr_collect_tip = "How often the game is read: heroes, details, map scan.\nEco costs the least FPS.\nTURBO manages collection automatically.",
        cr_collects_eco = "Eco, 3 Hz",
        cr_collects_balanced = "Balanced, 5 Hz",
        cr_collects_fast = "Fast, 10 Hz",
        cr_collects_smooth = "Smooth, 20 Hz",
        cr_performance_wait = "Load: no data yet",
        cr_performance = "Load: %.1f ms, %.1f KB, ping %.0f ms, %.1f Hz",
        cr_hitch = "Last freeze: %.1f s, script %.0f ms, %s",
        cr_st_off = "off",
        cr_st_stopping = "stopping",
        cr_st_stopped = "stopped",
        cr_st_closed = "stopped, link closed",
        cr_st_close_fail = "could not close the link: HTTP %d. Press Stop again",
        cr_st_enable_first = "turn NEXUS Radar on first",
        cr_st_no_json = "assets.JSON is not loaded",
        cr_st_creating = "creating a session",
        cr_st_connected = "connected, the link can be shared",
        cr_st_connect_fail = "connection error: HTTP %d",
        cr_st_start_first = "press Start first",
        cr_st_link_fail = "could not get the link: HTTP %d. Press Start",
        cr_st_collect_fail = "data collection error: %s",
        cr_st_encode_fail = "data encoding error: %s",
        cr_st_running = "radar is running",
        cr_st_waiting = "waiting for a match",
        cr_st_auth = "signing in",
        cr_st_auth_fail = "sign-in error: HTTP %d",
        cr_st_link_ready = "the link is in the Link field",
        cr_st_send_fail = "upload failed: HTTP %d, retrying",
        cr_link_hint = "Start, then send the link",
        cr_effects_tip = "Casts, teleports and scans on the map\nand in the event feed",
        cr_details_tip = "Needs the Heroes layer",
        cr_version = "Version 2.7.0-codex",
    },
    ru = {
        cr_group_main = "NEXUS Radar",
        cr_group_link = "Ссылка для друзей",
        cr_group_objects = "Объекты",
        cr_group_details = "Информация",
        cr_group_events = "Типы событий",
        cr_group_extras = "Юниты и кемпы",
        cr_enabled = "Включить NEXUS Radar",
        cr_enabled_tip = "После включения нажмите Start.\nStop закрывает сессию и старую ссылку.",
        cr_gear_extra = "Диагностика",
        cr_debug = "Неизвестные эффекты в журнал",
        cr_debug_tip = "Пишет неизвестные частицы и фризы\nв журнал моста",
        cr_pause_eco = "Экономить ресурсы на паузе матча",
        cr_pause_eco_tip = "Реже собирать и передавать данные, пока матч на паузе",
        cr_prediction = "Расчёт волн крипов",
        cr_prediction_tip = "Оценивать невидимые волны по известным линиям.\nОтключите для показа только наблюдений и снижения нагрузки.",
        cr_status = "Статус: %s",
        cr_start = "Start",
        cr_stop = "Stop",
        cr_link = "Ссылка",
        cr_link_tip = "Полная ссылка для друзей.\nКопируйте ее целиком из этого поля.",
        cr_get_link = "Показать ссылку",
        cr_get_link_tip = "Вставляет текущую ссылку\nв поле выше",
        cr_new_link = "Новая ссылка",
        cr_new_link_tip = "Создает новую ссылку,\nстарая перестает работать",
        cr_heroes = "Герои",
        cr_wards = "Варды",
        cr_wisdom = "Wisdom",
        cr_buildings = "Башни",
        cr_roshan = "Рошан",
        cr_tormentors = "Торментор",
        cr_runes = "Руны",
        cr_effects = "Передавать события",
        cr_layer_couriers = "Курьеры",
        cr_layer_creeps = "Линейные крипы",
        cr_layer_neutrals = "Лесные крипы",
        cr_layer_camps = "Нейтральные кемпы",
        cr_camps_tip = "Показывает кемпы и замеченных нейтралов.\nНет видимых крипов не значит зафармлен.",
        cr_items = "Предметы",
        cr_abilities = "Способности и перезарядки",
        cr_modifiers = "Модификаторы",
        cr_stats = "Статистика игроков",
        cr_buybacks = "Байбек",
        cr_buybacks_tip = "Настоящий КД из Player Resource.\nГотовый байбек не значит, что хватит золота.",
        cr_teleports = "Телепорты",
        cr_ultimates = "Ультимейты",
        cr_active_items = "Активные предметы",
        cr_casts = "Остальные способности",
        cr_scans = "Скан",
        cr_profile = "Частота передачи",
        cr_profile_tip = "Как часто данные уходят на сайт.\nОграничена частотой сбора и временем ответа сети.\nTURBO сам ускоряет сбор; не больше одной отправки за игровой кадр.",
        cr_profiles_eco = "Эконом, 3 Гц",
        cr_profiles_balanced = "Баланс, 5 Гц",
        cr_profiles_fast = "Быстрый, 10 Гц",
        cr_profiles_smooth = "Плавный, 20 Гц",
        cr_profiles_turbo = "TURBO, максимум скорости",
        cr_collect = "Частота сбора",
        cr_collect_tip = "Как часто читается игра: герои, детали, скан карты.\nЭконом бережет FPS.\nВ TURBO сбор настраивается автоматически.",
        cr_collects_eco = "Эконом, 3 Гц",
        cr_collects_balanced = "Баланс, 5 Гц",
        cr_collects_fast = "Быстрый, 10 Гц",
        cr_collects_smooth = "Плавный, 20 Гц",
        cr_performance_wait = "Нагрузка: нет данных",
        cr_performance = "Нагрузка: %.1f мс, %.1f КБ, пинг %.0f мс, %.1f Гц",
        cr_hitch = "Последний фриз: %.1f с, скрипт %.0f мс, %s",
        cr_st_off = "выключен",
        cr_st_stopping = "остановка",
        cr_st_stopped = "остановлен",
        cr_st_closed = "остановлен, ссылка закрыта",
        cr_st_close_fail = "не удалось закрыть ссылку: HTTP %d. Повторите Stop",
        cr_st_enable_first = "сначала включите NEXUS Radar",
        cr_st_no_json = "не загружен assets.JSON",
        cr_st_creating = "создание сессии",
        cr_st_connected = "подключен, можно поделиться ссылкой",
        cr_st_connect_fail = "ошибка подключения: HTTP %d",
        cr_st_start_first = "сначала нажмите Start",
        cr_st_link_fail = "не удалось получить ссылку: HTTP %d. Нажмите Start",
        cr_st_collect_fail = "ошибка сбора данных: %s",
        cr_st_encode_fail = "ошибка кодирования данных: %s",
        cr_st_running = "радар работает",
        cr_st_waiting = "ожидание матча",
        cr_st_auth = "вход",
        cr_st_auth_fail = "ошибка входа: HTTP %d",
        cr_st_link_ready = "ссылка в поле «Ссылка»",
        cr_st_send_fail = "ошибка передачи: HTTP %d, повтор",
        cr_link_hint = "Start и отправьте ссылку",
        cr_effects_tip = "Касты, телепорты и сканы на карте\nи в ленте событий",
        cr_details_tip = "Нужен слой «Герои»",
        cr_version = "Версия 2.7.0-codex",
    },
})

local UI = localization.WrapLibrary(Menu)
local L = localization.Get

local script = {}
script.VERSION = "2.7.0-codex"
local ui = {}
local JSON
local state = {
    ready = false, active = false, control = false, pendingStop = false,
    session = nil, url = "", nextSend = 0, nextSlow = 0, inflight = {}, sendSerial = 0, feedOwner = nil,
    requestId = 0, sentAt = 0, failures = 0, status = nil, statusKey = "cr_st_off",
    heroes = {}, events = {}, particles = {}, units = {}, wards = {}, runes = {}, camps = {},
    match = nil, requests = {}, details = {}, players = {}, nextPlayers = 0,
    casts = {}, castSerial = 0, roshan_units = {}, nextRoshan = 0, genericRates = {},
    flags = {}, nextFlags = 0, classifications = {}, scanJob = nil, detailsBudget = 1, detailCursor = 0,
    layersDirty = true, needFull = true, perf = {collect_ms = 0, encode_ms = 0, scan_ms = 0, bytes = 0},
    campDefs = {}, nextCampDefs = 0, activeEffects = {}, buybacks = {},
    roshanAttackers = {},
    wardMemory = {}, movers = {}, wisdom = {}, destroyed = {}, nextObjects = 0,
    innatePositions = {},
    teleports = {}, tormentor_units = {}, tormentorAttackers = {}, objectiveMotion = {},
    farming = {}, orbParticles = {}, unitMemory = {}, runeMemory = {}, laneMovers = {}, laneCursor = 0, laneList = {},
    courierCosts = {}, nextCouriers = 0, inventoryDirty = {}, courierMotion = {}, courierCursor = 0, courierSamples = {},
    itemKeys = setmetatable({}, {__mode = "k"}), loggedParticles = {},
    nameCache = {}, nameCacheSize = 0, soundNames = {}, partAt = {}, due = nil,
    fb = {waiters = {}}, sentParts = {}, feedQueue = {}, feedSeq = 0, feedKeys = {}, feedPrune = {}, mem = {}, resendAll = true,
    relay = {units = {}, wards = {}, runes = {}}, kills = {}, kills_by = {},
    upload = nil, afterUpload = nil, feedEpoch = 0,
    feedRevisions = setmetatable({}, {__mode = "k"}),
    infoCache = {}, sentInfo = {}, detailUrgent = {}, urgentBurst = 0,
}
local runtime = {}
local start, stop, copyLink
local observeCast
local observeItemEffect
local observeTeleport
local function invalidateDetails(id)
    local cached = state.details[tostring(id)]
    if cached then cached.wall = -math.huge end
    if cached then state.detailUrgent[tostring(id)] = true end
    if cached and runtime.sampleAt then runtime.sampleAt = 0 end
end
local function excludedSpell(name)
    return type(name) == "string" and (name:find("sun_strike", 1, true) or name:find("sunstrike", 1, true)
        or name:find("meat_hook", 1, true) or name:find("meathook", 1, true)
        or name:find("mirana_arrow", 1, true) or name:find("mirana_spell_arrow", 1, true)) ~= nil
end
-- Optional APIs may be absent. Actual call failures are reported only in
-- diagnostic mode, at most once per five seconds, without recursive logging.
local function reportError(context, err)
    local bridge = ai_bridge
    if not state.flags.debug or not bridge or type(bridge.mcp_log) ~= "function" then return end
    local now = os.clock()
    if now < (state.nextErrorLog or 0) then return end
    state.nextErrorLog = now + 5
    pcall(bridge.mcp_log, "warn", "[NEXUS Radar] " .. context, {error = tostring(err)})
end

local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, result = pcall(fn, ...)
    if ok then return result end
    reportError("API call", result)
    return nil
end

local function get(widget, fallback)
    local value = widget and call(widget.Get, widget)
    if value == nil then return fallback end
    return value
end

local function finite(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local MODES = {
    [0] = {rate = 3, hz = 3, pipeline = 1, detail = 1.2, slow = 2.5, scanMs = 0.0008, scanCount = 8, couriers = 1, creeps = 12, roshan = 1,
        parts = {info = 1.5, units = 1, wards = 2, runes = 1, camps = 4, objectives = 1}},
    [1] = {rate = 5, hz = 5, pipeline = 1, detail = 0.7, slow = 1.5, scanMs = 0.0012, scanCount = 12, couriers = 0.5, creeps = 24, roshan = 0.5,
        parts = {info = 0.8, units = 0.4, wards = 1, runes = 0.5, camps = 2, objectives = 0.5}},
    [2] = {rate = 10, hz = 10, pipeline = 1, detail = 0.4, slow = 1, scanMs = 0.0018, scanCount = 20, couriers = 0.25, creeps = 32, roshan = 0.25,
        parts = {info = 0.5, units = 0.2, wards = 0.5, runes = 0.3, camps = 1, objectives = 0.3}},
    [3] = {rate = 20, hz = 20, pipeline = 1, detail = 0.4, slow = 1, scanMs = 0.0018, scanCount = 20, couriers = 0.25, creeps = 32, roshan = 0.25,
        parts = {info = 0.5, units = 0.2, wards = 0.5, runes = 0.3, camps = 1, objectives = 0.3}},
    -- No fixed position-send interval. Heavy observations retain independent
    -- budgets; acknowledgements and game frames provide backpressure.
    [4] = {turbo = true, pipeline = 1, detail = 0.4, detailTick = 0.04, slow = 1,
        scanMs = 0.0012, scanCount = 12, couriers = 0.1, creeps = 32, creepPeriod = 0.05,
        objects = 0.1, roshan = 0.1,
        parts = {info = 0.2, units = 0.1, wards = 0.25, runes = 0.2, camps = 1, objectives = 0.2}},
}

local function mode()
    return state.mode or MODES[1]
end

local function refreshFlags(now)
    if now < state.nextFlags then return end
    for _, key in ipairs({"heroes", "illusions", "wards", "couriers", "creeps", "neutrals", "prediction", "pause_eco", "wisdom", "buildings", "roshan", "tormentors", "runes", "camps", "effects", "items", "abilities", "modifiers", "stats", "buybacks", "teleports", "ultimates", "active_items", "casts", "projectiles", "scans"}) do
        local enabled = get(ui[key], key ~= "illusions" and key ~= "projectiles")
        if state.flags[key] ~= enabled then state.layersDirty, state.needFull = true, true end
        state.flags[key] = enabled
    end
    state.flags.enabled = get(ui.enabled, false)
    state.flags.debug = get(ui.debug, false)
    local send, gather = get(ui.profile, 1), get(ui.collect, 1)
    if not state.mode or state.profile ~= send or state.gather ~= gather then
        local merged = {}
        local sendMode = MODES[send] or MODES[1]
        local gatherMode = sendMode.turbo and sendMode or (MODES[gather] or MODES[1])
        for key, value in pairs(gatherMode) do merged[key] = value end
        merged.rate, merged.parts, merged.pipeline = sendMode.rate, sendMode.parts, sendMode.pipeline
        merged.turbo = sendMode.turbo == true
        state.mode, state.profile, state.gather = merged, send, gather
        state.nextDetail, state.nextObjects, state.nextCreeps = 0, 0, 0
        state.partAt = {}
        runtime.sampleAt = 0
        if state.failures == 0 then state.nextSend = now end
    end
    state.nextFlags = now + 0.5
end

local function clock()
    return os.clock()
end

local function gameClock()
    return call(GameRules and GameRules.GetGameTime) or 0
end

local function setLabel(widget, text)
    if not widget or not text then return end
    if widget.ForceLocalization then call(widget.ForceLocalization, widget, text) else call(widget.Name, widget, text) end
end

local function show(key, ...)
    local text = string.format(L(key), ...)
    if state.status == text then return end
    state.status, state.statusKey = text, key
    state.statusText = string.format(L("cr_status"), text)
    setLabel(ui.status, state.statusText)
    if state.ready and ai_bridge and ai_bridge.mcp_log then
        call(ai_bridge.mcp_log, "info", "[NEXUS Radar] status", {key = key, args = {...}})
    end
end

local function resetMatch()
    state.heroes, state.events, state.particles = {}, {}, {}
    state.units, state.wards, state.runes = {}, {}, {}
    state.camps, state.campDefs, state.nextCampDefs = {}, {}, 0
    state.activeEffects, state.buybacks = {}, {}
    state.roshanAttackers = {}
    state.wardMemory, state.movers, state.wisdom, state.destroyed, state.nextObjects = {}, {}, {}, {}, 0
    state.innatePositions = {}
    state.orbParticles = {}
    state.teleports, state.tormentor_units, state.tormentorAttackers, state.objectiveMotion = {}, {}, {}, {}
    state.farming, state.kills, state.kills_by = {}, {}, {}
    state.unitMemory, state.runeMemory, state.laneMovers, state.laneCursor = {}, {}, {}, 0
    state.laneList = {}
    state.courierCosts, state.nextCouriers, state.inventoryDirty = {}, 0, {}
    state.courierMotion, state.courierCursor = {}, 0
    state.courierSamples = {}
    state.itemKeys = setmetatable({}, {__mode = "k"})
    state.details, state.players, state.nextPlayers = {}, {}, 0
    state.casts, state.genericRates, state.roshan_units, state.nextRoshan = {}, {}, {}, 0
    state.roshan = nil
    state.classifications, state.scanJob, state.layersDirty, state.needFull = {}, nil, true, true
    state.nextSlow, state.nextCourierSample, state.nextObjects = 0, 0, 0
    state.partAt, state.due = {}, nil
    state.soundNames, state.soundCount, state.loggedParticles = {}, 0, {}
    state.detailCursor, state.nextDetail = 0, 0
    state.heroList, state.nextHeroes, state.nextCreeps = nil, 0, 0
    state.teleportSampleAt, state.detailUrgent, state.urgentBurst = {}, {}, 0
    if runtime.reset then runtime.reset() end
    state.resendAll = true
    state.localTeam, state.roshanLastHp, state.roshanLastTime, state.roshanDamageUntil = nil, nil, nil, 0
end

local DETAILS = {"items", "abilities", "modifiers", "stats", "buybacks"}
local EVENTS = {"teleports", "ultimates", "active_items", "casts", "scans"}
local LAYERS = {"wards", "wisdom", "buildings", "roshan", "tormentors", "runes", "couriers", "creeps", "neutrals", "camps"}

local function refreshDisabled()
    local on = get(ui.enabled, false)
    for key, widget in pairs(ui) do
        if key ~= "enabled" and key ~= "status" and type(widget) == "table" and widget.Disabled then
            call(widget.Disabled, widget, not on)
        end
    end
    local heroes, effects = get(ui.heroes, true), get(ui.effects, true)
    for _, key in ipairs(DETAILS) do call(ui[key].Disabled, ui[key], not on or not heroes) end
    for _, key in ipairs(EVENTS) do call(ui[key].Disabled, ui[key], not on or not effects) end
    if ui.collect then call(ui.collect.Disabled, ui.collect, not on or get(ui.profile, 1) == 4) end
    state.nextFlags = 0
end

local function initMenu()
    if state.ready or not UI or not UI.Create then return end
    local root = UI.Create("Scripts", "Scripts", "NEXUS Radar")
    if not root then return end
    root:Icon("\u{f279}")
    local main = root:Create("Main")
    local data = root:Create("Data")
    local connection = main:Create("cr_group_main", Enum.GroupSide.Left)
    local link = main:Create("cr_group_link", Enum.GroupSide.Right)
    local objects = data:Create("cr_group_objects", Enum.GroupSide.Left)
    local extras = data:Create("cr_group_extras", Enum.GroupSide.Left)
    local details = data:Create("cr_group_details", Enum.GroupSide.Right)
    local events = data:Create("cr_group_events", Enum.GroupSide.Right)

    ui.enabled = connection:Switch("cr_enabled", false, "\u{f011}")
    ui.enabled:ToolTip("cr_enabled_tip")
    local gear = ui.enabled:Gear("cr_gear_extra")
    ui.debug = gear:Switch("cr_debug", false, "\u{f188}")
    ui.debug:ToolTip("cr_debug_tip")
    ui.pause_eco = gear:Switch("cr_pause_eco", true, "\u{f04c}")
    ui.pause_eco:ToolTip("cr_pause_eco_tip")
    ui.prediction = extras:Switch("cr_prediction", true, "\u{f201}")
    ui.prediction:ToolTip("cr_prediction_tip")
    ui.prediction:SetCallback(function() state.nextFlags = 0 end)
    ui.pause_eco:SetCallback(function() state.nextFlags = 0 end)
    ui.start = connection:Button("cr_start", function() start() end)
    ui.start:Icon("\u{f144}")
    ui.stop = connection:Button("cr_stop", function() stop() end)
    ui.stop:Icon("\u{f04d}")
    ui.status = connection:Label("cr_st_off", "\u{f05a}")
    ui.profile = connection:Combo("cr_profile", {"cr_profiles_eco", "cr_profiles_balanced", "cr_profiles_fast", "cr_profiles_smooth", "cr_profiles_turbo"}, 1)
    ui.profile:Icon("\u{f1de}")
    ui.profile:ToolTip("cr_profile_tip")
    ui.collect = connection:Combo("cr_collect", {"cr_collects_eco", "cr_collects_balanced", "cr_collects_fast", "cr_collects_smooth"}, 1)
    ui.collect:Icon("\u{f1c0}")
    ui.collect:ToolTip("cr_collect_tip")
    ui.performance = connection:Label("cr_performance_wait", "\u{f080}")
    connection:Label("cr_version", "\u{f02b}")

    ui.link = link:Input("cr_link", "", "\u{f0c1}")
    ui.link:ToolTip("cr_link_tip")
    ui.getLink = link:Button("cr_get_link", function() copyLink() end)
    ui.getLink:Icon("\u{f0c5}")
    ui.getLink:ToolTip("cr_get_link_tip")
    ui.newLink = link:Button("cr_new_link", function() start(true) end)
    ui.newLink:Icon("\u{f021}")
    ui.newLink:ToolTip("cr_new_link_tip")
    ui.linkHint = link:Label("cr_link_hint", "\u{f05a}")

    for _, row in ipairs({{"heroes", "\u{f007}"}, {"wards", "\u{f06e}"}, {"wisdom", "\u{f0eb}"},
        {"buildings", "\u{f447}"}, {"roshan", "\u{f6d5}"}, {"tormentors", "\u{f3ed}"}, {"runes", "\u{f219}"}}) do
        ui[row[1]] = objects:Switch("cr_" .. row[1], true, row[2])
    end
    for _, row in ipairs({{"couriers", "\u{f0d1}"}, {"creeps", "\u{f0c0}"}, {"neutrals", "\u{f1bb}"}, {"camps", "\u{f3c5}"}}) do
        ui[row[1]] = extras:Switch("cr_layer_" .. row[1], true, row[2])
    end
    local detailIcons = {items = "\u{f290}", abilities = "\u{f0e7}", modifiers = "\u{f1de}", stats = "\u{f080}", buybacks = "\u{f155}"}
    for _, key in ipairs(DETAILS) do
        ui[key] = details:Switch("cr_" .. key, true, detailIcons[key])
    end
    ui.effects = events:Switch("cr_effects", true, "\u{f0f3}")
    ui.effects:ToolTip("cr_effects_tip")
    local eventIcons = {teleports = "\u{f0ec}", ultimates = "\u{f005}", active_items = "\u{f135}", casts = "\u{f0d0}", scans = "\u{f002}"}
    for _, key in ipairs(EVENTS) do
        ui[key] = events:Switch("cr_" .. key, true, eventIcons[key])
    end
    ui.camps:ToolTip("cr_camps_tip")
    ui.items:ToolTip("cr_details_tip")
    ui.buybacks:ToolTip("cr_buybacks_tip")

    ui.heroes:SetCallback(refreshDisabled)
    ui.effects:SetCallback(refreshDisabled)
    ui.profile:SetCallback(refreshDisabled)
    ui.collect:SetCallback(function() state.nextFlags = 0 end)
    for _, list in ipairs({LAYERS, DETAILS, EVENTS}) do
        for _, key in ipairs(list) do ui[key]:SetCallback(function() state.nextFlags = 0 end) end
    end
    ui.enabled:SetCallback(function()
        state.flags.enabled = ui.enabled:Get()
        refreshDisabled()
        if not ui.enabled:Get() then stop() end
    end)
    refreshDisabled()
    state.ready = true
    state.status = nil
    show(state.statusKey or "cr_st_off")
end

local FB = {
    key = "AIzaSyDUkWV-TOYM00F3d6LC-JsI3z0QWaNKO7g",
    db = "https://nexus-radar-eb31b-default-rtdb.europe-west1.firebasedatabase.app",
    site = "https://nevadascp.github.io/nexus-radar/#s=",
    config = "nexus_radar",
}

-- Configuration store: validate before replacement, keep the last good copy,
-- and load the backup if the main JSON file was interrupted or corrupted.
local saved
local function savedPath()
    local dir = call(Engine and Engine.GetCheatDirectory)
    if type(dir) ~= "string" or dir == "" then return nil end
    return (dir:gsub("[\\/]+$", "")) .. "/configs/nexus_radar.json"
end

local function readConfig(path)
    if not path then return end
    local file = call(io and io.open, path, "rb")
    if not file then return end
    local raw = call(file.read, file, "*a")
    call(file.close, file)
    if type(raw) ~= "string" or #raw > 262144 then return end
    local decoded = call(JSON and JSON.decode, JSON, raw)
    if type(decoded) ~= "table" then return end
    for key, value in pairs(decoded) do
        if type(key) ~= "string" or type(value) ~= "string" then return end
    end
    return decoded
end

local function savedGet(key)
    if not saved then
        local path = savedPath()
        saved = readConfig(path) or readConfig(path and path .. ".bak") or {}
    end
    local value = saved[key]
    if type(value) ~= "string" then value = call(Config and Config.ReadString, FB.config, key, "") end
    if type(value) ~= "string" then value = "" end
    return value
end

local function writeConfig(path, body)
    local file = call(io and io.open, path, "wb")
    if not file then return false end
    local wrote = call(file.write, file, body)
    local closed = call(file.close, file)
    return wrote ~= nil and wrote ~= false and closed ~= nil and closed ~= false
end

local function flushSaved()
    if not state.saveDirty then return true end
    local path = savedPath()
    local encoded = call(JSON and JSON.encode, JSON, saved)
    local success = false
    if path and type(encoded) == "string" then
        if type(os.rename) == "function" and type(os.remove) == "function" then
            local temp, backup = path .. ".tmp", path .. ".bak"
            if writeConfig(temp, encoded) and readConfig(temp) then
                -- POSIX can atomically replace an existing target. Windows
                -- falls back to moving the validated old file to its backup.
                local prior = readConfig(path)
                if prior then
                    local oldBody = call(JSON.encode, JSON, prior)
                    if oldBody then writeConfig(backup, oldBody) end
                end
                success = call(os.rename, temp, path) == true
                if not success and prior then
                    call(os.remove, backup)
                    if call(os.rename, path, backup) then
                        success = call(os.rename, temp, path) == true
                        if not success then call(os.rename, backup, path) end
                    end
                elseif not success and not prior then
                    -- Invalid JSON is already unusable; the verified temp file
                    -- and the last valid .bak remain available for recovery.
                    call(os.remove, path)
                    success = call(os.rename, temp, path) == true
                end
            end
        else
            local prior = readConfig(path)
            local backedUp = not prior
            if prior then
                local body = call(JSON.encode, JSON, prior)
                backedUp = type(body) == "string" and writeConfig(path .. ".bak", body) and readConfig(path .. ".bak") ~= nil
            end
            if backedUp then success = writeConfig(path, encoded) end
        end
    end
    if success then state.saveDirty, state.saveAt = false, nil; return true end
    state.saveAt = clock() + 5
    reportError("config write", "could not safely save nexus_radar.json")
    return false
end

local function savedSet(key, value)
    savedGet(key)
    if saved[key] == value then return end
    saved[key], state.saveDirty = value, true
    if key == "session" or key == "refresh_token" then flushSaved()
    else state.saveAt = math.min(state.saveAt or math.huge, clock() + 1) end
end

local function wallClock()
    return call(os and os.time) or clock()
end

local function request(method, url, body, callback, headers)
    local pending = {deadline = clock() + 15, finished = false}
    local function finish(decoded, code, response)
        if pending.finished then return end
        pending.finished = true
        local ok, err = pcall(callback, decoded, code, response)
        if not ok then reportError("request callback", err) end
    end
    pending.finish = finish
    state.requests[#state.requests + 1] = pending
    local data = {headers = headers or {["Content-Type"] = "application/json"}, timeout = 12000}
    if body then data.data = body end
    local began = clock()
    local sent = call(HTTP and HTTP.Request, method, url, data, function(response)
        local replyBegan = clock()
        local code = tonumber(response and response.code) or 0
        local text = type(response) == "table" and type(response.response) == "string" and response.response or ""
        local decoded = text ~= "" and call(JSON and JSON.decode, JSON, text) or nil
        finish(decoded, code, response)
        state.perf.reply_ms = math.max(state.perf.reply_ms or 0, (clock() - replyBegan) * 1000)
    end)
    state.perf.http_ms = math.max(state.perf.http_ms or 0, (clock() - began) * 1000)
    if not sent then finish(nil, 0) end
end

local function dbRequest(method, sid, body, callback)
    local headers = {["Content-Type"] = "application/json", ["Connection"] = "keep-alive"}
    if method ~= "GET" then headers["X-HTTP-Method-Override"] = method end
    request(method == "GET" and "GET" or "POST", FB.db .. "/sessions/" .. sid .. ".json?" .. (method == "GET" and "" or "print=silent&") .. "auth=" .. (state.fb.token or ""),
        body, callback, headers)
end

local function formEncode(value)
    return (value:gsub("[^%w%-%._~]", function(char) return string.format("%%%02X", string.byte(char)) end))
end

local function authorize(callback)
    local fb = state.fb
    if fb.token and wallClock() < (fb.expires or 0) then callback(true); return end
    if clock() < (fb.retryAt or 0) then callback(false, fb.lastCode or 0); return end
    fb.waiters[#fb.waiters + 1] = callback
    if fb.authorizing then return end
    fb.authorizing = true
    local function done(ok, code)
        fb.authorizing = false
        if ok then
            fb.failures, fb.retryAt, fb.lastCode = 0, nil, nil
        else
            fb.failures = math.min((fb.failures or 0) + 1, 5)
            fb.retryAt, fb.lastCode = clock() + math.min(30, 2 ^ fb.failures), code
        end
        local waiters = fb.waiters
        fb.waiters = {}
        for _, waiter in ipairs(waiters) do
            local called, err = pcall(waiter, ok, code)
            if not called then reportError("auth callback", err) end
        end
    end
    local function accept(token, refresh, expires, uid)
        if type(token) ~= "string" or token == "" or type(uid) ~= "string" or uid == "" then return false end
        fb.token, fb.uid = token, uid
        fb.expires = wallClock() + math.max(60, (tonumber(expires) or 3600) - 300)
        if type(refresh) == "string" and refresh ~= fb.refresh then
            fb.refresh = refresh
            savedSet("refresh_token", refresh)
        end
        return true
    end
    local refresh = fb.refresh or savedGet("refresh_token")
    if refresh == "" then done(false, 403); return end
    request("POST", "https://securetoken.googleapis.com/v1/token?key=" .. FB.key, "grant_type=refresh_token&refresh_token=" .. formEncode(refresh), function(data, code)
        if code == 200 and type(data) == "table" and accept(data.id_token, data.refresh_token, data.expires_in, data.user_id) then
            done(true, code)
        elseif code == 400 then
            -- Preserve the credential for diagnosis; an invalid pairing must
            -- not silently replace the identity authorized by database rules.
            done(false, code)
        else done(false, code) end
    end, {["Content-Type"] = "application/x-www-form-urlencoded"})
end

-- SHA-256 is used once per link. The entropy comes from Firebase's secret
-- refresh credential, never math.random alone; no credential enters the URL.
local function sha256(message)
    local K = {0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
        0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
        0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
        0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
        0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
        0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
        0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
        0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2}
    local function rotr(x,n) return ((x >> n) | (x << (32-n))) & 0xffffffff end
    local function be(n) return string.char((n>>24)&255,(n>>16)&255,(n>>8)&255,n&255) end
    local len=#message
    message=message..string.char(128)..string.rep(string.char(0),(55-len)%64)..be(math.floor(len/0x20000000))..be((len*8)&0xffffffff)
    local H={0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19}
    for off=1,#message,64 do
        local w={}
        for i=0,15 do local a,b,c,d=message:byte(off+i*4,off+i*4+3);w[i]=(a<<24)|(b<<16)|(c<<8)|d end
        for i=16,63 do local a,b=w[i-15],w[i-2];local x=rotr(a,7)~rotr(a,18)~(a>>3);local y=rotr(b,17)~rotr(b,19)~(b>>10);w[i]=(w[i-16]+x+w[i-7]+y)&0xffffffff end
        local a,b,c,d,e,f,g,h=table.unpack(H)
        for i=0,63 do local t1=(h+(rotr(e,6)~rotr(e,11)~rotr(e,25))+((e&f)~((~e)&g))+K[i+1]+w[i])&0xffffffff
            local t2=((rotr(a,2)~rotr(a,13)~rotr(a,22))+((a&b)~(a&c)~(b&c)))&0xffffffff
            h,g,f,e,d,c,b,a=g,f,e,(d+t1)&0xffffffff,c,b,a,(t1+t2)&0xffffffff end
        for i,v in ipairs({a,b,c,d,e,f,g,h}) do H[i]=(H[i]+v)&0xffffffff end
    end
    local out={};for i,v in ipairs(H) do out[i]=string.format("%08x",v) end;return table.concat(out)
end
local function newSessionId()
    local secret=state.fb.refresh or savedGet("refresh_token")
    assert(type(secret)=="string" and #secret>=32,"NEXUS: sender pairing credential is missing")
    state.linkNonce=(state.linkNonce or 0)+1
    return sha256(secret.."|"..tostring(state.fb.uid).."|"..tostring(wallClock()).."|"..tostring(clock()).."|"..tostring(state.linkNonce).."|"..tostring(math.random())):sub(1,32)
end

-- Control actions wait for the current upload before deleting/reusing a
-- session. Clearing local callbacks alone would not stop an HTTP write.
local function afterUpload(callback)
    if state.upload then state.afterUpload = callback else callback() end
end

local function finishControl()
    state.control = false
    if state.pendingStop or not get(ui.enabled, false) then
        state.pendingStop = false
        stop()
    end
end

stop = function()
    state.active, state.retryAt = false, nil
    state.requestId = state.requestId + 1
    state.inflight, state.feedOwner = {}, nil
    if state.control then state.pendingStop = true; show("cr_st_stopping"); return end
    if not state.session then
        local persisted=savedGet("session")
        if #persisted==32 and persisted:match("^[a-f0-9]+$") then state.session=persisted end
    end
    if not state.session then show("cr_st_stopped"); return end
    state.control = true
    afterUpload(function()
        authorize(function(ok, code)
            if not ok then state.control = false; show("cr_st_close_fail", code or 0); return end
            dbRequest("DELETE", state.session, nil, function(_, result)
                state.control, state.pendingStop = false, false
                if result >= 200 and result < 300 then
                    state.session, state.url = nil, ""
                    savedSet("session", "")
                    if ui.link then ui.link:Set("") end
                    show("cr_st_closed")
                else
                    show("cr_st_close_fail", result)
                end
            end)
        end)
    end)
end

start = function(rotate)
    if state.control then return end
    if not get(ui.enabled, false) then show("cr_st_enable_first"); return end
    if not JSON then show("cr_st_no_json"); return end
    state.active, state.control = false, true
    state.inflight, state.feedOwner = {}, nil
    state.requestId = state.requestId + 1
    show("cr_st_auth")
    afterUpload(function()
        authorize(function(ok, code)
            if not ok then
                show("cr_st_auth_fail", code or 0)
                state.retryAt = clock() + 5
                finishControl()
                return
            end
            local old = state.session or savedGet("session")
            if not old:match("^[a-f0-9]+$") or #old ~= 32 then old = "" end
            local function create(sid, retry, sequence)
                show("cr_st_creating")
                local body = string.format('{"meta/owner":%s,"meta/updated":{".sv":"timestamp"},"meta/protocol":2,"meta/active":true}',
                    call(JSON.encode, JSON, state.fb.uid) or '""')
                dbRequest("PATCH", sid, body, function(_, result)
                    if result >= 200 and result < 300 then
                        if not state.active then resetMatch() end
                        state.sequence = sequence or 0
                        state.session, state.url = sid, FB.site .. sid
                        savedSet("session", sid)
                        if ui.link then ui.link:Set(state.url) end
                        state.active, state.failures, state.nextSend = true, 0, 0
                        state.perf.actualRate, state.perf.uploads, state.perf.rateAt = 0, 0, clock()
                        state.needFull, state.layersDirty, state.nextFlags = true, true, 0
                        state.sentParts, state.feedQueue, state.feedSeq, state.mem = {}, {}, 0, {}
                        state.sentInfo = {}
                        state.feedBase, state.feedKeys, state.feedPrune = math.floor(wallClock()), {}, {}
                        state.feedEpoch = state.feedEpoch + 1
                        state.feedRevisions = setmetatable({}, {__mode = "k"})
                        state.clearFeed = true
                        state.resendAll = true
                        state.relayMatch = sid == old and savedGet("match") or nil
                        refreshFlags(clock())
                        show("cr_st_connected")
                        finishControl()
                    elseif retry and (result == 401 or result == 403) then
                        create(newSessionId(), false)
                    else
                        show("cr_st_connect_fail", result)
                        if result == 0 or result >= 500 then state.retryAt = clock() + 5 end
                        finishControl()
                    end
                end)
            end
            if rotate and old ~= "" then
                show("cr_st_stopping")
                dbRequest("DELETE", old, nil, function(_, result)
                    if result < 200 or result >= 300 then
                        show("cr_st_close_fail", result)
                        finishControl()
                        return
                    end
                    state.session, state.url = nil, ""
                    savedSet("session", "")
                    if ui.link then ui.link:Set("") end
                    create(newSessionId(), false)
                end)
            else
                if old == "" then create(newSessionId(), false)
                else
                    -- Resume above the server's acknowledged sequence. A late timed-out
                    -- upload cannot replace a newer packet or recreate a stopped room.
                    dbRequest("GET", old, nil, function(data, result)
                        if result == 200 and type(data)=="table" and type(data.meta)=="table"
                            and data.meta.owner==state.fb.uid and data.meta.active==true and data.meta.protocol==2 then
                            local seq=type(data.live)=="table" and tonumber(data.live.seq) or 0
                            create(old, false, finite(seq) and math.floor(seq) or 0)
                        elseif result==200 or result==401 or result==403 or result==404 then create(newSessionId(), false)
                        else show("cr_st_connect_fail",result);finishControl() end
                    end)
                end
            end
        end)
    end)
end

copyLink = function()
    if not state.session then show("cr_st_start_first"); return end
    if ui.link then ui.link:Set(state.url) end
    show("cr_st_link_ready")
end

local function pos(vector)
    if not vector then return nil end
    local x, y = vector.x, vector.y
    if type(x) ~= "number" or type(y) ~= "number" or x ~= x or y ~= y
        or x == math.huge or x == -math.huge or y == math.huge or y == -math.huge then return nil end
    return {x = x, y = y}
end

local function forgetEntity(id)
    local key, prefix = tostring(id), tostring(id) .. ":"
    local cached = state.heroes[id]
    local hero = cached and cached.identity and tostring(cached.identity.name or ""):find("npc_dota_hero_", 1, true) == 1
    state.classifications[id], state.destroyed[id], state.heroes[id] = nil, nil, nil
    state.casts[key] = nil
    for _, name in ipairs({"infoCache", "detailUrgent", "details", "wardMemory", "unitMemory", "runeMemory", "wisdom", "movers", "laneMovers",
        "courierMotion", "inventoryDirty", "innatePositions", "teleports", "objectiveMotion", "farming", "roshanAttackers", "genericRates"}) do
        state[name][key] = nil
    end
    state.courierSamples[id] = nil
    for entry in pairs(state.activeEffects) do if entry:sub(1, #prefix) == prefix then state.activeEffects[entry] = nil end end
    for index, orb in pairs(state.orbParticles) do if orb.owner_id == key then state.orbParticles[index] = nil end end
    for entry, attacker in pairs(state.tormentorAttackers) do
        if attacker.id == key or attacker.target_id == key then state.tormentorAttackers[entry] = nil end
    end
    for entry, event in pairs(state.events) do
        if event.owner_id == key then state.events[entry], state.particles[entry] = nil, nil end
    end
    for _, name in ipairs({"units", "wards", "runes"}) do
        for index = #state[name], 1, -1 do if state[name][index].id == key then table.remove(state[name], index) end end
    end
    for _, name in ipairs({"roshan_units", "tormentor_units"}) do
        for index = #state[name], 1, -1 do if state[name][index].row.id == key then table.remove(state[name], index) end end
    end
    if state.scanJob then for _, name in ipairs({"units", "wards"}) do
        for index = #state.scanJob[name], 1, -1 do if state.scanJob[name][index].id == key then table.remove(state.scanJob[name], index) end end
    end end
    state.layersDirty = true
    if hero then state.needFull = true end
end

local function base(unit, kind, now)
    local id = call(Entity.GetIndex, unit)
    if not id then return nil end
    local hidden = call(Entity.IsDormant, unit) == true
    local previous = state.heroes[id]
    if previous and previous.entity and previous.entity ~= unit then
        local retired = previous.entity
        forgetEntity(id)
        state.destroyed[id] = retired
        previous = nil
    end
    local isWard = kind == "observer" or kind == "sentry"
    local isMapObject = isWard or kind == "building" or kind == "roshan" or kind == "tormentor" or kind == "wisdom"
    local location = (not hidden or isMapObject) and pos(call(Entity.GetAbsOrigin, unit)) or nil
    local source = "visible"
    local maphack
    if hidden then
        maphack = kind == "hero" and pos(call(Hero and Hero.GetLastMaphackPos, unit)) or nil
        source = maphack and "maphack_last" or (isMapObject and location and "entity_dormant") or (previous and previous.source == "maphack_last" and "maphack_last" or "last_seen")
        location = maphack or location or previous
    end
    local trace = kind == "hero" and state.innatePositions[tostring(id)]
    if trace and now - trace.observed_at > 3 then state.innatePositions[tostring(id)], trace = nil, nil end
    local maphackTime = maphack and (previous and previous.maphack_x == maphack.x and previous.maphack_y == maphack.y
        and previous.maphack_observed_at or now)
    if hidden and trace and now >= trace.observed_at and now - trace.observed_at <= 3
        and (not maphack or trace.observed_at > maphackTime) then
        location, source = trace, "innate_trace"
    end
    local cached = previous or {}
    cached.entity = unit
    if not cached.identity or clock() >= (cached.nextIdentity or 0) then
        cached.identity = {name = call(NPC.GetUnitName, unit) or kind, team = call(Entity.GetTeamNum, unit),
            max_hp = call(Entity.GetMaxHealth, unit), max_mana = kind == "hero" and call(NPC.GetMaxMana, unit) or nil,
            level = kind == "hero" and call(NPC.GetCurrentLevel, unit) or nil,
            player_id = kind == "hero" and call(Hero.GetPlayerID, unit) or nil}
        cached.nextIdentity = clock() + (kind == "hero" and 1 or 10)
    end
    local identity = cached.identity
    local row = {id = tostring(id), name = identity.name, kind = kind,
        team = identity.team, alive = call(Entity.IsAlive, unit),
        visible = not hidden, source = source, x = location and location.x, y = location and location.y,
        hp = call(Entity.GetHealth, unit), max_hp = identity.max_hp,
        mana = kind == "hero" and call(NPC.GetMana, unit) or nil, max_mana = identity.max_mana,
        level = identity.level, player_id = identity.player_id, heading = false}
    if not hidden then
        cached.x, cached.y, cached.last_seen = row.x, row.y, now
        cached.position_observed_at = now
        cached.maphack_x, cached.maphack_y, cached.maphack_observed_at = nil, nil, nil
    elseif maphack then
        -- The API supplies cached coordinates, not their original timestamp.
        -- Date only the first/new coordinate observed locally; repeated reads
        -- must not make an old MapHack observation look like fresh visibility.
        if cached.maphack_x ~= maphack.x or cached.maphack_y ~= maphack.y then
            cached.maphack_observed_at = now
        end
        cached.maphack_x, cached.maphack_y = maphack.x, maphack.y
        cached.x, cached.y = maphack.x, maphack.y
        cached.position_observed_at = cached.maphack_observed_at
    elseif isMapObject and location and (cached.x ~= row.x or cached.y ~= row.y) then
        cached.x, cached.y, cached.position_observed_at = row.x, row.y, now
    end
    cached.source = source
    state.heroes[id] = cached
    row.last_seen = cached.last_seen
    row.position_observed_at = cached.position_observed_at
    row.maphack_observed_at = hidden and cached.maphack_observed_at or nil
    row.position_timestamp_source = source == "maphack_last" and "local_observation" or "visibility"
    row.data_stale = hidden
    if not hidden then
        cached.hp, cached.mana, cached.alive = row.hp, row.mana, row.alive
    else
        if finite(cached.hp) then row.hp = cached.hp end
        if finite(cached.mana) then row.mana = cached.mana end
        if (isWard or kind == "neutral" or kind == "building") and cached.alive ~= nil then row.alive = cached.alive end
    end
    if source == "innate_trace" then
        row.position_observed_at, row.innate_observed_at = trace.observed_at, trace.observed_at
        row.position_timestamp_source = "particle_cp0"
    end
    return row
end

local itemModifiers = {
    modifier_black_king_bar_immune = "item_black_king_bar",
    modifier_item_aeon_disk_buff = "item_aeon_disk",
    modifier_item_mask_of_madness_berserk = "item_mask_of_madness",
    modifier_mask_of_madness_berserk = "item_mask_of_madness",
    modifier_item_satanic_unholy = "item_satanic",
    modifier_item_blade_mail_reflect = "item_blade_mail",
    modifier_item_lotus_orb_active = "item_lotus_orb",
    modifier_item_phase_boots_active = "item_phase_boots",
}
local orbModifiers = {modifier_invoker_quas_instance = "quas",
    modifier_invoker_wex_instance = "wex", modifier_invoker_exort_instance = "exort"}

local function inventoryKey(item)
    -- The item entity follows a delivery between hero/courier slots. Names
    -- cannot identify it: one player can own several identical items.
    local id = call(Entity.GetIndex, item)
    return id ~= nil and "item:" .. tostring(id) or tostring(item)
end

local function abilityData(ability, slot, owner, now, hidden, previous, ownerIndex)
    local name = call(Ability.GetName, ability)
    local same = previous and previous.name == name
    local ultimate, passive
    if same then ultimate, passive = previous.ultimate, previous.passive end
    if ultimate == nil then ultimate = call(Ability.IsUltimate, ability) end
    if passive == nil then passive = call(Ability.IsPassive, ability) end
    local info = {slot = slot, name = name, level = call(Ability.GetLevel, ability),
        cooldown = call(Ability.GetCooldown, ability), charges = call(Ability.GetCurrentCharges, ability),
        ultimate = ultimate, passive = passive,
        hidden = call(Ability.IsHidden, ability),
        observed_at = now, source = "ability_api", stale = hidden == true}
    if not finite(info.cooldown) or info.cooldown < 0 then info.cooldown = nil end
    local since = call(Ability.SecondsSinceLastUse, ability)
    if finite(since) and since >= 0 and since <= now and info.cooldown and info.cooldown > 0 then
        info.used_at, info.usage_source = now - since, "ability_last_use"
    end
    if observeCast then observeCast(owner, ability, "ability_sample", now, info, nil, ownerIndex) end
    local id = ownerIndex or call(Entity.GetIndex, owner)
    local effect = id and state.activeEffects[tostring(id) .. ":" .. tostring(info.name)]
    if effect and effect.active_until > now then
        info.active_until, info.active_source = effect.active_until, "modifier"
        info.active_observed_at = effect.observed_at
        if not info.used_at and finite(effect.used_at) then
            info.used_at, info.usage_source = effect.used_at, effect.usage_source
        end
    end
    return info
end

local function heroDetails(unit, row, now, refresh)
    local identity = state.heroes[tonumber(row.id)]
    local respawn
    if row.alive == false then
        if identity and clock() < (identity.nextRespawn or 0) then respawn = identity.respawn
        else
            respawn = call(Hero.GetRespawnTime, unit)
            if identity then identity.respawn, identity.nextRespawn = respawn, clock() + 0.25 end
        end
    end
    row.respawn = finite(respawn) and math.max(0, respawn - now) or 0
    local signature = tostring(state.flags.items) .. tostring(state.flags.abilities)
        .. tostring(state.flags.modifiers) .. tostring(state.flags.stats) .. tostring(state.flags.buybacks)
    local cached = state.details[row.id]
    local detailInterval = mode().detail
    if not refresh or (cached and clock() - cached.wall < detailInterval and signature == cached.signature) then
        if state.needFull then
            if cached then
                row.abilities, row.items, row.modifiers, row.stats, row.buyback, row.details_at, row.orbs = cached.abilities, cached.items, cached.modifiers, cached.stats, cached.buyback, cached.game, cached.orbs
                row.inventory_state, row.items_observed_at = cached.inventory_state, cached.items_observed_at
            end
        end
        return
    end
    if state.detailsBudget <= 0 then return end
    state.detailsBudget = state.detailsBudget - 1
    row.abilities, row.items, row.modifiers, row.orbs = {}, {}, {}, {}
    local invoker = row.name == "npc_dota_hero_invoker" and state.flags.abilities
    local modifiers = (state.flags.modifiers or state.flags.items or invoker) and (call(NPC.GetModifiers, unit) or {}) or {}
    local foundEffects = {}
    for index, modifier in ipairs(modifiers) do
        if index > 64 then break end
        local modifierName = call(Modifier.GetName, modifier)
        local effectItem = itemModifiers[modifierName]
        if invoker and orbModifiers[modifierName] and #row.orbs < 3 then
            row.orbs[#row.orbs + 1] = {name = orbModifiers[modifierName], observed_at = now, stale = row.data_stale}
        end
        if effectItem then foundEffects[effectItem] = true end
        if observeItemEffect then observeItemEffect(unit, modifier, "modifier_sample", now) end
        if state.flags.modifiers then
            local ending = call(Modifier.GetDieTime, modifier)
            row.modifiers[#row.modifiers + 1] = {name = modifierName,
                stacks = call(Modifier.GetStackCount, modifier),
                remaining = finite(ending) and ending > now and ending - now or nil,
                die_time = finite(ending) and ending or nil, observed_at = now, stale = row.data_stale}
        end
    end
    if invoker and #row.orbs == 0 then
        for _, orb in pairs(state.orbParticles) do
            if orb.owner_id == tostring(row.id) and #row.orbs < 3 then
                row.orbs[#row.orbs + 1] = {name = orb.name, observed_at = orb.observed_at,
                    stale = row.data_stale, source = "orb_particle"}
            end
        end
    end
    if not row.data_stale and #modifiers <= 64 and (state.flags.modifiers or state.flags.items) then
        for _, itemName in pairs(itemModifiers) do
            if not foundEffects[itemName] then state.activeEffects[row.id .. ":" .. itemName] = nil end
        end
    end
    local rescanSlots = not cached or clock() >= (cached.nextSlotScan or 0)
        or cached.level ~= row.level or state.inventoryDirty[row.id] or cached.signature ~= signature
    local abilitySlots, itemSlots = {}, {}
    local oldAbilities, oldItems = {}, {}
    if cached then
        for _, entry in ipairs(cached.abilities or {}) do oldAbilities[entry.slot] = entry end
        for _, entry in ipairs(cached.items or {}) do oldItems[entry.slot] = entry end
    end
    if state.flags.abilities then
        for slot = 0, 31 do
            local ability = (rescanSlots or cached.abilitySlots and cached.abilitySlots[slot]) and call(NPC.GetAbilityByIndex, unit, slot)
            if ability then
                abilitySlots[slot] = true
                row.abilities[#row.abilities + 1] = abilityData(ability, slot, unit, now, row.data_stale, oldAbilities[slot], tonumber(row.id))
            end
        end
    end
    if state.flags.items then
        local occupied, reused = {}, false
        for slot = 0, 20 do
            local item = (rescanSlots or cached.itemSlots and cached.itemSlots[slot]) and call(NPC.GetItemByIndex, unit, slot)
            if item then
                itemSlots[slot] = true
                local info = abilityData(item, slot, unit, now, row.data_stale, oldItems[slot], tonumber(row.id))
                info.charges = call(Item and Item.GetCurrentCharges, item)
                local prior = oldItems[slot]
                info.cost = prior and prior.name == info.name and prior.cost or call(Item and Item.GetCost, item)
                if not finite(info.cost) or info.cost < 0 then info.cost = nil end
                row.items[#row.items + 1] = info
                state.itemKeys[info] = inventoryKey(item)
                occupied[slot] = true
            end
        end
        -- A missing slot in fog is not evidence of selling an item. A native
        -- inventory update or fresh visible enumeration may clear old slots.
        if row.data_stale and cached then
            local observedKeys = {}; for _, item in ipairs(row.items) do
                local key = state.itemKeys[item]
                if key then observedKeys[key] = true end
            end
            for _, item in ipairs(cached.items or {}) do
                local key = state.itemKeys[item]
                if not occupied[item.slot] and not (key and observedKeys[key]) then
                    local copy = {}; for key, value in pairs(item) do copy[key] = value end
                    state.itemKeys[copy] = key
                    copy.stale = true; row.items[#row.items + 1] = copy; reused = true
                    itemSlots[item.slot] = true
                end
            end
        end
        row.inventory_state = reused and "last_observation" or row.data_stale and "partial" or "observed"
        row.items_observed_at = reused and cached.items_observed_at or now
    else
        row.inventory_state, row.items_observed_at = false, false
    end
    state.inventoryDirty[row.id] = nil
    row.stats = false
    row.buyback = false
    local playerData = cached and cached.playerData or {}
    if state.flags.stats or state.flags.buybacks then
        local player = state.players[row.player_id]
        if player then
            local team = (state.localTeam == 1 or state.hasLocalHero and row.team == state.localTeam) and (call(Player.GetTeamData, player) or {}) or {}
            -- Reuse the native output table, but clear fields that would otherwise
            -- survive a missing field in the next Player Resource observation.
            for key in pairs(playerData) do playerData[key] = nil end
            local info = call(Player.GetTeamPlayer, player, playerData) or {}
            playerData = info
            if state.flags.stats then
                row.stats = {kills = team.kills, deaths = team.deaths, assists = team.assists,
                    networth = finite(info.networth) and info.networth >= 0 and info.networth or nil,
                    networth_source = "player_resource", networth_observed_at = now,
                    lasthits = info.lasthit_count, denies = info.deny_count}
            end
            if state.flags.buybacks then
                local last = state.buybacks[row.player_id]
                local ready = info.buyback_cooldown_time
                local nativeLast = team.last_buyback_time
                if finite(ready) and ready >= 0 or finite(nativeLast) and nativeLast > 0 or last then
                    row.buyback = {ready_at = finite(ready) and ready >= 0 and ready or nil,
                        cooldown = finite(ready) and ready >= 0 and math.max(0, ready - now) or nil,
                        last_at = finite(nativeLast) and nativeLast > 0 and nativeLast or last and last.last_at,
                        last_source = finite(nativeLast) and nativeLast > 0 and "team_data" or last and last.source,
                        source = finite(ready) and ready >= 0 and "player_resource" or last and last.source or "team_data",
                        observed_at = now}
                end
            end
        end
    end
    if state.flags.stats then
        row.stats = type(row.stats) == "table" and row.stats or {}
        local worth, known, itemKeys = 0, false, {}
        for _, item in ipairs(row.items) do
            local key = state.itemKeys[item]
            if finite(item.cost) and not (key and itemKeys[key]) then
                worth, known = worth + item.cost, true
                if key then itemKeys[key] = true end
            end
        end
        local inventoryWorth, courierWorth = worth, 0
        local courier = state.courierCosts[row.player_id]
        if courier then for key, cost in pairs(courier.items) do
            if not itemKeys[key] then
                itemKeys[key] = true
                courierWorth, known = courierWorth + cost, true
            end
        end end
        worth = worth + courierWorth
        -- Player Resource is authoritative. A zero contradicted by observed
        -- gear is unavailable enemy data; publish a labelled lower bound.
        if known and worth > 0 and (not finite(row.stats.networth) or row.stats.networth < worth) then
            local cash = (finite(playerData.reliable_gold) and math.max(0, playerData.reliable_gold) or 0)
                + (finite(playerData.unreliable_gold) and math.max(0, playerData.unreliable_gold) or 0)
            row.stats.networth, row.stats.networth_source = worth + cash, "observed_items_lower_bound"
            row.stats.networth_partial, row.stats.networth_observed_at = true, now
            row.stats.inventory_value, row.stats.courier_value = inventoryWorth, courierWorth
        end
    end
    local attr = state.flags.stats and cached and cached.attr or nil
    if state.flags.stats and not row.data_stale then
        local magic = call(NPC.GetMagicalArmorValue, unit)
        attr = {str = call(Hero.GetStrengthTotal, unit), agi = call(Hero.GetAgilityTotal, unit), int = call(Hero.GetIntellectTotal, unit),
            primary = call(Hero.GetPrimaryAttribute, unit), dmg = call(NPC.GetTrueDamage, unit), dmg_max = call(NPC.GetTrueMaximumDamage, unit),
            aps = call(NPC.GetAttacksPerSecond, unit), range = (call(NPC.GetAttackRange, unit) or 0) + (call(NPC.GetAttackRangeBonus, unit) or 0),
            armor = call(NPC.GetPhysicalArmorValue, unit), mres = finite(magic) and magic * 100 or nil, ms = call(NPC.GetMoveSpeed, unit),
            hpr = call(NPC.GetHealthRegen, unit), mpr = call(NPC.GetManaRegen, unit), xp = call(Hero.GetCurrentXP, unit)}
    end
    local playerName = cached and cached.playerName
    if not playerName and state.players[row.player_id] then playerName = call(Player.GetName, state.players[row.player_id]) end
    state.details[row.id] = {wall = clock(), game = now, signature = signature, attr = attr, playerName = playerName,
        abilities = row.abilities, items = row.items, modifiers = row.modifiers, stats = row.stats,
        buyback = row.buyback, playerData = playerData, orbs = row.orbs,
        inventory_state = row.inventory_state, items_observed_at = row.items_observed_at,
        abilitySlots = abilitySlots, itemSlots = itemSlots, level = row.level,
        nextSlotScan = rescanSlots and clock() + 2 or cached.nextSlotScan}
    row.details_at = now
end

local function classify(unit)
    if call(NPC.GetUnitName, unit) == "npc_dota_xp_fountain" then return "wisdom", "wisdom" end
    if call(NPC.IsWard, unit) then
        local name = call(NPC.GetUnitName, unit) or ""
        return name:find("sentry", 1, true) and "sentry" or "observer", "wards"
    end
    if call(NPC.IsRoshan, unit) then return "roshan", "roshan" end
    if call(NPC.IsTormentor, unit) or call(NPC.GetUnitName, unit) == "npc_dota_miniboss" then return "tormentor", "tormentors" end
    if call(NPC.IsCourier, unit) then return "courier", "couriers" end
    if call(NPC.IsIllusion, unit) or call(NPC.IsMeepoClone, unit) then return "illusion", "illusions" end
    local unitName = call(NPC.GetUnitName, unit) or ""
    if unitName:find("npc_dota_lone_druid_bear", 1, true) == 1 then return "bear", "heroes" end
    if call(NPC.IsTower, unit) or unitName:find("_tower", 1, true) or call(NPC.IsBarracks, unit) == true or unitName:find("_rax_", 1, true)
        or call(NPC.IsFort, unit) == true or unitName:find("_fort", 1, true) then return "building", "buildings" end
    local neutral = call(NPC.IsNeutral, unit) == true
    if neutral then return "neutral", "neutrals", true end
    if call(NPC.IsLaneCreep, unit) then return "creep", "creeps" end
    return nil
end

local function campDefinition(camp)
    local box = call(Camp and Camp.GetCampBox, camp)
    local low, high = box and pos(box.min), box and pos(box.max)
    local campType = call(Camp and Camp.GetType, camp)
    local id = call(Entity.GetIndex, camp)
    if not id or not low or not high or not finite(campType) or campType < 0 or campType > 3
        or campType % 1 ~= 0 or low.x > high.x or low.y > high.y then return nil end
    return {id = tostring(id), camp_type = campType, x = (low.x + high.x) / 2, y = (low.y + high.y) / 2,
        min_x = low.x, min_y = low.y, max_x = high.x, max_y = high.y,
        stack_count = call(Camp and Camp.GetStackCount, camp),
        z = finite(box.min.z) and box.min.z or 0}
end

local function campVisible(camp)
    -- This is evidence at nine native vision samples, not proof of a cleared
    -- camp. Pulled/stacked neutrals can be outside the spawn box.
    if not FogOfWar or type(FogOfWar.IsPointVisible) ~= "function" then return false end
    for _, x in ipairs({camp.min_x, camp.x, camp.max_x}) do
        for _, y in ipairs({camp.min_y, camp.y, camp.max_y}) do
            local point = call(Vector, x, y, camp.z) or {x = x, y = y, z = camp.z}
            if call(FogOfWar.IsPointVisible, point) ~= true then return false end
        end
    end
    return true
end

local function observeNeutral(job, unit, now)
    if #job.camps == 0 or call(Entity.IsAlive, unit) ~= true then return end
    local p = pos(call(Entity.GetAbsOrigin, unit))
    if not p then return end
    local hidden = call(Entity.IsDormant, unit) == true
    for _, camp in ipairs(job.camps) do
        if p.x >= camp.min_x and p.x <= camp.max_x and p.y >= camp.min_y and p.y <= camp.max_y then
            if hidden then camp.hidden_count = camp.hidden_count + 1
            else camp.count, camp.neutral_at = camp.count + 1, now; camp.representative_name = call(NPC.GetUnitName, unit) end
        end
    end
end

local function finishCamp(camp, previous, now)
    local visibleAfter = campVisible(camp)
    local occupied = camp.count > 0
    local empty = not occupied and camp.hidden_count == 0 and camp.visible_before and visibleAfter
    local status = occupied and "occupied" or empty and "empty" or "unknown"
    local stacks = occupied and finite(camp.stack_count) and camp.stack_count >= 0
        and camp.stack_count <= 256 and camp.stack_count % 1 == 0 and camp.stack_count or nil
    local row = {id = camp.id, x = camp.x, y = camp.y, camp_type = camp.camp_type,
        state = status, source = occupied and "visible_neutrals" or empty and "visible_samples_no_neutrals" or "unobserved",
        observed_at = occupied and camp.neutral_at or now, visible = occupied or empty,
        count = occupied and camp.count or empty and 0 or nil,
        stack_count = stacks, stack_source = stacks and "native_camp" or nil,
        min_x = camp.min_x, min_y = camp.min_y, max_x = camp.max_x, max_y = camp.max_y,
        representative_name = camp.representative_name or previous and previous.representative_name}
    if status == "unknown" and previous then
        row.last_state = previous.state ~= "unknown" and previous.state or previous.last_state
        row.last_observed_at = previous.state ~= "unknown" and previous.observed_at or previous.last_observed_at
        row.last_count = previous.count or previous.last_count
        row.last_stack_count = previous.stack_count or previous.last_stack_count
    end
    local dotaTime = call(GameRules.GetDOTATime, true, true) or 0
    row.memory_until = status == "unknown" and previous and previous.memory_until
        or now + (60 - math.max(0, dotaTime) % 60)
    return row
end

local function rememberUnit(unit, row, now)
    if row.kind == "neutral" or row.kind == "building" then
        local previous = state.unitMemory[row.id]
        if row.alive == false and row.visible then state.unitMemory[row.id] = nil; return end
        if row.visible and row.x then
            if row.kind == "neutral" then
                local dotaTime = call(GameRules.GetDOTATime, true, true) or 0
                row.memory_until = now + (60 - math.max(0, dotaTime) % 60)
            end
            state.unitMemory[row.id] = {unit = unit, row = row}
        elseif previous then
            row.x, row.y, row.hp, row.max_hp = previous.row.x, previous.row.y, previous.row.hp, previous.row.max_hp
            row.memory_until, row.position_observed_at = previous.row.memory_until, previous.row.position_observed_at
            row.source, row.visible, row.data_stale = "last_observation", false, true
        end
    elseif row.kind == "creep" then
        if row.alive ~= false then
            local entry = state.laneMovers[row.id]
            if entry and entry.unit == unit then entry.row = row
            else state.laneMovers[row.id] = {unit = unit, row = row} end
        else state.laneMovers[row.id] = nil end
    end
end

local WARD_LIFETIME = {observer = 360, sentry = 420}

local function slowSnapshot(now, available)
    local began = clock()
    local f = state.flags
    if not (f.camps or f.wards or f.couriers or f.creeps or f.neutrals or f.buildings
        or f.roshan or f.tormentors or f.wisdom or f.heroes or f.illusions) then
        state.scanJob, state.nextSlow = nil, clock() + mode().slow
        return
    end
    if not state.scanJob then
        local refreshCamps = state.flags.camps and clock() >= state.nextCampDefs
        local campList = state.flags.camps and (refreshCamps and call(Camps and Camps.GetAll) or state.campDefs) or {}
        local previous = {}
        for _, camp in ipairs(state.camps) do previous[camp.id] = camp end
        local native = call(NPCs and NPCs.GetAll) or {}
        local nativeTowers = state.flags.buildings and call(Towers and Towers.GetAll) or {}
        -- C-level array copies keep a stable snapshot if a native API reuses
        -- its result table, without the old Lua loop building the seen set.
        local list = table.move(native, 1, #native, 1, {})
        local towers = table.move(nativeTowers, 1, #nativeTowers, 1, {})
        state.scanJob = {list = list, towers = towers, towerIndex = 1, seen = {},
            index = 1, units = {}, wards = {}, roshan = {}, tormentors = {},
            phase = "camps", campList = campList or {}, campIndex = 1, refreshCamps = refreshCamps,
            campDefs = {}, camps = {}, previousCamps = previous, finishedCamps = {}}
    end
    local job, count, campWork = state.scanJob, 0, 0
    local md = mode()
    while count < md.scanCount and clock() - began < math.min(md.scanMs, available or math.huge) do
        if job.phase == "camps" then
            if job.campIndex > #job.campList or job.campIndex > 256 then
                if job.refreshCamps then state.campDefs, state.nextCampDefs = job.campDefs, clock() + 1.5 end
                job.phase = "units"
            else
                if campWork >= 2 then break end
                local definition
                if job.refreshCamps then definition = campDefinition(job.campList[job.campIndex])
                else definition = job.campList[job.campIndex] end
                job.campIndex, count, campWork = job.campIndex + 1, count + 1, campWork + 1
                if definition then
                    job.campDefs[#job.campDefs + 1] = definition
                    local camp = {}
                    for key, value in pairs(definition) do camp[key] = value end
                    camp.count, camp.hidden_count, camp.visible_before = 0, 0, campVisible(camp)
                    job.camps[#job.camps + 1] = camp
                end
            end
        elseif job.phase == "camp_finish" then
            if job.campIndex > #job.camps then break end
            if campWork >= 2 then break end
            local camp = job.camps[job.campIndex]
            job.finishedCamps[#job.finishedCamps + 1] = finishCamp(camp, job.previousCamps[camp.id], now)
            job.campIndex, count, campWork = job.campIndex + 1, count + 1, campWork + 1
        elseif job.index > #job.list and job.towerIndex > #job.towers then
            job.phase, job.campIndex = "camp_finish", 1
        else
            local unit
            if job.index <= #job.list then
                unit, job.index = job.list[job.index], job.index + 1
            else
                unit, job.towerIndex = job.towers[job.towerIndex], job.towerIndex + 1
            end
            count = count + 1
            if unit and not job.seen[unit] then
                job.seen[unit] = true
                local identity = call(Entity.GetIndex, unit)
                local classification = identity and state.classifications[identity]
                if not classification and state.destroyed[identity] ~= unit then
                    local kind, filter, neutral = classify(unit)
                    classification = {kind = kind, filter = filter, neutral = neutral}
                    if identity then state.classifications[identity] = classification end
                end
                classification = classification or {}
                if classification.neutral and state.destroyed[identity] ~= unit then observeNeutral(job, unit, now) end
                local kind, filter = classification.kind, classification.filter
                if kind and state.flags[filter] and state.destroyed[identity] ~= unit then
                    local row = base(unit, kind, now)
                    if row then
                        rememberUnit(unit, row, now)
                        if kind == "courier" then state.movers[row.id] = unit end
                        if kind == "wisdom" then
                            local previous = state.wisdom[row.id]
                            if previous and (previous.unit == unit or previous.unit == nil) then
                                for _, key in ipairs({"active", "cycle", "taken_at", "observed_at"}) do row[key] = previous.row[key] end
                            end
                            state.wisdom[row.id] = {unit = unit, row = row}
                        end
                        if kind == "roshan" then job.roshan[#job.roshan + 1] = {unit = unit, row = row} end
                        if kind == "tormentor" then job.tormentors[#job.tormentors + 1] = {unit = unit, row = row} end
                        if kind == "observer" or kind == "sentry" then
                            row.radius = kind == "sentry" and 900 or call(NPC.GetDayTimeVisionRange, unit)
                            for _, modifier in ipairs(call(NPC.GetModifiers, unit) or {}) do
                                local name = call(Modifier.GetName, modifier) or ""
                                if name:find("ward", 1, true) then
                                    local ending = call(Modifier.GetDieTime, modifier)
                                    if finite(ending) and ending > now then row.expires_at, row.remaining = ending, ending - now end
                                end
                            end
                            if #job.wards < 512 then
                                row.observed_at = now
                                local previous = state.wardMemory[row.id]
                                if previous then
                                    row.x, row.y = previous.x, previous.y
                                    row.expires_at = row.expires_at or previous.expires_at
                                    if row.visible == false then row.observed_at = previous.observed_at end
                                end
                                row.first_seen = previous and previous.first_seen or now
                                row.forget_at = row.first_seen + WARD_LIFETIME[kind]
                                if row.expires_at then row.remaining = math.max(0, row.expires_at - now) end
                                if row.alive == false then state.wardMemory[row.id] = nil
                                else state.wardMemory[row.id] = row; job.wards[#job.wards + 1] = row end
                            end
                        elseif #job.units < 512 then job.units[#job.units + 1] = row end
                    end
                end
            end
        end
    end
    if job.phase == "units" and job.index > #job.list and job.towerIndex > #job.towers then
        job.phase, job.campIndex = "camp_finish", 1
    end
    if job.phase ~= "camp_finish" or job.campIndex <= #job.camps then return end
    local seen = {}
    for _, row in ipairs(job.units) do seen[row.id] = true end
    for id, entry in pairs(state.unitMemory) do
        local row = entry.row
        if row.memory_until and row.memory_until <= now then state.unitMemory[id] = nil
        elseif not seen[id] and state.flags[row.kind == "neutral" and "neutrals" or "buildings"] and #job.units < 512 then
            local copy = {}; for key, value in pairs(row) do copy[key] = value end
            copy.visible, copy.data_stale, copy.source = false, true, "last_observation"
            job.units[#job.units + 1] = copy
        end
    end
    seen = {}
    for _, row in ipairs(job.wards) do seen[row.id] = true end
    if state.flags.wards then
        for id, row in pairs(state.wardMemory) do
            if row.alive == false or row.expires_at and row.expires_at <= now or row.forget_at and row.forget_at <= now then state.wardMemory[id] = nil
            elseif not seen[id] and #job.wards < 512 then
                local copy = {}; for key, value in pairs(row) do copy[key] = value end
                copy.visible, copy.data_stale = false, true
                state.wardMemory[id] = copy
                job.wards[#job.wards + 1] = copy
            end
        end
    end
    state.units, state.wards, state.roshan_units = job.units, job.wards, job.roshan
    local present = {}; for _, row in ipairs(job.units) do present[row.id] = true end
    for id in pairs(state.laneMovers) do if not present[id] then state.laneMovers[id] = nil end end
    state.laneList = {}; for _, entry in pairs(state.laneMovers) do state.laneList[#state.laneList + 1] = entry end
    state.tormentor_units = job.tormentors
    state.camps = state.flags.camps and job.finishedCamps or {}
    state.scanJob, state.layersDirty, state.nextSlow = nil, true, clock() + mode().slow
end

local function objectSnapshot(now, packet)
    -- Small cached sets only. Couriers bypass the full NPC scan; rune and
    -- shrine observations run at 4 Hz, with at most 16 courier samples/packet.
    packet.units_patch = {}
    if state.flags.couriers and clock() >= (state.nextCourierSample or 0) then
        state.nextCourierSample = clock() + mode().couriers
        local count = 0
        for id, unit in pairs(state.movers) do
            if count >= 16 then break end
            count = count + 1
            if state.destroyed[call(Entity.GetIndex, unit)] == unit or call(Entity.IsAlive, unit) == false then
                packet.units_patch[#packet.units_patch + 1] = {id = id, _delete = true}; state.movers[id] = nil
            else
                local row = base(unit, "courier", now)
                if row then
                    local prior = state.courierMotion[id]
                    if row.visible and row.x then
                        local dt = prior and now - prior.time or 0
                        if dt > 0 and dt <= 1 and math.abs(row.x - prior.x) + math.abs(row.y - prior.y) < 1800 then
                            row.vx, row.vy = (row.x - prior.x) / dt, (row.y - prior.y) / dt
                            row.motion_source, row.motion_observed_at = "observed_displacement", now
                        end
                        state.courierMotion[id] = {x = row.x, y = row.y, time = now}
                    end
                    packet.units_patch[#packet.units_patch + 1] = row
                end
            end
        end
    end
    -- Moving lane creeps use a bounded round-robin cache, not NPCs.GetAll.
    if state.flags.creeps and clock() >= (state.nextCreeps or 0) then
        state.nextCreeps = clock() + (mode().creepPeriod or 0)
        local list = state.laneList
        for step = 1, math.min(mode().creeps, #list) do
            state.laneCursor = state.laneCursor % #list + 1
            local entry = list[state.laneCursor]
            local row, unit = entry.row, entry.unit
            if state.laneMovers[row.id] == entry then
                if now >= (entry.nextVisibility or 0) then
                    entry.hidden, entry.alive = call(Entity.IsDormant, unit) == true, call(Entity.IsAlive, unit)
                    entry.nextVisibility = now + 0.25
                end
                if entry.alive == false then
                    packet.units_patch[#packet.units_patch + 1] = {id = row.id, _delete = true}; state.laneMovers[row.id] = nil
                elseif not entry.hidden then
                    local p = pos(call(Entity.GetAbsOrigin, unit))
                    if p then
                        local dt = entry.seenAt and now - entry.seenAt
                        if dt and dt > 0 and dt <= 2 and finite(row.x) then
                            entry.vx, entry.vy = (p.x - row.x) / dt, (p.y - row.y) / dt
                        end
                        entry.seenAt, entry.ms = now, entry.ms or call(NPC.GetMoveSpeed, unit)
                        row.x, row.y, row.visible, row.data_stale, row.position_observed_at = p.x, p.y, true, false, now
                        packet.units_patch[#packet.units_patch + 1] = {id = row.id, _merge = true,
                            x = p.x, y = p.y, visible = true, data_stale = false, source = "visible", position_observed_at = now}
                    end
                elseif row.visible ~= false then
                    row.visible, row.data_stale = false, true
                    packet.units_patch[#packet.units_patch + 1] = {id = row.id, _merge = true, visible = false, data_stale = true}
                end
            end
        end
    end
    if clock() < state.nextObjects then return end
    state.nextObjects = clock() + (mode().objects or 0.25)
    local couriers = (state.flags.couriers or state.flags.stats) and call(Couriers and Couriers.GetAll) or {}
    for index, unit in ipairs(couriers or {}) do
        if index > 16 then break end
        local id = call(Entity.GetIndex, unit)
        if state.flags.couriers and id and state.destroyed[id] ~= unit then state.movers[tostring(id)] = unit end
    end
    -- Sample one courier inventory per object tick; include only items with
    -- native player ownership. No guess from which courier is nearest a hero.
    if state.flags.stats and #couriers > 0 then
        state.courierCursor = state.courierCursor % math.min(16, #couriers) + 1
        local unit = couriers[state.courierCursor]
        local id = call(Entity.GetIndex, unit)
        if id then
            local values = {}
            if state.destroyed[id] ~= unit and call(Entity.IsAlive, unit) ~= false then
                for slot = 0, 20 do
                    local item = call(NPC.GetItemByIndex, unit, slot)
                    local owner = item and call(Item and Item.GetPlayerOwnerID, item)
                    local cost = item and call(Item and Item.GetCost, item)
                    if finite(owner) and owner >= 0 and finite(cost) and cost >= 0 then
                        values[owner] = values[owner] or {}
                        values[owner][inventoryKey(item)] = cost
                    end
                end
            end
            state.courierSamples[id] = {values = values, observed_at = now}
        end
    end
    state.courierCosts = {}
    for id, sample in pairs(state.courierSamples) do
        if now - sample.observed_at > 4 then state.courierSamples[id] = nil
        else for owner, items in pairs(sample.values) do
            local entry = state.courierCosts[owner] or {items = {}, observed_at = sample.observed_at}
            for key, cost in pairs(items) do entry.items[key] = cost end
            state.courierCosts[owner] = entry
        end end
    end
    local runes, runeSeen, runePresent = {}, {}, {}
    if state.flags.runes then for _, rune in ipairs(call(Runes and Runes.GetAll) or {}) do
        local id, hidden = call(Entity.GetIndex, rune), call(Entity.IsDormant, rune) == true
        if id then runePresent[tostring(id)] = true end
        if id and state.destroyed[id] ~= rune and #runes < 64 then
            local remembered = state.runeMemory[tostring(id)]
            local previous = remembered and remembered.row
            local p = not hidden and pos(call(Entity.GetAbsOrigin, rune)) or previous
            if p then
                local kind = not hidden and (call(Rune and Rune.GetRuneType, rune) or call(Entity.GetField, rune, "m_iRuneType")) or previous and previous.rune_type
                local row = {id = tostring(id), x = p.x, y = p.y, rune_type = finite(kind) and kind >= 0 and kind <= 9 and kind or nil,
                    name = call(Entity.GetUnitName, rune) or "Rune", visible = not hidden, data_stale = hidden,
                    observed_at = not hidden and now or previous and previous.observed_at, source = hidden and "last_observation" or "entity"}
                local dotaTime = call(GameRules.GetDOTATime, true, true) or 0
                -- Standard 7.41 clocks: bounty 4 min; water/power 2 min.
                -- Turbo uses half the scheduled interval.
                local turbo = Enum.GameMode and call(GameRules.GetGameMode) == Enum.GameMode.DOTA_GAMEMODE_TURBO
                local period = kind == 5 and 240 or kind == 8 and 420 or 120
                if turbo then period = period / 2 end
                row.memory_until = hidden and previous and previous.memory_until or now + (period - math.max(0, dotaTime) % period)
                row.next_expected_at = row.memory_until
                state.runeMemory[row.id] = {unit = rune, row = row}
                runeSeen[row.id] = not hidden
            end
        end
    end end
    if state.flags.runes then for id, entry in pairs(state.runeMemory) do
        local row = entry.row
        local spot = not runePresent[id] and finite(row.x) and call(Vector, row.x, row.y, call(World.GetGroundZ, row.x, row.y) or 128)
        if row.memory_until and row.memory_until <= now then state.runeMemory[id] = nil
        elseif spot and call(FogOfWar.IsPointVisible, spot) == true then state.runeMemory[id] = nil
        elseif #runes < 64 then
            local copy = {}; for key, value in pairs(row) do copy[key] = value end
            if not runeSeen[id] then copy.visible, copy.data_stale, copy.source = false, true, "last_observation" end
            runes[#runes + 1] = copy
        end
    end end
    state.runes, packet.runes = runes, runes
    local wards = {}
    if state.flags.wards then for id, row in pairs(state.wardMemory) do
        if row.alive == false or row.expires_at and row.expires_at <= now or row.forget_at and row.forget_at <= now then state.wardMemory[id] = nil
        else wards[#wards + 1] = row end
    end end
    state.wards, packet.wards = wards, wards
    for _, entry in pairs(state.wisdom) do
        local unit, row = entry.unit, entry.row
        if state.flags.wisdom then
            local hidden = unit == nil or call(Entity.IsDormant, unit) == true
            local native
            if not hidden then native = call(Entity.GetField, unit, "m_bActive") end
            local cycle = math.floor(math.max(0, call(GameRules.GetDOTATime, true, true) or 0) / 420)
            local value = type(native) == "boolean" and native or type(native) == "number" and native ~= 0 or nil
            if native == false or native == 0 then value = false end
            if row.cycle ~= cycle then row.taken_at, row.active = nil, nil end
            if value ~= nil then
                if value == false and row.active == true and row.cycle == cycle and now - (row.observed_at or 0) <= 2 then row.taken_at = now end
                row.active, row.observed_at, row.source = value, now, "native_active"
            end
            row.cycle, row.visible, row.data_stale = cycle, not hidden, hidden or value == nil
            local dotaTime = call(GameRules.GetDOTATime, true, true) or 0
            row.next_expected_at, row.schedule_source = now + ((math.floor(math.max(0, dotaTime) / 420) + 1) * 420 - dotaTime), "match_cycle_420"
        end
    end
end

local function isRoshan(unit)
    return unit ~= nil and (call(NPC.IsRoshan, unit) == true or call(NPC.GetUnitName, unit) == "npc_dota_roshan")
end

local function isTormentor(unit)
    return unit ~= nil and (call(NPC.IsTormentor, unit) == true or call(NPC.GetUnitName, unit) == "npc_dota_miniboss")
end
local function attackerOwner(unit)
    local owner = call(NPC.GetOwnerNPC, unit) or call(Entity.GetOwner, unit)
    local name = owner and call(NPC.GetUnitName, owner)
    if type(name) == "string" and name:find("npc_dota_hero_", 1, true) == 1 then
        local id = call(Entity.GetIndex, owner)
        return id and tostring(id), name
    end
end

local function recordTormentorAttacker(unit, target, source, now, damage)
    local owner, targetId = call(Entity.GetIndex, unit), call(Entity.GetIndex, target)
    if owner == nil or targetId == nil or call(Entity.IsAlive, unit) == false then return end
    local heroId, heroName = attackerOwner(unit)
    state.tormentorAttackers[tostring(targetId) .. ":" .. tostring(owner)] = {id = tostring(owner), target_id = tostring(targetId),
        hero_id = heroId, hero_name = heroName,
        name = call(NPC.GetUnitName, unit), team = call(Entity.GetTeamNum, unit), observed_at = now,
        source = source, damage = finite(damage) and damage > 0 and damage or nil,
        stale = source == "attack_target" and call(Entity.IsDormant, unit) == true}
end

local function objectivePosition(unit, kind, now)
    local row = base(unit, kind, now)
    if not row then return {} end
    local previous = state.objectiveMotion[row.id]
    if row.x and row.y then
        if previous and (previous.x ~= row.x or previous.y ~= row.y) then
            local distance = math.sqrt((row.x - previous.x)^2 + (row.y - previous.y)^2)
            if now >= previous.time and now - previous.time <= 2 and distance > 16 then
                previous.from_x, previous.from_y, previous.moved_at = previous.x, previous.y, now
                previous.relocated = distance > 1800
            end
        end
        previous = previous or {}
        previous.x, previous.y, previous.time = row.x, row.y, now
        state.objectiveMotion[row.id] = previous
    end
    return {x = row.x, y = row.y, visible = row.visible, position_source = row.source,
        position_observed_at = row.position_observed_at, moving = previous and previous.moved_at and now - previous.moved_at <= 1.5 or false,
        move_from_x = previous and previous.from_x, move_from_y = previous and previous.from_y,
        relocated = previous and previous.relocated}
end

local function tormentorSnapshot(now)
    local result = {}
    if not state.flags.tormentors then return result end
    for _, entry in ipairs(state.tormentor_units) do
        local unit, row = entry.unit, entry.row
        local info = objectivePosition(unit, "tormentor", now)
        info.id, info.hp, info.max_hp, info.alive = row.id, call(Entity.GetHealth, unit), call(Entity.GetMaxHealth, unit), call(Entity.IsAlive, unit)
        info.stale, info.observed_at, info.attackers = call(Entity.IsDormant, unit) == true, now, {}
        local motion = state.objectiveMotion[row.id]
        if motion and not info.stale and finite(info.hp) then
            if finite(motion.hp) and finite(motion.hp_at) and now >= motion.hp_at and now - motion.hp_at < 2
                and info.hp < motion.hp then motion.damage_until = now + 2 end
            motion.hp, motion.hp_at = info.hp, now
            if info.alive ~= false and finite(motion.damage_until) and now < motion.damage_until then info.under_attack = true end
        end
        for key, attacker in pairs(state.tormentorAttackers) do
            if now < attacker.observed_at or now - attacker.observed_at >= 4 then state.tormentorAttackers[key] = nil
            elseif attacker.target_id == row.id and info.alive ~= false then
                info.attackers[#info.attackers + 1] = attacker
                if attacker.stale ~= true then info.under_attack = true end
            end
        end
        result[#result + 1] = info
        if #result >= 8 then break end
    end
    return result
end

observeTeleport = function(unit, modifier, now)
    if not state.active or not state.flags.teleports or call(Modifier.GetName, modifier) ~= "modifier_teleporting" then return end
    local id, ending = call(Entity.GetIndex, unit), call(Modifier.GetDieTime, modifier)
    if id == nil or not finite(ending) or ending <= now or ending > now + 90 then return end
    local previous, started = state.teleports[tostring(id)], call(Modifier.GetCreationTime, modifier)
    state.teleports[tostring(id)] = {ends_at = ending, started_at = finite(started) and started <= now and started or nil,
        observed_at = previous and previous.ends_at == ending and previous.observed_at or now,
        source = "modifier_teleporting", stale = call(Entity.IsDormant, unit) == true}
end

local function sampleTeleport(unit, row, now)
    if not state.flags.teleports then return end
    state.teleportSampleAt = state.teleportSampleAt or {}
    local wall = clock()
    if wall >= (state.teleportSampleAt[row.id] or 0) then
        state.teleportSampleAt[row.id] = wall + (mode().turbo and 0.1 or 0)
        local modifier = call(NPC.GetModifier, unit, "modifier_teleporting")
        if modifier then observeTeleport(unit, modifier, now)
        elseif row.visible == true and type(NPC.GetModifier) == "function" and state.teleports[row.id] then
            state.teleports[row.id] = nil
            for id, event in pairs(state.events) do
                if event.kind == "teleport" and event.owner_id == row.id and event.channel_end_at then state.events[id], state.particles[id] = nil, nil end
            end
        end
    end
    local channel = state.teleports[row.id]
    if channel and channel.ends_at <= now then state.teleports[row.id], channel = nil, nil end
    if channel then
        row.teleport = {}; for key, value in pairs(channel) do row.teleport[key] = value end
    end
end

local function recordRoshanAttacker(unit, source, now, damage)
    local id = unit and call(Entity.GetIndex, unit)
    local name = unit and call(NPC.GetUnitName, unit)
    if id == nil or type(name) ~= "string" or name == "" or call(Entity.IsAlive, unit) == false then return end
    local key = tostring(id)
    local previous = state.roshanAttackers[key]
    if source == "attack_target" and previous and previous.source == "damage_event" and now - previous.observed_at < 1 then return end
    local heroId, heroName = attackerOwner(unit)
    state.roshanAttackers[key] = {id = key, name = name, team = call(Entity.GetTeamNum, unit),
        hero_id = heroId, hero_name = heroName,
        observed_at = now, source = source, damage = finite(damage) and damage > 0 and damage or nil,
        stale = source == "attack_target" and call(Entity.IsDormant, unit) == true}
end

local function sampleRoshanAttacker(unit, now)
    if call(Entity.IsDormant, unit) == true then
        local id = call(Entity.GetIndex, unit)
        local previous = id and state.roshanAttackers[tostring(id)]
        if previous and previous.source == "attack_target" then previous.stale = true end
        if id then for _, attacker in pairs(state.tormentorAttackers) do
            if attacker.id == tostring(id) and attacker.source == "attack_target" then attacker.stale = true end
        end end
        return
    end
    if call(NPC.IsAttacking, unit) ~= true then return end
    -- These getters are optional in local scripts, not part of the documented
    -- API. Never infer the target from proximity or the attacking state alone.
    local target = call(Entity and Entity.GetAttackTarget, unit) or call(NPC and NPC.GetAttackTarget, unit)
    if state.flags.roshan and isRoshan(target) and call(Entity.IsAlive, target) ~= false then recordRoshanAttacker(unit, "attack_target", now) end
    if state.flags.tormentors and isTormentor(target) and call(Entity.IsAlive, target) ~= false then recordTormentorAttacker(unit, target, "attack_target", now) end
    return target
end

local function roshanSnapshot(now)
    if not state.flags.roshan then return nil end
    local native = call(Entity and Entity.GetRoshanHealth)
    local result
    for _, entry in ipairs(state.roshan_units) do
        local unit, row = entry.unit, entry.row
        local hp = call(Entity.GetHealth, unit)
        local hidden = call(Entity.IsDormant, unit) == true
        local source = "entity"
        if hidden and type(native) == "number" and native > 0 then hp, source = native, "native_roshan" end
        if type(hp) == "number" then
            row.hp, row.max_hp = hp, call(Entity.GetMaxHealth, unit) or row.max_hp
            row.hp_source, row.hp_stale = source, hidden and source ~= "native_roshan"
            if not row.hp_stale then row.hp_observed_at = now end
        end
        row.visible, row.alive = not hidden, call(Entity.IsAlive, unit)
        if source == "native_roshan" and hp > 0 then row.alive = true end
        if not result or row.alive ~= false then
            result = objectivePosition(unit, "roshan", now)
            result.id, result.hp, result.max_hp, result.alive = row.id, row.hp, row.max_hp, row.alive
            result.stale, result.source, result.observed_at = row.hp_stale, row.hp_source, row.hp_observed_at
        end
    end
    if not result and type(native) == "number" and native > 0 then
        result = {hp = native, alive = true, stale = false, source = "native_roshan", observed_at = now}
    end
    if result and not result.stale and type(result.hp) == "number" then
        if state.roshanLastHp and state.roshanLastTime and now >= state.roshanLastTime and now - state.roshanLastTime < 2 and result.hp < state.roshanLastHp then
            state.roshanDamageUntil = now + 2
        end
        state.roshanLastHp, state.roshanLastTime = result.hp, now
        result.under_attack = result.alive ~= false and now < (state.roshanDamageUntil or 0)
    end
    if result and result.alive == false or native == 0 then state.roshanAttackers = {} end
    local attackers, hasDamage, hasProjectile = {}, false, false
    for id, attacker in pairs(state.roshanAttackers) do
        if now < attacker.observed_at or now - attacker.observed_at >= 4 then state.roshanAttackers[id] = nil
        else
            attackers[#attackers + 1] = attacker
            if attacker.source == "damage_event" then hasDamage = true end
            if attacker.source == "attack_projectile" then hasProjectile = true end
        end
    end
    table.sort(attackers, function(a, b) return a.id < b.id end)
    local nativeTargets = type(Entity and Entity.GetAttackTarget) == "function" or type(NPC and NPC.GetAttackTarget) == "function"
    result = result or {}
    result.attackers, result.attackers_available = attackers, nativeTargets or hasDamage or hasProjectile
    result.attackers_source = hasDamage and "damage_event" or hasProjectile and "attack_projectile" or nativeTargets and "attack_target" or "unavailable"
    for _, attacker in ipairs(attackers) do
        if attacker.stale ~= true then result.under_attack = true; break end
    end
    return result
end

local function eventAllowed(event)
    if not state.flags.effects then return false end
    if event.kind == "scan" then return state.flags.scans end
    if event.kind == "teleport" then return state.flags.teleports end
    if event.item_name or event.ability_name and event.ability_name:find("item_", 1, true) == 1 then return state.flags.active_items end
    if event.ultimate == true then return state.flags.ultimates end
    if event.kind == "projectile" or event.vx or event.kind == "arrow" or event.kind == "hook" then return state.flags.projectiles end
    return state.flags.casts
end

local KEEP_EVENTS = {teleport = true, scan = true, smoke = true, blink = true, innate = true}

local function eventRoom(kind)
    local count, oldest, oldestAt = 0, nil, math.huge
    for id, event in pairs(state.events) do
        count = count + 1
        if not KEEP_EVENTS[event.kind] and (event.started or 0) < oldestAt then oldest, oldestAt = id, event.started or 0 end
    end
    if count < 96 then return true end
    if not KEEP_EVENTS[kind] or not oldest then return false end
    state.events[oldest], state.particles[oldest] = nil, nil
    return true
end

local function recordFarming(unit, target, source, now)
    if not unit or not target or call(NPC.IsNeutral, target) ~= true then return end
    local name = call(NPC.GetUnitName, unit)
    if type(name) ~= "string" or name:find("npc_dota_hero_", 1, true) ~= 1 then return end
    local id = call(Entity.GetIndex, unit)
    if not id then return end
    state.farming[tostring(id)] = {kind = "farm", target_id = tostring(call(Entity.GetIndex, target)),
        observed_at = now, expires_at = now + 4, source = source}
end

local function inGame()
    local phase = call(GameRules.GetGameState)
    if phase == Enum.GameState.DOTA_GAMERULES_STATE_POST_GAME or phase == Enum.GameState.DOTA_GAMERULES_STATE_DISCONNECT then
        state.over = true
        return false
    end
    if call(Engine.IsInGame) == true then state.over = false; return true end
    local watching = (phase == Enum.GameState.DOTA_GAMERULES_STATE_PRE_GAME or phase == Enum.GameState.DOTA_GAMERULES_STATE_GAME_IN_PROGRESS)
        and (call(Heroes.Count) or 0) > 0
    if get(ui.debug, false) and state.lastPhase ~= phase and ai_bridge and ai_bridge.mcp_log then
        state.lastPhase = phase
        call(ai_bridge.mcp_log, "debug", "[NEXUS Radar] in-game check", {engine = false, phase = phase,
            heroes = call(Heroes.Count), local_hero = call(Heroes.GetLocal) ~= nil, watching = watching})
    end
    state.over = not watching
    return watching
end

local function localTeam(hero)
    local team = hero and call(Entity.GetTeamNum, hero)
    if team ~= 2 and team ~= 3 then
        local player = call(Players.GetLocal)
        team = player and call(Entity.GetTeamNum, player)
    end
    return (team == 2 or team == 3) and team or 1
end

local function collect()
    local now = gameClock()
    local packet = {type = "update", match = tostring(call(GameRules.GetMatchID) or "local"),
        game_time = call(GameRules.GetDOTATime, true, true) or now, game_clock = now,
        paused = call(GameRules.IsPaused) == true, in_game = inGame(),
        heroes = {}, events = {}, objectives = {}}
    if not packet.in_game then resetMatch(); return packet end
    if state.match and state.match ~= packet.match then resetMatch() end
    state.match = packet.match
    local localHero = call(Heroes.GetLocal)
    packet.local_team = localTeam(localHero)
    packet.spectator = packet.local_team == 1
    state.hasLocalHero = localHero ~= nil
    state.localTeam, state.detailsBudget = packet.local_team, 1
    if clock() >= state.nextPlayers then
        state.players = {}
        for _, player in ipairs(call(Players and Players.GetAll) or {}) do
            local id = call(Player.GetPlayerID, player)
            if id then state.players[id] = player end
        end
        state.nextPlayers = clock() + 2
    end
    if state.flags.heroes then
        local wall = clock()
        if not state.heroList or wall >= (state.nextHeroes or 0) then
            local list = {}
            for _, unit in ipairs(call(Heroes.GetAll) or {}) do
                if not call(NPC.IsIllusion, unit) and not call(NPC.IsMeepoClone, unit) and #list < 64 then
                    list[#list + 1] = unit
                end
            end
            state.heroList, state.nextHeroes = list, wall + 0.25
        end
        local heroes = state.heroList
        local selected
        if #heroes > 0 and wall >= (state.nextDetail or 0) then

            if state.urgentBurst < 3 and next(state.detailUrgent) then
                for _, candidate in ipairs(heroes) do
                    local id = call(Entity.GetIndex, candidate)
                    if id and state.detailUrgent[tostring(id)] then
                        selected = candidate
                        state.detailUrgent[tostring(id)] = nil
                        state.urgentBurst = state.urgentBurst + 1
                        break
                    end
                end
            end
            if not selected then
                state.detailCursor = state.detailCursor % #heroes + 1
                selected, state.urgentBurst = heroes[state.detailCursor], 0
            end
            state.nextDetail = wall + (mode().detailTick or 0)
        end
        for _, unit in ipairs(heroes) do
            local row = base(unit, "hero", now)
            if row and #packet.heroes < 64 then
                row["local"] = localHero and unit == localHero or false
                heroDetails(unit, row, now, unit == selected)
                sampleTeleport(unit, row, now)
                if unit == selected then
                    local target = sampleRoshanAttacker(unit, now)
                    recordFarming(unit, target, "attack_target", now)
                end
                local activity = state.farming[row.id]
                if activity and activity.expires_at > now then row.activity = activity
                elseif activity then state.farming[row.id] = nil end
                packet.heroes[#packet.heroes + 1] = row
            end
        end
    end
    objectSnapshot(now, packet)
    if state.layersDirty or state.needFull then
        local filters = {bear = "heroes", illusion = "illusions", courier = "couriers", creep = "creeps", neutral = "neutrals", building = "buildings", roshan = "roshan", tormentor = "tormentors", wisdom = "wisdom"}
        packet.units = {}
        for _, row in ipairs(state.units) do if state.flags[filters[row.kind]] then packet.units[#packet.units + 1] = row end end
        packet.wards, packet.runes = state.flags.wards and state.wards or {}, state.flags.runes and state.runes or {}
        packet.camps = state.flags.camps and state.camps or {}
        state.layersDirty = false
    end
    local function cooldown(fn)
        local ready = call(fn)
        return type(ready) == "number" and math.max(0, ready - now) or nil
    end
    packet.objectives = {glyph_radiant = cooldown(GameRules.GetGoodGlyphCD), glyph_dire = cooldown(GameRules.GetBadGlyphCD),
        scan_radiant = cooldown(GameRules.GetGoodScanCD), scan_dire = cooldown(GameRules.GetBadScanCD)}
    if clock() >= state.nextRoshan then
        state.roshan = roshanSnapshot(now)
        state.nextRoshan = clock() + mode().roshan
    end
    packet.objectives.roshan = state.roshan
    if not state.due or state.due.objectives or not state.tormentorCache then state.tormentorCache = tormentorSnapshot(now) end
    packet.objectives.tormentors = state.tormentorCache
    local cycleRemaining = call(GameRules.GetNextCycleTime)
    if finite(cycleRemaining) and cycleRemaining >= 0 and cycleRemaining <= 1200 then
        packet.objectives.cycle = {next_at = now + cycleRemaining, source = "native_cycle"}
    end
    packet.objectives.wisdom = {}
    if state.flags.wisdom then for _, entry in pairs(state.wisdom) do
        local row = {}; for key, value in pairs(entry.row) do row[key] = value end
        packet.objectives.wisdom[#packet.objectives.wisdom + 1] = row
    end end
    for id, event in pairs(state.events) do
        local channel = event.kind == "teleport" and event.owner_id and state.teleports[event.owner_id]
        if channel and channel.ends_at > now then
            event.channel_end_at, event.remaining, event.timing = channel.ends_at, channel.ends_at - now, "native_modifier"
            event.duration = channel.started_at and math.max(0.01, channel.ends_at - channel.started_at) or nil
            event.ending, event.stale = channel.ends_at, channel.stale
        end
        if event.ending <= now then
            state.events[id], state.particles[id] = nil, nil
        elseif eventAllowed(event) and event.x then
            local row = {}
            for key, value in pairs(event) do if key ~= "ending" then row[key] = value end end
            if event.timing == "observed_lifetime" then
                row.elapsed = math.max(0, now - event.started)
            else row.remaining = event.ending - now end
            packet.events[#packet.events + 1] = row
        end
    end
    packet.performance = state.perf
    state.needFull = false
    return packet
end

-- Confirmed in the lobby capture. Keep endpoint names exact: other control
-- points can be colors, attachment offsets or shader parameters, not positions.
local observedParticles = {
    keeper_light_speed = {kind = "innate", point = 0, ttl = 3},
    antimage_blink_start = {kind = "blink", phase = "origin", point = 0, entityPoint = 1, ttl = 1.5},
    antimage_blink_end = {kind = "blink", phase = "destination", entityPoint = 1, ttl = 1.5},
    blink_dagger_start = {kind = "blink", phase = "origin", point = 0, ttl = 4, item = "item_blink"},
    blink_dagger_end = {kind = "blink", phase = "destination", point = 0, ttl = 4, item = "item_blink"},
    teleport_start = {kind = "teleport", phase = "origin", point = 0, entityPoint = 0, ttl = 30},
    teleport_origin = {kind = "teleport", phase = "origin", point = 0, ttl = 30},
    teleport_end = {kind = "teleport", phase = "destination", point = 0, originPoint = 3, ttl = 30},
}
local patterns = {
    {"smoke_of_deceit", "smoke", 3},
}

local function active()
    return state.active and state.flags.enabled and state.flags.effects
end

local function eventOwner(event, entity, id)
    local index = entity and call(Entity.GetIndex, entity) or id
    if index ~= nil then event.owner_id = tostring(index) end
    if entity then
        event.owner_name = call(NPC.GetUnitName, entity) or event.owner_name
        event.team = call(Entity.GetTeamNum, entity) or event.team
        event.owner_hidden = call(Entity.IsDormant, entity) == true
        event.owner_player_id = call(Hero and Hero.GetPlayerID, entity)
    elseif index ~= nil then
        local cached = state.heroes[tonumber(index) or index]
        local identity = cached and cached.identity
        if identity then
            event.owner_name, event.team, event.owner_player_id = identity.name, identity.team, identity.player_id
        end
    end
end

observeCast = function(unit, ability, source, now, native, effect, ownerIndex)
    if not active() or not unit or not ability and not effect and not native then return end
    if native and native.passive == true then return end
    if ability and not effect and not native and call(Ability.IsPassive, ability) == true then return end
    local name = native and native.name or ability and call(Ability.GetName, ability) or effect and effect.item_name
    local owner = ownerIndex or call(Entity.GetIndex, unit)
    if not name or not owner or excludedSpell(name) then return end
    now = now or gameClock()
    local byOwner = state.casts[tostring(owner)] or {}
    state.casts[tostring(owner)] = byOwner
    local seen = byOwner[name] or {}
    local castTime = ability and call(Ability.GetCastStartTime, ability) or nil
    local cooldown = native and native.cooldown or ability and call(Ability.GetCooldown, ability)
    local fresh = source == "ability_animation" or source == "modifier_event" or source == "ability_projectile" or source == "ability_sound"
    if effect and source == "modifier_sample" then
        fresh = finite(effect.used_at) and now >= effect.used_at and now - effect.used_at < 2 and seen.effectUsedAt ~= effect.used_at
        seen.effectUsedAt = effect.used_at
    end
    -- Instant items may never expose a cast animation or cast-start timestamp.
    -- The API's last-use timestamp also confirms a first observation, while a
    -- cooldown increase alone could be Blink's damage lockout.
    local usedAt = native and native.used_at or effect and effect.used_at
    if source == "ability_sample" and finite(usedAt) then
        fresh = now >= usedAt and now - usedAt < 2 and (not finite(seen.usedAt) or usedAt > seen.usedAt + 0.2)
    end
    if not fresh and finite(castTime) and castTime > 0 then
        fresh = castTime ~= seen.castTime and now >= castTime and now - castTime < 2
    end
    if not fresh and source == "ability_sample" and not Ability.SecondsSinceLastUse
        and not name:find("blink", 1, true) and finite(cooldown) and finite(seen.cooldown) then
        fresh = cooldown > seen.cooldown + 0.75
    end
    seen.castTime, seen.cooldown = castTime, cooldown
    if finite(usedAt) then seen.usedAt = math.max(seen.usedAt or -math.huge, usedAt) end
    byOwner[name] = seen
    if not fresh or (seen.wall and clock() - seen.wall < 0.25) then return end
    seen.wall = clock()
    local hidden = call(Entity.IsDormant, unit) == true
    local cached = state.heroes[owner]
    local nativePosition = hidden and pos(call(Hero and Hero.GetLastMaphackPos, unit)) or nil
    local p = not hidden and pos(call(Entity.GetAbsOrigin, unit)) or nativePosition
    p = p or cached
    if not p or type(p.x) ~= "number" or type(p.y) ~= "number" then return end
    local isBlink = name == "item_blink" or name == "item_overwhelming_blink" or name == "item_swift_blink" or name == "item_arcane_blink"
    if not eventRoom(isBlink and "blink" or "cast") then return end
    state.castSerial = state.castSerial + 1
    local id = "cast:" .. tostring(state.castSerial)
    local event = {id = id, kind = isBlink and "blink" or "cast", name = name, ability_name = name,
        x = p.x, y = p.y, started = now, ending = now + 4,
        timing = "observed_lifetime", source = source, location = "caster",
        position_source = hidden and (nativePosition and "maphack_last" or cached and cached.source or "last_seen") or "visible",
        observed_at = now, stale = hidden, cooldown = finite(cooldown) and cooldown >= 0 and cooldown or nil,
        ultimate = native and native.ultimate == true or ability and call(Ability.IsUltimate, ability) == true or false,
        item_name = name:find("item_", 1, true) == 1 and name or nil,
        active_until = effect and effect.active_until, active_source = effect and "modifier" or nil,
        used_at = usedAt or finite(castTime) and castTime > 0 and castTime <= now and castTime or nil}
    eventOwner(event, unit)
    state.events[id] = event
    invalidateDetails(owner)
end

local function particleAbility(entity, name)
    if name:find("arc_warden_spark_wraith", 1, true) == 1 then return "arc_warden_spark_wraith" end
    local id = entity and call(Entity.GetIndex, entity)
    local details = id and state.details[tostring(id)]
    if not details then return nil end
    local normalized = name:gsub("_spell_", "_")
    local best, bestLength
    local entries = {}
    for _, ability in ipairs(details.abilities or {}) do entries[#entries + 1] = ability end
    for _, item in ipairs(details.items or {}) do entries[#entries + 1] = item end
    for _, ability in ipairs(entries) do
        local candidate = ability.name
        if candidate and candidate:find("item_", 1, true) == 1 then candidate = candidate:sub(6) end
        if type(candidate) == "string" and #candidate >= 6 and not excludedSpell(candidate)
            and (normalized == candidate or normalized:find(candidate .. "_", 1, true) == 1
                or normalized:gsub("_", ""):find(candidate:gsub("_", ""), 1, true) == 1)
            and (not bestLength or #candidate > bestLength) then best, bestLength = ability.name, #candidate end
    end
    return best
end

observeItemEffect = function(unit, modifier, source, now)
    if not unit or not modifier then return end
    local modifierName = call(Modifier.GetName, modifier)
    local itemName = itemModifiers[modifierName]
    if not itemName then return end
    local owner, ending = call(Entity.GetIndex, unit), call(Modifier.GetDieTime, modifier)
    if not owner then return end
    if not finite(ending) or ending <= now then
        -- An activation callback remains evidence of use even when the runtime
        -- omits its expiry. Do not invent the active duration or item cooldown.
        if source == "modifier_event" then
            observeCast(unit, call(Modifier.GetAbility, modifier), source, now, {name = itemName})
        end
        return
    end
    local key = tostring(owner) .. ":" .. itemName
    local previous = state.activeEffects[key]
    local created = call(Modifier.GetCreationTime, modifier)
    local hidden = call(Entity.IsDormant, unit) == true
    local used = finite(created) and created > 0 and created <= now and created or nil
    local record = {item_name = itemName, active_until = ending,
        observed_at = previous and previous.active_until == ending and previous.observed_at or now,
        used_at = used or (source == "modifier_event" and now or previous and previous.used_at),
        usage_source = used and "modifier_creation" or source == "modifier_event" and "modifier_event" or previous and previous.usage_source,
        stale = hidden}
    state.activeEffects[key] = record
    -- Cached hidden modifiers do not become new activations on every sample.
    local newEffect = not previous or previous.active_until ~= ending
    if newEffect and (source == "modifier_event" or used and now - used < 2) then
        local ability = call(Modifier.GetAbility, modifier)
        observeCast(unit, ability, source, now, {name = itemName,
            cooldown = ability and call(Ability.GetCooldown, ability)}, record)
    end
end

local function groupEvent(event)
    if not event.phase or not event.owner_id then return end
    for _, other in pairs(state.events) do
        if other ~= event and other.owner_id == event.owner_id and other.kind == event.kind
            and other.name ~= event.name and other.ending > gameClock()
            and math.abs(other.started - event.started) <= 0.25 then
            event.group_id = other.group_id or other.id
            event.origin_x, event.origin_y = other.origin_x, other.origin_y
            event.destination_x, event.destination_y = other.destination_x, other.destination_y
            return
        end
    end
end

local function setEndpoint(event, phase, p)
    local xKey, yKey = phase .. "_x", phase .. "_y"
    event[xKey], event[yKey] = p.x, p.y
    if event.phase == phase then event.x, event.y = p.x, p.y end
    -- Share endpoints between a cast's origin/destination particles. A TP's
    -- owner-origin CP3 must never overwrite the destination marker's CP0.
    for _, other in pairs(state.events) do
        if other ~= event and event.group_id and other.group_id == event.group_id then
            other[xKey], other[yKey] = p.x, p.y
        end
    end
end

local function addEvent(data, projectile)
    if not state.active or not state.flags.enabled or type(data) ~= "table" then return end
    if projectile and not state.flags.projectiles then return end
    local rawKey = tostring(data.name) .. "|" .. tostring(data.fullName)
    local names = state.nameCache[rawKey]
    if not names then
        local short = tostring(data.name or data.fullName or ""):lower():gsub("\\", "/")
        local full = tostring(data.fullName or data.name or ""):lower():gsub("\\", "/")
        short = (short:match("([^/]+)$") or short):gsub("%.vpcf_c$", ""):gsub("%.vpcf$", "")
        names = {short, full, excluded = excludedSpell(short)}
        state.nameCacheSize = state.nameCacheSize + 1
        if state.nameCacheSize > 4096 then state.nameCache, state.nameCacheSize = {}, 1 end
        state.nameCache[rawKey] = names
    end
    local name, fullName = names[1], names[2]
    local orbName = name:match("^invoker_(quas)_orb$") or name:match("^invoker_(wex)_orb$") or name:match("^invoker_(exort)_orb$")
    if orbName and not projectile then
        local owner = data.entity or data.entityForModifiers
        local ownerId = owner and call(Entity.GetIndex, owner)
        if state.flags.abilities and ownerId and call(NPC.GetUnitName, owner) == "npc_dota_hero_invoker" and data.index then
            local count = 0; for _ in pairs(state.orbParticles) do count = count + 1 end
            if count < 64 then
                state.orbParticles[tostring(data.index)] = {owner_id = tostring(ownerId), name = orbName, observed_at = gameClock()}
                invalidateDetails(ownerId)
            end
        end
        return
    end
    if not active() then return end
    if name:find("invoker_quas_", 1, true) == 1 or name:find("invoker_wex_", 1, true) == 1
        or name:find("invoker_exort_", 1, true) == 1 then return end -- cosmetic children of the three native orbs
    if names.excluded then return end
    if name:find("keeper_light_speed_", 1, true) == 1 then return end -- child visuals duplicate the innate trail
    if name:find("scan_preview", 1, true) or name:find("ambient", 1, true) or name:find("footstep", 1, true) then return end
    local observed = not projectile and observedParticles[name] or nil
    if name == "keeper_light_speed" and fullName:find("/", 1, true)
        and fullName ~= "particles/units/heroes/hero_keeper_of_the_light/keeper_light_speed.vpcf" then return end
    local kind, duration = "effect", 1.5
    local scan = name == "scan" and (not fullName:find("/", 1, true)
        or fullName:find("generic_gameplay/scan", 1, true) ~= nil)
    if observed then kind, duration = observed.kind, observed.ttl
    else
        for _, pattern in ipairs(patterns) do
            if name:find(pattern[1], 1, true) then kind, duration = pattern[2], pattern[3]; break end
        end
    end
    if scan then kind, duration = "scan", 12 end
    local entity = data.source or data.entity or data.entityForModifiers
    local owner = entity and (call(NPC.GetOwnerNPC, entity) or call(Entity.GetOwner, entity))
    if owner and (call(NPC.GetUnitName, owner) or ""):find("npc_dota_hero_", 1, true) == 1 then entity = owner end
    -- Hero-owned ability particles are supported generically, while persistent
    -- ambient/cosmetic/attack particles must not flood the event stream.
    local generic = false
    if kind == "effect" and not projectile then
        local ignored = names.ignored
        if ignored == nil then
            ignored = false
            for _, token in ipairs({"ambient", "aura", "overhead", "attack", "wearable", "status", "idle", "blood", "illusion", "trail", "body", "footstep"}) do
                if name:find(token, 1, true) then ignored = true; break end
            end
            names.ignored = ignored
        end
        if ignored then return end
        local ownerName = entity and call(NPC.GetUnitName, entity) or ""
        generic = not ignored and (fullName:find("/heroes/hero_", 1, true) ~= nil or ownerName:find("npc_dota_hero_", 1, true) == 1)
        if not generic then
            if get(ui.debug, false) and not state.loggedParticles[name] and ai_bridge and ai_bridge.mcp_log then
                state.loggedParticles[name] = true
                call(ai_bridge.mcp_log, "debug", "[NEXUS Radar] unknown particle", {name = name, full_name = fullName})
            end
            return
        end
        local ownerKey = tostring(entity and call(Entity.GetIndex, entity) or data.entity_id or "unknown")
        local rate = state.genericRates[ownerKey] or {time = clock(), count = 0}
        if clock() - rate.time >= 1 then rate.time, rate.count = clock(), 0 end
        if rate.count >= 6 then return end
        rate.count = rate.count + 1; state.genericRates[ownerKey] = rate
        duration = 6
    end
    if projectile and kind == "effect" then kind = "projectile" end
    local id = tostring(projectile and (data.handle or data.particleIndex) or data.index)
    if id == "nil" then return end
    id = (projectile and "projectile:" or "particle:") .. id
    if not state.events[id] and not eventRoom(kind) then return end
    local p = projectile and pos(data.origin or data.position) or nil
    -- Particle creation coordinates can be the caster rather than the target.
    -- Wait for control point 0 for particle world position.
    local now = gameClock()
    local velocity = pos(data.velocity)
    local speed = velocity and math.sqrt(velocity.x * velocity.x + velocity.y * velocity.y)
    if projectile and speed and speed > 0 and type(data.distance) == "number" then
        duration = math.min(10, data.distance / speed)
    end
    local event = {id = id, kind = kind, name = name, x = p and p.x, y = p and p.y,
        duration = not observed and not generic and not scan and duration or nil, ending = now + duration, started = now,
        vx = velocity and velocity.x, vy = velocity and velocity.y,
        source = projectile and "projectile" or "particle", timing = (observed or generic or scan) and "observed_lifetime" or "estimated",
        location = (generic or scan) and "effect" or nil,
        phase = observed and observed.phase, group_id = observed and id}
    eventOwner(event, entity, data.entity_id or data.entity_for_modifiers_id)
    if generic then
        event.ability_name = particleAbility(entity, name)
        local details = event.owner_id and state.details[event.owner_id]
        if details and event.ability_name then
            for _, entry in ipairs(details.abilities or {}) do
                if entry.name == event.ability_name then
                    event.cooldown, event.cooldown_observed_at = entry.cooldown, entry.observed_at
                    event.ultimate = entry.ultimate
                    break
                end
            end
        end
    end
    if observed and observed.item then event.ability_name, event.item_name = observed.item, observed.item end
    if name == "keeper_light_speed" then event.ability_name = "keeper_of_the_light_bright_speed" end
    groupEvent(event)
    state.events[id] = event
    if not projectile then state.particles[id] = true end
end

local function updateParticle(data, attached)
    if not active() or type(data) ~= "table" then return end
    local event = state.events["particle:" .. tostring(data.index)]
    local p = pos(data.position)
    if not event or not p then return end
    local observed = observedParticles[event.name]
    if event.kind == "scan" and data.controlPoint == 9 and p.x >= 0 and p.x <= 1 then
        -- Verified in the installed scan.vpcf: CP9.x mixes green -> red.
        event.scan_response = p.x >= 0.5 and "red" or "green"
        event.scan_response_source = "particle_cp9"
        return
    end
    if not observed then
        if data.controlPoint == 0 and math.abs(p.x) <= 20000 and math.abs(p.y) <= 20000 then
            event.x, event.y = p.x, p.y
            event.position_source = "particle_cp0"
        end
        return
    end
    local point
    if attached then point = observed.entityPoint else point = observed.point end
    if event.name == "keeper_light_speed" and data.controlPoint == 0 then
        if math.abs(p.x) > 20000 or math.abs(p.y) > 20000 then return end
        local attachedId = attached and (data.entity and call(Entity.GetIndex, data.entity) or data.entIdx)
        if attachedId and (not event.owner_id or tostring(attachedId) == event.owner_id) then eventOwner(event, data.entity, attachedId)
        else eventOwner(event, nil, event.owner_id) end
        event.x, event.y, event.position_source, event.observed_at = p.x, p.y, "particle_cp0", gameClock()
        if event.owner_id and event.owner_name == "npc_dota_hero_keeper_of_the_light" then
            state.innatePositions[event.owner_id] = {x = p.x, y = p.y, observed_at = event.observed_at}
        end
        return
    end
    local phase = point ~= nil and data.controlPoint == point and event.phase or nil
    if attached and observed.originPoint ~= nil and data.controlPoint == observed.originPoint then phase = "origin" end
    if not phase then return end
    if attached then
        local owner = data.entity and call(Entity.GetIndex, data.entity) or data.entIdx
        if not event.owner_id or (owner ~= nil and tostring(owner) == event.owner_id) then
            local hadOwner = event.owner_id ~= nil
            eventOwner(event, data.entity, data.entIdx)
            if not hadOwner then groupEvent(event) end
        end
    end
    setEndpoint(event, phase, p)
end

function script.OnParticleCreate(data)
    addEvent(data, false)
end
function script.OnLinearProjectileCreate(data)
    addEvent(data, true)
end

function script.OnParticleUpdate(data)
    updateParticle(data, false)
end
script.OnParticleUpdateFallback = script.OnParticleUpdate

function script.OnParticleUpdateEntity(data)
    updateParticle(data, true)
end

function script.OnUnitAnimation(data)
    if type(data) ~= "table" or not active() then return end
    local ability = data.unit and call(NPC and NPC.GetAbilityByActivity, data.unit, data.activity)
    if ability then
        observeCast(data.unit, ability, "ability_animation", gameClock())

    end
end

function script.OnProjectile(data)
    if not state.active or not state.flags.enabled or type(data) ~= "table" then return end
    if data.isAttack == true then
        recordFarming(data.source, data.target, "attack_projectile", gameClock())
        if state.flags.roshan and isRoshan(data.target) and call(Entity.IsAlive, data.target) ~= false then
            recordRoshanAttacker(data.source, "attack_projectile", gameClock())
        end
        if state.flags.tormentors and isTormentor(data.target) and call(Entity.IsAlive, data.target) ~= false then
            recordTormentorAttacker(data.source, data.target, "attack_projectile", gameClock())
        end
    elseif active() and data.ability and data.source then
        observeCast(data.source, data.ability, "ability_projectile", gameClock())
    end
end

function script.OnStartSound(data)
    if not active() or type(data) ~= "table" or type(data.name) ~= "string" or not data.source then return end
    local id = call(Entity.GetIndex, data.source)
    local details = id and state.details[tostring(id)]
    if not details then return end
    -- Match only a known native ability and its exact cast/activation sound.
    -- Impact, looping and cosmetic sound suffixes never become new casts.
    local cache = state.soundNames
    local name = cache[data.name]
    if not name then
        state.soundCount = (state.soundCount or 0) + 1
        if state.soundCount > 4096 then cache, state.soundCount = {}, 1; state.soundNames = cache end
        name = data.name:lower():gsub("^hero_", ""):gsub("[^a-z0-9]", "")
        cache[data.name] = name
    end
    for _, ability in ipairs(details.abilities or {}) do
        local key = type(ability.name) == "string" and cache[ability.name]
        if type(ability.name) == "string" and not key then
            key = ability.name:gsub("_", "")
            cache[ability.name] = key
        end
        if key and (name == key or name == key .. "cast" or name == key .. "activate") then
            observeCast(data.source, nil, "ability_sound", gameClock(), ability)
            return
        end
    end
end

function script.OnModifierCreate(entity, modifier)
    if not state.active then return end
    local id = entity and call(Entity.GetIndex, entity)
    if state.active and id and orbModifiers[call(Modifier.GetName, modifier)] then invalidateDetails(id) end
    if state.active then observeItemEffect(entity, modifier, "modifier_event", gameClock()) end
    if state.active then observeTeleport(entity, modifier, gameClock()) end
    if active() then
        local ability = call(Modifier.GetAbility, modifier)
        local owner = ability and call(Ability.GetOwner, ability)
        if owner and not itemModifiers[call(Modifier.GetName, modifier)] then
            observeCast(owner, ability, "modifier_event", gameClock())
        end
    end
end

function script.OnModifierUpdate(entity, modifier)
    if state.active then observeItemEffect(entity, modifier, "modifier_sample", gameClock()) end
    if state.active then observeTeleport(entity, modifier, gameClock()) end
end

function script.OnModifierDestroy(entity, modifier)
    if not state.active then return end
    local itemName = itemModifiers[call(Modifier.GetName, modifier)]
    local owner = entity and call(Entity.GetIndex, entity)
    if owner and orbModifiers[call(Modifier.GetName, modifier)] then invalidateDetails(owner) end
    if owner and call(Modifier.GetName, modifier) == "modifier_teleporting" then
        state.teleports[tostring(owner)] = nil
        for id, event in pairs(state.events) do
            if event.kind == "teleport" and event.owner_id == tostring(owner) and event.channel_end_at then state.events[id], state.particles[id] = nil, nil end
        end
    end
    if itemName and owner then
        state.activeEffects[tostring(owner) .. ":" .. itemName] = nil
        state.details[tostring(owner)] = nil
    end
end

function script.OnChatEvent(data)
    local buybackType = Enum and Enum.DotaChatMessage and Enum.DotaChatMessage.CHAT_MESSAGE_BUYBACK
    if not state.active or not state.flags.buybacks or type(data) ~= "table" or buybackType == nil or data.type ~= buybackType then return end
    local playerId = data.playerid_1
    -- Chat payload semantics are not documented per event; accept the explicit
    -- player-ID field only when it resolves to a known player, never value/value2.
    if not finite(playerId) or playerId < 0 or playerId % 1 ~= 0 or not state.players[playerId] then return end
    state.buybacks[playerId] = {last_at = gameClock(), source = "chat_event"}
    for id, hero in pairs(state.heroes) do
        if hero.identity and hero.identity.player_id == playerId then state.details[tostring(id)] = nil end
    end
end

function script.OnEntityHurt(data)
    -- Umbrella dispatches this only when its existing unsafe mode permits it.
    -- The radar never enables that mode; no event means no damage evidence.
    if not state.active or type(data) ~= "table" or not finite(data.damage) or data.damage <= 0 then return end
    recordFarming(data.source, data.target, "damage_event", gameClock())
    if state.flags.roshan and isRoshan(data.target) then
        recordRoshanAttacker(data.source, "damage_event", gameClock(), data.damage)
        state.nextRoshan = 0
    end
    if state.flags.tormentors and isTormentor(data.target) then recordTormentorAttacker(data.source, data.target, "damage_event", gameClock(), data.damage) end
end

function script.OnEntityKilled(data)
    local victim = type(data) == "table" and data.target
    if state.active and victim and call(Entity.IsHero, victim) == true and call(NPC.IsIllusion, victim) ~= true
        and call(NPC.IsMeepoClone, victim) ~= true then
        local id = call(Entity.GetIndex, victim)
        if id then
            local entry = state.kills_by[tostring(id)] or {k = 0, d = 0}
            entry.d = entry.d + 1
            state.kills_by[tostring(id)] = entry
        end
        local source = data.source
        local killer = source and (call(Entity.IsHero, source) == true and source or call(NPC.GetOwnerNPC, source) or call(Entity.GetOwner, source))
        local killerId = killer and call(Entity.IsHero, killer) == true and call(Entity.GetTeamNum, killer) ~= call(Entity.GetTeamNum, victim)
            and call(Entity.GetIndex, killer)
        if killerId then
            local entry = state.kills_by[tostring(killerId)] or {k = 0, d = 0}
            entry.k = entry.k + 1
            state.kills_by[tostring(killerId)] = entry
        end
    end
    if state.active and type(data) == "table" and isRoshan(data.target) then
        state.roshanAttackers, state.roshanDamageUntil, state.nextRoshan = {}, 0, 0
    end
    if state.active and type(data) == "table" and data.target and (call(NPC.IsTower, data.target) == true
        or call(NPC.IsBarracks, data.target) == true) and #state.kills < 32 then
        local p = pos(call(Entity.GetAbsOrigin, data.target))
        state.kills[#state.kills + 1] = {name = call(NPC.GetUnitName, data.target), team = call(Entity.GetTeamNum, data.target),
            barracks = call(NPC.IsBarracks, data.target) == true, x = p and p.x, y = p and p.y}
    end
    if type(data) == "table" and data.target and (call(NPC.IsWard, data.target) == true
        or call(NPC.IsNeutral, data.target) == true or call(NPC.IsTower, data.target) == true) then script.OnEntityDestroy(data.target, true) end
    if type(data) == "table" and isTormentor(data.target) then
        local targetId = tostring(call(Entity.GetIndex, data.target))
        for key, attacker in pairs(state.tormentorAttackers) do if attacker.target_id == targetId then state.tormentorAttackers[key] = nil end end
    end
end

function script.OnParticleDestroy(data)
    if type(data) == "table" then
        local orb = state.orbParticles[tostring(data.index)]
        if orb then invalidateDetails(orb.owner_id); state.orbParticles[tostring(data.index)] = nil end
        local id = "particle:" .. tostring(data.index)
        local event = state.events[id]
        -- A short-lived Blink particle still leaves its observed action badge.
        if event and event.kind == "blink" and event.item_name and event.owner_id and event.x and event.ending > gameClock() then
            event.location, event.phase, event.group_id = "caster", nil, nil
        else state.events[id] = nil end
        state.particles[id] = nil
    end
end
function script.OnLinearProjectileDestroy(data)
    if type(data) == "table" then state.events["projectile:" .. tostring(data.handle)] = nil end
end

function script.OnGameEnd()
    resetMatch()
    state.over, state.match = true, nil
    state.requestId = state.requestId + 1
    state.inflight, state.feedOwner = {}, nil
    state.nextSend = clock() + 2
end

function script.OnUnitInventoryUpdated(entity)
    if not state.active then return end
    local id = call(Entity.GetIndex, entity)
    if id then invalidateDetails(id); state.inventoryDirty[tostring(id)] = true end
end

function script.OnEntityDestroy(entity, confirmedDeath)
    if not state.active then return end
    local id = call(Entity.GetIndex, entity)
    if id then
        local key = tostring(id)
        local cached = state.heroes[id]
        -- A late removal for an old handle must not erase a new NPC which has
        -- already reused that index.
        if cached and cached.entity and cached.entity ~= entity then return end
        if not cached and not state.wardMemory[key] and not state.unitMemory[key] and not state.runeMemory[key]
            and not state.laneMovers[key] and not state.movers[key] and not state.wisdom[key] and not state.details[key] then
            state.classifications[id], state.destroyed[id] = nil, entity
            return
        end
        local remembered = state.wardMemory[key] or state.unitMemory[key] and state.unitMemory[key].row
        local obscured = call(Entity.IsDormant, entity) == true or remembered and remembered.visible == false
        local keep = remembered and obscured and not confirmedDeath
        local keepHero = not confirmedDeath and obscured and cached and cached.identity
            and (cached.identity.name or ""):find("npc_dota_hero_", 1, true) == 1
        if keep then
            remembered.visible, remembered.data_stale, remembered.source = false, true, "last_observation"
        else state.unitMemory[key], state.wardMemory[key] = nil, nil end
        local rune = state.runeMemory[key]
        if rune then
            local observed = rune.row.visible ~= false
            rune.unit = nil; rune.row.visible, rune.row.data_stale = false, true
            if not obscured and observed then state.runeMemory[key] = nil end
        end
        state.laneMovers[key], state.courierMotion[key], state.courierSamples[id] = nil, nil, nil
        state.casts[key], state.genericRates[key] = nil, nil
        local shrine = state.wisdom[key]
        if shrine then shrine.unit = nil; shrine.row.visible, shrine.row.data_stale = false, true end
        state.classifications[id] = nil
        if cached and cached.identity and (cached.identity.name or ""):find("npc_dota_hero_", 1, true) == 1 then
            state.nextHeroes = 0
        end
        state.heroes[id] = nil
        if not keepHero then state.details[key] = nil end
        state.innatePositions[tostring(id)] = nil
        state.teleports[tostring(id)], state.objectiveMotion[tostring(id)] = nil, nil
        state.farming[tostring(id)] = nil
        for index, orb in pairs(state.orbParticles) do if orb.owner_id == tostring(id) then state.orbParticles[index] = nil end end
        for _, name in ipairs({"tormentor_units", "roshan_units"}) do
            for index = #state[name], 1, -1 do if state[name][index].unit == entity then table.remove(state[name], index) end end
        end
        state.destroyed[id], state.movers[tostring(id)] = entity, nil
        for _, layer in ipairs({"units", "wards", "runes"}) do
            for index = #state[layer], 1, -1 do
                if state[layer][index].id == tostring(id) and not keep then table.remove(state[layer], index) end
            end
        end
        if state.scanJob then for _, layer in ipairs({"units", "wards"}) do
            for index = #state.scanJob[layer], 1, -1 do if state.scanJob[layer][index].id == tostring(id) then table.remove(state.scanJob[layer], index) end end
        end end
        state.layersDirty = true
    end
    state.nextSlow = math.min(state.nextSlow, clock() + 0.25)
end

function script.OnNpcSpawned(entity)
    if not state.active then return end
    if call(Entity.IsHero, entity) == true then state.nextHeroes = 0 end
    local id = call(Entity.GetIndex, entity)
    if id then
        local cached = state.heroes[id]
        local memory = state.unitMemory[tostring(id)]
        local retired = cached and cached.entity or state.destroyed[id] or memory and memory.unit
        forgetEntity(id)
        if retired and retired ~= entity then state.destroyed[id] = retired end
    end
    if call(NPC.IsWard, entity) then state.nextSlow = math.min(state.nextSlow, clock() + 0.1) end
end

local relay = {}
do
    local PARTS = {"clock", "pos", "info", "units", "wards", "runes", "camps", "events", "objectives"}
    local RUNE_MODS = {modifier_rune_doubledamage = 0, modifier_rune_haste = 1, modifier_rune_invis = 3,
        modifier_rune_regen = 4, modifier_rune_arcane = 6}

    local function round(value)
        return finite(value) and math.floor(value + 0.5) or nil
    end

    local function byId(a, b)
        return tostring(a.id) < tostring(b.id)
    end

    local function strip(list)
        for _, row in ipairs(list or {}) do row.id = nil end
        return list
    end

    local function boss(row)
        local item = {id = row.id, alive = row.alive, under_attack = row.under_attack == true or nil}
        if finite(row.hp) and finite(row.max_hp) and row.max_hp > 0 then item.hp = round(row.hp / row.max_hp * 100) end
        if row.visible == true and finite(row.x) and finite(row.y) then item.x, item.y = round(row.x), round(row.y) end
        local names, seen = {}, {}
        for _, attacker in ipairs(row.attackers or {}) do
            local name = attacker.hero_name
            if attacker.stale ~= true and name and not seen[name] and #names < 3 then
                seen[name] = true
                names[#names + 1] = name
            end
        end
        item.attackers = names
        return item
    end

    function relay.merge(packet)
        local r = state.relay
        if not packet.in_game then
            r.units, r.wards, r.runes = {}, {}, {}
            return
        end
        if type(packet.units) == "table" then
            r.units = {}
            for _, row in ipairs(packet.units) do r.units[row.id] = row end
        end
        for _, patch in ipairs(packet.units_patch or {}) do
            if patch._delete then r.units[patch.id] = nil
            elseif patch._merge then
                local row = r.units[patch.id]
                if row then for key, value in pairs(patch) do if key ~= "_merge" then row[key] = value end end end
            else r.units[patch.id] = patch end
        end
        if type(packet.wards) == "table" then r.wards = packet.wards end
        if type(packet.runes) == "table" then r.runes = packet.runes end
    end

    local function buildPath(points)
        local path, total = {}, 0
        for index, p in ipairs(points) do
            if index > 1 then total = total + math.sqrt((p.x - points[index - 1].x) ^ 2 + (p.y - points[index - 1].y) ^ 2) end
            path[index] = {x = p.x, y = p.y, s = total}
        end
        return path
    end

    local function towerPositions()
        if not state.towerPos then
            state.towerPos = {}
            local saved = call(JSON.decode, JSON, savedGet("towers"))
            if type(saved) == "table" then
                for name, t in pairs(saved) do
                    if type(t) == "table" and finite(t.x) and finite(t.y) then state.towerPos[name] = t end
                end
            end
        end
        return state.towerPos
    end

    local function lanePaths()
        local t, count = {}, 0
        for _, tower in pairs(towerPositions()) do t[tower.team .. tower.lane .. tower.tier] = tower; count = count + 1 end
        if state.lanePaths and state.lanePathsFrom == count then return state.lanePaths end
        local paths = {}
        for _, lane in ipairs({"top", "mid", "bot"}) do
            local g1, g2, g3 = t["2" .. lane .. "1"], t["2" .. lane .. "2"], t["2" .. lane .. "3"]
            local b1, b2, b3 = t["3" .. lane .. "1"], t["3" .. lane .. "2"], t["3" .. lane .. "3"]
            if g1 and g2 and g3 and b1 and b2 and b3 then
                local points = {g3, g2, g1}
                if lane == "top" then points[#points + 1] = {x = g1.x, y = b1.y}
                elseif lane == "bot" then points[#points + 1] = {x = b1.x, y = g1.y} end
                for _, p in ipairs({b1, b2, b3}) do points[#points + 1] = p end
                paths[lane] = buildPath(points)
            end
        end
        state.lanePaths, state.lanePathsFrom = paths, count
        return paths
    end

    local function project(path, x, y)
        local bestS, bestD
        for index = 2, #path do
            local a, b = path[index - 1], path[index]
            local dx, dy = b.x - a.x, b.y - a.y
            local len2 = dx * dx + dy * dy
            local k = len2 > 0 and math.max(0, math.min(1, ((x - a.x) * dx + (y - a.y) * dy) / len2)) or 0
            local d = (x - a.x - dx * k) ^ 2 + (y - a.y - dy * k) ^ 2
            if not bestD or d < bestD then bestD, bestS = d, a.s + (b.s - a.s) * k end
        end
        return bestS, bestD and math.sqrt(bestD)
    end

    local function along(path, s)
        s = math.max(0, math.min(path[#path].s, s))
        for index = 2, #path do
            local a, b = path[index - 1], path[index]
            if s <= b.s then
                local k = b.s > a.s and (s - a.s) / (b.s - a.s) or 0
                return a.x + (b.x - a.x) * k, a.y + (b.y - a.y) * k
            end
        end
        return path[#path].x, path[#path].y
    end

    local function laneOf(paths, x, y)
        local best, bestS, bestD
        for lane, path in pairs(paths) do
            local s, d = project(path, x, y)
            if s and d < 1500 and (not bestD or d < bestD) then best, bestS, bestD = lane, s, d end
        end
        return best, bestS
    end

    local WAVE_SPEED, WAVE_PERIOD = 325, 30

    local function hiddenPoint(x, y)
        local okz, z = pcall(World.GetGroundZ, x, y)
        local okv, point = pcall(Vector, x, y, okz and finite(z) and z or 128)
        if not okv or not point then return true end
        local okf, seen = pcall(FogOfWar.IsPointVisible, point)
        return not (okf and seen == true)
    end

    -- Creep waves in fog: every 30 s each barracks sends a wave that walks
    -- its lane at 325 until it meets the opposing wave. The meeting point
    -- comes from visible creeps when there are any, else the lane middle,
    -- and never passes the first alive enemy tower.
    local function simulateWaves(visible, alive, gt, out)
        local paths = lanePaths()
        if gt < 0 or not next(paths) then return end
        local m = state.mem
        m.front = m.front or {}
        local seen, limits = {}, {}
        for _, u in ipairs(visible) do
            local lane, s = laneOf(paths, u.x, u.y)
            if lane then
                local f = seen[lane] or {}
                seen[lane] = f
                if u.team == 2 then f.r = math.max(f.r or -math.huge, s) else f.d = math.min(f.d or math.huge, s) end
            end
        end
        for name, tower in pairs(towerPositions()) do
            local path = alive[name] and paths[tower.lane]
            if path then
                local s = project(path, tower.x, tower.y)
                local limit = limits[tower.lane] or {}
                limits[tower.lane] = limit
                if tower.team == 3 then limit.r = math.min(limit.r or math.huge, s - 500)
                else limit.d = math.max(limit.d or -math.huge, s + 500) end
            end
        end
        for lane, path in pairs(paths) do
            local length = path[#path].s
            local front = m.front[lane]
            local current = front and gt - front.at < 90 and front.s or length / 2
            local f = seen[lane]
            if f and f.r and f.d and f.d - f.r < 1500 then front = {s = (f.r + f.d) / 2, at = gt}
            elseif f and f.r and f.r > current then front = {s = f.r + 150, at = gt}
            elseif f and f.d and f.d < current then front = {s = f.d - 150, at = gt} end
            m.front[lane] = front
            local meet = front and gt - front.at < 90 and front.s or length / 2
            local limit = limits[lane]
            if limit and limit.r then meet = math.min(meet, limit.r) end
            if limit and limit.d then meet = math.max(meet, limit.d) end
            for team = 2, 3 do
                local dir = team == 2 and 1 or -1
                local start = team == 2 and -400 or length + 400
                local stop = meet - dir * 150
                local arrived, newest = false, math.floor(gt / WAVE_PERIOD)
                local function emit(s, key)
                    local x, y = along(path, s)
                    local nx, ny = along(path, s + dir * 60)
                    local dx, dy = nx - x, ny - y
                    local len = math.sqrt(dx * dx + dy * dy)
                    for _, u in ipairs(visible) do
                        if u.team == team and (u.x - x) ^ 2 + (u.y - y) ^ 2 < 900 ^ 2 then return end
                    end
                    if not hiddenPoint(x, y) then return end
                    out[#out + 1] = {id = "w" .. lane .. team .. key, kind = "wave", team = team, x = round(x), y = round(y),
                        dx = len > 0 and round(dx / len * 100) or 0, dy = len > 0 and round(dy / len * 100) or 0, f = 2}
                end
                for k = math.max(0, newest - 6), newest do
                    local s = start + dir * WAVE_SPEED * (gt - k * WAVE_PERIOD)
                    if (s - stop) * dir >= 0 then arrived = true
                    elseif s > 0 and s < length then emit(s, k) end
                end
                if arrived then emit(stop, "f") end
            end
        end
    end

    local function roshanPits(v, gt, objective)
        local pits = state.roshPits
        if not pits then
            pits = call(JSON.decode, JSON, savedGet("rosh_pits"))
            pits = type(pits) == "table" and pits or {}
            state.roshPits = pits
        end
        local day = v.clock.day == false and "night" or "day"
        local rosh
        for index = #v.units, 1, -1 do
            if v.units[index].kind == "roshan" then rosh = rosh or v.units[index]; table.remove(v.units, index) end
        end
        local m = state.mem
        if rosh and rosh.f == 0 then
            local still = m.roshStill
            if still and (rosh.x - still.x) ^ 2 + (rosh.y - still.y) ^ 2 < 150 ^ 2 then
                local pit = pits[day]
                if gt - still.since >= 5 and (type(pit) ~= "table" or (pit.x - rosh.x) ^ 2 + (pit.y - rosh.y) ^ 2 > 600 ^ 2) then
                    pits[day] = {x = rosh.x, y = rosh.y}
                    savedSet("rosh_pits", call(JSON.encode, JSON, pits) or "")
                end
            else m.roshStill = {x = rosh.x, y = rosh.y, since = gt} end
        end
        for key, pit in pairs(pits) do
            if type(pit) == "table" and finite(pit.x) and finite(pit.y) then
                v.units[#v.units + 1] = {id = "pit" .. key, kind = "rpit", x = round(pit.x), y = round(pit.y), f = 1}
            end
        end
        local alive = rosh ~= nil or type(objective) == "table" and objective.alive == true
        if rosh and rosh.f == 0 then v.units[#v.units + 1] = rosh
        elseif alive then
            local pit = pits[day]
            if type(pit) == "table" and finite(pit.x) then
                v.units[#v.units + 1] = {id = "rosh", kind = "roshan", x = round(pit.x), y = round(pit.y), f = 1}
            elseif rosh then v.units[#v.units + 1] = rosh end
        end
    end

    function relay.heroInfo(h, d, offset)
        local mask = (state.flags.modifiers and 16 or 0) + (state.flags.items and 1 or 0) + (state.flags.abilities and 2 or 0)
            + (state.flags.stats and 4 or 0) + (state.flags.buybacks and 8 or 0)
        local tracked = state.kills_by[h.id]
        local k, deaths = tracked and tracked.k, tracked and tracked.d
        local cache = state.infoCache[h.id]
        if cache and cache.detail == d and cache.offset == offset and cache.k == k and cache.deaths == deaths
            and cache.team == state.localTeam and cache.name == h.name and cache.mask == mask then return cache.value end
        local function readyAt(observed, remaining)
            return finite(remaining) and remaining > 0.5 and round(observed + remaining + offset) or nil
        end
        local info = {items = {}, abilities = {}, mods = {}, seen_at = finite(d.game) and round(d.game + offset) or nil}
        for index, modifier in ipairs(state.flags.modifiers and d.modifiers or {}) do
            if index>24 then break end
            if type(modifier.name)=="string" then info.mods[#info.mods+1]={name=modifier.name,
                ends_at=finite(modifier.die_time) and modifier.die_time>0 and round(modifier.die_time+offset) or nil,stacks=modifier.stacks} end
        end
        for _, item in ipairs(state.flags.items and d.items or {}) do
            if finite(item.slot) and item.name and (item.slot < 9 or item.slot == 15 or item.slot == 16) then
                info.items[#info.items + 1] = {slot = item.slot, name = item.name, ready_at = readyAt(item.observed_at or d.game, item.cooldown),
                    charges = finite(item.charges) and item.charges > 0 and item.charges or nil,
                    o = item.stale == true and 1 or nil, seen_at=finite(item.observed_at) and round(item.observed_at+offset) or nil}
            end
        end
        table.sort(info.items, function(a, b) return a.slot < b.slot end)
        local own = tostring(h.name or ""):gsub("^npc_dota_hero_", "") .. "_"
        for _, ability in ipairs(state.flags.abilities and d.abilities or {}) do
            local name = ability.name
            if type(name) == "string" and ability.hidden ~= true and name:find(own, 1, true) == 1 and #info.abilities < 8 then
                info.abilities[#info.abilities + 1] = {name = name, level = ability.level or 0,
                    ready_at = readyAt(ability.observed_at or d.game, ability.cooldown), ult = ability.ultimate == true or nil,
                    charges = finite(ability.charges) and ability.charges > 0 and ability.charges or nil}
            end
            if ability.ultimate == true and finite(ability.level) and ability.level > 0 and not info.ult then
                info.ult = {name = name, level = ability.level, ready_at = readyAt(ability.observed_at or d.game, ability.cooldown)}
            end
        end
        if state.flags.stats and type(d.attr) == "table" then
            local a = d.attr
            info.attr = {s = round(a.str), g = round(a.agi), i = round(a.int), p = a.primary, dmg = round(a.dmg), dmx = round(a.dmg_max),
                aps = finite(a.aps) and math.floor(a.aps * 100 + 0.5) / 100 or nil, rng = round(a.range),
                arm = finite(a.armor) and math.floor(a.armor * 10 + 0.5) / 10 or nil, mr = round(a.mres), ms = round(a.ms),
                hpr = finite(a.hpr) and math.floor(a.hpr * 10 + 0.5) / 10 or nil, mpr = finite(a.mpr) and math.floor(a.mpr * 10 + 0.5) / 10 or nil,
                xp = round(a.xp)}
        end
        if type(d.playerName) == "string" and d.playerName ~= "" then info.pn = d.playerName end
        if state.flags.stats and type(d.stats) == "table" then
            info.stats = {k = d.stats.kills, d = d.stats.deaths, a = d.stats.assists,
                nw = round(d.stats.networth), partial = d.stats.networth_partial == true or nil,
                lh = d.stats.lasthits, dn = d.stats.denies}
            if info.stats.k == nil and tracked then info.stats.k, info.stats.d, info.stats.est = tracked.k, tracked.d, 1 end
            local pd = d.playerData
            if type(pd) == "table" then
                info.stats.dmg = finite(pd.hero_damage) and pd.hero_damage > 0 and pd.hero_damage or nil
                info.stats.heal = finite(pd.healing) and pd.healing > 0 and round(pd.healing) or nil
                info.stats.obs = finite(pd.observer_wards_placed) and pd.observer_wards_placed > 0 and pd.observer_wards_placed or nil
                info.stats.sen = finite(pd.sentry_wards_placed) and pd.sentry_wards_placed > 0 and pd.sentry_wards_placed or nil
                info.stats.stk = finite(pd.camps_stacked) and pd.camps_stacked > 0 and pd.camps_stacked or nil
            end
            if (h.team == state.localTeam or state.localTeam == 1) and type(pd) == "table" and (finite(pd.reliable_gold) or finite(pd.unreliable_gold)) then
                info.stats.g = round((finite(pd.reliable_gold) and pd.reliable_gold or 0) + (finite(pd.unreliable_gold) and pd.unreliable_gold or 0))
            end
        end
        if state.flags.buybacks and type(d.buyback) == "table" and finite(d.buyback.cooldown) then
            info.buyback = {ready_at = readyAt(d.game, d.buyback.cooldown) or 0}
        end
        state.infoCache[h.id] = {detail=d, offset=offset, k=k, deaths=deaths, team=state.localTeam,
            name=h.name, mask=mask, value=info}
        return info
    end

    function relay.view(packet, due)
        local gt = packet.game_time or 0
        local now = packet.game_clock or gt
        local offset = gt - now
        local v = {clock = {t = round(gt) or 0, ms = finite(gt) and math.floor(gt * 100 + 0.5) / 100 or nil, in_game = packet.in_game == true, team = packet.local_team, spec = packet.spectator or nil, paused = packet.paused == true}}
        if not packet.in_game then return v end
        local tod = call(GameRules.GetTimeOfDay)
        if finite(tod) then v.clock.day = tod >= 0.25 and tod < 0.75 end
        local cycle = call(GameRules.GetNextCycleTime)
        if finite(cycle) and cycle >= 0 then v.clock.cyc = round(gt + cycle) end
        if call(GameRules.IsNightstalkerNight) == true then v.clock.ns = true end
        local m = state.mem
        local function at(t)
            return finite(t) and round(t + offset) or nil
        end
        v.pos = {}
        if due.info then v.info = {} end
        for _, h in ipairs(packet.heroes or {}) do
            if finite(h.x) and finite(h.y) then
                local fog = h.visible == true and 0 or (h.source == "maphack_last" or h.source == "innate_trace") and 1 or 2
                v.pos[#v.pos + 1] = {id = h.id, name = h.name, team = h.team, x = round(h.x), y = round(h.y), f = fog,
                    seen = fog > 0 and at(h.position_observed_at) or nil,
                    hp = round(h.hp), max_hp = round(h.max_hp), mana = round(h.mana), max_mana = round(h.max_mana),
                    alive = h.alive, level = h.level, me = h["local"] == true or nil,
                    tp = type(h.teleport) == "table" and at(h.teleport.ends_at) or nil,
                    respawn_at = h.alive == false and finite(h.respawn) and h.respawn > 0 and round(gt + h.respawn) or nil}
                local d = due.info and state.details[h.id]
                if d and finite(d.game) then
                    local info = relay.heroInfo(h, d, offset)
                    v.info["h" .. h.id] = info
                end
            end
        end
        table.sort(v.pos, byId)
        local r = state.relay
        if due.units then
        v.units = {}
        local visible, alive = {}, {}
        for _, u in pairs(r.units) do
            if u.alive ~= false and finite(u.x) and finite(u.y) then
                local row = {id = u.id, kind = u.kind, team = u.team, x = round(u.x), y = round(u.y), f = u.visible == true and 0 or 1}
                if u.kind == "wisdom" then row.a = u.active == true and 1 or u.active == false and 0 or nil end
                if u.kind == "bear" and finite(u.hp) and finite(u.max_hp) and u.max_hp > 0 then row.hp = round(u.hp / u.max_hp * 100) end
                if u.kind == "building" then
                    local name = tostring(u.name or "")
                    row.b = name:find("_fort", 1, true) and "fort" or name:find("watch_tower", 1, true) and "out" or name:find("_rax_", 1, true) and "rax" or name:match("tower(%d)") and "t" .. name:match("tower(%d)") or nil
                end
                if u.kind == "building" then
                    local key = tostring(u.name or ""):gsub("^npc_dota_", "")
                    local tier, lane = key:match("tower(%d)_(%a+)$")
                    if tier then
                        local towers = towerPositions()
                        if not towers[key] then
                            towers[key] = {x = round(u.x), y = round(u.y), team = u.team, tier = tonumber(tier), lane = lane}
                            local count = 0
                            for _ in pairs(towers) do count = count + 1 end
                            if count >= 18 then savedSet("towers", call(JSON.encode, JSON, towers) or "") end
                        end
                        alive[key] = true
                    end
                    if finite(u.hp) and finite(u.max_hp) and u.max_hp > 0 then row.hp = round(u.hp / u.max_hp * 100) end
                end
                if u.kind == "creep" then
                    row.s = tostring(u.name or ""):find("siege", 1, true) and 1 or nil
                    if u.visible == true then
                        visible[#visible + 1] = u
                        v.units[#v.units + 1] = row
                    end
                elseif u.kind ~= "illusion" or u.visible == true then
                    v.units[#v.units + 1] = row
                end
            end
        end
        if state.flags.prediction ~= false then simulateWaves(visible, alive, gt, v.units) end
        roshanPits(v, gt, packet.objectives and packet.objectives.roshan)
        table.sort(v.units, byId)
        end
        if due.wards then
        v.wards = {}
        for _, w in ipairs(r.wards or {}) do
            if finite(w.x) and finite(w.y) then
                v.wards[#v.wards + 1] = {id = w.id, kind = w.kind, team = w.team, x = round(w.x), y = round(w.y),
                    f = w.visible == true and 0 or 1, r = round(w.radius), e = at(w.expires_at)}
            end
        end
        table.sort(v.wards, byId)
        end
        if due.runes then
        v.runes = {}
        for _, rune in ipairs(r.runes or {}) do
            if finite(rune.x) and finite(rune.y) then
                v.runes[#v.runes + 1] = {id = rune.id, x = round(rune.x), y = round(rune.y), rune_type = rune.rune_type,
                    f = rune.visible == true and 0 or 1}
            end
        end
        table.sort(v.runes, byId)
        end
        if due.camps then
        v.camps = {}
        for _, c in ipairs(state.camps or {}) do
            if finite(c.x) and finite(c.y) then
                v.camps[#v.camps + 1] = {x = round(c.x), y = round(c.y), t = c.camp_type,
                    s = c.state == "occupied" and 1 or c.state == "empty" and 0 or nil,
                    n = c.count, st = finite(c.stack_count) and c.stack_count > 1 and c.stack_count or nil}
            end
        end
        end
        v.events = {}
        for _, e in ipairs(packet.events or {}) do
            if finite(e.x) and finite(e.y) then
                local destination = e.kind == "teleport" and e.phase == "destination"
                v.events[#v.events + 1] = {id = e.id, kind = e.kind, x = round(e.x), y = round(e.y), a = e.ability_name,
                    h = e.owner_name, team = e.team, f = e.stale == true and 1 or nil, ph = e.phase,
                    ox = destination and round(e.origin_x) or nil, oy = destination and round(e.origin_y) or nil,
                    t0 = at(e.started), te = at(e.channel_end_at)}
            end
        end
        table.sort(v.events, byId)
        if not due.objectives then return v end
        local o = packet.objectives or {}
        v.objectives = {tormentors = {}}
        for _, key in ipairs({"glyph_radiant", "glyph_dire", "scan_radiant", "scan_dire"}) do
            if finite(o[key]) then v.objectives[key] = o[key] > 0.5 and round(gt + o[key]) or 0 end
        end
        if type(o.roshan) == "table" and o.roshan.stale ~= true and o.roshan.source == "entity" then v.objectives.roshan = boss(o.roshan) end
        v.objectives.scan_charges = {r = call(GameRules.GetGoodScanCharges), d = call(GameRules.GetBadScanCharges)}
        local function stock(team)
            return {smoke = call(GameRules.GetStockCount, 188, team), obs = call(GameRules.GetStockCount, 42, team),
                sen = call(GameRules.GetStockCount, 43, team)}
        end
        if state.localTeam == 1 then
            v.objectives.stock, v.objectives.stock_dire = stock(2), stock(3)
        else v.objectives.stock = stock(state.localTeam) end
        for _, t in ipairs(o.tormentors or {}) do
            if t.stale ~= true then v.objectives.tormentors[#v.objectives.tormentors + 1] = boss(t) end
        end
        return v
    end

    local function sideOf(team)
        local lt = state.localTeam
        if (team ~= 2 and team ~= 3) or (lt ~= 2 and lt ~= 3) then return "n" end
        return team == lt and "a" or "e"
    end

    local function place(x, y)
        if not finite(x) or not finite(y) then return nil end
        local m = state.mem
        if m.rosh and (x - m.rosh.x) ^ 2 + (y - m.rosh.y) ^ 2 < 1800 ^ 2 then return "rosh" end
        for _, t in ipairs(m.torm or {}) do
            if (x - t.x) ^ 2 + (y - t.y) ^ 2 < 1500 ^ 2 then return "torm" end
        end
        local tower, best = nil, 1100 ^ 2
        for _, t in pairs(towerPositions()) do
            local d = (x - t.x) ^ 2 + (y - t.y) ^ 2
            if d < best then tower, best = t, d end
        end
        if tower then return "t" .. (tower.team == 2 and "r" or "d") .. tower.tier .. "_" .. tower.lane end
        local s, d = x + y, y - x
        if s < -9800 then return "base_r" end
        if s > 9800 then return "base_d" end
        local zone = math.abs(d) < 3000 and "mid" or (d > 0 and "top" or "bot")
        local side = s < -3500 and "r" or (s > 3500 and "d" or "c")
        return zone .. "_" .. side
    end

    local function log(entry)
        state.feedSeq = state.feedSeq + 1
        entry.t, entry.key = state.mem.gt or 0, string.format("e%010d%05d", state.feedBase or 0, state.feedSeq)
        state.feedRevisions[entry] = 1
        state.feedQueue[#state.feedQueue + 1] = entry
        while #state.feedQueue > 200 do table.remove(state.feedQueue, 1) end
        return entry
    end

    local function requeue(entry)
        state.feedRevisions[entry] = (state.feedRevisions[entry] or 0) + 1
        for _, queued in ipairs(state.feedQueue) do if queued == entry then return end end
        state.feedQueue[#state.feedQueue + 1] = entry
        while #state.feedQueue > 200 do table.remove(state.feedQueue, 1) end
    end

    local function addScanPlace(where)
        local scan = state.mem.scan
        if not where or scan.places[where] then return end
        scan.places[where] = true
        scan.entry.p = scan.entry.p and (scan.entry.p .. "," .. where) or where
        requeue(scan.entry)
    end

    local function trackBoss(key, kind, info, side)
        local m = state.mem
        m.boss = m.boss or {}
        local b = m.boss[key] or {atk = false, last = 0}
        m.boss[key] = b
        local alive, pct = info.alive, info.hp
        local attackers = #info.attackers > 0 and info.attackers or nil
        if alive == false and b.alive == true then
            log({k = "boss_dead", b = kind, team = side})
            b.atk = false
        elseif alive == true and b.alive == false then
            log({k = "boss_up", b = kind, team = side})
        end
        if alive ~= nil then b.alive = alive end
        local attacking = info.under_attack == true and alive ~= false
        if attacking and not b.atk then
            log({k = "boss_hit", b = kind, team = side, v = pct, n = attackers})
            b.atk, b.pct = true, pct
        elseif attacking and pct and b.pct and b.pct - pct >= 15 then
            log({k = "boss_hp", b = kind, team = side, v = pct, n = attackers})
            b.pct = pct
        end
        if attacking then b.last = m.gt
        elseif b.atk and m.gt - b.last > 6 and alive ~= false then
            log({k = "boss_calm", b = kind, team = side, v = pct})
            b.atk = false
        end
    end

    local function campAt(x, y)
        for _, camp in ipairs(state.campDefs or {}) do
            if x >= camp.min_x - 220 and x <= camp.max_x + 220 and y >= camp.min_y - 220 and y <= camp.max_y + 220 then return camp.id end
        end
    end

    function relay.derive(packet, v)
        if not packet.in_game then state.mem = {}; return end
        local m = state.mem
        m.gt = v.clock.t
        local obj = v.objectives
        if obj then
            if obj.roshan and obj.roshan.x then m.rosh = {x = obj.roshan.x, y = obj.roshan.y} end
            local torm = {}
            for _, t in ipairs(obj.tormentors) do if t.x then torm[#torm + 1] = {x = t.x, y = t.y} end end
            if #torm > 0 then m.torm = torm end
            if obj.roshan then trackBoss("rosh", "rosh", obj.roshan) end
            for _, t in ipairs(obj.tormentors) do
                trackBoss("torm" .. tostring(t.id), "torm", t, t.x and (t.x + t.y < 0 and "r" or "d") or nil)
            end
        end

        m.h, m.runeLog, m.runes, m.ev, m.cd = m.h or {}, m.runeLog or {}, m.runes or {}, m.ev or {}, m.cd or {}
        local heroes, seenNow = {}, {}
        for _, h in ipairs(v.pos) do
            heroes[h.id] = h
            if h.f == 0 then seenNow[#seenNow + 1] = h end
            local hm = m.h[h.id] or {}
            m.h[h.id] = hm
            if h.alive == false and hm.alive == true then
                log({k = "death", s = sideOf(h.team), h = h.name, r = h.respawn_at and math.max(0, h.respawn_at - m.gt) or nil})
            end
            if h.alive ~= nil then hm.alive = h.alive end
            local enemy = sideOf(h.team) == "e" and h.alive ~= false
            if enemy and h.f == 1 and h.seen and m.gt - h.seen <= 3 and h.seen ~= hm.spotSeen then
                hm.spotSeen = h.seen
                local far = not hm.spotX or (h.x - hm.spotX) ^ 2 + (h.y - hm.spotY) ^ 2 >= 800 ^ 2
                if far and m.gt - (hm.spotAt or -99) >= 15 then
                    log({k = "spot", s = "e", h = h.name, p = place(h.x, h.y)})
                    hm.spotAt, hm.spotX, hm.spotY = m.gt, h.x, h.y
                end
            end
            local camp = enemy and h.f == 1 and campAt(h.x, h.y)
            if camp then
                if hm.camp ~= camp then hm.camp, hm.campAt, hm.campLogged = camp, m.gt, false
                elseif not hm.campLogged and m.gt - hm.campAt >= 2 then
                    hm.campLogged = true
                    log({k = "farm", s = "e", h = h.name, p = place(h.x, h.y)})
                end
            elseif h.f ~= 1 or not enemy then hm.camp = nil end
            local d = state.details[h.id]
            if h.f == 0 and d and type(d.modifiers) == "table" and d.game ~= hm.modsAt then
                hm.modsAt = d.game
                local mods = {}
                for _, mod in ipairs(d.modifiers) do if mod.name then mods[mod.name] = true end end
                if hm.mods then
                    for name in pairs(mods) do
                        if RUNE_MODS[name] and not hm.mods[name] and m.gt - (m.runeLog[h.id] or -99) > 3 then
                            log({k = "rune", s = sideOf(h.team), h = h.name, a = RUNE_MODS[name]})
                            m.runeLog[h.id] = m.gt
                        end
                    end
                end
                hm.mods = mods
            end
        end

        local current = {}
        if v.runes then
        for _, rune in ipairs(v.runes) do
            if rune.f == 0 then
                current[rune.id] = true
                m.runes[rune.id] = {x = rune.x, y = rune.y, kind = rune.rune_type}
            end
        end
        for id, prev in pairs(m.runes) do
            if not current[id] then
                local near, best = nil, 450 ^ 2
                for _, h in ipairs(seenNow) do
                    if h.alive ~= false then
                        local dist = (h.x - prev.x) ^ 2 + (h.y - prev.y) ^ 2
                        if dist < best then near, best = h, dist end
                    end
                end
                if near and m.gt - (m.runeLog[near.id] or -99) > 3 then
                    log({k = "rune", s = sideOf(near.team), h = near.name, a = prev.kind, p = place(prev.x, prev.y)})
                    m.runeLog[near.id] = m.gt
                end
                m.runes[id] = nil
            end
        end
        end

        m.wardSeen = m.wardSeen or {}
        local firstWards = not m.wardInit
        if v.wards then m.wardInit = true end
        for _, w in ipairs(v.wards or {}) do
            if not m.wardSeen[w.id] then
                m.wardSeen[w.id] = true
                if not firstWards and w.f == 0 and sideOf(w.team) == "e" then
                    log({k = "ward", s = "e", w = w.kind == "sentry" and "s" or "o", p = place(w.x, w.y)})
                end
            end
        end

        for _, kill in ipairs(state.kills) do
            log({k = kill.barracks and "rax" or "tower", team = kill.team == 2 and "r" or kill.team == 3 and "d" or nil,
                s = sideOf(kill.team), p = place(kill.x, kill.y)})
        end
        state.kills = {}

        m.recent = m.recent or {}
        for key, at in pairs(m.recent) do if m.gt - at > 4 or at > m.gt then m.recent[key] = nil end end
        local function fresh(key)
            if m.recent[key] then return false end
            m.recent[key] = m.gt
            return true
        end
        for _, e in ipairs(packet.events or {}) do
            if e.id and finite(e.x) and finite(e.y) and not m.ev[e.id] then
                m.ev[e.id] = m.gt
                local owner = e.owner_id and heroes[e.owner_id]
                local name = owner and owner.name or (tostring(e.owner_name or ""):find("npc_dota_hero_", 1, true) == 1 and e.owner_name) or nil
                local entry = {s = sideOf(owner and owner.team or e.team), h = name, p = place(e.x, e.y), x=round(e.x), y=round(e.y)}
                if e.kind == "teleport" then
                    entry.k = e.phase == "destination" and "tp_to" or "tp_from"
                    if fresh(entry.k .. tostring(e.owner_id or name)) then log(entry) end
                elseif e.kind == "scan" then
                    if m.scan and m.gt - m.scan.at <= 4 then addScanPlace(entry.p)
                    else m.scan = {entry = log({k = "scan", p = entry.p}), at = m.gt, places = {[entry.p or ""] = true}} end
                elseif e.kind == "smoke" then
                    entry.k = "smoke"
                    log(entry)
                elseif e.kind == "blink" then
                    if e.phase ~= "origin" then entry.k = "blink"; log(entry) end
                elseif e.kind ~= "innate" then
                    entry.k, entry.a = e.ultimate == true and "ult" or "ability", e.ability_name or e.name
                    if fresh("a" .. tostring(e.owner_id or name) .. tostring(entry.a)) then log(entry) end
                end
            end
        end
        for id, at in pairs(m.ev) do
            if m.gt - at > 120 or at > m.gt then m.ev[id] = nil end
        end

        for _, key in ipairs(obj and {"glyph_radiant", "glyph_dire", "scan_radiant", "scan_dire"} or {}) do
            local value = obj[key]
            if value then
                local prev = m.cd[key]
                if prev and value > prev + 30 and value - m.gt > 100 then
                    local team = key:find("radiant", 1, true) and "r" or "d"
                    if key:find("glyph", 1, true) then log({k = "glyph", team = team})
                    elseif not (m.scan and m.gt - m.scan.at <= 4) then
                        m.scan = {entry = log({k = "scan_used", team = team}), at = m.gt, places = {}}
                    end
                end
                m.cd[key] = value
            end
        end
    end

    function relay.build(packet, due)
        if packet.in_game and packet.match ~= state.relayMatch then
            state.relayMatch, state.mem, state.feedQueue, state.clearFeed = packet.match, {}, {}, true
            state.feedKeys, state.feedPrune = {}, {}
            state.feedEpoch = state.feedEpoch + 1
            state.feedRevisions = setmetatable({}, {__mode = "k"})
            state.relay = {units = {}, wards = {}, runes = {}}
            for key in pairs(mode().parts) do due[key] = true end
            state.resendAll = true
            savedSet("match", tostring(packet.match))
        end
        relay.merge(packet)
        local v = relay.view(packet, due)
        relay.derive(packet, v)
        for _, key in ipairs({"units", "wards", "runes", "events"}) do if v[key] then strip(v[key]) end end
        return v
    end

    -- Views handed to the codec are immutable. Weak keys release encodings
    -- when an old view is superseded; repeated sends never re-encode it.
    function relay.encode(value)
        local cache = state.encodedTables
        if not cache then cache = setmetatable({}, {__mode = "k"}); state.encodedTables = cache end
        local encoded = type(value) == "table" and cache[value] or nil
        if not encoded then
            encoded = call(JSON.encode, JSON, value)
            if type(encoded) ~= "string" then error("JSON encoding failed") end
            if type(value) == "table" then cache[value] = encoded end
        end
        return encoded
    end

    function relay.patch(view, withFeed)
        local began = clock()
        local fields, commit = {}, {}
        local receipt = {epoch = state.feedEpoch, entries = {}, prune = {}, considered = {}}
        local inGame = view.clock and view.clock.in_game
        for _, key in ipairs(PARTS) do
            if key == "info" and view.info ~= nil then
                local names, encodedInfo, members = {}, {}, {}
                for name in pairs(view.info) do
                    if type(name) ~= "string" or not name:match("^h%d+$") then error("invalid hero info key") end
                    names[#names + 1] = name
                end
                table.sort(names)
                for _, name in ipairs(names) do
                    encodedInfo[name] = relay.encode(view.info[name])
                    members[#members + 1] = '"' .. name .. '":' .. encodedInfo[name]
                end
                local encoded = "{" .. table.concat(members, ",") .. "}"
                receipt.considered.info = true
                if state.resendAll or not state.sentParts.info or state.sentParts.info == "null" then
                    fields[#fields + 1] = '"live/info":' .. encoded
                    commit.info, receipt.info = encoded, encodedInfo
                elseif state.sentParts.info ~= encoded then
                    for _, name in ipairs(names) do
                        if not state.sentInfo or state.sentInfo[name] ~= encodedInfo[name] then
                            fields[#fields + 1] = '"live/info/' .. name .. '":' .. encodedInfo[name]
                        end
                    end
                    for name in pairs(state.sentInfo or {}) do
                        if not encodedInfo[name] then fields[#fields + 1] = '"live/info/' .. name .. '":null' end
                    end
                    commit.info, receipt.info = encoded, encodedInfo
                end
            else
                local encoded
                if view[key] ~= nil then encoded = relay.encode(view[key])
                elseif not inGame then encoded = "null" end
                if encoded then receipt.considered[key] = true end
                if encoded and (state.resendAll or state.sentParts[key] ~= encoded) then
                    fields[#fields + 1] = '"live/' .. key .. '":' .. encoded
                    commit[key] = encoded
                end
            end
        end
        if withFeed then
            if state.clearFeed then
                fields[#fields + 1] = '"feed":null'
                receipt.clear = true
            else
                local sentKeys = {}
                for index, entry in ipairs(state.feedQueue) do
                    if index > 20 then break end
                    -- Entries can be amended while a request is in flight;
                    -- their versioned receipt, not identity, owns the encoding.
                    local encoded = call(JSON.encode, JSON, entry)
                    if type(encoded) ~= "string" then error("cannot encode feed entry") end
                    fields[#fields + 1] = '"feed/' .. entry.key .. '":' .. encoded
                    sentKeys[entry.key] = true
                    receipt.entries[#receipt.entries + 1] = {entry = entry, revision = state.feedRevisions[entry] or 0}
                end
                for _, key in ipairs(state.feedPrune) do
                    receipt.prune[key] = true
                    if not sentKeys[key] then fields[#fields + 1] = '"feed/' .. key .. '":null' end
                end
            end
        end
        local changed = #fields > 0
        fields[#fields + 1] = '"meta/updated":{".sv":"timestamp"}'
        state.perf.encode_ms = (clock() - began) * 1000
        return "{" .. table.concat(fields, ",") .. "}", commit, receipt, changed
    end

    -- Acknowledge precisely the versions serialized into the successful
    -- request. In-flight edits and entries added after dispatch stay queued.
    function relay.ackFeed(receipt)
        if receipt.epoch ~= state.feedEpoch then return end
        if receipt.clear then state.clearFeed = false; return end
        local prune = {}
        for _, key in ipairs(state.feedPrune) do
            if not receipt.prune[key] then prune[#prune + 1] = key end
        end
        state.feedPrune = prune
        local known, versions = {}, {}
        for _, key in ipairs(state.feedKeys) do known[key] = true end
        for _, sent in ipairs(receipt.entries) do
            versions[sent.entry] = sent.revision
            local key = sent.entry.key
            if not known[key] then
                known[key] = true
                state.feedKeys[#state.feedKeys + 1] = key
            end
        end
        local pending = {}
        for _, entry in ipairs(state.feedQueue) do
            if versions[entry] == nil or versions[entry] ~= (state.feedRevisions[entry] or 0) then
                pending[#pending + 1] = entry
            end
        end
        state.feedQueue = pending
        while #state.feedKeys > 100 do
            state.feedPrune[#state.feedPrune + 1] = table.remove(state.feedKeys, 1)
        end
    end

end

function script.OnScriptsLoaded()
    initMenu()
    local session = savedGet("session")
    if get(ui.enabled, false) and #session == 32 then start() end
end

local function traceHitch(frameBegan)
    local gap = frameBegan - (state.lastFrame or frameBegan)
    state.lastFrame = frameBegan
    local p = state.perf
    if gap < 0.5 then
        state.eventTime, p.http_ms, p.reply_ms, p.build_ms, p.frame_ms = 0, 0, 0, 0, 0
        return
    end
    local parts = {scan = p.scan_ms or 0, collect = p.collect_ms or 0, build = p.build_ms or 0, encode = p.encode_ms or 0,
        http = p.http_ms or 0, reply = p.reply_ms or 0, events = (state.eventTime or 0) * 1000, frame = p.frame_ms or 0}
    state.eventTime, p.http_ms, p.reply_ms, p.build_ms, p.frame_ms = 0, 0, 0, 0, 0
    local total, worst, worstMs = 0, "game", 0
    for name, ms in pairs(parts) do
        if name ~= "frame" then
            total = total + ms
            if ms > worstMs then worst, worstMs = name, ms end
        end
    end
    total = math.max(total, parts.frame)
    if worstMs < 100 then worst = "game" end
    state.hitch = {gap = gap, ms = total, part = worst}
    state.nextPerf = 0
    if get(ui.debug, false) and ai_bridge and ai_bridge.mcp_log then
        parts.gap_s, parts.lua_kb, parts.bytes = gap, math.floor(collectgarbage("count")), p.bytes
        parts.pending = #state.requests
        call(ai_bridge.mcp_log, "warn", "[NEXUS Radar] freeze", parts)
    end
end

-- Runtime engine: sampling, bounded staging, transport, and frame budgeting.
-- Game observations above this section retain the original API bindings.
runtime.parts = {"clock", "pos", "info", "units", "wards", "runes", "camps", "events", "objectives"}

function runtime.reset()
    runtime.epoch = (runtime.epoch or 0) + 1
    runtime.latest, runtime.versions, runtime.dirty = {}, {}, {}
    runtime.sampleAt, runtime.sampledAt, runtime.heartbeatAt = 0, nil, 0
    runtime.sampleError, runtime.playing, runtime.paused = nil, nil, nil
    runtime.pressureUntil = 0
    state.infoCache = {}
    state.encodedTables = setmetatable({}, {__mode = "k"})
end

function runtime.pollRequests(now)
    -- Callbacks may append new requests. Compact only the captured prefix,
    -- then retain newly appended unfinished requests without allocating a list.
    local list, count, keep = state.requests, #state.requests, 0
    for index = 1, count do
        local pending = list[index]
        if not pending.finished and now >= pending.deadline then pending.finish(nil, 0) end
        if not pending.finished then keep = keep + 1; list[keep] = pending end
    end
    local total = #list
    for index = count + 1, total do
        local pending = list[index]
        if not pending.finished then keep = keep + 1; list[keep] = pending end
    end
    for index = keep + 1, total do list[index] = nil end
end

function runtime.stage(view)
    if not view.clock.in_game then
        runtime.latest = {}
        for _, key in ipairs(runtime.parts) do
            runtime.versions[key] = (runtime.versions[key] or 0) + 1
            runtime.dirty[key] = true
        end
    end
    for _, key in ipairs(runtime.parts) do
        if view[key] ~= nil then
            runtime.latest[key] = view[key]
            runtime.versions[key] = (runtime.versions[key] or 0) + 1
            runtime.dirty[key] = true
        end
    end
    runtime.playing, runtime.paused = view.clock.in_game, view.clock.paused
end

function runtime.sample(now, playing)
    local due, full = {}, state.needFull or not runtime.latest.clock
    for key, interval in pairs(mode().parts) do
        if full or now >= (state.partAt[key] or 0) then
            due[key], state.partAt[key] = true, now + interval
        end
    end
    state.due = due
    local began = clock()
    local ok, packet = pcall(collect)
    state.perf.collect_ms = (clock() - began) * 1000
    if not ok then
        runtime.sampleError, runtime.sampleAt = true, now + 1
        state.needFull, state.resendAll = true, true
        show("cr_st_collect_fail", tostring(packet))
        return false
    end
    began = clock()
    local built, view = pcall(relay.build, packet, due)
    state.perf.build_ms = (clock() - began) * 1000
    if not built then
        runtime.sampleError, runtime.sampleAt = true, now + 1
        state.needFull, state.resendAll = true, true
        show("cr_st_collect_fail", tostring(view))
        return false
    end
    runtime.stage(view)
    runtime.sampleError, runtime.sampledAt = nil, now
    local md, interval = mode()
    if not playing then interval = 2
    elseif view.clock.paused and state.flags.pause_eco ~= false then interval = 0.5
    elseif md.turbo then interval = state.upload and 0.1 or 0
    else interval = 1 / md.hz end
    if state.failures > 0 then interval = math.max(interval, 0.5) end
    local prior = runtime.sampleAt or 0
    runtime.sampleAt = interval == 0 and now or (now - prior > interval and now + interval or prior + interval)
    return true
end

function runtime.retryDelay(code, response)
    local delay = math.min(8, 0.5 * 2 ^ state.failures)
    if code == 429 and type(response) == "table" then
        local headers, seconds = response.headers
        if type(headers) == "table" then
            seconds = tonumber(headers["Retry-After"] or headers["retry-after"])
        elseif type(headers) == "string" then
            seconds = tonumber(headers:lower():match("retry%-after:%s*(%d+)"))
        end
        if finite(seconds) then delay = math.max(delay, math.min(60, math.max(0, seconds))) end
    end
    return delay
end

function runtime.reply(upload, commit, receipt, code, response)
    if state.upload == upload then state.upload = nil end
    local waiting = state.afterUpload
    state.afterUpload = nil
    if waiting then waiting() end
    if state.requestId ~= upload.controlEpoch or not state.inflight[upload.serial] then return end
    state.inflight[upload.serial] = nil
    if state.feedOwner == upload.serial then state.feedOwner = nil end
    if code >= 200 and code < 300 then
        -- A match may have changed while this request was outstanding.
        if upload.epoch ~= runtime.epoch then state.resendAll = true; return end
        for key, encoded in pairs(commit) do
            state.sentParts[key] = encoded
            if runtime.versions[key] == upload.versions[key] then runtime.dirty[key] = nil end
        end
        if receipt.info then state.sentInfo = receipt.info end
        if commit.info == "null" then state.sentInfo = {} end
        relay.ackFeed(receipt)
        state.resendAll, state.failures = false, 0
        local replied, perf = clock(), state.perf
        perf.upload_ms = math.max(0, (replied - upload.at) * 1000)
        perf.uploads = (perf.uploads or 0) + 1
        local elapsed = replied - (perf.rateAt or upload.at)
        if elapsed >= 1 then
            perf.actualRate = perf.uploads / elapsed
            perf.uploads, perf.rateAt = 0, replied
        end
        runtime.heartbeatAt = replied + 2
        show(runtime.playing and "cr_st_running" or "cr_st_waiting")
    else
        state.failures = math.min(state.failures + 1, 6)
        state.resendAll = true
        state.nextSend = clock() + runtime.retryDelay(code, response)
        if (code == 401 or code == 403) and state.fb.token == upload.token then state.fb.token = nil end
        if (code == 403 and state.failures >= 3) or code == 400 or code == 404 then state.active = false end
        if code ~= 0 or state.failures >= 3 then show("cr_st_send_fail", code) end
    end
end

function runtime.send(now)
    if state.upload or now + 0.000001 < state.nextSend or runtime.sampleError or not runtime.latest.clock then return end
    local md = mode()
    local period
    if not runtime.playing then period = 2
    elseif runtime.paused and state.flags.pause_eco ~= false then period = 0.5
    elseif md.turbo then period = 0
    else period = 1 / md.rate end
    -- A collection rate lower than the upload rate does not create duplicate
    -- packets. Idle and paused snapshots use the same two-second heartbeat.
    state.nextSend = period == 0 and now or (now - state.nextSend > period and now + period or state.nextSend + period)
    local view = {clock = runtime.latest.clock}
    for _, key in ipairs(runtime.parts) do
        if state.resendAll or runtime.dirty[key] then view[key] = runtime.latest[key] end
    end
    local ok, body, commit, receipt, changed = pcall(relay.patch, view, true)
    if not ok then
        state.resendAll, state.nextSend = true, now + 1
        show("cr_st_encode_fail", tostring(body))
        return
    end
    for key in pairs(receipt.considered) do
        if not commit[key] then runtime.dirty[key] = nil end
    end
    if not changed and now < (runtime.heartbeatAt or 0) then return end
    state.sequence = (state.sequence or 0) + 1
    local quality={work_ms=math.floor((state.perf.work_ms or 0)*100)/100,
        upload_ms=math.floor(state.perf.upload_ms or 0),bytes=state.perf.bytes or 0}
    local extra=string.format(',"live/schema":2,"live/seq":%d,"live/matchId":%s,"live/quality":%s',
        state.sequence,call(JSON.encode,JSON,tostring(state.relayMatch or "lobby")) or '"lobby"',call(JSON.encode,JSON,quality) or '{}')
    body=body:sub(1,-2)..extra..'}'
    state.sendSerial = state.sendSerial + 1
    local upload = {serial = state.sendSerial, controlEpoch = state.requestId, epoch = runtime.epoch,
        at = now, token = state.fb.token, versions = {}}
    for key in pairs(commit) do upload.versions[key] = runtime.versions[key] end
    state.upload, state.feedOwner = upload, upload.serial
    state.inflight[upload.serial] = now
    state.perf.bytes, state.perf.rateAt = #body, state.perf.rateAt or now
    dbRequest("PATCH", state.session, body, function(_, code, response)
        runtime.reply(upload, commit, receipt, code, response)
    end)
end

function runtime.labels(now)
    if now < (state.nextPerf or 0) then return end
    state.nextPerf = now + 1
    local p = state.perf
    state.perfText = string.format(L("cr_performance"), p.work_ms or 0, (p.bytes or 0) / 1024,
        p.upload_ms or 0, p.actualRate or 0)
    if state.hitch then
        state.perfText = state.perfText .. "\n" .. string.format(L("cr_hitch"), state.hitch.gap, state.hitch.ms, state.hitch.part)
    end
    setLabel(ui.performance, state.perfText)
end

function runtime.update()
    local began = clock()
    traceHitch(began)
    initMenu()
    if state.ready and began >= (state.nextLabels or 0) then
        state.nextLabels = began + 1
        setLabel(ui.status, state.statusText)
    end
    runtime.pollRequests(began)
    if state.retryAt and began >= state.retryAt and not state.active and not state.control then
        state.retryAt = nil
        if get(ui.enabled, false) then start() end
    end
    if state.saveDirty and began >= (state.saveAt or 0) then flushSaved() end
    if not state.active then return end
    refreshFlags(began)
    if not state.flags.enabled then return end
    local fb = state.fb
    if not fb.token or wallClock() >= (fb.expires or 0) then
        if not fb.authorizing and began >= (fb.retryAt or 0) then
            authorize(function(ok, code) if not ok then show("cr_st_auth_fail", code or 0) end end)
        end
        return
    end
    local playing = inGame()
    local paused = call(GameRules.IsPaused) == true
    if runtime.paused ~= nil and paused ~= runtime.paused then
        runtime.sampleAt = 0
        if state.failures == 0 then state.nextSend = math.min(state.nextSend, began) end
    end
    local sampleDue = began + 0.000001 >= (runtime.sampleAt or 0)
    -- On a freed TURBO connection always collect the freshest positions before
    -- sending. Slow-network waiting samples remain capped at ten per second.
    if mode().turbo and not state.upload and began >= state.nextSend and not runtime.paused
        and began >= runtime.pressureUntil then
        sampleDue = not runtime.sampleError or sampleDue
    end
    if state.failures > 0 and not state.upload and began >= state.nextSend then
        sampleDue = not runtime.sampleError or sampleDue
    end
    if playing ~= runtime.playing and not runtime.sampleError then sampleDue = true end
    if sampleDue then runtime.sample(began, playing) end
    runtime.send(clock())
    local md = mode()
    local budget = md.frameBudget or math.max(0.0012, md.scanMs)
    local remaining = budget - (clock() - began)
    if playing and remaining > 0.0001 and (state.scanJob or began >= state.nextSlow) then
        local scanBegan = clock()
        local ok, err = pcall(slowSnapshot, gameClock(), remaining)
        if not ok then
            state.scanJob, state.nextSlow = nil, clock() + 1
            reportError("map scan", err)
        end
        state.perf.scan_ms = (clock() - scanBegan) * 1000
    end
    local cost = math.max(0, clock() - began)
    state.perf.work_ms, state.perf.frame_ms = cost * 1000, cost * 1000
    if cost > budget then
        -- Soft governor: repay an unusually expensive frame with a bounded
        -- sampling pause. Native API calls cannot be interrupted mid-call.
        runtime.pressureUntil = clock() + math.min(0.1, (cost - budget) * 3)
        runtime.sampleAt = math.max(runtime.sampleAt or 0, runtime.pressureUntil)
    end
    runtime.labels(clock())
end

runtime.reset()

function script.OnUpdateEx()
    runtime.update()
end

local effectOnly = {OnParticleCreate=true, OnLinearProjectileCreate=true, OnParticleUpdate=true,
    OnParticleUpdateEntity=true, OnUnitAnimation=true, OnStartSound=true}
for _, name in ipairs({"OnParticleCreate", "OnLinearProjectileCreate", "OnParticleUpdate", "OnParticleUpdateEntity",
    "OnUnitAnimation", "OnProjectile", "OnStartSound", "OnModifierCreate", "OnModifierUpdate", "OnModifierDestroy",
    "OnEntityKilled", "OnEntityDestroy", "OnNpcSpawned", "OnParticleDestroy"}) do
    local handler = script[name]
    script[name] = function(...)
        if state.over or not state.active or (effectOnly[name] and not state.flags.effects
            and not (name == "OnParticleCreate" and state.flags.abilities)) then return end
        local began = clock()
        local ok, err = pcall(handler, ...)
        if not ok then reportError("event " .. name, err) end
        state.eventTime = (state.eventTime or 0) + clock() - began
    end
end
script.OnParticleUpdateFallback = script.OnParticleUpdate

local ok, result = pcall(require, "assets.JSON")
if ok then JSON = result end
return script
