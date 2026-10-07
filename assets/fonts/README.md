# Bundled fonts

The `google_fonts` package looks in the app's assets before it uses the
network, matching on file name. Keeping these here means the first launch on a
fresh install does not download fonts (slow start, text that jumps when the
font arrives, and no text styling at all when offline).

- IBM Plex Sans: Regular, Medium, SemiBold, Bold (SIL Open Font License 1.1)
- Fraunces: SemiBold (SIL Open Font License 1.1)

Only the weights the app uses are included. If a new weight is used in code,
add its file here with the same naming (`Family-WeightName.ttf`); until then
`google_fonts` falls back to downloading that one weight.

Files come from fonts.gstatic.com, the same URLs and SHA-256 hashes that the
`google_fonts` package pins in its own source.
