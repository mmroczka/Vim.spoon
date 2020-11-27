local c = require("hs.canvas")
-- local AppWatcher = dofile(vimModeScriptPath .. "lib/app_watcher.lua")

function getTotalScreenNum()
	local numScreens = 0
	for i,v in ipairs(hs.screen.allScreens()) do
		numScreens = numScreens + 1
	end
	return numScreens
end

function createNormalHUD()
  return c.new{x=1155, y=0,h=22, w=100}:appendElements({ action = "fill", fillColor = { red=.125, green=.464, blue=.968 }, type = "rectangle" }, { action = "clip", type="text", text="NORMAL", textSize=15, textAlignment="center", frame = { h = 22, w = 100, x = 0, y = 1 } })
end

function createInsertHUD()
  return c.new{x=1155,y=0,h=22,w=100}:appendElements( { action = "fill", fillColor = { red=.40, green=.518, blue=.145 }, type = "rectangle"}, { action = "clip", type="text", text="INSERT", textSize=15, textAlignment="center", frame = { h = 22, w = 100, x = 0, y = 1 } })
end

function createVisualHUD()
  return c.new{x=1155,y=0,h=22,w=100}:appendElements( { action = "fill", fillColor = { red=.651, green=.188, blue=.369 }, type = "rectangle"}, { action = "clip", type="text", text="VISUAL", textSize=15, textAlignment="center", frame = { h = 22, w = 100, x = 0, y = 1 } })
end

function buildHUD()
	local MODES = {
		lastMode = "NORMAL",
		normals = {},
		inserts = {},
		visuals = {}
	}
	local numOfEachHUDTOMake = getTotalScreenNum()
	-- build MODES
	table.insert(MODES.normals, { createNormalHUD(), createNormalHUD() });
	table.insert(MODES.inserts, { createInsertHUD(), createInsertHUD() });
	table.insert(MODES.visuals, { createVisualHUD(), createVisualHUD() });

	return MODES
end

function mergeArrays(ar1, ar2)
	-- add each array value to a table, and send the iteration at the end
	local tmp = {}
	for _, v in ipairs(ar1) do
		tmp[v] = true
	end
	for _, v2 in ipairs(ar2) do
		tmp[v2] = true
	end
	local output = {}
	for k, v in pairs(tmp) do
		table.insert(output, k)
	end
	return output
end

function mergeTables(t1, t2)
	local output = {}
	for k, v in pairs(t1) do
		if t2[k] == nil then
			output[k] = v
		else
			outpu[k] = t2[k]
		end
	end

	for k, v in pairs(t2) do
		if output[k] == nil then
			output[k] = v
		end
	end
	return output
end

function delayedKeyPress(mod, char, delay)
	-- if needed you can do a delayed keypress by `delay` seconds
	return hs.timer.delayed.new(delay, function ()
		keyPress(mod, char)
	end)
end

function keyPress(mod, char)
	-- press a key for 20ms
	hs.eventtap.keyStroke(mod, char, 10000)
end

function keyPressFactory(mod, char)
	-- return a function to press a certain key for 20ms
	return function () keyPress(mod, char) end
end

function complexKeyPressFactory(mods, keys)
	-- mods and keys are arrays and have to be the same length
	return function ()
		for i, v in ipairs(keys) do
			keyPress(mods[i], keys[i])
		end
	end
end

local Vim = {}

function Vim:new()
	newObj = {state = 'normal',
						keyMods = {}, -- these are like cmd, alt, shift, etc...
						commandMods = nil, -- these are like d, y, c, r in normal mode
						numberMods = 0, -- for # times to do an action
						debug = false,
						events = 0, -- flag for # events to let by the event mngr
						modals = buildHUD(),
						-- appWatcher = AppWatcher:new(vim):start()
					}

	self.__index = self
	return setmetatable(newObj, self)
end

function Vim:setDebug(val)
	self.debug = val
end

function Vim:showDebug(log)
	if self.debug then
		print(log)
	end
end


function Vim:showModals(modals)
	for i,mode in ipairs(modals) do
		mode[i]:show()
	end
end

function Vim:hideModals(modalGroupOne, modalGroupTwo)
	for i,mode in ipairs(modalGroupOne) do
		mode[i]:hide()
	end
	for i,mode in ipairs(modalGroupTwo) do
		mode[i]:hide()
	end
end

