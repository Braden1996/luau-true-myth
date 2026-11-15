Inside `Task.async`: suspends until `task` settles and returns its `Result` (at once if it has settled). Calling it
anywhere else is a defect and raises.
