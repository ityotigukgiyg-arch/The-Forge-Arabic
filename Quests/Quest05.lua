local Shared = _G.Shared

-- المهمة 5: "الفأس الجديد!" (نظام ذكي: قائم على الأولوية + مرن + تتبع ديناميكي للزومبي)
-- ترتيب الأولويات: 1) الشراء → 2) قتل الزومبي → 3) تعدين الصخور

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
local Quest5Active = true
local IsMiningActive = false
local IsKillingActive = false

local QUEST_CONFIG = {
    QUEST_NAME = "New Pickaxe!",
    PICKAXE_NAME = "Bronze Pickaxe",
    PICKAXE_AMOUNT = 1,
    NPC_POSITION = Vector3.new(-81.03, 28.51, 84.68),
    MINING_PATH = "Island1CaveMid",
    ROCK_NAME = "Rock",
    STARTING_POSITION = Vector3.new(50, -10, -200),
    UNDERGROUND_OFFSET = 4,
    ZOMBIE_UNDERGROUND_OFFSET = 5,
    ZOMBIE_MAX_DISTANCE = 50,
    LAYING_ANGLE = 90,
    MOVE_SPEED = 25,  
    
    -- 🔥 جديد: ترتيب الأولويات
    PRIORITY_ORDER = {
        "Purchase",   -- 1. شراء الفأس أولاً
        "Kill",       -- 2. قتل الزومبي
        "Mine",       -- 3. تعدين الصخور (أخيراً)
    }
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
local ProximityService = nil

pcall(function()
    CharacterService = Knit.GetService("CharacterService")
    PlayerController = Knit.GetController("PlayerController")
    ProximityService = Knit.GetService("ProximityService")
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
local PURCHASE_RF = SERVICES:WaitForChild("ProximityService"):WaitForChild("RF"):WaitForChild("Purchase")
local CHAR_RF = SERVICES:WaitForChild("CharacterService"):WaitForChild("RF"):WaitForChild("EquipItem")
local TOOL_RF_BACKUP = SERVICES:WaitForChild("ToolService"):WaitForChild("RF"):WaitForChild("ToolActivated")

local MINING_FOLDER_PATH = Workspace:WaitForChild("Rocks")
local LIVING_FOLDER = Workspace:WaitForChild("Living")

if CharacterService then print("✅ خدمة الشخصية جاهزة!") else warn("⚠️ خدمة الشخصية غير موجودة") end
if PlayerController then print("✅ وحدة تحكم اللاعب جاهزة!") else warn("⚠️ وحدة تحكم اللاعب غير موجودة") end
if ProximityService then print("✅ خدمة القرب جاهزة!") else warn("⚠️ خدمة القرب غير موجودة") end
if ToolController then print("✅ وحدة تحكم الأدوات جاهزة!") else warn("⚠️ وحدة تحكم الأدوات غير موجودة") end
if PURCHASE_RF then print("✅ ريموت الشراء جاهز!") else warn("⚠️ ريموت الشراء غير موجود") end

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
    currentObjectiveFrame = nil,
}

local function cleanupState()
    if State.hpWatchConn then State.hpWatchConn:Disconnect() State.hpWatchConn = nil end
    if State.noclipConn then State.noclipConn:Disconnect() State.noclipConn = nil end
    if State.moveConn then State.moveConn:Disconnect() State.moveConn = nil end
    if State.positionLockConn then State.positionLockConn:Disconnect() State.positionLockConn = nil end
    if State.bodyVelocity then State.bodyVelocity:Destroy() State.bodyVelocity = nil end
    if State.bodyGyro then State.bodyGyro:Destroy() State.bodyGyro = nil end
    State.currentTarget = nil
    State.targetDestroyed = false
    if ToolController then ToolController.holdingM1 = false end
end

----------------------------------------------------------------
-- معالج إعادة الظهور
----------------------------------------------------------------
local function setupRespawnHandler()
    player.CharacterAdded:Connect(function(character)
        print("💀 تم إعادة ظهور الشخصية!")
        
        local hrp = character:WaitForChild("HumanoidRootPart", 5)
        if not hrp then return end
        
        task.wait(1)
        
        if (IsMiningActive or IsKillingActive) and Quest5Active then
            print("🔄 العودة إلى العمل بعد إعادة الظهور...")
            task.wait(2)
        end
    end)
end

----------------------------------------------------------------
-- نظام المهمة
----------------------------------------------------------------
local function getQuestObjectives(questName)
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return nil, nil end
    
    local list = gui:FindFirstChild("Main") and gui.Main:FindFirstChild("Screen") 
                 and gui.Main.Screen:FindFirstChild("Quests") and gui.Main.Screen.Quests:FindFirstChild("List")
    if not list then return nil, nil end
    
    local questID = nil
    for _, child in ipairs(list:GetChildren()) do
        local id = string.match(child.Name, "^Introduction(%d+)Title$")
        if id and child:FindFirstChild("Frame") and child.Frame:FindFirstChild("TextLabel") then
            if child.Frame.TextLabel.Text == questName then
                questID = id
                break
            end
        end
    end
    
    if not questID then return nil, nil end
    
    local objList = list:FindFirstChild("Introduction" .. questID .. "List")
    return questID, objList
end

local function isObjectiveComplete(item)
    if not item then return false end
    local check = item:FindFirstChild("Main") and item.Main:FindFirstChild("Frame") and item.Main.Frame:FindFirstChild("Check")
    return check and check.Visible
end

local function getObjectiveText(item)
    local lbl = item:FindFirstChild("Main") and item.Main:FindFirstChild("TextLabel")
    return lbl and lbl.Text or ""
end

local function isQuest5StillActive()
    if not Quest5Active then return false end
    
    local questID, objList = getQuestObjectives(QUEST_CONFIG.QUEST_NAME)
    if not questID or not objList then
        print("🛑 المهمة '" .. QUEST_CONFIG.QUEST_NAME .. "' غير موجودة!")
        Quest5Active = false
        return false
    end
    
    return true
end

local function isCurrentObjectiveComplete()
    if State.currentObjectiveFrame then
        return isObjectiveComplete(State.currentObjectiveFrame)
    end
    return false
end

-- 🔥 جديد: تصنيف نوع الهدف
local function getObjectiveType(text)
    if string.find(text, "Purchase") or string.find(text, "Buy") or string.find(text, "Pickaxe") then
        return "Purchase"
    elseif string.find(text, "Kill") or string.find(text, "Zombie") or string.find(text, "Defeat") then
        return "Kill"
    elseif string.find(text, "Get Ore") or string.find(text, "Mine") or string.find(text, "Rock") then
        return "Mine"
    else
        return "Unknown"
    end
end

-- 🔥 جديد: تحقق إذا كان يمكن تنفيذ الهدف الآن (المهمة 5 لا تعتمد على مهام أخرى)
local function canDoObjective(objType)
    -- المهمة 5 لا تحتوي على تبعيات مثل المهمة 7 (الحدادة تحتاج خام)
    -- يمكن تنفيذ كل هدف مباشرة
    return true
end

----------------------------------------------------------------
-- دوال مساعدة
----------------------------------------------------------------
local HOTKEY_MAP = {
    ["1"] = Enum.KeyCode.One, ["2"] = Enum.KeyCode.Two, ["3"] = Enum.KeyCode.Three,
    ["4"] = Enum.KeyCode.Four, ["5"] = Enum.KeyCode.Five, ["6"] = Enum.KeyCode.Six,
    ["7"] = Enum.KeyCode.Seven, ["8"] = Enum.KeyCode.Eight, ["9"] = Enum.KeyCode.Nine, ["0"] = Enum.KeyCode.Zero
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
    local hotbar = gui:FindFirstChild("BackpackGui") and gui.BackpackGui:FindFirstChild("Backpack") and gui.BackpackGui.Backpack:FindFirstChild("Hotbar")
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

local function findWeaponSlotKey()
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return nil end
    local hotbar = gui:FindFirstChild("BackpackGui") and gui.BackpackGui:FindFirstChild("Backpack") and gui.BackpackGui.Backpack:FindFirstChild("Hotbar")
    if hotbar then
        for _, slotFrame in ipairs(hotbar:GetChildren()) do
            local frame = slotFrame:FindFirstChild("Frame")
            local label = frame and frame:FindFirstChild("ToolName")
            if label and label:IsA("TextLabel") and not string.find(label.Text, "Pickaxe") and label.Text ~= "" then
                return HOTKEY_MAP[slotFrame.Name], label.Text
            end
        end
    end
    return nil, nil
end

local function checkMiningError()
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return false end
    local notif = gui:FindFirstChild("Notifications")
    if notif and notif:FindFirstChild("Screen") and notif.Screen:FindFirstChild("NotificationsFrame") then
        for _, child in ipairs(notif.Screen.NotificationsFrame:GetChildren()) do
            local lbl = child:FindFirstChild("TextLabel", true)
            if lbl and string.find(lbl.Text, "Someone else is already mining") then return true end
        end
    end
    return false
end

local function getRockUndergroundPosition(rockModel)
    if not rockModel or not rockModel.Parent then return nil end
    
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

local function getZombieUndergroundPosition(zombieModel)
    if not zombieModel or not zombieModel.Parent then return nil end
    
    local hrp = zombieModel:FindFirstChild("HumanoidRootPart")
    if hrp then
        local pos = hrp.Position
        return Vector3.new(pos.X, pos.Y - QUEST_CONFIG.ZOMBIE_UNDERGROUND_OFFSET, pos.Z)
    end
    
    return nil
end

----------------------------------------------------------------
-- فاحص نقاط الصحة
----------------------------------------------------------------
local function getRockHP(rock)
    if not rock or not rock.Parent then return 0 end
    
    local success, result = pcall(function()
        return rock:GetAttribute("Health") or 0
    end)
    
    return success and result or 0
end

local function isTargetValid(rock)
    if not rock or not rock.Parent then return false end
    if not rock:FindFirstChildWhichIsA("BasePart") then return false end
    
    local hp = getRockHP(rock)
    return hp > 0
end

local function getZombieHP(zombie)
    if not zombie or not zombie.Parent then return 0 end
    local humanoid = zombie:FindFirstChild("Humanoid")
    if humanoid then return humanoid.Health or 0 end
    return 0
end

local function isZombieValid(zombie)
    if not zombie or not zombie.Parent then return false end
    return getZombieHP(zombie) > 0
end

----------------------------------------------------------------
-- الباحث عن الأهداف
----------------------------------------------------------------
local function findNearestRock()
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    
    local targetRock, minDist = nil, math.huge
    
    for _, folder in ipairs(MINING_FOLDER_PATH:GetChildren()) do
        if folder:IsA("Folder") or folder:IsA("Model") then
            for _, child in ipairs(folder:GetChildren()) do
                if child:IsA("SpawnLocation") or child.Name == "SpawnLocation" then
                    local rock = child:FindFirstChild(QUEST_CONFIG.ROCK_NAME)
                    if isTargetValid(rock) then
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
    
    return targetRock, minDist
end

local function findNearestZombie()
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    
    local targetZombie, minDist = nil, math.huge
    
    for _, child in ipairs(LIVING_FOLDER:GetChildren()) do
        if string.match(child.Name, "^Zombie%d+$") then
            if isZombieValid(child) then
                local pos = getZombieUndergroundPosition(child)
                if pos then
                    local dist = (pos - hrp.Position).Magnitude
                    if dist < minDist then
                        minDist = dist
                        targetZombie = child
                    end
                end
            end
        end
    end
    
    return targetZombie, minDist
end

----------------------------------------------------------------
-- تعطيل التصادم (noclip)
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
    -- ✅ تم إيقاف noclip واستعادة التصادم للشخصية
    Shared.restoreCollisions()
end

----------------------------------------------------------------
-- حركة سلسة باستخدام BodyVelocity
----------------------------------------------------------------
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
    
    print(string.format("   🚀 التحرك إلى (%.1f, %.1f, %.1f)...", targetPos.X, targetPos.Y, targetPos.Z))
    
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
-- قفل الموقع
----------------------------------------------------------------
local function lockPositionLayingDown(targetPos)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    if State.positionLockConn then State.positionLockConn:Disconnect() State.positionLockConn = nil end
    
    local angle = math.rad(QUEST_CONFIG.LAYING_ANGLE)
    local baseCFrame = CFrame.new(targetPos)
    local layingCFrame = baseCFrame * CFrame.Angles(angle, 0, 0)
    
    State.positionLockConn = RunService.Heartbeat:Connect(function()
        if not char or not char.Parent or not hrp or not hrp.Parent then
            if State.positionLockConn then State.positionLockConn:Disconnect() State.positionLockConn = nil end
            return
        end
        
        hrp.CFrame = layingCFrame
        hrp.Velocity = Vector3.zero
        hrp.AssemblyLinearVelocity = Vector3.zero
    end)
    
    print("   🛏️ تم قفل الموقع (وضع الاستلقاء)")
end

local function lockPositionFollowTarget(targetModel)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp or not targetModel then return end
    
    if State.positionLockConn then State.positionLockConn:Disconnect() State.positionLockConn = nil end
    
    local angle = math.rad(QUEST_CONFIG.LAYING_ANGLE)
    
    State.positionLockConn = RunService.Heartbeat:Connect(function()
        if not char or not char.Parent or not hrp or not hrp.Parent then
            if State.positionLockConn then State.positionLockConn:Disconnect() State.positionLockConn = nil end
            return
        end
        
        if not targetModel or not targetModel.Parent then
            if State.positionLockConn then State.positionLockConn:Disconnect() State.positionLockConn = nil end
            return
        end
        
        local targetPos = getZombieUndergroundPosition(targetModel)
        if targetPos then
            local baseCFrame = CFrame.new(targetPos)
            local layingCFrame = baseCFrame * CFrame.Angles(angle, 0, 0)
            
            hrp.CFrame = layingCFrame
            hrp.Velocity = Vector3.zero
            hrp.AssemblyLinearVelocity = Vector3.zero
        end
    end)
    
    print("   🎯 تم قفل الموقع (متابعة الهدف)")
end

local function unlockPosition()
    Shared.SoftUnlockPosition()
end

----------------------------------------------------------------
-- مراقبة نقاط الصحة
----------------------------------------------------------------
local function watchRockHP(rock)
    if State.hpWatchConn then State.hpWatchConn:Disconnect() end
    if not rock then return end
    
    State.hpWatchConn = rock:GetAttributeChangedSignal("Health"):Connect(function()
        local hp = rock:GetAttribute("Health") or 0
        print(string.format("   ⚡ [تم تغيير نقاط الصحة!] نقاط الصحة الجديدة: %d", hp))
        
        if hp <= 0 then
            print("   💥 تم الكشف عن نقاط صحة = 0! تغيير الهدف...")
            State.targetDestroyed = true
            if ToolController then ToolController.holdingM1 = false end
            unlockPosition()
        end
    end)
end

local function watchZombieHP(zombie)
    if State.hpWatchConn then State.hpWatchConn:Disconnect() end
    if not zombie then return end
    
    local humanoid = zombie:FindFirstChild("Humanoid")
    if not humanoid then return end
    
    State.hpWatchConn = humanoid:GetPropertyChangedSignal("Health"):Connect(function()
        local hp = humanoid.Health or 0
        print(string.format("   ⚡ [تم تغيير نقاط الصحة!] نقاط الصحة الجديدة: %.1f", hp))
        
        if hp <= 0 then
            print("   💀 مات الزومبي! تغيير الهدف...")
            State.targetDestroyed = true
            if ToolController then ToolController.holdingM1 = false end
            unlockPosition()
        end
    end)
end

----------------------------------------------------------------
-- إدارة الأسلحة
----------------------------------------------------------------
local function getBestWeapon()
    if not PlayerController or not PlayerController.Replica then return nil end
    
    local replica = PlayerController.Replica
    if not replica.Data or not replica.Data.Inventory or not replica.Data.Inventory.Equipments then
        return nil
    end
    
    local equipments = replica.Data.Inventory.Equipments
    local bestWeapon = nil
    local highestDmg = 0
    
    for id, item in pairs(equipments) do
        if type(item) == "table" and item.Type then
            if not string.find(item.Type, "Pickaxe") then
                local dmg = item.Dmg or 0
                if dmg > highestDmg then
                    highestDmg = dmg
                    bestWeapon = item
                end
            end
        end
    end
    
    return bestWeapon
end

----------------------------------------------------------------
-- الإجراءات
----------------------------------------------------------------
local function doPurchaseBronzePickaxe()
    print("🛒 الهدف: شراء فأس برونزي...")
    
    if not PURCHASE_RF then
        warn("   ❌ ريموت الشراء غير متوفر!")
        return false
    end
    
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    
    if hrp then
        local npcPos = QUEST_CONFIG.NPC_POSITION
        local currentDist = (npcPos - hrp.Position).Magnitude
        
        print(string.format("   🚶 التحرك إلى NPC عند (%.2f, %.2f, %.2f) (على بعد %.1f وحدات)...", 
            npcPos.X, npcPos.Y, npcPos.Z, currentDist))
        
        local moveComplete = false
        smoothMoveTo(npcPos, function()
            moveComplete = true
        end)
        
        local timeout = 60
        local startTime = tick()
        while not moveComplete and tick() - startTime < timeout do
            task.wait(0.1)
        end
        
        if State.moveConn then State.moveConn:Disconnect() State.moveConn = nil end
        if State.bodyVelocity then State.bodyVelocity:Destroy() State.bodyVelocity = nil end
        if State.bodyGyro then State.bodyGyro:Destroy() State.bodyGyro = nil end
        
        print("   ✅ تم الوصول إلى NPC!")
        print("   ⏸️  الانتظار 1.5 ثانية قبل الشراء...")
        task.wait(1.5)
    end
    
    print(string.format("   💰 الشراء: %s (الكمية: %d)", QUEST_CONFIG.PICKAXE_NAME, QUEST_CONFIG.PICKAXE_AMOUNT))
    
    local args = {
        QUEST_CONFIG.PICKAXE_NAME,
        QUEST_CONFIG.PICKAXE_AMOUNT
    }
    
    local success, result = pcall(function()
        return PURCHASE_RF:InvokeServer(unpack(args))
    end)
    
    if success then
        print("   ✅ تم الشراء بنجاح!")
        return true
    else
        warn("   ❌ فشل الشراء: " .. tostring(result))
        return false
    end
end

local function doMineRocks()
    print("⛏️ الهدف: تعدين الصخور...")
    
    IsMiningActive = true
    
    print("\n" .. string.rep("-", 30))
    print("⛏️ بدء حلقة التعدين تحت الأرض...")
    print(string.rep("-", 30))
    
    while isQuest5StillActive() and not isCurrentObjectiveComplete() do
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        
        if not hrp then
            warn("   ⚠️ في انتظار الشخصية...")
            task.wait(2)
            continue
        end
        
        cleanupState()
        
        local targetRock, dist = findNearestRock()
        
        if not targetRock then
            warn("   ❌ لم يتم العثور على صخور، في انتظار...")
            task.wait(2)
            continue
        end
        
        State.currentTarget = targetRock
        State.targetDestroyed = false
        
        local targetPos = getRockUndergroundPosition(targetRock)
        if not targetPos then
            warn("   ❌ لا يمكن الحصول على موقع الصخرة!")
            task.wait(1)
            continue
        end
        
        local currentHP = getRockHP(targetRock)
        print(string.format("   🎯 الهدف: %s (المسافة: %d، نقاط الصحة: %d)", 
            targetRock.Parent.Name, math.floor(dist), currentHP))
        
        watchRockHP(targetRock)
        
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
            warn("   ⚠️ انتهاء مهلة الحركة، تخطي هذه الصخرة لتجنب التليبورتيشن")
            State.targetDestroyed = true
            unlockPosition()
            -- لا حاجة لقفل الموقع هنا
            continue
        end
        
        task.wait(0.5)
        
        while not State.targetDestroyed and isQuest5StillActive() and not isCurrentObjectiveComplete() do
            if not char or not char.Parent then
                print("   💀 ماتت الشخصية!")
                break
            end
            
            if not targetRock or not targetRock.Parent then
                print("   💥 تم إزالة الهدف!")
                State.targetDestroyed = true
                break
            end
            
            if checkMiningError() then
                print("   ⚠️ شخص آخر يقوم بالتعدين!")
                State.targetDestroyed = true
                if ToolController then ToolController.holdingM1 = false end
                break
            end
            
            local toolInHand = char:FindFirstChildWhichIsA("Tool")
            local isPickaxeHeld = toolInHand and string.find(toolInHand.Name, "Pickaxe")
            
            if not isPickaxeHeld then
                if ToolController then ToolController.holdingM1 = false end
                local key = findPickaxeSlotKey()
                if key then 
                    pressKey(key) 
                    task.wait(0.3)
                else 
                    pcall(function() CHAR_RF:InvokeServer({Runes = {}, Name = QUEST_CONFIG.PICKAXE_NAME}) end)
                    task.wait(0.5) 
                end
            else
                if ToolController and ToolActivatedFunc then
                    ToolController.holdingM1 = true
                    pcall(function() ToolActivatedFunc(ToolController, toolInHand) end)
                else
                    pcall(function() TOOL_RF_BACKUP:InvokeServer(toolInHand.Name, true) end)
                end
            end
            
            task.wait(0.15)
        end
        
        --unlockPosition()
        
        if isCurrentObjectiveComplete() then
            print("✅ الهدف (تعدين الصخور) مكتمل!")
            break
        end
        
        print("   🔄 البحث عن الهدف التالي...")
        task.wait(0.5)
    end
    
    print("\n🛑 انتهى التعدين")
    IsMiningActive = false
    unlockPosition()
    disableNoclip()
    cleanupState()
end

local function doKillZombies()
    print("⚔️ الهدف: قتل الزومبي (تتبع ديناميكي)...")
    
    IsKillingActive = true
    
    print("\n" .. string.rep("-", 30))
    print("⚔️ بدء صيد الزومبي مع تتبع ديناميكي...")
    print(string.rep("-", 30))
    
    while isQuest5StillActive() and not isCurrentObjectiveComplete() do
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        
        if not hrp then
            warn("   ⚠️ في انتظار الشخصية...")
            task.wait(2)
            continue
        end
        
        cleanupState()
        
        local targetZombie, dist = findNearestZombie()
        
        if not targetZombie then
            warn("   ❌ لم يتم العثور على زومبي، في انتظار...")
            task.wait(2)
            continue
        end
        
        State.currentTarget = targetZombie
        State.targetDestroyed = false
        
        local targetPos = getZombieUndergroundPosition(targetZombie)
        if not targetPos then
            warn("   ❌ لا يمكن الحصول على موقع الزومبي!")
            task.wait(1)
            continue
        end
        
        local currentHP = getZombieHP(targetZombie)
        print(string.format("   🎯 الهدف: %s (المسافة: %d، نقاط الصحة: %.1f)", 
            targetZombie.Name, math.floor(dist), currentHP))
        
        watchZombieHP(targetZombie)
        
        local moveStarted = false
        smoothMoveTo(targetPos, function()
            lockPositionFollowTarget(targetZombie)
            moveStarted = true
        end)
        
        local timeout = 60
        local startTime = tick()
        while not moveStarted and tick() - startTime < timeout do
            task.wait(0.1)
        end
        
        -- ❌ لا تقم بقفل الموقع بقوة إذا لم تصل للهدف أبداً
        if not moveStarted then
            warn("   ⚠️ انتهاء مهلة الحركة، تخطي هذا الزومبي لتجنب التليبورتيشن")
            State.targetDestroyed = true
            unlockPosition()
            continue
        end
        
        task.wait(0.5)
        
        while not State.targetDestroyed and isQuest5StillActive() and not isCurrentObjectiveComplete() do
            if not char or not char.Parent then
                print("   💀 ماتت الشخصية!")
                break
            end
            
            if not targetZombie or not targetZombie.Parent or not isZombieValid(targetZombie) then
                print("   💀 مات الزومبي أو تم إزالته!")
                State.targetDestroyed = true
                unlockPosition() 
                break
            end
            
            local currentZombiePos = getZombieUndergroundPosition(targetZombie)
            if currentZombiePos and hrp then
                local distToZombie = (currentZombiePos - hrp.Position).Magnitude
                if distToZombie > QUEST_CONFIG.ZOMBIE_MAX_DISTANCE then
                    print(string.format("   ⚠️ الزومبي ابتعد كثيراً! (%.1f وحدات) تغيير الهدف...", distToZombie))
                    State.targetDestroyed = true
                    unlockPosition()
                    break
                end
            end
            
            local toolInHand = char:FindFirstChildWhichIsA("Tool")
            local isWeaponHeld = toolInHand and not string.find(toolInHand.Name, "Pickaxe")
            
            if not isWeaponHeld then
                if ToolController then ToolController.holdingM1 = false end
                
                local bestWeapon = getBestWeapon()
                if bestWeapon then
                    print(string.format("   🗡️ تجهيز السلاح: %s", bestWeapon.Type))
                    pcall(function() 
                        CharacterService:EquipItem(bestWeapon)
                    end)
                    task.wait(0.5)
                else
                    local key, weaponName = findWeaponSlotKey()
                    if key then
                        print(string.format("   🗡️ تجهيز عبر المفتاح السريع: %s", weaponName))
                        pressKey(key)
                        task.wait(0.3)
                    else
                        warn("   ⚠️ لم يتم العثور على سلاح!")
                        task.wait(1)
                    end
                end
            else
                if ToolController and ToolActivatedFunc then
                    ToolController.holdingM1 = true
                    pcall(function() ToolActivatedFunc(ToolController, toolInHand) end)
                else
                    pcall(function() TOOL_RF_BACKUP:InvokeServer(toolInHand.Name, true) end)
                end
            end
            
            task.wait(0.15)
        end
        
        --unlockPosition()
        
        if isCurrentObjectiveComplete() then
            print("✅ الهدف (قتل الزومبي) مكتمل!")
            break
        end
        
        print("   🔄 البحث عن الهدف التالي...")
        task.wait(0.5)
    end
    
    print("\n🛑 انتهى صيد الزومبي")
    IsKillingActive = false
    unlockPosition()
    disableNoclip()
    cleanupState()
end

----------------------------------------------------------------
-- 🔥 مشغل المهمة الذكي (قائم على الأولوية + مرن)
----------------------------------------------------------------
print(string.rep("=", 50))
print("🚀 المهمة 5: " .. QUEST_CONFIG.QUEST_NAME)
print("🎯 النظام الذكي: قائم على الأولوية + مرن")
print("📋 ترتيب الأولويات: الشراء → القتل → التعدين")
print(string.rep("=", 50))

setupRespawnHandler()

local questID, objList = getQuestObjectives(QUEST_CONFIG.QUEST_NAME)

if not questID then
    warn("❌ المهمة '" .. QUEST_CONFIG.QUEST_NAME .. "' غير موجودة!")
    Quest5Active = false
    return
end

print("✅ تم العثور على المهمة (المعرف: " .. questID .. ")")

-- جمع كل الأهداف
local objectives = {}
for _, item in ipairs(objList:GetChildren()) do
    if item:IsA("Frame") and tonumber(item.Name) then
        local text = getObjectiveText(item)
        local objType = getObjectiveType(text)
        
        table.insert(objectives, {
            order = tonumber(item.Name),
            frame = item,
            text = text,
            type = objType
        })
    end
end

-- 🔥 ترتيب حسب الأولوية بدلاً من الترتيب الأصلي
table.sort(objectives, function(a, b)
    local function getPriority(type)
        for i, priorityType in ipairs(QUEST_CONFIG.PRIORITY_ORDER) do
            if string.find(type, priorityType) then
                return i
            end
        end
        return 999
    end
    return getPriority(a.type) < getPriority(b.type)
end)

print("\n" .. string.rep("=", 50))
print("⚙️  أهداف المهمة (حسب ترتيب الأولوية):")
for i, obj in ipairs(objectives) do
    local complete = isObjectiveComplete(obj.frame)
    print(string.format("   %d. [%s] %s [%s]", i, obj.type, obj.text, complete and "✅" or "⏳"))
end
print(string.rep("=", 50))

local function hasIncompletePurchase()
    for _, obj in ipairs(objectives) do
        if obj.type == "Purchase" and not isObjectiveComplete(obj.frame) then
            return true
        end
    end
    return false
end

-- 🔥 الحلقة الرئيسية: معالجة الأهداف حسب الأولوية
local maxAttempts = 10
local attempt = 0

while isQuest5StillActive() and attempt < maxAttempts do
    attempt = attempt + 1
    print(string.format("\n🔄 دورة المهمة #%d", attempt))
    
    local allComplete = true
    local didSomething = false
    local purchasePending = hasIncompletePurchase()
    
    for _, obj in ipairs(objectives) do
        if not isQuest5StillActive() then
            print("🛑 اختفت المهمة!")
            break
        end
        
        local complete = isObjectiveComplete(obj.frame)
        
        if not complete then
            allComplete = false

            -- ⛔ إذا كان هناك شراء غير مكتمل → لا تنفذ أهداف أخرى
            if purchasePending and obj.type ~= "Purchase" then
                print(string.format("   ⏭️  تخطي [%s] (في انتظار إتمام الشراء)", obj.type))
                continue
            end
            
            -- 🔥 تحقق إذا يمكن تنفيذ هذا الهدف الآن
            if not canDoObjective(obj.type) then
                print(string.format("   ⏭️  تخطي [%s] - لا يمكن التنفيذ الآن", obj.type))
                continue
            end
            
            State.currentObjectiveFrame = obj.frame
            
            print(string.format("\n📋 معالجة [%s]: %s", obj.type, obj.text))
            
            -- تنفيذ الهدف
            if obj.type == "Purchase" then
                doPurchaseBronzePickaxe()
                didSomething = true
                task.wait(2)
                
                -- 🆕 إعادة التحقق إذا اكتمل الشراء بعد التنفيذ
                if isObjectiveComplete(obj.frame) then
                    purchasePending = false
                    print("   ✅ تم إكمال هدف الشراء! متابعة الأهداف الأخرى...")
                end
                
            elseif obj.type == "Kill" then
                doKillZombies()
                didSomething = true
                task.wait(1)
                
            elseif obj.type == "Mine" then
                doMineRocks()
                didSomething = true
                task.wait(1)
                
            else
                warn("   ⚠️ نوع هدف غير معروف: " .. obj.type)
            end
            
            -- التحقق من الإكمال
            task.wait(1)
            if isObjectiveComplete(obj.frame) then
                print(string.format("✅ [%s] مكتمل!", obj.type))
            else
                print(string.format("⏳ [%s] لا يزال قيد التنفيذ", obj.type))
            end
        end
    end
    
    if allComplete then
        print("\n🎉 تم إكمال جميع الأهداف!")
        break
    end
    
    if not didSomething then
        warn("\n⚠️ لا يمكن إكمال أي هدف في هذه الدورة!")
        print("   الانتظار 3 ثوانٍ قبل المحاولة مجدداً...")
        task.wait(3)
    end
end

-- التحقق النهائي
task.wait(2)

local allComplete = true
for _, obj in ipairs(objectives) do
    if not isObjectiveComplete(obj.frame) then
        allComplete = false
        warn(string.format("   ⚠️ [%s] غير مكتمل: %s", obj.type, obj.text))
    end
end

if allComplete then
    print("\n" .. string.rep("=", 50))
    print("✅ تم إكمال المهمة 5!")
    print(string.rep("=", 50))
else
    warn("\n" .. string.rep("=", 50))
    warn("⚠️ المهمة 5 غير مكتملة بعد " .. attempt .. " دورات")
    warn(string.rep("=", 50))
end

Quest5Active = false
IsMiningActive = false
IsKillingActive = false
unlockPosition()
disableNoclip()
cleanupState()