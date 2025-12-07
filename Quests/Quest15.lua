local Shared = _G.Shared
-- تحميل صامت (بدون إزعاج في الكونسول)

-- المهمة 15: الفهرس التلقائي للمطالبة (نظام الكودكس)
-- ✅ يفحص واجهة المستخدم للعناصر القابلة للمطالبة (مطابق لمنطق TestClaim.lua)
-- ✅ يطالب بالخامات، الأعداء، المعدات
-- ✅ يطالب فقط بالعناصر التي تحتوي على زر المطالبة

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

----------------------------------------------------------------
-- الإعدادات
----------------------------------------------------------------
local Quest15Active = true
local DEBUG_MODE = false -- اضبط على true للإخراج التفصيلي

local QUEST_CONFIG = {
    QUEST_NAME = "الفهرس التلقائي للمطالبة",
    CLAIM_DELAY = 0.3,
}

----------------------------------------------------------------
-- إعداد KNIT
----------------------------------------------------------------
local SERVICES = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Services")

local CLAIM_ORE_RF = nil
pcall(function()
    CLAIM_ORE_RF = SERVICES:WaitForChild("CodexService", 5):WaitForChild("RF", 3):WaitForChild("ClaimOre", 3)
end)

local CLAIM_ENEMY_RF = nil
pcall(function()
    CLAIM_ENEMY_RF = SERVICES:WaitForChild("CodexService", 5):WaitForChild("RF", 3):WaitForChild("ClaimEnemy", 3)
end)

local CLAIM_EQUIPMENT_RF = nil
pcall(function()
    CLAIM_EQUIPMENT_RF = SERVICES:WaitForChild("CodexService", 5):WaitForChild("RF", 3):WaitForChild("ClaimEquipment", 3)
end)

if DEBUG_MODE then
    print("📡 المطالبة بالخامة: " .. (CLAIM_ORE_RF and "✅" or "❌"))
    print("📡 مطالبة العدو: " .. (CLAIM_ENEMY_RF and "✅" or "❌"))
    print("📡 مطالبة المعدات: " .. (CLAIM_EQUIPMENT_RF and "✅" or "❌"))
end

----------------------------------------------------------------
-- الحصول على واجهة الفهرس
----------------------------------------------------------------
local function getIndexUI()
    local indexUI = playerGui:FindFirstChild("Menu")
                   and playerGui.Menu:FindFirstChild("Frame")
                   and playerGui.Menu.Frame:FindFirstChild("Frame")
                   and playerGui.Menu.Frame.Frame:FindFirstChild("Menus")
                   and playerGui.Menu.Frame.Frame.Menus:FindFirstChild("Index")
    
    if indexUI then
        return indexUI
    else
        -- فحص احتياطي (من TestClaim.lua)
        if DEBUG_MODE then
            print("   ❌ واجهة الفهرس غير موجودة! جارٍ التحقق من المسار...")
            local menu = playerGui:FindFirstChild("Menu")
            print("   - القائمة: " .. (menu and "✅" or "❌"))
            if menu then
                local frame1 = menu:FindFirstChild("Frame")
                print("   - القائمة.الإطار: " .. (frame1 and "✅" or "❌"))
                if frame1 then
                    local frame2 = frame1:FindFirstChild("Frame")
                    print("   - القائمة.الإطار.الإطار: " .. (frame2 and "✅" or "❌"))
                    if frame2 then
                        local menus = frame2:FindFirstChild("Menus")
                        print("   - القائمة.الإطار.الإطار.القوائم: " .. (menus and "✅" or "❌"))
                        if menus then
                            local index = menus:FindFirstChild("Index")
                            print("   - القائمة.الإطار.الإطار.القوائم.الفهرس: " .. (index and "✅" or "❌"))
                        end
                    end
                end
            end
        end
        return nil
    end
end

----------------------------------------------------------------
-- دوال المطالبة
----------------------------------------------------------------
local function claimOre(oreName)
    if not CLAIM_ORE_RF then return false end
    
    local success, result = pcall(function()
        return CLAIM_ORE_RF:InvokeServer(oreName)
    end)
    
    if success then
        print(string.format("   🪨 تمت المطالبة: %s | النتيجة: %s", oreName, tostring(result)))
        return true
    else
        warn(string.format("   ❌ فشل في المطالبة بـ %s: %s", oreName, tostring(result)))
    end
    return false
end

local function claimEnemy(enemyName)
    if not CLAIM_ENEMY_RF then return false end
    
    local success, result = pcall(function()
        return CLAIM_ENEMY_RF:InvokeServer(enemyName)
    end)
    
    if success then
        print(string.format("   👹 تمت المطالبة: %s | النتيجة: %s", enemyName, tostring(result)))
        return true
    else
        warn(string.format("   ❌ فشل في المطالبة بـ %s: %s", enemyName, tostring(result)))
    end
    return false
end

local function claimEquipment(equipmentName)
    if not CLAIM_EQUIPMENT_RF then return false end
    
    local success, result = pcall(function()
        return CLAIM_EQUIPMENT_RF:InvokeServer(equipmentName)
    end)
    
    if success then
        print(string.format("   ⚔️ تمت المطالبة: %s | النتيجة: %s", equipmentName, tostring(result)))
        return true
    else
        warn(string.format("   ❌ فشل في المطالبة بـ %s: %s", equipmentName, tostring(result)))
    end
    return false
