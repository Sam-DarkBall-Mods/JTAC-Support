// Both runs walk their aim point _distanceToStrafe metres along the attack
// heading, one step per round, and guide every round to its step

STRAFING_RUN_ROCKET = {
    if (!isServer) exitWith {};

    params ["_targetLocation", "_incomingAngle", "_projectiles"];
    _projectiles params [
        "_projectileClassName", "_numberToSend", "_distanceToStrafe", "_source2dDistance", "_pitch",
        "_spread", "_minTimeBetween", "_maxRandomTime"
    ];

    // the rockets dive in at _pitch degrees; their own top speed is kept
    private _speed = getNumber (configFile >> "CfgAmmo" >> _projectileClassName >> "maxSpeed");
    if (_speed <= 0) then {_speed = 600};
    private _height = _source2dDistance * tan (abs _pitch);
    private _step = [sin (_incomingAngle + 180), cos (_incomingAngle + 180), 0] vectorMultiply (_distanceToStrafe / (_numberToSend max 1));

    for "_i" from 0 to _numberToSend - 1 do {
        private _aim = (_targetLocation vectorAdd (_step vectorMultiply _i)) vectorAdd [(random (2 * _spread)) - _spread, (random (2 * _spread)) - _spread, 0];
        private _sourceLocation = _aim getPos [_source2dDistance, _incomingAngle];
        _sourceLocation set [2, _height + (_aim select 2)];

        private _rocket = _projectileClassName createVehicle _sourceLocation;
        _rocket setPosASL _sourceLocation;
        [_rocket, _aim, _speed] call JTAC_GUIDE;

        sleep (_minTimeBetween + random _maxRandomTime);
    };
};

STRAFING_RUN_PROJECTILE = {
    if (!isServer) exitWith {};

    params ["_targetLocation", "_incomingAngle", "_projectiles"];
    _projectiles params [
        "_projectileClassName", "_numberToSend", "_verticalOffset", "_distanceToStrafe", "_spread",
        "_minTimeBetween", "_maxRandomTime"
    ];

    private _step = [sin (_incomingAngle + 180), cos (_incomingAngle + 180), 0] vectorMultiply (_distanceToStrafe / (_numberToSend max 1));

    for "_i" from 0 to _numberToSend - 1 do {
        private _aim = (_targetLocation vectorAdd (_step vectorMultiply _i)) vectorAdd [(random (2 * _spread)) - _spread, (random (2 * _spread)) - _spread, 0];
        private _sourceLocation = _aim getPos [2000, _incomingAngle];
        _sourceLocation set [2, 982.1129 + (_aim select 2)];

        private _projectile = _projectileClassName createVehicle _sourceLocation;
        _projectile setPosASL _sourceLocation;
        [_projectile, _aim, 1000] call JTAC_GUIDE;

        sleep (_minTimeBetween + random _maxRandomTime);
    };
};
