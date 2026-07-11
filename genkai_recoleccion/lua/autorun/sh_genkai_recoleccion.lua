-- ============================================================
--  sh_genkai_recoleccion.lua
--  ADDON APARTE: Nivel de Recoleccion (max 100).
--  Carpeta: lua/autorun/   (COMPARTIDO: server + client)
--
--  Se engancha al sistema de farmeo (genkai_inventory) por hooks:
--    GenkaiFarm_Pesos       -> ajusta probabilidades segun tu nivel
--    GenkaiFarm_Recolectado -> da XP al recolectar
--  Si el addon de farmeo no esta, este addon simplemente no hace nada.
--
--  Pensado como plantilla: cuando montes Forja / Medicina / Cocina,
--  cada una sera un addon igual a este pero con su propia tabla y
--  su propio disparador de XP.
-- ============================================================

GENKAI_REC = GENKAI_REC or {}

GENKAI_REC.NivelMax = 100

-- -------------------------------------------------------
-- CURVA DE XP
--   XPParaNivel(n) = XP necesaria para pasar de nivel n a n+1.
--   Sube de forma exponencial suave. Ajusta Base/Exp a gusto.
-- -------------------------------------------------------
GENKAI_REC.XPBase = 40
GENKAI_REC.XPExp  = 1.6

function GENKAI_REC.XPParaNivel(n)
    if n >= GENKAI_REC.NivelMax then return 0 end
    return math.floor(GENKAI_REC.XPBase * (n ^ GENKAI_REC.XPExp))
end

-- -------------------------------------------------------
-- XP QUE DA CADA MATERIAL SEGUN SU RAREZA (por unidad).
-- -------------------------------------------------------
GENKAI_REC.XPPorRareza = {
    comun      = 5,
    raro       = 12,
    epico      = 30,
    legendario = 80,
}

-- -------------------------------------------------------
-- DESBLOQUEO Y PROBABILIDAD POR RAREZA
--   unlock   -> nivel minimo para que esa rareza pueda salir.
--               Por debajo de ese nivel, su peso es 0 (bloqueada).
--   pesoBase -> peso justo al desbloquearla.
--   pesoMax  -> peso al llegar a nivel 100.
--   El peso se interpola linealmente entre unlock y 100.
--
--   Nota: "comun" empieza alto y BAJA con el nivel, para que a niveles
--   altos salgan proporcionalmente mas materiales buenos.
-- -------------------------------------------------------
GENKAI_REC.Rarezas = {
    comun      = { unlock = 1,  pesoBase = 60, pesoMax = 25 },
    raro       = { unlock = 10, pesoBase = 25, pesoMax = 35 },
    epico      = { unlock = 30, pesoBase = 10, pesoMax = 28 },
    legendario = { unlock = 60, pesoBase = 3,  pesoMax = 14 },
}

-- Orden de rareza (para saber cual es "mejor" en avisos de desbloqueo).
GENKAI_REC.OrdenRareza = { comun = 1, raro = 2, epico = 3, legendario = 4 }

-- Peso de UNA rareza a un nivel dado (0 si aun no esta desbloqueada).
function GENKAI_REC.PesoRareza(rareza, nivel)
    local r = GENKAI_REC.Rarezas[rareza]
    if not r then return 0 end
    if nivel < r.unlock then return 0 end
    local span = math.max(1, GENKAI_REC.NivelMax - r.unlock)
    local t    = math.Clamp((nivel - r.unlock) / span, 0, 1)
    return Lerp(t, r.pesoBase, r.pesoMax)
end

-- Tabla completa de pesos rareza->peso para un nivel (lo que consume el farmeo).
function GENKAI_REC.Pesos(nivel)
    local out = {}
    for rareza in pairs(GENKAI_REC.Rarezas) do
        out[rareza] = GENKAI_REC.PesoRareza(rareza, nivel)
    end
    return out
end

-- Lista de rarezas que se desbloquean EXACTAMENTE en este nivel
-- (para el aviso "¡Ahora puedes conseguir materiales Épicos!").
function GENKAI_REC.DesbloqueosEnNivel(nivel)
    local t = {}
    for rareza, r in pairs(GENKAI_REC.Rarezas) do
        if r.unlock == nivel then t[#t + 1] = rareza end
    end
    table.sort(t, function(a, b)
        return (GENKAI_REC.OrdenRareza[a] or 0) < (GENKAI_REC.OrdenRareza[b] or 0)
    end)
    return t
end

-- Nombre bonito de la rareza (usa el del inventario si esta cargado).
function GENKAI_REC.NombreRareza(rareza)
    if GENKAI_INV and GENKAI_INV.Rarezas and GENKAI_INV.Rarezas[rareza] then
        return GENKAI_INV.Rarezas[rareza].nombre
    end
    return rareza
end
