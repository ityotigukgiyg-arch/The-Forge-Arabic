--[[
    ████████╗██╗  ██╗███████╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
    ╚══██╔══╝██║  ██║██╔════╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
       ██║   ███████║█████╗      █████╗  ██║   ██║██████╔╝██║  ███╗█████╗  
       ██║   ██╔══██║██╔══╝      ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝  
       ██║   ██║  ██║███████╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
       ╚═╝   ╚═╝  ╚═╝╚══════╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
    
    🔥 محمل المهام المعياري
    📦 يقوم بتحميل المهام تلقائيًا من GitHub بناءً على اكتشاف المهمة النشطة
    
    الاستخدام: loadstring(game:HttpGet("YOUR_GITHUB_RAW_URL/Loader.lua"))()
--]]

repeat task.wait(1) until game:IsLoaded()

----------------------------------------------------------------
-- ⚙️ الإعدادات
----------------------------------------------------------------
local CONFIG = {
    -- 🔗 رابط GitHub Raw (غيره إلى رابطك)
    GITHUB_BASE_URL = "https://raw.githubusercontent.com/talnw1123/The-Forge-Script2/refs/heads/main/",
    
    -- ⏱️ التوقيت
    INITIAL_WAIT = 150,          -- وقت الانتظار الابتدائي (بالثواني)
    QUEST_CHECK_INTERVAL = 2,    -- التحقق من المهمة الجديدة كل كم ثانية
    
    -- 🎮 نطاق المهام
    MIN_QUEST = 1,
    MAX_QUEST = 19,  -- تم التحديث: 1-18 للجزيرة 1، 19 للجزيرة 2
    
    -- 🔧 التصحيح
    DEBUG_MODE = true,
    
    -- 🚀 تحسين الأداء
    
    -- 🛡️ نظام مكافحة الخمول
    ANTI_AFK_ENABLED = true,
    ANTI_AFK_INTERVAL = 120,   -- كل دقيقتين
    ANTI_AFK_CLICK_COUNT = 5,  -- عدد النقرات في كل دورة
}

----------------------------------------------------------------
-- 📦 تحميل الأدوات المشتركة
----------------------------------------------------------------
print("=" .. string.rep("=", 59))
print("🔥 THE FORGE - محمل المهام المعياري")
print("=" .. string.rep("=", 59))

print("\n⏳ الانتظار الابتدائي: " .. CONFIG.INITIAL_WAIT .. " ثانية...")
task.wait(CONFIG.INITIAL_WAIT)

print("\n📦 جاري تحميل الأدوات المشتركة...")
local sharedUrl = CONFIG.GITHUB_BASE_URL .. "Shared.lua"
local sharedSuccess, sharedError = pcall(function()
    loadstring(game:HttpGet(sharedUrl))()
end)

if not sharedSuccess then
    warn("❌ فشل تحميل Shared.lua: " .. tostring(sharedError))
    warn("💡 تأكد من صحة الرابط: " .. sharedUrl)
    return
end

print("✅ تم تحميل الأدوات المشتركة!")

-- التحقق من تحميل Shared بنجاح
if not _G.Shared then
    warn("❌ لم يتم العثور على _G.Shared بعد تحميل Shared.lua")
    return
end

local Shared = _G.Shared

----------------------------------------------------------------
-- 🔍 نظام اكتشاف المهام
----------------------------------------------------------------
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Workspace = game:GetService("Workspace")

-- 🌍 اكتشاف الجزيرة
local FORGES_FOLDER = Workspace:WaitForChild("Forges", 10)

local function getCurrentIsland()
    if not FORGES_FOLDER then
        return nil
    end
    
    for _, child in ipairs(FORGES_FOLDER:GetChildren()) do
        if child:IsA("Folder") or child:IsA("Model") then
            local islandMatch = string.match(child.Name, "Island(%d+)")
            if islandMatch then
                return "Island" .. islandMatch
            end
        end
    end
    return nil
end




