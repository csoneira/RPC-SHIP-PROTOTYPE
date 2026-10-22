# TOMAR configuration files

## Slow-charge ADC lookup

`thin_strip_adc_lookup.csv` maps the 48 logical input wires used by the thin-strip analysis to the raw ADC channels. The analysis reads this table directly, so the CSV is the authoritative channel-order definition for the slow-charge channels.

### 2026-10-22 correction

Updated on **22 October 2026** following Alberto Blanco's correction communicated on 10 September 2026.

The correct ADC-channel order for logical inputs 1 through 48 is:

```text
33 34 35 36  45 46 47 48  29 30 31 32  25 26 27 28  01 02 03 04  09 10 11 12
05 06 07 08  13 14 15 16  17 18 19 20  21 22 23 24  37 38 39 40  41 42 43 44
```

This supersedes the previous ordering:

```text
01 02 03 04  09 10 11 12  29 30 31 32  25 26 27 28  33 34 35 36  45 46 47 48
05 06 07 08  13 14 15 16  17 18 19 20  21 22 23 24  37 38 39 40  41 42 43 44
```

Only the lookup ordering was corrected. The pulse extraction and downstream thin-strip analysis logic are unchanged.
