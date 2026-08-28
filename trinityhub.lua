--============================================================--
--                    TrinityHub V1                           --
--============================================================--


--------------------------------------------------------------
-- SERVICES
--------------------------------------------------------------

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

--------------------------------------------------------------
-- DEFAULT SETTINGS
--------------------------------------------------------------

local DEFAULT_SETTINGS = {
    MasterEnabled = true,
    MasterKey = "P",

    ActivationKeys = {
        Z = "Z",
        X = "X",
        C = "C",
        V = "V",
        F = "F",
        R = "R",
    },

    ActivationEnabled = {
        Z = true,
        X = true,
        C = true,
        V = true,
        F = true,
        R = true,
    },

    LookDuration = 0.1,
    MaxDistance = 500,
    MouseCenterEnabled = true,

    FOVEnabled = false,
    FOVSize = 180,
    FOVRainbow = false,

    ESPEnabled = true,
    ESPRainbow = false,
    ESPThickness = 1,
    ESPBoxSize = 1,
    ESPBoxEnabled = true,
    ESPSkeletonEnabled = true,
    ESPHealthEnabled = true,
}

--------------------------------------------------------------
-- DEFAULT APPEARANCE
--------------------------------------------------------------

local DEFAULT_APPEARANCE = {
    MenuColor = Color3.fromRGB(20, 20, 25),
    PanelColor = Color3.fromRGB(30, 30, 37),
    ButtonColor = Color3.fromRGB(45, 45, 55),

    AccentColor = Color3.fromRGB(140, 80, 255),
    NotificationColor = Color3.fromRGB(22, 22, 28),

    ESPLineColor = Color3.fromRGB(190, 100, 255),
    ESPBoxColor = Color3.fromRGB(130, 60, 220),
    ESPSkeletonColor = Color3.fromRGB(90, 120, 255),

    ESPHealthColor = Color3.fromRGB(80, 220, 80),

    FOVColor = Color3.fromRGB(140, 80, 255),
}

--------------------------------------------------------------
-- CURRENT SETTINGS
--------------------------------------------------------------

local Settings = {
    MasterEnabled = DEFAULT_SETTINGS.MasterEnabled,
    MasterKey = DEFAULT_SETTINGS.MasterKey,

    ActivationKeys = {},
    ActivationEnabled = {},

    LookDuration = DEFAULT_SETTINGS.LookDuration,
    MaxDistance = DEFAULT_SETTINGS.MaxDistance,
    MouseCenterEnabled = DEFAULT_SETTINGS.MouseCenterEnabled,

    FOVEnabled = DEFAULT_SETTINGS.FOVEnabled,
    FOVSize = DEFAULT_SETTINGS.FOVSize,
    FOVRainbow = DEFAULT_SETTINGS.FOVRainbow,

    ESPEnabled = DEFAULT_SETTINGS.ESPEnabled,
    ESPRainbow = DEFAULT_SETTINGS.ESPRainbow,
    ESPThickness = DEFAULT_SETTINGS.ESPThickness,
    ESPBoxSize = DEFAULT_SETTINGS.ESPBoxSize,
    ESPBoxEnabled = DEFAULT_SETTINGS.ESPBoxEnabled,
    ESPSkeletonEnabled = DEFAULT_SETTINGS.ESPSkeletonEnabled,
    ESPHealthEnabled = DEFAULT_SETTINGS.ESPHealthEnabled,
}

for slot, key in pairs(DEFAULT_SETTINGS.ActivationKeys) do
    Settings.ActivationKeys[slot] = key
end

for slot, enabled in pairs(DEFAULT_SETTINGS.ActivationEnabled) do
    Settings.ActivationEnabled[slot] = enabled
end

--------------------------------------------------------------
-- CURRENT APPEARANCE
--------------------------------------------------------------

local Appearance = {}

for key, value in pairs(DEFAULT_APPEARANCE) do
    Appearance[key] = value
end

--------------------------------------------------------------
-- STATE
--------------------------------------------------------------

local MenuOpen = false
local CurrentTab = "Main"

local WaitingForKey = nil

local Looking = false
local CameraToken = 0
local CameraState = nil

local Dragging = false
local DragStart = nil
local StartPosition = nil

local SystemDestroyed = false
local MenuRemoved = false

local NoFogEnabled = false
local NoFogConnection = nil

local SavedFogStart = Lighting.FogStart
local SavedFogEnd = Lighting.FogEnd
local SavedAtmospheres = {}

local ESPObjects = {}

local FloatingButtonRemoved = false
local FloatingDragging = false
local FloatingDragStart = nil
local FloatingStartPosition = nil

--------------------------------------------------------------
-- GUI REFERENCES
--------------------------------------------------------------

local ScreenGui
local ESPContainer
local MainFrame

local MainTab
local AppearanceTab
local ESPTab
local MiscTab

local MainPage
local AppearancePage
local ESPPage
local MiscPage

local CloseButton
local MasterButton
local MouseButton

local DurationBox
local DistanceBox
local FOVSizeBox
local ESPThicknessBox
local ESPBoxSizeBox

local MenuKeyButton

local KeyButtons = {}
local SlotToggleButtons = {}
local ColorFields = {}

local ESPEnabledButton
local ESPRainbowButton

local FOVEnabledButton
local FOVRainbowButton

local Notification

local FloatingButton
local FloatingClose

local ColorPicker
local SelectedColorField

--------------------------------------------------------------
-- BASIC HELPERS
--------------------------------------------------------------

local function getCharacter(player)
    return player and player.Character or nil
end

local function getRoot(player)
    local character = getCharacter(player)

    if not character then
        return nil
    end

    return character:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid(player)
    local character = getCharacter(player)

    if not character then
        return nil
    end

    return character:FindFirstChildOfClass("Humanoid")
end

local function isAlive(player)
    local humanoid = getHumanoid(player)

    return humanoid ~= nil and humanoid.Health > 0
end

--------------------------------------------------------------
-- SCREEN POSITION
--
-- IMPORTANTE:
-- ScreenGui usa IgnoreGuiInset = true.
-- Portanto NÃO devemos descontar GuiInset.
--------------------------------------------------------------


local function worldToOverlayPoint(camera, worldPosition)
    local viewport, onScreen = camera:WorldToViewportPoint(worldPosition)
    return Vector2.new(viewport.X, viewport.Y), viewport.Z, onScreen
end

local function getViewportSize()
    local camera = workspace.CurrentCamera
    if not camera then return Vector2.zero end
    return camera.ViewportSize
end

local function projectToScreenEdge(camera, worldPosition, margin)
    local point, depth = worldToOverlayPoint(camera, worldPosition)
    local viewport = getViewportSize()
    local center = viewport / 2
    local m = margin or 8

    if depth <= 0 then
        point = center + (center - point)
    end

    local delta = point - center
    if delta.Magnitude < 0.001 then
        return Vector2.new(center.X, m)
    end

    local tx = math.huge
    local ty = math.huge
    if delta.X > 0 then
        tx = (viewport.X - m - center.X) / delta.X
    elseif delta.X < 0 then
        tx = (m - center.X) / delta.X
    end
    if delta.Y > 0 then
        ty = (viewport.Y - m - center.Y) / delta.Y
    elseif delta.Y < 0 then
        ty = (m - center.Y) / delta.Y
    end

    local t = math.min(tx, ty)
    if t == math.huge or t < 0 then t = 1 end
    return center + delta * t
end

local function getCursorPosition()
    local mousePosition = UserInputService:GetMouseLocation()
    return Vector2.new(mousePosition.X, mousePosition.Y)
end

--------------------------------------------------------------
-- RESET
--------------------------------------------------------------

local function resetSettings()
    Settings.MasterEnabled =
        DEFAULT_SETTINGS.MasterEnabled

    Settings.MasterKey =
        DEFAULT_SETTINGS.MasterKey

    for slot, key in pairs(DEFAULT_SETTINGS.ActivationKeys) do
        Settings.ActivationKeys[slot] = key
    end

    for slot, enabled in pairs(DEFAULT_SETTINGS.ActivationEnabled) do
        Settings.ActivationEnabled[slot] = enabled
    end

    Settings.LookDuration =
        DEFAULT_SETTINGS.LookDuration

    Settings.MaxDistance =
        DEFAULT_SETTINGS.MaxDistance

    Settings.MouseCenterEnabled =
        DEFAULT_SETTINGS.MouseCenterEnabled

    Settings.FOVEnabled =
        DEFAULT_SETTINGS.FOVEnabled

    Settings.FOVSize =
        DEFAULT_SETTINGS.FOVSize

    Settings.FOVRainbow =
        DEFAULT_SETTINGS.FOVRainbow

    Settings.ESPEnabled =
        DEFAULT_SETTINGS.ESPEnabled

    Settings.ESPRainbow =
        DEFAULT_SETTINGS.ESPRainbow

    Settings.ESPThickness =
        DEFAULT_SETTINGS.ESPThickness

    Settings.ESPBoxSize =
        DEFAULT_SETTINGS.ESPBoxSize
end

local function resetAppearance()
    for key, value in pairs(DEFAULT_APPEARANCE) do
        Appearance[key] = value
    end
end

--------------------------------------------------------------
-- SCREEN GUI
--------------------------------------------------------------

ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "TrinityHub"
ScreenGui.ResetOnSpawn = false

-- ESSENCIAL PARA AS COORDENADAS DO MOUSE:
ScreenGui.IgnoreGuiInset = true

ScreenGui.ZIndexBehavior =
    Enum.ZIndexBehavior.Sibling

ScreenGui.Parent = PlayerGui

--------------------------------------------------------------
-- ESP CONTAINER
--------------------------------------------------------------

ESPContainer = Instance.new("Frame")
ESPContainer.Name = "ESPOverlay"
ESPContainer.Size = UDim2.fromScale(1, 1)
ESPContainer.Position = UDim2.fromScale(0, 0)
ESPContainer.BackgroundTransparency = 1
ESPContainer.BorderSizePixel = 0
ESPContainer.ZIndex = 20
ESPContainer.Parent = ScreenGui

