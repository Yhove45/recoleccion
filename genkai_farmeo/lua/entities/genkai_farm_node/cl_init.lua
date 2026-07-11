-- ============================================================
--  entities/genkai_farm_node/cl_init.lua  (CLIENT)
--  Dibuja el modelo + un cartel 3D2D flotante con nombre,
--  barra de golpes restantes o cuenta atras de respawn.
-- ============================================================
include("shared.lua")

-- Fuentes (se crean una sola vez).
surface.CreateFont("GenkaiFarmTitulo", { font = "Roboto", size = 26, weight = 700, antialias = true })
surface.CreateFont("GenkaiFarmSub",    { font = "Roboto", size = 18, weight = 500, antialias = true })

function ENT:Draw()
    self:DrawModel()

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    -- Distancia: no dibujar el cartel si esta lejos.
    local dMax = GENKAI_FARM.DistanciaCartel or 600
    local pos  = self:WorldSpaceCenter() + Vector(0, 0, self:OBBMaxs().z * 0.7 + 14)
    if pos:DistToSqr(ply:GetPos()) > (dMax * dMax) then return end

    local cfg     = GENKAI_FARM.Nodos[self:GetNWString("GenkaiNodeType", self.NodeType or "mineral")]
    local nombre  = (cfg and cfg.nombre) or "Nodo"
    local colBase = (cfg and cfg.color) or Color(212, 175, 55)

    local dorado = (GENKAI_INV.Colores and GENKAI_INV.Colores.dorado) or Color(212, 175, 55)
    local crema  = (GENKAI_INV.Colores and GENKAI_INV.Colores.crema)  or Color(244, 228, 188)

    -- Cartel que siempre mira al jugador en horizontal (queda derecho).
    local yaw = (ply:EyePos() - pos):Angle().yaw
    local ang = Angle(0, yaw - 90, 90)

    local agotado = self:GetNWBool("GenkaiAgotado", false)

    cam.Start3D2D(pos, ang, 0.1)
        local w, h = 220, 66

        -- Panel de fondo.
        draw.RoundedBox(8, -w / 2, -h, w, h, Color(10, 9, 7, 220))
        surface.SetDrawColor(colBase.r, colBase.g, colBase.b, 90)
        surface.DrawOutlinedRect(-w / 2, -h, w, h, 2)

        -- Titulo.
        draw.SimpleText(nombre, "GenkaiFarmTitulo", 0, -h + 8,
            dorado, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

        if agotado then
            local restante = math.max(0, math.ceil(self:GetNWFloat("GenkaiRespawnEn", 0) - CurTime()))
            draw.SimpleText(("Agotado — reaparece en %ds"):format(restante), "GenkaiFarmSub",
                0, -h + 40, Color(200, 90, 90), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        else
            -- Barra de golpes restantes.
            local gol  = self:GetNWInt("GenkaiGolpes", 0)
            local gmax = math.max(1, self:GetNWInt("GenkaiGolpesMax", 1))
            local frac = math.Clamp(gol / gmax, 0, 1)

            local bw, bh = w - 40, 12
            local bx, by = -bw / 2, -22
            draw.RoundedBox(3, bx, by, bw, bh, Color(22, 20, 16, 255))
            draw.RoundedBox(3, bx, by, bw * frac, bh, colBase)

            draw.SimpleText("[E] Recolectar", "GenkaiFarmSub", 0, -6,
                crema, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        end
    cam.End3D2D()
end
