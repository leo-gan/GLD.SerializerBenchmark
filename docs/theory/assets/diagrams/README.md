# Theory course diagrams

Simple SVG figures for Serialization 101–401. Light and dark twins share geometry.

## Design rules

- Flat shapes, no gradients or shadows
- Palette: slate + indigo (Material-friendly)
- Action labels: Liberation/DejaVu Sans, regular weight, open tracking
- Light: `*-name.svg` · Dark: `*-name-dark.svg`

## Embedding (Material)

```markdown
![Alt text](../assets/diagrams/STEM.svg#only-light)
![Alt text](../assets/diagrams/STEM-dark.svg#only-dark)
```

Requires `attr_list` (enabled in `mkdocs.yml`).

## Inventory

| Stem | Course page |
|------|-------------|
| `101-serialize-contract` | `theory/101/index.md` |
| `201-memory-padding` | `theory/201/memory-layout.md` |
| `201-endianness` | `theory/201/memory-layout.md` (Endianness) |
| `201-self-describing-vs-schema` | `theory/201/self-describing-vs-schema-dependent.md` |
| `201-zero-copy` | `theory/201/zero-copy.md` |
| `301-trust-boundaries` | `theory/301/trust-boundaries.md` |
| `401-miniuser-wire` | `theory/401/protobuf-wire-format.md` |
| `401-varint` | `theory/401/protobuf-wire-format.md` |
