--[[
    ⚔️ المهمة 04: الحصول على المعدات!
    📋 تجهيز أفضل سلاح → بيع أضعف سلاح
    📍 مقتطف من 0.lua (الأسطر 2245-3010)
--]]

-- المهمة 4: "الحصول على المعدات!" (نظام ذكي: قائم على الأولوية + مرن + قراءة ضرر من واجهة المستخدم)
-- ترتيب الأولوية: 1) تجهيز أفضل سلاح → 2) بيع أضعف سلاح

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

----------------------------------------------------------------
-- الإعدادات
----------------------------------------------------------------
local Quest4Active = true

-- أنواع الأسلحة (جميع الأسلحة في اللعبة - 23 نوع)
local WEAPON_TYPES = {
    "Dagger", "Falchion Knife", "Gladius Dagger", "Hook",
    "Crusaders Sword", "Long Sword", "Falchion Sword", "Gladius Sword",
    "Cutlass", "Rapier", "Great Sword", "Uchigatana", "Tachi",
    "Double Battle Axe", "Hammer", "Skull Crusher", "Scythe",
    "Dragon Slayer", "Comically Large Spoon", "Chaos", "Ironhand",
    "Boxing Gloves", "Relevator"
}

-- إعدادات البيع
local SELL_CONFIG = {
    NPC_NAME = "Marbles",
    KEEP_BEST_COUNT = 1
}

-- ترتيب الأولوية
local PRIORITY_ORDER = {
    "Equip",   -- 1. تجهيز أفضل سلاح أولاً
    "Sell",    -- 2. ثم بيع أضعف سلاح
}

----------------------------------------------------------------
-- إعداد Knit
----------------------------------------------------------------
local KnitPackage = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Knit")
local Knit = require(KnitPackage)

if not Knit.OnStart then 
    pcall(function() Knit.Start():await() end)
end

local CharacterService = nil
local PlayerController = nil
local ProximityService = nil
local DialogueService = nil
local UIController = nil

pcall(function()
    CharacterService = Knit.GetService("CharacterService")
    PlayerController = Knit.GetController("PlayerController")
    ProximityService = Knit.GetService("ProximityService")
    DialogueService = Knit.GetService("DialogueService")
end)

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

if CharacterService then print("✅ خدمة الشخصية جاهزة!") else warn("⚠️ خدمة الشخصية غير موجودة") end
if PlayerController then print("✅ وحدة تحكم اللاعب جاهزة!") else warn("⚠️ وحدة تحكم اللاعب غير موجودة") end
if ProximityService then print("✅ خدمة القرب جاهزة!") else warn("⚠️ خدمة القرب غير موجودة") end
if DialogueService then print("✅ خدمة الحوار جاهزة!") else warn("⚠️ خدمة الحوار غير موجودة") end
if UIController then print("✅ وحدة تحكم الواجهة جاهزة!") else warn("⚠️ وحدة تحكم الواجهة غير موجودة") end

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

local function isQuest4StillActive()
    if not Quest4Active then return false end
    
    local questID, objList = getQuestObjectives("Getting Equipped!")
    if not questID or not objList then
        print("🛑 لم يتم العثور على مهمة 'الحصول على المعدات!'")
        Quest4Active = false
        return false
    end
    
    return true
end

local function getObjectiveType(text)
    if string.find(text, "Equip") and string.find(text, "Weapon") then
        return "Equip"
    elseif string.find(text, "Sell") and string.find(text, "Weapon") then
        return "Sell"
    else
        return "Unknown"
    end
end

----------------------------------------------------------------
-- إدارة واجهة المستخدم
----------------------------------------------------------------
local function openToolsMenu()
    if not UIController then
        warn("   ⚠️ وحدة تحكم الواجهة غير متاحة، استخدام الحل البديل...")
        return false
    end
    
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

