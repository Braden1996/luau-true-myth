A pending task and the functions that settle it. Luau cannot infer types used only in a result, so name them: `local d =
Task.withResolvers() :: Task.Deferred<number, string>`.
