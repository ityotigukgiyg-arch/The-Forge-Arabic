local Shared = _G.Shared

-- المهمة 19: التعدين + البيع التلقائي والشراء التلقائي
-- ✅ الأولوية 1: تهيئة البيع التلقائي (إعداد لمرة واحدة)
-- ✅ الأولوية 2: المهام الخلفية (البيع التلقائي + الشراء التلقائي - تعمل دائمًا)
-- ✅ الأولوية 3: التعدين (صخر البازلت / نواة البازلت)

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
local Quest19Active = true
local IsMiningActive = false
local DEBUG_MODE = true

local QUEST_CONFIG = {
    QUEST_NAME = "التعدين + البيع والشراء التلقائي",
    REQUIRED_LEVEL = 10,
    
    -- الأولوية 1: البيع التلقائي (الخام)
    AUTO_SELL_ENABLED = true,
    AUTO_SELL_INTERVAL = 10,
    AUTO_SELL_NPC_NAME = "Greedy Cey",
    
    -- الأولوية 2: الشراء التلقائي لفأس الكوبالت (خلفية)
    AUTO_BUY_ENABLED = true,
    AUTO_BUY_INTERVAL = 15,
    TARGET_PICKAXE = "Cobalt Pickaxe",
    MIN_GOLD_TO_BUY = 10000,
    SHOP_POSITION = Vector3.new(-165, 22, -111.7),
    
    -- الأولوية 2.5: الشراء التلقائي لفأس الماجما (الذهب >= 150k)
    MAGMA_PICKAXE_CONFIG = {
        ENABLED = true,
        TARGET_PICKAXE = "Magma Pickaxe",
        MIN_GOLD_TO_BUY = 150000,
        SELL_SHOP_POSITION = Vector3.new(-115.1, 22.3, -92.3),  -- بيع الأسلحة/الدروع
        BUY_SHOP_POSITION = Vector3.new(378, 88.6, 109.6),       -- شراء فأس الماجما
    },

    -- الأولوية 2.8: فحص سعة المخزن
    STASH_CHECK_CONFIG = {
        ENABLED = true,
        CHECK_INTERVAL = 20, -- ثواني
        FULL_COOLDOWN = 60,  -- فترة انتظار بعد التفريغ (سيتم التعامل معها كثواني في الكود، المستخدم قال 1 دقيقة = 60 ثانية)
        SHOP_POSITION = Vector3.new(-165, 22, -111.7),
        NPC_NAME = "Greedy Cey",
    },
    
    -- الأولوية 3: التعدين (افتراضي: صخر البازلت)
    ROCK_NAME = "Basalt Rock",
    UNDERGROUND_OFFSET = 4,
    LAYING_ANGLE = 90,
    MOVE_SPEED = 25,  
    STOP_DISTANCE = 2,
    
    MINING_PATHS = {
        "Island2CaveStart",
        "Island2CaveDanger1",
        "Island2CaveDanger2",
        "Island2CaveDanger3",
        "Island2CaveDanger4",
        "Island2CaveDangerClosed",
        "Island2CaveDeep",
        "Island2CaveLavaClosed",
        "Island2CaveMid",
    },
    
    -- المستوى 2: نواة البازلت (إذا كان لديك فأس الكوبالت)
    BASALT_CORE_CONFIG = {
        ROCK_NAME = "Basalt Core",
        MINING_PATHS = {
            "Island2CaveStart",
            "Island2CaveDanger1",
            "Island2CaveDanger2",
            "Island2CaveDanger3",
            "Island2CaveDanger4",
            "Island2CaveDangerClosed",
            "Island2CaveDeep",
            "Island2CaveLavaClosed",
            "Island2CaveMid",
        },
    },
    
    -- المستوى 3: عروق البازلت (إذا كان لديك فأس الماجما)
    BASALT_VEIN_CONFIG = {
        ROCK_NAME = "Basalt Core",
        MINING_PATHS = {
            "Island2CaveStart",
            "Island2CaveDanger1",
            "Island2CaveDanger2",
            "Island2CaveDanger3",
            "Island2CaveDanger4",
            "Island2CaveDangerClosed",
            "Island2CaveDeep",
            "Island2CaveLavaClosed",
            "Island2CaveMid",
        },
    },
    
    WAYPOINTS = {
        Vector3.new(-154.5, 39.1, 138.8),
        Vector3.new(11, 46.5, 124.2),
        Vector3.new(65, 74.2, -44),
    },
    
    WAYPOINT_STOP_DISTANCE = 5,
    MAX_ROCKS_TO_MINE = 99999999999999,
    HOLD_POSITION_AFTER_MINE = true,
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

pcall(function()
    CharacterService = Knit.GetService("CharacterService")
    PlayerController = Knit.GetController("PlayerController")
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

local SERVICES = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Services")

local PORTAL_RF = nil
pcall(function()
    PORTAL_RF = SERVICES:WaitForChild("PortalService", 5):WaitForChild("RF", 3):WaitForChild("TeleportToIsland", 3)
end)

local CHAR_RF = nil
pcall(function()
    CHAR_RF = SERVICES:WaitForChild("CharacterService", 5):WaitForChild("RF", 3):WaitForChild("EquipItem", 3)
end)

local TOOL_RF_BACKUP = nil
pcall(function()
    TOOL_RF_BACKUP = SERVICES:WaitForChild("ToolService", 5):WaitForChild("RF", 3):WaitForChild("ToolActivated", 3)
end)

local DIALOGUE_RF = nil
local DialogueRE = nil
pcall(function()
    local dialogueService = SERVICES:WaitForChild("DialogueService", 5)
    DIALOGUE_RF = dialogueService:WaitForChild("RF", 3):WaitForChild("RunCommand", 3)
    DialogueRE = dialogueService:WaitForChild("RE", 3):WaitForChild("DialogueEvent", 3)
end)

local ProximityDialogueRF = nil
local PURCHASE_RF = nil
pcall(function()
    local proximityService = SERVICES:WaitForChild("ProximityService", 5)
    ProximityDialogueRF = proximityService:WaitForChild("RF", 3):WaitForChild("Dialogue", 3)
    PURCHASE_RF = proximityService:WaitForChild("RF", 3):WaitForChild("Purchase", 3)
end)

local FORGES_FOLDER = Workspace:WaitForChild("Forges")
local MINING_FOLDER_PATH = Workspace:WaitForChild("Rocks")

if PORTAL_RF then print("✅ بوابة التحكم جاهزة!") else warn("⚠️ لم يتم العثور على بوابة التحكم") end
if PlayerController then print("✅ وحدة تحكم اللاعب جاهزة!") else warn("⚠️ لم يتم العثور على وحدة تحكم اللاعب") end
if ToolController then print("✅ وحدة تحكم الأدوات جاهزة!") else warn("⚠️ لم يتم العثور على وحدة تحكم الأدوات") end
if DIALOGUE_RF then print("✅ التحكم بالحوار جاهز!") else warn("⚠️ لم يتم العثور على التحكم بالحوار") end
if PURCHASE_RF then print("✅ التحكم بالشراء جاهز!") else warn("⚠️ لم يتم العثور على التحكم بالشراء") end

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
    
    autoSellTask = nil,
    autoBuyTask = nil,
    isPaused = false,
}

-- 🛡️ القائمة السوداء للصخور التي يقوم شخص آخر بتعدينها
-- الصيغة: { [rockModel] = expireTime }
local OccupiedRocks = {}
local OCCUPIED_TIMEOUT = 10  -- إزالة من القائمة السوداء بعد 10 ثواني

local function isRockOccupied(rock)
    if not rock then return false end
    local expireTime = OccupiedRocks[rock]
    if not expireTime then return false end
    
    if tick() > expireTime then
        OccupiedRocks[rock] = nil
        return false
    end
    return true
end

local function markRockAsOccupied(rock)
    if not rock then return end
    OccupiedRocks[rock] = tick() + OCCUPIED_TIMEOUT
    print(string.format("   🚫 أضيف إلى القائمة السوداء لمدة %d ثانية: %s", OCCUPIED_TIMEOUT, rock.Name))
end

local function cleanupExpiredBlacklist()
    local now = tick()
    for rock, expireTime in pairs(OccupiedRocks) do
        if now > expireTime or not rock.Parent then
            OccupiedRocks[rock] = nil
        end
    end
end

-- استخدم _G للحفاظ على الحالة عبر إعادة تحميل السكربت (اللودر يشغل المهمة 19 في حلقة)
_G.Quest19AutoSellInitialized = _G.Quest19AutoSellInitialized or false
local AutoSellInitialized = _G.Quest19AutoSellInitialized

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
-- نظام الذهب
----------------------------------------------------------------
local function getGold()
    local goldLabel = playerGui:FindFirstChild("Main")
                     and playerGui.Main:FindFirstChild("Screen")
                     and playerGui.Main.Screen:FindFirstChild("Hud")
                     and playerGui.Main.Screen.Hud:FindFirstChild("Gold")
    
    if not goldLabel or not goldLabel:IsA("TextLabel") then
        return 0
    end
    
    local goldText = goldLabel.Text
    local goldString = string.gsub(goldText, "[$,]", "")
    local gold = tonumber(goldString)
    
    return gold or 0
end

----------------------------------------------------------------
-- فحص الجرد
----------------------------------------------------------------
local function hasPickaxe(pickaxeName)
    -- فحص الواجهة: PlayerGui.Menu.Frame.Frame.Menus.Tools.Frame
    local menu = playerGui:FindFirstChild("Menu")
    if not menu then
        if DEBUG_MODE then
            warn("[Q18] القائمة غير موجودة → اعتبر أنه لا يوجد فأس")
        end
        return false
    end

    local ok, toolsFrame = pcall(function()
        local f1    = menu:FindFirstChild("Frame")
        local f2    = f1 and f1:FindFirstChild("Frame")
        local menus = f2 and f2:FindFirstChild("Menus")
        local tools = menus and menus:FindFirstChild("Tools")
        local frame = tools and tools:FindFirstChild("Frame")
        return frame
    end)

    if not ok or not toolsFrame then
        if DEBUG_MODE then
            warn("[Q18] Tools.Frame غير موجود → اعتبر أنه لا يوجد فأس")
        end
        return false
    end

    -- الأطفال في Frame مثل "Iron Pickaxe", "Stone Pickaxe", "Cobalt Pickaxe"
    local gui = toolsFrame:FindFirstChild(pickaxeName)
    if gui then
        if DEBUG_MODE then
            local visible = gui:IsA("GuiObject") and gui.Visible or "N/A"
            print(string.format("[Q18] ✅ تم العثور على الفأس '%s' في الواجهة (مرئي=%s)", pickaxeName, tostring(visible)))
        end
        return true
    end

    if DEBUG_MODE then
        print(string.format("[Q18] ⚠️ لم يتم العثور على الفأس '%s' في الواجهة", pickaxeName))
    end
    return false
end

----------------------------------------------------------------
-- إغلاق الحوار بالقوة
----------------------------------------------------------------
local function ForceEndDialogueAndRestore()
    local gui = player:FindFirstChild("PlayerGui")
    if gui then
        local dUI = gui:FindFirstChild("DialogueUI")
        if dUI then
            dUI.Enabled = false
            local bb = dUI:FindFirstChild("ResponseBillboard")
            if bb then bb.Visible = false end
        end
    end
    
    local cam = Workspace.CurrentCamera
    if cam then
        cam.CameraType = Enum.CameraType.Custom
        cam.FieldOfView = 70
    end
    
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
        
        local humanoid = char:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = 16
            humanoid.JumpPower = 50
        end
    end
    
    if gui then
        local main = gui:FindFirstChild("Main")
        if main then main.Enabled = true end
        
        local backpack = gui:FindFirstChild("BackpackGui")
        if backpack then backpack.Enabled = true end
    end
    
    if DialogueRE then
        pcall(function()
            DialogueRE:FireServer("Closed")
        end)
    end
end

----------------------------------------------------------------
-- تعطيل التصادم والحركة
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
    -- استعادة التصادم (غير معرف في هذا النطاق، يفترض أن اللعبة تتعامل معه أو غير مطلوب)
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
    
    if DEBUG_MODE then
        print(string.format("   🚀 التحرك إلى (%.1f, %.1f, %.1f)...", targetPos.X, targetPos.Y, targetPos.Z))
    end
    
    local reachedTarget = false
    
    State.moveConn = RunService.Heartbeat:Connect(function()
        if reachedTarget then return end
        
        -- تحقق إذا تم تدمير الشخصية أو BodyVelocity
        if not char or not char.Parent or not hrp or not hrp.Parent then
            if State.moveConn then State.moveConn:Disconnect() State.moveConn = nil end
            if bv and bv.Parent then bv:Destroy() end
            if bg and bg.Parent then bg:Destroy() end
            State.bodyVelocity = nil
            State.bodyGyro = nil
            return
        end
        
        -- تحقق إذا تم تدمير BodyVelocity بواسطة اللعبة/سكربت آخر
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
        
        if distance < QUEST_CONFIG.STOP_DISTANCE then
            if DEBUG_MODE then
                print(string.format("   ✅ تم الوصول! (%.1f)", distance))
            end
            
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
-- نظام البيع التلقائي
----------------------------------------------------------------
local function getSellNPC()
    local prox = Workspace:FindFirstChild("Proximity")
    return prox and prox:FindFirstChild(QUEST_CONFIG.AUTO_SELL_NPC_NAME) or nil
end

local function getSellNPCPos()
    local npc = getSellNPC()
    if not npc then return nil end
    local hrp = npc:FindFirstChild("HumanoidRootPart")
    return hrp and hrp.Position or nil
end

local function getStashBackground()
    local menu = playerGui:FindFirstChild("Menu")
    if not menu then return nil end
    local f1 = menu:FindFirstChild("Frame")
    if not f1 then return nil end
    local f2 = f1:FindFirstChild("Frame")
    if not f2 then return nil end
    local menus = f2:FindFirstChild("Menus")
    if not menus then return nil end
    local stash = menus:FindFirstChild("Stash")
    if not stash then return nil end
    return stash:FindFirstChild("Background")
end

local function parseQty(text)
    if not text or text == "" then return 1 end
    local n = string.match(text, "x?(%d+)")
    return tonumber(n) or 1
end

local function getStashItemsUI()
    local bg = getStashBackground()
    if not bg then return {} end
    
    local basket = {}
    for _, child in ipairs(bg:GetChildren()) do
        if child:IsA("GuiObject") and not string.match(child.Name, "^UI") then
            local qty = 1
            local main = child:FindFirstChild("Main")
            if main then
                local q = main:FindFirstChild("Quantity")
                if q and q:IsA("TextLabel") and q.Visible then
                    qty = parseQty(q.Text)
                end
            end
            basket[child.Name] = qty
        end
    end
    return basket
end

local function initAutoSellWithNPC()
    if AutoSellInitialized then return true end
    
    print("\n" .. string.rep("=", 60))
    print("🔧 تهيئة البيع التلقائي (مرة واحدة)")
    print(string.rep("=", 60))
    
    local npcPos = getSellNPCPos()
    if not npcPos then
        warn("   ❌ لم يتم العثور على NPC: " .. QUEST_CONFIG.AUTO_SELL_NPC_NAME)
        return false
    end
    
    print(string.format("   ✅ تم العثور على %s في (%.1f, %.1f, %.1f)", 
        QUEST_CONFIG.AUTO_SELL_NPC_NAME, npcPos.X, npcPos.Y, npcPos.Z))
    
    print("   🚶 جارٍ التحرك إلى NPC...")
    
    local done = false
    smoothMoveTo(npcPos, function() done = true end)
    
    local t0 = tick()
    while not done and tick() - t0 < 30 do
        task.wait(0.1)
    end
    
    if not done then
        warn("   ❌ فشل الوصول إلى NPC (انتهى الوقت)")
        return false
    end
    
    print("   ✅ تم الوصول إلى NPC!")
    task.wait(1)
    
    local npc = getSellNPC()
    if npc and ProximityDialogueRF then
        print("   💬 فتح الحوار...")
        pcall(function()
            ProximityDialogueRF:InvokeServer(npc)
        end)
    end
    
    task.wait(2)
    
    print("   🚪 إغلاق الحوار...")
    ForceEndDialogueAndRestore()
    
    task.wait(1)
    
    AutoSellInitialized = true
    _G.Quest19AutoSellInitialized = true  -- الحفاظ على الحالة عبر إعادة تحميل السكربت
    
    print("\n" .. string.rep("=", 60))
    print("✅ تم تهيئة البيع التلقائي!")
    print(string.rep("=", 60))
    
    return true
end

local function sellAllFromUI()
    if not DIALOGUE_RF then return end
    if not AutoSellInitialized then return end
    
    local basket = getStashItemsUI()
    local hasItem = false
    for _, v in pairs(basket) do
        if v > 0 then hasItem = true break end
    end
    
    if not hasItem then
        if DEBUG_MODE then print("البيع التلقائي: لا توجد عناصر") end
        return
    end
    
    local args = { "SellConfirm", { Basket = basket } }
    local ok, res = pcall(function()
        return DIALOGUE_RF:InvokeServer(unpack(args))
    end)
    
    if ok then
        print("💰 البيع التلقائي: تم بيع العناصر!")
    else
        warn("فشل البيع التلقائي:", res)
    end
end

local function startAutoSellTask()
    if not QUEST_CONFIG.AUTO_SELL_ENABLED or not DIALOGUE_RF then
        return
    end
    
    print("🤖 بدء مهمة البيع التلقائي في الخلفية!")
    
    State.autoSellTask = task.spawn(function()
        while Quest19Active do
            task.wait(QUEST_CONFIG.AUTO_SELL_INTERVAL)
            
            if not State.isPaused then
                pcall(sellAllFromUI)
            end
        end
    end)
end

----------------------------------------------------------------
-- نظام الشراء التلقائي (خلفية)
----------------------------------------------------------------
local function purchasePickaxe(pickaxeName)
    if not PURCHASE_RF then
        warn("التحكم بالشراء مفقود")
        return false
    end
    
    print(string.format("   🛒 جاري شراء: %s", pickaxeName))
    
    local ok, res = pcall(function()
        return PURCHASE_RF:InvokeServer(pickaxeName, 1)
    end)
    
    if ok then
        print(string.format("   ✅ تم شراء: %s!", pickaxeName))
        return true
    else
        warn(string.format("   ❌ فشل: %s", tostring(res)))
        return false
    end
end

local function unlockPosition()
    if State.positionLockConn then
        State.positionLockConn:Disconnect()
        State.positionLockConn = nil
        if DEBUG_MODE then
            print("   🔓 تم فك قفل الموقع")
        end
    end
    
    -- تنظيف محركات الحركة لمنع التعارض مع smoothMoveTo
    if State.moveConn then
        State.moveConn:Disconnect()
        State.moveConn = nil
    end
    if State.bodyVelocity and State.bodyVelocity.Parent then
        State.bodyVelocity:Destroy()
        State.bodyVelocity = nil
    end
    if State.bodyGyro and State.bodyGyro.Parent then
        State.bodyGyro:Destroy()
        State.bodyGyro = nil
    end
end

local function tryBuyPickaxe()
    local pickaxeName = QUEST_CONFIG.TARGET_PICKAXE or "Cobalt Pickaxe"

    -- 1) تحقق إذا كان لديك الفأس بالفعل
    if hasPickaxe(pickaxeName) then
        if DEBUG_MODE then
            print(string.format("[Q18] ✅ لديك بالفعل %s - تخطي الشراء التلقائي", pickaxeName))
        end
        return true
    end

    -- 2) تحقق من الذهب
    local gold = getGold()
    gold = gold or 0

    if gold < QUEST_CONFIG.MIN_GOLD_TO_BUY then
        if DEBUG_MODE then
            print(string.format(
                "[Q18] ⏸ الذهب غير كافٍ لـ %s (لديك %d، تحتاج > %d)",
                pickaxeName,
                gold,
                QUEST_CONFIG.MIN_GOLD_TO_BUY
            ))
        end
        return false
    end

    -- 3) إيقاف التعدين والذهاب إلى المتجر
    print(string.format("\n🛒 [Q18] الشراء التلقائي: بحاجة إلى %s! (الذهب: %d)", pickaxeName, gold))

    local wasMining = IsMiningActive
    if wasMining then
        State.isPaused = true
        print("   ⏸️  إيقاف التعدين مؤقتًا...")

        if ToolController then
            ToolController.holdingM1 = false
        end

        unlockPosition()
        task.wait(1)
    end

    -- 4) التحرك إلى المتجر
    local shopPos = QUEST_CONFIG.SHOP_POSITION
    print(string.format("   🚶 الذهاب إلى المتجر (%.1f, %.1f, %.1f)...",
        shopPos.X, shopPos.Y, shopPos.Z))

    local done = false
    smoothMoveTo(shopPos, function()
        done = true
    end)

    local t0 = tick()
    while not done and tick() - t0 < 30 do
        task.wait(0.1)
    end

    if not done then
        warn("   ⚠️ فشل الوصول إلى المتجر!")
        if wasMining then
            State.isPaused = false
        end
        return false
    end

    print("   ✅ وصلت إلى المتجر!")
    task.wait(1)

    -- 5) الشراء
    local purchased = purchasePickaxe(pickaxeName)

    if purchased then
        print("   ✅ تم الشراء بنجاح!")
        task.wait(2)
    else
        warn("   ❌ فشل الشراء!")
    end

    -- 6) استئناف التعدين
    if wasMining then
        print("   ▶️  استئناف التعدين...")
        State.isPaused = false
    end

    return purchased
