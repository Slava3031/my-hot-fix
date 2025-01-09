hook.Add(
	"RenderScreenspaceEffects",
	"ToyssssnssssEffect",
	function()
		local bloodlevel = LocalPlayer():GetNWInt("Blood", 5000)
		local painlevel = LocalPlayer():GetNWInt("pain", 5000)
		local fraction = math.Clamp(1 - ((bloodlevel - 3200) / ((5000 - 1400) - 2000)), 0, 1)
		DrawToyTown(fraction * 8, ScrH() * fraction * 1.5)
		if fraction > 0.93 then
			DrawMotionBlur(0.2, 0.9, 0.03)
			local fraction1 = math.Clamp(1 - (painlevel / 250), 0.25, 1)
			local tab = {
				["$pp_colour_contrast"] = fraction1
			}

			DrawColorModify(tab)
		end
	end
)

net.Receive(
	"ragplayercolor",
	function()
		local ent = net.ReadEntity()
		local col = net.ReadVector()
		if IsValid(ent) and isvector(col) then
			function ent:GetPlayerColor()
				return col
			end
		end
	end
)

surface.CreateFont("thehomigeadfont", {
    font = "Exo 2 Medium",
    extended = true,
    size = ScreenScale(25),
    antialias = true,
    weight = 500,
	blursize = 0
})
surface.CreateFont("bluredfont", {
    font = "Exo 2 Medium",
    extended = true,
    size = ScreenScale(25),
    antialias = true,
    weight = 500,
	blursize = 2
})

surface.CreateFont("smalledfont", {
    font = "Exo 2 Medium",
    extended = true,
    size = ScreenScale(7),
    antialias = true,
    weight = 500,
	blursize = 0
})

surface.CreateFont("buttofont", {
    font = "Exo 2 Medium",
    extended = true,
    size = ScreenScale(10),
    antialias = true,
    weight = 500,
	blursize = 0
})

local function Spalchscreen()

	local faded_black = Color(0, 0, 0, 255) -- The color black but with 200 Alpha
	local whitecolor = Color(255,255,255,0)
	local opentime = CurTime() + 5
	local closetime = CurTime()
	local DFrame = vgui.Create("DFrame") -- The name of the panel we don't have to parent it.
	DFrame:SetPos(0, 0) -- Set the position to 100x by 100y. 
	DFrame:SetSize(ScrW(), ScrH()) -- Set the size to 300x by 200y.
	DFrame:ShowCloseButton( false )
	DFrame:SetTitle("") -- Set the title in the top left to "Derma Frame".
	DFrame:SetDraggable(false) -- Makes it so you can't drag it.
	DFrame:MakePopup() -- Makes it so you can move your mouse on it.

-- Paint function w, h = how wide and tall it is.
		
	end