# Launch changes handoff (2026-11-03)

Owner's 9 changes before publishing (one shot, no PASSED waits). Plus: run the pacing sim after the pet slot
change; OP Egg gets a green "super saiyan" aura. Restore point: git tag `restore-launch-changes-before`.

## The 9 items and the plan
1. Fuse prompt: popup when a pet reaches 3 copies (MascotController, after hatch) with GO FUSE (teleport to the
   fusion machine via CoreGoTo "Fusion", then the FUSE PETS window opens).
2. PASSES HUD button gone: Config.Ui.PassesButton = false (CoreShopController + HudKit grid: TELEPORT takes its spot).
3. Pet slots: 3 base, +1 at 3 rebirths (Config.Economy.Mascots.SlotRebirths = {3}), +2 PET SLOTS pass (exists).
   Coin slots removed (Config.PetStats.SlotPrices = {}); Mascots.Slots/SlotLocks stats branch use rebirth slots.
4. Auto bowl = pass only: Config.AutoBowl.FreeAfterRebirths = 0; AUTO button shows for everyone, tap = buy.
5. Auto sell pass (new, Id AutoSell, PassId 0 until owner makes it): bag sells itself when full.
6. Infinite Bag pass (new, Id InfiniteBag): no bag limit, pins sell as they land. Excludes AutoSell both ways
   (store card greyed). Card in the shop's Bags tab too.
7. OP Egg (Id "OP", zone 1, 299 R$ dev product OpEgg, ProductId 0 until owner makes it): old zone 4 pets (models
   from ServerStorage.PetModels_Backup_20261103 + TitanJr), stats above every pet, no triple hatch, green aura.
   Odds shown = real odds (Roblox paid-random-items rule; told owner).
8. Triple hatch pass 199 R$ (owner changes the price in Creator Hub too).
9. Eggs bigger: Config.EggBoard / stand egg scale.

## Progress
- (update as each item lands)

## Sync
`python -m http.server 35311 --bind 127.0.0.1` in the project folder, then in Studio Edit:
`require(game.ServerStorage.Tools.DevSync:Clone())({ "src/...luau" })`.
- 2026-11-03: ALL CODE WRITTEN (items 1-9 + aura + pet retune x1.6 zone 2 / x1.7 zones 3-4 from the sim). Studio:
  OP pet models + Egg_OP in ReplicatedStorage.PetModels, stand ServerStorage.ZoneKits.Zone1.OPEgg (edit-mode changes,
  need Save to Roblox). NEXT: sync to Studio, play test, commit.
- Synced all 16 files to Studio (DevSync, port 35377); play start: no errors in Output. NOT yet checked in play:
  OP Egg stand placement at (60, -3438) (may overlap props), aura look, fuse prompt popup/buttons position, AUTO SELL
  button spot under AUTO (phone too), INFINITE BAG card in the shop Bags tab, bigger eggs on every stand.
- Owner to do: make passes AutoSell (249 R$) + InfiniteBag (499 R$) and product OpEgg (299 R$) in Creator Hub, send
  IDs (PassId/ProductId 0 = hidden live); change TRIPLE HATCH to 199 R$ there; Save to Roblox (new models live only
  in Studio until then).