end

local function startAutoBuyTask()
    if not QUEST_CONFIG.AUTO_BUY_ENABLED or not PURCHASE_RF then
        return
    end
    
    print("🤖 بدء مهمة الشراء التلقائي في الخلفية!")
    
    State.autoBuyTask = task.spawn(function()
        while Quest19Active do
            task.wait(QUEST_CONFIG.AUTO_BUY_INTERVAL)
            
            if State.isPaused then
                continue
            end
            
            pcall(function()
                tryBuyPickaxe()
            end)
        end
    end)
end

----------------------------------------------------------------
-- نظام الشراء التلقائي لفأس الماجما (مع بيع الأسلحة/الدروع)
----------------------------------------------------------------
local UIController = nil
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

local function openToolsMenu()
    if not UIController then return false end
    
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

-- تحقق إذا كان العنصر مجهزًا (يوجد زر "إزالة التجهيز")
local function isItemEquippedFromUI(guid)
    local menuGui = playerGui:FindFirstChild("Menu")
    if not menuGui then return false end
    
    local toolsFrame = menuGui:FindFirstChild("Frame") and menuGui.Frame:FindFirstChild("Frame") 
                    and menuGui.Frame.Frame:FindFirstChild("Menus") 
                    and menuGui.Frame.Frame.Menus:FindFirstChild("Tools")
                    and menuGui.Frame.Frame.Menus.Tools:FindFirstChild("Frame")
    
    if not toolsFrame then return false end
    
    local itemFrame = toolsFrame:FindFirstChild(guid)
    if not itemFrame then return false end
    
    local equipButton = itemFrame:FindFirstChild("Equip")
    if not equipButton then return false end
    
    local textLabel = equipButton:FindFirstChild("TextLabel")
    if not textLabel or not textLabel:IsA("TextLabel") then return false end
    
    return textLabel.Text == "Unequip"
