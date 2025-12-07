local Shared = _G.Shared

-- المهمة 14: "الجيتار المفقود" (تم الإصلاح - تغيير عرض المهمة)
-- ✅ الانتقال إلى الجيتار (-46.2, -26.6, -63.4)
-- ✅ جمع الجيتار عبر Functionals Remote
-- ✅ العودة إلى NPC العازف (-130.9, 27.8, 109.8)
-- ✅ التحدث إلى NPC → التحقق من المهمة → إنهاء المهمة
-- ✅ إكمال المهمة تلقائيًا

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

----------------------------------------------------------------
-- الإعدادات
----------------------------------------------------------------
local Quest14Active = true
local DEBUG_MODE = true

local QUEST_CONFIG = {
    QUEST_NAME = "الجيتار المفقود!",
    QUEST_ID = "BardQuest",  -- يستخدم بدلاً من Introduction{N}
    
    -- موقع الجيتار
    GUITAR_OBJECT_NAME = "BardGuitar",
    GUITAR_POSITION = Vector3.new(-46.2, -26.6, -63.4),
    
    -- NPC العازف
    NPC_NAME = "Bard",
    NPC_POSITION = Vector3.new(-130.9, 27.8, 109.8),
    
    MOVE_SPEED = 25,  
    STOP_DISTANCE = 5,
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

local FUNCTIONALS_RF = nil
pcall(function()
    FUNCTIONALS_RF = SERVICES:WaitForChild("ProximityService", 5):WaitForChild("RF", 3):WaitForChild("Functionals", 3)
end)

local DIALOGUE_COMMAND_RF = nil
pcall(function()
    DIALOGUE_COMMAND_RF = SERVICES:WaitForChild("DialogueService", 5):WaitForChild("RF", 3):WaitForChild("RunCommand", 3)
end)

if PlayerController then print("✅ تم تجهيز PlayerController!") else warn("⚠️ لم يتم العثور على PlayerController") end
if ProximityService then print("✅ تم تجهيز ProximityService!") else warn("⚠️ لم يتم العثور على ProximityService") end
if DialogueService then print("✅ تم تجهيز DialogueService!") else warn("⚠️ لم يتم العثور على DialogueService") end
if DIALOGUE_RF then print("✅ تم تجهيز Dialogue Remote!") else warn("⚠️ لم يتم العثور على Dialogue Remote") end
if FUNCTIONALS_RF then print("✅ تم تجهيز Functionals Remote!") else warn("⚠️ لم يتم العثور على Functionals Remote") end
if DIALOGUE_COMMAND_RF then print("✅ تم تجهيز DialogueCommand Remote!") else warn("⚠️ لم يتم العثور على DialogueCommand Remote") end

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
-- نظام المهمة (تم الإصلاح - بدون Introduction{N})
----------------------------------------------------------------
local function getQuestObjectives(questID)
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return nil, nil end
    
    local list = gui:FindFirstChild("Main") and gui.Main:FindFirstChild("Screen") 
                 and gui.Main.Screen:FindFirstChild("Quests") and gui.Main.Screen.Quests:FindFirstChild("List")
    if not list then return nil, nil end
    
    -- البحث عن العنوان (مثلاً "BardQuestTitle")
    local titleFrame = list:FindFirstChild(questID .. "Title")
    if not titleFrame then
        if DEBUG_MODE then
            warn(string.format("   ❌ لم يتم العثور على عنوان المهمة: %sTitle", questID))
        end
        return nil, nil
    end
    
    -- التحقق من تطابق العنوان مع اسم المهمة
    if titleFrame:FindFirstChild("Frame") and titleFrame.Frame:FindFirstChild("TextLabel") then
        local questName = titleFrame.Frame.TextLabel.Text
        if DEBUG_MODE then
            print(string.format("   ✅ تم العثور على المهمة: %s", questName))
        end
    end
    
    -- البحث عن القائمة (مثلاً "BardQuestList")
    local objList = list:FindFirstChild(questID .. "List")
    if not objList then
        if DEBUG_MODE then
            warn(string.format("   ❌ لم يتم العثور على قائمة المهمة: %sList", questID))
        end
        return nil, nil
    end
    
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

local function isQuest14StillActive()
    if not Quest14Active then return false end
    
    local questID, objList = getQuestObjectives(QUEST_CONFIG.QUEST_ID)
    if not questID or not objList then
        print("🛑 لم يتم العثور على المهمة '" .. QUEST_CONFIG.QUEST_NAME .. "'!")
        Quest14Active = false
        return false
    end
    
    return true
end

local function areAllObjectivesComplete()
    local questID, objList = getQuestObjectives(QUEST_CONFIG.QUEST_ID)
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
-- تعطيل الاصطدام والحركة
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
    
    print(string.format("   🚀 جارٍ التحرك إلى (%.1f, %.1f, %.1f)...", targetPos.X, targetPos.Y, targetPos.Z))
    
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
-- مساعدات الكائنات
----------------------------------------------------------------
local function getProximityObject(name)
    local prox = Workspace:FindFirstChild("Proximity")
    return prox and prox:FindFirstChild(name)
end

----------------------------------------------------------------
-- التقاط الجيتار
----------------------------------------------------------------
local function pickupGuitar()
    if not FUNCTIONALS_RF then
        warn("   ❌ Functionals Remote غير متوفر!")
        return false
    end
    
    local guitarObject = getProximityObject(QUEST_CONFIG.GUITAR_OBJECT_NAME)
    if not guitarObject then
        warn("   ❌ لم يتم العثور على كائن الجيتار: " .. QUEST_CONFIG.GUITAR_OBJECT_NAME)
        return false
    end
    
    print("   🎸 جارٍ التقاط الجيتار...")
    
    local success, result = pcall(function()
        return FUNCTIONALS_RF:InvokeServer(guitarObject)
    end)
    
    if success then
        print("   ✅ تم التقاط الجيتار!")
        return true
    else
        warn("   ❌ فشل في التقاط الجيتار: " .. tostring(result))
        return false
    end
end

----------------------------------------------------------------
-- التفاعل مع NPC
----------------------------------------------------------------
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
        warn(string.format("   ❌ فشل في تنفيذ الأمر '%s': %s", command, tostring(result)))
        return false
    end
end

----------------------------------------------------------------
-- استعادة واجهة المستخدم
----------------------------------------------------------------
local function forceRestoreUI()
    print("🔧 جارٍ فرض استعادة واجهة المستخدم...")
    
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
    
    print("✅ تم استكمال استعادة واجهة المستخدم")
end

----------------------------------------------------------------
-- تنفيذ المهمة الرئيسية
----------------------------------------------------------------
local function doCollectGuitar()
    print("🎸 الخطوة 1: جمع الجيتار...")
    
    -- 1. الانتقال إلى الجيتار
    local guitarPos = QUEST_CONFIG.GUITAR_POSITION
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    
    if hrp then
        local currentDist = (guitarPos - hrp.Position).Magnitude
        print(string.format("   🚶 جارٍ التحرك إلى الجيتار عند (%.1f, %.1f, %.1f) (على بعد %.1f وحدات)...", 
            guitarPos.X, guitarPos.Y, guitarPos.Z, currentDist))
    end
    
    local moveComplete = false
    smoothMoveTo(guitarPos, function()
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
        warn("   ⚠️ فشل في الوصول إلى الجيتار")
        return false
    end
    
    print("   ✅ تم الوصول إلى الجيتار!")
    task.wait(1)
    
    -- 2. التقاط الجيتار
    local pickupSuccess = pickupGuitar()
    
    if not pickupSuccess then
        warn("   ❌ فشل في التقاط الجيتار")
        return false
    end
    
    task.wait(1)
    return true
end

local function doReturnGuitar()
    print("\n🎸 الخطوة 2: إعادة الجيتار إلى العازف...")
    
    -- 1. الانتقال إلى NPC العازف
    local npcPos = QUEST_CONFIG.NPC_POSITION
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    
    if hrp then
        local currentDist = (npcPos - hrp.Position).Magnitude
        print(string.format("   🚶 جارٍ التحرك إلى %s عند (%.1f, %.1f, %.1f) (على بعد %.1f وحدات)...", 
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
    
    -- 2. العثور على نموذج NPC
    local npcModel = getProximityObject(QUEST_CONFIG.NPC_NAME)
    if not npcModel then
        warn("   ❌ لم يتم العثور على NPC: " .. QUEST_CONFIG.NPC_NAME)
        return false
    end
    
    -- 3. فتح الحوار
    print("\n📞 جارٍ فتح الحوار...")
    local dialogueOpened = openDialogue(npcModel)
    
    if not dialogueOpened then
        warn("   ❌ فشل في فتح الحوار")
        return false
    end
    
    task.wait(1.5)
    
    -- 4. التحقق من المهمة
    print("\n🔍 جارٍ التحقق من حالة المهمة...")
    local checkSuccess = runDialogueCommand("CheckQuest")
    
    if not checkSuccess then
        warn("   ❌ فشل في التحقق من المهمة")
        return false
    end
    
    task.wait(1)
    
    -- 5. إنهاء المهمة (إعادة الجيتار)
    print("\n✅ جارٍ إعادة الجيتار إلى العازف...")
    local finishSuccess = runDialogueCommand("FinishQuest")
    
    if not finishSuccess then
        warn("   ❌ فشل في إنهاء المهمة")
        return false
    end
    
    print("   ✅ تم إكمال المهمة!")
    
    -- 6. استعادة واجهة المستخدم
    task.wait(1)
    forceRestoreUI()
    
    return true
end

----------------------------------------------------------------
-- مشغل المهمة الذكي
----------------------------------------------------------------
print(string.rep("=", 50))
print("🚀 المهمة 14: " .. QUEST_CONFIG.QUEST_NAME)
print("🎯 الهدف: العثور على الجيتار وإعادته إلى العازف")
print("✅ الاستراتيجية: جمع الجيتار → العودة إلى NPC → إنهاء المهمة")
print(string.rep("=", 50))

local questID, objList = getQuestObjectives(QUEST_CONFIG.QUEST_ID)

if not questID then
    warn("❌ لم يتم العثور على المهمة '" .. QUEST_CONFIG.QUEST_NAME .. "'!")
    warn(string.format("   💡 البحث عن: %sTitle", QUEST_CONFIG.QUEST_ID))
    Quest14Active = false
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

while isQuest14StillActive() and not areAllObjectivesComplete() and attempt < maxAttempts do
    attempt = attempt + 1
    print(string.format("\n🔄 المحاولة #%d", attempt))
    
    -- الخطوة 1: جمع الجيتار
    local collectSuccess = doCollectGuitar()
    
    if not collectSuccess then
        warn("   ❌ فشل في جمع الجيتار، إعادة المحاولة بعد 3 ثوانٍ...")
        task.wait(3)
        continue
    end
    
    -- الخطوة 2: إعادة الجيتار
    local returnSuccess = doReturnGuitar()
    
    if returnSuccess then
        print("   ✅ تم إكمال المهمة بنجاح!")
        task.wait(2)
        
        if areAllObjectivesComplete() then
            print("\n🎉 تم إكمال جميع الأهداف!")
            break
        else
            print("   ⚠️ لم يتم تعليم المهمة كمكتملة، إعادة المحاولة...")
            task.wait(2)
        end
    else
        warn("   ❌ فشل في إعادة الجيتار، إعادة المحاولة بعد 3 ثوانٍ...")
        task.wait(3)
    end
end

task.wait(1)

if areAllObjectivesComplete() then
    print("\n" .. string.rep("=", 50))
    print("✅ تم إكمال المهمة 14!")
    print(string.rep("=", 50))
else
    warn("\n" .. string.rep("=", 50))
    warn("⚠️ المهمة 14 غير مكتملة بعد " .. attempt .. " محاولات")
    warn(string.rep("=", 50))
end

Quest14Active = false
cleanupState()
disableNoclip()