BleedingEntities = {}
local PlayerMeta = FindMetaTable("Player")
local EntityMeta = FindMetaTable("Entity")
print("[DEBUG] sv_fake.lua loaded")
--include("autorun/shared/sh_items.lua")


Organs = {
    ["brain"] = 20,
    ["lungs"] = 30,
    ["liver"] = 30,
    ["stomach"] = 40,
    ["intestines"] = 40,
    ["heart"] = 10,
    ["artery"] = 1, -- Оставляем "artery" как есть, предположим, что это "основная" артерия или артерия шеи
    ["artery_r_arm"] = 1, -- Артерия правой руки
    ["artery_l_arm"] = 1, -- Артерия левой руки
    ["spine"] = 10,
    ["pelvis"] = 35,
	["kidneys"] = 25,
	["pancreas"] = 20,
	["spleen"] = 15,
	["ribs"] = 35
}


local bonenames = {
	["ValveBiped.Bip01_Head1"] = "Head",
	["ValveBiped.Bip01_Spine"] = "Belly",
	["ValveBiped.Bip01_Spine1"] = "intestines",
	["ValveBiped.Bip01_Spine2"] = "Chest",
	["ValveBiped.Bip01_Spine4"] = "Chest",
	["ValveBiped.Bip01_Pelvis"] = "Belly",
	["ValveBiped.Bip01_R_Hand"] = "Right hand",
	["ValveBiped.Bip01_R_Forearm"] = "Head",
	["ValveBiped.Bip01_R_Foot"] = "Right leg",
	["ValveBiped.Bip01_R_Thigh"] = "Right thigh",
	["ValveBiped.Bip01_R_Calf"] = "Right calf",
	["ValveBiped.Bip01_R_Shoulder"] = "Right shoulder",
	["ValveBiped.Bip01_R_Elbow"] = "Right elbow",
	["ValveBiped.Bip01_L_Hand"] = "Left hand",
	["ValveBiped.Bip01_L_Forearm"] = "Head",
	["ValveBiped.Bip01_L_Foot"] = "Left leg",
	["ValveBiped.Bip01_L_Thigh"] = "Left thigh",
	["ValveBiped.Bip01_L_Calf"] = "Left calf",
	["ValveBiped.Bip01_L_Shoulder"] = "Left shoulder",
	["ValveBiped.Bip01_L_Elbow"] = "Left elbow"
}

--Умножения урона при попадании по регдоллу
RagdollDamageBoneMul = {
	[HITGROUP_LEFTLEG] = 1.2, -- Увеличен урон по левой ноге
	[HITGROUP_RIGHTLEG] = 1.2, -- Увеличен урон по правой ноге
	[HITGROUP_GENERIC] = 1.0,   -- Увеличен общий урон
	[HITGROUP_LEFTARM] = 1.2,  -- Увеличен урон по левой руке
	[HITGROUP_RIGHTARM] = 1.2, -- Увеличен урон по правой руке
	[HITGROUP_CHEST] = 1.5,    -- Увеличен урон по груди
	[HITGROUP_STOMACH] = 1.4,   -- Увеличен урон по животу
	[HITGROUP_HEAD] = 25,	  -- Увеличен урон по голове
}

--Хитгруппы костей
local bonetohitgroup = {
	["ValveBiped.Bip01_Head1"] = 1,
	["ValveBiped.Bip01_R_UpperArm"] = 5,
	["ValveBiped.Bip01_R_Forearm"] = 5,
	["ValveBiped.Bip01_R_Hand"] = 5,
	["ValveBiped.Bip01_L_UpperArm"] = 4,
	["ValveBiped.Bip01_L_Forearm"] = 4,
	["ValveBiped.Bip01_L_Hand"] = 4,
	["ValveBiped.Bip01_Pelvis"] = 3,
	["ValveBiped.Bip01_Spine2"] = 2,
    ["ValveBiped.Bip01_Spine1"] = 2,
    ["ValveBiped.Bip01_Spine"] = 3,
	["ValveBiped.Bip01_L_Thigh"] = 6,
	["ValveBiped.Bip01_L_Calf"] = 6,
	["ValveBiped.Bip01_L_Foot"] = 6,
	["ValveBiped.Bip01_R_Thigh"] = 7,
	["ValveBiped.Bip01_R_Calf"] = 7,
	["ValveBiped.Bip01_R_Foot"] = 7
}

function StopBleeding(ply)
    ply.IsBleeding = false
    ply.Bloodlosing = 0
    ply.arterybloodlosing = 0
    ply:SetNWFloat("BloodLosing", 0) -- на всякий случай синхронизируем
    ply:SetNWFloat("ArteryBloodLosing", 0)
    ply:ChatPrint("Кровотечение остановлено!") -- Сообщение можешь поменять
end

-- Хук для обработки экипировки JMod брони
hook.Add("JMod_Armor_Equip", "HandleJModArmorEquip", function(ply, slot, item, drop)
    print("[DEBUG] Equip called for:", ply, slot, item)
    local ragdoll = ply:GetNWEntity("DeathRagdoll")
    if not IsValid(ragdoll) then return end

    local ent = CreateArmor(ragdoll, item)
    ent.armorID = slot.id
    ent.Owner = ply
    ragdoll.armors = ragdoll.armors or {}
    ragdoll.armors[slot.id] = ent

    ent:CallOnRemove("HandleJModArmorRemove", function()
        if IsValid(ragdoll) and ragdoll.armors then
            ragdoll.armors[slot.id] = nil
        end
    end)
end)

-- Хук для обработки снятия JMod брони
hook.Add("JMod_Armor_Remove", "HandleJModArmorRemove", function(ply, slot, item, drop)
    print("[DEBUG] Remove called for:", ply, slot, item)
    local ragdoll = ply:GetNWEntity("DeathRagdoll")
    if not IsValid(ragdoll) or not ragdoll.armors then return end

    local ent = ragdoll.armors[slot.id]
    if IsValid(ent) then
        ent:Remove()
        ragdoll.armors[slot.id] = nil
    end
end)


-- Сохранение игрока перед его падением в фейк
function SavePlyInfo(ply)
	ply.Info = {}
	local info = ply.Info
	info.HasSuit = ply:IsSuitEquipped()
	info.SuitPower = ply:GetSuitPower()
	info.Ammo = ply:GetAmmo()
	info.ActiveWeapon = IsValid(ply:GetActiveWeapon()) and ply:GetActiveWeapon():GetClass() or nil
	info.ActiveWeapon2 = ply:GetActiveWeapon()
	GetFakeWeapon(ply)
	info.Weapons = {}
	for i, wep in pairs(ply:GetWeapons()) do
		info.Weapons[wep:GetClass()] = {
			Clip1 = wep:Clip1(),
			Clip2 = wep:Clip2(),
		}
	end

	return info
end

-- Например:
--[[local vel = ply:GetVelocity()
if ply.EZarmor and ply.EZarmor.items then
	ply.Info.ArmorItems = table.Copy(ply.EZarmor.items) --залупа не трогать все ломает я даун тупой -Slava
end]]


function GetFakeWeapon(ply)
	ply.curweapon = ply.Info.ActiveWeapon
end

function ClearFakeWeapon(ply)
	if ply.FakeShooting then
		DespawnWeapon(ply)
	end
end

-- Сохранение игрока перед вставанием
function SavePlyInfoPreSpawn(ply)
	ply.Info = ply.Info or {}
	local info = ply.Info
	info.Hp = ply:Health()
	info.Armor = ply:Armor()

	return info
end

-- возвращение информации игроку по его вставанию
function ReturnPlyInfo(ply)
	ClearFakeWeapon(ply)
	local info = ply.Info
	if not info then return end
	ply:SetSuppressPickupNotices(true)
	ply:StripWeapons()
	ply:StripAmmo()
	for name, wepinfo in pairs(info.Weapons or {}) do
		local weapon = ply:Give(name, true)
		if IsValid(weapon) then
			weapon:SetClip1(wepinfo.Clip1)
			weapon:SetClip2(wepinfo.Clip2)
		end
	end

	for ammo, amt in pairs(info.Ammo or {}) do
		ply:GiveAmmo(amt, ammo)
	end

	if info.ActiveWeapon then
		ply:SelectWeapon(info.ActiveWeapon)
	end

	if info.HasSuit then
		ply:EquipSuit()
		ply:SetSuitPower(info.SuitPower or 0)
	else
		ply:RemoveSuit()
	end

	ply:SetHealth(info.Hp)
	ply:SetArmor(info.Armor)
	ply:SetSuppressPickupNotices(false)
    if not ply:GetNWBool("unfaked") then
        ply.LeftLeg = 1
        ply.RightLeg = 1
        ply.RightArm = 1
        ply.LeftArm = 1
    end
    if ply.Info.ArmorItems then
        ply.EZarmor = ply.EZarmor or { items = {} }
        ply.EZarmor.items = ply.Info.ArmorItems
        for _, armor in pairs(ply.Info.ArmorItems) do
            JMod.AddArmor(ply, armor.name, armor.amount)
        end
    end
end



-- Функция для создания брони на регдолле
-- Функция для создания брони на регдолле
util.AddNetworkString("nodraw_helmet")

local function CreateArmor(ragdoll, info)
    if not IsValid(ragdoll) then
        print("[ERROR] CreateArmor: rэгдолл невалиден!")
        return
    end

    if not info or not info.name then
        print("[ERROR] CreateArmor: некорректные данные брони!", info and info.name or "NIL")
        return
    end

    local item = JMod.ArmorTable[info.name]
    if not item then
        print("[ERROR] CreateArmor: нет данных в JMod.ArmorTable для", info.name)
        return
    end

    local Index = ragdoll:LookupBone(item.bon)
    if not Index then
        print("[ERROR] CreateArmor: не найдена кость", item.bon, "для", info.name)
        return
    end

    local Pos, Ang = ragdoll:GetBonePosition(Index)
    if not Pos then
        print("[ERROR] CreateArmor: не удалось получить позицию кости", item.bon, "для", info.name)
        return
    end

    local ent = ents.Create(item.ent)
    if not IsValid(ent) then
        print("[ERROR] CreateArmor: не удалось создать объект", item.ent, "для", info.name)
        return
    end

    local Right, Forward, Up = Ang:Right(), Ang:Forward(), Ang:Up()
    Pos = Pos + Right * item.pos.x + Forward * item.pos.y + Up * item.pos.z

    Ang:RotateAroundAxis(Right, item.ang.p)
    Ang:RotateAroundAxis(Up, item.ang.y)
    Ang:RotateAroundAxis(Forward, item.ang.r)

    ent.IsArmor = true
    ent:SetPos(Pos)
    ent:SetAngles(Ang)
    ent:SetColor(Color(info.col.r, info.col.g, info.col.b, info.col.a))
    ent:Spawn()

    print("[DEBUG] Успешно создана броня:", info.name, "на рэгдолле", ragdoll)

    ent:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
    if IsValid(ent:GetPhysicsObject()) then
        ent:GetPhysicsObject():SetMaterial("plastic")
    end

    -- Скрытие шлема для игрока
    timer.Simple(0.1, function()
        local ply = RagdollOwner(ragdoll)
        if item.bon == "ValveBiped.Bip01_Head1" and IsValid(ply) and ply:IsPlayer() then
            net.Start("nodraw_helmet")
            net.WriteEntity(ent)
            net.Send(ply)
        end
    end)

    constraint.Weld(ent, ragdoll, 0, ragdoll:TranslateBoneToPhysBone(Index), 0, true, false)

    ragdoll:DeleteOnRemove(ent)

    return ent
end



local function Remove(self,ply)
	if self.override then return end

	self.ragdoll.armors[self.armorID] = nil
	JMod.RemoveArmorByID(ply,self.armorID,true)
end

local function RemoveRag(self)
	for id,ent in pairs(self.armors) do
		if not IsValid(ent) then continue end

		ent.override = true
		ent:Remove()
	end
end

-- Обновленная функция переноса брони