end

-- الحصول على جميع الأسلحة والدروع غير المجهزة
local function getNonEquippedItems()
    if not PlayerController or not PlayerController.Replica then
        warn("   ⚠️ النسخة المكررة غير متوفرة!")
        return {}
    end
    
    local replica = PlayerController.Replica
    
    if not replica.Data or not replica.Data.Inventory or not replica.Data.Inventory.Equipments then
        warn("   ⚠️ لم يتم العثور على المعدات في النسخة المكررة!")
        return {}
    end
    
    print("   📂 فتح قائمة الأدوات لفحص العناصر المجهزة...")
    openToolsMenu()
    task.wait(0.5)
    
    local equipments = replica.Data.Inventory.Equipments
    local items = {}
    
    for id, item in pairs(equipments) do
        if type(item) == "table" and item.Type and item.GUID then
            -- تخطي الفأس (لا تبيع الفؤوس)
            if string.find(item.Type, "Pickaxe") then
                continue
            end
            
            local guid = item.GUID
            local isEquipped = isItemEquippedFromUI(guid)
            
            if not isEquipped then
                table.insert(items, {
                    ID = id,
                    GUID = guid,
                    Type = item.Type,
                    Name = item.Name or item.Type,
                })
                print(string.format("      💰 يمكن البيع: %s (GUID: %s)", item.Type, guid))
            else
                print(string.format("      ⚡ مجهز (تخطي): %s", item.Type))
            end
        end
    end
    
    closeToolsMenu()
    
    return items
