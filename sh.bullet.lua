-- Константы для настройки
local MAX_BOUNCES = 5
local BASE_BULLET_SPEED = 1000

-- Таблица "твердости" поверхностей
SIB_SurfaceHardness = {
    [MAT_METAL] = 0.95, [MAT_COMPUTER] = 0.95, [MAT_VENT] = 0.95, [MAT_GRATE] = 0.95, [MAT_FLESH] = 0.1, [MAT_ALIENFLESH] = 0.05,
    [MAT_SAND] = 0.01, [MAT_DIRT] = 0.05, [74] = 0.01, [85] = 0.02, [MAT_WOOD] = 0.3, [MAT_FOLIAGE] = 0.01,
    [MAT_CONCRETE] = 0.8, [MAT_TILE] = 0.7, [MAT_SLOSH] = 0.001, [MAT_PLASTIC] = 0.2, [MAT_GLASS] = 0.4
}

if SERVER then
    CreateConVar("sib_dev_tracers", "0", FCVAR_ARCHIVE, "Включить dev-трассеры пуль")
    concommand.Add("sib_toggle_dev_tracers", function(ply, cmd, args)
        local convar = GetConVar("sib_dev_tracers")
        convar:SetInt(1 - convar:GetInt())
        MsgN("Dev tracers: " .. (convar:GetInt() == 1 and "ON" or "OFF"))
    end)
end

-- Теперь BulletCallbackFunc принимает tracerColor и bounces
function SWEP:BulletCallbackFunc(dmgAmt, ply, tr, dmg, tracer, hard, multi, tracerColor, bounces, bulletSpeed)
	if SERVER then
		if tr.MatType == MAT_FLESH then
			util.Decal("Impact.Flesh", tr.HitPos + tr.HitNormal, tr.HitPos - tr.HitNormal)
				   local effectdata = EffectData()
				   effectdata:SetOrigin(tr.HitPos)
				   effectdata:SetRadius(5)
				   net.Start("sib_draw_flesh_decal")
					   net.WriteVector(tr.HitPos + tr.HitNormal)
					   net.WriteVector(tr.HitPos - tr.HitNormal)
				   net.Broadcast()
		   end
	end

    if (self.NumBullet or 1) > 1 then return end
    if tr.HitSky then return end

    bulletSpeed = bulletSpeed or BASE_BULLET_SPEED

    if hard then self:RicochetOrPenetrate(tr, tracerColor, bounces, bulletSpeed) end
end