-- функция падения
function Faking(ply)
    ply.fake = not ply.fake
    ply:SetNWBool("fake", ply.fake)
    if ply.fake then
        SavePlyInfo(ply)
        ply:DrawViewModel(false)
        if SERVER then
            ply:DrawWorldModel(false)
        end

        if ply:InVehicle() then
            ply:ExitVehicle()
        end

        ply:CreateRagdoll()
        local ragdoll = ply:GetNWEntity("DeathRagdoll")
        if IsValid(ragdoll) then
            ply.fakeragdoll = ragdoll
            ply:HuySpectate()
            ply:SetSuppressPickupNotices(false)
            ply:SetActiveWeapon(nil)
            ply:DropObject()
            timer.Create("faketimer" .. ply:EntIndex(), 2, 1, function() end)
            local guninfo = weapons.Get(ply.curweapon)
            if guninfo and guninfo.Base == "salat_base" then
                ply.FakeShooting = true
                ply:SetNWInt("FakeShooting", true)
            else
                ply.FakeShooting = false
                ply:SetNWInt("FakeShooting", false)
            end
        end
        -- Переносим броню на регдолл
		--TransferArmorToRagdoll(ply, ragdoll)
	else
		if IsValid(ply:GetNWEntity("DeathRagdoll")) then
			ply.fakeragdoll = nil
			SavePlyInfoPreSpawn(ply)
			local pos = ply:GetNWEntity("DeathRagdoll"):GetPos()
			local vel = ply:GetNWEntity("DeathRagdoll"):GetVelocity()
			--ply:UnSpectate()
			ply.unfaked = true
			ply:SetNWBool("unfaked", ply.unfaked)
			local eyepos = ply:EyeAngles()
			ply:Spawn()
			ReturnPlyInfo(ply)
			ply.FakeShooting = false
			ply:SetNWInt("FakeShooting", false)
			ply:SetVelocity(vel)
			ply:SetEyeAngles(eyepos)
			ply.unfaked = false
			ply:SetNWBool("unfaked", ply.unfaked)
			ply:SetParent()
			ply:SetPos(pos)
			ply:DrawViewModel(true)
			ply:DrawWorldModel(true)
			ply:GetNWEntity("DeathRagdoll"):Remove()
			ply:SetNWEntity("DeathRagdoll", nil)
		end
	end
end


--функция стрельбы лежа
hook.Add(
	"Think",
	"FakedShoot",
	function()
		for i, ply in ipairs(player.GetAll()) do
			if IsValid(ply:GetNWEntity("DeathRagdoll")) and ply.FakeShooting and ply:Alive() then
				SpawnWeapon(ply)
			else
				if IsValid(ply.wep) then
					DespawnWeapon(ply)
				end
			end
		end
	end
)

hook.Add("PlayerSay","huyasds",function(ply,text)
	if ply:IsAdmin() and string.lower(text)=="!hostageply" then
		local hostagemodels = {
			"models/player/hostage/hostage_01.mdl",
			"models/player/hostage/hostage_02.mdl",
			"models/player/hostage/hostage_03.mdl",
			"models/player/hostage/hostage_04.mdl"
		}
		local ent = ply:GetEyeTrace().Entity
		if ent:IsPlayer() then
			ply:ChatPrint(ent:Nick(),ent:EntIndex())
			print(tostring(ply:Name()).." связал "..tostring(ent:Name()))
			ent:StripWeapons()
			ent:Give("weapon_hands")
			ent:SetModel(table.Random(hostagemodels))
			Faking(ent)
			timer.Simple(0,function()
				local enta = ent:GetNWEntity("Ragdoll")
				enta:GetPhysicsObjectNum(5):SetPos(enta:GetPhysicsObjectNum(7):GetPos())
				for i=1,3 do
					constraint.Rope(enta,enta,5,7,Vector(0,0,0),Vector(0,0,0),-2,2,0,4,"cable/rope.vmt",false,Color(255,255,255))
				end
			end)
			ent.Hostage = true
		elseif ent:IsRagdoll() then
			ply:ChatPrint(IsValid(RagdollOwner(ent)) and RagdollOwner(ent):Name())
			--ent:StripWeapons()
			--ent:Give("weapon_hands")
			--Faking(ent)
			timer.Simple(0,function()
				local enta = ent
				enta:GetPhysicsObjectNum(5):SetPos(enta:GetPhysicsObjectNum(7):GetPos())
				for i=1,3 do
					constraint.Rope(enta,enta,5,7,Vector(0,0,0),Vector(0,0,0),-2,2,0,4,"cable/rope.vmt",false,Color(255,255,255))
				end
			end)
		end
		return ""
	end
end)

function RagdollOwner(rag) --функция, определяет хозяина регдолла
	if not IsValid(rag) then return end

	local ent = rag:GetNWEntity("RagdollController")
	return IsValid(ent) and ent
end

--функция, определяет хозяина регдолла
function RagdollOwner(rag)
	for k, v in ipairs(player.GetAll()) do
		local ply = v
		if ply:GetNWEntity("DeathRagdoll") == rag then return ply end
	end

	return false
end



function PlayerMeta:DropWeapon()
	local ply = self
	if not IsValid(ply:GetActiveWeapon()) then return end
	local guninfo = weapons.Get(ply:GetActiveWeapon():GetClass())
	if guninfo.Base == "salat_base" then
		ply.curweapon = ply:GetActiveWeapon():GetClass()
		ply.Clip = ply:GetActiveWeapon():Clip1()
		ply.AmmoType = ply:GetActiveWeapon():GetPrimaryAmmoType()
		SpawnWeaponEnt(ply:GetActiveWeapon():GetClass(), ply:EyePos() + Vector(0, 0, -10), ply):GetPhysicsObject():ApplyForceCenter(ply:GetAimVector() * 200 + ply:GetVelocity())
		ply.curweapon = nil
		ply.Clip = nil
		ply.AmmoType = nil
		ply:GetActiveWeapon():Remove()
	end
end

function PlayerMeta:PickupEnt()
	local ply = self
	local rag = ply:GetNWEntity("DeathRagdoll")
	local phys = rag:GetPhysicsObjectNum(7)
	local offset = phys:GetAngles():Right() * 5
	local traceinfo = {
		start = phys:GetPos(),
		endpos = phys:GetPos() + offset,
		filter = rag,
		output = trace,
	}

	local trace = util.TraceLine(traceinfo)
	if trace.Entity == Entity(0) or trace.Entity == NULL or not trace.Entity.canpickup then return end
	if trace.Entity:GetClass() == "wep" then
		ply:Give(trace.Entity.curweapon, true):SetClip1(trace.Entity.Clip)
		--SavePlyInfo(ply)
		ply.wep.Clip = trace.Entity.Clip
		trace.Entity:Remove()
	end
end

--обнуление регдолла после вставания
hook.Add(
	"PlayerDeath",
	"resetfakes",
	function(ply, inflictor, attacker)
		if ply.fake then
			ply:SetNWEntity("DeathRagdoll", nil)
			Faking(ply)
			ply:SetParent()
			ply:Spectate(OBS_MODE_ROAMING)
			ply:SetNWEntity("DeathRagdoll", nil)
		end

		if ply.Attacker ~= nil and ply.Attacker ~= ply:Nick() then
			if bonenames[tostring(ply.LastHit)] ~= nil then
				ply:ChatPrint("you were killed by a " .. ply.Attacker .. " in " .. bonenames[tostring(ply.LastHit)] .. ".")
			else
				ply:ChatPrint("you were killed by a " .. ply.Attacker .. ".")
			end

			print(bonenames[tostring(ply.LastHit)])
		else
			ply:ChatPrint("You dead.")
		end
	end
)

hook.Add(
	"PhysgunDrop",
	"DropPlayer",
	function(ply, ent)
		ent.isheld = false
	end
)

hook.Add(
	"PhysgunPickup",
	"DropPlayer2",
	function(ply, ent)
		if ply:GetUserGroup() == "superadmin" then
			ent.isheld = true
			if ent:IsPlayer() and not ent.fake then
				Faking(ent)

				return false
			end
		end
	end
)

--обнуление регдолла после вставания
hook.Add(
	"DoPlayerDeath",
	"resetfakes3232",
	function(ply)
		if ply.fake then
			local rag = ply:GetNWEntity("DeathRagdoll")
			ply:GetNWEntity("DeathRagdoll").deadbody = true
			if ply.IsBleeding then
				rag.IsBleeding = true
			end

			table.insert(BleedingEntities, rag)
			rag:SetEyeTarget(vector_origin)
			ply:Spectate(OBS_MODE_ROAMING)
			ply:SetMoveType(MOVETYPE_OBSERVER)
		end
	end
)

concommand.Add(
	"organdamage",
	function(ply, command, arguments)
		if not ply:IsPlayer() then return end
		if not arguments[1] or not arguments[2] then
			ply:ChatPrint("Usage: organdamage <орган> <урон>")
			return
		end
		local target = ply:GetEyeTrace().Entity
		local hitply

		if not IsValid(target) or not target:IsPlayer() and not IsValid(RagdollOwner(target)) then
          for k, v in ipairs(player.GetAll()) do
            if v:GetPos():Distance(ply:GetPos()) < 300 then
                hitply = v
				break
			end
         end
		  if not IsValid(hitply) then
				ply:ChatPrint("Nothing is being targeted")
				return
			end
		  target = hitply
		end

		if target:IsPlayer() or IsValid(RagdollOwner(target)) then
			 local target = RagdollOwner(target) or target
		   local organ = arguments[1]
		   local damage = tonumber(arguments[2])
			if not damage then
				ply:ChatPrint("Урон должен быть числом")
				return
			end
			if target.Organs and target.Organs[organ] then
				target.Organs[organ] = math.Clamp(target.Organs[organ] - damage, 0, 100)
				if IsValid(RagdollOwner(target)) then
					RagdollOwner(target):ChatPrint("Урон органу "..organ.." нанесён : " .. damage .. " points.")
				elseif target:IsPlayer() then
					target:ChatPrint("Урон органу "..organ.." нанесён : " .. damage .. " points.")
				end
				print(ply:Nick().." нанес урон " .. damage .. " по органу " ..organ .. " игроку " .. target:Nick())
			else
				ply:ChatPrint("Неизвестный орган: " .. organ)
			end
		else
			ply:ChatPrint("Не игрок")
		end
	end
)

concommand.Add("organs", function(ply, cmd, args)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    local organs = ply.Organs
    if not organs then
        ply:ChatPrint("У вас нет органов, или они еще не проинициализированы.")
        return
    end

    ply:ChatPrint("--------- Состояние органов ---------")
    for organName, organHealth in pairs(organs) do
        ply:ChatPrint(organName .. ": " .. (organHealth or "Цел"))
    end
     if ply.brokenspine then
	   ply:ChatPrint("Сломана спина")
	end
    ply:ChatPrint("-----------------------------------")
end)

--ply:GetNWEntity("DeathRagdoll").index=table.MemberValuesFromKey(BleedingEntities,ply:GetNWEntity("DeathRagdoll"))
hook.Add(
	"Think",
	"BodyDespawn",
	function()
		for i, ent in pairs(ents.FindByClass("prop_ragdoll")) do
			if ent.deadbody and engine.ActiveGamemode() == "sandbox" then
				if IsValid(ent.ZacConsLH) then
					ent.ZacConsLH:Remove()
					ent.ZacConsLH = nil
				end

				if IsValid(ent.ZacConsRH) then
					ent.ZacConsRH:Remove()
					ent.ZacConsRH = nil
				end

				if not timer.Exists("DecayTimer" .. ent:EntIndex()) then
					timer.Create(
						"DecayTimer" .. ent:EntIndex(),
						240,
						1,
						function()
							if IsValid(ent) then
								ent:Remove()
								table.RemoveByValue(BleedingEntities, ent)
							end
						end
					)
				end
			end
		end
	end
)

util.AddNetworkString("ragplayercolor")
function EntityMeta:BetterSetPlayerColor(col)
	if not (col or self) then return end
	timer.Simple(
		.1,
		function()
			if not IsValid(self) then return end
			net.Start("ragplayercolor")
			net.WriteEntity(self)
			net.WriteVector(col)
			net.Broadcast()
		end
	)
end

