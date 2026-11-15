/*
    FIRE_DRONE - flies attack drones from other mods into the target.
        parameters - [_droneClassName, _warheadClassName, _numberToSend, _speed, _source2dDistance, _sourceHeight, _spreadRadial, _minTimeBetween, _maxRandomTime]
            _droneClassName - CfgAmmo class (it explodes by itself) or CfgVehicles class
                              (its _warheadClassName is set off at the target).
            The attack is listed only while the drone's mod is loaded (see jtacsettings.sqf).

    Each drone picks a point within the spread and goes for the vehicle nearest
    to it, following it if it drives off. It comes in above the hills and trees
    and dives at the shallowest angle that clears the ground before the target.
*/

// The vehicle a drone aimed at _point goes for, or objNull
JTAC_DRONE_TARGET = {
    params ["_point"];
    private _near = nearestObjects [ASLToAGL _point, ["LandVehicle", "Ship", "StaticWeapon", "Air"], 15] select {
        alive _x && {!(_x isKindOf "Air") || {isTouchingGround _x}}
    };
    if (_near isEqualTo []) then {objNull} else {_near select 0}
};

// [_source, _via] for a drone coming in from _bearing over _distance metres
JTAC_DRONE_ROUTE = {
    params ["_aim", "_bearing", "_distance", "_height"];
    private _along = [sin _bearing, cos _bearing, 0];
    private _groundAt = {(getTerrainHeightASL (_aim vectorAdd (_along vectorMultiply _this))) max 0};

    // cruise 40 m over the highest ground on the way, trees and roofs included
    private _cruise = (_aim select 2) + _height;
    for "_d" from 50 to _distance step 25 do {
        _cruise = _cruise max ((_d call _groundAt) + 40);
    };
    private _rise = _cruise - (_aim select 2);

    private _tan = tan 85;
    {
        private _t = tan _x;
        private _clear = true;
        for "_d" from 10 to ((_rise / _t) min _distance) step 10 do {
            if ((_aim select 2) + _d * _t < (_d call _groundAt) + ([2, 20] select (_d > 40))) exitWith {_clear = false};
        };
        if (_clear) exitWith {_tan = _t};
    } forEach [30, 45, 60, 75];

    private _dive = _rise / _tan;
    private _source = _aim vectorAdd (_along vectorMultiply _distance);
    _source set [2, _cruise];
    private _via = [];
    if (_dive < _distance) then {
        private _pushover = _along vectorMultiply _dive;
        _pushover set [2, _rise];
        _pushover pushBack _cruise;
        _via pushBack _pushover;
    };
    [_source, _via]
};

FIRE_DRONE = {
    if (!isServer) exitWith {};

    params ["_targetLocation", "_incomingAngle", "_projectiles"];
    _projectiles params [
        "_droneClassName", "_warheadClassName", "_numberToSend", "_speed", "_source2dDistance",
        "_sourceHeight", "_spreadRadial", "_minTimeBetween", "_maxRandomTime"
    ];

    private _isVehicle = isClass (configFile >> "CfgVehicles" >> _droneClassName);
    // the warhead goes off at the drone, facing its course, so a shaped charge
    // sends its jet on into what the drone struck (as ArmaFPV detonates it);
    // one shot down on the way blows up where it was hit
    private _detonate = {
        params ["_drone"];
        private _warhead = _drone getVariable ["DB_JTAC_Warhead", ""];
        if (_warhead isEqualTo "") exitWith {};
        private _charge = createVehicle [_warhead, [0, 0, 0], [], 0, "CAN_COLLIDE"];
        _charge setPosASL getPosASL _drone;
        _charge setVectorDirAndUp [vectorDir _drone, vectorUp _drone];
        deleteVehicle _drone;
        triggerAmmo _charge;
    };

    for "_i" from 0 to _numberToSend - 1 do {
        private _point = [_targetLocation, _spreadRadial] call JTAC_SPREAD_POINT;
        if (_spreadRadial > 0) then {_point set [2, (getTerrainHeightASL _point) max 0]};
        private _target = [_point] call JTAC_DRONE_TARGET;
        private _aim = [_target, _point] select (isNull _target);
        private _aimPos = if (isNull _target) then {_point} else {aimPos _target};
        private _bearing = [_incomingAngle, _incomingAngle + random 30 - 15] select (_numberToSend > 1);
        ([_aimPos, _bearing, _source2dDistance, _sourceHeight] call JTAC_DRONE_ROUTE) params ["_source", "_via"];

        // made where it starts and in one go, so two drones never meet at a spawn point
        isNil {
            private _drone = createVehicle [_droneClassName, ASLToAGL _source, [], 0, "CAN_COLLIDE"];
            _drone setPosASL _source;
            if (_isVehicle) then {
                _drone setVariable ["DB_JTAC_Warhead", _warheadClassName];
                _drone engineOn true;
            };
            [_drone, _aim, _speed, [{}, _detonate] select _isVehicle, _via] call JTAC_GUIDE;
        };

        sleep (_minTimeBetween + random _maxRandomTime);
    };
};
