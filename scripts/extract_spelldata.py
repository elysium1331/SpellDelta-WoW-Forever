"""Builds SpellData.lua from game tables exported with wow.export.

Usage:
    python scripts/extract_spelldata.py data-src/1.60.1.70938 [--out SpellData.lua] [--report]

Input: the CSV files wow.export writes from its Data Tables tab (semicolon separated):
Spell, SpellName, SpellEffect, SpellMisc, SpellDuration, SkillLine, SkillLineAbility,
SpellDescriptionVariables, SpellXDescriptionVariables.

What it writes, per class spell whose numbers grow with spell damage or healing: one
"slot" for every number the spell's tooltip shows, in tooltip order. A slot says how
much that number grows per point of bonus, and which bonus:

    "h:0.856"   grows 0.856 per point of healing bonus
    "2:0.714*2" two numbers ("min to max"), each growing 0.714 per point of holy damage
    "6:0.428"   grows 0.428 per point of shadow damage bonus (schools 2-7 as in
                GetSpellBonusDamage: 2 holy, 3 fire, 4 nature, 5 frost, 6 shadow, 7 arcane)
    "0"         does not grow (a duration, a radius, a percentage...)

The addon reads the live tooltip, checks that it shows exactly as many numbers as
there are slots, and only then predicts. If the counts differ it predicts nothing for
that spell, so a template this script misreads can never produce a wrong number.

How the slots are found: the spell's description template is rendered token by token
($s1, $o1, $d, ${...}, $?a123[...][...] and so on). The rules are in Template below.
Anything the script does not understand marks the whole spell as unsupported.
"""
from __future__ import annotations

import argparse
import ast
import csv
import math
import operator
import re
import sys
from collections import defaultdict
from pathlib import Path

SCHOOL_INDEX = {2: 2, 4: 3, 8: 4, 16: 5, 32: 6, 64: 7}  # SchoolMask bit -> bonus index

# SpellEffect.Effect / EffectAura values (WoW enums).
EFFECT_SCHOOL_DAMAGE = 2
EFFECT_HEALTH_LEECH = 9
EFFECT_HEAL = 10
EFFECT_APPLY_AURA = 6
EFFECT_APPLY_AREA_AURA_PARTY = 35
AURA_PERIODIC_DAMAGE = 3
AURA_PERIODIC_HEAL = 8
AURA_PERIODIC_LEECH = 53
AURA_SCHOOL_ABSORB = 69
HEAL_AURAS = {AURA_PERIODIC_HEAL, AURA_SCHOOL_ABSORB}
AURA_EFFECTS = {EFFECT_APPLY_AURA, EFFECT_APPLY_AREA_AURA_PARTY, 27, 65, 119, 128, 129, 143, 174}
AURA_DAMAGE_SHIELD = 43
# Effects whose number is damage (weapon strikes count when the spell has a magic school,
# like Holy Strike).
DAMAGE_EFFECTS = {EFFECT_SCHOOL_DAMAGE, EFFECT_HEALTH_LEECH, 17, 31, 58, 121}
DAMAGE_AURAS = {AURA_PERIODIC_DAMAGE, AURA_PERIODIC_LEECH, AURA_SCHOOL_ABSORB, AURA_DAMAGE_SHIELD}

# Spell-power tokens inside ${...} expressions -> which bonus they read.
SPELL_POWER_TOKENS = {"SPH": "h", "SPHO": "2", "SPFI": "3", "SPN": "4", "SPFR": "5", "SPS": "6",
                      "SPA": "7", "SP": "school"}

EXCLUDED_SKILL_LINES = {"777", "778"}  # Mounts, Companions
CLASS_CATEGORY = "7"


def load(folder: Path, name: str) -> list[dict]:
    path = folder / f"{name}.csv"
    with path.open(encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f, delimiter=";"))


def num(value: str) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return 0.0


# --- Safe arithmetic for ${...} expressions -------------------------------------------

_BINOPS = {ast.Add: operator.add, ast.Sub: operator.sub, ast.Mult: operator.mul,
           ast.Div: operator.truediv, ast.Mod: operator.mod, ast.Pow: operator.pow}
_FUNCS = {"max": max, "min": min, "floor": math.floor, "ceil": math.ceil, "abs": abs,
          "round": round}


