% TOMAR fast-electronics 6 x 6 analysis (GNU Octave compatible)
%
% The core analysis covers the twelve fast-TDC channels:
%   T1_F, T1_B       leading-edge time [ns], 6 front + 6 back channels
%   TOT1_F, TOT1_B   time-over-threshold [ns], matching channels
%   EBtime           absolute event timestamp [days]
%
% When sampled thin-strip ADC arrays Q1_T/Q1_B are present, the companion
% thin-strip pulse analysis is run automatically using Alberto's lookup.
% Editable CSV configuration files live in TOMAR/CONFIGS. Histogram axis
% limits never alter the data.
%
% Run from the repository root:
%   octave-cli --quiet TOMAR/run_fast_6x6.m
% Run definitions are listed in TOMAR/CONFIGS/runs.csv. MAT files live in TOMAR/DATA;
% bring_data.sh fetches them from TOMAR's varData DAQ directory.
%
% Direct invocation also accepts optional arguments:
%   analyze_fast_6x6('/path/to/file.mat', true, true, 1000, 'run_name')
%   arguments: MAT file, no_plot, save_plots, maximum valid ToT [ns], run name

function analyze_fast_6x6(mat_file, no_plot, save_plots, tot_max_ns, requested_run)

% ---------------------------------------------------------------------
% Header and output setup
% ---------------------------------------------------------------------

if nargin < 1 || isempty(mat_file), mat_file = ''; end
if nargin < 2 || isempty(no_plot), no_plot = false; end
if nargin < 3 || isempty(save_plots), save_plots = false; end
if nargin < 4 || isempty(tot_max_ns), tot_max_ns = 1000; end
if nargin < 5 || isempty(requested_run), requested_run = ''; end

script_dir = fileparts(mfilename('fullpath'));
tomar_root = fileparts(script_dir);
data_dir = fullfile(tomar_root, 'DATA');
config_dir = fullfile(tomar_root, 'CONFIGS');
run_config_file = fullfile(config_dir, 'runs.csv');
if isempty(mat_file)
    [run_name, mat_file, run_comment, run_order, scint_mode] = resolve_run_configuration(run_config_file, data_dir, requested_run);
else
    [~, run_name] = fileparts(mat_file);
    run_comment = '';
    run_order = 1;
    scint_mode = 'none';
end
scint_required = ~strcmp(scint_mode, 'none');
if exist(mat_file, 'file') ~= 2
    error('MAT file not found: %s', mat_file);
end

output_directory_name = sprintf('%d_%s', run_order, regexprep(run_name, '\s+', '_'));
output_dir = fullfile(tomar_root, 'OUTPUTS', output_directory_name);
if exist(output_dir, 'dir') ~= 7, mkdir(output_dir); end
archived_file_count = archive_previous_output_files(output_dir);
calibration_file = fullfile(config_dir, 'calibration_offsets.csv');
limits_file = fullfile(config_dir, 'histogram_limits.csv');
filter_file = fullfile(config_dir, 'filter_limits.csv');
scint_histogram_limits_file = fullfile(config_dir, 'scint_histogram_limits.csv');
scint_filter_limits_file = fullfile(config_dir, 'scint_filter_limits.csv');
alt_scintillator_map_file = fullfile(config_dir, 'alt_scintillator_map.csv');
special_parameters_file = fullfile(config_dir, 'special_parameters.csv');
plot_list_file = fullfile(config_dir, 'plot_list.csv');
ensure_configuration_templates(calibration_file, limits_file, filter_file, scint_histogram_limits_file, scint_filter_limits_file, special_parameters_file, plot_list_file, alt_scintillator_map_file);
[qf_offset, qb_offset, tdif_offset, q_dif_offset] = read_calibration_offsets(calibration_file);
histogram_limits = read_histogram_limits(limits_file, false);
filter_limits = read_histogram_limits(filter_file, true);
scint_histogram_limits = read_scint_limits(scint_histogram_limits_file, false);
scint_filter_limits = read_scint_limits(scint_filter_limits_file, true);
special_parameters = read_special_parameters(special_parameters_file);
plot_list = read_plot_list(plot_list_file);
alt_scintillator_map = read_alt_scintillator_map(alt_scintillator_map_file);

should_plot = logical(~no_plot);
% Headless terminals should save PNGs quietly instead of rendering ASCII plots.
restore_figure_visibility = [];
restore_text_interpreter = [];
if should_plot && save_plots
    available_toolkits = available_graphics_toolkits();
    if any(strcmp(available_toolkits, 'gnuplot'))
        setenv('GNUTERM', 'pngcairo');
        graphics_toolkit('gnuplot');
    end
    previous_visibility = get(0, 'defaultfigurevisible');
    set(0, 'defaultfigurevisible', 'off');
    restore_figure_visibility = onCleanup(@() set(0, 'defaultfigurevisible', previous_visibility));
    previous_text_interpreter = get(0, 'defaulttextinterpreter');
    set(0, 'defaulttextinterpreter', 'none');
    restore_text_interpreter = onCleanup(@() set(0, 'defaulttextinterpreter', previous_text_interpreter));
end
log_info = @(fmt, varargin) fprintf('[INFO] %s\n', sprintf(fmt, varargin{:}));
log_banner = @(fmt, varargin) fprintf('\n=== %s ===\n', sprintf(fmt, varargin{:}));

log_banner('Starting TOMAR fast-electronics 6 x 6 analysis');
log_info('Run: %s', run_name);
log_info('Run order: %d', run_order);
if ~isempty(run_comment), log_info('Comment: %s', run_comment); end
log_info('Scintillator mode: %s', scint_mode);
log_info('Input: %s', mat_file);
if archived_file_count > 0
    log_info('Archived %d files from the previous execution in: %s', archived_file_count, fullfile(output_dir, 'LAST'));
else
    log_info('No previous output files to archive in: %s', output_dir);
end
log_info('Fast channels and EBtime event timestamps (when present) will be loaded.');

% ---------------------------------------------------------------------
% File import and validation
% ---------------------------------------------------------------------

load_fields = {'T1_F', 'T1_B', 'TOT1_F', 'TOT1_B', 'EBtime'};
if strcmp(scint_mode, 'alt')
    mapped_fields = unique([alt_scintillator_map.time_field(:); alt_scintillator_map.charge_field(:)])';
    load_fields = [load_fields, mapped_fields];
end
fast = load(mat_file, load_fields{:});
mat_variables = whos('-file', mat_file);
mat_variable_names = {mat_variables.name};
has_thin_strip_data = all(ismember({'Q1_T', 'Q1_B'}, mat_variable_names));
required_fields = {'T1_F', 'T1_B', 'TOT1_F', 'TOT1_B'};
for idx = 1:numel(required_fields)
    if ~isfield(fast, required_fields{idx})
        error('Required fast-electronics variable %s is missing.', required_fields{idx});
    end
end

% Stored matrices are sparse: zero means no edge/ToT was recorded.
t_f = full(double(fast.T1_F));       t_b = full(double(fast.T1_B));
q_f = full(double(fast.TOT1_F));     q_b = full(double(fast.TOT1_B));
expected_size = [size(t_f, 1), 6];
all_matrices = {t_f, t_b, q_f, q_b};
all_names = {'T1_F', 'T1_B', 'TOT1_F', 'TOT1_B'};
for idx = 1:numel(all_matrices)
    if ~isequal(size(all_matrices{idx}), expected_size)
        error('%s has size [%s]; expected [%d 6].', all_names{idx}, ...
            num2str(size(all_matrices{idx})), expected_size(1));
    end
end

n_events = size(t_f, 1);
has_event_time = isfield(fast, 'EBtime');
event_time_seconds = [];
event_time_days = [];
if has_event_time
    event_time_days = double(fast.EBtime(:));
    if numel(event_time_days) ~= n_events || any(~isfinite(event_time_days))
        error('EBtime must contain one finite absolute timestamp for every event.');
    end
    event_time_seconds = (event_time_days - min(event_time_days)) * 86400;
else
    log_info('EBtime is absent: Poisson count and waiting-time tests will be skipped.');
end

alt_scintillator_data = empty_alt_scintillator_data(n_events);
if strcmp(scint_mode, 'alt')
    alt_scintillator_data = build_alt_scintillator_data(fast, alt_scintillator_map, n_events, tot_max_ns);
    % Keep the established channel-6 visual panels useful: display the
    % first mapped PMT of scintillator 1 as Front 6 and scintillator 2 as
    % Back 6.  Filtering below still uses every mapped PMT channel.
    t_f(:, 6) = alt_scintillator_data.t_1(:, 1);
    q_f(:, 6) = alt_scintillator_data.q_1(:, 1);
    t_b(:, 6) = alt_scintillator_data.t_2(:, 1);
    q_b(:, 6) = alt_scintillator_data.q_2(:, 1);
end
channels = (1:6)';
hit_F = t_f ~= 0;   hit_B = t_b ~= 0;
valid_tot_F = hit_F & q_f > 0 & q_f < tot_max_ns;
valid_tot_B = hit_B & q_b > 0 & q_b < tot_max_ns;
log_info('Events: %d | Front hits: %d | Back hits: %d', ...
    n_events, nnz(hit_F), nnz(hit_B));
log_info('Loaded five-channel offsets from %s', calibration_file);
has_scintillator_data = any(hit_F(:, 6) | hit_B(:, 6));
if scint_required
    if strcmp(scint_mode, 'alt')
        log_info('Dedicated PMT channels are used for scintillator 1 and scintillator 2.');
    else
        log_info('Channel 6 is treated as scintillator 1 and scintillator 2.');
    end
    if ~has_scintillator_data
        log_info('Configured scintillator run has no channel-6 hits in this file.');
    end
end

% The only q calibrations: raw q_f/q_b become q_f_cal/q_b_cal. Channel 6
% remains at zero offset because this run has five active channels per side.
q_f_cal = q_f - repmat(qf_offset, n_events, 1);
q_b_cal = q_b - repmat(qb_offset, n_events, 1);

% ---------------------------------------------------------------------
% Fast-electronics summary (six front + six back channels only)
% ---------------------------------------------------------------------

