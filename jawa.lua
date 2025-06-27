-- 🧩 Rayfield UI
local success, Rayfield = pcall(function()
    return loadstring(game:HttpGet("https://sirius.menu/rayfield", true))()
end)

if not success then
    warn("❌ Rayfield failed to load:", Rayfield)
else
    print("✅ Rayfield loaded successfully.")
end

local Window = Rayfield:CreateWindow({
    Name = "BCWO Hub",
    LoadingTitle = "BCWO Hub",
    LoadingSubtitle = "by razzie.mp4",
    ConfigurationSaving = {
       Enabled = true,
       FolderName = nil,
       FileName = "BCWOHub"
    },
    Discord = {
       Enabled = false,
       Invite = "", -- example: "sirius"
       RememberJoins = true
    },
    KeySystem = false,
})

-- ⚙️ Services
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- 🌐 Webhook (editable via UI)
local WEBHOOK_URL = ""

-- 🧠 Biome Settings
local BIOME_NAMES = {
    "NightSky", "StormSurge", "Radiation", "NormalSky",
    "PurpleNebula", "BlueMoonSky", "Nature", "FlameRazedSky",
    "FrostSky", "ChristmasSky", "CultistSky", "HeavenSky", "YinYangSky"
}

-- 📦 Variables
local currentBiome = "None"
local lastBiome = "None"
local whitelist = {}
local webhookNotify = {}
local historyLog = {}
local merchantSpawned = false
local pingMerchant = false

-- 🔔 Biome Tab
local BiomeTab = Window:CreateTab("Biomes", 4483362458)
local biomeParagraph = BiomeTab:CreateParagraph({ Title = "Current Biome", Content = "None" })
local activeBiomesParagraph = BiomeTab:CreateParagraph({ Title = "Active Biomes", Content = "Loading..." })
local historyLogBox = BiomeTab:CreateParagraph({ Title = "Log", Content = "..." })

-- ✅ Biome Toggles
for _, biome in ipairs(BIOME_NAMES) do
    whitelist[biome] = false
    webhookNotify[biome] = false

    BiomeTab:CreateToggle({
        Name = "Track " .. biome,
        CurrentValue = false,
        Callback = function(state)
            whitelist[biome] = state
        end
    })

    BiomeTab:CreateToggle({
        Name = "Ping @everyone for " .. biome,
        CurrentValue = false,
        Callback = function(state)
            webhookNotify[biome] = state
        end
    })
end

-- ♻️ Notifier Enable
local notifierEnabled = false
BiomeTab:CreateToggle({
    Name = "Enable Notifier",
    CurrentValue = false,
    Callback = function(value)
        notifierEnabled = value
    end
})

-- 🌐 Webhook Tab
local WebhookTab = Window:CreateTab("Webhook", 4483362458)
WebhookTab:CreateInput({
    Name = "Set Webhook URL",
    PlaceholderText = "Paste your Discord webhook...",
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        WEBHOOK_URL = text
        Rayfield:Notify({ Title = "✅ Webhook Updated", Content = "Your webhook has been set!", Duration = 5 })
    end
})
WebhookTab:CreateButton({
    Name = "Test Webhook",
    Callback = function()
        if WEBHOOK_URL == "" then
            return Rayfield:Notify({ Title = "❌ Error", Content = "Set webhook first!", Duration = 5 })
        end
        local response = http_request({
            Url = WEBHOOK_URL,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode({
                content = "",
                embeds = {{
                    title = "✅ Webhook Test Successful",
                    description = "Webhook is working!",
                    color = 3066993
                }}
            })
        })
        if response and response.StatusCode == 204 then
            Rayfield:Notify({ Title = "✅ Sent", Content = "Check your Discord!", Duration = 5 })
        else
            Rayfield:Notify({ Title = "❌ Failed", Content = "Status: " .. tostring(response.StatusCode), Duration = 6 })
        end
    end
})
WebhookTab:CreateToggle({
    Name = "Ping @everyone for Merchant",
    CurrentValue = false,
    Callback = function(state)
        pingMerchant = state
    end
})

