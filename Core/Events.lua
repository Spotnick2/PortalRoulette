local _, ns = ...

local Events = {
    handlers = {},
}
ns.Events = Events

local frame = CreateFrame("Frame", nil, WorldFrame)
Events.frame = frame

-- Register a handler. An event the client does not know is reported through
-- ns.API.eventFailures (/pr debug) instead of breaking the load.
function Events:Register(eventName, handler)
    if type(eventName) ~= "string" or type(handler) ~= "function" then
        return false
    end

    local eventHandlers = self.handlers[eventName]
    if not eventHandlers then
        if not ns.API.RegisterEvent(frame, eventName) then
            return false
        end
        eventHandlers = {}
        self.handlers[eventName] = eventHandlers
    end

    eventHandlers[#eventHandlers + 1] = handler
    return true
end

frame:SetScript("OnEvent", function(_, eventName, ...)
    local eventHandlers = Events.handlers[eventName]
    if not eventHandlers then
        return
    end

    for _, handler in ipairs(eventHandlers) do
        handler(eventName, ...)
    end
end)