local function getDamageFromUI(guid)
    local menuGui = playerGui:FindFirstChild("Menu")
    if not menuGui then return 0 end
    
    local toolsFrame = menuGui:FindFirstChild("Frame") and menuGui.Frame:FindFirstChild("Frame") 
                       and menuGui.Frame.Frame:FindFirstChild("Menus") 
                       and menuGui.Frame.Frame.Menus:FindFirstChild("Tools")
                       and menuGui.Frame.Frame.Menus.Tools:FindFirstChild("Frame")
    
    if not toolsFrame then return 0 end
    
    local weaponFrame = toolsFrame:FindFirstChild(guid)
    if not weaponFrame then return 0 end
    
    local stats = weaponFrame:FindFirstChild("Stats")
    if not stats then return 0 end
    
    local dmgLabel = stats:FindFirstChild("DMG")
    if not dmgLabel or not dmgLabel:IsA("TextLabel") then return 0 end
    
    local text = dmgLabel.Text
    local damageValue = tonumber(string.match(text, "([%d%.]+)"))
    
    return damageValue or 0
end

----------------------------------------------------------------
-- إدارة الأسلحة
----------------------------------------------------------------
local function isWeaponType(itemType)
    for _, weaponType in ipairs(WEAPON_TYPES) do
        if itemType == weaponType then
            return true
        end
    end
    return false
end

local function isWeaponEquippedFromUI(guid)
    local menuGui = playerGui:FindFirstChild("Menu")
    if not menuGui then return false end
    
    local toolsFrame = menuGui:FindFirstChild("Frame") and menuGui.Frame:FindFirstChild("Frame") 
                    and menuGui.Frame.Frame:FindFirstChild("Menus") 
                    and menuGui.Frame.Frame.Menus:FindFirstChild("Tools")
                    and menuGui.Frame.Frame.Menus.Tools:FindFirstChild("Frame")
    
    if not toolsFrame then return false end
    
    local weaponFrame = toolsFrame:FindFirstChild(guid)
    if not weaponFrame then return false end
    
    local equipButton = weaponFrame:FindFirstChild("Equip")
    if not equipButton then return false end
    
    local textLabel = equipButton:FindFirstChild("TextLabel")
    if not textLabel or not textLabel:IsA("TextLabel") then return false end
    
    return textLabel.Text == "Unequip"
end

local function getPlayerWeapons()
    if not PlayerController or not PlayerController.Replica then
        warn("   ⚠️ النسخة المتماثلة غير متاحة!")
        return {}
    end
    
    local replica = PlayerController.Replica
    
    if not replica.Data or not replica.Data.Inventory or not replica.Data.Inventory.Equipments then
        warn("   ⚠️ لم يتم العثور على المعدات في النسخة المتماثلة!")
        return {}
    end
    
    print("   📂 فتح قائمة الأدوات لقراءة الضرر...")
    openToolsMenu()
    
    local equipments = replica.Data.Inventory.Equipments
    local weapons = {}
    
    for id, item in pairs(equipments) do
        if type(item) == "table" and item.Type and isWeaponType(item.Type) then
            local guid = item.GUID
            local quality = item.Quality or 0
            local damage = getDamageFromUI(guid)
            local isEquipped = isWeaponEquippedFromUI(guid)
            
            table.insert(weapons, {
                ID = id,
                Type = item.Type,
                Damage = damage,
                Quality = quality,
                GUID = guid,
                Data = item,
                IsEquipped = isEquipped
            })
            
            print(string.format("      - %s | الضرر: %.2f | GUID: %s | مجهز: %s", 
                item.Type, damage, guid, tostring(isEquipped)))
        end
    end
    
    closeToolsMenu()
    
    return weapons
end

local function findBestWeapon()
    local weapons = getPlayerWeapons()
    
    if #weapons == 0 then
        return nil, "لم يتم العثور على أسلحة في المخزون!"
    end
    
    local bestWeapon = weapons[1]
    
    for _, weapon in ipairs(weapons) do
        if weapon.Damage > bestWeapon.Damage then
            bestWeapon = weapon
        elseif weapon.Damage == bestWeapon.Damage and weapon.Quality > bestWeapon.Quality then
            bestWeapon = weapon
        end
    end
    
    return bestWeapon, nil
end

