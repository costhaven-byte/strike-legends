"""Addendum 6 pacing sim (Stages 7 and 9): the four-zone core loop, read straight from src/shared/Config/init.luau.

Rules it plays (same as the game): pins a throw = best ball's Pins x pin multiplier; the bag holds BagSizes[bag] x
(1 + pets' Bag) pins; a throw that doesn't fit only fills it; a sell trip of Gifts.TripSeconds when full; the sell pays
pins x the PinValue of the highest open zone x coin multiplier. Coin multiplier = 1 + pets' Coins + Rebirth.Bonus x n
(+ nothing else: no potions, passes, friends). Pin multiplier = 1 + pets' Pins + Rebirth.PinBonus x n. Seconds between
throws = Cooldown / (1 + pets' Speed), never under CooldownFloor. Ball, bag and gate prices x (1 + Bonus x n) ^
LadderPower after n rebirths (CoreLadder.Price). Eggs and pet slots are not scaled. A rebirth resets coins, balls,
bags and zones; keeps pets and bought slots.

The player buys the cheapest useful thing next: the next ball, the next bag, the next gate, the next pet slot, or a
hatch of the highest open zone's egg (up to HATCHES per egg per run). EQUIP BEST by income.

    python tools/pacing_sim.py            (prints the Stage 7 report)
    python tools/pacing_sim.py stage9     (Stage 9: every table in PACING_REPORT.md, 9 pet-luck seeds; ~1 min)
"""
import math
import random
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONFIG = (ROOT / "src/shared/Config/init.luau").read_text(encoding="utf-8")


def block(start_pattern: str, text: str = CONFIG) -> str:
    """The {...} block that starts at the first match of start_pattern."""
    m = re.search(start_pattern, text)
    if not m:
        raise SystemExit("not found: " + start_pattern)
    i = text.index("{", m.start())
    depth = 0
    for j in range(i, len(text)):
        c = text[j]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return text[i : j + 1]
    raise SystemExit("unclosed: " + start_pattern)


def strip_comments(s: str) -> str:
    return re.sub(r"--[^\n]*", "", s)


def numbers(s: str):
    return [float(x) for x in re.findall(r"-?\d+(?:\.\d+)?(?:e\d+)?", strip_comments(s))]


def num(pattern: str, text: str) -> float:
    m = re.search(pattern + r"\s*=\s*(-?[\d.e]+)", strip_comments(text))
    if not m:
        raise SystemExit("no number: " + pattern)
    return float(m.group(1))


CORE = block(r"Config\.CoreLoop\s*=\s*\{")
BALLS = []
for row in re.findall(r"\{ Ball = [^\n]*\}", block(r"\n\tBalls = \{", CORE)):
    BALLS.append(
        {
            "Name": re.search(r'Name = "([^"]+)"', row).group(1),
            "Pins": float(re.search(r"Pins = ([\d.]+)", row).group(1)),
            "Price": float(re.search(r"Price = ([\d.]+)", row).group(1)),
            "Zone": int(re.search(r"Zone = (\d+)", row).group(1)) if "Zone =" in row else 1,
        }
    )
BAG_SIZES = numbers(block(r"BagSizes = \{", CORE))
BAG_PRICES = numbers(block(r"BagPrices = \{", CORE))
BAG_ZONES = [int(x) for x in numbers(block(r"BagZones = \{", CORE))]
COOLDOWN = num(r"\n\tCooldown", CORE)
FLOOR = num(r"CooldownFloor", CORE)
TRIP = num(r"TripSeconds", CORE)
ZONES = []
for row in re.findall(r'Name = "[^"]+",\s*Folder[^\n]*?PinValue = [\d.]+, Price = [\d.]+|Name = "[^"]+",\s*\n\s*Folder = "[^"]+",\s*\n\s*Offset = [^\n]+\n\s*PinValue = [\d.]+,\s*\n\s*Price = [\d.]+', block(r"\n\tZones = \{", CORE)):
    ZONES.append({"PinValue": float(re.search(r"PinValue = ([\d.]+)", row).group(1)), "Price": float(re.search(r"Price = ([\d.]+)", row).group(1))})
REB = block(r"\n\tRebirth = \{\s*\n\s*Enabled", CORE)
REB_PRICES = numbers(block(r"Prices = \{", REB))
REB_GROWTH = num(r"Growth", REB)
REB_BONUS = num(r"\n\t\tBonus", REB)
REB_PIN = num(r"PinBonus", REB)
LADDER_POWER = num(r"LadderPower", REB)

