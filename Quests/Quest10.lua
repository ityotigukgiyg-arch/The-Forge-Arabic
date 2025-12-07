local Shared = _G.Shared

-- المهمة 10: "رموز القوة!" (تم الإصلاح - العثور على الرمز من واجهة التخزين)
-- ✅ العثور على الرمز من PlayerGui.Menu.Frame.Menus.Stash.Background
-- ✅ العثور على اسم العنصر = "شرارة اللهب" أو "شريحة الانفجار"
-- ✅ استخدام الـ GUID لإرفاق الرمز
-- ✅ لا حاجة لفتح واجهة الرمز أولاً!

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

----------------------------------------------------------------
-- الإعدادات
----------------------------------------------------------------
local Quest10Active = true
local DEBUG_MODE = true

local QUEST_CONFIG = {
    QUEST_NAME = "Runes of Power",
    NPC_NAME = "Runemaker",
    NPC_POSITION = Vector3.new(-271.7, 20.3, 141.9),
    MOVE_SPEED = 25,  
    NPC_STOP_DISTANCE = 5,
    
    -- الرموز التي يجب البحث عنها (اختر واحداً)
    ALLOWED_RUNE_NAMES = {
        "Flame Spark",
        "Blast Chip",
    },
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
local RuneService = nil

pcall(function()
    PlayerController = Knit.GetController("PlayerController")
    ProximityService = Knit.GetService("ProximityService")
    RuneService = Knit.GetService("RuneService")
end)

local SERVICES = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Services")

local PURCHASE_ATTACH_RF = nil
pcall(function()
    PURCHASE_ATTACH_RF = SERVICES:WaitForChild("RuneService", 5):WaitForChild("RF", 3):WaitForChild("PurchaseAttach", 3)
end)

local GET_PRICE_INFO_RF = nil
pcall(function()
    GET_PRICE_INFO_RF = SERVICES:WaitForChild("RuneService", 5):WaitForChild("RF", 3):WaitForChild("GetPriceInfo", 3)
end)

if PlayerController then print("✅ تم تجهيز PlayerController!") else warn("⚠️ لم يتم العثور على PlayerController") end
if ProximityService then print("✅ تم تجهيز ProximityService!") else warn("⚠️ لم يتم العثور على ProximityService") end
if RuneService then print("✅ تم تجهيز RuneService!") else warn("⚠️ لم يتم العثور على RuneService") end
if PURCHASE_ATTACH_RF then print("✅ تم تجهيز PurchaseAttach Remote!") else warn("⚠️ لم يتم العثور على PurchaseAttach Remote") end

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

local function isQuest10StillActive()
    if not Quest10Active then return false end
    
    local questID, objList = getQuestObjectives(QUEST_CONFIG.QUEST_NAME)
    if not questID or not objList then
        print("🛑 لم يتم العثور على المهمة '" .. QUEST_CONFIG.QUEST_NAME .. "'!")
        Quest10Active = false
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
-- مساعدات المعدات
----------------------------------------------------------------
local function getEquippedWeaponGUID()
    print("   🔍 التحقق من العناصر المجهزة من الواجهة...")
    
    local menuUI = playerGui:FindFirstChild("Menu")
                   and playerGui.Menu:FindFirstChild("Frame")
                   and playerGui.Menu.Frame:FindFirstChild("Frame")
                   and playerGui.Menu.Frame.Frame:FindFirstChild("Menus")
                   and playerGui.Menu.Frame.Frame.Menus:FindFirstChild("Tools")
                   and playerGui.Menu.Frame.Frame.Menus.Tools:FindFirstChild("Frame")
    
    if menuUI then
        for _, child in ipairs(menuUI:GetChildren()) do
            if string.match(child.Name, "^%x+%-%x+%-%x+%-%x+%-%x+$") then
                local equipButton = child:FindFirstChild("Equip")
                local equipLabel = equipButton and equipButton:FindFirstChild("TextLabel")
                
                if equipLabel and equipLabel:IsA("TextLabel") then
                    local isEquipped = (equipLabel.Text == "Unequip")
                    
                    if PlayerController and PlayerController.Replica then
                        local replica = PlayerController.Replica
                        if replica.Data and replica.Data.Inventory and replica.Data.Inventory.Equipments then
                            for id, item in pairs(replica.Data.Inventory.Equipments) do
                                if type(item) == "table" and item.GUID == child.Name then
                                    local isPickaxe = string.find(item.Type or "", "Pickaxe")
                                    
                                    if DEBUG_MODE then
                                        print(string.format("      - %s: UI_Equipped=%s, Pickaxe=%s, GUID=%s", 
                                            item.Type or "Unknown", 
                                            tostring(isEquipped), 
                                            tostring(isPickaxe), 
                                            item.GUID))
                                    end
                                    
                                    if not isPickaxe and isEquipped then
                                        return item.GUID, item.Type
                                    end
                                    
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
    else
        warn("   ⚠️ لم يتم العثور على واجهة القائمة!")
    end
    
    print("   🔍 بديل: التحقق من النسخة...")
    
    if not PlayerController or not PlayerController.Replica then
        warn("   ⚠️ PlayerController/Replica غير متوفر!")
        return nil
    end
    
    local replica = PlayerController.Replica
    if not replica.Data or not replica.Data.Inventory or not replica.Data.Inventory.Equipments then
        warn("   ⚠️ لم يتم العثور على المعدات في النسخة!")
        return nil
    end
    
    local equipments = replica.Data.Inventory.Equipments
    
    for id, item in pairs(equipments) do
        if type(item) == "table" and item.Type and item.GUID then
            local isPickaxe = string.find(item.Type, "Pickaxe")
            local isEquipped = (item.Equipped == true)
            
            if DEBUG_MODE then
                print(string.format("      - %s: Replica_Equipped=%s, Pickaxe=%s, GUID=%s", 
                    item.Type, tostring(isEquipped), tostring(isPickaxe), item.GUID))
            end
            
            if not isPickaxe and isEquipped then
                return item.GUID, item.Type
            end
        end
    end
    
    warn("   ❌ لم يتم العثور على سلاح مجهز (باستثناء المعول)!")
    return nil
end

----------------------------------------------------------------
-- مساعدات الرموز (تم الإصلاح - العثور من واجهة التخزين)
----------------------------------------------------------------
local function getRunesFromStash()
    local runes = {}
    
    print("   🔍 البحث عن الرموز في واجهة التخزين...")
    
    -- المسار: PlayerGui.Menu.Frame.Frame.Menus.Stash.Background
    local stashBackground = playerGui:FindFirstChild("Menu")
                           and playerGui.Menu:FindFirstChild("Frame")
                           and playerGui.Menu.Frame:FindFirstChild("Frame")
                           and playerGui.Menu.Frame.Frame:FindFirstChild("Menus")
                           and playerGui.Menu.Frame.Frame.Menus:FindFirstChild("Stash")
                           and playerGui.Menu.Frame.Frame.Menus.Stash:FindFirstChild("Background")
    
    if not stashBackground then
        warn("   ❌ لم يتم العثور على خلفية التخزين!")
        warn("   💡 المسار: PlayerGui.Menu.Frame.Frame.Menus.Stash.Background")
        return runes
    end
    
    print("   ✅ تم العثور على خلفية التخزين!")
    print(string.format("   📊 إجمالي العناصر الفرعية: %d", #stashBackground:GetChildren()))
    
    -- التكرار عبر جميع العناصر الفرعية للعثور على GUIDs
    for _, child in ipairs(stashBackground:GetChildren()) do
        -- التحقق من أن الاسم يتبع نمط GUID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
        if string.match(child.Name, "^%x+%-%x+%-%x+%-%x+%-%x+$") then
            local main = child:FindFirstChild("Main")
            if main then
                local itemNameLabel = main:FindFirstChild("ItemName")
                if itemNameLabel and itemNameLabel:IsA("TextLabel") then
                    local itemName = itemNameLabel.Text
                    local itemGUID = child.Name
                    
                    if DEBUG_MODE then
                        print(string.format("      - تم العثور على العنصر: %s (GUID: %s)", itemName, itemGUID))
                    end
                    
                    table.insert(runes, {
                        GUID = itemGUID,
                        Name = itemName,
                        Frame = child,
                    })
                end
            end
        end
    end
    
    print(string.format("   📊 إجمالي العناصر الموجودة في التخزين: %d", #runes))
    
    return runes
end

local function findAllowedRuneFromStash()
    local allItems = getRunesFromStash()
    
    if #allItems == 0 then
        return nil, "لم يتم العثور على عناصر في التخزين!"
    end
    
    print(string.format("   📋 تم العثور على %d عنصر(عناصر) في التخزين:", #allItems))
    
    -- تصفية الرموز التي تطابق ALLOWED_RUNE_NAMES
    local allowedRunes = {}
    
    for _, item in ipairs(allItems) do
        for _, allowedName in ipairs(QUEST_CONFIG.ALLOWED_RUNE_NAMES) do
            if item.Name == allowedName then
                table.insert(allowedRunes, item)
                print(string.format("      ✅ مطابق: %s (GUID: %s)", item.Name, item.GUID))
            end
        end
    end
    
    if #allowedRunes == 0 then
        warn(string.format("   ❌ لم يتم العثور على رموز مسموح بها!"))
        warn(string.format("   💡 البحث عن: %s", table.concat(QUEST_CONFIG.ALLOWED_RUNE_NAMES, ", ")))
        
        -- تصحيح الأخطاء: عرض جميع العناصر المتاحة
        if DEBUG_MODE then
            print("   📋 العناصر المتاحة في التخزين:")
            for i, item in ipairs(allItems) do
                print(string.format("      %d. %s (GUID: %s)", i, item.Name, item.GUID))
            end
        end
        
        return nil, string.format("لم يتم العثور على رموز مسموح بها! (البحث عن: %s)", table.concat(QUEST_CONFIG.ALLOWED_RUNE_NAMES, ", "))
    end
    
    -- اختيار عشوائي واحد
    local selectedRune = allowedRunes[math.random(1, #allowedRunes)]
    
    return selectedRune, nil
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
-- التفاعل مع الـ NPC
----------------------------------------------------------------
local function getNpcModel(name)
    local prox = Workspace:FindFirstChild("Proximity")
    return prox and prox:FindFirstChild(name)
end

----------------------------------------------------------------
-- إرفاق الرمز
----------------------------------------------------------------
local function attachRuneToWeapon(weaponGUID, runeGUID)
    if not PURCHASE_ATTACH_RF then
        warn("   ❌ PurchaseAttach Remote غير متوفر!")
        return false
    end
    
    print(string.format("🔮 جاري إرفاق الرمز بالسلاح..."))
    print(string.format("   - معرف السلاح: %s", weaponGUID))
    print(string.format("   - معرف الرمز: %s", runeGUID))
    
    -- استدعاء GetPriceInfo أولاً (إذا كان متاحاً)
    if GET_PRICE_INFO_RF then
        local success = pcall(function()
            GET_PRICE_INFO_RF:InvokeServer(weaponGUID, runeGUID, "Attach")
        end)
        
        if success then
            print("   ✅ تم استدعاء GetPriceInfo")
        end
        
        task.wait(0.3)
    end
    
    -- استدعاء PurchaseAttach
    local success, result = pcall(function()
        return PURCHASE_ATTACH_RF:InvokeServer(weaponGUID, runeGUID)
    end)
    
    if success then
        print("   ✅ تم إرفاق الرمز بنجاح!")
        return true
    else
        warn("   ❌ فشل في إرفاق الرمز: " .. tostring(result))
        return false
    end
end

----------------------------------------------------------------
-- تنفيذ المهمة الرئيسية
----------------------------------------------------------------
local function doAttachRune()
    print("🔮 الهدف: إرفاق الرمز بالسلاح...")
    
    -- 1. التحرك إلى الـ NPC
    local npcModel = getNpcModel(QUEST_CONFIG.NPC_NAME)
    if not npcModel then
        warn("   ❌ لم يتم العثور على الـ NPC: " .. QUEST_CONFIG.NPC_NAME)
        return false
    end
    
    local npcPos = QUEST_CONFIG.NPC_POSITION
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    
    if hrp then
        local currentDist = (npcPos - hrp.Position).Magnitude
        print(string.format("   🚶 التحرك إلى %s عند (%.1f, %.1f, %.1f) (يبعد %.1f وحدات)...", 
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
        warn("   ⚠️ فشل في الوصول إلى الـ NPC")
        return false
    end
    
    print("   ✅ تم الوصول إلى الـ NPC!")
    task.wait(1)
    
    -- 2. العثور على السلاح المجهز
    print("\n🔍 البحث عن السلاح المجهز...")
    local weaponGUID, weaponType = getEquippedWeaponGUID()
    
    if not weaponGUID then
        warn("   ❌ لا يوجد سلاح مجهز!")
        warn("   💡 يرجى تجهيز سلاح (غير المعول) وحاول مرة أخرى")
        return false
    end
    
    print(string.format("   ✅ تم العثور على السلاح المجهز: %s (GUID: %s)", weaponType or "غير معروف", weaponGUID))
    
    -- 3. العثور على الرمز المناسب من واجهة التخزين
    print("\n🔍 البحث عن رمز مناسب من واجهة التخزين...")
    local selectedRune, errorMsg = findAllowedRuneFromStash()
    
    if not selectedRune then
        warn("   ❌ خطأ: " .. errorMsg)
        return false
    end
    
    print(string.format("   ✅ الرمز المختار: %s (GUID: %s)", selectedRune.Name, selectedRune.GUID))
    
    -- 4. إرفاق الرمز
    print("\n⚡ جاري إرفاق الرمز بالسلاح...")
    local attachSuccess = attachRuneToWeapon(weaponGUID, selectedRune.GUID)
    
    if attachSuccess then
        print("   ✅ تم إكمال إرفاق الرمز!")
        return true
    else
        warn("   ❌ فشل في إرفاق الرمز!")
        return false
    end
end

----------------------------------------------------------------
-- مشغل المهمة الذكي
----------------------------------------------------------------
print(string.rep("=", 50))
print("🚀 المهمة 10: " .. QUEST_CONFIG.QUEST_NAME)
print("🎯 الهدف: إرفاق الرمز بالسلاح")
print("✅ الاستراتيجية: التحرك إلى الـ NPC → العثور على الرمز من التخزين → الإرفاق")
print(string.rep("=", 50))

local questID, objList = getQuestObjectives(QUEST_CONFIG.QUEST_NAME)

if not questID then
    warn("❌ لم يتم العثور على المهمة '" .. QUEST_CONFIG.QUEST_NAME .. "'!")
    Quest10Active = false
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
    print("\n✅ تم إكمال المهمة بالفعل!")
    cleanupState()
    disableNoclip()
    return
end

local maxAttempts = 3
local attempt = 0

while isQuest10StillActive() and not areAllObjectivesComplete() and attempt < maxAttempts do
    attempt = attempt + 1
    print(string.format("\n🔄 المحاولة #%d", attempt))
    
    local success = doAttachRune()
    
    if success then
        print("   ✅ تم إكمال إرفاق الرمز!")
        task.wait(2)
        
        if areAllObjectivesComplete() then
            print("\n🎉 تم إكمال جميع الأهداف!")
            break
        else
            print("   ⚠️ لم يتم تعليم المهمة كمكتملة، إعادة المحاولة...")
            task.wait(2)
        end
    else
        warn("   ❌ فشل إرفاق الرمز، إعادة المحاولة بعد 3 ثواني...")
        task.wait(3)
    end
end

task.wait(1)

if areAllObjectivesComplete() then
    print("\n" .. string.rep("=", 50))
    print("✅ تم إكمال المهمة 10!")
    print(string.rep("=", 50))
else
    warn("\n" .. string.rep("=", 50))
    warn("⚠️ المهمة 10 غير مكتملة بعد " .. attempt .. " محاولات")
    warn(string.rep("=", 50))
end

Quest10Active = false
cleanupState()
disableNoclip()