# Menu and campaign art expansion

## Stage 1: Audit and art direction
- Review menu coverage, pause presentation, dialogue data and existing commander paintings.
- Preserve the grounded industrial style and each faction's materials and colors.

## Stage 2: Generate and integrate
- Generate three faction environment paintings and thirteen individual speaker portraits with the built-in imagegen tool.
- Save project assets and exact prompts; retain existing art.
- Randomize menu artwork when shown, avoid consecutive repeats, and add art to pause.
- Use matching portraits throughout campaign dialogue, briefings and mission selection.

## Stage 3: Verify
- Check resource coverage and randomization behavior, pause/resume and campaign captions.
- Render menus and campaign samples at normal and compact sizes; inspect captures.
- Run relevant existing regressions and report limitations.

## Agent progress
- Audit complete: one shared menu painting, blur-only pause, thirteen flat SVG speaker portraits; painted commander briefing art supplies the style and identity references.
- Generated and integrated three faction environment paintings and thirteen painted cast portraits using the built-in imagegen tool. Exact prompts are in `art/menu-campaign-art/prompts.json`; originals remain intact.
- Front-end menus and both battle-menu implementations now select artwork on display. The five-background gallery avoids immediate repeats and uses a separate random generator. Skirmish/Campaign preserve prior tactical pause, selection and controls.
- Connected every conversation portrait and added missing briefing portraits; updated hero HUD art, campaign mission boards, hub headers and archive speakers. Dialogue avatars now have an 80-pixel minimum.
- Verification complete: nine checks passed, including campaign conversations and menus, hub behavior, randomization/pause regression, all-faction rendered HUD review, and 1,152 briefing paragraph/layout cases with portraits enabled. Reviewed live dialogue in all three factions, English/Chinese and compact 720p layouts.
- Render fixture timing and combat-interruption issues were corrected before the final clean capture run. Exact results, asset hashes and the menu test's shutdown warnings are recorded in `art/menu-campaign-art/verification.json`. Packaged-export acceptance was not part of this pass.
