"""Original dialogue and casting for the offline battle voice bank.

Each speaking faction/role has a dedicated male voice; each robot has its own machine voice;
command never voices units. Camp mercenaries are neutral hires with one voice each, whichever
army pays them. Tuple order: selection (2), movement (2), attack (2), produced (1).
"""
import json
from pathlib import Path

# Soldiers are spoiling for a fight: Bastion are roaring zealots, Helix are gleeful
# predators, Frontier are rowdy raiders. Even support crews are amped up.
CAST = {
    'bastion': {
        'Infantry': ('Infantry', ['Rifle team! Who dies today?', 'Locked and loaded! Point me at them!',
                                  'Go, go, go!', "Double time! The fight won't wait!", 'Light them up!',
                                  'No mercy! Kill them all!', 'Rifle team, hungry for a fight!']),
        'RocketInfantry': ('RocketInfantry', ['Rockets hot! Show me some armor!',
                                              'I want something big to blow up!', 'Hauling rockets! Move it!',
                                              'Finding a kill spot!', 'Rocket out! Burn!', 'Wreck that tank!',
                                              "Rocket team! Let's wreck some armor!"]),
        'SniperInfantry': ('SniperInfantry', ["My scope is hungry! Feed it!", 'I see every one of them!',
                                              'Moving to a killing perch!', "They won't hear me coming!",
                                              'One shot! One kill!', 'Drop! Next!', "Marksman ready! Who's first?"]),
        'AssaultInfantry': ('AssaultInfantry', ["Breachers! Let's tear in!", 'Armor on! Blood up!',
                                                'Charge! Push, push!', 'Straight down their throats!',
                                                'Break them! Crush them!', 'Into the grinder! Go!',
                                                'Assault squad! Ready to break skulls!']),
        'Hero': ('Hero', ['Aegis! Give me a war!', 'The line holds! Then we crush them!', 'With me! Forward!',
                          'March! We end this today!', 'Bastion! Destroy them!',
                          'For everyone behind us! Attack!', 'Marshal Aegis! Let them come!']),
        'Tank': ('Tank', ['Tank crew! Guns loaded, blood up!', "Let's roll over somebody!",
                          'Tracks rolling! Full throttle!', 'Full speed ahead! Move it!', 'Fire! Fire! Fire!',
                          'Blow them to pieces!', 'Bastion armor! Ready to crush!']),
        'AdvancedTank': ('AdvancedTank', ['Railgun charged! Feed me targets!', 'Nothing survives this gun!',
                                          'Moving the big gun! Clear the way!', 'Heavy tracks! Crushing through!',
                                          'Capacitors full! Obliterate them!', 'Punch a hole right through them!',
                                          'Railgun tank! Ready for slaughter!']),
        'Helicopter': ('Helicopter', ['Strike flight! Weapons hot!', 'Give me something to burn!',
                                      'Banking hard! Hold on!', "Full throttle! Let's hunt!",
                                      'Going in hot! Rockets away!', 'Rain fire on them!',
                                      'Gunship ready! Give me targets!']),
        'SupplyTruck': ('SupplyTruck', ["Supply run! Let's move it!", 'Ammo for the killers!', 'Pedal down! Go!',
                                        'Clear the road! Coming through!', 'You want me in there? Fine!',
                                        "Run them over if we must!", 'Supply truck loaded! Bullets for everyone!']),
        'Fighter': ('Fighter', ['Interceptor up! Give me bandits!', 'Nothing flies in my sky!',
                                'Afterburners! Go, go!', 'Climbing! Full thrust!',
                                'Firing missiles! Bring them down!', 'Knock them out of the sky!',
                                'Interceptor jet! Hungry for bandits!']),
        'Bomber': ('Bomber', ['Heavy bomber! Bomb bays full!', 'Who gets flattened today?',
                              'Heavy bird inbound! Hold course!', 'Steady! Big payload aboard!',
                              'Bombs away! Level it!', 'Turn it all to rubble!',
                              'Heavy bomber! Loaded for a firestorm!']),
        'AntiAirVehicle': ('AntiAirVehicle', ['Flak tank! Radar is hungry!',
                                              'Let them fly! My guns are waiting!',
                                              'Flak tracks rolling! Move!', 'Moving the guns! Eyes up!',
                                              'Flak up! Shred them!', 'Bring those birds down!',
                                              'Flak tank! Radar up, guns hot!']),
    },
    'helix': {
        'Infantry': ('Infantry', ['Vector operator! I want blood!', 'Signal clean! Let me hunt!',
                                  'Hunting! Moving!', 'Closing in on the prey!', 'Target found! Kill it!',
                                  'Tear them apart!', "Vector operator online! Who's next?"]),
        'RocketInfantry': ('RocketInfantry', ['Missiles armed! Show me armor!', 'Lock and launch! I love this part!',
                                              'Moving to the kill angle!', 'Intercept course! Go!',
                                              'Locked! Launching!', 'Burn their armor!',
                                              'Missile specialist! Ready to burn!']),
        'SniperInfantry': ('SniperInfantry', ['Optics hungry! I see the weak point!',
                                              'They glow so bright in my scope!', 'Slipping away! Fast!',
                                              'New angle! New victims!', 'One signal! One kill!', 'Erase them!',
                                              "Precision operator! Let's hunt!"]),
        'AssaultInfantry': ('AssaultInfantry', ['Breach operator! Unleash me!', 'Close range is where I live!',
                                                'Closing the distance! Fast!', 'Through the gap! Go!',
                                                'Overwhelm them! Now!', 'Rip them out of cover!',
                                                "Breach operator! Let's break them!"]),
        'Hero': ('Hero', ['Spectre Nyx! The hunt begins!', "They can't see us! Delicious!",
                          'Into their blind spots! Move!', 'Follow my signal! Swift!',
                          'Their defense has a flaw! Strike!', 'Vanish! Then kill!',
                          "Nyx in the field! They're already dead!"]),
        'Tank': ('Tank', ['Needle skimmer! Hungry for targets!', "Hover field charged! Let's hunt!",
                          'Gliding in! Fast!', 'Skimming in for the kill!', 'Needles away! Shred them!',
                          'Pierce their formation!', 'Needle skimmer! Ready to shred!']),
        'AdvancedTank': ('AdvancedTank', ['Prism aligned! Something must burn!', 'Feed the beam!',
                                          'Moving the firing solution!', 'Repositioning! Hurry!',
                                          'Focus the beam! Melt them!', 'Burn! Burn it all!',
                                          'Prism artillery! Let it burn!']),
        'Helicopter': ('Helicopter', ['Wraith flight! Weapons screaming!', 'This airspace is mine!',
                                      'Diving in! Hold on!', 'High approach! Hunting!', 'Strike window! Kill!',
                                      'Payload away! Die!', "Wraith striker! Let's hunt!"]),
        'SupplyTruck': ('SupplyTruck', ['Logistics! Keeping the killers fed!', 'Manifest locked! Move!',
                                        'Route set! Full speed!', 'Rolling! Out of my way!',
                                        'Not my fight! Moving!', 'Protect the shipment!',
                                        'Logistics transport! Rolling hot!']),
        'Fighter': ('Fighter', ['Talon online! Something to chase?', 'Their pilots are prey!',
                                'Vector set! Fast!', 'Burners lit! Climbing!', 'Locked! Missile away!',
                                'Clip their wings! Kill!', "Talon interceptor! Let's hunt the sky!"]),
        'Bomber': ('Bomber', ['Shrike bomber! Payload armed!', 'Show me what should burn!',
                              'Inbound! Steady and silent!', 'Holding altitude! Swift!',
                              'Payload released! Burn!', 'Erase that position!',
                              'Shrike bomber! Bays full of fire!']),
        'AntiAirVehicle': ('AntiAirVehicle', ['Halo skimmer! The sky is my hunting ground!',
                                              'Interceptors armed! Bring me aircraft!',
                                              'Skimming! Repositioning!', 'Gliding in! Covering the sky!',
                                              'Interceptors away! Track and kill!',
                                              'Pluck them out of the air!',
                                              'Halo skimmer! Nothing flies past me!']),
    },
    'frontier': {
        'Worker': ('Worker', ['Scrapper! What needs smashing?', 'This rig is itching for a fight!',
                              'Dirt road! Floor it!', 'Wheels turning! Go!', 'You want a mechanic to fight? Fine!',
                              'Getting this rig out alive!', 'Scrapper rig! Fueled and furious!']),
        'Infantry': ('Infantry', ["Ridge ranger! Let's shoot something!", "What's the call? Let's ride!",
                                  'Moving out! Move, move!', 'Boots on the trail! Go!', 'Make every round count!',
                                  'Keep them off our ridge! Fire!', "Ranger ready! Let's raise hell!"]),
        'RocketInfantry': ('RocketInfantry', ['This rocket has their name on it!', 'Point out the big one!',
                                              'Hauling the launcher! Move!', 'Finding a ridge! Go!',
                                              'Crack that tin can!', 'Thunder incoming!',
                                              'Rocket crew! Ready to blow stuff up!']),
        'SniperInfantry': ('SniperInfantry', ["Spotter here! Horizon's full of targets!",
                                              "Patience? I'm itching!", 'Higher ground! Go!',
                                              'Quiet trail! Then boom!', 'Hold still for me!', 'One round! Done!',
                                              'Long rifle! Hungry!']),
        'AssaultInfantry': ('AssaultInfantry', ['Breach crew! Bring the trouble!', 'Heavy kit! Heavy hurt!',
                                                'Making our own road!', 'Coming through! Move!',
                                                'No room! Smash them!', 'Right through the front! Charge!',
                                                'Breach crew! Saddled up and mad!']),
        'Hero': ('Hero', ["Pathfinder Rook! Let's start a fight!", "We didn't come this far to quit!",
                          'Follow my tracks! Fast!', 'Another route! Go, go!', 'This ground is ours! Kill them!',
                          'Make them run!', 'Rook is here! Time to bleed them!']),
        'Tank': ('Tank', ["Outrider! Engine's screaming!", "Runs like a beast! Let's eat!",
                          'Kicking up dust! Go!', 'Rough road! Hang on tight!', 'Big gun! Fire!',
                          'Knock them off the road!', 'Outrider! Loaded and angry!']),
        'AdvancedTank': ('AdvancedTank', ['Ironback! Built to crush!', 'Heavy metal! Heavy hate!',
                                          'Moving out! Crush everything!', 'Moving this mountain!',
                                          'Let the cannon scream!', 'Flatten them!',
                                          'Ironback rolling! Get out of the way!']),
        'Helicopter': ('Helicopter', ["Kestrel! Let's go hunting!", "Rotor's hot! Sky is ours!",
                                      'Down the valley! Go!', 'Around the ridge! Hold tight!',
                                      'Diving in! Hang on!', 'Dust storm! Eat it!',
                                      "Kestrel gunship! Let's fly!"]),
        'SupplyTruck': ('SupplyTruck', ["Supply driver! Let's roll!", 'Nothing fell off yet!',
                                        'Convoy rolling! Go!', 'Found a road! Floor it!',
                                        "This cargo's getting through!", 'Heads down! Punch it!',
                                        "Supply rig loaded! Let's ride!"]),
        'Fighter': ('Fighter', ["Hornet! Let's stir up some trouble!", 'Point me at a pilot!',
                                'Throttle wide open! Go!', 'Over the hills! Hang on!',
                                'Sting them! Shoot them down!', 'Chase them down! Fire!',
                                'Hornet fighter! Fueled and spoiling for it!']),
        'Bomber': ('Bomber', ['Buzzard! Loaded with trouble!', 'Bombs loaded! Give us a target!',
                              'Big bird flying! Hold tight!', 'Low and loud! Go!', 'Drop the lot! Boom!',
                              'Bury them in the dirt!', "Buzzard bomber! Let's wreck something!"]),
        'AntiAirVehicle': ('AntiAirVehicle', ['Ripsaw truck! Sky is full of targets!',
                                              'Let them fly! I dare them!', 'Truck rolling! Hang on!',
                                              'Bumpy road! Guns up!', 'Tear them out of the sky!',
                                              'Shred that bird! Fire!', 'Ripsaw truck! Loaded and looking up!']),
    },
}
# Neutral camp contracts: the same sellswords answer whichever army hires them.
MERCENARY = 'mercenary'
MERCENARY_CAST = {
    'MercenaryWarden': ('MercenaryWarden', ['Iron Warden! Paid up and ready to brawl!',
                                            'Shield up! Let them try me!', 'Marching! Shield first!',
                                            'Heavy boots! Coming through!', 'Up close! Grind them down!',
                                            'Behind the shield! Fire!',
                                            "Iron Warden! You've bought yourself a wall!"]),
    'MercenaryRanger': ('MercenaryRanger', ['Ranger here! I see them all!', 'Good coin, better hunting!',
                                            'Fast and quiet! Moving!', 'Scouting ahead! Keep up!',
                                            'In my sights! Drop!', 'Clean shot! Next!',
                                            'Ranger! Contract signed! Who dies first?']),
    'MercenaryLancer': ('MercenaryLancer', ['Breach Lancer! Show me a wall!',
                                            'Pay me and point me at armor!', 'Hauling the lance! Move!',
                                            'Finding a firing line!', 'Lance away! Crack it open!',
                                            'Blow a hole straight through!',
                                            'Breach Lancer! Heavy rockets for hire!']),
}
STOP_TEXT = {'bastion': 'Holding! Let them come!', 'helix': 'Holding! Waiting for prey!',
             'frontier': "Fine! We'll wait!", MERCENARY: 'Holding! Your coin, your call!'}
