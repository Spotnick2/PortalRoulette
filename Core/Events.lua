local _, ns = ...

local Events = {
    handlers = {},
}
ns.Events = Events

local frame = CreateFrame("Frame")
Events.frame = frame

function Events:Register(eventName, handler)
    if type(eventName) ~= "string" or type(handler) ~= "function" then
        return
    end

    local eventHandlers = self.handlers[eventName]
    if not eventHandlers then
        eventHandlers = {}
        self.handlers[eventName] = eventHandlers
        frame:RegisterEvent(eventName)
    end

    eventHandlers[#eventHandlers + 1] = handler
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
