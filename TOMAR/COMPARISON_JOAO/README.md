# TOMAR–JOAO CSV comparison

This directory is the dedicated home for cross-setup comparison products.

Inputs:

- TOMAR scan summaries and charge histograms in `TOMAR/OUTPUTS_SCAN` and
  `TOMAR/OUTPUTS/<run>/`.
- JOAO thick-RPC run summaries and charge histograms in
  `STAGES/STAGE_7/DATA/DATA_FILES/OUTPUTS_7/`.
- JOAO run/HV metadata in
  `STAGES/STAGE_3/DATA/DATA_FILES/file_run_dictionary.csv`.

Generated comparison figures and joined CSV tables belong in `OUTPUTS/`.

`comparison_limits.csv` controls charge and HV display limits plus independent
`tomar_date_*` and `joao_date_*` windows. Those date windows filter the
comparison inputs; the JOAO window also controls `joao_run_conditions.png`.

`joao_run_selection.csv` is a mandatory condition filter: only rows marked
`include` are compared. It records the source/pressure/trigger condition and
the exclusion reason for each run. The initial TOMAR-like selection is runs
3, 5, 6 and 10; CAEN-supply, sub-pressure, altered-trigger and known-fault
runs are excluded. To include another run deliberately, change only its
`selection` cell from `exclude` to `include`, then rerun the comparison.

Charge axes remain native to each setup: TOMAR `q_sum` is in ns, while the
JOAO thick-RPC spectrum is in ADC bins. Spectra can therefore be compared by
shape and HV evolution until a common charge calibration is provided.

For the efficiency comparison, the JOAO reader uses the Stage-7 `range`
metric, not `good`: it requires a four-PMT scintillator coincidence and every
PMT charge inside that run's 20th--80th-percentile charge interval. Its
denominator is therefore the scintillator-qualified sample, analogous to the
TOMAR scintillator-conditioned efficiency. The Stage-7 `StreamerPct` remains
the native JOAO streamer metric and is not redefined here.