end

----------------------------------------------------------------
-- الدالة الرئيسية للمطالبة (فحص واجهة المستخدم)
----------------------------------------------------------------
local function claimAllIndex()
    local totalClaimed = 0
    
    local indexUI = getIndexUI()
    if not indexUI then
        if DEBUG_MODE then warn("❌ واجهة الفهرس غير موجودة!") end
        return false
    end
    
    local pages = indexUI:FindFirstChild("Pages")
    if not pages then
        if DEBUG_MODE then warn("❌ الصفحات غير موجودة!") end
        return false
    end
    
    if DEBUG_MODE then
        print("\n📂 الصفحات الموجودة:")
        for _, page in ipairs(pages:GetChildren()) do
            print("   - " .. page.Name)
        end
    end
    
    -- 1. مطالبة الخامات
    local oresPage = pages:FindFirstChild("Ores")
    if oresPage then
        if DEBUG_MODE then print("\n🪨 جارٍ فحص صفحة الخامات...") end
        local oreCount = 0
        for _, child in ipairs(oresPage:GetChildren()) do
            if string.find(child.Name, "List$") then
                for _, oreItem in ipairs(child:GetChildren()) do
                    if oreItem:IsA("Frame") or oreItem:IsA("GuiObject") then
                        oreCount = oreCount + 1
                        local main = oreItem:FindFirstChild("Main")
                        if main then
                            local claim = main:FindFirstChild("Claim")
                            if claim then
                                if DEBUG_MODE then print("      ✅ قابل للمطالبة: " .. oreItem.Name) end
                                if claimOre(oreItem.Name) then
                                    totalClaimed = totalClaimed + 1
                                end
                                task.wait(QUEST_CONFIG.CLAIM_DELAY)
                            end
                        end
                    end
                end
            end
        end
        if DEBUG_MODE then print("   📊 تم فحص " .. oreCount .. " خامات.") end
    else
        if DEBUG_MODE then warn("   ❌ صفحة الخامات غير موجودة") end
    end
    
    -- 2. مطالبة الأعداء
    local enemiesPage = pages:FindFirstChild("Enemies")
    if enemiesPage then
        local scrollFrame = enemiesPage:FindFirstChild("ScrollingFrame")
        if scrollFrame then
            if DEBUG_MODE then print("\n👹 جارٍ فحص صفحة الأعداء...") end
            local enemyCount = 0
            for _, child in ipairs(scrollFrame:GetChildren()) do
                if string.find(child.Name, "List$") then
                    for _, enemyItem in ipairs(child:GetChildren()) do
                        if enemyItem:IsA("Frame") or enemyItem:IsA("GuiObject") then
                            enemyCount = enemyCount + 1
                            local main = enemyItem:FindFirstChild("Main")
                            if main then
                                local claim = main:FindFirstChild("Claim")
                                if claim then
                                    if DEBUG_MODE then print("      ✅ قابل للمطالبة: " .. enemyItem.Name) end
                                    if claimEnemy(enemyItem.Name) then
                                        totalClaimed = totalClaimed + 1
                                    end
                                    task.wait(QUEST_CONFIG.CLAIM_DELAY)
                                end
                            end
                        end
                    end
                end
            end
            if DEBUG_MODE then print("   📊 تم فحص " .. enemyCount .. " أعداء.") end
        else
             if DEBUG_MODE then warn("   ❌ إطار التمرير للأعداء غير موجود") end
        end
    else
        if DEBUG_MODE then warn("   ❌ صفحة الأعداء غير موجودة") end
    end
    
    -- 3. مطالبة المعدات
    local equipPage = pages:FindFirstChild("Equipments")
    if equipPage then
        local scrollFrame = equipPage:FindFirstChild("ScrollingFrame")
        if scrollFrame then
            if DEBUG_MODE then print("\n⚔️ جارٍ فحص صفحة المعدات...") end
            local equipCount = 0
            for _, child in ipairs(scrollFrame:GetChildren()) do
                if string.find(child.Name, "List$") then
                    for _, equipItem in ipairs(child:GetChildren()) do
                        if equipItem:IsA("Frame") or equipItem:IsA("GuiObject") then
                            equipCount = equipCount + 1
                            local main = equipItem:FindFirstChild("Main")
                            if main then
                                local claim = main:FindFirstChild("Claim")
                                if claim then
                                    if DEBUG_MODE then print("      ✅ قابل للمطالبة: " .. equipItem.Name) end
                                    if claimEquipment(equipItem.Name) then
                                        totalClaimed = totalClaimed + 1
                                    end
                                    task.wait(QUEST_CONFIG.CLAIM_DELAY)
                                end
                            end
                        end
                    end
                end
            end
            if DEBUG_MODE then print("   📊 تم فحص " .. equipCount .. " معدات.") end
        else
            if DEBUG_MODE then warn("   ❌ إطار التمرير للمعدات غير موجود") end
        end
    else
        if DEBUG_MODE then warn("   ❌ صفحة المعدات غير موجودة") end
    end
    
    return totalClaimed > 0
end

----------------------------------------------------------------
-- التنفيذ
----------------------------------------------------------------
-- تنفيذ صامت (بدون إزعاج في الكونسول)
local success = claimAllIndex()
Quest15Active = false