if CLIENT then
    CreateConVar("ragdoll_despawn_time", "240", FCVAR_CLIENTCMD_CAN_EXECUTE, "Время деспавна регдолов в секундах")
end

if SERVER then
    util.AddNetworkString("SyncRagdollDespawnTime")
    
    -- Отправляем значение клиенту при его подключении
    hook.Add("PlayerInitialSpawn", "SendRagdollDespawnTime", function(ply)
        net.Start("SyncRagdollDespawnTime")
        net.WriteInt(GetConVar("ragdoll_despawn_time"):GetInt(), 16)
        net.Send(ply)
    end)
end

if CLIENT then
    local ragdollDespawnTime = 240 -- Значение по умолчанию

    net.Receive("SyncRagdollDespawnTime", function()
        ragdollDespawnTime = net.ReadInt(16)
    end)

    -- Используем локальное значение вместо GetConVar
    local function OpenRagdollSettings()
        local frame = vgui.Create("DFrame")
        frame:SetTitle("Настройки регдоллов")
        frame:SetSize(300, 150)
        frame:Center()
        frame:MakePopup()

        local slider = vgui.Create("DNumSlider", frame)
        slider:SetPos(10, 40)
        slider:SetSize(280, 40)
        slider:SetText("Время деспавна (секунды)")
        slider:SetMin(30) -- Минимальное значение
        slider:SetMax(600) -- Максимальное значение
        slider:SetDecimals(0) -- Без дробей
        slider:SetValue(ragdollDespawnTime) -- Используем локальное значение
        slider.OnValueChanged = function(_, value)
            net.Start("SetRagdollDespawnTime")
            net.WriteInt(value, 16)
            net.SendToServer()
        end
    end

    concommand.Add("open_ragdoll_settings", OpenRagdollSettings)
end

if SERVER then
    util.AddNetworkString("SetRagdollDespawnTime")

    net.Receive("SetRagdollDespawnTime", function(len, ply)
        if not ply:IsAdmin() then return end -- Только админы могут менять настройки
        local newTime = net.ReadInt(16)
        RunConsoleCommand("ragdoll_despawn_time", tostring(newTime))
        print("[Ragdoll Settings] Новое время деспавна: " .. newTime)
    end)
end
