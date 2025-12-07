--[[
    🚀 سكربت تعزيز معدل الإطارات FPS
    📊 يقلل التأخير ويحسن أداء اللعبة
    
    ⚠️ ملاحظة: بعض الإعدادات قد تجعل الرسوميات تبدو أسوأ لكن معدل الإطارات سيكون أفضل بكثير
--]]

----------------------------------------------------------------
-- ⚙️ الإعدادات (يمكن تعديلها حسب الرغبة)
----------------------------------------------------------------
local Settings = {
    -- ====== الرسوميات ======
    LowerQuality = true,           -- تقليل جودة الرسوميات بشكل عام
    DisableShadows = true,         -- إيقاف الظلال
    DisableParticles = true,       -- إيقاف الجسيمات/التأثيرات
    DisableDecals = true,          -- إيقاف الملصقات (Decals)
    DisableTextures = true,        -- إيقاف الخامات (يجعل المظهر سيئًا جدًا)
    Disable3DRendering = true,     -- إيقاف العرض ثلاثي الأبعاد (أقصى حد)
    BlackScreenMode = true,        -- تفعيل وضع الشاشة السوداء (يوفر GPU + CPU)
    
    -- ====== الإضاءة ======
    DisableGlobalShadows = true,   -- إيقاف الظلال العالمية
    DisableBloom = true,           -- إيقاف تأثير التوهج (Bloom)
    DisableBlur = true,            -- إيقاف التمويه/عمق المجال
    DisableSunRays = true,         -- إيقاف أشعة الشمس
    DisableColorCorrection = true, -- إيقاف تصحيح الألوان
    
    -- ====== التضاريس ======
    LowerTerrainQuality = true,    -- تقليل جودة التضاريس
    DisableWater = true,           -- إيقاف عرض الماء
    
    -- ====== الشخصية ======
    DisablePlayerNames = false,    -- إخفاء أسماء اللاعبين
    SimplifyCharacters = true,     -- تبسيط تعقيد الشخصيات
    DisableAccessories = true,     -- إخفاء الإكسسوارات
    
    -- ====== متفرقات ======
    DisableSounds = false,         -- إيقاف الأصوات
    LimitFPS = false,              -- تحديد معدل الإطارات (يوفر CPU)
    TargetFPS = 60,                -- معدل الإطارات المستهدف (إذا تم تفعيل LimitFPS)
    GarbageCollect = true,         -- تفعيل جمع القمامة (Garbage Collection)
    GCInterval = 60,               -- تكرار جمع القمامة كل كم ثانية
}

----------------------------------------------------------------
-- 📦 الخدمات
----------------------------------------------------------------
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- مرجع عام لتبديل الشاشة السوداء
local BlackScreenOverlay = nil
local BlackScreenEnabled = true

----------------------------------------------------------------
-- 🎨 جودة الرسوميات
----------------------------------------------------------------
local function setGraphicsQuality()
    if not Settings.LowerQuality then return end
    
    print("🎨 تقليل جودة الرسوميات...")
    
    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    end)
    
    pcall(function()
        settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.DistanceBased
    end)
end

----------------------------------------------------------------
-- 💡 تأثيرات الإضاءة
----------------------------------------------------------------
local function disableLightingEffects()
    print("💡 إيقاف تأثيرات الإضاءة...")
    
    if Settings.DisableGlobalShadows then
        pcall(function() Lighting.GlobalShadows = false end)
    end
    
    for _, effect in ipairs(Lighting:GetChildren()) do
        pcall(function()
            if effect:IsA("BloomEffect") and Settings.DisableBloom then
                effect.Enabled = false
            elseif effect:IsA("BlurEffect") and Settings.DisableBlur then
                effect.Enabled = false
            elseif effect:IsA("DepthOfFieldEffect") and Settings.DisableBlur then
                effect.Enabled = false
            elseif effect:IsA("SunRaysEffect") and Settings.DisableSunRays then
                effect.Enabled = false
            elseif effect:IsA("ColorCorrectionEffect") and Settings.DisableColorCorrection then
                effect.Enabled = false
            end
        end)
    end
    
    print("   ✅ تم إيقاف تأثيرات الإضاءة")
end

