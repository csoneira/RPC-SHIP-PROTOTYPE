# RPC Multiplexed Timing Detector Studies

## Introduction
The current programme with LIP extends the multiplexed readout concept pioneered for the SHiP prototype RPC built in 2017 and installed in R3B since 2020. That detector demonstrated that combining thick and narrow strips can drastically reduce the number of instrumented channels in large-area timing RPCs while preserving excellent time resolution. João Pedro Saraiva's 2023 thesis pushed the idea further by showing how aggressive signal multiplexing, careful control of the electronic/ionic signal balance, and high-stability gas handling can keep sub-100 ps timing even on 130 × 90 cm² planes. Our present effort uses this detector as both a reference system and a test-bed for the next iteration of the concept.

The long-term objective is to deliver the same performance with a **single** timing multigap RPC equipped exclusively with thin strips. Doing so demands an electronic chain that can peel apart the prompt electronic pulse—needed for precise timing—from the much larger but slower ionic tail that carries the charge information required for sub-millimetre positioning. By eliminating the thick-strip timing plane and folding its role into fast/slow filtering on the thin-strip signals, we can simplify the mechanics, reduce channel count, and cut cost and maintenance overhead while retaining the detector’s original physics reach for SHiP, R3B, and future large-acceptance experiments.

## Detector system overview
Our setup employs two stacked timing multigap RPCs as a reference configuration to benchmark a prospective single-chamber solution. Each chamber comprises six 0.3 mm gas gaps separated by seven 1.1 mm float-glass electrodes housed in a polypropylene box that allows stable operation at ultra-low gas flux. Key subsystems include:

