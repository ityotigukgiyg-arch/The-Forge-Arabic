local Shared = _G.Shared

-- المهمة 7: "التشكيل تحت الضغط!" - نظام ذكي (نسخة مُصلحة)
-- ✅ الأولوية: الشراء → القتل → التعدين → التشكيل
-- ✅ نظام البيع: التحقق من واجهة المستخدم (يدعم اسم المعول + معرف السلاح/الدرع)
-- ✅ بيع كل شيء غير مُجهز (بما في ذلك المعول)
-- ✅ مُصلح: إغلاق واجهة التشكيل بعد اكتمال التشكيل (مثل المهمة 3)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

----------------------------------------------------------------
-- الإعدادات
----------------------------------------------------------------
local Quest7Active = true
local IsMiningActive = false
local IsKillingActive = false
local IsForgingActive = false

local QUEST_CONFIG = {
    QUEST_NAME = "Forging Under Pressure",
    PICKAXE_NAME = "Iron Pickaxe",
    PICKAXE_AMOUNT = 1,
    NPC_POSITION = Vector3.new(-81.03, 28.51, 84.68),
    ZOMBIE_UNDERGROUND_OFFSET = 6,
    ZOMBIE_MAX_DISTANCE = 50,
    REQUIRED_ORE_COUNT = 3,
    ITEM_TYPE = "Armor",
    FORGE_DELAY = 2,
    FORGE_POSITION = Vector3.new(-192.3, 29.5, 168.1),
    ROCK_NAME = "Pebble",
    UNDERGROUND_OFFSET = 4,
    MIN_ORES_FOR_FORGE = 10,
    LAYING_ANGLE = 90,
    MOVE_SPEED = 25,  
    SELL_NPC_NAME = "Marbles",
    SELL_NPC_POSITION = Vector3.new(49.84, 29.17, 85.84),
    PRIORITY_ORDER = {"Purchase", "Kill", "Mine", "Forge"},
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
local ForgeService = nil
local DialogueService = nil
local UIController = nil

pcall(function()
    CharacterService = Knit.GetService("CharacterService")
    PlayerController = Knit.GetController("PlayerController")
    ProximityService = Knit.GetService("ProximityService")
    ForgeService = Knit.GetService("ForgeService")
    DialogueService = Knit.GetService("DialogueService")
end)

local ToolController = nil
local ToolActivatedFunc = nil

pcall(function()
    for _, v in pairs(getgc(true)) do
        if type(v) == "table" then
            if rawget(v, "Name") == "ToolController" and rawget(v, "ToolActivated") then
                ToolController = v
                ToolActivatedFunc = v.ToolActivated
                break
            end
        end
    end
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

local SERVICES = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Services")

local PURCHASE_RF = nil
pcall(function()
    PURCHASE_RF = SERVICES:WaitForChild("ProximityService", 5):WaitForChild("RF", 3):WaitForChild("Purchase", 3)
end)

local CHAR_RF = nil
pcall(function()
    CHAR_RF = SERVICES:WaitForChild("CharacterService", 5):WaitForChild("RF", 3):WaitForChild("EquipItem", 3)
end)

local TOOL_RF_BACKUP = nil
pcall(function()
    TOOL_RF_BACKUP = SERVICES:WaitForChild("ToolService", 5):WaitForChild("RF", 3):WaitForChild("ToolActivated", 3)
end)

local PROXIMITY_RF = nil
pcall(function()
    PROXIMITY_RF = SERVICES:WaitForChild("ProximityService", 5):WaitForChild("RF", 3):WaitForChild("Forge", 3)
end)

local MINING_FOLDER_PATH = Workspace:WaitForChild("Rocks")
local LIVING_FOLDER = Workspace:WaitForChild("Living")

local FORGE_OBJECT = nil
pcall(function()
    FORGE_OBJECT = Workspace:WaitForChild("Proximity", 5):WaitForChild("Forge", 3)
end)

if CharacterService then print("✅ خدمة الشخصية جاهزة!") else warn("⚠️ خدمة الشخصية غير موجودة") end
if PlayerController then print("✅ وحدة تحكم اللاعب جاهزة!") else warn("⚠️ وحدة تحكم اللاعب غير موجودة") end
if ToolController then print("✅ وحدة تحكم الأدوات جاهزة!") else warn("⚠️ وحدة تحكم الأدوات غير موجودة") end
if ForgeService then print("✅ خدمة التشكيل جاهزة!") else warn("⚠️ خدمة التشكيل غير موجودة") end
if DialogueService then print("✅ خدمة الحوار جاهزة!") else warn("⚠️ خدمة الحوار غير موجودة") end
if ProximityService then print("✅ خدمة القرب جاهزة!") else warn("⚠️ خدمة القرب غير موجودة") end
if UIController then print("✅ وحدة تحكم واجهة المستخدم جاهزة!") else warn("⚠️ وحدة تحكم واجهة المستخدم غير موجودة") end
if PURCHASE_RF then print("✅ ريموت الشراء جاهز!") else warn("⚠️ ريموت الشراء غير موجود") end
if FORGE_OBJECT then print("✅ كائن التشكيل جاهز!") else warn("⚠️ كائن التشكيل غير موجود") end

----------------------------------------------------------------
-- إدارة الحالة
----------------------------------------------------------------
local State = {
    currentTarget = nil,
    targetDestroyed = false,
    hpWatchConn = nil,
    noclipConn = nil,
    moveConn = nil,
    positionLockConn = nil,
    bodyVelocity = nil,
    bodyGyro = nil,
    currentObjectiveFrame = nil,
}

local function cleanupState()
    if State.hpWatchConn then State.hpWatchConn:Disconnect() State.hpWatchConn = nil end
    if State.noclipConn then State.noclipConn:Disconnect() State.noclipConn = nil end
    if State.moveConn then State.moveConn:Disconnect() State.moveConn = nil end
    if State.positionLockConn then State.positionLockConn:Disconnect() State.positionLockConn = nil end
    if State.bodyVelocity then State.bodyVelocity:Destroy() State.bodyVelocity = nil end
    if State.bodyGyro then State.bodyGyro:Destroy() State.bodyGyro = nil end
    
    State.currentTarget = nil
    State.targetDestroyed = false
    
    if ToolController then
        ToolController.holdingM1 = false
    end
end

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

local function isQuest7StillActive()
    if not Quest7Active then return false end
    
    local questID, objList = getQuestObjectives(QUEST_CONFIG.QUEST_NAME)
    if not questID or not objList then
        print("🛑 المهمة '" .. QUEST_CONFIG.QUEST_NAME .. "' غير موجودة!")
        Quest7Active = false
        return false
    end
    
    return true
end

local function isCurrentObjectiveComplete()
    if State.currentObjectiveFrame then
        return isObjectiveComplete(State.currentObjectiveFrame)
    end
    return false
end

local function getObjectiveType(text)
    if string.find(text, "Purchase") or string.find(text, "Buy") or string.find(text, "Pickaxe") then
        return "Purchase"
    elseif string.find(text, "Kill") or string.find(text, "Zombie") or string.find(text, "Defeat") then
        return "Kill"
    elseif string.find(text, "Get Ore") or string.find(text, "Mine") or string.find(text, "Pebble") then
        return "Mine"
    elseif string.find(text, "Forge") or string.find(text, "forge") or string.find(text, "Item") then
        return "Forge"
    else
        return "Unknown"
    end
end

----------------------------------------------------------------
-- نظام الجرد
----------------------------------------------------------------
local function getPlayerInventory()
    local inventory = {}
    
    if not PlayerController or not PlayerController.Replica then
        warn("وحدة تحكم اللاعب/النسخة غير متوفرة!")
        return inventory
    end
    
    local replica = PlayerController.Replica
    if replica and replica.Data and replica.Data.Inventory then
        for itemName, amount in pairs(replica.Data.Inventory) do
            if type(amount) == "number" and amount > 0 then
                inventory[itemName] = amount
            end
        end
    end
    
    return inventory
end

local function getAvailableOres()
    local inventory = getPlayerInventory()
    local ores = {}
    
    local oreTypes = {"Copper", "Stone", "Iron", "Sand Stone", "Tin", "Cardboardite", "Silver", "Gold", "Bananite", "Mushroomite", "Platinum", "Aite","Poopite"}
    
    for _, oreName in ipairs(oreTypes) do
        if inventory[oreName] and inventory[oreName] > 0 then
            table.insert(ores, {Name = oreName, Amount = inventory[oreName]})
        end
    end
    
    if #ores == 0 then
        for itemName, amount in pairs(inventory) do
            if string.find(itemName, "Ore") or string.find(itemName, "ore") then
                table.insert(ores, {Name = itemName, Amount = amount})
            end
        end
    end
    
    return ores
end

function getTotalOreCount()
    local ores = getAvailableOres()
    local total = 0
    for _, ore in ipairs(ores) do
        total = total + ore.Amount
    end
    return total
end

local function selectRandomOres(count)
    local availableOres = getAvailableOres()
    
    if #availableOres == 0 then
        return nil, "لا توجد خامات في الجرد!"
    end
    
    local totalOres = 0
    for _, ore in ipairs(availableOres) do
        totalOres = totalOres + ore.Amount
    end
    
    if totalOres < count then
        return nil, string.format("لا توجد خامات كافية! تحتاج %d، لديك %d", count, totalOres)
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
    print("📦 فحص الجرد:")
    local ores = getAvailableOres()
    
    if #ores == 0 then
        warn("   ❌ لا توجد خامات في الجرد!")
        local inv = getPlayerInventory()
        if next(inv) then
            print("   📋 كل العناصر في الجرد:")
            for item, amount in pairs(inv) do
                print(string.format("      - %s: %d", item, amount))
            end
        else
            warn("   ⚠️ الجرد فارغ تماماً!")
        end
        return
    end
    
    print("   💎 الخامات المتاحة:")
    local total = 0
    for _, ore in ipairs(ores) do
        print(string.format("      - %s: %d", ore.Name, ore.Amount))
        total = total + ore.Amount
    end
    print(string.format("   📊 الإجمالي: %d خامات", total))
    print("   " .. string.rep("-", 28))
end

local function canDoObjective(objType)
    if objType == "Forge" then
        local totalOres = getTotalOreCount()
        if totalOres < QUEST_CONFIG.REQUIRED_ORE_COUNT then
            print(string.format("⏸️  لا يمكن التشكيل: فقط %d/%d خامات متاحة", totalOres, QUEST_CONFIG.REQUIRED_ORE_COUNT))
            return false
        end
    end
    return true
end

----------------------------------------------------------------
-- دوال مساعدة
----------------------------------------------------------------
local HOTKEY_MAP = {
    ["1"] = Enum.KeyCode.One,
    ["2"] = Enum.KeyCode.Two,
    ["3"] = Enum.KeyCode.Three,
    ["4"] = Enum.KeyCode.Four,
    ["5"] = Enum.KeyCode.Five,
    ["6"] = Enum.KeyCode.Six,
    ["7"] = Enum.KeyCode.Seven,
    ["8"] = Enum.KeyCode.Eight,
    ["9"] = Enum.KeyCode.Nine,
    ["0"] = Enum.KeyCode.Zero
}

local function pressKey(keyCode)
    if not keyCode then return end
    VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
    task.wait(0.05)
    VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
end

local function findPickaxeSlotKey()
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return nil end
    
    local hotbar = gui:FindFirstChild("BackpackGui") and gui.BackpackGui:FindFirstChild("Backpack") and gui.BackpackGui.Backpack:FindFirstChild("Hotbar")
    if hotbar then
        for _, slotFrame in ipairs(hotbar:GetChildren()) do
            local frame = slotFrame:FindFirstChild("Frame")
            local label = frame and frame:FindFirstChild("ToolName")
            if label and label:IsA("TextLabel") and string.find(label.Text, "Pickaxe") then
                return HOTKEY_MAP[slotFrame.Name]
            end
        end
    end
    
    return nil
end

local function findWeaponSlotKey()
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return nil end
    
    local hotbar = gui:FindFirstChild("BackpackGui") and gui.BackpackGui:FindFirstChild("Backpack") and gui.BackpackGui.Backpack:FindFirstChild("Hotbar")
    if hotbar then
        for _, slotFrame in ipairs(hotbar:GetChildren()) do
            local frame = slotFrame:FindFirstChild("Frame")
            local label = frame and frame:FindFirstChild("ToolName")
            if label and label:IsA("TextLabel") and not string.find(label.Text, "Pickaxe") and label.Text ~= "" then
                return HOTKEY_MAP[slotFrame.Name], label.Text
            end
        end
    end
    
    return nil, nil
end

local function checkMiningError()
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return false end
    
    local notif = gui:FindFirstChild("Notifications")
    if notif and notif:FindFirstChild("Screen") and notif.Screen:FindFirstChild("NotificationsFrame") then
        for _, child in ipairs(notif.Screen.NotificationsFrame:GetChildren()) do
            local lbl = child:FindFirstChild("TextLabel", true)
            if lbl and string.find(lbl.Text, "Someone else is already mining") then
                return true
            end
        end
    end
    
    return false
end

----------------------------------------------------------------
-- دوال مساعدة للصخور
----------------------------------------------------------------
local function getRockUndergroundPosition(rockModel)
    if not rockModel or not rockModel.Parent then return nil end
    
    local pivotCFrame = nil
    pcall(function()
        if rockModel.GetPivot then
            pivotCFrame = rockModel:GetPivot()
        elseif rockModel.WorldPivot then
            pivotCFrame = rockModel.WorldPivot
        end
    end)
    
    if pivotCFrame then
        local pos = pivotCFrame.Position
        return Vector3.new(pos.X, pos.Y - QUEST_CONFIG.UNDERGROUND_OFFSET, pos.Z)
    end
    
    if rockModel.PrimaryPart then
        local pos = rockModel.PrimaryPart.Position
        return Vector3.new(pos.X, pos.Y - QUEST_CONFIG.UNDERGROUND_OFFSET, pos.Z)
    end
    
    local part = rockModel:FindFirstChildWhichIsA("BasePart")
    if part then
        local pos = part.Position
        return Vector3.new(pos.X, pos.Y - QUEST_CONFIG.UNDERGROUND_OFFSET, pos.Z)
    end
    
    return nil
end

local function getRockHP(rock)
    if not rock or not rock.Parent then return 0 end
    local success, result = pcall(function()
        return rock:GetAttribute("Health") or 0
    end)
    return success and result or 0
end

local function isTargetValid(rock)
    if not rock or not rock.Parent then return false end
    if not rock:FindFirstChildWhichIsA("BasePart") then return false end
    local hp = getRockHP(rock)
    return hp > 0
end

local function findNearestRock()
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    
    local targetRock, minDist = nil, math.huge
    
    for _, folder in ipairs(MINING_FOLDER_PATH:GetChildren()) do
        if folder:IsA("Folder") or folder:IsA("Model") then
            for _, child in ipairs(folder:GetChildren()) do
                if child:IsA("SpawnLocation") or child.Name == "SpawnLocation" then
                    local rock = child:FindFirstChild(QUEST_CONFIG.ROCK_NAME)
                    if isTargetValid(rock) then
                        local pos = getRockUndergroundPosition(rock)
                        if pos then
                            local dist = (pos - hrp.Position).Magnitude
                            if dist < minDist then
                                minDist = dist
                                targetRock = rock
                            end
                        end
                    end
                end
            end
        end
    end
    
    return targetRock, minDist
end

local function watchRockHP(rock)
    if State.hpWatchConn then State.hpWatchConn:Disconnect() end
    if not rock then return end
    
    State.hpWatchConn = rock:GetAttributeChangedSignal("Health"):Connect(function()
        local hp = rock:GetAttribute("Health") or 0
        print(string.format("💥 تغيرت نقاط الصحة! الصحة الجديدة: %d", hp))
        if hp == 0 then
            print("✅ تم الكشف عن الصحة = 0! تغيير الهدف...")
            State.targetDestroyed = true
            if ToolController then ToolController.holdingM1 = false end
            Shared.SoftUnlockPosition()
        end
    end)
end

----------------------------------------------------------------
-- دوال مساعدة للزومبي
----------------------------------------------------------------
local function getZombieUndergroundPosition(zombieModel)
    if not zombieModel or not zombieModel.Parent then return nil end
    
    local hrp = zombieModel:FindFirstChild("HumanoidRootPart")
    if hrp then
        local pos = hrp.Position
        return Vector3.new(pos.X, pos.Y - QUEST_CONFIG.ZOMBIE_UNDERGROUND_OFFSET, pos.Z)
    end
    
    return nil
end

local function getZombieHP(zombie)
    if not zombie or not zombie.Parent then return 0 end
    local humanoid = zombie:FindFirstChild("Humanoid")
    if humanoid then
        return humanoid.Health or 0
    end
    return 0
end

local function isZombieValid(zombie)
    if not zombie or not zombie.Parent then return false end
    return getZombieHP(zombie) > 0
end

local function findNearestZombie()
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    
    local targetZombie, minDist = nil, math.huge
    
    for _, child in ipairs(LIVING_FOLDER:GetChildren()) do
        -- ✅ فقط أسماء على شكل "Zombie1234" (لا تشمل EliteZombie)
        if string.match(child.Name, "^Zombie%d+$") then
            if isZombieValid(child) then
                local pos = getZombieUndergroundPosition(child)
                if pos then
                    local dist = (pos - hrp.Position).Magnitude
                    if dist < minDist then
                        minDist = dist
                        targetZombie = child
                    end
                end
            end
        end
    end
    
    return targetZombie, minDist
end


local function watchZombieHP(zombie)
    if State.hpWatchConn then State.hpWatchConn:Disconnect() end
    if not zombie then return end
    
    local humanoid = zombie:FindFirstChild("Humanoid")
    if not humanoid then return end
    
    State.hpWatchConn = humanoid:GetPropertyChangedSignal("Health"):Connect(function()
        local hp = humanoid.Health or 0
        print(string.format("💥 تغيرت نقاط الصحة! الصحة الجديدة: %.1f", hp))
        if hp == 0 then
            print("✅ مات الزومبي! تغيير الهدف...")
            State.targetDestroyed = true
            if ToolController then ToolController.holdingM1 = false end
            Shared.SoftUnlockPosition()
        end
    end)
end

local function getBestWeapon()
    if not PlayerController or not PlayerController.Replica then return nil end
    
    local replica = PlayerController.Replica
    if not replica.Data or not replica.Data.Inventory or not replica.Data.Inventory.Equipments then
        return nil
    end
    
    local equipments = replica.Data.Inventory.Equipments
    local bestWeapon = nil
    local highestDmg = 0
    
    for id, item in pairs(equipments) do
        if type(item) == "table" and item.Type then
            if not string.find(item.Type, "Pickaxe") then
                local dmg = item.Dmg or 0
                if dmg > highestDmg then
                    highestDmg = dmg
                    bestWeapon = item
                end
            end
        end
    end
    
    return bestWeapon
end

----------------------------------------------------------------
-- خاصية عدم التصادم والحركة
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
    Shared.restoreCollisions()
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
    
    local reachedTarget = false
    
    State.moveConn = RunService.Heartbeat:Connect(function()
        if reachedTarget then return end
        
        -- التحقق من وجود الشخصية أو BodyVelocity
        if not char or not char.Parent or not hrp or not hrp.Parent then
            if State.moveConn then State.moveConn:Disconnect() State.moveConn = nil end
            if bv and bv.Parent then bv:Destroy() end
            if bg and bg.Parent then bg:Destroy() end
            State.bodyVelocity = nil
            State.bodyGyro = nil
            return
        end
        
        -- التحقق من تدمير BodyVelocity بواسطة اللعبة أو سكريبت آخر
        if not bv or not bv.Parent then
            warn("   ⚠️ تم تدمير BodyVelocity! إعادة الإنشاء...")
            
            -- إعادة إنشاء BodyVelocity
            bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bv.Parent = hrp
            State.bodyVelocity = bv
        end
        
        if not bg or not bg.Parent then
            bg = Instance.new("BodyGyro")
            bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
            bg.P = 10000
            bg.D = 500
            bg.Parent = hrp
            State.bodyGyro = bg
        end
        
        local currentPos = hrp.Position
        local direction = (targetPos - currentPos)
        local distance = direction.Magnitude
        
        if distance < 2 then
            print("   ✅ تم الوصول إلى الهدف!")
            
            reachedTarget = true
            
            bv.Velocity = Vector3.zero
            hrp.Velocity = Vector3.zero
            hrp.AssemblyLinearVelocity = Vector3.zero
            
            task.wait(0.1)
            
            if bv and bv.Parent then bv:Destroy() end
            if bg and bg.Parent then bg:Destroy() end
            State.bodyVelocity = nil
            State.bodyGyro = nil
            
            if State.moveConn then State.moveConn:Disconnect() State.moveConn = nil end
            
            if callback then callback() end
            return
        end
        
        local speed = math.min(QUEST_CONFIG.MOVE_SPEED, distance * 10)
        local velocity = direction.Unit * speed
        
        bv.Velocity = velocity
        bg.CFrame = CFrame.lookAt(currentPos, targetPos)
    end)
    
    return true
end

----------------------------------------------------------------
-- قفل الموقع
----------------------------------------------------------------
local function lockPositionLayingDown(targetPos)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    if State.positionLockConn then
        State.positionLockConn:Disconnect()
        State.positionLockConn = nil
    end
    
    local angle = math.rad(QUEST_CONFIG.LAYING_ANGLE)
    local baseCFrame = CFrame.new(targetPos)
    local layingCFrame = baseCFrame * CFrame.Angles(angle, 0, 0)
    
    State.positionLockConn = RunService.Heartbeat:Connect(function()
        if not char or not char.Parent or not hrp or not hrp.Parent then
            if State.positionLockConn then
                State.positionLockConn:Disconnect()
                State.positionLockConn = nil
            end
            return
        end
        
        hrp.CFrame = layingCFrame
        hrp.Velocity = Vector3.zero
        hrp.AssemblyLinearVelocity = Vector3.zero
    end)
    
    print("🔒 تم قفل الموقع (وضع الاستلقاء)")
end

local function lockPositionFollowTarget(targetModel)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp or not targetModel then return end
    
    if State.positionLockConn then
        State.positionLockConn:Disconnect()
        State.positionLockConn = nil
    end
    
    local angle = math.rad(QUEST_CONFIG.LAYING_ANGLE)
    
    State.positionLockConn = RunService.Heartbeat:Connect(function()
        if not char or not char.Parent or not hrp or not hrp.Parent then
            if State.positionLockConn then
                State.positionLockConn:Disconnect()
                State.positionLockConn = nil
            end
            return
        end
        
        if not targetModel or not targetModel.Parent then
            if State.positionLockConn then
                State.positionLockConn:Disconnect()
                State.positionLockConn = nil
            end
            return
        end
        
        local targetPos = getZombieUndergroundPosition(targetModel)
        if targetPos then
            local baseCFrame = CFrame.new(targetPos)
            local layingCFrame = baseCFrame * CFrame.Angles(angle, 0, 0)
            
            hrp.CFrame = layingCFrame
            hrp.Velocity = Vector3.zero
            hrp.AssemblyLinearVelocity = Vector3.zero
        end
    end)
    
    print("🔒 تم قفل الموقع (متابعة الهدف)")
end

local function unlockPosition()
    Shared.SoftUnlockPosition()
end

----------------------------------------------------------------
-- نظام البيع (مُصلح - التحقق من واجهة المستخدم بدلاً من النسخة)
----------------------------------------------------------------
local function getEquippedItemsFromUI()
    local equipped = {}
    
    print("   🔍 التحقق من العناصر المُجهزة من واجهة المستخدم...")
    
    -- التحقق من PlayerGui.Menu.Frame.Frame.Menus.Tools.Frame
    local menuUI = playerGui:FindFirstChild("Menu")
                   and playerGui.Menu:FindFirstChild("Frame")
                   and playerGui.Menu.Frame:FindFirstChild("Frame")
                   and playerGui.Menu.Frame.Frame:FindFirstChild("Menus")
                   and playerGui.Menu.Frame.Frame.Menus:FindFirstChild("Tools")
                   and playerGui.Menu.Frame.Frame.Menus.Tools:FindFirstChild("Frame")
    
    if not menuUI then
        warn("   ⚠️ واجهة قائمة الأدوات غير موجودة!")
        return equipped
    end
    
    for _, child in ipairs(menuUI:GetChildren()) do
        local equipButton = child:FindFirstChild("Equip")
        local equipLabel = equipButton and equipButton:FindFirstChild("TextLabel")
        
        if equipLabel and equipLabel:IsA("TextLabel") then
            local isEquipped = (equipLabel.Text == "Unequip")
            
            if isEquipped then
                -- child.Name قد يكون معرف GUID أو اسم المعول
                local identifier = child.Name
                equipped[identifier] = true
                
                print(string.format("      ✅ مُجهز: %s (واجهة المستخدم)", identifier))
            end
        end
    end
    
    return equipped
end

local function getSellableItems()
    if not PlayerController or not PlayerController.Replica then
        return {}
    end
    
    local replica = PlayerController.Replica
    if not replica.Data or not replica.Data.Inventory or not replica.Data.Inventory.Equipments then
        return {}
    end
    
    local sellable = {}
    
    -- ✅ التحقق من المُجهز من واجهة المستخدم بدلاً من النسخة
    local equippedItems = getEquippedItemsFromUI()
    
    for id, item in pairs(replica.Data.Inventory.Equipments) do
        if type(item) == "table" and item.Type then
            local isPickaxe = string.find(item.Type, "Pickaxe")
            
            -- ✅ التحقق من واجهة المستخدم (كلا من GUID والنوع/الاسم)
            local isEquipped = false
            
            -- 1. التحقق من GUID
            if item.GUID and equippedItems[item.GUID] then
                isEquipped = true
            end
            
            -- 2. التحقق من النوع (للمعول الذي يستخدم الاسم بدلاً من GUID)
            if equippedItems[item.Type] then
                isEquipped = true
            end
            
            -- 3. التحقق من الاسم
            if item.Name and equippedItems[item.Name] then
                isEquipped = true
            end
            
            -- ✅ بيع كل شيء غير مُجهز (بما في ذلك المعول)
            if not isEquipped then
                -- المعرف: المعول يستخدم النوع، والباقي يستخدم GUID
                local identifier = isPickaxe and item.Type or item.GUID
                
                table.insert(sellable, {
                    ID = id,
                    Identifier = identifier,
                    Type = item.Type,
                    Name = item.Name or item.Type,
                    Dmg = item.Dmg or 0,
                    IsPickaxe = isPickaxe
                })
            end
        end
    end
    
    return sellable
end

local function doSellUnequippedItems()
    print("💰 بيع العناصر غير المُجهزة...")
    
    local sellableItems = getSellableItems()
    
    if #sellableItems == 0 then
        print("   ✅ لا توجد عناصر للبيع (كلها مُجهزة)")
        return true
    end
    
    print(string.format("   📋 تم العثور على %d عناصر غير مُجهزة للبيع:", #sellableItems))
    for i, item in ipairs(sellableItems) do
        local idType = item.IsPickaxe and "الاسم" or "GUID"
        print(string.format("      %d. %s (%s: %s, الضرر: %d)", 
            i, item.Name, idType, item.Identifier, item.Dmg))
    end
    
    -- البحث عن NPC للبيع
    local proximity = Workspace:FindFirstChild("Proximity")
    local npc = proximity and (proximity:FindFirstChild(QUEST_CONFIG.SELL_NPC_NAME) or proximity:FindFirstChild("Greedy Cey"))
    
    if not npc then
        warn("   ❌ NPC البيع غير موجود!")
        return false
    end
    
    if not ProximityService or not DialogueService then
        warn("   ❌ الخدمات المطلوبة غير متوفرة!")
        return false
    end
    
    local soldCount = 0
    
    for _, item in ipairs(sellableItems) do
        print(string.format("   💰 بيع %s...", item.Name))
        
        -- 1. فتح الحوار
        local success1 = pcall(function()
            ProximityService:ForceDialogue(npc, "SellConfirm")
        end)
        
        if not success1 then
            warn("      ❌ فشل في فتح الحوار")
            continue
        end
        
        task.wait(0.2)
        
        -- 2. إرسال السلة (باستخدام المعرف)
        local basket = {[item.Identifier] = true}
        
        local success2 = pcall(function()
            DialogueService:RunCommand("SellConfirm", {Basket = basket})
        end)
        
        if success2 then
            soldCount = soldCount + 1
            print(string.format("      ✅ تم البيع!"))
            task.wait(0.3)
        else
            warn(string.format("      ❌ فشل في بيع %s", item.Name))
        end
        
        -- 3. إجبار استعادة واجهة المستخدم
        pcall(function()
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
            end
            
            local gui = player:FindFirstChild("PlayerGui")
            if gui then
                local dUI = gui:FindFirstChild("DialogueUI")
                if dUI then dUI.Enabled = false end
            end
        end)
        
        task.wait(0.5)
    end
    
    print(string.format("   ✅ تم البيع! تم بيع %d/%d عناصر", soldCount, #sellableItems))
    
    -- استعادة نهائية
    local gui = player:FindFirstChild("PlayerGui")
    if gui then
        local main = gui:FindFirstChild("Main")
        if main then main.Enabled = true end
        
        local backpack = gui:FindFirstChild("BackpackGui")
        if backpack then backpack.Enabled = true end
    end
    
    return true
end

----------------------------------------------------------------
-- إدارة واجهة المستخدم
----------------------------------------------------------------
local function closeForgeUI()
    print("🔧 إغلاق واجهة التشكيل...")
    
    local closed = false
    
    if UIController and UIController.Close then
        pcall(function()
            if UIController.Modules and UIController.Modules.Forge then
                UIController:Close("Forge")
                print("   ✅ تم الإغلاق عبر وحدة تحكم الواجهة")
                closed = true
            end
        end)
    end
    
    if not closed then
        pcall(function()
            local forgeGui = playerGui:FindFirstChild("Forge") or playerGui:FindFirstChild("ForgeUI")
            if forgeGui then
                forgeGui.Enabled = false
                print("   ✅ تم الإغلاق عبر PlayerGui")
                closed = true
            end
        end)
    end
    
    if not closed then
        warn("   ⚠️ لم يتمكن من إغلاق واجهة التشكيل (ربما مغلقة بالفعل)")
    end
    
    task.wait(0.3)
end

local function restoreUI()
    print("🔧 استعادة حالة واجهة المستخدم...")
    
    local char = player.Character
    if char then
        local status = char:FindFirstChild("Status")
        if status then
            for _, tag in ipairs(status:GetChildren()) do
                if tag.Name == "DisableBackpack" or tag.Name == "NoMovement" or tag.Name == "Talking" then
                    pcall(function() tag:Destroy() end)
                end
            end
        end
        
        local humanoid = char:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = 16
            humanoid.JumpPower = 50
        end
    end
    
    local gui = player:FindFirstChild("PlayerGui")
    if gui then
        local main = gui:FindFirstChild("Main")
        if main then main.Enabled = true end
        
        local backpack = gui:FindFirstChild("BackpackGui")
        if backpack then backpack.Enabled = true end
        
        local dialogueUI = gui:FindFirstChild("DialogueUI")
        if dialogueUI then dialogueUI.Enabled = false end
    end
    
    local cam = Workspace.CurrentCamera
    if cam then
        cam.CameraType = Enum.CameraType.Custom
    end
    
    print("✅ تم استعادة حالة واجهة المستخدم!")
end

----------------------------------------------------------------
-- نظام التشكيل
----------------------------------------------------------------
getgenv().ForgeHookActive = getgenv().ForgeHookActive or false

local function setupForgeHook()
    if getgenv().ForgeHookActive then
        print("⚙️  خطاف التشكيل مفعل بالفعل")
        return
    end
    
    if not ForgeService then
        warn("❌ خدمة التشكيل غير متوفرة!")
        return
    end
    
    print("🔧 تركيب خطاف التشكيل...")
    
    local originalChangeSequence = ForgeService.ChangeSequence
    
    ForgeService.ChangeSequence = function(self, sequenceName, args)
        print("🔨 تسلسل: " .. sequenceName)
        
        local success, result = pcall(originalChangeSequence, self, sequenceName, args)
        
        task.spawn(function()
            if sequenceName == "Melt" then
                print("   ⏳ صب تلقائي بعد 8 ثواني...")
                task.wait(8)
                self:ChangeSequence("Pour", {ClientTime = 8.5, InContact = true})
            elseif sequenceName == "Pour" then
                print("   ⏳ طرق تلقائي بعد 5 ثواني...")
                task.wait(5)
                self:ChangeSequence("Hammer", {ClientTime = 5.2})
            elseif sequenceName == "Hammer" then
                print("   ⏳ ري تلقائي بعد 6 ثواني...")
                task.wait(6)
                self:ChangeSequence("Water", {ClientTime = 6.5})
            elseif sequenceName == "Water" then
                print("   ⏳ عرض تلقائي بعد 3 ثواني...")
                task.wait(3)
                self:ChangeSequence("Showcase", {})
            elseif sequenceName == "Showcase" then
                print("   ✅ اكتمل التشكيل!")
                -- ✅ لا يتم إغلاق الواجهة هنا (تتم معالجتها في doForge())
            end
        end)
        
        return success, result
    end
    
    getgenv().ForgeHookActive = true
    print("✅ تم تركيب خطاف التشكيل!")
end

local function moveToForge()
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    local forgePos = QUEST_CONFIG.FORGE_POSITION
    local currentDist = (forgePos - hrp.Position).Magnitude

    print(string.format("🚶 التحرك إلى التشكيل عند (%.1f, %.1f, %.1f) (يبعد %.1f وحدات)...", 
        forgePos.X, forgePos.Y, forgePos.Z, currentDist))

    -- 🆕 فك القفل قبل التحرك
    unlockPosition()

    local moveComplete = false
    smoothMoveTo(forgePos, function()
        moveComplete = true
    end)

    local timeout = 60
    local startTime = tick()
    while not moveComplete and tick() - startTime < timeout do
        task.wait(0.1)
    end
    
    if not moveComplete then
        warn("   ⚠️ انتهى وقت التحرك! إعادة المحاولة...")
        if State.moveConn then State.moveConn:Disconnect() State.moveConn = nil end
        if State.bodyVelocity then State.bodyVelocity:Destroy() State.bodyVelocity = nil end
        if State.bodyGyro then State.bodyGyro:Destroy() State.bodyGyro = nil end
        return false
    end

    if State.moveConn then State.moveConn:Disconnect() State.moveConn = nil end
    if State.bodyVelocity then State.bodyVelocity:Destroy() State.bodyVelocity = nil end
    if State.bodyGyro then State.bodyGyro:Destroy() State.bodyGyro = nil end

    print("✅ تم الوصول إلى التشكيل!")
    print("   ⏳ الانتظار 1.5 ثانية قبل فتح واجهة التشكيل...")
    task.wait(1.5)

    return true
end


local function startForge(oreSelection)
    print("🔨 بدء التشكيل مع:")
    for oreName, amount in pairs(oreSelection) do
        print(string.format("   - %s x%d", oreName, amount))
    end

    if not FORGE_OBJECT then
        warn("❌ كائن التشكيل غير موجود!")
        return false
    end

    pcall(function()
        PROXIMITY_RF:InvokeServer(FORGE_OBJECT)
    end)

    task.wait(1)

    if not ForgeService then return false end

    local forgeSuccess = pcall(function()
        ForgeService:ChangeSequence("Melt", {
            Ores = oreSelection,
            ItemType = QUEST_CONFIG.ITEM_TYPE,
            FastForge = false
        })
    end)

    if forgeSuccess then
        print("✅ بدأ التشكيل بالذوبان!")
        return true
    else
        return false
    end
end
----------------------------------------------------------------
-- الأهداف
----------------------------------------------------------------
local function doPurchaseIronPickaxe()
    print("🛒 الهدف 1: شراء معول حديدي...")
    
    if not PURCHASE_RF then
        warn("   ❌ ريموت الشراء غير متوفر!")
        return false
    end
    
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    
    if hrp then
        local npcPos = QUEST_CONFIG.NPC_POSITION
        local currentDist = (npcPos - hrp.Position).Magnitude
        
        print(string.format("   🚶 التحرك إلى NPC عند (%.2f, %.2f, %.2f) (يبعد %.1f وحدات)...", 
            npcPos.X, npcPos.Y, npcPos.Z, currentDist))
        
        -- 🆕 فك القفل قبل التحرك
        unlockPosition()
        
        local moveComplete = false
        smoothMoveTo(npcPos, function()
            moveComplete = true
        end)
        
        local timeout = 60
        local startTime = tick()
        while not moveComplete and tick() - startTime < timeout do
            task.wait(0.1)
        end
        
        if not moveComplete then
            warn("   ⚠️ انتهى وقت التحرك! إعادة المحاولة...")
            if State.moveConn then State.moveConn:Disconnect() State.moveConn = nil end
            if State.bodyVelocity then State.bodyVelocity:Destroy() State.bodyVelocity = nil end
            if State.bodyGyro then State.bodyGyro:Destroy() State.bodyGyro = nil end
            return false
        end
        
        if State.moveConn then State.moveConn:Disconnect() State.moveConn = nil end
        if State.bodyVelocity then State.bodyVelocity:Destroy() State.bodyVelocity = nil end
        if State.bodyGyro then State.bodyGyro:Destroy() State.bodyGyro = nil end
        
        print("   ✅ تم الوصول إلى NPC!")
        print("   ⏳ الانتظار 1.5 ثانية قبل الشراء...")
        task.wait(1.5)
    end
    
    print(string.format("   💰 شراء %s (الكمية: %d)", QUEST_CONFIG.PICKAXE_NAME, QUEST_CONFIG.PICKAXE_AMOUNT))
    
    local args = {QUEST_CONFIG.PICKAXE_NAME, QUEST_CONFIG.PICKAXE_AMOUNT}
    local success, result = pcall(function()
        return PURCHASE_RF:InvokeServer(unpack(args))
    end)
    
    if success then
        print("   ✅ تم الشراء بنجاح!")
        return true
    else
        warn("   ❌ فشل الشراء: " .. tostring(result))
        return false
    end
end

local function doMinePebble()
    print("⛏️  الهدف 4: تعدين الحصى...")
    
    IsMiningActive = true
    
    print("   " .. string.rep("-", 30))
    print("   🔄 بدء حلقة تعدين الحصى...")
    print("   " .. string.rep("-", 30))
    
    while isQuest7StillActive() and not isCurrentObjectiveComplete() do
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        
        if not hrp then
            warn("   ⚠️ انتظار الشخصية...")
            task.wait(2)
            continue
        end
        
        cleanupState()
        
        local targetRock, dist = findNearestRock()
        if not targetRock then
            warn("   ⚠️ لم يتم العثور على حصى، الانتظار...")
            task.wait(2)
            continue
        end
        
        State.currentTarget = targetRock
        State.targetDestroyed = false
        
        local targetPos = getRockUndergroundPosition(targetRock)
        if not targetPos then
            warn("   ⚠️ لا يمكن الحصول على موقع الحصى!")
            task.wait(1)
            continue
        end
        
        local currentHP = getRockHP(targetRock)
        print(string.format("   🎯 الهدف: %s (المسافة: %d، الصحة: %d)", targetRock.Parent.Name, math.floor(dist), currentHP))
        
        watchRockHP(targetRock)
        
        -- 🆕 فك القفل قبل التحرك
        unlockPosition()
        
        local moveStarted = false
        smoothMoveTo(targetPos, function()
            lockPositionLayingDown(targetPos)
            moveStarted = true
        end)
        
        local timeout = 60
        local startTime = tick()
        while not moveStarted and tick() - startTime < timeout do
            task.wait(0.1)
        end
        
        if not moveStarted then
            lockPositionLayingDown(targetPos)
        end
        
        task.wait(0.5)
        
        while not State.targetDestroyed and isQuest7StillActive() and not isCurrentObjectiveComplete() do
            if not char or not char.Parent then
                print("   ⚠️ ماتت الشخصية!")
                break
            end
            
            if not targetRock or not targetRock.Parent then
                print("   ⚠️ تم إزالة الهدف!")
                State.targetDestroyed = true
                break
            end
            
            if checkMiningError() then
                print("   ⚠️ شخص آخر يقوم بالتعدين!")
                State.targetDestroyed = true
                if ToolController then ToolController.holdingM1 = false end
                break
            end
            
            local toolInHand = char:FindFirstChildWhichIsA("Tool")
            local isPickaxeHeld = toolInHand and string.find(toolInHand.Name, "Pickaxe")
            
            if not isPickaxeHeld then
                if ToolController then ToolController.holdingM1 = false end
                
                local key = findPickaxeSlotKey()
                if key then
                    pressKey(key)
                    task.wait(0.3)
                else
                    pcall(function()
                        CHAR_RF:InvokeServer({Runes = {}}, {Name = QUEST_CONFIG.PICKAXE_NAME})
                    end)
                    task.wait(0.5)
                end
            else
                if ToolController and ToolActivatedFunc then
                    ToolController.holdingM1 = true
                    pcall(function()
                        ToolActivatedFunc(ToolController, toolInHand)
                    end)
                else
                    pcall(function()
                        TOOL_RF_BACKUP:InvokeServer(toolInHand.Name, true)
                    end)
                end
            end
            
            task.wait(0.15)
        end
        
        --unlockPosition()
        
        if isCurrentObjectiveComplete() then
            print("   ✅ الهدف 4 (تعدين الحصى) مكتمل!")
            break
        end
        
        print("   🔄 البحث عن الهدف التالي...")
        task.wait(0.5)
    end
    
    print("   ⛏️  انتهى التعدين")
    IsMiningActive = false
    unlockPosition()
    disableNoclip()
    cleanupState()
end

local function doKillZombies()
    print("⚔️  الهدف 2: قتل الزومبي...")
    
    IsKillingActive = true
    
    print("   " .. string.rep("-", 30))
    print("   🔄 بدء حلقة صيد الزومبي...")
    print("   " .. string.rep("-", 30))
    
    while isQuest7StillActive() and not isCurrentObjectiveComplete() do
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        
        if not hrp then
            warn("   ⚠️ انتظار الشخصية...")
            task.wait(2)
            continue
        end
        
        cleanupState()
        
        local targetZombie, dist = findNearestZombie()
        if not targetZombie then
            warn("   ⚠️ لم يتم العثور على زومبي، الانتظار...")
            task.wait(2)
            continue
        end
        
        State.currentTarget = targetZombie
        State.targetDestroyed = false
        
        local targetPos = getZombieUndergroundPosition(targetZombie)
        if not targetPos then
            warn("   ⚠️ لا يمكن الحصول على موقع الزومبي!")
            task.wait(1)
            continue
        end
        
        local currentHP = getZombieHP(targetZombie)
        print(string.format("   🎯 الهدف: %s (المسافة: %d، الصحة: %.1f)", targetZombie.Name, math.floor(dist), currentHP))
        
        watchZombieHP(targetZombie)
        
        -- 🆕 فك القفل قبل التحرك
        unlockPosition()
        
        local moveStarted = false
        smoothMoveTo(targetPos, function()
            lockPositionFollowTarget(targetZombie)
            moveStarted = true
        end)
        
        local timeout = 60
        local startTime = tick()
        while not moveStarted and tick() - startTime < timeout do
            task.wait(0.1)
        end
        
        -- ❌ لا تقم بقفل صارم إذا لم تصل إلى الهدف أبداً
        if not moveStarted then
            warn("   ⚠️ انتهى وقت التحرك، تخطي هذا الزومبي لتجنب النقل")
            State.targetDestroyed = true
            unlockPosition()
            continue
        end
        
        task.wait(0.5)
        
        while not State.targetDestroyed and isQuest7StillActive() and not isCurrentObjectiveComplete() do
            if not char or not char.Parent then
                print("   ⚠️ ماتت الشخصية!")
                break
            end
            
            if not targetZombie or not targetZombie.Parent or not isZombieValid(targetZombie) then
                print("   ⚠️ تم إزالة الهدف أو مات!")
                State.targetDestroyed = true
                unlockPosition()  
                break
            end
            
            local currentZombiePos = getZombieUndergroundPosition(targetZombie)
            if currentZombiePos and hrp then
                local distToZombie = (currentZombiePos - hrp.Position).Magnitude
                if distToZombie > QUEST_CONFIG.ZOMBIE_MAX_DISTANCE then
                    print(string.format("   ⚠️ تحرك الزومبي بعيداً جداً! (%.1f وحدات) تغيير الهدف...", distToZombie))
                    State.targetDestroyed = true
                    unlockPosition()
                    break
                end
            end
            
            local toolInHand = char:FindFirstChildWhichIsA("Tool")
            local isWeaponHeld = toolInHand and not string.find(toolInHand.Name, "Pickaxe")
            
            if not isWeaponHeld then
                if ToolController then ToolController.holdingM1 = false end
                
                local bestWeapon = getBestWeapon()
                if bestWeapon then
                    print(string.format("   ⚔️  تجهيز السلاح: %s", bestWeapon.Type))
                    pcall(function()
                        CharacterService:EquipItem(bestWeapon)
                    end)
                    task.wait(0.5)
                else
                    local key, weaponName = findWeaponSlotKey()
                    if key then
                        print(string.format("   ⚔️  تجهيز عبر المفتاح السريع: %s", weaponName))
                        pressKey(key)
                        task.wait(0.3)
                    else
                        warn("   ❌ لم يتم العثور على سلاح!")
                        task.wait(1)
                    end
                end
            else
                if ToolController and ToolActivatedFunc then
                    ToolController.holdingM1 = true
                    pcall(function()
                        ToolActivatedFunc(ToolController, toolInHand)
                    end)
                else
                    pcall(function()
                        TOOL_RF_BACKUP:InvokeServer(toolInHand.Name, true)
                    end)
                end
            end
            
            task.wait(0.15)
        end
        
        --unlockPosition()
        
        if isCurrentObjectiveComplete() then
            print("   ✅ الهدف 2 (قتل الزومبي) مكتمل!")
            break
        end
        
        print("   🔄 البحث عن الهدف التالي...")
        task.wait(0.5)
    end
    
    print("   ⚔️  انتهى صيد الزومبي")
    IsKillingActive = false
    unlockPosition()
    disableNoclip()
    cleanupState()
end

local function doForge()
    print("🔨 الهدف 3: تشكيل الدرع...")
    
    IsForgingActive = true
    
    print("\n" .. string.rep("=", 50))
    print("📋 الخطوة 1: بيع العناصر غير المُجهزة")
    print(string.rep("=", 50))
    
    doSellUnequippedItems()
    
    print("\n" .. string.rep("=", 50))
    print("🔨 الخطوة 2: بدء التشكيل")
    print(string.rep("=", 50))
    
    setupForgeHook()
    moveToForge()
    
    local forgeAttempts = 0
    
    while isQuest7StillActive() and not isCurrentObjectiveComplete() do
        forgeAttempts = forgeAttempts + 1
        print(string.format("\n🔨 محاولة تشكيل #%d", forgeAttempts))
        
        printInventorySummary()
        
        local totalOres = getTotalOreCount()
        if totalOres < QUEST_CONFIG.REQUIRED_ORE_COUNT then
            warn(string.format("❌ خامات غير كافية! لديك %d، تحتاج %d", totalOres, QUEST_CONFIG.REQUIRED_ORE_COUNT))
            warn("⚠️ هذا لا يجب أن يحدث - يجب إكمال هدف التعدين أولاً!")
            break
        end
        
        local oreSelection, errorMsg = selectRandomOres(QUEST_CONFIG.REQUIRED_ORE_COUNT)
        if not oreSelection then
            warn(string.format("❌ خطأ: %s", errorMsg))
            break
        end
        
        local success = startForge(oreSelection)
        if success then
            print("   ⏳ الانتظار حتى اكتمال التشكيل...")
            task.wait(27)
        else
            warn("   ❌ فشل التشكيل، إعادة المحاولة بعد 3 ثواني...")
            task.wait(3)
        end
        
        if isCurrentObjectiveComplete() then
            print("   ✅ الهدف 3 (التشكيل) مكتمل!")
            break
        end
        
        print(string.format("   ⏸️  فترة تبريد لمدة %d ثانية...", QUEST_CONFIG.FORGE_DELAY))
        task.wait(QUEST_CONFIG.FORGE_DELAY)
    end
    
    -- ✅ مُصلح: إضافة إغلاق الواجهة (مثل المهمة 3)
    print("\n🚪 إغلاق واجهة التشكيل...")
    closeForgeUI()
    task.wait(0.5)
    restoreUI()
    
    print("   🔨 انتهى التشكيل")
    IsForgingActive = false
    disableNoclip()
    cleanupState()
end

----------------------------------------------------------------
-- مشغل المهمة الذكي
----------------------------------------------------------------
print(string.rep("=", 50))
print("🚀 المهمة 7: " .. QUEST_CONFIG.QUEST_NAME)
print("⚙️  نظام ذكي: قائم على الأولويات + مرن")
print("📋 ترتيب الأولويات: شراء → قتل → تعدين → تشكيل")
print("💰 نظام البيع: التحقق من واجهة المستخدم (اسم المعول + معرف السلاح/الدرع)")
print(string.rep("=", 50))

local questID, objList = getQuestObjectives(QUEST_CONFIG.QUEST_NAME)

if not questID then
    warn("❌ المهمة '" .. QUEST_CONFIG.QUEST_NAME .. "' غير موجودة!")
    Quest7Active = false
    return
end

print("✅ تم العثور على المهمة (المعرف: " .. questID .. ")\n")

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
        for i, priorityType in ipairs(QUEST_CONFIG.PRIORITY_ORDER) do
            if string.find(type, priorityType) then
                return i
            end
        end
        return 999
    end
    return getPriority(a.type) < getPriority(b.type)
end)

print(string.rep("=", 50))
print("📋 أهداف المهمة (ترتيب الأولوية):")
for i, obj in ipairs(objectives) do
    local complete = isObjectiveComplete(obj.frame)
    print(string.format("   %d. [%s] %s %s", i, obj.type, obj.text, complete and "✅" or "⏳"))
end
print(string.rep("=", 50))


-- 🆕 مساعد: التحقق إذا كان هناك شراء غير مكتمل
local function hasIncompletePurchase()
    for _, obj in ipairs(objectives) do
        if obj.type == "Purchase" and not isObjectiveComplete(obj.frame) then
            return true
        end
    end
    return false
end

local maxAttempts = 10
local attempt = 0

while isQuest7StillActive() and attempt < maxAttempts do
    attempt = attempt + 1
    print(string.format("\n🔄 دورة المهمة #%d", attempt))
    
    local allComplete = true
    local didSomething = false
    local purchasePending = hasIncompletePurchase()
    
    for _, obj in ipairs(objectives) do
        if not isQuest7StillActive() then
            print("🛑 المهمة اختفت!")
            break
        end
        
        local complete = isObjectiveComplete(obj.frame)
        
        if not complete then
            allComplete = false

            -- ⛔ إذا كان الشراء غير مكتمل → لا تقم بالقتل / التعدين / التشكيل
            if purchasePending and obj.type ~= "Purchase" then
                print(string.format("⏭️  تخطي [%s] (انتظار إكمال الشراء)", obj.type))
                continue
            end
            
            if not canDoObjective(obj.type) then
                print(string.format("⏸️  تخطي [%s] - لا يمكن التنفيذ الآن", obj.type))
                continue
            end
            
            State.currentObjectiveFrame = obj.frame
            
            print(string.format("\n▶️  معالجة [%s]: %s", obj.type, obj.text))
            
            if obj.type == "Purchase" then
                doPurchaseIronPickaxe()
                didSomething = true
                task.wait(2)
                
                -- 🆕 إعادة التحقق إذا اكتمل الشراء بعد التنفيذ
                if isObjectiveComplete(obj.frame) then
                    purchasePending = false
                    print("   ✅ هدف الشراء مكتمل! المتابعة للأهداف الأخرى...")
                end
            elseif obj.type == "Kill" then
                doKillZombies()
                didSomething = true
                task.wait(1)
            elseif obj.type == "Mine" then
                doMinePebble()
                didSomething = true
                task.wait(1)
            elseif obj.type == "Forge" then
                doForge()
                didSomething = true
                task.wait(1)
            else
                warn("❌ نوع الهدف غير معروف: " .. obj.type)
            end
            
            task.wait(1)
            
            if isObjectiveComplete(obj.frame) then
                print(string.format("✅ [%s] مكتمل!", obj.type))
            else
                print(string.format("⏳ [%s] لا يزال قيد التقدم", obj.type))
            end
        end
    end
    
    if allComplete then
        print("\n🎉 جميع الأهداف مكتملة!")
        break
    end
    
    if not didSomething then
        warn("⚠️ لا يمكن إكمال أي هدف في هذه الدورة!")
        print("   ⏳ الانتظار 3 ثواني قبل إعادة المحاولة...")
        task.wait(3)
    end
end

task.wait(2)

local allComplete = true
for _, obj in ipairs(objectives) do
    if not isObjectiveComplete(obj.frame) then
        allComplete = false
        warn(string.format("❌ [%s] غير مكتمل: %s", obj.type, obj.text))
    end
end

if allComplete then
    print("\n" .. string.rep("=", 50))
    print("🏆 المهمة 7 مكتملة!")
    print(string.rep("=", 50))
else
    warn("\n" .. string.rep("=", 50))
    warn("⚠️ المهمة 7 غير مكتملة بعد " .. attempt .. " دورة")
    warn(string.rep("=", 50))
end

Quest7Active = false
IsMiningActive = false
IsKillingActive = false
IsForgingActive = false
unlockPosition()
disableNoclip()
cleanupState()