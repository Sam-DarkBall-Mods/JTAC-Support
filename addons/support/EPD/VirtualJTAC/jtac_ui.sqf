/*
    The JTAC tablet: a 7" rugged tablet (tools/draw_tablet.py) running a
    map-centred fires app in the manner of ATAK.

    Layout is in design pixels of a 1920x1080 screen; the display of the
    tablet is 1131 x 707 of them, from (395, 187).
*/

DB_jtacUi = "\jtac_support\data\ui\tablet\";

DB_jtacText = [0.93, 0.93, 0.93, 1];
DB_jtacLabel = [0.58, 0.6, 0.63, 1];
DB_jtacPane = [0.105, 0.108, 0.115, 0.97];
DB_jtacButton = [0.2, 0.205, 0.215, 1];
DB_jtacPressed = [0.2, 0.71, 0.9, 0.55];
DB_jtacAccent = [0.2, 0.71, 0.9, 1];
DB_jtacFire = [0.76, 0.19, 0.13, 1];
DB_jtacBar = [0, 0, 0, 0.62];

// ---------------------------------------------------------------- layout

JTAC_TabletRect = {
    params ["_x", "_y", "_w", "_h"];
    private _k = (safeZoneW / (1920 * pixelW)) min (safeZoneH / (1080 * pixelH));
    [
        safeZoneX + safeZoneW / 2 + (_x - 960) * _k * pixelW,
        safeZoneY + safeZoneH / 2 + (_y - 540) * _k * pixelH,
        _w * _k * pixelW,
        _h * _k * pixelH
    ]
};

JTAC_TabletScreen = {
    params ["_x", "_y", "_w", "_h"];
    [395 + _x, 187 + _y, _w, _h] call JTAC_TabletRect
};

JTAC_TabletPx = {
    _this * ((safeZoneW / (1920 * pixelW)) min (safeZoneH / (1080 * pixelH))) * pixelH
};

// A control at a rect of the display (or of the whole design screen)
JTAC_TabletCtrl = {
    disableSerialization;
    params ["_display", "_class", "_rect", ["_text", ""], ["_size", 18], ["_color", DB_jtacText], ["_bg", [0, 0, 0, 0]], ["_font", "RobotoCondensed"], ["_onScreen", true]];
    private _ctrl = _display ctrlCreate [_class, -1];
    _ctrl ctrlSetPosition (_rect call ([JTAC_TabletRect, JTAC_TabletScreen] select _onScreen));
    if (_text != "") then {_ctrl ctrlSetText _text};
    _ctrl ctrlSetFont _font;
    _ctrl ctrlSetFontHeight (_size call JTAC_TabletPx);
    _ctrl ctrlSetTextColor _color;
    _ctrl ctrlSetBackgroundColor _bg;
    _ctrl ctrlCommit 0;
    _ctrl
};

// A flat button that lights while it is held; _label is text or an icon
JTAC_TabletTouch = {
    disableSerialization;
    params ["_display", "_rect", "_label", "_action", ["_bg", DB_jtacButton], ["_size", 18], ["_color", DB_jtacText]];
    private _isIcon = (_label find ".paa") > 0;
    private _face = [_display, "JTAC_TextCenter", _rect, ["", _label] select !_isIcon, _size, _color, _bg, "RobotoCondensedBold"] call JTAC_TabletCtrl;
    if (_isIcon) then {
        _rect params ["_x", "_y", "_w", "_h"];
        private _s = (_w min _h) * 0.6;
        _face setVariable ["DB_icon", [_display, "JTAC_Picture", [_x + (_w - _s) / 2, _y + (_h - _s) / 2, _s, _s], _label, 0, _color] call JTAC_TabletCtrl];
    };
    private _hit = [_display, "JTAC_Touch", _rect] call JTAC_TabletCtrl;
    _hit setVariable ["DB_face", _face];
    _hit setVariable ["DB_bg", _bg];
    _hit setVariable ["DB_action", _action];
    _hit ctrlAddEventHandler ["MouseButtonDown", {
        params ["_hit", "_button"];
        if (_button != 0) exitWith {};
        (_hit getVariable "DB_face") ctrlSetBackgroundColor DB_jtacPressed;
        [ctrlParent _hit] call JTAC_TabletBlinkDrive;
    }];
    {
        _hit ctrlAddEventHandler [_x, {
            params ["_hit"];
            (_hit getVariable "DB_face") ctrlSetBackgroundColor (_hit getVariable "DB_bg");
        }];
    } forEach ["MouseButtonUp", "MouseExit"];
    _hit ctrlAddEventHandler ["ButtonClick", {
        params ["_hit"];
        [ctrlParent _hit, _hit] call (_hit getVariable "DB_action");
    }];
    _hit
};

