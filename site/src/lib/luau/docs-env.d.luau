-- The host APIs the docs' examples call: a few World of Warcraft functions and Roblox/Lune's `task.delay`, typed as
-- those hosts type them. The docs checker (checker.ts) loads this next to the library, so examples can use them.

declare function UnitName(unit: string): string?
declare function UnitLevel(unit: string): number

declare C_Timer: {
	After: (seconds: number, callback: () -> ()) -> (),
}

declare task: {
	delay: (seconds: number, callback: () -> ()) -> thread,
}
