local Shared = _G.Shared

-- المهمة 12: "كل شيء يبدأ الآن!" (التحدث إلى الساحر - إكمال تلقائي)
-- ✅ تحرك سلس للجسم نحو الساحر
-- ✅ حوار تلقائي → تحقق من المهمة → إنهاء المهمة
-- ✅ إجبار على استعادة واجهة المستخدم

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

----------------------------------------------------------------
-- الإعدادات
----------------------------------------------------------------
local Quest12Active = true

local QUEST_CONFIG = {
    QUEST_NAME = "كل شيء يبدأ الآن.",
    NPC_NAME = "Wizard",
    NPC_POSITION = Vector3.new(-24.1, 80.9, -358.5),
    MOVE_SPEED = 25,  
    NPC_STOP_DISTANCE = 5,
}

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

local function isQuest12StillActive()
    if not Quest12Active then return false end
    
    local questID, objList = getQuestObjectives(QUEST_CONFIG.QUEST_NAME)
    if not questID or not objList then
        print("🛑 المهمة '" .. QUEST_CONFIG.QUEST_NAME .. "' غير موجودة!")
        Quest12Active = false
        return false
    end
    
    return true
end

local function areAllObjectivesComplete()
    local questID, objList = getQuestObjectives(QUEST_CONFIG.QUEST_NAME)
    if not questID or not objList then return true end
    
    for _, item in ipairs(objList:GetChildren()) do
        if item:IsA("Frame") and tonumber(item.Name) then
            if not isObjectiveComplete(item) then
                return false
            end
        end
    end
    
    return true
end

----------------------------------------------------------------
-- مساعدات الـ NPC
----------------------------------------------------------------
local function getNpcModel(name)
    local prox = Workspace:FindFirstChild("Proximity")
    return prox and prox:FindFirstChild(name)
end

----------------------------------------------------------------
-- عدم التصادم والحركة
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
        
        if distance < QUEST_CONFIG.NPC_STOP_DISTANCE then
            print("   ✅ وصلت إلى الـ NPC!")
            
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
-- الدوال البعيدة
----------------------------------------------------------------
local function invokeDialogueStart(npcModel)
    local remote = ReplicatedStorage:WaitForChild("Shared")
        :WaitForChild("Packages"):WaitForChild("Knit")
        :WaitForChild("Services"):WaitForChild("ProximityService")
        :WaitForChild("RF"):WaitForChild("Dialogue")
    if remote then
        pcall(function() remote:InvokeServer(npcModel) end)
        print("📡 1. بدأ الحوار")
    end
end

local function invokeRunCommand(commandName)
    local remote = ReplicatedStorage:WaitForChild("Shared")
        :WaitForChild("Packages"):WaitForChild("Knit")
        :WaitForChild("Services"):WaitForChild("DialogueService")
        :WaitForChild("RF"):WaitForChild("RunCommand")
    if remote then
        print("📡 2. تنفيذ الأمر: " .. commandName)
        pcall(function() remote:InvokeServer(commandName) end)
    end
end

----------------------------------------------------------------
-- استعادة واجهة المستخدم
----------------------------------------------------------------
local function forceEndDialogueAndRestore()
    print("🔧 3. إجبار التنظيف واستعادة واجهة المستخدم...")
    
    -- أ. إغلاق الحوار وإصلاح الكاميرا
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
    
    -- ب. إزالة علامات الحالة
    local char = player.Character
    if char then
        local status = char:FindFirstChild("Status")
        if status then
            for _, tag in ipairs(status:GetChildren()) do
                if tag.Name == "DisableBackpack" or tag.Name == "NoMovement" or tag.Name == "Talking" then
                    pcall(function() tag:Destroy() end)
                    print("   - تمت إزالة علامة الحالة: " .. tag.Name)
                end
            end
        end
        
        -- استعادة الـ Humanoid
        local humanoid = char:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = 16
            humanoid.JumpPower = 50
        end
    end
    
    -- ج. استعادة واجهة المستخدم الرئيسية
    if gui then
        local main = gui:FindFirstChild("Main")
        if main then 
            main.Enabled = true 
            print("   - تم استعادة واجهة المستخدم الرئيسية (المهمة)")
        end
        
        local backpack = gui:FindFirstChild("BackpackGui")
        if backpack then 
            backpack.Enabled = true 
            print("   - تم استعادة الحقيبة")
        end
        
        local compass = gui:FindFirstChild("Compass")
        if compass then compass.Enabled = true end
        
        local mobile = gui:FindFirstChild("MobileButtons")
        if mobile then mobile.Enabled = true end
    end
    
    -- د. إعلام الخادم بالإغلاق
    local dialogueEvent = ReplicatedStorage:WaitForChild("Shared")
        :WaitForChild("Packages"):WaitForChild("Knit")
        :WaitForChild("Services"):WaitForChild("DialogueService")
        :WaitForChild("RE"):WaitForChild("DialogueEvent")
    if dialogueEvent then
        pcall(function() dialogueEvent:FireServer("Closed") end)
    end
    
    print("✅ تم الاستعادة بنجاح")
