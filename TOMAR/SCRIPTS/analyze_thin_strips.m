% Analyze the sampled thin-strip ADC pulses in a TOMAR MAT file.
%
% The two 24-channel ADC banks Q1_T and Q1_B are concatenated in raw ADC
% order and then placed in input-wire order with Alberto/Paulo's lookup
% table in TOMAR/CONFIGS/thin_strip_adc_lookup.csv.  The output therefore
% has 48 instrumented input wires.  If each input is connected to a pair of
% physical strips, that detector-specific fan-out is intentionally not
% guessed here.
%
% Charge is extracted with the same negative-pulse trapezoidal filter used
% by Joao's unpacker.  These records contain 20 samples, so the baseline is
% restricted to samples 1--6 (the pulse begins near sample 7).
%
% Direct use from the repository root:
%   addpath('TOMAR/SCRIPTS');
%   analyze_thin_strips('TOMAR/DATA/dabc26212155929.mat', ...
%       'TOMAR/OUTPUTS/thin_test', true, true);

% Returns a compact structure. Detailed event arrays are saved in a
% dedicated MAT result file rather than returned to the caller.

function compact = analyze_thin_strips(mat_file, output_dir, should_plot, save_plots, run_name)

if nargin < 2 || isempty(output_dir), output_dir = pwd; end
if nargin < 3 || isempty(should_plot), should_plot = true; end
if nargin < 4 || isempty(save_plots), save_plots = true; end
if nargin < 5 || isempty(run_name), [~, run_name] = fileparts(mat_file); end
if exist(output_dir, 'dir') ~= 7, mkdir(output_dir); end

script_dir = fileparts(mfilename('fullpath'));
config_dir = fullfile(fileparts(script_dir), 'CONFIGS');
lookup_file = fullfile(config_dir, 'thin_strip_adc_lookup.csv');
parameter_file = fullfile(config_dir, 'thin_strip_parameters.csv');
scintillator_map_file = fullfile(config_dir, 'thin_strip_scintillator_map.csv');
overlay_rectangle_file = fullfile(config_dir, 'thin_strip_overlay_rectangles.csv');
lookup = read_thin_lookup(lookup_file);
parameters = read_thin_parameters(parameter_file);
scintillator_map = read_thin_scintillator_map(scintillator_map_file);
overlay_rectangles = read_overlay_rectangles(overlay_rectangle_file);

variables = whos('-file', mat_file);
names = {variables.name};
if ~all(ismember({'Q1_T', 'Q1_B'}, names))
    error('Thin-strip analysis requires both Q1_T and Q1_B in %s.', mat_file);
end
q_info_t = variables(strcmp(names, 'Q1_T'));
q_info_b = variables(strcmp(names, 'Q1_B'));
if ~isequal(q_info_t.size, q_info_b.size) || numel(q_info_t.size) ~= 3 || ...
        q_info_t.size(2) ~= 24
    error('Q1_T and Q1_B must have matching [samples 24 events] dimensions.');
end
n_samples = q_info_t.size(1);
n_events = q_info_t.size(3);
validate_thin_parameters(parameters, n_samples, parameter_file);

fprintf('[INFO] Thin strips: extracting pulses from %d events, %d samples, 48 ADC channels.\n', ...
    n_events, n_samples);
[features_t, mean_waveform_t, example_t] = extract_adc_bank(mat_file, 'Q1_T', parameters);
[features_b, mean_waveform_b, example_b] = extract_adc_bank(mat_file, 'Q1_B', parameters);

% Raw channel numbers 1:24 are Q1_T; 25:48 are Q1_B.
raw_baseline = [features_t.baseline, features_b.baseline];
raw_baseline_noise = [features_t.baseline_noise, features_b.baseline_noise];
raw_amplitude = [features_t.amplitude, features_b.amplitude];
raw_charge = [features_t.charge, features_b.charge];
raw_integral = [features_t.integral, features_b.integral];
raw_valid = [features_t.valid, features_b.valid];
raw_mean_waveform = [mean_waveform_t, mean_waveform_b];
raw_example_waveform = [example_t.waveform, example_b.waveform];
raw_example_event = [example_t.event, example_b.event];

baseline = raw_baseline(:, lookup);
baseline_noise = raw_baseline_noise(:, lookup);
amplitude = raw_amplitude(:, lookup);
charge = raw_charge(:, lookup);
integral = raw_integral(:, lookup);
valid_trace = raw_valid(:, lookup);
mean_waveform = raw_mean_waveform(:, lookup);
example_waveform = raw_example_waveform(:, lookup);
example_event = raw_example_event(lookup);
pulse = valid_trace & charge >= parameters.pulse_threshold_adc;

wire_input = (1:48)';
valid_count = sum(valid_trace, 1)';
pulse_count = sum(pulse, 1)';
occupancy = pulse_count ./ max(valid_count, 1);
median_occupancy = median(occupancy(valid_count > 0));
dead_limit = parameters.dead_occupancy_fraction * median_occupancy;
dead_channel = valid_count == 0 | occupancy < dead_limit;
baseline_median = column_finite_median(baseline)';
baseline_noise_median = column_finite_median(baseline_noise)';
amplitude_median = column_masked_median(amplitude, pulse)';
charge_median = column_masked_median(charge, pulse)';
integral_median = column_masked_median(integral, pulse)';
channel_summary = [wire_input, lookup(:), valid_count, pulse_count, 100 * occupancy, ...
    baseline_median, baseline_noise_median, amplitude_median, charge_median, ...
    integral_median, dead_channel];

event_multiplicity = sum(pulse, 2);
event_pulse_charge = double(charge);
event_pulse_charge(~pulse) = 0;
event_total_charge = sum(event_pulse_charge, 2);
weighted_position = sum(event_pulse_charge .* repmat(1:48, n_events, 1), 2);
event_centroid = weighted_position ./ event_total_charge;
event_centroid(event_total_charge == 0) = NaN;

% Reproduce Joao's position method: circular weighted means in the two
% 24-input thin planes, followed by thick-strip wrap disambiguation.
auxiliary = load_position_and_scintillator_fields(mat_file, n_events);
position = reconstruct_joao_position(event_pulse_charge, auxiliary, parameters, config_dir);
scintillator = build_thin_scintillator_data(auxiliary, scintillator_map, n_events, parameters);

summary_csv = fullfile(output_dir, [run_name '_thin_strip_channel_summary.csv']);
event_csv = fullfile(output_dir, [run_name '_thin_strip_event_summary.csv']);
scintillator_csv = fullfile(output_dir, [run_name '_scintillator_channel_summary.csv']);
routing_csv = fullfile(output_dir, [run_name '_thin_strip_routing_summary.csv']);
write_thin_channel_summary(summary_csv, channel_summary);
write_thin_event_summary(event_csv, event_multiplicity, event_total_charge, event_centroid, position, scintillator);
write_scintillator_summary(scintillator_csv, scintillator);
write_routing_summary(routing_csv, position, scintillator, parameters);

results_mat = fullfile(output_dir, [run_name '_thin_strip_results.mat']);
save('-mat7-binary', results_mat, 'charge', 'amplitude', 'integral', 'pulse', ...
    'valid_trace', 'event_multiplicity', 'event_total_charge', 'event_centroid', ...
    'channel_summary', 'mean_waveform', 'example_waveform', 'example_event', ...
    'position', 'scintillator', 'scintillator_map', 'lookup', 'parameters', 'mat_file', 'run_name');

