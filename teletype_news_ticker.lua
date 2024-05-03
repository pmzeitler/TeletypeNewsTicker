obs = obslua

-- Teletype News Ticker Script
-- By Phoebe Zeitler
-- phoebe.zeitler@gmail.com 
-- Support: https://obsproject.com/forum/resources/teletype-news-ticker.725/

-- begin properties variables
source_name       = ""
file_name         = ""
teletype_delay_ds = 1
full_display_s    = 10
reload_on_loop    = true
prefix_chars      = ""
use_cursor        = false
use_rand_cursor   = false
use_cursor_char   = "_"
-- end properties variables

-- begin internal use variables
lines_stack       = {}
current_delay     = 0
current_line      = 1
current_char      = 1
teletype_mode     = false
timer_deployed	  = false
processed_line    = ""
-- end internal use variables

-- begin user configurable options
default_path      = "C:\\"
	-- IMPORTANT: use only basic ASCII characters here-- UTF-8 not yet supported
rand_cursor_chars = "qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM1234567890-=+_)(*&^%$#@![]{}|,<.>/? "
-- end user configurable options

-- begin imported functions

-- function courtesy Dirk Laurie
-- http://lua-users.org/lists/lua-l/2014-04/msg00590.html
--[[
function utf8.sub(s,i,j)
   i = i or 1
   j = j or -1
   if i<1 or j<1 then
      local n = utf8.len(s)
      if not n then return nil end
      if i<0 then i = n+1+i end
      if j<0 then j = n+1+j end
      if i<0 then i = 1 elseif i>n then i = n end
      if j<0 then j = 1 elseif j>n then j = n end
   end
   if j<i then return "" end
   i = utf8.offset(s,i)
   j = utf8.offset(s,j+1)
   if i and j then return s:sub(i,j-1)
      elseif i then return s:sub(i)
      else return ""
   end
end
]]

-- functions courtesy Bart Kiers
-- https://stackoverflow.com/questions/11201262/how-to-read-data-from-a-file-in-lua
function file_exists(file)
  local f = io.open(file, "rb")
  if f then f:close() end
  return f ~= nil
end

