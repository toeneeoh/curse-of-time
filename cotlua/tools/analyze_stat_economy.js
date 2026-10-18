// Offline balance scenarios. No gameplay source, map, or player saves are changed.
// Run from the repository root: node cotlua/tools/analyze_stat_economy.js
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const root = path.resolve(__dirname, '../..');
const read = p => fs.readFileSync(path.join(root, p), 'utf8');
const progression = read('cotlua/src/gameplay/players/progression.lua');
const tomeSource = read('cotlua/src/gameplay/economy/tomes.lua');
const questSource = read('cotlua/src/gameplay/world/quests.lua');
const historical = execFileSync('git', ['show', '05f327f^:cotlua/src/helper.lua'],
    { cwd: root, encoding: 'utf8' });
function requireFormula(condition, label) {
    if (!condition) throw new Error(`Source formula changed: ${label}; update this model.`);
}
requireFormula(historical.includes('bonus * 17.2 // Pow(totalStats, 0.35)'), 'historical tomes');
requireFormula(historical.includes('IMaxBJ(250,') && historical.includes('IMaxBJ(50,'), 'historical floors');
requireFormula(tomeSource.includes('100 // (projected ^ 0.25)')
    && tomeSource.includes('math.log(cap / projected + 0.75, 2.71828) / 3.'), 'current tomes');
requireFormula(progression.includes('20 + 13. * level * 1.4 ^ (level / 20)')
    && progression.includes('economy_value ^ 0.94'), 'current gold');
requireFormula(questSource.includes('kq.gold_value * 0.5'), 'kill quest gold');
requireFormula(read('cotlua/src/gameplay/persistence/profile.lua')
    .includes('level ^ 4 * 0.000003 + 10 * level + level ^ 3 * 0.0005'), 'stat cap');
const constant = (source, key) => {
    const match = source.match(new RegExp(`\\b${key}\\s*=\\s*([0-9.]+)`));
    if (!match) throw new Error(`Missing constant ${key}`);
    return Number(match[1]);
};
const maxLevel = constant(read('cotlua/src/config/variables.lua'), 'MAX_LEVEL');
const xpPerLevel = constant(progression, 'XP_PER_LEVEL');
const soloBonus = constant(progression, 'SOLO_PARTY_BONUS');
const startKills = constant(progression, 'STARTING_KILLS_PER_LEVEL');
const linearKills = constant(progression, 'LINEAR_KILL_GROWTH');
const lateKills = constant(progression, 'LATE_KILL_GROWTH');
const questXP = constant(questSource, 'KILL_QUEST_XP_SHARE');
const source = read('cotlua/src/config/hero_definitions.lua');
const heroes = [...source.matchAll(/\[(HERO_\w+)\]\s*=\s*\{([\s\S]*?)\n\s*\},/g)]
    .map(match => {
        const get = key => constant(match[2], key);
        return {
            name: match[1].replace('HERO_', ''),
            base: get('str') + get('agi') + get('int'),
            growth: get('str_gain') + get('agi_gain') + get('int_gain')
                - (match[1] === 'HERO_OBLIVION_GUARD' ? 0.3 : 0),
        };
    });
