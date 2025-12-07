local Shared = _G.Shared

-- المهمة 13: مهمة العازف (مهمة تلقائية تعتمد على المستوى)
-- ✅ التحقق من المستوى من PlayerGui.Main.Screen.Hud.Level
-- ✅ إذا كان المستوى < 10 → الانتقال إلى NPC العازف
-- ✅ فتح الحوار → CheckQuest → GiveBardQuest
-- ✅ قبول المهمة تلقائيًا وإكمالها

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

----------------------------------------------------------------
-- الإعدادات
----------------------------------------------------------------
local Quest13Active = true
local DEBUG_MODE = true

local QUEST_CONFIG = {
    QUEST_NAME = "Bard Quest",  -- اسم المهمة (إذا لم يتم العثور عليه، تحقق من المستوى)
    NPC_NAME = "Bard",
    NPC_POSITION = Vector3.new(-130.9, 27.8, 109.8),
    MIN_LEVEL = 10,  -- الحد الأدنى للمستوى المطلوب (هل هو الحد الأقصى لهذه المهمة؟)
    MOVE_SPEED = 25,  
    NPC_STOP_DISTANCE = 5,
}

----------------------------------------------------------------
-- إعداد Knit
----------------------------------------------------------------
local KnitPackage = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Knit")
local Knit = require(KnitPackage)

if not Knit.OnStart then 
    pcall(function() Knit.Start():await() end)
end

local PlayerController = nil
local ProximityService = nil
local DialogueService = nil

pcall(function()
    PlayerController = Knit.GetController("PlayerController")
    ProximityService = Knit.GetService("ProximityService")
    DialogueService = Knit.GetService("DialogueService")
end)

local SERVICES = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Services")

local DIALOGUE_RF = nil
pcall(function()
    DIALOGUE_RF = SERVICES:WaitForChild("ProximityService", 5):WaitForChild("RF", 3):WaitForChild("Dialogue", 3)
end)

local DIALOGUE_COMMAND_RF = nil
pcall(function()
    DIALOGUE_COMMAND_RF = SERVICES:WaitForChild("DialogueService", 5):WaitForChild("RF", 3):WaitForChild("RunCommand", 3)
end)

if PlayerController then print("✅ PlayerController جاهز!") else warn("⚠️ PlayerController غير موجود") end
if ProximityService then print("✅ ProximityService جاهز!") else warn("⚠️ ProximityService غير موجود") end
if DialogueService then print("✅ DialogueService جاهز!") else warn("⚠️ DialogueService غير موجود") end
if DIALOGUE_RF then print("✅ Dialogue Remote جاهز!") else warn("⚠️ Dialogue Remote غير موجود") end
if DIALOGUE_COMMAND_RF then print("✅ DialogueCommand Remote جاهز!") else warn("⚠️ DialogueCommand Remote غير موجود") end

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
        warn("   💡 المسار: PlayerGui.Main.Screen.Hud.Level")
        return nil
    end
    
    if not levelLabel:IsA("TextLabel") then
        warn("   ❌ المستوى ليس TextLabel!")
        return nil
    end
    
    local levelText = levelLabel.Text
    print(string.format("   📊 نص المستوى: '%s'", levelText))
    
    -- استخراج المستوى من النص (مثلاً "Level 7" → 7)
    local level = tonumber(string.match(levelText, "%d+"))
    
    if level then
        print(string.format("   ✅ مستوى اللاعب: %d", level))
        return level
    else
        warn("   ❌ فشل في استخراج المستوى من النص!")
        return nil
    end
end

local function shouldDoQuest()
    local level = getPlayerLevel()
    
    if not level then
        warn("   ❌ لا يمكن تحديد مستوى اللاعب!")
        return false
    end
    
    if level < QUEST_CONFIG.MIN_LEVEL then
        print(string.format("   ✅ المستوى %d < %d - المهمة متاحة!", level, QUEST_CONFIG.MIN_LEVEL))
        return true
    else
        print(string.format("   ⏸️  المستوى %d >= %d - المهمة غير متاحة", level, QUEST_CONFIG.MIN_LEVEL))
        return false
    end
end

----------------------------------------------------------------
-- نظام المهمة (احتياطي - إذا كان اسم المهمة موجود)
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

local function areAllObjectivesComplete()
    local questID, objList = getQuestObjectives(QUEST_CONFIG.QUEST_NAME)
    if not questID or not objList then return false end
    
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
        
        if distance < QUEST_CONFIG.NPC_STOP_DISTANCE then
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
-- التفاعل مع NPC
----------------------------------------------------------------
local function getNpcModel(name)
    local prox = Workspace:FindFirstChild("Proximity")
    return prox and prox:FindFirstChild(name)
end

local function openDialogue(npcModel)
    if not DIALOGUE_RF then
        warn("   ❌ Dialogue Remote غير متوفر!")
        return false
    end
    
    print("   📞 فتح الحوار مع " .. QUEST_CONFIG.NPC_NAME .. "...")
    
    local success = pcall(function()
        DIALOGUE_RF:InvokeServer(npcModel)
    end)
    
    if success then
        print("   ✅ تم فتح الحوار!")
        return true
    else
        warn("   ❌ فشل في فتح الحوار")
        return false
    end
end