-- 📤 Send Webhook
local function sendWebhook(message, embed)
    if WEBHOOK_URL == "" then return end
    http_request({
        Url = WEBHOOK_URL,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = HttpService:JSONEncode({ content = message, embeds = { embed } })
    })
end

-- 🧾 Log Entry (Asia/Jakarta Time)
local function logEvent(text)
    local utc = os.time()
    local adjustedTime = utc + (7 * 3600)
    local timestamp = os.date("!%H:%M:%S", adjustedTime)
    local place = game.PlaceId
    local entry = string.format("[🕒 %s] [🌍 %s] %s", timestamp, place, text)
    table.insert(historyLog, 1, entry)
    if #historyLog > 20 then table.remove(historyLog, #historyLog) end
    historyLogBox:Set({ Title = "Log", Content = table.concat(historyLog, "\n") })
end

-- 🔎 Biome + Merchant Checker
task.spawn(function()
    while true do
        if notifierEnabled then
            local activeBiomes = {}
            for _, child in ipairs(Lighting:GetChildren()) do
                table.insert(activeBiomes, child.Name)
                if whitelist[child.Name] and child.Name ~= lastBiome then
                    local ping = webhookNotify[child.Name] and "@everyone" or ""
                    local embed = {
                        title = "🌍 Biome Detected: " .. child.Name,
                        description = "A biome changed to **" .. child.Name .. "**!",
                        color = 65280,
                        fields = {
                            { name = "Player", value = LocalPlayer.Name, inline = true },
                            { name = "Place ID", value = tostring(game.PlaceId), inline = true }
                        }
                    }
                    sendWebhook(ping, embed)
                    logEvent("Biome Spawned: " .. child.Name)
                    lastBiome = child.Name
                    currentBiome = child.Name
                end
            end

            -- Detect biome despawn
            local foundTracked = false
            for _, name in ipairs(activeBiomes) do
                if whitelist[name] then
                    foundTracked = true
                    break
                end
            end
            if not foundTracked and lastBiome ~= "None" then
                logEvent("Biome Despawned: " .. lastBiome)
                lastBiome = "None"
                currentBiome = "None"
            end

            -- Merchant Detection
            local merchant = Workspace:FindFirstChild("TravellingMerchantRain")
            if merchant and not merchantSpawned then
                local embed = {
                    title = "🧑‍🌾 Travelling Merchant Arrived!",
                    description = "TravellingMerchantRain has spawned in your server!",
                    color = 0x00ffff
                }
                local merchantPing = pingMerchant and "@everyone" or ""
                sendWebhook(merchantPing, embed)
                logEvent("Travelling Merchant Rain has arrived!")
                merchantSpawned = true
            elseif not merchant then
                merchantSpawned = false
            end

            -- UI Refresh
            local activeStr = #activeBiomes > 0 and table.concat(activeBiomes, ", ") or "None"
            activeBiomesParagraph:Set({ Title = "Active Biomes", Content = activeStr })
            biomeParagraph:Set({ Title = "Current Biome", Content = currentBiome })
        end
        task.wait(1)
    end
end)
-- ✅ Load Rayfield (already loaded in Part 1)
local player = game.Players.LocalPlayer
local Lighting = game:GetService("Lighting")

