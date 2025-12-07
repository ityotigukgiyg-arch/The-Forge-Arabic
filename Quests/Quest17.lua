local Shared = _G.Shared

-- المهمة 17: التعدين التلقائي حتى المستوى 10 (تم الإصلاح - حركة سلسة)
-- ✅ تحقق من أن المستوى < 10
-- ✅ العثور على جميع الصخور في workspace.Rocks
-- ✅ انتقال سلس بين الصخور (بدون السقوط من الخريطة)
-- ✅ التكرار حتى الوصول للمستوى 10

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

----------------------------------------------------------------
-- الإعدادات
----------------------------------------------------------------
local Quest17Active = true
local IsMiningActive = false
local DEBUG_MODE = true

local QUEST_CONFIG = {
    QUEST_NAME = "التعدين التلقائي حتى المستوى 10",
    TARGET_LEVEL = 10,  -- التعدين حتى المستوى = 10
    
    -- إعدادات الصخور
    ROCK_NAME = "Boulder",
    
    UNDERGROUND_OFFSET = 4,
    LAYING_ANGLE = 90,
    MOVE_SPEED = 25,  
    
    -- إعدادات الحركة السلسة
    HOLD_POSITION_AFTER_MINE = true,  -- الثبات في الموقع بعد التعدين
    RESPAWN_WAIT_TIME = 3,  -- الانتظار لإعادة الظهور (بالثواني)
}

----------------------------------------------------------------
-- إعداد Knit
----------------------------------------------------------------
local KnitPackage = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Knit")
local Knit = require(KnitPackage)

if not Knit.OnStart then 
    pcall(function() Knit.Start():await() end)
end

local CharacterService = nil
local PlayerController = nil

pcall(function()
    CharacterService = Knit.GetService("CharacterService")
    PlayerController = Knit.GetController("PlayerController")
end)

local ToolController = nil
local ToolActivatedFunc = nil

pcall(function()
    for _, v in pairs(getgc(true)) do
        if type(v) == "table" then
            if rawget(v, "Name") == "ToolController" and rawget(v, "ToolActivated") then
                ToolController = v
                ToolActivatedFunc = v.ToolActivated
                break
            end
        end
    end
end)

local SERVICES = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Services")

local CHAR_RF = nil
pcall(function()
    CHAR_RF = SERVICES:WaitForChild("CharacterService", 5):WaitForChild("RF", 3):WaitForChild("EquipItem", 3)
end)

local TOOL_RF_BACKUP = nil
pcall(function()
    TOOL_RF_BACKUP = SERVICES:WaitForChild("ToolService", 5):WaitForChild("RF", 3):WaitForChild("ToolActivated", 3)
end)

local MINING_FOLDER_PATH = Workspace:WaitForChild("Rocks")

if CharacterService then print("✅ خدمة الشخصية جاهزة!") else warn("⚠️ خدمة الشخصية غير موجودة") end
if PlayerController then print("✅ وحدة تحكم اللاعب جاهزة!") else warn("⚠️ وحدة تحكم اللاعب غير موجودة") end
if ToolController then print("✅ وحدة تحكم الأدوات جاهزة!") else warn("⚠️ وحدة تحكم الأدوات غير موجودة") end

----------------------------------------------------------------
-- إدارة الحالة
----------------------------------------------------------------
local State = {
    currentTarget = nil,
    targetDestroyed = false,
    hpWatchConn = nil,
    noclipConn = nil,
    moveConn = nil,
    positionLockConn = nil,
    bodyVelocity = nil,
    bodyGyro = nil,
}

-- 🛡️ القائمة السوداء للصخور التي يقوم شخص آخر بتعدينها
-- الصيغة: { [rockModel] = expireTime }
local OccupiedRocks = {}
local OCCUPIED_TIMEOUT = 10  -- إزالة من القائمة السوداء بعد 10 ثواني