WORKER_TASKS = {'gather': 'Rip it up! Salvage!', 'construct': 'Hammers out! Build it!',
                'repair': 'Patch it up! Fast!'}
# Announcers are exclusive Kokoro voices. Every unit and robot clones its own reference voice
# (VCTK, CC BY 4.0, and Unmute voice donations, CC0: https://huggingface.co/kyutai/tts-voices);
# never an announcer, a blend, or a rate/pitch variant of another unit's voice.
MALE_VOICES = {'am_michael', 'bm_george', 'am_fenrir'}
COMMAND_VOICES = {'bastion': 'am_michael', 'helix': 'bm_george', 'frontier': 'am_fenrir'}
# Stable explicit assignments (from select_voice_cast.py, reviewed): adding a role must never
# recast existing units. Crew are native speakers, one accent family per army: Bastion North
# American, Helix English, Frontier Irish/Australian; the neutral mercenaries are Scottish, an
# accent no army uses. Reference metrics: voice-pool.json.
UNIT_VOICES = {
    'bastion': {
        'Hero': 'vctk/p360', 'AdvancedTank': 'Bobby_McFern', 'Tank': 'vctk/p311',
        'AssaultInfantry': 'vctk/p345', 'SniperInfantry': 'Greggy', 'RocketInfantry': 'vctk/p334',
        'Infantry': 'vctk/p363', 'SupplyTruck': 'oldNerd3',
        'Helicopter': 'BrokenHypocrite', 'Bomber': 'Antoni', 'AntiAirVehicle': 'MrHat',
        'Fighter': 'Gonzalo-1',
    },
    'helix': {
        'Hero': 'Nyx', 'AdvancedTank': 'vctk/p274', 'Tank': 'vctk/p287',
        'AssaultInfantry': 'vctk/p232', 'SniperInfantry': 'vctk/p258', 'RocketInfantry': 'vctk/p243',
        'Infantry': 'vctk/p279', 'SupplyTruck': 'vctk/p227',
        'Helicopter': 'vctk/p273', 'Bomber': 'Midlands_Bedfordshire_Dialect', 'AntiAirVehicle': '29da',
        'Fighter': 'vctk/p286',
    },
    'frontier': {
        'Hero': 'vctk/p326', 'AdvancedTank': 'vctk/p245', 'Tank': 'Mystery_Sir',
        'AssaultInfantry': 'vctk/p304', 'SniperInfantry': 'vctk/p364', 'RocketInfantry': 'vctk/p292',
        'Infantry': 'vctk/p226', 'Worker': 'vctk/p298', 'SupplyTruck': 'vctk/p315',
        'Helicopter': 'Lake', 'Bomber': 'Roscoe', 'AntiAirVehicle': 'Jeremy_Q', 'Fighter': 'vctk/p374',
    },
}
MERCENARY_VOICES = {'MercenaryWarden': 'vctk/p281', 'MercenaryLancer': 'vctk/p275',
                    'MercenaryRanger': 'vctk/p255'}
