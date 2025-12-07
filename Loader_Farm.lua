--[[
    🔥 The Forge Script - محمل المزرعة التلقائية (Farm Loader)
    
    الاستخدام: loadstring(game:HttpGet("YOUR_GITHUB_RAW_URL/Loader_Farm.lua"))()
    
    هذا الملف يقوم بتحميل:
    1. مكتبة LinoriaLib (لإنشاء الواجهة الرسومية)
    2. الأدوات المشتركة (Shared.lua)
    3. الواجهة الرسومية المخصصة (GUI_Farm.lua)
    4. سكربت المزرعة التلقائية (AutoFarm.lua)
    
    ملاحظة: يجب تعديل GITHUB_BASE_URL بعد رفع الملفات إلى مستودعك.
--]]

local GITHUB_BASE_URL = "https://raw.githubusercontent.com/ityotigukgiyg-arch/The-Forge-Arabic/main/" -- **رابط مستودعك**

local function httpGet(file)
    -- إضافة متغير عشوائي (Cache Buster) لضمان تحميل أحدث نسخة
    local cacheBuster = math.random(100000, 999999)
    local url = GITHUB_BASE_URL .. file .. "?t=" .. tostring(tick()) .. "&cb=" .. tostring(cacheBuster)
    local success, result = pcall(function()
        return game:HttpGet(url)
    end)
    
    if success then
        return result
    else
        warn("❌ فشل تحميل الملف: " .. file .. " | الخطأ: " .. tostring(result))
        return nil
    end
end

local function loadScript(file)
    local code = httpGet(file)
    if code then
        local success, result = pcall(function()
            loadstring(code)()
        end)
        
        if success then
            print("✅ تم تحميل: " .. file)
            return true
        else
            warn("❌ فشل تنفيذ السكربت: " .. file .. " | الخطأ: " .. tostring(result))
            return false
        end
    end
    return false
end

print("=" .. string.rep("=", 59))
print("🔥 THE FORGE - محمل المزرعة التلقائية")
print("=" .. string.rep("=", 59))

-- 1. تحميل الأدوات المشتركة (Shared.lua)
print("\n📦 جاري تحميل الأدوات المشتركة (Shared.lua)...")
loadScript("Shared.lua")

-- 2. تحميل الواجهة الرسومية (GUI_Farm.lua)
print("\n🎨 جاري تحميل الواجهة الرسومية (GUI_Farm.lua)...")
loadScript("GUI_Farm.lua")

-- 3. تحميل سكربت المزرعة التلقائية (AutoFarm.lua)
print("\n🚜 جاري تحميل سكربت المزرعة التلقائية (AutoFarm.lua)...")
loadScript("AutoFarm.lua")

print("\n🎉 اكتمل التحميل. يمكنك الآن استخدام الواجهة الرسومية.")