if should_plot
    make_thin_summary_plot(channel_summary, mean_waveform, parameters, run_name, ...
        output_dir, [run_name '_thin_strip_summary.png'], save_plots);
    make_thin_event_plot(event_multiplicity, event_total_charge, event_centroid, run_name, ...
        output_dir, [run_name '_thin_strip_events.png'], save_plots);
    make_thin_pulse_examples_plot(example_waveform, example_event, dead_channel, run_name, ...
        output_dir, [run_name '_thin_strip_pulse_examples.png'], save_plots, parameters);
    make_thin_charge_spectra_plot(charge, pulse, run_name, output_dir, ...
        [run_name '_thin_strip_charge_spectra.png'], save_plots);
    make_thin_charge_sharing_plot(event_pulse_charge, position, run_name, output_dir, ...
        [run_name '_thin_strip_charge_sharing.png'], save_plots, parameters);
    make_circular_gaussian_examples_plot(event_pulse_charge, position, scintillator, run_name, output_dir, ...
        [run_name '_thin_strip_circular_gaussian_examples.png'], save_plots, parameters);
    make_thin_position_plot(position, scintillator, run_name, output_dir, ...
        [run_name '_thin_strip_position_maps.png'], save_plots);
    make_thick_only_position_plot(position, scintillator, parameters, run_name, output_dir, ...
        [run_name '_thick_strip_only_position_maps.png'], save_plots);
    make_fast_slow_position_comparison_plot(position, scintillator, parameters, run_name, output_dir, ...
        [run_name '_fast_slow_position_comparison.png'], save_plots);
    make_combined_final_position_geometry_plot(position, scintillator, overlay_rectangles, run_name, output_dir, ...
        'FINAL_FAST_SLOW_POSITIONS_WITH_GEOMETRY.png', save_plots);
    make_routing_diagnostics_plot(position, scintillator, run_name, output_dir, ...
        [run_name '_thin_strip_routing_diagnostics.png'], save_plots);
    make_scintillator_overview_plot(scintillator, run_name, output_dir, ...
        [run_name '_scintillator_channels.png'], save_plots);
    make_scintillator_correlations_plot(scintillator, run_name, output_dir, ...
        [run_name '_scintillator_correlations.png'], save_plots);
end

dead_inputs = wire_input(dead_channel);
dead_raw_channels = lookup(dead_channel);
fprintf('[INFO] Thin strips: %d pulses above %.6g ADC bins; median occupancy %.3f%%.\n', ...
    nnz(pulse), parameters.pulse_threshold_adc, 100 * median_occupancy);
fprintf('[INFO] Thin position: %d reconstructed events; slow/fast/all scintillator coincidences: %d/%d/%d.\n', ...
    nnz(position.valid), nnz(scintillator.slow_coincidence), ...
    nnz(scintillator.fast_coincidence), nnz(scintillator.all_coincidence));
if isempty(dead_inputs)
    fprintf('[INFO] Thin strips: no low-occupancy amplifier candidates.\n');
else
    fprintf('[INFO] Thin strips: low-occupancy input(s) %s (raw ADC channel(s) %s).\n', ...
        mat2str(dead_inputs'), mat2str(dead_raw_channels'));
end
fprintf('[INFO] Thin-strip results saved in %s.\n', output_dir);

compact = struct('available', true, 'n_samples', n_samples, 'n_events', n_events, ...
    'channel_summary', channel_summary, 'dead_inputs', dead_inputs, ...
    'dead_raw_channels', dead_raw_channels, 'pulse_threshold_adc', ...
    parameters.pulse_threshold_adc, 'position_count', nnz(position.valid), ...
    'slow_coincidence_count', nnz(scintillator.slow_coincidence), ...
    'fast_coincidence_count', nnz(scintillator.fast_coincidence), 'lookup', lookup);
end