local function isRockOccupied(rock)
    if not rock then return false end
    local expireTime = OccupiedRocks[rock]
    if not expireTime then return false end
    
    if tick() > expireTime then
        OccupiedRocks[rock] = nil
        return false
    end
    return true
end

local function markRockAsOccupied(rock)
    if not rock then return end
    OccupiedRocks[rock] = tick() + OCCUPIED_TIMEOUT
    print(string.format("   🚫 أضيف إلى القائمة السوداء لمدة %d ثانية: %s", OCCUPIED_TIMEOUT, rock.Name))
end

local function cleanupExpiredBlacklist()
    local now = tick()
    for rock, expireTime in pairs(OccupiedRocks) do
        if now > expireTime or not rock.Parent then
            OccupiedRocks[rock] = nil
        end
    end
end

local function cleanupState()
    if State.hpWatchConn then State.hpWatchConn:Disconnect() State.hpWatchConn = nil end
    if State.noclipConn then State.noclipConn:Disconnect() State.noclipConn = nil end
    if State.moveConn then State.moveConn:Disconnect() State.moveConn = nil end
    if State.positionLockConn then State.positionLockConn:Disconnect() State.positionLockConn = nil end
    if State.bodyVelocity then State.bodyVelocity:Destroy() State.bodyVelocity = nil end
    if State.bodyGyro then State.bodyGyro:Destroy() State.bodyGyro = nil end
    
    State.currentTarget = nil
    State.targetDestroyed = false
    
    if ToolController then
        ToolController.holdingM1 = false
    end
end

----------------------------------------------------------------
-- نظام المستوى
----------------------------------------------------------------
local function getPlayerLevel()
    local levelLabel = playerGui:FindFirstChild("Main")
                      and playerGui.Main:FindFirstChild("Screen")
                      and playerGui.Main.Screen:FindFirstChild("Hud")
                      and playerGui.Main.Screen.Hud:FindFirstChild("Level")
    
    if not levelLabel or not levelLabel:IsA("TextLabel") then
        return nil
    end
    
    local levelText = levelLabel.Text
    local level = tonumber(string.match(levelText, "%d+"))
    
    return level
end

local function shouldMine()
    local level = getPlayerLevel()
    
    if not level then
        warn("   ❌ لا يمكن تحديد مستوى اللاعب!")
        return false
    end
    
    if level < QUEST_CONFIG.TARGET_LEVEL then
        return true
    else
        print(string.format("   ⏸️  المستوى %d >= %d - إيقاف التعدين", level, QUEST_CONFIG.TARGET_LEVEL))
        return false
    end
end

----------------------------------------------------------------
-- دوال مساعدة
----------------------------------------------------------------
local HOTKEY_MAP = {
    ["1"] = Enum.KeyCode.One,
    ["2"] = Enum.KeyCode.Two,
    ["3"] = Enum.KeyCode.Three,
    ["4"] = Enum.KeyCode.Four,
    ["5"] = Enum.KeyCode.Five,
    ["6"] = Enum.KeyCode.Six,
    ["7"] = Enum.KeyCode.Seven,
    ["8"] = Enum.KeyCode.Eight,
    ["9"] = Enum.KeyCode.Nine,
    ["0"] = Enum.KeyCode.Zero,
}

local function pressKey(keyCode)
    if not keyCode then return end
    VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
    task.wait(0.05)
    VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
end

local function findPickaxeSlotKey()
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return nil end
    
    local hotbar = gui:FindFirstChild("BackpackGui") 
                   and gui.BackpackGui:FindFirstChild("Backpack") 
                   and gui.BackpackGui.Backpack:FindFirstChild("Hotbar")
    
    if hotbar then
        for _, slotFrame in ipairs(hotbar:GetChildren()) do
            local frame = slotFrame:FindFirstChild("Frame")
            local label = frame and frame:FindFirstChild("ToolName")
            if label and label:IsA("TextLabel") and string.find(label.Text, "Pickaxe") then
                return HOTKEY_MAP[slotFrame.Name]
            end
        end
    end
    
    return nil
end

