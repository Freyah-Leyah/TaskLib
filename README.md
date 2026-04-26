# TaskLib for Payday 2: Coroutine Scheduler

TaskLib provides a coroutine scheduler for Payday 2. It hooks into the CoreSetup update loop, allowing developers to write asynchronous logic without relying on easier loop, waits and events managment.

## Getting Started

TaskLib is accessible globally via the task table (or `_G.task`). Because it automatically hooks into `CoreSetup:__update`, tasks are processed automatically each frame.

**❗Important:** Any function that yields (e.g., `task.wait()` or `task.WaitForChild()`) must be executed within a coroutine initialized by this library.

**Note**: For stability reasons, there is a hardcoded limit of 100 task resumes per frame. If this limit is reached, any remaining tasks will be skipped for the current frame and resumed during the next one. (You will probably never reach that limit though)

## Core API: Managing Tasks

These functions are used to initialize, terminate, and monitor tasks.

### task.spawn(func, \[name\], \[run_once\])

Creates and immediately schedules a new coroutine.

_(Alias: task.new)_

- **func** _(function)_: The function to execute asynchronously.
- **name** _(string, optional)_: An identifier for the task, useful for debugging. Defaults to "Task#ID".
- **run_once** _(boolean, optional)_: If true, the task is removed from the scheduler after its initial execution, regardless of yielding. Defaults to false.
- **Returns:** TaskHandle table.

**Example:**
```lua
local myTask = task.spawn(function()
      log("Task initialized.")
      task.wait(2)
      log("Task completed after 2 seconds.")
end, "InitializationTask")
```
### task.cancel(handle)

Terminates a scheduled task. The task is marked as cancelled and will be removed during the next frame update.

- **handle** _(TaskHandle)_: The handle returned by task.spawn().

**Example:**
```lua
local myTask = task.spawn(function()  
      task.wait(10)  
      log("This will not print.")  
end)  
-- Cancel the task before it can finish waiting  
task.cancel(myTask)
```
### task.isRunning(handle)

Evaluates whether a specific task is currently active in the scheduler.

- **handle** _(TaskHandle)_: The task handle to check.
- **Returns:** true if the task is active and has not been cancelled or finished; false otherwise.

**Example:**
```lua
local myTask = task.spawn(function()  
      task.wait(5)  
end)
log(tostring(task.isRunning(myTask))) -- Outputs: true
```
### task.stats()

Logs and returns the total number of currently active tasks. Useful for memory management and debugging runaway loops.

- **Returns:** _(number)_ The count of active tasks.

**Example:**
```lua
local activeCount = task.stats()  
      if activeCount > 50 then  
          log("[Warning] High number of active tasks: " .. tostring(activeCount))
      end
```
## Async Helpers (Yielding)

These functions yield the current coroutine. They must be called from within a task.spawn callback.

### task.wait(\[seconds\])

Yields the current coroutine for a specified duration.

- **seconds** _(number, optional)_: The duration to yield in seconds. If omitted or set to 0, it yields for exactly one frame.

**Example:**
```lua
task.spawn(function()  
    log("Starting sequence...")  
    task.wait(2.5) -- Yields for 2.5 seconds  
    log("Sequence complete.")  
end)
```
### task.WaitForChild(parent, childName, \[timeoutSeconds\])

Yields the coroutine until a specific key is populated within a parent table.

- **parent** _(table)_: The table to monitor.
- **childName** _(string/any)_: The key expected to be assigned in the parent table.
- **timeoutSeconds** _(number, optional)_: Maximum time to wait in seconds. If exceeded, logs a warning and returns nil.
- **Returns:** The assigned value, or nil if the timeout is reached.

**Example:**
```lua
task.spawn(function()  
  -- Wait up to 10 seconds for the player manager to initialize  
  local loc = task.WaitForChild(managers, "player", 10)  
  if loc then  
      log("Player manager is ready.")  
   else  
      log("[Error] Player manager failed to load within timeout.")  
  end  
end)
```
## Timer Utilities

Utility wrappers for common delay and interval operations. These do not require manual coroutine initialization.

### task.delay(seconds, callback, \[name\])

Executes a callback function after a specified delay.

_(Alias: task.timeout)_

- **seconds** _(number)_: Delay in seconds.
- **callback** _(function)_: The function to execute.
- **name** _(string, optional)_: Task identifier.

**Example:**
```lua
task.delay(3.0, function()  
    log("This executes exactly 3 seconds later.")  
end, "DelayedLog")
```
### task.every(intervalSeconds, callback, \[name\])

Executes a callback repeatedly at a specified interval. The loop terminates if the callback explicitly returns false.

_(Alias: task.loopInf)_

- **intervalSeconds** _(number)_: Time between executions in seconds.
- **callback** _(function)_: The function to execute.
- **name** _(string, optional)_: Task identifier.

**Example:**
```lua
task.every(1.0, function()  
    local player = managers.player:player_unit()  
    
    if not alive(player) then 
      return false -- Returning false cancels the interval loop  
    end  
    
    local damage_ext = player:character_damage()
    if damage_ext:get_real_health() < damage_ext:_max_health() then  
        damage_ext:restore_health(5, false)  
        return true  
    end
    
return false -- Cancel loop once fully healed  
end, "RegenLoop")
```
### task.loopUntil(intervalSeconds, callback, timeoutSeconds, \[name\])

Executes a callback repeatedly at a specified interval, terminating automatically when the maximum duration is reached.

- **intervalSeconds** _(number)_: Time between executions.
- **callback** _(function)_: The function to execute. Can return false to terminate early.
- **timeoutSeconds** _(number)_: The maximum total runtime for the loop.
- **name** _(string, optional)_: Task identifier.

**Example:**
```lua
task.loopUntil(0.5, function()  
      log("Checking conditions...")  
      -- Condition logic here  
      return true  
end, 5.0, "StartupCheck")  
-- This will log every 0.5 seconds for a maximum of 5 seconds.
```
