if (missionNamespace getVariable ["DB_JTAC_RuntimeInitialized", false]) exitWith {
    if (!isDedicated and !(isNil "DB_fnc_jtacRefreshState")) then {
        [] call DB_fnc_jtacRefreshState;
    };
};

missionNamespace setVariable ["DB_JTAC_RuntimeInitialized", true];

call compile preprocessFileLineNumbers "\jtac_support\EPD\VirtualJTAC\Attacks\Guide.sqf";
call compile preprocessFileLineNumbers "\jtac_support\EPD\VirtualJTAC\Attacks\Projectiles.sqf";
call compile preprocessFileLineNumbers "\jtac_support\EPD\VirtualJTAC\Attacks\EvenSpread.sqf";
call compile preprocessFileLineNumbers "\jtac_support\EPD\VirtualJTAC\Attacks\Mines.sqf";
call compile preprocessFileLineNumbers "\jtac_support\EPD\VirtualJTAC\Attacks\Bombs.sqf";
call compile preprocessFileLineNumbers "\jtac_support\EPD\VirtualJTAC\Attacks\Rockets.sqf";
call compile preprocessFileLineNumbers "\jtac_support\EPD\VirtualJTAC\Attacks\GuidedMissile.sqf";
call compile preprocessFileLineNumbers "\jtac_support\EPD\VirtualJTAC\Attacks\StrafingRun.sqf";
call compile preprocessFileLineNumbers "\jtac_support\EPD\VirtualJTAC\Attacks\Oreshnik.sqf";
call compile preprocessFileLineNumbers "\jtac_support\EPD\VirtualJTAC\Attacks\Drones.sqf";
call compile preprocessFileLineNumbers "\jtac_support\EPD\VirtualJTAC\jtacattackparser.sqf";
call compile preprocessFileLineNumbers "\jtac_support\EPD\VirtualJTAC\jtacfirecontrol.sqf";
call compile preprocessFileLineNumbers "\jtac_support\EPD\VirtualJTAC\jtacreload.sqf";
call compile preprocessFileLineNumbers "\jtac_support\EPD\VirtualJTAC\jtacmapcontrol.sqf";

// Новый UI
call compile preprocessFileLineNumbers "\jtac_support\EPD\VirtualJTAC\jtac_ui.sqf";

call PARSE_AVAILABLE_JTAC_ATTACKS;

// ====================== ИНИЦИАЛИЗАЦИЯ ПЕРЕМЕННОЙ КЛАВИШИ ======================
if (isNil "JTAC_KeyCode") then {
    JTAC_KeyCode = 35; // H по умолчанию
};

if (!isDedicated) then {
    JtacAvailable = true;
    JtacIncomingAngle = "RANDOM";
    JtacTargetingMethod = "LASER";

    waitUntil {sleep 0.5; !(isNull player)};
    [] call DB_fnc_jtacRefreshState;

    // ====================== CBA KEYBIND (с переменной) ======================
    if !(missionNamespace getVariable ["DB_JTAC_KeybindRegistered", false]) then {
        missionNamespace setVariable ["DB_JTAC_KeybindRegistered", true];

        [
            "JTAC Support",
            "JTAC_OpenMenu",
            ["Open JTAC Support Menu", "Opens the JTAC support request menu"],
            {
                if (([] call DB_fnc_jtacRefreshState) && {JtacAvailable}) then {
                    [] call JTAC_OpenMainUI;
                };
            },
            {},
            [JTAC_KeyCode, [false, false, false]],
            (false)
        ] call CBA_fnc_addKeybind;
    };

    // ====================== Respawn ======================
    if !(missionNamespace getVariable ["DB_JTAC_RespawnHandlerRegistered", false]) then {
        missionNamespace setVariable ["DB_JTAC_RespawnHandlerRegistered", true];

        player addEventHandler ["Respawn", {
            params ["_unit"];
            [_unit] call DB_fnc_jtacRefreshState;
            JtacAvailable = true;
        }];
    };
};
