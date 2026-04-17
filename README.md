# BlisteringScalesAlert 

A WoW addon for Augmentation Evokers that shows a single on-screen alert when your Blistering Scales buff is not active on a tank in your group.

That is the entire job. It does nothing else.

---

## What it does

When you are playing Augmentation Evoker, out of combat, in a group that has at least one player assigned the Tank role, and none of those tanks currently have your Blistering Scales buff on them, a text alert appears on screen. When the buff lands, the alert disappears. When you enter combat, the alert disappears. When you leave the group, the alert disappears. It stays out of your way unless the one thing it watches for is actually true.

The alert shows the name of the tank or tanks you need to cover, so you do not have to guess who to target.

---

## Why it is not noise

A lot of reminder addons run constantly and fire events all the time. This one is built to do as little as possible until it is actually needed.

The high-frequency aura scanning event is only registered when you are an Augmentation Evoker and you are outside of combat. The moment you pull, the event unregisters entirely. The moment you leave combat it re-registers, checks once, and either shows or stays hidden. There is no polling, no timer, and no repeated scanning during a fight.

The addon also only looks at units that the game has explicitly flagged as Tanks by role assignment. It does not scan every group member on every event. If the group has no assigned tanks it does nothing.

Blistering Scales cast by another Augmentation Evoker in your group does not satisfy the check. The alert is only suppressed when your own cast is on a tank. The addon uses a protected aura read wrapped in error handling to distinguish your auras from another player's without causing Lua taint errors in the WoW 12.x client.

---

## When the alert will appear

All of the following must be true at the same time:

- Your active specialization is Augmentation
- You are in a party or raid
- At least one player in that group has the Tank role assigned
- None of those tanks currently have your Blistering Scales buff
- You are not in combat

If any one of those conditions is false, the alert is hidden.

---

## When the alert will not appear

- Any other Evoker specialization, including Devastation and Preservation
- Solo play with no group
- A group where no one has been assigned the Tank role (for example an open-world group of all DPS)
- Any time you are in combat, regardless of buff status
- When your Blistering Scales is already active on a tank

This means the alert is invisible during actual encounters. It exists only in the window between pulls when you have a chance to re-apply the buff. In high-end content that window is short and the reminder is useful. In casual content or when grouping without formal tank assignments it simply never fires.

---

## Settings

Open the settings panel with `/bsa` or through Interface, AddOns in the game menu.

**Font Size** adjusts the size of the alert text from 18pt to 48pt. The subtitle line below it scales proportionally.

**Text Color** sets the color of the main alert line. The subtitle remains white for readability at all sizes.

**Drag to Reposition** lets you click and drag the alert frame to any position on screen. Click the button a second time to lock it in place. The position is saved between sessions.

**Reset Position** returns the alert to the default location at the top-center of the screen.

---

## Slash commands

`/bsa` opens the settings panel.

`/bsa state` prints a full status dump including your current spec, combat state, detected tanks, and whether each tank has the buff. Useful for checking that the addon sees your group correctly.

`/bsa log` prints the last 40 internal events in order, including every aura check, roster change, spec change, and combat transition. Useful for tracing unexpected behavior.

`/bsa check` forces an immediate rescan of tanks and buff status.

`/bsa tanks` lists every unit currently identified as a tank in your group along with their role assignment.

`/bsa show` forces the alert visible regardless of conditions. Use this to preview placement and styling.

`/bsa hide` hides the alert.

`/bsa spellid` confirms that the game can resolve the Blistering Scales spell ID, which can help rule out patched spell data as a source of problems.

`/bsa help` lists all commands.

---

## Saved variables

The addon stores one saved variable table called `BSADB`. It holds your font size, color choice, and alert frame position. These persist across sessions and characters on the same account. Deleting the saved variable file resets everything to default.

---

## Compatibility

The addon targets the WoW 12.x client API. It uses `C_UnitAuras.GetAuraSlots` and `C_UnitAuras.GetAuraDataBySlot` for aura detection, and `Settings.RegisterCanvasLayoutCategory` for the options panel.

---

## Source

Repository: https://github.com/Seems-Good/BlisteringScalesAlert

Website: https://seemsgood.org
