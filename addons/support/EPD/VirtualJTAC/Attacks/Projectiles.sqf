SHOOT_PROJECTILES = {
    if (!isServer) exitWith {};

    params ["_targetLocation", "_incomingAngle", "_projectiles"];
    _projectiles params [
        "_projectileClassName", "_numberToSend", "_verticalOffset", "_spreadRadial", "_spreadNormal",
        "_minTimeBetween", "_maxRandomTime", ["_sourceHeight", 982.1129], ["_source2dDistance", 2000], ["_projectileSpeed", 1000]
    ];

    private _sourceLocation = _targetLocation getPos [_source2dDistance, _incomingAngle];
    _sourceLocation set [2, _sourceHeight + (_targetLocation select 2)];

    // guided to the aim point, so _verticalOffset (the old aim-high for drop) is not needed
    for "_i" from 0 to _numberToSend - 1 do {
        private _aim = [_targetLocation, _spreadRadial] call JTAC_SPREAD_POINT;
        _aim set [2, (_aim select 2) + (random (2 * _spreadNormal)) - _spreadNormal];

        private _projectile = _projectileClassName createVehicle _sourceLocation;
        _projectile setPosASL _sourceLocation;
        [_projectile, _aim, _projectileSpeed] call JTAC_GUIDE;

        sleep (_minTimeBetween + random _maxRandomTime);
    };
};
