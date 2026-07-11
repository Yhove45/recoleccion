-- ============================================================
--  sv_genkai_farm.lua  (SERVER)
--  Comandos de admin para COLOCAR nodos y PERSISTIRLOS por mapa.
--  Los nodos se guardan en:  data/genkai_farm/<mapa>.txt
--  y se cargan solos al iniciar el mapa.
-- ============================================================

local CARPETA = "genkai_farm"

-- Clase de entidad segun el tipo de nodo.
local CLASE_POR_TIPO = {
    mineral = "genkai_veta_mineral",
    madera  = "genkai_arbol_recursos",
    tela    = "genkai_restos_guerra",
}

-- Permiso: superadmin, o adapta a tu sistema (CAMI, ULX, etc.).
local function EsAdmin(ply)
    return not IsValid(ply) or ply:IsSuperAdmin()
end

local function RutaMapa()
    return CARPETA .. "/" .. game.GetMap() .. ".txt"
end

-- -------------------------------------------------------
-- Crear un nodo en una posicion/angulo dados.
-- -------------------------------------------------------
local function CrearNodo(tipo, pos, ang)
    local clase = CLASE_POR_TIPO[tipo]
    if not clase then return nil end

    local ent = ents.Create(clase)
    if not IsValid(ent) then return nil end
    ent:SetPos(pos)
    ent:SetAngles(ang or Angle(0, 0, 0))
    ent:Spawn()
    ent:Activate()

    local phys = ent:GetPhysicsObject()
    if IsValid(phys) then phys:EnableMotion(false) end
    return ent
end

-- -------------------------------------------------------
-- GUARDAR todos los nodos del mapa a disco.
-- -------------------------------------------------------
local function GuardarNodos()
    local datos = {}
    for tipo, clase in pairs(CLASE_POR_TIPO) do
        for _, ent in ipairs(ents.FindByClass(clase)) do
            if IsValid(ent) then
                local p, a = ent:GetPos(), ent:GetAngles()
                datos[#datos + 1] = {
                    tipo = tipo,
                    pos  = { p.x, p.y, p.z },
                    ang  = { a.p, a.y, a.r },
                }
            end
        end
    end

    if not file.IsDir(CARPETA, "DATA") then file.CreateDir(CARPETA) end
    file.Write(RutaMapa(), util.TableToJSON(datos))
    return #datos
end

-- -------------------------------------------------------
-- CARGAR nodos guardados del mapa.
-- -------------------------------------------------------
local function CargarNodos()
    local raw = file.Read(RutaMapa(), "DATA")
    if not raw or raw == "" then return 0 end

    local datos = util.JSONToTable(raw)
    if not datos then return 0 end

    local n = 0
    for _, d in ipairs(datos) do
        local pos = Vector(d.pos[1], d.pos[2], d.pos[3])
        local ang = Angle(d.ang[1], d.ang[2], d.ang[3])
        if CrearNodo(d.tipo, pos, ang) then n = n + 1 end
    end
    return n
end

hook.Add("InitPostEntity", "GenkaiFarm_CargarNodos", function()
    timer.Simple(1, function()
        local n = CargarNodos()
        if n > 0 then print(("[Genkai Farmeo] %d nodo(s) cargados en %s."):format(n, game.GetMap())) end
    end)
end)

-- =======================================================
--  COMANDOS DE CONSOLA (solo admins)
-- =======================================================

-- genkai_farm_spawn <mineral|madera|tela>
-- Coloca un nodo donde estas mirando.
concommand.Add("genkai_farm_spawn", function(ply, _, args)
    if not EsAdmin(ply) then return end
    local tipo = string.lower(args[1] or "")
    if not CLASE_POR_TIPO[tipo] then
        if IsValid(ply) then ply:ChatPrint("[Farmeo] Uso: genkai_farm_spawn <mineral|madera|tela>") end
        return
    end

    -- Trazar hacia donde mira el admin (o hacia abajo desde la consola RCON).
    local pos, ang
    if IsValid(ply) then
        local tr = ply:GetEyeTrace()
        pos = tr.HitPos
        ang = Angle(0, ply:EyeAngles().y + 180, 0)
    else
        pos = Vector(0, 0, 0)
        ang = Angle(0, 0, 0)
    end

    local ent = CrearNodo(tipo, pos + Vector(0, 0, 4), ang)
    if IsValid(ent) and IsValid(ply) then
        ply:ChatPrint("[Farmeo] Nodo colocado. Usa genkai_farm_guardar para hacerlo permanente.")
    end
end)

-- genkai_farm_guardar  -> guarda todos los nodos del mapa
concommand.Add("genkai_farm_guardar", function(ply)
    if not EsAdmin(ply) then return end
    local n = GuardarNodos()
    local msg = ("[Farmeo] %d nodo(s) guardados en %s."):format(n, game.GetMap())
    if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
end)

-- genkai_farm_limpiar  -> elimina todos los nodos del mapa (no borra el guardado)
concommand.Add("genkai_farm_limpiar", function(ply)
    if not EsAdmin(ply) then return end
    local n = 0
    for _, clase in pairs(CLASE_POR_TIPO) do
        for _, ent in ipairs(ents.FindByClass(clase)) do
            if IsValid(ent) then ent:Remove() n = n + 1 end
        end
    end
    local msg = ("[Farmeo] %d nodo(s) eliminados (el guardado sigue intacto)."):format(n)
    if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
end)

print("[Genkai Farmeo] Comandos de admin cargados (genkai_farm_spawn / guardar / limpiar).")