----------------------------------------------------------------
-- 🛡️ نظام مكافحة الخمول
----------------------------------------------------------------
if CONFIG.ANTI_AFK_ENABLED then
    local VirtualInputManager = game:GetService("VirtualInputManager")
    local GuiService = game:GetService("GuiService")
    local camera = workspace.CurrentCamera
    
    local function performAntiAfkClicks()
        local viewportSize = camera.ViewportSize
        local guiInset = GuiService:GetGuiInset()
        local centerX = viewportSize.X / 2
        local centerY = (viewportSize.Y / 2) + guiInset.Y
        
        print("🛡️ [مكافحة الخمول] تنفيذ " .. CONFIG.ANTI_AFK_CLICK_COUNT .. " نقرة افتراضية...")
        
        for i = 1, CONFIG.ANTI_AFK_CLICK_COUNT do
            VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, true, game, 1)
            task.wait(0.05)
            VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, false, game, 1)
            
            if i < CONFIG.ANTI_AFK_CLICK_COUNT then
                task.wait(0.5)
            end
        end
        
        print("🛡️ [مكافحة الخمول] انتهت النقرات! التالية بعد " .. CONFIG.ANTI_AFK_INTERVAL .. " ثانية.")
    end
    
    task.spawn(function()
        print("🛡️ [مكافحة الخمول] النظام بدأ! النقر كل " .. CONFIG.ANTI_AFK_INTERVAL .. " ثانية.")
        while true do
            task.wait(CONFIG.ANTI_AFK_INTERVAL)
            pcall(performAntiAfkClicks)
        end
    end)
end


----------------------------------------------------------------
-- 📊 نظام التحقق من المستوى
----------------------------------------------------------------
local function getPlayerLevel()
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return nil end
    
    local levelLabel = gui:FindFirstChild("Main")
                      and gui.Main:FindFirstChild("Screen")
                      and gui.Main.Screen:FindFirstChild("Hud")
                      and gui.Main.Screen.Hud:FindFirstChild("Level")
    
    if not levelLabel or not levelLabel:IsA("TextLabel") then
        return nil
    end
    
    local levelText = levelLabel.Text
    local level = tonumber(string.match(levelText, "%d+"))
    return level
end


----------------------------------------------------------------
-- 📋 التحقق من قائمة المهام الفارغة
----------------------------------------------------------------
local function isQuestListEmpty()
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return false end
    
    local list = gui:FindFirstChild("Main") 
        and gui.Main:FindFirstChild("Screen") 
        and gui.Main.Screen:FindFirstChild("Quests") 
        and gui.Main.Screen.Quests:FindFirstChild("List")
    
    if not list then return false end
    
    -- التحقق إذا كانت القائمة تحتوي فقط على UIListLayout و UIPadding (لا توجد مهام فعلية)
    for _, child in ipairs(list:GetChildren()) do
        if child.Name ~= "UIListLayout" and child.Name ~= "UIPadding" then
            return false  -- تم العثور على عنصر مهمة!
        end
    end
    
    return true  -- فقط UIListLayout و UIPadding = فارغة!
end

local function getActiveQuestNumber()
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return nil end
    
    local list = gui:FindFirstChild("Main") 
        and gui.Main:FindFirstChild("Screen") 
        and gui.Main.Screen:FindFirstChild("Quests") 
        and gui.Main.Screen.Quests:FindFirstChild("List")
    
    if not list then return nil end
    
    -- البحث عن المهمة النشطة
    for _, child in ipairs(list:GetChildren()) do
        local id = string.match(child.Name, "^Introduction(%d+)Title$")
        if id and child:FindFirstChild("Frame") and child.Frame:FindFirstChild("TextLabel") then
            local questName = child.Frame.TextLabel.Text
            local questNum = tonumber(id) + 1
            
            if questNum and questName ~= "" then
                -- التحقق من أن المهمة لم تكتمل بعد
                local objList = list:FindFirstChild("Introduction" .. id .. "List")
                if objList then
                    for _, item in ipairs(objList:GetChildren()) do
                        if item:IsA("Frame") and tonumber(item.Name) then
                            local check = item:FindFirstChild("Main") 
                                and item.Main:FindFirstChild("Frame") 
                                and item.Main.Frame:FindFirstChild("Check")
                            if check and not check.Visible then
                                -- تم العثور على هدف لم يكتمل بعد
                                return questNum, questName
                            end
                        end
                    end
                end
            end
        end
    end
    
    return nil
end