--обнуление регдолла после вставания
hook.Add(
	"PlayerSpawn",
	"resetfakebody",
	function(ply)
		ply.fake = false
		if not ply.unfaked then
			ply.suiciding = false
			ply:SetNWEntity("DeathRagdoll", nil)
			--ply:GetNWEntity("DeathRagdoll").health=ply:Health()
			local Organs = {
				["brain"] = 5,
				["lungs"] = 30,
				["liver"] = 30,
				["stomach"] = 40,
				["intestines"] = 40,
				["heart"] = 10,
				["artery"] = 1,
				["spine"] = 10,
				["pelvis"] = 1,
				["kidneys"] = 25,
				["pancreas"] = 20,
				["spleen"] = 15,
				["ribs"] = 35
			}

			ply.InternalBleeding = nil
			ply.InternalBleeding2 = nil
			ply.InternalBleeding3 = nil
			ply.InternalBleeding4 = nil
			ply.InternalBleeding5 = nil
			ply.arterybleeding = false
			ply.brokenspine = false
			--table.Merge(Organs,ply.Organs)

			-- Инициализация переменных для системы переломов
			ply.LeftArm = 1
			ply.RightArm = 1
			ply.LeftLeg = 1
			ply.RightLeg = 1

			ply.msgLeftArm = 0
			ply.msgRightArm = 0
			ply.msgLeftLeg = 0
			ply.msgRightLeg = 0

			ply.upper_spine = 10
			ply.LeftArmbroke = false
			ply.RightArmbroke = false
			ply.LeftLegbroke = false
			ply.RightLegbroke = false
			ply.brokenspine = false
			ply.broken_uspine = false
		end
	end
)

local function HandleArteryDamage(target, organName, damage)
	if target.Organs[organName] ~= 0 then
		target.Organs[organName] = math.Clamp((target.Organs[organName] or 1) - damage, 0, 1)

		if not target.arterybleeding then -- Проверяем общий флаг arterybleeding
			target.arterybleeding = true -- Устанавливаем общий флаг
			target:SetNWBool("ArterialBleeding", true)
			target:ChatPrint("У вас сильное артериальное кровотечение!")
			print(organName .. " повреждена! Началось артериальное кровотечение!")
		end
	end
end

local bleedsounds = {"player/pl_pain1.wav", "player/pl_pain2.wav", "player/damage1.wav",  "player/pl_pain3.wav", "player/damage2.wav", "player/damage3.wav", "player/pl_pain5.wav", "player/pl_pain6.wav", "player/pl_pain6.wav", "player/pl_pain4.wav"}
--урон по разным костям регдолла
local r_tooth = math.random(4,9)

local Organs = {
    ["brain"] = 20,
    ["lungs"] = 30,
    ["liver"] = 30,
    ["stomach"] = 40,
    ["intestines"] = 40,
    ["heart"] = 10,
    ["artery"] = 1, -- Оставляем "artery" как есть, предположим, что это "основная" артерия или артерия шеи
    ["artery_r_arm"] = 1, -- Артерия правой руки
    ["artery_l_arm"] = 1, -- Артерия левой руки
    ["spine"] = 10,
    ["pelvis"] = 35,
	["kidneys"] = 25,
	["pancreas"] = 20,
	["spleen"] = 15,
	["ribs"] = 35
}

local LiverTimers = {}
local AortaTimers = {}
local MouthTimers = {}
local TraheaTimers = {}
local HeartTimers = {}
local LungTimers = {}
local AllTimers = {}
local walkSpeeds = {}
local runSpeeds = {}

