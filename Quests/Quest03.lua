--[[
    ⚔️ المهمة 03: تعلم كيفية الصهر!
    📋 صهر سلاح في الفرن
    📍 مقتبس من 0.lua (الأسطر 1554-2240)
--]]

-- المهمة 3 فقط: "تعلم كيفية الصهر!" (تم الإصلاح: smoothMoveTo + قفل الموقع)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

----------------------------------------------------------------
-- الإعدادات
----------------------------------------------------------------
local Quest3Active = true

local FORGE_CONFIG = {
    REQUIRED_ORE_COUNT = 3,
    ITEM_TYPE = "Weapon",
    FORGE_DELAY = 2,
    FORGE_POSITION = Vector3.new(-192.3, 29.5, 168.1),
    MOVE_SPEED = 25,  
}

----------------------------------------------------------------
-- الخدمات والريموتات
----------------------------------------------------------------
local SERVICES = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Services")
local PROXIMITY_RF = SERVICES:WaitForChild("ProximityService"):WaitForChild("RF"):WaitForChild("Forge")

local FORGE_OBJECT = Workspace:WaitForChild("Proximity"):WaitForChild("Forge")

----------------------------------------------------------------
-- إعداد Knit
----------------------------------------------------------------
local KnitPackage = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Knit")
local Knit = require(KnitPackage)

if not Knit.OnStart then 
    pcall(function() Knit.Start():await() end)
end

local ForgeController = nil
local ForgeService = nil
local PlayerController = nil
local UIController = nil

pcall(function()
    ForgeController = Knit.GetController("ForgeController")
    ForgeService = Knit.GetService("ForgeService")
    PlayerController = Knit.GetController("PlayerController")
end)

-- ربط UIController من getgc
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

if ForgeService then print("✅ خدمة الفرن جاهزة!") else warn("⚠️ خدمة الفرن غير موجودة") end
if PlayerController then print("✅ وحدة اللاعب جاهزة!") else warn("⚠️ وحدة اللاعب غير موجودة") end
if UIController then print("✅ وحدة واجهة المستخدم جاهزة!") else warn("⚠️ وحدة واجهة المستخدم غير موجودة") end

----------------------------------------------------------------
-- الحالة
----------------------------------------------------------------
local State = {
    moveConn = nil,
    noclipConn = nil,
    bodyVelocity = nil,
    bodyGyro = nil,
}

local function restoreCollisions()
    local char = player.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = true
        end
    end
end

local function cleanupState()
    if State.moveConn then State.moveConn:Disconnect() State.moveConn = nil end
    if State.noclipConn then State.noclipConn:Disconnect() State.noclipConn = nil end
    if State.bodyVelocity then State.bodyVelocity:Destroy() State.bodyVelocity = nil end
    if State.bodyGyro then State.bodyGyro:Destroy() State.bodyGyro = nil end
end

----------------------------------------------------------------
-- عدم الاصطدام والحركة
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
    restoreCollisions()
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

        if distance < 2 then
            print("   ✅ تم الوصول إلى الهدف!")

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

        local speed = math.min(FORGE_CONFIG.MOVE_SPEED, distance * 10)
        local velocity = direction.Unit * speed

        bv.Velocity = velocity
        bg.CFrame = CFrame.lookAt(currentPos, targetPos)
    end)

    return true
end

----------------------------------------------------------------
-- إدارة واجهة المستخدم
----------------------------------------------------------------
local function closeForgeUI()
    print("\n   🚪 إغلاق واجهة الفرن...")
    
    local closed = false
    
    if UIController and UIController.Close then
        pcall(function()
            if UIController.Modules and UIController.Modules["Forge"] then
                UIController:Close("Forge")
                print("      ✅ تم الإغلاق عبر وحدة واجهة المستخدم")
                closed = true
            end
        end)
    end
    
    if not closed and ForgeController then
        pcall(function()
            if ForgeController.Close then
                ForgeController:Close()
                print("      ✅ تم الإغلاق عبر وحدة الفرن")
                closed = true
            elseif ForgeController.CloseForge then
                ForgeController:CloseForge()
                print("      ✅ تم الإغلاق عبر ForgeController.CloseForge")
                closed = true
            end
        end)
    end
    
    if not closed then
        pcall(function()
            local forgeGui = playerGui:FindFirstChild("Forge") or playerGui:FindFirstChild("ForgeUI")
            if forgeGui then
                forgeGui.Enabled = false
                print("      ✅ تم الإغلاق عبر PlayerGui")
                closed = true
            end
        end)
    end
    
    if not closed then
        warn("      ⚠️ لم يتمكن من إغلاق واجهة الفرن (ربما مغلقة بالفعل)")
    end
    
    task.wait(0.5)
