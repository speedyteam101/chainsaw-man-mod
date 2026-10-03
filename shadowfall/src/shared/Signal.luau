--!nonstrict
-- Minimal synchronous signal used for communication between server services.

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ handlers = {} }, Signal)
end

function Signal:Connect(handler: (...any) -> ())
	table.insert(self.handlers, handler)
	return {
		Disconnect = function()
			local index = table.find(self.handlers, handler)
			if index then
				table.remove(self.handlers, index)
			end
		end,
	}
end

function Signal:Fire(...)
	for _, handler in table.clone(self.handlers) do
		task.spawn(handler, ...)
	end
end

return Signal