local function HandleOrganDamage(target, dmginfo)
    local bullet_force = dmginfo:GetDamageForce()
    local bullet_pos = dmginfo:GetDamagePosition()
	local damage = dmginfo:GetDamage() or 0
    if not target.Organs then
        target.Organs = Organs
    end

    if target:IsPlayer() and dmginfo:IsBulletDamage() then
        local attacker = dmginfo:GetAttacker()
        if attacker and attacker:IsPlayer() and attacker:GetActiveWeapon() then
            if attacker:GetActiveWeapon():GetClass() != "wep_mann_hmcd_pnevmat" then
                 local pos,ang = target:GetBonePosition(target:LookupBone('ValveBiped.Bip01_Head1'))
                local head = util.IntersectRayWithOBB(bullet_pos,bullet_force, pos, ang, Vector(2,-5,-3),Vector(7,3,3))
                local mouth = util.IntersectRayWithOBB(bullet_pos,bullet_force, pos, ang, Vector(-1,-5,-3),Vector(2,1,3))
                local trahea = util.IntersectRayWithOBB(bullet_pos,bullet_force, pos, ang, Vector(-9,-1,-0.8), Vector(-2,0.2,0.8))
                
                local pos1, ang1 = target:GetBonePosition(target:LookupBone("ValveBiped.Bip01_Spine1"))
                local aorta = util.IntersectRayWithOBB(bullet_pos, bullet_force, pos1, ang1, Vector(-4, 1, 1), Vector(4, 2, 2))
				local liver = util.IntersectRayWithOBB(bullet_pos,bullet_force, pos1, ang1, Vector(-1,-2,-5),Vector(4,4,1))
                --local kidneys = util.IntersectRayWithOBB(bullet_pos, bullet_force, pos1, ang1, Vector(-6, -3, -2), Vector(2, 3, 4))
                local pancreas = util.IntersectRayWithOBB(bullet_pos, bullet_force, pos1, ang1, Vector(1, 0, -1), Vector(3, 2, 3))
                local spleen = util.IntersectRayWithOBB(bullet_pos, bullet_force, pos1, ang1, Vector(-2, -3, 3), Vector(-3, 2, 6))
                
                local pos2, ang2 = target:GetBonePosition(target:LookupBone("ValveBiped.Bip01_Spine2"))
                local lung = util.IntersectRayWithOBB(bullet_pos, bullet_force, pos2, ang2, Vector(1, -1, -6), Vector(8, 7, 6))
				local heart = util.IntersectRayWithOBB(bullet_pos, bullet_force, pos2, ang2, Vector(1, 0, -1), Vector(5, 4, 3))
				local rib = util.IntersectRayWithOBB(bullet_pos, bullet_force, pos2, ang2, Vector(-3, 4, -1), Vector(7,10,1))

                local pos3, ang3 = target:GetBonePosition(target:LookupBone('ValveBiped.Bip01_Pelvis'))
                local pelvis = util.IntersectRayWithOBB(bullet_pos, bullet_force, pos3, ang3, Vector(-4, -3, -3), Vector(4, 3, 3))

				 local pos5, ang5 = target:GetBonePosition(target:LookupBone("ValveBiped.Bip01_Spine4"))
                 local spine = util.IntersectRayWithOBB(bullet_pos,bullet_force, pos5, ang5, Vector(-8, -1, -1), Vector(2, 0, 1))
				 local pos6, ang6 = target:GetBonePosition(target:LookupBone("ValveBiped.Bip01_Spine1"))
				 local spine2 = util.IntersectRayWithOBB(bullet_pos,bullet_force, pos6, ang6, Vector(-8, -3, -1), Vector(2, -2, 1))

                local pos7, ang7 = target:GetBonePosition(target:LookupBone("ValveBiped.Bip01_Head1"))
                local artery1 = util.IntersectRayWithOBB(bullet_pos, bullet_force, pos7, ang7, Vector(-3, -2, -2), Vector(0, -1, -1))
                local artery2 = util.IntersectRayWithOBB(bullet_pos, bullet_force, pos7, ang7, Vector(-3, -2, 1), Vector(0, -1, 2))
                local rib2 = util.IntersectRayWithOBB(bullet_pos, bullet_force, pos1, ang1, Vector(-3, 4, -1), Vector(7,10,1))
                
				local pos_r_leg, ang_r_leg = target:GetBonePosition(target:LookupBone("ValveBiped.Bip01_R_Thigh"))
				local artery_r_leg = util.IntersectRayWithOBB(bullet_pos, bullet_force, pos_r_leg, ang_r_leg, Vector(-2, 0, 0), Vector(10, 1, 1))
				
				local pos_l_leg, ang_l_leg = target:GetBonePosition(target:LookupBone("ValveBiped.Bip01_L_Thigh"))
				local artery_l_leg = util.IntersectRayWithOBB(bullet_pos, bullet_force, pos_l_leg, ang_l_leg, Vector(-2, 0, 0), Vector(10, 1, 1))
				
				local pos_r_arm, ang_r_arm = target:GetBonePosition(target:LookupBone("ValveBiped.Bip01_R_UpperArm"))
                local artery_r_arm = util.IntersectRayWithOBB(bullet_pos, bullet_force, pos_r_arm, ang_r_arm, Vector(-1, 0, 0), Vector(10, 1, 1))
				local pos_l_arm, ang_l_arm = target:GetBonePosition(target:LookupBone("ValveBiped.Bip01_L_UpperArm"))
                local artery_l_arm = util.IntersectRayWithOBB(bullet_pos, bullet_force, pos_l_arm, ang_l_arm, Vector(-1, 0, 0), Vector(10, 1, 1))
				local timerName = "organ_timer" .. target:SteamID()
                if head then
                    print("Head Hitted")
					target:ChatPrint("Вы получили повреждение мозга!")
                    target:Kill()
					target.Organs["brain"] = 0
					target:EmitSound("NPC_Barnacle.BreakNeck", 511, 200, 1, CHAN_ITEM)
                end

                if mouth then
                    print("Mouth Hitted")
					target:ChatPrint("Пуля попала вам в область рта, ваша челюсть свисает, вы лишились нескольких зубов.")
                    target:SetNWInt("Tooth", target:GetNWInt("Tooth", 32) - r_tooth)
                    target:SetNWBool("ArterialBleeding", true)
                     timer.Create(timerName, 0.3, 0, function()
						if not IsValid(target) then timer.Remove(timerName); return end
                        local handPos, handAng = target:GetBonePosition(target:LookupBone("ValveBiped.Bip01_Neck1"))
                        local bloodPos = handPos + handAng:Forward() * 50
                        local bloodTrace = util.TraceLine({
                            start = bloodPos,
                            endpos = bloodPos - Vector(0, 0, 100),
                            filter = target
                        })
						if not IsValid(target) then timer.Remove(timerName); return end
                        target:SetWalkSpeed(50)
                        target:SetRunSpeed(100)
                        if bloodTrace.Hit then
                            if default_dblood == false then
								if not IsValid(target) then timer.Remove(timerName); return end
                                util.Decal(table.Random(artery_paint), bloodTrace.HitPos + bloodTrace.HitNormal, bloodTrace.HitPos - bloodTrace.HitNormal)
                            end
                            if default_dblood == true then
								if not IsValid(target) then timer.Remove(timerName); return end
                                util.Decal("Blood", bloodTrace.HitPos + bloodTrace.HitNormal, bloodTrace.HitPos - bloodTrace.HitNormal)
                            end
							if not IsValid(target) then timer.Remove(timerName); return end
                            target:SetNWInt("Blood", target:GetNWInt("Blood", 5000) - 10)
                            target:SetNWInt("Pain", target:GetNWInt("Pain", 0) + 1)
                            target:EmitSound(table.Random(bleedsounds), 75, 100, 1, CHAN_AUTO)
                        end
                    end)
                     AllTimers[timerName] = timerName
                    MouthTimers[target:SteamID()] = timerName
                end

                if trahea then
					print("Trahea hit")
					target:ChatPrint("Пуля попала вам в трахею, дыхание затруднено.")
					target:SetNWInt("Pain", target:GetNWInt("Pain", 0) + 30)
					target.stamina = math.max(target.stamina - 20, 0) -- Уменьшение стамины из-за трудностей с дыханием
					local timerName = "organ_timer" .. target:SteamID()
					timer.Create(timerName, 3, 0, function()
						if not IsValid(target) then timer.Remove(timerName); return end
						target:SetNWInt("O2", target:GetNWInt("O2", 100) - 15)
					end)
					AllTimers[timerName] = timerName
					TraheaTimers[target:SteamID()] = timerName
				end
				
                
                if aorta then
					print("Aorta Hitted")
					target:ChatPrint("В вас попали! У вас разорвалась аорта! Вы истекаете кровью!")
					target:EmitSound("player/pl_pain5.wav", 75, 100, 1, CHAN_AUTO)
					--target:EmitSound("player/breathe1.wav", 75, 100, 1, CHAN_AUTO)
					target:SetNWInt("Pain", target:GetNWInt("Pain", 0) + 20)
					
					-- Запускаем неизлечимое артериальное кровотечение
					target:SetNWBool("ArterialBleeding", true)
					target.aorta_ruptured = true -- Флаг, что аорта разорвана
					
					local timerName = "aorta_bleeding_" .. target:SteamID()
					timer.Create(timerName, 0.3, 0, function()
						if not IsValid(target) then timer.Remove(timerName); return end
						if target.Blood <= 0 then 
							target:Kill()
							timer.Remove(timerName)
							return
						end
				
						local bloodLoss = target.aorta_ruptured and 30 or 10 -- Если аорта разорвана, кровотечение сильнее
						target.Blood = math.max(target.Blood - bloodLoss, 0)
						target:SetNWInt("Blood", target.Blood)
				
						local bloodPos = target:GetBonePosition(target:LookupBone("ValveBiped.Bip01_Spine2")) + Vector(0, 0, -10)
						util.Decal("Blood", bloodPos + Vector(0, 0, 5), bloodPos - Vector(0, 0, 5), target)
						target:EmitSound("ambient/water/drip" .. math.random(1, 4) .. ".wav", 60, 100, 0.5, CHAN_AUTO)
					end)
				
					AllTimers[timerName] = timerName
					AortaTimers[target:SteamID()] = timerName
				end
				

                if heart then
					if not IsValid(target) then return end
                    print("Heart Hitted")
					target:ChatPrint("Бум, вам попали в сердце, у вас сильная отдышка и очень массивная боль.")
                    target:SetNWInt("Pain", target:GetNWInt("Pain", 0) + 30)
                    target:SetNWBool("ArterialBleeding", true)
                    target.stamina = math.max(target.stamina - 30, 0) -- Уменьшение стамины
					local timerName = "organ_timer" .. target:SteamID()
                    timer.Create(timerName, 0.3, 0, function()
						if not IsValid(target) then timer.Remove(timerName); return end
                        local handPos, handAng = target:GetBonePosition(target:LookupBone("ValveBiped.Bip01_Spine2"))
                        local bloodPos = handPos + handAng:Forward() * 50
                        local bloodTrace = util.TraceLine({
                            start = bloodPos,
                            endpos = bloodPos - Vector(0, 0, 100),
                            filter = target
                        })
						if not IsValid(target) then timer.Remove(timerName); return end
                        target:SetWalkSpeed(50)
                        target:SetRunSpeed(100)
                        if bloodTrace.Hit then
                            if default_dblood == false then
								if not IsValid(target) then timer.Remove(timerName); return end
                                util.Decal(table.Random(artery_paint), bloodTrace.HitPos + bloodTrace.HitNormal, bloodTrace.HitPos - bloodTrace.HitNormal)
                            end
                            if default_dblood == true then
								if not IsValid(target) then timer.Remove(timerName); return end
                                util.Decal("Blood", bloodTrace.HitPos + bloodTrace.HitNormal, bloodTrace.HitPos - bloodTrace.HitNormal)
                            end
							if not IsValid(target) then timer.Remove(timerName); return end
                            target:SetNWInt("Blood", target:GetNWInt("Blood", 5000) - 10)
                            target:SetNWInt("Pain", target:GetNWInt("Pain", 0) + 2)
                            target:EmitSound(table.Random(bleedsounds), 75, 100, 1, CHAN_AUTO)
                        end
                    end)
                    AllTimers[timerName] = timerName
                     HeartTimers[target:SteamID()] = timerName
                end

                if lung then
					if not IsValid(target) then return end
					print("Lung Hitted")
					target:ChatPrint("Вы чувствуете, что ваша грудная клетка переполняется кислородом")
					target:SetNWInt("Pain", target:GetNWInt("Pain", 0) + 20)
					target.stamina = math.max(target.stamina - 15, 0) -- Потеря стамины из-за недостатка кислорода
					local timerName = "organ_timer" .. target:SteamID()
					timer.Create(timerName, 3, 0, function()
						if not IsValid(target) then timer.Remove(timerName); return end
						target:SetNWInt("O2", target:GetNWInt("O2", 100) - 15)
						target:SetNWInt("Blood", target:GetNWInt("Blood", 5000) - target:GetNWInt("O2", 100) / 5)
					end)
					AllTimers[timerName] = timerName
					LungTimers[target:SteamID()] = timerName
				end
                
                if pelvis then
					if not IsValid(target) then return end
                    print("Pelvis Hitted")
					 target:ChatPrint("Вам сломало таз! Это довольно сильная боль!")
                    target:EmitSound("player/pl_pain5.wav", 75, 100, 1, CHAN_AUTO)
                    target:SetNWInt("Pain", target:GetNWInt("Pain", 0) + 30)
                    target:SetWalkSpeed(50)
                    target:SetRunSpeed(100)
                    timer.Simple(1, function() if IsValid(target) then target:SetWalkSpeed(200); target:SetRunSpeed(300) end end)
                    target.Organs["pelvis"] = 0
                end
				
                 if liver then
					if not IsValid(target) then return end
                    print("Liver Hitted")
					target:ChatPrint("Ваша печень повреждена!")
                    target:EmitSound("player/pl_pain5.wav", 75, 100, 1, CHAN_AUTO)
                    target:SetNWInt("Pain", target:GetNWInt("Pain", 0) + 10)
                    target:SetNWBool("LiverBleeding", true)
                    local timerName = "organ_timer" .. target:SteamID()
                    timer.Create(timerName, 0.6, 0, function()
						if not IsValid(target) then timer.Remove(timerName); return end
                        local handPos, handAng = target:GetBonePosition(target:LookupBone("ValveBiped.Bip01_Spine"))
                        local bloodPos = handPos + handAng:Forward() * 50
                        local bloodTrace = util.TraceLine({
                            start = bloodPos,
                            endpos = bloodPos - Vector(0, 0, 100),
                            filter = target
                        })
						if not IsValid(target) then timer.Remove(timerName); return end
                        target:SetWalkSpeed(50)
                        target:SetRunSpeed(100)
                        if bloodTrace.Hit then
                            if default_dblood == false then
								if not IsValid(target) then timer.Remove(timerName); return end
                                util.Decal("Cross", bloodTrace.HitPos + bloodTrace.HitNormal, bloodTrace.HitPos - bloodTrace.HitNormal)
                            end
                            if default_dblood == true then
								if not IsValid(target) then timer.Remove(timerName); return end
                                util.Decal("Blood", bloodTrace.HitPos + bloodTrace.HitNormal, bloodTrace.HitPos - bloodTrace.HitNormal)
                            end
							if not IsValid(target) then timer.Remove(timerName); return end
                            target:SetNWInt("Blood", target:GetNWInt("Blood", 5000) - 10)
                            target:SetNWInt("Pain", target:GetNWInt("Pain", 0) + 2)
                            target:EmitSound(table.Random(bleedsounds), 75, 100, 1, CHAN_AUTO)
                        end
                    end)
                    AllTimers[timerName] = timerName
                     LiverTimers[target:SteamID()] = timerName
                end
				 
				if spine or spine2 then
					if target.Organs["spine"] ~= 0 then
						target.Organs["spine"] = math.Clamp((target.Organs["spine"] or 10) - damage, 0, 10)
						if target.Organs["spine"] == 0 then
							if not target.fake then
								Faking(target)
								target:ChatPrint("Your spine was broken.")
							end
						end
					end
				end
                if kidneys then
					if not IsValid(target) then return end
                    print("kidneys Hitted")
					 target:ChatPrint("У вас повреждены почки!")
                    target.Organs["kidneys"] = math.Clamp((target.Organs["kidneys"] or 25) - damage, 0, 25)
                    target:EmitSound("ambient/water/drip" .. math.random(1, 4) .. ".wav", 60, math.random(230, 240), 0.1, CHAN_AUTO)
					if target:IsPlayer() then
					  target:SetWalkSpeed(math.max(target:GetWalkSpeed() - 30, 0))
                     target:SetRunSpeed(math.max(target:GetRunSpeed() - 30, 0))
					  target:SetNWInt("Pain", target:GetNWInt("Pain", 0) + 10)
					 end
                end

                if pancreas then
					if not IsValid(target) then return end
                    print("pancreas Hitted")
					target:ChatPrint("У вас повреждена поджелудочная железа!")
                    target.Organs["pancreas"] = math.Clamp((target.Organs["pancreas"] or 20) - damage, 0, 20)
					 target:EmitSound("ambient/water/drip" .. math.random(1, 4) .. ".wav", 60, math.random(230, 240), 0.1, CHAN_AUTO)
					if target:IsPlayer() then
					 target.stamina = math.max(target.stamina - 15, 0)
					 end
                end
				
				if artery_r_leg then
					print("Right Leg Artery Hit!")
					target:ChatPrint("Вы попали в артерию правой ноги! Началось артериальное кровотечение!")
					HandleArteryDamage(target, "artery_r_leg", damage)
				end
				
				if artery_l_leg then
					print("Left Leg Artery Hit!")
					target:ChatPrint("Вы попали в артерию левой ноги! Началось артериальное кровотечение!")
					HandleArteryDamage(target, "artery_l_leg", damage)
				end

				if artery_r_arm then
					print("Right Arm Artery Hit!")
					target:ChatPrint("Повреждена артерия правой руки! Кровотечение!")
					HandleArteryDamage(target, "artery_r_arm", damage) -- Новая функция HandleArteryDamage для обработки урона артериям
				elseif artery_l_arm then
					print("Left Arm Artery Hit!")
					target:ChatPrint("Повреждена артерия левой руки! Кровотечение!")
					HandleArteryDamage(target, "artery_l_arm", damage) -- Используем ту же функцию, но для левой руки
				elseif artery1 or artery2 then -- Обработка попаданий в "старые" артерии шеи (если вы их оставляете)
					print("Neck Artery Hit!")
					target:ChatPrint("Повреждена артерия шеи! Кровотечение!")
					HandleArteryDamage(target, "artery", damage) -- Урон по "основной" артерии (шеи)
				end
				
			
                if spleen then
					if not IsValid(target) then return end
                    print("spleen Hitted")
					 target:ChatPrint("У вас повреждена селезёнка!")
                     target.Organs["spleen"] = math.Clamp((target.Organs["spleen"] or 15) - damage, 0, 15)
                     target:EmitSound("ambient/water/drip" .. math.random(1, 4) .. ".wav", 60, math.random(230, 240), 0.1, CHAN_AUTO)
					 if target:IsPlayer() then
					  target.arterybloodlosing = math.min(target.arterybloodlosing + 20, 250)
					 end
                end
                 if rib or rib2 then
					 if not IsValid(target) then return end
					if target.Organs["ribs"] ~= 0 then
						print("ribs Hitted") 
						target:ChatPrint("Вам сломало ребра!")
                         target.Organs["ribs"] = math.Clamp((target.Organs["ribs"] or 35) - (damage or 0), 0, 35)
                         target:EmitSound("NPC_Barnacle.BreakNeck", 100, 200, 1, CHAN_ITEM)
						  if target:IsPlayer() then
						 target:SetWalkSpeed(math.max(target:GetWalkSpeed() - 15, 0))
                         target:SetRunSpeed(math.max(target:GetRunSpeed() - 15, 0))
					    end
					end
                end
            end
        end
    end
end



hook.Add("PlayerDeath", "PlayerDeathCancelTimers", function(ply, attacker, dmginfo)
	for timerName, _ in pairs(AllTimers) do
		if string.find(timerName, ply:SteamID()) then
			timer.Remove(timerName)
		end
    end
    if LiverTimers[ply:SteamID()] then LiverTimers[ply:SteamID()] = nil end
    if AortaTimers[ply:SteamID()] then AortaTimers[ply:SteamID()] = nil end
    if MouthTimers[ply:SteamID()] then MouthTimers[ply:SteamID()] = nil end
    if TraheaTimers[ply:SteamID()] then TraheaTimers[ply:SteamID()] = nil end
    if HeartTimers[ply:SteamID()] then HeartTimers[ply:SteamID()] = nil end
     if LungTimers[ply:SteamID()] then LungTimers[ply:SteamID()] = nil end
	  walkSpeeds[ply] = nil
    runSpeeds[ply] = nil
    if ply.Organs then
        for organName, _ in pairs(ply.Organs) do
            ply.Organs[organName] = Organs[organName]
        end
	 end
end)

concommand.Add("reseteffects", function(ply, cmd, args)
    if not IsValid(ply) or not ply:IsPlayer() then return end
   
    for timerName, _ in pairs(AllTimers) do
		if string.find(timerName, ply:SteamID()) then
			timer.Remove(timerName)
		end
    end
    -- Сброс переменных
    ply.Blood = 5000
	ply:SetNWInt("Blood", ply.Blood)
    ply.Bloodlosing = 0
	ply:SetNWInt("BloodLosing", 0)
    ply.arterybloodlosing = 0
	ply.stamina = 100
	ply:SetNWInt("stamina", ply.stamina)
    ply.IsBleeding = false
    ply.aorta = false
    ply.brokenspine = false
   if ply.Organs then
        for organName, _ in pairs(ply.Organs) do
            ply.Organs[organName] = Organs[organName]
        end
	 end
	ply.LeftLeg = 1
	ply.RightLeg = 1
	ply.RightArm = 1
	ply.LeftArm = 1
    ply:SetWalkSpeed(200)
    ply:SetRunSpeed(300)
	ply:SetJumpPower(190)
	
    ply:ChatPrint("Эффекты сброшены.")
end)