end

----------------------------------------------------------------
-- نظام المهام
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

local function isQuestComplete(questName)
    local questID, objList = getQuestObjectives(questName)
    
    if not questID or not objList then
        return true
    end
    
    for _, item in ipairs(objList:GetChildren()) do
        if item:IsA("Frame") and tonumber(item.Name) then
            local check = item:FindFirstChild("Main") and item.Main:FindFirstChild("Frame") and item.Main.Frame:FindFirstChild("Check")
            if check and not check.Visible then
                return false
            end
        end
    end
    
    return true
end

local function isQuest3StillActive()
    if not Quest3Active then return false end
    
    if isQuestComplete("Learning to Forge!") then
        print("🛑 المهمة 'تعلم كيفية الصهر!' مكتملة!")
        Quest3Active = false
        return false
    end
    
    local questID, objList = getQuestObjectives("Learning to Forge!")
    if not questID or not objList then
        print("🛑 المهمة 'تعلم كيفية الصهر!' غير موجودة!")
        Quest3Active = false
        return false
    end
    
    return true
end

----------------------------------------------------------------
-- نظام الجرد
----------------------------------------------------------------
local function getPlayerInventory()
    local inventory = {}
    
    if not PlayerController then
        warn("   ⚠️ وحدة اللاعب غير متوفرة!")
        return inventory
    end
    
    if not PlayerController.Replica then
        print("   ⏳ في انتظار النسخة...")
        task.wait(2)
    end
    
    if not PlayerController.Replica then
        warn("   ❌ النسخة لا تزال غير متوفرة!")
        return inventory
    end
    
    local replica = PlayerController.Replica
    
    if replica and replica.Data and replica.Data.Inventory then
        print("   ✅ قراءة من Replica.Data.Inventory")
        
        for itemName, amount in pairs(replica.Data.Inventory) do
            if type(amount) == "number" and amount > 0 then
                inventory[itemName] = amount
            end
        end
    else
        warn("   ❌ Replica.Data.Inventory غير موجود!")
    end
    
    return inventory
end

local function getAvailableOres()
    local inventory = getPlayerInventory()
    local ores = {}
    
    local oreTypes = {"Copper","Stone", "Iron","Sand Stone", "Tin", "Cardboardite", "Silver", "Gold", "Bananite", "Mushroomite", "Platinum","Aite","Poopite"}
    
    for _, oreName in ipairs(oreTypes) do
        if inventory[oreName] and inventory[oreName] > 0 then
            table.insert(ores, {Name = oreName, Amount = inventory[oreName]})
        end
    end
    
    if #ores == 0 then
        print("   🔍 فحص جميع العناصر للعثور على المعادن...")
        for itemName, amount in pairs(inventory) do
            if string.find(itemName, "Ore") or string.find(itemName, "ore") then
                table.insert(ores, {Name = itemName, Amount = amount})
            end
        end
    end
    
    return ores
end

