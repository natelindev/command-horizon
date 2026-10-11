"""Original dialogue and casting for the offline battle voice bank.

Each speaking faction/role uses a distinct male-only Kokoro style profile. Tuple order:
selection (2), movement (2), attack (2), produced (1).
"""
CAST = {
    'bastion': {
        'Infantry': ('Infantry', ['Rifle team standing by.', 'Eyes front. Waiting on you.', 'Moving as ordered.', 'Keeping formation.', 'Rifles up. Engage!', 'Covering the advance.', 'Rifle team reporting for duty.']),
        'RocketInfantry': ('RocketInfantry', ['Anti-armor team ready.', 'Show me the heavy targets.', 'Launcher secured. Moving.', 'Finding a firing position.', 'Rocket away!', 'That armor will not hold.', 'Anti-armor team deployed.']),
        'SniperInfantry': ('SniperInfantry', ['Scope is clear.', 'Watching the approaches.', 'Changing my vantage.', 'Quiet steps.', 'One clean shot.', 'Target in my sights.', 'Marksman on station.']),
        'AssaultInfantry': ('AssaultInfantry', ['Assault squad. Point us in.', 'Armor locked. Ready to breach.', 'Pushing forward.', 'Taking the front.', 'Break their line!', 'Close in. Weapons hot!', 'Assault squad ready to breach.']),
        'Hero': ('Hero', ['Marshal Aegis. Your orders.', 'We hold. Whatever comes.', 'I will lead the column.', 'Stay close. We move together.', 'Stand firm. Return fire!', 'For everyone behind us!', 'Aegis reporting. The line will hold.']),
        'Tank': ('Tank', ['Tank crew standing by.', 'Armor and ammunition checked.', 'Tracks rolling.', 'Driver, take us forward.', 'Gunner, engage!', 'Sending a shell their way.', 'Bastion armor ready.']),
        'AdvancedTank': ('AdvancedTank', ['Railgun charged and stable.', 'Give us a clear firing lane.', 'Repositioning the railgun.', 'Heavy tracks on the move.', 'Capacitors full. Fire!', 'Punching through their armor.', 'Railgun tank operational.']),
        'Helicopter': ('Helicopter', ['Strike flight checking in.', 'Flight controls are green.', 'Changing heading.', 'Flying your route.', 'Weapons free. Going in.', 'Missiles on target.', 'Strike aircraft ready for tasking.']),
        'SupplyTruck': ('SupplyTruck', ['Supply convoy checking in.', 'Cargo secure.', 'Convoy moving.', 'Taking the supply road.', 'Keeping clear of the fight.', 'Getting this cargo through.', 'Supply truck loaded and ready.']),
        'EvacTransport': ('EvacTransport', ['Rescue flight on station.', 'We have room for survivors.', 'Inbound to your position.', 'Rescue flight moving.', 'Taking evasive action.', 'Keeping our passengers safe.', 'Rescue transport ready.']),
    },
    'helix': {
        'Infantry': ('Infantry', ['Vector operator linked.', 'Signal clean. Awaiting task.', 'Following the vector.', 'Position update received.', 'Acquiring hostile signature.', 'Applying focused fire.', 'Vector operator synchronized.']),
        'RocketInfantry': ('RocketInfantry', ['Heavy target specialist online.', 'Guidance channel clear.', 'Adjusting launch geometry.', 'Moving to intercept.', 'Guidance locked. Launching.', 'Armor signature isolated.', 'Missile specialist linked.']),
        'SniperInfantry': ('SniperInfantry', ['Optics synchronized.', 'I see the weak point.', 'Relocating without a trace.', 'Taking a cleaner angle.', 'One signal. One shot.', 'Removing the interference.', 'Precision operator connected.']),
        'AssaultInfantry': ('AssaultInfantry', ['Breach operator connected.', 'Close-range systems primed.', 'Closing the distance.', 'Advancing through the gap.', 'Overwhelm their position.', 'Breach and suppress.', 'Breach operator online.']),
        'Hero': ('Hero', ['Spectre Nyx. Channel secure.', 'They have not seen us yet.', 'Moving between their blind spots.', 'Follow my signal.', 'Their defense has a flaw.', 'Disappear into the interference.', 'Nyx is in the field. Stay connected.']),
        'Tank': ('Tank', ['Needle skimmer linked.', 'Hover field holding steady.', 'Gliding to your coordinates.', 'Adjusting the approach vector.', 'Needle array discharging.', 'Piercing their formation.', 'Needle skimmer online.']),
        'AdvancedTank': ('AdvancedTank', ['Prism alignment complete.', 'Refraction chamber stable.', 'Moving the firing solution.', 'Repositioning the prism.', 'Focus the beam.', 'Light finds every weakness.', 'Prism artillery calibrated.']),
        'Helicopter': ('Helicopter', ['Wraith flight connected.', 'Airspace scan complete.', 'Changing flight vector.', 'Taking the high approach.', 'Strike window confirmed.', 'Delivering the payload.', 'Wraith striker airborne.']),
        'SupplyTruck': ('SupplyTruck', ['Logistics link established.', 'Manifest verified.', 'Route synchronized.', 'Transport proceeding.', 'Avoiding hostile contact.', 'Protecting the shipment.', 'Logistics transport connected.']),
        'EvacTransport': ('EvacTransport', ['Recovery flight connected.', 'Life support is stable.', 'Approaching the extraction point.', 'Recovery route set.', 'Evasive vector selected.', 'Keeping the cabin secure.', 'Recovery transport online.']),
    },
    'frontier': {
        'Worker': ('Worker', ['Scrapper here. What needs fixing?', 'Plenty of life in this old rig.', 'Taking the dirt road.', 'Wheels turning. Tools packed.', 'I am a mechanic, remember?', 'Getting this rig out alive.', 'Scrapper rig fueled and ready.']),
        'Infantry': ('Infantry', ['Ridge ranger. Got eyes on the trail.', 'Wind is clear. What is the call?', 'Taking the long way round.', 'Boots on the trail.', 'Make every round count!', 'Keep them off our ridge!', 'Ranger packed and ready.']),
        'RocketInfantry': ('RocketInfantry', ['Got a rocket with their name on it.', 'Just point out the big one.', 'Hauling the launcher.', 'Finding a good ridge.', 'Let us crack that tin can!', 'Sending a little thunder.', 'Rocket crew ready to ride.']),
        'SniperInfantry': ('SniperInfantry', ['Spotter here. Horizon is clear.', 'Out here, patience pays.', 'Finding higher ground.', 'Taking the quiet trail.', 'Hold still for me.', 'One round is plenty.', 'Long rifle ready.']),
        'AssaultInfantry': ('AssaultInfantry', ['Breach crew. Ready for trouble.', 'We brought the heavy kit.', 'Making our own road.', 'Coming through.', 'Give them no room!', 'Right through the front!', 'Breach crew saddled up.']),
        'Hero': ('Hero', ['Pathfinder Rook. I know a way.', 'We did not come this far to quit.', 'Follow my tracks.', 'There is always another route.', 'This ground is ours!', 'Let us give them a reason to leave.', 'Rook is here. Let us bring everyone home.']),
        'Tank': ('Tank', ['Outrider crew. Engine is warm.', 'Still runs like a beast.', 'Kicking up some dust.', 'Taking the rough road.', 'Give them the big gun!', 'Knock them off the road.', 'Outrider fueled and armed.']),
        'AdvancedTank': ('AdvancedTank', ['Ironback here. Built to last.', 'Heavy metal. Steady hands.', 'Slow and steady.', 'Moving this mountain.', 'Let the cannon talk.', 'That should get their attention.', 'Ironback rolling out.']),
        'Helicopter': ('Helicopter', ['Kestrel here. Good day to fly.', 'Rotor is steady. Sky is ours.', 'Following the valley.', 'Coming around the ridge.', 'Diving in. Hang on!', 'Give them a dust storm.', 'Kestrel gunship ready to fly.']),
        'SupplyTruck': ('SupplyTruck', ['Supply driver here.', 'Nothing fell off yet.', 'Convoy rolling.', 'Found us a road.', 'This cargo is getting through.', 'Best keep our heads down.', 'Supply rig loaded.']),
        'EvacTransport': ('EvacTransport', ['Rescue pilot here. Who needs a lift?', 'Nobody gets left out here.', 'Coming to pick you up.', 'Keep the landing zone clear.', 'Hold tight back there.', 'Taking us out of the crossfire.', 'Rescue bird ready.']),
    },
}
# Blend voice styles before inference; never layer rendered voices or shift pitch.
# All components are explicitly male in hexgrad/Kokoro-82M/VOICES.md.
MALE_VOICES = {'am_michael', 'am_fenrir', 'am_onyx', 'am_eric',
               'bm_george', 'bm_fable', 'bm_lewis'}
