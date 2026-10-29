Config = {}

-- Affiche des marqueurs (buse, impact) et active /pwfx, /pwpos.
Config.Debug = false

-- Arme addon (data/weapons.meta, modèle stream/w_ar_pressurewasher.ydr), item arme d'ox_inventory.
Config.Item = 'WEAPON_PRESSUREWASHER'

-- Position de la buse dans le repère du modèle (mesurée sur le modèle exporté).
Config.NozzleOffset = vec3(0.755, 0.0, 0.121)

Config.Controls = {
    spray = 24,          -- INPUT_ATTACK (maintenir)
    -- Désactivés tant que le nettoyeur est en main (tir GTA, mêlée). La visée reste native.
    disable = { 24, 45, 140, 141, 142, 257, 263, 264 },
}

-- Visée native de l'arme (clic droit) : posture et caméra de fusil.
Config.Aim = {
    requireAim = true,   -- le jet ne part qu'en visée
}

Config.Jet = {
    range = 8.0,          -- portée maximale du raycast (m)
    effective = 5.0,      -- au-delà, le lavage perd en efficacité jusqu'à range
    minDistance = 0.4,    -- trop près : pas de lavage
    -- Effets vanilla vérifiés (core). Rendu et axe d'émission à valider en jeu.
    asset = 'core',
    -- Effets du jet, superposés. rot = correction (degrés) si l'effet n'émet pas selon +Y :
    -- ent_sht_extinguisher émet vers le haut (+Z), d'où pitch -90.
    --   scale  = taille de la brume (1.0 = taille de l'extincteur vanilla)
    --   alpha  = opacité, de 0.0 (invisible) à 1.0 (pleine)
    --   layers = nombre de couches superposées (1 à 5) : plus de couches = brume plus dense, plus « puissante »
    -- Réglage en jeu : /pwjet <taille> <opacité> <couches> [pitch], /pwjet reset (rendu local, non sauvegardé).
    tuneCommand = false,  -- true pour réactiver /pwjet
    -- L'effet s'épuise seul au bout de quelques secondes : relancé (sans coupure) toutes les N ms.
    -- Si la brume faiblit encore avant la relance, baisser cette valeur.
    refreshMs = 2500,
    effects = {
        { effect = 'ent_sht_extinguisher', scale = 1.2, alpha = 1.0, layers = 5, rot = vec3(-90.0, 0.0, 0.0) },
        -- { effect = 'ent_sht_extinguisher_water', scale = 0.3 }, -- filet d'eau au centre de la brume
    },
    rotOffset = vec3(0.0, 0.0, 0.0), -- correction si l'effet n'émet pas selon +Y
    -- Effets d'impact (core), joués ensemble à chaque intervalle :
    -- Ajouter une ligne pour superposer un effet. Essai en jeu (Config.Debug) : /pwfx <effet> <échelle>.
    -- Pas de exp_water : c'est un geyser de borne à incendie, pas une brume.
    impactEffects = {
        { effect = 'liquid_splash_water', scale = 0.8 },
    },
    impactInterval = 180, -- ms entre deux éclaboussures
}

Config.Tank = {
    capacity = 90.0,      -- autonomie en secondes de jet continu
    consumption = 1.0,    -- unités consommées par seconde de jet
}

Config.Wash = {
    -- Saleté GTA : 0.0 (propre) à 15.0 (très sale). Unités retirées par seconde de jet efficace.
    speed = 1.5,
}

-- Synchronisation client -> serveur pendant le jet (pas d'event par frame).
Config.TickMs = 500
-- Écriture des métadonnées de l'item (niveau d'eau) au plus toutes les N ms pendant le jet.
Config.FlushMs = 3000

-- Remplissage : nettoyeur en main, touche R. Chaque appui consomme une bouteille d'eau.
Config.Refill = {
    item = 'water',        -- item ox_inventory consommé
    percentPerItem = 50,   -- % du réservoir ajouté par bouteille (50 : 1 bouteille = 50 %, 2 = plein)
    key = 45,              -- INPUT_RELOAD (R), déjà désactivé dans Config.Controls.disable
    seconds = 4.0,         -- durée du versement par bouteille (illustration NUI)
    cancelKey = 73,        -- INPUT_VEH_DUCK (X) : annuler
    -- Petite anim discrète (vanilla vérifiée) : mains qui s'affairent devant soi, haut du corps (flag 49).
    anim = { dict = 'mini@repair', clip = 'fixing_a_player', flag = 49 },
    -- Objet en main facultatif, ex. { model = `prop_water_bottle`, bone = 28422, pos = vec3(0, 0, 0), rot = vec3(0, 0, 0) }
    prop = nil,
}

-- Son du jet : synthétisé en NUI (WebAudio), aucune banque audio GTA utilisée. Désactivé : seuls les effets d'eau restent.
Config.Sound = {
    enabled = false,
    volume = 0.35,
    maxDistance = 25.0,
}

-- Rendu des nettoyeurs des autres joueurs.
Config.Remote = {
    drawDistance = 60.0,
}

-- Language: 'en' or 'fr' (add your own table below).
Config.Lang = 'en'

Config.Locales = {}

Config.Locales.en = {
    equip = 'Pressure washer equipped',
    empty = 'Tank empty: press R with a water bottle',
    full = 'Tank already full',
    no_bottle = 'You have no water bottle',
    refilling = 'Refilling the tank...',
    cancel = 'Cancel',
    refilled = 'Tank: %d %%',
    no_washer = 'You have no pressure washer',
    busy = 'You cannot do that right now',
    tank = 'Tank: %d %%',
}

Config.Locales.fr = {
    equip = 'Nettoyeur haute pression en main',
    empty = "Réservoir vide : appuyez sur R avec une bouteille d'eau",
    full = 'Réservoir déjà plein',
    no_bottle = "Aucune bouteille d'eau sur vous",
    refilling = 'Remplissage du réservoir...',
    cancel = 'Annuler',
    refilled = 'Réservoir : %d %%',
    no_washer = 'Aucun nettoyeur haute pression sur vous',
    busy = 'Action impossible pour le moment',
    tank = 'Réservoir : %d %%',
}

Config.Locale = Config.Locales[Config.Lang] or Config.Locales.en