--------------------------------------------------------------
-- FOV
--------------------------------------------------------------

local FOVCircle = Instance.new("Frame")
FOVCircle.Name = "FOV"
FOVCircle.AnchorPoint = Vector2.new(0.5, 0.5)
FOVCircle.BackgroundTransparency = 1
FOVCircle.BorderSizePixel = 0
FOVCircle.Visible = false
FOVCircle.ZIndex = 25
FOVCircle.Parent = ESPContainer

local FOVCorner = Instance.new("UICorner")
FOVCorner.CornerRadius = UDim.new(1, 0)
FOVCorner.Parent = FOVCircle

local FOVStroke = Instance.new("UIStroke")
FOVStroke.Thickness = 2
FOVStroke.Color = Appearance.FOVColor
FOVStroke.Parent = FOVCircle

--------------------------------------------------------------
-- GUI HELPERS
--------------------------------------------------------------

local function addCorner(instance, radius)
    local corner = Instance.new("UICorner")

    corner.CornerRadius =
        UDim.new(0, radius or 8)

    corner.Parent = instance

    return corner
end

local function createSection(parent, text)
    local label = Instance.new("TextLabel")

    label.Size =
        UDim2.new(1, -10, 0, 30)

    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 =
        Appearance.AccentColor

    label.TextSize = 13
    label.Font = Enum.Font.GothamBold

    label.TextXAlignment =
        Enum.TextXAlignment.Left

    label.Parent = parent

    return label
end

local function createRow(parent, height)
    local row = Instance.new("Frame")

    row.Size =
        UDim2.new(1, -10, 0, height or 45)

    row.BackgroundColor3 =
        Appearance.PanelColor

    row.BorderSizePixel = 0
    row.Parent = parent

    addCorner(row, 8)

    return row
end

local function createLabel(parent, text)
    local label = Instance.new("TextLabel")

    label.Size =
        UDim2.new(0.55, 0, 1, 0)

    label.Position =
        UDim2.fromOffset(14, 0)

    label.BackgroundTransparency = 1
    label.Text = text

    label.TextColor3 =
        Color3.fromRGB(230, 230, 235)

    label.TextSize = 14
    label.Font = Enum.Font.GothamMedium

    label.TextXAlignment =
        Enum.TextXAlignment.Left

    label.Parent = parent

    return label
end

local function createButton(parent, text, width)
    local button = Instance.new("TextButton")

    button.Size =
        UDim2.fromOffset(width or 90, 32)

    button.BackgroundColor3 =
        Appearance.ButtonColor

    button.BorderSizePixel = 0
    button.Text = text

    button.TextColor3 =
        Color3.new(1, 1, 1)

    button.TextSize = 13
    button.Font = Enum.Font.GothamBold
    button.Parent = parent

    addCorner(button, 7)

    return button
end

local function createTextSetting(
    parent,
    labelText,
    value,
    callback
)
    local row = createRow(parent)

    createLabel(row, labelText)

    local box = Instance.new("TextBox")

    box.Size =
        UDim2.fromOffset(115, 32)

    box.Position =
        UDim2.new(1, -130, 0.5, -16)

    box.BackgroundColor3 =
        Appearance.ButtonColor

    box.BorderSizePixel = 0

    box.TextColor3 =
        Color3.new(1, 1, 1)

    box.TextSize = 13
    box.Font = Enum.Font.Gotham

    box.ClearTextOnFocus = false
    box.Text = tostring(value)
    box.Parent = row

    addCorner(box, 7)

    box.FocusLost:Connect(function()
        callback(box)
    end)

    return box
end

--------------------------------------------------------------
-- MAIN FRAME
--------------------------------------------------------------

MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"

MainFrame.Size =
    UDim2.fromOffset(500, 570)

MainFrame.Position =
    UDim2.fromScale(0.5, 0.5)

MainFrame.AnchorPoint =
    Vector2.new(0.5, 0.5)

MainFrame.BackgroundColor3 =
    Appearance.MenuColor

MainFrame.BorderSizePixel = 0
MainFrame.Visible = false
MainFrame.ZIndex = 40
MainFrame.Parent = ScreenGui

addCorner(MainFrame, 14)

local MainStroke = Instance.new("UIStroke")
MainStroke.Color =
    Color3.fromRGB(65, 65, 75)

MainStroke.Thickness = 1
MainStroke.Parent = MainFrame

--------------------------------------------------------------
-- TITLE
--------------------------------------------------------------

local Title = Instance.new("TextLabel")

Title.Size =
    UDim2.new(1, -70, 0, 40)

Title.Position =
    UDim2.fromOffset(20, 8)

Title.BackgroundTransparency = 1
Title.Text = "TrinityHub V1"

Title.TextColor3 =
    Color3.new(1, 1, 1)

Title.TextSize = 22
Title.Font = Enum.Font.GothamBold

Title.TextXAlignment =
    Enum.TextXAlignment.Left

Title.ZIndex = 41
Title.Parent = MainFrame

Title.InputBegan:Connect(function(input)
    if input.UserInputType ==
        Enum.UserInputType.MouseButton1
        or input.UserInputType ==
        Enum.UserInputType.Touch then

        Dragging = true
        DragStart = input.Position
        StartPosition = MainFrame.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if SystemDestroyed or not Dragging then
        return
    end

    if input.UserInputType ~=
        Enum.UserInputType.MouseMovement
        and input.UserInputType ~=
        Enum.UserInputType.Touch then

        return
    end

    local delta =
        input.Position - DragStart

    MainFrame.Position =
        UDim2.new(
            StartPosition.X.Scale,
            StartPosition.X.Offset + delta.X,
            StartPosition.Y.Scale,
            StartPosition.Y.Offset + delta.Y
        )
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType ==
        Enum.UserInputType.MouseButton1
        or input.UserInputType ==
        Enum.UserInputType.Touch then

        Dragging = false
    end
end)

--------------------------------------------------------------
-- CLOSE
--------------------------------------------------------------

CloseButton =
    createButton(MainFrame, "×", 35)

CloseButton.Position =
    UDim2.new(1, -45, 0, 12)

CloseButton.TextSize = 22
CloseButton.ZIndex = 42

--------------------------------------------------------------
-- TABS
--------------------------------------------------------------

MainTab =
    createButton(MainFrame, "MAIN", 110)

MainTab.Position =
    UDim2.fromOffset(15, 55)

AppearanceTab =
    createButton(MainFrame, "APPEARANCE", 110)

AppearanceTab.Position =
    UDim2.fromOffset(135, 55)

ESPTab =
    createButton(MainFrame, "ESP", 110)

ESPTab.Position =
    UDim2.fromOffset(255, 55)

MiscTab =
    createButton(MainFrame, "MISC", 110)

MiscTab.Position =
    UDim2.fromOffset(375, 55)

--------------------------------------------------------------
-- PAGES
--------------------------------------------------------------

local function createPage()
    local page = Instance.new("ScrollingFrame")

    page.Size =
        UDim2.new(1, -30, 1, -110)

    page.Position =
        UDim2.fromOffset(15, 100)

    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0

    page.ScrollBarThickness = 5

    page.ScrollBarImageColor3 =
        Appearance.AccentColor

    page.ScrollingDirection =
        Enum.ScrollingDirection.Y

    page.AutomaticCanvasSize =
        Enum.AutomaticSize.Y

    page.CanvasSize =
        UDim2.new(0, 0, 0, 0)

    page.ZIndex = 41
    page.Parent = MainFrame

    local padding = Instance.new("UIPadding")

    padding.PaddingLeft =
        UDim.new(0, 5)

    padding.PaddingRight =
        UDim.new(0, 5)

    padding.PaddingBottom =
        UDim.new(0, 15)

    padding.Parent = page

    local layout = Instance.new("UIListLayout")

    layout.Padding =
        UDim.new(0, 8)

    layout.SortOrder =
        Enum.SortOrder.LayoutOrder

    layout.Parent = page

    return page
end

MainPage = createPage()
AppearancePage = createPage()
ESPPage = createPage()
MiscPage = createPage()

AppearancePage.Visible = false
ESPPage.Visible = false
MiscPage.Visible = false

--------------------------------------------------------------
-- MAIN
--------------------------------------------------------------

createSection(MainPage, "GENERAL")

local MasterRow =
    createRow(MainPage)

createLabel(
    MasterRow,
    "Master Switch"
)

MasterButton =
    createButton(
        MasterRow,
        "ON",
        85
    )

MasterButton.Position =
    UDim2.new(1, -100, 0.5, -16)

local function updateMasterButton()
    MasterButton.Text =
        Settings.MasterEnabled
        and "ON"
        or "OFF"

    MasterButton.BackgroundColor3 =
        Settings.MasterEnabled
        and Appearance.AccentColor
        or Color3.fromRGB(150, 50, 50)
end

MasterButton.MouseButton1Click:Connect(function()
    Settings.MasterEnabled =
        not Settings.MasterEnabled

    updateMasterButton()
end)

--------------------------------------------------------------
-- ACTIVATION
--------------------------------------------------------------

createSection(
    MainPage,
    "ACTIVATION SLOTS"
)

local function createSlotRow(slot)
    local row =
        createRow(MainPage, 48)

    createLabel(
        row,
        "Slot " .. slot
    )

    local keyButton =
        createButton(
            row,
            Settings.ActivationKeys[slot],
            85
        )

    keyButton.Position =
        UDim2.new(1, -205, 0.5, -16)

    KeyButtons[slot] =
        keyButton

    keyButton.MouseButton1Click:Connect(function()
        if WaitingForKey then
            return
        end

        WaitingForKey = slot
        keyButton.Text = "Pressione..."
    end)

    local toggleButton =
        createButton(
            row,
            "ON",
            85
        )

    toggleButton.Position =
        UDim2.new(1, -105, 0.5, -16)

    SlotToggleButtons[slot] =
        toggleButton

    local function updateToggle()
        toggleButton.Text =
            Settings.ActivationEnabled[slot]
            and "ON"
            or "OFF"

        toggleButton.BackgroundColor3 =
            Settings.ActivationEnabled[slot]
            and Appearance.AccentColor
            or Color3.fromRGB(150, 50, 50)
    end

    toggleButton.MouseButton1Click:Connect(function()
        Settings.ActivationEnabled[slot] =
            not Settings.ActivationEnabled[slot]

        updateToggle()
    end)

    updateToggle()
