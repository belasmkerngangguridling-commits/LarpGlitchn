local shared = odh_shared_plugins

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local power = 50

local Maid = {}
Maid.__index = Maid

function Maid.new()
    return setmetatable({
        Tasks = {},
        Destroyed = false
    }, Maid)
end

function Maid:GiveTask(task)
    if self.Destroyed then
        return
    end

    table.insert(self.Tasks, task)
    return task
end

function Maid:Destroy()
    if self.Destroyed then
        return
    end

    self.Destroyed = true

    for _, task in ipairs(self.Tasks) do

        pcall(function()

            if typeof(task) == "RBXScriptConnection" then
                task:Disconnect()

            elseif typeof(task) == "Instance" then
                task:Destroy()

            elseif type(task) == "function" then
                task()

            elseif type(task) == "table"
                and type(task.Destroy) == "function" then

                task:Destroy()
            end

        end)

    end

    table.clear(self.Tasks)
end

local BindableButtons = {
    Buttons = {},
    Maids = {},
    Count = 0
}

local SHAPES = {
    [0] = "rbxassetid://86221076925479",
    [1] = "rbxassetid://96242665417546",
    [2] = "rbxassetid://97129189935336",
    [3] = "rbxassetid://76165862027868",
    [4] = "rbxassetid://125868092127496"
}

local NORMAL_COLOR = ColorSequence.new({
    ColorSequenceKeypoint.new(
        0,
        Color3.new(0.133333, 0.827451, 0.494118)
    ),

    ColorSequenceKeypoint.new(
        0.6,
        Color3.new(0.231373, 0.509804, 0.498039)
    ),

    ColorSequenceKeypoint.new(
        1,
        Color3.new(0.501961, 0.501961, 0.501961)
    )
})

local function safeCallback(callback)

    if not callback then
        return
    end

    local ok, err = xpcall(
        callback,
        function(e)
            return debug.traceback(e)
        end
    )

    if not ok then
        warn("[FLINGME BIND ERROR] " .. tostring(err))
    end

end

local function GetBindStorage()

    local parent = nil

    -- Try gethui
    pcall(function()

        if type(gethui) == "function" then

            local result = gethui()

            if typeof(result) == "Instance" then
                parent = result
            end

        end

    end)

    -- Fallback CoreGui
    if not parent then

        local ok, coreGui =
            pcall(function()
                return game:GetService("CoreGui")
            end)

        if ok and typeof(coreGui) == "Instance" then
            parent = coreGui
        end

    end

    -- Final fallback PlayerGui
    if not parent then

        parent =
            player:WaitForChild(
                "PlayerGui"
            )

    end

    -- Safety check
    if typeof(parent) ~= "Instance" then

        error(
            "FlingMe: GUI parent is not an Instance"
        )

    end

    local storage =
        parent:FindFirstChild(
            "@FlingMeBindStorage"
        )

    if not storage then

        storage = Instance.new("ScreenGui")

        storage.Name =
            "@FlingMeBindStorage"

        storage.ResetOnSpawn = false
        storage.IgnoreGuiInset = true

        pcall(function()
            storage.ScreenInsets =
                Enum.ScreenInsets.None
        end)

        storage.Parent = parent

    end

    return storage

end

