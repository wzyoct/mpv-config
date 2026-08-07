-- cache-display.lua
-- 将北京时间 / 缓冲可观看时间（倍速折算）/ 网速 注入 uosc 顶栏副标题

mp.add_periodic_timer(0.5, function()
    local cache_sec = mp.get_property_number("demuxer-cache-duration", 0)
    local speed_bytes = mp.get_property_number("cache-speed", 0)
    local speed = mp.get_property_number("speed", 1)

    -- 按倍速折算实际可观看的缓冲时间
    local watchable_sec = (speed > 0) and (cache_sec / speed) or cache_sec

    -- 格式化网速
    local speed_text
    if speed_bytes >= 1024 * 1024 then
        speed_text = string.format("%.2f MiB/s", speed_bytes / (1024 * 1024))
    elseif speed_bytes >= 1024 then
        speed_text = string.format("%.1f KiB/s", speed_bytes / 1024)
    else
        speed_text = string.format("%d B/s", speed_bytes)
    end

    -- 格式化缓冲时间（倍速折算后）
    local cache_text
    if watchable_sec == 0 then
        cache_text = "0s"
    elseif watchable_sec >= 60 then
        local minutes = math.floor(watchable_sec / 60)
        local seconds = math.floor(watchable_sec % 60)
        cache_text = seconds == 0 and string.format("%dm", minutes) or string.format("%dm%ds", minutes, seconds)
    else
        cache_text = string.format("%.1fs", watchable_sec)
    end

    -- 北京时间
    local time_text = os.date("%H:%M")

    -- 拼接：时间 / 缓冲 / 网速
    local text = time_text .. " / " .. cache_text .. " / " .. speed_text

    -- 注入 uosc 顶栏副标题
    mp.set_property("user-data/cache-display/info", text)
end)
