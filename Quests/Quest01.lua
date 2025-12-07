--[[
    ⚔️ المهمة 01: البداية!
    📋 تحدث إلى المعلم مورو
    📍 مقتطف من 0.lua (الأسطر 209-587)
--]]

-- سكريبت أتمتة المهمة 1 بالكامل (حركة سلسة + استعادة واجهة المستخدم بالقوة)
-- الميزات: التحقق من المهمة -> حركة سلسة للجسم -> حوار -> استعادة واجهة المستخدم بالكامل بالقوة

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

----------------------------------------------------------------
-- الإعدادات
----------------------------------------------------------------
local QUEST_NAME = "البداية!"
local NPC_NAME = "Sensei Moro"
local QUEST_OPTION_ARG = "GiveIntroduction1"
local MOVE_SPEED = 25

----------------------------------------------------------------
-- إدارة الحالة
----------------------------------------------------------------
local State = {
    noclipConn = nil,
    moveConn = nil,
    bodyVelocity = nil,
    bodyGyro = nil,
}

local function restoreCollisions()
    local char = player.Character
    if not char then return end

    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = true
        end
    end
end

local function cleanupState()
    if State.noclipConn then
        State.noclipConn:Disconnect()
        State.noclipConn = nil
    end
    if State.moveConn then
        State.moveConn:Disconnect()
        State.moveConn = nil
    end
    if State.bodyVelocity then
        State.bodyVelocity:Destroy()
        State.bodyVelocity = nil
    end
    if State.bodyGyro then
        State.bodyGyro:Destroy()
        State.bodyGyro = nil
    end

    -- ✅ مهم: إعادة CanCollide للشخصية
    restoreCollisions()
end

----------------------------------------------------------------
-- تعطيل الاصطدام (NOCLIP)
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
    -- ✅ إيقاف noclip وإعادة الاصطدام للشخصية
    restoreCollisions()
end

----------------------------------------------------------------
-- الحركة السلسة
----------------------------------------------------------------
local function smoothMoveTo(targetPos, callback)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    -- تنظيف الحركة السابقة
    if State.moveConn then State.moveConn:Disconnect() State.moveConn = nil end
    if State.bodyVelocity then State.bodyVelocity:Destroy() State.bodyVelocity = nil end
    if State.bodyGyro then State.bodyGyro:Destroy() State.bodyGyro = nil end
    
    -- تفعيل noclip
    enableNoclip()
    
    -- إنشاء BodyVelocity
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = hrp
    State.bodyVelocity = bv
    
    -- إنشاء BodyGyro
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
        
        if distance < 5 then  -- التوقف على بعد 5 وحدات (قرب NPC)
            print("   ✅ تم الوصول إلى NPC!")
            
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
        
        local speed = math.min(MOVE_SPEED, distance * 10)
        local velocity = direction.Unit * speed
        
        bv.Velocity = velocity
        bg.CFrame = CFrame.lookAt(currentPos, targetPos)
    end)
    
    return true
end

----------------------------------------------------------------
-- الدوال البعيدة (REMOTE FUNCTIONS)
----------------------------------------------------------------
local function invokeDialogueStart(npcModel)
    local remote = ReplicatedStorage:WaitForChild("Shared")
        :WaitForChild("Packages"):WaitForChild("Knit")
        :WaitForChild("Services"):WaitForChild("ProximityService")
        :WaitForChild("RF"):WaitForChild("Dialogue")
    if remote then
        remote:InvokeServer(npcModel)
        print("📡 1. بدأ الحوار")
    end
end

local function invokeRunCommand(commandName)
    local remote = ReplicatedStorage:WaitForChild("Shared")
        :WaitForChild("Packages"):WaitForChild("Knit")
        :WaitForChild("Services"):WaitForChild("DialogueService")
        :WaitForChild("RF"):WaitForChild("RunCommand")
    if remote then
        print("📡 2. اختيار الخيار: " .. commandName)
        pcall(function() remote:InvokeServer(commandName) end)
    end