local function checkMiningError()
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return false end
    
    local notif = gui:FindFirstChild("Notifications")
    if notif and notif:FindFirstChild("Screen") and notif.Screen:FindFirstChild("NotificationsFrame") then
        for _, child in ipairs(notif.Screen.NotificationsFrame:GetChildren()) do
            local lbl = child:FindFirstChild("TextLabel", true)
            if lbl and string.find(lbl.Text, "Someone else is already mining") then
                return true
            end
        end
    end
    
    return false
end

----------------------------------------------------------------
-- مساعدات الصخور
----------------------------------------------------------------
local function getRockUndergroundPosition(rockModel)
    if not rockModel or not rockModel.Parent then
        return nil
    end
    
    local pivotCFrame = nil
    pcall(function()
        if rockModel.GetPivot then
            pivotCFrame = rockModel:GetPivot()
        elseif rockModel.WorldPivot then
            pivotCFrame = rockModel.WorldPivot
        end
    end)
    
    if pivotCFrame then
        local pos = pivotCFrame.Position
        return Vector3.new(pos.X, pos.Y - QUEST_CONFIG.UNDERGROUND_OFFSET, pos.Z)
    end
    
    if rockModel.PrimaryPart then
        local pos = rockModel.PrimaryPart.Position
        return Vector3.new(pos.X, pos.Y - QUEST_CONFIG.UNDERGROUND_OFFSET, pos.Z)
    end
    
    local part = rockModel:FindFirstChildWhichIsA("BasePart")
    if part then
        local pos = part.Position
        return Vector3.new(pos.X, pos.Y - QUEST_CONFIG.UNDERGROUND_OFFSET, pos.Z)
    end
    
    return nil
end

local function getRockHP(rock)
    if not rock or not rock.Parent then
        return 0
    end
    
    local success, result = pcall(function()
        return rock:GetAttribute("Health") or 0
    end)
    
    return success and result or 0
end

local function isTargetValid(rock)
    if not rock or not rock.Parent then
        return false
    end
    
    if not rock:FindFirstChildWhichIsA("BasePart") then
        return false
    end
    
    local hp = getRockHP(rock)
    return hp > 0
end

local function findNearestBoulder(excludeRock)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    
    cleanupExpiredBlacklist()
    
    local targetRock, minDist = nil, math.huge
    local skippedOccupied = 0
    
    for _, folder in ipairs(MINING_FOLDER_PATH:GetChildren()) do
        if folder:IsA("Folder") or folder:IsA("Model") then
            for _, child in ipairs(folder:GetChildren()) do
                if child:IsA("SpawnLocation") or child.Name == "SpawnLocation" then
                    local rock = child:FindFirstChild(QUEST_CONFIG.ROCK_NAME)
                    
                    if rock and rock ~= excludeRock and isTargetValid(rock) then
                        if isRockOccupied(rock) then
                            skippedOccupied = skippedOccupied + 1
                        else
                            local pos = getRockUndergroundPosition(rock)
                            if pos then
                                local dist = (pos - hrp.Position).Magnitude
                                
                                if dist < minDist then
                                    minDist = dist
                                    targetRock = rock
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    if skippedOccupied > 0 then
        print(string.format("   ⏭️ تم تخطي %d صخور مشغولة (في القائمة السوداء)", skippedOccupied))
    end
    
    return targetRock, minDist
end

local function watchRockHP(rock)
    if State.hpWatchConn then
        State.hpWatchConn:Disconnect()
    end
    
    if not rock then return end
    
    State.hpWatchConn = rock:GetAttributeChangedSignal("Health"):Connect(function()
        local hp = rock:GetAttribute("Health") or 0
        
        if hp <= 0 then
            print("   ✅ تم تدمير الصخرة!")
            State.targetDestroyed = true
            
            if ToolController then
                ToolController.holdingM1 = false
            end
        end
    end)
end

