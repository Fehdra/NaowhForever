-- Holidays.lua: which of the game's holidays are on now, read from its calendar (Completo.Holidays).
local ns = _G.NaowhForever

local GetCurrentCalendarTime = C_DateAndTime.GetCurrentCalendarTime
local GetMonthInfo = C_Calendar.GetMonthInfo
local GetNumDayEvents = C_Calendar.GetNumDayEvents
local GetDayEvent = C_Calendar.GetDayEvent

local HOLIDAY = "HOLIDAY"
local FIRST_DAY, MIDDLE_DAY, LAST_DAY = "START", "ONGOING", "END"
local MONTHS = 12
local MINUTES = 60

local on = {}
local opened

local Holidays = {}
ns.Completo.Holidays = Holidays

local function Minutes(t)
    return t.hour * MINUTES + t.minute
end

local function Running(event, now)
    local at, day = Minutes(now), event.sequenceType
    if day == MIDDLE_DAY then return true end
    if day ~= LAST_DAY and at < Minutes(event.startTime) then return false end
    if day ~= FIRST_DAY and at > Minutes(event.endTime) then return false end
    return true
end

function Holidays.Read()
    wipe(on)
    if not opened then
        opened = true
        C_Calendar.OpenCalendar()
    end
    local now, shown = GetCurrentCalendarTime(), GetMonthInfo(0)
    if not (now and shown) then return end
    local offset = (now.year - shown.year) * MONTHS + now.month - shown.month
    for i = 1, GetNumDayEvents(offset, now.monthDay) do
        local event = GetDayEvent(offset, now.monthDay, i)
        if event and event.calendarType == HOLIDAY and Running(event, now) then on[event.eventID] = true end
    end
end

function Holidays.On(id)
    return on[id] == true
end