end

----------------------------------------------------------------
-- مساعد: استعادة بالقوة (إصلاح واجهة المستخدم المفقودة)
----------------------------------------------------------------
local function ForceEndDialogueAndRestore()
    print("🔧 3. فرض التنظيف واستعادة واجهة المستخدم...")

    -- أ. إغلاق الحوار وتصحيح الكاميرا
    local gui = player:FindFirstChild("PlayerGui")
    if gui then
        local dUI = gui:FindFirstChild("DialogueUI")
        if dUI then
            dUI.Enabled = false
            local bb = dUI:FindFirstChild("ResponseBillboard")
            if bb then bb.Visible = false end
        end
    end

    local cam = Workspace.CurrentCamera
    if cam then
        cam.CameraType = Enum.CameraType.Custom
        cam.FieldOfView = 70
    end

    -- ب. حذف الحالات التي تسبب اختفاء واجهة المستخدم
    local char = player.Character
    if char then
        local status = char:FindFirstChild("Status")
        if status then
            for _, tag in ipairs(status:GetChildren()) do
                if tag.Name == "DisableBackpack" or tag.Name == "NoMovement" or tag.Name == "Talking" then
                    tag:Destroy()
                    print("   - تمت إزالة حالة: " .. tag.Name)
                end
            end
        end
        
        -- إعادة ضبط Humanoid
        local humanoid = char:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = 16
            humanoid.JumpPower = 50
        end
    end

    -- ج. فرض إعادة تفعيل واجهات المستخدم المهمة
    if gui then
        local main = gui:FindFirstChild("Main")
        if main then 
            main.Enabled = true 
            print("   - تم استعادة واجهة المستخدم الرئيسية (المهمة)")
        end
        
        local backpack = gui:FindFirstChild("BackpackGui")
        if backpack then 
            backpack.Enabled = true 
            print("   - تم استعادة حقيبة الظهر")
        end
        
        local compass = gui:FindFirstChild("Compass")
        if compass then compass.Enabled = true end
        
        local mobile = gui:FindFirstChild("MobileButtons")
        if mobile then mobile.Enabled = true end
    end

    -- د. إعلام الخادم بأنه تم الإغلاق
    local remote = ReplicatedStorage:WaitForChild("Shared")
        :WaitForChild("Packages"):WaitForChild("Knit")
        :WaitForChild("Services"):WaitForChild("DialogueService")
        :WaitForChild("RE"):WaitForChild("DialogueEvent")
    if remote then
        remote:FireServer("Closed")
    end
    
    print("✅ تم الاستعادة بالكامل")
end

----------------------------------------------------------------
-- مساعد: التحقق من المستوى
----------------------------------------------------------------
local function getPlayerLevel()
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return nil end
    
    local levelLabel = gui:FindFirstChild("Main")
                      and gui.Main:FindFirstChild("Screen")
                      and gui.Main.Screen:FindFirstChild("Hud")
                      and gui.Main.Screen.Hud:FindFirstChild("Level")
    
    if not levelLabel or not levelLabel:IsA("TextLabel") then
        return nil
    end
    
    local levelText = levelLabel.Text
    local level = tonumber(string.match(levelText, "%d+"))
    return level
end

----------------------------------------------------------------
-- مساعد: المهمة والحركة
----------------------------------------------------------------
local function getActiveQuestName()
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return nil end
    local list = gui:FindFirstChild("Main") and gui.Main:FindFirstChild("Screen") 
                 and gui.Main.Screen:FindFirstChild("Quests") and gui.Main.Screen.Quests:FindFirstChild("List")
    if not list then return nil end
    for _, child in ipairs(list:GetChildren()) do
        if string.match(child.Name, "^Introduction%d+Title$") then
            local frame = child:FindFirstChild("Frame")
            if frame then
                local label = frame:FindFirstChild("TextLabel")
                if label and label.Text ~= "" then return label.Text end
            end
        end
    end
    return nil
