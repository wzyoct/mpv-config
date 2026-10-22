local utils = require 'mp.utils'
local msg = require 'mp.msg'

local helper = mp.command_native({'expand-path', '~~/tools/subtitle-layout.ps1'})
local cache = mp.command_native({'expand-path', '~~/subtitles/layout'})
local font_option = mp.get_property('sub-fonts-dir', '')
local fonts = mp.command_native({'expand-path', font_option ~= '' and font_option or '~~/fonts'})
local ffmpeg = mp.command_native({'expand-path', '~~/../ffmpeg.exe'})
local base_override = mp.get_property('sub-ass-override', 'scale')
local default_scale = mp.get_property_number('sub-scale', 1.5)
local base_window_scale = mp.get_property('sub-ass-scale-with-window', 'no')
local base_margins = mp.get_property('sub-ass-force-margins', 'no')
local generation, serial = 0, 0
local media, active, request_id, timer
local sources, generated, resume_tracks = {}, {}, {}
local scales = {text = default_scale, image = 1}
local changing, ready = false, false
local cache_ready = false
local resumed_scale

local function rendering(plain)
    mp.set_property('sub-ass-scale-with-window', plain and 'yes' or base_window_scale)
    mp.set_property('sub-ass-force-margins', plain and 'yes' or base_margins)
end

local function ass_color(option)
    local a, r, g, b = mp.get_property(option):match('^#(%x%x)(%x%x)(%x%x)(%x%x)$')
    assert(a, '无效的字幕颜色：' .. option)
    return string.format('&H%02X%s%s%s', 255 - tonumber(a, 16), b, g, r)
end

local function plain_style()
    local dimensions = mp.get_property_native('osd-dimensions') or {w = 1280, h = 720}
    return {
        PlayResX = math.floor(720 * dimensions.w / math.max(1, dimensions.h) + 0.5),
        Fontname = mp.get_property('sub-font'), Fontsize = mp.get_property_number('sub-font-size', 38),
        MarginL = mp.get_property_number('sub-margin-x', 19), MarginR = mp.get_property_number('sub-margin-x', 19),
        MarginV = mp.get_property_number('sub-margin-y', 34), Outline = mp.get_property_number('sub-border-size', 2),
        Shadow = mp.get_property_number('sub-shadow-offset', 1), Spacing = mp.get_property_number('sub-spacing', 0),
        PrimaryColour = ass_color('sub-color'), OutlineColour = ass_color('sub-border-color'), BackColour = ass_color('sub-shadow-color'),
        Bold = mp.get_property_bool('sub-bold', false) and -1 or 0, Italic = mp.get_property_bool('sub-italic', false) and -1 or 0,
    }
end