end

-- بيع جميع الأسلحة والدروع غير المجهزة
local function sellAllNonEquippedItems()
    print("\n💰 جاري بيع جميع الأسلحة/الدروع غير المجهزة...")
    
    local items = getNonEquippedItems()
    
    if #items == 0 then
        print("   ⏭️  لا توجد عناصر للبيع!")
        return true
    end
    
    print(string.format("   📦 تم العثور على %d عناصر للبيع", #items))
    
    -- بناء السلة بكل معرفات GUID
    local basket = {}
    for _, item in ipairs(items) do
        basket[item.GUID] = true
        print(string.format("      - %s", item.Type))
    end
    
    -- البيع باستخدام خدمة الحوار
    local success = false
    pcall(function()
        success = DIALOGUE_RF:InvokeServer("SellConfirm", { Basket = basket })
    end)
    
    if success then
        print("   ✅ تم بيع جميع العناصر بنجاح!")
        return true
    else
        warn("   ⚠️ قد يكون البيع قد فشل جزئيًا")
        return true -- استمر على أي حال
    end
end

-- محاولة شراء فأس الماجما (مع بيع العناصر أولاً)
local function tryBuyMagmaPickaxe()
    local config = QUEST_CONFIG.MAGMA_PICKAXE_CONFIG
    if not config or not config.ENABLED then return false end
    
    local pickaxeName = config.TARGET_PICKAXE or "Magma Pickaxe"

    -- 1) تحقق إذا كان لديك فأس الماجما بالفعل
    if hasPickaxe(pickaxeName) then
        if DEBUG_MODE then
            print(string.format("[Q19] ✅ لديك بالفعل %s - تخطي الشراء التلقائي", pickaxeName))
        end
        return true
    end

    -- 2) تحقق من الذهب
    local gold = getGold()
    gold = gold or 0

    if gold < config.MIN_GOLD_TO_BUY then
        if DEBUG_MODE then
            print(string.format(
                "[Q19] ⏸ الذهب غير كافٍ لـ %s (لديك %d، تحتاج > %d)",
                pickaxeName,
                gold,
                config.MIN_GOLD_TO_BUY
            ))
        end
        return false
    end

    -- 3) إيقاف التعدين
    print(string.format("\n🛒 [Q19] الشراء التلقائي لفأس الماجما: بحاجة إلى %s! (الذهب: %d)", pickaxeName, gold))

    local wasMining = IsMiningActive
    if wasMining then
        State.isPaused = true
        print("   ⏸️  إيقاف التعدين مؤقتًا...")

        if ToolController then
            ToolController.holdingM1 = false
        end

        unlockPosition()
        task.wait(1)
    end

    -- 4) التحرك إلى متجر البيع وبيع جميع الأسلحة/الدروع
    local sellShopPos = config.SELL_SHOP_POSITION
    print(string.format("   🚶 الذهاب إلى متجر البيع (%.1f, %.1f, %.1f)...",
        sellShopPos.X, sellShopPos.Y, sellShopPos.Z))

    local done = false
    smoothMoveTo(sellShopPos, function()
        done = true
    end)

    local t0 = tick()
    while not done and tick() - t0 < 30 do
        task.wait(0.1)
    end

    if not done then
        warn("   ⚠️ فشل الوصول إلى متجر البيع!")
        if wasMining then State.isPaused = false end
        return false
    end

    print("   ✅ وصلت إلى متجر البيع!")
    task.wait(1)

    -- بيع جميع العناصر غير المجهزة
    sellAllNonEquippedItems()
    task.wait(1)

    -- 5) التحرك إلى متجر الشراء
    local buyShopPos = config.BUY_SHOP_POSITION
    print(string.format("   🚶 الذهاب إلى متجر الماجما (%.1f, %.1f, %.1f)...",
        buyShopPos.X, buyShopPos.Y, buyShopPos.Z))

    done = false
    smoothMoveTo(buyShopPos, function()
        done = true
    end)

    t0 = tick()
    while not done and tick() - t0 < 60 do
        task.wait(0.1)
    end

    if not done then
        warn("   ⚠️ فشل الوصول إلى متجر الماجما!")
        if wasMining then State.isPaused = false end
        return false
    end

    print("   ✅ وصلت إلى متجر الماجما!")
    task.wait(1)

    -- 6) شراء فأس الماجما
    local purchased = purchasePickaxe(pickaxeName)

    if purchased then
        print("   ✅ تم شراء فأس الماجما!")
        print("   🔄 التبديل إلى تعدين عروق البازلت...")
        task.wait(2)
    else
        warn("   ❌ فشل الشراء!")
    end

    -- 7) استئناف التعدين
    if wasMining then
        print("   ▶️  استئناف التعدين...")
        State.isPaused = false
    end

    return purchased
