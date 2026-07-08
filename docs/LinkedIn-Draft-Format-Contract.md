# LinkedIn Draft Format Contract

## Purpose

This document defines the canonical LinkedIn draft format used by Spark and the
LinkedIn posting pipeline. Drafts must follow this contract so that
`scripts/linkedin-post.sh` and `scripts/validate-linkedin-draft.sh` can parse
them consistently and catch bot-signal or structural problems before posting.

## Scope

Applies to all LinkedIn draft markdown files produced by Spark or written by
hand in `social-drafts/`. Legacy drafts using the old `---`-only delimiter
format are still accepted with a warning, but new drafts should follow the
current contract.

## Contract

A valid LinkedIn draft must satisfy all of the following rules.

### 1. `## Draft` heading is mandatory

The draft must contain a level-2 markdown heading named exactly `## Draft`
(case-insensitive, no trailing punctuation). This marks the beginning of the
post body.

### 2. Body text must be longer than 100 characters

The body is the text between the `## Draft` heading and the first `---`
separator that precedes the hashtag line or the `## Image Prompt` heading. Body
text must be more than 100 characters. Very short bodies are rejected because
they are usually a sign of a truncated or malformed draft.

### 3. `---` separator after the body

A horizontal-rule style separator (`---`) must appear after the body and before
the hashtag line. It separates the human-readable post from the metadata.

### 4. Hashtag line starting with `#`

After the `---` separator there must be at least one line that starts with `#`
and is **not** a markdown heading (i.e. not `## `). Example:

```markdown
#AIinAustralia #BuildingInPublic #FoundationFirst
```

### 5. `## Image Prompt` heading is mandatory

The draft must contain a level-2 heading named exactly `## Image Prompt`. This
heading separates the post metadata from the image-generation prompt used by
`scripts/hf-generate-image.sh`.

### 6. No em-dashes in the body

The body text must not contain em-dashes (`—`). Em-dashes are a known bot
signal per Spark rules and must be replaced with hyphens (`-`) before posting.

## Example

```markdown
## Draft

Earlier my AI workflow was held together by a strong model. Today it is held
together by the foundation underneath.

Here is what I learned.

Strong models hide weak foundations. The longer the model covers for the
system, the bigger the debt when the model changes. I have paid that debt. I
do not recommend it.

---

#AIinAustralia #BuildingInPublic #FoundationFirst

---

## Image Prompt

A wide landscape at dawn, the foreground a stable concrete foundation, the
middle ground a partially-built structure rising out of it, the background a
calm sky just starting to warm, soft natural light, muted greys and warm
sunrise gold, editorial landscape photography, hopeful and grounded mood.
Square 1:1 format, no text, no logos, professional quality.
```

## Legacy compatibility

Old drafts that use only `---` delimiters (no `## Draft` / `## Image Prompt`
headings) are recognized as **legacy format**. They PASS validation with a
warning, but they must still satisfy the body length and em-dash rules.

## Validation tools

- `scripts/validate-linkedin-draft.sh <draft.md>` — standalone validator that
  exits `0` on PASS and `1` on FAIL.
- `scripts/linkedin-post.sh --validate-format --content-file <draft.md>` —
  validates the draft without posting.

## Related change records

- CHG-0421 / TKT-0235: Robust markdown content extraction and em-dash check.
- CHG-0832 / SSOT Phase 1: Formalized contract and standalone validator.