// The drive LED flickers on every touch, as the tablet's storage does
JTAC_TabletBlinkDrive = {
    params ["_display"];
    [_display getVariable ["DB_JTAC_DriveLed", controlNull]] spawn {
        disableSerialization;
        params ["_led"];
        if (isNull _led) exitWith {};
        _led ctrlShow true;
        uiSleep (0.06 + random 0.08);
        if (!isNull _led) then {_led ctrlShow false};
    };
};

JTAC_TabletDirectionText = {
    if (JtacIncomingAngle isEqualTo "RANDOM") exitWith {"RANDOM"};
    private _names = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"];
    private _a = round JtacIncomingAngle;
    format ["%1° %2", [_a, 3] call CBA_fnc_formatNumber, _names select (round (_a / 45) mod 8)]
};

JTAC_TabletSetMode = {
    params ["_display", "_mode"];
    JtacTargetingMethod = _mode;
    (_display getVariable ["DB_JTAC_ModeIcon", controlNull]) ctrlSetText (DB_jtacUi + (["icon_laser.paa", "icon_map.paa"] select (_mode == "MAP")));
    [_display, format ["Targeting: %1", _mode]] call JTAC_TabletMessage;
};

JTAC_TabletMessage = {
    params ["_display", "_text"];
    private _ctrl = _display getVariable ["DB_JTAC_Message", controlNull];
    if (!isNull _ctrl) then {_ctrl ctrlSetText _text};
};

// ---------------------------------------------------------------- display

