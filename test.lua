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

function async(func)
    CoroutineScheduler:Run(func)
end

function wait(seconds)
    return coroutine.yield(seconds)
end

function setTimeout(delaySeconds, callback)
    async(function()
        wait(delaySeconds)
        callback()
    end)
end

function setLoop(intervalSeconds, callback)
    async(function()
        while true do
            wait(intervalSeconds)
            callback()
        end
    end)
end

function WaitForChild(parent, childName, timeout)
    -- Immediate check if child exists
    if parent[childName] ~= nil then
        return parent[childName]
    end

    local timeWaited = 0
    while true do
        -- Yield until next frame and get frame delta time
        local dt = wait(0)
        timeWaited = timeWaited + dt

        -- Re-check for child existence each frame
        if parent[childName] ~= nil then
            return parent[childName]
        end

        -- Handle timeout if specified
        if timeout and timeWaited >= timeout then
            error(string.format("waitForChild: Timed out after %.2f seconds waiting for '%s'", timeout, childName))
        end
    end
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