% Numeric column order:
% channel, hit_count, hit_fraction_percent, valid_tot_count,
% invalid_tot_count, leading_time_median_ns, tot_median_ns, tot_std_ns
front_summary = make_channel_summary(channels, hit_F, t_f, q_f_cal, valid_tot_F, n_events);
back_summary = make_channel_summary(channels, hit_B, t_b, q_b_cal, valid_tot_B, n_events);
front_back_coincidences = double(hit_F') * double(hit_B);

% Same-channel semi-sums and semi-differences. t_dif is raw, while the only
% time-difference calibration produces t_dif_cal from t_dif.
rpc_time_pair = false(n_events, 6);
rpc_charge_pair = false(n_events, 6);
rpc_time_pair(:, 1:5) = hit_F(:, 1:5) & hit_B(:, 1:5);
rpc_charge_pair(:, 1:5) = valid_tot_F(:, 1:5) & valid_tot_B(:, 1:5);
t_dif = NaN(n_events, 6); t_dif_cal = NaN(n_events, 6); t_sum = NaN(n_events, 6);
q_dif = NaN(n_events, 6); q_dif_cal = NaN(n_events, 6); q_sum = NaN(n_events, 6);
tdif_offset_matrix = repmat(tdif_offset, n_events, 1);
q_dif_offset_matrix = repmat(q_dif_offset, n_events, 1);
t_dif(rpc_time_pair) = (t_f(rpc_time_pair) - t_b(rpc_time_pair)) / 2;
t_dif_cal(rpc_time_pair) = t_dif(rpc_time_pair) - tdif_offset_matrix(rpc_time_pair);
t_sum(rpc_time_pair) = (t_f(rpc_time_pair) + t_b(rpc_time_pair)) / 2;
q_dif(rpc_charge_pair) = (q_f_cal(rpc_charge_pair) - q_b_cal(rpc_charge_pair)) / 2;
q_dif_cal(rpc_charge_pair) = q_dif(rpc_charge_pair) - q_dif_offset_matrix(rpc_charge_pair);
q_sum(rpc_charge_pair) = (q_f_cal(rpc_charge_pair) + q_b_cal(rpc_charge_pair)) / 2;

% Event charge across the five physical strips. Channel 6 is excluded.
% q_max_event identifies the dominant strip, while q_sum_event retains all
% simultaneously hit strips.
[q_max_event, q_sum_event] = event_max_and_sum(q_sum(:, 1:5));
strip_multiplicity = sum(q_sum(:, 1:5) > special_parameters.min_charge_to_say_activated_strip, 2);
streamer_event = isfinite(q_sum_event) & q_sum_event > special_parameters.streamer_charge_threshold;
streamer_count = sum(streamer_event);
streamer_fraction = streamer_count / n_events;
filter_pass = event_filter_mask(q_f, q_b, q_f_cal, q_b_cal, t_f, t_b, ...
    q_sum, q_dif, q_dif_cal, t_dif, t_dif_cal, t_sum, hit_F, hit_B, ...
    valid_tot_F, valid_tot_B, q_max_event, q_sum_event, filter_limits, scint_filter_limits, scint_mode, alt_scintillator_data);
q_sum_filtered = q_sum_event;
q_sum_filtered(~filter_pass) = NaN;
q_max_filtered = q_max_event;
q_max_filtered(~filter_pass) = NaN;
% Report both the unconditioned RPC efficiency and the efficiency for the
% particle sample selected by the two scintillator-charge cuts.  The latter
% has the scintillator-selected events as its denominator; its numerator
% additionally requires q_sum_event to be inside the RPC q_event limits.
[q_sum_efficiency, q_sum_efficiency_uncertainty, q_sum_good_count] = calculate_q_sum_efficiency(q_sum_event, filter_limits.q_event, n_events);
scintillator_charge_pass = scintillator_charge_filter_mask(q_f, q_b, valid_tot_F, valid_tot_B, scint_filter_limits, scint_mode, alt_scintillator_data);
scintillator_selected_count = sum(scintillator_charge_pass);
[q_sum_scintillator_efficiency, q_sum_scintillator_efficiency_uncertainty, q_sum_scintillator_good_count] = ...
    calculate_q_sum_efficiency(q_sum_event(scintillator_charge_pass), filter_limits.q_event, scintillator_selected_count);
poisson_window_seconds = NaN; poisson_rate_hz = NaN; poisson_counts = [];
grouped_waiting_times = []; grouped_waiting_time_count = 0;
if has_event_time
    [poisson_window_seconds, poisson_rate_hz, poisson_counts] = poisson_arrival_counts(event_time_seconds, special_parameters.poisson_target_counts_per_window);
    [grouped_waiting_times, grouped_waiting_time_count] = grouped_event_waiting_times(event_time_seconds, special_parameters.poisson_waiting_particles);
    log_info('Poisson test: %.4g Hz; using %.6g s windows (target %.6g counts/window).', ...
        poisson_rate_hz, poisson_window_seconds, special_parameters.poisson_target_counts_per_window);
    log_info('Waiting-time test: using non-overlapping intervals for %d arrivals (%d intervals).', ...
        special_parameters.poisson_waiting_particles, grouped_waiting_time_count);
end
same_channel_dt = t_dif_cal;
pair_summary = [channels, sum(~isnan(same_channel_dt), 1)', ...
    column_median(same_channel_dt)', column_std(same_channel_dt)'];

summary_csv = fullfile(output_dir, [run_name '_fast_6x6_channel_summary.csv']);
pair_csv = fullfile(output_dir, [run_name '_fast_6x6_same_channel_dt.csv']);
coincidence_csv = fullfile(output_dir, [run_name '_fast_6x6_front_back_coincidences.csv']);
efficiency_csv = fullfile(output_dir, [run_name '_q_sum_efficiency.csv']);
charge_histogram_csv = fullfile(output_dir, [run_name '_q_sum_charge_histogram.csv']);
event_time_window_csv = fullfile(output_dir, [run_name '_event_time_window.csv']);
write_channel_summary_csv(summary_csv, front_summary, back_summary);
write_numeric_csv(pair_csv, 'channel,front_back_pairs,tdif_median_ns,tdif_std_ns', pair_summary);
write_numeric_csv(coincidence_csv, 'front_channel_rows_back_channel_columns', front_back_coincidences);
write_numeric_csv(efficiency_csv, ['total_original_rows,good_q_sum_rows,efficiency_fraction,efficiency_uncertainty_fraction,' ...
    'efficiency_percent,efficiency_uncertainty_percent,scintillator_selected_rows,scintillator_selected_good_q_sum_rows,' ...
    'scintillator_conditioned_efficiency_fraction,scintillator_conditioned_efficiency_uncertainty_fraction,' ...
    'scintillator_conditioned_efficiency_percent,scintillator_conditioned_efficiency_uncertainty_percent,left_limit,right_limit'], ...
    [n_events, q_sum_good_count, q_sum_efficiency, q_sum_efficiency_uncertainty, 100 * q_sum_efficiency, 100 * q_sum_efficiency_uncertainty, ...
    scintillator_selected_count, q_sum_scintillator_good_count, q_sum_scintillator_efficiency, q_sum_scintillator_efficiency_uncertainty, ...
    100 * q_sum_scintillator_efficiency, 100 * q_sum_scintillator_efficiency_uncertainty, filter_limits.q_event]);
write_charge_histogram_csv(charge_histogram_csv, q_sum_event, histogram_limits.q_event, special_parameters.scan_charge_histogram_bin_width);
write_event_time_window_csv(event_time_window_csv, event_time_days);
log_info('q_sum efficiency (all events): %d / %d = %.4f +/- %.4f%% within [%.6g, %.6g].', ...
    q_sum_good_count, n_events, 100 * q_sum_efficiency, 100 * q_sum_efficiency_uncertainty, filter_limits.q_event(1), filter_limits.q_event(2));
log_info('q_sum efficiency (scintillator-charge selected): %d / %d = %.4f +/- %.4f%%.', ...
    q_sum_scintillator_good_count, scintillator_selected_count, 100 * q_sum_scintillator_efficiency, 100 * q_sum_scintillator_efficiency_uncertainty);
log_info('Streamer fraction (q_sum_event > %.6g): %d / %d = %.4f%%.', ...
    special_parameters.streamer_charge_threshold, streamer_count, n_events, 100 * streamer_fraction);

results_mat = fullfile(output_dir, [run_name '_fast_6x6_results.mat']);
save('-mat7-binary', results_mat, 'front_summary', 'back_summary', 'pair_summary', ...
    'front_back_coincidences', 'q_f', 'q_b', 'q_f_cal', 'q_b_cal', 't_f', 't_b', ...
    'q_sum', 'q_dif', 'q_dif_cal', 'q_max_event', 'q_sum_event', 'strip_multiplicity', 'streamer_event', 'streamer_count', 'streamer_fraction', 't_dif', 't_dif_cal', 't_sum', 'qf_offset', ...
    'qb_offset', 'tdif_offset', 'q_dif_offset', 'histogram_limits', 'filter_limits', 'special_parameters', 'plot_list', 'run_name', 'run_comment', 'run_order', 'scint_required', 'scint_mode', 'alt_scintillator_map', 'alt_scintillator_data', ...
    'filter_pass', 'q_sum_filtered', 'q_max_filtered', 'q_sum_efficiency', 'q_sum_efficiency_uncertainty', 'q_sum_good_count', 'scintillator_charge_pass', 'scintillator_selected_count', 'q_sum_scintillator_efficiency', 'q_sum_scintillator_efficiency_uncertainty', 'q_sum_scintillator_good_count', 'has_event_time', 'event_time_seconds', 'poisson_window_seconds', 'poisson_rate_hz', 'poisson_counts', ...
    'grouped_waiting_times', 'grouped_waiting_time_count', 'tot_max_ns', 'mat_file');
log_info('Saved summaries in %s', output_dir);

% Q1_T/Q1_B are large sampled-waveform arrays. Analyze them after the fast
% result has been saved so they are never retained in the main result MAT.
thin_strip_summary = struct('available', false);
if has_thin_strip_data
    log_info('Q1_T and Q1_B found: starting thin-strip pulse analysis.');
    thin_strip_summary = analyze_thin_strips(mat_file, output_dir, should_plot, save_plots, run_name);
else
    log_info('Q1_T/Q1_B are absent: thin-strip pulse analysis skipped.');
end

% ---------------------------------------------------------------------
% Plots
% ---------------------------------------------------------------------

if should_plot
    channel_histogram_specs = { ...
        'q_f',       q_f,       valid_tot_F, 'q_f = raw front ToT [ns]',    histogram_limits.q_f,       filter_limits.q_f,       false; ...
        'q_b',       q_b,       valid_tot_B, 'q_b = raw back ToT [ns]',     histogram_limits.q_b,       filter_limits.q_b,       false; ...
        'q_f_cal',   q_f_cal,   valid_tot_F, 'q_f_cal [ns]',                 histogram_limits.q_f_cal,   filter_limits.q_f_cal,   false; ...
        'q_b_cal',   q_b_cal,   valid_tot_B, 'q_b_cal [ns]',                 histogram_limits.q_b_cal,   filter_limits.q_b_cal,   false; ...
        't_f',       t_f,       hit_F,       't_f = front leading time [ns]', histogram_limits.t_f,      filter_limits.t_f,       false; ...
        't_b',       t_b,       hit_B,       't_b = back leading time [ns]',  histogram_limits.t_b,      filter_limits.t_b,       false; ...
        't_dif',     t_dif,     rpc_time_pair,   't_dif = (t_f - t_b) / 2 [ns]', histogram_limits.t_dif,     filter_limits.t_dif,     false; ...
        't_dif_cal', t_dif_cal, rpc_time_pair,   't_dif_cal [ns]',               histogram_limits.t_dif_cal, filter_limits.t_dif_cal, false; ...
        't_sum',     t_sum,     rpc_time_pair,   't_sum = (t_f + t_b) / 2 [ns]', histogram_limits.t_sum,     filter_limits.t_sum,     false; ...
        'q_dif',     q_dif,     rpc_charge_pair, 'q_dif = (q_f - q_b) / 2 [ns]', histogram_limits.q_dif,     filter_limits.q_dif,     true; ...
        'q_dif_cal', q_dif_cal, rpc_charge_pair, 'q_dif_cal [ns]',               histogram_limits.q_dif_cal, filter_limits.q_dif_cal, true; ...
        'q_sum',     q_sum,     rpc_charge_pair, 'q_sum = (q_f + q_b) / 2 [ns]', histogram_limits.q_sum,     filter_limits.q_sum,     false ...
    };
    if plot_list.all_channel_histograms
        log_info('Generating combined channel histograms (72 panels)...');
        make_and_save_all_channel_histograms(channel_histogram_specs, scint_histogram_limits, scint_filter_limits, scint_required, output_dir, ...
            [run_name '_all_channel_histograms.png'], save_plots);
    end

    if strcmp(scint_mode, 'alt') && plot_list.alt_scintillator_pmt_histograms
        log_info('Generating dedicated scintillator PMT histograms...');
        make_and_save_alt_scintillator_pmt_histograms(alt_scintillator_data, scint_histogram_limits, scint_filter_limits, ...
            output_dir, [run_name '_alt_scintillator_pmt_histograms.png'], save_plots);
    end

    % 2D map: each of the five active channels occupies a non-overlapping
    % normalized Y interval of width 1/5. Channel 6 is intentionally absent.
    if plot_list.t_dif_cal_vs_y_2d
        log_info('Generating t_dif_cal versus Y map...');
        make_and_save_tdif_cal_y_map(t_dif_cal, rpc_time_pair, histogram_limits.t_dif_cal, filter_limits.t_dif_cal, ...
            output_dir, [run_name '_t_dif_cal_vs_y_2d.png'], save_plots);
    end

    if plot_list.q_max_vs_q_sum_per_event
        log_info('Generating q_max versus q_sum comparison...');
        make_and_save_event_charge_comparison(q_max_event, q_sum_event, q_sum_filtered, q_max_filtered, histogram_limits.q_event, filter_limits.q_event, ...
            output_dir, [run_name '_q_max_vs_q_sum_per_event.png'], save_plots);
    end

    if plot_list.q_sum_efficiency
        log_info('Generating q_sum efficiency plot...');
        make_and_save_q_sum_efficiency_plot(q_sum_event, n_events, q_sum_good_count, q_sum_efficiency, q_sum_efficiency_uncertainty, ...
            scintillator_selected_count, q_sum_scintillator_good_count, q_sum_scintillator_efficiency, q_sum_scintillator_efficiency_uncertainty, ...
            filter_limits.q_event, output_dir, [run_name '_q_sum_efficiency.png'], save_plots);
    end

    if plot_list.q_sum_filtered_vs_t_dif_cal_scatter
        log_info('Generating q_sum_filtered versus t_dif_cal scatter plot...');
        make_and_save_q_sum_filtered_tdifcal_scatter(q_sum_filtered, t_dif_cal, ...
            output_dir, [run_name '_q_sum_filtered_vs_t_dif_cal_scatter.png'], save_plots);
    end

    if plot_list.q_sum_by_multiplicity
        log_info('Generating q_sum histograms by strip multiplicity...');
        make_and_save_q_sum_by_multiplicity(q_max_event, q_sum_event, q_max_filtered, q_sum_filtered, strip_multiplicity, ...
            special_parameters.min_charge_to_say_activated_strip, histogram_limits.q_event, filter_limits.q_event, ...
            output_dir, [run_name '_q_sum_by_multiplicity.png'], save_plots);
    end

    if plot_list.poisson_arrival_test && has_event_time
        log_info('Generating Poisson event-arrival test...');
        make_and_save_poisson_arrival_test(poisson_counts, poisson_window_seconds, poisson_rate_hz, ...
            output_dir, [run_name '_poisson_arrival_test.png'], save_plots);
    end

    if plot_list.poisson_waiting_time_test && has_event_time
        log_info('Generating Poisson waiting-time test...');
        make_and_save_poisson_waiting_time_test(grouped_waiting_times, special_parameters.poisson_waiting_particles, poisson_rate_hz, ...
            output_dir, [run_name '_poisson_waiting_time_test.png'], save_plots);
    end

    if plot_list.q_sum_split_t_dif_cal_vs_y
        log_info('Generating q_sum split t_dif_cal versus Y figure...');
        make_and_save_charge_position_split_figure(q_max_event, q_sum_event, q_sum_filtered, q_max_filtered, ...
            t_dif_cal, rpc_time_pair, histogram_limits, filter_limits, special_parameters.q_separator, ...
            plot_list.q_sum_split_t_dif_cal_vs_y_specific, ...
            output_dir, [run_name '_q_sum_split_t_dif_cal_vs_y.png'], save_plots);
    end

    if plot_list.total_charge_streamer_spectrum
        log_info('Generating total-charge streamer spectrum...');
        make_and_save_total_charge_streamer_spectrum(q_sum_event, n_events, special_parameters.streamer_charge_threshold, ...
            output_dir, [run_name '_total_charge_streamer_spectrum.png'], save_plots);
    end

    if plot_list.streamer_t_dif_cal_vs_y
        log_info('Generating streamer split t_dif_cal versus Y maps...');
        make_and_save_streamer_position_maps(t_dif_cal, rpc_time_pair, streamer_event, ...
            special_parameters.streamer_charge_threshold, histogram_limits.t_dif_cal, filter_limits.t_dif_cal, ...
            output_dir, [run_name '_streamer_t_dif_cal_vs_y.png'], save_plots);
    end

    if plot_list.charge_statistics_t_dif_cal_vs_y
        log_info('Generating mean and median charge position maps...');
        make_and_save_charge_statistics_position_maps(q_sum_event, t_dif_cal, rpc_time_pair, ...
            histogram_limits.t_dif_cal, filter_limits.t_dif_cal, ...
            output_dir, [run_name '_charge_statistics_t_dif_cal_vs_y.png'], save_plots);
    end

end

log_banner('Completed TOMAR fast-electronics 6 x 6 analysis');

end

% ---------------------------------------------------------------------
% Local helpers
% ---------------------------------------------------------------------

function summary = make_channel_summary(channels, hit, time, tot, valid_tot, n_events)
    n_channels = numel(channels);
    summary = NaN(n_channels, 8);
    for channel_idx = 1:n_channels
        hit_count = sum(hit(:, channel_idx));
        values_time = time(hit(:, channel_idx), channel_idx);
        values_tot = tot(valid_tot(:, channel_idx), channel_idx);
        summary(channel_idx, 1:5) = [channels(channel_idx), hit_count, ...
            100 * hit_count / n_events, sum(valid_tot(:, channel_idx)), ...
            hit_count - sum(valid_tot(:, channel_idx))];
        if ~isempty(values_time), summary(channel_idx, 6) = median(values_time); end
        if ~isempty(values_tot)
            summary(channel_idx, 7) = median(values_tot);
            summary(channel_idx, 8) = std(values_tot);
        end
    end
end

function values = column_median(data)
    values = NaN(1, columns(data));
    for idx = 1:columns(data)
        data_column = data(:, idx); data_column = data_column(~isnan(data_column));
        if ~isempty(data_column), values(idx) = median(data_column); end
    end
end

function values = column_std(data)
    values = NaN(1, columns(data));
    for idx = 1:columns(data)
        data_column = data(:, idx); data_column = data_column(~isnan(data_column));
        if ~isempty(data_column), values(idx) = std(data_column); end
    end
end

function make_and_save_all_channel_histograms(specs, scint_histogram_limits, scint_filter_limits, scint_required, output_dir, file_name, save_plots)
    n_rows = rows(specs);
    % This 72-panel diagnostic is deliberately compact: at the former
    % canvas size it dominated the run time when gnuplot rasterized it.
    fig = figure('Color', 'w', 'Position', [20 20 1800 3000]);
    axes_handles = zeros(n_rows, 6);
    for row = 1:n_rows
        quantity_name = specs{row, 1}; data = specs{row, 2}; mask = specs{row, 3}; x_label = specs{row, 4};
        x_limits = specs{row, 5}; filter_bounds = specs{row, 6}; show_median = specs{row, 7};
        for channel = 1:6
            subplot(n_rows, 6, (row - 1) * 6 + channel);
            axes_handles(row, channel) = gca();
            scint_quantity = scintillator_quantity_name(quantity_name);
            if channel == 6 && scint_required && ~isempty(scint_quantity)
                x_limits = scint_histogram_limits.(scint_quantity);
                filter_bounds = scint_filter_limits.(scint_quantity);
            else
                x_limits = specs{row, 5};
                filter_bounds = specs{row, 6};
            end
            channel_label = channel_display_label(quantity_name, channel, scint_required);
            plot_one_channel_histogram(data, mask, channel, channel_label, x_label, x_limits, filter_bounds, show_median);
        end
    end
    % Subplot can reflow earlier axes while later ones are created.  Move all
    % axes only after the complete grid exists, so the panels fill the page.
    for row = 1:n_rows
        for channel = 1:6
            set(axes_handles(row, channel), 'Position', tight_grid_position(n_rows, 6, row, channel));
        end
    end
    save_figure_if_requested(fig, output_dir, file_name, save_plots);
end

function position = tight_grid_position(n_rows, n_columns, row, column)
    left = 0.052; right = 0.012; bottom = 0.025; top = 0.012;
    horizontal_gap = 0.016; vertical_gap = 0.028;
    width = (1 - left - right - (n_columns - 1) * horizontal_gap) / n_columns;
    height = (1 - bottom - top - (n_rows - 1) * vertical_gap) / n_rows;
    x = left + (column - 1) * (width + horizontal_gap);
    y = 1 - top - row * height - (row - 1) * vertical_gap;
    position = [x, y, width, height];
end

function plot_one_channel_histogram(data, mask, channel, channel_label, x_label, x_limits, filter_bounds, show_median)
    values = data(mask(:, channel), channel);
    values = filter_histogram_values(values, x_limits);
    if isempty(values)
        text(0.5, 0.5, 'No values in range', 'HorizontalAlignment', 'center'); axis off;
    else
        % Filled bins retain the visual weight of a histogram while the
        % darker outline keeps individual bins distinguishable.
        [counts, centers] = hist(values, 80);
        bar(centers, counts, 1.0, 'FaceColor', [0.72 0.87 1.00], ...
            'EdgeColor', [0.00 0.35 0.85], 'LineWidth', 0.55);
        grid off;
        xlabel(x_label); ylabel('Entries');
        apply_x_limits(x_limits);
        draw_filter_limit_lines(filter_bounds);
    end
    if show_median && ~isempty(values)
        title(sprintf('%s (N = %d)\nMedian = %.3f ns', channel_label, numel(values), median(values)));
    else
        title(sprintf('%s (N = %d)', channel_label, numel(values)));
    end
end

function make_and_save_alt_scintillator_pmt_histograms(scint_data, histogram_limits, filter_limits, output_dir, file_name, save_plots)
    q_data = [scint_data.q_1, scint_data.q_2];
    t_data = [scint_data.t_1, scint_data.t_2];
    q_mask = [scint_data.q_1_recorded, scint_data.q_2_recorded];
    t_mask = [scint_data.t_1_recorded, scint_data.t_2_recorded];
    scintillator_id = [ones(1, columns(scint_data.q_1)), 2 * ones(1, columns(scint_data.q_2))];
    n_pmts = columns(q_data);
    fig = figure('Color', 'w', 'Position', [80 80 max(900, 310 * n_pmts) 600]);
    pmt_number = [0, 0];
    for pmt = 1:n_pmts
        scintillator = scintillator_id(pmt);
        pmt_number(scintillator) = pmt_number(scintillator) + 1;
        q_name = sprintf('q_%d', scintillator); t_name = sprintf('t_%d', scintillator);
        label = sprintf('Scint. %d PMT %d', scintillator, pmt_number(scintillator));
        subplot(2, n_pmts, pmt);
        plot_one_channel_histogram(q_data, q_mask, pmt, label, 'PMT ToT [ns]', ...
            histogram_limits.(q_name), filter_limits.(q_name), false);
        subplot(2, n_pmts, n_pmts + pmt);
        plot_one_channel_histogram(t_data, t_mask, pmt, label, 'PMT leading time [ns]', ...
            histogram_limits.(t_name), filter_limits.(t_name), false);
    end
    save_figure_if_requested(fig, output_dir, file_name, save_plots);
end

function label = channel_display_label(quantity_name, channel, scint_required)
    if channel ~= 6
        label = sprintf('Ch. %d', channel);
    elseif ~scint_required
        label = 'Not used';
    elseif any(strcmp(quantity_name, {'q_f', 'q_f_cal', 't_f'}))
        label = 'Scint. 1';
    elseif any(strcmp(quantity_name, {'q_b', 'q_b_cal', 't_b'}))
        label = 'Scint. 2';
    else
        label = 'Not used';
    end
end

function scint_quantity = scintillator_quantity_name(quantity_name)
    switch quantity_name
        case 'q_f', scint_quantity = 'q_1';
        case 'q_b', scint_quantity = 'q_2';
        case 'q_f_cal', scint_quantity = 'q_1_cal';
        case 'q_b_cal', scint_quantity = 'q_2_cal';
        case 't_f', scint_quantity = 't_1';
        case 't_b', scint_quantity = 't_2';
        otherwise, scint_quantity = '';
    end
end

function plot_six_by_two(front_data, back_data, front_mask, back_mask, x_label, overall_title, x_limits)
    for side_idx = 1:2
        if side_idx == 1
            data = front_data; mask = front_mask; side_name = 'Front';
        else
            data = back_data; mask = back_mask; side_name = 'Back';
        end
        for ch = 1:6
            subplot(2, 6, (side_idx - 1) * 6 + ch);
            values = data(mask(:, ch), ch);
            values = filter_histogram_values(values, x_limits);
            if isempty(values)
                text(0.5, 0.5, 'No values in range', 'HorizontalAlignment', 'center'); axis off;
            else
                hist(values, 80); grid on;
                xlabel(x_label); ylabel('Entries');
                apply_x_limits(x_limits);
            end
            title(sprintf('%s ch. %d (N = %d)', side_name, ch, numel(values)));
        end
    end
    % Kept as an argument for readable calling code; subplot titles carry
    % the side, channel, and event count without overlapping a global title.
end

function plot_six_by_one(data, mask, x_label, overall_title, x_limits, show_median, filter_bounds)
    if nargin < 6, show_median = false; end
    if nargin < 7, filter_bounds = [NaN, NaN]; end
    for ch = 1:6
        subplot(1, 6, ch);
        values = data(mask(:, ch), ch);
        values = filter_histogram_values(values, x_limits);
        if isempty(values)
            text(0.5, 0.5, 'No values in range', 'HorizontalAlignment', 'center'); axis off;
        else
            hist(values, 80); grid on;
                xlabel(x_label); ylabel('Entries');
                apply_x_limits(x_limits);
                draw_filter_limit_lines(filter_bounds);
        end
        if show_median && ~isempty(values)
            title(sprintf('Channel %d (N = %d)\nMedian = %.3f ns', ch, numel(values), median(values)));
        else
            title(sprintf('Channel %d (N = %d)', ch, numel(values)));
        end
    end
    % Kept as an argument for readable calling code; channel titles are used
    % instead of an overlapping global title in Octave's gnuplot backend.
end

function make_and_save_six_histograms(data, mask, x_label, x_limits, filter_bounds, output_dir, file_name, save_plots)
    fig = figure('Color', 'w', 'Position', [30 80 1500 360]);
    plot_six_by_one(data, mask, x_label, file_name, x_limits, false, filter_bounds);
    save_figure_if_requested(fig, output_dir, file_name, save_plots);
end

function make_and_save_tdif_cal_y_map(t_dif_cal, time_pair, x_limits, filter_bounds, output_dir, file_name, save_plots)
    fig = figure('Color', 'w', 'Position', [120 120 950 600]);
    plot_tdif_cal_y_map(t_dif_cal, time_pair, true(rows(t_dif_cal), 1), ...
        x_limits, filter_bounds, '2D histogram: t_dif_cal versus Y');
    save_figure_if_requested(fig, output_dir, file_name, save_plots);
end

function plot_tdif_cal_y_map(t_dif_cal, time_pair, event_selection, x_limits, filter_bounds, plot_title)
    n_x_bins = 80;
    n_channels = 5;
    tdif_values = [];
    channel_index = [];
    for channel = 1:n_channels
        values = t_dif_cal(time_pair(:, channel) & event_selection, channel);
        values = filter_histogram_values(values, x_limits);
        tdif_values = [tdif_values; values]; %#ok<AGROW>
        channel_index = [channel_index; channel * ones(numel(values), 1)]; %#ok<AGROW>
    end

    if isempty(tdif_values)
        text(0.5, 0.5, 'No t_dif_cal values in the configured range', ...
            'HorizontalAlignment', 'center');
        axis off;
    else
        if numel(x_limits) == 2 && all(isfinite(x_limits)) && x_limits(1) < x_limits(2)
            x_edges = linspace(x_limits(1), x_limits(2), n_x_bins + 1);
        else
            x_min = min(tdif_values); x_max = max(tdif_values);
            if x_min == x_max
                x_min = x_min - 0.5; x_max = x_max + 0.5;
            end
            x_edges = linspace(x_min, x_max, n_x_bins + 1);
        end
        [~, x_bin] = histc(tdif_values, x_edges);
        x_bin(x_bin == n_x_bins + 1) = n_x_bins;
        valid = x_bin >= 1 & x_bin <= n_x_bins;
        counts = accumarray([channel_index(valid), x_bin(valid)], 1, [n_channels, n_x_bins], @sum, 0);
        x_centers = (x_edges(1:end-1) + x_edges(2:end)) / 2;
        y_centers = ((1:n_channels) - 0.5) / n_channels;
        imagesc(x_centers, y_centers, counts);
        set(gca, 'YDir', 'normal', 'YTick', y_centers, ...
            'YTickLabel', {'Ch. 1', 'Ch. 2', 'Ch. 3', 'Ch. 4', 'Ch. 5'});
        xlabel('t_dif_cal [ns]');
        ylabel('Normalized Y (five non-overlapping strips)');
        title(plot_title);
        draw_filter_limit_lines(filter_bounds);
        colorbar;
    end
end

function [q_max_event, q_sum_event] = event_max_and_sum(q_sum_active)
    n_events = rows(q_sum_active);
    q_max_event = NaN(n_events, 1);
    q_sum_event = NaN(n_events, 1);
    for event = 1:n_events
        values = q_sum_active(event, :);
        values = values(isfinite(values));
        if ~isempty(values)
            q_max_event(event) = max(values);
            q_sum_event(event) = sum(values);
        end
    end
end

function write_event_time_window_csv(file_name, event_time_days)
    % Store exact absolute event bounds when the input MAT provides EBtime.
    % The scan script reads this small sidecar instead of reopening large MATs.
    fid = fopen(file_name, 'w');
    if fid < 0, error('Could not write event-time window CSV: %s', file_name); end
    fprintf(fid, 'event_time_available,first_event_datenum,last_event_datenum\n');
    if isempty(event_time_days)
        fprintf(fid, 'false,,\n');
    else
        fprintf(fid, 'true,%.15g,%.15g\n', min(event_time_days), max(event_time_days));
    end
    fclose(fid);
end

function [efficiency, uncertainty, good_count] = calculate_q_sum_efficiency(q_sum_event, bounds, total_rows)
    if numel(bounds) ~= 2 || ~all(isfinite(bounds)) || bounds(1) >= bounds(2)
        error('filter_limits.csv requires finite q_event left and right limits with left < right for q_sum efficiency.');
    end
    good_count = sum(isfinite(q_sum_event) & q_sum_event >= bounds(1) & q_sum_event <= bounds(2));
    if total_rows == 0
        efficiency = NaN;
        uncertainty = NaN;
        return;
    end
    efficiency = good_count / total_rows;
    if good_count > 0
        % For epsilon = N_good / N_total, with independent Poisson
        % uncertainties sigma_good=sqrt(N_good), sigma_total=sqrt(N_total):
        % sigma_epsilon^2 = (d epsilon/d N_good)^2 sigma_good^2 +
        %                     (d epsilon/d N_total)^2 sigma_total^2.
        uncertainty = sqrt(good_count / total_rows^2 + good_count^2 / total_rows^3);
    else
        uncertainty = NaN;
    end
end

function write_charge_histogram_csv(file_name, values, bounds, bin_width)
    if numel(bounds) ~= 2 || ~all(isfinite(bounds)) || bounds(1) >= bounds(2)
        error('Histogram q_event limits must be finite with min < max to export the scan charge histogram.');
    end
    edges = bounds(1):bin_width:bounds(2);
    if edges(end) < bounds(2)
        edges = [edges bounds(2)];
    elseif edges(end) > bounds(2)
        edges(end) = bounds(2);
    end
    selected = values(isfinite(values) & values >= bounds(1) & values <= bounds(2));
    centers = edges(1:end-1) + diff(edges) / 2;
    % histcounts is unavailable in the project's GNU Octave version.
    counts = hist(selected, centers);
    write_numeric_csv(file_name, 'Charge_bin_center,Count', [centers(:), counts(:)]);
end

function pass = scintillator_charge_filter_mask(q_f, q_b, valid_q_f, valid_q_b, scint_limits, scint_mode, alt_scintillator_data)
    % Require a recorded charge for each scintillator and require every
    % recorded PMT charge to lie within that scintillator's configured q cut.
    % This intentionally uses q_1/q_2 only: q_1_cal and q_2_cal are separate,
    % optional cuts and are not part of the requested charge denominator.
    n_events = rows(q_f);
    if strcmp(scint_mode, 'legacy')
        pass_1 = scintillator_charge_in_bounds(q_f(:, 6), valid_q_f(:, 6), scint_limits.q_1);
        pass_2 = scintillator_charge_in_bounds(q_b(:, 6), valid_q_b(:, 6), scint_limits.q_2);
    elseif strcmp(scint_mode, 'alt')
        pass_1 = scintillator_charge_in_bounds(alt_scintillator_data.q_1, alt_scintillator_data.q_1_recorded, scint_limits.q_1);
        pass_2 = scintillator_charge_in_bounds(alt_scintillator_data.q_2, alt_scintillator_data.q_2_recorded, scint_limits.q_2);
    else
        % Runs without configured scintillators retain the all-events
        % denominator, so that the conditional result equals the original one.
        pass = true(n_events, 1);
        return;
    end
    pass = pass_1 & pass_2;
end

function pass = scintillator_charge_in_bounds(values, recorded, bounds)
    if numel(bounds) ~= 2 || ~all(isfinite(bounds)) || bounds(1) >= bounds(2)
        error('scint_filter_limits.csv requires finite q_1 and q_2 limits with min < max for scintillator-conditioned efficiency.');
    end
    recorded = recorded & isfinite(values);
    % A scintillator must actually have a charge measurement.  For a
    % multi-PMT scintillator, all recorded PMTs must satisfy its cut.
    has_charge = any(recorded, 2);
    in_bounds = values >= bounds(1) & values <= bounds(2);
    pass = has_charge & all(~recorded | in_bounds, 2);
end

function make_and_save_q_sum_efficiency_plot(q_sum_event, total_rows, good_count, efficiency, uncertainty, ...
        scintillator_total_rows, scintillator_good_count, scintillator_efficiency, scintillator_uncertainty, bounds, output_dir, file_name, save_plots)
    values = q_sum_event(isfinite(q_sum_event));
    fig = figure('Color', 'w', 'Position', [120 120 950 550]);
    if isempty(values)
        text(0.5, 0.5, 'No finite q_sum values', 'HorizontalAlignment', 'center');
        axis off;
    else
        x_edges = linspace(bounds(1), bounds(2), 201);
        in_range_values = values(values >= bounds(1) & values <= bounds(2));
        counts = hist(in_range_values, (x_edges(1:end-1) + x_edges(2:end)) / 2);
        bar((x_edges(1:end-1) + x_edges(2:end)) / 2, counts, 1.0, ...
            'FaceColor', [0.72 0.87 1.00], 'EdgeColor', [0.00 0.35 0.85], 'LineWidth', 0.55);
        grid off; xlabel('Total calibrated event charge q_sum [ns]'); ylabel('Rows in good q_sum range');
        xlim(bounds);
        draw_filter_limit_lines(bounds);
        title({sprintf('q_sum efficiency (all events) = %d / %d = %.4f +/- %.4f%%', good_count, total_rows, 100 * efficiency, 100 * uncertainty), ...
            sprintf('Scintillator-charge selected = %d / %d = %.4f +/- %.4f%%', scintillator_good_count, scintillator_total_rows, 100 * scintillator_efficiency, 100 * scintillator_uncertainty)});
        text(0.03, 0.92, sprintf('Good range: %.6g <= q_sum <= %.6g ns', bounds(1), bounds(2)), ...
            'Units', 'normalized', 'VerticalAlignment', 'top');
    end
    save_figure_if_requested(fig, output_dir, file_name, save_plots);
end

function [window_seconds, rate_hz, counts] = poisson_arrival_counts(event_time_seconds, target_counts)
    duration_seconds = max(event_time_seconds) - min(event_time_seconds);
    if duration_seconds <= 0
        error('EBtime does not span a positive acquisition duration; cannot test event arrivals.');
    end
    rate_hz = numel(event_time_seconds) / duration_seconds;
    % At low rates, one-second bins are mostly empty and do not diagnose a
    % Poisson process well.  Increase the window until it contains roughly
    % the requested number of events on average.
    window_seconds = max(1, ceil(target_counts / rate_hz));
    n_windows = max(1, ceil(duration_seconds / window_seconds));
    bin_index = floor(event_time_seconds / window_seconds) + 1;
    bin_index(bin_index > n_windows) = n_windows;
    counts = accumarray(bin_index, 1, [n_windows, 1], @sum, 0);
end

function [grouped_waiting_times, interval_count] = grouped_event_waiting_times(event_time_seconds, arrivals_per_interval)
    ordered_times = sort(event_time_seconds(:));
    start_indices = 1:arrivals_per_interval:(numel(ordered_times) - arrivals_per_interval);
    grouped_waiting_times = ordered_times(start_indices + arrivals_per_interval) - ordered_times(start_indices);
    grouped_waiting_times = grouped_waiting_times(grouped_waiting_times >= 0);
    interval_count = numel(grouped_waiting_times);
    if interval_count == 0
        error('EBtime has too few timestamps for a %d-arrival waiting-time test.', arrivals_per_interval);
    end
end

function make_and_save_poisson_arrival_test(counts, window_seconds, rate_hz, output_dir, file_name, save_plots)
    lambda = mean(counts);
    fano_factor = var(counts, 1) / lambda;
    max_count = max(counts);
    k = 0:max_count;
    observed = hist(counts, k);
    expected = numel(counts) * exp(-lambda + k .* log(lambda) - gammaln(k + 1));
    [chi_square, degrees_of_freedom, p_value] = poisson_chi_square_test(observed, expected, lambda, numel(counts));

    fig = figure('Color', 'w', 'Position', [120 80 1000 760]);
    subplot(2, 1, 1);
    stairs(k, observed, 'LineWidth', 1.8, 'Color', [0 0.35 0.85]); hold on;
    plot(k, expected, 'o-', 'LineWidth', 1.4, 'MarkerSize', 4, 'Color', [0.85 0.2 0.1]); hold off;
    xlabel('Events per time window'); ylabel('Number of windows'); grid off;
    title(sprintf('Poisson count test: window = %.6g s, mean = %.4g, Fano = %.4g, chi2/%d = %.3g (p = %.3g)', ...
        window_seconds, lambda, fano_factor, degrees_of_freedom, chi_square, p_value));
    legend({'Observed window counts', 'Poisson expectation'}, 'Location', 'northeast');

    subplot(2, 1, 2);
    window_start_seconds = (0:numel(counts)-1)' * window_seconds;
    stairs(window_start_seconds, counts, 'LineWidth', 0.8, 'Color', [0.1 0.6 0.2]); hold on;
    plot([0, window_start_seconds(end) + window_seconds], [lambda, lambda], '--', ...
        'Color', [0.85 0.2 0.1], 'LineWidth', 1.6); hold off;
    xlabel('Elapsed acquisition time [s]'); ylabel('Events per window'); grid off;
    title(sprintf('Arrival rate = %.4g Hz; Poisson arrivals should give Fano factor near 1', rate_hz));
    legend({'Observed count', 'Mean count'}, 'Location', 'northeast');
    save_figure_if_requested(fig, output_dir, file_name, save_plots);
end

function make_and_save_poisson_waiting_time_test(waiting_times, arrivals_per_interval, rate_hz, output_dir, file_name, save_plots)
    mean_waiting_time = mean(waiting_times);
    n_waiting_times = numel(waiting_times);
    max_plot_time = quantile(waiting_times, 0.995);
    if max_plot_time <= 0, max_plot_time = max(waiting_times); end
    n_bins = 80;
    edges = linspace(0, max_plot_time, n_bins + 1);
    centers = (edges(1:end-1) + edges(2:end)) / 2;
    observed = hist(waiting_times(waiting_times <= max_plot_time), centers);
    expected = n_waiting_times * (erlang_cdf(edges(2:end), arrivals_per_interval, rate_hz) - ...
        erlang_cdf(edges(1:end-1), arrivals_per_interval, rate_hz));

    sorted_waiting_times = sort(waiting_times);
    empirical_cdf = (1:n_waiting_times)' / n_waiting_times;
    erlang_model_cdf = erlang_cdf(sorted_waiting_times, arrivals_per_interval, rate_hz);
    ks_distance = max(abs(empirical_cdf - erlang_model_cdf));
    % Simple large-sample KS approximation; this is diagnostic because the
    % rate is estimated from the same timestamp stream.
    ks_p_approx = min(1, 2 * exp(-2 * n_waiting_times * ks_distance^2));

    fig = figure('Color', 'w', 'Position', [120 80 1000 760]);
    subplot(2, 1, 1);
    stairs(centers, observed, 'LineWidth', 1.8, 'Color', [0 0.35 0.85]); hold on;
    plot(centers, expected, 'LineWidth', 1.5, 'Color', [0.85 0.2 0.1]); hold off;
    xlabel(sprintf('Time for %d arrivals [s]', arrivals_per_interval)); ylabel('Intervals'); grid off;
    title(sprintf('%d-arrival waiting-time histogram: mean = %.4g s', arrivals_per_interval, mean_waiting_time));
    legend({'Observed intervals', 'Erlang expectation'}, 'Location', 'northeast');

    subplot(2, 1, 2);
    [unique_waiting_times, ~, unique_index] = unique(sorted_waiting_times);
    multiplicities = accumarray(unique_index, 1);
    survival_empirical = 1 - [0; cumsum(multiplicities(1:end-1))] / n_waiting_times;
    erlang_survival = 1 - erlang_cdf(unique_waiting_times, arrivals_per_interval, rate_hz);
    survival_floor = 0.5 / n_waiting_times;
    erlang_survival(erlang_survival < survival_floor) = NaN;
    % Binomial one-sigma uncertainty for the empirical survival fraction.
    survival_error = sqrt(survival_empirical .* (1 - survival_empirical) / n_waiting_times);
    lower_error = survival_empirical - max(survival_floor, survival_empirical - survival_error);
    upper_error = min(1, survival_empirical + survival_error) - survival_empirical;
    lower_values = survival_empirical - lower_error;
    upper_values = survival_empirical + upper_error;
    error_x = reshape([unique_waiting_times'; unique_waiting_times'; NaN(size(unique_waiting_times'))], [], 1);
    error_y = reshape([lower_values'; upper_values'; NaN(size(unique_waiting_times'))], [], 1);
    observed_handle = semilogy(unique_waiting_times, survival_empirical, 'LineWidth', 1.2, 'Color', [0.1 0.6 0.2]); hold on;
    plot(error_x, error_y, 'Color', [0.1 0.6 0.2], 'LineWidth', 0.55, 'HandleVisibility', 'off');
    model_handle = semilogy(unique_waiting_times, erlang_survival, '--', ...
        'LineWidth', 1.5, 'Color', [0.85 0.2 0.1]); hold off;
    xlabel(sprintf('Time for %d arrivals [s]', arrivals_per_interval)); ylabel('Survival probability'); grid off;
    title(sprintf('Erlang waiting-time test: rate = %.4g Hz, KS D = %.4g (approx. p = %.3g)', ...
        rate_hz, ks_distance, ks_p_approx));
    ylim([survival_floor, 1]);
    legend([observed_handle, model_handle], {'Observed survival (±1σ)', 'Erlang survival'}, 'Location', 'northeast');
    save_figure_if_requested(fig, output_dir, file_name, save_plots);
end

function values = erlang_cdf(times, shape, rate_hz)
    values = zeros(size(times));
    scaled_times = rate_hz * times;
    series_sum = zeros(size(times));
    for order = 0:(shape - 1)
        series_sum = series_sum + scaled_times .^ order / factorial(order);
    end
    values = 1 - exp(-scaled_times) .* series_sum;
    values(values < 0) = 0; values(values > 1) = 1;
end

function [chi_square, degrees_of_freedom, p_value] = poisson_chi_square_test(observed, expected, lambda, n_windows)
    % Combine sparse Poisson tails so every chi-square category has an
    % expected population near or above five windows.
    well_populated = find(expected >= 5);
    if numel(well_populated) < 2
        chi_square = NaN; degrees_of_freedom = 0; p_value = NaN;
        return;
    end
    first = well_populated(1); last = well_populated(end);
    observed_groups = [sum(observed(1:first-1)), observed(first:last), sum(observed(last+1:end))];
    low_expected = sum(expected(1:first-1));
    high_expected = n_windows - sum(expected(1:last));
    expected_groups = [low_expected, expected(first:last), high_expected];
    valid = expected_groups > 0;
    chi_square = sum((observed_groups(valid) - expected_groups(valid)).^2 ./ expected_groups(valid));
    % One degree is lost because lambda is estimated from the same counts.
    degrees_of_freedom = sum(valid) - 2;
    if degrees_of_freedom > 0
        p_value = 1 - gammainc(chi_square / 2, degrees_of_freedom / 2);
    else
        p_value = NaN;
    end
end

function make_and_save_q_sum_by_multiplicity(q_max_event, q_sum_event, q_max_filtered, q_sum_filtered, strip_multiplicity, activation_threshold, x_limits, filter_bounds, output_dir, file_name, save_plots)
    values = [q_max_event(isfinite(q_max_event)); q_sum_event(isfinite(q_sum_event)); ...
        q_max_filtered(isfinite(q_max_filtered)); q_sum_filtered(isfinite(q_sum_filtered))];
    values = filter_histogram_values(values, x_limits);
    fig = figure('Color', 'w', 'Position', [120 50 950 1250]);
    if isempty(values)
        text(0.5, 0.5, 'No q_sum event values in the configured range', 'HorizontalAlignment', 'center');
        axis off;
    else
        n_bins = 200;
        if all(isfinite(x_limits)) && x_limits(1) < x_limits(2)
            x_edges = linspace(x_limits(1), x_limits(2), n_bins + 1);
        else
            x_min = min(values); x_max = max(values);
            if x_min == x_max, x_min = x_min - 0.5; x_max = x_max + 0.5; end
            x_edges = linspace(x_min, x_max, n_bins + 1);
        end
        x_centers = (x_edges(1:end-1) + x_edges(2:end)) / 2;
        labels = {'Blue: maximum strip charge', 'Red: sum of strip charges', ...
            'Green: filtered sum of strip charges', 'Purple: filtered maximum strip charge'};
        for multiplicity = 1:5
            subplot(5, 1, multiplicity);
            selected = strip_multiplicity == multiplicity;
            q_max_plot = filter_histogram_values(q_max_event(selected & isfinite(q_max_event)), x_limits);
            q_sum_plot = filter_histogram_values(q_sum_event(selected & isfinite(q_sum_event)), x_limits);
            q_max_filtered_plot = filter_histogram_values(q_max_filtered(selected & isfinite(q_max_filtered)), x_limits);
            q_sum_filtered_plot = filter_histogram_values(q_sum_filtered(selected & isfinite(q_sum_filtered)), x_limits);
            if isempty(q_max_plot) && isempty(q_sum_plot) && isempty(q_max_filtered_plot) && isempty(q_sum_filtered_plot)
                text(0.5, 0.5, sprintf('Multiplicity %d: no events', multiplicity), ...
                    'HorizontalAlignment', 'center');
                axis off;
            else
                max_counts = hist(q_max_plot, x_centers);
                sum_counts = hist(q_sum_plot, x_centers);
                filtered_counts = hist(q_sum_filtered_plot, x_centers);
                max_filtered_counts = hist(q_max_filtered_plot, x_centers);
                max_plot = max_counts; max_plot(max_plot <= 0) = NaN;
                sum_plot = sum_counts; sum_plot(sum_plot <= 0) = NaN;
                filtered_plot = filtered_counts; filtered_plot(filtered_plot <= 0) = NaN;
                max_filtered_plot = max_filtered_counts; max_filtered_plot(max_filtered_plot <= 0) = NaN;
                stairs(x_centers, max_plot, 'LineWidth', 1.4, 'Color', [0 0.35 0.85]); hold on;
                stairs(x_centers, sum_plot, 'LineWidth', 1.4, 'Color', [0.85 0.2 0.1]);
                stairs(x_centers, filtered_plot, 'LineWidth', 1.4, 'Color', [0.1 0.6 0.2]);
                stairs(x_centers, max_filtered_plot, 'LineWidth', 1.4, 'Color', [0.55 0.2 0.75]); hold off;
                set(gca, 'YScale', 'log');
                positive_counts = [max_counts(max_counts > 0), sum_counts(sum_counts > 0), ...
                    filtered_counts(filtered_counts > 0), max_filtered_counts(max_filtered_counts > 0)];
                ylim([0.5, max(positive_counts) * 1.2]);
                apply_x_limits(x_limits);
                draw_filter_limit_lines(filter_bounds);
                grid off;
                ylabel('Entries');
                title(sprintf('Multiplicity %d: %d events', multiplicity, sum(selected)));
                if multiplicity == 1
                    legend_handle = legend(labels, 'Location', 'northeast');
                    set(legend_handle, 'FontSize', 8);
                end
                if multiplicity == 5
                    xlabel('Total calibrated event charge q_sum [ns]');
                end
            end
        end
        annotation('textbox', [0.12 0.967 0.78 0.025], 'String', ...
            sprintf('q_sum by strip multiplicity (activated when calibrated q_sum > %.6g ns)', activation_threshold), ...
            'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
    end
    save_figure_if_requested(fig, output_dir, file_name, save_plots);
end

function make_and_save_event_charge_comparison(q_max_event, q_sum_event, q_sum_filtered, q_max_filtered, x_limits, filter_bounds, output_dir, file_name, save_plots)
    q_max_plot = filter_histogram_values(q_max_event(isfinite(q_max_event)), x_limits);
    q_sum_plot = filter_histogram_values(q_sum_event(isfinite(q_sum_event)), x_limits);
    q_sum_filtered_plot = filter_histogram_values(q_sum_filtered(isfinite(q_sum_filtered)), x_limits);
    q_max_filtered_plot = filter_histogram_values(q_max_filtered(isfinite(q_max_filtered)), x_limits);
    all_values = [q_max_plot; q_sum_plot; q_sum_filtered_plot; q_max_filtered_plot];
    fig = figure('Color', 'w', 'Position', [120 80 1050 900]);
    if isempty(all_values)
        text(0.5, 0.5, 'No event-charge values in the configured range', ...
            'HorizontalAlignment', 'center');
        axis off;
    else
        n_bins = 200;
        if numel(x_limits) == 2 && all(isfinite(x_limits)) && x_limits(1) < x_limits(2)
            x_edges = linspace(x_limits(1), x_limits(2), n_bins + 1);
        else
            x_min = min(all_values); x_max = max(all_values);
            if x_min == x_max, x_min = x_min - 0.5; x_max = x_max + 0.5; end
            x_edges = linspace(x_min, x_max, n_bins + 1);
        end
        x_centers = (x_edges(1:end-1) + x_edges(2:end)) / 2;
        max_counts = hist(q_max_plot, x_centers);
        sum_counts = hist(q_sum_plot, x_centers);
        filtered_counts = hist(q_sum_filtered_plot, x_centers);
        max_filtered_counts = hist(q_max_filtered_plot, x_centers);
        labels = {'Blue: maximum strip charge', 'Red: sum of strip charges', ...
            'Green: filtered sum of strip charges', 'Purple: filtered maximum strip charge'};

        subplot(2, 1, 1);
        plot_event_charge_histograms(x_centers, max_counts, sum_counts, filtered_counts, max_filtered_counts, ...
            x_limits, filter_bounds, labels, false);
        title('Event charge: maximum strip charge versus sum of strip charges (linear Y)');

        subplot(2, 1, 2);
        plot_event_charge_histograms(x_centers, max_counts, sum_counts, filtered_counts, max_filtered_counts, ...
            x_limits, filter_bounds, labels, true);
        title('Event charge: maximum strip charge versus sum of strip charges (log Y)');
    end
    save_figure_if_requested(fig, output_dir, file_name, save_plots);
end

function plot_event_charge_histograms(x_centers, max_counts, sum_counts, filtered_counts, max_filtered_counts, x_limits, filter_bounds, labels, use_log_y)
    max_plot = max_counts; sum_plot = sum_counts; filtered_plot = filtered_counts; max_filtered_plot = max_filtered_counts;
    if use_log_y
        max_plot(max_plot <= 0) = NaN;
        sum_plot(sum_plot <= 0) = NaN;
        filtered_plot(filtered_plot <= 0) = NaN;
        max_filtered_plot(max_filtered_plot <= 0) = NaN;
    end
    stairs(x_centers, max_plot, 'LineWidth', 1.6, 'Color', [0 0.35 0.85]); hold on;
    stairs(x_centers, sum_plot, 'LineWidth', 1.6, 'Color', [0.85 0.2 0.1]);
    stairs(x_centers, filtered_plot, 'LineWidth', 1.6, 'Color', [0.1 0.6 0.2]);
    stairs(x_centers, max_filtered_plot, 'LineWidth', 1.6, 'Color', [0.55 0.2 0.75]); hold off;
    grid off; xlabel('Calibrated event charge proxy [ns]'); ylabel('Entries');
    apply_x_limits(x_limits);
    if use_log_y
        set(gca, 'YScale', 'log');
        positive_counts = [max_counts(max_counts > 0), sum_counts(sum_counts > 0), ...
            filtered_counts(filtered_counts > 0), max_filtered_counts(max_filtered_counts > 0)];
        if ~isempty(positive_counts)
            ylim([0.5, max(positive_counts) * 1.2]);
        end
    end
    draw_filter_limit_lines(filter_bounds);
    legend_handle = legend(labels, 'Location', 'northeast');
    set(legend_handle, 'FontSize', 9);
end

function make_and_save_charge_position_split_figure(q_max_event, q_sum_event, q_sum_filtered, q_max_filtered, ...
        t_dif_cal, time_pair, histogram_limits, filter_limits, q_separator, use_log_y, output_dir, file_name, save_plots)
    q_max_plot = filter_histogram_values(q_max_event(isfinite(q_max_event)), histogram_limits.q_event);
    q_sum_plot = filter_histogram_values(q_sum_event(isfinite(q_sum_event)), histogram_limits.q_event);
    q_sum_filtered_plot = filter_histogram_values(q_sum_filtered(isfinite(q_sum_filtered)), histogram_limits.q_event);
    q_max_filtered_plot = filter_histogram_values(q_max_filtered(isfinite(q_max_filtered)), histogram_limits.q_event);
    all_values = [q_max_plot; q_sum_plot; q_sum_filtered_plot; q_max_filtered_plot];
    fig = figure('Color', 'w', 'Position', [60 60 900 650]);
    if isempty(all_values)
        text(0.5, 0.5, 'No event-charge values in the configured range', ...
            'HorizontalAlignment', 'center');
        axis off;
    else
        n_bins = 200;
        if all(isfinite(histogram_limits.q_event))
            x_edges = linspace(histogram_limits.q_event(1), histogram_limits.q_event(2), n_bins + 1);
        else
            x_min = min(all_values); x_max = max(all_values);
            if x_min == x_max, x_min = x_min - 0.5; x_max = x_max + 0.5; end
            x_edges = linspace(x_min, x_max, n_bins + 1);
        end
        x_centers = (x_edges(1:end-1) + x_edges(2:end)) / 2;
        max_counts = hist(q_max_plot, x_centers);
        sum_counts = hist(q_sum_plot, x_centers);
        filtered_counts = hist(q_sum_filtered_plot, x_centers);
        max_filtered_counts = hist(q_max_filtered_plot, x_centers);
        labels = {'Blue: maximum strip charge', 'Red: sum of strip charges', ...
            'Green: filtered sum of strip charges', 'Purple: filtered maximum strip charge'};

        subplot(2, 2, [1 2]);
        plot_event_charge_histograms(x_centers, max_counts, sum_counts, filtered_counts, max_filtered_counts, ...
            histogram_limits.q_event, filter_limits.q_event, labels, use_log_y);
        draw_q_separator(q_separator);
        if use_log_y
            title(sprintf('Event charge split at q = %.6g (log Y)', q_separator));
        else
            title(sprintf('Event charge split at q = %.6g', q_separator));
        end

        low_charge_events = isfinite(q_sum_event) & q_sum_event < q_separator;
        high_charge_events = isfinite(q_sum_event) & q_sum_event > q_separator;
        subplot(2, 2, 3);
        plot_tdif_cal_y_map(t_dif_cal, time_pair, low_charge_events, ...
            histogram_limits.t_dif_cal, filter_limits.t_dif_cal, ...
            sprintf('t_dif_cal versus Y: q_sum < %.6g', q_separator));
        subplot(2, 2, 4);
        plot_tdif_cal_y_map(t_dif_cal, time_pair, high_charge_events, ...
            histogram_limits.t_dif_cal, filter_limits.t_dif_cal, ...
            sprintf('t_dif_cal versus Y: q_sum > %.6g', q_separator));
    end
    save_figure_if_requested(fig, output_dir, file_name, save_plots);
end

function draw_q_separator(q_separator)
    was_hold = ishold();
    hold on;
    y_bounds = ylim();
    plot([q_separator, q_separator], y_bounds, '--', 'Color', [0.9 0 0], 'LineWidth', 3);
    if ~was_hold, hold off; end
end

function make_and_save_total_charge_streamer_spectrum(q_sum_event, total_rows, streamer_threshold, output_dir, file_name, save_plots)
    values = q_sum_event(isfinite(q_sum_event));
    streamer_count = sum(isfinite(q_sum_event) & q_sum_event > streamer_threshold);
    fig = figure('Color', 'w', 'Position', [100 100 950 570]);
    if isempty(values)
        text(0.5, 0.5, 'No finite total event-charge values', 'HorizontalAlignment', 'center');
        axis off;
    else
        x_min = min(0, min(values)); x_max = max(values);
        if x_min == x_max, x_min = x_min - 0.5; x_max = x_max + 0.5; end
        x_edges = linspace(x_min, x_max, 201);
        x_centers = (x_edges(1:end-1) + x_edges(2:end)) / 2;
        counts = hist(values, x_centers);
        bar(x_centers, counts, 1, 'FaceColor', [0.82 0.25 0.12], 'EdgeColor', 'none');
        hold on;
        y_bounds = ylim();
        plot([streamer_threshold streamer_threshold], y_bounds, '--', 'Color', [0.35 0 0], 'LineWidth', 2.5);
        hold off;
        xlabel('Total calibrated event charge q_sum [ns]'); ylabel('Events');
        title(sprintf('Total charge spectrum: streamers q_sum > %.6g: %d / %d = %.4f%%', ...
            streamer_threshold, streamer_count, total_rows, 100 * streamer_count / total_rows));
        legend({'Total event charge', 'Streamer threshold'}, 'Location', 'northeast');
        grid on;
    end
    save_figure_if_requested(fig, output_dir, file_name, save_plots);
end

function make_and_save_streamer_position_maps(t_dif_cal, time_pair, streamer_event, streamer_threshold, x_limits, filter_bounds, output_dir, file_name, save_plots)
    fig = figure('Color', 'w', 'Position', [70 100 1300 570]);
    subplot(1, 2, 1);
    plot_tdif_cal_y_map_colored(t_dif_cal, time_pair, ~streamer_event, x_limits, filter_bounds, ...
        sprintf('Non-streamers: q_sum <= %.6g', streamer_threshold));
    subplot(1, 2, 2);
    plot_tdif_cal_y_map_colored(t_dif_cal, time_pair, streamer_event, x_limits, filter_bounds, ...
        sprintf('Streamers: q_sum > %.6g', streamer_threshold));
    save_figure_if_requested(fig, output_dir, file_name, save_plots);
end

function plot_tdif_cal_y_map_colored(t_dif_cal, time_pair, event_selection, x_limits, filter_bounds, plot_title)
    [counts, x_centers, y_centers] = tdif_cal_y_bin_counts(t_dif_cal, time_pair, event_selection, x_limits);
    if isempty(counts)
        text(0.5, 0.5, 'No t_dif_cal values in the configured range', 'HorizontalAlignment', 'center'); axis off;
        return;
    end
    imagesc(x_centers, y_centers, counts);
    set(gca, 'YDir', 'normal', 'YTick', y_centers, 'YTickLabel', {'Ch. 1', 'Ch. 2', 'Ch. 3', 'Ch. 4', 'Ch. 5'});
    colormap(gca, magma_red_colormap(256)); colorbar;
    xlabel('t_dif_cal [ns]'); ylabel('Normalized Y (five non-overlapping strips)'); title(plot_title);
    draw_filter_limit_lines(filter_bounds);
end

function make_and_save_charge_statistics_position_maps(q_sum_event, t_dif_cal, time_pair, x_limits, filter_bounds, output_dir, file_name, save_plots)
    [mean_charge, median_charge, x_centers, y_centers] = charge_statistics_by_position(q_sum_event, t_dif_cal, time_pair, x_limits);
    fig = figure('Color', 'w', 'Position', [70 100 1300 570]);
    subplot(1, 2, 1);
    plot_charge_statistic_map(mean_charge, x_centers, y_centers, filter_bounds, 'Mean total event charge q_sum [ns]');
    subplot(1, 2, 2);
    plot_charge_statistic_map(median_charge, x_centers, y_centers, filter_bounds, 'Median total event charge q_sum [ns]');
    save_figure_if_requested(fig, output_dir, file_name, save_plots);
end

function plot_charge_statistic_map(statistic, x_centers, y_centers, filter_bounds, plot_title)
    if isempty(statistic)
        text(0.5, 0.5, 'No finite charge and t_dif_cal values in the configured range', 'HorizontalAlignment', 'center'); axis off;
        return;
    end
    imagesc(x_centers, y_centers, statistic);
    set(gca, 'YDir', 'normal', 'YTick', y_centers, 'YTickLabel', {'Ch. 1', 'Ch. 2', 'Ch. 3', 'Ch. 4', 'Ch. 5'});
    colormap(gca, magma_red_colormap(256)); colorbar;
    xlabel('t_dif_cal [ns]'); ylabel('Normalized Y (five non-overlapping strips)'); title(plot_title);
    draw_filter_limit_lines(filter_bounds);
end

function [mean_charge, median_charge, x_centers, y_centers] = charge_statistics_by_position(q_sum_event, t_dif_cal, time_pair, x_limits)
    [~, x_centers, y_centers, x_edges] = tdif_cal_y_bin_counts(t_dif_cal, time_pair, isfinite(q_sum_event), x_limits);
    if isempty(x_centers)
        mean_charge = []; median_charge = []; return;
    end
    n_x_bins = numel(x_centers); n_channels = 5;
    mean_charge = NaN(n_channels, n_x_bins); median_charge = NaN(n_channels, n_x_bins);
    for channel = 1:n_channels
        valid = time_pair(:, channel) & isfinite(t_dif_cal(:, channel)) & isfinite(q_sum_event);
        values = t_dif_cal(valid, channel); charges = q_sum_event(valid);
        % With one output, histc returns bin *counts*, not the bin index of
        % each event.  Keep the second output so x_bin remains aligned with
        % charges; otherwise a 80-bin count vector indexes a shorter charge
        % vector and fails for sparsely populated channels.
        [~, x_bin] = histc(values, x_edges); x_bin(x_bin == n_x_bins + 1) = n_x_bins;
        for bin = 1:n_x_bins
            bin_charges = charges(x_bin == bin);
            if ~isempty(bin_charges)
                mean_charge(channel, bin) = mean(bin_charges);
                median_charge(channel, bin) = median(bin_charges);
            end
        end
    end
end

function [counts, x_centers, y_centers, x_edges] = tdif_cal_y_bin_counts(t_dif_cal, time_pair, event_selection, x_limits)
    n_x_bins = 80; n_channels = 5; tdif_values = []; channel_index = [];
    for channel = 1:n_channels
        values = t_dif_cal(time_pair(:, channel) & event_selection, channel);
        values = filter_histogram_values(values, x_limits);
        tdif_values = [tdif_values; values]; %#ok<AGROW>
        channel_index = [channel_index; channel * ones(numel(values), 1)]; %#ok<AGROW>
    end
    if isempty(tdif_values)
        counts = []; x_centers = []; y_centers = []; x_edges = []; return;
    end
    if numel(x_limits) == 2 && all(isfinite(x_limits)) && x_limits(1) < x_limits(2)
        x_edges = linspace(x_limits(1), x_limits(2), n_x_bins + 1);
    else
        x_min = min(tdif_values); x_max = max(tdif_values);
        if x_min == x_max, x_min = x_min - 0.5; x_max = x_max + 0.5; end
        x_edges = linspace(x_min, x_max, n_x_bins + 1);
    end
    [~, x_bin] = histc(tdif_values, x_edges); x_bin(x_bin == n_x_bins + 1) = n_x_bins;
    valid = x_bin >= 1 & x_bin <= n_x_bins;
    counts = accumarray([channel_index(valid), x_bin(valid)], 1, [n_channels, n_x_bins], @sum, 0);
    x_centers = (x_edges(1:end-1) + x_edges(2:end)) / 2;
    y_centers = ((1:n_channels) - 0.5) / n_channels;
end

function colors = magma_red_colormap(n)
    if nargin < 1, n = 256; end
    anchors = [0.001 0.000 0.014; 0.251 0.038 0.368; 0.550 0.161 0.506; 0.826 0.310 0.441; 0.988 0.645 0.338; 0.987 0.991 0.750];
    anchor_x = linspace(0, 1, rows(anchors)); target_x = linspace(0, 1, n);
    colors = [interp1(anchor_x, anchors(:, 1), target_x)', interp1(anchor_x, anchors(:, 2), target_x)', interp1(anchor_x, anchors(:, 3), target_x)'];
end

function make_and_save_q_sum_filtered_tdifcal_scatter(q_sum_filtered, t_dif_cal, output_dir, file_name, save_plots)
    fig = figure('Color', 'w', 'Position', [120 120 900 650]);
    colors = [0.00 0.35 0.85; 0.85 0.20 0.10; 0.10 0.60 0.20; ...
              0.60 0.20 0.75; 0.90 0.55 0.05];
    hold on;
    has_points = false;
    for channel = 1:5
        valid = isfinite(q_sum_filtered) & isfinite(t_dif_cal(:, channel));
        if any(valid)
            scatter(q_sum_filtered(valid), t_dif_cal(valid, channel), 10, ...
                colors(channel, :), 'filled', 'DisplayName', sprintf('Channel %d', channel));
            has_points = true;
        end
    end
    hold off; grid on;
    xlabel('q_sum_filtered [ns]');
    ylabel('t_dif_cal [ns]');
    title('Filtered event charge versus calibrated time semi-difference');
    if has_points, legend('Location', 'northeast'); end
    save_figure_if_requested(fig, output_dir, file_name, save_plots);
end

function filter_pass = event_filter_mask(q_f, q_b, q_f_cal, q_b_cal, t_f, t_b, ...
        q_sum, q_dif, q_dif_cal, t_dif, t_dif_cal, t_sum, hit_f, hit_b, ...
        valid_q_f, valid_q_b, q_max_event, q_sum_event, limits, scint_limits, scint_mode, alt_scintillator_data)
    % An event passes only when none of its recorded channel-1..5 values
    % violates any finite range in filter_limits.csv. Missing measurements
    % are ignored; they are not interpreted as a value of zero.
    n_events = rows(q_f);
    filter_pass = true(n_events, 1);
    rpc_charge_pair = false(rows(q_f), 6);
    rpc_time_pair = false(rows(q_f), 6);
    rpc_charge_pair(:, 1:5) = valid_q_f(:, 1:5) & valid_q_b(:, 1:5);
    rpc_time_pair(:, 1:5) = hit_f(:, 1:5) & hit_b(:, 1:5);
    filter_pass = reject_out_of_range(filter_pass, q_f, valid_q_f, limits.q_f);
    filter_pass = reject_out_of_range(filter_pass, q_b, valid_q_b, limits.q_b);
    filter_pass = reject_out_of_range(filter_pass, q_f_cal, valid_q_f, limits.q_f_cal);
    filter_pass = reject_out_of_range(filter_pass, q_b_cal, valid_q_b, limits.q_b_cal);
    filter_pass = reject_out_of_range(filter_pass, t_f, hit_f, limits.t_f);
    filter_pass = reject_out_of_range(filter_pass, t_b, hit_b, limits.t_b);
    filter_pass = reject_out_of_range(filter_pass, q_sum, rpc_charge_pair, limits.q_sum);
    filter_pass = reject_out_of_range(filter_pass, q_dif, rpc_charge_pair, limits.q_dif);
    filter_pass = reject_out_of_range(filter_pass, q_dif_cal, rpc_charge_pair, limits.q_dif_cal);
    filter_pass = reject_out_of_range(filter_pass, t_dif, rpc_time_pair, limits.t_dif);
    filter_pass = reject_out_of_range(filter_pass, t_dif_cal, rpc_time_pair, limits.t_dif_cal);
    filter_pass = reject_out_of_range(filter_pass, t_sum, rpc_time_pair, limits.t_sum);
    if all(isfinite(limits.q_event))
        event_values = [q_max_event, q_sum_event];
        out_of_range = isfinite(event_values) & ...
            (event_values < limits.q_event(1) | event_values > limits.q_event(2));
        filter_pass = filter_pass & ~any(out_of_range, 2);
    end
    if strcmp(scint_mode, 'legacy')
        filter_pass = reject_scint_out_of_range(filter_pass, q_f(:, 6), valid_q_f(:, 6), scint_limits.q_1);
        filter_pass = reject_scint_out_of_range(filter_pass, q_b(:, 6), valid_q_b(:, 6), scint_limits.q_2);
        filter_pass = reject_scint_out_of_range(filter_pass, q_f_cal(:, 6), valid_q_f(:, 6), scint_limits.q_1_cal);
        filter_pass = reject_scint_out_of_range(filter_pass, q_b_cal(:, 6), valid_q_b(:, 6), scint_limits.q_2_cal);
        filter_pass = reject_scint_out_of_range(filter_pass, t_f(:, 6), hit_f(:, 6), scint_limits.t_1);
        filter_pass = reject_scint_out_of_range(filter_pass, t_b(:, 6), hit_b(:, 6), scint_limits.t_2);
    elseif strcmp(scint_mode, 'alt')
        filter_pass = reject_scint_out_of_range(filter_pass, alt_scintillator_data.q_1, alt_scintillator_data.q_1_recorded, scint_limits.q_1);
        filter_pass = reject_scint_out_of_range(filter_pass, alt_scintillator_data.q_2, alt_scintillator_data.q_2_recorded, scint_limits.q_2);
        filter_pass = reject_scint_out_of_range(filter_pass, alt_scintillator_data.q_1, alt_scintillator_data.q_1_recorded, scint_limits.q_1_cal);
        filter_pass = reject_scint_out_of_range(filter_pass, alt_scintillator_data.q_2, alt_scintillator_data.q_2_recorded, scint_limits.q_2_cal);
        filter_pass = reject_scint_out_of_range(filter_pass, alt_scintillator_data.t_1, alt_scintillator_data.t_1_recorded, scint_limits.t_1);
        filter_pass = reject_scint_out_of_range(filter_pass, alt_scintillator_data.t_2, alt_scintillator_data.t_2_recorded, scint_limits.t_2);
    end
end

function filter_pass = reject_out_of_range(filter_pass, values, recorded, bounds)
    if any(isfinite(bounds))
        values = values(:, 1:5);
        recorded = recorded(:, 1:5) & isfinite(values);
        out_of_range = false(size(values));
        if isfinite(bounds(1)), out_of_range = out_of_range | values < bounds(1); end
        if isfinite(bounds(2)), out_of_range = out_of_range | values > bounds(2); end
        out_of_range = recorded & out_of_range;
        filter_pass = filter_pass & ~any(out_of_range, 2);
    end
end

function filter_pass = reject_scint_out_of_range(filter_pass, values, recorded, bounds)
    if any(isfinite(bounds))
        out_of_range = false(size(values));
        if isfinite(bounds(1)), out_of_range = out_of_range | values < bounds(1); end
        if isfinite(bounds(2)), out_of_range = out_of_range | values > bounds(2); end
        out_of_range = recorded & isfinite(values) & out_of_range;
        filter_pass = filter_pass & ~out_of_range;
    end
end

function apply_x_limits(x_limits)
    if numel(x_limits) == 2 && all(isfinite(x_limits)) && x_limits(1) < x_limits(2)
        xlim(x_limits);
    end
end

function draw_filter_limit_lines(bounds)
    if numel(bounds) ~= 2 || ~any(isfinite(bounds))
        return;
    end
    was_hold = ishold();
    hold on;
    current_x_limits = xlim();
    if all(isfinite(bounds)) && bounds(1) < bounds(2) && ...
            abs(current_x_limits(1) - bounds(1)) < eps(max(1, abs(bounds(1)))) && ...
            abs(current_x_limits(2) - bounds(2)) < eps(max(1, abs(bounds(2))))
        padding = 0.02 * (bounds(2) - bounds(1));
        xlim([bounds(1) - padding, bounds(2) + padding]);
    end
    y_bounds = ylim();
    if isfinite(bounds(1))
        plot([bounds(1), bounds(1)], y_bounds, '--', 'Color', [0.85 0 0], 'LineWidth', 1.8);
    end
    if isfinite(bounds(2))
        plot([bounds(2), bounds(2)], y_bounds, '--', 'Color', [0.85 0 0], 'LineWidth', 1.8);
    end
    if ~was_hold, hold off; end
end

function values = filter_histogram_values(values, x_limits)
    % Histogram limits are a plotting-only filter: apply them before hist()
    % so the automatically selected bins describe the requested range.
    if numel(x_limits) == 2 && all(isfinite(x_limits)) && x_limits(1) < x_limits(2)
        values = values(values >= x_limits(1) & values <= x_limits(2));
    end
end

function archived_file_count = archive_previous_output_files(output_dir)
    % Keep the immediately preceding execution for inspection.  LAST is
    % cleared before archiving, so it never contains more than one run.
    last_dir = fullfile(output_dir, 'LAST');
    if exist(last_dir, 'dir') ~= 7, mkdir(last_dir); end
    last_entries = dir(last_dir);
    for idx = 1:numel(last_entries)
        entry = last_entries(idx);
        if ~entry.isdir
            delete(fullfile(last_dir, entry.name));
        end
    end

    archived_file_count = 0;
    entries = dir(output_dir);
    for idx = 1:numel(entries)
        entry = entries(idx);
        if ~entry.isdir
            source_file = fullfile(output_dir, entry.name);
            [moved, message] = movefile(source_file, last_dir);
            if ~moved
                error('Could not archive %s: %s', source_file, message);
            end
            archived_file_count = archived_file_count + 1;
        end
    end
end

function map = read_alt_scintillator_map(file_name)
    fid = fopen(file_name, 'r');
    if fid < 0, error('Could not read %s', file_name); end
    parsed = textscan(fid, '%s%s%f%f%s%s', 'Delimiter', ',', 'HeaderLines', 1, 'Whitespace', '');
    fclose(fid);
    if isempty(parsed{1})
        error('%s must contain at least one PMT mapping row.', file_name);
    end
    enabled = false(numel(parsed{1}), 1);
    for idx = 1:numel(enabled)
        enabled(idx) = parse_boolean_value(parsed{5}{idx}, 'enabled', file_name);
        if ~any(parsed{4}(idx) == [1, 2]) || parsed{3}(idx) < 1 || parsed{3}(idx) ~= round(parsed{3}(idx))
            error('%s mapping rows need a positive channel and scintillator 1 or 2.', file_name);
        end
    end
    map = struct('time_field', {parsed{1}}, 'charge_field', {parsed{2}}, 'channel', parsed{3}, ...
        'scintillator', parsed{4}, 'enabled', enabled);
end

function scint_data = empty_alt_scintillator_data(n_events)
    empty_values = NaN(n_events, 0);
    empty_recorded = false(n_events, 0);
    scint_data = struct('q_1', empty_values, 'q_2', empty_values, 't_1', empty_values, 't_2', empty_values, ...
        'q_1_recorded', empty_recorded, 'q_2_recorded', empty_recorded, ...
        't_1_recorded', empty_recorded, 't_2_recorded', empty_recorded);
end

function scint_data = build_alt_scintillator_data(fast, map, n_events, tot_max_ns)
    scint_data = empty_alt_scintillator_data(n_events);
    for scintillator = 1:2
        rows_for_scintillator = find(map.enabled & map.scintillator == scintillator);
        if isempty(rows_for_scintillator)
            error('alt_scintillator_map.csv has no enabled PMT for scintillator %d.', scintillator);
        end
        time_values = NaN(n_events, numel(rows_for_scintillator));
        charge_values = NaN(n_events, numel(rows_for_scintillator));
        time_recorded = false(n_events, numel(rows_for_scintillator));
        charge_recorded = false(n_events, numel(rows_for_scintillator));
        for column = 1:numel(rows_for_scintillator)
            row = rows_for_scintillator(column);
            time_field = map.time_field{row}; charge_field = map.charge_field{row}; channel = map.channel(row);
            if ~isfield(fast, time_field) || ~isfield(fast, charge_field)
                error('alt scintillator mapping requires %s and %s in the MAT file.', time_field, charge_field);
            end
            raw_time = full(double(fast.(time_field)));
            raw_charge = full(double(fast.(charge_field)));
            if size(raw_time, 1) ~= n_events || size(raw_charge, 1) ~= n_events || ...
                    size(raw_time, 2) < channel || size(raw_charge, 2) < channel
                error('Invalid PMT mapping for channel %d in %s / %s.', channel, time_field, charge_field);
            end
            time_values(:, column) = raw_time(:, channel);
            charge_values(:, column) = raw_charge(:, channel);
            time_recorded(:, column) = raw_time(:, channel) ~= 0;
            charge_recorded(:, column) = time_recorded(:, column) & raw_charge(:, channel) > 0 & raw_charge(:, channel) < tot_max_ns;
        end
        scint_data.(sprintf('t_%d', scintillator)) = time_values;
        scint_data.(sprintf('q_%d', scintillator)) = charge_values;
        scint_data.(sprintf('t_%d_recorded', scintillator)) = time_recorded;
        scint_data.(sprintf('q_%d_recorded', scintillator)) = charge_recorded;
    end
end

function [run_name, mat_file, run_comment, run_order, scint_mode] = resolve_run_configuration(config_file, data_dir, requested_run)
    if exist(config_file, 'file') ~= 2
        error('Run configuration file not found: %s', config_file);
    end
    fid = fopen(config_file, 'r');
    if fid < 0, error('Could not read run configuration: %s', config_file); end
    parsed = textscan(fid, '%s%s%s%s', 'Delimiter', ',', 'HeaderLines', 1, ...
        'Whitespace', '');
    fclose(fid);
    run_names = parsed{1}; file_names = parsed{2}; scint_values = parsed{3}; comments = parsed{4};
    if isempty(run_names)
        error('Run configuration %s has no data rows.', config_file);
    end
    if isempty(requested_run)
        selected_index = numel(run_names); % newest appended run by default
    elseif numel(requested_run) > 1 && requested_run(1) == '@'
        selected_index = str2double(requested_run(2:end));
        if ~isfinite(selected_index) || selected_index ~= floor(selected_index) || selected_index < 1 || selected_index > numel(run_names)
            error('Row selector "%s" must be @ followed by a runs.csv data-row number from 1 to %d.', requested_run, numel(run_names));
        end
    else
        selected_index = find(strcmp(run_names, requested_run));
        if numel(selected_index) ~= 1
            error('Run "%s" was not found exactly once in %s.', requested_run, config_file);
        end
    end
    run_name = run_names{selected_index};
    file_name = file_names{selected_index};
    run_comment = comments{selected_index};
    run_order = selected_index;
    scint_mode = parse_scintillator_mode(scint_values{selected_index}, config_file);
    if isempty(run_name) || isempty(file_name)
        error('The selected run in %s needs both run_name and file_name.', config_file);
    end
    if ~isempty(regexp(run_name, '[\\/]', 'once'))
        error('run_name cannot contain path separators: %s', run_name);
    end
    mat_file = fullfile(data_dir, file_name);
end

function scint_mode = parse_scintillator_mode(text_value, file_name)
    normalized = lower(strtrim(text_value));
    if any(strcmp(normalized, {'false', '0', 'no'}))
        scint_mode = 'none';
    elseif any(strcmp(normalized, {'true', '1', 'yes'}))
        scint_mode = 'legacy';
    elseif strcmp(normalized, 'alt')
        scint_mode = 'alt';
    else
        error('Field "scint" in %s must be true, false, or alt.', file_name);
    end
end

function value = parse_boolean_value(text_value, field_name, file_name)
    normalized = lower(strtrim(text_value));
    if any(strcmp(normalized, {'true', '1', 'yes'}))
        value = true;
    elseif any(strcmp(normalized, {'false', '0', 'no'}))
        value = false;
    else
        error('Field "%s" in %s must be true or false.', field_name, file_name);
    end
end

function text_value = logical_to_text(value)
    if value
        text_value = 'true';
    else
        text_value = 'false';
    end
end

function ensure_configuration_templates(calibration_file, limits_file, filter_file, scint_histogram_limits_file, scint_filter_limits_file, special_parameters_file, plot_list_file, alt_scintillator_map_file)
    if exist(calibration_file, 'file') ~= 2
        fid = fopen(calibration_file, 'w');
        fprintf(fid, 'channel,qf_offset_ns,qb_offset_ns,tdif_offset_ns,q_dif_offset_ns\n');
        for channel = 1:5, fprintf(fid, '%d,0,0,0,0\n', channel); end
        fclose(fid);
    end
    if exist(limits_file, 'file') ~= 2
        fid = fopen(limits_file, 'w');
        fprintf(fid, 'quantity,min,max\n');
        names = {'q_f', 'q_b', 'q_f_cal', 'q_b_cal', 't_f', 't_b', ...
            'q_sum', 'q_dif', 'q_dif_cal', 'q_event', 't_dif', 't_dif_cal', 't_sum'};
        for idx = 1:numel(names), fprintf(fid, '%s,NaN,NaN\n', names{idx}); end
        fclose(fid);
    end
    if exist(filter_file, 'file') ~= 2
        copyfile(limits_file, filter_file);
    end
    scint_names = {'q_1', 'q_2', 'q_1_cal', 'q_2_cal', 't_1', 't_2'};
    if exist(scint_histogram_limits_file, 'file') ~= 2
        write_scint_limits_template(scint_histogram_limits_file, scint_names);
    end
    if exist(scint_filter_limits_file, 'file') ~= 2
        write_scint_limits_template(scint_filter_limits_file, scint_names);
    end
    if exist(special_parameters_file, 'file') ~= 2
        fid = fopen(special_parameters_file, 'w');
        fprintf(fid, ['parameter,value\nq_separator,12\nstreamer_charge_threshold,15\n' ...
            'min_charge_to_say_activated_strip,0\npoisson_target_counts_per_window,10\n' ...
            'poisson_waiting_particles,5\nscan_charge_histogram_bin_width,0.25\n']);
        fclose(fid);
    end
    if exist(plot_list_file, 'file') ~= 2
        fid = fopen(plot_list_file, 'w');
        fprintf(fid, ['plot_name,enabled,specific,comment\n' ...
            'all_channel_histograms,true,NaN,Not used for this plot\n' ...
            'alt_scintillator_pmt_histograms,true,NaN,Only used for scint=alt dedicated PMT inputs\n' ...
            't_dif_cal_vs_y_2d,true,NaN,Not used for this plot\n' ...
            'q_max_vs_q_sum_per_event,true,NaN,Not used for this plot\n' ...
            'q_sum_efficiency,true,NaN,Counts original rows with q_sum inside filter_limits q_event\n' ...
            'q_sum_filtered_vs_t_dif_cal_scatter,false,NaN,Not used for this plot\n' ...
            'q_sum_by_multiplicity,true,NaN,Not used for this plot\n' ...
            'poisson_arrival_test,true,NaN,Tests EBtime counts against a Poisson process\n' ...
            'poisson_waiting_time_test,true,NaN,Tests multi-arrival EBtime waiting times against an Erlang distribution\n' ...
            'q_sum_split_t_dif_cal_vs_y,true,false,Use true for logarithmic Y in the top histogram\n' ...
            'total_charge_streamer_spectrum,true,NaN,Total event-charge spectrum and streamer fraction\n' ...
            'streamer_t_dif_cal_vs_y,true,NaN,Non-streamer and streamer t_dif_cal versus strip maps\n' ...
            'charge_statistics_t_dif_cal_vs_y,true,NaN,Mean and median event charge maps by t_dif_cal and strip\n']);
        fclose(fid);
    end
    if exist(alt_scintillator_map_file, 'file') ~= 2
        fid = fopen(alt_scintillator_map_file, 'w');
        fprintf(fid, ['time_field,charge_field,channel,scintillator,enabled,comment\n' ...
            'T3_F,TOT3_F,1,1,true,Current PMT for scintillator 1\n' ...
            'T3_F,TOT3_F,2,2,true,Current PMT for scintillator 2\n' ...
            'T3_F,TOT3_F,3,1,false,Future second PMT for scintillator 1\n' ...
            'T3_F,TOT3_F,4,2,false,Future second PMT for scintillator 2\n']);
        fclose(fid);
    end
end

function write_scint_limits_template(file_name, names)
    fid = fopen(file_name, 'w');
    fprintf(fid, 'quantity,min,max\n');
    for idx = 1:numel(names), fprintf(fid, '%s,NaN,NaN\n', names{idx}); end
    fclose(fid);
end

function special_parameters = read_special_parameters(file_name)
    fid = fopen(file_name, 'r');
    if fid < 0, error('Could not read %s', file_name); end
    parsed = textscan(fid, '%s%f', 'Delimiter', ',', 'HeaderLines', 1);
    fclose(fid);
    separator_row = find(strcmp(parsed{1}, 'q_separator'));
    streamer_threshold_row = find(strcmp(parsed{1}, 'streamer_charge_threshold'));
    threshold_row = find(strcmp(parsed{1}, 'min_charge_to_say_activated_strip'));
    poisson_target_row = find(strcmp(parsed{1}, 'poisson_target_counts_per_window'));
    poisson_waiting_row = find(strcmp(parsed{1}, 'poisson_waiting_particles'));
    scan_histogram_bin_width_row = find(strcmp(parsed{1}, 'scan_charge_histogram_bin_width'));
    if numel(separator_row) ~= 1 || ~isfinite(parsed{2}(separator_row))
        error('%s must contain one finite q_separator value.', file_name);
    end
    if numel(threshold_row) ~= 1 || ~isfinite(parsed{2}(threshold_row))
        error('%s must contain one finite min_charge_to_say_activated_strip value.', file_name);
    end
    if numel(streamer_threshold_row) ~= 1 || ~isfinite(parsed{2}(streamer_threshold_row)) || parsed{2}(streamer_threshold_row) < 0
        error('%s must contain one non-negative streamer_charge_threshold value.', file_name);
    end
    if numel(poisson_target_row) ~= 1 || ~isfinite(parsed{2}(poisson_target_row)) || parsed{2}(poisson_target_row) <= 0
        error('%s must contain one positive poisson_target_counts_per_window value.', file_name);
    end
    if numel(poisson_waiting_row) ~= 1 || ~isfinite(parsed{2}(poisson_waiting_row)) || ...
            parsed{2}(poisson_waiting_row) < 1 || parsed{2}(poisson_waiting_row) ~= round(parsed{2}(poisson_waiting_row))
        error('%s must contain one positive integer poisson_waiting_particles value.', file_name);
    end
    if numel(scan_histogram_bin_width_row) ~= 1 || ~isfinite(parsed{2}(scan_histogram_bin_width_row)) || parsed{2}(scan_histogram_bin_width_row) <= 0
        error('%s must contain one positive scan_charge_histogram_bin_width value.', file_name);
    end
    special_parameters = struct('q_separator', parsed{2}(separator_row), ...
        'streamer_charge_threshold', parsed{2}(streamer_threshold_row), ...
        'min_charge_to_say_activated_strip', parsed{2}(threshold_row), ...
        'poisson_target_counts_per_window', parsed{2}(poisson_target_row), ...
        'poisson_waiting_particles', parsed{2}(poisson_waiting_row), ...
        'scan_charge_histogram_bin_width', parsed{2}(scan_histogram_bin_width_row));
end

function plot_list = read_plot_list(file_name)
    expected = {'all_channel_histograms', 'alt_scintillator_pmt_histograms', 't_dif_cal_vs_y_2d', ...
        'q_max_vs_q_sum_per_event', 'q_sum_efficiency', 'q_sum_filtered_vs_t_dif_cal_scatter', ...
        'q_sum_by_multiplicity', ...
        'poisson_arrival_test', ...
        'poisson_waiting_time_test', ...
        'q_sum_split_t_dif_cal_vs_y', 'total_charge_streamer_spectrum', 'streamer_t_dif_cal_vs_y', ...
        'charge_statistics_t_dif_cal_vs_y'};
    fid = fopen(file_name, 'r');
    if fid < 0, error('Could not read %s', file_name); end
    parsed = textscan(fid, '%s%s%s%s', 'Delimiter', ',', 'HeaderLines', 1, 'Whitespace', '');
    fclose(fid);
    if numel(parsed{1}) ~= numel(expected)
        error('%s must include exactly one row for every supported plot.', file_name);
    end
    plot_list = struct();
    for idx = 1:numel(expected)
        name = expected{idx};
        row = find(strcmp(parsed{1}, name));
        if numel(row) ~= 1
            error('%s must contain exactly one "%s" row.', file_name, name);
        end
        value = lower(strtrim(parsed{2}{row}));
        if any(strcmp(value, {'true', '1', 'yes'}))
            plot_list.(name) = true;
        elseif any(strcmp(value, {'false', '0', 'no'}))
            plot_list.(name) = false;
        else
            error('Plot "%s" in %s must be true or false.', name, file_name);
        end
        specific_value = lower(strtrim(parsed{3}{row}));
        if strcmp(name, 'q_sum_split_t_dif_cal_vs_y')
            if any(strcmp(specific_value, {'true', '1', 'yes'}))
                plot_list.([name '_specific']) = true;
            elseif any(strcmp(specific_value, {'false', '0', 'no'}))
                plot_list.([name '_specific']) = false;
            else
                error('Specific value for "%s" in %s must be true or false (top histogram log Y).', name, file_name);
            end
        elseif ~strcmp(specific_value, 'nan')
            error('Specific value for "%s" in %s must be NaN.', name, file_name);
        else
            plot_list.([name '_specific']) = false;
        end
    end
end

function [qf_offset, qb_offset, tdif_offset, q_dif_offset] = read_calibration_offsets(file_name)
    values = dlmread(file_name, ',', 1, 0);
    if ~isequal(size(values), [5, 5]) || any(values(:, 1)' ~= 1:5)
        error(['%s must have exactly five rows for channels 1--5 and five columns: ' ...
            'channel,qf_offset_ns,qb_offset_ns,tdif_offset_ns,q_dif_offset_ns.'], file_name);
    end
    if any(~isfinite(values(:, 2:5))(:))
        error('Calibration offsets in %s must be finite numbers.', file_name);
    end
    qf_offset = [values(:, 2); 0]';
    qb_offset = [values(:, 3); 0]';
    tdif_offset = [values(:, 4); 0]';
    q_dif_offset = [values(:, 5); 0]';
end

function limits = read_histogram_limits(file_name, allow_one_sided)
    fid = fopen(file_name, 'r');
    if fid < 0, error('Could not read %s', file_name); end
    parsed = textscan(fid, '%s%f%f', 'Delimiter', ',', 'HeaderLines', 1);
    fclose(fid);
    expected = {'q_f', 'q_b', 'q_f_cal', 'q_b_cal', 't_f', 't_b', ...
        'q_sum', 'q_dif', 'q_dif_cal', 'q_event', 't_dif', 't_dif_cal', 't_sum'};
    if numel(parsed{1}) ~= numel(expected)
        error('%s must contain one row for each histogram quantity.', file_name);
    end
    limits = struct();
    for idx = 1:numel(expected)
        name = expected{idx};
        row = find(strcmp(parsed{1}, name));
        if numel(row) ~= 1
            error('%s must contain exactly one "%s" row.', file_name, name);
        end
        bounds = [parsed{2}(row), parsed{3}(row)];
        validate_limit_bounds(bounds, name, file_name, allow_one_sided);
        limits.(name) = bounds;
    end
end

function limits = read_scint_limits(file_name, allow_one_sided)
    expected = {'q_1', 'q_2', 'q_1_cal', 'q_2_cal', 't_1', 't_2'};
    fid = fopen(file_name, 'r');
    if fid < 0, error('Could not read %s', file_name); end
    parsed = textscan(fid, '%s%f%f', 'Delimiter', ',', 'HeaderLines', 1);
    fclose(fid);
    if numel(parsed{1}) ~= numel(expected)
        error('%s must contain one row for each scintillator quantity.', file_name);
    end
    limits = struct();
    for idx = 1:numel(expected)
        name = expected{idx};
        row = find(strcmp(parsed{1}, name));
        if numel(row) ~= 1
            error('%s must contain exactly one "%s" row.', file_name, name);
        end
        bounds = [parsed{2}(row), parsed{3}(row)];
        validate_limit_bounds(bounds, name, file_name, allow_one_sided);
        limits.(name) = bounds;
    end
end

function validate_limit_bounds(bounds, name, file_name, allow_one_sided)
    % Histogram axes need both endpoints. Filters may use either endpoint:
    % for example, 380,NaN means keep values >= 380.
    if all(isnan(bounds))
        return;
    end
    if allow_one_sided
        if all(isfinite(bounds)) && bounds(1) >= bounds(2)
            error('Filter limits for %s in %s must have min < max.', name, file_name);
        end
    elseif ~(all(isfinite(bounds)) && bounds(1) < bounds(2))
        error('Histogram limits for %s in %s must be two finite values with min < max, or NaN,NaN.', name, file_name);
    end
end

function write_channel_summary_csv(file_name, front_summary, back_summary)
    fid = fopen(file_name, 'w');
    if fid < 0, error('Could not write %s', file_name); end
    fprintf(fid, 'side,channel,hit_count,hit_fraction_percent,valid_tot_count,invalid_tot_count,leading_time_median_ns,tot_median_ns,tot_std_ns\n');
    write_channel_rows(fid, 'Front', front_summary);
    write_channel_rows(fid, 'Back', back_summary);
    fclose(fid);
end

function write_channel_rows(fid, side, summary)
    for idx = 1:rows(summary)
        fprintf(fid, '%s,%d,%d,%.10g,%d,%d,%.10g,%.10g,%.10g\n', side, ...
            summary(idx, 1), summary(idx, 2), summary(idx, 3), summary(idx, 4), ...
            summary(idx, 5), summary(idx, 6), summary(idx, 7), summary(idx, 8));
    end
end

function write_numeric_csv(file_name, header, data)
    fid = fopen(file_name, 'w');
    if fid < 0, error('Could not write %s', file_name); end
    fprintf(fid, '%s\n', header); fclose(fid);
    dlmwrite(file_name, data, '-append', 'delimiter', ',', 'precision', '%.12g');
end

function save_figure_if_requested(fig, output_dir, file_name, save_plots)
    if save_plots
        % Force every output figure through gnuplot and keep it invisible.
        % This avoids the Qt/OpenGL interface completely in octave-cli.
        available_toolkits = available_graphics_toolkits();
        if any(strcmp(available_toolkits, 'gnuplot'))
            graphics_toolkit(fig, 'gnuplot');
        end
        set(fig, 'visible', 'off');
        % The large 72-panel figure needs more pixels than the other plots.
        if ~isempty(strfind(file_name, '_all_channel_histograms.png'))
            print(fig, fullfile(output_dir, file_name), '-dpng', '-r100');
        else
            print(fig, fullfile(output_dir, file_name), '-dpng', '-r72');
        end
        close(fig);
    end
end