JTAC_TabletOpen = {
    disableSerialization;
    params [["_view", "main"]];

    private _old = uiNamespace getVariable ["DB_JTAC_TabletDisplay", displayNull];
    if (!isNull _old) then {_old closeDisplay 2};

    private _display = (findDisplay 46) createDisplay "RscDisplayEmpty";
    uiNamespace setVariable ["DB_JTAC_TabletDisplay", _display];
    _display displayAddEventHandler ["Unload", {
        params ["_display"];
        if ((uiNamespace getVariable ["DB_JTAC_TabletDisplay", displayNull]) isEqualTo _display) then {
            uiNamespace setVariable ["DB_JTAC_TabletDisplay", displayNull];
        };
    }];

    private _shade = _display ctrlCreate ["RscText", -1];
    _shade ctrlSetPosition [safeZoneXAbs, safeZoneY, safeZoneWAbs, safeZoneH];
    _shade ctrlSetBackgroundColor [0, 0, 0, 0.45];
    _shade ctrlCommit 0;

    [_display, "JTAC_Picture", [-50, 35, 2020, 1010], DB_jtacUi + "body.paa", 0, [1, 1, 1, 1], [0, 0, 0, 0], "RobotoCondensed", false] call JTAC_TabletCtrl;

    // map under everything on the display
    private _map = [_display, "JTAC_Map", [0, 28, 1131, 679]] call JTAC_TabletCtrl;
    _display setVariable ["DB_JTAC_Map", _map];
    _map ctrlMapSetPosition ([0, 28, 1131, 679] call JTAC_TabletScreen);
    _map ctrlAddEventHandler ["Draw", {call JTAC_TabletDraw}];
    _map ctrlAddEventHandler ["MouseButtonClick", {call JTAC_TabletMapClick}];

    // status bar
    [_display, "JTAC_Text", [0, 0, 1131, 28], "", 16, DB_jtacText, [0, 0, 0, 0.92]] call JTAC_TabletCtrl;
    _display setVariable ["DB_JTAC_Clock", [_display, "JTAC_Text", [12, 0, 120, 28], "", 20, DB_jtacText, [0, 0, 0, 0], "RobotoCondensedBold"] call JTAC_TabletCtrl];
    {
        _x params ["_icon", "_xPos"];
        [_display, "JTAC_Picture", [_xPos, 4, 20, 20], DB_jtacUi + _icon] call JTAC_TabletCtrl;
    } forEach [["icon_gps.paa", 1052], ["icon_signal.paa", 1076], ["icon_battery.paa", 1100]];

    // toolbar
    [_display, "JTAC_Text", [0, 28, 285, 57], "", 18, DB_jtacText, DB_jtacBar] call JTAC_TabletCtrl;
    {
        _x params ["_icon", "_action"];
        private _hit = [_display, [_forEachIndex * 57, 28, 57, 57], DB_jtacUi + _icon, _action, [0, 0, 0, 0]] call JTAC_TabletTouch;
        if (_forEachIndex == 2) then {_display setVariable ["DB_JTAC_ModeIcon", (_hit getVariable "DB_face") getVariable "DB_icon"]};
    } forEach [
        ["icon_menu.paa", {params ["_display"]; [_display, "main"] call JTAC_TabletPane}],
        ["icon_fires.paa", {params ["_display"]; [_display, "main"] call JTAC_TabletPane}],
        [["icon_laser.paa", "icon_map.paa"] select (JtacTargetingMethod == "MAP"), {
            params ["_display"];
            [_display, ["MAP", "LASER"] select (JtacTargetingMethod == "MAP")] call JTAC_TabletSetMode;
            [_display, _display getVariable ["DB_JTAC_View", "main"]] call JTAC_TabletPane;
        }],
        ["icon_dir.paa", {params ["_display"]; [_display, "dir"] call JTAC_TabletPane}],
        ["icon_status.paa", {params ["_display"]; [_display, "status"] call JTAC_TabletPane}]
    ];

    // map controls down the left edge
    [_display, "JTAC_Picture", [10, 96, 50, 50], DB_jtacUi + "icon_north.paa"] call JTAC_TabletCtrl;
    [_display, [10, 156, 50, 50], DB_jtacUi + "icon_self.paa", {
        params ["_display"];
        private _map = _display getVariable "DB_JTAC_Map";
        _map ctrlMapAnimAdd [0.4, ctrlMapScale _map, getPosATL player];
        ctrlMapAnimCommit _map;
    }, DB_jtacBar] call JTAC_TabletTouch;
    {
        _x params ["_icon", "_factor", "_y"];
        private _btn = [_display, [10, _y, 50, 50], DB_jtacUi + _icon, {
            params ["_display", "_hit"];
            private _map = _display getVariable "DB_JTAC_Map";
            private _scale = ((ctrlMapScale _map) * (_hit getVariable "DB_factor")) max 0.002 min 1;
            ctrlPosition _map params ["_mx", "_my", "_mw", "_mh"];
            _map ctrlMapAnimAdd [0.25, _scale, _map ctrlMapScreenToWorld [_mx + _mw / 2, _my + _mh / 2]];
            ctrlMapAnimCommit _map;
            uiNamespace setVariable ["DB_JTAC_MapScale", _scale];
        }, DB_jtacBar] call JTAC_TabletTouch;
        _btn setVariable ["DB_factor", _factor];
    } forEach [["icon_plus.paa", 0.6, 222], ["icon_minus.paa", 1.6, 274]];

    // own position, bottom right of the map; messages bottom left
    [_display, "JTAC_Text", [433, 589, 290, 110], "", 15, DB_jtacText, DB_jtacBar] call JTAC_TabletCtrl;
    private _self = [];
    for "_i" from 0 to 3 do {
        _self pushBack ([_display, "JTAC_Text", [443, 593 + _i * 26, 275, 26], "", 19, [DB_jtacText, DB_jtacAccent] select (_i == 0)] call JTAC_TabletCtrl);
    };
    _display setVariable ["DB_JTAC_SelfLines", _self];
    _display setVariable ["DB_JTAC_Message", [_display, "JTAC_Text", [10, 668, 410, 32], "", 20, DB_jtacText, [0, 0, 0, 0], "RobotoCondensedBold"] call JTAC_TabletCtrl];
    private _banner = [_display, "JTAC_TextCenter", [180, 98, 380, 46], "", 23, [0, 0, 0, 1], [1, 0.8, 0.2, 0.92], "RobotoCondensedBold"] call JTAC_TabletCtrl;
    _banner ctrlShow false;
    _display setVariable ["DB_JTAC_Banner", _banner];

    // LEDs over the body: power and battery lit, drive on activity
    [_display, "JTAC_Picture", [1572, 194, 40, 40], DB_jtacUi + "led_green.paa", 0, [1, 1, 1, 1], [0, 0, 0, 0], "RobotoCondensed", false] call JTAC_TabletCtrl;
    [_display, "JTAC_Picture", [1572, 258, 40, 40], DB_jtacUi + "led_green.paa", 0, [1, 1, 1, 1], [0, 0, 0, 0], "RobotoCondensed", false] call JTAC_TabletCtrl;
    private _drive = [_display, "JTAC_Picture", [1572, 226, 40, 40], DB_jtacUi + "led_amber.paa", 0, [1, 1, 1, 1], [0, 0, 0, 0], "RobotoCondensed", false] call JTAC_TabletCtrl;
    _drive ctrlShow false;
    _display setVariable ["DB_JTAC_DriveLed", _drive];

    // home key: back to the fires page, or off
    private _home = [_display, "JTAC_Picture", [918, 913, 84, 42], DB_jtacUi + "home_up.paa", 0, [1, 1, 1, 1], [0, 0, 0, 0], "RobotoCondensed", false] call JTAC_TabletCtrl;
    private _homeHit = [_display, "JTAC_Touch", [928, 916, 64, 36], "", 0, [1, 1, 1, 1], [0, 0, 0, 0], "RobotoCondensed", false] call JTAC_TabletCtrl;
    _homeHit setVariable ["DB_key", _home];
    _homeHit ctrlAddEventHandler ["MouseButtonDown", {
        params ["_hit", "_button"];
        if (_button == 0) then {(_hit getVariable "DB_key") ctrlSetText (DB_jtacUi + "home_down.paa")};
    }];
    {
        _homeHit ctrlAddEventHandler [_x, {
            params ["_hit"];
            (_hit getVariable "DB_key") ctrlSetText (DB_jtacUi + "home_up.paa");
        }];
    } forEach ["MouseButtonUp", "MouseExit"];
    _homeHit ctrlAddEventHandler ["ButtonClick", {
        params ["_hit"];
        private _display = ctrlParent _hit;
        switch (_display getVariable ["DB_JTAC_View", "main"]) do {
            case "main": {_display closeDisplay 2};
            case "pick": {_display closeDisplay 2};
            default {[_display, "main"] call JTAC_TabletPane};
        };
    }];

    [_display, _view] call JTAC_TabletPane;
    _display
};