requireFormula(heroes.length === 19, 'roster count');
// Override verified against native map data: Oblivion Guard STR gain is 3.2.
// Its inherited INT gain uses the available legacy Mountain King default 1.5.
function cap(level) {
    return Math.floor(0.000003 * level ** 4 + 0.0005 * level ** 3 + 10 * level);
}
function bandGold(level, questCoverage) {
    const progress = (level - 1) / Math.max(1, maxLevel - 1);
    const kills = startKills + linearKills * progress + lateKills * progress ** 2;
    const xp = Math.floor(xpPerLevel / (kills * soloBonus) + 0.5);
    const gold = Math.floor(20 + 13 * level * 1.4 ** (level / 20)) ** 0.94;
    return xpPerLevel * gold * (1 + 0.5 * questCoverage)
        / (xp * (soloBonus + questXP * questCoverage));
}
function quote(kind, level, total, iterations, allStats, clampLegacy) {
    const multiplier = allStats ? 3 : 1;
    if (kind === 'old') {
        const scaledTotal = Math.max(level > 25 ? 250 : 50, total);
        if (scaledTotal > cap(level)) return 0;
        const bonus = Math.floor(172 * iterations / scaledTotal ** 0.35);
        // The historical function allowed the last purchase to overshoot the cap.
        // The optional clamp provides a comparison excluding that old loophole.
        return clampLegacy ? Math.min(bonus,
            Math.max(0, Math.floor((cap(level) - total) / multiplier))) : bonus;
    }
    if (total >= cap(level)) return 0;
    let bonus = 0;
    for (let i = 0; i < iterations; i++) {
        const projected = total + bonus * multiplier;
        bonus += Math.floor(100 / projected ** 0.25)
            * Math.log(cap(level) / projected + 0.75) / Math.log(2.71828) / 3;
        if (total + bonus * multiplier >= cap(level)) {
            bonus = (cap(level) - total) / multiplier;
            break;
        }
    }
    return Math.floor(bonus);
}
function simulate(hero, kind, options) {
    const { share, questCoverage = 1, allStats = false, bundled = true,
        clampLegacy = false, growth = hero.growth, goldFind = 0 } = options;
    const price = allStats ? 20000 : 10000;
    let allowance = 0, earned = 0, bought = 0, spent = 0;
    const trace = {};
    for (let level = 2; level <= 180; level++) {
        const income = bandGold(level - 1, questCoverage) * (1 + goldFind);
        earned += income;
        allowance += share * income;
        const natural = hero.base + growth * (level - 1);
        let guard = 0;
        while (allowance >= price) {
            if (++guard > 10000) throw new Error('Purchase loop did not converge');
            let iterations = 1;
            if (bundled) {
                iterations = kind === 'old'
                    ? (level >= 100 && allowance >= price * 100 ? 100 : 1)
                    : [10000, 1000, 100, 10, 1].find(n => allowance >= price * n);
            }
            const gain = quote(kind, level, natural + bought,
                iterations, allStats, clampLegacy);
            if (gain <= 0) break;
            allowance -= price * iterations;
            spent += price * iterations;
            bought += gain * (allStats ? 3 : 1);
        }
        trace[level] = { earned, spent, allowance, bought, natural, total: natural + bought };
    }
    return trace;
}
// Independently verify the JS quote against the actual Lua TomeService source.
// This stubs the game-facing reads only; quote() runs unchanged.
const luaCases = [
    { level: 25, total: 156.5, iterations: 1, all: false, bundle: 1 },
    { level: 50, total: 286.8, iterations: 10, all: false, bundle: 2 },
    { level: 100, total: 1200, iterations: 100, all: true, bundle: 3 },
    { level: 180, total: 7600, iterations: 100, all: true, bundle: 3 },
];
const lua = 'C:/Program Files/lua5.3.6/lua53.exe';
let verified = false;
if (fs.existsSync(lua)) {
    const cases = luaCases.map(c => `{${c.level},${c.total},${c.bundle},${c.all ? 4 : 1}}`).join(',');
    const harness = `
OnInit={final=function(_,f)f(function()end)end}
FourCC=function(s)return s end
Hero={[1]=1}; Unit={[1]={str=0,agi=0,int=0}}
Profile={[1]={hero={unit_id=1}}}
HERO_STATS={[1]={str=0,agi=0,int=0}}
StatAllocation={get=function()return {}end}
StatAllocationModel={budget=function()return Unit[1].str end}
GetItem=function(id)return nil,id end
GetHeroLevel=function()return level end
GetCurrency=function()return 1e12 end
GOLD=0; PLATINUM=1
TomeCap=function(l)return math.floor(l^4*.000003+10*l+l^3*.0005)end
dofile('cotlua/src/gameplay/economy/tomes.lua')
-- Preserve the pre-allocation Knowledge branch for this historical replay.
TomeService.types.I0TT=4
for _,c in ipairs({${cases}}) do
level=c[1]; Unit[1].str=c[2]
print(TomeService.quote(1,c[4]==4 and 'I0TT' or 'I0TS',c[3]).gain)
end
`;
    const values = execFileSync(lua, ['-'], { cwd: root, input: harness, encoding: 'utf8' })
        .trim().split(/\s+/).map(Number);
    luaCases.forEach((c, i) => {
        const expected = quote('current', c.level, c.total, c.iterations, c.all, false);
        if (expected !== values[i]) throw new Error(`Lua quote differs: ${expected} vs ${values[i]}`);
    });
    verified = true;
}
const milestones = [25, 50, 75, 100, 150, 180];
const mean = values => values.reduce((a, b) => a + b, 0) / values.length;
const scenarios = [];
for (const share of [0.25, 0.5, 1]) {
    for (const allStats of [false, true]) {
        const old = heroes.map(h => simulate(h, 'old', { share, allStats }));
        const controlled = heroes.map(h => simulate(h, 'old', { share, allStats, clampLegacy: true }));
        const current = heroes.map(h => simulate(h, 'current', { share, allStats }));
        scenarios.push({ share, tome: allStats ? 'knowledge' : 'single', milestones: milestones.map(level => {
            const oldBought = mean(old.map(s => s[level].bought));
            const currentBought = mean(current.map(s => s[level].bought));
            return { level, gold: old[0][level].earned,
                oldBought, oldCapControlledBought: mean(controlled.map(s => s[level].bought)),
                currentBought, gap: oldBought - currentBought,
                extraPointsPerLevel: (oldBought - currentBought) / (level - 1),
                oldTotal: mean(old.map(s => s[level].total)),
                currentTotal: mean(current.map(s => s[level].total)) };
        }) });
    }
}
const replacements = [6, 7, 8, 9, 10].map(growth => {
    const current = heroes.map(h => simulate(h, 'current', { share: 0.5, growth }));
    return { growth, milestones: milestones.map(level => ({ level,
        total: mean(current.map(s => s[level].total)),
        bought: mean(current.map(s => s[level].bought)) })) };
});
const sensitivity = [];
for (const questCoverage of [0, 0.5, 1]) {
    for (const goldFind of [0, 0.2]) {
        for (const bundled of [false, true]) {
            const old = heroes.map(h => simulate(h, 'old', { share: 0.5, questCoverage, goldFind, bundled }));
            const current = heroes.map(h => simulate(h, 'current', { share: 0.5, questCoverage, goldFind, bundled }));
            sensitivity.push({ questCoverage, goldFind, bundled,
                milestones: [25, 50, 100, 180].map(level => ({ level,
                    gold: old[0][level].earned,
                    gap: mean(old.map((s, i) => s[level].bought - current[i][level].bought)) })) });
        }
    }
}
const report = {
    assumptions: { model: 'Equal-level solo normal kills; quest rewards amortized across kills.',
        purchaseTiming: 'Visit shop after each level gained; reserve the selected share of gross gold.',
        excluded: ['boss loot and gold', 'sales', 'mining', 'Colosseum', 'one-off quest XP',
            'party play', 'travel and turn-in timing', 'XP bonuses', 'native attribute rounding'],
        goldRandomization: 'Use mean multiplier 1; omit sub-gold reward flooring.',
        legacySource: '05f327f^:cotlua/src/helper.lua',
        currentQuoteVerifiedAgainstLua: verified },
    roster: { count: heroes.length, meanStartingStats: mean(heroes.map(h => h.base)),
        meanGrowth: mean(heroes.map(h => h.growth)) },
    noPurchaseQuotes: milestones.map(level => ({ level,
        old: mean(heroes.map(h => quote('old', level, h.base + h.growth * (level - 1), 1, false, false))),
        current: mean(heroes.map(h => quote('current', level, h.base + h.growth * (level - 1), 1, false, false))) })),
    scenarios, replacements, sensitivity,
};
process.stdout.write(JSON.stringify(report, null, 2) + '\n');