function SWEP:RicochetOrPenetrate(initialTrace, tracerColor, bounces, bulletSpeed)
    if bounces >= MAX_BOUNCES then
        return
    end

    local AVec, IPos, TNorm, SMul = initialTrace.Normal, initialTrace.HitPos, initialTrace.HitNormal, SIB_SurfaceHardness[initialTrace.MatType]
    if not(SMul)then SMul=.5 end

    local ApproachAngle = -math.deg(math.asin(TNorm:DotProduct(AVec)))
    local MaxRicAngle = 60 * SMul

    local RicochetChance = 0
    if initialTrace.MatType == MAT_METAL or initialTrace.MatType == MAT_CONCRETE then
        RicochetChance = SMul * (1 - ApproachAngle / 90) * (bulletSpeed / BASE_BULLET_SPEED)
    elseif initialTrace.MatType == MAT_WOOD then
        RicochetChance = SMul * (1 - ApproachAngle / 90) * 0.5
    else
        RicochetChance = 0
    end

    if ApproachAngle > (MaxRicAngle * 1.25) or math.random() > RicochetChance then
		local MaxDist,SearchPos,SearchDist,Penetrated=(self.Primary.Damage/SMul)*.25,IPos,5,false
		while((not(Penetrated))and(SearchDist<MaxDist))do
			SearchPos=IPos+AVec*SearchDist
			local PeneTrace=util.QuickTrace(SearchPos,-AVec*SearchDist)
			if((not(PeneTrace.StartSolid))and(PeneTrace.Hit))then
				Penetrated=true
			else
				SearchDist=SearchDist+5
			end
		if(Penetrated)then
             if CLIENT and GetConVar("sib_dev_tracers"):GetBool() then
                  debugoverlay.Line(IPos, SearchPos, 2, Color(0, 255, 0), true, 10)
                debugoverlay.Cross(SearchPos, 2, 2, Color(255, 255, 0), true, 10)
             end
			local DamageLoss = 0.35 + ApproachAngle / 180
       		local NewDamage = self.Primary.Damage * (1 - DamageLoss)
        	local NewForce = self.Primary.Force * 0.2 * (1 - bounces * 0.1)
			self:FireBullets({
				Attacker=self.Owner,
				Damage=NewDamage,
				Force=NewForce,
				Num=1,
				Tracer=1,
				TracerName="Tracer",
				Dir=AVec,
				Spread=Vector(0,0,0),
				Src=SearchPos+AVec,
				Callback = function(ply, tr, dmgInfo)
					local newBounces = bounces + 1
					ply:GetActiveWeapon():BulletCallbackFunc(self.Primary.Damage,ply,tr,self.Primary.Damage,false,true,false,tracerColor, newBounces, bulletSpeed)
				end
			})
		end
	end
    else
        sound.Play("snd_jack_hmcd_ricochet_"..math.random(1,2)..".wav",IPos,70,math.random(90,100))
        local reflectAngle = (AVec - 2 * AVec:Dot(TNorm) * TNorm):GetNormalized()

		if CLIENT and GetConVar("sib_dev_tracers"):GetBool() then
            debugoverlay.Line(IPos, IPos + reflectAngle * 30, 2, Color(0, 0, 255), true, 10)
            debugoverlay.Cross(IPos, 2, 2, Color(255, 0, 255), true, 10)
        end

        local DamageLoss = 0.5 + ApproachAngle / 180 + bounces * 0.1
        local NewDamage = self.Primary.Damage * (1 - DamageLoss)
        local NewForce = self.Primary.Force * 0.2 * (1 - bounces * 0.1)

        local NewBulletSpeed = bulletSpeed * (1 - DamageLoss)

        RicochetChance = RicochetChance * (1 - bounces * 0.2)
        if math.random() > RicochetChance then
            return
        end
		
		local NewTracerColor = tracerColor
		if bounces == 1 then
			NewTracerColor = Color(255, 128, 0)
		elseif bounces == 2 then
			NewTracerColor = Color(255, 255, 0)
		elseif bounces >= 3 then
			NewTracerColor = Color(128, 128, 128)
		end

        self:FireBullets({
			Attacker=self.Owner,
			Damage=NewDamage,
			Force=NewForce,
			Num=1,
			Tracer=1,
			TracerName="Tracer",
			Dir=reflectAngle,
			Spread=Vector(0,0,0),
			Src=IPos+TNorm,
			Callback = function(ply, tr, dmgInfo)
				local newBounces = bounces + 1
				ply:GetActiveWeapon():BulletCallbackFunc(self.Primary.Damage,ply,tr,self.Primary.Damage,false,true,false,NewTracerColor, newBounces, NewBulletSpeed)
			end
		})
    end
end

local vec = Vector(0,0,0)
local vecZero = Vector(0,0,0)
local angZero = Angle(0,0,0)