// ---------------------------------------------------------------- map

JTAC_TabletDraw = {
    params ["_map"];
    private _display = ctrlParent _map;
    if !(_map getVariable ["DB_centred", false]) exitWith {
        _map setVariable ["DB_centred", true];
        _map ctrlMapAnimAdd [0, uiNamespace getVariable ["DB_JTAC_MapScale", 0.12], getPosATL player];
        ctrlMapAnimCommit _map;
    };

    private _lines = _display getVariable ["DB_JTAC_SelfLines", []];
    if (_lines isEqualTo []) exitWith {};
    (_display getVariable ["DB_JTAC_Clock", controlNull]) ctrlSetText ([daytime, "HH:MM"] call BIS_fnc_timeToString);
    private _grid = mapGridPosition player;
    private _half = floor (count _grid / 2);
    {
        (_lines select _forEachIndex) ctrlSetText _x;
    } forEach [
        format ["Callsign: %1", name player],
        format ["%1 %2", _grid select [0, _half], _grid select [_half]],
        format ["%1 m MSL", round ((getPosASL player) select 2)],
        format ["%1°   %2 km/h", [round getDirVisual player, 3] call CBA_fnc_formatNumber, round abs speed vehicle player]
    ];

    _map drawIcon [DB_jtacUi + "icon_selfmark.paa", [1, 1, 1, 1], getPosASLVisual player, 26, 26, getDirVisual player, "", 0];

    private _laser = laserTarget player;
    if (isNull _laser) then {_laser = laserTarget vehicle player};
    if (!isNull _laser) then {
        _map drawIcon [DB_jtacUi + "icon_hostile.paa", [1, 1, 1, 1], getPosASLVisual _laser, 20, 20, 0, " LASER", 2, 0.045, "RobotoCondensedBold", "right"];
    };

    if ((_display getVariable ["DB_JTAC_View", ""]) == "pick") then {
        if (jtacIngressSet) then {
            _map drawIcon ["\A3\ui_f\data\map\markers\handdrawn\start_CA.paa", [0.2, 0.71, 0.9, 1], jtacIngressPosition, 24, 24, 0, " IP", 2, 0.045, "RobotoCondensedBold", "right"];
        };
        if (jtacTargetSet) then {
            _map drawIcon [DB_jtacUi + "icon_hostile.paa", [1, 1, 1, 1], jtacTarget, 22, 22, 0, " TGT", 2, 0.045, "RobotoCondensedBold", "right"];
            if (jtacIngressSet) then {_map drawArrow [jtacIngressPosition, jtacTarget, [0.2, 0.71, 0.9, 1]]};
        };
    };

    private _last = missionNamespace getVariable ["DB_JTAC_LastTarget", []];
    if (_last isNotEqualTo [] && {time - (_last select 1) < 180}) then {
        _map drawIcon [DB_jtacUi + "icon_hostile.paa", [1, 1, 1, 0.8], _last select 0, 18, 18, 0, " " + (_last select 2), 2, 0.04, "RobotoCondensed", "right"];
    };
};

