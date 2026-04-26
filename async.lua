local CoroutineScheduler = {
    coroutines = {},
    next_id = 0,
    max_resumes_per_frame = 100
}

_G.task = _G.task or {}
local scheduler = CoroutineScheduler

-- //////////////////////////////////////////////////////////
-- Logging
-- //////////////////////////////////////////////////////////

local function logInfo(...)
    log("[TaskLib] " .. tostring(...))
end

local function logWarn(...)
    log("[TaskLib] [WARNING] " .. tostring(...))
end

local function logError(...)
    log("[TaskLib] [ERROR] " .. tostring(...))
end

-- //////////////////////////////////////////////////////////
-- Internal Helpers
-- //////////////////////////////////////////////////////////

local function safeCall(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        logError(err)
    end
end

local function createTask(func, name, run_once)
    scheduler.next_id = scheduler.next_id + 1

    local co = coroutine.create(func)

    local entry = {
        id = scheduler.next_id,
        name = name or ("Task#" .. tostring(scheduler.next_id)),
        co = co,
        wait_time = 0,
        elapsed = 0,
        first_run = true,
        cancelled = false,
        run_once = run_once or false
    }

    table.insert(scheduler.coroutines, entry)
    return entry
end

local function removeTask(index)
    table.remove(scheduler.coroutines, index)
end

-- //////////////////////////////////////////////////////////
-- Frame Update
-- //////////////////////////////////////////////////////////

Hooks:PostHook(CoreSetup, "__update", "CoroutineSchedulerUpdate", function(self, _, dt)
    local resumes = 0

    for i = #scheduler.coroutines, 1, -1 do
        if resumes >= scheduler.max_resumes_per_frame then
            break
        end

        local t = scheduler.coroutines[i]

        if t.run_once and not t.first_run then
            removeTask(i)
        end

        if t.cancelled then
            removeTask(i)
        else
            t.elapsed = t.elapsed + dt

            if t.first_run or t.elapsed >= t.wait_time then
                t.first_run = false
                resumes = resumes + 1

                local success, result = coroutine.resume(t.co, t, dt)

                if not success then
                    logError("[" .. t.name .. "] " .. tostring(result))
                    removeTask(i)

                elseif coroutine.status(t.co) == "dead" then
                    removeTask(i)

                else
                    t.wait_time = tonumber(result) or 0
                    t.elapsed = 0
                end
            end
        end
    end
end)

-- //////////////////////////////////////////////////////////
-- Public API
-- //////////////////////////////////////////////////////////

function task.new(func, name, run_once)
    return createTask(func, name, run_once)
end

function task.spawn(func, name, run_once)
    return createTask(func, name, run_once)
end

function task.cancel(handle)
    if handle then
        handle.cancelled = true
    end
end

function task.isRunning(handle)
    if not handle or handle.cancelled then
        return false
    end

    return coroutine.status(handle.co) ~= "dead"
end

function task.stats()
    local active = 0

    for _, t in ipairs(scheduler.coroutines) do
        if not t.cancelled then
            active = active + 1
        end
    end

    logInfo("Active tasks: " .. tostring(active))
    return active
end

-- //////////////////////////////////////////////////////////
-- Async Helpers (must be used inside coroutine)
-- //////////////////////////////////////////////////////////

function task.wait(seconds)
    return coroutine.yield(seconds or 0)
end

function task.WaitForChild(parent, childName, timeoutSeconds)
    if parent[childName] ~= nil then
        return parent[childName]
    end

    if not timeoutSeconds then
        logWarn("WaitForChild(" .. tostring(childName) .. ") called without timeout. This may cause an infinite wait if the child never appears.")
    end

    local waited = 0

    while true do
        local dt = task.wait()
        waited = waited + dt

        if parent[childName] ~= nil then
            return parent[childName]
        end

        if timeoutSeconds and waited >= timeoutSeconds then
            logError(
                string.format(
                    "WaitForChild timed out after %.2f sec waiting for '%s'",
                    timeoutSeconds,
                    tostring(childName)
                )
            )
            return nil
        end
    end
end

-- //////////////////////////////////////////////////////////
-- Timer Utilities
-- //////////////////////////////////////////////////////////

function task.timeout(seconds, callback, name)
    return task.new(function(self_task)
        task.wait(seconds)
        callback(self_task)
    end, name or "timeout")
end

function task.delay(seconds, callback, name)
    return task.timeout(seconds, callback, name or "delay")
end

function task.every(intervalSeconds, callback, name)
    return task.new(function(self_task)
        while true do
            task.wait(intervalSeconds)
            local result = callback(self_task)
            if result == false then break end
        end
    end, name or "every")
end

function task.loopInf(intervalSeconds, callback, name)
    return task.every(intervalSeconds, callback, name or "loopInf")
end

function task.loopUntil(intervalSeconds, callback, timeoutSeconds, name)
    return task.new(function(self_task)
        local elapsed = 0

        while elapsed < timeoutSeconds do
            task.wait(intervalSeconds)
            elapsed = elapsed + intervalSeconds
            local result = callback(self_task)
            if result == false then break end
        end
    end, name or "loopUntil")
end