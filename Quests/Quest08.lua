local Shared = _G.Shared

-- المهمة 8: "التبليغ!" (تحريك الجسم + حوار مع سينسي مورو)
-- الهدف: اذهب إلى سينسي مورو وانقر على CheckQuest

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

----------------------------------------------------------------
-- الإعدادات
----------------------------------------------------------------
local Quest8Active = true

local QUEST_CONFIG = {
    QUEST_NAME = "Reporting In",
    NPC_NAME = "Sensei Moro",
    QUEST_OPTION_ARG = "CheckQuest",
    MOVE_SPEED = 25,  
    NPC_STOP_DISTANCE = 5,  -- التوقف على بعد 5 وحدات من الـ NPC
}

----------------------------------------------------------------
-- إعداد Knit
----------------------------------------------------------------
local KnitPackage = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Knit")
local Knit = require(KnitPackage)

if not Knit.OnStart then 
    pcall(function() Knit.Start():await() end)
end

local ProximityService = nil
local DialogueService = nil

pcall(function()
    ProximityService = Knit.GetService("ProximityService")
    DialogueService = Knit.GetService("DialogueService")
end)

local SERVICES = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Services")

local DIALOGUE_RF = nil
pcall(function()
    DIALOGUE_RF = SERVICES:WaitForChild("ProximityService", 5):WaitForChild("RF", 3):WaitForChild("Dialogue", 3)
end)

local RUNCOMMAND_RF = nil
pcall(function()
    RUNCOMMAND_RF = SERVICES:WaitForChild("DialogueService", 5):WaitForChild("RF", 3):WaitForChild("RunCommand", 3)
end)

local DIALOGUE_RE = nil
pcall(function()
    DIALOGUE_RE = SERVICES:WaitForChild("DialogueService", 5):WaitForChild("RE", 3):WaitForChild("DialogueEvent", 3)
end)

if ProximityService then print("✅ خدمة القرب جاهزة!") else warn("⚠️ خدمة القرب غير موجودة") end
if DialogueService then print("✅ خدمة الحوار جاهزة!") else warn("⚠️ خدمة الحوار غير موجودة") end
if DIALOGUE_RF then print("✅ التحكم عن بعد للحوار جاهز!") else warn("⚠️ التحكم عن بعد للحوار غير موجود") end
if RUNCOMMAND_RF then print("✅ التحكم عن بعد لأمر التشغيل جاهز!") else warn("⚠️ التحكم عن بعد لأمر التشغيل غير موجود") end

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

local function isQuest8StillActive()
    if not Quest8Active then return false end
    
    local questID, objList = getQuestObjectives(QUEST_CONFIG.QUEST_NAME)
    if not questID or not objList then
        print("🛑 المهمة '" .. QUEST_CONFIG.QUEST_NAME .. "' غير موجودة!")
        Quest8Active = false
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
-- مساعدو الـ NPC
----------------------------------------------------------------
local function getNpcModel(name)
    local prox = Workspace:FindFirstChild("Proximity")
    return prox and prox:FindFirstChild(name)
end

local function getNpcPosition(npcModel)
    if not npcModel then return nil end
    
    local targetPart = npcModel.PrimaryPart or npcModel:FindFirstChildWhichIsA("BasePart")
    if not targetPart then return nil end
    
    return targetPart.Position
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
            print("   ✅ تم الوصول إلى الـ NPC!")
            
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
-- استعادة واجهة المستخدم
----------------------------------------------------------------
local function forceRestoreUI()
    print("🔧 إجبار استعادة واجهة المستخدم...")
    
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
        
        local humanoid = char:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = 16
            humanoid.JumpPower = 50
        end
    end
    
    local gui = player:FindFirstChild("PlayerGui")
    if gui then
        local dUI = gui:FindFirstChild("DialogueUI")
        if dUI then
            dUI.Enabled = false
            local bb = dUI:FindFirstChild("ResponseBillboard")
            if bb then bb.Visible = false end
        end
        
        local main = gui:FindFirstChild("Main")
        if main then 
            main.Enabled = true 
            print("   - تم استعادة الواجهة الرئيسية")
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
    
    local cam = Workspace.CurrentCamera
    if cam then
        cam.CameraType = Enum.CameraType.Custom
        cam.FieldOfView = 70
    end
    
    if DIALOGUE_RE then
        pcall(function() DIALOGUE_RE:FireServer("Closed") end)
    end
    
    print("✅ استعادة واجهة المستخدم مكتملة")
