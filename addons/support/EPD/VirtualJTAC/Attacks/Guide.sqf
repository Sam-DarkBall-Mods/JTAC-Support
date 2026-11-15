/*
    Flies spawned ordnance in a straight line to its aim point at a set speed,
    nose first. Left to the engine every ammo class missed by its own drag,
    thrust or seeker: the old launch speeds were tuned for the GBU-12 only.
    The spread is in the aim point alone.

    [_object, _aim, _speed, _onArrival, _via] call JTAC_GUIDE
        _aim       - ASL position, or an object to home on (its aimPos, the
                     last one seen if it is deleted on the way)
        _onArrival - optional, called with [_object] when it is within a frame
                     of the aim point or has been destroyed on the way
        _via       - optional offsets from the aim point, flown through in turn;
                     a fourth number is the lowest ASL height of that waypoint
*/

DB_JTAC_Guided = [];
DB_JTAC_GuideEH = -1;

JTAC_GUIDE = {
    if (!isServer) exitWith {};
    params ["_object", "_aim", "_speed", ["_onArrival", {}], ["_via", []]];

    private _last = if (_aim isEqualType objNull) then {aimPos _aim} else {_aim};
    // start it towards its first point: a round spawned moving any other way
    // would count that point as passed on the first frame
    private _first = if (_via isEqualTo []) then {_last} else {_last vectorAdd ((_via select 0) select [0, 3])};
    _object setVelocity ((vectorNormalized (_first vectorDiff getPosASL _object)) vectorMultiply (_speed max 1));
    // an empty vehicle (a drone) is not moved by the engine: it is carried
    DB_JTAC_Guided pushBack [_object, _aim, _speed max 1, _onArrival, _object isKindOf "AllVehicles", +_via, _last];
    if (DB_JTAC_GuideEH >= 0) exitWith {};

    DB_JTAC_GuideEH = addMissionEventHandler ["EachFrame", {
        DB_JTAC_Guided = DB_JTAC_Guided select {
            _x params ["_object", "_aim", "_speed", "_onArrival", "_carried", "_via", "_last"];
            private _flying = !isNull _object && {alive _object};
            if (_flying) then {
                if (_aim isEqualType objNull && {!isNull _aim}) then {
                    // lead a moving target by the time left to reach it, so it is struck side-on
                    _last = (aimPos _aim) vectorAdd ((velocity _aim) vectorMultiply (((_object distance _aim) / _speed) min 3));
                    _x set [6, _last];
                };
                private _viaPoint = {
                    // a waypoint keeps at least the height it was planned at, whatever the target does
                    private _v = _via select 0;
                    private _p = _last vectorAdd (_v select [0, 3]);
                    _p set [2, (_p select 2) max (_v param [3, -1e6])];
                    _p
                };
                private _point = if (_via isEqualTo []) then {_last} else {call _viaPoint};
                private _toAim = _point vectorDiff getPosASL _object;
                private _step = _speed * (diag_deltaTime min 0.2);
                // a slow frame can carry a round past its point: a waypoint
                // counts as reached, the aim point is let go rather than turned back to
                private _passed = !_carried && {((velocity _object) vectorDotProduct _toAim) < 0};
                if (_via isNotEqualTo [] && {_passed || {vectorMagnitude _toAim <= _step + 1}}) then {
                    _via deleteAt 0;
                    _point = if (_via isEqualTo []) then {_last} else {call _viaPoint};
                    _toAim = _point vectorDiff getPosASL _object;
                    _passed = false;
                };
                if (_passed) exitWith {_flying = false};
                if (_via isNotEqualTo []) then {
                    // on the way in, climb over ground that rises within 40 m of the course
                    private _pos = getPosASL _object;
                    private _flat = [_toAim select 0, _toAim select 1, 0];
                    private _run = vectorMagnitude _flat;
                    if (_run > 1) then {
                        private _ahead = _pos vectorAdd ((vectorNormalized _flat) vectorMultiply (150 min _run));
                        private _floor = ((getTerrainHeightASL _ahead) max 0) + 40;
                        if ((_pos select 2) + (_toAim select 2) * ((150 min _run) / _run) < _floor) then {
                            _ahead set [2, _floor];
                            _toAim = _ahead vectorDiff _pos;
                        };
                    };
                };

                private _dir = vectorNormalized _toAim;
                // the last frame is left to the engine so it strikes rather than hovers
                _flying = _via isNotEqualTo [] || {vectorMagnitude _toAim > _step + 1};
                if (_carried) then {
                    // a carried drone stops at the first thing in its way, as one that flies would
                    private _from = getPosASL _object;
                    private _to = _from vectorAdd (_dir vectorMultiply ((_step + 1) min vectorMagnitude _toAim));
                    private _hit = lineIntersectsSurfaces [_from, _to, _object, objNull, true, 1, "GEOM", "FIRE"];
                    if (_hit isEqualTo []) then {
                        _object setPosASL (_from vectorAdd (_dir vectorMultiply (_step min vectorMagnitude _toAim)));
                    } else {
                        _object setPosASL (((_hit select 0) select 0) vectorDiff (_dir vectorMultiply 0.5));
                        _flying = false;
                    };
                };
                _object setVelocity (_dir vectorMultiply _speed);
                private _side = _dir vectorCrossProduct [0, 0, 1];
                if (vectorMagnitude _side < 0.01) then {_side = [1, 0, 0]};
                _object setVectorDirAndUp [_dir, vectorNormalized (_side vectorCrossProduct _dir)];
            };
            if (!_flying) then {[_object] call _onArrival};
            _flying
        };
        if (DB_JTAC_Guided isEqualTo []) then {
            removeMissionEventHandler ["EachFrame", DB_JTAC_GuideEH];
            DB_JTAC_GuideEH = -1;
        };
    }];
};

// A random point within _radius metres of _center on the ground plane
JTAC_SPREAD_POINT = {
    params ["_center", "_radius"];
    private _point = _center getPos [_radius * sqrt random 1, random 360];
    _point set [2, _center select 2];
    _point
};