end

for _, slot in ipairs({
    "Z",
    "X",
    "C",
    "V",
    "F",
    "R"
}) do
    createSlotRow(slot)
end

--------------------------------------------------------------
-- MENU KEY
--------------------------------------------------------------

local MenuKeyRow =
    createRow(MainPage, 48)

createLabel(
    MenuKeyRow,
    "Menu Key"
)

MenuKeyButton =
    createButton(
        MenuKeyRow,
        Settings.MasterKey,
        85
    )

MenuKeyButton.Position =
    UDim2.new(1, -105, 0.5, -16)

MenuKeyButton.Parent =
    MenuKeyRow

MenuKeyButton.MouseButton1Click:Connect(function()
    if WaitingForKey then
        return
    end

    WaitingForKey = "MASTER"
    MenuKeyButton.Text = "Pressione..."
end)

--------------------------------------------------------------
-- CAMERA
--------------------------------------------------------------

createSection(
    MainPage,
    "CAMERA"
)

DurationBox =
    createTextSetting(
        MainPage,
        "Look Duration",
        Settings.LookDuration,
        function(box)
            local value =
                tonumber(box.Text)

            if value then
                Settings.LookDuration =
                    math.clamp(
                        value,
                        0.01,
                        10
                    )
            end

            box.Text =
                tostring(
                    Settings.LookDuration
                )
        end
    )

local MouseRow =
    createRow(MainPage)

createLabel(
    MouseRow,
    "Centralizar Mouse"
)

MouseButton =
    createButton(
        MouseRow,
        "ON",
        85
    )

MouseButton.Position =
    UDim2.new(1, -100, 0.5, -16)

local function updateMouseButton()
    MouseButton.Text =
        Settings.MouseCenterEnabled
        and "ON"
        or "OFF"

    MouseButton.BackgroundColor3 =
        Settings.MouseCenterEnabled
        and Appearance.AccentColor
        or Color3.fromRGB(150, 50, 50)
end

MouseButton.MouseButton1Click:Connect(function()
    Settings.MouseCenterEnabled =
        not Settings.MouseCenterEnabled

    updateMouseButton()
end)

--------------------------------------------------------------
-- TARGETING
--------------------------------------------------------------

createSection(
    MainPage,
    "TARGETING"
)

DistanceBox =
    createTextSetting(
        MainPage,
        "Max Search Distance",
        Settings.MaxDistance,
        function(box)
            local value =
                tonumber(box.Text)

            if value then
                Settings.MaxDistance =
                    math.clamp(
                        value,
                        5,
                        2000
                    )
            end

            box.Text =
                tostring(
                    Settings.MaxDistance
                )
        end
    )

--------------------------------------------------------------
-- FOV
--------------------------------------------------------------

createSection(
    MainPage,
    "FOV"
)

local FOVEnabledRow =
    createRow(MainPage)

createLabel(
    FOVEnabledRow,
    "FOV"
)

FOVEnabledButton =
    createButton(
        FOVEnabledRow,
        "OFF",
        85
    )

FOVEnabledButton.Position =
    UDim2.new(
        1,
        -100,
        0.5,
        -16
    )

local function updateFOVEnabled()
    FOVEnabledButton.Text =
        Settings.FOVEnabled
        and "ON"
        or "OFF"

    FOVEnabledButton.BackgroundColor3 =
        Settings.FOVEnabled
        and Appearance.AccentColor
        or Color3.fromRGB(150, 50, 50)

    FOVCircle.Visible =
        Settings.FOVEnabled
end

FOVEnabledButton.MouseButton1Click:Connect(function()
    Settings.FOVEnabled =
        not Settings.FOVEnabled

    updateFOVEnabled()
end)

FOVSizeBox =
    createTextSetting(
        MainPage,
        "FOV Size",
        Settings.FOVSize,
        function(box)
            local value =
                tonumber(box.Text)

            if value then
                Settings.FOVSize =
                    math.clamp(
                        value,
                        25,
                        1000
                    )
            end

            box.Text =
                tostring(
                    Settings.FOVSize
                )
        end
    )

local FOVRainbowRow =
    createRow(MainPage)

createLabel(
    FOVRainbowRow,
    "FOV Rainbow"
)

FOVRainbowButton =
    createButton(
        FOVRainbowRow,
        "OFF",
        85
    )

FOVRainbowButton.Position =
    UDim2.new(
        1,
        -100,
        0.5,
        -16
    )

local function updateFOVRainbow()
    FOVRainbowButton.Text =
        Settings.FOVRainbow
        and "ON"
        or "OFF"

    FOVRainbowButton.BackgroundColor3 =
        Settings.FOVRainbow
        and Appearance.AccentColor
        or Color3.fromRGB(150, 50, 50)
end

FOVRainbowButton.MouseButton1Click:Connect(function()
    Settings.FOVRainbow =
        not Settings.FOVRainbow

    updateFOVRainbow()
end)

--------------------------------------------------------------
-- ESP
--------------------------------------------------------------

createSection(
    ESPPage,
    "GENERAL"
)

local ESPEnabledRow =
    createRow(ESPPage)

createLabel(
    ESPEnabledRow,
    "ESP Enabled"
)

ESPEnabledButton =
    createButton(
        ESPEnabledRow,
        "ON",
        85
    )

ESPEnabledButton.Position =
    UDim2.new(
        1,
        -100,
        0.5,
        -16
    )

local function updateESPEnabledButton()
    ESPEnabledButton.Text =
        Settings.ESPEnabled
        and "ON"
        or "OFF"

    ESPEnabledButton.BackgroundColor3 =
        Settings.ESPEnabled
        and Appearance.AccentColor
        or Color3.fromRGB(150, 50, 50)
end

ESPEnabledButton.MouseButton1Click:Connect(function()
    Settings.ESPEnabled =
        not Settings.ESPEnabled

    updateESPEnabledButton()
end)

local ESPRainbowRow =
    createRow(ESPPage)

createLabel(
    ESPRainbowRow,
    "Rainbow"
)

ESPRainbowButton =
    createButton(
        ESPRainbowRow,
        "OFF",
        85
    )

ESPRainbowButton.Position =
    UDim2.new(
        1,
        -100,
        0.5,
        -16
    )

local function updateESPRainbowButton()
    ESPRainbowButton.Text =
        Settings.ESPRainbow
        and "ON"
        or "OFF"

    ESPRainbowButton.BackgroundColor3 =
        Settings.ESPRainbow
        and Appearance.AccentColor
        or Color3.fromRGB(150, 50, 50)
end

ESPRainbowButton.MouseButton1Click:Connect(function()
    Settings.ESPRainbow =
        not Settings.ESPRainbow

    updateESPRainbowButton()
end)

--------------------------------------------------------------
-- ESP VISUAL
--------------------------------------------------------------

createSection(
    ESPPage,
    "VISUAL"
)

ESPThicknessBox =
    createTextSetting(
        ESPPage,
        "Line Thickness",
        Settings.ESPThickness,
        function(box)
            local value =
                tonumber(box.Text)

            if value then
                Settings.ESPThickness =
                    math.clamp(
                        value,
                        1,
                        10
                    )
            end

            box.Text =
                tostring(
                    Settings.ESPThickness
                )
        end
    )

ESPBoxSizeBox =
    createTextSetting(
        ESPPage,
        "Box Size",
        Settings.ESPBoxSize,
        function(box)
            local value =
                tonumber(box.Text)

            if value then
                Settings.ESPBoxSize =
                    math.clamp(
                        value,
                        0.25,
                        3
                    )
            end

            box.Text =
                tostring(
                    Settings.ESPBoxSize
                )
        end
    )

-- ESP Toggles: Box and Skeleton
local ESPBoxRow = createRow(ESPPage)
createLabel(ESPBoxRow, "Box Outline")
local ESPBoxButton = createButton(ESPBoxRow, Settings.ESPBoxEnabled and "ON" or "OFF", 85)
ESPBoxButton.Position = UDim2.new(1, -100, 0.5, -16)
local function updateESPBoxButton()
    ESPBoxButton.Text = Settings.ESPBoxEnabled and "ON" or "OFF"
    ESPBoxButton.BackgroundColor3 = Settings.ESPBoxEnabled and Appearance.AccentColor or Color3.fromRGB(150,50,50)
end
ESPBoxButton.MouseButton1Click:Connect(function()
    Settings.ESPBoxEnabled = not Settings.ESPBoxEnabled
    updateESPBoxButton()
end)

local ESPSkelRow = createRow(ESPPage)
createLabel(ESPSkelRow, "Skeleton")
local ESPSkelButton = createButton(ESPSkelRow, Settings.ESPSkeletonEnabled and "ON" or "OFF", 85)
ESPSkelButton.Position = UDim2.new(1, -100, 0.5, -16)
local function updateESPSkelButton()
    ESPSkelButton.Text = Settings.ESPSkeletonEnabled and "ON" or "OFF"
    ESPSkelButton.BackgroundColor3 = Settings.ESPSkeletonEnabled and Appearance.AccentColor or Color3.fromRGB(150,50,50)
end
ESPSkelButton.MouseButton1Click:Connect(function()
    Settings.ESPSkeletonEnabled = not Settings.ESPSkeletonEnabled
    updateESPSkelButton()
end)

updateESPBoxButton()
updateESPSkelButton()

-- Health toggle
local ESPHealthRow = createRow(ESPPage)
createLabel(ESPHealthRow, "Health Bar")
local ESPHealthButton = createButton(ESPHealthRow, Settings.ESPHealthEnabled and "ON" or "OFF", 85)
ESPHealthButton.Position = UDim2.new(1, -100, 0.5, -16)
local function updateESPHealthButton()
    ESPHealthButton.Text = Settings.ESPHealthEnabled and "ON" or "OFF"
    ESPHealthButton.BackgroundColor3 = Settings.ESPHealthEnabled and Appearance.AccentColor or Color3.fromRGB(150,50,50)
