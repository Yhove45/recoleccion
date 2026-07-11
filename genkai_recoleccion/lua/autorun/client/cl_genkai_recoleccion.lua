-- ============================================================
--  cl_genkai_recoleccion.lua  (CLIENT)
--  Popup que aparece SOLO al recolectar: material obtenido, +XP,
--  barra de nivel, subida de nivel y desbloqueos de rareza.
--  Carpeta: lua/autorun/client/
-- ============================================================

surface.CreateFont("GenkaiRecBig",  { font = "Roboto", size = 30, weight = 800, antialias = true })
surface.CreateFont("GenkaiRecMed",  { font = "Roboto", size = 22, weight = 700, antialias = true })
surface.CreateFont("GenkaiRecSmall",{ font = "Roboto", size = 18, weight = 500, antialias = true })

-- Estado local del nivel (se mantiene aunque el popup desaparezca).
local ESTADO = { nivel = 1, xp = 0, xpNec = GENKAI_REC.XPParaNivel(1) }

-- Popup activo (nil = nada que dibujar).
local POPUP = nil
local barMostrada = 0  -- fraccion animada de la barra

-- Duraciones.
local T_HOLD = 3.6
local T_FADE = 0.7

local function colRareza(rareza)
    if GENKAI_INV and GENKAI_INV.GetRareza then
        return GENKAI_INV.GetRareza(rareza).color
    end
    return Color(212, 175, 55)
end

-- -------------------------------------------------------
-- RECIBIR estado inicial (al cargar el personaje).
-- -------------------------------------------------------
net.Receive("GenkaiRec_Estado", function()
    ESTADO.nivel = net.ReadUInt(8)
    ESTADO.xp    = net.ReadUInt(32)
    ESTADO.xpNec = net.ReadUInt(32)
    barMostrada  = (ESTADO.xpNec > 0) and (ESTADO.xp / ESTADO.xpNec) or 1
end)

-- -------------------------------------------------------
-- RECIBIR evento de recoleccion -> abre el popup.
-- -------------------------------------------------------
net.Receive("GenkaiRec_Popup", function()
    local nombre   = net.ReadString()
    local rareza   = net.ReadString()
    local cantidad = net.ReadUInt(16)
    local xpGanado = net.ReadUInt(32)
    local nivel    = net.ReadUInt(8)
    local xp       = net.ReadUInt(32)
    local xpNec    = net.ReadUInt(32)
    local subio    = net.ReadBool()

    local nDesb = net.ReadUInt(4)
    local desbloqueos = {}
    for i = 1, nDesb do desbloqueos[i] = net.ReadString() end

    ESTADO.nivel, ESTADO.xp, ESTADO.xpNec = nivel, xp, xpNec

    POPUP = {
        nombre = nombre, rareza = rareza, cantidad = cantidad,
        xpGanado = xpGanado, subio = subio, desbloqueos = desbloqueos,
        nace = CurTime(),
    }

    if subio then surface.PlaySound("buttons/button9.wav") end
end)

-- Al cambiar de personaje, limpiar el popup viejo.
hook.Add("Genkai_PersonajeSeleccionado", "GenkaiRec_LimpiarPopup", function()
    POPUP = nil
end)

-- -------------------------------------------------------
-- DIBUJO
-- -------------------------------------------------------
hook.Add("HUDPaint", "GenkaiRec_Popup", function()
    if not POPUP then return end

    local t   = CurTime() - POPUP.nace
    local vida = T_HOLD + T_FADE
    if t >= vida then POPUP = nil return end

    -- Alpha: entra rapido, se mantiene, se desvanece.
    local a = 255
    if t < 0.15 then
        a = 255 * (t / 0.15)
    elseif t > T_HOLD then
        a = 255 * (1 - (t - T_HOLD) / T_FADE)
    end
    a = math.Clamp(a, 0, 255)

    -- Animar la barra de XP hacia el objetivo.
    local objetivo = (ESTADO.xpNec > 0) and math.Clamp(ESTADO.xp / ESTADO.xpNec, 0, 1) or 1
    barMostrada = Lerp(FrameTime() * 6, barMostrada, objetivo)

    local dorado = (GENKAI_INV and GENKAI_INV.Colores and GENKAI_INV.Colores.dorado) or Color(212, 175, 55)
    local crema  = (GENKAI_INV and GENKAI_INV.Colores and GENKAI_INV.Colores.crema)  or Color(244, 228, 188)
    local cRar   = colRareza(POPUP.rareza)

    local w, h = 320, 96
    local x = ScrW() / 2 - w / 2
    local y = ScrH() * 0.70

    local function A(c, mul) return Color(c.r, c.g, c.b, (c.a or 255) * (a / 255) * (mul or 1)) end

    -- Panel.
    draw.RoundedBox(8, x, y, w, h, Color(10, 9, 7, 235 * (a / 255)))
    surface.SetDrawColor(A(dorado, 0.4))
    surface.DrawOutlinedRect(x, y, w, h, 2)

    -- Linea 1: material obtenido.
    draw.SimpleText(("+%d  %s"):format(POPUP.cantidad, POPUP.nombre), "GenkaiRecMed",
        x + 14, y + 12, A(cRar), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    -- XP ganada (derecha).
    draw.SimpleText(("+%d XP"):format(POPUP.xpGanado), "GenkaiRecSmall",
        x + w - 14, y + 14, A(crema, 0.9), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

    -- Nivel + barra.
    local etiqueta = (ESTADO.nivel >= GENKAI_REC.NivelMax) and "NIVEL MÁX" or ("Nivel " .. ESTADO.nivel)
    draw.SimpleText(etiqueta, "GenkaiRecSmall", x + 14, y + 44, A(dorado), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    local bx, by = x + 14, y + 68
    local bw, bh = w - 28, 14
    draw.RoundedBox(3, bx, by, bw, bh, Color(22, 20, 16, 235 * (a / 255)))
    draw.RoundedBox(3, bx, by, bw * barMostrada, bh, A(dorado))

    if ESTADO.nivel < GENKAI_REC.NivelMax then
        draw.SimpleText(("%d / %d"):format(ESTADO.xp, ESTADO.xpNec), "GenkaiRecSmall",
            x + w - 14, y + 46, A(crema, 0.8), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
    end

    -- Aviso de subida de nivel (encima del panel).
    if POPUP.subio then
        draw.SimpleText(("¡Nivel %d!"):format(ESTADO.nivel), "GenkaiRecBig",
            x + w / 2, y - 10, A(dorado), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
    end

    -- Avisos de desbloqueo (debajo del panel).
    if POPUP.desbloqueos and #POPUP.desbloqueos > 0 then
        local oy = y + h + 8
        for _, rareza in ipairs(POPUP.desbloqueos) do
            local txt = ("¡Ahora consigues materiales %s!"):format(GENKAI_REC.NombreRareza(rareza))
            draw.SimpleText(txt, "GenkaiRecSmall", x + w / 2, oy,
                A(colRareza(rareza)), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            oy = oy + 22
        end
    end
end)
