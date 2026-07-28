# Diátaxis: the compass and the type contracts

Read this when a page resists classification, two types seem to fit, or a
docs tree needs typing page by page. Canonical: <https://diataxis.fr/>.

## The compass

Two questions classify any page:

1. Does it inform the reader's **action** (practical steps) or their
   **cognition** (knowledge)?
2. Does it serve **acquisition** of skill (study, learning) or
   **application** of skill (work, doing)?

|  | Acquisition (study) | Application (work) |
|---|---|---|
| **Action** (practical) | Tutorial | How-to guide |
| **Cognition** (theoretical) | Explanation | Reference |

## Type contracts

### Tutorial — a lesson

- The author chooses the goal; the reader follows to learn, not to
  accomplish their own task.
- Must work every time on the reader's first day: pin versions, state
  prerequisites, show expected output after each step.
- Minimize choices and minimize explanation — link explanations instead.
  Success is "I did it and I want more", not "I understood everything".

### How-to guide — a recipe

- The reader brings the goal and the context; address someone already
  competent: why is their business, how is yours.
- Name it after the task ("How to rotate credentials"), not the tool.
- A sequence of actions adaptable to circumstances. Omission is a
  feature — completeness belongs to reference.

### Reference — a map

- Structure mirrors the machinery it describes: one page per
  module/command/endpoint, ordered like the code.
- Austere, uniform, factual: state, list, describe. No instruction, no
  persuasion; examples may illustrate, never teach.

### Explanation — a discussion

- Answers "why": design reasons, trade-offs, history, alternatives,
  connections to other topics. Opinion is admissible when marked.
- Readable away from the machine; nothing to execute.

## Classic confusions

| Symptom | Fix |
|---|---|
| Tutorial full of "you could also ..." branches | Move the choices to how-to guides; keep one guaranteed path |
| How-to guide that teaches basics first | Cut to the steps; link a tutorial for beginners |
| Reference page that argues for a design | Move the argument to explanation; keep the facts |
| Explanation that turned into numbered steps | It became a how-to guide; split it |
| One page serving beginner and expert at once | Split by need: tutorial + reference |

## Working incrementally

Pick the page most in need; decide its single type; move out-of-type
content to its right home (create stubs if the home is missing); repeat.
Never block improvement on a grand restructuring plan — the structure
emerges from repeated small corrections.