function Vim:setModal(mode)
	if mode == "normal" then
		self:showModals(self.modals.normals)
		self:hideModals(self.modals.inserts, self.modals.visuals)
	elseif mode == "insert" then
		self:showModals(self.modals.inserts)
		self:hideModals(self.modals.normals, self.modals.visuals)
	elseif mode == "visual" then
		self:showModals(self.modals.visuals)
		self:hideModals(self.modals.normals, self.modals.inserts)
	end
end

function Vim:start()
	local selfPointer = self
	self.tapWatcher = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(evt)
		return self:eventWatcher(evt)
	end)
	self.modal = hs.hotkey.modal.new({}, "f13")
	selfPointer:setMode('insert')
	function self.modal:entered()
		-- reset to the normal mode
		selfPointer.tapWatcher:start()
		selfPointer:setMode('normal')
	end
	function self.modal:exited()
		selfPointer:setMode('insert')
		selfPointer.tapWatcher:stop()
		selfPointer:resetEvents()
	end
end

function Vim:handleKeyEvent(char)
	-- check for text modifiers
	local modifiers = 'dcyr'
	local stop_event = true -- stop event from propagating
	local keyMods = self.keyMods
	self:showDebug('\t--- handleKeyEvent -> '.. char)
	if self.commandMods ~= nil and string.find('dcy', self.commandMods) ~= nil then
		-- using shift to delete and select things even in visual mode
		keyMods = mergeArrays(keyMods, {'shift'})
	end
	-- allows for visual mode too
	local movements = {
		D = complexKeyPressFactory({mergeArrays(keyMods, {'shift', 'cmd'}), keyMods}, {'right', 'delete'}),
		X = keyPressFactory(keyMods, 'delete'),
		['$'] = keyPressFactory(mergeArrays(keyMods, {'cmd'}), 'right'),
		['0'] = keyPressFactory(mergeArrays(keyMods, {'cmd'}), 'left'),
		b = keyPressFactory(mergeArrays(keyMods, {'alt'}), 'left'),
		e = keyPressFactory(mergeArrays(keyMods, {'alt'}), 'right'),
		h = keyPressFactory(keyMods, 'left'),
		j = keyPressFactory(keyMods, 'down'),
		k = keyPressFactory(keyMods, 'up'),
		l = keyPressFactory(keyMods, 'right'),
		w = complexKeyPressFactory({mergeArrays(keyMods, {'alt'}), keyMods}, {'right', 'right'}),
		x = keyPressFactory(keyMods, 'forwarddelete'),
	} -- movements to make

	local modifierKeys = {
		c = complexKeyPressFactory({{'cmd'}, {}, {}}, {'c', 'delete', 'i'}),
		d = complexKeyPressFactory({{'cmd'}, {}}, {'c', 'delete'}),
		-- r = complexKeyPressFactory({{}, {}}, {'forwarddelete', char}),
		y = complexKeyPressFactory({{'cmd'}, {}}, {'c', 'right'}),
	} -- keypresses for the modifiers after the movement

	local numEvents = {
		D = 2,
		X = 1,
		['$'] = 1,
		['0'] = 1,
		b = 1,
		c = 2,
		d = 2,
		e = 1,
		g = 2,
		h = 1,
		j = 1,
		k = 1,
		l = 1,
		r = 2,
		w = 2,
		x = 1,
		y = 2,
	} -- table of events the system has to let past for this

	if movements[char] ~= nil and self.commandMods ~= 'r' then
		-- do movement commands, but state-dependent
		self.events = numEvents[char]
		movements[char]() -- execute function assigned to this specific key
		stop_event = true
	elseif modifiers:find(char) ~= nil and self.commandMods == nil then
		self:showDebug('\t--- handleKeyEvent: Modifier character: ' .. char)
		self.commandMods = char
		stop_event = true
	elseif char == 'r' then
		return stop_event
	end

	if self.commandMods ~= nil and modifiers:find(self.commandMods) ~= nil then
		-- do something related to modifiers
		-- run this block only after movement-related code
		self:showDebug('\t--- handleKeyEvent: Modifier in progress') 
		if modifiers:find(char) == nil then
			self.events = self.events + numEvents[self.commandMods]
			modifierKeys[self.commandMods]()
			self.commandMods = nil
			-- reset
			self:setMode('normal')
		elseif char ~= 'r' and self.state == 'visual' then
			self.events = self.events + numEvents[self.commandMods]
			modifierKeys[self.commandMods]()
			self.commandMods = nil
			self:setMode('normal')
		end
	end

	if self.state == 'insert' then
		stop_event = false
	end
	self:showDebug("\t--- handleKeyEvent: Stop event = ".. tostring(stop_event))
	return stop_event
