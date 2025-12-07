local Shared = _G.Shared

-- المهمة 16: الشراء التلقائي للفأس (معتمد على الذهب)
-- ✅ التحقق من الذهب > 3340
-- ✅ الانتقال إلى المتجر (-32.6, -2.0, -269.3)
-- ✅ شراء "فأس ستونويك" ×1
-- ✅ الشراء التلقائي

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

----------------------------------------------------------------
-- الإعدادات
----------------------------------------------------------------
local Quest16Active = true
local DEBUG_MODE = true

local QUEST_CONFIG = {
    QUEST_NAME = "الشراء التلقائي للفأس",
    MIN_GOLD = 3340,  -- يجب أن يكون الذهب >= 3340
    
    -- موقع المتجر
    SHOP_POSITION = Vector3.new(-32.6, -2.0, -269.3),
    
    -- عنصر الشراء
    ITEM_NAME = "فأس ستونويك",
    ITEM_QUANTITY = 1,
    
    MOVE_SPEED = 25,  
    STOP_DISTANCE = 5,
}

----------------------------------------------------------------
-- إعداد KNIT
----------------------------------------------------------------
local KnitPackage = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Knit")
local Knit = require(KnitPackage)

if not Knit.OnStart then 
    pcall(function() Knit.Start():await() end)
end

local PlayerController = nil
local ProximityService = nil

pcall(function()
    PlayerController = Knit.GetController("PlayerController")
    ProximityService = Knit.GetService("ProximityService")
end)

local SERVICES = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Services")

local PURCHASE_RF = nil
pcall(function()
    PURCHASE_RF = SERVICES:WaitForChild("ProximityService", 5):WaitForChild("RF", 3):WaitForChild("Purchase", 3)
end)

if PlayerController then print("✅ تحكم اللاعب جاهز!") else warn("⚠️ لم يتم العثور على تحكم اللاعب") end
if ProximityService then print("✅ خدمة القرب جاهزة!") else warn("⚠️ لم يتم العثور على خدمة القرب") end
if PURCHASE_RF then print("✅ التحكم البعيد للشراء جاهز!") else warn("⚠️ لم يتم العثور على التحكم البعيد للشراء") end

----------------------------------------------------------------
-- إدارة الحالة
----------------------------------------------------------------
local State = {
    noclipConn = nil,
    moveConn = nil,
    bodyVelocity = nil,
    bodyGyro = nil,
}

local function cleanupState()
    if State.noclipConn then State.noclipConn:Disconnect() State.noclipConn = nil end
    if State.moveConn then State.moveConn:Disconnect() State.moveConn = nil end
    if State.bodyVelocity then State.bodyVelocity:Destroy() State.bodyVelocity = nil end
    if State.bodyGyro then State.bodyGyro:Destroy() State.bodyGyro = nil end
end

----------------------------------------------------------------
-- نظام المستوى
----------------------------------------------------------------
local function getPlayerLevel()
    print("   🔍 التحقق من مستوى اللاعب...")

    -- المسار: PlayerGui.Main.Screen.Hud.Level
    local levelLabel = playerGui:FindFirstChild("Main")
                    and playerGui.Main:FindFirstChild("Screen")
                    and playerGui.Main.Screen:FindFirstChild("Hud")
                    and playerGui.Main.Screen.Hud:FindFirstChild("Level")

    if not levelLabel then
        warn("   ❌ لم يتم العثور على تسمية المستوى!")
        return nil
    end

    if not levelLabel:IsA("TextLabel") then
        warn("   ❌ المستوى ليس تسمية نصية!")
        return nil
    end

    local levelText = levelLabel.Text
    local level = tonumber(string.match(levelText, "%d+"))
    
    if level then
        print(string.format("   ✅ مستوى اللاعب: %d", level))
        return level
    else
        warn("   ❌ فشل في استخراج المستوى من النص!")
        return nil
    end
end