ROBOT_VOICE_REFERENCES = {
    'bastion/Worker': '7020', 'bastion/RepairRobot': 'Hannah', 'bastion/CombatRobot': 'vctk/p301',
    'bastion/Drone': 'vctk/p248', 'helix/Worker': 'vctk/p303', 'helix/RepairRobot': 'fc96',
    'helix/CombatRobot': 'Sp46', 'helix/Drone': 'vctk/p313', 'frontier/RepairRobot': 'bc98',
    'frontier/CombatRobot': 'thepolishdane', 'frontier/Drone': 'vctk/p312',
}

# Robots speak in short machine reports; ROBOT_VOICES in robot_voice.py makes each one sound
# like its own hardware. Order: selection (2), movement (2), attack (2), produced (1).
ROBOT_CAST = {
    'bastion': {
        'Worker': {'lines': ['Engineer rover online.', 'Build queue empty. Awaiting task.',
                             'Relocating.', 'Route plotted.', 'Non-combat unit. Complying.',
                             'Rerouting to target.', 'Engineer rover deployed.'],
                   'tasks': {'gather': 'Harvest cycle engaged.', 'construct': 'Construction protocol active.',
                             'repair': 'Structural repair underway.'},
                   'stop': 'Motion halted.'},
        'RepairRobot': {'lines': ['Repair unit online.', 'Diagnostics nominal.', 'Moving to assist.',
                                  'Servos engaged.', 'Repair unit. No weapons.', 'Moving to support.',
                                  'Repair robot operational.'],
                        'tasks': {'repair': 'Commencing repairs.'}, 'stop': 'Standing by.'},
        'CombatRobot': {'lines': ['Combat walker. Weapons online.', 'Awaiting target designation.',
                                  'Walker advancing.', 'Walker in motion.', 'Target acquired. Engaging.',
                                  'Hostile designated. Firing.', 'Combat walker armed and ready.'],
                        'stop': 'Halting. Weapons hot.'},
        'Drone': {'lines': ['Recon drone airborne.', 'Sensors active.', 'Flight path set.',
                            'Scouting ahead.', 'Unarmed. Marking target.', 'Tracking hostile.',
                            'Recon drone launched.'],
                  'stop': 'Hovering.'},
    },
    'helix': {
        'Worker': {'lines': ['Mule engineer linked.', 'Fabrication matrix idle.', 'Path computed.',
                             'Relocating to vector.', 'Combat parameters absent.',
                             'Redirecting to coordinates.', 'Mule engineer synchronized.'],
                   'tasks': {'gather': 'Extraction sequence initiated.',
                             'construct': 'Fabrication sequence initiated.',
                             'repair': 'Restoring structural integrity.'},
                   'stop': 'Motion suspended.'},
        'RepairRobot': {'lines': ['Mender online.', 'Nanite reserves full.', 'Mender relocating.',
                                  'Vector accepted.', 'Mender has no weapons.', 'Following the vector.',
                                  'Mender robot active.'],
                        'tasks': {'repair': 'Mending in progress.'}, 'stop': 'Mender suspended.'},
        'CombatRobot': {'lines': ['Lancer walker linked.', 'Lance capacitors charged.', 'Lancer advancing.',
                                  'Stride synchronized.', 'Lance discharge authorized.',
                                  'Target isolated. Discharging.', 'Lancer walker online.'],
                        'stop': 'Lancer holding.'},
        'Drone': {'lines': ['Kite scout aloft.', 'Optical array active.', 'Kite repositioning.',
                            'Survey vector set.', 'Kite is unarmed. Painting target.',
                            'Hostile signature logged.', 'Kite scout launched.'],
                  'stop': 'Kite holding station.'},
    },
    'frontier': {
        'RepairRobot': {'lines': ['Patch crawler, ready.', 'Spare parts loaded.', 'Crawling over.',
                                  'On my way.', 'No guns. Just wrenches.', 'Crawling that way.',
                                  'Patch crawler assembled.'],
                        'tasks': {'repair': 'Patching it up.'}, 'stop': 'Crawler parked.'},
        'CombatRobot': {'lines': ['Jackal rig. Guns loaded.', 'Rig is rattling. Ready.', 'Jackal moving.',
                                  'Marching forward.', 'Jackal engaging!', 'Tearing into them!',
                                  'Jackal rig bolted together.'],
                        'stop': 'Jackal holding.'},
        'Drone': {'lines': ['Lookout drone up.', 'Eyes in the sky.', 'Lookout heading out.',
                            'Buzzing over.', 'Unarmed. Spotting target.', 'Got eyes on them.',
                            'Lookout drone flying.'],
                  'stop': 'Lookout circling.'},
    },
}

