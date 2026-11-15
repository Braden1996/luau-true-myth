Runs `retryable` until its task resolves, waiting `strategy`'s delays between attempts. Rejects with `RetryFailed` when
the strategy runs out or `shouldRetry` returns false.
