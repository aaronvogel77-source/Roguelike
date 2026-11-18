class_name Palette
extends RefCounted
## Shared placeholder colors until the real art direction lands in M8.

const BACKGROUND := Color(0.051, 0.043, 0.063)
const PANEL := Color(0.11, 0.095, 0.13)
const GOLD := Color(0.85, 0.68, 0.32)
const PARCHMENT := Color(0.91, 0.86, 0.74)
const MUTED := Color(0.62, 0.58, 0.52)
## Stat colors on cards and in texts: attack red, health green.
const ATTACK := Color(0.85, 0.2, 0.22)
const LIFE := Color(0.25, 0.68, 0.3)
## Warning / defeat red (frames, banners) - separate from the attack stat.
const HEALTH := Color(0.8, 0.2, 0.25)
const TRIGGER := Color(0.95, 0.78, 0.35)
const ENEMY_BORDER := Color(0.55, 0.2, 0.22)
const DAMAGE_FLASH := Color(1.0, 0.35, 0.35)

## Fixed color meanings: one color per meaning on every screen.
## Gold = money, prices, buying · red = danger, fight, loss, selling ·
## blue = souls and shields · green = healing, level-up, merging ·
## violet = tarot, curse, events, fusion.
const MONEY := GOLD
const DANGER := Color(0.9, 0.25, 0.28)
const SPIRIT := Color(0.6, 0.85, 1.0)
const GROWTH := Color(0.35, 0.85, 0.45)
const MYSTIC := Color(0.78, 0.6, 0.98)

const SUIT_COLORS := {
	"coins": Color(0.45, 0.78, 0.4),
	"wands": Color(0.95, 0.45, 0.2),
	"cups": Color(0.3, 0.75, 0.85),
	"swords": Color(0.7, 0.6, 0.95),
}
