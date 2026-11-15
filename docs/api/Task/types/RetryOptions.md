Fields:

- `strategy`: The delays between attempts; the default is three immediate retries. A strategy that returns nil stops.
- `schedule`: Waits between attempts. Required unless every delay is 0.
- `shouldRetry`: Return false to stop retrying after this rejection. Default: always retry.