----------------------------------------------------------------
-- ✨ الجسيمات والتأثيرات
----------------------------------------------------------------
local function disableParticles()
    if not Settings.DisableParticles then return end
    
    print("✨ إيقاف الجسيمات...")
    
    local count = 0
    for _, desc in ipairs(Workspace:GetDescendants()) do
        pcall(function()
            if desc:IsA("ParticleEmitter") or 
               desc:IsA("Fire") or 
               desc:IsA("Smoke") or 
               desc:IsA("Sparkles") or
               desc:IsA("Trail") or
               desc:IsA("Beam") then
                desc.Enabled = false
                count = count + 1
            end
        end)
    end
    
    print(string.format("   ✅ تم إيقاف %d تأثير جسيمات", count))
end

----------------------------------------------------------------
-- 🖼️ الملصقات والخامات
----------------------------------------------------------------
local function disableDecalsAndTextures()
    print("🖼️ معالجة الملصقات/الخامات...")
    
    local decalCount, textureCount = 0, 0
    
    for _, desc in ipairs(Workspace:GetDescendants()) do
        pcall(function()
            if Settings.DisableDecals and desc:IsA("Decal") then
                desc.Transparency = 1
                decalCount = decalCount + 1
            end
            
            if Settings.DisableTextures and desc:IsA("Texture") then
                desc.Transparency = 1
                textureCount = textureCount + 1
            end
        end)
    end
    
    if Settings.DisableDecals then
        print(string.format("   ✅ تم إخفاء %d ملصق", decalCount))
    end
    if Settings.DisableTextures then
        print(string.format("   ✅ تم إخفاء %d خامة", textureCount))
    end
end

----------------------------------------------------------------
-- 🌊 التضاريس
----------------------------------------------------------------
local function optimizeTerrain()
    if not Settings.LowerTerrainQuality then return end
    
    print("🌊 تحسين التضاريس...")
    
    local terrain = Workspace:FindFirstChildOfClass("Terrain")
    if terrain then
        pcall(function()
            terrain.WaterWaveSize = 0
            terrain.WaterWaveSpeed = 0
            terrain.WaterReflectance = 0
            terrain.WaterTransparency = 0
            terrain.Decoration = false
        end)
        
        if Settings.DisableWater then
            pcall(function()
                terrain.WaterColor = Color3.new(0, 0, 0)
                terrain.WaterTransparency = 1
            end)
        end
    end
    
    print("   ✅ تم تحسين التضاريس")
end

----------------------------------------------------------------
-- 🫥 الظلال
----------------------------------------------------------------
local function disableShadows()
    if not Settings.DisableShadows then return end
    
    print("🫥 إيقاف الظلال...")
    
    local count = 0
    for _, desc in ipairs(Workspace:GetDescendants()) do
        pcall(function()
            if desc:IsA("BasePart") then
                desc.CastShadow = false
                count = count + 1
            end
        end)
    end
    
    print(string.format("   ✅ تم إيقاف الظلال على %d جزء", count))
end

----------------------------------------------------------------
-- 👤 تحسين الشخصيات
----------------------------------------------------------------
local function optimizeCharacters()
    print("👤 تحسين الشخصيات...")
    
    local function optimizeChar(char)
        if not char then return end
        
        for _, desc in ipairs(char:GetDescendants()) do
            pcall(function()
                if Settings.DisableAccessories and desc:IsA("Accessory") then
                    desc:Destroy()
                end
                
                if Settings.DisableParticles then
                    if desc:IsA("ParticleEmitter") or desc:IsA("Trail") then
                        desc.Enabled = false
                    end
                end
                
                if Settings.SimplifyCharacters and desc:IsA("BasePart") then
                    desc.CastShadow = false
                end
            end)
        end
    end
    
    if player.Character then
        optimizeChar(player.Character)
    end
    
    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= player and otherPlayer.Character then
            optimizeChar(otherPlayer.Character)
        end
    end
    
    Players.PlayerAdded:Connect(function(p)
        p.CharacterAdded:Connect(function(char)
            task.wait(1)
            optimizeChar(char)
        end)
    end)
    
    print("   ✅ تم تحسين الشخصيات")
end

----------------------------------------------------------------
-- 🔊 الأصوات
----------------------------------------------------------------
local function disableSounds()
    if not Settings.DisableSounds then return end
    
    print("🔊 إيقاف الأصوات...")
    
    local count = 0
    for _, desc in ipairs(game:GetDescendants()) do
        pcall(function()
            if desc:IsA("Sound") then
                desc.Volume = 0
                count = count + 1
            end
        end)
    end
    
    print(string.format("   ✅ تم كتم %d صوت", count))