----------------------------------------------------------------
-- نظام الذهب
----------------------------------------------------------------
local function getPlayerGold()
    print("   🔍 التحقق من ذهب اللاعب...")
    
    -- المسار: PlayerGui.Main.Screen.Hud.Gold
    local goldLabel = playerGui:FindFirstChild("Main")
                     and playerGui.Main:FindFirstChild("Screen")
                     and playerGui.Main.Screen:FindFirstChild("Hud")
                     and playerGui.Main.Screen.Hud:FindFirstChild("Gold")
    
    if not goldLabel then
        warn("   ❌ لم يتم العثور على تسمية الذهب!")
        return nil
    end
    
    if not goldLabel:IsA("TextLabel") then
        warn("   ❌ الذهب ليس تسمية نصية!")
        return nil
    end
    
    local goldText = goldLabel.Text
    
    -- استخراج الذهب من النص (مثلاً "$3,722.72" → 3722.72)
    local goldString = string.gsub(goldText, "[$,]", "")
    local gold = tonumber(goldString)
    
    if gold then
        print(string.format("   ✅ ذهب اللاعب: $%.2f", gold))
        return gold
    else
        warn("   ❌ فشل في استخراج الذهب من النص!")
        return nil
    end
end

local function hasEnoughGold()
    local gold = getPlayerGold()
    
    if not gold then
        warn("   ❌ لا يمكن تحديد ذهب اللاعب!")
        return false
    end
    
    if gold >= QUEST_CONFIG.MIN_GOLD then
        print(string.format("   ✅ الذهب $%.2f >= $%d - يمكن الشراء!", gold, QUEST_CONFIG.MIN_GOLD))
        return true
    else
        print(string.format("   ⏸️  الذهب $%.2f < $%d - لا يوجد ذهب كافٍ", gold, QUEST_CONFIG.MIN_GOLD))
        return false
    end
end

----------------------------------------------------------------
-- خاصية عدم التصادم والحركة
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
        
        if distance < QUEST_CONFIG.STOP_DISTANCE then
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
-- نظام الشراء
----------------------------------------------------------------
local function purchaseItem(itemName, quantity)
    if not PURCHASE_RF then
        warn("   ❌ التحكم البعيد للشراء غير متوفر!")
        return false
    end
    
    print(string.format("   🛒 جاري الشراء: %s ×%d", itemName, quantity))
    
    local success, result = pcall(function()
        return PURCHASE_RF:InvokeServer(itemName, quantity)
    end)
    
    if success then
        print(string.format("   ✅ تم الشراء: %s ×%d", itemName, quantity))
        return true
    else
        warn(string.format("   ❌ فشل في شراء %s: %s", itemName, tostring(result)))
        return false
    end
end

----------------------------------------------------------------
-- التحقق من المخزون
----------------------------------------------------------------
local function hasPickaxe(pickaxeName)
    if not PlayerController or not PlayerController.Replica then
        warn("   ❌ تحكم اللاعب/النسخة غير متوفر!")
        return false
    end
    
    local replica = PlayerController.Replica
    if not replica.Data or not replica.Data.Inventory or not replica.Data.Inventory.Equipments then
        warn("   ❌ لم يتم العثور على المعدات في النسخة!")
        return false
    end
    
    local equipments = replica.Data.Inventory.Equipments
    
    for id, item in pairs(equipments) do
        if type(item) == "table" and item.Type then
            if item.Type == pickaxeName then
                print(string.format("   ✅ لديك بالفعل: %s", pickaxeName))
                return true
            end
        end
    end
    
    return false
end