# Delivery is part of the performance, not the identity. Soldiers are always fired up; attack
# calls are the most intense. Chatterbox: higher exaggeration is more intense; lower
# cfg_weight keeps intense lines from rushing. Above ~1.0 voices screech and lose identity.
EVENT_DELIVERY = {
    'select': (.75, .35), 'move': (.8, .35), 'attack': (.95, .3), 'ready': (.85, .35),
    'stop': (.75, .35), 'gather': (.8, .35), 'construct': (.8, .35), 'repair': (.8, .35),
    'low_health': (1., .3), 'kill': (.85, .35),
}
TEMPERAMENT = {'Hero': .05, 'AssaultInfantry': .05, 'SniperInfantry': -.1, 'Fighter': .05,
               'MercenaryWarden': .05, 'MercenaryRanger': -.1}
FACTION_TEMPERAMENT = {'bastion': 0., 'helix': 0., 'frontier': .05, MERCENARY: .05}


def delivery(speaker, event):
    profile = PROFILES[speaker]
    if profile['engine'] != 'chatterbox':
        return None
    if profile.get('robot'):
        # Machines report evenly; intensity would only smear words under the processing.
        return {'exaggeration': .3, 'cfg_weight': .5, 'temperature': .7}
    faction, role = speaker.split('/')
    intensity, cfg = EVENT_DELIVERY[event]
    intensity += TEMPERAMENT.get(role, 0) + FACTION_TEMPERAMENT[faction]
    return {'exaggeration': round(min(max(intensity, .3), 1.), 2), 'cfg_weight': cfg,
            'temperature': .8}


