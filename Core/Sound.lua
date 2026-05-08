local _, ns = ...

local Sound = {
    lastPlayedAt = {},
}
ns.Sound = Sound

local DEFAULT_CHANNEL = "SFX"

local soundPaths = {
    Open = ns.Media.SOUND_OPEN,
    Close = ns.Media.SOUND_CLOSE,
    NodeHover = ns.Media.SOUND_NODE_HOVER,
    NodeClick = ns.Media.SOUND_NODE_CLICK,
    HearthstoneHover = ns.Media.SOUND_HEARTHSTONE_HOVER,
    HearthstoneClick = ns.Media.SOUND_HEARTHSTONE_CLICK,
    KarazhanHover = ns.Media.SOUND_KARAZHAN_HOVER,
    Error = ns.Media.SOUND_ERROR,
}

local soundThrottleSeconds = {
    NodeHover = 0.10,
    HearthstoneHover = 0.10,
    KarazhanHover = 0.10,
    Error = 0.20,
}

local hoverKeys = {
    NodeHover = true,
    HearthstoneHover = true,
    KarazhanHover = true,
}

local validChannels = {
    SFX = true,
    Master = true,
    Ambience = true,
}

function Sound:GetChannel()
    local channel = ns.db and ns.db.soundChannel or DEFAULT_CHANNEL
    if validChannels[channel] then
        return channel
    end
    return DEFAULT_CHANNEL
end

function Sound:IsEnabled(soundKey, options)
    if not ns.db or not ns.db.soundsEnabled then
        return false
    end

    local isHover = (options and options.hover) and true or false
    if not isHover and hoverKeys[soundKey] then
        isHover = true
    end
    if isHover and ns.db.hoverSoundsEnabled == false then
        return false
    end

    return true
end

function Sound:IsThrottled(soundKey, options)
    local throttle = soundThrottleSeconds[soundKey] or 0
    if options and type(options.throttle) == "number" then
        throttle = options.throttle
    end
    if throttle <= 0 then
        return false
    end

    local now = (type(GetTime) == "function" and GetTime()) or 0
    local last = self.lastPlayedAt[soundKey] or 0
    if (now - last) < throttle then
        return true
    end

    self.lastPlayedAt[soundKey] = now
    return false
end

function Sound:Play(soundKey, options)
    local path = soundPaths[soundKey]
    if not path then
        return false
    end
    if type(PlaySoundFile) ~= "function" then
        return false
    end
    if not self:IsEnabled(soundKey, options) then
        return false
    end
    if self:IsThrottled(soundKey, options) then
        return false
    end

    local ok, result = pcall(PlaySoundFile, path, self:GetChannel())
    if not ok then
        return false
    end

    return result and true or false
end