function lines_from(file)
  if not file_exists(file) then return {} end
  lines = {}
  for line in io.lines(file) do 
    lines[#lines + 1] = line
  end
  return lines
end

--functions courtesy Superlou (modified by Phoebe Zeitler)
--https://github.com/superlou/obs-newsroom/blob/master/dsk_tool.lua
function find_source_by_name_in_list(source_list, name)
  for i, source in pairs(source_list) do
    local source_name = obs.obs_source_get_name(source)
    if source_name == name then
      return source
    end
  end
	--print ("Source " .. source_name .. " was not found")
  return nil
end

function source_is_active(dsk_name)
  local sources = obs.obs_enum_sources()
  local dsk = find_source_by_name_in_list(sources, dsk_name)
  local is_active = obs.obs_source_active(dsk)
  obs.source_list_release(sources)
  return is_active
end

-- end imported functions

-- begin OBS required functions

-- A function named script_properties defines the properties that the user
-- can change for the entire script module itself
function script_properties()
  local props = obs.obs_properties_create()
  
    local p = obs.obs_properties_add_list(props, "source_name", "Text Source (In Scene)", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	local sources = obs.obs_enum_sources()
	if sources ~= nil then
		for _, source in ipairs(sources) do
			source_id = obs.obs_source_get_id(source)
			if source_id == "text_gdiplus" or source_id == "text_ft2_source" then
				local name = obs.obs_source_get_name(source)
				obs.obs_property_list_add_string(p, name, name)
			end
		end
	end
	obs.source_list_release(sources)
	
	obs.obs_properties_add_path(props, "file_name", "Source File", obs.OBS_PATH_FILE, "Text Files (*.txt)", default_path)
	obs.obs_properties_add_bool(props, "reload_on_loop", "When EOF reached, Reload File")
	obs.obs_properties_add_int(props, "teletype_delay_ds", "Teletype Delay (0.1 seconds)", 0, 101, 1)
	obs.obs_properties_add_int(props, "full_display_s", "Full Line Display Time (seconds)", 1, 31, 1)
	obs.obs_properties_add_text(props, "prefix_chars", "Line Prefix Character(s)", obs.OBS_TEXT_DEFAULT)
	obs.obs_properties_add_bool(props, "use_cursor", "Use Cursor Trailer Character When Teletyping")
	obs.obs_properties_add_bool(props, "use_rand_cursor", "Randomize Cursor Character")
	obs.obs_properties_add_text(props, "use_cursor_char", "Static Cursor Character(s)", obs.OBS_TEXT_DEFAULT)
	return props
end

-- A function named script_defaults will be called to set the default settings
function script_defaults(settings)
	obs.obs_data_set_default_int(settings, "teletype_delay_ds", 10)
	obs.obs_data_set_default_int(settings, "full_display_s", 10)
end

-- A function named script_description returns the description shown to
-- the user
function script_description()
	return "Creates a teletype-effect rotating file reader. \n\nAuthor: Phoebe Zeitler (See source for additional code acknowledgements)"
end
	
	
-- A function named script_update will be called when settings are changed
function script_update(settings)
	source_name = obs.obs_data_get_string(settings, "source_name")
	file_name = obs.obs_data_get_string(settings, "file_name")
	reload_on_loop = obs.obs_data_get_bool(settings, "reload_on_loop")
	teletype_delay_ds = obs.obs_data_get_int(settings, "teletype_delay_ds")
	full_display_s = obs.obs_data_get_int(settings, "full_display_s")
	prefix_chars = obs.obs_data_get_string(settings, "prefix_chars")
	use_cursor = obs.obs_data_get_bool(settings, "use_cursor")
	use_rand_cursor = obs.obs_data_get_bool(settings, "use_rand_cursor")
	use_cursor_char = obs.obs_data_get_string(settings, "use_cursor_char")
	reset()
end 

function script_load(settings)
	
end

-- end OBS required functions

-- begin application-specific functions

function reset() 
	math.randomseed(os.time())
    if timer_deployed then
		obs.timer_remove(timer_callback)
	end
	

	lines_stack = lines_from(file_name)
	current_delay = teletype_delay_ds
	teletype_mode = true
	current_line = 1
	current_char = 1
	
	--print("File loaded: " .. file_name)
	--print("Lines in file: " .. #lines_stack)
	
	if #lines_stack > 0 then
		obs.timer_add(timer_callback, 100)
		timer_deployed = true
	end 
end


function timer_callback()
	if not source_is_active(source_name) then
		--print("Source " .. source_name .. " is not active")
		return
	end
	current_delay = current_delay - 1
	if current_delay <= 0 then 
		if not teletype_mode then
			next_line()
		else
			current_char = current_char + 1
			if current_char > string.len(processed_line) then
				teletype_mode = false
				current_delay = full_display_s * 10
			end
		end
	end
	update_display()
end 

function next_line() 
    local is_valid_line = false
	while (is_valid_line == false) do
		current_line = current_line + 1
		if current_line > #lines_stack then
			if reload_on_loop then 
				lines_stack = lines_from(file_name)
			end
			current_line = 1
		end
		current_char = 1
		teletype_mode = true
		current_delay = teletype_delay_ds
		if string.sub(lines_stack[current_line], 1,1) == "#" then
			is_valid_line = false
		else
			is_valid_line = true
		end
	end
	process_line()
end

function process_line()
	processed_line = lines_stack[current_line]
	processed_line = string.gsub(processed_line, "%[date%]", os.date("%d %B %Y"))
end

function update_display() 
	local text_to_display = ""
	if teletype_mode then
		text_to_display = string.sub(processed_line, 1, current_char)
		if use_cursor then
			text_to_display = text_to_display .. get_cursor_char()
		end
	else 
		text_to_display = processed_line
	end
	text_to_display = prefix_chars .. text_to_display 
	local source = obs.obs_get_source_by_name(source_name)
	if source ~= nil then
		local settings = obs.obs_data_create()
		obs.obs_data_set_string(settings, "text", text_to_display)
		obs.obs_source_update(source, settings)
		obs.obs_data_release(settings)
		obs.obs_source_release(source)
	end
end

function get_cursor_char() 
	local retval = use_cursor_char
	if use_rand_cursor then
		local charnum = math.random(string.len(rand_cursor_chars))
		retval = string.sub(rand_cursor_chars, charnum, charnum)
	end
	return retval
end


-- end application-specific functions