-- 🎨 Ore Colors
local oreColors = {
    Iron = Color3.fromRGB(150,90,50), Lead = Color3.fromRGB(80,80,80), Crystal = Color3.fromRGB(230,230,230),
    Gold = Color3.fromRGB(255,220,50), Diamond = Color3.fromRGB(140,255,255), Cobalt = Color3.fromRGB(0,80,255),
    Viridis = Color3.fromRGB(0,255,0), Oureclasium = Color3.fromRGB(255,120,50), Tungsten = Color3.fromRGB(255,255,255),
    Titanium = Color3.fromRGB(140,140,140), Mithril = Color3.fromRGB(0,255,255), Adamantine = Color3.fromRGB(255,0,0),
    ["Gemstone of Purity"] = Color3.fromRGB(255,255,200), ["Gemstone of Hatred"] = Color3.fromRGB(200,0,0),
    Hatrite = Color3.fromRGB(255,0,255), Purite = Color3.fromRGB(150,255,255), Hellite = Color3.fromRGB(255,100,100),
    Hevenite = Color3.fromRGB(200,255,255), ["Forbidden Crystal"] = Color3.fromRGB(0,0,0),
    Moonstone = Color3.fromRGB(180,220,255), Irradium = Color3.fromRGB(50,255,50), Uranium = Color3.fromRGB(0,255,0),
    Plutonium = Color3.fromRGB(255,255,0), ["Astral Silver"] = Color3.fromRGB(180,180,255),
    Duranite = Color3.fromRGB(120,120,255), Aurium = Color3.fromRGB(255,215,0), Lanite = Color3.fromRGB(200,150,255)
}
local cavernOres = {"Iron","Lead","Crystal","Gold","Diamond","Cobalt","Viridis","Oureclasium","Tungsten","Titanium","Mithril","Adamantine"}
local beneathOres = {"Gemstone of Purity","Gemstone of Hatred","Hatrite","Purite","Hellite","Hevenite","Forbidden Crystal","Moonstone","Irradium","Uranium","Plutonium","Astral Silver","Duranite","Aurium","Lanite"}

-- 🧿 ESP UI Setup
local EspTab = Window:CreateTab("ESP", 4483362458)
local VisualsTab = Window:CreateTab("Visuals", 4483362458)
local PlayerTab = Window:CreateTab("Player", 4483362458)
local TeleportTab = Window:CreateTab("Teleport", 4483362458)

-- Ore ESP
local espEnabled, espObjects = false, {}
local enabledOres = {}; for k in pairs(oreColors) do enabledOres[k] = false end
local function clearESP() for _, gui in pairs(espObjects) do if gui then gui:Destroy() end end espObjects = {} end
local function createESP()
    clearESP()
    local ores = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Ores")
    if not ores then return end
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    for _, model in ipairs(ores:GetChildren()) do
        if model:IsA("Model") and oreColors[model.Name] and enabledOres[model.Name] then
            local part = model:FindFirstChildWhichIsA("BasePart")
            if part and root then
                local dist = math.floor((root.Position - part.Position).Magnitude)
                local gui = Instance.new("BillboardGui", game.CoreGui)
                gui.Adornee = part; gui.Size = UDim2.new(0, 100, 0, 20); gui.AlwaysOnTop = true
                gui.StudsOffset = Vector3.new(0, 3, 0)
                local lbl = Instance.new("TextLabel", gui)
                lbl.Size = UDim2.new(1, 0, 1, 0); lbl.BackgroundTransparency = 1
                lbl.Text = model.Name .. " ["..dist.."m]"; lbl.TextColor3 = oreColors[model.Name]
                lbl.TextScaled = true; lbl.Font = Enum.Font.GothamBold
                table.insert(espObjects, gui)
            end
        end
    end
end
EspTab:CreateToggle({ Name = "Enable Ore ESP", CurrentValue = false, Callback = function(v) espEnabled = v; if v then createESP() else clearESP() end end })
EspTab:CreateSection("🕳️ Cavern Ores")
for _, ore in ipairs(cavernOres) do
    EspTab:CreateToggle({ Name = ore, CurrentValue = false, Callback = function(v) enabledOres[ore] = v; if espEnabled then createESP() end end })
end
EspTab:CreateSection("🌌 The Beneath Ores")
for _, ore in ipairs(beneathOres) do
    EspTab:CreateToggle({ Name = ore, CurrentValue = false, Callback = function(v) enabledOres[ore] = v; if espEnabled then createESP() end end })
end
task.spawn(function() while true do task.wait(5) if espEnabled then createESP() end end end)