local function MakeDraggable(
    gui,
    maid,
    ripple,
    sound,
    clickFunc
)

    local dragging = false
    local dragInput = nil
    local dragStart = nil
    local startPos = nil
    local hasMoved = false

    maid:GiveTask(
        gui.InputBegan:Connect(function(input)

            if input.UserInputType
                ~= Enum.UserInputType.MouseButton1
                and input.UserInputType
                ~= Enum.UserInputType.Touch then

                return

            end

            dragging = true
            dragStart = input.Position
            startPos = gui.Position
            hasMoved = false

            pcall(function()
                sound:Play()
            end)

            local absPos =
                gui.AbsolutePosition

            ripple.Position =
                UDim2.new(
                    0,
                    input.Position.X - absPos.X,
                    0,
                    input.Position.Y - absPos.Y
                )

            ripple.Size =
                UDim2.new(0, 0, 0, 0)

            ripple.BackgroundTransparency = 0.5
            ripple.Visible = true

            TweenService:Create(
                ripple,
                TweenInfo.new(
                    0.4,
                    Enum.EasingStyle.Sine,
                    Enum.EasingDirection.Out
                ),
                {
                    Size =
                        UDim2.new(
                            0,
                            45,
                            0,
                            45
                        ),

                    BackgroundTransparency = 1
                }
            ):Play()

            local releaseConnection

            releaseConnection =
                UserInputService.InputEnded:Connect(
                    function(endInput)

                        if endInput.UserInputType
                            ~= input.UserInputType then

                            return

                        end

                        dragging = false

                        if not hasMoved then
                            safeCallback(clickFunc)
                        end

                        if releaseConnection then
                            releaseConnection:Disconnect()
                        end

                    end
                )

            maid:GiveTask(
                releaseConnection
            )

        end)
    )

    maid:GiveTask(
        gui.InputChanged:Connect(function(input)

            if input.UserInputType
                == Enum.UserInputType.MouseMovement
                or input.UserInputType
                == Enum.UserInputType.Touch then

                dragInput = input

            end

        end)
    )

    maid:GiveTask(
        UserInputService.InputChanged:Connect(
            function(input)

                if input == dragInput
                    and dragging then

                    local delta =
                        input.Position
                        - dragStart

                    if delta.Magnitude > 7 then
                        hasMoved = true
                    end

                    local screen =
                        gui.Parent.AbsoluteSize

                    if screen.X <= 0
                        or screen.Y <= 0 then

                        return
                    end

                    gui.Position =
                        UDim2.new(
                            startPos.X.Scale
                                + delta.X / screen.X,

                            0,

                            startPos.Y.Scale
                                + delta.Y / screen.Y,

                            0
                        )

                end

            end
        )
    )

end

function BindableButtons.AddBButton(
    id,
    text,
    clickFunc
)

    if BindableButtons.Buttons[id] then
        return
    end

    local maid = Maid.new()

    local camera =
        workspace.CurrentCamera

    if not camera then
        return
    end

    local screen =
        camera.ViewportSize

    local buttonSizeY = 0.11

    local widthScale =
        buttonSizeY
        * (screen.Y / screen.X)

    local xPos =
        0.1
        + (
            BindableButtons.Count
            % 8
        ) * (widthScale + 0.005)

    local yPos =
        0.9
        - (
            math.floor(
                BindableButtons.Count / 8
            )
            * (buttonSizeY + 0.015)
        )

    -- IMAGE BUTTON

    local button =
        Instance.new("ImageButton")

    button.Name = id

    button.Size =
        UDim2.new(
            widthScale,
            0,
            buttonSizeY,
            0
        )

    button.Position =
        UDim2.new(
            xPos,
            0,
            yPos,
            0
        )

    button.AnchorPoint =
        Vector2.new(0.5, 0.5)

    button.Image =
        SHAPES[0]

    button.BackgroundTransparency = 1
    button.BorderSizePixel = 0
    button.ClipsDescendants = false
    button.AutoButtonColor = false

    button.Parent =
        GetBindStorage()

    maid:GiveTask(button)

    -- TEXT

    local label =
        Instance.new("TextLabel")

    label.Name = "@Text"

    label.Size =
        UDim2.new(
            0.8,
            0,
            0.8,
            0
        )

    label.Position =
        UDim2.new(
            0.5,
            0,
            0.5,
            0
        )

    label.AnchorPoint =
        Vector2.new(0.5, 0.5)

    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Jura
    label.Text = text
    label.TextColor3 =
        Color3.new(1, 1, 1)

    label.TextSize = 10
    label.TextWrapped = true
    label.ZIndex = 3
    label.Parent = button

    -- ASPECT

    local aspect =
        Instance.new(
            "UIAspectRatioConstraint"
        )

    aspect.AspectRatio = 1
    aspect.AspectType =
        Enum.AspectType.ScaleWithParentSize

    aspect.Parent = button

    -- GRADIENT

    local gradient =
        Instance.new("UIGradient")

    gradient.Name = "@Stroke"
    gradient.Color = NORMAL_COLOR
    gradient.Parent = button

    -- RIPPLE

    local ripple =
        Instance.new("Frame")

    ripple.Name = "@ripple"

    ripple.BackgroundColor3 =
        Color3.fromRGB(
            0,
            155,
            255
        )

    ripple.BackgroundTransparency = 0.5

    ripple.Size =
        UDim2.new(
            0,
            0,
            0,
            0
        )

    ripple.AnchorPoint =
        Vector2.new(0.5, 0.5)

    ripple.Visible = false
    ripple.ZIndex = 2
    ripple.Parent = button

    local corner =
        Instance.new("UICorner")

    corner.CornerRadius =
        UDim.new(1, 0)

    corner.Parent = ripple

    -- SOUND

    local sound =
        Instance.new("Sound")

    sound.SoundId =
        "rbxassetid://3868133279"

    sound.Volume = 0.5
    sound.Parent = button

    -- DRAG / CLICK

    MakeDraggable(
        button,
        maid,
        ripple,
        sound,
        clickFunc
    )

    -- ROTATION

    maid:GiveTask(
        RunService.RenderStepped:Connect(
            function()

                if gradient.Parent then

                    gradient.Rotation =
                        (
                            gradient.Rotation + 1
                        ) % 360

                end

            end
        )
    )

    BindableButtons.Buttons[id] =
        button

    BindableButtons.Maids[id] =
        maid

    BindableButtons.Count += 1

