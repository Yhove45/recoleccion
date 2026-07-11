-- ============================================================
--  entities/genkai_farm_node/shared.lua
--  ENTIDAD BASE del sistema de farmeo. No se spawnea directamente:
--  las 3 entidades reales (veta/arbol/restos) heredan de esta.
-- ============================================================
ENT.Type      = "anim"
ENT.Base      = "base_gmodentity"

ENT.PrintName = "Nodo de Farmeo (base)"
ENT.Author    = "Genkai"
ENT.Spawnable = false        -- la base no aparece en el menu
ENT.AdminOnly = true

-- Tipo de nodo por defecto. Las entidades hijas lo sobrescriben
-- ("mineral", "madera", "tela") en su propio shared.lua.
ENT.NodeType  = "mineral"