JTAC_TabletMapClick = {
    params ["_map", "_button", "_xPos", "_yPos"];
    private _display = ctrlParent _map;
    if (_button != 0 || {(_display getVariable ["DB_JTAC_View", ""]) != "pick"}) exitWith {};

    private _pos2D = _map ctrlMapScreenToWorld [_xPos, _yPos];
    private _pos = [_pos2D select 0, _pos2D select 1, 0];
    if (!jtacIngressSet) exitWith {
        jtacIngressPosition = _pos;
        jtacIngressSet = true;
        [_display, "pick"] call JTAC_TabletPane;
    };
    if (!jtacTargetSet) then {
        jtacTarget = _pos;
        jtacTargetSet = true;
        [_display, "pick"] call JTAC_TabletPane;
        _display setVariable ["DB_JTAC_MapDone", true];
    };
};

// ---------------------------------------------------------------- right pane

JTAC_TabletGetCategories = {
    private _categories = [];
    for "_i" from 1 to (count JtacMainMenu - 1) do {
        private _entry = JtacMainMenu select _i;
        private _link = _entry select 2;
        if (_link find "#USER:" == 0 && {!((_entry select 0) in ["Fire Direction", "Targeting Method", "Reload Status"])}) then {
            private _var = _link select [6];
            if (count (missionNamespace getVariable [_var, []]) > 1) then {
                _categories pushBack [_entry select 0, _var];
            };
        };
    };
    _categories
};

JTAC_TabletPane = {
    disableSerialization;
    params ["_display", "_view"];
    if ((_display getVariable ["DB_JTAC_View", ""]) == "pick" && {_view != "pick"}) exitWith {
        _display closeDisplay 2;
    };

    {ctrlDelete _x} forEach (_display getVariable ["DB_JTAC_Pane", []]);
    _display setVariable ["DB_JTAC_View", _view];
    private _before = allControls _display;

    [_display, "JTAC_Text", [731, 28, 400, 679], "", 18, DB_jtacText, DB_jtacPane] call JTAC_TabletCtrl;
    private _title = switch (_view) do {
        case "dir": {"INGRESS"};
        case "status": {"RELOAD STATUS"};
        case "pick": {"MAP TARGETING"};
        default {"FIRE SUPPORT"};
    };
    [_display, "JTAC_Text", [747, 32, 270, 50], _title, 28, DB_jtacText, [0, 0, 0, 0], "RobotoCondensedBold"] call JTAC_TabletCtrl;
    if (_view in ["dir", "status"]) then {
        [_display, [1071, 34, 46, 46], DB_jtacUi + "icon_back.paa", {params ["_display"]; [_display, "main"] call JTAC_TabletPane}, [0, 0, 0, 0]] call JTAC_TabletTouch;
    } else {
        private _ready = JtacAvailable && {_view != "pick"};
        [_display, "JTAC_TextCenter", [1017, 44, 100, 28], ["BUSY", "READY"] select _ready, 18, [0, 0, 0, 1], [[1, 0.7, 0.2, 1], [0.35, 0.85, 0.4, 1]] select _ready, "RobotoCondensedBold"] call JTAC_TabletCtrl;
    };
    [_display, "JTAC_Text", [731, 84, 400, 1], "", 18, DB_jtacText, [0.3, 0.31, 0.33, 1]] call JTAC_TabletCtrl;

    (_display getVariable ["DB_JTAC_Banner", controlNull]) ctrlShow false;
    [_display, _view] call (missionNamespace getVariable ["JTAC_TabletPane_" + _view, {}]);

    _display setVariable ["DB_JTAC_Pane", (allControls _display) - _before];
};

