# Step E playtest (by numbers, 2026-11-01)
Studio Play, START FROM ZERO (test session, nothing saved). Driven from execute_luau (Client VM remotes + a temp
server Script that set the Bag; the temp Script was only in the Play copy).

1. TEST > PACING at 0:13 -> report printed: run 0, nothing bought yet. OK.
2. COINS x10 twice, GO TO SHOP, CoreBuy Ball, Ball, Bag, Ball, PetSlot, Bag -> Output: `[Pacing] Ball2 at 0:28 into
   run 0`, Ball3, Bag2, Ball4, Slot4, Bag3, each once. Analytics: LogCustomEvent + LogFunnelStepEvent fired. OK.
3. READY TO REBIRTH + Rebirth remote -> rebirth 1. COINS, GO TO SHOP, Ball -> `Ball2 at 0:04 into run 1` (new run, run
   time restarted). PACING: run 0 closed ("rebirth 1 after 0:32"), run 1 open. OK.
4. Four sells of a 50K bag (x2 rebirth = 100K each) -> PACING: income now 397K a minute, run 1 top 400K. OK.
5. GO TO EGGS + HatchEgg Alley -> `Egg_Alley at 0:59 into run 1`. OK.
6. Found + fixed: run 0 had no sells, so its "before rebirth" income was 0 and run 1 counted as "back to it" at the
   first sell. Now "back to the last run's income" needs that income to be above 0.
No errors in Output (the AreaSign/ZoneShop "not found" lines were there before this step).
Not checked live: the print on leaving (same Report function as the PACING button), Creator Dashboard (only fills in
the live game).