end
ESPHealthButton.MouseButton1Click:Connect(function()
    Settings.ESPHealthEnabled = not Settings.ESPHealthEnabled
    updateESPHealthButton()
end)

updateESPHealthButton()

--------------------------------------------------------------
-- APPEARANCE
--------------------------------------------------------------

createSection(
    AppearancePage,
    "INTERFACE"
)

--------------------------------------------------------------
-- COLOR PICKER
--------------------------------------------------------------

ColorPicker = Instance.new("Frame")

ColorPicker.Size =
    UDim2.fromOffset(280, 330)

ColorPicker.Position =
    UDim2.fromScale(0.5, 0.5)

ColorPicker.AnchorPoint =
    Vector2.new(0.5, 0.5)

ColorPicker.BackgroundColor3 =
    Color3.fromRGB(25, 25, 30)

ColorPicker.BorderSizePixel = 0
ColorPicker.Visible = false
ColorPicker.ZIndex = 200
ColorPicker.Parent = ScreenGui

addCorner(ColorPicker, 12)

local PickerTitle =
    Instance.new("TextLabel")

PickerTitle.Size =
    UDim2.new(1, -55, 0, 32)

PickerTitle.Position =
    UDim2.fromOffset(15, 7)

PickerTitle.BackgroundTransparency = 1
PickerTitle.Text = "Choose Color"

PickerTitle.TextColor3 =
    Color3.new(1, 1, 1)

PickerTitle.TextSize = 14
PickerTitle.Font =
    Enum.Font.GothamBold

PickerTitle.TextXAlignment =
    Enum.TextXAlignment.Left

PickerTitle.Parent = ColorPicker

local PickerClose =
    createButton(
        ColorPicker,
        "×",
        30
    )

PickerClose.Position =
    UDim2.new(1, -38, 0, 8)

local SV =
    Instance.new("Frame")

SV.Size =
    UDim2.fromOffset(205, 205)

SV.Position =
    UDim2.fromOffset(15, 48)

SV.BackgroundColor3 =
    Color3.fromRGB(255, 0, 0)

SV.BorderSizePixel = 0
SV.ZIndex = 201
SV.Parent = ColorPicker

addCorner(SV, 7)

local White =
    Instance.new("Frame")

White.Size =
    UDim2.fromScale(1, 1)

White.BackgroundColor3 =
    Color3.new(1, 1, 1)

White.BorderSizePixel = 0
White.Parent = SV

local WhiteGradient =
    Instance.new("UIGradient")

WhiteGradient.Transparency =
    NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 1),
    })

WhiteGradient.Parent = White

local Black =
    Instance.new("Frame")

Black.Size =
    UDim2.fromScale(1, 1)

Black.BackgroundColor3 =
    Color3.new(0, 0, 0)

Black.BorderSizePixel = 0
Black.Parent = SV

local BlackGradient =
    Instance.new("UIGradient")

BlackGradient.Rotation = 90

BlackGradient.Transparency =
    NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(1, 0),
    })

BlackGradient.Parent = Black

local SVPointer =
    Instance.new("Frame")

SVPointer.Size =
    UDim2.fromOffset(12, 12)

SVPointer.AnchorPoint =
    Vector2.new(0.5, 0.5)

SVPointer.BackgroundTransparency = 1
SVPointer.Parent = SV

addCorner(SVPointer, 6)

local SVStroke =
    Instance.new("UIStroke")

SVStroke.Color =
    Color3.new(1, 1, 1)

SVStroke.Thickness = 2
SVStroke.Parent = SVPointer

local HueBar =
    Instance.new("Frame")

HueBar.Size =
    UDim2.fromOffset(28, 205)

HueBar.Position =
    UDim2.fromOffset(235, 48)

HueBar.BorderSizePixel = 0
HueBar.Parent = ColorPicker

addCorner(HueBar, 7)

local HueGradient =
    Instance.new("UIGradient")

HueGradient.Rotation = 90

HueGradient.Color =
    ColorSequence.new({
        ColorSequenceKeypoint.new(
            0,
            Color3.fromRGB(255, 0, 0)
        ),
        ColorSequenceKeypoint.new(
            0.166,
            Color3.fromRGB(255, 255, 0)
        ),
        ColorSequenceKeypoint.new(
            0.333,
            Color3.fromRGB(0, 255, 0)
        ),
        ColorSequenceKeypoint.new(
            0.5,
            Color3.fromRGB(0, 255, 255)
        ),
        ColorSequenceKeypoint.new(
            0.666,
            Color3.fromRGB(0, 0, 255)
        ),
        ColorSequenceKeypoint.new(
            0.833,
            Color3.fromRGB(255, 0, 255)
        ),
        ColorSequenceKeypoint.new(
            1,
            Color3.fromRGB(255, 0, 0)
        ),
    })

HueGradient.Parent = HueBar

local HuePointer =
    Instance.new("Frame")

HuePointer.Size =
    UDim2.new(1, 4, 0, 4)

HuePointer.AnchorPoint =
    Vector2.new(0.5, 0.5)

HuePointer.BackgroundColor3 =
    Color3.new(1, 1, 1)

HuePointer.BorderSizePixel = 0
HuePointer.Parent = HueBar

local Hue = 0
local Saturation = 1
local Value = 1

--------------------------------------------------------------
-- APPEARANCE LIVE
--------------------------------------------------------------

local function applyAppearanceLive()

    MainFrame.BackgroundColor3 =
        Appearance.MenuColor

    FOVStroke.Color =
        Appearance.FOVColor

    for _, page in ipairs({
        MainPage,
        AppearancePage,
        ESPPage,
        MiscPage
    }) do
        for _, child in ipairs(page:GetChildren()) do
            if child:IsA("Frame") then
                child.BackgroundColor3 =
                    Appearance.PanelColor
            end
        end
    end

    for field, button in pairs(ColorFields) do
        if Appearance[field] then
            button.BackgroundColor3 =
                Appearance[field]
        end
    end

    MainTab.BackgroundColor3 =
        CurrentTab == "Main"
        and Appearance.AccentColor
        or Appearance.ButtonColor

    AppearanceTab.BackgroundColor3 =
        CurrentTab == "Appearance"
        and Appearance.AccentColor
        or Appearance.ButtonColor

    ESPTab.BackgroundColor3 =
        CurrentTab == "ESP"
        and Appearance.AccentColor
        or Appearance.ButtonColor

    MiscTab.BackgroundColor3 =
        CurrentTab == "Misc"
        and Appearance.AccentColor
        or Appearance.ButtonColor

    updateMasterButton()
    updateMouseButton()
    updateFOVEnabled()
    updateFOVRainbow()
    updateESPEnabledButton()
    updateESPRainbowButton()
end

--------------------------------------------------------------
-- COLOR PICKER UPDATE
--------------------------------------------------------------

local function updateColorPicker()
    if not SelectedColorField then
        return
    end

    local color =
        Color3.fromHSV(
            Hue,
            Saturation,
            Value
        )

    Appearance[SelectedColorField] =
        color

    local preview =
        ColorFields[SelectedColorField]

    if preview then
        preview.BackgroundColor3 =
            color
    end

    SV.BackgroundColor3 =
        Color3.fromHSV(
            Hue,
            1,
            1
        )

    SVPointer.Position =
        UDim2.fromScale(
            Saturation,
            1 - Value
        )

    HuePointer.Position =
        UDim2.new(
            0.5,
            0,
            Hue,
            0
        )

    applyAppearanceLive()
end

--------------------------------------------------------------
-- SV DRAG
--------------------------------------------------------------

local SVDragging = false

SV.InputBegan:Connect(function(input)
    if input.UserInputType ==
        Enum.UserInputType.MouseButton1
        or input.UserInputType ==
        Enum.UserInputType.Touch then

        SVDragging = true
    end
end)

SV.InputEnded:Connect(function(input)
    if input.UserInputType ==
        Enum.UserInputType.MouseButton1
        or input.UserInputType ==
        Enum.UserInputType.Touch then

        SVDragging = false
    end
end)

SV.InputChanged:Connect(function(input)
    if not SVDragging then
        return
    end

    if input.UserInputType ~=
        Enum.UserInputType.MouseMovement
        and input.UserInputType ~=
        Enum.UserInputType.Touch then

        return
    end

    local position =
        SV.AbsolutePosition

    local size =
        SV.AbsoluteSize

    Saturation =
        math.clamp(
            (input.Position.X - position.X)
                / size.X,
            0,
            1
        )

    Value =
        1 - math.clamp(
            (input.Position.Y - position.Y)
                / size.Y,
            0,
            1
        )

    updateColorPicker()
end)

--------------------------------------------------------------
-- HUE DRAG
--------------------------------------------------------------

local HueDragging = false

HueBar.InputBegan:Connect(function(input)
    if input.UserInputType ==
        Enum.UserInputType.MouseButton1
        or input.UserInputType ==
        Enum.UserInputType.Touch then

        HueDragging = true
    end
end)

HueBar.InputEnded:Connect(function(input)
    if input.UserInputType ==
        Enum.UserInputType.MouseButton1
        or input.UserInputType ==
        Enum.UserInputType.Touch then

        HueDragging = false
    end
end)

HueBar.InputChanged:Connect(function(input)
    if not HueDragging then
        return
    end

    if input.UserInputType ~=
        Enum.UserInputType.MouseMovement
        and input.UserInputType ~=
        Enum.UserInputType.Touch then

        return
    end

    local position =
        HueBar.AbsolutePosition

    local size =
        HueBar.AbsoluteSize

    Hue =
        math.clamp(
            (input.Position.Y - position.Y)
                / size.Y,
            0,
            1
        )

    updateColorPicker()
end)

PickerClose.MouseButton1Click:Connect(function()
    ColorPicker.Visible = false
    SelectedColorField = nil
end)

