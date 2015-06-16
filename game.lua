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
		  	{11, 11,  0,  0, 11, 11}},

	board_char =   {{'|', '|', '|', '|', '|', '|'}, 
		  	{'|', ' ', ' ', ' ', ' ', '|'},
		  	{'|', ' ', ' ', ' ', ' ', '|'},
		  	{'|', ' ', ' ', ' ', ' ', '|'},
		  	{'|', ' ', ' ', ' ', ' ', '|'},
		  	{'|', ' ', ' ', ' ', ' ', '|'},
		  	{'|', '|', ' ', ' ', '|', '|'}},

	sentries = {{x=2, y=2, dx=1, dy=2, char = '\\', fg_color='black', bg_color='red'},
		    {x=3, y=2, dx=2, dy=2, char = ' ', fg_color='green', bg_color='green'},
		    {x=5, y=2, dx=1, dy=2, char = '/', fg_color='black', bg_color='red'},
		    {x=2, y=4, dx=1, dy=2, char = '+', fg_color='white', bg_color='blue'},
		    {x=3, y=4, dx=2, dy=1, char = '-', fg_color='black', bg_color='white'},
		    {x=5, y=4, dx=1, dy=2, char = '+', fg_color='white', bg_color='blue'},
		    {x=3, y=5, dx=1, dy=1, char = '.', fg_color='red', bg_color='yellow'},
		    {x=4, y=5, dx=1, dy=1, char = '.', fg_color='cyan', bg_color='cyan'},
		    {x=3, y=6, dx=1, dy=1, char = '.', fg_color='cyan', bg_color='cyan'},
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
    		curses.init_pair(k, c_fg, c_bg)
  	end
	local border = self.border
	
	c_fg, c_bg = curses['COLOR_' .. border.fg_color:upper()], curses['COLOR_' .. border.bg_color:upper()]
    	curses.init_pair(11, c_fg, c_bg)

	function set_color(c)
  		stdscr:attron(curses.color_pair(c))
	end

	function draw_point(x, y, x_offset, y_offset, color, point_char)
  		point_char = point_char or ' '  -- Space is the default point_char.
  		if color then set_color(color) end
  		-- Don't draw pieces when the game is paused.
		y_scale, x_scale = self.y_scale, self.x_scale
		y, x = y_offset + y_scale * y, x_offset + x_scale * x
		for dx = 0, self.x_scale - 1 do
			for dy = 0, self.y_scale -1 do
				stdscr:mvaddstr(y + dy, x + dx, point_char)
			end
		end
		set_color(12)
	end 
end

function Game:handle_input()
    	local key = stdscr:getch()  -- Nonblocking; returns nil if no key was pressed.
    	if key == nil then return end

    	if key == tostring('q'):byte(1) then  -- The q key quits.
    		curses.endwin()
    		os.exit(0)
	elseif  key == curses.KEY_DOWN then
		self:move(0,1)
	elseif  key == curses.KEY_LEFT then
		self:move(-1,0)
	elseif  key == curses.KEY_RIGHT then
		self:move(1,0)
	elseif key == curses.KEY_UP then
		self:move(0,-1)	
    	end
end


function Game:set_sentry(sentry, color, char)
	for dx=0,sentry.dx-1 do
		for dy=0, sentry.dy-1 do 
			self.board_color[sentry.y+dy][sentry.x+dx] = color or sentry.fg_color
			self.board_char[sentry.y+dy][sentry.x+dx] = char or sentry.char
		end
	end
end

function Game:check_valid_sentry(sentry)
	valid = true
	for dx=0,sentry.dx-1 do
		for dy=0, sentry.dy-1 do 
			if self.board_color[sentry.y+dy][sentry.x+dx] ~= 0 or 
				self.board_char[sentry.y+dy][sentry.x+dx] ~= ' ' then
				valid = false
			end
		end
	end
	return valid
end

function Game:move(dx, dy)
	local sentries =  self.sentries
	for i, sentry in ipairs(sentries) do
		local board_color = self.board_color
		self:set_sentry(sentry, 0, ' ')
		local new_sentry = copy(sentry)
		new_sentry.x, new_sentry.y = new_sentry.x + dx, new_sentry.y + dy
		if self:check_valid_sentry(new_sentry) then
			self.sentries[i] = new_sentry
			self:set_sentry(self.sentries[i])
			break
		end
		self:set_sentry(self.sentries[i])
	end	
end

function Game:fill_board()
	local sentries =  self.sentries
	for i, sentry in ipairs(sentries) do
		color, x, y, char = i, sentry.x, sentry.y, sentry.char
		for dx=0, sentry.dx-1 do
			for dy=0, sentry.dy-1 do
				self.board_char[y+dy][x+dx] = char
				self.board_color[y+dy][x+dx] = color
			end
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

function Game:play()
	self:init()
	self:fill_board()
 	while true do  -- Main loop.
    		self:handle_input(stats, fall, next_piece)
    		--lower_piece_at_right_time(stats, fall, next_piece)
		self:fill_board()
    		self:draw_screen()

    		-- Don't poll for input much faster than the display can change.
    		local sec, nsec = 0, 5e6  -- 0.005 seconds.
    		posix.nanosleep(sec, nsec)
  	end
end

g = Game:new()
g:play()