JTAC_TabletLabel = {
    params ["_display", "_y", "_text"];
    [_display, "JTAC_Text", [747, _y, 360, 22], _text, 17, DB_jtacLabel, [0, 0, 0, 0], "RobotoCondensedBold"] call JTAC_TabletCtrl;
};

JTAC_TabletPane_main = {
    params ["_display"];

    [_display, 90, "TARGETING"] call JTAC_TabletLabel;
    {
        _x params ["_mode", "_xPos"];
        private _on = JtacTargetingMethod == _mode;
        private _btn = [_display, [_xPos, 113, 184, 42], _mode, {
            params ["_display", "_hit"];
            [_display, _hit getVariable "DB_mode"] call JTAC_TabletSetMode;
            [_display, "main"] call JTAC_TabletPane;
        }, [DB_jtacButton, DB_jtacAccent] select _on, 21, [DB_jtacText, [0, 0, 0, 1]] select _on] call JTAC_TabletTouch;
        _btn setVariable ["DB_mode", _mode];
    } forEach [["MAP", 747], ["LASER", 933]];

    [_display, 162, "INGRESS"] call JTAC_TabletLabel;
    [_display, [747, 185, 370, 42], call JTAC_TabletDirectionText, {
        params ["_display"];
        [_display, "dir"] call JTAC_TabletPane;
    }, DB_jtacButton, 21] call JTAC_TabletTouch;

    // packages as chips: no scrolling for up to twelve of them
    [_display, 234, "PACKAGE"] call JTAC_TabletLabel;
    private _cats = call JTAC_TabletGetCategories;
    private _cat = ((uiNamespace getVariable ["DB_JTAC_Cat", 0]) min (count _cats - 1)) max 0;
    {
        _x params ["_name"];
        private _on = _forEachIndex == _cat;
        private _short = (_name splitString " ") select 0;
        if (count _name <= 15) then {_short = _name};
        private _btn = [_display, [747 + (_forEachIndex % 3) * 126, 257 + floor (_forEachIndex / 3) * 42, 118, 36], _short, {
            params ["_display", "_hit"];
            uiNamespace setVariable ["DB_JTAC_Cat", _hit getVariable "DB_index"];
            uiNamespace setVariable ["DB_JTAC_Attack", 0];
            [_display, "main"] call JTAC_TabletPane;
        }, [DB_jtacButton, DB_jtacAccent] select _on, 20, [DB_jtacText, [0, 0, 0, 1]] select _on] call JTAC_TabletTouch;
        _btn setVariable ["DB_index", _forEachIndex];
    } forEach _cats;

    private _top = 257 + (ceil ((count _cats max 1) / 3)) * 42 + 4;
    [_display, _top, "MISSION"] call JTAC_TabletLabel;
    private _attacks = [_display, "JTAC_List", [747, _top + 23, 370, 618 - _top - 23], "", 23, DB_jtacText, [0, 0, 0, 0.35]] call JTAC_TabletCtrl;
    private _info = [_display, "JTAC_Text", [747, 618, 370, 26], "", 18, DB_jtacLabel] call JTAC_TabletCtrl;
    _display setVariable ["DB_JTAC_Attacks", _attacks];
    _display setVariable ["DB_JTAC_Info", _info];

    _attacks ctrlAddEventHandler ["LBSelChanged", {
        params ["_attacks", "_index"];
        uiNamespace setVariable ["DB_JTAC_Attack", _index];
        [ctrlParent _attacks] call JTAC_TabletShowInfo;
    }];
    _attacks ctrlAddEventHandler ["LBDblClick", {
        params ["_attacks", "_index"];
        [_attacks, _index] call JTAC_TabletExecuteAttackSelection;
    }];

    if (_cats isNotEqualTo []) then {
        private _attackIndex = uiNamespace getVariable ["DB_JTAC_Attack", 0];
        [_display, (_cats select _cat) select 1] call JTAC_TabletFillAttacks;
        if (lbSize _attacks > 0) then {_attacks lbSetCurSel (_attackIndex min (lbSize _attacks - 1))};
    };

    [_display, [747, 648, 370, 52], "REQUEST FIRE", {
        params ["_display"];
        private _attacks = _display getVariable "DB_JTAC_Attacks";
        [_attacks, lbCurSel _attacks] call JTAC_TabletExecuteAttackSelection;
    }, DB_jtacFire, 24] call JTAC_TabletTouch;
};

