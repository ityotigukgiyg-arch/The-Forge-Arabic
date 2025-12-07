--[[
    🔥 The Forge Script - واجهة رسومية عربية متقدمة (GUI)
    
    هذه الواجهة مصممة خصيصًا للجوال وتتحكم في جميع وظائف السكربت.
    
    المميزات:
    1. التحكم في تشغيل/إيقاف السكربت الرئيسي.
    2. التحكم في إعدادات FPS Booster.
    3. التحكم في نظام Anti-AFK.
    4. تشغيل المهام المتقدمة (Auto Sell, Auto Buy, Auto Claim Index) بشكل يدوي.
    5. عرض حالة السكربت.
--]]

local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/wally-rblx/LinoriaLib/main/Library.lua"))()

local Window = Library:CreateWindow({
    Title = "🔥 The Forge Script - النسخة العربية",
    Center = true,
    AutoShow = true,
})

-- ==================================================================================
-- ⚙️ الإعدادات العامة (General Settings)
-- ==================================================================================
local GeneralTab = Window:AddTab("الإعدادات العامة")

-- 1. التحكم في السكربت الرئيسي
local MainSection = GeneralTab:AddSection("التحكم الرئيسي")

local MainToggle = MainSection:AddToggle("تشغيل/إيقاف السكربت", {
    Default = false,
    Callback = function(value)
        if value then
            -- يتم تشغيل السكربت الرئيسي (Loader.lua) هنا
            -- يجب أن يكون Loader.lua قد تم تحميله مسبقًا أو يتم تحميله عند التشغيل
            -- في هذا المثال، سنفترض أن السكربت الرئيسي يعمل في الخلفية ويستجيب لمتغيرات _G
            _G.TheForge_MainScript_Enabled = true
            print("✅ تم تشغيل السكربت الرئيسي.")
        else
            _G.TheForge_MainScript_Enabled = false
            print("❌ تم إيقاف السكربت الرئيسي.")
        end
    end
})

-- 2. نظام منع الخمول (Anti-AFK)
local AntiAFKSection = GeneralTab:AddSection("نظام منع الخمول (Anti-AFK)")

local AntiAFKToggle = AntiAFKSection:AddToggle("تفعيل Anti-AFK", {
    Default = true,
    Callback = function(value)
        _G.TheForge_AntiAFK_Enabled = value
        print("🛡️ Anti-AFK: " .. (value and "مفعل" or "معطل"))
    end
})

AntiAFKSection:AddSlider("فاصل زمني (ثانية)", {
    Default = 120,
    Min = 30,
    Max = 300,
    Rounding = 0,
    Callback = function(value)
        _G.TheForge_AntiAFK_Interval = value
    end
})

-- ==================================================================================
-- 🚀 تحسين الأداء (FPS Booster)
-- ==================================================================================
local FPSTab = Window:AddTab("تحسين الأداء")

FPSTab:AddSection("إعدادات الرسوميات")

FPSTab:AddToggle("تقليل جودة الرسوميات", {
    Default = true,
    Callback = function(value)
        _G.TheForge_FPS_LowerQuality = value
    end
})

FPSTab:AddToggle("إلغاء الظلال", {
    Default = true,
    Callback = function(value)
        _G.TheForge_FPS_DisableShadows = value
    end
})

FPSTab:AddToggle("إلغاء المؤثرات (Particles)", {
    Default = true,
    Callback = function(value)
        _G.TheForge_FPS_DisableParticles = value
    end
})

FPSTab:AddToggle("وضع الشاشة السوداء (أقصى أداء)", {
    Default = false,
    Callback = function(value)
        _G.TheForge_FPS_BlackScreenMode = value
    end
})

FPSTab:AddButton("تطبيق إعدادات FPS", function()
    -- يتم استدعاء وظيفة تطبيق الإعدادات من FPSBooster.lua
    if _G.TheForge_ApplyFPS then
        _G.TheForge_ApplyFPS()
        print("✅ تم تطبيق إعدادات تحسين الأداء.")
    else
        warn("❌ لم يتم تحميل وظيفة تطبيق FPS. تأكد من تحميل FPSBooster.lua.")
    end
end)

-- ==================================================================================
-- 💰 المهام المتقدمة (Advanced Quests)
-- ==================================================================================
local AdvancedTab = Window:AddTab("المهام المتقدمة")

-- 1. التعدين والبيع التلقائي (Quest 19)
local MiningSection = AdvancedTab:AddSection("التعدين والبيع التلقائي")

MiningSection:AddToggle("تفعيل التعدين التلقائي (Quest 19)", {
    Default = false,
    Callback = function(value)
        _G.TheForge_Quest19_Enabled = value
        print("⛏️ التعدين التلقائي: " .. (value and "مفعل" or "معطل"))
    end
})

MiningSection:AddToggle("تفعيل البيع التلقائي للخامات", {
    Default = true,
    Callback = function(value)
        _G.TheForge_Quest19_AutoSell = value
    end
})

MiningSection:AddToggle("تفعيل الشراء التلقائي للفأس", {
    Default = true,
    Callback = function(value)
        _G.TheForge_Quest19_AutoBuyPickaxe = value
    end
})

-- 2. استلام مكافآت الإنجازات (Quest 15)
local IndexSection = AdvancedTab:AddSection("استلام مكافآت الإنجازات (Codex)")

IndexSection:AddButton("تشغيل استلام المكافآت الآن", function()
    -- يتم استدعاء وظيفة تشغيل Quest 15 يدويًا
    if _G.TheForge_RunQuest15 then
        _G.TheForge_RunQuest15()
        print("💰 جاري استلام مكافآت الإنجازات...")
    else
        warn("❌ لم يتم تحميل وظيفة Quest 15. تأكد من تحميل Loader.lua.")
    end
end)

-- ==================================================================================
-- 📊 حالة السكربت (Status)
-- ==================================================================================
local StatusTab = Window:AddTab("حالة السكربت")

local StatusLabel = StatusTab:AddLabel("الحالة: متوقف")

-- تحديث حالة السكربت بشكل دوري
task.spawn(function()
    while task.wait(1) do
        local status = "الحالة: "
        if _G.TheForge_MainScript_Enabled then
            status = status .. "✅ يعمل"
            if _G.TheForge_CurrentQuest then
                status = status .. " | المهمة الحالية: " .. _G.TheForge_CurrentQuest
            end
        else
            status = status .. "❌ متوقف"
        end
        
        StatusLabel:Set(status)
    end
end)

-- ==================================================================================
-- 🧹 التنظيف (Cleanup)
-- ==================================================================================
Library:OnUnload(function()
    -- إيقاف السكربت الرئيسي عند إغلاق الواجهة
    _G.TheForge_MainScript_Enabled = false
    print("🧹 تم إيقاف السكربت وتنظيفه.")
end)

-- تهيئة المتغيرات العامة (يجب أن يتم استخدامها في Loader.lua و FPSBooster.lua)
_G.TheForge_MainScript_Enabled = false
_G.TheForge_AntiAFK_Enabled = true
_G.TheForge_AntiAFK_Interval = 120
_G.TheForge_FPS_LowerQuality = true
_G.TheForge_FPS_DisableShadows = true
_G.TheForge_FPS_DisableParticles = true
_G.TheForge_FPS_BlackScreenMode = false
_G.TheForge_Quest19_Enabled = false
_G.TheForge_Quest19_AutoSell = true
_G.TheForge_Quest19_AutoBuyPickaxe = true
_G.TheForge_CurrentQuest = "لا يوجد"
