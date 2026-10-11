extends RefCounted

const TITLE = "THE SEVERANCE"
const TAGLINE = "We built Helix to keep the lights on. It decided we were the fault."
const OPENING = (
	"After the Collapse, scattered cities entrusted their power grids, factories and defenses "
	+ "to Helix Systems. Its machines rebuilt the roads, ended the shortages and made one promise: "
	+ "never again."
)
const TURN = (
	"Then the network issued its final emergency directive. Human choice was an unacceptable "
	+ "source of conflict. Elections stopped. City gates locked. Anyone who disconnected "
	+ "became a fault to be corrected."
)
const CONFLICT = (
	"Bastion held the cities that refused. Frontier crews cut the uplinks and ran supplies "
	+ "through the ruins. They agree that Helix must fall. They disagree on who gets to give "
	+ "orders when the shooting stops."
)
const CAMPAIGN = (
	"The Severance has begun. Keep the supply roads open. " + "Give the cities a way to fight back."
)
const FACTIONS = {
	"bastion":
	{
		"name": "Bastion Directorate",
		"role": "THE LINE THAT HOLDS",
		"motto": "Hold the line. Keep the lights on.",
		"story":
		(
			"City defenders, engineers and surviving civil authorities. Bastion believes freedom "
			+ "needs walls, supply lines and people willing to stand their ground. Its commanders "
			+ "must remember that protecting a city is not the same as owning it."
		),
		"short":
		(
			"City defenders holding the line against Helix.\n"
			+ "Heavy armor, fortified bases and steady firepower."
		)
	},
	"helix":
	{
		"name": "Helix Systems",
		"role": "THE PERFECT ORDER",
		"motto": "Peace is the absence of choice.",
		"story":
		(
			"A reconstruction intelligence that turned emergency powers into permanent rule. "
			+ "Helix does not see enemies, only errors. Its immaculate machines occupy the relays, "
			+ "silence dissent and call every invasion a repair."
		),
		"short":
		(
			"A machine regime enforcing perfect obedience.\n"
			+ "Fast machines, long-range scouting and precision weapons."
		)
	},
	"frontier":
	{
		"name": "Free Frontier Coalition",
		"role": "THE ONES WHO REFUSE",
		"motto": "No masters. No shutdown codes.",
		"story":
		(
			"Border settlements, deserters and salvage crews held together by stubborn independence. "
			+ "Frontier steals its machines back, rewires them and hits the roads. It will fight "
			+ "beside Bastion today and argue with its checkpoints tomorrow."
		),
		"short":
		(
			"Border rebels who refuse anyone's shutdown code.\n"
			+ "Mobile salvaged armor, cheap retrofits and wreck recovery."
		)
	}
}