def safe_eval(expr: str) -> float:
    tree = ast.parse(expr, mode="eval")

    def ev(node):
        if isinstance(node, ast.Expression):
            return ev(node.body)
        if isinstance(node, ast.Constant) and isinstance(node.value, (int, float)):
            return float(node.value)
        if isinstance(node, ast.BinOp) and type(node.op) in _BINOPS:
            return _BINOPS[type(node.op)](ev(node.left), ev(node.right))
        if isinstance(node, ast.UnaryOp) and isinstance(node.op, (ast.USub, ast.UAdd)):
            v = ev(node.operand)
            return -v if isinstance(node.op, ast.USub) else v
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id in _FUNCS:
            return float(_FUNCS[node.func.id](*[ev(a) for a in node.args]))
        raise ValueError("unsupported expression")

    return ev(tree)


class Unsupported(Exception):
    pass


class Data:
    def __init__(self, folder: Path):
        self.names = {r["ID"]: r["Name_lang"] for r in load(folder, "SpellName")}
        self.spell = {r["ID"]: r for r in load(folder, "Spell")}
        self.description_by_name: dict[str, str] = {}
        for sid in sorted(self.spell, key=int):
            text = self.spell[sid].get("Description_lang", "")
            if text.strip() and self.names.get(sid):
                self.description_by_name.setdefault(self.names[sid], text)
        self.misc = {}
        for r in load(folder, "SpellMisc"):
            if r["DifficultyID"] == "0":
                self.misc.setdefault(r["SpellID"], r)
        self.duration = {r["ID"]: num(r["Duration"]) for r in load(folder, "SpellDuration")}
        self.effects: dict[str, dict[int, dict]] = defaultdict(dict)
        for r in load(folder, "SpellEffect"):
            if r["DifficultyID"] == "0":
                self.effects[r["SpellID"]][int(r["EffectIndex"]) + 1] = r
        variables = {r["ID"]: r["Variables"] for r in load(folder, "SpellDescriptionVariables")}
        self.desc_vars: dict[str, dict[str, str]] = {}
        for r in load(folder, "SpellXDescriptionVariables"):
            text = variables.get(r["SpellDescriptionVariablesID"], "")
            parsed = {}
            for line in text.splitlines():
                m = re.match(r"\s*\$(\w+)\s*=\s*(.*)$", line)
                if m:
                    parsed[m.group(1).lower()] = m.group(2).strip()
            self.desc_vars[r["SpellID"]] = parsed
        skill_lines = {r["ID"]: r for r in load(folder, "SkillLine")}
        self.class_spells = set()
        self.skill_line_name: dict[str, str] = {}
        for r in load(folder, "SkillLineAbility"):
            line = skill_lines.get(r["SkillLine"])
            if line and line["CategoryID"] == CLASS_CATEGORY and r["SkillLine"] not in EXCLUDED_SKILL_LINES:
                self.class_spells.add(r["Spell"])
                self.skill_line_name[r["Spell"]] = line["DisplayName_lang"]

    def school_mask(self, spell_id: str) -> int:
        return int(num(self.misc.get(spell_id, {}).get("SchoolMask", "0")))

    def spell_duration_ms(self, spell_id: str) -> float:
        idx = self.misc.get(spell_id, {}).get("DurationIndex", "0")
        return self.duration.get(idx, 0.0)

    def bonus_var(self, spell_id: str, effect: dict) -> str | None:
        """Which bonus an effect's coefficient applies to: 'h', '2'..'7', or None."""
        kind = int(num(effect["Effect"]))
        aura = int(num(effect["EffectAura"]))
        mask = self.school_mask(spell_id)
        is_aura = kind in AURA_EFFECTS
        if kind == EFFECT_HEAL or (is_aura and aura == AURA_PERIODIC_HEAL):
            return "h"
        if is_aura and aura == AURA_SCHOOL_ABSORB:
            # Priest shields grow with healing; mage/warlock absorbs with their school.
            if mask & 2 or not mask & 0x7E:
                return "h"
        # Only damage effects grow with a school bonus. Other effects (Resurrection's
        # "resurrect", for example) can carry a coefficient of 1 that the game never uses.
        damages = kind in DAMAGE_EFFECTS or (is_aura and aura in DAMAGE_AURAS)
        if not damages:
            return None
        for bit in (2, 4, 8, 16, 32, 64):
            if mask & bit:
                return str(SCHOOL_INDEX[bit])
        return None  # physical: spell bonuses do not apply

    def effect(self, spell_id: str, index: int) -> dict | None:
        return self.effects.get(spell_id, {}).get(index)

    def coef(self, spell_id: str, index: int) -> tuple[str | None, float]:
        e = self.effect(spell_id, index)
        if not e:
            return None, 0.0
        c = num(e["EffectBonusCoefficient"])
        if c <= 0:
            return None, 0.0
        var = self.bonus_var(spell_id, e)
        return (var, c) if var else (None, 0.0)

    def ticks(self, spell_id: str, index: int) -> int:
        e = self.effect(spell_id, index)
        if not e:
            return 0
        period = num(e["EffectAuraPeriod"])
        if period <= 0:
            return 0
        return int(self.spell_duration_ms(spell_id) // period)


# --- Template rendering ------------------------------------------------------------------

NUMBER_RE = re.compile(r"\d[\d,.]*")


def literal_count(text: str) -> int:
    """How many numbers SpellText.Numbers (Lua) finds in plain text."""
    count = 0
    for m in NUMBER_RE.finditer(text):
        raw = m.group(0).rstrip(",.")
        if "," in raw:
            parts = raw.split(",")
            grouped = len(parts) >= 2 and re.fullmatch(r"\d{1,3}", parts[0]) is not None
            for i, part in enumerate(parts[1:], start=2):
                ok = re.fullmatch(r"\d{3}", part) or (i == len(parts) and re.fullmatch(r"\d{3}\.\d+", part))
                if not ok:
                    grouped = False
            count += 1 if grouped else len([p for p in parts if p])
        else:
            count += 1 if raw else 0
    return count


class Slot:
    """One token of the tooltip: n numbers (2 for a "min to max" range) growing by
    coef per point of bonus `var` (None: not growing)."""
    __slots__ = ("var", "coef", "n")

    def __init__(self, var: str | None = None, coef: float = 0.0, n: int = 1):
        self.var, self.coef = (var, coef) if var and coef > 0 else (None, 0.0)
        self.n = n

    def encode(self) -> str:
        if not self.var:
            return " ".join(["0"] * self.n)
        return f"{self.var}:{self.coef:.4g}" + ("*2" if self.n == 2 else "")


VALUE_LETTERS = set("sSmMoOwW")
FIXED_LETTERS = set("dDtTaArRhHnNuUxXeEbBqQiIcCfFvVkKpP")


class Template:
    """Renders one description into a list of slots."""

    def __init__(self, data: Data, spell_id: str, depth: int = 0):
        self.data, self.spell_id, self.depth = data, spell_id, depth

    # Value of a $-reference in a ${} expression: base points + coef * B, so the
    # expression can be evaluated at B=0 and B=1000 to get its growth per point.
    def ref_value(self, spell_id: str, letter: str, index: int, bonus: float) -> tuple[float, str | None]:
        e = self.data.effect(spell_id, index or 1)
        if letter.lower() in "smw":
            if not e:
                raise Unsupported(f"missing effect {spell_id}:{index}")
            var, c = self.data.coef(spell_id, index or 1)
            return num(e["EffectBasePointsF"]) + c * bonus, var
        if letter.lower() == "o":
            if not e:
                raise Unsupported(f"missing effect {spell_id}:{index}")
            var, c = self.data.coef(spell_id, index or 1)
            ticks = self.data.ticks(spell_id, index or 1)
            return (num(e["EffectBasePointsF"]) + c * bonus) * ticks, var
        if letter.lower() == "d":
            return self.data.spell_duration_ms(spell_id) / 1000.0, None
        if letter.lower() == "t":
            return (num(e["EffectAuraPeriod"]) / 1000.0) if e else 0.0, None
        if letter.lower() in "abhnrux":
            return 1.0, None  # fixed, value irrelevant to growth
        raise Unsupported(f"ref ${letter}")

    def expr_slot(self, expr: str) -> Slot:
        """${expr} -> one number, growing linearly with the bonus (or not at all)."""
        vars_seen = set()

        def substitute(bonus: float) -> str:
            def repl(m):
                spell = m.group(1) or self.spell_id
                letter, index = m.group(2), int(m.group(3) or 0)
                value, var = self.ref_value(spell, letter, index, bonus)
                if var:
                    vars_seen.add(var)
                return f"({value:.10f})"

            def spell_power(m):
                var = SPELL_POWER_TOKENS[m.group(1)]
                if var == "school":
                    var = self.data.bonus_var(self.spell_id, {"Effect": "2", "EffectAura": "0"})
                    if not var:
                        raise Unsupported("$SP on a physical spell")
                vars_seen.add(var)
                return f"({bonus:.10f})"

            text = expr
            for _ in range(5):  # variables may refer to other variables
                new = re.sub(r"\$<(\w+)>", lambda m: "(" + self.var_expr(m.group(1)) + ")", text)
                if new == text:
                    break
                text = new
            if re.search(r"\$(MWS|MWB|MW|mw|mws|mwb)\b", text):
                raise Unsupported(f"expression uses weapon damage {expr!r}")

            def attack_power(m):
                var = "rap" if m.group(1).lower() == "rap" else "ap"
                vars_seen.add(var)
                return f"({bonus:.10f})"

            text = re.sub(r"\$(RAP|rap|AP|apm|ap)(?![A-Za-z])", attack_power, text)
            text = re.sub(r"\$(SPFR|SPFI|SPHO|SPH|SPN|SPS|SPA|SP)(?![A-Za-z])", spell_power, text)
            text = re.sub(r"\$PL\b", "60", text)
            text = re.sub(r"\$(\d*)([a-zA-Z])(\d?)", repl, text)
            text = text.replace("$", "")
            stripped = re.sub(r"(max|min|floor|ceil|abs|round)\(", "(", text)
            if re.search(r"[A-Za-z_]", stripped):
                raise Unsupported(f"expression {expr!r}")
            return text

        try:
            f0 = safe_eval(substitute(0.0))
            f1 = safe_eval(substitute(1000.0))
        except (ValueError, SyntaxError, ZeroDivisionError, TypeError) as exc:
            raise Unsupported(f"expression {expr!r}: {exc}") from exc
        if len(vars_seen) > 1:
            raise Unsupported("expression mixes bonuses")
        growth = abs(f1 - f0) / 1000.0
        return Slot(next(iter(vars_seen)) if vars_seen else None, growth)

    def var_expr(self, name: str) -> str:
        variables = self.data.desc_vars.get(self.spell_id, {})
        value = variables.get(name.lower())
        if value is None:
            raise Unsupported(f"variable $<{name}>")
        value = value.strip()
        if value.startswith("$?"):
            # "$?s12953[${1.06}][${$<frostdamage2>}]": a talent check. Use the last
            # (no-talent) branch; talents are handled separately.
            last_open = None
            depth = 0
            for k, ch in enumerate(value):
                if ch == "[":
                    if depth == 0:
                        last_open = k
                    depth += 1
                elif ch == "]":
                    depth -= 1
            if last_open is None:
                raise Unsupported(f"conditional variable $<{name}>")
            value = value[last_open + 1:value.rindex("]")].strip()
        if value.startswith("${") and value.endswith("}"):
            return value[2:-1]
        return value

    def render(self, text: str) -> list[Slot]:
        slots: list[Slot] = []
        i, n = 0, len(text)
        literal_start = 0

        def flush(upto: int):
            for _ in range(literal_count(text[literal_start:upto])):
                slots.append(Slot())

        while i < n:
            if text[i] != "$":
                i += 1
                continue
            flush(i)
            i, new = self.token(text, i)
            slots.extend(new)
            literal_start = i
        flush(n)
        return slots

    def token(self, text: str, i: int) -> tuple[int, list[Slot]]:
        """Parses the token starting at text[i] == '$'. Returns (next index, slots)."""
        n = len(text)
        j = i + 1
        if j >= n:
            return j, []
        ch = text[j]
        if ch == "{":
            end = match_brace(text, j, "{", "}")
            expr = text[j + 1:end]
            k = end + 1
            m = re.match(r"\.\d", text[k:])
            if m:
                k += 2
            return k, [self.expr_slot(expr)]
        if ch == "?":
            return self.conditional(text, j + 1)
        if ch == "<":
            end = text.index(">", j)
            name = text[j + 1:end]
            return end + 1, [self.expr_slot(self.var_expr(name))]
        if ch == "@":
            m = re.match(r"@(\w+?)(\d+)", text[j:])
            if m and m.group(1) == "spelldesc" and self.depth < 3:
                other = m.group(2)
                inner = Template(self.data, other, self.depth + 1).render(
                    self.data.spell.get(other, {}).get("Description_lang", ""))
                return j + m.end(), inner
            if m and m.group(1) in ("spellname", "spellicon", "spelltooltip"):
                if m.group(1) == "spelltooltip":
                    raise Unsupported("spelltooltip")
                return j + m.end(), []
            raise Unsupported(f"@ token {text[j:j + 20]!r}")
        if ch in "lLgG":
            end = text.find(";", j)
            if end < 0:
                raise Unsupported("unterminated $l/$g")
            return end + 1, []
        if ch in "/*":
            m = re.match(r"([/*])(\d+(?:\.\d+)?);(\d*)([a-zA-Z])(\d?)", text[j:])
            if not m:
                raise Unsupported(f"scaled token {text[i:i + 15]!r}")
            factor = float(m.group(2))
            slot = self.simple(m.group(3) or self.spell_id, m.group(4), int(m.group(5) or 0))
            for s in slot:
                if s.var:
                    s.coef = s.coef / factor if m.group(1) == "/" else s.coef * factor
            return j + m.end(), slot
        m = re.match(r"(\d*)([a-zA-Z])(\d?)", text[j:])
        if not m:
            return j, []  # a lone "$" in text
        return j + m.end(), self.simple(m.group(1) or self.spell_id, m.group(2), int(m.group(3) or 0))

    def simple(self, spell_id: str, letter: str, index: int) -> list[Slot]:
        if spell_id != self.spell_id and spell_id not in self.data.spell and spell_id not in self.data.effects:
            raise Unsupported(f"unknown spell {spell_id}")
        if letter in VALUE_LETTERS:
            idx = index or 1
            e = self.data.effect(spell_id, idx)
            if not e:
                raise Unsupported(f"missing effect {spell_id}:{idx}")
            var, c = self.data.coef(spell_id, idx)
            if letter in "oO":
                ticks = self.data.ticks(spell_id, idx)
                if ticks <= 0:
                    raise Unsupported(f"$o without ticks on {spell_id}:{idx}")
                return [Slot(var, c * ticks)]
            if letter == "s" and num(e.get("Variance", "0")) > 0:
                return [Slot(var, c, n=2)]
            return [Slot(var, c)]
        if letter in FIXED_LETTERS:
            return [Slot()]
        if letter in "zZ":
            return []
        raise Unsupported(f"token ${letter}")

    def conditional(self, text: str, j: int) -> tuple[int, list[Slot]]:
        """$?cond[a]?cond2[b][c] -> renders the last (no-condition) branch.

        The live tooltip may show another branch; every branch normally shows the same
        numbers, and the count check in the addon catches the rest."""
        n = len(text)
        branches = []
        k = j
        while k < n:
            if text[k] == "[":
                end = match_brace(text, k, "[", "]")
                branches.append(text[k + 1:end])
                k = end + 1
                if k < n and text[k] == "?":
                    k += 1
                    continue
                if k < n and text[k] == "[":
                    continue
                break
            k += 1
        if not branches:
            raise Unsupported("conditional without branches")
        counts = set()
        rendered = None
        for b in branches:
            try:
                r = self.render(b)
            except Unsupported:
                continue
            counts.add(sum(s.n for s in r))
            rendered = r
        if rendered is None:
            raise Unsupported("no renderable branch")
        if len(counts) > 1:
            raise Unsupported("branches show different numbers")
        return k, rendered


def match_brace(text: str, start: int, open_ch: str, close_ch: str) -> int:
    depth = 0
    for k in range(start, len(text)):
        if text[k] == open_ch:
            depth += 1
        elif text[k] == close_ch:
            depth -= 1
            if depth == 0:
                return k
    raise Unsupported("unbalanced brackets")


# --- Build ---------------------------------------------------------------------------------

def build(folder: Path):
    data = Data(folder)
    spells: dict[int, str] = {}
    reasons: dict[str, int] = defaultdict(int)
    considered = 0
    for spell_id in sorted(data.class_spells, key=int):
        row = data.spell.get(spell_id)
        if not row or not row["Description_lang"].strip():
            continue
        if not any(data.coef(spell_id, idx)[1] > 0 for idx in data.effects.get(spell_id, {})):
            # Also allow spells whose text uses another spell's scaling numbers, or attack power.
            if not re.search(r"\$\d+[sSoOmM]|\$(AP|apm|RAP|rap)\b", row["Description_lang"]):
                continue
        considered += 1
        try:
            slots = Template(data, spell_id).render(row["Description_lang"])
        except Unsupported as exc:
            reasons[str(exc).split(" ")[0]] += 1
            continue
        if not any(s.var for s in slots):
            reasons["no-scaling-number"] += 1
            continue
        spells[int(spell_id)] = " ".join(s.encode() for s in slots)
    return data, spells, considered, reasons


# Weapon strikes: abilities whose damage comes from the weapon, attack power or block value
# (Sinister Strike, Mortal Strike, Auto Shot, Bloodthirst, Shield Slam...). Their tooltips
# show only a fixed part or a percentage, so the addon works the hit out from these codes.
# Weapon codes: the first token says which weapon, then the steps in effect order:
#   "m" main hand, "r" ranged, "o" off-hand, "b" both hands (main hand plus off-hand hit)
#   "w+16"  weapon damage (the weapon's own speed for attack power) plus 16
#   "n+68"  the same with normalized speed (instant attacks)
#   "*1.5"  150% weapon damage (also multiplies the fixed amounts before it)
# Other codes:
#   "a 0.45+48"  45% of attack power plus 48 ("ra": ranged attack power)
#   "k 655"      655 plus block value
WEAPON_EFFECTS = {"17": "w", "58": "w", "121": "n"}
WEAPON_PERCENT = "31"
TRIGGER_EFFECTS = {"64", "3"}  # trigger spell, dummy (the work is done by the spell it names)
AP_PCT_RE = re.compile(r"\$s(\d)% of your (ranged )?attack power(?: plus \$s(\d))?", re.I)
BLOCK_RE = re.compile(r"\$s(\d) damage, increased by your block value", re.I)
# "$s2% weapon damage per existing application" (Lacerate) is a stacking extra, not the hit.
PCT_WEAPON_RE = re.compile(r"\$s(\d)% (?:of )?(?:off-hand )?weapon damage(?! per )", re.I)
PLAIN_WEAPON_RE = re.compile(r"\bweapon damage\b", re.I)
BOTH_RE = re.compile(r"\bboth (?:melee )?weapons\b", re.I)
OFF_HAND_RE = re.compile(r"\boff-hand weapon\b", re.I)


def weapon_steps(data: Data, spell_id: str, desc: str, depth: int = 0) -> list[str]:
    effects = data.effects.get(spell_id, {})
    # A percentage named only in the text (Devastate) counts when no effect carries it already.
    has_percent = any(e["Effect"] == WEAPON_PERCENT for e in effects.values())
    pct_in_text = set()
    if depth == 0 and not has_percent:
        pct_in_text = {int(m.group(1)) for m in PCT_WEAPON_RE.finditer(desc)}
    steps = []
    for index in sorted(effects):
        e = effects[index]
        if e["Effect"] in WEAPON_EFFECTS:
            steps.append(f"{WEAPON_EFFECTS[e['Effect']]}+{int(round(num(e['EffectBasePointsF'])))}")
        elif e["Effect"] == WEAPON_PERCENT or index in pct_in_text:
            steps.append(f"*{num(e['EffectBasePointsF']) / 100:g}")
    if not steps and depth == 0:
        # A castable spell that hands the work to another one (Mutilate).
        for index in sorted(effects):
            e = effects[index]
            trigger = e.get("EffectTriggerSpell", "0")
            if e["Effect"] in TRIGGER_EFFECTS and trigger not in ("", "0"):
                steps = weapon_steps(data, trigger, "", depth + 1)
                if steps:
                    break
    return steps


def strike(data: Data, spell_id: str, scaled: bool) -> str | None:
    if data.skill_line_name.get(spell_id, "").startswith("Pet"):
        return None
    desc = data.spell.get(spell_id, {}).get("Description_lang", "")
    if not desc.strip():
        # A rank with no text of its own counts only when its spell's text says it strikes with
        # both weapons (Mutilate's ranks); other text-less spells are hidden helpers.
        desc = data.description_by_name.get(data.names.get(spell_id, ""), "")
        if not BOTH_RE.search(desc):
            return None
    effects = data.effects.get(spell_id, {})

    def base(index: int) -> float | None:
        e = effects.get(index)
        return num(e["EffectBasePointsF"]) if e else None

    physical = data.school_mask(spell_id) == 1
    m = AP_PCT_RE.search(desc)
    if m and physical and base(int(m.group(1))):
        fixed = base(int(m.group(3))) if m.group(3) else 0
        return f"{'ra' if m.group(2) else 'a'} {base(int(m.group(1))) / 100:g}+{int(round(fixed or 0))}"
    m = BLOCK_RE.search(desc)
    if m and physical and base(int(m.group(1))) is not None:
        return f"k {int(round(base(int(m.group(1)))))}"
    if scaled:
        return None  # its tooltip number already grows with spell damage or attack power
    steps = weapon_steps(data, spell_id, desc)
    if not steps and not PLAIN_WEAPON_RE.search(desc):
        return None
    if re.search(r"weapon damage per ", desc, re.I) and not any(step[0] in "wn" for step in steps):
        return None
    if not any(step[0] in "wn" for step in steps):
        if not steps and not re.search(r"normal (?:off-hand )?weapon damage", desc, re.I):
            return None
        steps.insert(0, "w+0")  # percent of weapon damage only (Riposte), or plain weapon damage (Shiv)
    if BOTH_RE.search(desc):
        side = "b"
    elif OFF_HAND_RE.search(desc) or re.search(r"off-hand weapon damage", desc, re.I):
        side = "o"
    elif re.search(r"\branged weapon\b", desc, re.I) or (
            data.misc.get(spell_id, {}).get("RangeIndex") not in ("1", "2")
            and data.skill_line_name.get(spell_id) == "Marksmanship"):
        side = "r"
    else:
        side = "m"
    return side + " " + " ".join(steps)


def build_strikes(data: Data, spells: dict[int, str]) -> dict[int, str]:
    strikes = {}
    for spell_id in sorted(data.class_spells, key=int):
        code = strike(data, spell_id, int(spell_id) in spells)
        if code:
            strikes[int(spell_id)] = code
    return strikes


def write_lua(path: Path, build_id: str, spells: dict[int, str], strikes: dict[int, str]):
    lines = [
        "-- GENERATED by scripts/extract_spelldata.py from World of Warcraft game data",
        f"-- (client {build_id}). Do not edit by hand. Numeric facts (c) Blizzard Entertainment.",
        "--",
        "-- One string per spell: one slot per number its tooltip shows, in order.",
        '-- "h:0.856" = +0.856 per point of healing bonus, "6:0.428" = per point of shadow',
        '-- damage bonus (2 holy .. 7 arcane), "*2" = a "min to max" pair of numbers,',
        '-- "0" = a number that does not grow with bonuses. "ap:0.15" = per point of attack power',
        '-- ("rap": ranged attack power).',
        '--',
        '-- strikes: abilities whose damage comes from the weapon, attack power or block value.',
        '-- "m"/"r"/"o"/"b" = main hand, ranged, off-hand, both hands; then in effect order',
        '-- "w+16" = weapon damage plus 16, "n+68" = the same at normalized weapon speed,',
        '-- "*1.5" = 150% weapon damage (also multiplies the fixed amounts before it).',
        '-- "a 0.45+48" = 45% of attack power plus 48 ("ra": ranged); "k 655" = 655 plus block value.',
        "local _, ns = ...",
        "",
        "ns.SpellData = {",
        f'\tbuild = "{build_id}",',
        "\tspells = {",
    ]
    for sid in sorted(spells):
        lines.append(f'\t\t[{sid}] = "{spells[sid]}",')
    lines += ["\t},", "\tstrikes = {"]
    for sid in sorted(strikes):
        lines.append(f'\t\t[{sid}] = "{strikes[sid]}",')
    lines += ["\t},", "}", ""]
    path.write_text("\n".join(lines), encoding="utf-8", newline="\n")


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("folder", type=Path, help="folder with the exported CSV files")
    parser.add_argument("--out", type=Path, default=Path(__file__).resolve().parent.parent / "SpellData.lua")
    parser.add_argument("--build", default=None, help="client build (default: folder name)")
    parser.add_argument("--report", action="store_true", help="print why spells were skipped")
    args = parser.parse_args(argv)
    data, spells, considered, reasons = build(args.folder)
    build_id = args.build or args.folder.name
    strikes = build_strikes(data, spells)
    write_lua(args.out, build_id, spells, strikes)
    print(f"{len(spells)} of {considered} scaling class spells and {len(strikes)} weapon strikes "
          f"written to {args.out}")
    if args.report:
        for reason, count in sorted(reasons.items(), key=lambda kv: -kv[1]):
            print(f"  skipped {count:5d}: {reason}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
