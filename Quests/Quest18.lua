local Shared = _G.Shared

-- المهمة 18: النقل الذكي إلى المملكة المنسية
-- ✅ التحقق مما إذا كان اللاعب على الجزيرة 1
-- ✅ إذا كان على الجزيرة 1 → النقل إلى المملكة المنسية (الجزيرة 2)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

----------------------------------------------------------------
-- الإعدادات
----------------------------------------------------------------
local Quest18Active = true

local QUEST_CONFIG = {
    QUEST_NAME = "النقل الذكي",
    REQUIRED_LEVEL = 10,
    ISLAND_NAME = "المملكة المنسية",
}

----------------------------------------------------------------
-- إعداد Knit
----------------------------------------------------------------
local KnitPackage = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Knit")
local Knit = require(KnitPackage)

if not Knit.OnStart then 
    pcall(function() Knit.Start():await() end)
end

local SERVICES = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Services")

local PORTAL_RF = nil
pcall(function()
    PORTAL_RF = SERVICES:WaitForChild("PortalService", 5):WaitForChild("RF", 3):WaitForChild("TeleportToIsland", 3)
end)

local FORGES_FOLDER = Workspace:WaitForChild("Forges")

if PORTAL_RF then print("✅ بوابة التحكم جاهزة!") else warn("⚠️ لم يتم العثور على بوابة التحكم") end

----------------------------------------------------------------
-- نظام المستويات
----------------------------------------------------------------
local function getPlayerLevel()
    local levelLabel = playerGui:FindFirstChild("Main")
                      and playerGui.Main:FindFirstChild("Screen")
                      and playerGui.Main.Screen:FindFirstChild("Hud")
                      and playerGui.Main.Screen.Hud:FindFirstChild("Level")
    
    if not levelLabel or not levelLabel:IsA("TextLabel") then
        return nil
    end
    
    local levelText = levelLabel.Text
    local level = tonumber(string.match(levelText, "%d+"))
    
    return level
end

local function hasRequiredLevel()
    local level = getPlayerLevel()
    
    if not level then
        warn("   ❌ لا يمكن تحديد المستوى!")
        return false
    end
    
    if level >= QUEST_CONFIG.REQUIRED_LEVEL then
        print(string.format("   ✅ المستوى %d >= %d", level, QUEST_CONFIG.REQUIRED_LEVEL))
        return true
    else
        print(string.format("   ⏸️  المستوى %d < %d", level, QUEST_CONFIG.REQUIRED_LEVEL))
        return false
    end
end

----------------------------------------------------------------
-- كشف الجزيرة الحالية
----------------------------------------------------------------
local function getCurrentIsland()
    for _, child in ipairs(FORGES_FOLDER:GetChildren()) do
        if child:IsA("Folder") or child:IsA("Model") then
            if string.match(child.Name, "Island%d+") then
                return child.Name
            end
        end
    end
    return nil
end

local function needsTeleport()
    local currentIsland = getCurrentIsland()
    
    if not currentIsland then
        return true
    end
    
    if currentIsland == "Island1" then
        print(string.format("   ✅ على %s → بحاجة للنقل!", currentIsland))
        return true
    elseif currentIsland == "Island2" then
        print(string.format("   ✅ على %s → بالفعل على الهدف!", currentIsland))
        return false
    else
        warn(string.format("   ⚠️ غير معروف: %s", currentIsland))
        return true
    end
end

----------------------------------------------------------------
-- نظام النقل
----------------------------------------------------------------
local function teleportToIsland(islandName)
    if not PORTAL_RF then
        warn("   ❌ بوابة التحكم غير متوفرة!")
        return false
    end
    
    print(string.format("   🌀 جاري النقل إلى: %s", islandName))
    
    local args = {islandName}
    
    local success, result = pcall(function()
        return PORTAL_RF:InvokeServer(unpack(args))
    end)
    
    if success then
        print(string.format("   ✅ تم النقل إلى: %s", islandName))
        return true
    else
        warn(string.format("   ❌ فشل: %s", tostring(result)))
        return false
    end
end

----------------------------------------------------------------
-- مشغل المهمة الذكي
----------------------------------------------------------------
print(string.rep("=", 50))
print("🚀 المهمة 18: " .. QUEST_CONFIG.QUEST_NAME)
print("🎯 الهدف: النقل إلى المملكة المنسية")
print(string.rep("=", 50))

-- التحقق من المستوى
print("\n🔍 التحقق المسبق: التحقق من متطلبات المستوى...")
if not hasRequiredLevel() then
    print("\n❌ لم يتم استيفاء متطلبات المستوى!")
    print(string.rep("=", 50))
    return
end

-- التحقق مما إذا كان النقل مطلوبًا
print("\n🔍 التحقق من الموقع...")
if needsTeleport() then
    print("   ⚠️ غير موجود على الجزيرة الهدف!")
    local success = teleportToIsland(QUEST_CONFIG.ISLAND_NAME)
    
    if success then
        print("\n" .. string.rep("=", 50))
        print("✅ المهمة 18 مكتملة! تم النقل إلى المملكة المنسية!")
        print(string.rep("=", 50))
    else
        print("\n" .. string.rep("=", 50))
        print("❌ فشلت المهمة 18! لم يتمكن من النقل!")
        print(string.rep("=", 50))
    end
else
    print("\n" .. string.rep("=", 50))
    print("✅ المهمة 18 مكتملة! بالفعل على الجزيرة الهدف!")
    print(string.rep("=", 50))
end

Quest18Active = false