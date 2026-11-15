private _category = "JTAC Support";

[
    "EPDJtacDebug",
    "CHECKBOX",
    ["Debug mode", "Skips the delay before a strike and the reload of every support category."],
    [_category, "General"],
    true,
    1
] call CBA_fnc_addSetting;

[
    "EPDJtacAquisitionFixedTime",
    "SLIDER",
    ["Fixed acquisition time", "0 uses the time of each attack. Above 0 every strike takes this many seconds to acquire."],
    [_category, "General"],
    [0, 60, 0, 1],
    1
] call CBA_fnc_addSetting;

[
    "EPDJtacAquisitionGlobalModifier",
    "SLIDER",
    ["Acquisition time multiplier", "Used while the fixed time is 0. 1 keeps the time of each attack."],
    [_category, "General"],
    [0.1, 10, 1, 2],
    1
] call CBA_fnc_addSetting;

[
    "EPDJtacGuidedMissileExplosiveFailureChance",
    "SLIDER",
    ["Missile blows up in flight, %", "Chance that a guided missile explodes before it reaches the target."],
    [_category, "Guided missiles"],
    [0, 100, 1, 1],
    1
] call CBA_fnc_addSetting;

[
    "EPDJtacGuidedMissileLostTrackingFailureChance",
    "SLIDER",
    ["Missile loses the target, %", "Chance that a guided missile loses its guidance and flies on straight."],
    [_category, "Guided missiles"],
    [0, 100, 1, 1],
    1
] call CBA_fnc_addSetting;

DB_JTAC_ReloadDefaults = [
    ["BULLETS", "Bullets", 100, 60, 60],
    ["SHELLS", "Shells", 100, 60, 60],
    ["STRAFINGRUN", "Strafing run", 100, 60, 60],
    ["BOMBS", "Bombs", 100, 1, 1],
    ["ROCKETS", "Rockets and cruise missiles", 100, 1, 1],
    ["GUIDEDMISSILE", "Guided missiles", 100, 1, 1],
    ["MINES", "Mines", 100, 60, 60],
    ["SMOKE", "Smoke", 100, 60, 60],
    ["NIGHT", "Night", 100, 60, 60],
    ["DRONES", "Drones", 100, 60, 60]
];

DB_fnc_jtacApplyReloadSettings = {
    EPDJtacReloads = DB_JTAC_ReloadDefaults apply {
        _x params ["_id", "", "_defaultCapacity", "_defaultShortReload", "_defaultLongReload"];
        private _settingPrefix = format ["DB_JTAC_Reload_%1", _id];

        [
            _id,
            missionNamespace getVariable [_settingPrefix + "_Capacity", _defaultCapacity],
            missionNamespace getVariable [_settingPrefix + "_Short", _defaultShortReload],
            missionNamespace getVariable [_settingPrefix + "_Long", _defaultLongReload]
        ]
    };

    if (isNil "EPDJtacCategories") exitWith {};

    {
        _x params ["_id", "_capacity", "_shortReload", "_longReload"];
        private _index = EPDJtacCategories find _id;

        if (_index != -1) then {
            EPDJtacCapacities set [_index, _capacity];
            EPDJtacShortReloadTimes set [_index, _shortReload];
            EPDJtacLongReloadTimes set [_index, _longReload];
        };
    } forEach EPDJtacReloads;
};

{
    _x params ["_id", "_displayName", "_defaultCapacity", "_defaultShortReload", "_defaultLongReload"];
    private _settingPrefix = format ["DB_JTAC_Reload_%1", _id];
    private _applyReloadSettings = {call DB_fnc_jtacApplyReloadSettings};

    [
        _settingPrefix + "_Capacity",
        "SLIDER",
        [format ["%1: capacity", _displayName], "Total capacity the calls may use before the long reload."],
        [_category, "Reload"],
        [1, 1000, _defaultCapacity, 0],
        1,
        _applyReloadSettings
    ] call CBA_fnc_addSetting;

    [
        _settingPrefix + "_Short",
        "TIME",
        [format ["%1: short reload", _displayName], "Delay after a call that left capacity."],
        [_category, "Reload"],
        [0, 3600, _defaultShortReload],
        1,
        _applyReloadSettings
    ] call CBA_fnc_addSetting;

    [
        _settingPrefix + "_Long",
        "TIME",
        [format ["%1: long reload", _displayName], "Delay once the capacity is used up."],
        [_category, "Reload"],
        [0, 3600, _defaultLongReload],
        1,
        _applyReloadSettings
    ] call CBA_fnc_addSetting;
} forEach DB_JTAC_ReloadDefaults;