PROFILES = {}
BASES = {
    'bastion': ('am_michael', ['am_fenrir', 'am_onyx', 'am_eric']),
    'helix': ('bm_george', ['bm_fable', 'bm_lewis']),
    'frontier': ('am_fenrir', ['am_michael', 'am_eric', 'am_onyx']),
}
ANNOUNCERS = {}
for faction, roles in CAST.items():
    primary, supporting = BASES[faction]
    lang = 'en-gb' if faction == 'helix' else 'en-us'
    announcer = faction + '/Command'
    ANNOUNCERS[faction] = announcer
    PROFILES[announcer] = {'voices': {primary: 1.0}, 'speed': 1.0, 'lang': lang}
    for index, (role, (_, lines)) in enumerate(roles.items()):
        profile = faction + '/' + role
        weight = round(.25 + .055 * index, 3)
        secondary = supporting[index % len(supporting)]
        PROFILES[profile] = {'voices': {primary: 1.0 - weight, secondary: weight},
                             'speed': [.97, 1.02, .94, 1.05, .96][index % 5], 'lang': lang}
        roles[role] = (profile, lines)

# Stable event names mirror VoiceLines.gd, not integer enum ordinals.
ANNOUNCER_TEXT = {
    'UNIT_HELLO': 'Sir?',
    'UNIT_ACK_1': 'Yes, sir.',
    'UNIT_ACK_2': 'Acknowledged.',
    'MATCH_STARTED': 'Battle control online.',
    'MATCH_ABORTED': 'Battle control offline.',
    'MATCH_FINISHED_WITH_VICTORY': 'You are victorious.',
    'MATCH_FINISHED_WITH_DEFEAT': 'You have lost.',
    'BASE_UNDER_ATTACK': 'Your base is under attack.',
    'UNIT_UNDER_ATTACK': 'Unit under attack.',
    'UNIT_LOST': 'Unit lost.',
    'UNIT_PRODUCTION_STARTED': 'Training.',
    'UNIT_PRODUCTION_FINISHED': 'Unit ready.',
    'UNIT_CONSTRUCTION_FINISHED': 'Construction complete.',
    'NOT_ENOUGH_RESOURCES': 'Not enough resources.',
    'RESEARCH_COMPLETED': 'Research complete.',
    'LOW_POWER': 'Low power. Production slowed.',
    'POWER_RESTORED': 'Power restored.',
}
MACHINES = ['Worker', 'RepairRobot', 'CombatRobot', 'Drone']
STRUCTURES = ['CommandCenter', 'Barracks', 'VehicleFactory', 'AircraftFactory',
              'PowerPlant', 'CommandLab', 'RepairDepot', 'AntiGroundTurret', 'AntiAirTurret']
EVENTS = ['select', 'select', 'move', 'move', 'attack', 'attack', 'ready']
