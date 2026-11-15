/*
    Flies spawned ordnance in a straight line to its aim point at a set speed,
    nose first. Left to the engine every ammo class missed by its own drag,
    thrust or seeker: the old launch speeds were tuned for the GBU-12 only.
    The spread is in the aim point alone.

    [_object, _aimASL, _speed, _onArrival] call JTAC_GUIDE
        _onArrival - optional, called with [_object] when it is within a frame
                     of the aim point or has been destroyed on the way
*/

DB_JTAC_Guided = [];
DB_JTAC_GuideEH = -1;

JTAC_GUIDE = {
    if (!isServer) exitWith {};
    params ["_object", "_aim", "_speed", ["_onArrival", {}]];

    // an empty vehicle (a drone) is not moved by the engine: it is carried
    DB_JTAC_Guided pushBack [_object, _aim, _speed max 1, _onArrival, _object isKindOf "AllVehicles"];
    if (DB_JTAC_GuideEH >= 0) exitWith {};

    DB_JTAC_GuideEH = addMissionEventHandler ["EachFrame", {
        DB_JTAC_Guided = DB_JTAC_Guided select {
            _x params ["_object", "_aim", "_speed", "_onArrival", "_carried"];
            private _flying = !isNull _object && {alive _object};
            // a slow frame can carry a round past an aim point above the ground:
            // it is let go rather than turned back
            if (_flying && {!_carried} && {((velocity _object) vectorDotProduct (_aim vectorDiff getPosASL _object)) < 0}) then {
                _flying = false;
            };
            if (_flying) then {
                private _toAim = _aim vectorDiff getPosASL _object;
                private _dir = vectorNormalized _toAim;
                private _step = _speed * (diag_deltaTime min 0.2);
                // the last frame is left to the engine so it strikes rather than hovers
                _flying = vectorMagnitude _toAim > _step + 1;
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