end

local function getNpcModel(name)
    local prox = Workspace:FindFirstChild("Proximity")
    return prox and prox:FindFirstChild(name)
end

----------------------------------------------------------------
-- إكمال بالقوة (للتعافي من حوار منقطع)
-- يستخدم حركة الجسم إلى موقع NPC ثابت
-- يعمل فقط إذا كانت قائمة المهام فارغة (بدون عناصر)
----------------------------------------------------------------
local NPC_POSITION = Vector3.new(-200.07, 30.37, 158.41)

local function forceCompleteQuest1()
    print("\n🔧 التحقق مما إذا كان إكمال بالقوة مطلوب...")
    
    -- ⚠️ تحقق أولاً إذا كانت قائمة المهام فارغة حقًا
    local gui = player:FindFirstChild("PlayerGui")
    local isQuestListEmpty = true
    
    if gui then
        local list = gui:FindFirstChild("Main") and gui.Main:FindFirstChild("Screen") 
                     and gui.Main.Screen:FindFirstChild("Quests") and gui.Main.Screen.Quests:FindFirstChild("List")
        if list then
            for _, child in ipairs(list:GetChildren()) do
                -- يوجد عنصر مهمة (ليس فقط UIListLayout أو UIPadding)
                if child.Name ~= "UIListLayout" and child.Name ~= "UIPadding" then
                    isQuestListEmpty = false
                    break
                end
            end
        end
    end
    
    -- ❌ إذا كانت هناك عناصر مهمة → لا يتم الإكمال بالقوة
    if not isQuestListEmpty then
        print("   ⏭️ قائمة المهام تحتوي على عناصر (ليست فارغة)")
        print("   → تخطي الإكمال بالقوة (مهام أخرى نشطة)")
        return false
    end
    
    -- ✅ قائمة المهام فارغة → تنفيذ الإكمال بالقوة
    print("   ✅ قائمة المهام فارغة! متابعة الإكمال بالقوة...")
    print(string.format("   🎯 التحرك إلى موقع NPC (%.1f, %.1f, %.1f)...", 
        NPC_POSITION.X, NPC_POSITION.Y, NPC_POSITION.Z))
    
    -- 1. تفعيل noclip والتحرك إلى موقع NPC
    enableNoclip()
    
    local moveComplete = false
    smoothMoveTo(NPC_POSITION, function()
        moveComplete = true
    end)
    
    -- الانتظار للحركة (حد أقصى 30 ثانية)
    local timeout = 30
    local startTime = tick()
    while not moveComplete and tick() - startTime < timeout do
        task.wait(0.1)
    end
    
    -- تنظيف الحركة
    cleanupState()
    disableNoclip()
    
    if not moveComplete then
        warn("   ⚠️ انتهاء مهلة الحركة، لكن محاولة الاتصال بالخادم على أي حال...")
    else
        print("   ✅ تم الوصول إلى موقع NPC!")
    end
    
    task.wait(0.5)
    
    -- 2. محاولة إيجاد NPC وبدء الحوار
    local npcModel = getNpcModel(NPC_NAME)
    if npcModel then
        print("   📡 تم العثور على NPC، بدء الحوار...")
        invokeDialogueStart(npcModel)
        task.wait(0.5)
    else
        print("   ⚠️ لم يتم العثور على NPC في الموقع، محاولة الاتصال بالخادم مباشرة...")
    end
    
    -- 3. إرسال أمر قبول المهمة
    print("   📡 إرسال أمر قبول المهمة...")
    pcall(function()
        invokeRunCommand(QUEST_OPTION_ARG)
    end)
    task.wait(0.5)
    
    -- 4. تنظيف واجهة المستخدم
    ForceEndDialogueAndRestore()
    
    print("   ✅ تم إكمال الإكمال بالقوة!")
    return true
end