call DB_fnc_jtacApplyReloadSettings;

/*
    ["payloadCategory", "displayName", "acquireRate", "capacityUsed", "projectileFiringMethod", [firing method parameters...]]

    payloadCategory - One of "BULLETS", "SHELLS", "STRAFINGRUN", "BOMBS", "ROCKETS", "GUIDEDMISSILE", "MINES", "SMOKE", "NIGHT" or "DRONES". Determines which Jtac menu the payload will show up in.

    displayName - Name of the payload that will be presented to the operator.

    acquireRate - Seconds required to aquire a target.

    capacityUsed - The amount of the remaining capacity the attack will use. When the capacity is reached a long reload is triggered.

    projectileFiringMethod - One of "SHOOT_PROJECTILES", "DROP_BOMBS", "FIRE_ROCKETS", "EVEN_SPREAD_PROJECTILES", "STRAFING_RUN_ROCKET", "STRAFING_RUN_PROJECTILE", "LAY_MINE_FIELD", "FIRE_DRONE". Determines which method will be used to send the payload to the target.

    SHOOT_PROJECTILES, DROP_BOMBS, STRAFING_RUN_* and FIRE_DRONE guide every round in a straight line
    to a random point of the spread (Attacks\Guide.sqf), whatever the drag of its ammo class.

        SHOOT_PROJECTILES - Projectiles fly in from about 2.2 km away.
            parameters - [_projectileClassName, _numberToSend, _verticalOffset, _spreadRadial, _spreadNormal, _minTimeBetween, _maxRandomTime, _height, _distance, _speed]
                _projectileClassName - Classname of the projectile to use.
                _numberToSend - How many projectiles to shoot.
                _verticalOffset - Unused since the rounds are guided; kept so old lists still fit.
                _spreadRadial - Rounds land anywhere in a circle of this radius around the target.
                _spreadNormal - Rounds land up to this many meters above or below the target.
                _minTimeBetween - Minimum time between shots.
                _maxRandomTime  - A random value of up to this value is added to the _minTimeBetween variable to provide some variable time between shots.
                _height - Optional starting height for the projectile.
                _distance - Optional starting distance for the projectile.
                _speed - Optional speed of the projectile.

        DROP_BOMBS - Bombs come in from about 3.9 km away and 1300 m up.
            parameters - [_projectileClassName, _numberToSend, _initialSpeed, _speedVariance, _spreadRadial, _minTimeBetween, _maxRandomTime, _useImpactSpread, _sourceDistance]
                _projectileClassName - Classname of the projectile to use.
                _numberToSend - How many bombs to drop.
                _initialSpeed - How fast the bomb is going.
                _speedVariance - The speed of the bomb will be adjusted by up to this much.
                _spreadRadial - Bombs land anywhere in a circle of this radius around the target.
                _minTimeBetween - Minimum time between shots.
                _maxRandomTime  - A random value of up to this value is added to the _minTimeBetween variable to provide some variable time between shots.
                _useImpactSpread - Unused, the spread is always at the target; kept so old lists still fit.
                _sourceDistance - Optional horizontal distance from the target.

        FIRE_ROCKETS - Spawns a missile. Sets the correct orientation and sets the correct model orientation.
            parameters - [_projectileClassName, _numberToSend, _horizontalDistance, _pitch, _pitchVariance, _yawVariance, _minTimeBetween, _maxRandomTime]
                _projectileClassName - Classname of the projectile to use.
                _numberToSend - How many rockets to fire.
                _horizontalDistance - How far away the missile spawns.
                _pitch - The pitch the model must be angled to to hit.
                _pitchVariance - How much the pitch can be varied, This will cause the missile to undershoot or overshoot.
                _yawVariance - How much the yaw can be varied, this will cause the missile to land to the left or right.
                _minTimeBetween - Minimum time between shots.
                _maxRandomTime  - A random value of up to this value is added to the _minTimeBetween variable to provide some variable time between shots.

        STRAFING_RUN_ROCKET - Spawns a run of rockets.
            parameters - [_projectileClassName, _numberToSend, _distanceToStrafe, _horizontalDistance, _pitch, _spread, _minTimeBetween, _maxRandomTime]
                _projectileClassName - Classname of the projectile to use.
                _numberToSend - How many rockets to fire.
                _distanceToStrafe - How far the run should go.
                _horizontalDistance - How far away the rockets spawn.
                _pitch - The angle the rockets dive in at.
                _spread - How many meters in each direction the rockets can land from their desired location.
                _minTimeBetween - Minimum time between shots.
                _maxRandomTime  - A random value of up to this value is added to the _minTimeBetween variable to provide some variable time between shots.

        STRAFING_RUN_PROJECTILE - Spawns a run of projectiles.
            parameters - [_projectileClassName, _numberToSend, _verticalOffset, _distanceToStrafe, _spread, _minTimeBetween, _maxRandomTime]
                _projectileClassName - Classname of the projectile to use.
                _numberToSend - How many rounds to fire.
                _verticalOffset - Unused since the rounds are guided; kept so old lists still fit.
                _distanceToStrafe - How far the run should go.
                _spread - How many meters in each direction the rounds can land from their desired location.
                _minTimeBetween - Minimum time between shots.
                _maxRandomTime  - A random value of up to this value is added to the _minTimeBetween variable to provide some variable time between shots.

        EVEN_SPREAD_PROJECTILES - Spawns 12 of the items randomly above the target and flings them down. Creates an evenly space inner triangle and an evenly space outer nonagon.
            parameters - [[_projectileClassName, _projectileClassName,_projectileClassName,...], _spreadRadial, _downwardSpeed, _spawnHeight]
                _projectileClassName - Classname of the projectile to use. 1 or more of these can be passed in.
                _spreadRadial - Radius of the horizontal inaccuracy. Projectiles can land anywhere in a circle of this radius around the target.
                _downwardSpeed - Initial downward velocity before gravity kicks in.
                _spawnHeight - Height above the terran that the projectile will spawn.

        LAY_MINE_FIELD - Spawns a mine field.
            parameters - [[_mineClassName, _mineClassName,...], _numberToSend,  _spreadRadial]
                _projectileClassName - Classname of the projectile to use. 1 or more of these can be passed in.
                _numberToSend - How many mines to lay.
                _spreadRadial - How far the mines can spawn from the target.

        FIRE_DRONE - Attack drones of other mods, see Attacks\Drones.sqf.
            parameters - [_droneClassName, _warheadClassName, _numberToSend, _speed, _distance, _height, _spreadRadial, _minTimeBetween, _maxRandomTime]
*/