JTAC_TabletFillAttacks = {
    params ["_display", "_var"];
    private _attacks = _display getVariable "DB_JTAC_Attacks";
    lbClear _attacks;
    private _menu = missionNamespace getVariable [_var, []];
    for "_i" from 1 to (count _menu - 1) do {
        private _item = _menu select _i;
        _attacks lbSetData [_attacks lbAdd (_item select 0), (_item select 4) select 0 select 1];
    };
    if (lbSize _attacks > 0) then {_attacks lbSetCurSel 0};
    [_display] call JTAC_TabletShowInfo;
};

JTAC_TabletShowInfo = {
    params ["_display"];
    private _attacks = _display getVariable "DB_JTAC_Attacks";
    private _name = _attacks lbText (lbCurSel _attacks);
    private _attack = EPDJtacAvailableAttacks select {(_x select 1) == _name};
    private _text = "";
    if (_attack isNotEqualTo []) then {
        _attack = _attack select 0;
        _text = format ["Lock %1 s   Load %2", _attack select 2, _attack select 3];
        private _numbers = (_attack select 5) select {_x isEqualType 0};
        if ((_attack select 4) in ["FIRE_DRONE", "SHOOT_PROJECTILES", "DROP_BOMBS", "FIRE_ROCKETS", "STRAFING_RUN_ROCKET", "STRAFING_RUN_PROJECTILE", "LAY_MINE_FIELD"] && {_numbers isNotEqualTo []}) then {
            _text = format ["%1   x%2", _text, _numbers select 0];
        };
    };
    (_display getVariable "DB_JTAC_Info") ctrlSetText _text;
};

JTAC_TabletExecuteAttackSelection = {
    disableSerialization;
    params ["_ctrl", "_index"];
    if (_index < 0) exitWith {
        [ctrlParent _ctrl, "Select a fire mission first"] call JTAC_TabletMessage;
    };
    private _expression = _ctrl lbData _index;
    if (_expression != "") then {
        (ctrlParent _ctrl) closeDisplay 2;
        call compile _expression;
    };
};

JTAC_TabletPane_dir = {
    params ["_display"];
    [_display, 92, "FIRE COMES IN FROM"] call JTAC_TabletLabel;
    {
        _x params ["_label", "_value"];
        private _col = _forEachIndex % 3;
        private _row = floor (_forEachIndex / 3);
        private _on = JtacIncomingAngle isEqualTo _value;
        private _btn = [_display, [747 + _col * 126, 122 + _row * 96, 118, 88], _label, {
            params ["_display", "_hit"];
            JtacIncomingAngle = _hit getVariable "DB_value";
            [_display, format ["Ingress: %1", call JTAC_TabletDirectionText]] call JTAC_TabletMessage;
            [_display, "main"] call JTAC_TabletPane;
        }, [DB_jtacButton, DB_jtacAccent] select _on, 26, [DB_jtacText, [0, 0, 0, 1]] select _on] call JTAC_TabletTouch;
        _btn setVariable ["DB_value", _value];
    } forEach [
        ["NW", 315], ["N", 0], ["NE", 45],
        ["W", 270], ["RANDOM", "RANDOM"], ["E", 90],
        ["SW", 225], ["S", 180], ["SE", 135]
    ];
    ([_display, "JTAC_Text", [747, 418, 370, 30], "", 18, DB_jtacLabel] call JTAC_TabletCtrl) ctrlSetText "On the map, the ingress point sets it instead.";
};

JTAC_TabletPane_status = {
    params ["_display"];
    private _text = [_display, "RscStructuredText", [747, 96, 370, 540], "", 22, DB_jtacText, [0, 0, 0, 0.35]] call JTAC_TabletCtrl;
    _display setVariable ["DB_JTAC_StatusText", _text];
    [_display, ["Requesting reload state..."]] call JTAC_TabletSetStatusLines;
    player remoteExec ["GET_RELOAD_STATUS_ARRAY", 2, false];
    [_display, [747, 648, 370, 52], "REFRESH", {
        params ["_display"];
        [_display, "status"] call JTAC_TabletPane;
    }, DB_jtacButton, 22] call JTAC_TabletTouch;
};

