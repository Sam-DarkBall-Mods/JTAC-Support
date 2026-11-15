DROP_BOMBS = {
    if (!isServer) exitWith {};

    params ["_targetLocation", "_incomingAngle", "_projectiles"];
    _projectiles params [
        "_projectileClassName", "_numberToSend", "_bombSpeed", "_speedVariance", "_spreadRadial",
        "_minTimeBetween", "_maxRandomTime", ["_impactSpread", true], ["_source2dDistance", 3919.25]
    ];

    // released 1300 m up; each bomb is guided to its own point of the spread
    private _sourceLocation = _targetLocation getPos [_source2dDistance, _incomingAngle];
    _sourceLocation set [2, 1300 + (_targetLocation select 2)];

    for "_i" from 0 to _numberToSend - 1 do {
        private _aim = [_targetLocation, _spreadRadial] call JTAC_SPREAD_POINT;
        private _bomb = _projectileClassName createVehicle _sourceLocation;
        _bomb setPosASL _sourceLocation;
        [_bomb, _aim, _bombSpeed + (random (2 * _speedVariance)) - _speedVariance] call JTAC_GUIDE;

        sleep (_minTimeBetween + random _maxRandomTime);
    };
};