end

-- مهمة خلفية لشراء فأس الماجما
local function startMagmaBuyTask()
    local config = QUEST_CONFIG.MAGMA_PICKAXE_CONFIG
    if not config or not config.ENABLED or not PURCHASE_RF then
        return
    end
    
    print("🤖 بدء مهمة الشراء التلقائي لفأس الماجما!")
    
    State.magmaBuyTask = task.spawn(function()
        while Quest19Active do
            task.wait(30) -- تحقق كل 30 ثانية
            
            if State.isPaused then
                continue
            end
            
            -- حاول فقط إذا كان لديك فأس الكوبالت بالفعل
            if hasPickaxe(QUEST_CONFIG.TARGET_PICKAXE) then
                pcall(function()
                    tryBuyMagmaPickaxe()
                end)
            end
        end
    end)
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
        print(string.format("   ✅ على %s → بحاجة إلى الانتقال!", currentIsland))
        return true
    elseif currentIsland == "Island2" then
        print(string.format("   ✅ على %s → جاهز للتعدين!", currentIsland))
        return false
    else
        warn(string.format("   ⚠️ غير معروف: %s", currentIsland))
        return true
    end
end

----------------------------------------------------------------
-- نظام المستوى
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
    ["0"] = Enum.KeyCode.Zero,
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
    
    local hotbar = gui:FindFirstChild("BackpackGui") 
                   and gui.BackpackGui:FindFirstChild("Backpack") 
                   and gui.BackpackGui.Backpack:FindFirstChild("Hotbar")
    
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
    
    if DEBUG_MODE then
        print("   🔒 تم قفل الموقع")
    end
