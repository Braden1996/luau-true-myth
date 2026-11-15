The rejection reason of `Task.withRetries` when it gives up.

Fields:

- `tries`: How many attempts ran.
- `elapsed`: The sum of the delays waited, in seconds.
- `rejections`: Every rejection reason, in order; the last one is why it gave up.
