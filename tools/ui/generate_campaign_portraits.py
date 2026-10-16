"""Generate original vector cast portraits for the campaign comms cards."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CAST = json.loads((ROOT/'docs/plans/hero-campaign-dialogue.json').read_text())['cast']
OUT = ROOT/'assets/ui/campaign'
COLORS = {'bastion':('#d5bb78','#59656a'), 'helix':('#83d6df','#3d5362'),
          'frontier':('#d99462','#665a47')}
# Profile, hair, complexion: deliberately authored silhouettes, never real-person likenesses.
LOOK = {'aegis':('helmet','#96917f','#b89378'), 'nyx':('visor','#202b36','#c3a28d'),
        'rook':('cap','#574337','#c59a70'), 'voss':('short','#704b39','#d6ad91'),
        'kerrigan':('helmet','#9e9e91','#af8464'), 'elias':('short','#846443','#d9b292'),
        'cantor':('machine','#2b4654','#49788a'), 'arden':('short','#999d99','#bca08b'),
        'ren':('helmet','#25313b','#b8927b'), 'ilan':('long','#3d322e','#d6b49b'),
        'wren':('long','#8c5937','#c99b79'), 'hask':('beard','#c6b99a','#ae8b6a'),
        'jory':('short','#493528','#c39b78')}
OUT.mkdir(parents=True,exist_ok=True)
for name,actor in CAST.items():
    accent,armor=COLORS[actor['faction']];style,hair,skin=LOOK[name]
    detail=''
    if style in ['helmet','visor','machine']:
        detail=f'<path d="M43 58 L48 32 L72 24 L96 32 L103 58 L94 68 L49 68Z" fill="{armor}"/><path d="M49 52 L97 52 L92 66 L54 66Z" fill="#17242b"/><path d="M55 55 H91 V60 H55Z" fill="{accent}"/>'
    else:
        detail=f'<path d="M45 61 L46 37 L58 26 L85 28 L99 42 L97 61 L87 44 L58 43 L52 63Z" fill="{hair}"/>'
        if style=='long':detail+=f'<path d="M46 43 L39 101 L52 91 L55 47Z M96 44 L106 101 L92 90 L88 45Z" fill="{hair}"/>'
        if style=='beard':detail+=f'<path d="M48 75 L59 101 L74 110 L90 97 L97 74 L84 86 L61 85Z" fill="{hair}"/>'
        if style=='cap':detail+=f'<path d="M44 42 L51 23 L86 25 L99 44 L111 49 L45 51Z" fill="{armor}"/>'
    svg=f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 144 160">
<rect width="144" height="160" rx="12" fill="#172126"/>
<path d="M0 126L144 22V160H0Z" fill="#202f34"/>
<path d="M9 160L18 120L54 102H91L126 122L136 160Z" fill="{armor}"/>
<path d="M57 92H88V118L73 130L55 116Z" fill="{skin}"/>
<path d="M48 44L72 33L96 44L100 75L90 97L73 106L55 94L45 73Z" fill="{skin}"/>
<path d="M73 34L96 44L100 75L90 97L73 106L79 72Z" fill="#000" opacity=".15"/>
<path d="M54 66H63 M83 66H92" stroke="#253038" stroke-width="3"/>
<path d="M64 87H81" stroke="#765f50" stroke-width="2"/>{detail}
<path d="M18 122L43 114L56 133L43 153L11 149Z M126 122L102 114L89 133L102 153L133 149Z" fill="{accent}" opacity=".85"/>
<path d="M62 134H82V154H62Z" fill="#26363d"/><path d="M67 139H77V144H67Z" fill="{accent}"/>
</svg>'''
    (OUT/(name+'.svg')).write_text(svg+'\n')
print('Generated',len(CAST),'cast portraits')
