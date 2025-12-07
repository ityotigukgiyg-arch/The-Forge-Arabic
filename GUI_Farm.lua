--[[
    🎨 The Forge Script - واجهة رسومية مخصصة للمزرعة (Farm GUI)
    
    الاستخدام: يتم تحميلها بواسطة Loader_Farm.lua
    
    تعتمد على مكتبة LinoriaLib (يجب أن تكون محملة مسبقاً)
--]]

local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/wally-rblx/LinoriaLib/main/Library.lua"))()

-- ==================================================================================
-- 🖼️ إعداد الواجهة
-- ==================================================================================
local Window = Library:CreateWindow({
    Title = "🔥 The Forge - المزرعة التلقائية (Farm)",
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    Side = "Left",
    Theme = Library.Themes.Midnight
})

-- ==================================================================================
-- ⚙️ التحكم الرئيسي
-- ==================================================================================
local MainTab = Window:AddTab("التحكم الرئيسي")

MainTab:AddSection("تشغيل/إيقاف")

MainTab:AddToggle("تشغيل/إيقاف المزرعة التلقائية", {
    Default = false,
    Callback = function(value)
        if value then
            Shared.startAutoFarm()
        else
            Shared.stopAutoFarm()
        end
    end
})

MainTab:AddLabel("حالة المزرعة: ")
    :AddParagraph("متوقفة", true)
    :Set("حالة المزرعة: متوقفة")
    :Name("FarmStatusLabel")

-- ==================================================================================
-- ⚔️ إعدادات القتال
-- ==================================================================================
local CombatTab = Window:AddTab("القتال والتعدين")

CombatTab:AddSection("قتال الزومبي")

CombatTab:AddToggle("تفعيل قتل الزومبي التلقائي", {
    Default = false,
    Callback = function(value)
        _G.TheForge_Farm_KillZombies = value
    end
})

CombatTab:AddSection("التعدين")

CombatTab:AddToggle("تفعيل التعدين التلقائي", {
    Default = false,
    Callback = function(value)
        _G.TheForge_Farm_MineRocks = value
    end
})

-- ==================================================================================
-- 💰 إعدادات الاقتصاد
-- ==================================================================================
local EconomyTab = Window:AddTab("الاقتصاد التلقائي")

EconomyTab:AddSection("البيع والشراء")

EconomyTab:AddToggle("تفعيل البيع التلقائي للخامات", {
    Default = false,
    Callback = function(value)
        _G.TheForge_Farm_AutoSell = value
    end
})

EconomyTab:AddToggle("تفعيل الشراء التلقائي للفؤوس", {
    Default = false,
    Callback = function(value)
        _G.TheForge_Farm_AutoBuy = value
    end
})

-- ==================================================================================
-- 🛡️ إعدادات إضافية
-- ==================================================================================
local ExtraTab = Window:AddTab("إضافات")

ExtraTab:AddSection("مكافحة الخمول")

ExtraTab:AddToggle("تفعيل مكافحة الخمول (Anti-AFK)", {
    Default = true,
    Callback = function(value)
        _G.TheForge_AntiAFK_Enabled = value
    end
})

ExtraTab:AddSlider("فاصل مكافحة الخمول (ثانية)", {
    Default = 120,
    Min = 30,
    Max = 300,
    Rounding = 0,
    Callback = function(value)
        _G.TheForge_AntiAFK_Interval = value
    end
})

-- ==================================================================================
-- 🔄 تحديث الحالة (يتم استدعاؤها من AutoFarm.lua)
-- ==================================================================================
function Shared.updateFarmStatus(status)
    local label = Library.Elements.FarmStatusLabel
    if label then
        label:Set("حالة المزرعة: " .. status)
    end
end

-- تهيئة المتغيرات العامة (يجب أن يتم استخدامها في Loader.lua و AutoFarm.lua)
_G.TheForge_AntiAFK_Enabled = true
_G.TheForge_AntiAFK_Interval = 120

print("✅ تم تحميل GUI_Farm.lua")
