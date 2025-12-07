--[[
    🔥 The Forge Script - محمل النسخة العربية مع واجهة رسومية (GUI)
    
    الاستخدام: loadstring(game:HttpGet("YOUR_GITHUB_RAW_URL/Loader_Arabic.lua"))()
    
    هذا الملف يقوم بتحميل:
    1. الواجهة الرسومية (GUI.lua)
    2. ملفات السكربت المترجمة (Loader.lua, Shared.lua, Utils/FPSBooster.lua, Quests/*.lua)
    
    ملاحظة: يجب تعديل GITHUB_BASE_URL بعد رفع الملفات إلى مستودعك.
--]]

local GITHUB_BASE_URL = "https://raw.githubusercontent.com/ityotigukgiyg-arch/The-Forge-Arabic/main/" -- **يجب تغيير هذا الرابط إلى رابط مستودعك**

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
print("🔥 THE FORGE SCRIPT - محمل النسخة العربية")
print("=" .. string.rep("=", 59))

-- 1. تحميل الواجهة الرسومية (GUI)
print("\n🎨 جاري تحميل الواجهة الرسومية (GUI.lua)...")
loadScript("GUI.lua")

-- 2. تحميل ملفات المرافق المشتركة (Shared Utilities)
print("\n📦 جاري تحميل المرافق المشتركة (Shared.lua)...")
loadScript("Shared.lua")

-- 3. تحميل السكربت الرئيسي (Loader.lua)
-- هذا الملف يحتوي على منطق تشغيل المهام التلقائي
print("\n🎮 جاري تحميل السكربت الرئيسي (Loader.lua)...")
loadScript("Loader.lua")

print("\n🎉 اكتمل التحميل. يمكنك الآن استخدام الواجهة الرسومية.")