end

local function transitionToNewTarget(newTargetPos)
    if State.positionLockConn then
        State.positionLockConn:Disconnect()
        State.positionLockConn = nil
    end
    
    local moveComplete = false
    smoothMoveTo(newTargetPos, function()
        lockPositionLayingDown(newTargetPos)
        moveComplete = true
    end)
    
    local timeout = 60
    local startTime = tick()
    while not moveComplete and tick() - startTime < timeout do
        task.wait(0.1)
    end
    
    if not moveComplete then
        warn("   ⚠️ انتهى وقت الانتقال!")
        return false
    end
    
    return true
end

----------------------------------------------------------------
-- نظام الانتقال (التليبورتر)
----------------------------------------------------------------
local function teleportToIsland(islandName)
    if not PORTAL_RF then
        warn("   ❌ التحكم بالبوابة غير متوفر!")
        return false
    end
    
    print(string.format("   🌀 جاري الانتقال إلى: %s", islandName))
    
    local args = {islandName}
    
    local success, result = pcall(function()
        return PORTAL_RF:InvokeServer(unpack(args))
    end)
    
    if success then
        print(string.format("   ✅ تم الانتقال إلى: %s", islandName))
        return true
    else
        warn(string.format("   ❌ فشل: %s", tostring(result)))
        return false
    end