local function runDialogueCommand(command)
    if not DIALOGUE_COMMAND_RF then
        warn("   ❌ DialogueCommand Remote غير متوفر!")
        return false
    end
    
    print(string.format("   💬 تنفيذ الأمر: '%s'", command))
    
    local success, result = pcall(function()
        return DIALOGUE_COMMAND_RF:InvokeServer(command)
    end)
    
    if success then
        print(string.format("   ✅ تم تنفيذ الأمر '%s' بنجاح!", command))
        if DEBUG_MODE and result then
            print(string.format("   📊 النتيجة: %s", tostring(result)))
        end
        return true
    else
        warn(string.format("   ❌ فشل تنفيذ الأمر '%s': %s", command, tostring(result)))
        return false
    end
end

----------------------------------------------------------------
-- استعادة واجهة المستخدم
----------------------------------------------------------------
local function forceRestoreUI()
    print("🔧 إجبار استعادة واجهة المستخدم...")
    
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
    
    local char = player.Character
    if char then
        local status = char:FindFirstChild("Status")
        if status then
            for _, tag in ipairs(status:GetChildren()) do
                if tag.Name == "DisableBackpack" or tag.Name == "NoMovement" or tag.Name == "Talking" then
                    pcall(function() tag:Destroy() end)
                    print("   - تم إزالة علامة الحالة: " .. tag.Name)
                end
            end
        end
        
        local humanoid = char:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = 16
            humanoid.JumpPower = 50
        end
    end
    
    if gui then
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
    end
    
    print("✅ استعادة واجهة المستخدم مكتملة")
end

----------------------------------------------------------------
-- تنفيذ المهمة الرئيسية
----------------------------------------------------------------
local function doAcceptQuest()
    print("📜 الهدف: قبول مهمة العازف...")
    
    -- 1. التحقق من المستوى
    print("\n🔍 التحقق من توفر المهمة...")
    if not shouldDoQuest() then
        warn("   ❌ المهمة غير متاحة (المستوى مرتفع جدًا)")
        return false
    end
    
    -- 2. العثور على NPC
    local npcModel = getNpcModel(QUEST_CONFIG.NPC_NAME)
    if not npcModel then
        warn("   ❌ لم يتم العثور على NPC: " .. QUEST_CONFIG.NPC_NAME)
        return false
    end
    
    -- 3. الانتقال إلى NPC
    local npcPos = QUEST_CONFIG.NPC_POSITION
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    
    if hrp then
        local currentDist = (npcPos - hrp.Position).Magnitude
        print(string.format("   🚶 الانتقال إلى %s عند (%.1f, %.1f, %.1f) (يبعد %.1f وحدات)...", 
            QUEST_CONFIG.NPC_NAME, npcPos.X, npcPos.Y, npcPos.Z, currentDist))
    end
    
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
    
    if not moveComplete then
        warn("   ⚠️ فشل في الوصول إلى NPC")
        return false
    end
    
    print("   ✅ تم الوصول إلى NPC!")
    task.wait(1)
    
    -- 4. فتح الحوار
    print("\n📞 فتح الحوار...")
    local dialogueOpened = openDialogue(npcModel)
    
    if not dialogueOpened then
        warn("   ❌ فشل في فتح الحوار")
        return false
    end
    
    task.wait(1.5)
    
    -- 5. التحقق من المهمة (CheckQuest)
    print("\n🔍 التحقق من توفر المهمة...")
    local checkSuccess = runDialogueCommand("CheckQuest")
    
    if not checkSuccess then
        warn("   ❌ فشل في التحقق من المهمة")
        return false
    end
    
    task.wait(1)
    
    -- 6. قبول المهمة (GiveBardQuest)
    print("\n✅ قبول المهمة...")
    local giveSuccess = runDialogueCommand("GiveBardQuest")
    
    if not giveSuccess then
        warn("   ❌ فشل في قبول المهمة")
        return false
    end
    
    print("   ✅ تم قبول المهمة!")
    
    -- 7. استعادة واجهة المستخدم
    task.wait(1)
    forceRestoreUI()
    
    return true
end

----------------------------------------------------------------
-- مشغل المهمة الذكي
----------------------------------------------------------------
print(string.rep("=", 50))
print("🚀 المهمة 13: " .. QUEST_CONFIG.QUEST_NAME)
print("🎯 الهدف: قبول مهمة العازف (تعتمد على المستوى)")
print(string.format("✅ الاستراتيجية: التحقق من المستوى → الانتقال إلى NPC → قبول المهمة"))
print(string.rep("=", 50))

-- التحقق من المستوى أولاً
print("\n🔍 التحقق المسبق: التحقق من متطلبات المستوى...")
if not shouldDoQuest() then
    print("\n✅ المهمة غير متاحة (المستوى مرتفع جدًا)")
    print(string.rep("=", 50))
    cleanupState()
    disableNoclip()
    return
end

local maxAttempts = 3
local attempt = 0

while Quest13Active and attempt < maxAttempts do
    attempt = attempt + 1
    print(string.format("\n🔄 المحاولة #%d", attempt))
    
    local success = doAcceptQuest()
    
    if success then
        print("   ✅ تم قبول المهمة بنجاح!")
        task.wait(2)
        
        -- التحقق من وجود المهمة في الواجهة
        local questID, objList = getQuestObjectives(QUEST_CONFIG.QUEST_NAME)
        if questID then
            print("\n🎉 تم العثور على المهمة في سجل المهام!")
            
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
            
            break
        else
            print("   ⚠️ المهمة غير موجودة في سجل المهام، لكنها مقبولة")
            break
        end
    else
        warn("   ❌ فشل في قبول المهمة، إعادة المحاولة خلال 3 ثواني...")
        task.wait(3)
    end
end

task.wait(1)

print("\n" .. string.rep("=", 50))
print("✅ المهمة 13 مكتملة!")
print(string.rep("=", 50))

Quest13Active = false
cleanupState()
disableNoclip()