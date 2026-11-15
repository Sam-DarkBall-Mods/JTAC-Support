/*
    FIRE_DRONE - flies attack drones from other mods into the target.
        parameters - [_droneClassName, _warheadClassName, _numberToSend, _speed, _source2dDistance, _sourceHeight, _spreadRadial, _minTimeBetween, _maxRandomTime]
            _droneClassName - CfgAmmo class (it explodes by itself) or CfgVehicles class
                              (its _warheadClassName is set off at the target).
            The attack is listed only while the drone's mod is loaded (see jtacsettings.sqf).
*/

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
        private _aim = [_targetLocation, _spreadRadial] call JTAC_SPREAD_POINT;
        // a drone goes for the vehicle's side, not the ground under its belly
        _aim set [2, (_aim select 2) + 1.5];
        private _sourceLocation = _aim getPos [_source2dDistance, _incomingAngle];
        _sourceLocation set [2, _sourceHeight + (_aim select 2)];

        private _drone = objNull;
        if (_isVehicle) then {
            _drone = createVehicle [_droneClassName, [0, 0, 1000], [], 0, "FLY"];
            _drone setVariable ["DB_JTAC_Warhead", _warheadClassName];
            _drone engineOn true;
        } else {
            _drone = _droneClassName createVehicle _sourceLocation;
        };
        _drone setPosASL _sourceLocation;
        [_drone, _aim, _speed, [{}, _detonate] select _isVehicle] call JTAC_GUIDE;

        sleep (_minTimeBetween + random _maxRandomTime);
    };
};
