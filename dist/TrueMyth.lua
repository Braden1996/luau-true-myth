-- luau-true-myth 0.2.0: Maybe, Result and Task for Lua 5.1 (World of Warcraft addons).
-- https://github.com/Braden1996/luau-true-myth - generated from the Luau sources by darklua; do not edit.
-- Listed in a .toc it stores the library as `ns.TrueMyth`; loaded any other way it returns it.
--
-- MIT License
--
-- Copyright (c) 2026 Braden Marshall
-- Copyright (c) 2017 Chris Krycho (true-myth, of which this library is a port)
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

local __DARKLUA_BUNDLE_MODULES = {cache = {}}

do
    do
        local function __modImpl()
            local Delay = {}

            function Delay.fixed(seconds)
                return function()
                    return seconds
                end
            end
            function Delay.immediate()
                return Delay.fixed(0)
            end
            function Delay.none()
                return function()
                    return nil
                end
            end
            function Delay.exponential(options)
                local from = (options and options.from and {
                    options.from,
                } or {1})[1]
                local factor = (options and options.factor and {
                    options.factor,
                } or {2})[1]
                local max = (options and options.max and {
                    options.max,
                } or {
                    math.huge,
                })[1]
                local current = from

                return function()
                    local delay = math.min(current, max)

                    current = current * factor

                    return delay
                end
            end
            function Delay.fibonacci(from)
                local base = from or 1
                local current, following = base, base

                return function()
                    local delay = current

                    current, following = following, current + following

                    return delay
                end
            end
            function Delay.linear(options)
                local from = (options and options.from and {
                    options.from,
                } or {0})[1]
                local step = (options and options.step and {
                    options.step,
                } or {1})[1]
                local current = from

                return function()
                    local delay = current

                    current = current + step

                    return delay
                end
            end
            function Delay.take(strategy, count)
                local taken = 0

                return function()
                    if taken >= count then
                        return nil
                    end

                    taken = taken + 1

                    return strategy()
                end
            end
            function Delay.jitter(strategy, random)
                return function()
                    local delay = strategy()

                    if delay == nil then
                        return nil
                    end

                    return delay * random()
                end
            end

            return Delay
        end

        function __DARKLUA_BUNDLE_MODULES.a()
            local v = __DARKLUA_BUNDLE_MODULES.cache.a

            if not v then
                v = {
                    c = __modImpl(),
                }
                __DARKLUA_BUNDLE_MODULES.cache.a = v
            end

            return v.c
        end
    end
    do
        local function __modImpl()
            local Exhaustive = {}

            function Exhaustive.casesHandled(value)
                error('Exhaustive.casesHandled: unhandled case ' .. tostring(value), 2)
            end

            return Exhaustive
        end

        function __DARKLUA_BUNDLE_MODULES.b()
            local v = __DARKLUA_BUNDLE_MODULES.cache.b

            if not v then
                v = {
                    c = __modImpl(),
                }
                __DARKLUA_BUNDLE_MODULES.cache.b = v
            end

            return v.c
        end
    end
    do
        local function __modImpl()
            local Show = {}
            local TAGGED_RENDERINGS = {
                {
                    tag = 'Just',
                    payloadField = 'value',
                },
                {
                    tag = 'Nothing',
                    payloadField = nil,
                },
                {
                    tag = 'Ok',
                    payloadField = 'value',
                },
                {
                    tag = 'Err',
                    payloadField = 'error',
                },
            }

            local function uncheckedRawField(record, field)
                return rawget(record, field)
            end
            local function tagOf(value)
                if type(value) ~= 'table' then
                    return nil
                end

                return uncheckedRawField(value, 'kind')
            end
            local function renderingFor(tag)
                for _, rendering in ipairs(TAGGED_RENDERINGS)do
                    if rendering.tag == tag then
                        return rendering
                    end
                end

                return nil
            end

            function Show.value(value)
                if type(value) == 'string' then
                    return string.format('%q', value)
                end

                local rendering = renderingFor(tagOf(value))

                if rendering == nil then
                    return tostring(value)
                end

                local payloadField = rendering.payloadField

                if payloadField == nil then
                    return rendering.tag
                end

                return rendering.tag .. '(' .. Show.value(uncheckedRawField(value, payloadField)) .. ')'
            end

            return Show
        end

        function __DARKLUA_BUNDLE_MODULES.c()
            local v = __DARKLUA_BUNDLE_MODULES.cache.c

            if not v then
                v = {
                    c = __modImpl(),
                }
                __DARKLUA_BUNDLE_MODULES.cache.c = v
            end

            return v.c
        end
    end
    do
        local function __modImpl()
            local Show = __DARKLUA_BUNDLE_MODULES.c()
            local NOTHING = {
                kind = 'Nothing',
            }
            local Maybe = {}

            local function uncheckedJustOfNonNil(value)
                return {
                    kind = 'Just',
                    value = value,
                }
            end
            local function uncheckedView(maybe)
                return maybe
            end

            function Maybe.just(value)
                if value == nil then
                    error(
[[Maybe.just: value is nil; use Maybe.of for a value that may be nil]], 2)
                end

                return {
                    kind = 'Just',
                    value = value,
                }
            end
            function Maybe.nothing()
                return NOTHING
            end
            function Maybe.of(value)
                if value == nil then
                    return NOTHING
                end

                return uncheckedJustOfNonNil(value)
            end
            function Maybe.isJust(maybe)
                return maybe.kind == 'Just'
            end
            function Maybe.isNothing(maybe)
                return maybe.kind == 'Nothing'
            end
            function Maybe.map(maybe, f)
                local m = uncheckedView(maybe)

                if m.kind == 'Just' then
                    return Maybe.of(f(m.value))
                end

                return NOTHING
            end
            function Maybe.mapOr(maybe, default, f)
                local m = uncheckedView(maybe)

                if m.kind == 'Just' then
                    return f(m.value)
                end

                return default
            end
            function Maybe.mapOrElse(maybe, orElse, f)
                local m = uncheckedView(maybe)

                if m.kind == 'Just' then
                    return f(m.value)
                end

                return orElse()
            end
            function Maybe.match(maybe, matcher)
                local m = uncheckedView(maybe)

                if m.kind == 'Just' then
                    return matcher.Just(m.value)
                end

                return matcher.Nothing()
            end
            function Maybe.andThen(maybe, f)
                local m = uncheckedView(maybe)

                if m.kind == 'Just' then
                    return uncheckedView(f(m.value))
                end

                return NOTHING
            end
            function Maybe.and_(maybe, other)
                if uncheckedView(maybe).kind == 'Just' then
                    return uncheckedView(other)
                end

                return NOTHING
            end
            function Maybe.or_(maybe, other)
                local m = uncheckedView(maybe)

                if m.kind == 'Just' then
                    return m
                end

                return uncheckedView(other)
            end
            function Maybe.orElse(maybe, f)
                local m = uncheckedView(maybe)

                if m.kind == 'Just' then
                    return m
                end

                return uncheckedView(f())
            end
            function Maybe.unwrapOr(maybe, default)
                local m = uncheckedView(maybe)

                if m.kind == 'Just' then
                    return m.value
                end

                return default
            end
            function Maybe.unwrapOrElse(maybe, f)
                local m = uncheckedView(maybe)

                if m.kind == 'Just' then
                    return m.value
                end

                return f()
            end
            function Maybe.flatten(maybe)
                local m = uncheckedView(maybe)

                if m.kind == 'Just' then
                    return uncheckedView(m.value)
                end

                return NOTHING
            end
            function Maybe.filter(maybe, predicate)
                local m = uncheckedView(maybe)

                if m.kind == 'Just' and predicate(m.value) then
                    return m
                end

                return NOTHING
            end
            function Maybe.equals(a, b)
                if a.kind == 'Just' and b.kind == 'Just' then
                    return a.value == b.value
                end

                return a.kind == b.kind
            end
            function Maybe.toString(maybe)
                return Show.value(maybe)
            end
            function Maybe.inspect(maybe, f)
                local m = uncheckedView(maybe)

                if m.kind == 'Just' then
                    f(m.value)
                end

                return maybe
            end
            function Maybe.first(list)
                return Maybe.of(list[1])
            end
            function Maybe.last(list)
                return Maybe.of(list[#list])
            end
            function Maybe.find(list, predicate)
                for _, value in ipairs(list)do
                    if predicate(value) then
                        return Maybe.just(value)
                    end
                end

                return NOTHING
            end
            function Maybe.get(map, key)
                return Maybe.of(map[key])
            end
            function Maybe.all(maybes)
                local values = {}

                for _, maybe in ipairs(maybes)do
                    local m = uncheckedView(maybe)

                    if m.kind == 'Nothing' then
                        return NOTHING
                    end

                    table.insert(values, m.value)
                end

                return Maybe.just(values)
            end
            function Maybe.values(maybes)
                local values = {}

                for _, maybe in ipairs(maybes)do
                    local m = uncheckedView(maybe)

                    if m.kind == 'Just' then
                        table.insert(values, m.value)
                    end
                end

                return values
            end
            function Maybe.safe(f)
                return function(...)
                    return Maybe.of(f(...))
                end
            end

            return Maybe
        end

        function __DARKLUA_BUNDLE_MODULES.d()
            local v = __DARKLUA_BUNDLE_MODULES.cache.d

            if not v then
                v = {
                    c = __modImpl(),
                }
                __DARKLUA_BUNDLE_MODULES.cache.d = v
            end

            return v.c
        end
    end
    do
        local function __modImpl()
            local Show = __DARKLUA_BUNDLE_MODULES.c()
            local Result = {}

            local function uncheckedView(result)
                return result
            end

            function Result.ok(value)
                return {
                    kind = 'Ok',
                    value = value,
                }
            end
            function Result.err(error)
                return {
                    kind = 'Err',
                    error = error,
                }
            end
            function Result.isOk(result)
                return result.kind == 'Ok'
            end
            function Result.isErr(result)
                return result.kind == 'Err'
            end
            function Result.map(result, f)
                local r = uncheckedView(result)

                if r.kind == 'Ok' then
                    return Result.ok(f(r.value))
                end

                return r
            end
            function Result.mapErr(result, f)
                local r = uncheckedView(result)

                if r.kind == 'Err' then
                    return Result.err(f(r.error))
                end

                return r
            end
            function Result.mapOr(result, default, f)
                local r = uncheckedView(result)

                if r.kind == 'Ok' then
                    return f(r.value)
                end

                return default
            end
            function Result.mapOrElse(result, orElse, f)
                local r = uncheckedView(result)

                if r.kind == 'Ok' then
                    return f(r.value)
                end

                return orElse(r.error)
            end
            function Result.match(result, matcher)
                local r = uncheckedView(result)

                if r.kind == 'Ok' then
                    return matcher.Ok(r.value)
                end

                return matcher.Err(r.error)
            end
            function Result.andThen(result, f)
                local r = uncheckedView(result)

                if r.kind == 'Ok' then
                    return uncheckedView(f(r.value))
                end

                return r
            end
            function Result.and_(result, other)
                local r = uncheckedView(result)

                if r.kind == 'Ok' then
                    return uncheckedView(other)
                end

                return r
            end
            function Result.or_(result, other)
                local r = uncheckedView(result)

                if r.kind == 'Ok' then
                    return r
                end

                return uncheckedView(other)
            end
            function Result.orElse(result, f)
                local r = uncheckedView(result)

                if r.kind == 'Ok' then
                    return r
                end

                return uncheckedView(f(r.error))
            end
            function Result.unwrapOr(result, default)
                local r = uncheckedView(result)

                if r.kind == 'Ok' then
                    return r.value
                end

                return default
            end
            function Result.unwrapOrElse(result, f)
                local r = uncheckedView(result)

                if r.kind == 'Ok' then
                    return r.value
                end

                return f(r.error)
            end
            function Result.flatten(result)
                local r = uncheckedView(result)

                if r.kind == 'Ok' then
                    return uncheckedView(r.value)
                end

                return r
            end
            function Result.equals(a, b)
                if a.kind == 'Ok' and b.kind == 'Ok' then
                    return a.value == b.value
                elseif a.kind == 'Err' and b.kind == 'Err' then
                    return a.error == b.error
                end

                return false
            end
            function Result.toString(result)
                return Show.value(result)
            end
            function Result.inspect(result, f)
                local r = uncheckedView(result)

                if r.kind == 'Ok' then
                    f(r.value)
                end

                return result
            end
            function Result.inspectErr(result, f)
                local r = uncheckedView(result)

                if r.kind == 'Err' then
                    f(r.error)
                end

                return result
            end
            function Result.all(results)
                local values = {}

                for _, result in ipairs(results)do
                    local r = uncheckedView(result)

                    if r.kind == 'Err' then
                        return r
                    end

                    table.insert(values, r.value)
                end

                return Result.ok(values)
            end
            function Result.any(results)
                local errors = {}

                for _, result in ipairs(results)do
                    local r = uncheckedView(result)

                    if r.kind == 'Ok' then
                        return r
                    end

                    table.insert(errors, r.error)
                end

                return Result.err(errors)
            end
            function Result.partition(results)
                local values, errors = {}, {}

                for _, result in ipairs(results)do
                    local r = uncheckedView(result)

                    if r.kind == 'Ok' then
                        table.insert(values, r.value)
                    else
                        table.insert(errors, r.error)
                    end
                end

                return values, errors
            end
            function Result.tryOr(error, f)
                local ok, value = pcall(f)

                if ok then
                    return Result.ok(value)
                end

                return Result.err(error)
            end
            function Result.tryOrElse(onError, f)
                local ok, value = pcall(f)

                if ok then
                    return Result.ok(value)
                end

                return Result.err(onError(value))
            end
            function Result.safe(f, onError)
                return function(...)
                    local ok, value = pcall(f, ...)

                    if ok then
                        return Result.ok(value)
                    end

                    return Result.err(onError(value))
                end
            end

            return Result
        end

        function __DARKLUA_BUNDLE_MODULES.e()
            local v = __DARKLUA_BUNDLE_MODULES.cache.e

            if not v then
                v = {
                    c = __modImpl(),
                }
                __DARKLUA_BUNDLE_MODULES.cache.e = v
            end

            return v.c
        end
    end
    do
        local function __modImpl()
            local Delay = __DARKLUA_BUNDLE_MODULES.a()
            local Result = __DARKLUA_BUNDLE_MODULES.e()
            local PENDING_STATE = {
                kind = 'Pending',
            }

            local function uncheckedWeakKeyedThreads()
                return (setmetatable({}, {
                    __mode = 'k',
                }))
            end

            local asyncThreads = uncheckedWeakKeyedThreads()
            local Task = {}

            local function uncheckedResult(value)
                return value
            end
            local function newPendingRecord()
                return {
                    state = PENDING_STATE,
                    waiters = {},
                }
            end
            local function uncheckedRecordOf(task)
                return task
            end
            local function toResult(state)
                if state.kind == 'Resolved' then
                    return Result.ok(state.value)
                end

                return Result.err(state.reason)
            end
            local function settle(task, state)
                if task.state.kind ~= 'Pending' then
                    return
                end

                task.state = state

                local waiters = task.waiters

                task.waiters = {}

                local result = toResult(state)

                for _, waiter in ipairs(waiters)do
                    waiter(result)
                end
            end
            local function resolveRecord(task, value)
                settle(task, {
                    kind = 'Resolved',
                    value = value,
                })
            end
            local function rejectRecord(task, reason)
                settle(task, {
                    kind = 'Rejected',
                    reason = reason,
                })
            end
            local function whenRecordSettles(task, callback)
                local inner = uncheckedRecordOf(task)
                local state = inner.state

                if state.kind == 'Pending' then
                    table.insert(inner.waiters, callback)
                else
                    callback(toResult(state))
                end
            end
            local function settleLike(source, target)
                whenRecordSettles(source, function(result)
                    if result.kind == 'Ok' then
                        resolveRecord(target, result.value)
                    else
                        rejectRecord(target, result.error)
                    end
                end)
            end

            function Task.whenSettled(task, callback)
                whenRecordSettles(task, callback)
            end
            function Task.new(executor)
                local task = newPendingRecord()

                executor(function(value)
                    resolveRecord(task, value)
                end, function(reason)
                    rejectRecord(task, reason)
                end)

                return task
            end
            function Task.withResolvers()
                local task = newPendingRecord()

                return {
                    task = task,
                    resolve = function(value)
                        resolveRecord(task, value)
                    end,
                    reject = function(reason)
                        rejectRecord(task, reason)
                    end,
                }
            end
            function Task.resolve(value)
                local task = newPendingRecord()

                resolveRecord(task, value)

                return task
            end
            function Task.reject(reason)
                local task = newPendingRecord()

                rejectRecord(task, reason)

                return task
            end
            function Task.fromResult(result)
                local task = newPendingRecord()
                local r = uncheckedResult(result)

                if r.kind == 'Ok' then
                    resolveRecord(task, r.value)
                else
                    rejectRecord(task, r.error)
                end

                return task
            end
            function Task.peek(task)
                local state = uncheckedRecordOf(task).state

                if state.kind == 'Pending' then
                    return nil
                end

                return toResult(state)
            end
            function Task.isPending(task)
                return task.state.kind == 'Pending'
            end
            function Task.isResolved(task)
                return task.state.kind == 'Resolved'
            end
            function Task.isRejected(task)
                return task.state.kind == 'Rejected'
            end
            function Task.map(task, f)
                local target = newPendingRecord()

                whenRecordSettles(task, function(result)
                    if result.kind == 'Ok' then
                        resolveRecord(target, f(result.value))
                    else
                        rejectRecord(target, result.error)
                    end
                end)

                return target
            end
            function Task.mapRejected(task, f)
                local target = newPendingRecord()

                whenRecordSettles(task, function(result)
                    if result.kind == 'Ok' then
                        resolveRecord(target, result.value)
                    else
                        rejectRecord(target, f(result.error))
                    end
                end)

                return target
            end
            function Task.andThen(task, f)
                local target = newPendingRecord()

                whenRecordSettles(task, function(result)
                    if result.kind == 'Ok' then
                        settleLike(f(result.value), target)
                    else
                        rejectRecord(target, result.error)
                    end
                end)

                return target
            end
            function Task.orElse(task, f)
                local target = newPendingRecord()

                whenRecordSettles(task, function(result)
                    if result.kind == 'Ok' then
                        resolveRecord(target, result.value)
                    else
                        settleLike(f(result.error), target)
                    end
                end)

                return target
            end
            function Task.and_(task, other)
                local target = newPendingRecord()

                whenRecordSettles(task, function(result)
                    if result.kind == 'Ok' then
                        settleLike(other, target)
                    else
                        rejectRecord(target, result.error)
                    end
                end)

                return target
            end
            function Task.or_(task, other)
                local target = newPendingRecord()

                whenRecordSettles(task, function(result)
                    if result.kind == 'Ok' then
                        resolveRecord(target, result.value)
                    else
                        settleLike(other, target)
                    end
                end)

                return target
            end
            function Task.match(task, matcher)
                local target = newPendingRecord()

                whenRecordSettles(task, function(result)
                    if result.kind == 'Ok' then
                        resolveRecord(target, matcher.Resolved(result.value))
                    else
                        resolveRecord(target, matcher.Rejected(result.error))
                    end
                end)

                return target
            end
            function Task.toResult(task)
                local target = newPendingRecord()

                whenRecordSettles(task, function(result)
                    resolveRecord(target, result)
                end)

                return target
            end
            function Task.inspect(task, f)
                whenRecordSettles(task, function(result)
                    if result.kind == 'Ok' then
                        f(result.value)
                    end
                end)

                return task
            end
            function Task.inspectRejected(task, f)
                whenRecordSettles(task, function(result)
                    if result.kind == 'Err' then
                        f(result.error)
                    end
                end)

                return task
            end
            function Task.all(tasks)
                local target = newPendingRecord()
                local values = {}
                local remaining = #tasks

                if remaining == 0 then
                    resolveRecord(target, values)

                    return target
                end

                for index, task in ipairs(tasks)do
                    whenRecordSettles(task, function(result)
                        if result.kind == 'Ok' then
                            values[index] = result.value
                            remaining = remaining - 1

                            if remaining == 0 then
                                resolveRecord(target, values)
                            end
                        else
                            rejectRecord(target, result.error)
                        end
                    end)
                end

                return target
            end
            function Task.allSettled(tasks)
                local target = newPendingRecord()
                local results = {}
                local remaining = #tasks

                if remaining == 0 then
                    resolveRecord(target, results)

                    return target
                end

                for index, task in ipairs(tasks)do
                    whenRecordSettles(task, function(result)
                        results[index] = result
                        remaining = remaining - 1

                        if remaining == 0 then
                            resolveRecord(target, results)
                        end
                    end)
                end

                return target
            end
            function Task.any(tasks)
                local target = newPendingRecord()
                local reasons = {}
                local remaining = #tasks

                if remaining == 0 then
                    rejectRecord(target, reasons)

                    return target
                end

                for index, task in ipairs(tasks)do
                    whenRecordSettles(task, function(result)
                        if result.kind == 'Ok' then
                            resolveRecord(target, result.value)
                        else
                            reasons[index] = result.error
                            remaining = remaining - 1

                            if remaining == 0 then
                                rejectRecord(target, reasons)
                            end
                        end
                    end)
                end

                return target
            end
            function Task.race(tasks)
                local target = newPendingRecord()

                for _, task in ipairs(tasks)do
                    settleLike(task, target)
                end

                return target
            end
            function Task.async(body)
                local task = newPendingRecord()
                local thread = coroutine.create(function()
                    local result = uncheckedResult(body())

                    if result.kind == 'Ok' then
                        resolveRecord(task, result.value)
                    else
                        rejectRecord(task, result.error)
                    end
                end)

                asyncThreads[thread] = true

                local ok, raised = coroutine.resume(thread)

                if not ok then
                    error(raised, 0)
                end

                return task
            end
            function Task.await(task)
                local state = uncheckedRecordOf(task).state

                if state.kind ~= 'Pending' then
                    return toResult(state)
                end

                local thread = coroutine.running()

                if thread == nil or not asyncThreads[thread] then
                    error('Task.await: called outside Task.async', 2)
                end

                local settled = nil

                whenRecordSettles(task, function(result)
                    settled = result

                    local ok, raised = coroutine.resume(thread)

                    if not ok then
                        error(raised, 0)
                    end
                end)

                while true do
                    local result = settled

                    if result ~= nil then
                        return result
                    end

                    coroutine.yield()
                end
            end
            function Task.timer(seconds, schedule)
                local task = newPendingRecord()

                schedule(seconds, function()
                    resolveRecord(task, seconds)
                end)

                return task
            end
            function Task.timeout(task, seconds, schedule)
                local target = newPendingRecord()

                settleLike(task, target)
                schedule(seconds, function()
                    local timeout = {
                        kind = 'Timeout',
                        seconds = seconds,
                    }

                    rejectRecord(target, timeout)
                end)

                return target
            end

            local function delayBeforeNextAttempt(
                reason,
                status,
                strategy,
                shouldRetry
            )
                if shouldRetry ~= nil and not shouldRetry(reason, status) then
                    return nil
                end

                return strategy()
            end
            local function waitThen(seconds, schedule, continue)
                if seconds <= 0 then
                    continue()
                elseif schedule then
                    schedule(seconds, continue)
                else
                    error('Task.withRetries: a delay above 0 needs options.schedule', 0)
                end
            end

            function Task.withRetries(retryable, options)
                local strategy = (options and options.strategy and {
                    options.strategy,
                } or {
                    (Delay.take(Delay.immediate(), 3)),
                })[1]
                local schedule = (options and {
                    options.schedule,
                } or {nil})[1]
                local shouldRetry = (options and {
                    options.shouldRetry,
                } or {nil})[1]
                local target = newPendingRecord()
                local rejections = {}
                local elapsed = 0

                local function giveUp(attempts)
                    local failed = {
                        kind = 'RetryFailed',
                        tries = attempts,
                        elapsed = elapsed,
                        rejections = rejections,
                    }

                    rejectRecord(target, failed)
                end
                local function attempt(count)
                    local status = {
                        count = count,
                        elapsed = elapsed,
                    }

                    whenRecordSettles(retryable(status), function(result)
                        if result.kind == 'Ok' then
                            resolveRecord(target, result.value)

                            return
                        end

                        table.insert(rejections, result.error)

                        local delay = delayBeforeNextAttempt(result.error, status, strategy, shouldRetry)

                        if delay == nil then
                            giveUp(count + 1)

                            return
                        end

                        elapsed = elapsed + delay

                        waitThen(delay, schedule, function()
                            attempt(count + 1)
                        end)
                    end)
                end

                attempt(0)

                return target
            end

            return Task
        end

        function __DARKLUA_BUNDLE_MODULES.f()
            local v = __DARKLUA_BUNDLE_MODULES.cache.f

            if not v then
                v = {
                    c = __modImpl(),
                }
                __DARKLUA_BUNDLE_MODULES.cache.f = v
            end

            return v.c
        end
    end
    do
        local function __modImpl()
            local Maybe = __DARKLUA_BUNDLE_MODULES.d()
            local Result = __DARKLUA_BUNDLE_MODULES.e()
            local Toolbelt = {}

            local function uncheckedMaybe(maybe)
                return maybe
            end
            local function uncheckedResult(result)
                return result
            end

            function Toolbelt.toMaybe(result)
                local r = uncheckedResult(result)

                if r.kind == 'Ok' then
                    return Maybe.just(r.value)
                end

                return Maybe.nothing()
            end
            function Toolbelt.toOkOrErr(maybe, error)
                local m = uncheckedMaybe(maybe)

                if m.kind == 'Just' then
                    return Result.ok(m.value)
                end

                return Result.err(error)
            end
            function Toolbelt.toOkOrElseErr(maybe, f)
                local m = uncheckedMaybe(maybe)

                if m.kind == 'Just' then
                    return Result.ok(m.value)
                end

                return Result.err(f())
            end
            function Toolbelt.transposeResult(result)
                local r = uncheckedResult(result)

                if r.kind == 'Err' then
                    return Maybe.just(r)
                end

                local m = uncheckedMaybe(r.value)

                if m.kind == 'Just' then
                    return Maybe.just(Result.ok(m.value))
                end

                return Maybe.nothing()
            end
            function Toolbelt.transposeMaybe(maybe)
                local m = uncheckedMaybe(maybe)

                if m.kind == 'Nothing' then
                    return Result.ok(Maybe.nothing())
                end

                local r = uncheckedResult(m.value)

                if r.kind == 'Ok' then
                    return Result.ok(Maybe.just(r.value))
                end

                return r
            end

            return Toolbelt
        end

        function __DARKLUA_BUNDLE_MODULES.g()
            local v = __DARKLUA_BUNDLE_MODULES.cache.g

            if not v then
                v = {
                    c = __modImpl(),
                }
                __DARKLUA_BUNDLE_MODULES.cache.g = v
            end

            return v.c
        end
    end
    do
        local function __modImpl()
            local Delay = __DARKLUA_BUNDLE_MODULES.a()
            local Exhaustive = __DARKLUA_BUNDLE_MODULES.b()
            local Maybe = __DARKLUA_BUNDLE_MODULES.d()
            local Result = __DARKLUA_BUNDLE_MODULES.e()
            local Task = __DARKLUA_BUNDLE_MODULES.f()
            local Toolbelt = __DARKLUA_BUNDLE_MODULES.g()

            return {
                version = '0.2.0',
                Delay = Delay,
                Exhaustive = Exhaustive,
                Maybe = Maybe,
                Result = Result,
                Task = Task,
                Toolbelt = Toolbelt,
            }
        end

        function __DARKLUA_BUNDLE_MODULES.h()
            local v = __DARKLUA_BUNDLE_MODULES.cache.h

            if not v then
                v = {
                    c = __modImpl(),
                }
                __DARKLUA_BUNDLE_MODULES.cache.h = v
            end

            return v.c
        end
    end
end

local TrueMyth = __DARKLUA_BUNDLE_MODULES.h()
local _, namespace = ...

if type(namespace) == 'table' then
    namespace.TrueMyth = TrueMyth
end

return TrueMyth
