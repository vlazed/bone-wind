# Bone Wind <!-- omit from toc -->

Add a bit of motion to your model

## Table of Contents <!-- omit from toc -->
- [Bone Wind](#bone-wind)
  - [Features](#features)
  - [Rational](#rational)
  - [Remarks](#remarks)
- [Disclaimer](#disclaimer)
- [Pull Requests](#pull-requests)

## Bone Wind

https://github.com/user-attachments/assets/06ce5d40-8d3c-4d76-b85c-878c423d249b

This adds a Bone Wind tool and a system, which applies a "wind" force to a bone, which makes the bone point in the direction of the wind. 

### Features
- Entity and bone hierarchy to control the bones of entities (bonemerged or not) with the wind system
- Intuitive wind pointing UI which orients itself to your world, with additional settings for amplitude and frequency of the wind effect
- (WIP) Bone angle offsets
- Additional settings to improve wind performance
- Compatibility with Stop Motion Helper's Physics Recorder!

> [!NOTE] 
> To use this with Stop Motion Helper, make sure that you are on a timeline with nonphysical bones checked. For safety, you should bake the wind effects on a separate timeline to keep your timelines clean.

### Rational

Animating ragdolls in GMod is tedious. Stop Motion Helper currently places keyframes for the pose of *all* nonphysical bones (individual bone timelines as of February 14, 2025 have not been developed yet). This makes certain elements hard to animate because of the time it takes to animate `n` number of bones on a model. 

In particular, this tool automates the presence of wind for an animation, which would have taken the user quite some time to make.

### Remarks

I suggest using this tool with *bonemerged* models with *jigglebones* (either with Easy Bonemerge Tool or Composite Bonemerge Tool with childbone editing disabled). I've tailored this tool to work with these type of entities, as they are animate independently from the nonphysical bones of the main entity. My workflow for this tool is the following:

- Bonemerge an entity with models with jigglebones (hair, clothing, other end effectors),
- Add some bones from the bonemerged models into the bone wind system, and
- Bake the wind effect onto the bonemerged models using the Physics Recorder.

Of course, the tool also works with regular nonphysical bones too, although this is not always flexible, as the physics recorder will override *all* nonphysical bones.

## Disclaimer

**This tool has been tested in singleplayer.** Although this tool may function in multiplayer, please expect bugs and report any that you observe in the issue tracker.

## Pull Requests

When making a pull request, make sure to confine to the style seen throughout. Try to add types for new functions or data structures. I used the default [StyLua](https://github.com/JohnnyMorganz/StyLua) formatting style.