POOL = json.loads((Path(__file__).with_name('voice-pool.json')).read_text())


# Crew must sound like native speakers. VCTK speakers carry their own reported accent. A
# donation counts only with confident English and either a confident native-variety score or
# an accent classifier that hesitates only between native varieties (its three strongest).
CORPUS_ACCENTS = {'American': 'us', 'Canadian': 'canada', 'English': 'england',
                  'Australian': 'australia', 'Irish': 'ireland', 'NorthernIrish': 'ireland',
                  'Scottish': 'scotland'}
NATIVE_VARIETIES = {'us', 'canada', 'england', 'australia', 'ireland', 'scotland', 'wales',
                    'newzealand'}


def native_accent(info):
    if info['folder'] == 'vctk':
        return CORPUS_ACCENTS.get(info['corpus_accent']) if info['gender'] == 'M' else None
    if (info['english'] >= .99 and info['accent'] in {'us', 'canada', 'england', 'australia'}
            and info['accent_scores'][info['accent']] >= .75):
        return info['accent']
    if info['english'] >= .99 and set(info['accent_scores']) <= NATIVE_VARIETIES:
        return info['accent']
    return None


def cloned(name, **extra):
    info = POOL[name]
    return {'engine': 'chatterbox', 'reference': info['folder'] + '/' + info['file'].split('/')[-1],
            'reference_sha256': info['sha256'], 'reference_license': info['license'], **extra}