----------------------------------------------------------------
-- التنفيذ الرئيسي
----------------------------------------------------------------
local function Run_Quest1()
    print(string.rep("=", 50))
    print("🚀 المهمة 1: " .. QUEST_NAME)
    print(string.rep("=", 50))
    
    -- ✅ التحقق من وجود Introduction0Title (واجهة مهمة 1)
    local gui = player:FindFirstChild("PlayerGui")
    local hasQuest1UI = false
    
    if gui then
        local list = gui:FindFirstChild("Main") and gui.Main:FindFirstChild("Screen") 
                     and gui.Main.Screen:FindFirstChild("Quests") and gui.Main.Screen.Quests:FindFirstChild("List")
        if list and list:FindFirstChild("Introduction0Title") then
            hasQuest1UI = true
        end
    end
    
    if hasQuest1UI then
        -- ✅ يوجد واجهة مهمة 1 → متابعة التدفق العادي
        print("✅ تم العثور على واجهة مهمة 1 (Introduction0Title)! متابعة التدفق العادي...")
    else
        -- ⚠️ لا توجد واجهة مهمة 1 → تنفيذ forceCompleteQuest1
        print("\n⚠️ تم الكشف: لا توجد واجهة مهمة 1 (Introduction0Title)!")
        print("   → واجهة مهمة 1 غير مرئية")
        print("   → قد يكون اللاعب قد انقطع أثناء الحوار")
        print("   → محاولة استعادة بالقوة...")
        
        local success = forceCompleteQuest1()
        if success then
            cleanupState()
            disableNoclip()
            print("\n" .. string.rep("=", 50))
            print("🎉 تم استعادة المهمة 1 بنجاح!")
            print(string.rep("=", 50))
            return
        end
    end

    local npcModel = getNpcModel(NPC_NAME)
    if not npcModel then 
        cleanupState()
        disableNoclip()
        return warn("❌ لم يتم العثور على NPC") 
    end
    
    local targetPart = npcModel.PrimaryPart or npcModel:FindFirstChildWhichIsA("BasePart")
    if not targetPart then
        cleanupState()
        disableNoclip()
        return warn("❌ NPC لا يحتوي على جزء صالح")
    end
    
    local targetPos = targetPart.Position
    
    print(string.format("\n🚶 التحرك إلى NPC '%s' عند (%.1f, %.1f, %.1f)...", 
        NPC_NAME, targetPos.X, targetPos.Y, targetPos.Z))
    
    -- بدء الحركة السلسة
    local moveComplete = false
    smoothMoveTo(targetPos, function()
        moveComplete = true
    end)
    
    -- الانتظار حتى اكتمال الحركة
    local timeout = 60
    local startTime = tick()
    while not moveComplete and tick() - startTime < timeout do
        task.wait(0.1)
    end
    
    -- تنظيف الحركة
    if State.moveConn then State.moveConn:Disconnect() State.moveConn = nil end
    if State.bodyVelocity then State.bodyVelocity:Destroy() State.bodyVelocity = nil end
    if State.bodyGyro then State.bodyGyro:Destroy() State.bodyGyro = nil end
    
    if not moveComplete then
        cleanupState()
        disableNoclip()
        return warn("❌ فشل الوصول إلى NPC (انتهت المهلة)")
    end
    
    print("\n📞 بدء الحوار...")
    task.wait(0.5)
    invokeDialogueStart(npcModel)
    
    print("⏳ الانتظار لفتح الحوار...")
    task.wait(1.5)
    
    print("✅ اختيار خيار المهمة...")
    invokeRunCommand(QUEST_OPTION_ARG)
    
    print("⏳ جاري المعالجة...")
    task.wait(0.5)
    
    ForceEndDialogueAndRestore()
    
    -- التنظيف النهائي
    cleanupState()
    disableNoclip()
    
    print("\n" .. string.rep("=", 50))
    print("🎉 تم الانتهاء من تسلسل المهمة 1!")
    print(string.rep("=", 50))
end

Run_Quest1()