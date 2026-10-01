extends RefCounted
# Weapon table carried over from the HTML reference (WEAPONS). Damage is per hit
# (per pellet for the shotgun), rate is seconds between shots, spread is radians.

const DATA := {
	"fists": {"name": "YUMRUK", "melee": true, "damage": 14.0, "range": 1.9, "rate": 0.5},
	"knife": {"name": "BIÇAK", "melee": true, "damage": 48.0, "range": 2.2, "rate": 0.42},
	"pistol": {"name": "TABANCA", "damage": 34.0, "rate": 0.3, "spread": 0.01, "ammo": "ammo9",
		"mag": 12, "reload": 1.4, "noise": 55.0, "kick": 0.02, "pose": "AimPistol"},
	"shotgun": {"name": "POMPALI", "damage": 17.0, "pellets": 8, "rate": 0.85, "spread": 0.05,
		"ammo": "shell", "mag": 6, "reload": 2.4, "noise": 75.0, "kick": 0.06, "pose": "AimRifle"},
	"rifle": {"name": "TÜFEK", "damage": 42.0, "rate": 0.11, "spread": 0.018, "ammo": "ammo762",
		"mag": 30, "reload": 2.2, "noise": 80.0, "kick": 0.008, "pose": "AimRifle", "auto": true},
}
const NAMES := {
	"knife": "Bıçak", "pistol": "Tabanca", "shotgun": "Pompalı tüfek", "rifle": "Tüfek",
	"ammo9": "9mm mermi", "ammo762": "7.62 mermi", "shell": "Av fişeği", "bandage": "Sargı bezi",
}
const GUNS := ["pistol", "shotgun", "rifle"]


static func is_gun(weapon: String) -> bool:
	return weapon in GUNS


static func label(kind: String, amount: int) -> String:
	return NAMES.get(kind, kind) + (" ×%d" % amount if amount > 1 and not is_gun(kind) else "")