local util_TraceLine = util.TraceLine

function GetPhysicsBoneDamageInfo(ent,dmgInfo)
	local pos = dmgInfo:GetDamagePosition()
	local dir = dmgInfo:GetDamageForce():GetNormalized()

	dir:Mul(1024 * 8)

	local tr = {}
	tr.start = pos
	tr.endpos = pos + dir
	tr.filter = filter
	filterEnt = ent
	tr.ignoreworld = true

	local result = util_TraceLine(tr)
	if result.Entity ~= ent then
		tr.endpos = pos - dir

		return util_TraceLine(tr).PhysicsBone
	else
		return result.PhysicsBone
	end
end



local function SetLimping(ply, is_left_leg_broken, is_right_leg_broken)
    if is_left_leg_broken or is_right_leg_broken then
        ply:SetWalkSpeed(100)  -- Устанавливаем скорость ходьбы (можешь подобрать значение по своему вкусу)
        ply:SetRunSpeed(150)  -- Устанавливаем скорость бега (можешь подобрать значение по своему вкусу)
    else
        ply:SetWalkSpeed(200)  -- стандартная скорость
        ply:SetRunSpeed(300)  -- стандартная скорость
    end
end

hook.Add(
	"EntityTakeDamage",
	"ragdamage",
	function(ent, dmginfo)
		if IsValid(ent:GetPhysicsObject()) and dmginfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT + DMG_CLUB + DMG_GENERIC + DMG_BLAST) then
			ent:GetPhysicsObject():ApplyForceOffset(dmginfo:GetDamageForce() / 2, dmginfo:GetDamagePosition())
		end

		local ply = RagdollOwner(ent) or ent
		if not(ply and ply:IsPlayer()) then return end

		if not ply:Alive() or ply:HasGodMode() then
			return
		end

		local rag = ply ~= ent and ent

		if rag and dmginfo:IsDamageType(DMG_CRUSH) and att and att:IsRagdoll() then
			dmginfo:SetDamage(0)

			return true
		end

		local physics_bone = GetPhysicsBoneDamageInfo(ent, dmginfo)
		local bonename = ent:GetBoneName(ent:TranslatePhysBoneToBone(physics_bone))
		ply.LastHitBoneName = bonename

		local hitgroup
		if bonetohitgroup[bonename] then
			hitgroup = bonetohitgroup[bonename]
		end

		local mul = RagdollDamageBoneMul[hitgroup]

		if rag and mul then
			dmginfo:ScaleDamage(mul)
		end

		local entAtt = dmginfo:GetAttacker()
		local att = (entAtt:IsPlayer() and entAtt:Alive() and entAtt) or RagdollOwner(entAtt) or (entAtt:GetClass() == "wep" and entAtt:GetOwner())
		att = dmginfo:GetDamageType() ~= DMG_CRUSH and att or ply.LastAttacker

		ply.LastAttacker = att
		ply.LastHitGroup = hitgroup

		if ent.deadbody and not ent.IsBleeding and dmginfo:IsDamageType(DMG_BULLET + DMG_SLASH + DMG_BLAST + DMG_ENERGYBEAM + DMG_NEVERGIB + DMG_ALWAYSGIB + DMG_PLASMA + DMG_AIRBOAT + DMG_SNIPER + DMG_BUCKSHOT) then
			ent.IsBleeding = true
		end

		local trace = util.QuickTrace(dmginfo:GetDamagePosition(), dmginfo:GetDamageForce():GetNormalized() * 100)
		local bone = trace.PhysicsBone
		local isfall
		if bonetohitgroup[bonename] ~= nil then
			hitgroup = bonetohitgroup[bonename]
		end

		if RagdollDamageBoneMul[hitgroup] then
			if RagdollOwner(ent) then
				dmginfo:ScaleDamage(0.3)
				timer.Create("faketimer" .. RagdollOwner(ent):EntIndex(), dmginfo:GetDamage() / 30, 1, function() end)
				if hitgroup == HITGROUP_HEAD then
					if dmginfo:GetAttacker():IsRagdoll() then return end
					dmginfo:ScaleDamage(2)
					if dmginfo:GetDamageType() == 2 then
						dmginfo:ScaleDamage(2)
					end

					if dmginfo:GetDamageType() == 1 and dmginfo:GetDamage() > 6 and ent:GetVelocity():Length() > 500 then
						RagdollOwner(ent):ChatPrint("Your neck was broken")
						ent:EmitSound("NPC_Barnacle.BreakNeck", 511, 200, 1, CHAN_ITEM)
						dmginfo:ScaleDamage(1000000)
					end

					if dmginfo:GetDamageType() == 1 and dmginfo:GetDamage() > 5 and ent:GetVelocity():Length() > 220 and RagdollOwner(ent).Otrub == 0 then
						RagdollOwner(ent).pain = 270
					end
				end

				if hitgroup == HITGROUP_LEFTARM then
					if dmginfo:GetAttacker():IsRagdoll() then return end
					dmginfo:ScaleDamage(0.3)
					if dmginfo:GetDamageType() == 2 and dmginfo:GetDamage() > 10 and ply.LeftArm > 0.6 then
						if IsValid(RagdollOwner(ent)) then
							RagdollOwner(ent):ChatPrint("Your left arm was broken")
							ent:EmitSound("NPC_Barnacle.BreakNeck", 100, 200, 1, CHAN_ITEM)
						elseif ent:IsPlayer() then
							ent:ChatPrint("Your left arm was broken")
							ent:EmitSound("NPC_Barnacle.BreakNeck", 100, 200, 1, CHAN_ITEM)
						end
						ply.LeftArm = 0.6
						dmginfo:ScaleDamage(0.3)
					end

					if dmginfo:GetDamageType() == 1 and ent:GetVelocity():Length() > 600 and ply.LeftArm > 0.6 then
						if IsValid(RagdollOwner(ent)) then
							RagdollOwner(ent):ChatPrint("Your left arm was broken")
							ent:EmitSound("NPC_Barnacle.BreakNeck", 100, 200, 1, CHAN_ITEM)
						elseif ent:IsPlayer() then
							ent:ChatPrint("Your left arm was broken")
							ent:EmitSound("NPC_Barnacle.BreakNeck", 100, 200, 1, CHAN_ITEM)
						end
						ply.LeftArm = 0.6
						dmginfo:ScaleDamage(0.3)
					end
				end

				if hitgroup == HITGROUP_LEFTLEG then
					if dmginfo:GetAttacker():IsRagdoll() then return end
					dmginfo:ScaleDamage(0.3)
					if dmginfo:GetDamageType() == 2 then end
					if (dmginfo:GetDamageType() == 2 and dmginfo:GetDamage() > 15 or dmginfo:GetDamageType() == 1 and ent:GetVelocity():Length() > 600) and ply.LeftLeg > 0.6 then
						if IsValid(RagdollOwner(ent)) then
							RagdollOwner(ent):ChatPrint("Your left leg was broken")
							ent:EmitSound("NPC_Barnacle.BreakNeck", 100, 200, 1, CHAN_ITEM)
						elseif ent:IsPlayer() then
							ent:ChatPrint("Your left leg was broken")
							ent:EmitSound("NPC_Barnacle.BreakNeck", 100, 200, 1, CHAN_ITEM)
						end
						ply.LeftLeg = 0.6
						dmginfo:ScaleDamage(0.3)
					end

					if dmginfo:GetDamageType() == 1 and ent:GetVelocity():Length() > 600 and ply.LeftLeg > 0.6 then
						if IsValid(RagdollOwner(ent)) then
							RagdollOwner(ent):ChatPrint("Your left leg was broken")
							ent:EmitSound("NPC_Barnacle.BreakNeck", 100, 200, 1, CHAN_ITEM)
						elseif ent:IsPlayer() then
							ent:ChatPrint("Your left leg was broken")
							ent:EmitSound("NPC_Barnacle.BreakNeck", 100, 200, 1, CHAN_ITEM)
						end
						ply.LeftLeg = 0.6
						dmginfo:ScaleDamage(0.3)
					end
                    if ply.LeftLeg == 0.6 then
                        ply.LeftLegbroke = true
                        --SetLimping(ply, true, ply.RightLeg == 0.6)
                    end
				end

				if hitgroup == HITGROUP_RIGHTLEG then
					if dmginfo:GetAttacker():IsRagdoll() then return end
					dmginfo:ScaleDamage(0.3)
					if dmginfo:GetDamageType() == 2 and dmginfo:GetDamage() > 15 and ply.RightLeg > 0.6 then
						if IsValid(RagdollOwner(ent)) then
							RagdollOwner(ent):ChatPrint("Your right leg was broken")
							ent:EmitSound("NPC_Barnacle.BreakNeck", 100, 200, 1, CHAN_ITEM)
						elseif ent:IsPlayer() then
							ent:ChatPrint("Your right leg was broken")
							ent:EmitSound("NPC_Barnacle.BreakNeck", 100, 200, 1, CHAN_ITEM)
						end
						ply.RightLeg = 0.6
						dmginfo:ScaleDamage(0.3)
					end

					if dmginfo:GetDamageType() == 1 and ent:GetVelocity():Length() > 600 and ply.RightLeg > 0.6 then
						if IsValid(RagdollOwner(ent)) then
							RagdollOwner(ent):ChatPrint("Your right leg was broken")
							ent:EmitSound("NPC_Barnacle.BreakNeck", 100, 200, 1, CHAN_ITEM)
						elseif ent:IsPlayer() then
							ent:ChatPrint("Your right leg was broken")
							ent:EmitSound("NPC_Barnacle.BreakNeck", 100, 200, 1, CHAN_ITEM)
						end
						ply.RightLeg = 0.6
						dmginfo:ScaleDamage(0.3)
					end
                    if ply.RightLeg == 0.6 then
                        ply.RightLegbroke = true
                        --SetLimping(ply, ply.LeftLeg == 0.6, true)
                    end
				end

				if hitgroup == HITGROUP_RIGHTARM then
					if dmginfo:GetAttacker():IsRagdoll() then return end
					dmginfo:ScaleDamage(0.3)
					if dmginfo:GetDamageType() == 2 and dmginfo:GetDamage() > 10 and RagdollOwner(ent).RightArm > 0.6 then
						RagdollOwner(ent):ChatPrint("Your right hand was broken")
						ent:EmitSound("NPC_Barnacle.BreakNeck", 100, 200, 1, CHAN_ITEM)
						RagdollOwner(ent).RightArm = 0.6
						dmginfo:ScaleDamage(0.3)
					end

					if dmginfo:GetDamageType() == 1 and ent:GetVelocity():Length() > 600 and RagdollOwner(ent).RightArm > 0.6 then
						RagdollOwner(ent):ChatPrint("Your right hand was broken")
						ent:EmitSound("NPC_Barnacle.BreakNeck", 100, 200, 1, CHAN_ITEM)
						RagdollOwner(ent).RightArm = 0.6
						dmginfo:ScaleDamage(0.3)
					end
				end

				if hitgroup == HITGROUP_CHEST then
					if dmginfo:GetAttacker():IsRagdoll() then return end
					if dmginfo:GetDamageType() == 1 and ent:GetVelocity():Length() > 800 and RagdollOwner(ent).Organs["spine"] > 0 then
						RagdollOwner(ent).brokenspine = true
						RagdollOwner(ent).Organs["spine"] = 0
						RagdollOwner(ent):ChatPrint("Your spine was broken.")
						ent:EmitSound("NPC_Barnacle.BreakNeck", 511, 200, 1, CHAN_ITEM)
						dmginfo:ScaleDamage(0.3)
					end

					dmginfo:ScaleDamage(0.8)
				end

				if hitgroup == HITGROUP_STOMACH then
					if dmginfo:GetAttacker():IsRagdoll() then return end
					dmginfo:ScaleDamage(0.5)
				end
			end

			local ply
			local penetration
			if IsValid(RagdollOwner(ent)) then
				ply = RagdollOwner(ent)
			elseif ent:IsPlayer() then
				ply = ent
			end

			if dmginfo:IsDamageType(DMG_BULLET + DMG_SLASH) then
				penetration = dmginfo:GetDamageForce() * 0.008
			else
				penetration = dmginfo:GetDamageForce() * 0.004
			end

            if ent:IsPlayer() or IsValid(RagdollOwner(ent)) then
                HandleOrganDamage(ent, dmginfo)
            end
			
			local dmg = dmginfo:GetDamage()

			local dmgpos = dmginfo:GetDamagePosition()

			local matrix = ent:GetBoneMatrix(ent:LookupBone('ValveBiped.Bip01_Spine4'))
			local ang = matrix:GetAngles()
			local pos = ent:GetBonePosition(ent:LookupBone('ValveBiped.Bip01_Spine4'))
			-- up spine
			local hit_upper_spine = util.IntersectRayWithOBB(dmgpos,penetration, pos, ang, Vector(-8,-1,-1),Vector(2,0,1))
			local matrix = ent:GetBoneMatrix(ent:LookupBone('ValveBiped.Bip01_Spine1'))
			local ang = matrix:GetAngles()
			local pos = ent:GetBonePosition(ent:LookupBone('ValveBiped.Bip01_Spine1'))
			-- low spine
			local hit_lower_spine = util.IntersectRayWithOBB(dmgpos,penetration, pos, ang, Vector(-8,-3,-1),Vector(2,-2,1))
			-- lower spine
			if (hit_lower_spine) then --ply:ChatPrint("You were hit in the spine.")
				if ply.Organs['spine']!=0 then
					ply.Organs['spine']=math.Clamp(ply.Organs['spine']-dmg/10,0,1)
					if ply.Organs['spine']==0 then
						timer.Simple(0.01,function()
							if !ply.fake then
								Faking(ply)
							end
						end)
						ply.brokenspine=true 
						ply:ChatPrint("Low Spine is broken")
						ent:EmitSound("neck_snap_01",70,125,0.7,CHAN_ITEM)
					end
				end
			end
			-- upper spine
			if (hit_upper_spine) then
				if ply.upper_spine != 0 then
				ply.upper_spine=math.Clamp(ply.upper_spine-dmg/10,0,1)
				if ply.upper_spine == 0 then
						timer.Simple(0.01,function()
							if !ply.fake then
								Faking(ply)
							end
						end)
						ply.broken_uspine = true
						ply:ChatPrint("High Spine is broken")
						ent:EmitSound("neck_snap_01",70,125,0.7,CHAN_ITEM)
					end
				end
			end

			if IsValid(RagdollOwner(ent)) then
				RagdollOwner(ent).LastHit = bonename
			elseif ent:IsPlayer() then
				ent.LastHit = bonename
			end

        if IsValid(RagdollOwner(ent)) then
            if dmginfo:GetDamageType() == 1 then
                if dmginfo:GetAttacker():IsRagdoll() then
                    RagdollOwner(ent):SetHealth(RagdollOwner(ent):Health())
                else
                    RagdollOwner(ent):SetHealth(RagdollOwner(ent):Health() - dmginfo:GetDamage() / 100)
                end
            end

            RagdollOwner(ent):TakeDamageInfo(dmginfo)
            if RagdollOwner(ent):Health() <= 0 and RagdollOwner(ent):Alive() then
                RagdollOwner(ent):Kill()
            end
        end
    end