local function findWeakestWeapon()
    local weapons = getPlayerWeapons()
    
    if #weapons == 0 then
        return nil, "لم يتم العثور على أسلحة في المخزون!"
    end
    
    if #weapons <= SELL_CONFIG.KEEP_BEST_COUNT then
        return nil, "لا يوجد أسلحة كافية للبيع!"
    end
    
    print("\n🔍 البحث عن أضعف سلاح للبيع...")
    
    local weakestWeapon = nil
    for _, weapon in ipairs(weapons) do
        if not weapon.IsEquipped then
            if not weakestWeapon then
                weakestWeapon = weapon
            elseif weapon.Damage < weakestWeapon.Damage then
                weakestWeapon = weapon
            elseif weapon.Damage == weakestWeapon.Damage and weapon.Quality < weakestWeapon.Quality then
                weakestWeapon = weapon
            end
        else
            print(string.format("   ⚠️ تخطي السلاح المجهز: %s (الضرر: %.2f، الجودة: %.1f)", 
                weapon.Type, weapon.Damage, weapon.Quality))
        end
    end
    
    if weakestWeapon then
        print(string.format("   ✅ تم اختيار الأضعف (غير مجهز): %s | الضرر: %.2f | GUID: %s", 
            weakestWeapon.Type, weakestWeapon.Damage, weakestWeapon.GUID))
        return weakestWeapon, nil
    end
    
    print("   ⚠️ [حل بديل] أضعف سلاح مجهز! اختيار أي سلاح قابل للبيع...")
    for _, weapon in ipairs(weapons) do
        if not weapon.IsEquipped then
            print(string.format("   → تم اختيار الحل البديل: %s | الضرر: %.2f | GUID: %s", 
                weapon.Type, weapon.Damage, weapon.GUID))
            return weapon, nil
        end
    end
    
    return nil, "جميع الأسلحة مجهزة أو لا يوجد سلاح صالح للبيع!"
end