local function openColorPicker(field)
    SelectedColorField = field

    local h, s, v =
        Color3.toHSV(
            Appearance[field]
        )

    Hue = h
    Saturation = s
    Value = v

    SV.BackgroundColor3 =
        Color3.fromHSV(
            Hue,
            1,
            1
        )

    SVPointer.Position =
        UDim2.fromScale(
            Saturation,
            1 - Value
        )

    HuePointer.Position =
        UDim2.new(
            0.5,
            0,
            Hue,
            0
        )

    ColorPicker.Visible = true
end

local function createColorRow(
    parent,
    text,
    fieldName
)
    local row =
        createRow(parent, 48)

    createLabel(
        row,
        text
    )

    local button =
        createButton(
            row,
            "Choose",
            95
        )

    button.Position =
        UDim2.new(
            1,
            -110,
            0.5,
            -16
        )

    button.BackgroundColor3 =
        Appearance[fieldName]

    ColorFields[fieldName] =
        button

    button.MouseButton1Click:Connect(function()
        openColorPicker(fieldName)
    end)
end

createColorRow(
    AppearancePage,
    "Menu Color",
    "MenuColor"
)

createColorRow(
    AppearancePage,
    "Panel Color",
    "PanelColor"
)

createColorRow(
    AppearancePage,
    "Button Color",
    "ButtonColor"
)

createColorRow(
    AppearancePage,
    "Accent Color",
    "AccentColor"
)

createColorRow(
    AppearancePage,
    "Notification Color",
    "NotificationColor"
)

createSection(
    AppearancePage,
    "ESP COLORS"
)

createColorRow(
    AppearancePage,
    "ESP Lines",
    "ESPLineColor"
)

createColorRow(
    AppearancePage,
    "ESP Box",
    "ESPBoxColor"
)

createColorRow(
    AppearancePage,
    "ESP Skeleton",
    "ESPSkeletonColor"
)

createColorRow(
    AppearancePage,
    "ESP Health",
    "ESPHealthColor"
)

createSection(
    AppearancePage,
    "FOV"
)

createColorRow(
    AppearancePage,
    "FOV Color",
    "FOVColor"
)

local ResetAppearanceButton =
    createButton(
        AppearancePage,
        "Reset Appearance",
        120
    )

ResetAppearanceButton.Size =
    UDim2.new(1, -10, 0, 42)

ResetAppearanceButton.MouseButton1Click:Connect(function()
    resetAppearance()
    applyAppearanceLive()
end)

--------------------------------------------------------------
-- MISC
--------------------------------------------------------------

createSection(
    MiscPage,
    "UTILITY"
)

local SpoofMenuButton =
    createButton(
        MiscPage,
        "Spoof Menu",
        140
    )

SpoofMenuButton.Size =
    UDim2.new(1, -10, 0, 46)

SpoofMenuButton.BackgroundColor3 =
    Color3.fromRGB(190, 45, 45)

--------------------------------------------------------------
-- NO FOG
--------------------------------------------------------------

local NoFogRow =
    createRow(MiscPage)

createLabel(
    NoFogRow,
    "No Fog"
)

local NoFogButton =
    createButton(
        NoFogRow,
        "OFF",
        85
    )

NoFogButton.Position =
    UDim2.new(
        1,
        -100,
        0.5,
        -16
    )

local function captureAtmosphereState()
    table.clear(SavedAtmospheres)

    for _, child in ipairs(
        Lighting:GetChildren()
    ) do

        if child:IsA("Atmosphere") then
            SavedAtmospheres[child] = {
                Parent = child.Parent,
                Density = child.Density,
                Haze = child.Haze,
                Glare = child.Glare,
                Color = child.Color,
                Decay = child.Decay,
                Offset = child.Offset,
            }
        end
    end
end

local function setNoFog(enabled)
    NoFogEnabled = enabled

    if enabled then

        SavedFogStart =
            Lighting.FogStart

        SavedFogEnd =
            Lighting.FogEnd

        captureAtmosphereState()

        Lighting.FogStart = 0
        Lighting.FogEnd = 1000000

        for atmosphere in pairs(
            SavedAtmospheres
        ) do
            if atmosphere.Parent ==
                Lighting then

                atmosphere.Parent = nil
            end
        end

        if NoFogConnection then
            NoFogConnection:Disconnect()
        end

        NoFogConnection =
            Lighting.ChildAdded:Connect(function(child)

                if NoFogEnabled
                    and child:IsA("Atmosphere") then

                    task.defer(function()

                        if NoFogEnabled
                            and child.Parent ==
                                Lighting then

                            child.Parent = nil
                        end
                    end)
                end
            end)

        NoFogButton.Text = "ON"

        NoFogButton.BackgroundColor3 =
            Appearance.AccentColor

    else

        if NoFogConnection then
            NoFogConnection:Disconnect()
            NoFogConnection = nil
        end

        Lighting.FogStart =
            SavedFogStart

        Lighting.FogEnd =
            SavedFogEnd

        for atmosphere, state in pairs(
            SavedAtmospheres
        ) do

            if atmosphere
                and atmosphere.Parent == nil then

                atmosphere.Parent =
                    state.Parent
                    or Lighting
            end

            if atmosphere
                and atmosphere.Parent == Lighting then

                atmosphere.Density =
                    state.Density

                atmosphere.Haze =
                    state.Haze

                atmosphere.Glare =
                    state.Glare

                atmosphere.Color =
                    state.Color

                atmosphere.Decay =
                    state.Decay

                atmosphere.Offset =
                    state.Offset
            end
        end

        table.clear(
            SavedAtmospheres
        )

        NoFogButton.Text = "OFF"

        NoFogButton.BackgroundColor3 =
            Color3.fromRGB(
                150,
                50,
                50
            )
    end
end

NoFogButton.MouseButton1Click:Connect(function()
    setNoFog(
        not NoFogEnabled
    )
end)

--------------------------------------------------------------
-- ESP DRAWING
--------------------------------------------------------------

local function makeESPLine(name)
    local frame =
        Instance.new("Frame")

    frame.Name = name

    frame.AnchorPoint =
        Vector2.new(0.5, 0.5)

    frame.BorderSizePixel = 0
    frame.Visible = false
    frame.ZIndex = 30
    frame.Parent = ESPContainer

    return frame
end

local function makeBox()
    return {
        Top = makeESPLine("Top"),
        Bottom = makeESPLine("Bottom"),
        Left = makeESPLine("Left"),
        Right = makeESPLine("Right"),
    }
end

local function makeSkeleton(maxSegments)
    local segments = {}

    for i = 1, maxSegments do
        segments[i] =
            makeESPLine(
                "Skeleton_" .. i
            )
    end

    return segments
end

local function getESPObject(player)
    if ESPObjects[player] then
        return ESPObjects[player]
    end

    local object = {
        Line = makeESPLine("TargetLine"),
        Box = makeBox(),
        Skeleton = makeSkeleton(24),
        HealthBg = makeESPLine("HealthBg"),
        HealthFill = makeESPLine("HealthFill"),
    }

    ESPObjects[player] = object

    return object
end

local function hideESPObject(object)
    if object.Line then
        object.Line.Visible = false
    end

    if object.Box then
        for _, line in pairs(
            object.Box
        ) do
            line.Visible = false
        end
    end

    if object.Skeleton then
        for _, line in ipairs(
            object.Skeleton
        ) do
            line.Visible = false
        end
    end
    if object.HealthBg then
        object.HealthBg.Visible = false
    end
    if object.HealthFill then
        object.HealthFill.Visible = false
    end
end

local function destroyESPObject(player)
    local object =
        ESPObjects[player]

    if not object then
        return
    end

    hideESPObject(object)

    if object.Line then
        object.Line:Destroy()
    end

    if object.Box then
        for _, line in pairs(
            object.Box
        ) do
            line:Destroy()
        end
    end

    if object.Skeleton then
        for _, line in ipairs(
            object.Skeleton
        ) do
            line:Destroy()
        end
    end

    if object.HealthBg then
        object.HealthBg:Destroy()
    end

    if object.HealthFill then
        object.HealthFill:Destroy()
    end

    ESPObjects[player] = nil
end

local function getRainbowColor(offset)
    return Color3.fromHSV(
        (os.clock() * 0.20 + offset) % 1,
        1,
        1
    )
end

local function drawLine(
    frame,
    fromPos,
    toPos,
    thickness,
    color
)
    if not frame then
        return
    end

    local delta =
        toPos - fromPos

    local length =
        delta.Magnitude

    if length < 1 then
        frame.Visible = false
        return
    end

    local midpoint =
        (fromPos + toPos) / 2

    frame.Position =
        UDim2.fromOffset(
            midpoint.X,
            midpoint.Y
        )

    frame.Size =
        UDim2.fromOffset(
            length,
            thickness
        )

    frame.Rotation =
        math.deg(
            math.atan2(
                delta.Y,
                delta.X
            )
        )

    frame.BackgroundColor3 =
        color

    frame.Visible = true
end

--------------------------------------------------------------
-- BOX
--------------------------------------------------------------

local function getBoxBounds(
    camera,
    character
)
    local cf, size =
        character:GetBoundingBox()

    size *=
        Settings.ESPBoxSize

    local half =
        size / 2

    local corners = {
        cf * Vector3.new(
            -half.X,
            -half.Y,
            -half.Z
        ),

        cf * Vector3.new(
            -half.X,
            -half.Y,
            half.Z
        ),

        cf * Vector3.new(
            -half.X,
            half.Y,
            -half.Z
        ),

        cf * Vector3.new(
            -half.X,
            half.Y,
            half.Z
        ),

        cf * Vector3.new(
            half.X,
            -half.Y,
            -half.Z
        ),

        cf * Vector3.new(
            half.X,
            -half.Y,
            half.Z
        ),

        cf * Vector3.new(
            half.X,
            half.Y,
            -half.Z
        ),

        cf * Vector3.new(
            half.X,
            half.Y,
            half.Z
        ),
    }

    local minX = math.huge
    local minY = math.huge

    local maxX = -math.huge
    local maxY = -math.huge

    local visible = false

    for _, worldPoint in ipairs(
        corners
    ) do

        local screen, depth =
            worldToOverlayPoint(camera, 
                worldPoint
            )

        if depth > 0 then
            visible = true

            minX =
                math.min(
                    minX,
                    screen.X
                )

            minY =
                math.min(
                    minY,
                    screen.Y
                )

            maxX =
                math.max(
                    maxX,
                    screen.X
                )

            maxY =
                math.max(
                    maxY,
                    screen.Y
                )
        end
    end

    if not visible then
        return nil
    end

    return minX, minY, maxX, maxY