end)


concommand.Add(
	"fake",
	function(ply)
		if timer.Exists("faketimer" .. ply:EntIndex()) then return nil end
		if timer.Exists("StunTime"..ply:EntIndex()) then return nil end
		if ply:GetNWEntity("DeathRagdoll").isheld == true then return nil end
		if ply.brokenspine then return nil end
		if IsValid(ply:GetNWEntity("DeathRagdoll")) and ply:GetNWEntity("DeathRagdoll"):GetVelocity():Length() > 300 then return nil end
		if IsValid(ply:GetNWEntity("DeathRagdoll")) and table.Count(constraint.FindConstraints(ply:GetNWEntity("DeathRagdoll"), "Rope")) > 0 then return nil end
		if ply.pain > (250 * (ply.Blood / 5000)) + (ply:GetNWInt("SharpenAMT") * 5) or ply.Blood < 3000 then return end
		timer.Create("faketimer" .. ply:EntIndex(), 2, 1, function() end)
		if ply:Alive() then
			Faking(ply)
			ply.fakeragdoll = ply:GetNWEntity("DeathRagdoll")
		end
	end
)

function Stun(Entity)
	if Entity:IsPlayer() then
		Faking(Entity)
		timer.Create("StunTime"..Entity:EntIndex(), 8, 1, function() end)
		local fake = Entity:GetNWEntity("Ragdoll")
		timer.Create( "StunEffect"..Entity:EntIndex(), 0.1, 80, function()
			local rand = math.random(1,50)
			if rand == 50 then
			RagdollOwner(fake):Say("*drop")
			end
			RagdollOwner(fake).pain = RagdollOwner(fake).pain + 3
			fake:GetPhysicsObjectNum(1):SetVelocity(fake:GetPhysicsObjectNum(1):GetVelocity()+Vector(math.random(-55,55),math.random(-55,55),0))
			fake:EmitSound("ambient/energy/spark2.wav")
		end)
	elseif Entity:IsRagdoll() then
		if RagdollOwner(Entity) then
			RagdollOwner(Entity):Say("*drop")
			timer.Create("StunTime"..RagdollOwner(Entity):EntIndex(), 8, 1, function() end)
			local fake = Entity
			timer.Create( "StunEffect"..RagdollOwner(Entity):EntIndex(), 0.1, 80, function()
				if rand == 50 then
					RagdollOwner(fake):Say("*drop")
				end
				RagdollOwner(fake).pain = RagdollOwner(fake).pain + 3
				fake:GetPhysicsObjectNum(1):SetVelocity(fake:GetPhysicsObjectNum(1):GetVelocity()+Vector(math.random(-55,55),math.random(-55,55),0))
				fake:EmitSound("ambient/energy/spark2.wav")
			end)
		else
			local fake = Entity
			timer.Create( "StunEffect"..Entity:EntIndex(), 0.1, 80, function()
				fake:GetPhysicsObjectNum(1):SetVelocity(fake:GetPhysicsObjectNum(1):GetVelocity()+Vector(math.random(-55,55),math.random(-55,55),0))
				fake:EmitSound("ambient/energy/spark2.wav")
			end)
		end
	end
end

--все игроки встают после очистки карты
hook.Add(
	"PreCleanupMap",
	"cleannoobs",
	function()
		for i, v in ipairs(player.GetAll()) do
			if v.fake then
				Faking(v)
			end
		end

		BleedingEntities = {}
	end
)

--измененные функции регдола
function PlayerMeta:CreateRagdoll(attacker, dmginfo)
    if not self:Alive() and self.fake then return nil end

    -- Проверяем, есть ли уже регдолл, и очищаем его привязки
    local rag = self:GetNWEntity("Ragdoll")
    if IsValid(rag) then
        if IsValid(rag.ZacConsLH) then
            rag.ZacConsLH:Remove()
            rag.ZacConsLH = nil
        end

        if IsValid(rag.ZacConsRH) then
            rag.ZacConsRH:Remove()
            rag.ZacConsRH = nil
        end
    end

    -- Создаём новый регдолл
    local Data = duplicator.CopyEntTable(self)
    local rag = ents.Create("prop_ragdoll")
    if not IsValid(rag) then
        print("[ERROR] Не удалось создать регдолл для " .. self:GetName())
        return nil
    end

    duplicator.DoGeneric(rag, Data)
    rag:SetModel(self:GetModel())
    rag:SetColor(self:GetColor())
    rag:SetSkin(self:GetSkin())
    rag:BetterSetPlayerColor(self:GetPlayerColor())
    rag:Spawn()
    rag:Activate()
    rag:SetCollisionGroup(COLLISION_GROUP_WEAPON)

    -- Назначаем владельца регдолла
    rag:SetNWEntity("RagdollOwner", self)
    --PrintMessage(HUD_PRINTTALK, "[DEBUG] Ragdoll создан: " .. rag:EntIndex() .. " для игрока " .. self:GetName())

    -- Задаем начальную скорость регдоллу
    local vel = self:GetVelocity()
    for i = 0, rag:GetPhysicsObjectCount() - 1 do
        local physobj = rag:GetPhysicsObjectNum(i)
        local ragbonename = rag:GetBoneName(rag:TranslatePhysBoneToBone(i))
        local bone = self:LookupBone(ragbonename)

        if bone then
            local bonemat = self:GetBoneMatrix(bone)
            if bonemat then
                local bonepos = bonemat:GetTranslation()
                local boneang = bonemat:GetAngles()
                physobj:SetPos(bonepos, true)
                physobj:SetAngles(boneang)

                if not self:Alive() then
                    vel = vel / 2
                end

                physobj:AddVelocity(vel)
            end
        end
    end

    -- Добавляем перенос брони на регдолл
    local armors = {}

    if self.EZarmor and self.EZarmor.items then
        for id, info in pairs(self.EZarmor.items) do
            if not info then
                print("[ERROR] Броня с ID " .. tostring(id) .. " имеет неверные данные!")
                continue
            end

            local ent = CreateArmor(rag, info)
            if not IsValid(ent) then
                print("[ERROR] Не удалось создать броню " .. tostring(info.name) .. " на рэгдолле " .. tostring(rag))
                continue
            end

            ent.armorID = id
            ent.ragdoll = rag
            ent.Owner = self
            armors[id] = ent

            ent:CallOnRemove("Fake", Remove, self)
        end
    end

    if IsValid(self.wep) then
        self.wep.rag = rag
    end

    rag.armors = armors
    rag:CallOnRemove("Armors", RemoveRag)

    -- Привязываем регдолл к игроку
    self.fakeragdoll = rag
    self:SetNWEntity("Ragdoll", rag)

    if self:Alive() then
        self:SetNWEntity("DeathRagdoll", rag)
    else
        self:SetNWEntity("DeathRagdoll", rag)
        self.curweapon = self:GetActiveWeapon():GetClass()
        local guninfo = weapons.Get(self.curweapon)
        if guninfo and guninfo.Base == "salat_base" then
            SpawnWeapon(self)
        end

        self:Spectate(OBS_MODE_ROAMING)
        self:SetMoveType(MOVETYPE_OBSERVER)
        rag:SetEyeTarget(vector_origin)

        if self.IsBleeding then
            rag.IsBleeding = true
        end

        rag.deadbody = true
    end

    return rag
end


--проверка на скорость в фейке (для сбивания с ног других игроков)
hook.Add(
	"Think",
	"VelocityFakeHitPlyCheck",
	function()
		for i, rag in pairs(ents.FindByClass("prop_ragdoll")) do
			local ply = RagdollOwner(rag)
			if IsValid(ply) or rag.deadbody then
				if rag:GetVelocity():Length() > 165 then
					rag:SetCollisionGroup(COLLISION_GROUP_NONE)
					local trace = {
						start = rag:GetPos(),
						endpos = rag:GetPos() + rag:GetVelocity() / 4,
						filter = rag
					}

					local tr = util.TraceLine(trace)
					if tr.Entity == NULL or tr.Entity == rag or tr.Entity == Entity(0) then return nil end
					if tr.Entity:IsPlayer() and tr.Entity ~= RagdollOwner(rag) and tr.Entity.fake == false then
						Faking(tr.Entity)
					end
				else
					rag:SetCollisionGroup(COLLISION_GROUP_WEAPON)
				end
			end
		end
	end
)

--проверка на скорость в фейке (для сбивания с ног других игроков)
hook.Add(
	"Think",
	"VelocityFakeHitPlyCheck",
	function()
		for i, rag in pairs(ents.FindByClass("prop_ragdoll")) do
			if IsValid(rag) then
				if rag:GetVelocity():Length() > 130 then
					rag:SetCollisionGroup(COLLISION_GROUP_NONE)
				else
					rag:SetCollisionGroup(COLLISION_GROUP_WEAPON)
				end
			end
		end
	end
)

hook.Add(
	"PlayerInitialSpawn",
	"homigrad-addcallback",
	function(ply)
		ply:AddCallback(
			"PhysicsCollide",
			function(phys, data)
				hook.Run("Player Collide", ply, data.HitEntity, data)
			end
		)
	end
)

