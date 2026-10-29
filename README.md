# t0_pressurewasher

Standalone pressure washer **addon weapon** for FiveM and **ox_inventory**. It needs no framework (ESX, QBCore and ox_core all work) and no ox_target.

- Held with two hands like a rifle: aim with right click, spray with left click.
- The jet is a water mist. It stops on walls and washes vehicles progressively; the dirt level is synced for every player.
- Built-in 90-second tank. The water level is stored in the item metadata, and the tooltip shows a percentage.
- Refill with water bottles (`water` item): press **R** with the washer in hand. 1 bottle = 50 %, 2 bottles = full. A small NUI illustration shows the bottle emptying into the washer; press **X** to cancel.
- Server authoritative: water level, consumption, washing and refills are all validated server side.
- English and French included.

Français plus bas.

## Requirements

- [ox_lib](https://github.com/overextended/ox_lib)
- [ox_inventory](https://github.com/overextended/ox_inventory)
- OneSync enabled

## Installation

1. Drop the `t0_pressurewasher` folder into your `resources` folder. Keep the folder name: the item icon path uses it.
2. Add it to `server.cfg` **after** its dependencies:
   ```cfg
   ensure ox_lib
   ensure ox_inventory
   ensure t0_pressurewasher
   ```
3. Register the weapon in `ox_inventory/data/weapons.lua`. Paste the contents of [`install/weapons.lua`](install/weapons.lua) inside the `Weapons = { ... }` table:
   ```lua
   ['WEAPON_PRESSUREWASHER'] = {
       label = 'Pressure Washer',
       weight = 6000,
       durability = 0,
       client = { image = 'nui://t0_pressurewasher/web/images/pressure_washer.png' },
   },
   ```
   If you skip this step, the server console prints a warning together with the entry to paste.
4. Restart the server. Players must reconnect once so the weapon metas load.
5. Give yourself the weapon: `/giveitem <id> WEAPON_PRESSUREWASHER 1`, plus a few `water` items to refill it.

## Configuration

Everything lives in [`config.lua`](config.lua):

| Setting | Description |
|---|---|
| `Config.Lang` | `'en'` or `'fr'`. Add your own table to `Config.Locales`. |
| `Config.Jet` | Range, effective range, particle effects (size, opacity, layers). |
| `Config.Tank` | Capacity in seconds of spraying, consumption rate. |
| `Config.Wash` | Washing speed (GTA dirt units per second). |
| `Config.Refill` | Refill item, % per item, keys, duration, animation, optional hand prop. |
| `Config.Sound` | Synthesized jet sound (disabled by default). |

## Controls

| Key | Action |
|---|---|
| Right click | Aim |
| Left click (hold, while aiming) | Spray |
| R | Refill with one water bottle |
| X | Cancel the refill |

## Notes

- Washing is **global**: it lowers the dirt level of the whole vehicle. GTA V has no per-area dirt.
- The weapon deals no damage and fires no real shot.
- `Config.Debug = true` enables the `/pwpos` and `/pwfx` tuning commands.

## License

- Code: [MIT](LICENSE).
- 3D model (`stream/w_ar_pressurewasher.ydr`) and icon: free to use on any server with this resource, but not open source. Do not sell, extract or redistribute them separately. See [LICENSE](LICENSE).

---

## Français

Arme addon **nettoyeur haute pression** autonome pour FiveM et **ox_inventory**. Aucun framework n'est requis (fonctionne avec ESX, QBCore ou ox_core), et pas besoin d'ox_target.

- Se tient à deux mains comme un fusil : clic droit pour viser, clic gauche pour arroser.
- Le jet est une brume d'eau. Il s'arrête sur les murs et lave les véhicules progressivement ; la saleté est synchronisée pour tous les joueurs.
- Réservoir intégré de 90 s. Le niveau d'eau est stocké dans les métadonnées de l'item, et le tooltip l'affiche en pourcentage.
- Remplissage avec des bouteilles d'eau (item `water`) : touche **R**, nettoyeur en main. 1 bouteille = 50 %, 2 = plein. Une petite illustration NUI montre la bouteille qui se vide dans le nettoyeur ; **X** pour annuler.
- Tout est validé côté serveur : niveau d'eau, consommation, lavage et remplissage.

### Installation

1. Placer le dossier `t0_pressurewasher` dans `resources`, sans le renommer (le chemin de l'icône l'utilise).
2. Dans `server.cfg`, après ses dépendances : `ensure ox_lib`, `ensure ox_inventory`, `ensure t0_pressurewasher`.
3. Coller le contenu de [`install/weapons.lua`](install/weapons.lua) dans la table `Weapons` de `ox_inventory/data/weapons.lua`. Pour un libellé français, remplacer `label` par `'Nettoyeur haute pression'`. Si l'entrée manque, la console serveur l'affiche au démarrage.
4. Mettre `Config.Lang = 'fr'` dans `config.lua`.
5. Redémarrer le serveur. Les joueurs doivent se reconnecter une fois pour charger les metas de l'arme.
6. Test : `/giveitem <id> WEAPON_PRESSUREWASHER 1`, plus quelques `water`.

### Licence

Le code est sous licence MIT. Le modèle 3D et l'icône sont gratuits sur tout serveur avec cette ressource, mais ne sont pas open source : pas de revente, d'extraction ni de redistribution séparée.
