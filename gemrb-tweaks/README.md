# GemRB Tweaks

This mod is a collection of small GemRB tweaks and a user-friendly way to make the
gameplay richer, different or both.

Current components:
- IWD2/HOW-style detailed combat feedback for other games
- Wisdom-based experience modifier
- 10% bonus experience as per BG2, regardless of wisdom
- Maximum HP on level up for BG1
- All mage schools available to gnomes
- Skip load screens

TODO: 
- add more tweaks from https://gemrb.org/Modding.html#mod-ideas
- add strings and mod modal.2da for iwd1 and bg1: https://github.com/gemrb/gemrb/issues/261
- add uninjured/.../near death strings for bg1 and set them in strings.2da


## Components

### IWD2/HOW-style detailed combat feedback for other games
This adds extra strings to the games, so combat feedback can be more detailed.
Damage types are reported, plus bonus and resisted damage, just like in IWDs.

For a screenshot, check this:
http://lynxlynx.info/bugs/iwd2stylecombat2.jpg

### Wisdom-based experience modifier
This gives everyone a bonus or malus to the experience gained depending on
their wisdom. This feature was only known in PST, where it had no penalties and
mostly 2% or 3% steps of improvement. 

For example, choosing the 2% table means that a character with 5 wisdom will receive 10% less xp,
while a sage with 18 will receive 16% more.

NOTE: the displayed string for xp gained will not change, since it is party based (same for quest xp).

#### 10% bonus experience as per BG2, regardless of wisdom
Just reinstates the player-favouring cheat the original BG2 implemented. Can
be applied to any game.

### Maximum HP on level up for BG1
It was the only game without this setting or at least not nicely exposed.

### All mage schools available to gnomes
In the originals, they were restricted to illusionists.

### Skip load screens
This is mainly an example mod to show how to override python files.
In general what is needed for mods like that:
- to provide a file of the same name as the one the engine uses
- installing it to `python` in the game dir (which this component does)
- if you're not starting with a copy of the original file, make sure to
  provide or stub out the callbacks the engine uses (`SetLoadScreen` for example).
  To find them, you can search the GemRB codebase for `RunFunction.*filename` —
  for this component `RunFunction.*LoadScreen` shows two functions need to be defined.

## Installation

**As of WeiDU version 247, you can install this mod like any other.**
Make sure to run GemRB at least once on this install, so WeiDU will know
where to look for files.

Run WeiDU from the game dir:
```
   weidu gemrb-tweaks/gemrb-tweaks.tp2
```
