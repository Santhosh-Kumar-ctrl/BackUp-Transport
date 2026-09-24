# Design system: "Transit signage"

The app should look like a transit authority's product, not a SaaS template. Everything
visual comes from real wayfinding: road and station signs, metro line maps, departure
boards, bus number plates, punched tickets.

Review renders live in `frontend/test/screenshots/`. Regenerate them with
`flutter test test/screenshots_test.dart --run-skipped --update-goldens`.

## Tokens (`tokens.dart`)
| Token | Hex | Use, and only this |
|---|---|---|
| `enamel` | `#EEF1F3` | page background (cool painted sign plate) |
| `signBlue` | `#123E63` | structural panels / headers, always with white type |
| `board` | `#17212B` | departure board, driver screens |
| `led` | `#FFB81C` | **live figures only**: expected times, delays on the board, focus rings |
| `ink` / `inkSoft` | `#1B2733` / `#52606D` | text |
| `late` | `#D7261E` | delay, over capacity, cancelled |
| `go` | `#1C8A4B` | on time, boarded, arrived |
| `caution` | `#F2A900` | nearly full, check, with ink text |
| route colours | per route | **identity only** (badge, line, band). The palette in `admin_network_screen.dart` avoids red/amber/green |

**Type:** Overpass (400/600/800, bundled) for everything. It's derived from Highway Gothic,
the road-sign face. Use tabular figures for anything that lines up (`TransitType.figure`, `display`).
Labels are **sentence case**, as on real signs. Don't use all-caps eyebrows.

**Shape:** 4px enamel-sign radius (`Radii.sign`). No shadows, no gradients. Separate things
with rules and coloured edges, not floating cards.

## Signature widgets (`widgets/`)
| Widget | What it is |
|---|---|
| `LineDiagram` | vertical line map: passed stops grey, bus marker on the current segment, "You" roundel, square campus terminus, struck-through timetable times under live expected times. **The one memorable element**: give it room. |
| `RouteBadge` | square route tile. Pass `rim: true` on dark panels |
| `NumberPlate` | bus registration drawn as a plate (`TN 09 AB 1401`) |
| `DepartureRow` | one line of the dark departure board (responsive: wide row / stacked) |
| `SeatBlocks` | occupancy as a top-down seat plan (2 + aisle + 2), red seats past capacity |
| `StatusPlate` | small coloured plate with a `Tone` (late/go/caution/info/neutral) |
| `SignHeader` | sign-blue (or board) header panel with leading badge / trailing action |
| `SignButton` | big flat action (`primary`, `go`, `danger`, `quiet`, `onDark`) with an LED focus rim |
| `TicketStub` | boarding receipt: the app's **single** orchestrated motion (stamp) |
| `SignNotice` | empty/error state: coloured edge, plain words, one action |
| `AsyncBody` | loading/error/data wrapper in house style (keeps old data while refreshing) |

## Rules
1. Import `design/design.dart`. Don't hand-pick colours or font sizes in screens.
2. Colour means something. Never use `late`/`go`/`caution` decoratively, and never use a route colour for status.
3. Write copy from the rider's side: "Scan to board", "Running late", "Tell riders". Errors say what happened and what to do.
4. Motion: only the ticket stamp and functional progress (QR countdown). Respect `MediaQuery.disableAnimations`.
5. Every screen must work at 360px wide with a 16px gutter.
6. Avoid: gradients, glassmorphism, purple accents, rounded card grids with drop shadows,
   emoji, all-caps labels, `→` in buttons, and unstyled Material widgets.