DB_JTAC_AttackDefaults = [
    ["BULLETS", "20mm Cannon", 10, 2, "SHOOT_PROJECTILES", ["B_20mm", 40, 10, 15, 5, .05, .05]],
    ["BULLETS", "20mm HE Burst", 10, 2, "SHOOT_PROJECTILES", ["G_20mm_HE", 30, 15, 20, 10, .05, .05]],
    ["BULLETS", "30mm HE Strike", 12, 3, "SHOOT_PROJECTILES", ["B_30mm_HE", 25, 10, 15, 8, .08, .1]],
    ["BULLETS", "40mm HEDP (Auto)", 16, 4, "SHOOT_PROJECTILES", ["G_40mm_HEDP", 20, 20, 25, 15, .15, .2]],
    ["BULLETS", "40mm HE (Auto)", 16, 4, "SHOOT_PROJECTILES", ["G_40mm_HE", 20, 20, 30, 15, .15, .2]],

    ["SHELLS", "82mm Battery Strike", 18, 3, "SHOOT_PROJECTILES", ["Sh_82mm_AMOS", 6, 23.9, 60, 30, 0.5, 0.5]],
    ["SHELLS", "120mm Battery Strike", 20, 3, "SHOOT_PROJECTILES", ["Sh_120mm_HE", 6, 37.4, 100, 50, 0.8, 1]],
    ["SHELLS", "Krasnopol", 22, 7, "SHOOT_PROJECTILES", ["Sh_155mm_AMOS", 1, 23.9, 5, 2, 0, 0]],
    ["SHELLS", "Excalibur", 22, 7, "SHOOT_PROJECTILES", ["Sh_155mm_AMOS", 1, 23.9, 5, 2, 0, 0]],
    ["SHELLS", "155mm cassette", 24, 7, "SHOOT_PROJECTILES", ["Cluster_155mm_AMOS", 1, 23.9, 8, 8, 2, 1]],

    ["STRAFINGRUN", "20mm - 50 meters", 12, 1, "STRAFING_RUN_PROJECTILE", ["B_20mm", 50, 10, 50, 5, .01, .01]],
    ["STRAFINGRUN", "20mm - 100 meters", 15, 2, "STRAFING_RUN_PROJECTILE", ["B_20mm", 100, 10, 100, 8, .005, .005]],
    ["STRAFINGRUN", "Dagger - 50 meters", 30, 2, "STRAFING_RUN_ROCKET", ["M_AT", 6, 50, 2500, -40, 10, .1, .2]],
    ["STRAFINGRUN", "Dagger - 100 meters", 35, 3, "STRAFING_RUN_ROCKET", ["M_AT", 12, 100, 2500, -40, 15, .1, .2]],
    ["STRAFINGRUN", "Shrieker HE - 50 meters", 30, 2, "STRAFING_RUN_ROCKET", ["Rocket_04_HE_F", 8, 50, 2500, -15, 12, .1, .2]],
    ["STRAFINGRUN", "Shrieker HE - 100 meters", 35, 3, "STRAFING_RUN_ROCKET", ["Rocket_04_HE_F", 16, 100, 2500, -15, 20, .1, .2]],

    ["BOMBS", "UMPK FAB 250", 30, 1, "DROP_BOMBS", ["umpk250", 1, 211.7, 0, 10, 0, 0, true]],
    ["BOMBS", "4x UMPK FAB 250", 30, 1, "DROP_BOMBS", ["umpk250", 4, 211.7, 0.5, 40, 0.5, 1, true]],
    ["BOMBS", "UMPK FAB 500", 30, 1, "DROP_BOMBS", ["umpk500", 1, 211.7, 0, 10, 0, 0, true]],
    ["BOMBS", "UMPK FAB 1500", 30, 1, "DROP_BOMBS", ["umpk1500", 1, 211.7, 0, 10, 0, 0, true, 4500]],
    ["BOMBS", "RBK500 cassette", 30, 1, "DROP_BOMBS", ["BombCluster_03_Ammo_F", 2, 212, 0.5, 60, 0.5, 1, true]],
    ["BOMBS", "500lb GBU12", 30, 1, "DROP_BOMBS", ["Bomb_03_F", 1, 223.5, 0, 5, 0, 0, true]],
    ["BOMBS", "4x 500lb GBU12", 30, 1, "DROP_BOMBS", ["Bomb_03_F", 4, 223.5, 0.5, 40, 0.5, 1, true]],
    ["BOMBS", "1000lb GBU32", 30, 1, "DROP_BOMBS", ["GBU32", 1, 223.5, 0, 5, 0, 0, true, 4500]],
    ["BOMBS", "1500lb GBU54", 30, 1, "DROP_BOMBS", ["GBU54", 1, 223.5, 0, 5, 0, 0, true]],
    ["BOMBS", "580lb cassette", 30, 1, "DROP_BOMBS", ["BombCluster_03_Ammo_F", 1, 212, 0.5, 50, 0, 0, true]],

    ["ROCKETS", "TORNADO-S", 30, 1, "DROP_BOMBS", ["TORNADOS", 12, 240.55, 0.5, 45, 0.8, 1.2, true]],
    ["ROCKETS", "TORNADO-S cassette", 30, 1, "DROP_BOMBS", ["BombCluster_03_Ammo_F", 12, 212, 0.5, 80, 1, 2, true]],
    ["ROCKETS", "TORNADO-G", 30, 1, "DROP_BOMBS", ["TORNADOG", 40, 240.55, 1.5, 200, 0.1, 0.2, true]],
    ["ROCKETS", "ISKANDER", 60, 1, "DROP_BOMBS", ["ISKANDERK", 1, 240.55, 0.2, 7, 0, 0, true]],
    ["ROCKETS", "X101", 60, 1, "FIRE_ROCKETS", ["X101", 1, 3911.5, -17.04, 0.05, 0.05, 0, 0]],
    ["ROCKETS", "X101 cassette", 60, 1, "FIRE_ROCKETS", ["ammo_Missile_Cruise_01_Cluster", 1, 3911.5, -17.04, 0.05, 0.05, 0, 0]],
    ["ROCKETS", "KINJAL", 60, 1, "FIRE_ROCKETS", ["KINJAL", 1, 4135.5, -17.04, 0.01, 0.01, 0, 0]],
    ["ROCKETS", "HIMARS", 30, 1, "DROP_BOMBS", ["TORNADOS", 6, 240.55, 0.5, 30, 1, 2, true]],
    ["ROCKETS", "ATACMS", 60, 1, "DROP_BOMBS", ["ISKANDERK", 1, 240.55, 0.2, 7, 0, 0, true]],
    ["ROCKETS", "TOMAHAWK", 60, 1, "FIRE_ROCKETS", ["X101", 1, 3911.5, -17.04, 0.05, 0.05, 0, 0]],
    ["ROCKETS", "ORESHNIK", 60, 1, "FIRE_ORESHNIK", []],

    ["GUIDEDMISSILE", "Spike LR Laser", 1, 1, "FIRE_GUIDED_MISSILE", ["M_Titan_AT_long", "laser"]],
    ["GUIDEDMISSILE", "Spike LR", 1, 1, "FIRE_GUIDED_MISSILE", ["M_Titan_AT_long", "vehicle"]],
    ["GUIDEDMISSILE", "Kornet AT", 1, 1, "FIRE_GUIDED_MISSILE", ["M_Vorona_HEAT", "laser"]],
    ["GUIDEDMISSILE", "Kornet AP", 1, 1, "FIRE_GUIDED_MISSILE", ["M_Vorona_HE", "laser"]],

    ["MINES", "APERS Mine", 30, 2, "LAY_MINE_FIELD", [["APERSMine"], 20, 20]],
    ["MINES", "APERS Bounding Mine", 30, 2, "LAY_MINE_FIELD", [["APERSBoundingMine"], 20, 20]],
    ["MINES", "APERS Mix", 40, 3, "LAY_MINE_FIELD", [["APERSMine", "APERSBoundingMine"], 20, 20]],
    ["MINES", "Anti-Tank Mine", 30, 2, "LAY_MINE_FIELD", [["ATMine"], 20, 20]],
    ["MINES", "SLAM Directional Mine", 30, 2, "LAY_MINE_FIELD", [["SLAMDirectionalMine"], 20, 20]],
    ["MINES", "Anti-Vehicle Mix", 30, 3, "LAY_MINE_FIELD", [["ATMine", "SLAMDirectionalMine"], 20, 20]],
    ["MINES", "Clear Mine Field", 30, 2, "EVEN_SPREAD_PROJECTILES", [["BombDemine_01_Ammo_F"], 20, -10, 200]],

    ["SMOKE", "White Smoke", 6, 1, "SHOOT_PROJECTILES", ["G_40mm_Smoke",2, 0, 5, 5, 1, 1.6, 75, 6, 25]],
    ["SMOKE", "Blue Smoke", 6, 1, "SHOOT_PROJECTILES", ["G_40mm_SmokeBlue",2, 0, 5, 5, 1, 1.6, 75, 6, 25]],
    ["SMOKE", "Green Smoke", 6, 1, "SHOOT_PROJECTILES", ["G_40mm_SmokeGreen",2, 0, 5, 5, 1, 1.6, 75, 6, 25]],
    ["SMOKE", "Orange Smoke", 6, 1, "SHOOT_PROJECTILES", ["G_40mm_SmokeOrange",2, 0, 5, 5, 1, 1.6, 75, 6, 25]],
    ["SMOKE", "Purple Smoke", 6, 1, "SHOOT_PROJECTILES", ["G_40mm_SmokePurple",2, 0, 5, 5, 1, 1.6, 75, 6, 25]],
    ["SMOKE", "Red Smoke", 6, 1, "SHOOT_PROJECTILES", ["G_40mm_SmokeRed",2, 0, 5, 5, 1, 1.6, 75, 6, 25]],
    ["SMOKE", "Yellow Smoke", 6, 1, "SHOOT_PROJECTILES", ["G_40mm_SmokeYellow",2, 0, 5, 5, 1, 1.6, 75, 6, 25]],
    ["SMOKE", "Small cloud", 10, 2, "EVEN_SPREAD_PROJECTILES", [["G_40mm_Smoke", "G_40mm_SmokeRed", "G_40mm_SmokeBlue", "G_40mm_SmokeGreen", "G_40mm_SmokeOrange", "G_40mm_SmokePurple", "G_40mm_SmokeRed", "G_40mm_SmokeYellow" ], 15, -0.1, 100]],
    ["SMOKE", "Medium cloud", 12, 3, "EVEN_SPREAD_PROJECTILES", [["Smoke_82mm_AMOS_White"], 15, -80, 1000]],
    ["SMOKE", "Large cloud", 14, 4, "EVEN_SPREAD_PROJECTILES", [["Smoke_120mm_AMOS_White"], 35, -80, 1000]],

    ["NIGHT", "Flare Cloud", 10, 1, "EVEN_SPREAD_PROJECTILES", [["F_40mm_White", "F_40mm_Green", "F_40mm_Red", "F_40mm_Yellow"], 35, -0.1, 120]],
    ["NIGHT", "Chem Lights", 10, 1, "EVEN_SPREAD_PROJECTILES", [["Chemlight_blue", "Chemlight_red", "Chemlight_yellow", "Chemlight_green"], 10, -0.1, 120]],
    ["NIGHT", "Strobes", 10, 1, "EVEN_SPREAD_PROJECTILES", [["I_IRStrobe"], 15, -0.1, 120]],
    ["NIGHT", "Night Signal", 10, 1, "EVEN_SPREAD_PROJECTILES", [["Chemlight_blue", "G_40mm_Smoke"], 8, -0.1, 120]],

    // Listed only while the drone's mod is loaded: Geran-3 is the Shahed-238 of
    // "Geran-2 & Shahed-136", Geran-4 the "Geran-4" mod, Krokus comes with ArmaFPV
    ["DRONES", "Geran-3", 30, 1, "FIRE_DRONE", ["shahed_238_CSAT", "lk_shahed_dummy_bomb", 1, 140, 4000, 400, 10, 0, 0]],
    ["DRONES", "Geran-4", 30, 1, "FIRE_DRONE", ["m_geran_dummy", "", 1, 80, 2500, 250, 10, 0, 0]],
    ["DRONES", "Krokus AP", 20, 1, "FIRE_DRONE", ["O_Crocus_AP", "R_TBG32V_F", 1, 30, 800, 60, 3, 0, 0]],
    ["DRONES", "Krokus AT", 20, 1, "FIRE_DRONE", ["O_Crocus_AT", "FPV_RPG42_AT", 1, 30, 800, 60, 3, 0, 0]]
];

