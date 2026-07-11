-- ============================================================
--  sv_genkai_recoleccion.lua  (SERVER)
--  Carga/guarda el nivel por personaje, da XP al recolectar,
--  ajusta las probabilidades del farmeo y envia el popup al cliente.
--  Carpeta: lua/autorun/server/
-- ============================================================

util.AddNetworkString("GenkaiRec_Popup")   -- feedback al recolectar
util.AddNetworkString("GenkaiRec_Estado")   -- sincroniza nivel/xp al cargar

-- -------------------------------------------------------
-- Helpers de acceso al runtime del jugador.
-- -------------------------------------------------------
local function GetData(ply)
    return IsValid(ply) and ply.GenkaiRec or nil
end

function GENKAI_REC.GetNivel(ply)
    local d = GetData(ply)
    return d and d.nivel or 1
end

-- Envia el estado actual (nivel/xp) al cliente. Se usa al cargar.
local function SyncEstado(ply)
    local d = GetData(ply)
    if not d then return end
    net.Start("GenkaiRec_Estado")
        net.WriteUInt(d.nivel, 8)
        net.WriteUInt(d.xp, 32)
        net.WriteUInt(GENKAI_REC.XPParaNivel(d.nivel), 32)
    net.Send(ply)
end

-- Guardado (directo, al pid que este cargado en el runtime).
function GENKAI_REC.GuardarYa(ply)
    local d = GetData(ply)
    if not d or not d._pid then return end
    GENKAI_REC.EscribirEnDB(d._pid, d.nivel, d.xp)
end

-- -------------------------------------------------------
-- CARGA al seleccionar personaje (mismo patron que el inventario).
-- Si ya tenia otro personaje cargado, lo guarda antes.
-- -------------------------------------------------------
function GENKAI_REC.CargarJugador(ply)
    if not IsValid(ply) then return end
    local nuevoPid = ply.GenkaiPersonaje and ply.GenkaiPersonaje.id
    if not nuevoPid then return end

    if ply.GenkaiRec and ply.GenkaiRec._pid and ply.GenkaiRec._pid ~= nuevoPid then
        GENKAI_REC.GuardarYa(ply)
    end

    local row = GENKAI_REC.LeerDeDB(nuevoPid)
    ply.GenkaiRec = { nivel = row.nivel, xp = row.xp, _pid = nuevoPid }

    SyncEstado(ply)
    hook.Run("GenkaiRec_Cargado", ply)
end

hook.Add("Genkai_PersonajeSeleccionado", "GenkaiRec_CargarAlSeleccionar", function(ply)
    GENKAI_REC.CargarJugador(ply)
end)

hook.Add("PlayerDisconnected", "GenkaiRec_GuardarAlSalir", function(ply)
    GENKAI_REC.GuardarYa(ply)
end)

hook.Add("DoPlayerDeath", "GenkaiRec_GuardarAlMorir", function(ply)
    GENKAI_REC.GuardarYa(ply)
end)

-- -------------------------------------------------------
-- DAR XP. Devuelve info del resultado para el popup:
--   { xpGanado, nivel, xp, xpNec, subio, nivelPrevio, desbloqueos = {..} }
-- -------------------------------------------------------
function GENKAI_REC.DarXP(ply, cantidad)
    local d = GetData(ply)
    if not d then return end
    cantidad = math.max(0, math.floor(cantidad))
    if cantidad <= 0 then return end

    local nivelPrevio = d.nivel
    local desbloqueos = {}

    if d.nivel < GENKAI_REC.NivelMax then
        d.xp = d.xp + cantidad

        -- Subir tantos niveles como alcance la XP acumulada.
        local nec = GENKAI_REC.XPParaNivel(d.nivel)
        while d.nivel < GENKAI_REC.NivelMax and nec > 0 and d.xp >= nec do
            d.xp    = d.xp - nec
            d.nivel = d.nivel + 1
            for _, rareza in ipairs(GENKAI_REC.DesbloqueosEnNivel(d.nivel)) do
                desbloqueos[#desbloqueos + 1] = rareza
            end
            nec = GENKAI_REC.XPParaNivel(d.nivel)
        end

        if d.nivel >= GENKAI_REC.NivelMax then d.xp = 0 end
    end

    -- Guardado ligero (con debounce por jugador para no martillear el disco).
    ply._GenkaiRecGuardarProx = ply._GenkaiRecGuardarProx or 0
    if CurTime() >= ply._GenkaiRecGuardarProx then
        GENKAI_REC.GuardarYa(ply)
        ply._GenkaiRecGuardarProx = CurTime() + 5
    end

    return {
        xpGanado    = cantidad,
        nivel       = d.nivel,
        xp          = d.xp,
        xpNec       = GENKAI_REC.XPParaNivel(d.nivel),
        subio       = d.nivel > nivelPrevio,
        nivelPrevio = nivelPrevio,
        desbloqueos = desbloqueos,
    }
end

-- =======================================================
--  ENGANCHES CON EL SISTEMA DE FARMEO
-- =======================================================

-- 1) Ajustar probabilidades segun el nivel del jugador.
hook.Add("GenkaiFarm_Pesos", "GenkaiRec_AjustarPesos", function(ply, nodeType, pesosBase)
    local nivel = GENKAI_REC.GetNivel(ply)
    return GENKAI_REC.Pesos(nivel)  -- reemplaza por completo los pesos base
end)

-- 2) Dar XP y enviar el popup justo al recolectar.
hook.Add("GenkaiFarm_Recolectado", "GenkaiRec_DarXP", function(ply, nodeType, item_id, cantidad, rareza)
    local xpUnidad = GENKAI_REC.XPPorRareza[rareza] or 1
    local res = GENKAI_REC.DarXP(ply, xpUnidad * math.max(1, cantidad))
    if not res then return end

    local def    = GENKAI_INV and GENKAI_INV.GetItem and GENKAI_INV.GetItem(item_id)
    local nombre = (def and def.nombre) or item_id

    net.Start("GenkaiRec_Popup")
        net.WriteString(nombre)
        net.WriteString(rareza)
        net.WriteUInt(math.max(1, cantidad), 16)
        net.WriteUInt(res.xpGanado, 32)
        net.WriteUInt(res.nivel, 8)
        net.WriteUInt(res.xp, 32)
        net.WriteUInt(res.xpNec, 32)
        net.WriteBool(res.subio)
        -- Rarezas recien desbloqueadas (para el aviso especial).
        net.WriteUInt(#res.desbloqueos, 4)
        for _, r in ipairs(res.desbloqueos) do
            net.WriteString(r)
        end
    net.Send(ply)
end)
