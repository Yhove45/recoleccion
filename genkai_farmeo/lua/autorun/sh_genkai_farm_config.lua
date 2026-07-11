-- ============================================================
--  sh_genkai_farm_config.lua
--  Sistema de FARMEO de materiales (ADDON APARTE: genkai_farmeo).
--  Carpeta: lua/autorun/   (COMPARTIDO: server + client)
--
--  NO toca el addon de inventario. Solo LLAMA a sus funciones
--  publicas (GENKAI_INV.RegistrarItem / Dar / Sync / GetItem).
--
--  ORDEN DE CARGA:
--  Como este es un addon separado, puede cargar ANTES que
--  genkai_inventory. Por eso los materiales NO se registran aqui
--  directamente, sino en el hook "Initialize", cuando GENKAI_INV
--  ya existe con seguridad.
-- ============================================================

GENKAI_FARM = GENKAI_FARM or {}

-- -------------------------------------------------------
-- AJUSTES GENERALES
-- -------------------------------------------------------
GENKAI_FARM.CooldownGolpe   = 1.2   -- segundos entre golpes del mismo jugador
GENKAI_FARM.DistanciaCartel = 600   -- distancia a la que se ve el cartel del nodo
GENKAI_FARM.IconPath        = "genkai/menu/"  -- ruta base de los iconos .png

-- Probabilidad base por rareza (si el addon de Nivel de Recoleccion no esta).
GENKAI_FARM.PesoRareza = {
    comun = 60, raro = 25, epico = 12, legendario = 3,
}

-- Cantidad {min,max} por golpe segun rareza.
GENKAI_FARM.CantRareza = {
    comun = { 1, 3 }, raro = { 1, 2 }, epico = { 1, 1 }, legendario = { 1, 1 },
}

-- Peso de inventario por defecto segun rareza.
GENKAI_FARM.PesoInvRareza = {
    comun = 0.2, raro = 0.3, epico = 0.4, legendario = 0.6,
}

-- -------------------------------------------------------
-- DEFINICION DE LOS 3 NODOS  (solo DATOS, sin registrar nada)
--   loot = lista de { id, nombre, rareza }
-- -------------------------------------------------------
GENKAI_FARM.Nodos = {

    mineral = {
        nombre  = "Veta de Mineral",
        modelo  = "models/props_wasteland/rockgranite02b.mdl",
        golpes  = 6,
        respawn = 120,
        sonido  = "physics/rock/rock_impact_hard4.wav",
        color   = Color(150, 160, 175),
        loot = {
            { id = "mena_hierro",      nombre = "Mena de Hierro",      rareza = "comun" },
            { id = "mena_cobre",       nombre = "Mena de Cobre",       rareza = "comun" },
            { id = "mena_estano",      nombre = "Mena de Estaño",      rareza = "comun" },
            { id = "carbon",           nombre = "Carbón",              rareza = "comun" },
            { id = "mena_plata",       nombre = "Mena de Plata",       rareza = "raro" },
            { id = "mena_oro",         nombre = "Mena de Oro",         rareza = "raro" },
            { id = "rubi_bruto",       nombre = "Rubí en Bruto",       rareza = "epico" },
            { id = "zafiro_bruto",     nombre = "Zafiro en Bruto",     rareza = "epico" },
            { id = "mena_chakra",      nombre = "Mena de Chakra",      rareza = "epico" },
            { id = "diamante_bruto",   nombre = "Diamante en Bruto",   rareza = "legendario" },
            { id = "nucleo_meteorito", nombre = "Núcleo de Meteorito", rareza = "legendario" },
        },
    },

    madera = {
        nombre  = "Árbol de Recursos",
        modelo  = "models/props_foliage/tree_deciduous_01a.mdl",
        golpes  = 6,
        respawn = 120,
        sonido  = "physics/wood/wood_solid_impact_hard5.wav",
        color   = Color(120, 170, 90),
        loot = {
            { id = "madera_roble",     nombre = "Madera de Roble",   rareza = "comun" },
            { id = "rama_seca",        nombre = "Rama Seca",         rareza = "comun" },
            { id = "corteza_fibrosa",  nombre = "Corteza Fibrosa",   rareza = "comun" },
            { id = "tabla_pino",       nombre = "Tabla de Pino",     rareza = "comun" },
            { id = "madera_ebano",     nombre = "Madera de Ébano",   rareza = "raro" },
            { id = "bambu_endurecido", nombre = "Bambú Endurecido",  rareza = "raro" },
            { id = "madera_cerezo",    nombre = "Madera de Cerezo",  rareza = "epico" },
            { id = "madera_chakra",    nombre = "Madera de Chakra",  rareza = "epico" },
            { id = "corazon_roble",    nombre = "Corazón de Roble",  rareza = "epico" },
            { id = "madera_sagrada",   nombre = "Madera Sagrada",    rareza = "legendario" },
            { id = "rama_divina",      nombre = "Rama Divina",       rareza = "legendario" },
        },
    },

    tela = {
        nombre  = "Restos de Guerra",
        modelo  = "models/props_junk/wood_crate001a.mdl",
        golpes  = 6,
        respawn = 120,
        sonido  = "physics/body/body_medium_impact_soft6.wav",
        color   = Color(180, 140, 90),
        loot = {
            { id = "tela_resistente",  nombre = "Tela Resistente",    rareza = "comun" },
            { id = "hilo_lino",        nombre = "Hilo de Lino",       rareza = "comun" },
            { id = "fragmento_cuero",  nombre = "Fragmento de Cuero", rareza = "comun" },
            { id = "placa_oxidada",    nombre = "Placa Oxidada",      rareza = "comun" },
            { id = "cuero_curtido",    nombre = "Cuero Curtido",      rareza = "raro" },
            { id = "seda_reforzada",   nombre = "Seda Reforzada",     rareza = "raro" },
            { id = "malla_acero",      nombre = "Malla de Acero",     rareza = "epico" },
            { id = "esencia_antigua",  nombre = "Esencia Antigua",    rareza = "epico" },
            { id = "seda_ignea",       nombre = "Seda Ígnea",         rareza = "epico" },
            { id = "reliquia_shinobi", nombre = "Reliquia Shinobi",   rareza = "legendario" },
            { id = "estandarte_caido", nombre = "Estandarte Caído",   rareza = "legendario" },
        },
    },
}

