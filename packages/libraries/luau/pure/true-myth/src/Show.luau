--!strict

local Show = {}

type TaggedRendering = { tag: string, payloadField: string? }

local TAGGED_RENDERINGS: { TaggedRendering } = {
	{ tag = "Just", payloadField = "value" },
	{ tag = "Nothing", payloadField = nil },
	{ tag = "Ok", payloadField = "value" },
	{ tag = "Err", payloadField = "error" },
}

local function uncheckedRawField(record: unknown, field: string): unknown
	return rawget(record :: any, field)
end

local function tagOf(value: unknown): unknown
	if type(value) ~= "table" then
		return nil
	end
	return uncheckedRawField(value, "kind")
end

local function renderingFor(tag: unknown): TaggedRendering?
	for _, rendering in ipairs(TAGGED_RENDERINGS) do
		if rendering.tag == tag then
			return rendering
		end
	end
	return nil
end

function Show.value(value: unknown): string
	if type(value) == "string" then
		return string.format("%q", value)
	end
	local rendering = renderingFor(tagOf(value))
	if rendering == nil then
		return tostring(value)
	end
	local payloadField = rendering.payloadField
	if payloadField == nil then
		return rendering.tag
	end
	return rendering.tag .. "(" .. Show.value(uncheckedRawField(value, payloadField)) .. ")"
end

return Show
