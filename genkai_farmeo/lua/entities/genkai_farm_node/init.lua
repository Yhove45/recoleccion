-- ============================================================
--  entities/genkai_farm_node/init.lua  (SERVER)
--  Lógica de farmeo manteniendo la "E", con regeneración pasiva
--  y parche de Autorefresh.
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
    
    -- Permite ejecutar la función Use constantemente mientras se mantiene apretada la E
    self:SetUseType(CONTINUOUS_USE) 

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
        phys:Wake()
    end

    local golpes = (cfg and cfg.golpes) or 6
    local tiempoRegen = (cfg and cfg.regen) or 60

    self.GolpesRestantes = golpes
    self.Recolectando    = {} -- Tabla para rastrear a los jugadores que están farmeando

    self:SetNWString("GenkaiNodeType",  self.NodeType or "mineral")
    self:SetNWInt("GenkaiGolpesMax",    golpes)
    self:SetNWInt("GenkaiGolpes",       golpes)
    self:SetNWBool("GenkaiAgotado",     false)
    self:SetNWFloat("GenkaiRespawnEn",  0)

    -- Regeneración pasiva
    if tiempoRegen > 0 then
        timer.Create("GenkaiFarm_Regen_" .. self:EntIndex(), tiempoRegen, 0, function()
            if not IsValid(self) then return end
            if self:GetNWBool("GenkaiAgotado", false) then return end

            if self.GolpesRestantes < golpes then
                self.GolpesRestantes = self.GolpesRestantes + 1
                self:SetNWInt("GenkaiGolpes", self.GolpesRestantes)
            end
        end)
    end
end

function ENT:OnRemove()
    timer.Remove("GenkaiFarm_Regen_" .. self:EntIndex())
end

-- Marca el nodo como agotado (empieza cooldown gigante para llenarse de nuevo)
function ENT:Agotar()
    local cfg = GENKAI_FARM.Nodos[self.NodeType or ""]
    local t   = (cfg and cfg.respawn) or 120

    self:SetNWBool("GenkaiAgotado", true)
    self:SetNWFloat("GenkaiRespawnEn", CurTime() + t)

    -- El nodo ya no se vuelve transparente ni se quita su colisión.
    -- Se queda físicamente en el mapa, pero su cartel dirá "Agotado".

    timer.Simple(t, function()
        if not IsValid(self) then return end
        self.GolpesRestantes = (cfg and cfg.golpes) or 6
        self:SetNWInt("GenkaiGolpes", self.GolpesRestantes)
        self:SetNWBool("GenkaiAgotado", false)
        self:SetNWFloat("GenkaiRespawnEn", 0)
    end)
end

-- Bucle constante que revisa el progreso de la barra
function ENT:Think()
    -- PARCHE: Asegurar que la tabla existe (útil tras un autorefresh del server)
    self.Recolectando = self.Recolectando or {}
    
    local ahora = CurTime()
    for ply, data in pairs(self.Recolectando) do
        if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then
            self:CancelarRecoleccion(ply)
            continue
        end

        -- Si el jugador soltó la E o miró a otro lado (dejó de llamar a Use por más de 0.2 segs)
        if ahora - data.ultimoTick > 0.2 then
            self:CancelarRecoleccion(ply)
            continue
        end

        -- ¡La barra se completó!
        if ahora >= data.fin then
            self:EntregarLoot(ply)
            
            -- Si quedan recursos en el nodo, reseteamos la barra por si el jugador sigue manteniendo la E
            if self.GolpesRestantes > 0 then
                local cfg = GENKAI_FARM.Nodos[self.NodeType or ""]
                local tiempo = (cfg and cfg.tiempoRecoleccion) or 3 -- Por defecto 3 segundos
                
                data.inicio = ahora
                data.fin = ahora + tiempo
                
                ply:SetNWFloat("GenkaiFarm_Inicio", ahora)
                ply:SetNWFloat("GenkaiFarm_Fin", ahora + tiempo)
            else
                self:CancelarRecoleccion(ply)
            end
        end
    end
    
    self:NextThink(CurTime() + 0.1)
    return true
end

-- Se ejecuta constantemente mientras el jugador mantenga presionada la E sobre el nodo
function ENT:Use(activator)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    if self:GetNWBool("GenkaiAgotado", false) then return end

    if not (activator.GenkaiPersonaje and activator.GenkaiPersonaje.id) then
        if not activator.SiguienteAvisoFarm or CurTime() > activator.SiguienteAvisoFarm then
            activator:ChatPrint("[Farmeo] Necesitas un personaje activo para recolectar.")
            activator.SiguienteAvisoFarm = CurTime() + 2
        end
        return
    end

    local cfg = GENKAI_FARM.Nodos[self.NodeType or ""]
    local tiempo = (cfg and cfg.tiempoRecoleccion) or 3 -- Tiempo en segundos para llenar la barra

    -- PARCHE: Asegurar que la tabla existe
    self.Recolectando = self.Recolectando or {}

    if not self.Recolectando[activator] then
        -- Inicia la barra de progreso
        self.Recolectando[activator] = {
            inicio = CurTime(),
            fin = CurTime() + tiempo,
            ultimoTick = CurTime()
        }
        
        -- Mandamos los datos al cliente para dibujar la barra
        activator:SetNWBool("GenkaiFarm_Cosechando", true)
        activator:SetNWFloat("GenkaiFarm_Inicio", CurTime())
        activator:SetNWFloat("GenkaiFarm_Fin", CurTime() + tiempo)
        activator:SetNWEntity("GenkaiFarm_Ent", self)
    else
        -- Actualizamos el tick para saber que el jugador sigue apretando la E
        self.Recolectando[activator].ultimoTick = CurTime()
    end
end

function ENT:CancelarRecoleccion(ply)
    self.Recolectando[ply] = nil
    if IsValid(ply) then
        ply:SetNWBool("GenkaiFarm_Cosechando", false)
    end
end

-- Función separada para dar el botín y descontar recursos (llamada solo al terminar la barra)
function ENT:EntregarLoot(activator)
    local pesos = table.Copy(GENKAI_FARM.PesoRareza)
    local ov    = hook.Run("GenkaiFarm_Pesos", activator, self.NodeType, pesos)
    if istable(ov) then pesos = ov end

    local entry = GENKAI_FARM.RollItem(self.NodeType, pesos)
    if not entry then return end
    local cant = GENKAI_FARM.RollCantidad(entry.rareza)

    local dado = GENKAI_INV.Dar(activator, entry.id, cant)
    if dado <= 0 then
        activator:ChatPrint("[Farmeo] Tu inventario está lleno (peso o espacio).")
        self:CancelarRecoleccion(activator)
        return
    end
    
    if GENKAI_INV.Sync then GENKAI_INV.Sync(activator) end
    hook.Run("GenkaiFarm_Recolectado", activator, self.NodeType, entry.id, dado, entry.rareza)

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

    -- Consumir 1 golpe
    self.GolpesRestantes = self.GolpesRestantes - 1
    self:SetNWInt("GenkaiGolpes", math.max(0, self.GolpesRestantes))
    if self.GolpesRestantes <= 0 then
        self:Agotar()
    end
end