local gg = CreateConVar("hg_oldcollidefake", "0")
hook.Add(
	"Player Collide",
	"homigrad-fake",
	function(ply, hitEnt, data)
		--if not ply:HasGodMode() and data.Speed >= 250 / hitEnt:GetPhysicsObject():GetMass() * 20 and not ply.fake and not hitEnt:IsPlayerHolding() and hitEnt:GetVelocity():Length() > 80 then
		if (not ply:HasGodMode() and data.Speed > 250) or (not gg:GetBool() and not ply:HasGodMode() and data.Speed >= 250 / hitEnt:GetPhysicsObject():GetMass() * 20 and not ply.fake and not hitEnt:IsPlayerHolding() and hitEnt:GetVelocity():Length() > 250) then
			timer.Simple(
				0,
				function()
					if not IsValid(ply) or ply.fake then return end
					if hook.Run("Should Fake Collide", ply, hitEnt, data) == false then return end
					Faking(ply)
				end
			)
		end
	end
)

--управление в фейке
local dvec = Vector(0, 0, -64)
hook.Add(
	"Think",
	"FakeControl",
	function()
		for i, ply in ipairs(player.GetAll()) do
			ply.holdingartery = false
			local rag = ply:GetNWEntity("DeathRagdoll")
			if IsValid(rag) then
				ply:SetNWBool("fake", ply.fake)
				local deltatime = CurTime() - (rag.ZacLastCallTime or CurTime())
				rag.ZacLastCallTime = CurTime()
				local eyeangs = ply:EyeAngles()
				local head = rag:GetPhysicsObjectNum(10)
				rag:SetFlexWeight(9, 0)
				local dist = (rag:GetAttachment(rag:LookupAttachment("eyes")).Ang:Forward() * 10000):Distance(ply:GetAimVector() * 10000)
				local distmod = math.Clamp(1 - (dist / 20000), 0.1, 1)
				local lookat = LerpVector(distmod, rag:GetAttachment(rag:LookupAttachment("eyes")).Ang:Forward() * 100000, ply:GetAimVector() * 100000)
				local attachment = rag:GetAttachment(rag:LookupAttachment("eyes"))
				local LocalPos, LocalAng = WorldToLocal(lookat, angle_zero, attachment.Pos, attachment.Ang)
				local bone = rag:LookupBone("ValveBiped.Bip01_Head1")
				local head1 = rag:GetBonePosition(bone) + dvec
				ply:SetPos(head1)
				if not RagdollOwner(rag).Otrub then
					rag:SetEyeTarget(LocalPos)
				else
					rag:SetEyeTarget(vector_origin)
				end

				if RagdollOwner(rag):Alive() then
					if not RagdollOwner(rag).Otrub then
						if ply:KeyPressed(IN_JUMP) and table.Count(constraint.FindConstraints(ply:GetNWEntity("DeathRagdoll"), "Rope")) > 0 and ply.stamina > 45 then
							local RopeCount = table.Count(constraint.FindConstraints(ply:GetNWEntity("DeathRagdoll"), "Rope"))
							Ropes = constraint.FindConstraints(ply:GetNWEntity("DeathRagdoll"), "Rope")
							Try = math.random(1, 10 * RopeCount)
							ply.stamina = ply.stamina - 4 * (RopeCount / 6)
							local phys = rag:GetPhysicsObjectNum(1)
							local speed = 200
							local shadowparams = {
								secondstoarrive = 0.05,
								pos = phys:GetPos() + phys:GetAngles():Forward() * 20,
								angle = phys:GetAngles(),
								maxangulardamp = 30,
								maxspeeddamp = 30,
								maxangular = 90,
								maxspeed = speed,
								teleportdistance = 0,
								deltatime = 0.01,
							}

							phys:Wake()
							phys:ComputeShadowControl(shadowparams)
							if Try > (7 * RopeCount) then
								if RopeCount > 1 then
									ply:ChatPrint("There are ropes left: " .. RopeCount - 1)
								else
									ply:ChatPrint("You're unleashed")
								end

								Ropes[1].Constraint:Remove()
								rag:EmitSound("snd_jack_hmcd_ducttape.wav", 90, 50, 0.5, CHAN_AUTO)
							end
						end

						if ply:KeyPressed(IN_RELOAD) then
							Reload(ply.wep)
						end

						if ply:KeyDown(IN_ATTACK) then
							if not ply.FakeShooting and not ply.arterybleeding then
								local phys = rag:GetPhysicsObjectNum(5)
								local ang = ply:EyeAngles()
								local shadowparams = {
									secondstoarrive = 0.3,
									pos = head:GetPos() + eyeangs:Forward() * (180 / math.Clamp(rag:GetVelocity():Length() / 300, 1, 6)),
									angle = ang,
									maxangulardamp = 600,
									maxspeeddamp = 50,
									maxspeed = 120,
									teleportdistance = 0,
									deltatime = deltatime,
								}

								phys:Wake()
								phys:ComputeShadowControl(shadowparams)
							end
						end

						local guninfo = weapons.Get(ply.curweapon)
						if guninfo and guninfo.Primary.Automatic then
							--KeyDown if an automatic gun
							if ply:KeyDown(IN_ATTACK) then
								if ply.FakeShooting then
									FireShot(ply.wep)
								end
							end
						else
							if ply:KeyPressed(IN_ATTACK) then
								if ply.FakeShooting then
									FireShot(ply.wep)
								end
							end
						end

						if ply:KeyDown(IN_ATTACK2) then
							local physa = rag:GetPhysicsObjectNum(7)
							local phys = rag:GetPhysicsObjectNum(5) --rhand
							local ang = ply:EyeAngles() --LerpAngle(0.5,ply:EyeAngles(),ply:GetNWEntity("DeathRagdoll"):GetAttachment(1).Ang)
							if ply.FakeShooting then
								ang:RotateAroundAxis(eyeangs:Forward(), 180)
							end

							local shadowparams = {
								secondstoarrive = 0.3,
								pos = head:GetPos() + eyeangs:Forward() * (180 / math.Clamp(rag:GetVelocity():Length() / 300, 1, 6)),
								angle = ang,
								maxangular = 670,
								maxangulardamp = 600,
								maxspeeddamp = 50,
								maxspeed = 120,
								teleportdistance = 0,
								deltatime = deltatime,
							}

							physa:Wake()
							if not ply.suiciding or (guninfo and guninfo.TwoHands) then
								if guninfo and guninfo.TwoHands and IsValid(ply.wep) then
									shadowparams.angle:RotateAroundAxis(eyeangs:Up(), 45)
									shadowparams.pos = shadowparams.pos + eyeangs:Right() * 40
									shadowparams.pos = shadowparams.pos + eyeangs:Up() * 40
									shadowparams.angle:RotateAroundAxis(eyeangs:Forward(), -90)
									ply.wep:GetPhysicsObject():ComputeShadowControl(shadowparams)
									--shadowparams.maxspeed=20
									phys:ComputeShadowControl(shadowparams) --if 2handed
									shadowparams.pos = rag:GetPhysicsObjectNum(0):GetPos()
									shadowparams.angle = ang
									ply.wep:GetPhysicsObject():ComputeShadowControl(shadowparams)
								else
									physa:ComputeShadowControl(shadowparams)
								end
							else
								if ply.FakeShooting and IsValid(ply.wep) then
									shadowparams.maxspeed = 500
									shadowparams.maxangular = 500
									shadowparams.pos = head:GetPos() - ply.wep:GetAngles():Forward() * 12
									ply.wep:GetAngles():Right()
								elseif 5 then
									shadowparams.angle = ply.wep:GetPhysicsObject():GetAngles()
									ply.wep:GetPhysicsObject():ComputeShadowControl(shadowparams)
									physa:ComputeShadowControl(shadowparams)
								end
							end
							--[[physa:ComputeShadowControl(shadowparams)
			if TwoHandedOrNo[ply.curweapon] then
				shadowparams.maxspeed=90
				ply.wep:GetPhysicsObject():ComputeShadowControl(shadowparams)
				shadowparams.maxspeed=20
				shadowparams.angle:RotateAroundAxis(eyeangs:Forward(),90)
				phys:ComputeShadowControl(shadowparams) --if 2handed
			end--]]
						end

						if ply:KeyDown(IN_USE) then
							local phys = head
							local angs = ply:EyeAngles()
							angs:RotateAroundAxis(angs:Forward(), 90)
							angs:RotateAroundAxis(angs:Up(), 90)
							local shadowparams = {
								secondstoarrive = 0.5,
								pos = head:GetPos() + vector_up * 20,
								angle = angs,
								maxangulardamp = 10,
								maxspeeddamp = 10,
								maxangular = 370,
								maxspeed = 40,
								teleportdistance = 0,
								deltatime = deltatime,
							}

							head:Wake()
							head:ComputeShadowControl(shadowparams)
						end
					end

					if ply:KeyDown(IN_SPEED) and ply.stamina > 45 and not RagdollOwner(rag).Otrub then
						local bone = 5
						local phys = rag:GetPhysicsObjectNum(bone)
						if ply.arterybleeding and not TwoHandedOrNo[ply.curweapon] then
							local shadowparams = {
								secondstoarrive = 0.5,
								pos = head:GetPos(),
								angle = angs,
								maxangulardamp = 10,
								maxspeeddamp = 10,
								maxangular = 370,
								maxspeed = 1120,
								teleportdistance = 0,
								deltatime = deltatime,
							}

							phys:Wake()
							phys:ComputeShadowControl(shadowparams)
							ply.holdingartery = true
							if IsValid(rag.ZacConsLH) then
								rag.ZacConsLH:Remove()
								rag.ZacConsLH = nil
							end
						end

						if not IsValid(rag.ZacConsLH) and (not rag.ZacNextGrLH or rag.ZacNextGrLH <= CurTime()) then
							rag.ZacNextGrLH = CurTime() + 0.1
							for i = 1, 2 do
								local offset = phys:GetAngles():Up() * -5
								if i == 2 then
									offset = phys:GetAngles():Right() * 5
								end

								local traceinfo = {
									start = phys:GetPos(),
									endpos = phys:GetPos() + offset,
									filter = rag,
									output = trace,
								}

								local trace = util.TraceLine(traceinfo)
								if trace.Hit and not trace.HitSky then
									local cons = constraint.Weld(rag, trace.Entity, bone, trace.PhysicsBone, 0, false, false)
									if IsValid(cons) then
										rag.ZacConsLH = cons
									end

									break
								end
							end
						end
					else
						if ply.arterybleeding then
							ply.holdingartery = false
						end

						if IsValid(rag.ZacConsLH) then
							rag.ZacConsLH:Remove()
							rag.ZacConsLH = nil
						end
					end

					if ply:KeyDown(IN_WALK) and ply.stamina > 45 and not RagdollOwner(rag).Otrub then
						local bone = 7
						local phys = rag:GetPhysicsObjectNum(bone)
						if not IsValid(rag.ZacConsRH) and (not rag.ZacNextGrRH or rag.ZacNextGrRH <= CurTime()) then
							rag.ZacNextGrRH = CurTime() + 0.1
							for i = 1, 2 do
								local offset = phys:GetAngles():Up() * 5
								if i == 2 then
									offset = phys:GetAngles():Right() * 5
								end

								local traceinfo = {
									start = phys:GetPos(),
									endpos = phys:GetPos() + offset,
									filter = rag,
									output = trace,
								}

								local trace = util.TraceLine(traceinfo)
								if trace.Hit and not trace.HitSky then
									local cons = constraint.Weld(rag, trace.Entity, bone, trace.PhysicsBone, 0, false, false)
									if IsValid(cons) then
										rag.ZacConsRH = cons
									end

									break
								end
							end
						end
					else
						if IsValid(rag.ZacConsRH) then
							rag.ZacConsRH:Remove()
							rag.ZacConsRH = nil
						end
					end

					if ply:KeyDown(IN_FORWARD) and IsValid(rag.ZacConsLH) then
						local phys = rag:GetPhysicsObjectNum(1)
						local lh = rag:GetPhysicsObjectNum(5)
						local angs = ply:EyeAngles()
						angs:RotateAroundAxis(angs:Forward(), 90)
						angs:RotateAroundAxis(angs:Up(), 90)
						local speed = 250
						ply.stamina = ply.stamina - 0.02
						if rag.ZacConsLH.Ent2:GetVelocity():LengthSqr() < 1000 then
							local shadowparams = {
								secondstoarrive = 0.5,
								pos = lh:GetPos(),
								angle = phys:GetAngles(),
								maxangulardamp = 10,
								maxspeeddamp = 10,
								maxangular = 50,
								maxspeed = speed,
								teleportdistance = 0,
								deltatime = deltatime,
							}

							phys:Wake()
							phys:ComputeShadowControl(shadowparams)
							--[[
				shadowparams.pos=phys:GetPos()+ply:EyeAngles():Right()*-300
				rag:GetPhysicsObjectNum( 11 ):Wake()
				rag:GetPhysicsObjectNum( 11 ):ComputeShadowControl(shadowparams)				-переделывай говно
				shadowparams.pos=phys:GetPos()-ply:EyeAngles():Forward()*300
				rag:GetPhysicsObjectNum( 9 ):Wake()
				rag:GetPhysicsObjectNum( 9 ):ComputeShadowControl(shadowparams)
				shadowparams.pos=lh:GetPos()
				--]]
							local angre = ply:EyeAngles()
							angre:RotateAroundAxis(ply:EyeAngles():Forward(), -90)
							shadowparams.angle = angre
							shadowparams.maxangular = 100
							shadowparams.pos = rag:GetPhysicsObjectNum(1):GetPos()
							shadowparams.secondstoarrive = 1
							rag:GetPhysicsObjectNum(0):Wake()
							rag:GetPhysicsObjectNum(0):ComputeShadowControl(shadowparams)
						end
					end

					if ply:KeyDown(IN_FORWARD) and IsValid(rag.ZacConsRH) then
						local phys = rag:GetPhysicsObjectNum(1)
						local rh = rag:GetPhysicsObjectNum(7)
						local angs = ply:EyeAngles()
						angs:RotateAroundAxis(angs:Forward(), 90)
						angs:RotateAroundAxis(angs:Up(), 100)
						local speed = 250
						ply.stamina = ply.stamina - 0.02
						if rag.ZacConsRH.Ent2:GetVelocity():LengthSqr() < 1000 then
							local shadowparams = {
								secondstoarrive = 0.3,
								pos = rh:GetPos(),
								angle = phys:GetAngles(),
								maxangulardamp = 10,
								maxspeeddamp = 10,
								maxangular = 50,
								maxspeed = speed,
								teleportdistance = 0,
								deltatime = deltatime,
							}

							phys:Wake()
							phys:ComputeShadowControl(shadowparams)
							--[[
				shadowparams.pos=phys:GetPos()+ply:EyeAngles():Right()*300
				rag:GetPhysicsObjectNum( 9 ):Wake()
				rag:GetPhysicsObjectNum( 9 ):ComputeShadowControl(shadowparams)				-переделывай говно
				shadowparams.pos=phys:GetPos()-ply:EyeAngles():Forward()*300
				rag:GetPhysicsObjectNum( 11 ):Wake()
				rag:GetPhysicsObjectNum( 11 ):ComputeShadowControl(shadowparams)
				shadowparams.pos=rh:GetPos()
				--]]
							local angre2 = ply:EyeAngles()
							angre2:RotateAroundAxis(ply:EyeAngles():Forward(), 90)
							shadowparams.angle = angre2
							shadowparams.maxangular = 100
							shadowparams.pos = rag:GetPhysicsObjectNum(1):GetPos()
							shadowparams.secondstoarrive = 1
							rag:GetPhysicsObjectNum(0):Wake()
							rag:GetPhysicsObjectNum(0):ComputeShadowControl(shadowparams)
						end
					end

					if ply:KeyDown(IN_BACK) and IsValid(rag.ZacConsLH) then
						local phys = rag:GetPhysicsObjectNum(1)
						local chst = rag:GetPhysicsObjectNum(0)
						local angs = ply:EyeAngles()
						angs:RotateAroundAxis(angs:Forward(), 90)
						angs:RotateAroundAxis(angs:Up(), 90)
						local speed = 200
						ply.stamina = ply.stamina - 0.02
						if rag.ZacConsLH.Ent2:GetVelocity():LengthSqr() < 1000 then
							local shadowparams = {
								secondstoarrive = 0.3,
								pos = chst:GetPos(),
								angle = phys:GetAngles(),
								maxangulardamp = 10,
								maxspeeddamp = 10,
								maxangular = 50,
								maxspeed = speed,
								teleportdistance = 0,
								deltatime = deltatime,
							}

							phys:Wake()
							phys:ComputeShadowControl(shadowparams)
						end
					end

					if ply:KeyDown(IN_BACK) and IsValid(rag.ZacConsRH) then
						local phys = rag:GetPhysicsObjectNum(1)
						local chst = rag:GetPhysicsObjectNum(0)
						local angs = ply:EyeAngles()
						angs:RotateAroundAxis(angs:Forward(), 90)
						angs:RotateAroundAxis(angs:Up(), 90)
						local speed = 200
						ply.stamina = ply.stamina - 0.02
						if rag.ZacConsRH.Ent2:GetVelocity():LengthSqr() < 1000 then
							local shadowparams = {
								secondstoarrive = 0.3,
								pos = chst:GetPos(),
								angle = phys:GetAngles(),
								maxangulardamp = 10,
								maxspeeddamp = 10,
								maxangular = 50,
								maxspeed = speed,
								teleportdistance = 0,
								deltatime = deltatime,
							}

							phys:Wake()
							phys:ComputeShadowControl(shadowparams)
						end
					end
				end
			end
		end
	end
)