EGGS = []
for row in re.split(r"\n\t\t\t\{", block(r"\n\tEggs = \{", CORE))[1:]:
    if "Odds" not in row:
        continue
    EGGS.append(
        {
            "Id": re.search(r'Id = "([^"]+)"', row).group(1),
            "Zone": int(re.search(r"Zone = (\d+)", row).group(1)),
            "Price": float(re.search(r"Price = ([\d.]+)", row).group(1)),
            "Odds": {k: float(v) for k, v in re.findall(r"(\w+) = ([\d.]+)", block(r"Odds = \{", row))},
            "Pets": re.findall(r'"(\w+)"', block(r"Pets = \{", row)),
        }
    )
PETS = {}
for m in re.finditer(r'Id = "(\w+)",\s*\n\s*Stats = (\{[^}]*\})', CONFIG):
    tail = CONFIG[m.end() : m.end() + 600]
    PETS[m.group(1)] = {
        "Stats": {k: float(v) for k, v in re.findall(r"(\w+) = ([\d.]+)", m.group(2))},
        "Rarity": re.search(r'Rarity = "(\w+)"', tail).group(1),
    }
MASC = block(r"Config\.Economy\.Mascots = \{")
START_SLOTS = int(num(r"StartSlots", MASC))
SHINY_MERGE = int(num(r"ShinyMerge", MASC))
SHINY_X = num(r"ShinyMultiplier", MASC)
SLOT_REBIRTHS = [int(x) for x in numbers(block(r"SlotRebirths = \{", MASC))]
SLOT_PRICES = numbers(block(r"SlotPrices = \{", block(r"Config\.PetStats = \{")))
HATCHES = 3
NL = chr(10)


def round2(x: float) -> float:
    unit = 10 ** max(math.floor(math.log10(x)) - 1, 0)
    return math.floor(x / unit + 0.5) * unit


def scaled(price: float, n: int) -> float:
    if n == 0 or price <= 0:
        return price
    return round2(price * (1 + REB_BONUS * n) ** LADDER_POWER)


def rebirth_price(n: int) -> float:
    p = REB_PRICES[n] if n < len(REB_PRICES) else REB_PRICES[-1] * REB_GROWTH ** (n + 1 - len(REB_PRICES))
    return round2(p)