-- -------------------------------------------------------
-- REGISTRO DE MATERIALES en el inventario.
-- Se llama en "Initialize" (ya existe GENKAI_INV) y una sola vez.
-- -------------------------------------------------------
local yaRegistrado = false
function GENKAI_FARM.RegistrarMateriales()
    if yaRegistrado then return end
    if not (GENKAI_INV and GENKAI_INV.RegistrarItem) then return end

    for _, node in pairs(GENKAI_FARM.Nodos) do
        for _, m in ipairs(node.loot) do
            GENKAI_INV.RegistrarItem(m.id, {
                nombre    = m.nombre,
                desc      = m.desc or "Material de crafteo.",
                categoria = "material",
                rareza    = m.rareza,
                peso      = m.peso or GENKAI_FARM.PesoInvRareza[m.rareza] or 0.2,
                stackable = true,
                maxStack  = m.maxStack or 99,
                icon      = GENKAI_FARM.IconPath .. (m.icon or m.id),
                modelo    = m.modelo or "models/props_junk/cardboard_box004a.mdl",
            })
        end
    end

    yaRegistrado = true
    print("[Genkai Farmeo] Materiales registrados en el inventario.")
end

hook.Add("Initialize", "GenkaiFarm_RegistrarMateriales", function()
    GENKAI_FARM.RegistrarMateriales()
end)
-- Reintento por si el inventario carga aun mas tarde en algun setup.
hook.Add("InitPostEntity", "GenkaiFarm_RegistrarMateriales2", function()
    GENKAI_FARM.RegistrarMateriales()
end)
-- Y un intento directo por si GENKAI_INV ya estaba listo al cargar este archivo.
if GENKAI_INV and GENKAI_INV.RegistrarItem then GENKAI_FARM.RegistrarMateriales() end

-- -------------------------------------------------------
-- SORTEO PONDERADO (soporta override de pesos del sistema de nivel).
-- Peso 0 = esa rareza no sale (bloqueada por nivel).
-- -------------------------------------------------------
function GENKAI_FARM.RollItem(nodeType, pesosOverride)
    local node = GENKAI_FARM.Nodos[nodeType]
    if not node or not node.loot then return nil end
    local pesos = pesosOverride or GENKAI_FARM.PesoRareza

    local total = 0
    for _, entry in ipairs(node.loot) do
        total = total + math.max(0, pesos[entry.rareza] or 0)
    end
    if total <= 0 then return node.loot[1] end

    local r, acc = math.random() * total, 0
    for _, entry in ipairs(node.loot) do
        acc = acc + math.max(0, pesos[entry.rareza] or 0)
        if r <= acc then return entry end
    end
    return node.loot[#node.loot]
end

function GENKAI_FARM.RollCantidad(rareza)
    local rango = GENKAI_FARM.CantRareza[rareza] or { 1, 1 }
    return math.random(rango[1], rango[2])
end

print("[Genkai Farmeo] Config cargado.")
