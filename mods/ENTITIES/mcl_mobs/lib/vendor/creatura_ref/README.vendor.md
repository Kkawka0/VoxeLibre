\# creatura\_ref



Reference snapshot of upstream \*\*Creatura\*\* code, stored locally for research and implementation guidance.



\## Purpose



This directory exists only as \*\*reference code\*\* for improving pathfinding / navigation in VoxeLibre `mcl\_mobs`.



It is \*\*not\*\* a runtime dependency.

It must \*\*not\*\* be loaded by the game automatically.

Do not add `dofile(...)` or any other direct integration from this folder unless a deliberate implementation step requires copying/adapting specific code.



\## Upstream



Source project: `ElCeejo/creatura`

Vendored from upstream for offline inspection and adaptation.



\## Intended use



Developers may study and adapt ideas or selected code related to:



\- pathfinding

\- waypoint following

\- local replanning

\- line-of-sight checks

\- movement execution



The goal is to improve VoxeLibre's existing `mcl\_mobs` navigation, not to replace the whole mob framework with Creatura.



\## Notes



\- Keep this folder as reference material.

\- If any code is copied/adapted into VoxeLibre, document that in the relevant commit/PR.

\- Preserve the upstream license file included in this directory.