end

----------------------------------------------------------------
-- تنفيذ المهمة الرئيسية
----------------------------------------------------------------
local function doTalkToWizard()
    print("📋 الهدف: التحدث إلى الساحر...")
    
    local npcModel = getNpcModel(QUEST_CONFIG.NPC_NAME)
    if not npcModel then
        warn("   ❌ لم يتم العثور على الـ NPC: " .. QUEST_CONFIG.NPC_NAME)
        warn("   💡 محاولة استخدام الموقع الثابت بدلاً من ذلك...")
    end
    
    local targetPos = QUEST_CONFIG.NPC_POSITION
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    
    if hrp then
        local currentDist = (targetPos - hrp.Position).Magnitude
        print(string.format("   🚶 التحرك إلى %s عند (%.1f, %.1f, %.1f) (يبعد %.1f وحدات)...", 
            QUEST_CONFIG.NPC_NAME, targetPos.X, targetPos.Y, targetPos.Z, currentDist))
    end
    
    local moveComplete = false
    smoothMoveTo(targetPos, function()
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
        warn("   ⚠️ فشل الوصول إلى الـ NPC، المتابعة على أي حال...")
    end
    
    -- تحقق من الـ NPC مرة أخرى
    if not npcModel then
        npcModel = getNpcModel(QUEST_CONFIG.NPC_NAME)
    end
    
    if not npcModel then
        warn("   ❌ لا يمكن العثور على نموذج الـ NPC!")
        return false
    end
    
    print("\n📞 بدء الحوار مع الساحر...")
    task.wait(0.5)
    invokeDialogueStart(npcModel)
    
    print("⏳ انتظار فتح الحوار...")
    task.wait(1.5)
    
    print("✅ اختيار خيار تحقق المهمة...")
    invokeRunCommand("CheckQuest")
    
    print("⏳ معالجة تحقق المهمة...")
    task.wait(0.8)
    
    print("✅ إرسال أمر إنهاء المهمة...")
    invokeRunCommand("FinishQuest")
    
    print("⏳ معالجة إنهاء المهمة...")
    task.wait(0.5)
    
    forceEndDialogueAndRestore()
    
    print("   ✅ تم إكمال حوار المهمة!")
    return true
end

----------------------------------------------------------------
-- مشغل المهمة الذكي
----------------------------------------------------------------
print(string.rep("=", 50))
print("🚀 المهمة 12: " .. QUEST_CONFIG.QUEST_NAME)
print("🎯 الهدف: التحدث إلى الساحر")
print("✅ الاستراتيجية: تحقق تلقائي من المهمة + إنهاء المهمة")
print(string.rep("=", 50))

local questID, objList = getQuestObjectives(QUEST_CONFIG.QUEST_NAME)

if not questID then
    warn("❌ المهمة '" .. QUEST_CONFIG.QUEST_NAME .. "' غير موجودة!")
    Quest12Active = false
    cleanupState()
    disableNoclip()
    return
end

print("✅ تم العثور على المهمة (المعرف: " .. questID .. ")")

print("\n" .. string.rep("=", 50))
print("⚙️  أهداف المهمة:")
local objectiveCount = 0
for _, item in ipairs(objList:GetChildren()) do
    if item:IsA("Frame") and tonumber(item.Name) then
        objectiveCount = objectiveCount + 1
        local text = getObjectiveText(item)
        local complete = isObjectiveComplete(item)
        print(string.format("   %d. %s [%s]", objectiveCount, text, complete and "✅" or "⏳"))
    end
end
print(string.rep("=", 50))

if areAllObjectivesComplete() then
    print("\n✅ المهمة مكتملة بالفعل!")
    cleanupState()
    disableNoclip()
    return
end

local maxAttempts = 3
local attempt = 0

while isQuest12StillActive() and not areAllObjectivesComplete() and attempt < maxAttempts do
    attempt = attempt + 1
    print(string.format("\n🔄 المحاولة #%d", attempt))
    
    local success = doTalkToWizard()
    
    if success then
        print("   ✅ تم إكمال تسلسل الحوار!")
        task.wait(2)
        
        if areAllObjectivesComplete() then
            print("\n🎉 تم إكمال جميع الأهداف!")
            break
        else
            print("   ⚠️ لم يتم تعليم المهمة كمكتملة، إعادة المحاولة...")
            task.wait(2)
        end
    else
        warn("   ❌ فشل الحوار، إعادة المحاولة بعد 3 ثوانٍ...")
        task.wait(3)
    end
end

task.wait(1)

if areAllObjectivesComplete() then
    print("\n" .. string.rep("=", 50))
    print("✅ المهمة 12 مكتملة!")
    print("🎉 كل شيء يبدأ الآن!")
    print(string.rep("=", 50))
else
    warn("\n" .. string.rep("=", 50))
    warn("⚠️ المهمة 12 غير مكتملة بعد " .. attempt .. " محاولات")
    warn(string.rep("=", 50))
end

Quest12Active = false
cleanupState()
disableNoclip()