end

--------------------------------------------------------------
-- SKELETON
--------------------------------------------------------------

local R15Connections = {
    {"Head", "UpperTorso"},
    {"UpperTorso", "LowerTorso"},

    {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},

    {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"},
    {"RightLowerArm", "RightHand"},

    {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},

    {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"},
    {"RightLowerLeg", "RightFoot"},
}

local R6Connections = {
    {"Head", "Torso"},
    {"Torso", "Left Arm"},
    {"Torso", "Right Arm"},
    {"Torso", "Left Leg"},
    {"Torso", "Right Leg"},
}

local function drawSkeleton(
    camera,
    character,
    skeletonLines,
    color
)
    local connections

    if character:FindFirstChild(
        "UpperTorso"
    ) then

        connections =
            R15Connections

    else
        connections =
            R6Connections
    end

    local drawn = 0

    for _, connection in ipairs(
        connections
    ) do

        local a =
            character:FindFirstChild(
                connection[1]
            )

        local b =
            character:FindFirstChild(
                connection[2]
            )

        if a and b
            and a:IsA("BasePart")
            and b:IsA("BasePart") then

            local pa, za =
                worldToOverlayPoint(camera, 
                    a.Position
                )

            local pb, zb =
                worldToOverlayPoint(camera, 
                    b.Position
                )

            if za > 0
                and zb > 0 then

                drawn += 1

                drawLine(
                    skeletonLines[drawn],
                    Vector2.new(
                        pa.X,
                        pa.Y
                    ),
                    Vector2.new(
                        pb.X,
                        pb.Y
                    ),
                    Settings.ESPThickness,
                    color
                )
            end
        end
    end

    for i = drawn + 1,
        #skeletonLines do

        skeletonLines[i].Visible =
            false
    end
end

--------------------------------------------------------------
-- UPDATE ESP
--------------------------------------------------------------

local function updateESP()
    if SystemDestroyed then
        return
    end

    if not Settings.ESPEnabled then
        for _, object in pairs(
            ESPObjects
        ) do
            hideESPObject(object)
        end

        return
    end

    local camera =
        workspace.CurrentCamera

    local localRoot =
        getRoot(LocalPlayer)

    if not camera or not localRoot then
        return
    end

    -- MESMA COORDENADA USADA PELO FOV
    local cursor =
        getCursorPosition()

    for _, player in ipairs(
        Players:GetPlayers()
    ) do

        if player == LocalPlayer then
            continue
        end

        local character =
            getCharacter(player)

        local root =
            getRoot(player)

        if not character
            or not root
            or not isAlive(player) then

            if ESPObjects[player] then
                hideESPObject(
                    ESPObjects[player]
                )
            end

            continue
        end

        local distance =
            (
                root.Position
                - localRoot.Position
            ).Magnitude

        if distance >
            Settings.MaxDistance then

            if ESPObjects[player] then
                hideESPObject(
                    ESPObjects[player]
                )
            end

            continue
        end

        local object =
            getESPObject(player)

        local rainbowBase =
            player.UserId * 0.001

        local lineColor =
            Settings.ESPRainbow
            and getRainbowColor(
                rainbowBase
            )
            or Appearance.ESPLineColor

        local boxColor =
            Settings.ESPRainbow
            and getRainbowColor(
                rainbowBase + 0.2
            )
            or Appearance.ESPBoxColor

        local skeletonColor =
            Settings.ESPRainbow
            and getRainbowColor(
                rainbowBase + 0.4
            )
            or Appearance.ESPSkeletonColor

        ------------------------------------------------------
        -- LINE
        ------------------------------------------------------

        local targetPart =
            character:FindFirstChild(
                "Head"
            )
            or root

        local screen, depth =
            worldToOverlayPoint(camera, 
                targetPart.Position
            )

        local point
        if depth > 0 then
            point = screen
        else
            point = projectToScreenEdge(camera, targetPart.Position, 8)
        end

        drawLine(
            object.Line,
            cursor,
            point,
            Settings.ESPThickness,
            lineColor
        )

        ------------------------------------------------------
        -- BOX
        ------------------------------------------------------

        local minX,
            minY,
            maxX,
            maxY =
            getBoxBounds(
                camera,
                character
            )

        if minX then
            if Settings.ESPBoxEnabled then
                drawLine(
                    object.Box.Top,
                    Vector2.new(
                        minX,
                        minY
                    ),
                    Vector2.new(
                        maxX,
                        minY
                    ),
                    Settings.ESPThickness,
                    boxColor
                )

                drawLine(
                    object.Box.Bottom,
                    Vector2.new(
                        minX,
                        maxY
                    ),
                    Vector2.new(
                        maxX,
                        maxY
                    ),
                    Settings.ESPThickness,
                    boxColor
                )

                drawLine(
                    object.Box.Left,
                    Vector2.new(
                        minX,
                        minY
                    ),
                    Vector2.new(
                        minX,
                        maxY
                    ),
                    Settings.ESPThickness,
                    boxColor
                )

                drawLine(
                    object.Box.Right,
                    Vector2.new(
                        maxX,
                        minY
                    ),
                    Vector2.new(
                        maxX,
                        maxY
                    ),
                    Settings.ESPThickness,
                    boxColor
                )
            else
                for _, line in pairs(object.Box) do
                    line.Visible = false
                end
            end
        else
            for _, line in pairs(object.Box) do
                line.Visible = false
            end
        end

        ------------------------------------------------------
        -- HEALTH BAR (left side of box)
        ------------------------------------------------------

        if minX and Settings.ESPHealthEnabled and object.HealthBg and object.HealthFill then
            local healthColor = Settings.ESPRainbow and getRainbowColor(rainbowBase + 0.6) or Appearance.ESPHealthColor

            -- full bar (background)
            local hx = minX - 8
            local hy1 = minY
            local hy2 = maxY
            drawLine(
                object.HealthBg,
                Vector2.new(hx, hy1),
                Vector2.new(hx, hy2),
                math.max(2, Settings.ESPThickness),
                Color3.fromRGB(40,40,40)
            )

            -- fill according to health percent (from bottom up)
            if object and object.Skeleton then
                local hum = getHumanoid(player)
                if hum and hum.Parent then
                    local pct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                    local height = math.max(1, (maxY - minY))
                    local fillLen = height * pct
                    if fillLen < 1 then
                        object.HealthFill.Visible = false
                    else
                        local fy1 = maxY - fillLen
                        local fy2 = maxY
                        drawLine(
                            object.HealthFill,
                            Vector2.new(hx, fy1),
                            Vector2.new(hx, fy2),
                            math.max(2, Settings.ESPThickness),
                            healthColor
                        )
                    end
                else
                    object.HealthFill.Visible = false
                end
            end
        else
            if object.HealthBg then object.HealthBg.Visible = false end
            if object.HealthFill then object.HealthFill.Visible = false end
        end

        ------------------------------------------------------
        -- SKELETON
        ------------------------------------------------------

        if Settings.ESPSkeletonEnabled then
            drawSkeleton(
                camera,
                character,
                object.Skeleton,
                skeletonColor
            )
        else
            for _, seg in ipairs(object.Skeleton) do
                seg.Visible = false
            end
        end
    end
end

--------------------------------------------------------------
-- UPDATE FOV
--------------------------------------------------------------

local function updateFOV()
    if SystemDestroyed then
        return
    end

    if not Settings.FOVEnabled then
        FOVCircle.Visible = false
        return
    end

    -- EXATAMENTE A MESMA POSIÇÃO DO MOUSE
    -- USADA PELO ESP E PELO TARGETING
    local cursor =
        getCursorPosition()

    FOVCircle.Position =
        UDim2.fromOffset(
            cursor.X,
            cursor.Y
        )

    FOVCircle.Size =
        UDim2.fromOffset(
            Settings.FOVSize * 2,
            Settings.FOVSize * 2
        )

    if Settings.FOVRainbow then

        FOVStroke.Color =
            getRainbowColor(0)

    else

        FOVStroke.Color =
            Appearance.FOVColor
    end

    FOVCircle.Visible = true
end

--------------------------------------------------------------
-- FOV TARGET CHECK
--------------------------------------------------------------

local function isPlayerInsideFOV(player)
    -- FOV DESLIGADO:
    -- NÃO FILTRA O ALVO.
    if not Settings.FOVEnabled then
        return true
    end

    local camera =
        workspace.CurrentCamera

    if not camera then
        return false
    end

    local character =
        getCharacter(player)

    if not character then
        return false
    end

    local target =
        character:FindFirstChild(
            "Head"
        )
        or getRoot(player)

    if not target then
        return false
    end

    local screen, depth =
        worldToOverlayPoint(camera,
            target.Position
        )

    if depth <= 0 then
        return false
    end

    -- WorldToScreenPoint e GetMouseLocation
    -- agora estão no MESMO espaço de tela.
    local targetPosition =
        Vector2.new(
            screen.X,
            screen.Y
        )

    local cursor =
        getCursorPosition()

    local difference =
        targetPosition - cursor

    return difference.Magnitude
        <= Settings.FOVSize
end

--------------------------------------------------------------
-- CLOSEST PLAYER
--------------------------------------------------------------

local function getClosestPlayer()
    local localRoot =
        getRoot(LocalPlayer)

    if not localRoot then
        return nil
    end

    local closestPlayer = nil

    local closestScreenDistance =
        math.huge

    for _, player in ipairs(
        Players:GetPlayers()
    ) do

        if player ~= LocalPlayer
            and isAlive(player) then

            local root =
                getRoot(player)

            if root then

                local distance =
                    (
                        root.Position
                        - localRoot.Position
                    ).Magnitude

                if distance <=
                    Settings.MaxDistance then

                    -- FOV DESLIGADO:
                    -- escolhe o mais próximo da tela.
                    --
                    -- FOV LIGADO:
                    -- só considera quem estiver dentro.
                    if isPlayerInsideFOV(
                        player
                    ) then

                        local camera =
                            workspace.CurrentCamera

                        local target =
                            getCharacter(player)
                                :FindFirstChild(
                                    "Head"
                                )
                                or root

                        if camera
                            and target then

                            local screen, depth =
                                worldToOverlayPoint(camera,
                                    target.Position
                                )

                            if depth > 0 then

                                local cursor =
                                    getCursorPosition()

                                local screenPosition =
                                    Vector2.new(
                                        screen.X,
                                        screen.Y
                                    )

                                local screenDistance =
                                    (
                                        screenPosition
                                        - cursor
                                    ).Magnitude

                                if screenDistance
                                    < closestScreenDistance then

                                    closestScreenDistance =
                                        screenDistance

                                    closestPlayer =
                                        player
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return closestPlayer
end

--------------------------------------------------------------
-- CAMERA
--------------------------------------------------------------

local CameraBindName =
    "TrinityHub_Camera"

local function stopCameraLook()
    CameraToken += 1

    if not Looking then
        return
    end

    Looking = false

    pcall(function()
        RunService:UnbindToRenderStep(
            CameraBindName
        )
    end)

    local camera =
        workspace.CurrentCamera

    if not camera then
        CameraState = nil
        return
    end

    if CameraState then

        camera.CameraType =
            CameraState.CameraType

        camera.CameraSubject =
            CameraState.CameraSubject

        camera.CFrame =
            CameraState.CFrame

        camera.Focus =
            CameraState.Focus

        UserInputService.MouseBehavior =
            CameraState.MouseBehavior

        if CameraState.CameraType ==
            Enum.CameraType.Custom then

            local humanoid =
                getHumanoid(
                    LocalPlayer
                )

            if humanoid then
                camera.CameraSubject =
                    humanoid
            end
        end
    end

    CameraState = nil
end

local function lookAtPlayer(targetPlayer)
    if Looking
        or not targetPlayer then

        return
    end

    local camera =
        workspace.CurrentCamera

    local localRoot =
        getRoot(LocalPlayer)

    local targetRoot =
        getRoot(targetPlayer)

    if not camera
        or not localRoot
        or not targetRoot then

        return
    end

    Looking = true

    CameraToken += 1

    local thisToken =
        CameraToken

    CameraState = {
        CameraType =
            camera.CameraType,

        CameraSubject =
            camera.CameraSubject,

        CFrame =
            camera.CFrame,

        Focus =
            camera.Focus,

        MouseBehavior =
            UserInputService.MouseBehavior,
    }

    local cameraOffset =
        camera.CFrame.Position
        - localRoot.Position

    camera.CameraType =
        Enum.CameraType.Scriptable

    if Settings.MouseCenterEnabled then
        UserInputService.MouseBehavior =
            Enum.MouseBehavior.LockCenter
    end

    RunService:BindToRenderStep(
        CameraBindName,
        Enum.RenderPriority.Last.Value,
        function()

            if thisToken ~= CameraToken
                or not Looking then

                return
            end

            local currentCamera =
                workspace.CurrentCamera

            local currentLocalRoot =
                getRoot(LocalPlayer)

            local currentTargetRoot =
                getRoot(targetPlayer)

            if not currentCamera
                or not currentLocalRoot
                or not currentTargetRoot
                or not isAlive(targetPlayer) then

                stopCameraLook()
                return
            end

            local cameraPosition =
                currentLocalRoot.Position
                + cameraOffset

            local targetPosition =
                currentTargetRoot.Position
                + Vector3.new(
                    0,
                    1.5,
                    0
                )

            currentCamera.CFrame =
                CFrame.lookAt(
                    cameraPosition,
                    targetPosition
                )

            currentCamera.Focus =
                CFrame.new(
                    targetPosition
                )
        end
    )

    task.delay(
        Settings.LookDuration,
        function()

            if thisToken ==
                CameraToken then

                stopCameraLook()
            end
        end
    )
end

--------------------------------------------------------------
-- ACTIVATION
--------------------------------------------------------------

local function activateSlot(slot)

    if MenuOpen then
        return
    end

    if not Settings.MasterEnabled then
        return
    end

    if not Settings.ActivationEnabled[slot] then
        return
    end

    if Looking then
        return
    end

    local target =
        getClosestPlayer()

    if target then
        lookAtPlayer(target)
    end
end

--------------------------------------------------------------
-- FLOATING MOBILE BUTTON
--------------------------------------------------------------

FloatingButton =
    Instance.new("Frame")

FloatingButton.Name =
    "FloatingButton"

FloatingButton.Size =
    UDim2.fromOffset(58, 58)

FloatingButton.Position =
    UDim2.new(
        0,
        25,
        0.5,
        -29
    )

FloatingButton.BackgroundColor3 =
    Appearance.AccentColor

FloatingButton.BorderSizePixel = 0
FloatingButton.ZIndex = 150
FloatingButton.Parent = ScreenGui

addCorner(
    FloatingButton,
    29
)

local FloatingStroke =
    Instance.new("UIStroke")

FloatingStroke.Color =
    Color3.fromRGB(0, 0, 0)

FloatingStroke.Thickness = 3
FloatingStroke.Parent =
    FloatingButton

local FloatingText =
    Instance.new("TextLabel")

FloatingText.Size =
    UDim2.fromScale(1, 1)

FloatingText.BackgroundTransparency = 1
FloatingText.Text = "T"

FloatingText.TextColor3 =
    Color3.new(1, 1, 1)

FloatingText.TextSize = 27

FloatingText.Font =
    Enum.Font.GothamBold

FloatingText.ZIndex = 151
FloatingText.Parent =
    FloatingButton

FloatingClose =
    Instance.new("TextButton")

FloatingClose.Size =
    UDim2.fromOffset(20, 20)

FloatingClose.Position =
    UDim2.new(
        1,
        -8,
        0,
        -7
    )

FloatingClose.AnchorPoint =
    Vector2.new(0.5, 0.5)

FloatingClose.BackgroundColor3 =
    Color3.fromRGB(15, 15, 15)

FloatingClose.BorderSizePixel = 0
FloatingClose.Text = "×"

FloatingClose.TextColor3 =
    Color3.new(1, 1, 1)

FloatingClose.TextSize = 14

FloatingClose.Font =
    Enum.Font.GothamBold

FloatingClose.ZIndex = 152
FloatingClose.Parent =
    FloatingButton

addCorner(
    FloatingClose,
    10
)

FloatingButton.InputBegan:Connect(function(input)

    if input.UserInputType ==
        Enum.UserInputType.MouseButton1
        or input.UserInputType ==
        Enum.UserInputType.Touch then

        FloatingDragging = false

        FloatingDragStart =
            input.Position

        FloatingStartPosition =
            FloatingButton.Position

        task.delay(
            0.08,
            function()

                if FloatingDragStart then
                    FloatingDragging = true
                end
            end
        )
    end
end)

UserInputService.InputChanged:Connect(function(input)

    if not FloatingDragStart then
        return
    end

    if input.UserInputType ~=
        Enum.UserInputType.MouseMovement
        and input.UserInputType ~=
        Enum.UserInputType.Touch then

        return
    end

    local delta =
        input.Position
        - FloatingDragStart

    if delta.Magnitude > 5 then

        FloatingDragging = true

        FloatingButton.Position =
            UDim2.new(
                FloatingStartPosition.X.Scale,
                FloatingStartPosition.X.Offset
                    + delta.X,

                FloatingStartPosition.Y.Scale,
                FloatingStartPosition.Y.Offset
                    + delta.Y
            )
    end
end)

UserInputService.InputEnded:Connect(function(input)

    if input.UserInputType ==
        Enum.UserInputType.MouseButton1
        or input.UserInputType ==
        Enum.UserInputType.Touch then

        if FloatingDragStart
            and not FloatingDragging then

            if not MenuRemoved then
                MenuOpen =
                    not MenuOpen

                MainFrame.Visible =
                    MenuOpen
            end
        end

        FloatingDragStart = nil
        FloatingDragging = false
    end
end)

FloatingClose.MouseButton1Click:Connect(function()

    FloatingButtonRemoved = true

    FloatingButton.Visible = false
end)

--------------------------------------------------------------
-- MENU
--------------------------------------------------------------

local function closeMenu()
    MenuOpen = false

    MainFrame.Visible = false

    if ColorPicker then
        ColorPicker.Visible = false
    end
end

local function toggleMenu()

    if MenuRemoved then
        return
    end

    MenuOpen =
        not MenuOpen

    MainFrame.Visible =
        MenuOpen

    if not MenuOpen
        and ColorPicker then

        ColorPicker.Visible = false
    end
end

CloseButton.MouseButton1Click:Connect(
    closeMenu
)

--------------------------------------------------------------
-- TABS
--------------------------------------------------------------

local function showTab(tabName)

    CurrentTab =
        tabName

    MainPage.Visible =
        tabName == "Main"

    AppearancePage.Visible =
        tabName == "Appearance"

    ESPPage.Visible =
        tabName == "ESP"

    MiscPage.Visible =
        tabName == "Misc"

    MainTab.BackgroundColor3 =
        tabName == "Main"
        and Appearance.AccentColor
        or Appearance.ButtonColor

    AppearanceTab.BackgroundColor3 =
        tabName == "Appearance"
        and Appearance.AccentColor
        or Appearance.ButtonColor

    ESPTab.BackgroundColor3 =
        tabName == "ESP"
        and Appearance.AccentColor
        or Appearance.ButtonColor

    MiscTab.BackgroundColor3 =
        tabName == "Misc"
        and Appearance.AccentColor
        or Appearance.ButtonColor
end

MainTab.MouseButton1Click:Connect(function()
    showTab("Main")
end)

AppearanceTab.MouseButton1Click:Connect(function()
    showTab("Appearance")
end)

ESPTab.MouseButton1Click:Connect(function()
    showTab("ESP")
end)

MiscTab.MouseButton1Click:Connect(function()
    showTab("Misc")
end)

--------------------------------------------------------------
-- SPOOF MENU
--------------------------------------------------------------

local function spoofMenuNow()

    if SystemDestroyed then
        return
    end

    SystemDestroyed = true
    MenuRemoved = true
    MenuOpen = false

    Settings.MasterEnabled = false
    Settings.ESPEnabled = false
    Settings.FOVEnabled = false

    pcall(stopCameraLook)

    pcall(function()
        RunService:UnbindToRenderStep(
            CameraBindName
        )
    end)

    pcall(function()
        RunService:UnbindToRenderStep(
            "TrinityHub_ESP"
        )
    end)

    pcall(function()
        RunService:UnbindToRenderStep(
            "TrinityHub_FOV"
        )
    end)

    for player in pairs(
        ESPObjects
    ) do
        destroyESPObject(player)
    end

    if NoFogEnabled then
        pcall(function()
            setNoFog(false)
        end)
    end

    if FloatingButton then
        FloatingButton:Destroy()
    end

    if ScreenGui then
        ScreenGui:Destroy()
        ScreenGui = nil
    end
end

SpoofMenuButton.MouseButton1Click:Connect(
    spoofMenuNow
)

--------------------------------------------------------------
-- INPUT
--------------------------------------------------------------

local InputConnection

local function getSlotFromKey(keyName)

    for slot, configuredKey in pairs(
        Settings.ActivationKeys
    ) do

        if configuredKey ==
            keyName then

            return slot
        end
    end

    return nil
end

InputConnection =
    UserInputService.InputBegan:Connect(
        function(input)

            if SystemDestroyed then
                return
            end

            if input.UserInputType ~=
                Enum.UserInputType.Keyboard then

                return
            end

            local keyName =
                input.KeyCode.Name

            if keyName == "Unknown" then
                return
            end

            --------------------------------------------------
            -- KEY CAPTURE
            --------------------------------------------------

            if WaitingForKey then

                local slot =
                    WaitingForKey

                if slot == "MASTER" then

                    Settings.MasterKey =
                        keyName

                    MenuKeyButton.Text =
                        keyName

                else

                    Settings.ActivationKeys[slot] =
                        keyName

                    KeyButtons[slot].Text =
                        keyName
                end

                WaitingForKey = nil
                return
            end

            --------------------------------------------------
            -- MENU
            --------------------------------------------------

            if keyName ==
                Settings.MasterKey then

                toggleMenu()
                return
            end

            --------------------------------------------------
            -- MENU OPEN
            --------------------------------------------------

            if MenuOpen then
                return
            end

            if UserInputService:GetFocusedTextBox() then
                return
            end

            --------------------------------------------------
            -- MASTER
            --------------------------------------------------

            if not Settings.MasterEnabled then
                return
            end

            local slot =
                getSlotFromKey(keyName)

            if slot then
                activateSlot(slot)
            end
        end
    )

--------------------------------------------------------------
-- RESET BUTTON
--------------------------------------------------------------

local ResetButton =
    createButton(
        MainPage,
        "Reset Settings",
        120
    )

ResetButton.Size =
    UDim2.new(1, -10, 0, 42)

ResetButton.MouseButton1Click:Connect(function()

    resetSettings()

    updateMasterButton()
    updateMouseButton()
    updateFOVEnabled()
    updateFOVRainbow()

    DurationBox.Text =
        tostring(
            Settings.LookDuration
        )

    DistanceBox.Text =
        tostring(
            Settings.MaxDistance
        )

    FOVSizeBox.Text =
        tostring(
            Settings.FOVSize
        )

    MenuKeyButton.Text =
        Settings.MasterKey

    for slot, button in pairs(
        KeyButtons
    ) do

        button.Text =
            Settings.ActivationKeys[slot]
    end

    for slot, button in pairs(
        SlotToggleButtons
    ) do

        button.Text =
            Settings.ActivationEnabled[slot]
            and "ON"
            or "OFF"

        button.BackgroundColor3 =
            Settings.ActivationEnabled[slot]
            and Appearance.AccentColor
            or Color3.fromRGB(
                150,
                50,
                50
            )
    end

    ESPThicknessBox.Text =
        tostring(
            Settings.ESPThickness
        )

    ESPBoxSizeBox.Text =
        tostring(
            Settings.ESPBoxSize
        )

    updateESPEnabledButton()
    updateESPRainbowButton()
end)

--------------------------------------------------------------
-- RENDER
--------------------------------------------------------------

RunService:BindToRenderStep(
    "TrinityHub_ESP",
    Enum.RenderPriority.Last.Value - 2,
    updateESP
)

RunService:BindToRenderStep(
    "TrinityHub_FOV",
    Enum.RenderPriority.Last.Value - 1,
    updateFOV
)

--------------------------------------------------------------
-- PLAYER CLEANUP
--------------------------------------------------------------

Players.PlayerRemoving:Connect(function(player)
    destroyESPObject(player)
end)

--------------------------------------------------------------
-- INITIAL STATE
--------------------------------------------------------------

showTab("Main")

updateMasterButton()
updateMouseButton()
updateFOVEnabled()
updateFOVRainbow()
updateESPEnabledButton()
updateESPRainbowButton()

setNoFog(false)

applyAppearanceLive()

--------------------------------------------------------------
-- FLOATING BUTTON COLOR
--------------------------------------------------------------

FloatingButton.BackgroundColor3 =
    Appearance.AccentColor

--------------------------------------------------------------
-- NOTIFICATION
--------------------------------------------------------------

Notification =
    Instance.new("Frame")

Notification.Name =
    "LoadedNotification"

Notification.Size =
    UDim2.fromOffset(350, 75)

Notification.Position =
    UDim2.new(
        1,
        370,
        0,
        20
    )

Notification.AnchorPoint =
    Vector2.new(1, 0)

Notification.BackgroundColor3 =
    Appearance.NotificationColor

Notification.BorderSizePixel = 0
Notification.ZIndex = 100
Notification.Parent = ScreenGui

addCorner(
    Notification,
    12
)

local NotificationStroke =
    Instance.new("UIStroke")

NotificationStroke.Color =
    Appearance.AccentColor

NotificationStroke.Thickness = 1
NotificationStroke.Parent =
    Notification

local NotificationIcon =
    Instance.new("Frame")

NotificationIcon.Size =
    UDim2.fromOffset(44, 44)

NotificationIcon.Position =
    UDim2.fromOffset(15, 15)

NotificationIcon.BackgroundColor3 =
    Appearance.AccentColor

NotificationIcon.BorderSizePixel = 0
NotificationIcon.Parent =
    Notification

addCorner(
    NotificationIcon,
    22
)

local Check =
    Instance.new("TextLabel")

Check.Size =
    UDim2.fromScale(1, 1)

Check.BackgroundTransparency = 1
Check.Text = "✓"

Check.TextColor3 =
    Color3.new(1, 1, 1)

Check.TextSize = 24

Check.Font =
    Enum.Font.GothamBold

Check.Parent =
    NotificationIcon

local NotificationTitle =
    Instance.new("TextLabel")

NotificationTitle.Size =
    UDim2.new(1, -75, 0, 25)

NotificationTitle.Position =
    UDim2.fromOffset(72, 10)

NotificationTitle.BackgroundTransparency = 1
NotificationTitle.Text =
    "TrinityHub V1"

NotificationTitle.TextColor3 =
    Color3.new(1, 1, 1)

NotificationTitle.TextSize = 15

NotificationTitle.Font =
    Enum.Font.GothamBold

NotificationTitle.TextXAlignment =
    Enum.TextXAlignment.Left

NotificationTitle.Parent =
    Notification

local NotificationMessage =
    Instance.new("TextLabel")

NotificationMessage.Size =
    UDim2.new(1, -75, 0, 25)

NotificationMessage.Position =
    UDim2.fromOffset(72, 35)

NotificationMessage.BackgroundTransparency = 1

NotificationMessage.Text =
    "Sistema carregado com sucesso!"

NotificationMessage.TextColor3 =
    Color3.fromRGB(
        175,
        175,
        185
    )

NotificationMessage.TextSize = 12

NotificationMessage.Font =
    Enum.Font.Gotham

NotificationMessage.TextXAlignment =
    Enum.TextXAlignment.Left

NotificationMessage.Parent =
    Notification

local NotificationIn =
    TweenService:Create(
        Notification,
        TweenInfo.new(
            0.35,
            Enum.EasingStyle.Quint,
            Enum.EasingDirection.Out
        ),
        {
            Position =
                UDim2.new(
                    1,
                    -20,
                    0,
                    20
                )
        }
    )

NotificationIn:Play()

task.delay(
    3.5,
    function()

        if not Notification
            or not Notification.Parent then

            return
        end

        local out =
            TweenService:Create(
                Notification,
                TweenInfo.new(
                    0.3,
                    Enum.EasingStyle.Quint,
                    Enum.EasingDirection.In
                ),
                {
                    Position =
                        UDim2.new(
                            1,
                            370,
                            0,
                            20
                        )
                }
            )

        out:Play()

        out.Completed:Connect(function()

            if Notification then
                Notification:Destroy()
            end
        end)
    end
)

--------------------------------------------------------------
-- FINAL CLEANUP
--------------------------------------------------------------

ScreenGui.Destroying:Connect(function()

    CameraToken += 1

    pcall(function()

        RunService:UnbindToRenderStep(
            CameraBindName
        )

        RunService:UnbindToRenderStep(
            "TrinityHub_ESP"
        )

        RunService:UnbindToRenderStep(
            "TrinityHub_FOV"
        )
    end)

    for player in pairs(
        ESPObjects
    ) do

        destroyESPObject(player)
    end

    if InputConnection then
        InputConnection:Disconnect()
        InputConnection = nil
    end

    if NoFogConnection then
        NoFogConnection:Disconnect()
        NoFogConnection = nil
    end

    Looking = false
    CameraState = nil
end)