-- Mob ESP
local mobESPEnabled, mobESPInstances = false, {}
local function clearMobESP() for _, esp in pairs(mobESPInstances) do esp:Destroy() end mobESPInstances = {} end
local function createMobESP()
    clearMobESP()
    if game.PlaceId ~= 87037279088519 then return end
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChild("Humanoid") and obj:FindFirstChild("HumanoidRootPart") then
            local gui = Instance.new("BillboardGui", game.CoreGui)
            gui.Adornee = obj.HumanoidRootPart; gui.Size = UDim2.new(0, 150, 0, 40)
            gui.StudsOffset = Vector3.new(0, 4, 0); gui.AlwaysOnTop = true
            local lbl = Instance.new("TextLabel", gui)
            lbl.Size = UDim2.new(1, 0, 1, 0); lbl.BackgroundTransparency = 1; lbl.TextScaled = true
            lbl.Font = Enum.Font.GothamBold; lbl.TextColor3 = Color3.fromRGB(255,85,85)
            lbl.TextStrokeTransparency = 0; lbl.TextStrokeColor3 = Color3.new(0,0,0)
            lbl.Text = obj.Name .. " | " .. math.floor(obj.Humanoid.Health) .. " HP"
            table.insert(mobESPInstances, gui)
        end
    end
end
task.spawn(function() while true do task.wait(2) if mobESPEnabled then createMobESP() end end end)
game:GetService("RunService").RenderStepped:Connect(function()
    if not mobESPEnabled then return end
    for _, esp in pairs(mobESPInstances) do
        if esp and esp.Adornee and esp.Adornee:IsDescendantOf(workspace) then
            local model = esp.Adornee.Parent
            local hum = model:FindFirstChild("Humanoid")
            local root = model:FindFirstChild("HumanoidRootPart")
            if hum and root and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                local dist = math.floor((root.Position - player.Character.HumanoidRootPart.Position).Magnitude)
                esp.TextLabel.Text = model.Name .. " ["..dist.."m] | " .. math.floor(hum.Health) .. " HP"
            end
        end
    end
end)
VisualsTab:CreateToggle({ Name = "Enable Mob ESP", CurrentValue = false, Callback = function(v) mobESPEnabled = v; if v then createMobESP() else clearMobESP() end end })

-- Fullbright
local originalLighting = {}; for _, p in ipairs({"Ambient","Brightness","ClockTime","FogEnd","GlobalShadows","ColorShift_Top","ColorShift_Bottom"}) do originalLighting[p] = Lighting[p] end
VisualsTab:CreateToggle({ Name = "Enable Fullbright", CurrentValue = false, Callback = function(v)
    if v then
        Lighting.Ambient = Color3.new(1,1,1); Lighting.Brightness = 5; Lighting.ClockTime = 12
        Lighting.FogEnd = 1e5; Lighting.GlobalShadows = false
    else for k,v in pairs(originalLighting) do Lighting[k] = v end end
end})