----------------------------------------------------------------
-- تعطيل التصادم والحركة
----------------------------------------------------------------
local function enableNoclip()
    if State.noclipConn then return end
    
    local char = player.Character
    if not char then return end
    
    State.noclipConn = RunService.Stepped:Connect(function()
        if not char or not char.Parent then
            if State.noclipConn then State.noclipConn:Disconnect() State.noclipConn = nil end
            return
        end
        
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end)
end

local function disableNoclip()
    if State.noclipConn then
        State.noclipConn:Disconnect()
        State.noclipConn = nil
    end
end

local function smoothMoveTo(targetPos, callback)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    if State.moveConn then State.moveConn:Disconnect() State.moveConn = nil end
    if State.bodyVelocity then State.bodyVelocity:Destroy() State.bodyVelocity = nil end
    if State.bodyGyro then State.bodyGyro:Destroy() State.bodyGyro = nil end
    
    enableNoclip()
    
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = hrp
    State.bodyVelocity = bv
    
    local bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bg.P = 10000
    bg.D = 500
    bg.Parent = hrp
    State.bodyGyro = bg
    
    print(string.format("   🚀 الانتقال إلى (%.1f, %.1f, %.1f)...", targetPos.X, targetPos.Y, targetPos.Z))
    
    State.moveConn = RunService.Heartbeat:Connect(function()
        if not char or not char.Parent or not hrp or not hrp.Parent then
            if State.moveConn then State.moveConn:Disconnect() State.moveConn = nil end
            if bv then bv:Destroy() end
            if bg then bg:Destroy() end
            State.bodyVelocity = nil
            State.bodyGyro = nil
            return
        end
        
        local currentPos = hrp.Position
        local direction = (targetPos - currentPos)
        local distance = direction.Magnitude
        
        if distance < 2 then
            print("   ✅ تم الوصول إلى الهدف!")
            
            bv.Velocity = Vector3.zero
            task.wait(0.1)
            
            bv:Destroy()
            bg:Destroy()
            State.bodyVelocity = nil
            State.bodyGyro = nil
            
            if State.moveConn then State.moveConn:Disconnect() State.moveConn = nil end
            
            if callback then callback() end
            return
        end
        
        local speed = math.min(QUEST_CONFIG.MOVE_SPEED, distance * 10)
        local velocity = direction.Unit * speed
        
        bv.Velocity = velocity
        bg.CFrame = CFrame.lookAt(currentPos, targetPos)
    end)
    
    return true
end

----------------------------------------------------------------
-- قفل الموقع (انتقال سلس)
----------------------------------------------------------------
local function lockPositionLayingDown(targetPos)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    if State.positionLockConn then
        State.positionLockConn:Disconnect()
        State.positionLockConn = nil
    end
    
    local angle = math.rad(QUEST_CONFIG.LAYING_ANGLE)
    local baseCFrame = CFrame.new(targetPos)
    local layingCFrame = baseCFrame * CFrame.Angles(angle, 0, 0)
    
    State.positionLockConn = RunService.Heartbeat:Connect(function()
        if not char or not char.Parent or not hrp or not hrp.Parent then
            if State.positionLockConn then
                State.positionLockConn:Disconnect()
                State.positionLockConn = nil
            end
            return
        end
        
        hrp.CFrame = layingCFrame
        hrp.Velocity = Vector3.zero
        hrp.AssemblyLinearVelocity = Vector3.zero
    end)
    
    print("   🔒 تم قفل الموقع")
end

local function transitionToNewTarget(newTargetPos)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    print(string.format("   🔄 انتقال سلس إلى الهدف الجديد..."))
    
    if State.positionLockConn then
        State.positionLockConn:Disconnect()
        State.positionLockConn = nil
    end
    
    local moveComplete = false
    smoothMoveTo(newTargetPos, function()
        lockPositionLayingDown(newTargetPos)
        moveComplete = true
    end)
    
    local timeout = 60
    local startTime = tick()
    while not moveComplete and tick() - startTime < timeout do
        task.wait(0.1)
    end
    
    if not moveComplete then
        warn("   ⚠️ انتهاء مهلة الانتقال!")
        return false
    end
    
    return true