- **Gas system and high voltage** – The detector circulates a 95.5–99% C₂H₂F₄ + 0.5–4.5% SF₆ mixture, with the exact composition tuned to suppress streamers on the large-area planes. High voltage is compensated every 15 minutes to maintain a reduced electric field around 380 Td, following the proportionality \(HV \propto (E/N) \cdot d_{gap} \cdot P/T\).
- **Trigger** – Two 8 cm × 2 cm plastic scintillators above and below the stack, each read out by a pair of ageing photomultiplier tubes. Despite atypical pulse shapes, their timing stability enables reliable external triggering at roughly 1 kHz day⁻¹, with charge and timing information stored for offline checks.
- **Electrodes** – Thin strips with a 2.54 mm pitch (aligned with standard 0.1" electronics footprints) cover the top and bottom planes, providing orthogonal x/y views with an average cluster size of about six strips. A 61.0 mm pitch thick strip plane between the two RPCs boosts the induced fast component for timing. Ground planes on the outer surfaces are mandatory to control transmission-line behaviour; removing the top ground plane was observed to worsen timing from ~65 ps to >100 ps.
- **Signal multiplexing** – Each set of thin strips is routed through a Signal Merging PCB that groups multiple strips per electronic channel (five in the 30 × 30 cm² prototype and up to 22 in the 130 × 90 cm² system). Coarse 2D timing from the thick strips disambiguates which physical strip fired and permits <1 mm charge interpolation even after multiplexing.
- **Front-end and digitisation** – The thick strip channel records only the prompt electronic component via current-sensitive preamplifiers with ≤35 ps intrinsic timing. Thin-strip channels capture both the fast and much larger slow ionic component through charge-sensitive amplifiers with ~100 µs integration, enabling detailed charge measurement; spacer shadows as narrow as 300 µm remain visible in the charge maps. Signals are digitised with a TRB board sampling every 25 ns and storing extended waveforms for the slow component.
- **Data pipeline** – João's Python-based unpacker retrieves fast and slow waveforms, applies trapezoidal filtering, and produces time/charge matrices analogous to the mingo framework. Auxiliary loggers track environmental parameters (temperature, pressure, humidity, gas flow) for correlation studies.

### Performance benchmarks from the reference detector
- **Efficiency and stability** – The double-stack reaches (98 ± 1)% efficiency near ±8.5 kV per chamber, while the large-area implementation stabilises around 94–95% efficiency with <6% streamer rate after conditioning.
- **Spatial resolution** – Charge interpolation on the thin strips yields 140–200 µm resolution on minimally multiplexed prototypes and ~0.6 mm on the full 130 × 90 cm² modules. Longitudinal reconstruction from timing on the 61 mm strips is 4–6 mm, matching expectations from the 171 mm/ns propagation velocity.
- **Timing** – After slewing corrections, the reference double-stack operates at 65 ps intrinsic resolution (73–90 ps on the large-area chambers), validating that multiplexing does not compromise the timing budget when both chambers are active.

## Current challenge and roadmap
Transitioning to a single multigap timing RPC without the thick-strip plane requires separating the fast and slow signal components electronically. The envisaged filter chain will keep the prompt electronic fraction for timing while routing the slow ionic charge to an integrator, making it possible to retain both timing and position performance with only thin strips. Preliminary tests disconnecting one chamber in the existing double-stack showed a modest timing degradation (≈130 ps) but a substantial efficiency drop to 70%. Two archived runs are available: one at nominal 9 kV with full performance, and another with a disconnected plane suffering reduced efficiency—likely due to the HV supply delivering less voltage than reported. Immediate tasks are to analyse these datasets, scrutinise charge spectra (e.g., Polya fits versus environmental conditions), and perform HV scans to reproduce the characteristic efficiency/timing/streamer curves. Depending on the outcome, the HV source may be replaced before implementing the fast/slow filter and migrating to an all-thin-strip configuration. Achieving stable single-chamber running will demonstrate that the thick-strip timing plane can be fully removed while the fast/slow filters recover the roles formerly played by the double-stack geometry.

## Analysis workflow
The steps of the analysis, in parallel.

### Setting up the environment
1. Set up the Python environment, as described in `PYTHON_ENVIRONMENT_SETUP_COMPLETE.md` (or `PYTHON_SETUP.md` for manual steps)

   ```bash
   bash /home/csoneira/WORK/LIP_stuff/JOAO_SETUP/setup_environment.sh
   ```

Python environment quick instructions:

- Automated setup: `bash setup_environment.sh`
- Environment location: `/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/venv/`
- Activation: `source venv/bin/activate`
- Deactivation: `deactivate`
- One-shot run without activation: `venv/bin/python <script>`
- Required packages: numpy, pandas, matplotlib, scipy, pyyaml
- Notes: Python 3.12.3 in use; `runUnpacker.py` uses `python3` shebang

### The log branch
1. Bring the log files from the joao computer. This script brings the files and calls `/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/LOG_FILES/SCRIPTS/log_aggregate_and_join.py`.

   ```bash
   bash /home/csoneira/WORK/LIP_stuff/JOAO_SETUP/LOG_FILES/SCRIPTS/log_bring_and_clear.sh
   ```

### The data branch
1. **Data bringing.** The data is brought in hld format from a certain date, though if the files are already present they are not copied back. HLDs are brought to `/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/unpacker/hlds_toUnpack`.

   ```bash
   bash /home/csoneira/WORK/LIP_stuff/JOAO_SETUP/DATA_FILES/SCRIPTS/bring_hlds.sh <date_cut YYYY-MM-DD>
   ```

2. **Unpacking.** The data is unpacked using the following script, which calls `python unpacker/unpackAll.py` with the environment. It stores unpacked data in directories named `dabcYYDDDHHMMSS-dabcYYDDDHHMMSS_YYYY-MM-DD_HHhMMmSSs`, where the first timestamp marks the run start, the second the run end, and the suffix records the unpacking time.

   ```bash
   bash /home/csoneira/WORK/LIP_stuff/JOAO_SETUP/guide_to_unpack.sh
   ```

3. **Data analysis.** The unpacked data is analysed using the following script, which runs `matlab -batch "run('DATA_FILES/SCRIPTS/Backbone/caye_edits_minimal.m')"` within the environment. Results are written to `/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/DATA_FILES/DATA/TABLES/analyzed_dabcYYDDDHHMMSS-dabcYYDDDHHMMSS_YYYY-MM-DD_HHhMMmSSs.csv`, where the suffix again encodes the analysis timestamp.

   ```bash
   bash /home/csoneira/WORK/LIP_stuff/JOAO_SETUP/guide_to_analyze.sh
   ```

## Conference submission draft
- **Proposed title:** *Towards a Single-Chamber Multiplexed Thin-Strip Timing RPC for SHiP and R3B*
- **Abstract:**

  *We report on ongoing work at LIP to streamline the readout of large-area timing RPCs for the SHiP and R3B experiments. Building on João Pedro Saraiva’s double timing multigap RPC, which combines 2.54 mm thin-strip boards, 61 mm timing strips, and signal merging PCBs to achieve 65 ps timing with a fivefold channel reduction, we now target a single-chamber solution that dispenses with the thick-strip plane. Two reference runs with the double-stack—one at nominal ±9 kV and another with a disconnected chamber—expose an unexplained efficiency loss to ~70% when operating in single-plane mode despite preserved timing. We outline our analysis pipeline, from waveform unpacking with trapezoidal filtering to charge-spectrum fits and environmental correlations, and describe the upcoming high-voltage scans to validate the suspected power-supply limitations. The final step is to implement complementary fast/slow filters on the thin-strip readout so that a single timing RPC can provide both precise time-of-flight and sub-millimetre position measurements without resorting to thick strips. This path charts how multiplexed thin-strip technology can instrument large acceptance experiments with reduced cost and complexity while retaining physics performance.*

