--#!/usr/local/bin/lua


usage_str = [[
Usage:
  	Use arrow keys to navigate and Esc to quit. 

Objective:
	Move blocks to get the biggest block out of the maze.
]]

-- following modules are required

local curses = require 'curses'
local posix  = require 'posix'
local inspect = require 'inspect'

function copy(obj, seen)
  	if type(obj) ~= 'table' then return obj end
  	if seen and seen[obj] then return seen[obj] end
  	local s = seen or {}
  	local res = setmetatable({}, getmetatable(obj))
  	s[obj] = res
  	for k, v in pairs(obj) do res[copy(k, s)] = copy(v, s) end
  	return res
end

-- Define Game class

Game = { board_color = {{11, 11, 11, 11, 11, 11}, 
		  	{11,  0,  0,  0,  0, 11},
			{11,  0,  0,  0,  0, 11},
		  	{11,  0,  0,  0,  0, 11},
		  	{11,  0,  0,  0,  0, 11},
		  	{11,  0,  0,  0,  0, 11},
		  	{11, 11,  13,  13, 11, 11}},

	board_char =   {{'|', '|', '|', '|', '|', '|'}, 
		  	{'|', ' ', ' ', ' ', ' ', '|'},
		  	{'|', ' ', ' ', ' ', ' ', '|'},
		  	{'|', ' ', ' ', ' ', ' ', '|'},
		  	{'|', ' ', ' ', ' ', ' ', '|'},
		  	{'|', ' ', ' ', ' ', ' ', '|'},
		  	{'|', '|', '-', '-', '|', '|'}},

	sentries = {{x=2, y=2, dx=1, dy=2, char = '\\', fg_color='black', bg_color='red'},
		    {x=3, y=2, dx=2, dy=2, char = ' ', fg_color='red', bg_color='green'},  -- Khun Pan
		    {x=5, y=2, dx=1, dy=2, char = '/', fg_color='black', bg_color='red'},
		    {x=2, y=4, dx=1, dy=2, char = '+', fg_color='white', bg_color='blue'},
		    {x=3, y=4, dx=2, dy=1, char = '-', fg_color='black', bg_color='white'},
		    {x=5, y=4, dx=1, dy=2, char = '+', fg_color='white', bg_color='blue'},
		    {x=3, y=5, dx=1, dy=1, char = '.', fg_color='red', bg_color='yellow'},
		    {x=4, y=5, dx=1, dy=1, char = '.', fg_color='magenta', bg_color='cyan'},
		    {x=3, y=6, dx=1, dy=1, char = '.', fg_color='magenta', bg_color='cyan'},
                    {x=4, y=6, dx=1, dy=1, char = '.', fg_color='red', bg_color='yellow'}},
	border = {fg_color='white', bg_color='black'},
	x_scale =  4
       }


function Game:new ()
  	return setmetatable({}, {__index = self})
end

function Game:init()
	print 'init'
	-- Start up curses.	
	curses.initscr()    -- Initialize the curses library and the terminal screen.
  	curses.cbreak()     -- Turn off input line buffering.
  	curses.echo(false)  -- Don't print out characters as the user types them.
	curses.nl(false)    -- Turn off special-case return/newline handling.
  	curses.curs_set(0)  -- Hide the cursor.
	-- Set up our standard screen.
	stdscr = curses.stdscr()
  	stdscr:nodelay(true)  -- Make getch nonblocking.
  	stdscr:keypad()       -- Correctly catch arrow key presses.
	self.y_scale = self.x_scale/2
	
	
	-- Set up colors.
  	curses.start_color()
  	if not curses.has_colors() then
    		curses.endwin()
    		print('Bummer! Looks like your terminal doesn\'t support colors :\'(')
    		os.exit(1)
  	end
	
	curses.init_pair(12, curses['COLOR_BLACK'], curses['COLOR_BLACK'])
  	for k, v in ipairs(self.sentries) do
    		c_fg, c_bg = curses['COLOR_' .. v.fg_color:upper()], curses['COLOR_' .. v.bg_color:upper()]
		v.color, v.flip_color = k, k+33
    		curses.init_pair(v.color, c_fg, c_bg)
		curses.init_pair(v.flip_color, c_bg, c_fg)
		if k == 2 then v.khun_pan = true else v.khun_pan = false end
  	end
	local border = self.border
	
	c_fg, c_bg = curses['COLOR_' .. border.fg_color:upper()], curses['COLOR_' .. border.bg_color:upper()]
    	curses.init_pair(11, c_fg, c_bg)
	curses.init_pair(13,curses['COLOR_YELLOW'], curses['COLOR_BLACK'])

	function set_color(c)
  		stdscr:attron(curses.color_pair(c))
	end

	function draw_point(x, y, x_offset, y_offset, color, point_char)
  		point_char = point_char or ' '  -- Space is the default point_char.
		if color == 0 then 
			--print('found empty', x, y)
			color = 12 
		end
  		if color then set_color(color) end
  		-- Don't draw pieces when the game is paused.
		y_scale, x_scale = self.y_scale, self.x_scale
		y, x = y_offset + y_scale * y, x_offset + x_scale * x
		for dx = 0, self.x_scale - 1 do
			for dy = 0, self.y_scale -1 do
				stdscr:mvaddstr(y + dy, x + dx, point_char)
			end
		end
		--set_color(12)
	end 
	
	self.active_sentry = 4
