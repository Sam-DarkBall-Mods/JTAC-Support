# JTAC Support

[![CI](https://github.com/Sam-DarkBall-Mods/JTAC-Support/actions/workflows/ci.yml/badge.svg)](https://github.com/Sam-DarkBall-Mods/JTAC-Support/actions/workflows/ci.yml)

A JTAC tablet for Arma 3. Mark a target with the laser designator or on the
map and call in cannon fire, artillery, strafing runs, bombs, rockets and
cruise missiles, guided missiles, mine fields, smoke, night support and attack
drones.

## Download

Get `JTAC_Support.zip` from [Releases](https://github.com/Sam-DarkBall-Mods/JTAC-Support/releases),
unpack the `@JTAC_Support` folder and load it as a local mod. Servers that
check signatures need `keys/db_jtac_support.bikey`.

## Requirements

- Arma 3 2.18 or newer
- [CBA_A3](https://steamcommunity.com/sharedfiles/filedetails/?id=450814997)

The Drones menu lists only the drones whose mods are loaded: Geran-3 (Shahed-238
from Geran-2 & Shahed-136), Geran-4, and Krokus AP and AT from ArmaFPV.

## Use

Equip the JTAC Laserdesignator and press H (CBA keybind "Open JTAC Support
Menu"). Pick a support package, then the target by laser or on the tablet map.
Every attack's numbers, the reload times and the acquisition time are CBA
settings under JTAC Support.

## Development

```bash
python3 -B tools/validate_repository.py
python3 -B -m unittest discover -s tests -p "test_*.py" -v
hemtt check
hemtt build --no-bin
```

The addon is packed without model binarization: the models reference vanilla
materials that HEMTT cannot resolve, and the release ships them as they are.

## License

See [LICENSES.md](LICENSES.md) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
