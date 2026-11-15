/*
    Each Oreshnik element hits like a GBU-12: a charge with the damage of
    Bomb_03_F (DB_JTAC_Oreshnik_Impact) falls into the point it lands on, so
    a vehicle there takes a direct hit. The strike shows and sounds its own
    impact, so the charge has neither.
*/
params [
    ["_impactATL", [0, 0, 0], [[]]],
    ["_settings", createHashMap, [createHashMap]]
];

if (!isServer) exitWith { false };

private _charge = createVehicle ["DB_JTAC_Oreshnik_Impact", [0, 0, 0], [], 0, "CAN_COLLIDE"];
_charge setPosASL ((ATLToASL _impactATL) vectorAdd [0, 0, 20]);
_charge setVectorDirAndUp [[0, 0, -1], [0, 1, 0]];
_charge setVelocity [0, 0, -300];

true;