JTAC_TabletSetStatusLines = {
    params ["_display", "_lines"];
    private _ctrl = _display getVariable ["DB_JTAC_StatusText", controlNull];
    if (isNull _ctrl) exitWith {};
    if (_lines isEqualTo []) then {_lines = ["No status data"]};
    _ctrl ctrlSetStructuredText parseText format [
        "<t font='RobotoCondensed' color='#EDEDED'>%1</t>",
        _lines joinString "<br/>"
    ];
};

JTAC_TabletPane_pick = {
    params ["_display"];
    {
        _x params ["_step", "_label", "_done", "_y"];
        [_display, "JTAC_TextCenter", [747, _y, 40, 40], _step, 22, [[0, 0, 0, 1], [0, 0, 0, 1]] select _done, [DB_jtacButton, DB_jtacAccent] select _done, "RobotoCondensedBold"] call JTAC_TabletCtrl;
        [_display, "JTAC_Text", [800, _y, 310, 40], _label, 22, [DB_jtacText, DB_jtacLabel] select _done] call JTAC_TabletCtrl;
    } forEach [
        ["1", "Tap the ingress point", jtacIngressSet, 100],
        ["2", "Tap the target", jtacTargetSet, 152]
    ];
    ([_display, "JTAC_Text", [747, 206, 370, 30], "", 18, DB_jtacLabel] call JTAC_TabletCtrl) ctrlSetText "Drag with the right mouse button.";

    private _banner = _display getVariable ["DB_JTAC_Banner", controlNull];
    _banner ctrlSetText (["TAP INGRESS POINT", "TAP TARGET"] select jtacIngressSet);
    _banner ctrlShow !jtacTargetSet;

    [_display, [747, 648, 182, 52], "RESET", {
        params ["_display"];
        jtacIngressSet = false;
        jtacTargetSet = false;
        [_display, "pick"] call JTAC_TabletPane;
    }, DB_jtacButton, 22] call JTAC_TabletTouch;
    [_display, [935, 648, 182, 52], "CANCEL", {
        params ["_display"];
        _display closeDisplay 2;
    }, DB_jtacButton, 22] call JTAC_TabletTouch;
};

// ---------------------------------------------------------------- entry points

JTAC_OpenMainUI = {
    if (!JtacAvailable) exitWith {
        hint "JTAC currently unavailable (reload in progress)";
    };
    ["main"] call JTAC_TabletOpen;
};

JTAC_TabletGetMapPositions = {
    disableSerialization;
    jtacIngressSet = false;
    jtacIngressPosition = [-1, -1, -1];
    jtacTargetSet = false;
    jtacTarget = [-1, -1, -1];

    private _display = ["pick"] call JTAC_TabletOpen;
    _display setVariable ["DB_JTAC_MapDone", false];
    waitUntil {
        sleep 0.1;
        (isNull _display) || {_display getVariable ["DB_JTAC_MapDone", false]}
    };

    private _result = [false];
    if (jtacIngressSet && {jtacTargetSet}) then {
        private _diff = jtacIngressPosition vectorDiff jtacTarget;
        JtacIncomingAngle = (((_diff select 0) atan2 (_diff select 1)) + 360) % 360;
        _result = [true, [jtacTarget select 0, jtacTarget select 1, getTerrainHeightASL jtacTarget]];
        sleep 0.4;
    };
    if (!isNull _display) then {_display closeDisplay 1};
    _result
};

JTAC_GET_MAP_POSITIONS = {
    call JTAC_TabletGetMapPositions
};

if ((isNil "DB_fnc_jtacDisplayReloadStatusSitrep") && {!(isNil "CLIENT_DISPLAY_RELOAD_STATUS")}) then {
    DB_fnc_jtacDisplayReloadStatusSitrep = CLIENT_DISPLAY_RELOAD_STATUS;
};
CLIENT_DISPLAY_RELOAD_STATUS = {
    private _display = uiNamespace getVariable ["DB_JTAC_TabletDisplay", displayNull];
    if (isNull _display || {(_display getVariable ["DB_JTAC_View", ""]) != "status"}) exitWith {
        _this spawn BIS_fnc_EXP_camp_SITREP;
    };
    [_display, (_this apply {_x select 0}) select {_x != ""}] call JTAC_TabletSetStatusLines;
};