----------------------------------------------------------------
-- تنفيذ المهمة الرئيسية
----------------------------------------------------------------
local function doBuyPickaxe()
    print("🛒 الهدف: شراء الفأس...")
    
    -- 1. التحقق من الذهب
    print("\n💰 التحقق من الذهب...")
    if not hasEnoughGold() then
        warn("   ❌ لا يوجد ذهب كافٍ للشراء!")
        return false
    end
    
    -- 2. التحقق من المخزون
    print("\n🔍 التحقق من المخزون...")
    if hasPickaxe(QUEST_CONFIG.ITEM_NAME) then
        print("   ✅ لديك الفأس بالفعل!")
        return true
    end
    
    -- 3. الانتقال إلى المتجر
    local shopPos = QUEST_CONFIG.SHOP_POSITION
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    
    if hrp then
        local currentDist = (shopPos - hrp.Position).Magnitude
        print(string.format("   🚶 الانتقال إلى المتجر في (%.1f, %.1f, %.1f) (يبعد %.1f وحدات)...", 
            shopPos.X, shopPos.Y, shopPos.Z, currentDist))
    end
    
    local moveComplete = false
    smoothMoveTo(shopPos, function()
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
    
    if not moveComplete then
        warn("   ⚠️ فشل في الوصول إلى المتجر")
        return false
    end
    
    print("   ✅ تم الوصول إلى المتجر!")
    task.wait(1)
    
    -- 4. شراء الفأس
    print("\n🛒 جاري شراء الفأس...")
    local purchaseSuccess = purchaseItem(QUEST_CONFIG.ITEM_NAME, QUEST_CONFIG.ITEM_QUANTITY)
    
    if not purchaseSuccess then
        warn("   ❌ فشل في شراء الفأس")
        return false
    end
    
    print("   ✅ تم إتمام الشراء!")
    
    -- 5. التحقق من الذهب بعد الشراء
    task.wait(1)
    local newGold = getPlayerGold()
    if newGold then
        print(string.format("\n💰 الذهب بعد الشراء: $%.2f", newGold))
    end
    
    -- 6. التحقق من المخزون مرة أخرى
    task.wait(1)
    if hasPickaxe(QUEST_CONFIG.ITEM_NAME) then
        print(string.format("   ✅ تم الحصول بنجاح على: %s", QUEST_CONFIG.ITEM_NAME))
        return true
    else
        warn("   ⚠️ تم الشراء بنجاح لكن العنصر غير موجود في المخزون")
        return true  -- نفترض النجاح إذا عمل التحكم البعيد
    end
end

----------------------------------------------------------------
-- مشغل المهمة الذكي
----------------------------------------------------------------
print(string.rep("=", 50))
print("🚀 المهمة 16: " .. QUEST_CONFIG.QUEST_NAME)
print("🎯 الهدف: شراء الفأس")
print("✅ الاستراتيجية: التحقق من الذهب → الانتقال إلى المتجر → الشراء")
print(string.rep("=", 50))

-- التحقق المسبق: الذهب >= 3340 و المستوى < 10
print("\n🔍 التحقق المسبق: التحقق من متطلبات الذهب والمستوى...")

-- 1) التحقق من الذهب >= الحد الأدنى
local goldOk = hasEnoughGold()

-- 2) التحقق من المستوى < 10
local level = getPlayerLevel()
if not level then
    warn("\n❌ لا يمكن تحديد مستوى اللاعب – تخطي المهمة 16")
    print(string.rep("=", 50))
    cleanupState()
    disableNoclip()
    return
end

if (not goldOk) or level >= 10 then
    print(string.format(
        "\n❌ الشرط غير مستوفى (الذهب ≥ %d و المستوى < 10). الحالي: الذهبOK=%s، المستوى=%d",
        QUEST_CONFIG.MIN_GOLD,
        tostring(goldOk),
        level
    ))
    print(string.rep("=", 50))
    cleanupState()
    disableNoclip()
    return
end

print(string.format(
    "   ✅ الشرط مستوفى! الذهب ≥ %d و المستوى < 10 (المستوى = %d)",
    QUEST_CONFIG.MIN_GOLD,
    level
))

-- التحقق إذا كان الفأس موجوداً بالفعل
print("\n🔍 التحقق المسبق: التحقق إذا كان الفأس موجوداً بالفعل...")
if hasPickaxe(QUEST_CONFIG.ITEM_NAME) then
    print("\n✅ لديك الفأس بالفعل!")
    print(string.rep("=", 50))
    cleanupState()
    disableNoclip()
    return
end

print("   ❌ لا تملك الفأس بعد – المتابعة للشراء...")

-- شراء الفأس
local buySuccess = doBuyPickaxe()

if buySuccess then
    print("\n" .. string.rep("=", 50))
    print("✅ المهمة 16 مكتملة! تم شراء الفأس بنجاح!")
    print(string.rep("=", 50))
else
    warn("\n" .. string.rep("=", 50))
    warn("❌ المهمة 16 فشلت! لم يتمكن من شراء الفأس.")
    warn(string.rep("=", 50))
end

Quest16Active = false
cleanupState()
disableNoclip()