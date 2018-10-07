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
-- end properties variables

-- begin internal use variables
lines_stack       = {}
current_delay     = 0
current_line      = 1
current_char      = 1
teletype_mode     = false
timer_deployed	  = false
-- end internal use variables

-- begin user configurable options
default_path      = "C:\\"
-- end user configurable options

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
	obs.obs_properties_add_int(props, "teletype_delay_ds", "Teletype Delay (0.1 seconds)", 0, 11, 1)
	obs.obs_properties_add_int(props, "full_display_s", "Full Line Display Time (seconds)", 1, 31, 1)
	
	return props
end

-- A function named script_defaults will be called to set the default settings
function script_defaults(settings)
	obs.obs_data_set_default_int(settings, "teletype_delay_ds", 1)
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
	reset()
end 

function script_load(settings)

end

-- end OBS required functions

-- begin application-specific functions

function reset() 
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
	current_delay = current_delay - 1
	if current_delay <= 0 then 
		if not teletype_mode then
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
		else
			current_char = current_char + 1
			if current_char > string.len(lines_stack[current_line]) then
				teletype_mode = false
				current_delay = full_display_s * 10
			end
		end
	end
	update_display()
end 

function update_display() 
	local text_to_display = ""
	if teletype_mode then
		text_to_display = string.sub(lines_stack[current_line], 1, current_char)
	else 
		text_to_display = lines_stack[current_line]
	end
	local source = obs.obs_get_source_by_name(source_name)
	if source ~= nil then
		local settings = obs.obs_data_create()
		obs.obs_data_set_string(settings, "text", text_to_display)
		obs.obs_source_update(source, settings)
		obs.obs_data_release(settings)
		obs.obs_source_release(source)
	end
end

-- end application-specific functions