local function canDoObjective(objType)
    if objType == "Sell" then
        local weapons = getPlayerWeapons()
        if #weapons <= 1 then
            print("   ⚠️ لا يمكن البيع: تحتاج على الأقل لسلاحين (لديك " .. #weapons .. ")")
            return false
        end
    end
    return true
end

local function printWeaponsSummary()
    print("\n   ⚔️  === مخزون الأسلحة ===")
    
    local weapons = getPlayerWeapons()
    
    if #weapons == 0 then
        warn("   ❌ لم يتم العثور على أسلحة!")
        return
    end
    
    print(string.format("   ✅ تم العثور على %d سلاح(أسلحة):", #weapons))
    
    table.sort(weapons, function(a, b)
        if a.Damage ~= b.Damage then
            return a.Damage > b.Damage
        else
            return a.Quality > b.Quality
        end
    end)
    
    for i, weapon in ipairs(weapons) do
        local marker = ""
        if i == 1 then marker = " 👑 الأفضل" end
        if i == #weapons and #weapons > 1 and not weapon.IsEquipped then 
            marker = " 🗑️ الأسوأ" 
        end
        if weapon.IsEquipped then 
            marker = marker .. " ⚡ مجهز" 
        end
        
        print(string.format("      %d. %s - الضرر: %.2f | الجودة: %.1f%s", 
            i, weapon.Type, weapon.Damage, weapon.Quality, marker))
    end
    
    print("   " .. string.rep("=", 30) .. "\n")
end

----------------------------------------------------------------
-- استعادة الحالة بالقوة
----------------------------------------------------------------
local function forceRestoreState()
    print("   🔧 استعادة حالة اللاعب...")
    
    local char = player.Character
    if char then
        local status = char:FindFirstChild("Status")
        if status then
            for _, tag in ipairs(status:GetChildren()) do
                if tag.Name == "DisableBackpack" or tag.Name == "NoMovement" or tag.Name == "Talking" then
                    tag:Destroy()
                end
            end
        end
        
        if char:FindFirstChild("Humanoid") then
            char.Humanoid.WalkSpeed = 16
            char.Humanoid.JumpPower = 50
        end
    end
    
    local gui = player:FindFirstChild("PlayerGui")
    if gui then
        local dUI = gui:FindFirstChild("DialogueUI")
        if dUI then dUI.Enabled = false end
        
        local main = gui:FindFirstChild("Main")
        if main then main.Enabled = true end
        
        local backpack = gui:FindFirstChild("BackpackGui")
        if backpack then backpack.Enabled = true end
    end
    
    local cam = Workspace.CurrentCamera
    if cam then
        cam.CameraType = Enum.CameraType.Custom
    end
    
    pcall(function()
        local dialogueRE = ReplicatedStorage.Shared.Packages.Knit.Services.DialogueService.RE.DialogueEvent
        dialogueRE:FireServer("Closed")
    end)
    
    print("   ✅ تم استعادة الحالة!")
end

----------------------------------------------------------------
-- الإجراءات
----------------------------------------------------------------
local function doEquipBestWeapon()
    print("⚔️  الهدف: تجهيز أفضل سلاح...")
    
    printWeaponsSummary()
    
    local bestWeapon, errorMsg = findBestWeapon()
    
    if not bestWeapon then
        warn(string.format("   ❌ خطأ: %s", errorMsg))
        return false
    end
    
    print(string.format("   🎯 تم الاختيار: %s (الضرر: %.2f | الجودة: %.1f)", bestWeapon.Type, bestWeapon.Damage, bestWeapon.Quality))
    
    if not CharacterService then
        warn("   ❌ خدمة الشخصية غير متاحة!")
        return false
    end
    
    local success, err = pcall(function()
        CharacterService:EquipItem(bestWeapon.Data)
    end)
    
    if success then
        print("   ✅ تم التجهيز بنجاح!")
        return true
    else
        warn("   ❌ فشل في التجهيز: " .. tostring(err))
        return false
    end
end

local function doSellWeakestWeapon()
    print("💰 الهدف: بيع أضعف سلاح...")
    
    printWeaponsSummary()
    
    local weakestWeapon, errorMsg = findWeakestWeapon()
    
    if not weakestWeapon then
        warn(string.format("   ❌ خطأ: %s", errorMsg))
        return false
    end
    
    print(string.format("   🎯 تم الاختيار: %s (الضرر: %.2f | الجودة: %.1f)", weakestWeapon.Type, weakestWeapon.Damage, weakestWeapon.Quality))
    
    local basket = {}
    basket[weakestWeapon.GUID] = true
    
    local proximity = Workspace:FindFirstChild("Proximity")
    local npc = proximity and (proximity:FindFirstChild(SELL_CONFIG.NPC_NAME) or proximity:FindFirstChild("Greedy Cey"))
    
    if not npc then
        warn("   ❌ لم يتم العثور على NPC!")
        return false
    end
    
    if not ProximityService or not DialogueService then
        warn("   ❌ الخدمات غير متاحة!")
        return false
    end
    
    print("   🔌 فتح الحوار...")
    local success1 = pcall(function()
        ProximityService:ForceDialogue(npc, "SellConfirm")
    end)
    
    if not success1 then
        warn("   ❌ فشل في فتح الحوار")
        return false
    end
    
    task.wait(0.2)
    
    print("   💸 بيع السلاح...")
    local success2 = pcall(function()
        DialogueService:RunCommand("SellConfirm", { Basket = basket })
    end)
    
    if success2 then
        print("   ✅ تم البيع بنجاح!")
        task.wait(0.1)
        forceRestoreState()
        return true
    else
        warn("   ❌ فشل البيع")
        forceRestoreState()
        return false
    end
end

----------------------------------------------------------------
-- مشغل المهمة الذكي
----------------------------------------------------------------
local function RunQuest4_Smart()
    print(string.rep("=", 50))
    print("🚀 المهمة 4: الحصول على المعدات!")
    print("🎯 نظام ذكي: قائم على الأولوية + مرن")
    print("📋 ترتيب الأولوية: تجهيز → بيع")
    print(string.rep("=", 50))
    
    local questID, objList = getQuestObjectives("Getting Equipped!")
    
    if not questID then
        warn("❌ لم يتم العثور على مهمة 'الحصول على المعدات!'")
        Quest4Active = false
        return
    end
    
    print("✅ تم العثور على المهمة (المعرف: " .. questID .. ")")
    
    local objectives = {}
    for _, item in ipairs(objList:GetChildren()) do
        if item:IsA("Frame") and tonumber(item.Name) then
            local text = getObjectiveText(item)
            local objType = getObjectiveType(text)
            
            table.insert(objectives, {
                order = tonumber(item.Name),
                frame = item,
                text = text,
                type = objType
            })
        end
    end
    
    table.sort(objectives, function(a, b)
        local function getPriority(type)
            for i, priorityType in ipairs(PRIORITY_ORDER) do
                if string.find(type, priorityType) then
                    return i
                end
            end
            return 999
        end
        return getPriority(a.type) < getPriority(b.type)
    end)
    
    print("\n" .. string.rep("=", 50))
    print("⚙️  أهداف المهمة (ترتيب الأولوية):")
    for i, obj in ipairs(objectives) do
        local complete = isObjectiveComplete(obj.frame)
        print(string.format("   %d. [%s] %s [%s]", i, obj.type, obj.text, complete and "✅" or "⏳"))
    end
    print(string.rep("=", 50))
    
    local maxAttempts = 5
    local attempt = 0
    
    while isQuest4StillActive() and attempt < maxAttempts do
        attempt = attempt + 1
        print(string.format("\n🔄 دورة المهمة #%d", attempt))
        
        local allComplete = true
        local didSomething = false
        
        for _, obj in ipairs(objectives) do
            if not isQuest4StillActive() then
                print("🛑 اختفت المهمة!")
                break
            end
            
            local complete = isObjectiveComplete(obj.frame)
            
            if not complete then
                allComplete = false
                
                if not canDoObjective(obj.type) then
                    print(string.format("   ⏭️  تخطي [%s] - لا يمكن التنفيذ الآن", obj.type))
                    continue
                end
                
                print(string.format("\n📋 معالجة [%s]: %s", obj.type, obj.text))
                
                local success = false
                
                if obj.type == "Equip" then
                    success = doEquipBestWeapon()
                    didSomething = true
                    task.wait(1.5)
                    
                elseif obj.type == "Sell" then
                    success = doSellWeakestWeapon()
                    didSomething = true
                    task.wait(1.5)
                    
                else
                    warn("   ⚠️ نوع هدف غير معروف: " .. obj.type)
                end
                
                if success then
                    print(string.format("   ✅ تم إكمال الإجراء!"))
                else
                    warn(string.format("   ⚠️ فشل الإجراء، سيتم المحاولة مجددًا"))
                end
                
                task.wait(1)
                if isObjectiveComplete(obj.frame) then
                    print(string.format("✅ [%s] مكتمل!", obj.type))
                else
                    print(string.format("⏳ [%s] لا يزال قيد التنفيذ", obj.type))
                end
            end
        end
        
        if allComplete then
            print("\n🎉 تم إكمال جميع الأهداف!")
            break
        end
        
        if not didSomething then
            warn("\n⚠️ لم يتم إكمال أي أهداف في هذه الدورة!")
            print("   الانتظار 2 ثانية قبل المحاولة مجددًا...")
            task.wait(2)
        end
    end
    
    task.wait(1)
    
    local allComplete = true
    for _, obj in ipairs(objectives) do
        if not isObjectiveComplete(obj.frame) then
            allComplete = false
            warn(string.format("   ⚠️ [%s] غير مكتمل: %s", obj.type, obj.text))
        end
    end
    
    if allComplete then
        print("\n" .. string.rep("=", 50))
        print("✅ المهمة 4 مكتملة!")
        print(string.rep("=", 50))
    else
        warn("\n" .. string.rep("=", 50))
        warn("⚠️ المهمة 4 غير مكتملة بعد " .. attempt .. " دورة")
        warn(string.rep("=", 50))
    end
    
    Quest4Active = false
end

----------------------------------------------------------------
-- البداية
----------------------------------------------------------------
RunQuest4_Smart()