function [features, mean_waveform, example] = extract_adc_bank(mat_file, field_name, p)
    loaded = load(mat_file, field_name);
    q = loaded.(field_name);
    n_samples = size(q, 1); n_channels = size(q, 2); n_events = size(q, 3);
    features = struct('baseline', NaN(n_events, n_channels, 'single'), ...
        'baseline_noise', NaN(n_events, n_channels, 'single'), ...
        'amplitude', NaN(n_events, n_channels, 'single'), ...
        'charge', NaN(n_events, n_channels, 'single'), ...
        'integral', NaN(n_events, n_channels, 'single'), ...
        'valid', false(n_events, n_channels));
    mean_waveform = NaN(n_samples, n_channels);
    example = struct('waveform', NaN(n_samples, n_channels), 'event', NaN(1, n_channels));
    last_start = n_samples - 2 * p.trapezoid_length - p.trapezoid_gap + 1;
    for channel = 1:n_channels
        traces = double(squeeze(q(:, channel, :))');
        valid = all(isfinite(traces) & traces > 0, 2);
        base_region = traces(:, 1:p.baseline_samples);
        base = mean(base_region, 2);
        noise = std(base_region, 0, 2);
        signal = base - traces(:, p.signal_start_sample:end);
        amp = max(signal, [], 2);
        integ = sum(max(signal, 0), 2);
        trap = zeros(n_events, 1);
        for start_sample = 1:last_start
            early = sum(traces(:, start_sample:start_sample + p.trapezoid_length - 1), 2);
            late_start = start_sample + p.trapezoid_length + p.trapezoid_gap;
            late = sum(traces(:, late_start:late_start + p.trapezoid_length - 1), 2);
            trap = max(trap, (early - late) / p.trapezoid_length);
        end
        base(~valid) = NaN; noise(~valid) = NaN; amp(~valid) = NaN;
        integ(~valid) = NaN; trap(~valid) = NaN;
        features.baseline(:, channel) = single(base);
        features.baseline_noise(:, channel) = single(noise);
        features.amplitude(:, channel) = single(amp);
        features.charge(:, channel) = single(trap);
        features.integral(:, channel) = single(integ);
        features.valid(:, channel) = valid;
        if any(valid), mean_waveform(:, channel) = mean(traces(valid, :), 1)'; end
        candidates = find(valid & trap >= p.pulse_threshold_adc);
        if ~isempty(candidates)
            target_charge = quantile(trap(candidates), 0.75);
            [~, nearest] = min(abs(trap(candidates) - target_charge));
            selected = candidates(nearest);
            example.waveform(:, channel) = (traces(selected, :) - base(selected))';
            example.event(channel) = selected;
        end
    end
    clear q loaded;
end

function lookup = read_thin_lookup(file_name)
    values = dlmread(file_name, ',', 1, 0);
    if ~isequal(size(values), [48 2]) || any(values(:, 1) ~= (1:48)') || ...
            ~isequal(sort(values(:, 2))', 1:48)
        error('%s must map wire inputs 1:48 bijectively to ADC channels 1:48.', file_name);
    end
    lookup = values(:, 2)';
end

function p = read_thin_parameters(file_name)
    fid = fopen(file_name, 'r');
    if fid < 0, error('Could not read %s.', file_name); end
    parsed = textscan(fid, '%s%f', 'Delimiter', ',', 'HeaderLines', 1);
    fclose(fid);
    expected = {'baseline_samples', 'signal_start_sample', 'trapezoid_length', ...
        'trapezoid_gap', 'pulse_threshold_adc', 'dead_occupancy_fraction', ...
        'position_charge_threshold_adc', 'position_tdif_min_ns', ...
        'position_tdif_max_ns', 'strip_pitch_mm', 'thin_axes_rotated', ...
        'thin_x_flip', 'thin_y_flip', 'thin_x_cyclic_offset', 'thin_y_cyclic_offset', ...
        'pulse_example_count', 'charge_share_example_count', ...
        'scintillator_time_min_ns', 'scintillator_time_max_ns', 'scintillator_tot_max_ns', ...
        'slow_core_tot_min_ns', 'slow_core_tot_max_ns'};
    p = struct();
    for idx = 1:numel(expected)
        row = find(strcmp(parsed{1}, expected{idx}));
        if numel(row) ~= 1 || ~isfinite(parsed{2}(row))
            error('%s must contain one finite %s value.', file_name, expected{idx});
        end
        p.(expected{idx}) = parsed{2}(row);
    end
end

function validate_thin_parameters(p, n_samples, file_name)
    integer_names = {'baseline_samples', 'signal_start_sample', 'trapezoid_length', ...
        'trapezoid_gap', 'pulse_example_count', 'charge_share_example_count'};
    for idx = 1:numel(integer_names)
        value = p.(integer_names{idx});
        if value < 1 || value ~= round(value)
            error('%s: %s must be a positive integer.', file_name, integer_names{idx});
        end
    end
    if p.baseline_samples >= p.signal_start_sample || p.signal_start_sample > n_samples
        error('%s: baseline samples must precede the signal region.', file_name);
    end
    if 2 * p.trapezoid_length + p.trapezoid_gap > n_samples
        error('%s: trapezoidal filter is longer than the waveform.', file_name);
    end
    if p.pulse_threshold_adc < 0 || p.dead_occupancy_fraction < 0 || p.dead_occupancy_fraction >= 1
        error('%s: thresholds are outside their valid ranges.', file_name);
    end
    if p.position_charge_threshold_adc < 0 || p.position_tdif_min_ns >= p.position_tdif_max_ns || ...
            p.strip_pitch_mm <= 0 || ~ismember(p.thin_axes_rotated, [0 1]) || ...
            ~ismember(p.thin_x_flip, [0 1]) || ~ismember(p.thin_y_flip, [0 1])
        error('%s: invalid thin-position parameters.', file_name);
    end
    if p.scintillator_time_min_ns >= p.scintillator_time_max_ns || p.scintillator_tot_max_ns <= 0
        error('%s: invalid scintillator validity limits.', file_name);
    end
    if p.slow_core_tot_min_ns < 0 || p.slow_core_tot_min_ns >= p.slow_core_tot_max_ns
        error('%s: invalid slow-scintillator core ToT limits.', file_name);
    end
end

function map = read_thin_scintillator_map(file_name)
    fid = fopen(file_name, 'r');
    if fid < 0, error('Could not read %s.', file_name); end
    parsed = textscan(fid, '%f%s%s%f', 'Delimiter', ',', 'HeaderLines', 1, 'Whitespace', '');
    fclose(fid);
    if numel(parsed{1}) ~= 6 || any(parsed{1}(:)' ~= 1:6) || ...
            ~isequal(parsed{3}(:)', {'fast_down', 'fast_down', 'fast_up', 'fast_up', 'slow_1', 'slow_2'})
        error('%s must define T2 channels 1--6 as two fast-down PMTs, two fast-up PMTs, slow_1 and slow_2.', file_name);
    end
    map = struct('channel', parsed{1}(:)', 'label', {parsed{2}(:)'}, ...
        'group', {parsed{3}(:)'}, 'pmt', parsed{4}(:)');
end

function geometry = read_overlay_rectangles(file_name)
    fid = fopen(file_name, 'r');
    if fid < 0, error('Could not read %s.', file_name); end
    parsed = textscan(fid, '%s%s%f%f%f%f', 'Delimiter', ',', 'HeaderLines', 1, 'Whitespace', '');
    fclose(fid);
    labels = parsed{1}; categories = parsed{2};
    values = [parsed{3}, parsed{4}, parsed{5}, parsed{6}];
    allowed = {'thick_strip', 'fast_scintillator', 'slow_scintillator'};
    if isempty(labels) || numel(unique(labels)) ~= numel(labels) || ...
            any(~ismember(categories, allowed)) || any(~isfinite(values(:))) || ...
            any(values(:, 3) <= 0) || any(values(:, 4) <= 0)
        error('%s must contain unique labels, valid categories, finite centers, and positive base/height.', file_name);
    end
    geometry = struct('label', {labels(:)'}, 'category', {categories(:)'}, ...
        'center_x_mm', values(:, 1)', 'center_y_mm', values(:, 2)', ...
        'base_mm', values(:, 3)', 'height_mm', values(:, 4)');
end

function auxiliary = load_position_and_scintillator_fields(mat_file, n_events)
    requested = {'T1_F', 'T1_B', 'TOT1_F', 'TOT1_B', 'T2_F', 'TOT2_F'};
    info = whos('-file', mat_file); names = {info.name};
    available = requested(ismember(requested, names));
    auxiliary = load(mat_file, available{:});
    for idx = 1:numel(requested)
        name = requested{idx};
        if isfield(auxiliary, name)
            values = full(double(auxiliary.(name)));
            if rows(values) ~= n_events
                error('%s must contain one row per event.', name);
            end
            auxiliary.(name) = values;
        else
            auxiliary.(name) = zeros(n_events, 0);
        end
    end
end

function position = reconstruct_joao_position(event_charge, auxiliary, p, config_dir)
    n_events = rows(event_charge); n_plane_strips = 24; n_wraps = 5;
    q_top = event_charge(:, 1:24); q_bottom = event_charge(:, 25:48);
    q_top(q_top < p.position_charge_threshold_adc) = 0;
    q_bottom(q_bottom < p.position_charge_threshold_adc) = 0;
    [mu_top, spread_top, multiplicity_top] = circular_weighted_position(q_top);
    [mu_bottom, spread_bottom, multiplicity_bottom] = circular_weighted_position(q_bottom);
    if logical(p.thin_axes_rotated)
        unrouted_x = mu_bottom; unrouted_y = mu_top;
    else
        unrouted_x = mu_top; unrouted_y = mu_bottom;
    end
    raw_x = apply_circular_routing(unrouted_x, p.thin_x_flip, p.thin_x_cyclic_offset, n_plane_strips);
    raw_y = apply_circular_routing(unrouted_y, p.thin_y_flip, p.thin_y_cyclic_offset, n_plane_strips);

    thick_strip = NaN(n_events, 1); thick_tdif = NaN(n_events, 1);
    has_thick = columns(auxiliary.TOT1_F) >= 5 && columns(auxiliary.TOT1_B) >= 5 && ...
        columns(auxiliary.T1_F) >= 5 && columns(auxiliary.T1_B) >= 5;
    if has_thick
        q_f = auxiliary.TOT1_F(:, 1:5); q_b = auxiliary.TOT1_B(:, 1:5);
        q_f(~isfinite(q_f) | q_f <= 0) = 0; q_b(~isfinite(q_b) | q_b <= 0) = 0;
        [max_f, strip_f] = max(q_f, [], 2); [max_b, strip_b] = max(q_b, [], 2);
        thick_valid = max_f > 0 & max_b > 0 & strip_f == strip_b;
        event_rows = (1:n_events)';
        pair_index = sub2ind([n_events 5], event_rows, strip_f);
        t_f = auxiliary.T1_F(:, 1:5); t_b = auxiliary.T1_B(:, 1:5);
        paired_t_f = t_f(pair_index); paired_t_b = t_b(pair_index);
        thick_valid = thick_valid & paired_t_f ~= 0 & paired_t_b ~= 0 & ...
            isfinite(paired_t_f) & isfinite(paired_t_b);
        offsets = zeros(1, 5);
        calibration_file = fullfile(config_dir, 'calibration_offsets.csv');
        if exist(calibration_file, 'file') == 2
            calibration = dlmread(calibration_file, ',', 1, 0);
            if rows(calibration) >= 5 && columns(calibration) >= 4
                offsets = calibration(1:5, 4)';
            end
        end
        paired_offsets = offsets(strip_f); paired_offsets = paired_offsets(:);
        thick_strip(thick_valid) = strip_f(thick_valid);
        thick_tdif(thick_valid) = (paired_t_f(thick_valid) - paired_t_b(thick_valid)) / 2 - paired_offsets(thick_valid);
    end

    y_mapped = 1 + 119 * (thick_tdif - p.position_tdif_min_ns) / ...
        (p.position_tdif_max_ns - p.position_tdif_min_ns);
    y_mapped = max(1, min(120, y_mapped));
    final_x_axis = raw_x + (thick_strip - 1) * n_plane_strips;
    y_candidates = raw_y + repmat((0:n_wraps-1) * n_plane_strips, n_events, 1);
    [~, closest_wrap] = min(abs(y_candidates - repmat(y_mapped, 1, n_wraps)), [], 2);
    selected_y = sub2ind(size(y_candidates), (1:n_events)', closest_wrap);
    final_y_axis = y_candidates(selected_y);
    valid = isfinite(raw_x) & isfinite(raw_y) & isfinite(thick_strip) & isfinite(thick_tdif) & ...
        thick_tdif >= p.position_tdif_min_ns & thick_tdif <= p.position_tdif_max_ns;
    final_x_axis(~valid) = NaN; final_y_axis(~valid) = NaN;
    final_x_mm = (final_x_axis - 60.5) * p.strip_pitch_mm;
    final_y_mm = (final_y_axis - 60.5) * p.strip_pitch_mm;
    position = struct('valid', valid, 'raw_x', raw_x, 'raw_y', raw_y, ...
        'unrouted_x', unrouted_x, 'unrouted_y', unrouted_y, ...
        'spread_top', spread_top, 'spread_bottom', spread_bottom, ...
        'multiplicity_top', multiplicity_top, 'multiplicity_bottom', multiplicity_bottom, ...
        'thick_strip', thick_strip, 'thick_tdif_ns', thick_tdif, 'thick_y_axis', y_mapped, ...
        'final_x_axis', final_x_axis, 'final_y_axis', final_y_axis, ...
        'final_x_mm', final_x_mm, 'final_y_mm', final_y_mm, ...
        'strip_pitch_mm', p.strip_pitch_mm, 'axes_rotated', logical(p.thin_axes_rotated));
end

function routed = apply_circular_routing(values, flip, offset, period)
    direction = 1;
    if logical(flip), direction = -1; end
    routed = 1 + mod(direction * (values - 1) + offset, period);
    routed(~isfinite(values)) = NaN;
end

function [mu, sigma_like, multiplicity] = circular_weighted_position(charge)
    n_strips = columns(charge); angles = 2 * pi * (0:n_strips-1) / n_strips;
    total = sum(charge, 2); multiplicity = sum(charge > 0, 2);
    cosine = sum(charge .* repmat(cos(angles), rows(charge), 1), 2) ./ total;
    sine = sum(charge .* repmat(sin(angles), rows(charge), 1), 2) ./ total;
    resultant = sqrt(cosine .^ 2 + sine .^ 2);
    angle = atan2(sine, cosine); angle(angle < 0) = angle(angle < 0) + 2 * pi;
    mu = 1 + angle * n_strips / (2 * pi);
    sigma_like = sqrt(max(-2 * log(max(resultant, eps)), 0)) * n_strips / (2 * pi);
    invalid = total <= 0 | ~isfinite(resultant) | resultant <= 0;
    mu(invalid) = NaN; sigma_like(invalid) = NaN;
end

function scint = build_thin_scintillator_data(auxiliary, map, n_events, p)
    if columns(auxiliary.T2_F) < 6 || columns(auxiliary.TOT2_F) < 6
        time = zeros(n_events, 6); charge = zeros(n_events, 6);
    else
        time = auxiliary.T2_F(:, map.channel);
        charge = auxiliary.TOT2_F(:, map.channel);
    end
    recorded = isfinite(time) & isfinite(charge) & ...
        time >= p.scintillator_time_min_ns & time <= p.scintillator_time_max_ns & ...
        charge > 0 & charge < p.scintillator_tot_max_ns;
    fast_down_complete = all(recorded(:, 1:2), 2);
    fast_up_complete = all(recorded(:, 3:4), 2);
    fast_coincidence = fast_down_complete & fast_up_complete;
    slow_coincidence = recorded(:, 5) & recorded(:, 6);
    slow_core = slow_coincidence & ...
        charge(:, 5) >= p.slow_core_tot_min_ns & charge(:, 5) <= p.slow_core_tot_max_ns & ...
        charge(:, 6) >= p.slow_core_tot_min_ns & charge(:, 6) <= p.slow_core_tot_max_ns;
    all_coincidence = fast_coincidence & slow_coincidence;
    fast_down_time = row_masked_mean(time(:, 1:2), recorded(:, 1:2));
    fast_up_time = row_masked_mean(time(:, 3:4), recorded(:, 3:4));
    fast_down_charge = row_masked_sum(charge(:, 1:2), recorded(:, 1:2));
    fast_up_charge = row_masked_sum(charge(:, 3:4), recorded(:, 3:4));
    scint = struct('time', time, 'charge', charge, 'recorded', recorded, ...
        'labels', {map.label}, 'fast_down_complete', fast_down_complete, ...
        'fast_up_complete', fast_up_complete, 'fast_coincidence', fast_coincidence, ...
        'slow_coincidence', slow_coincidence, 'slow_core', slow_core, ...
        'all_coincidence', all_coincidence, ...
        'fast_down_time', fast_down_time, 'fast_up_time', fast_up_time, ...
        'fast_down_charge', fast_down_charge, 'fast_up_charge', fast_up_charge);
end

function values = row_masked_mean(data, mask)
    data(~mask) = 0; counts = sum(mask, 2); values = sum(data, 2) ./ counts; values(counts == 0) = NaN;
end

function values = row_masked_sum(data, mask)
    data(~mask) = 0; values = sum(data, 2); values(sum(mask, 2) == 0) = NaN;
end

function values = column_finite_median(data)
    values = NaN(1, columns(data));
    for idx = 1:columns(data)
        x = double(data(:, idx)); x = x(isfinite(x));
        if ~isempty(x), values(idx) = median(x); end
    end
end

function values = column_masked_median(data, mask)
    values = NaN(1, columns(data));
    for idx = 1:columns(data)
        x = double(data(mask(:, idx), idx)); x = x(isfinite(x));
        if ~isempty(x), values(idx) = median(x); end
    end
end

function write_thin_channel_summary(file_name, summary)
    fid = fopen(file_name, 'w');
    if fid < 0, error('Could not write %s.', file_name); end
    fprintf(fid, ['wire_input,raw_adc_channel,adc_bank,bank_channel,valid_trace_count,' ...
        'pulse_count,occupancy_percent,baseline_median_adc,baseline_noise_median_adc,' ...
        'pulse_amplitude_median_adc,trapezoid_charge_median_adc,positive_integral_median_adc,status\n']);
    for row = 1:rows(summary)
        raw = summary(row, 2);
        if raw <= 24, bank = 'Q1_T'; bank_channel = raw;
        else, bank = 'Q1_B'; bank_channel = raw - 24; end
        if summary(row, 11), status = 'LOW_OCCUPANCY'; else, status = 'OK'; end
        fprintf(fid, '%d,%d,%s,%d,%d,%d,%.10g,%.10g,%.10g,%.10g,%.10g,%.10g,%s\n', ...
            summary(row, 1), raw, bank, bank_channel, summary(row, 3), summary(row, 4), ...
            summary(row, 5), summary(row, 6), summary(row, 7), summary(row, 8), ...
            summary(row, 9), summary(row, 10), status);
    end
    fclose(fid);
end

function write_thin_event_summary(file_name, multiplicity, total_charge, centroid, position, scintillator)
    fid = fopen(file_name, 'w');
    if fid < 0, error('Could not write %s.', file_name); end
    fprintf(fid, ['event,multiplicity,total_trapezoid_charge_adc,charge_weighted_input,' ...
        'thin_x_mod24,thin_y_mod24,thick_strip,thick_tdif_ns,x_mm,y_mm,position_valid,' ...
        'slow_scint_coincidence,fast_scint_coincidence,all_scint_coincidence\n']);
    for event = 1:numel(multiplicity)
        fprintf(fid, '%d,%d,%.10g,%.10g,%.10g,%.10g,%.10g,%.10g,%.10g,%.10g,%d,%d,%d,%d\n', ...
            event, multiplicity(event), total_charge(event), centroid(event), ...
            position.raw_x(event), position.raw_y(event), position.thick_strip(event), ...
            position.thick_tdif_ns(event), position.final_x_mm(event), position.final_y_mm(event), ...
            position.valid(event), scintillator.slow_coincidence(event), ...
            scintillator.fast_coincidence(event), scintillator.all_coincidence(event));
    end
    fclose(fid);
end

function write_scintillator_summary(file_name, scintillator)
    fid = fopen(file_name, 'w');
    if fid < 0, error('Could not write %s.', file_name); end
    fprintf(fid, 'channel,label,recorded_count,occupancy_percent,leading_time_median_ns,tot_median_ns\n');
    n_events = rows(scintillator.time);
    for channel = 1:6
        mask = scintillator.recorded(:, channel);
        times = scintillator.time(mask, channel); charges = scintillator.charge(mask, channel);
        if isempty(times), median_time = NaN; median_charge = NaN;
        else, median_time = median(times); median_charge = median(charges); end
        fprintf(fid, '%d,%s,%d,%.10g,%.10g,%.10g\n', channel, scintillator.labels{channel}, ...
            nnz(mask), 100 * nnz(mask) / n_events, median_time, median_charge);
    end
    fclose(fid);
end

function write_routing_summary(file_name, position, scintillator, p)
    fid = fopen(file_name, 'w');
    if fid < 0, error('Could not write %s.', file_name); end
    fast = position.valid & scintillator.fast_coincidence;
    fast_strip_2 = fast & position.thick_strip == 2;
    fast_strip_3 = fast & position.thick_strip == 3;
    fprintf(fid, 'metric,value\n');
    fprintf(fid, 'thin_axes_rotated,%d\n', logical(p.thin_axes_rotated));
    fprintf(fid, 'thin_x_flip,%d\n', logical(p.thin_x_flip));
    fprintf(fid, 'thin_y_flip,%d\n', logical(p.thin_y_flip));
    fprintf(fid, 'thin_x_cyclic_offset,%.10g\n', p.thin_x_cyclic_offset);
    fprintf(fid, 'thin_y_cyclic_offset,%.10g\n', p.thin_y_cyclic_offset);
    fprintf(fid, 'fast_four_pmt_reconstructed_count,%d\n', nnz(fast));
    fprintf(fid, 'fast_strip2_unrouted_x_median,%.10g\n', masked_median(position.unrouted_x, fast_strip_2));
    fprintf(fid, 'fast_strip3_unrouted_x_median,%.10g\n', masked_median(position.unrouted_x, fast_strip_3));
    fprintf(fid, 'fast_strip2_routed_x_median,%.10g\n', masked_median(position.raw_x, fast_strip_2));
    fprintf(fid, 'fast_strip3_routed_x_median,%.10g\n', masked_median(position.raw_x, fast_strip_3));
    fprintf(fid, 'slow_broad_reconstructed_count,%d\n', nnz(position.valid & scintillator.slow_coincidence));
    fprintf(fid, 'slow_core_reconstructed_count,%d\n', nnz(position.valid & scintillator.slow_core));
    fclose(fid);
end

function value = masked_median(data, mask)
    values = data(mask & isfinite(data));
    if isempty(values), value = NaN; else, value = median(values); end
end

function make_thin_summary_plot(summary, mean_waveform, p, run_name, output_dir, file_name, save_plots)
    fig = figure('Color', 'w', 'Position', [40 40 1500 900]);
    subplot(2, 2, 1); bar(summary(:, 1), summary(:, 5), 1); grid on;
    hold on; plot([0 49], [100 * p.dead_occupancy_fraction * median(summary(:, 5) / 100), ...
        100 * p.dead_occupancy_fraction * median(summary(:, 5) / 100)], 'r--');
    xlim([0 49]); xlabel('Input wire'); ylabel('Pulse occupancy [%]'); title('Occupancy');
    subplot(2, 2, 2); bar(summary(:, 1), summary(:, 9), 1); grid on;
    xlim([0 49]); xlabel('Input wire'); ylabel('Median trapezoid charge [ADC]'); title('Pulse charge');
    subplot(2, 2, 3); bar(summary(:, 1), summary(:, 7), 1); grid on;
    xlim([0 49]); xlabel('Input wire'); ylabel('Median baseline RMS [ADC]'); title('Baseline noise');
    waveform_baseline = mean(mean_waveform(1:p.baseline_samples, :), 1);
    mean_waveform_zeroed = mean_waveform - repmat(waveform_baseline, rows(mean_waveform), 1);
    subplot(2, 2, 4); imagesc(1:48, 1:rows(mean_waveform_zeroed), mean_waveform_zeroed);
    axis xy; colorbar; xlabel('Input wire'); ylabel('ADC sample'); title('Mean baseline-subtracted waveform [ADC]');
    annotation('textbox', [0.2 0.95 0.6 0.04], 'String', ...
        sprintf('%s: thin-strip pulse diagnostics', run_name), 'HorizontalAlignment', 'center', ...
        'EdgeColor', 'none', 'FontWeight', 'bold', 'Interpreter', 'none');
    save_thin_figure(fig, output_dir, file_name, save_plots);
end

function make_thin_event_plot(multiplicity, total_charge, centroid, run_name, output_dir, file_name, save_plots)
    fig = figure('Color', 'w', 'Position', [60 60 1500 480]);
    subplot(1, 3, 1); hist(multiplicity, 0:max(max(multiplicity), 1));
    xlabel('Inputs above threshold'); ylabel('Events');
    title(sprintf('%s: pulse multiplicity', run_name), 'Interpreter', 'none'); grid on;
    subplot(1, 3, 2); positive = total_charge(total_charge > 0);
    if ~isempty(positive)
        hist(positive, 100);
        upper_charge = quantile(positive, 0.995);
        if isfinite(upper_charge) && upper_charge > 0, xlim([0 upper_charge]); end
    end
    xlabel('Total trapezoid charge [ADC]'); ylabel('Events'); title('Event charge'); grid on;
    subplot(1, 3, 3); finite_centroid = centroid(isfinite(centroid));
    if ~isempty(finite_centroid), hist(finite_centroid, 1:48); end
    xlabel('Charge-weighted input wire'); ylabel('Events'); title('Pulse centroid'); grid on;
    save_thin_figure(fig, output_dir, file_name, save_plots);
end

function make_thin_pulse_examples_plot(waveforms, events, dead_channel, run_name, output_dir, file_name, save_plots, p)
    available = find(~dead_channel' & isfinite(events));
    count = min(p.pulse_example_count, numel(available));
    if count == 0, return; end
    selected = available(unique(round(linspace(1, numel(available), count))));
    count = numel(selected); n_columns = 4; n_rows = ceil(count / n_columns);
    fig = figure('Color', 'w', 'Position', [30 30 1500 320 * n_rows]);
    for idx = 1:count
        wire = selected(idx); subplot(n_rows, n_columns, idx);
        plot(1:rows(waveforms), waveforms(:, wire), '-o', 'LineWidth', 1.1, 'MarkerSize', 3);
        hold on; plot([p.signal_start_sample p.signal_start_sample], ylim(), 'r--'); hold off;
        grid on; xlabel('ADC sample'); ylabel('ADC - baseline');
        title(sprintf('Input %d, event %d', wire, events(wire)));
    end
    annotation('textbox', [0.2 0.965 0.6 0.025], 'String', ...
        sprintf('%s: representative negative pulses', run_name), 'HorizontalAlignment', 'center', ...
        'EdgeColor', 'none', 'FontWeight', 'bold', 'Interpreter', 'none');
    save_thin_figure(fig, output_dir, file_name, save_plots);
end

function make_thin_charge_spectra_plot(charge, pulse, run_name, output_dir, file_name, save_plots)
    all_values = double(charge(pulse));
    if isempty(all_values), return; end
    upper = quantile(all_values, 0.99); if ~isfinite(upper) || upper <= 0, upper = max(all_values); end
    centers = linspace(0, upper, 50);
    fig = figure('Color', 'w', 'Position', [20 20 1900 1500]);
    for wire = 1:48
        subplot(6, 8, wire); values = double(charge(pulse(:, wire), wire));
        if ~isempty(values)
            counts = hist(values, centers); bar(centers, counts, 1, 'FaceColor', [0.25 0.55 0.85], 'EdgeColor', 'none');
            xlim([0 upper]);
        else
            text(0.5, 0.5, 'No pulses', 'HorizontalAlignment', 'center'); axis off;
        end
        title(sprintf('Input %d', wire));
        if wire > 40, xlabel('Q [ADC]'); end
        if mod(wire - 1, 8) == 0, ylabel('Events'); end
    end
    annotation('textbox', [0.2 0.972 0.6 0.02], 'String', ...
        sprintf('%s: thin-input trapezoidal charge spectra', run_name), 'HorizontalAlignment', 'center', ...
        'EdgeColor', 'none', 'FontWeight', 'bold', 'Interpreter', 'none');
    save_thin_figure(fig, output_dir, file_name, save_plots);
end

function make_thin_charge_sharing_plot(event_charge, position, run_name, output_dir, file_name, save_plots, p)
    candidates = find(position.valid & position.multiplicity_top >= 2 & position.multiplicity_bottom >= 2);
    if isempty(candidates), return; end
    quality = position.spread_top(candidates) + position.spread_bottom(candidates);
    [~, order] = sort(quality, 'ascend');
    count = min(p.charge_share_example_count, numel(order)); selected = candidates(order(1:count));
    fig = figure('Color', 'w', 'Position', [60 30 1200 260 * count]);
    for idx = 1:count
        event = selected(idx);
        subplot(count, 2, 2 * idx - 1); bar(1:24, event_charge(event, 1:24), 1);
        hold on; limits = ylim(); plot([position.raw_x(event) position.raw_x(event)], limits, 'r-', 'LineWidth', 1.4); hold off;
        xlim([0.5 24.5]); grid on; ylabel('Charge [ADC]');
        title(sprintf('Event %d plane 1: x=%.2f', event, position.raw_x(event)));
        subplot(count, 2, 2 * idx); bar(1:24, event_charge(event, 25:48), 1);
        hold on; limits = ylim(); plot([position.raw_y(event) position.raw_y(event)], limits, 'r-', 'LineWidth', 1.4); hold off;
        xlim([0.5 24.5]); grid on;
        title(sprintf('Plane 2: y=%.2f', position.raw_y(event)));
        if idx == count, xlabel('Input modulo 24'); end
    end
    annotation('textbox', [0.2 0.972 0.6 0.02], 'String', ...
        sprintf('%s: Joao-style circular charge sharing', run_name), 'HorizontalAlignment', 'center', ...
        'EdgeColor', 'none', 'FontWeight', 'bold', 'Interpreter', 'none');
    save_thin_figure(fig, output_dir, file_name, save_plots);
end

function make_circular_gaussian_examples_plot(event_charge, position, scint, run_name, output_dir, file_name, save_plots, p)
    scintillator_coincidence = scint.slow_coincidence | scint.fast_coincidence;
    candidates = find(position.valid & scintillator_coincidence & ...
        position.multiplicity_top >= 3 & position.multiplicity_bottom >= 3);
    if isempty(candidates), return; end
    quality = position.spread_top(candidates) + position.spread_bottom(candidates);
    count = min(p.charge_share_example_count, numel(candidates));
    selected = zeros(count, 1);
    minimum_cluster_size = min(position.multiplicity_top, position.multiplicity_bottom);
    used = false(numel(candidates), 1);
    % Deliberately show several cluster sizes instead of repeatedly choosing
    % the narrowest two-channel charge-sharing events.
    for idx = 1:count
        target_size = idx + 2;
        pool = find(~used & minimum_cluster_size(candidates) == target_size);
        if isempty(pool), pool = find(~used); end
        [~, best_in_pool] = min(quality(pool));
        chosen = pool(best_in_pool);
        selected(idx) = candidates(chosen); used(chosen) = true;
    end
    fig = figure('Color', 'w', 'Position', [50 20 1250 270 * count]);
    for idx = 1:count
        event = selected(idx);
        profiles = {event_charge(event, 1:24), event_charge(event, 25:48)};
        if scint.fast_coincidence(event) && scint.slow_coincidence(event)
            trigger_label = 'fast+slow';
        elseif scint.fast_coincidence(event)
            trigger_label = 'fast';
        else
            trigger_label = 'slow';
        end
        for plane = 1:2
            [mu_fit, sigma_fit, model, chi_square, fit_x, fit_model] = fit_circular_gaussian(profiles{plane});
            subplot(count, 2, 2 * idx - 2 + plane);
            bar(1:24, profiles{plane}, 1, 'FaceColor', [0.25 0.50 0.80], 'EdgeColor', 'none'); hold on;
            plot(fit_x, fit_model, 'r-', 'LineWidth', 2.2);
            hold off; xlim([0.5 24.5]); grid on;
            ylabel('Charge [ADC]'); if idx == count, xlabel('Input modulo 24'); end
            if plane == 1
                routed_mu = apply_circular_routing(mu_fit, p.thin_x_flip, p.thin_x_cyclic_offset, 24);
            else
                routed_mu = apply_circular_routing(mu_fit, p.thin_y_flip, p.thin_y_cyclic_offset, 24);
            end
            if plane == 1, cluster_size = position.multiplicity_top(event);
            else, cluster_size = position.multiplicity_bottom(event); end
            title(sprintf('%s event %d, plane %d, CS=%d: mu=%.2f -> %.2f, sigma=%.2f, SSE=%.2g', ...
                trigger_label, event, plane, cluster_size, mu_fit, routed_mu, sigma_fit, chi_square));
        end
    end
    annotation('textbox', [0.18 0.972 0.64 0.02], 'String', ...
        sprintf('%s: wrapped circular-Gaussian avalanche-position examples', run_name), ...
        'HorizontalAlignment', 'center', 'EdgeColor', 'none', 'FontWeight', 'bold', 'Interpreter', 'none');
    save_thin_figure(fig, output_dir, file_name, save_plots);
end

function [mu, sigma, model, chi_square, fit_x, fit_model] = fit_circular_gaussian(profile)
    x = (1:24)'; y = double(profile(:)); y(~isfinite(y)) = 0;
    [peak, mu0] = max(y); amplitude0 = max(peak, eps);
    wrap_distance = @(delta) mod(delta + 12, 24) - 12;
    sigma_from_parameter = @(value) 0.2 + 5.8 ./ (1 + exp(-value));
    model_from_parameters = @(parameters, coordinates) exp(parameters(3)) .* ...
        exp(-0.5 * wrap_distance(coordinates - (1 + mod(parameters(1) - 1, 24))) .^ 2 ./ ...
        sigma_from_parameter(parameters(2)) .^ 2);
    objective = @(parameters) sum((y - model_from_parameters(parameters, x)) .^ 2);
    options = optimset('Display', 'off', 'MaxFunEvals', 1500, 'MaxIter', 1500);
    initial_sigma_parameter = log((1 - 0.2) / (6 - 1));
    fitted = fminsearch(objective, [mu0, initial_sigma_parameter, log(amplitude0)], options);
    mu = 1 + mod(fitted(1) - 1, 24); sigma = sigma_from_parameter(fitted(2));
    model = model_from_parameters(fitted, x); chi_square = objective(fitted);
    fit_x = linspace(0.5, 24.5, 1201)';
    fit_model = model_from_parameters(fitted, fit_x);
end

function make_thin_position_plot(position, scint, run_name, output_dir, file_name, save_plots)
    fig = figure('Color', 'w', 'Position', [20 20 1800 1100]);
    subplot(2, 3, 1); plot_position_density_mm(position, position.valid);
    xlabel('X [mm]'); ylabel('Y [mm]'); title('Thick-strip disambiguated: all');
    subplot(2, 3, 2); plot_position_density_mm(position, position.valid & scint.slow_coincidence);
    xlabel('X [mm]'); ylabel('Y [mm]');
    title(sprintf('Slow pair, broad validity (N=%d)', nnz(position.valid & scint.slow_coincidence)));
    subplot(2, 3, 3); plot_position_density_mm(position, position.valid & scint.slow_core);
    xlabel('X [mm]'); ylabel('Y [mm]');
    title(sprintf('Slow pair, optional ToT core (N=%d)', nnz(position.valid & scint.slow_core)));
    subplot(2, 3, 4); plot_position_density_mm(position, position.valid & scint.fast_down_complete);
    xlabel('X [mm]'); ylabel('Y [mm]');
    title(sprintf('Fast down PMT pair (N=%d)', nnz(position.valid & scint.fast_down_complete)));
    subplot(2, 3, 5); plot_position_density_mm(position, position.valid & scint.fast_up_complete);
    xlabel('X [mm]'); ylabel('Y [mm]');
    title(sprintf('Fast up PMT pair (N=%d)', nnz(position.valid & scint.fast_up_complete)));
    subplot(2, 3, 6); plot_position_density_mm(position, position.valid & scint.fast_coincidence);
    xlabel('X [mm]'); ylabel('Y [mm]');
    title(sprintf('Four-fast-PMT coincidence (N=%d)', nnz(position.valid & scint.fast_coincidence)));
    annotation('textbox', [0.2 0.965 0.6 0.025], 'String', ...
        sprintf('%s: reconstructed thin-strip positions', run_name), 'HorizontalAlignment', 'center', ...
        'EdgeColor', 'none', 'FontWeight', 'bold', 'Interpreter', 'none');
    save_thin_figure(fig, output_dir, file_name, save_plots);
end

function plot_position_density(x, y, mask, n_bins)
    valid = mask & isfinite(x) & isfinite(y) & x >= 1 & x <= n_bins & y >= 1 & y <= n_bins;
    if ~any(valid), text(0.5, 0.5, 'No reconstructed events', 'HorizontalAlignment', 'center'); axis off; return; end
    x_bin = max(1, min(n_bins, round(x(valid)))); y_bin = max(1, min(n_bins, round(y(valid))));
    counts = accumarray([y_bin x_bin], 1, [n_bins n_bins]);
    imagesc(1:n_bins, 1:n_bins, log10(1 + counts)); axis xy square; colorbar;
end

function plot_position_density_mm(position, mask)
    n_bins = 120; x = position.final_x_axis; y = position.final_y_axis;
    valid = mask & isfinite(x) & isfinite(y) & x >= 1 & x <= n_bins & y >= 1 & y <= n_bins;
    if ~any(valid), text(0.5, 0.5, 'No reconstructed events', 'HorizontalAlignment', 'center'); axis off; return; end
    x_bin = max(1, min(n_bins, round(x(valid)))); y_bin = max(1, min(n_bins, round(y(valid))));
    counts = accumarray([y_bin x_bin], 1, [n_bins n_bins]);
    centers_mm = ((1:n_bins) - 60.5) * position.strip_pitch_mm;
    imagesc(centers_mm, centers_mm, log10(1 + counts)); axis xy square; colorbar;
end

function make_thick_only_position_plot(position, scint, p, run_name, output_dir, file_name, save_plots)
    masks = {true(rows(position.thick_strip), 1), scint.slow_coincidence, scint.slow_core, ...
        scint.fast_down_complete, scint.fast_up_complete, scint.fast_coincidence};
    labels = {'All thick-strip events', 'Slow pair: broad validity', 'Slow pair: optional ToT core', ...
        'Fast down PMT pair', 'Fast up PMT pair', 'Four-fast-PMT coincidence'};
    fig = figure('Color', 'w', 'Position', [20 20 1800 1100]);
    for idx = 1:6
        subplot(2, 3, idx); count = plot_thick_position_density(position, masks{idx}, p);
        xlabel('Thick-strip X [mm]'); ylabel('Thick timing Y [mm]');
        title(sprintf('%s (N=%d)', labels{idx}, count));
    end
    annotation('textbox', [0.2 0.965 0.6 0.025], 'String', ...
        sprintf('%s: thick-strip-only reference maps', run_name), 'HorizontalAlignment', 'center', ...
        'EdgeColor', 'none', 'FontWeight', 'bold', 'Interpreter', 'none');
    save_thin_figure(fig, output_dir, file_name, save_plots);
end

function count = plot_thick_position_density(position, mask, p)
    valid = mask & isfinite(position.thick_strip) & isfinite(position.thick_y_axis) & ...
        position.thick_strip >= 1 & position.thick_strip <= 5 & ...
        position.thick_tdif_ns >= p.position_tdif_min_ns & position.thick_tdif_ns <= p.position_tdif_max_ns;
    count = nnz(valid);
    if count == 0, text(0.5, 0.5, 'No thick-strip positions', 'HorizontalAlignment', 'center'); axis off; return; end
    strip = round(position.thick_strip(valid)); y_bin = max(1, min(120, round(position.thick_y_axis(valid))));
    counts = accumarray([y_bin strip], 1, [120 5]);
    x_centers_mm = ((1:5) - 3) * 24 * p.strip_pitch_mm;
    y_centers_mm = ((1:120) - 60.5) * p.strip_pitch_mm;
    imagesc(x_centers_mm, y_centers_mm, log10(1 + counts)); axis xy; colorbar;
end

function make_fast_slow_position_comparison_plot(position, scint, p, run_name, output_dir, file_name, save_plots)
    % Trigger type is arranged by column and reconstruction type by row.
    % Broad signal-presence selections avoid sculpting either shadow with
    % optional PMT or slow-scintillator charge windows.
    fast_mask = scint.fast_coincidence;
    slow_mask = scint.slow_coincidence;
    fig = figure('Color', 'w', 'Position', [30 20 1450 1120]);

    subplot(2, 2, 1);
    fast_thick_count = plot_thick_position_density(position, fast_mask, p);
    xlabel('Thick-strip X [mm]'); ylabel('Thick timing Y [mm]');
    title(sprintf('Fast scintillator: thick strips only (N=%d)', fast_thick_count));

    subplot(2, 2, 2);
    slow_thick_count = plot_thick_position_density(position, slow_mask, p);
    xlabel('Thick-strip X [mm]'); ylabel('Thick timing Y [mm]');
    title(sprintf('Slow scintillator: thick strips only (N=%d)', slow_thick_count));

    subplot(2, 2, 3);
    fast_final_mask = position.valid & fast_mask;
    plot_position_density_mm(position, fast_final_mask);
    xlabel('Final X [mm]'); ylabel('Final Y [mm]');
    title(sprintf('Fast scintillator: final reconstruction (N=%d)', nnz(fast_final_mask)));

    subplot(2, 2, 4);
    slow_final_mask = position.valid & slow_mask;
    plot_position_density_mm(position, slow_final_mask);
    xlabel('Final X [mm]'); ylabel('Final Y [mm]');
    title(sprintf('Slow scintillator: final reconstruction (N=%d)', nnz(slow_final_mask)));

    annotation('textbox', [0.14 0.965 0.72 0.025], 'String', ...
        sprintf('%s: scintillator shadows before and after thin-strip reconstruction', run_name), ...
        'HorizontalAlignment', 'center', 'EdgeColor', 'none', ...
        'FontWeight', 'bold', 'Interpreter', 'none');
    save_thin_figure(fig, output_dir, file_name, save_plots);
end

function make_combined_final_position_geometry_plot(position, scint, geometry, run_name, output_dir, file_name, save_plots)
    n_bins = 120;
    centers_mm = ((1:n_bins) - 60.5) * position.strip_pitch_mm;
    fast_counts = final_position_density_counts(position, position.valid & scint.fast_coincidence, n_bins);
    slow_counts = final_position_density_counts(position, position.valid & scint.slow_coincidence, n_bins);
    fast_density = normalized_log_density(fast_counts) .^ 0.65;
    slow_density = normalized_log_density(slow_counts) .^ 0.65;

    % Normalize each trigger independently: otherwise the much larger slow
    % sample would make the compact fast-scintillator shadow disappear.
    fast_color = [0.88 0.03 0.01];
    slow_color = [0.01 0.22 0.88];
    rgb = ones(n_bins, n_bins, 3);
    for channel = 1:3
        rgb(:, :, channel) = 1 - fast_density * (1 - fast_color(channel)) ...
            - slow_density * (1 - slow_color(channel));
    end
    rgb = max(0, min(1, rgb));

    fig = figure('Color', 'w', 'Position', [30 20 1500 1200]);
    image(centers_mm, centers_mm, rgb); set(gca, 'YDir', 'normal');
    axis square; xlim([-155 155]); ylim([-155 155]); grid off; hold on;
    set(gca, 'FontSize', 22, 'LineWidth', 1.8, 'TickDir', 'out');
    xlabel('Final X [mm]', 'FontSize', 27, 'FontWeight', 'bold');
    ylabel('Final Y [mm]', 'FontSize', 27, 'FontWeight', 'bold');
    title(sprintf('%s: combined final positions and detector geometry', run_name), ...
        'Interpreter', 'none', 'FontSize', 29, 'FontWeight', 'bold');

    for idx = 1:numel(geometry.label)
        lower_x = geometry.center_x_mm(idx) - geometry.base_mm(idx) / 2;
        lower_y = geometry.center_y_mm(idx) - geometry.height_mm(idx) / 2;
        if strcmp(geometry.category{idx}, 'thick_strip')
            edge_color = [0.08 0.08 0.08]; line_style = '--'; line_width = 4.0;
        elseif strcmp(geometry.category{idx}, 'fast_scintillator')
            edge_color = fast_color; line_style = '-'; line_width = 5.0;
        else
            edge_color = slow_color; line_style = '-'; line_width = 5.0;
        end
        rectangle('Position', [lower_x lower_y geometry.base_mm(idx) geometry.height_mm(idx)], ...
            'EdgeColor', edge_color, 'LineStyle', line_style, 'LineWidth', line_width);
        if ~strcmp(geometry.category{idx}, 'thick_strip')
            text(lower_x + 2, lower_y + geometry.height_mm(idx) - 3, ...
                strrep(geometry.label{idx}, '_', ' '), 'Color', edge_color, ...
                'FontSize', 22, 'FontWeight', 'bold', 'VerticalAlignment', 'top', ...
                'BackgroundColor', 'w', 'Margin', 2);
        end
    end

    hold off;
    save_thin_figure(fig, output_dir, file_name, save_plots);
end

function counts = final_position_density_counts(position, mask, n_bins)
    x = position.final_x_axis; y = position.final_y_axis;
    valid = mask & isfinite(x) & isfinite(y) & x >= 1 & x <= n_bins & y >= 1 & y <= n_bins;
    x_bin = max(1, min(n_bins, round(x(valid))));
    y_bin = max(1, min(n_bins, round(y(valid))));
    if any(valid), counts = accumarray([y_bin x_bin], 1, [n_bins n_bins]);
    else, counts = zeros(n_bins, n_bins); end
end

function density = normalized_log_density(counts)
    density = log10(1 + counts);
    positive = density(density > 0);
    if isempty(positive), return; end
    % A robust upper scale makes the occupied regions presentation-visible
    % without allowing one exceptionally hot bin to wash out the map.
    upper_scale = quantile(positive, 0.98);
    if upper_scale > 0, density = min(1, density / upper_scale); end
end

function make_routing_diagnostics_plot(position, scint, run_name, output_dir, file_name, save_plots)
    fig = figure('Color', 'w', 'Position', [30 30 1450 1150]);
    subplot(2, 2, 1); plot_position_density(position.unrouted_x, position.unrouted_y, ...
        isfinite(position.unrouted_x) & isfinite(position.unrouted_y), 24);
    xlabel('Unrouted plane-1 modulo 24'); ylabel('Plane-2 modulo 24'); title('Before routing orientation');
    subplot(2, 2, 2); plot_position_density(position.raw_x, position.raw_y, ...
        isfinite(position.raw_x) & isfinite(position.raw_y), 24);
    xlabel('Routed plane-1 modulo 24'); ylabel('Plane-2 modulo 24'); title('After configured plane-1 flip');
    old_position = position;
    old_position.final_x_axis = position.unrouted_x + (position.thick_strip - 1) * 24;
    old_position.final_x_mm = (old_position.final_x_axis - 60.5) * position.strip_pitch_mm;
    subplot(2, 2, 3); plot_position_density_mm(old_position, position.valid & scint.fast_coincidence);
    xlabel('X [mm]'); ylabel('Y [mm]'); title('Fast four-PMT map before X flip');
    subplot(2, 2, 4); plot_position_density_mm(position, position.valid & scint.fast_coincidence);
    xlabel('X [mm]'); ylabel('Y [mm]'); title('Fast four-PMT map after X flip');
    annotation('textbox', [0.2 0.965 0.6 0.025], 'String', ...
        sprintf('%s: thin-routing orientation diagnostic', run_name), 'HorizontalAlignment', 'center', ...
        'EdgeColor', 'none', 'FontWeight', 'bold', 'Interpreter', 'none');
    save_thin_figure(fig, output_dir, file_name, save_plots);
end

function make_scintillator_overview_plot(scint, run_name, output_dir, file_name, save_plots)
    if ~any(scint.recorded(:)), return; end
    fig = figure('Color', 'w', 'Position', [20 20 1900 650]);
    for channel = 1:6
        subplot(2, 6, channel); values = scint.time(scint.recorded(:, channel), channel);
        plot_auto_histogram(values, 70, [0.35 0.65 0.90]);
        title(strrep(scint.labels{channel}, '_', ' ')); xlabel('Leading time [ns]'); ylabel('Events');
        subplot(2, 6, 6 + channel); values = scint.charge(scint.recorded(:, channel), channel);
        plot_auto_histogram(values, 70, [0.90 0.55 0.25]);
        xlabel('ToT [ns]'); ylabel('Events');
    end
    annotation('textbox', [0.2 0.955 0.6 0.03], 'String', ...
        sprintf('%s: T2 scintillator channels', run_name), 'HorizontalAlignment', 'center', ...
        'EdgeColor', 'none', 'FontWeight', 'bold', 'Interpreter', 'none');
    save_thin_figure(fig, output_dir, file_name, save_plots);
end

function make_scintillator_correlations_plot(scint, run_name, output_dir, file_name, save_plots)
    if ~any(scint.recorded(:)), return; end
    fig = figure('Color', 'w', 'Position', [25 25 1500 900]);
    subplot(2, 3, 1); plot_sampled_scatter(scint.charge(:, 1), scint.charge(:, 2), scint.fast_down_complete);
    xlabel('Fast down PMT1 ToT [ns]'); ylabel('PMT2 ToT [ns]'); title('Fast down charge correlation');
    subplot(2, 3, 2); plot_sampled_scatter(scint.charge(:, 3), scint.charge(:, 4), scint.fast_up_complete);
    xlabel('Fast up PMT1 ToT [ns]'); ylabel('PMT2 ToT [ns]'); title('Fast up charge correlation');
    subplot(2, 3, 3); plot_sampled_scatter(scint.charge(:, 5), scint.charge(:, 6), scint.slow_coincidence);
    xlabel('Slow 1 ToT [ns]'); ylabel('Slow 2 ToT [ns]'); title('Slow-scint charge correlation');
    subplot(2, 3, 4); fast_dt = scint.fast_down_time - scint.fast_up_time;
    plot_auto_histogram(fast_dt(scint.fast_coincidence), 100, [0.45 0.35 0.85]);
    xlabel('Mean fast down - mean fast up [ns]'); ylabel('Events'); title('Fast scintillator time difference');
    subplot(2, 3, 5); slow_dt = scint.time(:, 5) - scint.time(:, 6);
    plot_auto_histogram(slow_dt(scint.slow_coincidence), 100, [0.25 0.70 0.45]);
    xlabel('Slow 1 - slow 2 [ns]'); ylabel('Events'); title('Slow scintillator time difference');
    subplot(2, 3, 6); plot_sampled_scatter(scint.fast_down_charge, scint.fast_up_charge, scint.fast_coincidence);
    xlabel('Fast down summed ToT [ns]'); ylabel('Fast up summed ToT [ns]'); title('Fast up/down charge correlation');
    annotation('textbox', [0.2 0.955 0.6 0.03], 'String', ...
        sprintf('%s: scintillator coincidences and correlations', run_name), 'HorizontalAlignment', 'center', ...
        'EdgeColor', 'none', 'FontWeight', 'bold', 'Interpreter', 'none');
    save_thin_figure(fig, output_dir, file_name, save_plots);
end

function plot_auto_histogram(values, n_bins, color)
    values = values(isfinite(values));
    if isempty(values), text(0.5, 0.5, 'No entries', 'HorizontalAlignment', 'center'); axis off; return; end
    lower = quantile(values, 0.005); upper = quantile(values, 0.995);
    if lower == upper, lower = min(values); upper = max(values); end
    if lower == upper, lower = lower - 1; upper = upper + 1; end
    centers = linspace(lower, upper, n_bins); counts = hist(values, centers);
    bar(centers, counts, 1, 'FaceColor', color, 'EdgeColor', 'none'); xlim([lower upper]); grid on;
end

function plot_sampled_scatter(x, y, mask)
    valid = mask & isfinite(x) & isfinite(y); indices = find(valid);
    if isempty(indices), text(0.5, 0.5, 'No coincidences', 'HorizontalAlignment', 'center'); axis off; return; end
    if numel(indices) > 6000, indices = indices(round(linspace(1, numel(indices), 6000))); end
    plot(x(indices), y(indices), '.', 'MarkerSize', 3); grid on;
end

function save_thin_figure(fig, output_dir, file_name, save_plots)
    if save_plots
        available = available_graphics_toolkits();
        if any(strcmp(available, 'gnuplot')), graphics_toolkit(fig, 'gnuplot'); end
        set(fig, 'visible', 'off');
        print(fig, fullfile(output_dir, file_name), '-dpng', '-r100');
        close(fig);
    end
end