local function isQuestComplete(questNum)
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return true end
    
    local list = gui:FindFirstChild("Main") 
        and gui.Main:FindFirstChild("Screen") 
        and gui.Main.Screen:FindFirstChild("Quests") 
        and gui.Main.Screen.Quests:FindFirstChild("List")
    
    if not list then return true end
    
    -- تحويل رقم المهمة من 1-based إلى 0-based للواجهة
    local uiID = questNum - 1
    local objList = list:FindFirstChild("Introduction" .. uiID .. "List")
    if not objList then return true end
    
    for _, item in ipairs(objList:GetChildren()) do
        if item:IsA("Frame") and tonumber(item.Name) then
            local check = item:FindFirstChild("Main") 
                and item.Main:FindFirstChild("Frame") 
                and item.Main.Frame:FindFirstChild("Check")
            if check and not check.Visible then
                return false
            end
        end
    end
    
    return true
end

----------------------------------------------------------------
-- 📥 محمل المهام
----------------------------------------------------------------
local loadedQuests = {}

local function loadQuest(questNum)
    local questFile = string.format("Quest%02d.lua", questNum)
    local questUrl = CONFIG.GITHUB_BASE_URL .. "Quests/" .. questFile .. "?t=" .. tostring(tick())
    
    -- تخطي السجلات التفصيلية للمهمة 15 (تعمل في الخلفية بشكل متكرر)
    local showLogs = (questNum ~= 15)
    
    if showLogs then
        print(string.format("\n📥 جاري تحميل %s من GitHub...", questFile))
        print("   الرابط: " .. questUrl)
    end
    
    local success, result = pcall(function()
        local code = game:HttpGet(questUrl)
        local func = loadstring(code)
        if func then
            return func()
        else
            error("فشل في تجميع كود المهمة")
        end
    end)
    
    if success then
        if showLogs then
            print(string.format("✅ تم تحميل %s بنجاح!", questFile))
        end
        loadedQuests[questNum] = true
        return true
    else
        warn(string.format("❌ فشل تحميل %s: %s", questFile, tostring(result)))
        return false
    end
end



----------------------------------------------------------------
-- � المهمة 15 في الخلفية (المطالبة التلقائية)
----------------------------------------------------------------
-- تبدأ فورًا، تعمل كل 2 ثانية
local quest15Running = false

local function startQuest15Background()
    if quest15Running then return end
    quest15Running = true
    
    task.spawn(function()
        -- بدء صامت (بدون إزعاج في الكونسول)
        while quest15Running do
            pcall(function()
                loadQuest(15)
            end)
            
            task.wait(2)  -- تعمل كل 2 ثانية
        end
    end)
end

-- بدء المهمة 15 في الخلفية فورًا
startQuest15Background()


