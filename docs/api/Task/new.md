A task settled by `executor(resolve, reject)`. The executor runs at once; it may settle later (from a timer or event
callback). The first settlement wins. An error raised by the executor is a defect and propagates.