end

function Game:handle_input()
    	local key = stdscr:getch()  -- Nonblocking; returns nil if no key was pressed.
    	if key == nil then return end

    	if key == tostring('q'):byte(1) then  -- The q key quits.
    		curses.endwin()
    		os.exit(0)
	elseif  key == curses.KEY_DOWN then
		self:move('down')
	elseif  key == curses.KEY_LEFT then
		self:move('left')
	elseif  key == curses.KEY_RIGHT then
		self:move('right')
	elseif key == curses.KEY_UP then
		self:move('up')
	elseif key == tostring(' '):byte(1) then
		self:toggle_active_sentry()	
    	end
end


function Game:set_sentry(sentry, color, char)
	for dx=0, sentry.dx-1 do
		for dy=0, sentry.dy-1 do 
			self.board_color[sentry.y+dy][sentry.x+dx] = color or sentry.color
			self.board_char[sentry.y+dy][sentry.x+dx] = char or sentry.char
		end
	end
end

function Game:is_valid_move(old_sentry, new_sentry)
	self:set_sentry(old_sentry, 0, ' ')
	valid = true
	for dx=0, new_sentry.dx-1 do
		for dy=0, new_sentry.dy-1 do
			eff_x, eff_y = new_sentry.x+dx, new_sentry.y+dy
			if eff_x < 1 or eff_x > 6 or eff_y < 1 or eff_y > 7 then valid = false end
			if self.board_color[eff_y][eff_x] ~= 0 then valid = false end
			if new_sentry.khun_pan and self.board_char[eff_y][eff_x] == '-' then 
				if self.board_color[eff_y][eff_x] == 13 then valid = true end
			end
			if not valid then break end
		end
	end
	self:set_sentry(old_sentry)
	return valid
end

function Game:move(direction)
	sentry =  self.sentries[self.active_sentry]
	new_sentry = self:get_moved_sentry(sentry, direction)
	if self:is_valid_move(sentry, new_sentry) then
		self:set_sentry(sentry, 0, ' ')
		self.sentries[self.active_sentry] = new_sentry
		self:set_sentry(self.sentries[self.active_sentry])
	end
end

function Game:fill_board()
	for i, sentry in ipairs(self.sentries) do
		if i == self.active_sentry then
			if self.flipped == 'yes' then
				self:set_sentry(sentry, sentry.flip_color)	
			end
		else
			self:set_sentry(sentry)
		end
	end	
end

function Game:draw_screen()
  	stdscr:erase()
  	-- Update the screen dimensions.
  	local scr_width = curses.cols()
  	local board_width = self.x_scale * 6
	local board_height = self.y_scale * 7
  	local x_margin = math.floor((scr_width - board_width) / 2)
	local y_margin = 10	

	active_sentry = self.sentries[self.active_sentry] 
	-- Draw the board's border and non-falling pieces if we're not paused.
  	for y = 1, 7 do
    		for x = 1, 6 do
      			-- Draw ' ' for shape & empty points; '|' for border points.
			local color = self.board_color[y][x]
			local char = self.board_char[y][x]
      			draw_point( x, y,  x_margin, y_margin, color, char)
    		end
  	end
	
end

function Game:get_moved_sentry(sentry, direction)
	moved_sentry = copy(sentry)
	if direction == 'up' then
		moved_sentry.y = moved_sentry.y - 1
	elseif direction == 'left' then
		moved_sentry.x = moved_sentry.x - 1
	elseif direction == 'right' then 
		moved_sentry.x = moved_sentry.x + 1
	elseif direction == 'down' then
		moved_sentry.y = moved_sentry.y + 1
	end
	return moved_sentry
end

function Game:update_movable_sentries()
	for i, sentry in ipairs(self.sentries) do
		can_up = self:is_valid_move(sentry, self:get_moved_sentry(sentry, 'up'))
		can_down = self:is_valid_move(sentry, self:get_moved_sentry(sentry, 'down'))
		can_left = self:is_valid_move(sentry, self:get_moved_sentry(sentry, 'left'))
		can_right = self:is_valid_move(sentry, self:get_moved_sentry(sentry, 'right'))
		if can_up or can_down or can_right or can_left then
			self.sentries[i].movable = true
		else
			self.sentries[i].movable = false
		end
	end
end

function Game:toggle_active_sentry()
	while(true) do
		self.active_sentry = self.active_sentry + 1
		if self.active_sentry > #self.sentries then self.active_sentry = 1 end
		if self.sentries[self.active_sentry].movable then break end
	end
end

function Game:toggle_counter(counter_max)
	if not self.counter then self.counter = 1 end
	if not self.flipped then self.flipped = 'no' end
	self.counter = self.counter + 1
	local flipped = {['yes']='no', ['no']='yes'}
	if self.counter == counter_max then 
		self.counter = 1
		self.flipped = flipped[self.flipped]
	end
end

function Game:play()
	self:init()
	self:fill_board()
	self:update_movable_sentries()
	self:toggle_active_sentry()
 	while true do  -- Main loop.
		self:update_movable_sentries()
    		self:handle_input()
		self:fill_board()
    		self:draw_screen()

    		-- Don't poll for input much faster than the display can change.
    		local sec, nsec = 0, 5e6  -- 0.005 seconds.
    		posix.nanosleep(sec, nsec)

		self:toggle_counter(10)
  	end
	--]]
end

g = Game:new()
g:play()