# A role without an assigned voice has no profile, so validate_cast rejects it until
# select_voice_cast.py proposes one.
PROFILES = {}
ANNOUNCERS = {}
for faction, roles in CAST.items():
    announcer = faction + '/Command'
    ANNOUNCERS[faction] = announcer
    PROFILES[announcer] = {
        'engine': 'kokoro', 'voices': {COMMAND_VOICES[faction]: 1.0},
        'speed': 1.0, 'lang': 'en-gb' if faction == 'helix' else 'en-us',
    }
    for role, (_, lines) in roles.items():
        profile = faction + '/' + role
        if role in UNIT_VOICES[faction]:
            PROFILES[profile] = cloned(UNIT_VOICES[faction][role], max_word_error=.25)
        roles[role] = (profile, lines)
    for role, script in ROBOT_CAST[faction].items():
        profile = faction + '/' + role
        PROFILES[profile] = cloned(ROBOT_VOICE_REFERENCES[profile], robot=True, max_word_error=.4,
                                   min_similarity=0.)
        ROBOT_CAST[faction][role] = (profile, script)
for role, (_, lines) in MERCENARY_CAST.items():
    profile = MERCENARY + '/' + role
    if role in MERCENARY_VOICES:
        PROFILES[profile] = cloned(MERCENARY_VOICES[role], max_word_error=.25)
    MERCENARY_CAST[role] = (profile, lines)

# Stable event names mirror VoiceLines.gd, not integer enum ordinals.
ANNOUNCER_TEXT = {
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
              'PowerPlant', 'CommandLab', 'RepairDepot', 'AntiGroundTurret', 'AntiAirTurret',
              'ForwardRefinery']
EVENTS = ['select', 'select', 'move', 'move', 'attack', 'attack', 'ready']