end

----------------------------------------------------------------
-- 🗑️ جمع القمامة
----------------------------------------------------------------
local function startGarbageCollection()
    if not Settings.GarbageCollect then return end
    
    print("🗑️ بدء روتين جمع القمامة...")
    
    task.spawn(function()
        while true do
            task.wait(Settings.GCInterval)
            pcall(function()
                gcinfo()
                collectgarbage("collect")
            end)
        end
    end)
    
    print(string.format("   ✅ سيتم تشغيل جمع القمامة كل %d ثانية", Settings.GCInterval))
end

----------------------------------------------------------------
-- ⏱️ محدد معدل الإطارات (يوفر CPU)
----------------------------------------------------------------
local function startFPSLimiter()
    if not Settings.LimitFPS then return end
    
    print("⏱️ بدء محدد معدل الإطارات...")
    
    local targetFrameTime = 1 / Settings.TargetFPS
    
    RunService.RenderStepped:Connect(function()
        local startTime = tick()
        while tick() - startTime < targetFrameTime do
            -- انتظار نشط
        end
    end)
    
    print(string.format("   ✅ تم تحديد معدل الإطارات إلى %d", Settings.TargetFPS))
end

----------------------------------------------------------------
-- 🖥️ العرض ثلاثي الأبعاد والشاشة السوداء (أقصى حد)
----------------------------------------------------------------
local function enableBlackScreen()
    if not Settings.BlackScreenMode then return end
    
    print("🖤 تفعيل وضع الشاشة السوداء...")
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "BlackScreenOverlay"
    screenGui.IgnoreGuiInset = true
    screenGui.DisplayOrder = 1000
    screenGui.Parent = player:WaitForChild("PlayerGui")
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Color3.new(0, 0, 0)
    frame.BorderSizePixel = 0
    frame.ZIndex = 1000
    frame.Parent = screenGui
    
    local text = Instance.new("TextLabel")
    text.Text = "🌑 وضع الخمول: توفير الموارد 🌑"
    text.Size = UDim2.new(1, 0, 0, 50)
    text.Position = UDim2.new(0, 0, 0.4, -25)
    text.BackgroundTransparency = 1
    text.TextColor3 = Color3.new(1, 1, 1)
    text.Font = Enum.Font.RobotoMono
    text.TextSize = 24
    text.ZIndex = 1001
    text.Parent = frame
    
    -- اسم الشخصية كبير
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Text = player.Name or "غير معروف"
    nameLabel.Size = UDim2.new(1, 0, 0, 80)
    nameLabel.Position = UDim2.new(0, 0, 0.5, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Color3.fromRGB(0, 255, 255)
    nameLabel.Font = Enum.Font.FredokaOne
    nameLabel.TextSize = 20
    nameLabel.ZIndex = 1001
    nameLabel.Parent = frame
    
    -- عرض الذهب
    local goldLabel = Instance.new("TextLabel")
    goldLabel.Text = "💰 الذهب: جاري التحميل..."
    goldLabel.Size = UDim2.new(1, 0, 0, 60)
    goldLabel.Position = UDim2.new(0, 0, 0.6, 20)
    goldLabel.BackgroundTransparency = 1
    goldLabel.TextColor3 = Color3.fromRGB(255, 215, 0) -- لون الذهب
    goldLabel.Font = Enum.Font.FredokaOne
    goldLabel.TextSize = 32
    goldLabel.ZIndex = 1001
    goldLabel.Parent = frame
    
    -- تحديث الذهب كل ثانيتين
    task.spawn(function()
        while screenGui and screenGui.Parent do
            local goldUI = player:FindFirstChild("PlayerGui")
                          and player.PlayerGui:FindFirstChild("Main")
                          and player.PlayerGui.Main:FindFirstChild("Screen")
                          and player.PlayerGui.Main.Screen:FindFirstChild("Hud")
                          and player.PlayerGui.Main.Screen.Hud:FindFirstChild("Gold")
            
            if goldUI and goldUI:IsA("TextLabel") then
                goldLabel.Text = "💰 " .. goldUI.Text
            else
                goldLabel.Text = "💰 الذهب: --"
            end
            
            task.wait(2)
        end
    end)
    
    print("   ✅ تراكب الشاشة السوداء مفعل")
    print("   🎮 اضغط F2 للتبديل!")
    
    BlackScreenOverlay = screenGui
end

-- دالة تبديل الشاشة السوداء
local function toggleBlackScreen()
    if not BlackScreenOverlay then
        print("⚠️ الشاشة السوداء غير مهيأة!")
        return
    end
    
    BlackScreenEnabled = not BlackScreenEnabled
    BlackScreenOverlay.Enabled = BlackScreenEnabled
    
    if BlackScreenEnabled then
        print("🖤 الشاشة السوداء: مفعلة")
    else
        print("🔆 الشاشة السوداء: معطلة (واجهة المستخدم مرئية)")
    end
end

-- دالة عامة للوصول الخارجي
_G.ToggleBlackScreen = toggleBlackScreen

-- اختصار مفتاح F2
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.F2 then
        toggleBlackScreen()
    end
end)

