-- ============================================================
--  sv_genkai_recoleccion_db.lua  (SERVER)
--  SQLite: nivel y XP de recoleccion por personaje.
--  Carpeta: lua/autorun/server/
-- ============================================================

local function InicializarDB()
    sql.Query([[
        CREATE TABLE IF NOT EXISTS genkai_recoleccion (
            personaje_id INTEGER PRIMARY KEY,
            nivel        INTEGER NOT NULL DEFAULT 1,
            xp           INTEGER NOT NULL DEFAULT 0
        )
    ]])
end
hook.Add("Initialize", "GenkaiRec_InicializarDB", InicializarDB)
InicializarDB() -- por si el addon carga despues del Initialize del mapa

-- Leer { nivel, xp } de un personaje (o valores por defecto).
function GENKAI_REC.LeerDeDB(pid)
    pid = tonumber(pid)
    if not pid then return { nivel = 1, xp = 0 } end

    local row = sql.QueryRow("SELECT nivel, xp FROM genkai_recoleccion WHERE personaje_id = " .. pid)
    if not row then return { nivel = 1, xp = 0 } end
    return {
        nivel = math.Clamp(tonumber(row.nivel) or 1, 1, GENKAI_REC.NivelMax),
        xp    = math.max(0, tonumber(row.xp) or 0),
    }
end

-- Guardar nivel/xp de un personaje.
function GENKAI_REC.EscribirEnDB(pid, nivel, xp)
    pid = tonumber(pid)
    if not pid then return end
    sql.Query(string.format(
        "REPLACE INTO genkai_recoleccion (personaje_id, nivel, xp) VALUES (%d, %d, %d)",
        pid, math.floor(nivel), math.floor(xp)
    ))
end

-- Borrar el progreso de un personaje (al eliminarlo en el creador).
function GENKAI_REC.BorrarDePersonaje(pid)
    pid = tonumber(pid)
    if not pid then return end
    sql.Query("DELETE FROM genkai_recoleccion WHERE personaje_id = " .. pid)
end
