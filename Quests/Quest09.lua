local Shared = _G.Shared

-- المهمة 9: "الترقية الأولى!" (تعزيز تلقائي إلى +3)
-- ✅ لا حاجة للانتقال إلى NPC
-- ✅ استخدم Enhance Equipment Remote مباشرة
-- ✅ تكرار التعزيز حتى اكتمال المهمة

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

----------------------------------------------------------------
-- الإعدادات
----------------------------------------------------------------
local Quest9Active = true

local QUEST_CONFIG = {
    QUEST_NAME = "The First Upgrade",
    TARGET_UPGRADE_LEVEL = 3,  -- يجب التعزيز إلى +3
    ENHANCE_DELAY = 1.0,       -- الانتظار 1 ثانية بين التعزيزات
    MAX_ENHANCE_ATTEMPTS = 50, -- لمنع الحلقة اللانهائية
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
local EnhanceService = nil

pcall(function()
    PlayerController = Knit.GetController("PlayerController")
    EnhanceService = Knit.GetService("EnhanceService")
end)

local SERVICES = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Services")

local ENHANCE_RF = nil
pcall(function()
    ENHANCE_RF = SERVICES:WaitForChild("EnhanceService", 5):WaitForChild("RF", 3):WaitForChild("EnhanceEquipment", 3)
end)

local FIND_EQUIPMENT_RF = nil
pcall(function()
    FIND_EQUIPMENT_RF = SERVICES:WaitForChild("EnhanceService", 5):WaitForChild("RF", 3):WaitForChild("FindEquipmentByGUID", 3)
end)

if PlayerController then print("✅ PlayerController جاهز!") else warn("⚠️ لم يتم العثور على PlayerController") end
if EnhanceService then print("✅ EnhanceService جاهز!") else warn("⚠️ لم يتم العثور على EnhanceService") end
if ENHANCE_RF then print("✅ Enhance Remote جاهز!") else warn("⚠️ لم يتم العثور على Enhance Remote") end
if FIND_EQUIPMENT_RF then print("✅ FindEquipment Remote جاهز!") else warn("⚠️ لم يتم العثور على FindEquipment Remote") end

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

local function isQuest9StillActive()
    if not Quest9Active then return false end
    
    local questID, objList = getQuestObjectives(QUEST_CONFIG.QUEST_NAME)
    if not questID or not objList then
        print("🛑 المهمة '" .. QUEST_CONFIG.QUEST_NAME .. "' غير موجودة!")
        Quest9Active = false
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
-- متحكم واجهة المستخدم (من Quest04)
----------------------------------------------------------------
local UIController = nil
pcall(function()
    for _, v in pairs(getgc(true)) do
        if type(v) == "table" then
            if rawget(v, "Open") and rawget(v, "Close") and rawget(v, "Modules") then
                UIController = v
                break
            end
        end
    end
end)

if UIController then print("✅ UIController جاهز!") else warn("⚠️ لم يتم العثور على UIController") end

local function openToolsMenu()
    if not UIController then return false end
    
    if UIController.Modules["Menu"] then
        pcall(function() UIController:Open("Menu") end)
        task.wait(0.5)
        
        local menuModule = UIController.Modules["Menu"]
        if menuModule.OpenTab then
            pcall(function() menuModule:OpenTab("Tools") end)
        elseif menuModule.SwitchTab then
            pcall(function() menuModule:SwitchTab("Tools") end)
        end
        
        task.wait(0.5)
        return true
    end
    
    return false
end

local function closeToolsMenu()
    if UIController and UIController.Close then
        pcall(function() UIController:Close("Menu") end)
        task.wait(0.3)
    end
end

----------------------------------------------------------------
-- العثور على السلاح المجهز (عبر نص "فك التجهيز" في الواجهة)
----------------------------------------------------------------
local function findEquippedWeapon()
    print("   📂 فتح قائمة الأدوات للعثور على السلاح المجهز...")
    openToolsMenu()
    task.wait(0.5)
    
    local menuGui = playerGui:FindFirstChild("Menu")
    if not menuGui then 
        warn("   ❌ لم يتم العثور على واجهة القائمة!")
        closeToolsMenu()
        return nil, "لم يتم العثور على واجهة القائمة"
    end
    
    local toolsFrame = menuGui:FindFirstChild("Frame") 
                    and menuGui.Frame:FindFirstChild("Frame") 
                    and menuGui.Frame.Frame:FindFirstChild("Menus") 
                    and menuGui.Frame.Frame.Menus:FindFirstChild("Tools")
                    and menuGui.Frame.Frame.Menus.Tools:FindFirstChild("Frame")
    
    if not toolsFrame then 
        warn("   ❌ لم يتم العثور على إطار الأدوات!")
        closeToolsMenu()
        return nil, "لم يتم العثور على إطار الأدوات"
    end
    
    print("   🔍 البحث عن السلاح المجهز (زر فك التجهيز)...")
    
    local equippedWeapon = nil
    
    -- مسح جميع العناصر في إطار الأدوات
    for _, weaponFrame in ipairs(toolsFrame:GetChildren()) do
        if weaponFrame:IsA("Frame") then
            local equipButton = weaponFrame:FindFirstChild("Equip")
            if equipButton then
                local textLabel = equipButton:FindFirstChild("TextLabel")
                if textLabel and textLabel:IsA("TextLabel") then
                    -- التحقق إذا كان النص "فك التجهيز" = مجهز حالياً
                    if textLabel.Text == "Unequip" then
                        local guid = weaponFrame.Name
                        
                        -- تخطي المعول
                        local itemName = weaponFrame:FindFirstChild("TextLabel")
                        local itemType = itemName and itemName.Text or ""
                        
                        if string.find(itemType, "Pickaxe") then
                            print(string.format("      ⏭️  تخطي المعول: %s", itemType))
                            continue
                        end
                        
                        -- الحصول على مستوى الترقية من الواجهة
                        local upgradeLevel = 0
                        local stats = weaponFrame:FindFirstChild("Stats")
                        if stats then
                            -- محاولة العثور على نص الترقية
                            for _, stat in ipairs(stats:GetChildren()) do
                                if stat:IsA("TextLabel") then
                                    local upgradeMatch = string.match(stat.Text, "%+(%d+)")
                                    if upgradeMatch then
                                        upgradeLevel = tonumber(upgradeMatch) or 0
                                    end
                                end
                            end
                        end
                        
                        equippedWeapon = {
                            GUID = guid,
                            Name = itemType,
                            Type = itemType,
                            Upgrade = upgradeLevel,
                        }
                        
                        print(string.format("      ✅ تم العثور على السلاح المجهز: %s (GUID: %s, +%d)", 
                            itemType, guid, upgradeLevel))
                        break
                    end
                end
            end
        end
    end
    
    closeToolsMenu()
    
    if not equippedWeapon then
        return nil, "لم يتم العثور على سلاح مجهز (لا يوجد زر فك التجهيز)"
    end
    
    return equippedWeapon, nil
end

local function getItemCurrentUpgrade(guid)
    if not FIND_EQUIPMENT_RF then return nil end
    
    local success, result = pcall(function()
        return FIND_EQUIPMENT_RF:InvokeServer(guid)
    end)
    
    if success and result and type(result) == "table" then
        return result.Upgrade or 0
    end
    
    return nil
end

----------------------------------------------------------------
-- نظام التعزيز
----------------------------------------------------------------
local function enhanceItem(guid)
    if not ENHANCE_RF then
        warn("   ❌ Enhance Remote غير متوفر!")
        return false, "الريموت غير متوفر"
    end
    
    local success, result = pcall(function()
        return ENHANCE_RF:InvokeServer(guid)
    end)
    
    if success then
        if result == true or (type(result) == "table" and result.Success) then
            return true, "نجاح"
        elseif type(result) == "table" and result.Error then
            return false, result.Error
        else
            return false, "نتيجة غير معروفة"
        end
    else
        return false, tostring(result)
    end
end

local function printItemInfo(item)
    print(string.format("   🎯 العنصر المختار: %s", item.Name or item.Type))
    print(string.format("      - النوع: %s", item.Type or "غير معروف"))
    print(string.format("      - الترقية الحالية: +%d", item.Upgrade or 0))
    print(string.format("      - GUID: %s", item.GUID))
end

----------------------------------------------------------------
-- تنفيذ المهمة الرئيسي
----------------------------------------------------------------
local function doEnhanceToPlus3()
    print("⚡ الهدف: تعزيز السلاح المجهز إلى +3...")
    
    -- العثور على السلاح المجهز حالياً (ليس بأقل ترقية)
    local targetItem, errorMsg = findEquippedWeapon()
    
    if not targetItem then
        warn("   ❌ خطأ: " .. errorMsg)
        return false
    end
    
    printItemInfo(targetItem)
    
    if targetItem.Upgrade >= QUEST_CONFIG.TARGET_UPGRADE_LEVEL then
        print(string.format("   ✅ العنصر بالفعل عند +%d أو أعلى!", targetItem.Upgrade))
        return true
    end
    
    print(string.format("\n   🔨 بدء حلقة التعزيز (الهدف: +%d)...\n", QUEST_CONFIG.TARGET_UPGRADE_LEVEL))
    
    local enhanceCount = 0
    local successCount = 0
    local failCount = 0
    
    while isQuest9StillActive() and not areAllObjectivesComplete() do
        enhanceCount = enhanceCount + 1
        
        if enhanceCount > QUEST_CONFIG.MAX_ENHANCE_ATTEMPTS then
            warn(string.format("   ⚠️ تم الوصول إلى الحد الأقصى للمحاولات (%d)! التوقف...", QUEST_CONFIG.MAX_ENHANCE_ATTEMPTS))
            break
        end
        
        -- التحقق من المستوى الحالي
        local currentUpgrade = getItemCurrentUpgrade(targetItem.GUID)
        
        if currentUpgrade then
            print(string.format("   📊 الحالة الحالية: +%d / +%d", currentUpgrade, QUEST_CONFIG.TARGET_UPGRADE_LEVEL))
            
            if currentUpgrade >= QUEST_CONFIG.TARGET_UPGRADE_LEVEL then
                print(string.format("   🎉 تم الوصول للهدف! العنصر الآن +%d", currentUpgrade))
                break
            end
        end
        
        -- محاولة التعزيز
        print(string.format("   ⚡ محاولة تعزيز #%d...", enhanceCount))
        
        local success, result = enhanceItem(targetItem.GUID)
        
        if success then
            successCount = successCount + 1
            print(string.format("      ✅ تم التعزيز بنجاح! (+%d ناجح)", successCount))
        else
            failCount = failCount + 1
            print(string.format("      ❌ فشل التعزيز! (%s) (+%d فشل)", result, failCount))
        end
        
        -- التحقق إذا كانت المهمة مكتملة
        task.wait(0.5)
        if areAllObjectivesComplete() then
            print("\n   🎉 تم إكمال هدف المهمة!")
            break
        end
        
        -- الانتظار قبل المحاولة التالية
        print(string.format("   ⏸️  الانتظار %.1f ثانية قبل المحاولة التالية...\n", QUEST_CONFIG.ENHANCE_DELAY))
        task.wait(QUEST_CONFIG.ENHANCE_DELAY)
    end
    
    print("\n   📊 ملخص التعزيز:")
    print(string.format("      - إجمالي المحاولات: %d", enhanceCount))
    print(string.format("      - الناجحة: %d", successCount))
    print(string.format("      - الفاشلة: %d", failCount))
    
    -- التحقق من المستوى النهائي
    local finalUpgrade = getItemCurrentUpgrade(targetItem.GUID)
    if finalUpgrade then
        print(string.format("      - الترقية النهائية: +%d", finalUpgrade))
        
        if finalUpgrade >= QUEST_CONFIG.TARGET_UPGRADE_LEVEL then
            print("   ✅ تم الانتهاء من التعزيز!")
            return true
        else
            warn(string.format("   ⚠️ فشل في الوصول إلى +%d (الحالي: +%d)", QUEST_CONFIG.TARGET_UPGRADE_LEVEL, finalUpgrade))
            return false
        end
    end
    
    return false
end

----------------------------------------------------------------
-- مشغل المهمة الذكي
----------------------------------------------------------------
print(string.rep("=", 50))
print("🚀 المهمة 9: " .. QUEST_CONFIG.QUEST_NAME)
print("🎯 الهدف: تعزيز العنصر إلى +" .. QUEST_CONFIG.TARGET_UPGRADE_LEVEL)
print("✅ الاستراتيجية: تعزيز عن بعد (بدون حركة)")
print(string.rep("=", 50))

local questID, objList = getQuestObjectives(QUEST_CONFIG.QUEST_NAME)

if not questID then
    warn("❌ المهمة '" .. QUEST_CONFIG.QUEST_NAME .. "' غير موجودة!")
    Quest9Active = false
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
    return
end

print("\n" .. string.rep("=", 50))
print("⚡ بدء عملية التعزيز...")
print(string.rep("=", 50))

local success = doEnhanceToPlus3()

task.wait(1)

if areAllObjectivesComplete() then
    print("\n" .. string.rep("=", 50))
    print("✅ المهمة 9 مكتملة!")
    print(string.rep("=", 50))
else
    if success then
        print("\n   ⚠️ تم الانتهاء من التعزيز لكن المهمة لم تُعلم كمكتملة")
        print("   💡 حاول التحقق من حالة المهمة يدوياً")
    else
        warn("\n" .. string.rep("=", 50))
        warn("⚠️ المهمة 9 غير مكتملة - فشل التعزيز")
        warn(string.rep("=", 50))
    end
end

Quest9Active = false