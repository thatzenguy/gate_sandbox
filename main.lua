local StarterGui = script.Parent
local Screen = StarterGui:WaitForChild("Screen")
local Inputs, Outputs = Screen.Inputs, Screen.Outputs

game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)

local Max = 5

local function count(dir)
	local Children = dir:GetChildren()
	local Counter = 0
	for i = 1, #Children do
		if Children[i].Name == "Input" or Children[i].Name == "Output" then
			Counter += 1
		end
	end
	return Counter
end

local updateConnections = Instance.new("BindableEvent")

local function add(Parent, Object)
	if count(Parent) < Max then
		local Clone = Screen.Temp:FindFirstChild(Object.Name):Clone()
		Clone.Parent = Parent
		Clone.Visible = true
		if count(Parent) == Max then
			Parent.z_Add:Destroy()
		end
		updateConnections:Fire()
	end
end

Inputs.z_Add.MouseButton1Click:Connect(function()
	add(Inputs, Inputs.Input)
end)

Outputs.z_Add.MouseButton1Click:Connect(function()
	add(Outputs, Outputs.Output)
end)

local UIS = game:GetService("UserInputService")

local function draw(obj1, obj2)
	local start = obj1.AbsolutePosition + obj1.AbsoluteSize * 0.5
	local ending = obj2 and (obj2.AbsolutePosition + obj2.AbsoluteSize * 0.5) or UIS:GetMouseLocation() + Vector2.new(0, -36)
	local length = (Vector2.new(start.X, start.Y) - Vector2.new(ending.X, ending.Y)).Magnitude

	local line = Screen.Temp.LTemplate:Clone()
	line.Name = "Line"
	line.Parent = Screen.Temp
	local latch = Instance.new("ObjectValue")
	latch.Parent = line
	latch.Name = "Latch"
	latch.Value = obj2
	line.Size = UDim2.new(0, length, 0, 15)
	line.Position = UDim2.new(0, (start.X + ending.X) / 2, 0, (start.Y + ending.Y) / 2) - UDim2.new(0, Screen.Temp.AbsolutePosition.X, 0, Screen.Temp.AbsolutePosition.Y)
	line.Rotation = math.atan2(ending.Y - start.Y, ending.X - start.X) * (180 / math.pi)
	line.Visible = true
	return line
end

local Previewing = false
local Dragging = false
local RunService = game:GetService("RunService")

local Connections = {}

local function toOffset(Scale)
	local ViewPortSize = workspace.Camera.ViewportSize
	return {ViewPortSize.X * Scale[1],ViewPortSize.Y * Scale[2]}
end

local function toScale(Offset)
	local ViewPortSize = workspace.Camera.ViewportSize
	return {Offset[1] / ViewPortSize.X, Offset[2] / ViewPortSize.Y}
end

local function get_hook(Receiver)
	for _, Contents in pairs(Connections) do
		for i = 1, #Contents do
			if Contents[i].Receiver == Receiver then
				return Contents[i].Hook
			end
		end
	end
end

local function get_receivers(Hook)
	local receivers = {}
	for _, Contents in pairs(Connections) do
		for i = 1, #Contents do
			if Contents[i].Hook == Hook then
				table.insert(receivers, Contents[i].Receiver)
			end
		end
	end
	return receivers
end

local function get_current_hook()
	for _, Hook in pairs(Screen:GetDescendants()) do
		if Hook.Name == "Hook" then
			if Hook:GetAttribute("CurrentHook") then
				return Hook
			end
		end
	end
end

local function preview_connection(Object)
	Object:SetAttribute("CurrentHook", true)
	Previewing = RunService.Heartbeat:Connect(function()
		local line = draw(Object)
		line.BackgroundColor3 = Object.BackgroundColor3
		task.wait()
		line:Destroy()
	end)
end

local function is_previewing()
	return Previewing ~= false
end

local function is_dragging()
	return Dragging ~= false
end

local function stop_previewing()
	if is_previewing() then
		if get_current_hook() then
			get_current_hook():SetAttribute("CurrentHook", false)
		end
		Previewing:Disconnect()
	end
end