end

----------------------------------------------------------------
-- دوال مساعدة للصخور
----------------------------------------------------------------
local function getRockUndergroundPosition(rockModel)
    if not rockModel or not rockModel.Parent then
        return nil
    end
    
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
    if not rock or not rock.Parent then
        return 0
    end
    
    local success, result = pcall(function()
        return rock:GetAttribute("Health") or 0
    end)
    
    return success and result or 0
end

local function isTargetValid(rock)
    if not rock or not rock.Parent then
        return false
    end
    
    if not rock:FindFirstChildWhichIsA("BasePart") then
        return false
    end
    
    local hp = getRockHP(rock)
    return hp > 0
end

-- الحصول على اسم الصخر الحالي ومسارات التعدين بناءً على الفأس
local function getCurrentMiningConfig()
    local magmaPickaxe = QUEST_CONFIG.MAGMA_PICKAXE_CONFIG and QUEST_CONFIG.MAGMA_PICKAXE_CONFIG.TARGET_PICKAXE or "Magma Pickaxe"
    local cobaltPickaxe = QUEST_CONFIG.TARGET_PICKAXE or "Cobalt Pickaxe"
    
    -- المستوى 3: فأس الماجما → نواة البازلت (طلب المستخدم بسبب الازدحام في العروق)
    if hasPickaxe(magmaPickaxe) then
        print("   🔥 لديك فأس الماجما → تعدين نواة البازلت (العروق مزدحمة)")
        return {
            ROCK_NAME = QUEST_CONFIG.BASALT_CORE_CONFIG.ROCK_NAME,
            MINING_PATHS = QUEST_CONFIG.BASALT_CORE_CONFIG.MINING_PATHS,
        }
    -- المستوى 2: فأس الكوبالت → نواة البازلت
    elseif hasPickaxe(cobaltPickaxe) then
        print("   💎 لديك فأس الكوبالت → تعدين نواة البازلت")
        return {
            ROCK_NAME = QUEST_CONFIG.BASALT_CORE_CONFIG.ROCK_NAME,
            MINING_PATHS = QUEST_CONFIG.BASALT_CORE_CONFIG.MINING_PATHS,
        }
    -- المستوى 1: افتراضي → صخر البازلت
    else
        print("   ⛏️ لا يوجد فأس خاص → تعدين صخر البازلت")
        return {
            ROCK_NAME = QUEST_CONFIG.ROCK_NAME,
            MINING_PATHS = QUEST_CONFIG.MINING_PATHS,
        }
    end
end

local function findNearestBasaltRock(excludeRock)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    
    cleanupExpiredBlacklist()
    
    -- الحصول على إعداد التعدين الحالي بناءً على الفأس
    local miningConfig = getCurrentMiningConfig()
    local rockName = miningConfig.ROCK_NAME
    local miningPaths = miningConfig.MINING_PATHS
    
    local targetRock, minDist = nil, math.huge
    local skippedOccupied = 0
    
    for _, pathName in ipairs(miningPaths) do
        local folder = MINING_FOLDER_PATH:FindFirstChild(pathName)
        
        if folder then
            for _, child in ipairs(folder:GetChildren()) do
                if child:IsA("SpawnLocation") or child.Name == "SpawnLocation" then
                    local rock = child:FindFirstChild(rockName)
                    
                    if rock and rock ~= excludeRock and isTargetValid(rock) then
                        if isRockOccupied(rock) then
                            skippedOccupied = skippedOccupied + 1
                        else
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
    end
    
    if skippedOccupied > 0 then
        print(string.format("   ⏭️ تم تخطي %d صخور مشغولة (في القائمة السوداء)", skippedOccupied))
    end
    
    return targetRock, minDist, rockName
end

local function watchRockHP(rock)
    if State.hpWatchConn then
        State.hpWatchConn:Disconnect()
    end
    
    if not rock then return end
    
    State.hpWatchConn = rock:GetAttributeChangedSignal("Health"):Connect(function()
        local hp = rock:GetAttribute("Health") or 0
        
        if hp <= 0 then
            print("   ✅ تم تدمير الصخر!")
            State.targetDestroyed = true
            
            if ToolController then
                ToolController.holdingM1 = false
            end
        end
    end)
end