-- Player Tab: WalkSpeed, JumpPower, Noclip, Fly
local noclip = false
PlayerTab:CreateToggle({ Name = "Enable Noclip", CurrentValue = false, Callback = function(v) noclip = v end })
game:GetService("RunService").Stepped:Connect(function()
    if noclip and player.Character then
        for _, p in pairs(player.Character:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end
end)
PlayerTab:CreateSlider({ Name = "WalkSpeed", Range = {16, 200}, CurrentValue = 16, Suffix = "Speed", Callback = function(v)
    if player.Character and player.Character:FindFirstChild("Humanoid") then player.Character.Humanoid.WalkSpeed = v end
end})
PlayerTab:CreateSlider({ Name = "JumpPower", Range = {50, 300}, CurrentValue = 50, Suffix = "Power", Callback = function(v)
    if player.Character and player.Character:FindFirstChild("Humanoid") then player.Character.Humanoid.JumpPower = v end
end})

-- Fly
local flyEnabled, bodyGyro, bodyVel
local flyKeys = {W=false,A=false,S=false,D=false,Space=false,LeftShift=false}
local UIS = game:GetService("UserInputService")
UIS.InputBegan:Connect(function(i,gp) if gp then return end local k=i.KeyCode.Name if flyKeys[k]~=nil then flyKeys[k]=true end end)
UIS.InputEnded:Connect(function(i) local k=i.KeyCode.Name if flyKeys[k]~=nil then flyKeys[k]=false end end)
local function startFly()
    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    bodyGyro = Instance.new("BodyGyro", hrp); bodyGyro.P = 9e4; bodyGyro.MaxTorque = Vector3.new(9e9,9e9,9e9); bodyGyro.CFrame = hrp.CFrame
    bodyVel = Instance.new("BodyVelocity", hrp); bodyVel.Velocity = Vector3.zero; bodyVel.MaxForce = Vector3.new(9e9,9e9,9e9)
    game:GetService("RunService"):BindToRenderStep("FlyControl", Enum.RenderPriority.Input.Value, function()
        if not flyEnabled then return end
        local cam = workspace.CurrentCamera; local move = Vector3.zero
        if flyKeys.W then move += cam.CFrame.LookVector end
        if flyKeys.S then move -= cam.CFrame.LookVector end
        if flyKeys.A then move -= cam.CFrame.RightVector end
        if flyKeys.D then move += cam.CFrame.RightVector end
        if flyKeys.Space then move += Vector3.new(0,1,0) end
        if flyKeys.LeftShift then move -= Vector3.new(0,1,0) end
        bodyVel.Velocity = move.Unit * 80
        bodyGyro.CFrame = cam.CFrame
    end)
end
local function stopFly()
    flyEnabled = false
    game:GetService("RunService"):UnbindFromRenderStep("FlyControl")
    if bodyGyro then bodyGyro:Destroy() end
    if bodyVel then bodyVel:Destroy() end
end
PlayerTab:CreateToggle({ Name = "Enable Fly (WASD + Space + Shift)", CurrentValue = false, Callback = function(v)
    flyEnabled = v; if v then startFly() else stopFly() end
end})

-- Teleport-to-Ore
local function teleportToClosestOre(name)
    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local ores = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Ores")
    local closest, minDist = nil, math.huge
    if not hrp or not ores then return end
    for _, model in pairs(ores:GetChildren()) do
        if model.Name == name and model:IsA("Model") then
            local part = model:FindFirstChildWhichIsA("BasePart")
            if part then
                local dist = (hrp.Position - part.Position).Magnitude
                if dist < minDist then minDist = dist; closest = part end
            end
        end
    end
    if closest then hrp.CFrame = closest.CFrame + Vector3.new(0,5,0) end
end
TeleportTab:CreateSection("🕳️ Cavern Ores")
for _, ore in ipairs(cavernOres) do
    TeleportTab:CreateButton({ Name = "Teleport to "..ore, Callback = function() teleportToClosestOre(ore) end })
end
TeleportTab:CreateSection("🌌 The Beneath Ores")
for _, ore in ipairs(beneathOres) do
    TeleportTab:CreateButton({ Name = "Teleport to "..ore, Callback = function() teleportToClosestOre(ore) end })
end
TeleportTab:CreateSection("📍 Teleport")
TeleportTab:CreateButton({
    Name = "Teleport to The Beneath",
    Callback = function()
        local tp = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("BeneathTeleporter")
        tp = tp and (tp:IsA("BasePart") and tp or tp:FindFirstChildWhichIsA("BasePart"))
        local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if tp and hrp then hrp.CFrame = tp.CFrame + Vector3.new(0,5,0) end
    end
})
-- Tool use loop (with auto equip)
task.spawn(function()
	while true do
		if autoToolFarm then
			local char = game.Players.LocalPlayer.Character
			local backpack = game.Players.LocalPlayer:FindFirstChild("Backpack")
			if char and backpack then
				for _, toolName in ipairs(selectedTools) do
					if toolName ~= "" then
						local equippedTool = char:FindFirstChild(toolName)
						local backpackTool = backpack:FindFirstChild(toolName)

						-- Equip if not already equipped
						if not equippedTool and backpackTool then
							backpackTool.Parent = char
							task.wait(0.1)
						end

						-- Activate if equipped
						local tool = char:FindFirstChild(toolName)
						if tool and tool:IsA("Tool") then
							tool:Activate()
							task.wait(0.3)
						end
					end
				end
			end
		end
		task.wait(toolLoopDelay)
	end
end)
-- 🛠️ Misc Tab
local MiscTab = Window:CreateTab("Misc", 4483362458)

-- 💤 Anti-AFK
local antiAfkConnection
MiscTab:CreateToggle({
    Name = "Enable Anti-AFK",
    CurrentValue = false,
    Callback = function(state)
        if state then
            if antiAfkConnection then antiAfkConnection:Disconnect() end
            antiAfkConnection = game:GetService("Players").LocalPlayer.Idled:Connect(function()
                VirtualUser = game:GetService("VirtualUser")
                VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
                task.wait(1)
                VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            end)
        else
            if antiAfkConnection then antiAfkConnection:Disconnect() end
        end
    end
})

-- 📦 Misc Tab & Drop Logger Setup
local MiscTab = Window:CreateTab("Misc", 4483362458)

local dropParagraph = MiscTab:CreateParagraph({
    Title = "📦 Dropped Items (Session)", Content = "No drops yet."
})

local dropPingEveryone = false
MiscTab:CreateToggle({
    Name = "Ping @everyone on Drop",
    CurrentValue = false,
    Callback = function(val) dropPingEveryone = val end
})

local dropLog = {}
local function updateDropParagraph()
    if #dropLog == 0 then
        dropParagraph:Set({ Title = "📦 Dropped Items (Session)", Content = "No drops yet." })
    else
        local out = {}
        for _, v in ipairs(dropLog) do table.insert(out, v) end
        dropParagraph:Set({ Title = "📦 Dropped Items (Session)", Content = table.concat(out, "\n") })
    end
end

MiscTab:CreateButton({
    Name = "Reset Drop Log",
    Callback = function()
        dropLog = {}
        updateDropParagraph()
        Rayfield:Notify({ Title = "✅ Cleared", Content = "Drop log cleared", Duration = 4 })
    end
})

-- 🟨 Rarity Color Mapping
local rarityColors = {
    ["#ffdd00"] = "Divine",
    ["#b14cff"] = "Mythical",
    ["#ff00ff"] = "Fabled",
    ["#00ffff"] = "Enchanted",
    ["#00ff00"] = "Exotic",
    ["#ff0000"] = "Legendary",
    ["#ffffff"] = "Common"
}

local function getColorHex(color3)
    local r = math.floor(color3.R * 255)
    local g = math.floor(color3.G * 255)
    local b = math.floor(color3.B * 255)
    return string.format("#%02x%02x%02x", r, g, b)
end
-- 📦 Inventory Drop Detection
local HttpService = game:GetService("HttpService")
local LocalPlayer = game:GetService("Players").LocalPlayer
local invFrame = LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("Inventory")
    .Frame.INVFrame.InventoryMain.LoadoutsFrame.Main.Scroll["5"].ItemsFrame.ScrollingFrame

local seenItems = {}

for _, v in ipairs(invFrame:GetChildren()) do
    if v:IsA("ImageLabel") and v:FindFirstChild("ItemName") then
        seenItems[v.ItemName.Text] = true
    end
end

invFrame.ChildAdded:Connect(function(child)
    if not child:IsA("ImageLabel") then return end
    local nameLabel = child:WaitForChild("ItemName", 3)
    if not nameLabel then return end

    local itemName = nameLabel.Text
    if seenItems[itemName] then return end -- already logged

    seenItems[itemName] = true

    local rarityHex = getColorHex(nameLabel.TextColor3)
    local rarity = rarityColors[rarityHex] or "Unknown"

    local msg = string.format("📦 **%s** [%s]", itemName, rarity)
    table.insert(dropLog, 1, msg)
    if #dropLog > 20 then table.remove(dropLog, #dropLog) end
    updateDropParagraph()

    if WEBHOOK_URL and WEBHOOK_URL ~= "" then
        http_request({
            Url = WEBHOOK_URL,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode({
                content = dropPingEveryone and "@everyone" or "",
                embeds = {{
                    title = "📦 Item Drop Detected",
                    description = msg,
                    color = 16753920
                }}
            })
        })
    end
end)
-- 📌 Autofarm Variables
local autofarmEnabled = false
local toolSlots = {"", "", "", "", "", ""}
local autofarmStats = { Swings = 0, Kills = 0 }
local antiAFKEnabled = false
local UserInputService = game:GetService("UserInputService")

-- 🧩 Autofarm Tab
local AutofarmTab = Window:CreateTab("🤖 Autofarm", 4483362458)
AutofarmTab:CreateToggle({
    Name = "Enable Autofarm (Click-based)",
    CurrentValue = false,
    Callback = function(val) autofarmEnabled = val end
})

for i = 1, 6 do
    AutofarmTab:CreateInput({
        Name = "Tool Slot " .. i,
        PlaceholderText = "Enter Tool Name",
        RemoveTextAfterFocusLost = false,
        Callback = function(txt) toolSlots[i] = txt end
    })
end

-- 📊 Autofarm Stats
local statParagraph = AutofarmTab:CreateParagraph({ Title = "Stats", Content = "Swings: 0\nKills: 0" })
local function updateStats()
    statParagraph:Set({
        Title = "Stats",
        Content = "Swings: " .. autofarmStats.Swings .. "\nKills: " .. autofarmStats.Kills
    })
end

-- ☕ Anti-AFK
AutofarmTab:CreateToggle({
    Name = "Enable Anti-AFK",
    CurrentValue = false,
    Callback = function(val)
        antiAFKEnabled = val
    end
})

game:GetService("Players").LocalPlayer.Idled:Connect(function()
    if antiAFKEnabled then
        virtualUser = virtualUser or game:GetService("VirtualUser")
        virtualUser:CaptureController()
        virtualUser:ClickButton2(Vector2.new())
    end
end)
task.spawn(function()
    while true do
        if autofarmEnabled then
            local char = game.Players.LocalPlayer.Character
            if char and char:FindFirstChild("Humanoid") and char:FindFirstChild("HumanoidRootPart") then
                -- Equip first available tool
                for _, tool in ipairs(game.Players.LocalPlayer.Backpack:GetChildren()) do
                    for _, wanted in ipairs(toolSlots) do
                        if wanted ~= "" and tool.Name == wanted then
                            tool.Parent = char
                        end
                    end
                end

                -- Attempt click
                for _, tool in ipairs(char:GetChildren()) do
                    if tool:IsA("Tool") then
                        autofarmStats.Swings += 1
                        updateStats()
                        pcall(function() tool:Activate() end)
                    end
                end

                -- Optional kill check (simple)
                for _, mob in ipairs(workspace:GetDescendants()) do
                    if mob:IsA("Model") and mob:FindFirstChild("Humanoid") and mob:FindFirstChild("HumanoidRootPart") then
                        local hum = mob:FindFirstChild("Humanoid")
                        if hum.Health <= 0 then
                            autofarmStats.Kills += 1
                            updateStats()
                        end
                    end
                end
            end
        end
        task.wait(2)
    end
end)


   -- 🛡️ Auto Shield Script (F Spam)
local autoShieldEnabled = false

-- 🧩 UI Toggle (Rayfield example, add to your Combat tab)
local CombatTab = Window:CreateTab("⚔️ Combat", 4483362458)
CombatTab:CreateToggle({
	Name = "Auto Shield (F Spam)",
	CurrentValue = false,
	Callback = function(val)
		autoShieldEnabled = val
	end
})

-- 🔁 F Key Press Loop
task.spawn(function()
	local VirtualInputManager = game:GetService("VirtualInputManager")
	while true do
		if autoShieldEnabled then
			VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
			task.wait(0.05)
			VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
		end
		task.wait(0.5)
	end
end)