local function create_connection(Gate, Hook, Receiver)
	if Previewing ~= false then
		Previewing:Disconnect()
	end
	if not Connections[Gate] then
		Connections[Gate] = {}
	end
	local line = draw(Hook, Receiver)
	line.BackgroundColor3 = Hook.BackgroundColor3
	Receiver.BackgroundColor3 = Hook.BackgroundColor3
	local HookVal = Hook:GetAttribute("Value") or 0
	Receiver:SetAttribute("Value", HookVal)
	table.insert(Connections[Gate], {["Hook"] = Hook, ["Line"] = line, ["Receiver"] = Receiver})
	return line
end

local function destroy_gate(Gate)
	for i = 1, #Connections[Gate] do
		Connections[Gate][i].Line:Destroy()
	end
	Connections[Gate] = nil
end

local Colors = {
	Hook = Color3.fromRGB(100, 100, 100);
	Receiver = Color3.fromRGB(100, 100, 100);
	Gate = Color3.fromRGB(184, 184, 184);
	On = Color3.fromRGB(230, 75, 75);
	Off = Color3.fromRGB(30, 30, 30);
}

local function destroy_hook(Gate, Receiver)
	for i = 1, #Connections[Gate] do
		local Node = Connections[Gate][i]
		if Node.Receiver == Receiver then
			Node.Line:Destroy()
			Receiver:SetAttribute("Value", 0)
			if Gate.Label.Text == "NOT" then
				Receiver:SetAttribute("Value", nil)
				Gate.Hook:SetAttribute("Value", 0)
			end
			table.remove(Connections[Gate], i)
			break
		end
	end
end

local function get_lines(Hook)
	local lines = {}
	for _, Contents in pairs(Connections) do
		for i = 1, #Contents do
			if Contents[i].Hook == Hook then
				table.insert(lines, Contents[i].Line)
			end
		end
	end
	return lines
end

local function drag(Object)
	if Object.Parent == Screen.Toolbox then
		local preview = Object:Clone()
		local Position = UIS:GetMouseLocation()
		preview.Parent = Screen.Gates
		preview.Position = UDim2.new(0, Position.X, 0, Position.Y)
		preview.Size = UDim2.new(0.085, 0, 0.12, 0)
		local newPos = nil
		Dragging = RunService.Heartbeat:Connect(function(dt)
			newPos = UIS:GetMouseLocation()
			if newPos ~= Position then
				preview.Position = UDim2.new(0, newPos.X, 0, newPos.Y)
			end
		end)
	else
		local Position = UIS:GetMouseLocation()
		local newPos = nil
		Dragging = RunService.Heartbeat:Connect(function(dt)
			newPos = UIS:GetMouseLocation()
			if newPos ~= Position then
				Object.Position = UDim2.new(0, newPos.X, 0, newPos.Y)
				updateConnections:Fire()
			end
		end)
	end
end

local function stop_dragging()
	if is_dragging() then
		Dragging:Disconnect()
	end
end

local function setup(Object)
	if ((Object.Name == "Input" or Object.Name == "Output") and Object.Parent == Screen.Inputs or Object.Parent == Screen.Outputs) or (Object.Name == "Gate" and Object.Parent ~= Screen.Toolbox) then
		Object:GetAttributeChangedSignal("Value"):Connect(function()
			local Value = Object:GetAttribute("Value")
			Object.BackgroundColor3 = Value == 1 and Colors.On or (Object.Name == "Gate" and Colors.Gate) or Colors.Off
			for _, v in pairs(Object:GetChildren()) do
				if v.Name == "Hook" then
					v:SetAttribute("Value", Value)
				end
			end
		end)
		for _, Child in pairs(Object:GetChildren()) do
			if Child.Name == "Receiver" then
				local Types = {
					["AND"] = function(a, b)
						if (a == 1 and b == 1) then
							return 1
						end
						return 0
					end,
					["OR"] = function(a, b)
						if (a == 1 and b == 0) or (a == 1 and b == 1) or (a == 0 and b == 1) then
							return 1
						end
						return 0
					end,
					["NOT"] = function(a)
						if (a == 1) then
							return 0
						end
						return 1
					end
				}

				Child:GetAttributeChangedSignal("Value"):Connect(function()
					local Value = Child:GetAttribute("Value")

					Child.BackgroundColor3 = Value == 1 and Colors.On or Colors.Receiver
					if Object.Name == "Output" then
						Object.BackgroundColor3 = Value == 1 and Colors.On or Colors.Off
					end
					local Values = {}
					for _, v in pairs(Object:GetChildren()) do
						if v.Name == "Receiver" then
							local Value = v:GetAttribute("Value")
							if Value == nil then
								for _, Line in pairs(Screen.Temp:GetChildren()) do
									if Line.Name == "Line" then
										if Line.Latch.Value == Child then
											Value = 0
										end
									end
								end
							end
							if Value then
								table.insert(Values, Value)
							end
						end
					end
					local Label = Object:FindFirstChild("Label")
					if Label then
						if #Values >= 1 then
							local Type = Label.Text
							local Output = Types[Type](unpack(Values))
							Child.Parent:FindFirstChild("Hook"):SetAttribute("Value", Output)
						end
					end
				end)
			elseif Child.Name == "Hook" then
				Child:GetAttributeChangedSignal("Value"):Connect(function()
					local Lines = get_lines(Child)
					local Receivers = get_receivers(Child)
					local Value = Child:GetAttribute("Value")
					for i = 1, #Lines do
						Lines[i]:SetAttribute("Value", Value)
					end
					for i = 1, #Receivers do
						Receivers[i]:SetAttribute("Value", Value)
					end
					Child.BackgroundColor3 = Value == 1 and Colors.On or Colors.Hook
				end)
			end
		end
	end