----------------------------------------------------------------
-- تنفيذ التعدين
----------------------------------------------------------------
local function doMineBasaltRock()
    -- تحقق من الفأس وحدد نوع الصخر
    local miningConfig = getCurrentMiningConfig()
    local currentRockName = miningConfig.ROCK_NAME
    
    print("\n⛏️ بدء التعدين...")
    print(string.format("   🎯 التعدين: %s", currentRockName))
    print(string.format("   الهدف: %d صخور", QUEST_CONFIG.MAX_ROCKS_TO_MINE))
    
    IsMiningActive = true
    
    local miningCount = 0
    
    print("\n" .. string.rep("=", 50))
    print(string.format("⛏️ حلقة التعدين (%s)...", currentRockName))
    print(string.rep("=", 50))
    
    while Quest19Active and miningCount < QUEST_CONFIG.MAX_ROCKS_TO_MINE do
        if State.isPaused then
            print("   ⏸️  متوقف مؤقتًا (الشراء التلقائي يعمل)...")
            task.wait(2)
            continue
        end
        
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        
        if not hrp then
            warn("   ⚠️ في انتظار الشخصية...")
            task.wait(2)
            continue
        end
        
        if not State.positionLockConn and not State.moveConn and not State.bodyVelocity then
            cleanupState()
        end
        
        local targetRock, dist, rockName = findNearestBasaltRock(State.currentTarget)
        
        if not targetRock then
            warn(string.format("   ❌ لم يتم العثور على %s!", rockName or "الصخور"))
            unlockPosition()
            cleanupState()
            task.wait(3)
            continue
        end
        
        local previousTarget = State.currentTarget
        State.currentTarget = targetRock
        State.targetDestroyed = false
        
        local targetPos = getRockUndergroundPosition(targetRock)
        
        if not targetPos then
            warn("   ❌ لا يمكن الحصول على الموقع!")
            task.wait(1)
            continue
        end
        
        local currentHP = getRockHP(targetRock)
        
        print(string.format("\n🎯 الهدف #%d: %s (HP: %d, المسافة: %.1f)", 
            miningCount + 1,
            targetRock.Parent.Parent.Name,
            currentHP, 
            dist))
        
        watchRockHP(targetRock)
        
        -- إذا كنا مقفلين على هدف مختلف، استخدم الانتقال السلس
        -- وإلا، استخدم دائمًا smoothMoveTo (حتى لنفس الهدف بعد إعادة الظهور)
        if State.positionLockConn and previousTarget and previousTarget ~= targetRock then
            print("   🔄 الانتقال إلى هدف جديد...")
            transitionToNewTarget(targetPos)
        else
            -- فك أي قفل موقع موجود أولاً
            if State.positionLockConn then
                unlockPosition()
            end
            
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
                warn("   ⚠️ انتهى وقت الحركة، تخطي هذا الصخر")
                State.targetDestroyed = true
                unlockPosition()
                continue
            end
        end
        
        task.wait(0.5)
        
        while not State.targetDestroyed and Quest19Active and not State.isPaused do
            if not char or not char.Parent then
                break
            end
            
            if not targetRock or not targetRock.Parent then
                State.targetDestroyed = true
                break
            end
            
            if checkMiningError() then
                print("   ⚠️ شخص آخر يقوم بالتعدين! التبديل إلى هدف آخر...")
                markRockAsOccupied(targetRock)
                State.targetDestroyed = true
                if ToolController then
                    ToolController.holdingM1 = false
                end
                break
            end
            
            local toolInHand = char:FindFirstChildWhichIsA("Tool")
            local isPickaxeHeld = toolInHand and string.find(toolInHand.Name, "Pickaxe")
            
            if not isPickaxeHeld then
                if ToolController then
                    ToolController.holdingM1 = false
                end
                
                local key = findPickaxeSlotKey()
                if key then
                    pressKey(key)
                    task.wait(0.3)
                else
                    pcall(function()
                        if PlayerController and PlayerController.Replica then
                            local replica = PlayerController.Replica
                            if replica.Data and replica.Data.Inventory and replica.Data.Inventory.Equipments then
                                for id, item in pairs(replica.Data.Inventory.Equipments) do
                                    if type(item) == "table" and item.Type and string.find(item.Type, "Pickaxe") then
                                        CHAR_RF:InvokeServer({Runes = {}}, item)
                                        break
                                    end
                                end
                            end
                        end
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
        
        if State.targetDestroyed then
            miningCount = miningCount + 1
        end
        
        if QUEST_CONFIG.HOLD_POSITION_AFTER_MINE then
            print("   ⏸️  الحفاظ على الموقع، البحث عن الهدف التالي...")
        else
            unlockPosition()
        end
        
        task.wait(0.5)
    end
    
    print("\n" .. string.rep("=", 50))
    print("✅ انتهى التعدين")
    print(string.rep("=", 50))
    
    IsMiningActive = false
    unlockPosition()
    disableNoclip()
    cleanupState()
end

----------------------------------------------------------------
-- مشغل المهمة الذكي
----------------------------------------------------------------
print(string.rep("=", 50))
print("🚀 المهمة 19: " .. QUEST_CONFIG.QUEST_NAME)
print("🎯 الهدف: التعدين + البيع والشراء التلقائي")
print(string.rep("=", 50))

-- تحقق من المستوى
print("\n🔍 فحص مسبق: التحقق من متطلبات المستوى...")
if not hasRequiredLevel() then
    print("\n❌ لم يتم استيفاء متطلبات المستوى!")
    print(string.rep("=", 50))
    cleanupState()
    disableNoclip()
    return
end

-- الأولوية 1: تهيئة البيع التلقائي
print("\n🔍 الأولوية 1: تهيئة البيع التلقائي...")
if QUEST_CONFIG.AUTO_SELL_ENABLED then
    if not AutoSellInitialized then
        local success = initAutoSellWithNPC()
        if not success then
            warn("   ⚠️ فشل تهيئة البيع التلقائي - التخطي")
        end
    else
        print("   ✅ البيع التلقائي مهيأ بالفعل")
    end
end

-- الأولوية 2: المهام الخلفية
print("\n🔍 الأولوية 2: بدء المهام الخلفية...")
startAutoSellTask()
startAutoBuyTask()
startMagmaBuyTask()

-- الأولوية 3: التعدين
print("\n🔍 الأولوية 3: بدء التعدين...")
doMineBasaltRock()

Quest19Active = false
cleanupState()
disableNoclip()