end

function BindableButtons.DeleteBButton(id)

    local maid =
        BindableButtons.Maids[id]

    if not maid then
        return
    end

    maid:Destroy()

    BindableButtons.Maids[id] = nil
    BindableButtons.Buttons[id] = nil

    BindableButtons.Count =
        math.max(
            0,
            BindableButtons.Count - 1
        )

end

local function doFling()

    local character =
        player.Character

    if not character then
        return
    end

    local root =
        character:FindFirstChild(
            "HumanoidRootPart"
        )

    local humanoid =
        character:FindFirstChildOfClass(
            "Humanoid"
        )

    if not root or not humanoid then
        return
    end

    local angle =
        math.random()
        * math.pi
        * 2

    local direction =
        Vector3.new(
            math.cos(angle),
            math.random(40, 100) / 100,
            math.sin(angle)
        ).Unit

    local launchVelocity =
        power * 12

    local spinPower =
        power * 10

    local function randomSpin()

        return Vector3.new(
            math.random(
                -spinPower,
                spinPower
            ),

            math.random(
                -spinPower,
                spinPower
            ),

            math.random(
                -spinPower,
                spinPower
            )
        )

    end

    humanoid:ChangeState(
        Enum.HumanoidStateType.FallingDown
    )

    root.AssemblyLinearVelocity +=
        direction
        * launchVelocity

    root.AssemblyAngularVelocity =
        randomSpin()

    task.spawn(function()

        for _ = 1, 4 do

            task.wait(0.05)

            if not root.Parent then
                return
            end

            root.AssemblyAngularVelocity =
                randomSpin()

        end

    end)

end

local tab =
    shared.CreateTab(
        "FlingMe",
        "/belasmkerngangguridling-commits/LarpGlitchn/refs/heads/main/FlingMeIcon"
    )

local section =
    tab:AddSection(
        "FlingMe",
        "Fling control"
    )

section:AddSlider(
    "Fling Power",
    1,
    100,
    50,
    function(value)

        power = value

    end
)

section:AddToggle(
    "Show Fling Bind",
    function(state)

        if state then

            BindableButtons.AddBButton(
                "FlingMe",
                "FLING",
                function()

                    doFling()

                end
            )

            shared.Notify(
                "Fling Bind ON",
                2
            )

        else

            BindableButtons.DeleteBButton(
                "FlingMe"
            )

            shared.Notify(
                "Fling Bind OFF",
                1
            )

        end

    end
)