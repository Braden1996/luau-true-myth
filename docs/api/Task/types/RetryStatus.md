Passed to each attempt of `Task.withRetries`.

Fields:

- `count`: 0 for the first attempt, then 1, 2, ...
- `elapsed`: The sum of the delays waited so far, in seconds.
