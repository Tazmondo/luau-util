export type BinItem = Instance | RBXScriptConnection | () -> ...any

export type Add = <T>(Item: T & BinItem) -> T
export type Clear = () -> ()

return function(): (Add, Clear)
	local Bin: { BinItem } = {}

	return function<T>(Item: T & BinItem)
		table.insert(Bin, Item)

		return Item
	end, function()
		for _, Item in Bin do
			if typeof(Item) == "Instance" then
				Item:Destroy()
			elseif typeof(Item) == "RBXScriptConnection" then
				Item:Disconnect()
			elseif typeof(Item) == "function" then
				task.spawn(Item)
			end
		end

		table.clear(Bin)
	end
end