DB_JTAC_Attacks = DB_JTAC_AttackDefaults select {
    _x params ["", "", "", "", "_method", "_parameters"];
    _method != "FIRE_DRONE" || {
        private _drone = _parameters select 0;
        private _warhead = _parameters select 1;
        (isClass (configFile >> "CfgVehicles" >> _drone) && {isClass (configFile >> "CfgAmmo" >> _warhead)}) ||
        {isClass (configFile >> "CfgAmmo" >> _drone)}
    }
};

// Each attack's numbers are a CBA setting, in the order of its firing method
// above: acquire time, capacity used, then the numbers of its parameters.
// Class names stay fixed.
DB_JTAC_AttackNumberNames = createHashMapFromArray [
    ["SHOOT_PROJECTILES", "rounds, vertical offset (unused), spread radius m, vertical spread m, min interval s, random interval s, start height m, start distance m, speed m/s"],
    ["DROP_BOMBS", "bombs, speed m/s, speed variance m/s, spread radius m, min interval s, random interval s, start distance m"],
    ["FIRE_ROCKETS", "rockets, start distance m, pitch, pitch variance, yaw variance, min interval s, random interval s"],
    ["STRAFING_RUN_ROCKET", "rockets, run length m, start distance m, dive angle, spread m, min interval s, random interval s"],
    ["STRAFING_RUN_PROJECTILE", "rounds, vertical offset (unused), run length m, spread m, min interval s, random interval s"],
    ["EVEN_SPREAD_PROJECTILES", "spread radius m, downward speed m/s, spawn height m"],
    ["LAY_MINE_FIELD", "mines, spread radius m"],
    ["FIRE_DRONE", "drones, speed m/s, start distance m, start height m, spread radius m, min interval s, random interval s"]
];