end

----------------------------------------------------------------
-- نظام الحوار
----------------------------------------------------------------
local function startDialogue(npcModel)
    if not DIALOGUE_RF then
        warn("   ❌ التحكم عن بعد للحوار غير متوفر!")
        return false
    end
    
    print("📞 بدء الحوار مع " .. QUEST_CONFIG.NPC_NAME .. "...")
    
    local success = pcall(function()
        DIALOGUE_RF:InvokeServer(npcModel)
    end)
    
    if success then
        print("   ✅ تم بدء الحوار!")
        return true
    else
        warn("   ❌ فشل بدء الحوار")
        return false
    end
end

local function selectQuestOption(optionName)
    if not RUNCOMMAND_RF then
        warn("   ❌ التحكم عن بعد لأمر التشغيل غير متوفر!")
        return false
    end
    
    print("✅ اختيار الخيار: " .. optionName)
    
    local success = pcall(function()
        RUNCOMMAND_RF:InvokeServer(optionName)
    end)
    
    if success then
        print("   ✅ تم اختيار الخيار!")
        return true
    else
        warn("   ❌ فشل اختيار الخيار")
        return false
    end
end

----------------------------------------------------------------
-- تنفيذ المهمة الرئيسية
----------------------------------------------------------------
local function doReportToSenseiMoro()
    print("📋 الهدف: التبليغ إلى سينسي مورو...")
    
    local npcModel = getNpcModel(QUEST_CONFIG.NPC_NAME)
    if not npcModel then
        warn("   ❌ لم يتم العثور على الـ NPC: " .. QUEST_CONFIG.NPC_NAME)
        return false
    end
    
    local targetPos = getNpcPosition(npcModel)
    if not targetPos then
        warn("   ❌ لا يمكن الحصول على موقع الـ NPC!")
        return false
    end
    
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
        warn("   ❌ فشل الوصول إلى الـ NPC (انتهى الوقت)")
        return false
    end
    
    print("\n📞 التفاعل مع سينسي مورو...")
    task.wait(0.5)
    
    local dialogueSuccess = startDialogue(npcModel)
    if not dialogueSuccess then
        warn("   ❌ فشل الحوار!")
        return false
    end
    
    print("   ⏳ الانتظار لفتح الحوار...")
    task.wait(1.5)
    
    local optionSuccess = selectQuestOption(QUEST_CONFIG.QUEST_OPTION_ARG)
    if not optionSuccess then
        warn("   ❌ فشل اختيار الخيار!")
    end
    
    print("   ⏳ جاري المعالجة...")
    task.wait(1)
    
    forceRestoreUI()
    
    print("   ✅ اكتمال الحوار!")
    return true
end

----------------------------------------------------------------
-- مشغل المهمة الذكي
----------------------------------------------------------------
print(string.rep("=", 50))
print("🚀 المهمة 8: " .. QUEST_CONFIG.QUEST_NAME)
print("🎯 الهدف: التبليغ إلى سينسي مورو")
print(string.rep("=", 50))

local questID, objList = getQuestObjectives(QUEST_CONFIG.QUEST_NAME)

if not questID then
    warn("❌ المهمة '" .. QUEST_CONFIG.QUEST_NAME .. "' غير موجودة!")
    Quest8Active = false
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

while isQuest8StillActive() and not areAllObjectivesComplete() and attempt < maxAttempts do
    attempt = attempt + 1
    print(string.format("\n🔄 المحاولة #%d", attempt))
    
    local success = doReportToSenseiMoro()
    
    if success then
        print("   ✅ تم التبليغ بنجاح!")
        task.wait(2)
        
        if areAllObjectivesComplete() then
            print("\n🎉 جميع الأهداف مكتملة!")
            break
        else
            print("   ⚠️ لم يتم تعليم المهمة كمكتملة، إعادة المحاولة...")
            task.wait(2)
        end
    else
        warn("   ❌ فشل التبليغ، إعادة المحاولة بعد 3 ثواني...")
        task.wait(3)
    end
end

task.wait(1)

if areAllObjectivesComplete() then
    print("\n" .. string.rep("=", 50))
    print("✅ المهمة 8 مكتملة!")
    print(string.rep("=", 50))
else
    warn("\n" .. string.rep("=", 50))
    warn("⚠️ المهمة 8 غير مكتملة بعد " .. attempt .. " محاولات")
    warn(string.rep("=", 50))
end

Quest8Active = false
cleanupState()
disableNoclip()