function SWEP:FireBullet(dmg, numbul, spread)
	if self:Clip1() <= 0 or timer.Exists("reload"..self:EntIndex())  then return end
	
	local ply = self:GetOwner()

	ply:LagCompensation(true)

	local obj = self:LookupAttachment("muzzle")
	local Attachment = self.Owner:GetActiveWeapon():GetAttachment(obj)

	local cone = self.Primary.Cone

	local shootOrigin = Attachment.Pos
	local vec = vecZero
	vec:Set(self.addPos)
	vec:Rotate(Attachment.Ang)
	shootOrigin:Add(vec)

	local shootAngles = Attachment.Ang
	local ang = angZero
	ang:Set(self.addAng)
	shootAngles:Add(ang)

	local shootDir = shootAngles:Forward()

	local npc = ply:IsNPC() and ply:GetShootPos() or shootOrigin
	local npcdir = ply:IsNPC() and ply:GetAimVector() or shootDir
	local bullet = {}
	bullet.Num 			= self.NumBullet or 1
	bullet.Src 			= npc
	bullet.Dir 			= npcdir
	bullet.Spread 		= Vector(cone,cone,0)
	bullet.Force		= self.Primary.Force / 5
	bullet.Damage		= self.Primary.Damage
	bullet.AmmoType     = self.Primary.Ammo
	bullet.Attacker 	= self.Owner
	bullet.Tracer       = 1 -- ВАЖНО: Убедитесь, что Tracer установлен в 1, чтобы трассер отрисовывался!
	bullet.TracerName   = self.Tracer or "Tracer"
	bullet.IgnoreEntity = not self.Owner:IsNPC() and self.Owner:GetVehicle() or self.Owner
	--Вычисляем цвет трассера здесь, при создании пули
	local initialTracerColor = Color(255, 0, 0)  --Красный цвет по умолчанию, при необходимости можно изменить
	local initialBulletSpeed = BASE_BULLET_SPEED
	bullet.Callback = function(ply,tr,dmgInfo)
		--Передаем tracerColor и начинаем отсчет bounces
		--Изначально bounces=0 и tracerColor - красный
		ply:GetActiveWeapon():BulletCallbackFunc(self.Primary.Damage,ply,tr,self.Primary.Damage,false,true,false, initialTracerColor, 0, initialBulletSpeed)

		if self.NumBullet and self.NumBullet > 1 then
			local k = math.max(1 - tr.StartPos:Distance(tr.HitPos) / 750,0)

			dmgInfo:ScaleDamage(k)
		end
		
		if SERVER then
			net.Start("shoot_huy")
				net.WriteTable(tr)
			net.Broadcast()
		end
	end
	self:FireBullets(bullet)
	ply:LagCompensation(false)
	if SERVER then 
		self:TakePrimaryAmmo(1) 
	end

	-- EFFECTS MANNN!!!
	

	if self.DoFlash then
		local ef = EffectData()
		ef:SetEntity( self )
		ef:SetAttachment( 1 ) -- self:LookupAttachment( "muzzle" )
		ef:SetScale(0.1)
		ef:SetFlags( 1 ) -- Sets the Combine AR2 Muzzle flash

		util.Effect( "MuzzleFlash", ef )
	end

	local ef = EffectData()
	ef:SetEntity( self )

	util.Effect( "sib_muzzleefect", ef )

	if CLIENT then
		SIB_suppress.Shoot = 0.01*(self.Primary.Force/40)
	end
	local obj = self:LookupAttachment("shell") or 2
	local Attachment = self.Owner:GetActiveWeapon():GetAttachment(obj)
	if Attachment then
		local Angles = Attachment.Ang
		if self.ShellRotate then Angles:RotateAroundAxis(vector_up,180)  end
		local ef = EffectData()
		ef:SetOrigin(Attachment.Pos)
		ef:SetAngles(Angles)
		ef:SetFlags( 80 ) -- Sets the Combine AR2 Muzzle flash

		util.Effect( self.Shell, ef )
	end

end

if SERVER then
	util.AddNetworkString("shoot_huy")
	--Регистрируем сетевое сообщение для создания декалей на клиенте
    util.AddNetworkString("sib_draw_flesh_decal")
end

if CLIENT then
	net.Receive("shoot_huy",function(len)
		local tr = net.ReadTable()
		--snd_jack_hmcd_bc_1.wav

		local dist,vec,dist2 = util.DistanceToLine(tr.StartPos,tr.HitPos,EyePos())
		if dist < 128 and dist2 > 128 then
			EmitSound("snd_jack_hmcd_bc_"..tostring(math.random(1,7))..".wav", vec, 1, CHAN_AUTO, 1, 95, 0, 100,0)
			Suppress(1.5)
		end
	end)
    --Принимаем сетевое сообщение и отрисовываем декаль
    net.Receive("sib_draw_flesh_decal", function()
        local pos1 = net.ReadVector()
        local pos2 = net.ReadVector()
        util.Decal("Impact.Flesh", pos1, pos2)
    end)
end

function SWEP:IsReloaded()
	return timer.Exists("reload"..self:EntIndex())
end

function SWEP:IsScope()
	local ply = self:GetOwner()
	if ply:IsNPC() then return end

	if CLIENT or SERVER then
		return not ply:IsSprinting() and ply:KeyDown(IN_ATTACK2) and not self:IsReloaded()
	else
		return self:GetNWBool("IsScope")
	end
end