hook.Add(
	"Think",
	"VelocityPlayerFallOnPlayerCheck",
	function()
		for _, ply in ipairs(player.GetAll()) do
			if ply:GetVelocity():Length() > 400 and ply:Alive() and not ply.fake and not ply:HasGodMode() and ply:GetMoveType() ~= MOVETYPE_NOCLIP then
				Faking(ply)
			end
		end
	end
)

physenv.SetPerformanceSettings(
	{
		MaxVelocity = 99999
	}
)

physenv.SetAirDensity(2)
hook.Add(
	"EntityTakeDamage",
	"LastAttacker",
	function(ent, dmginfo)
		local attacker = dmginfo:GetAttacker()
		local ply = RagdollOwner(ent)
		if ent:IsPlayer() and attacker:IsPlayer() then
			ent.Attacker = attacker:Nick()
			ent.AttackerEnt = attacker
		elseif IsValid(ply) and attacker:IsPlayer() then
			ply.Attacker = attacker:Nick()
			ply.AttackerEnt = attacker
		elseif IsValid(ply) and attacker == ply.wep then
			-- сделать по-другому (тут только если ты себя убиваешь)
			ply.Attacker = ply:Nick()
			ply.AttackerEnt = attacker
		end
	end
)

concommand.Add(
	"suicide",
	function(ply)
		if not ply:Alive() then return nil end
		ply.suiciding = not ply.suiciding
	end
)

hook.Add(
	"PlayerSwitchWeapon",
	"fakewep",
	function(ply, oldwep, newwep)
		if ply.Otrub then return true end
		if ply.fake then
			if IsValid(ply.Info.ActiveWeapon2) and IsValid(ply.wep) then
				ply.Info.ActiveWeapon2:SetClip1(ply.wep.Clip)
				ply:SetAmmo(ply.wep.Amt, ply.wep.AmmoType)
			end

			local guninfo = weapons.Get(newwep:GetClass())
			if guninfo.Base == "salat_base" then
				if IsValid(ply.wep) then
					DespawnWeapon(ply)
				end

				ply:SetActiveWeapon(newwep)
				ply.Info.ActiveWeapon = newwep
				ply.curweapon = newwep
				SavePlyInfo(ply)
				ply:SetActiveWeapon(nil)
				SpawnWeapon(ply)
				ply.FakeShooting = true
			else
				if IsValid(ply.wep) then
					DespawnWeapon(ply)
				end

				ply:SetActiveWeapon(nil)
				ply.curweapon = newwep
				ply.FakeShooting = false
			end

			return true
		end
	end
)

function PlayerMeta:HuySpectate()
	local ply = self
	ply:Spectate(OBS_MODE_ROAMING)
	ply:UnSpectate()
	ply:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
	ply:SetMoveType(MOVETYPE_OBSERVER)
end

OrgansNextThink = 0
InternalBleeding = 10
hook.Add(
	"Think",
	"InternalBleeding",
	function()
		for i, ply in ipairs(player.GetAll()) do
			ply.OrgansNextThink = ply.OrgansNextThink or OrgansNextThink
			if not (ply.OrgansNextThink > CurTime()) then
				ply.OrgansNextThink = CurTime() + 0.2
				--print(ply) PrintTable(ply.Organs)
				if ply.Organs and ply:Alive() then
					if ply.Organs["brain"] == 0 then
						ply:Kill()
					end

					if ply.Organs["liver"] == 0 then
						ply.InternalBleeding = ply.InternalBleeding or InternalBleeding
						ply.InternalBleeding = math.Clamp(ply.InternalBleeding - 0.1, 0, 10)
						--print(ply.InternalBleeding, ply.Blood)
						ply.Blood = ply.Blood - ply.InternalBleeding
					end

					if ply.Organs["stomach"] == 0 then
						ply.InternalBleeding2 = ply.InternalBleeding2 or InternalBleeding
						ply.InternalBleeding2 = math.Clamp(ply.InternalBleeding2 - 0.1, 0, 10)
						--print(ply.InternalBleeding, ply.Blood)
						ply.Blood = ply.Blood - ply.InternalBleeding2
					end

					if ply.Organs["intestines"] == 0 then
						ply.InternalBleeding3 = ply.InternalBleeding3 or InternalBleeding
						ply.InternalBleeding3 = math.Clamp(ply.InternalBleeding3 - 0.1, 0, 10)
						--print(ply.InternalBleeding, ply.Blood)
						ply.Blood = ply.Blood - ply.InternalBleeding3
					end

					if ply.Organs["heart"] == 0 then
						ply.InternalBleeding4 = ply.InternalBleeding4 or InternalBleeding
						--print(ply.InternalBleeding4)
						ply.InternalBleeding4 = math.Clamp(ply.InternalBleeding4 * 10 - 0.1, 0, 10)
						--print(ply.InternalBleeding, ply.Blood)
						ply.Blood = ply.Blood - ply.InternalBleeding4 * 3
					end

					if ply.Organs["lungs"] == 0 then
						ply.InternalBleeding5 = ply.InternalBleeding5 or InternalBleeding
						ply.InternalBleeding5 = math.Clamp(ply.InternalBleeding5 - 0.1, 0, 10)
						--print(ply.InternalBleeding, ply.Blood)
						ply.Blood = ply.Blood - ply.InternalBleeding5
					end

					if ply.Organs["spine"] == 0 then
						ply.brokenspine = true
						if not ply.fake then
							Faking(ply)
						end
					end

					if ply.Organs["artery"] == 0 then
						ply.arterybleeding = true
					else
						ply.arterybleeding = false
					end

					--print(ply.Blood)
					if ply.Blood and ply.Blood <= 2000 and ply:Alive() or ply.pain and ply.pain > 950 and ply:Alive() then
						ply:ExitVehicle()
						ply:Kill()
						ply.Bloodlosing = 0
						ply:SetNWInt("BloodLosing", 0)
					end
				end
			end
		end
	end
)

hook.Add(
	"PlayerUse",
	"nouseinfake",
	function(ply)
		if ply.fake then return false end
	end
)

hook.Add(
	"PlayerSay",
	"dropweaponhuy",
	function(ply, text)
		if string.lower(text) == "*drop" then
			if not ply.fake then
				ply:DropWeapon()

				return ""
			else
				if IsValid(ply.wep) then
					if IsValid(ply.WepCons) then
						ply.WepCons:Remove()
						ply.WepCons = nil
					end

					if IsValid(ply.WepCons2) then
						ply.WepCons2:Remove()
						ply.WepCons2 = nil
					end

					ply.wep.canpickup = true
					ply.wep:SetOwner()
					ply.wep.curweapon = ply.curweapon
					ply.Info.Weapons[ply.Info.ActiveWeapon].Clip1 = ply.wep.Clip
					ply:StripWeapon(ply.Info.ActiveWeapon)
					ply.Info.Weapons[ply.Info.ActiveWeapon] = nil
					ply.wep = nil
					ply.Info.ActiveWeapon = nil
					ply.Info.ActiveWeapon2 = nil
					ply:SetActiveWeapon(nil)
					ply.FakeShooting = false
				else
					ply:PickupEnt()
				end

				return ""
			end
		end
	end
)



hook.Add("Think","ZenFix1", function ()
	for k, ply in pairs( player.GetAll() ) do
		util.AddNetworkString("ZenFix1")
		net.Start("ZenFix1")
			local bool = ply:GetNWBool("fake")
			net.WriteBool(bool)
			net.Send(ply)
	end
end)