end

local function unlockPosition()
    if State.positionLockConn then
        State.positionLockConn:Disconnect()
        State.positionLockConn = nil
        print("   🔓 تم فك قفل الموقع")
    end
end

----------------------------------------------------------------
-- تنفيذ التعدين الرئيسي
----------------------------------------------------------------
local function doMineUntilLevel10()
    print("⛏️ الهدف: التعدين حتى المستوى 10...")
    
    IsMiningActive = true
    
    print("\n" .. string.rep("=", 50))
    print("⛏️ بدء حلقة التعدين...")
    print(string.rep("=", 50))
    
    while Quest17Active and shouldMine() do
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        
        if not hrp then
            warn("   ⚠️ في انتظار الشخصية...")
            task.wait(2)
            continue
        end
        
        if not State.positionLockConn and not State.moveConn and not State.bodyVelocity then
            cleanupState()
        end
        
        -- 1. العثور على أقرب صخرة
        local targetRock, dist = findNearestBoulder(State.currentTarget)
        
        if not targetRock then
            warn("   ❌ لم يتم العثور على صخرة، في انتظار إعادة الظهور...")
            unlockPosition()
            cleanupState()
            task.wait(QUEST_CONFIG.RESPAWN_WAIT_TIME)
            continue
        end
        
        local previousTarget = State.currentTarget
        State.currentTarget = targetRock
        State.targetDestroyed = false
        
        -- 2. الحصول على موقع تحت الأرض
        local targetPos = getRockUndergroundPosition(targetRock)
        
        if not targetPos then
            warn("   ❌ لا يمكن الحصول على موقع الصخرة!")
            task.wait(1)
            continue
        end
        
        local currentHP = getRockHP(targetRock)
        local currentLevel = getPlayerLevel()
        
        print(string.format("\n🎯 الهدف: %s.%s (نقاط الصحة: %d, المسافة: %.1f, المستوى: %d)", 
            targetRock.Parent.Parent.Name,
            targetRock.Parent.Name,
            currentHP, 
            dist,
            currentLevel or 0))
        
        -- 3. مراقبة نقاط الصحة
        watchRockHP(targetRock)
        
        -- 4. الانتقال إلى الصخرة
        if State.positionLockConn and previousTarget ~= targetRock then
            print("   🔄 انتقال سلس من الهدف السابق...")
            transitionToNewTarget(targetPos)
        else
            local moveStarted = false
            smoothMoveTo(targetPos, function()
                lockPositionLayingDown(targetPos)
                moveStarted = true
            end)
            
            local timeout = 60
            local startTime = tick()
            while not moveStarted and tick() - startTime < timeout do
                task.wait(0.1)
            end
            
            if not moveStarted then
                warn("   ⚠️ انتهاء مهلة الحركة، تخطي هذه الصخرة")
                State.targetDestroyed = true
                unlockPosition()
                continue
            end
        end
        
        task.wait(0.5)
        
        -- 5. بدء التعدين
        while not State.targetDestroyed and Quest17Active and shouldMine() do
            if not char or not char.Parent then
                print("   ❌ ماتت الشخصية!")
                break
            end
            
            if not targetRock or not targetRock.Parent then
                print("   ✅ تم إزالة الهدف!")
                State.targetDestroyed = true
                break
            end
            
            if checkMiningError() then
                print("   ⚠️ شخص آخر يقوم بالتعدين! تغيير الهدف...")
                markRockAsOccupied(targetRock)
                State.targetDestroyed = true
                if ToolController then
                    ToolController.holdingM1 = false
                end
                break
            end
            
            local toolInHand = char:FindFirstChildWhichIsA("Tool")
            local isPickaxeHeld = toolInHand and string.find(toolInHand.Name, "Pickaxe")
            
            if not isPickaxeHeld then
                if ToolController then
                    ToolController.holdingM1 = false
                end
                
                local key = findPickaxeSlotKey()
                if key then
                    pressKey(key)
                    task.wait(0.3)
                else
                    pcall(function()
                        if PlayerController and PlayerController.Replica then
                            local replica = PlayerController.Replica
                            if replica.Data and replica.Data.Inventory and replica.Data.Inventory.Equipments then
                                for id, item in pairs(replica.Data.Inventory.Equipments) do
                                    if type(item) == "table" and item.Type and string.find(item.Type, "Pickaxe") then
                                        CHAR_RF:InvokeServer({Runes = {}}, item)
                                        break
                                    end
                                end
                            end
                        end
                    end)
                    task.wait(0.5)
                end
            else
                if ToolController and ToolActivatedFunc then
                    ToolController.holdingM1 = true
                    pcall(function()
                        ToolActivatedFunc(ToolController, toolInHand)
                    end)
                else
                    pcall(function()
                        TOOL_RF_BACKUP:InvokeServer(toolInHand.Name, true)
                    end)
                end
            end
            
            task.wait(0.15)
        end
        
        -- 6. بعد التعدين
        if QUEST_CONFIG.HOLD_POSITION_AFTER_MINE then
            print("   ⏸️  الثبات في الموقع، البحث عن الهدف التالي...")
        else
            unlockPosition()
        end
        
        local newLevel = getPlayerLevel()
        if newLevel and newLevel >= QUEST_CONFIG.TARGET_LEVEL then
            print(string.format("\n🎉 تم الوصول للمستوى %d! اكتمل التعدين!", newLevel))
            break
        end
        
        if DEBUG_MODE then
            print(string.format("   📊 المستوى الحالي: %d / %d", newLevel or 0, QUEST_CONFIG.TARGET_LEVEL))
        end
        
        task.wait(0.5)
    end
    
    print("\n" .. string.rep("=", 50))
    print("✅ انتهى التعدين")
    print(string.rep("=", 50))
    
    IsMiningActive = false
    unlockPosition()
    disableNoclip()
    cleanupState()