local function disable3DRendering()
    if not Settings.Disable3DRendering then return end
    
    print("🖥️ إيقاف العرض ثلاثي الأبعاد (أقصى حد)...")
    
    local s1, _ = pcall(function()
        RunService:Set3dRenderingEnabled(false)
    end)
    
    if s1 then
        print("   ✅ تم تعطيل العرض ثلاثي الأبعاد بنجاح!")
    else
        print("   ⚠️ Set3dRenderingEnabled غير مدعوم، سيتم استخدام الشاشة السوداء كبديل...")
    end
end

----------------------------------------------------------------
-- 📊 عداد معدل الإطارات FPS
----------------------------------------------------------------
local function createFPSCounter()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "FPSCounter"
    screenGui.ResetOnSpawn = false
    screenGui.DisplayOrder = 1001
    screenGui.Parent = player:WaitForChild("PlayerGui")
    
    local fpsLabel = Instance.new("TextLabel")
    fpsLabel.Name = "FPSLabel"
    fpsLabel.Size = UDim2.new(0, 100, 0, 30)
    fpsLabel.Position = UDim2.new(0, 10, 0, 10)
    fpsLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    fpsLabel.BackgroundTransparency = 0.5
    fpsLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
    fpsLabel.Font = Enum.Font.Code
    fpsLabel.TextSize = 14
    fpsLabel.Text = "FPS: --"
    fpsLabel.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 5)
    corner.Parent = fpsLabel
    
    local frameCount = 0
    local lastTime = tick()
    
    RunService.RenderStepped:Connect(function()
        frameCount = frameCount + 1
        local currentTime = tick()
        
        if currentTime - lastTime >= 1 then
            local fps = math.floor(frameCount / (currentTime - lastTime))
            fpsLabel.Text = string.format("FPS: %d", fps)
            
            if fps >= 50 then
                fpsLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
            elseif fps >= 30 then
                fpsLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
            else
                fpsLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
            end
            
            frameCount = 0
            lastTime = currentTime
        end
    end)
    
    print("📊 تم إنشاء عداد معدل الإطارات!")
end

----------------------------------------------------------------
-- 🚀 تشغيل جميع التحسينات
----------------------------------------------------------------
local function runAllOptimizations()
    print("\n" .. string.rep("=", 50))
    print("🚀 معزز معدل الإطارات - بدء التحسينات")
    print(string.rep("=", 50) .. "\n")
    
    setGraphicsQuality()
    disableLightingEffects()
    disableParticles()
    disableDecalsAndTextures()
    disableShadows()
    optimizeTerrain()
    optimizeCharacters()
    disableSounds()
    startGarbageCollection()
    startFPSLimiter()
    enableBlackScreen()
    disable3DRendering()
    createFPSCounter()
    
    print("\n" .. string.rep("=", 50))
    print("✅ معزز معدل الإطارات - تم تطبيق جميع التحسينات!")
    print(string.rep("=", 50) .. "\n")
end

-- تشغيل
runAllOptimizations()

-- إعادة التطبيق عند إضافة عناصر جديدة
Workspace.DescendantAdded:Connect(function(desc)
    task.defer(function()
        pcall(function()
            if Settings.DisableParticles then
                if desc:IsA("ParticleEmitter") or desc:IsA("Fire") or desc:IsA("Smoke") then
                    desc.Enabled = false
                end
            end
            if Settings.DisableShadows and desc:IsA("BasePart") then
                desc.CastShadow = false
            end
        end)
    end)
end)