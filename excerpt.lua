-- This script allows to create excerpts of a video that is played,
-- press "i" to mark the begin of the range to excerpt,
-- press "o" to mark the end   of the range to excerpt,
-- use the chapter markers on the OSD to jump between IN and OUT points,
-- press "E" to toggle between encoding (precise, negligible quality loss) and no-encoding (very fast, no quality loss),
-- press "x" to actually start the creation of the excerpt,
--  which will be done by starting an external executable (ffmpeg)
-- (see bottom of this file for all key bindings)

-- initialization:

utils = require 'mp.utils'

excerpt_begin = 0.0
excerpt_end   = mp.get_property_native("length")
if excerpt_end == nil or excerpt_end == "none" then
 excerpt_end = 0.0
end

mp.set_property("hr-seek-framedrop","no")
mp.set_property("options/keep-open","always")

function excerpt_on_eof()
	-- pause upon reaching the end of the file
	mp.msg.log("info", "playback reached end of file")
	mp.set_property("pause","yes")
	mp.commandv("seek", 100, "absolute-percent", "exact")
end
mp.register_event("eof-reached", excerpt_on_eof)

-- range marking

function excerpt_mark_begin_handler() 
	pt = mp.get_property_native("playback-time")
	if pt == nil or pt == "none" then
		pt = 0.0
	end

    local all_chapters = mp.get_property_native("chapter-list")
	-- table.remove(all_chapters,2) -- TODO find an elegant way to do this without breaking on different lua versions
	all_chapters[1] = {
		title = "in",
		time = pt
	}
	mp.set_property_native("chapter-list", all_chapters)
 
	excerpt_begin = pt
	if excerpt_begin > excerpt_end then
		excerpt_end = excerpt_begin
	end

	local message = "IN point set."
	mp.msg.log("info", message)
	mp.osd_message(message, 5)

	-- alas, the following setting seems to not take effect - needs
	-- to be specified on the command line of mpv, instead:
	mp.set_property("options/script-opts","osc-layout=bottombar,osc-hidetimeout=120000")

 end

function excerpt_mark_end_handler() 
	pt = mp.get_property_native("playback-time")
	if pt == nil or pt == "none" then
		pt = 0.0
	end

    local all_chapters = mp.get_property_native("chapter-list")
	all_chapters[2] = {
		title = "out",
		time = pt
	}
	mp.set_property_native("chapter-list", all_chapters)
	
	excerpt_end = pt
	if excerpt_end < excerpt_begin then
		excerpt_begin = excerpt_end
	end

	local message = "OUT point set."
	mp.msg.log("info", message)
	mp.osd_message(message, 5)
end

-- writing
srcname = ""
srcpath = ""
srcext = ""
installed_gpus = ""
encoding = true
ffmpeg_profiles = {}
export_profile_idx = 1

function get_destination_filename()	
	srcname   = mp.get_property_native("filename")
	local srcnamene = mp.get_property_native("filename/no-ext")	
	local ext_length = string.len(srcname) - string.len(srcnamene)
	srcext = string.sub(srcname, -ext_length)
	local name_length = string.len(tostring(srcname))
	srcpath = tostring(mp.get_property_native("path")) -- string.sub(tostring(mp.get_property_native("path")), name_length)
	return tostring(srcpath .. ".excerpt_" .. excerpt_begin .. "-" .. excerpt_end)
end

