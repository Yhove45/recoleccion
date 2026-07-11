-- ============================================================
--  entities/genkai_farm_node/init.lua  (SERVER)
--  Logica del nodo de farmeo: golpear -> dar material -> agotar -> respawn
-- ============================================================
AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:Initialize()
    local cfg    = GENKAI_FARM.Nodos[self.NodeType or ""]
    local modelo = (cfg and cfg.modelo) or "models/props_junk/cardboard_box004a.mdl"

    self:SetModel(modelo)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    -- Los nodos son fijos: no queremos que se muevan al golpearlos.
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
        phys:Wake()
    end

    -- Estado, expuesto al cliente por NW para dibujar el cartel.
    local golpes = (cfg and cfg.golpes) or 6
    self.GolpesRestantes = golpes
    self.ProxUso         = {}   -- cooldown por jugador (SteamID -> CurTime)

    self:SetNWString("GenkaiNodeType",  self.NodeType or "mineral")
    self:SetNWInt("GenkaiGolpesMax",    golpes)
    self:SetNWInt("GenkaiGolpes",       golpes)
    self:SetNWBool("GenkaiAgotado",     false)
    self:SetNWFloat("GenkaiRespawnEn",  0)
end

-- Marca el nodo como agotado y programa su reaparicion.
function ENT:Agotar()
    local cfg = GENKAI_FARM.Nodos[self.NodeType or ""]
    local t   = (cfg and cfg.respawn) or 120

    self:SetNWBool("GenkaiAgotado", true)
    self:SetNWFloat("GenkaiRespawnEn", CurTime() + t)

    -- Efecto visual "gastado": semitransparente y no solido.
    self:SetNotSolid(true)
    self:SetRenderMode(RENDERMODE_TRANSALPHA)
    self:SetColor(Color(255, 255, 255, 45))

    timer.Simple(t, function()
        if not IsValid(self) then return end
        self.GolpesRestantes = (cfg and cfg.golpes) or 6
        self:SetNWInt("GenkaiGolpes", self.GolpesRestantes)
        self:SetNWBool("GenkaiAgotado", false)
        self:SetNWFloat("GenkaiRespawnEn", 0)
        self:SetNotSolid(false)
        self:SetRenderMode(RENDERMODE_NORMAL)
        self:SetColor(Color(255, 255, 255, 255))
    end)
end

function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    if self:GetNWBool("GenkaiAgotado", false) then return end

    -- Requiere personaje activo (igual que el resto del addon).
    if not (activator.GenkaiPersonaje and activator.GenkaiPersonaje.id) then
        activator:ChatPrint("[Farmeo] Necesitas un personaje activo para recolectar.")
        return
    end

    -- Cooldown por jugador para evitar spam de +use.
    local ahora = CurTime()
    local sid   = activator:SteamID()
    if self.ProxUso[sid] and ahora < self.ProxUso[sid] then return end
    self.ProxUso[sid] = ahora + (GENKAI_FARM.CooldownGolpe or 1.2)

    -- Pesos de rareza. Por defecto los del config; el addon de Nivel de
    -- Recoleccion (opcional) los ajusta segun el nivel del jugador via hook.
    local pesos = table.Copy(GENKAI_FARM.PesoRareza)
    local ov    = hook.Run("GenkaiFarm_Pesos", activator, self.NodeType, pesos)
    if istable(ov) then pesos = ov end

    -- Sorteo del material.
    local entry = GENKAI_FARM.RollItem(self.NodeType, pesos)
    if not entry then return end
    local cant = GENKAI_FARM.RollCantidad(entry.rareza)

    -- Entregar al inventario.
    local dado = GENKAI_INV.Dar(activator, entry.id, cant)
    if dado <= 0 then
        activator:ChatPrint("[Farmeo] Tu inventario está lleno (peso o espacio).")
        return
    end
    if GENKAI_INV.Sync then GENKAI_INV.Sync(activator) end

    -- Aviso para otros addons (Nivel de Recoleccion, etc.). Aqui es donde
    -- el sistema de nivel da XP y muestra el popup al recolectar.
    hook.Run("GenkaiFarm_Recolectado", activator, self.NodeType, entry.id, dado, entry.rareza)

    -- Feedback: sonido + chispas. (El texto de "+N material" lo muestra el
    -- addon de Nivel de Recoleccion si esta instalado; si no, lo ponemos aqui.)
    local def = GENKAI_INV.GetItem(entry.id)
    if not GENKAI_REC then
        activator:ChatPrint(("[Farmeo] +%d %s"):format(dado, def and def.nombre or entry.id))
    end

    local cfg = GENKAI_FARM.Nodos[self.NodeType or ""]
    if cfg and cfg.sonido and cfg.sonido ~= "" then
        self:EmitSound(cfg.sonido, 75, math.random(95, 105))
    end

    local ed = EffectData()
    ed:SetOrigin(self:WorldSpaceCenter())
    ed:SetMagnitude(1)
    ed:SetScale(1)
    util.Effect("Sparks", ed)

    -- Descontar golpe y agotar si toca.
    self.GolpesRestantes = self.GolpesRestantes - 1
    self:SetNWInt("GenkaiGolpes", math.max(0, self.GolpesRestantes))
    if self.GolpesRestantes <= 0 then
        self:Agotar()
    end
end
