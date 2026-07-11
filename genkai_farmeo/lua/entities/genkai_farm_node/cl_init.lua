-- ============================================================
--  entities/genkai_farm_node/cl_init.lua  (CLIENT)
--  Dibuja usos en el nodo 3D y barra de progreso en pantalla
-- ============================================================
include("shared.lua")

surface.CreateFont("GenkaiFarmTitulo", { font = "Roboto", size = 26, weight = 700, antialias = true })
surface.CreateFont("GenkaiFarmSub",    { font = "Roboto", size = 18, weight = 500, antialias = true })

function ENT:Draw()
    self:DrawModel()

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local dMax = GENKAI_FARM.DistanciaCartel or 600
    local pos  = self:WorldSpaceCenter() + Vector(0, 0, self:OBBMaxs().z * 0.7 + 14)
    if pos:DistToSqr(ply:GetPos()) > (dMax * dMax) then return end

    local cfg     = GENKAI_FARM.Nodos[self:GetNWString("GenkaiNodeType", self.NodeType or "mineral")]
    local nombre  = (cfg and cfg.nombre) or "Nodo"
    local colBase = (cfg and cfg.color) or Color(212, 175, 55)

    local dorado = (GENKAI_INV.Colores and GENKAI_INV.Colores.dorado) or Color(212, 175, 55)
    local crema  = (GENKAI_INV.Colores and GENKAI_INV.Colores.crema)  or Color(244, 228, 188)

    local yaw = (ply:EyePos() - pos):Angle().yaw
    local ang = Angle(0, yaw - 90, 90)
    local agotado = self:GetNWBool("GenkaiAgotado", false)

    cam.Start3D2D(pos, ang, 0.1)
        local w, h = 220, 66

        draw.RoundedBox(8, -w / 2, -h, w, h, Color(10, 9, 7, 220))
        surface.SetDrawColor(colBase.r, colBase.g, colBase.b, 90)
        surface.DrawOutlinedRect(-w / 2, -h, w, h, 2)

        draw.SimpleText(nombre, "GenkaiFarmTitulo", 0, -h + 8, dorado, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

        if agotado then
            local restante = math.max(0, math.ceil(self:GetNWFloat("GenkaiRespawnEn", 0) - CurTime()))
            draw.SimpleText(("Agotado — reaparece en %ds"):format(restante), "GenkaiFarmSub",
                0, -h + 40, Color(200, 90, 90), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        else
            -- Muestra la barra de usos restantes en el 3D
            local gol  = self:GetNWInt("GenkaiGolpes", 0)
            local gmax = math.max(1, self:GetNWInt("GenkaiGolpesMax", 1))
            local frac = math.Clamp(gol / gmax, 0, 1)

            local bw, bh = w - 40, 12
            local bx, by = -bw / 2, -22
            draw.RoundedBox(3, bx, by, bw, bh, Color(22, 20, 16, 255))
            draw.RoundedBox(3, bx, by, bw * frac, bh, colBase)

            draw.SimpleText("[E] Mantener para extraer", "GenkaiFarmSub", 0, -6, crema, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        end
    cam.End3D2D()
end

-- Hook para dibujar la barra directamente en el HUD de la pantalla
hook.Add("HUDPaint", "GenkaiFarm_BarraPantalla", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    -- Buscar si el jugador está interactuando con un nodo cercano
    local nodoActivo = nil
    for _, ent in ipairs(ents.FindInSphere(ply:GetPos(), 150)) do
        if IsValid(ent) and ent.GetNWEntity and ent:GetNWEntity("GenkaiRecolector") == ply then
            nodoActivo = ent
            break
        end
    end

    if not IsValid(nodoActivo) then return end

    local inicio = nodoActivo:GetNWFloat("GenkaiRecolectarInicio", 0)
    local fin = nodoActivo:GetNWFloat("GenkaiRecolectarFin", 0)
    
    if fin <= inicio then return end

    local frac = math.Clamp((CurTime() - inicio) / (fin - inicio), 0, 1)
    
    -- Configuración de la barra en pantalla
    local w, h = 300, 24
    local x = (ScrW() / 2) - (w / 2)
    local y = (ScrH() / 2) + 120 -- Se dibuja debajo de la mira

    local cfg = GENKAI_FARM.Nodos[nodoActivo:GetNWString("GenkaiNodeType", "mineral")]
    local colBase = (cfg and cfg.color) or Color(212, 175, 55)
    
    -- Fondo oscuro
    draw.RoundedBox(4, x, y, w, h, Color(20, 20, 20, 220))
    -- Relleno dinámico
    draw.RoundedBox(4, x, y, w * frac, h, colBase)
    -- Borde
    surface.SetDrawColor(0, 0, 0, 255)
    surface.DrawOutlinedRect(x, y, w, h, 2)

    -- Texto superior
    draw.SimpleText("Recolectando...", "GenkaiFarmSub", x + w/2, y - 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
end)

hook.Add("HUDPaint", "GenkaiFarm_HUDBarra", function()
    local ply = LocalPlayer()
    -- Verificamos si el servidor nos marcó como "cosechando"
    if not IsValid(ply) or not ply:GetNWBool("GenkaiFarm_Cosechando", false) then return end

    local ent = ply:GetNWEntity("GenkaiFarm_Ent")
    if not IsValid(ent) then return end

    local inicio = ply:GetNWFloat("GenkaiFarm_Inicio", 0)
    local fin    = ply:GetNWFloat("GenkaiFarm_Fin", 0)
    local ahora  = CurTime()

    -- Calculamos porcentaje completado (0 a 1)
    local frac = math.Clamp((ahora - inicio) / (fin - inicio), 0, 1)

    -- Tamaño y Posición de la barra (centrada abajo del crosshair)
    local w, h = 300, 24
    local x, y = (ScrW() - w) / 2, (ScrH() / 2) + 120

    -- Fondo de la barra
    draw.RoundedBox(4, x, y, w, h, Color(10, 9, 7, 220))
    
    -- Barra de color dorado llenándose
    local dorado = (GENKAI_INV and GENKAI_INV.Colores and GENKAI_INV.Colores.dorado) or Color(212, 175, 55)
    if frac > 0 then
        draw.RoundedBox(4, x, y, w * frac, h, dorado)
    end
    
    -- Borde de la barra
    surface.SetDrawColor(dorado.r, dorado.g, dorado.b, 90)
    surface.DrawOutlinedRect(x, y, w, h, 2)

    -- Texto usando la fuente que ya habías creado
    draw.SimpleText("Recolectando...", "GenkaiFarmSub", x + w/2, y + h/2 - 1, Color(244, 228, 188), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)