end

Screen.Temp.ChildAdded:Connect(function(Child)
	if Child.Name == "Line" then
		Child:GetAttributeChangedSignal("Value"):Connect(function()
			local Value = Child:GetAttribute("Value")
			Child.BackgroundColor3 = Value == 1 and Colors.On or Colors.Hook
		end)
	end
end)

for _, v in ipairs(Screen:GetDescendants()) do
	setup(v)
end
Screen.DescendantAdded:Connect(setup)

updateConnections.Event:Connect(function()
	for Gate, Contents in pairs(Connections) do
		destroy_gate(Gate)
		for i = 1, #Contents do
			local line = create_connection(Gate, Contents[i].Hook, Contents[i].Receiver)
			line.BackgroundColor3 = Contents[i].Hook.BackgroundColor3
			Contents[i].Receiver.BackgroundColor3 = Contents[i].Hook.BackgroundColor3
		end
	end
end)

UIS.InputBegan:Connect(function(Input, GPE)
	if GPE then return end
	if Input.UserInputType == Enum.UserInputType.MouseButton1 then
		local Position = Input.Position
		local Objects = StarterGui:GetGuiObjectsAtPosition(Position.X, Position.Y)
		for i = 1, #Objects do
			if Objects[i].Name == "Hook" then
				preview_connection(Objects[i])
			elseif Objects[i].Name == "Receiver" then
				local Hook = get_hook(Objects[i])
				if Hook then
					preview_connection(Hook)
					task.delay(task.wait(), function()
						destroy_hook(Objects[i].Parent, Objects[i])
					end)
				end
			elseif Objects[i].Name == "Gate" then
				drag(Objects[i])
			elseif Objects[i].Name == "Input" then
				local Value = Objects[i]:GetAttribute("Value")
				Objects[i]:SetAttribute("Value", Value == 1 and 0 or 1)
			end
		end
	end
end)

UIS.InputEnded:Connect(function(Input, GPE)
	if GPE then return end
	if Input.UserInputType == Enum.UserInputType.MouseButton1 then
		local Position = Input.Position
		local Objects = StarterGui:GetGuiObjectsAtPosition(Position.X, Position.Y)
		for i = 1, #Objects do
			if Objects[i].Name == "Receiver" then
				if get_current_hook() ~= nil and not get_hook(Objects[i]) then
					if Objects[i].Parent.Parent ~= Screen.Toolbox then
						local current_hook = get_current_hook()
						local line = create_connection(Objects[i].Parent, current_hook, Objects[i])
						line.BackgroundColor3 = current_hook.BackgroundColor3
						Objects[i].BackgroundColor3 = current_hook.BackgroundColor3
					end
				end
			elseif Objects[i].Name == "Gate" then
				local scale = toScale({87.75, 87.75})
				Objects[i].Size = UDim2.new(scale[1], 0, scale[2], 0)
				stop_dragging()
			end
		end
		stop_previewing()
	end
end)