local function selectRandomOres(count)
    local availableOres = getAvailableOres()
    
    if #availableOres == 0 then
        return nil, "لا توجد معادن في الجرد!"
    end
    
    local totalOres = 0
    for _, ore in ipairs(availableOres) do
        totalOres = totalOres + ore.Amount
    end
    
    if totalOres < count then
        return nil, string.format("لا يوجد معادن كافية! تحتاج %d، لديك %d", count, totalOres)
    end
    
    local orePool = {}
    for _, ore in ipairs(availableOres) do
        for i = 1, ore.Amount do
            table.insert(orePool, ore.Name)
        end
    end
    
    local selected = {}
    for i = 1, count do
        if #orePool == 0 then break end
        
        local randomIndex = math.random(1, #orePool)
        local oreName = table.remove(orePool, randomIndex)
        
        selected[oreName] = (selected[oreName] or 0) + 1
    end
    
    return selected, nil
end

local function printInventorySummary()
    print("\n   📦 === فحص الجرد ===")
    
    local ores = getAvailableOres()
    
    if #ores == 0 then
        warn("   ❌ لا توجد معادن في الجرد!")
        return
    end
    
    print("   ✅ المعادن المتوفرة:")
    local total = 0
    for _, ore in ipairs(ores) do
        print(string.format("      • %s: %d", ore.Name, ore.Amount))
        total = total + ore.Amount
    end
    print(string.format("      📊 المجموع: %d معدن", total))
    print("   " .. string.rep("=", 28) .. "\n")
end

----------------------------------------------------------------
-- نظام الفرن
----------------------------------------------------------------
getgenv().ForgeHookActive = getgenv().ForgeHookActive or false

local function setupForgeHook()
    if getgenv().ForgeHookActive then
        print("   ⚠️ ربط الفرن مفعل بالفعل")
        return
    end
    
    if not ForgeService then
        warn("   ❌ خدمة الفرن غير متوفرة!")
        return
    end
    
    print("   🪝 تثبيت ربط الفرن...")
    local originalChangeSequence = ForgeService.ChangeSequence
    
    ForgeService.ChangeSequence = function(self, sequenceName, args)
        print("      🔄 تسلسل: " .. sequenceName)
        
        local success, result = pcall(originalChangeSequence, self, sequenceName, args)
        
        task.spawn(function()
            if sequenceName == "Melt" then
                print("      ⏩ تلقائي: الصب بعد 8 ثوانٍ...")
                task.wait(8)
                self:ChangeSequence("Pour", {ClientTime = 8.5, InContact = true})
                
            elseif sequenceName == "Pour" then
                print("      ⏩ تلقائي: الطرق بعد 5 ثوانٍ...")
                task.wait(5)
                self:ChangeSequence("Hammer", {ClientTime = 5.2})
                
            elseif sequenceName == "Hammer" then
                print("      ⏩ تلقائي: التبريد بالماء بعد 6 ثوانٍ...")
                task.wait(6)
                self:ChangeSequence("Water", {ClientTime = 6.5})
                
            elseif sequenceName == "Water" then
                print("      ⏩ تلقائي: العرض بعد 3 ثوانٍ...")
                task.wait(3)
                self:ChangeSequence("Showcase", {})
                
            elseif sequenceName == "Showcase" then
                print("      ✅ تم الانتهاء من الصهر!")
            end
        end)
        
        return success, result
    end
    
    getgenv().ForgeHookActive = true
    print("   ✅ تم تثبيت ربط الفرن!")
end

local function moveToForge()
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    local forgePos = FORGE_CONFIG.FORGE_POSITION
    local currentDist = (forgePos - hrp.Position).Magnitude
    
    print(string.format("   🚶 التحرك إلى الفرن عند (%.1f, %.1f, %.1f) (يبعد %.1f وحدات)...", 
        forgePos.X, forgePos.Y, forgePos.Z, currentDist))
    
    local moveComplete = false
    smoothMoveTo(forgePos, function()
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
    
    print("   ✅ تم الوصول إلى الفرن!")
    
    print("   ⏸️  الانتظار 1.5 ثانية قبل فتح واجهة الفرن...")
    task.wait(1.5)
    
    return true
end

local function startForge(oreSelection)
    print("   🔥 بدء الصهر مع:")
    for oreName, amount in pairs(oreSelection) do
        print(string.format("      • %s x%d", oreName, amount))
    end
    
    local success = pcall(function()
        PROXIMITY_RF:InvokeServer(FORGE_OBJECT)
    end)
    
    if not success then
        warn("   ❌ فشل استدعاء ريموت الفرن")
        return false
    end
    
    task.wait(1)
    
    if not ForgeService then
        warn("   ❌ خدمة الفرن غير متوفرة!")
        return false
    end
    
    local forgeSuccess = pcall(function()
        ForgeService:ChangeSequence("Melt", {
            Ores = oreSelection,
            ItemType = FORGE_CONFIG.ITEM_TYPE,
            FastForge = false
        })
    end)
    
    if forgeSuccess then
        print("   ✅ بدأ الصهر!")
        return true
    else
        warn("   ⚠️ لم يتمكن من بدء الصهر")
        return false
    end
end

local function doForgeLoop()
    print("🔥 الإجراء: الصهر التلقائي...")
    
    setupForgeHook()
    
    moveToForge()
    
    local forgeCount = 0
    local consecutiveFailures = 0
    
    while isQuest3StillActive() do
        forgeCount = forgeCount + 1
        print(string.format("\n   🔨 محاولة الصهر #%d", forgeCount))
        
        printInventorySummary()
        
        local oreSelection, errorMsg = selectRandomOres(FORGE_CONFIG.REQUIRED_ORE_COUNT)
        
        if not oreSelection then
            warn(string.format("\n❌ خطأ: %s", errorMsg))
            consecutiveFailures = consecutiveFailures + 1
            
            if consecutiveFailures >= 3 then
                warn("❌ فشل 3 مرات متتالية. لا يمكن الاستمرار في الصهر!")
                warn("💡 يرجى استخراج المزيد من المعادن والمحاولة مرة أخرى.")
                Quest3Active = false
                break
            end
            
            warn(string.format("⏳ الانتظار 5 ثوانٍ قبل المحاولة مجددًا... (%d/3 فشل)", consecutiveFailures))
            task.wait(5)
            continue
        end
        
        consecutiveFailures = 0
        
        local success = startForge(oreSelection)
        
        if success then
            print("   ⏳ الانتظار حتى اكتمال الصهر...")
            task.wait(25)
        else
            warn("   ⚠️ فشل الصهر، إعادة المحاولة بعد 3 ثوانٍ...")
            task.wait(3)
        end
        
        if not isQuest3StillActive() then
            print("   ✅ المهمة مكتملة!")
            break
        end
        
        print(string.format("   ⏸️ فترة تبريد لمدة %d ثانية...", FORGE_CONFIG.FORGE_DELAY))
        task.wait(FORGE_CONFIG.FORGE_DELAY)
    end
    
    print("\n🛑 انتهى الصهر في المهمة 3")
end

----------------------------------------------------------------
-- المشغل الرئيسي
----------------------------------------------------------------
local function Run_Quest3()
    print(string.rep("=", 50))
    print("🚀 المهمة 3: تعلم كيفية الصهر!")
    print("🛡️  تم تفعيل عدم الاصطدام + قفل الموقع")
    print("📍 موقع الفرن: (-192.3, 29.5, 168.1)")
    print("⏸️  الانتظار 1.5 ثانية قبل فتح واجهة الفرن")
    print(string.rep("=", 50))
    
    local questID, objList = getQuestObjectives("Learning to Forge!")
    
    if not questID then
        warn("❌ المهمة 'تعلم كيفية الصهر!' غير موجودة!")
        warn("💡 تأكد من أن المهمة مفعلة في سجل مهامك.")
        Quest3Active = false
        return
    end
    
    print("✅ تم العثور على المهمة (المعرف: " .. questID .. ")")
    
    print("\n" .. string.rep("=", 50))
    print("🔥 بدء تسلسل الصهر...")
    print(string.rep("=", 50))
    
    doForgeLoop()
    
    closeForgeUI()
    
    if Quest3Active == false and not isQuestComplete("Learning to Forge!") then
        warn("\n" .. string.rep("=", 50))
        warn("❌ فشل المهمة 3!")
        warn("السبب: لا توجد معادن كافية للاستمرار")
        warn(string.rep("=", 50))
    else
        print("\n" .. string.rep("=", 50))
        print("✅ المهمة 3 مكتملة!")
        print(string.rep("=", 50))
    end
    
    Quest3Active = false
    disableNoclip()
    cleanupState()
end

----------------------------------------------------------------
-- البداية
----------------------------------------------------------------
Run_Quest3()