DB_fnc_jtacAttackSettingName = {
    params ["_attack"];
    "DB_JTAC_Attack_" + (((_attack select 0) + "_" + (_attack select 1)) regexReplace ["[^A-Za-z0-9]+", "_"])
};

DB_fnc_jtacAttackNumbers = {
    params ["_attack"];
    [_attack select 2, _attack select 3] + ((_attack select 5) select {_x isEqualType 0})
};

DB_fnc_jtacApplyAttackSettings = {
    EPDJtacAvailableAttacks = DB_JTAC_Attacks apply {
        private _attack = +_x;
        private _defaults = [_attack] call DB_fnc_jtacAttackNumbers;
        private _text = missionNamespace getVariable [[_attack] call DB_fnc_jtacAttackSettingName, ""];
        private _fields = (_text splitString ",") apply {trim _x};
        private _numbers = _defaults;
        if (count _fields == count _defaults && {(_fields findIf {!(_x regexMatch "-?([0-9]+\.?[0-9]*|\.[0-9]+)")}) < 0}) then {
            _numbers = _fields apply {parseNumber _x};
        } else {
            if (_text != "") then {
                diag_log format ["VirtualJTAC :::: %1: expected %2 numbers, got ""%3"", defaults kept", _attack select 1, count _defaults, _text];
            };
        };
        _attack set [2, _numbers select 0];
        _attack set [3, _numbers select 1];
        private _next = 1;
        _attack set [5, (_attack select 5) apply {
            if (_x isEqualType 0) then {_next = _next + 1; _numbers select _next} else {_x}
        }];
        _attack
    };
    if (!isNil "PARSE_AVAILABLE_JTAC_ATTACKS") then {call PARSE_AVAILABLE_JTAC_ATTACKS};
};

{
    private _numbers = [_x] call DB_fnc_jtacAttackNumbers;
    private _names = DB_JTAC_AttackNumberNames getOrDefault [_x select 4, ""];
    private _payload = _x select 0;
    private _section = (DB_JTAC_ReloadDefaults select (DB_JTAC_ReloadDefaults findIf {(_x select 0) isEqualTo _payload})) select 1;
    [
        [_x] call DB_fnc_jtacAttackSettingName,
        "EDITBOX",
        [_x select 1, "acquire time s, capacity used" + ([", " + _names, ""] select (_names isEqualTo ""))],
        [_category, "Attacks: " + _section],
        (_numbers apply {str _x}) joinString ", ",
        1,
        {
            // CBA runs this for every attack at once on start: one rebuild is enough
            if (isNil "DB_JTAC_AttackApplyQueued") then {
                DB_JTAC_AttackApplyQueued = true;
                [{DB_JTAC_AttackApplyQueued = nil; call DB_fnc_jtacApplyAttackSettings}] call CBA_fnc_execNextFrame;
            };
        }
    ] call CBA_fnc_addSetting;
} forEach DB_JTAC_Attacks;

call DB_fnc_jtacApplyAttackSettings;