class Player:
    def __init__(self, seed: int, hatches: int = HATCHES):
        self.rng = random.Random(seed)
        self.hatches = hatches
        self.pets = {}  # (id, shiny) -> count
        self.bought_slots = 0
        self.rebirths = 0
        self.minutes = 0.0
        self.reset_run()
        self.team = None

    def reset_run(self):
        self.ball = 1
        self.bag = 1
        self.zones = 1
        self.hatched = {}  # egg id -> hatches this run

    def slots(self) -> int:
        return START_SLOTS + self.bought_slots + sum(1 for r in SLOT_REBIRTHS if self.rebirths >= r)

    # ---- income
    def income(self, team=None, ball=None, zones=None, bag=None) -> float:
        t = team if team is not None else self.best_team()
        ball = ball or self.ball
        zones = zones or self.zones
        bag = bag or self.bag
        n = self.rebirths
        coin = 1 + t["Coins"] + REB_BONUS * n
        pin = 1 + t["Pins"] + REB_PIN * n
        cd = max(COOLDOWN / (1 + t["Speed"]), FLOOR)
        per = BALLS[ball - 1]["Pins"] * pin
        size = BAG_SIZES[bag - 1] * (1 + t["Bag"])
        throws = max(1, math.ceil(size / per - 1e-9))
        fill = throws * cd
        pins = min(size, throws * per)
        return 60 * pins * ZONES[zones - 1]["PinValue"] * coin / (fill + TRIP)

    def best_team(self):
        if self.team is not None:
            return self.team
        owned = []
        for (pid, shiny), count in self.pets.items():
            mul = SHINY_X if shiny else 1
            owned += [{k: v * mul for k, v in PETS[pid]["Stats"].items()}] * min(count, self.slots())
        team = {"Coins": 0.0, "Pins": 0.0, "Bag": 0.0, "Speed": 0.0}
        for _ in range(min(self.slots(), len(owned))):
            best, best_i, best_v = None, None, -1
            for i, st in enumerate(owned):
                trial = dict(team)
                for k, v in st.items():
                    trial[k] += v
                v = self.income(trial)
                if v > best_v:
                    best, best_i, best_v = trial, i, v
            team = best
            owned.pop(best_i)
        self.team = team
        return team

    def hatch(self, egg):
        total = sum(egg["Odds"].values())
        pick = self.rng.random() * total
        rarity = None
        for r, c in egg["Odds"].items():
            pick -= c
            rarity = r
            if pick <= 0:
                break
        pool = [p for p in egg["Pets"] if PETS[p]["Rarity"] == rarity]
        pid = self.rng.choice(pool)
        self.pets[(pid, False)] = self.pets.get((pid, False), 0) + 1
        if self.pets[(pid, False)] >= SHINY_MERGE:
            self.pets[(pid, False)] -= SHINY_MERGE
            self.pets[(pid, True)] = self.pets.get((pid, True), 0) + 1
        self.hatched[egg["Id"]] = self.hatched.get(egg["Id"], 0) + 1
        self.team = None
        return pid

    # ---- shopping
    def options(self):
        n = self.rebirths
        out = []
        if self.ball < len(BALLS) and BALLS[self.ball]["Zone"] <= self.zones:
            out.append(("Ball", scaled(BALLS[self.ball]["Price"], n)))
        if self.bag < len(BAG_SIZES) and BAG_ZONES[self.bag] <= self.zones:
            out.append(("Bag", scaled(BAG_PRICES[self.bag], n)))
        if self.zones < len(ZONES):
            out.append(("Gate", scaled(ZONES[self.zones]["Price"], n)))
        if self.bought_slots < len(SLOT_PRICES):
            out.append(("Slot", SLOT_PRICES[self.bought_slots]))
        for egg in EGGS:
            if egg["Zone"] == self.zones and self.hatched.get(egg["Id"], 0) < self.hatches:
                out.append(("Egg", egg["Price"]))
        out.sort(key=lambda o: o[1])
        return out

    def spend(self, price: float):
        self.minutes += price / self.income()

    def buy(self, kind: str) -> str:
        if kind == "Ball":
            self.ball += 1
            self.team = None
            return "Ball%d" % self.ball
        if kind == "Bag":
            self.bag += 1
            self.team = None
            return "Bag%d" % self.bag
        if kind == "Gate":
            self.zones += 1
            self.team = None
            return "Zone%d" % self.zones
        if kind == "Slot":
            self.bought_slots += 1
            self.team = None
            return "Slot%d" % self.slots()
        egg = next(e for e in EGGS if e["Zone"] == self.zones)
        return "Egg%s(%s)" % (egg["Id"], self.hatch(egg))


def place(p: Player) -> str:
    """Where the player is: zone and that zone's ball number (1-10)."""
    return "zone %d ball %d" % (BALLS[p.ball - 1]["Zone"], (p.ball - 1) % 10 + 1)


def progress(p: Player) -> float:
    """One number for 'how far along': ball step + bag step (both 1..40)."""
    return p.ball + p.bag