function excerpt_encoding_toggle_handler() 
	export_profile_idx = (export_profile_idx % #ffmpeg_profiles) + 1
	mp.osd_message("Export profile: " .. ffmpeg_profiles[export_profile_idx][1], 3)
end

function excerpt_write_handler() 
	if excerpt_begin == excerpt_end then
		message = "excerpt_write: not writing because begin == end == " .. excerpt_begin
		mp.osd_message(message, 3)
		return
	end
 	
	dstname = get_destination_filename()
	duration = excerpt_end - excerpt_begin

	if (dstname == "") then
		-- file name creation has failed
		return
	end

	local message = ""
	message = message .. "writing to destination file '" .. dstname .. "'" .. "\nPlease wait..." 
	mp.msg.log("info", message)
	mp.osd_message(message, 60)

	local cmd = {}
	cmd["cancellable"] = false
	cmd["args"] = {}

	table.insert(cmd["args"], "ffmpeg")

	-- try to enable HW acceleration if user selected a GPU profile
	if string.find(ffmpeg_profiles[export_profile_idx][1], "GPU") then
		-- enable HW acceleration only if supported
		if string.find(installed_gpus, "nvidia")  then
			table.insert(cmd["args"], "-hwaccel") 
			table.insert(cmd["args"], "cuda")
			table.insert(cmd["args"], "-hwaccel_output_format")
			table.insert(cmd["args"], "cuda")
		elseif string.find(installed_gpus, "intel") then
			table.insert(cmd["args"], "-hwaccel") 
			table.insert(cmd["args"], "vaapi")
			table.insert(cmd["args"], "-hwaccel_output_format") 
			table.insert(cmd["args"], "vaapi")
			table.insert(cmd["args"], "-vaapi_device") 
			table.insert(cmd["args"], "/dev/dri/renderD128") 
		end
	end

	-- set input file and cut options
	table.insert(cmd["args"], "-i")
	table.insert(cmd["args"], tostring(srcpath))
	table.insert(cmd["args"], "-ss")
	table.insert(cmd["args"], tostring(excerpt_begin))
	table.insert(cmd["args"], "-t")
	table.insert(cmd["args"], tostring(duration))

	-- set encoding parameters
	for k, v in ipairs(ffmpeg_profiles[export_profile_idx]) do
		if k == 1 then
			-- mp.osd_message("Exporting with profile: " .. v, 1)
		else
			table.insert(cmd["args"], v)
		end
	end

	-- preserve original extension if user specified "." or apply user provided extension.
	local dstext_idx = #ffmpeg_profiles[export_profile_idx]
	local dstext = ffmpeg_profiles[export_profile_idx][dstext_idx]
	if dstext == "." then
		cmd["args"][#cmd["args"]] = dstname .. srcext
	else
		cmd["args"][#cmd["args"]] = dstname .. dstext
	end 

	local res = utils.subprocess(cmd)
	
	if (res["status"] ~= 0) then
		message = message .. "failed!\nfailed to run excerpt - status = " .. res["status"]
		if (res["error"] ~= nil) then
			message = message .. ", error message: " .. res["error"]
		end
		mp.msg.log("error", message)
		mp.osd_message(message, 10)
	else
		mp.msg.log("info", "excerpt '" .. dstname .. "' written.")
		message = message .. "\n DONE!"
		mp.osd_message(message, 10)
	end
 
end

-- things to do whenever a new file was loaded:

function os.capture(cmd, raw)
	local f = assert(io.popen(cmd, 'r'))
	local s = assert(f:read('*a'))
	f:close()
	if raw then return s end
	s = string.gsub(s, '^%s+', '')
	s = string.gsub(s, '%s+$', '')
	s = string.gsub(s, '[\n\r]+', ' ')
	return s
end

function excerpt_on_loaded()
	mp.osd_message("excerpt: use i and o to set IN and OUT points.", 3)

	local operating_system = string.lower(os.capture("uname"))
	installed_gpus = string.lower(os.capture("lspci -k | grep -E 'VGA|3D|Display'"))

	-- Set GPU profiles
	if operating_system == "darwin" then
		table.insert(ffmpeg_profiles, {"ACCURATE (MacOS GPU)", "-c:v", "h264_videotoolbox", "-b:v", "10000k", "-c:a", "aac", ".mp4"})
	else 
		if string.find(installed_gpus, "nvidia")  then
			table.insert(ffmpeg_profiles, {"ACCURATE (NVIDIA GPU)", "-c:v", "h264_nvenc", "-preset", "slow", "-c:a", "aac", ".mp4"})
		elseif string.find(installed_gpus, "intel")  then
			table.insert(ffmpeg_profiles, {"ACCURATE (INTEL GPU)", "-vf", "'format=nv12,hwupload'", "-c:v", "h264_vaapi", "-qp", "25", "-c:a", "aac", ".mp4"})
		end
	end 

	-- ADD YOUR EXPORT PROFILES HERE 
	table.insert(ffmpeg_profiles, {"ACCURATE (CPU)", "-c:v", "libx264", "-crf", "23", "-c:a", "aac", ".mp4"})
	table.insert(ffmpeg_profiles, {"FAST", "-c:v", "copy", "-c:a", "copy", "."})

end

mp.register_event("file-loaded", excerpt_on_loaded)

-- key bindings

mp.add_key_binding("i", "excerpt_mark_begin", excerpt_mark_begin_handler)
mp.add_key_binding("o", "excerpt_mark_end", excerpt_mark_end_handler)
mp.add_key_binding("shift+E", "excerpt_encoding_toggle", excerpt_encoding_toggle_handler)
mp.add_key_binding("x", "excerpt_write", excerpt_write_handler)
