--[[
    🔥 The Forge Script - Auto Farm (التعدين التلقائي وقتل الزومبي)
    
    الاستخدام: يتم تحميله بواسطة Loader_Farm.lua
    
    هذا الملف يجمع منطق التعدين المتقدم وقتل الزومبي من مهام مختلفة.
--]]

local Shared = _G.Shared
local Services = Shared.Services
local Knit = Shared.Knit
local player = Services.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Workspace = Services.Workspace
local RunService = Services.RunService

-- المتغيرات العامة للتحكم من الواجهة الرسومية
_G.TheForge_Farm_KillZombies = _G.TheForge_Farm_KillZombies or false
_G.TheForge_Farm_MineRocks = _G.TheForge_Farm_MineRocks or false
_G.TheForge_Farm_AutoSell = _G.TheForge_Farm_AutoSell or false
_G.TheForge_Farm_AutoBuy = _G.TheForge_Farm_AutoBuy or false

-- إعدادات ثابتة (مستخلصة من Quest05 و Quest19)
local CONFIG = {
    ZOMBIE_MAX_DISTANCE = 50,
    LAYING_ANGLE = 90,
    MOVE_SPEED = 25,
    STOP_DISTANCE = 2,
    UNDERGROUND_OFFSET = 4,
    ZOMBIE_UNDERGROUND_OFFSET = 5,
    
    -- إعدادات البيع والشراء التلقائي (من Quest19)
    AUTO_SELL_NPC_NAME = "Greedy Cey",
    AUTO_SELL_INTERVAL = 10,
    TARGET_PICKAXE = "Cobalt Pickaxe",
    MIN_GOLD_TO_BUY = 10000,
    SHOP_POSITION = Vector3.new(-165, 22, -111.7), -- متجر الكوبالت
    
    -- إعدادات فأس الماجما (من Quest19)
    MAGMA_PICKAXE_CONFIG = {
        TARGET_PICKAXE = "Magma Pickaxe",
        MIN_GOLD_TO_BUY = 150000,
        SELL_SHOP_POSITION = Vector3.new(-115.1, 22.3, -92.3),
        BUY_SHOP_POSITION = Vector3.new(378, 88.6, 109.6),
    },
}

-- المتغيرات الداخلية للحالة
local State = {
    isPaused = false,
    autoSellTask = nil,
    autoBuyTask = nil,
    mainLoopTask = nil,
}

-- ==================================================================================
-- 🛠️ دوال مساعدة (مستخلصة من Quest05 و Quest19)
-- ==================================================================================

-- [من Quest05]
local function getBestWeapon()
    -- ... (منطق استخراج أفضل سلاح) ...
    -- سيتم تبسيطها لاحقاً
    return nil -- تبسيط مؤقت
end

-- [من Quest05]
local function isZombieValid(zombie)
    return zombie and zombie.Parent and zombie:FindFirstChild("Humanoid") and zombie.Humanoid.Health > 0
end

-- [من Quest05]
local function findNearestZombie()
    -- ... (منطق البحث عن أقرب زومبي) ...
    return nil, math.huge -- تبسيط مؤقت
end

-- [من Quest05]
local function getZombieUndergroundPosition(zombie)
    -- ... (منطق الحصول على موقع الزومبي تحت الأرض) ...
    return nil -- تبسيط مؤقت
end

-- [من Quest05]
local function getZombieHP(zombie)
    -- ... (منطق الحصول على نقاط صحة الزومبي) ...
    return 0 -- تبسيط مؤقت
end

-- [من Quest19]
local function getGold()
    -- ... (منطق الحصول على الذهب) ...
    return 0 -- تبسيط مؤقت
end

-- [من Quest19]
local function hasPickaxe(pickaxeName)
    -- ... (منطق التحقق من وجود فأس) ...
    return false -- تبسيط مؤقت
end

-- [من Quest19]
local function purchasePickaxe(pickaxeName)
    -- ... (منطق شراء فأس) ...
    return false -- تبسيط مؤقت
end

-- [من Quest19]
local function sellAllNonEquippedItems()
    -- ... (منطق بيع جميع العناصر غير المجهزة) ...
end

-- [من Quest19]
local function tryBuyMagmaPickaxe()
    -- ... (منطق شراء فأس الماجما) ...
    return false -- تبسيط مؤقت
end

-- [من Quest19]
local function findNearestRock()
    -- ... (منطق البحث عن أقرب صخرة) ...
    return nil, math.huge -- تبسيط مؤقت
end

-- [من Quest19]
local function getRockUndergroundPosition(rock)
    -- ... (منطق الحصول على موقع الصخرة تحت الأرض) ...
    return nil -- تبسيط مؤقت
end

-- [من Quest19]
local function getRockHP(rock)
    -- ... (منطق الحصول على نقاط صحة الصخرة) ...
    return 0 -- تبسيط مؤقت
end

-- [من Quest19]
local function watchRockHP(rock)
    -- ... (منطق مراقبة نقاط صحة الصخرة) ...
end

-- [من Quest19]
local function watchZombieHP(zombie)
    -- ... (منطق مراقبة نقاط صحة الزومبي) ...
end

-- ==================================================================================
-- ⚔️ وظيفة قتل الزومبي (Auto Kill Zombies)
-- ==================================================================================
local function doKillZombies()
    -- ... (منطق قتل الزومبي) ...
end

-- ==================================================================================
-- ⛏️ وظيفة التعدين (Auto Mining)
-- ==================================================================================
local function doMineRocks()
    -- ... (منطق التعدين) ...
end

-- ==================================================================================
-- 💰 وظيفة البيع التلقائي (Auto Sell)
-- ==================================================================================
local function startAutoSellTask()
    -- ... (منطق البيع التلقائي) ...
end

-- ==================================================================================
-- 🛒 وظيفة الشراء التلقائي (Auto Buy)
-- ==================================================================================
local function startAutoBuyTask()
    -- ... (منطق الشراء التلقائي) ...
end

-- ==================================================================================
-- 🔄 المشغل الرئيسي
-- ==================================================================================
local function runFarmLoop()
    -- ... (الحلقة الرئيسية) ...
end

-- ==================================================================================
-- 🚀 وظيفة التشغيل/الإيقاف العامة
-- ==================================================================================
function Shared.startAutoFarm()
    -- ... (منطق بدء التشغيل) ...
end

function Shared.stopAutoFarm()
    -- ... (منطق الإيقاف) ...
end

print("✅ تم تحميل AutoFarm.lua (النسخة المبسطة)")
