-- 目标色彩属性可能不发送变更通知，定时检查以便切换显示模式时恢复伽马。
local sdr = {
    ["srgb"] = true, ["bt.1886"] = true,
    ["gamma1.8"] = true, ["gamma2.0"] = true, ["gamma2.2"] = true,
    ["gamma2.4"] = true, ["gamma2.6"] = true, ["gamma2.8"] = true,
}
local active = false

local function update_target_gamma()
    local input = mp.get_property("video-params/gamma")
    local output = mp.get_property("video-target-params/gamma")
    local should_apply = (input == "pq" or input == "hlg") and sdr[output] == true
    if should_apply ~= active then
        mp.commandv("apply-profile", "hdr-to-sdr-brighter", should_apply and "apply" or "restore")
        active = should_apply
    end
end

mp.register_event("video-reconfig", update_target_gamma)
mp.add_periodic_timer(1, update_target_gamma)