end

----------------------------------------------------------------
-- مشغل المهمة الذكي
----------------------------------------------------------------
print(string.rep("=", 50))
print("🚀 المهمة 17: " .. QUEST_CONFIG.QUEST_NAME)
print("🎯 الهدف: التعدين حتى المستوى 10")
print(string.format("✅ الاستراتيجية: تعدين سلس لجميع '%s' في workspace.Rocks", QUEST_CONFIG.ROCK_NAME))
print(string.rep("=", 50))

-- تحقق من المستوى أولاً
print("\n🔍 فحص مسبق: التحقق من متطلبات المستوى...")
if not shouldMine() then
    print("\n✅ بالفعل المستوى 10 أو أعلى!")
    print(string.rep("=", 50))
    cleanupState()
    disableNoclip()
    return
end

-- تحقق من وجود الصخور
print("\n🔍 فحص مسبق: البحث عن الصخور...")
local targetRock, dist = findNearestBoulder()

if not targetRock then
    warn("\n❌ لم يتم العثور على صخور في workspace.Rocks!")
    print(string.rep("=", 50))
    cleanupState()
    disableNoclip()
    return
end

print("   ✅ تم العثور على الصخور!")

-- بدء التعدين
doMineUntilLevel10()

task.wait(1)

local finalLevel = getPlayerLevel()

if finalLevel and finalLevel >= QUEST_CONFIG.TARGET_LEVEL then
    print("\n" .. string.rep("=", 50))
    print("✅ تم إكمال المهمة 17!")
    print(string.format("   🎉 المستوى النهائي: %d", finalLevel))
    print(string.rep("=", 50))
else
    warn("\n" .. string.rep("=", 50))
    warn("⚠️ المهمة 17 غير مكتملة")
    warn(string.format("   📊 المستوى الحالي: %d / %d", finalLevel or 0, QUEST_CONFIG.TARGET_LEVEL))
    warn(string.rep("=", 50))
end

Quest17Active = false
cleanupState()
disableNoclip()