----------------------------------------------------------------
-- 🎮 المشغل الرئيسي للمهام
----------------------------------------------------------------
local function runQuestLoop()
    print("\n" .. string.rep("=", 60))
    print("🎮 بدء مشغل المهام التلقائي")
    print(string.rep("=", 60))
    
    -- ✅ تحقق الاسترداد: هل قائمة المهام فارغة؟
    if isQuestListEmpty() then
        print("\n" .. string.rep("!", 50))
        print("⚠️ قائمة المهام فارغة!")
        print("   → لا توجد مهام في PlayerGui.Main.Screen.Quests.List")
        print("   → قد يكون اللاعب قد انقطع أثناء حوار المهمة 1")
        print("   → فرض تحميل المهمة 1 للاسترداد...")
        print(string.rep("!", 50))
        
        loadQuest(1)
        task.wait(5)
        
        print("✅ تم محاولة استرداد المهمة 1. المتابعة...")
    end
    
    local maxAttempts = 3
    local reachedQuest18 = false
    local quest13Run = false  -- تتبع تنفيذ المهمة 13
    
    -- 🌍 توجيه المهام بناءً على الجزيرة
    local currentIsland = getCurrentIsland()
    print(string.format("\n🌍 الجزيرة الحالية: %s", currentIsland or "غير معروف"))
    
    if currentIsland == "Island2" then
        -- ============================================
        -- 🌋 الجزيرة 2: تشغيل المهمة 19 فقط (حلقة التعدين)
        -- المهمة 19 تحتوي على حلقة تعدين داخلية خاصة بها
        -- ============================================
        print("\n" .. string.rep("=", 60))
        print("🌋 تم اكتشاف الجزيرة 2 - وضع المهمة 19")
        print("   ⛏️ بدء التعدين + البيع والشراء التلقائي...")
        print(string.rep("=", 60))
        
        -- تشغيل المهمة 19 مرة واحدة - تحتوي على حلقة لا نهائية داخلية
        loadQuest(19)
        
        -- المهمة 19 ستعمل حلقة التعدين داخليًا
        -- هذا السطر يصل إليه فقط إذا انتهت المهمة 19 (وهو غير متوقع)
        return
    end
    
    -- ============================================
    -- 🏝️ الجزيرة 1: تشغيل المهام 1-18 (التدفق العادي)
    -- ============================================
    print("\n🏝️ وضع الجزيرة 1 - تشغيل المهام 1-18...")
    
    local currentQuest = CONFIG.MIN_QUEST
    
    -- التحقق إذا بدأنا من المهمة 18 أو لا
    local activeNum, _ = getActiveQuestNumber()
    if activeNum and activeNum >= 18 then
        reachedQuest18 = true
        print("\n🌋 تم اكتشاف المهمة 18! تخطي فحص المهام 1-17...")
    end
    
    while currentQuest <= 18 do  -- الجزيرة 1: الحد الأقصى = 18
        -- إذا وصلنا للمهمة 18، تخطى إلى المهمة 18 مباشرة
        if reachedQuest18 and currentQuest < 18 then
            currentQuest = 18
            continue
        end
        
        -- ============================================
        -- 🛠️ منطق المهام المخصص (13، 14، 15، 16، 17، 18)
        -- لا يتم التحقق من الواجهة، يتم التشغيل حسب المنطق الداخلي
        -- ============================================
        if currentQuest == 13 then
            -- المهمة 13: تشغيل مرة واحدة لكل جلسة
            if not quest13Run then
                print("\n🎵 تحميل المهمة 13 (مهمة العازف) [تشغيل مرة واحدة لكل جلسة]...")
                loadQuest(13)
                quest13Run = true
            else
                print("   ⏭️ المهمة 13 تم تشغيلها بالفعل في هذه الجلسة، تخطي.")
            end
            currentQuest = currentQuest + 1
            task.wait(2)
            continue
            
        elseif currentQuest == 14 then
            -- المهمة 14: الجيتار المفقود (فحص داخلي، يستخدم BardQuest وليس Introduction{N})
            print("\n🎸 تحميل المهمة 14 (الجيتار المفقود)...")
            loadQuest(14)
            currentQuest = currentQuest + 1
            task.wait(2)
            continue
            
        elseif currentQuest == 15 then
            -- المهمة 15: تخطي فحص الواجهة، تعمل بالفعل في الخلفية
            -- (تخطي صامت - بدون إزعاج في الكونسول)
            currentQuest = currentQuest + 1
            task.wait(1)
            continue
            
        elseif currentQuest == 16 then
            -- المهمة 16: شراء الفأس تلقائيًا (الذهب >= 3340 والمستوى < 10، بدون فحص واجهة)
            print("\n🛒 تحميل المهمة 16 (شراء الفأس تلقائيًا)...")
            loadQuest(16)
            currentQuest = currentQuest + 1
            task.wait(2)
            continue
            
        elseif currentQuest == 17 then
            -- المهمة 17: التعدين التلقائي حتى المستوى 10 (فحص داخلي)
            print("\n⛏️ تحميل المهمة 17 (التعدين التلقائي حتى المستوى 10)...")
            loadQuest(17)
            currentQuest = currentQuest + 1
            task.wait(2)
            continue
            
        elseif currentQuest == 18 then
            -- المهمة 18: التعدين الذكي (فحص داخلي)
            print("\n🌋 تحميل المهمة 18 (التعدين الذكي)...")
            loadQuest(18)
            break  -- المهمة 18 حلقة لا نهائية
        end
        
        -- ============================================
        -- 📋 منطق المهام القياسي المعتمد على الواجهة (1-12)
        -- ============================================
        print(string.format("\n🔍 التحقق من المهمة %d...", currentQuest))
        
        -- التحقق إذا كانت المهمة نشطة
        activeNum, activeName = getActiveQuestNumber()
        
        if activeNum then
            print(string.format("   📋 المهمة النشطة: #%d - %s", activeNum, activeName or "غير معروف"))
            
            -- إذا وصلنا للمهمة 18، علم أنه لا حاجة لفحص المهام القديمة
            if activeNum >= 18 then
                reachedQuest18 = true
            end
            
            -- تحميل وتشغيل المهمة
            local attempts = 0
            while attempts < maxAttempts do
                attempts = attempts + 1
                print(string.format("\n🚀 تشغيل المهمة %d (المحاولة %d/%d)...", activeNum, attempts, maxAttempts))
                
                local success = loadQuest(activeNum)
                
                if success then
                    -- الانتظار حتى تكتمل المهمة
                    print("   ⏳ الانتظار حتى اكتمال المهمة...")
                    
                    local timeout = 600  -- مهلة 10 دقائق
                    local startTime = tick()
                    
                    while not isQuestComplete(activeNum) and (tick() - startTime) < timeout do
                        task.wait(CONFIG.QUEST_CHECK_INTERVAL)
                    end
                    
                    if isQuestComplete(activeNum) then
                        print(string.format("✅ المهمة %d اكتملت!", activeNum))
                        break
                    else
                        warn(string.format("⏰ المهمة %d انتهت مهلة الانتظار!", activeNum))
                    end
                else
                    warn(string.format("❌ فشل تحميل المهمة %d", activeNum))
                    task.wait(5)
                end
            end
            
            currentQuest = activeNum + 1
        else
            -- ⚠️ لم يتم العثور على مهمة نشطة
            print("   ⚠️ لم يتم العثور على مهمة نشطة!")
            
            local playerLevel = getPlayerLevel()
            print(string.format("   📊 مستوى اللاعب: %s", tostring(playerLevel)))
            
            -- 🩹 استرداد: إذا كنا نتحقق من المهمة 1 ولم يتم العثور على واجهة
            -- هذا يعني أن اللاعب ربما انقطع أثناء حوار المهمة 1
            if currentQuest == 1 then
                print("\n" .. string.rep("!", 50))
                print("⚠️ وضع الاسترداد: لم يتم العثور على واجهة المهمة 1!")
                print("   → قد يكون اللاعب قد انقطع أثناء حوار المهمة 1")
                print("   → فرض تحميل المهمة 1...")
                print(string.rep("!", 50))
                
                loadQuest(1)  -- المهمة 1 لديها منطق خاص للتعامل مع هذا
                task.wait(5)
                
                -- الانتقال إلى المهمة 2 بغض النظر (سكريبت المهمة 1 يتعامل مع الإكمال)
                currentQuest = 2
            else
                -- الحالة العادية: الانتقال إلى المهمة التالية
                currentQuest = currentQuest + 1
            end
        end
        
        task.wait(2)
    end
    
    -- ============================================
    -- 🌋 وضع الحلقة اللانهائية للمهمة 18
    -- ============================================
    if reachedQuest18 then
        print("\n" .. string.rep("=", 60))
        print("🌋 المهمة 18 - وضع الزراعة اللانهائية")
        print("   ⚠️ لن يتم فحص المهام 1-17 بعد الآن")
        print(string.rep("=", 60))
        
        local loopCount = 0
        
        while true do
            loopCount = loopCount + 1
            print(string.format("\n🔄 حلقة المهمة 18 #%d", loopCount))
            
            -- تشغيل المهمة 18
            local success = loadQuest(18)
            
            if success then
                -- الانتظار حتى تكتمل المهمة 18 (إذا كان ذلك ممكنًا)
                local timeout = 300  -- 5 دقائق
                local startTime = tick()
                
                while not isQuestComplete(18) and (tick() - startTime) < timeout do
                    task.wait(5)
                end
            end
            
            -- الانتظار قبل الحلقة الجديدة
            task.wait(5)
        end
    else
        print("\n" .. string.rep("=", 60))
        print("🎉 تم إكمال جميع المهام!")
        print(string.rep("=", 60))
    end
end

----------------------------------------------------------------
-- 🚀 البداية
----------------------------------------------------------------
-- الانتظار حتى تحميل واجهة المستخدم
print("\n⏳ الانتظار حتى تحميل واجهة المهمة...")
local uiReady = false
for i = 1, 5 do
    local activeNum = getActiveQuestNumber()
    if activeNum then
        uiReady = true
        print(string.format("✅ واجهة المهمة جاهزة! المهمة النشطة: #%d", activeNum))
        break
    end
    task.wait(1)
end

if not uiReady then
    warn("⚠️ لم يتم اكتشاف واجهة المهمة، سيتم البدء على أي حال...")
end

-- بدء حلقة المهام
runQuestLoop()