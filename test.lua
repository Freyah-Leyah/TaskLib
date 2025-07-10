local CoroutineScheduler = {
    coroutines = {}
}

function CoroutineScheduler:Run(func)
    local co = coroutine.create(func)
    table.insert(self.coroutines, {
        co = co,
        wait_time = 0,
        elapsed = 0,
        first_run = true
    })
end

local scheduler = CoroutineScheduler

Hooks:PostHook(CoreSetup, "__update", "CoroutineSchedulerUpdate", function(self, _, dt)
    for i = #scheduler.coroutines, 1, -1 do
        local task = scheduler.coroutines[i]
        task.elapsed = task.elapsed + dt

        if task.elapsed >= task.wait_time or task.first_run then
            task.first_run = false
            local success, wait_time_or_error = coroutine.resume(task.co, dt)

            if not success then
                log("[CoroutineScheduler] Error: " .. tostring(wait_time_or_error))
                table.remove(scheduler.coroutines, i)
            elseif coroutine.status(task.co) == "dead" then
                table.remove(scheduler.coroutines, i)
            else
                task.wait_time = wait_time_or_error or 0
                task.elapsed = 0
            end
        end
    end
end)

local function error(...)
    log("[BloxLib] [ERROR] " .. tostring(...))
end

local function warn(...)
    log("[BloxLib] [Warning] " .. tostring(...))
end

function async(func) -- Runs the given function as a coroutine without obstructing the main thread
    CoroutineScheduler:Run(func)
end

-- /////////////////////////////////////////////////////////////////////////
-- /// Helper functions that need to be called within an async context ////
-- ////////////////////////////////////////////////////////////////////////

function wait(seconds) -- [ASYNC] Waits for a specified number of seconds
    return coroutine.yield(seconds)
end

function WaitForChild(parent, childName, timeout) -- [ASYNC] Waits for a child to be added to the parent object and returns it. Defaults to no timeout
    if parent[childName] ~= nil then
        return parent[childName]
    end

    if not timeout then
        warn("WaitForChild(" .. childName .. ") called without timeout. This may lead to an infinite yield if the child never appears.")
    end

    local timeWaited = 0
    while true do
        local dt = wait()
        timeWaited = timeWaited + dt

        if parent[childName] ~= nil then
            return parent[childName]
        end

        if timeout and timeWaited >= timeout then
            error(string.format("WaitForChild() Timed out after %.2f seconds waiting for '%s'", timeout, childName))
            break
        end
    end
end

-- ///////////////////////////////////////////////////////////////////////////////////////////////////
-- /// Helper functions that can be called outside of async context (they call async when needed) ///
-- /////////////////////////////////////////////////////////////////////////////////////////////////

function Delay(delaySeconds, callback) -- Delays execution of callback by delaySeconds
    async(function()
        wait(delaySeconds)
        callback()
    end)
end

function Loop(intervalSeconds, callback) -- Spawns infinite loop that calls callback every intervalSeconds
    async(function()
        while true do
            wait(intervalSeconds)
            callback()
        end
    end)
end

function loopUntil(intervalSeconds, callback, timeout) -- Spawns a loop that calls callback every intervalSeconds until timeout is reached
    async(function()
        local elapsed = 0
        while elapsed < timeout do
            wait(intervalSeconds)
            callback()
            elapsed = elapsed + intervalSeconds
        end
    end)
end