def clock(m: float) -> str:
    return "%d:%02d" % (int(m // 60), int(m % 60)) if m >= 60 else "%dm%02ds" % (int(m), int(m * 60 % 60))


def short(x: float) -> str:
    for unit, name in ((1e15, "Qa"), (1e12, "T"), (1e9, "B"), (1e6, "M"), (1e3, "K")):
        if x >= unit:
            return ("%.3g" % (x / unit)) + name
    return "%.3g" % x


def play(seed=7, policy="asap", rebirths=50, limit=600.0, delay=0.0, log=None, hatches=HATCHES):
    """policy 'asap' = save for the rebirth as soon as it is the cheapest thing on offer, then rebirth; 'delay' = the
    same moment, then keep buying for `delay` more minutes first; 'never'. Returns the player and its runs. Each run:
    start/end (minutes played), buys [(minutes into the run, what)], place, income, cost, save, back."""
    p = Player(seed, hatches)
    runs = []
    run = {"start": 0.0, "buys": [], "back": None, "target": None}
    ready_at = None
    p.best_ball = 1
    p.timeline = []  # (minutes, best ball ever, rebirths, income)
    while p.minutes < limit:
        opts = p.options()
        price = rebirth_price(p.rebirths)
        if policy != "never" and p.rebirths < rebirths and (not opts or price <= opts[0][1]):
            if ready_at is None:
                ready_at = p.minutes
            if not opts or policy == "asap" or p.minutes - ready_at >= delay:
                save = price / p.income()
                p.minutes += save
                run.update(end=p.minutes, place=place(p), ball=p.ball, income=p.income(), cost=price, save=save, team=dict(p.best_team()))
                runs.append(run)
                p.rebirths += 1
                p.reset_run()
                p.team = None
                ready_at = None
                run = {"start": p.minutes, "buys": [], "back": None, "target": runs[-1]["ball"]}
                continue
        if not opts:
            p.minutes = limit  # (never-rebirther with everything bought: nothing left to do)
            break
        kind, cost = opts[0]
        p.spend(cost)
        what = p.buy(kind)
        run["buys"].append((p.minutes - run["start"], what))
        if run["target"] and run["back"] is None and p.ball >= run["target"]:
            run["back"] = p.minutes - run["start"]
        p.best_ball = max(p.best_ball, p.ball)
        p.timeline.append((p.minutes, p.best_ball, p.rebirths, p.income()))
        if log is not None:
            log.append((p.minutes, p.rebirths, what, p.income()))
    run.update(end=p.minutes, place=place(p), ball=p.ball, income=p.income())
    runs.append(run)
    return p, runs


def first(run, what):
    for t, w in run["buys"]:
        if w == what:
            return t
    return None


def report(seed=7, count=8):
    lines = [
        "REBIRTH: +%g coins, +%g pins a rebirth; prices %s then x%g; ladder + gates x(1+%g n)^%g"
        % (REB_BONUS, REB_PIN, ", ".join(short(x) for x in REB_PRICES), REB_GROWTH, REB_BONUS, LADDER_POWER)
    ]
    p, runs = play(seed, "asap", rebirths=count, limit=1200)
    for i, r in enumerate(runs):
        zones = ", ".join("zone %d at %s" % (z, clock(first(r, "Zone%d" % z))) for z in (2, 3, 4) if first(r, "Zone%d" % z) is not None)
        climb = r["end"] - r["start"] - r.get("save", 0)
        back = ""
        if r["back"] is not None:
            prev = runs[i - 1]
            back = "; back to %s in %s (%.0f%% of the run before's %s)" % (
                prev["place"], clock(r["back"]), 100 * r["back"] / (prev["end"] - prev["start"]), clock(prev["end"] - prev["start"]))
        if "cost" in r:
            lines.append("run %d: rebirth %d at %s played, at %s, %s/min, costs %s = %.1f min of income (run %s%s%s)" % (
                i, i + 1, clock(r["end"]), r["place"], short(r["income"]), short(r["cost"]), r["save"], clock(climb), (", " + zones) if zones else "", back))
        else:
            lines.append("run %d (open end): %s played, at %s%s%s" % (i, clock(r["end"]), r["place"], (", " + zones) if zones else "", back))
        if i == 0:
            lines.append("   (run 0: ball 10 at %s, bag 10 at %s)" % (clock(first(r, "Ball10") or 0), clock(first(r, "Bag10") or 0)))
    return NL.join(lines), runs


def reach(p, ball):
    for t, b, n, inc in p.timeline:
        if b >= ball:
            return t
    return None


def compare(seed=7, limit=480.0):
    """Rule 4: rebirth the moment it's ready vs wait. Time to first reach each ball step, and income at times."""
    out = ["%-14s %s | %s" % ("", " ".join("ball%-4d" % b for b in (10, 15, 20, 25, 30, 35, 40)), "income at 1h / 2h / 3h / 4h (rebirths)")]
    for name, kw in (("asap", dict(policy="asap")), ("wait 5 min", dict(policy="delay", delay=5)),
                     ("wait 10 min", dict(policy="delay", delay=10)), ("wait 20 min", dict(policy="delay", delay=20)),
                     ("never", dict(policy="never"))):
        p, runs = play(seed, limit=limit, **kw)
        reached = " ".join("%-8s" % (clock(reach(p, b)) if reach(p, b) else "-") for b in (10, 15, 20, 25, 30, 35, 40))
        incs = []
        for h in (60, 120, 180, 240):
            best = max([inc for t, b, n, inc in p.timeline if t <= h] or [0])
            reb = max([n for t, b, n, inc in p.timeline if t <= h] or [0])
            incs.append("%s(r%d)" % (short(best), reb))
        out.append("%-14s %s | %s" % (name, reached, " ".join(incs)))
    return NL.join(out)


# ---- Stage 9 (pacing pass): every measure the addendum asks for, over several pet-luck seeds
SEEDS = (1, 2, 3, 4, 5, 6, 7, 8, 9)


def median(xs):
    xs = sorted(x for x in xs if x is not None)
    if not xs:
        return None
    n = len(xs)
    return xs[n // 2] if n % 2 else (xs[n // 2 - 1] + xs[n // 2]) / 2


def trace(seed=7, policy="asap", limit=360.0, hatches=HATCHES, rebirths=50, delay=0.0):
    """One playthrough as a list of events (minutes played, run, what) + the runs. what = Ball12 / Bag3 / Zone2 /
    Slot5 / EggX(pet) / Rebirth1."""
    log = []
    p, runs = play(seed, policy, rebirths=rebirths, limit=limit, delay=delay, log=log, hatches=hatches)
    events = [(t, n, w) for t, n, w, inc in log]
    for i, r in enumerate(runs):
        if "cost" in r:
            events.append((r["end"], i, "Rebirth%d" % (i + 1)))
    events.sort(key=lambda e: e[0])
    return p, runs, events


def measures(seed=7, policy="asap", limit=360.0, hatches=HATCHES, delay=0.0):
    p, runs, events = trace(seed, policy, limit, hatches, delay=delay)
    out = {"ball": {}, "bag": {}, "gate": {}, "rebirth": {}, "waits": [], "frontier": {}, "back": {}, "runs": runs}
    best_ball = 1
    last_frontier = 0.0
    run_ball, caught_up = 1, 0.0
    for t, n, w in events:
        m = re.match(r"(Ball|Bag|Zone|Rebirth)(\d+)$", w)
        if not m:
            continue
        kind, k = m.group(1), int(m.group(2))
        key = {"Ball": "ball", "Bag": "bag", "Zone": "gate", "Rebirth": "rebirth"}[kind]
        if k not in out[key]:
            out[key][k] = (t, n)
        if kind == "Rebirth":
            run_ball, caught_up = 1, None  # (not caught up with the best ball yet)
            continue
        if kind == "Ball":
            run_ball = k
            if k == best_ball and caught_up is None:
                caught_up = t  # back at the best ball ever: the next new ball's wait starts here
            if k > best_ball:
                # the new-ball gap: minutes since the last new-best ball, or since this run caught up with it
                out["frontier"][k] = t - max(last_frontier, caught_up if caught_up is not None else t)
                best_ball, last_frontier, caught_up = k, t, t
    prev = 0.0
    for t, n, w in events:
        if t - prev > 8:
            out["waits"].append((prev, t, n, w))
        prev = t
    for i, r in enumerate(runs):
        if i > 0 and r["back"] is not None:
            before = runs[i - 1]
            out["back"][i] = (r["back"], before["end"] - before["start"], before["place"])
    return out


def ball_name(k):
    return "zone %d ball %d" % (BALLS[k - 1]["Zone"], (k - 1) % 10 + 1)


def stage9(seeds=SEEDS, hatches=HATCHES, limit=360.0):
    """Markdown tables for PACING_REPORT.md (median over seeds; [min-max] where it helps)."""
    ms = [measures(s, "asap", limit, hatches) for s in seeds]
    L = []

    def at(key, k):
        ts = [m[key][k][0] for m in ms if k in m[key]]
        runs_ = [m[key][k][1] for m in ms if k in m[key]]
        if not ts:
            return "-", "-"
        return clock(median(ts)), "%d" % median(runs_)

    L.append("Played time (median of %d pet-luck seeds, %d hatches of each zone's egg per run). "
             "Run = how many rebirths the player has done when it happens." % (len(seeds), hatches))
    L.append("")
    for z in (1, 2, 3, 4):
        L.append("**Zone %d**" % z)
        L.append("")
        L.append("| | " + " | ".join(str(i) for i in range(1, 11)) + " |")
        L.append("|---" * 11 + "|")
        for key, label in (("ball", "Ball"), ("bag", "Bag")):
            cells, runs_ = [], []
            for i in range(1, 11):
                k = (z - 1) * 10 + i
                if k == 1:
                    cells.append("start")
                    runs_.append("0")
                    continue
                c, r = at(key, k)
                cells.append(c)
                runs_.append(r)
            L.append("| %s at | %s |" % (label, " | ".join(cells)))
            L.append("| (run) | %s |" % " | ".join(runs_))
        fr = []
        for i in range(1, 11):
            k = (z - 1) * 10 + i
            vals = [m["frontier"].get(k) for m in ms]
            v = median(vals)
            fr.append("%.1f" % v if v is not None else "-")
        L.append("| new-ball gap (min) | %s |" % " | ".join(fr))
        L.append("")
    L.append("**Gates:** " + ", ".join("zone %d at %s (run %s)" % ((z,) + at("gate", z)) for z in (2, 3, 4)))
    L.append("")
    L.append("| Rebirth | At (played) | Where | Saving for it | Price | Back to the run before's best ball | % of that run |")
    L.append("|---|---|---|---|---|---|---|")
    for k in range(1, 9):
        ts = [m["rebirth"][k][0] for m in ms if k in m["rebirth"]]
        if not ts:
            continue
        rs = [m["runs"][k - 1] for m in ms if len(m["runs"]) > k - 1 and "cost" in m["runs"][k - 1]]
        place_ = median([r["ball"] for r in rs])
        save = median([r["save"] for r in rs])
        backs = [m["back"].get(k) for m in ms if m["back"].get(k)]
        b = median([x[0] for x in backs])
        pct = median([100 * x[0] / x[1] for x in backs])
        L.append("| %d | %s [%s-%s] | %s | %.1f min | %s | %s | %s |" % (
            k, clock(median(ts)), clock(min(ts)), clock(max(ts)), ball_name(int(place_)), save, short(rs[0]["cost"]),
            clock(b) if b is not None else "-", ("%.0f%%" % pct) if pct is not None else "-"))
    L.append("")
    waits = []
    for s, m in zip(seeds, ms):
        for a, b, n, w in m["waits"]:
            waits.append((s, a, b, n, w))
    if waits:
        L.append("Waits over 8 minutes with nothing new to buy (seed: from - to, run, what ended it):")
        for s, a, b, n, w in waits[:40]:
            L.append("- seed %d: %s - %s (%.1f min), run %d, ended by %s" % (s, clock(a), clock(b), b - a, n, w))
    else:
        L.append("Waits over 8 minutes with nothing new to buy: **none** in the first %s." % clock(limit))
    return NL.join(L), ms


def waits_until(ms, rebirth=5):
    """Waits over 8 min before rebirth `rebirth` (the part of the game the addendum times)."""
    out = []
    for m in ms:
        end = m["rebirth"].get(rebirth, (1e9, 0))[0]
        out += [(a, b, n, w) for a, b, n, w in m["waits"] if b <= end + 1e-9]
    return out


def rule4(seeds=SEEDS, limit=480.0, hatches=HATCHES):
    """Addendum 7.4 over several seeds: rebirth the moment it's ready vs wait 5/10/20 min vs never. Median played
    time to first reach balls 15..40."""
    marks = (15, 20, 25, 30, 35, 40)
    L = ["| Player | " + " | ".join("ball %d" % b for b in marks) + " |", "|---" * (len(marks) + 1) + "|"]
    for name, kw in (("rebirths at once", dict(policy="asap")), ("waits 5 min", dict(policy="delay", delay=5)),
                     ("waits 10 min", dict(policy="delay", delay=10)), ("waits 20 min", dict(policy="delay", delay=20)),
                     ("never rebirths", dict(policy="never"))):
        reached = {b: [] for b in marks}
        for sd in seeds:
            p, runs = play(sd, limit=limit, hatches=hatches, **kw)
            for b in marks:
                reached[b].append(reach(p, b))
        L.append("| %s | %s |" % (name, " | ".join(clock(median(reached[b])) if median(reached[b]) else "-" for b in marks)))
    return NL.join(L)


def hatching(seeds=SEEDS, counts=(3, 8, 15, 30), limit=600.0):
    """How much a player who hatches more each run speeds up (the pet snowball check)."""
    L = ["| Hatches of each egg a run | Rebirth 3 | Rebirth 5 | Rebirth 7 | Ball 30 | Ball 40 | Zone 4 new-ball gap |",
         "|---|---|---|---|---|---|---|"]
    for h in counts:
        ms = [measures(sd, "asap", limit, h) for sd in seeds]
        r = lambda k: clock(median([m["rebirth"].get(k, (None,))[0] for m in ms]) or 0)
        b = lambda k: clock(median([m["ball"].get(k, (None,))[0] for m in ms]) or 0)
        z4 = median([m["frontier"].get(k) for m in ms for k in range(32, 41)])
        L.append("| %d | %s | %s | %s | %s | %s | %.1f min |" % (h, r(3), r(5), r(7), b(30), b(40), z4))
    return NL.join(L)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "stage9":
        print(stage9(hatches=int(sys.argv[2]) if len(sys.argv) > 2 else HATCHES, limit=480)[0])
        print()
        print(rule4())
        print()
        print(hatching())
        raise SystemExit
    text, runs = report(int(sys.argv[1]) if len(sys.argv) > 1 else 7)
    print(text)
    print()
    print(compare())