end

function Vim:eventWatcher(evt)
	-- stop an event from propagating through the event system
	local stop_event = true
	local evtChar = evt:getCharacters()

	self:showDebug('====== EventWatcher: pressed ' .. evtChar)
	local insertEvents = 'iIsaAoO'
	local commandMods = 'rcdy'
	-- this function mostly handles the state-dependent events
	if self.events > 0 then
		self:showDebug('====== EventWatcher: event '.. self.events .. ' is occurring ')
		stop_event = false
		self.events = self.events - 1
	elseif evtChar == 'v' then
		-- if v key is hit, then go into visual mode
		self:setMode('visual')
		return stop_event
	elseif evtChar == ':' then
		-- do nothing for now because no ex mode
		self:setMode('ex')
		-- TODO: implement ex mode
	elseif evt:getKeyCode() == hs.keycodes.map['escape'] then
		-- get out of visual mode
		self:setMode('normal')
	elseif evtChar == 'u' then
		-- special undo key
		self.events = 1
		keyPress({'cmd'}, 'z')
	elseif evtChar == 'p' then
		self.events = 1
		keyPress({'cmd'}, 'v')
		self:setMode('normal')
	elseif evtChar == '/' then
		self.events = 1
		keyPress({'cmd'}, 'f')
		keyPress({}, 'i')
	elseif insertEvents:find(evtChar, 1, true) ~= nil and self.state == 'normal' and self.commandMods == nil then
		-- do the insert command
		self:showDebug('insertEvent occuring')
		self:insert(evtChar)
	elseif self.state == 'normal' and self.commandMods == 'r' then
		-- do the replace command 
		self:showDebug('replaceEvent occuring')
		self:replace(evtChar, evt:getKeyCode())
	else
		-- anything else, literally
		self:showDebug('handling key press event for movement')
		stop_event = self:handleKeyEvent(evtChar)
	end
	self:showDebug('====== EventWatcher: stop_event = ' .. tostring(stop_event).."\n\n")
	return stop_event
end

function Vim:insert(char)
	-- if is an insert event then do something
	-- ...
	self.events = 1
	if char == 's' then
		-- delete character and exit
		keyPress('', 'forwarddelete')
	elseif char == 'a' then
		keyPress('', 'right')
	elseif char == 'A' then
		keyPress({'cmd'}, 'right')
	elseif char == 'I' then
		keyPress({'cmd'}, 'left')
	elseif char == 'o' then
		self.events = 2
		complexKeyPressFactory({{'cmd'}, {}}, {'right', 'return'})()
	elseif char == 'O' then
		self.events = 3
		complexKeyPressFactory({{}, {'cmd'}, {}}, {'up', 'right', 'return'})()
	end

	local selfRef = self
	hs.timer.delayed.new(0.01*self.events + 0.001, function ()
		selfRef:exitModal()
	end):start()
end

function Vim:replace(char, keycode)
	self.events = 3
	if keycode == hs.keycodes.map['space'] then
		self.events = 2
		keyPress({}, 'forwarddelete')
		keyPress({}, 'space')
	else
		complexKeyPressFactory({{'cmd'}, {}, {}}, {'c', 'forwarddelete', char})()
	end
	local selfRef = self
	selfRef:setMode('normal')
end

function Vim:exitModal()
	self.modal:exit()
end

function Vim:resetEvents()
	self.events = 0
end

function Vim:setMode(val)
	self.state = val
	-- TODO: change any other flags that are important for visual mode changes
	if val == 'visual' then
		self.keyMods = {'shift'}
		self.commandMods = nil
		self.numberMods = 0
		self.moving = false
		self:setModal("visual")
	elseif val == 'normal' then
		self.keyMods = {}
		self.commandMods = nil
		self.numberMods = 0
		self.moving = false
		self:setModal("normal")
	elseif val == 'ex' then
		-- do nothing because this is not implemented
	elseif val == 'insert' then
		self:setModal("insert")
		-- do nothing because this is a placeholder
		-- insert mode is mainly for pasting characters or eventually applying
		-- recordings
		-- TODO: implement the recording feature
	end
end

-- what are the characters that end visual mode? y, p, x, d, esc

-- TODO: future implementations could use composition instead
-- TODO: add an ex mode into the Vim class using the chooser API

function Vim:disableForApp(appName)
--   self.appWatcher:disableApp(appName)
end

return Vim