local function resume_args()
    local directory = mp.get_property('watch-later-directory', '')
    if directory == '' then directory = '~~/watch_later' end
    local args = {'powershell.exe', '-NoProfile', '-NonInteractive', '-File', helper,
        '-ResumeMedia', mp.get_property('path'), '-ResumeDirectory', mp.command_native({'expand-path', directory})}
    if mp.get_property_bool('ignore-path-in-watch-later-config', false) then args[#args + 1] = '-IgnorePath' end
    return args
end

local function set_scale(value)
    changing = true
    mp.set_property_number('sub-scale', value)
    changing = false
end

local function failure(reason)
    msg.error(reason)
    mp.set_property('user-data/subtitle-layout/status', 'error: ' .. reason)
    mp.osd_message('字幕重排失败，保留当前字幕；详情见控制台', 6)
end

local function cancel()
    serial = serial + 1
    if timer then timer:kill(); timer = nil end
    if request_id then mp.abort_async_command(request_id); request_id = nil end
end

local function local_path(path)
    if not path or path:match('^%a[%w+.-]*://') then return nil end
    if path:sub(1, 7) == 'memory:' then return nil end
    if not path:match('^%a:[/\\]') and not path:match('^[/\\]') then
        path = utils.join_path(mp.get_property('working-directory'), path)
    end
    return path
end

local function selected()
    local sid = mp.get_property_number('sid')
    for _, track in ipairs(mp.get_property_native('track-list', {})) do
        if track.type == 'sub' and track.id == sid then return track end
    end
end

local function prepare(source)
    cancel()
    local token, file_generation = serial, generation
    local source_path
    if source.external then source_path = local_path(source['external-filename']) else source_path = media end
    if not source_path then
        mp.set_property('user-data/subtitle-layout/status', 'unsupported: non-local subtitle')
        return
    end
    local desired = scales.text
    if desired < 0.1 or desired > 10 then
        failure('ASS 重排倍率范围为 0.1–10；请调小倍率')
        return
    end
    local job = {
        source = source_path, media = media, stream = source.external and -1 or source['ff-index'],
        scale = desired, font = mp.get_property('sub-font'), fonts = fonts,
        cache = cache, ffmpeg = ffmpeg,
        srt = source.srt, plain = source.srt and plain_style() or nil,
    }
    if job.stream == nil then failure('无法确定内嵌 ASS 的流索引'); return end
    if not cache_ready then
        local mkdir = mp.command_native({name = 'subprocess', args = {
            'powershell.exe', '-NoProfile', '-NonInteractive', '-File', helper, '-CacheRoot', cache,
        }, playback_only = false, capture_stdout = true, capture_stderr = true})
        if mkdir.status ~= 0 then failure(mkdir.stderr or '无法建立字幕缓存目录'); return end
        cache_ready = true
    end
    local request = utils.join_path(cache, 'request-' .. utils.getpid() .. '-' .. generation .. '-' .. token .. '.json')
    local f, err = io.open(request, 'wb')
    if not f then failure(err); return end
    f:write(utils.format_json(job)); f:close()
    mp.set_property('user-data/subtitle-layout/status', 'processing')
    request_id = mp.command_native_async({name = 'subprocess', args = {
        'powershell.exe', '-NoProfile', '-NonInteractive', '-File', helper, '-Request', request,
    }, playback_only = false, capture_stdout = true, capture_stderr = true}, function(success, result, error)
        os.remove(request)
        if token ~= serial or file_generation ~= generation or not active or active.id ~= source.id then return end
        request_id = nil
        if not success or not result or result.status ~= 0 then
            failure((result and result.stderr) or error or '字幕处理进程失败')
            return
        end
        local report = utils.parse_json(result.stdout)
        local old_track = selected()
        if not old_track or (generated[old_track.id] or old_track).id ~= source.id then return end
        if report and report.native then
            if generated[mp.get_property_number('sid')] then
                changing = true; mp.set_property_number('sid', source.id); changing = false
            end
            rendering(false)
            mp.set_property('sub-ass-override', base_override)
            mp.set_property_native('user-data/subtitle-layout/report', report)
            mp.set_property('user-data/subtitle-layout/status', 'native')
            return
        end
        if not report or not report.path or not utils.file_info(report.path) then
            failure('字幕处理进程未返回有效文件'); return
        end
        local added, add_error = pcall(mp.commandv, 'sub-add', report.path, 'auto', '[自动排版] ' .. (source.title or source.lang or 'ASS'), source.lang or '')
        if not added then failure(tostring(add_error)); return end
        local new_id
        for _, track in ipairs(mp.get_property_native('track-list', {})) do
            if track.type == 'sub' and track['external-filename'] == report.path then new_id = track.id end
        end
        if not new_id then failure('无法找到排版后的字幕轨'); return end
        generated[new_id] = source
        resume_tracks[new_id] = source.id
        changing = true
        rendering(source.srt)
        -- Font sizes in the copy already include the requested scale.
        mp.set_property('sub-ass-override', 'yes')
        mp.set_property_number('sid', new_id)
        changing = false
        for id, original in pairs(generated) do
            if id ~= new_id and original.id == source.id then
                generated[id] = nil
                mp.commandv('sub-remove', id)
            end
        end
        report.track_id = new_id
        mp.set_property_native('user-data/subtitle-layout/report', report)
        mp.set_property('user-data/subtitle-layout/status', 'ready')
        msg.info(string.format('对白 %d，双语 %d，保留特殊行 %d，%s倍率 %.1f', report.changed, report.pairs, report.skipped, report.bilingual and '中文' or '字幕', desired))
        if report.uncertain > 0 then
            msg.warn(string.format('%d 条语言边界不明确的对白保留 1.0 倍', report.uncertain))
            mp.osd_message('部分字幕语言边界不明确，已保留原始大小；详情见控制台', 5)
        end
    end)
end

local function schedule()
    cancel()
    if not active or active.kind ~= 'text' or not (active.ass or active.srt) then return end
    mp.set_property('user-data/subtitle-layout/status', 'queued')
    local source = active
    timer = mp.add_timeout(0.25, function() timer = nil; prepare(source) end)
end

local function track_changed()
    if not ready or changing then return end
    local track = selected()
    if not track then
        cancel(); active = nil
        mp.set_property('sub-ass-override', base_override)
        rendering(false)
        mp.set_property('user-data/subtitle-layout/status', 'disabled')
        return
    end
    local source = generated[track.id] or sources[track.id]
    if not source then
        source = track
        local codec = (track.codec or ''):lower()
        source.kind = (codec:find('pgs') or codec:find('dvd_subtitle') or codec:find('dvb_subtitle') or codec == 'vobsub') and 'image' or 'text'
        source.ass = codec == 'ass' or codec == 'ssa'
        source.srt = codec == 'subrip' or codec == 'srt'
        sources[track.id] = source
    end
    if active and active.id == source.id and generated[track.id] then
        mp.set_property('sub-ass-override', 'yes')
        rendering(source.srt)
        return
    end
    cancel(); active = source
    set_scale(scales[source.kind])
    mp.set_property('sub-ass-override', generated[track.id] and 'yes' or base_override)
    rendering(generated[track.id] and source.srt)
    mp.set_property('user-data/subtitle-layout/status', source.kind == 'image' and 'image: manual scale' or 'native')
    schedule()
end

mp.register_event('start-file', function()
    cancel(); generation = generation + 1
    ready, active, media, resumed_scale = false, nil, nil, nil
    sources, generated, resume_tracks = {}, {}, {}
    scales = {text = default_scale, image = 1}
    mp.set_property('sub-ass-override', base_override)
    rendering(false)
    set_scale(default_scale)
end)

mp.add_hook('on_load', 50, function(hook)
    if not local_path(mp.get_property('path')) or not mp.get_property_bool('resume-playback', true) then return end
    hook:defer()
    mp.command_native_async({name = 'subprocess', args = resume_args(), playback_only = false,
        capture_stdout = true, capture_stderr = true}, function(success, result)
        if success and result.status == 0 then
            local saved = utils.parse_json(result.stdout)
            resumed_scale = saved and saved.scale
        else msg.warn('无法检查已有字幕续播倍率：' .. ((result and result.stderr) or '读取失败')) end
        hook:cont()
    end)
end)

mp.add_hook('on_unload', 50, function(hook)
    if not media or not next(resume_tracks) then return end
    local args = resume_args()
    local mapping = {}
    for id, original in pairs(resume_tracks) do mapping[#mapping + 1] = id .. ':' .. original end
    for _, value in ipairs({'-SidMap', table.concat(mapping, ','), '-BaseOverride', base_override,
        '-BaseMargins', base_margins, '-BaseWindowScale', base_window_scale}) do
        args[#args + 1] = value
    end
    hook:defer()
    mp.command_native_async({name = 'subprocess', args = args, playback_only = false,
        capture_stdout = true, capture_stderr = true}, function(success, result)
        if not success or result.status ~= 0 then failure((result and result.stderr) or '修复字幕续播轨号失败') end
        hook:cont()
    end)
end)

mp.register_event('file-loaded', function()
    media = local_path(mp.get_property('path'))
    local track = selected()
    local restored = mp.get_property_number('sub-scale', default_scale)
    -- An explicitly saved scale belongs to the initially selected track, even if it equals today's default.
    if track and (resumed_scale or restored ~= default_scale) then
        local codec = (track.codec or ''):lower()
        local image = codec:find('pgs') or codec:find('dvd_subtitle') or codec:find('dvb_subtitle') or codec == 'vobsub'
        scales[image and 'image' or 'text'] = resumed_scale or restored
    else scales.text = restored end
    ready = true
    track_changed()
end)
mp.register_event('end-file', function() ready = false; cancel() end)
mp.observe_property('sid', 'native', track_changed)
mp.observe_property('sub-scale', 'number', function(_, value)
    if not ready or changing or not active or not value then return end
    if math.abs(value - scales[active.kind]) < 0.00001 then return end
    scales[active.kind] = value
    schedule()
end)
local last_aspect
mp.observe_property('osd-dimensions', 'native', function(_, dimensions)
    if not dimensions or dimensions.h == 0 then return end
    local aspect = math.floor(720 * dimensions.w / dimensions.h + 0.5)
    if last_aspect ~= aspect and ready and active and active.srt then schedule() end
    last_aspect = aspect
end)
