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

function wait(seconds)
    return coroutine.yield(seconds)
end

function setTimeout(delaySeconds, callback)
    async(function()
        wait(delaySeconds)
        callback()
    end)
end

function setInterval(intervalSeconds, callback)
    async(function()
        while true do
            wait(intervalSeconds)
            callback()
        end
    end)
end

function async(func)
    CoroutineScheduler:Run(func)
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
