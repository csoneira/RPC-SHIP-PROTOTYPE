% Joana Pinto 2025
% csoneira@ucm.es 2025

% new script for the 4 scintillators, 2 top and 2 bottom
% run no.1 was acquired with the high voltage on
% runs no.2 and 3 were acquired with the top high voltage turned off

% System layout:
% PMT 1 ------------------------ PMT 2
% --------------- RPC ----------------
% PMT 3 ------------------------ PMT 4

% NOTE!!!
% pay attention to the order of the strip connections:
% wide strips: TFl = [l31 l32 l30 l28 l29]; TFt = [t31 t32 t30 t28 t29];  TBl = [l2 l1 l3 l5 l4]; TBt = [t2 t1 t3 t5 t4];
% scintillators: Tl_cint = [l11 l12 l9 l10]; Tt_cint = [t11 t12 t9 t10];
% Note: runs 1-2 (Joana) had the narrow-strip cables swapped (Qt=Ib, Qb=It); later runs are wired normally.

% l: leading edge times
% t: trailing edge times
% Q = t - l


% ---------------------------------------------------------------------
% ---------------------------------------------------------------------
% Header
% ---------------------------------------------------------------------
% ---------------------------------------------------------------------

% ---------------------------------------------------------------------
% Command-line flag parsing and logging setup
% ---------------------------------------------------------------------

cli_args = collect_cli_args();
no_plot_flag = any(strcmpi(cli_args, '--no-plot'));
debug_flag = any(strcmpi(cli_args, '--debug') | strcmpi(cli_args, '-d'));
slide_mode_flag = any(strcmpi(cli_args, '--slide-mode'));
essential_plots_flag = any(strcmpi(cli_args, '--esential-plots') | strcmpi(cli_args, '--essential-plots') | strcmpi(cli_args, '-ep'));

if evalin('base', 'exist(''no_plot'', ''var'')')
    base_no_plot = evalin('base', 'no_plot');
    if ischar(base_no_plot) || isstring(base_no_plot)
        base_no_plot = strcmpi(string(base_no_plot), "true");
    end
    if isnumeric(base_no_plot)
        base_no_plot = logical(base_no_plot);
    end
    if islogical(base_no_plot)
        no_plot_flag = no_plot_flag || base_no_plot;
    end
end

if evalin('base', 'exist(''debug_mode'', ''var'')')
    base_debug = evalin('base', 'debug_mode');
    if ischar(base_debug) || isstring(base_debug)
        base_debug = strcmpi(string(base_debug), "true");
    end
    if isnumeric(base_debug)
        base_debug = logical(base_debug);
    end
    if islogical(base_debug)
        debug_flag = debug_flag || base_debug;
    end
end
if evalin('base', 'exist(''debug'', ''var'')')
    base_debug_alt = evalin('base', 'debug');
    if ischar(base_debug_alt) || isstring(base_debug_alt)
        base_debug_alt = strcmpi(string(base_debug_alt), "true");
    end
    if isnumeric(base_debug_alt)
        base_debug_alt = logical(base_debug_alt);
    end
    if islogical(base_debug_alt)
        debug_flag = debug_flag || base_debug_alt;
    end
end

debug_mode = logical(debug_flag);

try
    if evalin('base', 'exist(''slide_mode'', ''var'')')
        base_slide_mode = evalin('base', 'slide_mode');
        if ischar(base_slide_mode) || isstring(base_slide_mode)
            base_slide_mode = strcmpi(string(base_slide_mode), "true");
        end
        if isnumeric(base_slide_mode)
            base_slide_mode = logical(base_slide_mode);
        end
        if islogical(base_slide_mode)
            slide_mode_flag = slide_mode_flag || base_slide_mode;
        end
    end
catch
end
slide_mode = logical(slide_mode_flag);
plot_essentials_only = logical(essential_plots_flag);
try
    if evalin('base', 'exist(''plot_essentials_only'',''var'')')
        base_essentials = evalin('base', 'plot_essentials_only');
        if ischar(base_essentials) || isstring(base_essentials)
            base_essentials = strcmpi(string(base_essentials), "true");
        end
        if isnumeric(base_essentials)
            base_essentials = logical(base_essentials);
        end
        if islogical(base_essentials)
            plot_essentials_only = plot_essentials_only || base_essentials;
        end
    end
catch
end

log_info = @(fmt, varargin) fprintf('[INFO] %s\n', sprintf(fmt, varargin{:}));
if debug_mode
    log_debug = @(fmt, varargin) fprintf('[DEBUG] %s\n', sprintf(fmt, varargin{:}));
else
    log_debug = @(varargin) [];
end
log_banner = @(fmt, varargin) fprintf('\n=== %s ===\n', sprintf(fmt, varargin{:}));

log_banner('Starting caye_edits_minimal');
if debug_mode
    log_info('Debug logging enabled.');
end
if slide_mode
    log_info('Slide mode enabled: compact figures with larger text.');
end
if plot_essentials_only
    log_info('Essential plots mode enabled: only position-related plots will be kept.');
end

should_plot = ~no_plot_flag;
simple_pdf_flag = any(strcmpi(cli_args, '--simple-pdf'));
full_pdf_flag = any(strcmpi(cli_args, '--full-pdf'));
png_only_flag = any(strcmpi(cli_args, '--png-only'));
png_only_flag = logical(png_only_flag);
DEFAULT_SIMPLE_PDF_LIMIT = 24;
pdf_limit_arg = NaN;
limit_flags = ["--pdf-limit", "--pdf-max-pages"];
for idx = 1:numel(cli_args)
    token = cli_args{idx};
    if ~(isstring(token) || ischar(token))
        continue;
    end
    tokenStr = string(token);
    for fIdx = 1:numel(limit_flags)
        flagStr = string(limit_flags(fIdx));
        equalPrefix = flagStr + "=";
        if startsWith(tokenStr, equalPrefix, 'IgnoreCase', true)
            valueStr = extractAfter(tokenStr, equalPrefix);
            candidate = str2double(valueStr);
            if ~isnan(candidate)
                pdf_limit_arg = candidate;
                break;
            end
        elseif strcmpi(tokenStr, flagStr)
            if idx < numel(cli_args)
                nextToken = cli_args{idx+1};
                candidate = str2double(string(nextToken));
                if ~isnan(candidate)
                    pdf_limit_arg = candidate;
                    break;
                end
            end
        end
    end
    if ~isnan(pdf_limit_arg)
        break;
    end
end
pdf_page_limit = NaN;
if ~isnan(pdf_limit_arg)
    pdf_page_limit = pdf_limit_arg;
elseif full_pdf_flag
    pdf_page_limit = Inf;
elseif simple_pdf_flag
    pdf_page_limit = DEFAULT_SIMPLE_PDF_LIMIT;
else
    try
        if evalin('base', 'exist(''save_pdf_max_pages'',''var'')')
            base_pdf_limit = evalin('base', 'save_pdf_max_pages');
            if ~isempty(base_pdf_limit) && isfinite(base_pdf_limit) && isnumeric(base_pdf_limit)
                pdf_page_limit = base_pdf_limit;
            end
        end
    catch
    end
end
if isnan(pdf_page_limit)
    pdf_page_limit = Inf;
end
if isfinite(pdf_page_limit)
    pdf_page_limit = max(0, floor(double(pdf_page_limit)));
else
    pdf_page_limit = Inf;
end

outputs7_root = fullfile(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))), 'STAGES', 'STAGE_7', 'DATA', 'DATA_FILES', 'OUTPUTS_7');
save_plots_dir_default = fullfile(outputs7_root, 'PDF');
if ~exist('save_plots','var')
    save_plots = false;
end
if png_only_flag
    save_plots = true;
end
if ~exist('save_plots_dir','var') || isempty(save_plots_dir)
    save_plots_dir = save_plots_dir_default;
end
if no_plot_flag
    save_plots = false;
end

debug_png_dir = '';
debug_png_counter = 0;

groot_default_visibility = get(groot, 'DefaultFigureVisible');
cleanup_debug_fig_visibility = [];
if debug_mode
    set(groot, 'DefaultFigureVisible', 'off');
    cleanup_debug_fig_visibility = onCleanup(@() set(groot, 'DefaultFigureVisible', groot_default_visibility));
    log_info('Debug mode enabled: figures will be rendered off-screen while PNGs are saved.');
end

% Essential plots (position-focused) kept when --esential-plots/--essential-plots/-ep is enabled.
% Scope: thin position derivation through final XY map.
essential_plot_labels = { ...
    'thin_vs_thin_raw', ...
    'thin_charge_share_weighted', ... % prefix match
    'thin_gaussian_fit', ... % prefix match
    'fits_matrix_top_bottom', ...
    'thin_bottom_vs_top', ...
    'thin_bottom_vs_thick', ...
    'thick_vs_thin_top', ...
    'thin_vs_thick_wraps', ...
    'final_xy_map' ...
};
try
    if evalin('base', 'exist(''essential_plot_labels'',''var'')')
        base_labels = evalin('base', 'essential_plot_labels');
        if iscell(base_labels) && all(cellfun(@(s) ischar(s) || isstring(s), base_labels))
            essential_plot_labels = cellfun(@char, base_labels, 'UniformOutput', false);
        end
    end
catch
end

clearvars -except save_plots save_plots_dir save_plots_dir_default input_dir keep_raster_temp test run should_plot no_plot_flag debug_flag debug_mode slide_mode log_info log_debug log_banner outputs7_root debug_png_dir debug_png_counter groot_default_visibility cleanup_debug_fig_visibility pdf_page_limit png_only_flag plot_essentials_only essential_plot_labels;
close all; clc;

assignin('base', 'plot_essentials_only', plot_essentials_only);
assignin('base', 'essential_plot_labels', essential_plot_labels);


%%


% ---------------------------------------------------------------------
% ---------------------------------------------------------------------
% Run test definition
% ---------------------------------------------------------------------
% ---------------------------------------------------------------------

if ~exist('test','var') || isempty(test)
    test = true;
end
if ischar(test) || isstring(test)
    test = strcmpi(string(test), "true");
end
test = logical(test);

if ~exist('run','var') || isempty(run)
    run = 1;
end
if isstring(run) || ischar(run)
    run = str2double(run);
end
if isnan(run)
    run = 0;
end

run_label = num2str(run);

project_root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
png_root_dirs = {fullfile(outputs7_root, 'RUN_SUMMARY_PNG')};

if test
    if run == 1
        input_dir = 'RUN_1';
        data_dir = fullfile(project_root, 'STAGES', 'STAGE_5', 'DATA', 'DATA_FILES', 'ANCILLARY', input_dir);
    elseif run == 2
        input_dir = 'RUN_2';
        data_dir = fullfile(project_root, 'STAGES', 'STAGE_5', 'DATA', 'DATA_FILES', 'ANCILLARY', input_dir);
    elseif run == 3
        input_dir = 'RUN_3';
        data_dir = fullfile(project_root, 'STAGES', 'STAGE_5', 'DATA', 'DATA_FILES', 'ANCILLARY', input_dir);
    elseif run == 4
        input_dir = 'dabc25282152204_RUN_4_2025-10-20_16h00m00s';
        data_dir = fullfile(project_root, 'STAGES', 'STAGE_5', 'DATA', 'DATA_FILES', 'ALL_UNPACKED', input_dir);
    elseif run == 5
        input_dir = 'dabc25291140248_RUN_5_2025-10-20_16h00m00s';
        data_dir = fullfile(project_root, 'STAGES', 'STAGE_5', 'DATA', 'DATA_FILES', 'ALL_UNPACKED', input_dir);
    else
        error('For test mode, set run to 1, 2, 3, 4, or 5.');
    end
    data_dir = char(data_dir);
end

% Limit the events for testing purposes
limit = true;
limit_number_of_events = 5000;



% ---------------------------------------------------------------------


%%


% ---------------------------------------------------------------------
% ---------------------------------------------------------------------
% File import and Setup
% ---------------------------------------------------------------------
% ---------------------------------------------------------------------


% Some paths ----------------------------------------------------------
HOME    = '/home/csoneira/WORK/LIP_stuff/';
% SCRIPTS = 'JOAO_SETUP/STORED_NOT_ESSENTIAL/';
DATA    = 'matFiles/time/';
DATA_Q    = 'matFiles/charge/';
% path(path,[HOME SCRIPTS 'util_matPlots/']);

summary_output_dir = fullfile(outputs7_root, 'TABLES');
path(path, fullfile(project_root, 'STORED_NOT_ESSENTIAL', 'util_matPlots'));
mst_saves_root = fullfile(project_root, 'STAGES', 'STAGE_6', 'DATA', 'DATA_FILES', 'JOINED');
unpacked_root = fullfile(project_root, 'STAGES', 'STAGE_6', 'DATA', 'DATA_FILES', 'JOINED');
if ~exist(outputs7_root, 'dir'); mkdir(outputs7_root); end
if ~exist(summary_output_dir, 'dir'); mkdir(summary_output_dir); end
if ~exist(fullfile(outputs7_root, 'PDF'), 'dir'); mkdir(fullfile(outputs7_root, 'PDF')); end
if ~exist(fullfile(outputs7_root, 'CHARGES'), 'dir'); mkdir(fullfile(outputs7_root, 'CHARGES')); end
% ---------------------------------------------------------------------


if isstring(save_plots_dir)
    save_plots_dir = char(save_plots_dir);
end

% Debug visibility for target directories
log_debug('Using save_plots_dir: %s', save_plots_dir);

% Ensure save_plots_dir is valid and not overwritten unnecessarily
if save_plots && (isempty(save_plots_dir) || (~ischar(save_plots_dir) && ~isstring(save_plots_dir)))
    error('Invalid save_plots_dir: %s', save_plots_dir);
end

clear save_plots_dir_default;

restoreFigureDefaults = [];
if save_plots
    originalFigureVisibility = get(groot, 'DefaultFigureVisible');
    originalFigureCreateFcn = get(groot, 'DefaultFigureCreateFcn');
    restoreFigureDefaults = onCleanup(@() restore_figure_defaults(originalFigureVisibility, originalFigureCreateFcn));
    set(groot, 'DefaultFigureVisible', 'off');
    set(groot, 'DefaultFigureCreateFcn', @(fig, ~) set(fig, 'Visible', 'off'));
end

plotThemeDefaults = apply_dark_plot_theme_defaults();
cleanup_plot_theme = onCleanup(@() restore_plot_theme_defaults(plotThemeDefaults));
presentation_defaults = apply_presentation_mode_defaults(slide_mode);
cleanup_presentation_mode = onCleanup(@() restore_presentation_mode_defaults(presentation_defaults));

if ( ~exist('input_dir','var') || isempty(input_dir) ) && ~test
    if ~isfolder(mst_saves_root)
        error('The directory %s does not exist. Provide input_dir or ensure MST_saves is available.', mst_saves_root);
    end

    dir_info = dir(mst_saves_root);
    dir_info = dir_info([dir_info.isdir]);
    dir_info = dir_info(~ismember({dir_info.name}, {'.','..'}));
    if isempty(dir_info)
        error('No subdirectories found in %s. Provide input_dir or populate MST_saves.', mst_saves_root);
    end

    [~, oldest_idx] = min([dir_info.datenum]);
    input_dir = dir_info(oldest_idx).name;
    log_info('Automatically selected MST_saves directory: %s', input_dir);
elseif isstring(input_dir)
    input_dir = char(input_dir);
end

if ~test
    if isfolder(input_dir)
        data_dir = char(input_dir);
    else
        data_dir_candidates = {fullfile(unpacked_root, input_dir), fullfile(mst_saves_root, input_dir)};
        existing_dirs = data_dir_candidates(cellfun(@isfolder, data_dir_candidates));
        if isempty(existing_dirs)
            error('Data directory "%s" not found in "%s" or "%s".', input_dir, unpacked_root, mst_saves_root);
        end
        data_dir = existing_dirs{1};
    end
end

log_info('Processing run %d using input directory "%s".', run, input_dir);
log_debug('Resolved data directory: %s', data_dir);

time_dir = fullfile(data_dir, 'time');
charge_dir = fullfile(data_dir, 'charge');

if ~isfolder(time_dir)
    error('Time directory not found: %s', time_dir);
end
if ~isfolder(charge_dir)
    error('Charge directory not found: %s', charge_dir);
end

dataset_basename = '';
if run > 0
    dataset_basename = sprintf('RUN_%d', run);
end
charge_listing = dir(fullfile(charge_dir, '*_joined*.mat'));
if isempty(charge_listing)
    charge_listing = dir(fullfile(time_dir, '*_joined*.mat'));
end
if ~isempty(charge_listing)
    [~, candidate_name] = fileparts(charge_listing(1).name);
    token = regexp(candidate_name, '(dabc\d+)', 'tokens', 'once');
    if ~isempty(token)
        dataset_basename = token{1};
    end
end
if isempty(dataset_basename)
    [~, dataset_basename] = fileparts(char(input_dir));
end

% Extract datetime from the basename and convert to 'yyyy-mm-dd_HH.MM.SS'
datetime_str = regexp(dataset_basename, '\\d{11,13}', 'match', 'once'); % Extract YYYYDOYHHMM[SS]
if isempty(datetime_str)
    warning('Failed to extract datetime from basename: %s. Using current timestamp.', dataset_basename);
    file_datetime = datetime('now');
else
    year_val = str2double(datetime_str(1:4));
    doy_val = str2double(datetime_str(5:7));
    if isnan(year_val) || isnan(doy_val)
        warning('Unable to parse timestamp token "%s". Using current timestamp.', datetime_str);
        file_datetime = datetime('now');
    else
        hour_val = 0;
        minute_val = 0;
        second_val = 0;
        if numel(datetime_str) >= 9
            hour_val = str2double(datetime_str(8:9));
        end
        if numel(datetime_str) >= 11
            minute_val = str2double(datetime_str(10:11));
        end
        if numel(datetime_str) >= 13
            second_val = str2double(datetime_str(12:13));
        end
        if any(isnan([hour_val, minute_val, second_val]))
            warning('Incomplete timestamp token "%s". Using current timestamp.', datetime_str);
            file_datetime = datetime('now');
        else
            is_leap = (mod(year_val, 4) == 0 && (mod(year_val, 100) ~= 0 || mod(year_val, 400) == 0));
            max_doy = 365 + double(is_leap);
            if doy_val < 1 || doy_val > max_doy
                warning('Day-of-year value %d out of range for year %d. Using current timestamp.', doy_val, year_val);
                file_datetime = datetime('now');
            else
                file_datetime = datetime(year_val, 1, 1, hour_val, minute_val, second_val) + days(doy_val - 1);
            end
        end
    end
end

% For readability in filenames
formatted_datetime = datestr(file_datetime, 'yyyy-mm-dd_HH.MM.SS');
formatted_datetime_tex = strrep(run_label, '_', '\_'); % Escape underscores for titles/labels
log_info('Dataset timestamp: %s', formatted_datetime);

execution_datetime = datestr(now, 'yyyy_mm_dd-HH.MM.SS');
if run ~= 0
    export_session_label = sprintf('RUN_%d_%s_exec_%s', run, formatted_datetime, execution_datetime);
    png_dir_label = sprintf('RUN_%d', run);
else
    export_session_label = sprintf('results_%s_exec_%s', formatted_datetime, execution_datetime);
    png_dir_label = 'RUN_0';
end
pdfFileName = sprintf('%s.pdf', export_session_label);
pdfPath = fullfile(save_plots_dir, pdfFileName);
log_info('Planned PDF output: %s', pdfPath);

png_session_dirs = cellfun(@(root) fullfile(root, png_dir_label), png_root_dirs, 'UniformOutput', false);
% Clear any existing PNGs for this run so outputs start fresh.
for idx = 1:numel(png_session_dirs)
    targetDir = png_session_dirs{idx};
    if isfolder(targetDir)
        existingPngs = dir(fullfile(targetDir, '*.png'));
        if ~isempty(existingPngs)
            log_info('Removing %d existing PNG(s) from %s', numel(existingPngs), targetDir);
            for fIdx = 1:numel(existingPngs)
                delete(fullfile(targetDir, existingPngs(fIdx).name));
            end
        end
    end
end

png_export_settings = struct( ...
    'enabled', png_only_flag, ...
    'dirs', {png_session_dirs}, ...
    'counter', 0, ...
    'resolution', 150, ...
    'auto_close', png_only_flag, ...
    'label_prefix', export_session_label);
assignin('base', 'png_export_settings', png_export_settings);

if png_only_flag
    for idx = 1:numel(png_session_dirs)
        targetDir = png_session_dirs{idx};
        if ~exist(targetDir, 'dir')
            mkdir(targetDir);
        end
    end
    log_info('--png-only enabled: streaming figures for %s to %s', png_dir_label, strjoin(png_session_dirs, ', '));
end

if debug_mode
    debug_png_root = fullfile(outputs7_root, 'DEBUG_PNG');
    if ~exist(debug_png_root, 'dir')
        mkdir(debug_png_root);
    end
    if run ~= 0
        debug_folder_name = sprintf('RUN_%d_%s_exec_%s', run, formatted_datetime, execution_datetime);
    else
        debug_folder_name = sprintf('results_%s_exec_%s', formatted_datetime, execution_datetime);
    end
    debug_png_dir = fullfile(debug_png_root, debug_folder_name);
    if ~exist(debug_png_dir, 'dir')
        mkdir(debug_png_dir);
    end
    log_info('Debug PNGs will stream to %s', debug_png_dir);
    debug_png_counter = 0;
else
    debug_png_dir = '';
    debug_png_counter = 0;
end

% Dynamically detect time MAT files in the directory
time_files = dir(fullfile(time_dir, sprintf('%s*_T.mat', dataset_basename)));

if isempty(time_files)
    error('No time MAT files found matching "%s*_T.mat" in %s', dataset_basename, time_dir);
end

log_info('Loading %d time file(s) from %s', numel(time_files), time_dir);

% Load each time file
for i = 1:length(time_files)
    time_file_path = fullfile(time_dir, time_files(i).name);
    log_debug('Loading time file: %s', time_file_path);
    load(time_file_path);
end

charge_listing = dir(fullfile(charge_dir, sprintf('%s*_a*_Q.mat', dataset_basename)));
if isempty(charge_listing)
    error('No charge MAT files found matching "%s_a*_Q.mat" in %s', dataset_basename, charge_dir);
end
charge_files = sort({charge_listing.name});
log_info('Loading %d charge file(s) from %s', numel(charge_files), charge_dir);
for idx = 1:numel(charge_files)
    charge_path = fullfile(charge_dir, charge_files{idx});
    log_debug('Loading charge data: %s', charge_path);
    load(charge_path);
end


%%


% ---------------------------------------------------------------------
% ---------------------------------------------------------------------
% NaN scrubber: replace NaNs with 0 across all float variables
% ---------------------------------------------------------------------
% ---------------------------------------------------------------------


ws = 'base';                     % workspace to operate on
vars = evalin(ws, 'whos');       % list all variables

replaced_names  = {};
replaced_counts = [];
skipped_names   = {};
skipped_types   = {};

log_info('Scanning %d workspace variable(s) for NaNs', numel(vars));
for k = 1:numel(vars)
    name = vars(k).name;
    cls  = vars(k).class;

    % Fetch value safely from the target workspace
    val = evalin(ws, name);

    % Only float classes can actually store NaN
    if isfloat(val)   % covers double, single (and complex/sparse variants)
        % isnan works elementwise; for complex, true if real or imag is NaN
        mask = isnan(val);
        nans = nnz(mask);

        if nans > 0
            val(mask) = 0;       % zero-out NaNs
            log_debug('Replaced %d NaN(s) in %-25s with 0.\n', nans, name);
            assignin(ws, name, val);
        end

        % fprintf('NaNs in %-25s : %d\n', name, nans);
        replaced_names{end+1}  = name; %#ok<AGROW>
        replaced_counts(end+1) = nans; %#ok<AGROW>

    else
        % Non-float types either cannot hold NaN or use different missing markers
        % (e.g., datetime/duration use NaT). We skip them.
        skipped_names{end+1} = name;  %#ok<AGROW>
        skipped_types{end+1} = cls;   %#ok<AGROW>
    end
end


%%


% ---------------------------------------------------------------------
% ---------------------------------------------------------------------
% Parameters and Thresholds
% ---------------------------------------------------------------------
% --------------------------------------------------------------------

% Load per-run parameters from configuration so edits live in one place.
thisFile = mfilename('fullpath');
if isempty(thisFile)
    if usejava('desktop')
        thisFile = matlab.desktop.editor.getActiveFilename;
    else
        thisFile = which('caye_edits_minimal');
    end
end
config_file = fullfile(fileparts(fileparts(thisFile)), 'CONFIGS', 'run_parameters_config.csv');
if ~exist(config_file, 'file')
    error('Parameter config not found: %s', config_file);
end

opts = detectImportOptions(config_file, 'TextType','string', 'PreserveVariableNames', true);
value_columns = setdiff(opts.VariableNames, {'parameter'});
if ~isempty(value_columns)
    opts = setvartype(opts, value_columns, 'string');
end
config_table = readtable(config_file, opts);
if ~ismember('parameter', config_table.Properties.VariableNames)
    error('Parameter config must include a ''parameter'' column.');
end

% Normalize value columns as strings so mixed scalar/vector data preserves formatting.
value_columns = setdiff(config_table.Properties.VariableNames, {'parameter'});
for colIdx = 1:numel(value_columns)
    colName = value_columns{colIdx};
    config_table.(colName) = string(config_table.(colName));
end

run_field = sprintf('run%d', run);
has_default = ismember('default', config_table.Properties.VariableNames);
if ~ismember(run_field, config_table.Properties.VariableNames)
    if has_default
        run_field = 'default';
    else
        error('No configuration column for run %d and no default column provided.', run);
    end
end

if iscell(config_table.parameter)
    param_names = config_table.parameter;
else
    param_names = cellstr(config_table.parameter);
end

param_values = cell(size(param_names));
for idx = 1:numel(param_names)
    selected_value = config_table.(run_field)(idx);
    if (ismissing(selected_value) || (isstring(selected_value) && strlength(strtrim(selected_value)) == 0)) && has_default
        selected_value = config_table.default(idx);
    end
    if ismissing(selected_value)
        error('Missing value for parameter %s in column %s.', param_names{idx}, run_field);
    end
    param_values{idx} = parseParameterValue(selected_value);
end

param_map = containers.Map(param_names, param_values);
getParam = @(name) param_map(name);

if run >= 4 && ~strcmp(run_field, 'default')
    log_info('Using configuration column "%s" for run %d.', run_field, run);
elseif strcmp(run_field, 'default')
    log_info('Using default parameter configuration for run %d.', run);
end


% PMTs
lead_time_pmt_min = getParam('lead_time_pmt_min');
lead_time_pmt_max = getParam('lead_time_pmt_max');
trail_time_pmt_min = getParam('trail_time_pmt_min');
trail_time_pmt_max = getParam('trail_time_pmt_max');

time_pmt_diff_thr = getParam('time_pmt_diff_thr'); % ns
tTH = getParam('tTH'); % time threshold [ns] to assume it comes from a good event
percentile_pmt = getParam('percentile_pmt'); % To calculate the range PTM

% WIDE
lead_time_wide_strip_min = getParam('lead_time_wide_strip_min');
lead_time_wide_strip_max = getParam('lead_time_wide_strip_max');
trail_time_wide_strip_min = getParam('trail_time_wide_strip_min');
trail_time_wide_strip_max = getParam('trail_time_wide_strip_max');

charge_wide_strip_diff_thr = getParam('charge_wide_strip_diff_thr');
QF_offsets = getParam('QF_offsets'); % from selfTrigger
QB_offsets = getParam('QB_offsets');

% NARROW
charge_narrow_strip_min = getParam('charge_narrow_strip_min');
charge_narrow_strip_max = getParam('charge_narrow_strip_max');
charge_top_pedestal = getParam('charge_top_pedestal');
charge_bot_pedestal = getParam('charge_bot_pedestal');

% Crosstalk
thick_strip_crosstalk = getParam('thick_strip_crosstalk'); % ADCbins
top_narrow_strip_crosstalk = getParam('top_narrow_strip_crosstalk'); % ADCbins/event
bot_narrow_strip_crosstalk = getParam('bot_narrow_strip_crosstalk'); % ADCbins/event

% Streamers
Q_thick_streamer_threshold = getParam('Q_thick_streamer_threshold'); % ADCbins
Q_thin_top_streamer_threshold = getParam('Q_thin_top_streamer_threshold'); % ADCbins
Q_thin_bot_streamer_threshold = getParam('Q_thin_bot_streamer_threshold'); % ADCbins

% Final plot
number_of_bins_final_charge_and_eff_plots = getParam('number_of_bins_final_charge_and_eff_plots');

% Position from narrow strips. Computationally expensive.
position_from_narrow_strips = getParam('position_from_narrow_strips');

% -----------------------------------------------------------
% -----------------------------------------------------------



%%


% ---------------------------------------------------------------------
% ---------------------------------------------------------------------
% Original Data Structuring
% ---------------------------------------------------------------------
% ---------------------------------------------------------------------

% -----------------------------------------------------------------------------
% Scintillator Timing and Charge Derivations
% -----------------------------------------------------------------------------

% Build matrices with leading/trailing edge times for each scintillator PMT
% and derive simple charge proxies and mean times per side.
try
    Tl_cint_OG = [l11 l12 l9 l10]; %tempos leadings  [ns] - leading times [ns]
    Tt_cint_OG = [t11 t12 t9 t10]; %tempos trailings [ns] - trailing times [ns]
catch
    warning('Variables 9/10/11/12 not found; THIS EXITS THE CODE.');
    return;
end

Qcint_OG = [Tt_cint_OG(:,1) - Tl_cint_OG(:,1) Tt_cint_OG(:,2) - Tl_cint_OG(:,2) Tt_cint_OG(:,3) - Tl_cint_OG(:,3) Tt_cint_OG(:,4) - Tl_cint_OG(:,4)]; 


% -----------------------------------------------------------------------------
% RPC WIDE STRIP Timing and Charge Derivations
% -----------------------------------------------------------------------------

% Joana - TFl = [l31 l32 l30 l28 l29];
        % TFt = [t31 t32 t30 t28 t29];
        % TBl = [l2 l1 l3 l5 l4];
        % TBt = [t2 t1 t3 t5 t4];

try
    TFl_OG = [l30 l31 l32 l29 l28];    % tempos leadings front [ns]; chs [32,28] -> 5 strips gordas front
    TFt_OG = [t30 t31 t32 t29 t28];    % tempos trailings front [ns]
    TBl_OG = [l3 l2 l1 l4 l5]; %leading times back [ns]; channels [1,5] -> 5 wide back strips
    TBt_OG = [t3 t2 t1 t4 t5]; %trailing times back [ns]
catch
    warning('Variables 29-30-31-32 not found; using alternative channel order 24-25-26-27-28.');

    % % Print the length of l28 to l32 to check if they exist
    % fprintf('Lengths of alternative wide strip variables: l24=%d, l25=%d, l26=%d, l27=%d, l28=%d\n', ...
    %     length(l24), length(l25), length(l26), length(l27), length(l28));
    
    %whos

    % % Exit
    % return;

    % If l27/t27 are missing, fill with zeros matching a nearby channel length so later
    % concatenations do not fail.
    ref_order_leading = {'l26','l28','l25','l24'};
    if ~exist('l27','var') || isempty(l27)
        ref_name = '';
        ref_vec = [];
        for k = 1:numel(ref_order_leading)
            candidate = ref_order_leading{k};
            if exist(candidate,'var') && ~isempty(eval(candidate))
                ref_name = candidate;
                ref_vec = eval(candidate);
                break;
            end
        end
        if isempty(ref_vec)
            l27 = zeros(0,1);
            warning('Variable l27 missing; substituting zero vector (no reference length found).');
        else
            l27 = zeros(size(ref_vec));
            warning('Variable l27 missing; substituting zeros with size matching %s.', ref_name);
        end
    end

    ref_order_trailing = {'t26','t28','t25','t24'};
    if ~exist('t27','var') || isempty(t27)
        ref_name_t = '';
        ref_vec_t = [];
        for k = 1:numel(ref_order_trailing)
            candidate = ref_order_trailing{k};
            if exist(candidate,'var') && ~isempty(eval(candidate))
                ref_name_t = candidate;
                ref_vec_t = eval(candidate);
                break;
            end
        end
        if isempty(ref_vec_t)
            t27 = zeros(size(l27));
            warning('Variable t27 missing; substituting zero vector matching l27 size (no timing reference found).');
        else
            t27 = zeros(size(ref_vec_t));
            warning('Variable t27 missing; substituting zeros with size matching %s.', ref_name_t);
        end
    end

    TFl_OG = [l26 l27 l28 l25 l24];
    TFt_OG = [t26 t27 t28 t25 t24];
    TBl_OG = [l3 l2 l1 l4 l5]; %leading times back [ns]; channels [1,5] -> 5 wide back strips
    TBt_OG = [t3 t2 t1 t4 t5]; %trailing times back [ns]
end

% Charge proxies per strip (front/back)
QF_OG  = TFt_OG - TFl_OG;
QB_OG  = TBt_OG - TBl_OG;





% -----------------------------------------------------------------------------
% RPC charges for the five NARROW STRIPS, which do not carry timing info.
% -----------------------------------------------------------------------------

% Convert charge arrays from cell traces to double matrices (after cable swap).
% note: runs 1-2 had swapped cables (Qt=Ib and Qb=It)

v = cast([Ib IIb IIIb IVb Vb VIb VIIb VIIIb IXb Xb XIb XIIb XIIIb XIVb XVb XVIb XVIIb XVIIIb XIXb XXb XXIb XXIIb XXIIIb XXIVb],"double");
w = cast([It IIt IIIt IVt Vt VIt VIIt VIIIt IXt Xt XIt XIIt XIIIt XIVt XVt XVIt XVIIt XVIIIt XIXt XXt XXIt XXIIt XXIIIt XXIVt],"double");

swap_narrow_top_bottom_default = ismember(run, [1 2 21]); % Joana runs had top/bottom swapped
reverse_narrow_strip_order_default = swap_narrow_top_bottom_default; % same cabling flipped the strip order

swap_narrow_top_bottom = swap_narrow_top_bottom_default;
reverse_narrow_strip_order = reverse_narrow_strip_order_default;

% Optional overrides from the base workspace for quick testing
try
    if evalin('base', 'exist(''swap_narrow_top_bottom'',''var'')')
        candidate = evalin('base', 'swap_narrow_top_bottom');
        if isstring(candidate) || ischar(candidate)
            candidate = strtrim(lower(string(candidate)));
            swap_narrow_top_bottom = any(candidate == ["true","1","yes","y"]);
        else
            swap_narrow_top_bottom = logical(candidate);
        end
    end
catch
    log_debug('swap_narrow_top_bottom override ignored (parse error).');
end

try
    if evalin('base', 'exist(''reverse_narrow_strip_order'',''var'')')
        candidate = evalin('base', 'reverse_narrow_strip_order');
        if isstring(candidate) || ischar(candidate)
            candidate = strtrim(lower(string(candidate)));
            reverse_narrow_strip_order = any(candidate == ["true","1","yes","y"]);
        else
            reverse_narrow_strip_order = logical(candidate);
        end
    end
catch
    log_debug('reverse_narrow_strip_order override ignored (parse error).');
end

if swap_narrow_top_bottom
    Qt_OG = v; % top narrow strips charge proxy
    Qb_OG = w; % bottom narrow strips charge proxy
    log_info('Run %d: narrow-strip channels swapped (Ib -> top, It -> bottom).', run);
else
    Qt_OG = w; % top narrow strips charge proxy
    Qb_OG = v; % bottom narrow strips charge proxy
    log_info('Run %d: narrow-strip channels in nominal order (It -> top, Ib -> bottom).', run);
end

%if reverse_narrow_strip_order
%    Qt_OG = fliplr(Qt_OG);
%    Qb_OG = fliplr(Qb_OG);
%    log_info('Run %d: reversed narrow-strip ordering to compensate cabling flip.', run);
%end


Q_thin_top_event_OG = sum(Qt_OG, 2); % total charge in the 5 narrow strips on the top side per event
Q_thin_bot_event_OG = sum(Qb_OG, 2); % total charge in the 5 narrow strips on the bottom side per event

%%

% Ancillary


% Ancillary


% Create a 6x4 figure showing the histograms per each narrow strip, that is, per each column of Qt_OG and Qb_OG.
% I want one figure for the top strips and another for the bottom strips. I want the same x axes limits for all
% histograms in each figure. Save to the debug_png_dir.

if should_plot
    make_histograms = @(data, label_prefix, fig_title, capture_tag) ...
        plot_narrow_strip_histograms(data, label_prefix, fig_title, capture_tag);

    make_histograms(Qt_OG, 'Top', sprintf('Top narrow-strip charges (run %s)', run_label), 'narrow_strip_top_hist');
    make_histograms(Qb_OG, 'Bottom', sprintf('Bottom narrow-strip charges (run %s)', run_label), 'narrow_strip_bottom_hist');
end

% Sum 10 to all Qt_OG and Qb_OG to avoid negative values
Qt_test = Qt_OG + charge_top_pedestal;
Qb_test = Qb_OG + charge_bot_pedestal;
Q_thin_top_event_test = sum(Qt_test, 2);
Q_thin_bot_event_test = sum(Qb_test, 2);
% Histogram them, thinner bars

% Create with linspace edges from 0 to 50000
edges = linspace(0, 50000, 150);

if should_plot
    fig = figure;
    histogram(Q_thin_top_event_test, edges, 'Normalization', 'probability', 'DisplayName','Top (pedestal adjusted)');
    hold on;
    histogram(Q_thin_bot_event_test, edges, 'Normalization', 'probability', 'DisplayName','Bottom (pedestal adjusted)');
    xlabel('Charge (ADC bins)');
    ylabel('Probability');
    title('Positive Charges (Thin)');
    grid on; box on;
    lg = legend('show', 'Location', 'northeast');
    ax = gca;
    set(fig, 'Color', [0 0 0]);
    set(ax, 'Color', [0 0 0], 'XColor', [1 1 1], 'YColor', [1 1 1], ...
        'GridColor', [0.4 0.4 0.4], 'MinorGridColor', [0.25 0.25 0.25]);
    if ~isempty(lg) && isgraphics(lg, 'legend')
        set(lg, 'Color', [0 0 0], 'EdgeColor', [1 1 1], 'TextColor', [1 1 1]);
    end
    capture_debug_png(fig, 'thin_charge_probability');
end

%%

% Pedestal addition
Qt_OG = Qt_OG + charge_top_pedestal;
Qb_OG = Qb_OG + charge_bot_pedestal;


%%

% % ---------------------------------------------------------------------
% % ---------------------------------------------------------------------
% % Time series plots for original data for comprobation
% % ---------------------------------------------------------------------
% % ---------------------------------------------------------------------

% % ---------------- Wide strips (timing) ----------------
% leading_front = {l30, l31, l32, l29, l28};
% trailing_front = {t30, t31, t32, t29, t28};
% leading_back  = {l3,  l2,  l1,  l4,  l5};
% trailing_back = {t3,  t2,  t1,  t4,  t5};

% labels_front = {'30','31','32','29','28'};
% labels_back  = {'3','2','1','4','5'};

% % ---------------- Narrow strips (charges) ----------------
% % Bottom (b) and top (t) strips
% b_labels = {'I','II','III','IV','V','VI','VII','VIII','IX','X','XI','XII', ...
%             'XIII','XIV','XV','XVI','XVII','XVIII','XIX','XX','XXI','XXII','XXIII','XXIV'};
% t_labels = b_labels;  % same indexing

% % Collect bottom and top charge arrays dynamically from base workspace
% b_vars = cell(1,numel(b_labels));
% t_vars = cell(1,numel(t_labels));
% for i = 1:numel(b_labels)
%     bname = sprintf('%sb', b_labels{i});
%     tname = sprintf('%st', t_labels{i});
%     if evalin('base', sprintf('exist(''%s'',''var'')', bname))
%         b_vars{i} = evalin('base', bname);
%     else
%         b_vars{i} = [];
%         warning('Missing variable: %s', bname);
%     end
%     if evalin('base', sprintf('exist(''%s'',''var'')', tname))
%         t_vars{i} = evalin('base', tname);
%     else
%         t_vars{i} = [];
%         warning('Missing variable: %s', tname);
%     end
% end

% % ---------------- Plot ----------------
% figure('Name','Original time series - timing and charges','Color','w');
% colors = lines(10);  % reusable color map

% % (1) Leading times - front wide strips
% subplot(6,1,1); hold on;
% for i = 1:numel(leading_front)
%     plot(leading_front{i}, 'Color', colors(i,:), 'LineWidth', 1.0);
% end
% title('Leading times - front wide strips (original data)');
% xlabel('Event index'); ylabel('Leading time (ns)');
% legend(strcat('l', labels_front), 'Location', 'best'); grid on;

% % (2) Trailing times - front wide strips
% subplot(6,1,2); hold on;
% for i = 1:numel(trailing_front)
%     plot(trailing_front{i}, 'Color', colors(i,:), 'LineWidth', 1.0);
% end
% title('Trailing times - front wide strips (original data)');
% xlabel('Event index'); ylabel('Trailing time (ns)');
% legend(strcat('t', labels_front), 'Location', 'best'); grid on;

% % (3) Leading times - back wide strips
% subplot(6,1,3); hold on;
% for i = 1:numel(leading_back)
%     plot(leading_back{i}, 'Color', colors(i,:), 'LineWidth', 1.0);
% end
% title('Leading times - back wide strips (original data)');
% xlabel('Event index'); ylabel('Leading time (ns)');
% legend(strcat('l', labels_back), 'Location', 'best'); grid on;

% % (4) Trailing times - back wide strips
% subplot(6,1,4); hold on;
% for i = 1:numel(trailing_back)
%     plot(trailing_back{i}, 'Color', colors(i,:), 'LineWidth', 1.0);
% end
% title('Trailing times - back wide strips (original data)');
% xlabel('Event index'); ylabel('Trailing time (ns)');
% legend(strcat('t', labels_back), 'Location', 'best'); grid on;

% % (5) Bottom charges (Ib ... XXIVb)
% subplot(6,1,5); hold on;
% for i = 1:numel(b_vars)
%     if ~isempty(b_vars{i})
%         plot(b_vars{i}, 'Color', colors(mod(i-1, size(colors,1))+1,:), 'LineWidth', 0.8);
%     end
% end
% title('Bottom charge signals - Ib ... XXIVb');
% xlabel('Event index'); ylabel('Charge amplitude (a.u.)');
% legend(strcat(b_labels, 'b'), 'Location', 'eastoutside', 'NumColumns', 2);
% grid on;

% % (6) Top charges (It ... XXIVt)
% subplot(6,1,6); hold on;
% for i = 1:numel(t_vars)
%     if ~isempty(t_vars{i})
%         plot(t_vars{i}, 'Color', colors(mod(i-1, size(colors,1))+1,:), 'LineWidth', 0.8);
%     end
% end
% title('Top charge signals - It ... XXIVt');
% xlabel('Event index'); ylabel('Charge amplitude (a.u.)');
% legend(strcat(t_labels, 't'), 'Location', 'eastoutside', 'NumColumns', 2);
% grid on;

% sgtitle('Time series for timing (wide strips) and charges (top/bottom narrow strips)');


%%

% ---------------------------------------------------------------------
% ---------------------------------------------------------------------
% Filtered Data Structuring
% ---------------------------------------------------------------------
% ---------------------------------------------------------------------

% -----------------------------------------------------------------------------
% Scintillator Timing and Charge Derivations
% -----------------------------------------------------------------------------

% Build matrices with leading/trailing edge times for each scintillator PMT
% and derive simple charge proxies and mean times per side.

Tl_cint = Tl_cint_OG;
Tt_cint = Tt_cint_OG;

% Count the number of events that not all Tl_cint(:,1:4) are zero
rawEvents = sum(any(Tl_cint(:,1:4) ~= 0, 2));

total_raw_events = rawEvents;

% If any value in Tl_cint or any value in Tt_cint is outside the expected range, put it to 0
Tl_cint(Tl_cint < lead_time_pmt_min | Tl_cint > lead_time_pmt_max) = 0;
Tt_cint(Tt_cint < trail_time_pmt_min | Tt_cint > trail_time_pmt_max) = 0;

Tl_cint(Tt_cint == 0) = 0;
Tt_cint(Tl_cint == 0) = 0;
Tl_cint(Tt_cint == 0) = 0;
Tt_cint(Tl_cint == 0) = 0;

cond_pmt_bot = ( abs(Tl_cint(:,1) - Tl_cint(:,2)) > time_pmt_diff_thr );
Tl_cint(cond_pmt_bot, 1) = 0;
Tl_cint(cond_pmt_bot, 2) = 0;

cond_pmt_top = ( abs(Tl_cint(:,3) - Tl_cint(:,4)) > time_pmt_diff_thr );
Tl_cint(cond_pmt_top, 3) = 0;
Tl_cint(cond_pmt_top, 4) = 0;

Tl_cint(Tt_cint == 0) = 0;
Tt_cint(Tl_cint == 0) = 0;
Tl_cint(Tt_cint == 0) = 0;
Tt_cint(Tl_cint == 0) = 0;



% Loop over tTH and plot % of good events
tTH_values = 1:0.1:7; % example range, adjust as needed
percent_good_events = zeros(size(tTH_values));

for i = 1:length(tTH_values)
    tTH_iter = tTH_values(i);
    restrictionsForPMTs_test = abs(Tl_cint(:,1)-Tl_cint(:,2)) < tTH_iter & ...
                                abs(Tl_cint(:,1)-Tl_cint(:,3)) < tTH_iter & ...
                                abs(Tl_cint(:,1)-Tl_cint(:,4)) < tTH_iter & ...
                                abs(Tl_cint(:,2)-Tl_cint(:,3)) < tTH_iter & ...
                                abs(Tl_cint(:,2)-Tl_cint(:,4)) < tTH_iter & ...
                                abs(Tl_cint(:,3)-Tl_cint(:,4)) < tTH_iter;
    percent_good_events(i) = 100 * length(find(restrictionsForPMTs_test)) / rawEvents;
end

if should_plot
    fig = figure;
    plot(tTH_values, percent_good_events, '-o'); hold on;
    % vertical line at tTH, orange dashed, thicker
    xline(tTH, '--', 'tTH chosen', ...
          'Color', [1 0.5 0], ...
          'LineWidth', 1.8, ...
          'LabelVerticalAlignment', 'middle', ...
          'LabelHorizontalAlignment', 'center');
    xlabel('tTH [ns]');
    ylabel('% of good events');
    title('Good events vs tTH');
    capture_debug_png(fig, 'tth_selection');
end


% ---------- PMT timing consistency ----------
% Treat any NaN as false by requiring all 4 times to be finite in the row.
% All pairwise diffs < tTH  <=> (max - min) < tTH

restrictionsForPMTs_comp = abs(Tl_cint(:,1)-Tl_cint(:,2)) > tTH | ...
                        abs(Tl_cint(:,1)-Tl_cint(:,3)) > tTH | ...
                        abs(Tl_cint(:,1)-Tl_cint(:,4)) > tTH | ...
                        abs(Tl_cint(:,2)-Tl_cint(:,3)) > tTH | ...
                        abs(Tl_cint(:,2)-Tl_cint(:,4)) > tTH | ...
                        abs(Tl_cint(:,3)-Tl_cint(:,4)) > tTH;

% Take the complementary mask
restrictionsForPMTs = ~restrictionsForPMTs_comp;

% Put to zero the Tl_cint and Tt_cint where restrictionsForPMTs is false
Tl_cint(~restrictionsForPMTs, :) = 0;
Tt_cint(~restrictionsForPMTs, :) = 0;

% Update the whole row
Tl_cint(Tt_cint == 0) = 0;
Tt_cint(Tl_cint == 0) = 0;
Tl_cint(Tt_cint == 0) = 0;
Tt_cint(Tl_cint == 0) = 0;

% Count the number of events that not all Tl_cint(:,1:4) are zero after filtering
filteredEvents = sum(any(Tl_cint(:,1:4) ~= 0, 2));
percentage_good_events_in_pmts = 100 * filteredEvents / rawEvents;
log_info('PMT filtering | raw events=%d | kept=%d (%.2f%%)', total_raw_events, filteredEvents, percentage_good_events_in_pmts);

%channels 1 and 2 -> bottom PMTs
Qcint = [Tt_cint(:,1) - Tl_cint(:,1) Tt_cint(:,2) - Tl_cint(:,2) Tt_cint(:,3) - Tl_cint(:,3) Tt_cint(:,4) - Tl_cint(:,4)]; 

% If Qcint(:,1) == 0, put Qcint(:,2) = 0, if Qcint(:,2) == 0, put Qcint(:,1) = 0
Qcint(Qcint(:,1) == 0, 2) = 0;  % if col1 is 0 -> set col2 to 0 (same rows)
Qcint(Qcint(:,2) == 0, 1) = 0;  % if col2 is 0 -> set col1 to 0 (same rows)
Qcint(Qcint(:,1) == 0, 2) = 0;  % if col1 is 0 -> set col2 to 0 (same rows)
Qcint(Qcint(:,2) == 0, 1) = 0;  % if col2 is 0 -> set col1 to 0 (same rows)

Qcint(Qcint(:,3) == 0, 4) = 0;  % if col1 is 0 -> set col2 to 0 (same rows)
Qcint(Qcint(:,4) == 0, 3) = 0;  % if col2 is 0 -> set col1 to 0 (same rows)
Qcint(Qcint(:,3) == 0, 4) = 0;  % if col1 is 0 -> set col2 to 0 (same rows)
Qcint(Qcint(:,4) == 0, 3) = 0;  % if col2 is 0 -> set col1 to 0 (same rows)


%%


% -----------------------------------------------------------------------------
% RPC WIDE STRIP Timing and Charge Derivations
% -----------------------------------------------------------------------------

% Try this, if it does not work, then store the channels from 24 to 28, and print a warning
% that the channel order is not as expected. So it was changed to the 24-28 order.
TFl = TFl_OG; % tempos leadings front [ns]; chs [32,28] -> 5 strips gordas front
TFt = TFt_OG; % tempos trailings front [ns]
TBl = TBl_OG; %leading times back [ns]; channels [1,5] -> 5 wide back strips
TBt = TBt_OG; %trailing times back [ns]

% Filter out-of-bounds times
TFl(TFl < lead_time_wide_strip_min | TFl > lead_time_wide_strip_max) = 0;
TFt(TFt < trail_time_wide_strip_min | TFt > trail_time_wide_strip_max) = 0;
TBl(TBl < lead_time_wide_strip_min | TBl > lead_time_wide_strip_max) = 0;
TBt(TBt < trail_time_wide_strip_min | TBt > trail_time_wide_strip_max) = 0;

% Go column-wise (strip-wise) and where TBt == 0, put TBl = 0; where TBl == 0, put TBt = 0
% where TFt == 0, put TFl = 0; where TFl == 0, put TFt = 0
TBl(TBt == 0) = 0;
TBt(TBl == 0) = 0;
TBl(TBt == 0) = 0;
TBt(TBl == 0) = 0;

TFl(TFt == 0) = 0;
TFt(TFl == 0) = 0;
TFl(TFt == 0) = 0;
TFt(TFl == 0) = 0;

TBl(TFl == 0) = 0;
TFl(TBl == 0) = 0;
TBl(TFl == 0) = 0;
TFl(TBl == 0) = 0;

TBl(TBt == 0) = 0;
TBt(TBl == 0) = 0;
TBl(TBt == 0) = 0;
TBt(TBl == 0) = 0;

TFl(TFt == 0) = 0;
TFt(TFl == 0) = 0;
TFl(TFt == 0) = 0;
TFt(TFl == 0) = 0;

TBl(TFl == 0) = 0;
TFl(TBl == 0) = 0;
TBl(TFl == 0) = 0;
TFl(TBl == 0) = 0;

clearvars l32 l31 l30 l29 l28 t32 t31 t30 t29 t28 l1 l2 l3 l4 l5 t1 t2 t3 t4 t5 l11 l12 l9 l10 t11 t12 t9 t10 

% Charge proxies per strip (front/back)
QF  = TFt - TFl;
QB  = TBt - TBl;

% Zero BOTH QF and QB wherever |QF - QB| > threshold (column-wise, all 5 strips)
msk = (abs(QF - QB) > charge_wide_strip_diff_thr);   % same size as QF/QB (Nx5)
QF(msk) = 0;
QB(msk) = 0;

QF(QB == 0) = 0;
QB(QF == 0) = 0;

rawEvents = size(TFl,1);




% -----------------------------------------------------------------------------
% RPC charges for the five NARROW STRIPS, which do not carry timing info.
% -----------------------------------------------------------------------------

Qt = Qt_OG; % top narrow strips charge proxy
Qb = Qb_OG; % bottom narrow strips charge proxy

% Filter out-of-bounds charges
Qt(Qt < charge_narrow_strip_min | Qt > charge_narrow_strip_max) = 0;
Qb(Qb < charge_narrow_strip_min | Qb > charge_narrow_strip_max) = 0;

clearvars v w
clearvars Ib IIb IIIb IVb Vb VIb VIIb VIIIb IXb Xb XIb XIIb XIIIb XIVb XVb XVIb XVIIb XVIIIb XIXb XXb XXIb XXIIb XXIIIb XXIVb It IIt IIIt IVt Vt VIt VIIt VIIIt IXt Xt XIt XIIt XIIIt XIVt XVt XVIt XVIIt XVIIIt XIXt XXt XXIt XXIIt XXIIIt XXIVt

% Charge sum over all narrow strips per event
Q_thin_top_event = sum(Qt, 2); % total charge in the 5 narrow strips on the top side per event
Q_thin_bot_event = sum(Qb, 2); % total charge in the 5 narrow strips on the bottom side per event



%%


% ---------------------------------------------------------------------
% ---------------------------------------------------------------------
% Wide strip calibrations
% ---------------------------------------------------------------------
% ---------------------------------------------------------------------


% For the original events only ----------------------------------------
QB_p_OG = QB_OG - QB_offsets .* (QB_OG ~= 0);
QF_p_OG = QF_OG - QF_offsets .* (QF_OG ~= 0);

% calculation of maximum charges and RAW position as a function of Qmax
% calculation of maximum charges and RAW position as a function of Qmax
[QFmax_OG,XFmax_OG] = max(QF_p_OG,[],2);    %XFmax -> strip of Qmax
[QBmax_OG,XBmax_OG] = max(QB_p_OG,[],2);

% Keep only events where the strip with maximum charge matches on both faces
Ind2Cut_OG   = find(~isnan(QF_p_OG) & ~isnan(QB_p_OG) & XFmax_OG == XBmax_OG);
[row_OG,col_OG] = ind2sub(size(TFl_OG),Ind2Cut_OG); %row=evento com Qmax na mesma strip; col=strip não interessa pois fica-se com a strip com Qmax
rows_OG      = unique(row_OG); %events sorted and without repetitions
Ind2Keep_OG  = sub2ind(size(TFl_OG),rows_OG,XFmax_OG(rows_OG)); %indices of the Qmax values, provided QFmax and QBmax are on the same strip

T_OG = nan(rawEvents,1); Q_OG = nan(rawEvents,1); X_OG = nan(rawEvents,1); Y_OG = nan(rawEvents,1);
T_OG(rows_OG) = (TFl_OG(Ind2Keep_OG) + TBl_OG(Ind2Keep_OG)) / 2; %[ns]
Q_OG(rows_OG) = (QF_p_OG(Ind2Keep_OG) + QB_p_OG(Ind2Keep_OG)) /2;    %[ns] sum of Qmax front and back -> contains NaNs if an event fails the Ind2Keep condition
X_OG(rows_OG) = XFmax_OG(rows_OG);  %strip number where Qmax is found (1 to 5)
Y_OG(rows_OG) = (TFl_OG(Ind2Keep_OG) - TBl_OG(Ind2Keep_OG)) / 2; %[ns]

X_thick_strip_OG = X_OG; %redefine X_thick_strip to be the strip number with maximum charge
Y_thick_strip_OG = Y_OG; %redefine Y_thick_strip to be the Y position with maximum charge
T_thick_strip_OG = T_OG; %redefine T_thick_strip to be the T from the strip with maximum charge
Q_thick_strip_OG = Q_OG; %redefine Q_thick_event to be the Q from the strip with maximum charge


% For the good events only --------------------------------------------
QB_p = QB - QB_offsets .* (QB ~= 0);
QF_p = QF - QF_offsets .* (QF ~= 0);

% calculation of maximum charges and RAW position as a function of Qmax
[QFmax,XFmax] = max(QF_p,[],2);    %XFmax -> strip of Qmax
[QBmax,XBmax] = max(QB_p,[],2);

% Keep only events where the strip with maximum charge matches on both faces
Ind2Cut   = find(~isnan(QF_p) & ~isnan(QB_p) & XFmax == XBmax);
[row,col] = ind2sub(size(TFl),Ind2Cut); %row=evento com Qmax na mesma strip; col=strip não interessa pois fica-se com a strip com Qmax
rows      = unique(row); %events sorted and without repetitions
Ind2Keep  = sub2ind(size(TFl),rows,XFmax(rows)); %indices of the Qmax values, provided QFmax and QBmax are on the same strip

T = nan(rawEvents,1); Q = nan(rawEvents,1); X = nan(rawEvents,1); Y = nan(rawEvents,1);
T(rows) = (TFl(Ind2Keep) + TBl(Ind2Keep)) / 2; %[ns]
Q(rows) = (QF_p(Ind2Keep) + QB_p(Ind2Keep)) /2;    %[ns] sum of Qmax front and back -> contains NaNs if an event fails the Ind2Keep condition
X(rows) = XFmax(rows);  %strip number where Qmax is found (1 to 5)
Y(rows) = (TFl(Ind2Keep) - TBl(Ind2Keep)) / 2; %[ns]

X_thick_strip = X; %redefine X_thick_strip to be the strip number with maximum charge
Y_thick_strip = Y; %redefine Y_thick_strip to be the Y position with maximum charge
T_thick_strip = T; %redefine T_thick_strip to be the T from the strip with maximum charge
Q_thick_event = Q; %redefine Q_thick_event to be the Q from the strip with maximum charge



%%

% ---------------------------------------------------------------------
% ---------------------------------------------------------------------
% Definition of new detasets
% ---------------------------------------------------------------------
% ---------------------------------------------------------------------


% ---------------------------------------------------------------------
% ==================== Signal EVENTS (zero-out others) ================
% ---------------------------------------------------------------------

% Create masks------------------------------------------------------------
validEvents_signal = (Qcint_OG(:,1) ~= 0) & (Qcint_OG(:,2) ~= 0) & (Qcint_OG(:,3) ~= 0) & (Qcint_OG(:,4) ~= 0);


% Apply masks ------------------------------------------------------------

% --- PMTs --- N x 4
Qcint_signal = zeros(size(Qcint_OG), 'like', Qcint_OG);
Qcint_signal(validEvents_signal, :) = Qcint_OG(validEvents_signal, :);

T_cint_1_signal = zeros(size(Tl_cint_OG), 'like', Tl_cint_OG);
T_cint_2_signal = zeros(size(Tl_cint_OG), 'like', Tl_cint_OG);
T_cint_3_signal = zeros(size(Tl_cint_OG), 'like', Tl_cint_OG);
T_cint_4_signal = zeros(size(Tl_cint_OG), 'like', Tl_cint_OG);
T_cint_1_signal(validEvents_signal) = Tl_cint_OG(validEvents_signal, 1);
T_cint_2_signal(validEvents_signal) = Tl_cint_OG(validEvents_signal, 2);
T_cint_3_signal(validEvents_signal) = Tl_cint_OG(validEvents_signal, 3);
T_cint_4_signal(validEvents_signal) = Tl_cint_OG(validEvents_signal, 4);
T_cint_top_signal = (T_cint_3_signal + T_cint_4_signal) / 2;
T_cint_bot_signal = (T_cint_1_signal + T_cint_2_signal) / 2;

% --- THICK (event-level) --- N x 1
X_thick_strip_signal = zeros(size(X_thick_strip_OG), 'like', X_thick_strip_OG);
Y_thick_strip_signal = zeros(size(Y_thick_strip_OG), 'like', Y_thick_strip_OG);
T_thick_strip_signal = zeros(size(T_thick_strip_OG), 'like', T_thick_strip_OG);
Q_thick_strip_signal = zeros(size(Q_thick_strip_OG), 'like', Q_thick_strip_OG);
X_thick_strip_signal(validEvents_signal) = X_thick_strip_OG(validEvents_signal);
Y_thick_strip_signal(validEvents_signal) = Y_thick_strip_OG(validEvents_signal);
T_thick_strip_signal(validEvents_signal) = T_thick_strip_OG(validEvents_signal);
Q_thick_strip_signal(validEvents_signal) = Q_thick_strip_OG(validEvents_signal);

% --- THIN STRIPS --- N x 24
Qb_signal = zeros(size(Qb_OG), 'like', Qb_OG);
Qt_signal = zeros(size(Qt_OG), 'like', Qt_OG);
Qb_signal(validEvents_signal, :) = Qb_OG(validEvents_signal, :);
Qt_signal(validEvents_signal, :) = Qt_OG(validEvents_signal, :);

% Totals per event --- N x 1
Q_thin_top_event_signal = sum(Qt_signal, 2);
Q_thin_bot_event_signal = sum(Qb_signal, 2);



% ---------------------------------------------------------------------
% ==================== COIN VALID EVENTS (zero-out others) ============
% ---------------------------------------------------------------------

% Create masks------------------------------------------------------------
validEvents_coin = (Qcint(:,1) ~= 0) & (Qcint(:,2) ~= 0) & (Qcint(:,3) ~= 0) & (Qcint(:,4) ~= 0);


% Apply masks ------------------------------------------------------------

% --- PMTs --- N x 4
Qcint_coin = zeros(size(Qcint_OG), 'like', Qcint_OG);
Qcint_coin(validEvents_coin, :) = Qcint_OG(validEvents_coin, :);

T_cint_1_coin = zeros(size(Tl_cint_OG), 'like', Tl_cint_OG);
T_cint_2_coin = zeros(size(Tl_cint_OG), 'like', Tl_cint_OG);
T_cint_3_coin = zeros(size(Tl_cint_OG), 'like', Tl_cint_OG);
T_cint_4_coin = zeros(size(Tl_cint_OG), 'like', Tl_cint_OG);
T_cint_1_coin(validEvents_coin) = Tl_cint_OG(validEvents_coin, 1);
T_cint_2_coin(validEvents_coin) = Tl_cint_OG(validEvents_coin, 2);
T_cint_3_coin(validEvents_coin) = Tl_cint_OG(validEvents_coin, 3);
T_cint_4_coin(validEvents_coin) = Tl_cint_OG(validEvents_coin, 4);
T_cint_top_coin = (T_cint_3_coin + T_cint_4_coin) / 2;
T_cint_bot_coin = (T_cint_1_coin + T_cint_2_coin) / 2;

% --- THICK (event-level) --- N x 1
X_thick_strip_coin = zeros(size(X_thick_strip_OG), 'like', X_thick_strip_OG);
Y_thick_strip_coin = zeros(size(Y_thick_strip_OG), 'like', Y_thick_strip_OG);
T_thick_strip_coin = zeros(size(T_thick_strip_OG), 'like', T_thick_strip_OG);
Q_thick_strip_coin = zeros(size(Q_thick_strip_OG), 'like', Q_thick_strip_OG);
X_thick_strip_coin(validEvents_coin) = X_thick_strip_OG(validEvents_coin);
Y_thick_strip_coin(validEvents_coin) = Y_thick_strip_OG(validEvents_coin);
T_thick_strip_coin(validEvents_coin) = T_thick_strip_OG(validEvents_coin);
Q_thick_strip_coin(validEvents_coin) = Q_thick_strip_OG(validEvents_coin);

% --- THIN STRIPS --- N x 24
Qb_coin = zeros(size(Qb_OG), 'like', Qb_OG);
Qt_coin = zeros(size(Qt_OG), 'like', Qt_OG);
Qb_coin(validEvents_coin, :) = Qb_OG(validEvents_coin, :);
Qt_coin(validEvents_coin, :) = Qt_OG(validEvents_coin, :);

% Totals per event --- N x 1
Q_thin_top_event_coin = sum(Qt_coin, 2);
Q_thin_bot_event_coin = sum(Qb_coin, 2);



% ---------------------------------------------------------------------
% ==================== GOOD VALID EVENTS (zero-out others) ============
% ---------------------------------------------------------------------

% Create masks---------------------------------------------------------
validEvents_good = validEvents_coin; % Same as before


% Apply masks ---------------------------------------------------------

% --- PMTs --- N x 4
Qcint_good = zeros(size(Qcint), 'like', Qcint);
Qcint_good(validEvents_good, :) = Qcint(validEvents_good, :);
Qcint_top_good = Qcint_good(:,3) + Qcint_good(:,4);
Qcint_bot_good = Qcint_good(:,1) + Qcint_good(:,2);

T_cint_1_good = zeros(size(Tl_cint(:,1)), 'like', Tl_cint(:,1));
T_cint_2_good = zeros(size(Tl_cint(:,2)), 'like', Tl_cint(:,2));
T_cint_3_good = zeros(size(Tl_cint(:,3)), 'like', Tl_cint(:,3));
T_cint_4_good = zeros(size(Tl_cint(:,4)), 'like', Tl_cint(:,4));
T_cint_1_good(validEvents_good) = Tl_cint(validEvents_good, 1);
T_cint_2_good(validEvents_good) = Tl_cint(validEvents_good, 2);
T_cint_3_good(validEvents_good) = Tl_cint(validEvents_good, 3);
T_cint_4_good(validEvents_good) = Tl_cint(validEvents_good, 4);
T_cint_top_good = (T_cint_3_good + T_cint_4_good) / 2;
T_cint_bot_good = (T_cint_1_good + T_cint_2_good) / 2;

% --- THICK ---
X_thick_strip_good = zeros(size(X_thick_strip), 'like', X_thick_strip);
Y_thick_strip_good = zeros(size(Y_thick_strip), 'like', Y_thick_strip);
T_thick_strip_good = zeros(size(T_thick_strip), 'like', T_thick_strip);
Q_thick_strip_good = zeros(size(Q_thick_event), 'like', Q_thick_event);
X_thick_strip_good(validEvents_good, :) = X_thick_strip(validEvents_good, :);
Y_thick_strip_good(validEvents_good, :) = Y_thick_strip(validEvents_good, :);
T_thick_strip_good(validEvents_good, :) = T_thick_strip(validEvents_good, :);
Q_thick_strip_good(validEvents_good) = Q_thick_event(validEvents_good);

% Extra, only for calibration checking
QF_good = zeros(size(QF), 'like', QF);
QB_good = zeros(size(QB), 'like', QB);
QF_p_good = zeros(size(QF_p), 'like', QF_p);
QB_p_good = zeros(size(QB_p), 'like', QB_p);
QF_good(validEvents_good, :) = QF(validEvents_good, :);
QB_good(validEvents_good, :) = QB(validEvents_good, :);
QF_p_good(validEvents_good, :) = QF_p(validEvents_good, :);
QB_p_good(validEvents_good, :) = QB_p(validEvents_good, :);

% --- THIN STRIPS ---
Qb_good = zeros(size(Qb), 'like', Qb);
Qt_good = zeros(size(Qt), 'like', Qt);
Qb_good(validEvents_good, :) = Qb(validEvents_good, :);
Qt_good(validEvents_good, :) = Qt(validEvents_good, :);

% Totals per event --- N x 1
Q_thin_top_event_good = sum(Qt_good, 2);
Q_thin_bot_event_good = sum(Qb_good, 2);



% ------------------------------------------------------------------------
% ==================== RANGE EVENTS (zero-out others) ====================
% ------------------------------------------------------------------------

% Create masks------------------------------------------------------------
log_debug('Calculating PMT charge thresholds for run 0 based on 20th and 80th percentiles.');
Q_pmt_1 = Qcint_good(:,1);
Q_pmt_2 = Qcint_good(:,2);
Q_pmt_3 = Qcint_good(:,3);
Q_pmt_4 = Qcint_good(:,4);

pmt_1_charge_threshold_min = prctile(Q_pmt_1(Q_pmt_1>0), percentile_pmt); % ADCbins
pmt_1_charge_threshold_max = prctile(Q_pmt_1(Q_pmt_1>0), 100 - percentile_pmt); % ADCbins
pmt_2_charge_threshold_min = prctile(Q_pmt_2(Q_pmt_2>0), percentile_pmt); % ADCbins
pmt_2_charge_threshold_max = prctile(Q_pmt_2(Q_pmt_2>0), 100 - percentile_pmt); % ADCbins
pmt_3_charge_threshold_min = prctile(Q_pmt_3(Q_pmt_3>0), percentile_pmt); % ADCbins
pmt_3_charge_threshold_max = prctile(Q_pmt_3(Q_pmt_3>0), 100 - percentile_pmt); % ADCbins
pmt_4_charge_threshold_min = prctile(Q_pmt_4(Q_pmt_4>0), percentile_pmt); % ADCbins
pmt_4_charge_threshold_max = prctile(Q_pmt_4(Q_pmt_4>0), 100 - percentile_pmt); % ADCbins

validEvents_range = ...
    (Qcint(:,1) >= pmt_1_charge_threshold_min) & (Qcint(:,1) <= pmt_1_charge_threshold_max) & ...
    (Qcint(:,2) >= pmt_2_charge_threshold_min) & (Qcint(:,2) <= pmt_2_charge_threshold_max) & ...
    (Qcint(:,3) >= pmt_3_charge_threshold_min) & (Qcint(:,3) <= pmt_3_charge_threshold_max) & ...
    (Qcint(:,4) >= pmt_4_charge_threshold_min) & (Qcint(:,4) <= pmt_4_charge_threshold_max);

% Apply masks ------------------------------------------------------------

% --- PMTs --- N x 4
Qcint_range = zeros(size(Qcint_good), 'like', Qcint_good);
Qcint_range(validEvents_range, :) = Qcint_good(validEvents_range, :);

T_cint_1_range = zeros(size(Tl_cint), 'like', Tl_cint);
T_cint_2_range = zeros(size(Tl_cint), 'like', Tl_cint);
T_cint_3_range = zeros(size(Tl_cint), 'like', Tl_cint);
T_cint_4_range = zeros(size(Tl_cint), 'like', Tl_cint);
T_cint_1_range(validEvents_range) = Tl_cint(validEvents_range, 1);
T_cint_2_range(validEvents_range) = Tl_cint(validEvents_range, 2);
T_cint_3_range(validEvents_range) = Tl_cint(validEvents_range, 3);
T_cint_4_range(validEvents_range) = Tl_cint(validEvents_range, 4);
T_cint_top_range = (T_cint_3_range + T_cint_4_range) / 2;
T_cint_bot_range = (T_cint_1_range + T_cint_2_range) / 2;

% --- THICK STRIPS --- N x 1
X_thick_strip_range = zeros(size(X_thick_strip_good), 'like', X_thick_strip_good);
Y_thick_strip_range = zeros(size(Y_thick_strip_good), 'like', Y_thick_strip_good);
T_thick_strip_range = zeros(size(T_thick_strip_good), 'like', T_thick_strip_good);
Q_thick_strip_range = zeros(size(Q_thick_strip_good), 'like', Q_thick_strip_good);
X_thick_strip_range(validEvents_range, :) = X_thick_strip_good(validEvents_range, :);
Y_thick_strip_range(validEvents_range, :) = Y_thick_strip_good(validEvents_range, :);
T_thick_strip_range(validEvents_range, :) = T_thick_strip_good(validEvents_range, :);

Q_thick_strip_range(validEvents_range) = Q_thick_strip_good(validEvents_range);

% --- THIN STRIPS --- N x 24
Qb_range = zeros(size(Qb_good), 'like', Qb_good);
Qt_range = zeros(size(Qt_good), 'like', Qt_good);
Qb_range(validEvents_range, :) = Qb_good(validEvents_range, :);
Qt_range(validEvents_range, :) = Qt_good(validEvents_range, :);

% Totals per event --- N x 1
Q_thin_top_event_range = sum(Qt_range, 2);
Q_thin_bot_event_range = sum(Qb_range, 2);



% ------------------------------------------------------------------------
% ==================== NO CROSSTALK EVENTS (zero-out others) =============
% ------------------------------------------------------------------------

% Create masks------------------------------------------------------------
validEventsFiltered_PMT = ...
    (Q_pmt_1 >= pmt_1_charge_threshold_min) & (Q_pmt_1 <= pmt_1_charge_threshold_max) & ...
    (Q_pmt_2 >= pmt_2_charge_threshold_min) & (Q_pmt_2 <= pmt_2_charge_threshold_max) & ...
    (Q_pmt_3 >= pmt_3_charge_threshold_min) & (Q_pmt_3 <= pmt_3_charge_threshold_max) & ...
    (Q_pmt_4 >= pmt_4_charge_threshold_min) & (Q_pmt_4 <= pmt_4_charge_threshold_max);
validEventsFiltered_thick = (Q_thick_strip_good >= thick_strip_crosstalk);
validEventsFiltered_thin_top = (Q_thin_top_event_good >= top_narrow_strip_crosstalk);
validEventsFiltered_thin_bot = (Q_thin_bot_event_good >= bot_narrow_strip_crosstalk);


% Apply masks ------------------------------------------------------------
% --- PMTs --- N x 4
Qcint_no_crosstalk = zeros(size(Qcint_good), 'like', Qcint_good);
Qcint_no_crosstalk(validEventsFiltered_PMT, :) = Qcint_good(validEventsFiltered_PMT, :);

% --- THICK STRIPS --- N x 1
X_thick_strip_no_crosstalk = zeros(size(X_thick_strip_good), 'like', X_thick_strip_good);
Y_thick_strip_no_crosstalk = zeros(size(Y_thick_strip_good), 'like', Y_thick_strip_good);
T_thick_strip_no_crosstalk = zeros(size(T_thick_strip_good), 'like', T_thick_strip_good);
Q_thick_strip_no_crosstalk = zeros(size(Q_thick_strip_good), 'like', Q_thick_strip_good);
X_thick_strip_no_crosstalk(validEventsFiltered_thick, :) = X_thick_strip_good(validEventsFiltered_thick, :);
Y_thick_strip_no_crosstalk(validEventsFiltered_thick, :) = Y_thick_strip_good(validEventsFiltered_thick, :);
T_thick_strip_no_crosstalk(validEventsFiltered_thick, :) = T_thick_strip_good(validEventsFiltered_thick, :);
Q_thick_strip_no_crosstalk(validEventsFiltered_thick) = Q_thick_event(validEventsFiltered_thick);

% --- THIN STRIPS --- N x 24
Qb_no_crosstalk = zeros(size(Qb_good), 'like', Qb_good);
Qt_no_crosstalk = zeros(size(Qt_good), 'like', Qt_good);
Qb_no_crosstalk(validEventsFiltered_thin_bot, :) = Qb_good(validEventsFiltered_thin_bot, :);
Qt_no_crosstalk(validEventsFiltered_thin_top, :) = Qt_good(validEventsFiltered_thin_top, :);

% Totals per event --- N x 1
Q_thin_top_event_no_crosstalk = zeros(size(Q_thin_top_event_good), 'like', Q_thin_top_event_good);
Q_thin_bot_event_no_crosstalk = zeros(size(Q_thin_bot_event_good), 'like', Q_thin_bot_event_good);
Q_thin_top_event_no_crosstalk(validEventsFiltered_thin_top) = Q_thin_top_event_good(validEventsFiltered_thin_top);
Q_thin_bot_event_no_crosstalk(validEventsFiltered_thin_bot) = Q_thin_bot_event_good(validEventsFiltered_thin_bot);

%%


% ---------------------------------------------------------------------
% ---------------------------------------------------------------------
% Definitions for histograms and plots
% ---------------------------------------------------------------------
% ---------------------------------------------------------------------

% Quantile limits (thin channels share limits)
q005_b_raw = quantile(Q_thin_bot_event_good, 0.01);
q95_b_raw  = quantile(Q_thin_bot_event_good, 0.99);
[q005_b, q95_b] = ensure_axis_limits(q005_b_raw, q95_b_raw);

q005_t_raw = quantile(Q_thin_top_event_good, 0.01);
q95_t_raw  = quantile(Q_thin_top_event_good, 0.99);
[q005_t, q95_t] = ensure_axis_limits(q005_t_raw, q95_t_raw);

[q005, q95] = ensure_axis_limits(min(q005_b, q005_t), max(q95_b, q95_t));

% Thick channel limits (separate scale)
t_lead_back_left = min(quantile(TBl, 0.001));
t_lead_front_left = min(quantile(TFl, 0.001));
t_lead_left = min(t_lead_back_left, t_lead_front_left);
t_lead_back_right = min(quantile(TBl, 0.999));
t_lead_front_right = min(quantile(TFl, 0.999));
t_lead_right = max(t_lead_back_right, t_lead_front_right);
[t_lead_left, t_lead_right] = ensure_axis_limits(t_lead_left, t_lead_right);

t_trail_back_left = min(quantile(TBt, 0.001));
t_trail_front_left = min(quantile(TFt, 0.001));
t_trail_left = min(t_trail_back_left, t_trail_front_left);
t_trail_back_right = min(quantile(TBt, 0.999));
t_trail_front_right = min(quantile(TFt, 0.999));
t_trail_right = max(t_trail_back_right, t_trail_front_right);
[t_trail_left, t_trail_right] = ensure_axis_limits(t_trail_left, t_trail_right);

t005_thick_raw = quantile(T_thick_strip_good, 0.001);
t95_thick_raw  = quantile(T_thick_strip_good, 0.999);
[t005_thick, t95_thick] = ensure_axis_limits(t005_thick_raw, t95_thick_raw);
q005_thick_raw = quantile(Q_thick_strip_good, 0.001);
q95_thick_raw  = quantile(Q_thick_strip_good, 0.999);
[q005_thick, q95_thick] = ensure_axis_limits(q005_thick_raw, q95_thick_raw);

% Bin edges (match your "like this" snippet for thin; keep fine bins for thick)
bin_number = 150; % number of bins
thinTopEdges  = linspace(q005, q95, bin_number); % 100 bins between 0.5% and 95% quantiles
thinBotEdges  = linspace(q005, q95, bin_number); % 100 bins between 0.5% and 95% quantiles
thickEdges    = linspace(q005_thick, q95_thick, bin_number); % 100 bins between 0.5% and 95% quantiles


% Create a non_zero version called Q_thick_strip_good_hist
% THICK
Q_thick_strip_signal_hist = Q_thick_strip_signal;
Q_thick_strip_signal_hist(Q_thick_strip_signal_hist == 0) = []; % remove zeros for histogram
Q_thick_strip_good_hist = Q_thick_strip_good;
Q_thick_strip_good_hist(Q_thick_strip_good_hist == 0) = []; % remove zeros for histogram

% THIN TOP
Q_thin_bot_event_signal_hist = Q_thin_bot_event_signal;
Q_thin_bot_event_signal_hist(Q_thin_bot_event_signal_hist == 0) = []; % remove zeros for histogram
Q_thin_bot_event_good_hist = Q_thin_bot_event_good;
Q_thin_bot_event_good_hist(Q_thin_bot_event_good_hist == 0) = []; % remove zeros for histogram

% THIN BOTTOM
Q_thin_top_event_signal_hist = Q_thin_top_event_signal;
Q_thin_top_event_signal_hist(Q_thin_top_event_signal_hist == 0) = []; % remove zeros for histogram
Q_thin_top_event_good_hist = Q_thin_top_event_good;
Q_thin_top_event_good_hist(Q_thin_top_event_good_hist == 0) = []; % remove zeros for histogram


% PMT quantiles
lead_samples = nonzeros(Tl_cint);
if isempty(lead_samples), lead_samples = nonzeros(Tl_cint_OG); end
if isempty(lead_samples), lead_samples = Tl_cint(:); end
if isempty(lead_samples), lead_samples = Tl_cint_OG(:); end
t005_pmt = quantile(lead_samples, 0.001);
t95_pmt  = quantile(lead_samples, 0.999);

trail_samples = nonzeros(Tt_cint);
if isempty(trail_samples), trail_samples = nonzeros(Tt_cint_OG); end
if isempty(trail_samples), trail_samples = Tt_cint(:); end
if isempty(trail_samples), trail_samples = Tt_cint_OG(:); end
t005_pmt_trail = quantile(trail_samples, 0.001);
t95_pmt_trail  = quantile(trail_samples, 0.999);

q005_pmt = quantile(Qcint_good(Qcint_good > 0), 0.01);
q95_pmt  = quantile(Qcint_good(Qcint_good > 0), 0.95);
binning_pmt = linspace(q005_pmt, q95_pmt, bin_number); % 100 bins between 0.5% and 95% quantiles

lead_time_limits_pmt  = [t005_pmt t95_pmt];
trail_time_limits_pmt = [t005_pmt_trail t95_pmt_trail];
charge_limits_pmt     = [q005_pmt q95_pmt];

SCATTER_LIMIT_MARGIN = 0.10;
thin_top_scatter_limits = expand_axis_limits([q005_t q95_t], SCATTER_LIMIT_MARGIN);
thin_bottom_scatter_limits = expand_axis_limits([q005_b q95_b], SCATTER_LIMIT_MARGIN);
thin_shared_scatter_limits = expand_axis_limits([q005 q95], SCATTER_LIMIT_MARGIN);
thick_scatter_limits = expand_axis_limits([q005_thick q95_thick], SCATTER_LIMIT_MARGIN);
lead_time_limits_pmt_scatter = expand_axis_limits(lead_time_limits_pmt, SCATTER_LIMIT_MARGIN);
trail_time_limits_pmt_scatter = expand_axis_limits(trail_time_limits_pmt, SCATTER_LIMIT_MARGIN);
charge_limits_pmt_scatter = expand_axis_limits(charge_limits_pmt, SCATTER_LIMIT_MARGIN);


%%


% ---------------------------------------------------------------------
% ---------------------------------------------------------------------
% Timing studies ------------------------------------------------------
% ---------------------------------------------------------------------
% ---------------------------------------------------------------------


timing_studies = false;
if timing_studies && should_plot && should_plot


    % Slewing correction on the PMTs
    diff_top = T_cint_3_good - T_cint_4_good;
    sum_top = T_cint_3_good + T_cint_4_good;

    diff_bot = T_cint_1_good - T_cint_2_good;
    sum_bot = T_cint_1_good + T_cint_2_good;

    mask_diff_top = isfinite(diff_top) & (diff_top ~= 0) & (abs(diff_top) < 20);
    mask_diff_bot = isfinite(diff_bot) & (diff_bot ~= 0) & (abs(diff_bot) < 20);

    q1 = Qcint_good(:,1);
    q2 = Qcint_good(:,2);
    q3 = Qcint_good(:,3);
    q4 = Qcint_good(:,4); 

    % apply mask
    q1_m = q1(mask_diff_bot);
    q2_m = q2(mask_diff_bot);
    q3_m = q3(mask_diff_top);
    q4_m = q4(mask_diff_top);
    diff_top_m = diff_top(mask_diff_top);
    sum_top_m = sum_top(mask_diff_top);
    diff_bot_m = diff_bot(mask_diff_bot);
    sum_bot_m = sum_bot(mask_diff_bot);


    % Check correlation of the time difference in the same scint with the sum of times.
    % Should be no correlation ideally

    if should_plot
        fig = figure;
        tiledlayout(1,2, 'TileSpacing', 'compact', 'Padding', 'compact');

        nexttile;
        hold on;
        scatter(sum_top_m, diff_top_m, 20, [0.2 0.8 0.2], '.');        % Sum PMT3 + PMT4
        hold off;
        % Print legend
        legend({'PMT3 + PMT4'}, 'Location','best');
        xlabel('Sum of Times PMT3 - PMT4 [ns]');
        ylabel('Time Difference PMT3 - PMT4 [ns]');
        title(sprintf('Time Difference vs Sum of Times, Top scint (run %s)', formatted_datetime_tex));
        grid on; box on;

        nexttile;
        hold on;
        scatter(sum_bot_m, diff_bot_m, 20, [0.2 0.8 0.2], '.');        % Sum PMT1 + PMT2
        hold off;
        % Print legend
        legend({'PMT1 + PMT2'}, 'Location','best');
        xlabel('Sum of Times PMT1 - PMT2 [ns]');
        ylabel('Time Difference PMT1 - PMT2 [ns]');
        title(sprintf('Time Difference vs Sum of Times, Bottom scint (run %s)', formatted_datetime_tex));
        grid on; box on;
        capture_debug_png(fig, 'timing_sum_vs_difference');
    end
    

    % Slewing correction (linear fit), fit
    % diff_bot_corr_1 = diff_bot - F(q1)
    % diff_bot_corr_2 = diff_bot - F(q2)
    % diff_top_corr_3 = diff_top - F(q3)
    % diff_top_corr_4 = diff_top - F(q4)


    % --- Choose polynomial degree once ---
    deg = 1;   % change to 2, 3, ... for higher-order fits

    % --- Fits with clipping (per pair, consistent masks) ---
    % PMT1 vs diff_bot_m
    [pmt1_fit_coeffs, q1_use, d1_use] = polyfit_clipped(q1_m, diff_bot_m, 80, 150, deg);

    % PMT2 vs diff_bot_m
    [pmt2_fit_coeffs, q2_use, d2_use] = polyfit_clipped(q2_m, diff_bot_m, 80, 150, deg);

    % PMT3 vs diff_top_m
    [pmt3_fit_coeffs, q3_use, d3_use] = polyfit_clipped(q3_m, diff_top_m, 80, 300, deg);

    % PMT4 vs diff_top_m
    [pmt4_fit_coeffs, q4_use, d4_use] = polyfit_clipped(q4_m, diff_top_m, 80, 120, deg);

    % --- Apply correction using polyval (works for any degree) ---
    % Apply correction only where charge is non-zero (and finite)
    diff_top_corr_3 = diff_top;
    mask3 = isfinite(q3) & (q3 ~= 0);
    if any(mask3)
        diff_top_corr_3(mask3) = diff_top(mask3) - polyval(pmt3_fit_coeffs, q3(mask3));
    end

    diff_top_corr_4 = diff_top;
    mask4 = isfinite(q4) & (q4 ~= 0);
    if any(mask4)
        diff_top_corr_4(mask4) = diff_top(mask4) - polyval(pmt4_fit_coeffs, q4(mask4));
    end

    diff_bot_corr_1 = diff_bot;
    mask1 = isfinite(q1) & (q1 ~= 0);
    if any(mask1)
        diff_bot_corr_1(mask1) = diff_bot(mask1) - polyval(pmt1_fit_coeffs, q1(mask1));
    end

    diff_bot_corr_2 = diff_bot;
    mask2 = isfinite(q2) & (q2 ~= 0);
    if any(mask2)
        diff_bot_corr_2(mask2) = diff_bot(mask2) - polyval(pmt2_fit_coeffs, q2(mask2));
    end

    % apply masks you already have
    diff_top_corr_3_m = diff_top_corr_3(mask_diff_top);
    diff_top_corr_4_m = diff_top_corr_4(mask_diff_top);
    diff_bot_corr_1_m = diff_bot_corr_1(mask_diff_bot);
    diff_bot_corr_2_m = diff_bot_corr_2(mask_diff_bot);

    if should_plot
        % --- Plots (before/after) ---
        fig = figure;
        tiledlayout(2,2, 'TileSpacing', 'compact', 'Padding', 'compact');

        ylimits = [-4 4];

        % ---- TOP: raw vs q3,q4 with polynomial overlays
        nexttile; hold on; grid on; box on;
        scatter(q3_m, diff_top_m, 20, [0.2 0.2 0.8], '.');   % PMT3
        scatter(q4_m, diff_top_m, 20, [0.8 0.6 0.0], '.');   % PMT4
        xfit_top_3 = linspace(min(q3_use), max(q3_use), 200);
        xfit_top_4 = linspace(min(q4_use), max(q4_use), 200);
        plot(xfit_top_3, polyval(pmt3_fit_coeffs, xfit_top_3), 'b--', 'LineWidth', 2);
        plot(xfit_top_4, polyval(pmt4_fit_coeffs, xfit_top_4), 'r--', 'LineWidth', 2);
        ylim(ylimits);
        legend({'PMT3','PMT4'}, 'Location','best');
        xlabel('PMT Charge [ADCbins]');
        ylabel('Time Difference PMT3 - PMT4 [ns]');
        title(sprintf('Time Diff vs PMT Charge (raw) — deg = %d', deg));
        hold off;

        % ---- BOTTOM: raw vs q1,q2 with polynomial overlays
        nexttile; hold on; grid on; box on;
        scatter(q1_m, diff_bot_m, 20, [0.2 0.2 0.8], '.');   % PMT1
        scatter(q2_m, diff_bot_m, 20, [0.8 0.6 0.0], '.');   % PMT2
        xfit_bot_1 = linspace(max(q1_use), min([q1_use; q2_use]), 200);
        xfit_bot_2 = linspace(max([q1_use; q2_use]), min([q1_use; q2_use]), 200);
        plot(xfit_bot_1, polyval(pmt1_fit_coeffs, xfit_bot_1), 'b--', 'LineWidth', 2);
        plot(xfit_bot_2, polyval(pmt2_fit_coeffs, xfit_bot_2), 'r--', 'LineWidth', 2);
        ylim(ylimits);
        legend({'PMT1','PMT2'}, 'Location','best');
        xlabel('PMT Charge [ADCbins]');
        ylabel('Time Difference PMT1 - PMT2 [ns]');
        title(sprintf('Time Diff vs PMT Charge (raw) — deg = %d', deg));
        hold off;

        % ---- TOP: corrected
        nexttile; hold on; grid on; box on;
        scatter(q3_m, diff_top_corr_3_m, 20, [0.2 0.2 0.8], '.');   % PMT3
        scatter(q4_m, diff_top_corr_4_m, 20, [0.8 0.6 0.0], '.');   % PMT4
        ylim(ylimits);
        legend({'PMT3','PMT4'}, 'Location','best');
        xlabel('PMT Charge [ADCbins]');
        ylabel('Corrected Time Difference (TOP) [ns]');
        title('After charge correction (TOP)');
        hold off;

        % ---- BOTTOM: corrected
        nexttile; hold on; grid on; box on;
        scatter(q1_m, diff_bot_corr_1_m, 20, [0.2 0.2 0.8], '.');   % PMT1
        scatter(q2_m, diff_bot_corr_2_m, 20, [0.8 0.6 0.0], '.');   % PMT2
        ylim(ylimits);
        legend({'PMT1','PMT2'}, 'Location','best');
        xlabel('PMT Charge [ADCbins]');
        ylabel('Corrected Time Difference (BOTTOM) [ns]');
        title('After charge correction (BOTTOM)');
        hold off;
        capture_debug_png(fig, 'pmt_slewing_overview');


        % ========================
        %  HISTOGRAMS: before vs after correction (fixed binning)
        % =========================
        fig_hist = figure('Name','Time-difference histograms before/after correction');
        tiledlayout(2,1,'TileSpacing','compact','Padding','compact');

        % Common binning
        edges = linspace(-5, 5, 251);  % n bins from -5 to 5

        % ---- TOP detector ----
        nexttile;
        hold on; grid on; box on;
        histogram(diff_top_m, edges, ...
            'FaceColor', [0.4 0.4 0.9], 'FaceAlpha', 0.5, 'DisplayName','Before correction');
        histogram(diff_top_corr_3_m, edges, 'FaceColor', [0.9 0.4 0.4], 'FaceAlpha', 0.5, 'DisplayName','After correction, PMT 3');
        histogram(diff_top_corr_4_m, edges, 'FaceColor', [1 1 1], 'FaceAlpha', 0.5, 'DisplayName','After correction, PMT 4');
        xlabel('Time difference TOP [ns]');
        ylabel('Counts');
        legend('Location','best');
        title('TOP time difference distribution — before vs after correction');
        xlim([-5 5]);

        % ---- BOTTOM detector ----
        nexttile;
        hold on; grid on; box on;
        histogram(diff_bot_m, edges, ...
            'FaceColor', [0.4 0.4 0.9], 'FaceAlpha', 0.5, 'DisplayName','Before correction');
        histogram(diff_bot_corr_1_m, edges, 'FaceColor', [0.9 0.4 0.4], 'FaceAlpha', 0.5, 'DisplayName','After correction, PMT 1');
        histogram(diff_bot_corr_2_m, edges, 'FaceColor', [1 1 1], 'FaceAlpha', 0.5, 'DisplayName','After correction, PMT 2');
        xlabel('Time difference BOTTOM [ns]');
        ylabel('Counts');
        legend('Location','best');
        title('BOTTOM time difference distribution — before vs after correction');
        xlim([-5 5]);

        sgtitle(sprintf('Time difference improvement after charge correction (run %s)', run_label));
        capture_debug_png(fig_hist, 'pmt_slewing_histograms');
    end



    %%

    % Now, calculated the time difference after correction, if I ask you to compute the time sum instead,
    % I want you to get a value corrected by the fact that the time difference was corrected.

    % Top PMTs
    diff_top = T_cint_3_good - T_cint_4_good;
    % require both PMTs finite and non-zero and diff within range
    mask_diff_top = isfinite(diff_top) & (diff_top ~= 0) & ...
                    isfinite(T_cint_3_good) & (T_cint_3_good ~= 0) & ...
                    isfinite(T_cint_4_good) & (T_cint_4_good ~= 0) & ...
                    (abs(diff_top) < 20);

    % Initialize corrected arrays as copies of the originals
    T_cint_3_corr = T_cint_3_good;
    T_cint_4_corr = T_cint_4_good;

    % Compute per-event deltas and apply only where mask_diff_top is true
    delta3 = 0.5 * (diff_top - diff_top_corr_3);
    delta4 = 0.5 * (diff_top - diff_top_corr_4);

    valid_top_idx = mask_diff_top & isfinite(delta3) & isfinite(delta4);
    T_cint_3_corr(valid_top_idx) = T_cint_3_good(valid_top_idx) - delta3(valid_top_idx);
    T_cint_4_corr(valid_top_idx) = T_cint_4_good(valid_top_idx) + delta4(valid_top_idx);

    % Build sum only for corrected (non-zero) entries; zero elsewhere
    sum_top_corr = zeros(size(T_cint_3_good));
    sum_top_corr(valid_top_idx) = ( T_cint_3_corr(valid_top_idx) + T_cint_4_corr(valid_top_idx) ) / 2;

    % Bottom PMTs
    diff_bot = T_cint_1_good - T_cint_2_good;
    % require both PMTs finite and non-zero and diff within range
    mask_diff_bot = isfinite(diff_bot) & (diff_bot ~= 0) & ...
                    isfinite(T_cint_1_good) & (T_cint_1_good ~= 0) & ...
                    isfinite(T_cint_2_good) & (T_cint_2_good ~= 0) & ...
                    (abs(diff_bot) < 20);

    % Initialize corrected arrays as copies of the originals
    T_cint_1_corr = T_cint_1_good;
    T_cint_2_corr = T_cint_2_good;

    % Compute per-event deltas and apply only where mask_diff_bot is true
    delta1 = 0.5 * (diff_bot - diff_bot_corr_1);
    delta2 = 0.5 * (diff_bot - diff_bot_corr_2);

    valid_bot_idx = mask_diff_bot & isfinite(delta1) & isfinite(delta2);
    T_cint_1_corr(valid_bot_idx) = T_cint_1_good(valid_bot_idx) - delta1(valid_bot_idx);
    T_cint_2_corr(valid_bot_idx) = T_cint_2_good(valid_bot_idx) + delta2(valid_bot_idx);

    % Build sum only for corrected (non-zero) entries; zero elsewhere
    sum_bot_corr = zeros(size(T_cint_1_good));
    sum_bot_corr(valid_bot_idx) = ( T_cint_1_corr(valid_bot_idx) + T_cint_2_corr(valid_bot_idx) ) / 2;

    T_cint_bot_corr = sum_bot_corr;
    T_cint_top_corr = sum_top_corr;

    time_diff_sum = T_cint_bot_good - T_cint_top_good;
    time_diff_sum_corr = T_cint_bot_corr - T_cint_top_corr;

    if should_plot
        fig = figure('Name','Time Difference Sum — Before/After with Gaussian fits (scaled properly)');
        nexttile; hold on; grid on; box on;

        % Data and mask
        m = mask_diff_bot & mask_diff_top;
        td_before = time_diff_sum(m);
        td_after  = time_diff_sum_corr(m);

        % Common binning
        edges = linspace(-3, 3, 351);
        binCenters = edges(1:end-1) + diff(edges)/2;

        % --- Histogram counts (manual, not histogram object) ---
        [counts_b,~] = histcounts(td_before, edges);
        [counts_a,~] = histcounts(td_after,  edges);

        % --- Fit Gaussian directly to histogram (counts vs bin centers) ---
        gauss_fun = @(b, x) b(1) * exp(-0.5*((x - b(2))/b(3)).^2);  % b = [amplitude, mean, sigma]

        % Initial guesses
        b0_b = [max(counts_b), mean(td_before), std(td_before)];
        b0_a = [max(counts_a), mean(td_after),  std(td_after)];

        % Fit via fminsearch
        error_func_b = @(b) sum((counts_b - gauss_fun(b, binCenters)).^2);
        error_func_a = @(b) sum((counts_a - gauss_fun(b, binCenters)).^2);

        opts = optimset('Display', 'off');
        bfit_b = fminsearch(error_func_b, b0_b, opts);
        bfit_a = fminsearch(error_func_a, b0_a, opts);

        % --- Evaluate fits for plotting ---
        xfit = linspace(edges(1), edges(end), 600);
        yfit_b = gauss_fun(bfit_b, xfit);
        yfit_a = gauss_fun(bfit_a, xfit);

        % --- Plot histograms (counts) ---
        bar(binCenters, counts_b, 1, 'FaceColor',[0.4 0.4 0.9], 'FaceAlpha',0.4, 'EdgeColor','none', 'DisplayName','Before correction');
        bar(binCenters, counts_a, 1, 'FaceColor',[0.9 0.4 0.4], 'FaceAlpha',0.4, 'EdgeColor','none', 'DisplayName','After correction');

        % --- Overlay fits (perfectly scaled) ---
        plot(xfit, yfit_b, 'b-', 'LineWidth',2, ...
            'DisplayName', sprintf('Gaussian before: \\mu=%.3f, \\sigma=%.3f', bfit_b(2), bfit_b(3)));
        plot(xfit, yfit_a, 'r-', 'LineWidth',2, ...
            'DisplayName', sprintf('Gaussian after: \\mu=%.3f, \\sigma=%.3f', bfit_a(2), bfit_a(3)));

        xlabel('Time Difference Sum (Bottom - Top) [ns]');
        ylabel('Counts');
        title(sprintf('Time Difference Sum — Before vs After correction (run %s)', formatted_datetime_tex));
        xlim([-3 3]);
        legend('Location','best');
        capture_debug_png(fig, 'time_diff_sum_gaussian');
    end


    %%


    % The proper slewing correction should be performed here: we have
    % T_cint_bot_corr, T_cint_top_corr and T_thick_strip_good

    time_diff_TOP_BOT = T_cint_bot_corr - T_cint_top_corr;

    time_diff_RPC_TOP = T_thick_strip_good - T_cint_top_corr;
    time_diff_RPC_BOT = T_thick_strip_good - T_cint_bot_corr;

    charge_RPC = Q_thick_strip_good;
    charge_TOP = Qcint_top_good;
    charge_BOT = Qcint_bot_good;

    if should_plot
        % Plot in 1 row and 3 cols the scatter plots of time differences vs charges
        fig = figure;
        tiledlayout(1,3, 'TileSpacing', 'compact', 'Padding', 'compact');
        % (1) TOP - BOT vs PMT charges
        nexttile;
        hold on;
        scatter(charge_BOT, time_diff_TOP_BOT, 20, [0.2 0.2 0.8], '.'); % PMT Bottom
        scatter(charge_TOP, time_diff_TOP_BOT, 20, [0.2 0.8 0.2], '.'); % PMT Top
        hold off;
        legend({'PMT_Bottom', 'PMT_Top'}, 'Location', 'best');
        xlabel('Scintillator Charges [ADCbins]');
        ylabel('Time Difference TOP - BOT [ns]');
        title('TOP - BOT vs PMT Charges');
        grid on; box on;
        
        % (2) RPC - TOP vs PMT Top and RPC
        nexttile;
        hold on;
        scatter(charge_TOP, time_diff_RPC_TOP, 20, [0.2 0.8 0.2], '.'); % PMT Top
        scatter(charge_RPC, time_diff_RPC_TOP, 20, [0.8 0.2 0.2], '.'); % RPC
        hold off;
        legend({'PMT_Top', 'RPC'}, 'Location', 'best');
        xlabel('Scintillator Charges [ADCbins]');
        ylabel('Time Difference RPC - TOP [ns]');
        title('RPC - TOP vs PMT Top and RPC');
        grid on; box on;

        % (3) RPC - BOT vs PMT Bottom and RPC
        nexttile;
        hold on;
        scatter(charge_BOT, time_diff_RPC_BOT, 20, [0.2 0.2 0.8], '.'); % PMT Bottom
        scatter(charge_RPC, time_diff_RPC_BOT, 20, [0.8 0.2 0.2], '.'); % RPC
        hold off;
        legend({'PMT_Bottom', 'RPC'}, 'Location', 'best');
        xlabel('Scintillator Charges [ADCbins]');
        ylabel('Time Difference RPC - BOT [ns]');
        title('RPC - BOT vs PMT Bottom and RPC');
        grid on; box on;

        sgtitle(sprintf('Time Differences vs Charges after Slewing Correction (run %s)', formatted_datetime_tex));
        adjust_three_panel_row_figure(fig, slide_mode);
        capture_debug_png(fig, 'slewing_scatter_triptych');
    end


    %%


    % ========= Slewing correction for THICK STRIP using RPC charge =========
    % Inputs already available in your workspace:
    %   T_thick_strip_good, T_cint_top_corr, T_cint_bot_corr
    %   Q_thick_strip_good
    %   (Optionally your masks; we build fresh masks here)

    % Time differences (RPC relative to corrected TOP/BOT)
    time_diff_RPC_TOP = T_thick_strip_good - T_cint_top_corr;  % RPC - TOP
    time_diff_RPC_BOT = T_thick_strip_good - T_cint_bot_corr;  % RPC - BOT
    charge_RPC        = Q_thick_strip_good;

    % Masks: finite diffs & charges; optional diff range to exclude outliers
    m_rt = isfinite(time_diff_RPC_TOP) & isfinite(charge_RPC) & time_diff_RPC_TOP~=0 & abs(time_diff_RPC_TOP) < 20;
    m_rb = isfinite(time_diff_RPC_BOT) & isfinite(charge_RPC) & time_diff_RPC_BOT~=0 & abs(time_diff_RPC_BOT) < 20;

    % ---- Choose polynomial degree and fit window in charge (RPC charge) ----
    deg_rpc  = 1;                 % change to 2, 3, ... if needed
    lo_rpc   = prctile(charge_RPC(m_rt|m_rb),  1);   % or hardcode e.g. 200
    hi_rpc   = prctile(charge_RPC(m_rt|m_rb), 99);   % or hardcode e.g. 2000

    % ---- Fit D = f(Qrpc) separately for RPC-TOP and RPC-BOT (robust 2-pass) ----
    [p_rt, Qrt_use, Drt_use] = polyfit_clipped_new(time_diff_RPC_TOP(m_rt), charge_RPC(m_rt), lo_rpc, hi_rpc, deg_rpc, 'x_on_y'); % fit D vs Q
    [p_rb, Qrb_use, Drb_use] = polyfit_clipped_new(time_diff_RPC_BOT(m_rb), charge_RPC(m_rb), lo_rpc, hi_rpc, deg_rpc, 'x_on_y');

    % Predicted slewing components
    D_rt_fit = nan(size(time_diff_RPC_TOP));
    D_rb_fit = nan(size(time_diff_RPC_BOT));
    D_rt_fit(m_rt) = polyval(p_rt, charge_RPC(m_rt));
    D_rb_fit(m_rb) = polyval(p_rb, charge_RPC(m_rb));

    % Correct the differences -> decorrelate from charge
    D_rt_corr = time_diff_RPC_TOP - D_rt_fit;   % RPC - TOP (charge-independent)
    D_rb_corr = time_diff_RPC_BOT - D_rb_fit;   % RPC - BOT (charge-independent)

    % Per-event deltas to apply to the RPC timestamp
    % (We attribute slewing to the RPC; scintillator times were already corrected)
    delta_rt = time_diff_RPC_TOP - D_rt_corr;   % equals D_rt_fit on m_rt
    delta_rb = time_diff_RPC_BOT - D_rb_corr;   % equals D_rb_fit on m_rb

    % Combine TOP/BOT information without double-correcting:
    % If both available, average; if only one, use that one; else 0.
    w_rt = double(m_rt);
    w_rb = double(m_rb);
    wsum = w_rt + w_rb;
    wsum(wsum==0) = 1;  % avoid div by zero
    delta_rpc = (w_rt.*delta_rt + w_rb.*delta_rb) ./ wsum;
    delta_rpc(~(m_rt | m_rb)) = 0;   % no correction where we had no fit support

    % ---- Recover the corrected RPC timestamps ----
    T_thick_strip_rpc_corr = T_thick_strip_good - delta_rpc;

    % (Optional) Recompute the decorrelated differences to verify
    time_diff_RPC_TOP_corr = T_thick_strip_rpc_corr - T_cint_top_corr;
    time_diff_RPC_BOT_corr = T_thick_strip_rpc_corr - T_cint_bot_corr;

    % ========= Quick checks / plots =========
    if should_plot
        fig_rpc_fit = figure('Name','RPC slewing vs RPC charge');
        tiledlayout(1,2,'TileSpacing','compact','Padding','compact');

        % RPC - TOP
        nexttile; hold on; grid on; box on;
        scatter(charge_RPC(m_rt), time_diff_RPC_TOP(m_rt), 6, '.', 'MarkerEdgeAlpha',0.35);
        qfit = linspace(lo_rpc, hi_rpc, 200);
        plot(qfit, polyval(p_rt, qfit), 'r--', 'LineWidth', 1.8);
        xlabel('RPC charge [ADCbins]'); ylabel('RPC - TOP [ns]');
        title(sprintf('RPC-TOP fit (deg=%d)', deg_rpc)); hold off;

        % RPC - BOT
        nexttile; hold on; grid on; box on;
        scatter(charge_RPC(m_rb), time_diff_RPC_BOT(m_rb), 6, '.', 'MarkerEdgeAlpha',0.35);
        plot(qfit, polyval(p_rb, qfit), 'r--', 'LineWidth', 1.8);
        xlabel('RPC charge [ADCbins]'); ylabel('RPC - BOT [ns]');
        title(sprintf('RPC-BOT fit (deg=%d)', deg_rpc)); hold off;
        capture_debug_png(fig_rpc_fit, 'rpc_slewing_vs_charge');

        fig_rpc_corr = figure('Name','After slewing correction (vs RPC charge)');
        tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
        nexttile; hold on; grid on; box on;
        scatter(charge_RPC(m_rt), time_diff_RPC_TOP_corr(m_rt), 6, '.', 'MarkerEdgeAlpha',0.35);
        xlabel('RPC charge [ADCbins]'); ylabel('RPC - TOP (corr) [ns]');
        title('RPC-TOP after correction'); yline(0,'k:'); hold off;

        nexttile; hold on; grid on; box on;
        scatter(charge_RPC(m_rb), time_diff_RPC_BOT_corr(m_rb), 6, '.', 'MarkerEdgeAlpha',0.35);
        xlabel('RPC charge [ADCbins]'); ylabel('RPC - BOT (corr) [ns]');
        title('RPC-BOT after correction'); yline(0,'k:'); hold off;
        capture_debug_png(fig_rpc_corr, 'rpc_slewing_corrected');
    end


    %%


    T_thick_strip_slew_corr = T_thick_strip_rpc_corr;
    T_cint_top_slew_corr = T_cint_top_corr;
    T_cint_bot_slew_corr = T_cint_bot_corr;

    % Compute time differences and apply a common mask
    % time_diff_SC1_SC2 = T_cint_bot_good - T_cint_top_good;
    % time_diff_RPC_SC1 = T_thick_strip_good - T_cint_top_good;
    % time_diff_RPC_SC2 = T_thick_strip_good - T_cint_bot_good;

    time_diff_SC1_SC2 = T_cint_bot_slew_corr - T_cint_top_slew_corr;
    time_diff_RPC_SC1 = T_thick_strip_slew_corr - T_cint_top_slew_corr;
    time_diff_RPC_SC2 = T_thick_strip_slew_corr - T_cint_bot_slew_corr;

    % Common mask: valid and non-zero time differences
    mask_td = isfinite(time_diff_SC1_SC2) & isfinite(time_diff_RPC_SC1) & isfinite(time_diff_RPC_SC2) & ...
            (time_diff_SC1_SC2 ~= 0) & (time_diff_RPC_SC1 ~= 0) & (time_diff_RPC_SC2 ~= 0) & ...
            (abs(time_diff_SC1_SC2) < 50) & (abs(time_diff_RPC_SC1) < 50) & (abs(time_diff_RPC_SC2) < 50) & ...
            (abs(time_diff_SC1_SC2) > 0.2) & (abs(time_diff_RPC_SC1) > 0.2) & (abs(time_diff_RPC_SC2) > 0.2);
    
    % mask_td = true(size(time_diff_SC1_SC2));  % for testing without mask
    
    % x-values: total PMT charge (row-wise) and individual PMT charges
    qbot = Qcint_good(:,1) + Qcint_good(:,2);
    qtop = Qcint_good(:,3) + Qcint_good(:,4);
    qrpc = Q_thick_strip_good;

    % Apply the common mask
    qbot_m = qbot(mask_td);
    qtop_m = qtop(mask_td);
    qrpc_m = qrpc(mask_td);
    td_SC1_SC2_m = time_diff_SC1_SC2(mask_td);
    td_RPC_SC1_m = time_diff_RPC_SC1(mask_td);
    td_RPC_SC2_m = time_diff_RPC_SC2(mask_td);

    % Plot the three scatter plots in a single row
    if should_plot
        fig = figure;
        tiledlayout(1,3, 'TileSpacing', 'compact', 'Padding', 'compact');

        % (1) SC2 - SC1 vs PMT charges
        nexttile;
        hold on;
        scatter(qbot_m, td_SC1_SC2_m, 20, [0.2 0.2 0.8], '.'); % PMT Bottom
        scatter(qtop_m, td_SC1_SC2_m, 20, [0.2 0.8 0.2], '.'); % PMT Top
        hold off;
        legend({'PMT_Bottom', 'PMT_Top'}, 'Location', 'best');
        xlabel('Sum of Scintillator Charges [ADCbins]');
        ylabel('Time Difference SC2 - SC1 [ns]');
        title('SC2 - SC1 vs PMT Charges');
        grid on; box on;

        % (2) RPC - SC1 vs PMT Top and RPC
        nexttile;
        hold on;
        scatter(qtop_m, td_RPC_SC1_m, 20, [0.2 0.8 0.2], '.'); % PMT Top
        scatter(qrpc_m, td_RPC_SC1_m, 20, [0.8 0.2 0.2], '.'); % RPC
        hold off;
        legend({'PMT_Top', 'RPC'}, 'Location', 'best');
        xlabel('Sum of Scintillator Charges [ADCbins]');
        ylabel('Time Difference RPC - SC1 [ns]');
        title('RPC - SC1 vs PMT Top and RPC');
        grid on; box on;

        % (3) RPC - SC2 vs PMT Bottom and RPC
        nexttile;
        hold on;
        scatter(qbot_m, td_RPC_SC2_m, 20, [0.2 0.2 0.8], '.'); % PMT Bottom
        scatter(qrpc_m, td_RPC_SC2_m, 20, [0.8 0.2 0.2], '.'); % RPC
        hold off;
        legend({'PMT_Bottom', 'RPC'}, 'Location', 'best');
        xlabel('Sum of Scintillator Charges [ADCbins]');
        ylabel('Time Difference RPC - SC2 [ns]');
        title('RPC - SC2 vs PMT Bottom and RPC');
        grid on; box on;

        sgtitle(sprintf('Time Differences vs Charges (run %s)', formatted_datetime_tex));
        adjust_three_panel_row_figure(fig, slide_mode);
        capture_debug_png(fig, 'time_diff_vs_charges');
    end


    %%


    % Fit a single Gaussian to each of the three time-difference distributions
    td_sets = { td_RPC_SC1_m, td_RPC_SC2_m, td_SC1_SC2_m };
    td_labels = {'RPC - SC1', 'RPC - SC2', 'SC2 - SC1'};
    td_colors = {[1 0 0], [0 0.6 0], [1 0.5 0]};   % red/green/orange
    nbins = 100;  % histogram bins for fitting
    opts = optimset('Display','off','TolX',1e-6,'TolFun',1e-6,'MaxIter',2000,'MaxFunEvals',2000);

    fit_results = repmat(struct('amp',NaN,'mu',NaN,'sigma',NaN,'FWHM',NaN), 1, numel(td_sets));

    did_plot_time_fits = false;
    hist_handles = gobjects(0);
    hist_labels = {};
    if should_plot
        fig_timefits = figure;
        hold on;
        did_plot_time_fits = true;
    end

    for ii = 1:numel(td_sets)
        td = td_sets{ii};
        % sanitize
        td = td(isfinite(td) & ~isnan(td));
        if isempty(td)
            warning('Time-diff %s empty, skipping fit.', td_labels{ii});
            continue;
        end

        % histogram (probability normalization)
        lo = prctile(td, 0.1);
        hi = prctile(td, 99.9);
        if lo == hi
            lo = min(td); hi = max(td);
            if lo == hi
                lo = lo - 1; hi = hi + 1;
            end
        end
        edges = linspace(lo, hi, nbins+1);
        p = histcounts(td, edges, 'Normalization', 'probability');
        centers = edges(1:end-1) + diff(edges)/2;

        % initial guess: amplitude, mean, sigma
        [~, imax] = max(p);
        amp0 = p(imax);
        mu0 = centers(imax);
        sigma0 = max(std(td), (edges(2)-edges(1))*2);

        gauss = @(par,x) par(1) * exp(-((x - par(2)).^2) ./ (2 * par(3).^2));

        err = @(par) sum((p - gauss(par, centers)).^2);

        par0 = [amp0, mu0, sigma0];
        parFit = fminsearch(err, par0, opts);

        amp_fit = parFit(1);
        mu_fit = parFit(2);
        sigma_fit = abs(parFit(3)); % ensure positive
        FWHM = 2*sqrt(2*log(2)) * sigma_fit;

        fit_results(ii).amp = amp_fit;
        fit_results(ii).mu = mu_fit;
        fit_results(ii).sigma = sigma_fit;
        fit_results(ii).FWHM = FWHM;

        if should_plot
            % Plot histogram (stairs) and fitted Gaussian (smooth)
            h_stairs = stairs(centers, p, 'Color', td_colors{ii}, 'LineWidth', 1.0);
            hist_handles(end+1) = h_stairs; %#ok<AGROW>
            hist_labels{end+1} = td_labels{ii}; %#ok<AGROW>
            xfit = linspace(min(centers), max(centers), 1000);
            yfit = gauss([amp_fit, mu_fit, sigma_fit], xfit);
            plot(xfit, yfit, 'Color', td_colors{ii}, 'LineWidth', 2, 'HandleVisibility','off');

            % annotate on plot
            sigma_ps = round(sigma_fit * 1e3);
            txt = sprintf('%s: \\sigma=%.0f ps', td_labels{ii}, sigma_ps);
            % place text progressively to avoid overlap, below peak
            range = max(centers) - min(centers);
            tx = min(centers) + 0.05*range;
            ty = max(p) * (0.75 - 0.2*(ii-1));
            text(tx, ty, txt, 'Color', td_colors{ii}, 'FontSize', 11, 'Interpreter','tex', 'BackgroundColor',[0 0 0], 'Margin',2, 'EdgeColor','none');
        end
    end

    if should_plot && did_plot_time_fits
        xlabel('Time Difference [ns]');
        ylabel('Probability');
        if ~isempty(hist_handles)
            legend(hist_handles, hist_labels, 'Location','northwest');
        end
        title(sprintf('Time Difference Histograms and Gaussian fits (run %s)', formatted_datetime_tex));
        grid on; box on;
        capture_debug_png(fig_timefits, 'time_diff_gaussian_fits');
        hold off;
    end

    % Print fit summary
    for ii = 1:3
        log_debug('%s fit: mu=%.4f ns | sigma=%.4f ns | FWHM=%.4f ns', ...
            td_labels{ii}, fit_results(ii).mu, fit_results(ii).sigma, fit_results(ii).FWHM);
    end


    % Assume the PMTs time resolutions are identical
    sigma_RPC_SC1 = fit_results(1).sigma;
    sigma_RPC_SC2 = fit_results(2).sigma;
    sigma_SC1_SC2 = fit_results(3).sigma;

    sigma_RPC_SC = (sigma_RPC_SC1 + sigma_RPC_SC2) / 2;
    sigma_SC = sigma_SC1_SC2 / sqrt(2);

    sigma_RPC = sqrt( (sigma_RPC_SC^2) - (sigma_SC^2) );

    log_info('Time resolution estimates under equal-PMT assumption | RPC=%.0f ps | SC=%.0f ps', sigma_RPC*1000, sigma_SC*1000);

end



%%


% ---------------------------------------------------------------------
% ---------------------------------------------------------------------
% Quick Visual Checks
% ---------------------------------------------------------------------
% ---------------------------------------------------------------------

% -----------------------------------------------------------------------------
% Scintillator Timing and Charge Derivations
% -----------------------------------------------------------------------------

% Plot scatter plots of Tl_cint i vs Tl_cint j for all PMT pairs to verify the
% coincidence cut. In the same figure the 6 pairs

if should_plot
    fig = figure('Units','normalized','Position',[0.12 0.15 0.76 0.7]);
    tl = tiledlayout(2, 2, 'TileSpacing','compact','Padding','compact');
    for p = 1:4
        nexttile(tl);
        plot(Tl_cint_OG(:,p), Tt_cint_OG(:,p), '.'); hold on;
        plot(Tl_cint(:,p), Tt_cint(:,p), '.');
        xlabel(sprintf('Tl PMT%d', p));
        ylabel(sprintf('Tt PMT%d', p));
        title(sprintf('Lead/trail PMT%d', p));
        xlim(lead_time_limits_pmt_scatter); ylim(trail_time_limits_pmt_scatter);
        xline(lead_time_pmt_min, 'r--'); xline(lead_time_pmt_max, 'r--');
        yline(trail_time_pmt_min, 'r--'); yline(trail_time_pmt_max, 'r--');
    end
    sgtitle(sprintf('PMT time lead vs trail (run %s)', formatted_datetime_tex));
    capture_debug_png(fig, 'pmt_time_lead_trail');
end

% Now plot the charge correlations for the same PMT pairs
if should_plot
    fig = figure;
    subplot(1,2,1); plot(Qcint_OG(:,1), Qcint_OG(:,2), '.'); hold on; plot(Qcint(:,1), Qcint(:,2), '.');
    xlabel('Qcint1'); ylabel('Qcint2'); title('Charge PMT1 vs PMT2');
    xlim(charge_limits_pmt_scatter); ylim(charge_limits_pmt_scatter);
    subplot(1,2,2); plot(Qcint_OG(:,3), Qcint_OG(:,4), '.'); hold on; plot(Qcint(:,3), Qcint(:,4), '.');
    xlabel('Qcint3'); ylabel('Qcint4'); title('Charge PMT3 vs PMT4');
    xlim(charge_limits_pmt_scatter); ylim(charge_limits_pmt_scatter);
    hLines = findobj(fig, 'Type', 'line');
    if numel(hLines) >= 2
        legendHandles = hLines(1:2);
    else
        legendHandles = hLines;
    end
    lg = legend(legendHandles, {'Corrected','Original'}, 'Location','northwest', 'Box','on');
    set(lg, 'ItemTokenSize', [35 14], 'FontSize', 13);
    ax_all = findall(fig, 'Type', 'axes');
    arrayfun(@(ax) set(ax, 'FontSize', 13), ax_all);
    arrayfun(@(ax) set(get(ax,'XLabel'), 'FontSize', 13), ax_all);
    arrayfun(@(ax) set(get(ax,'YLabel'), 'FontSize', 13), ax_all);
    arrayfun(@(ax) set(get(ax,'Title'),  'FontSize', 14), ax_all);
    sgtitle(sprintf('PMT charge correlations (run %s)', formatted_datetime_tex));
    capture_debug_png(fig, 'pmt_charge_correlations');
end


% Finally, plot the Tl_cint i vs Tl_cint j scatter plots for all PMT pairs
if should_plot
    fig = figure;
    subplot(1,2,1); plot(Tl_cint_OG(:,1), Tl_cint_OG(:,2),'.'); hold on; plot(Tl_cint(:,1), Tl_cint(:,2),'.');
    xlabel('Tl_cint1'); ylabel('Tl_cint2'); title('Time lead PMT1 vs PMT2');
    xlim(lead_time_limits_pmt_scatter); ylim(lead_time_limits_pmt_scatter);
    refline(1, time_pmt_diff_thr); refline(1, -time_pmt_diff_thr); % Plot the line y = x +- time_pmt_diff_thr
    subplot(1,2,2); plot(Tl_cint_OG(:,3), Tl_cint_OG(:,4),'.'); hold on; plot(Tl_cint(:,3), Tl_cint(:,4),'.');
    xlabel('Tl_cint3'); ylabel('Tl_cint4'); title('Time lead PMT3 vs PMT4');
    xlim(lead_time_limits_pmt_scatter); ylim(lead_time_limits_pmt_scatter);
    sgtitle(sprintf('PMT time coincidences (run %s)', formatted_datetime_tex));
    refline(1, time_pmt_diff_thr); refline(1, -time_pmt_diff_thr); % Plot the line y = x +- time_pmt_diff_thr
    capture_debug_png(fig, 'pmt_time_coincidences');
end


% Histograms of Tl for each strip to see the distribution of the difference
% Normalized histograms of the time lead differences for each PMT pair to verify the
if should_plot
    fig = figure;
    subplot(1,2,1);
    % Do not histogram zero values
    valid_diff_top = Tl_cint_OG(:,1) - Tl_cint_OG(:,2);
    valid_diff_top(valid_diff_top == 0) = [];
    histogram(valid_diff_top, 300, 'Normalization', 'probability');
    hold on;
    valid_diff = Tl_cint(:,1) - Tl_cint(:,2);
    valid_diff(valid_diff == 0) = [];
    histogram(valid_diff, 100, 'Normalization', 'probability');
    title('PMT 1 and 2 (BOT) time lead differences');
    xlabel('Time lead PMT 1 - PMT 2 [ns]'); ylabel('Counts');
    xline(time_pmt_diff_thr); xline(-time_pmt_diff_thr);
    subplot(1,2,2);
    % Do not histogram zero values
    valid_diff_top = Tl_cint_OG(:,3) - Tl_cint_OG(:,4);
    valid_diff_top(valid_diff_top == 0) = [];
    histogram(valid_diff_top, 300, 'Normalization', 'probability');
    hold on;
    valid_diff = Tl_cint(:,3) - Tl_cint(:,4);
    valid_diff(valid_diff == 0) = [];
    histogram(valid_diff, 100, 'Normalization', 'probability');
    title('PMT 3 and 4 (BOT) time lead differences');
    xlabel('Time lead PMT 3 - PMT 4 [ns]'); ylabel('Counts');
    sgtitle(sprintf('Histograms of time lead differences for PMTs (run %s)', formatted_datetime_tex));
    xline(time_pmt_diff_thr); xline(-time_pmt_diff_thr);
    capture_debug_png(fig, 'pmt_time_lead_histograms');
end



% -----------------------------------------------------------------------------
% RPC wide strip Timing and Charge Derivations
% -----------------------------------------------------------------------------

% leading times front [ns]; channels [32,28] -> 5 wide front strips
% TFl, TFt
% TBl, TBt

% Similar scatter subplot plots for the wide strips to verify no obvious problems.
if should_plot
    fig = figure('Units','normalized','Position',[0.02 0.05 0.96 0.9]);
    xlimits_1 = [t_lead_left t_lead_right];
    ylimits_1 = [t_trail_left t_trail_right];
    tl_lead_trail = tiledlayout(2, 5, 'TileSpacing','compact','Padding','compact');
    for strip = 1:5
        nexttile(tl_lead_trail);
        plot(TFl_OG(:,strip), TFt_OG(:,strip), '.'); hold on;
        plot(TFl(:,strip), TFt(:,strip), '.');
        xlabel('TFl'); ylabel('TFt');
        title(sprintf('Front lead/trail s%d', strip));
        xlim(xlimits_1); ylim(ylimits_1);
        xline(lead_time_wide_strip_min, 'r--'); xline(lead_time_wide_strip_max, 'r--');
        yline(trail_time_wide_strip_min, 'r--'); yline(trail_time_wide_strip_max, 'r--');
    end
    for strip = 1:5
        nexttile(tl_lead_trail);
        plot(TBl_OG(:,strip), TBt_OG(:,strip), '.'); hold on;
        plot(TBl(:,strip), TBt(:,strip), '.');
        xlabel('TBl'); ylabel('TBt');
        title(sprintf('Back lead/trail s%d', strip));
        xlim(xlimits_1); ylim(ylimits_1);
        xline(lead_time_wide_strip_min, 'r--'); xline(lead_time_wide_strip_max, 'r--');
        yline(trail_time_wide_strip_min, 'r--'); yline(trail_time_wide_strip_max, 'r--');
    end
    sgtitle(sprintf('Thick strip time lead vs trail (run %s)', formatted_datetime_tex));
    capture_debug_png(fig, 'thick_strip_lead_trail');
end

if should_plot

    fig = figure('Units','normalized','Position',[0.02 0.05 0.96 0.9]);
    xlimits_1 = [t_lead_left t_lead_right];
    ylimits_1 = [t_lead_left t_lead_right];
    right_lim_q_wide = 150; %adjust as needed
    xlimits_2 = [-2 right_lim_q_wide];
    ylimits_2 = xlimits_2;
    tl_fb = tiledlayout(2, 5, 'TileSpacing','compact','Padding','compact');
    for strip = 1:5
        nexttile(tl_fb);
        plot(TFl_OG(:,strip), TBl_OG(:,strip),'.'); hold on; plot(TFl(:,strip), TBl(:,strip),'.');
        xlabel('TFl'); ylabel('TBl');
        title(sprintf('Lead F/B s%d', strip));
        xlim(xlimits_1); ylim(ylimits_1);
        xline(lead_time_wide_strip_min, 'r--'); xline(lead_time_wide_strip_max, 'r--');
        yline(lead_time_wide_strip_min, 'r--'); yline(lead_time_wide_strip_max, 'r--');
    end

    for strip = 1:5
        nexttile(tl_fb);
        plot(QF_OG(:,strip), QB_OG(:,strip),'.'); hold on; plot(QF(:,strip), QB(:,strip),'.');
        xlabel('QF'); ylabel('QB');
        title(sprintf('Charge F/B s%d', strip));
        xlim(xlimits_2); ylim(ylimits_2);
    end
    sgtitle(sprintf('Thick strip time and charge front vs back (run %s)', formatted_datetime_tex));
    capture_debug_png(fig, 'thick_strip_front_back');
end

right_lim_q_wide = 100; %adjust as needed
fig = figure('Units','normalized','Position',[0.05 0.05 0.9 0.9]);
tl = tiledlayout(5, 2, 'TileSpacing','compact','Padding','compact');
for strip = 1:5
    % Left column: uncalibrated
    nexttile(tl);
    % Avoid plotting zero values
    QF_nonzero = QF_good(:,strip); QF_nonzero(QF_nonzero==0) = [];
    QB_nonzero = QB_good(:,strip); QB_nonzero(QB_nonzero==0) = [];
    histogram(QF_nonzero,-2:1:150); hold on;
    histogram(QB_nonzero,-2:1:150); xlim([-2 150]);
    legend(sprintf('QF - strip%d', strip), sprintf('QB - strip%d', strip), 'Location', 'northeast');
    ylabel('# of events');
    xlabel('Q [ns]');
    % Right column: calibrated
    nexttile(tl);
    % Avoid plotting zero values
    QF_p_nonzero = QF_p_good(:,strip); QF_p_nonzero(QF_p_nonzero==0) = [];
    QB_p_nonzero = QB_p_good(:,strip); QB_p_nonzero(QB_p_nonzero==0) = [];
    histogram(QF_p_nonzero, -2:1:right_lim_q_wide); hold on;
    histogram(QB_p_nonzero, -2:1:right_lim_q_wide);
    xlim([-2 right_lim_q_wide]);
    legend(sprintf('QF - strip%d', strip), sprintf('QB - strip%d', strip), 'Location', 'northeast');
    ylabel('# of events');
    xlabel('Q [ns]');
end
sgtitle(sprintf('Wide strip charge spectra and calibration (run %s)', formatted_datetime_tex));
capture_debug_png(fig, 'wide_strip_charge_calibration');


fig = figure('Units','normalized','Position',[0.1 0.15 0.8 0.7]);
% Avoid plotting zero values in histograms, take ~= 0 values
Q_nonzero = Q_thick_strip_OG; Q_nonzero(Q_nonzero==0) = [];
X_nonzero = X_thick_strip_OG; X_nonzero(X_nonzero==0) = [];
T_nonzero = T_thick_strip_OG; T_nonzero(T_nonzero==0) = [];
Y_nonzero = Y_thick_strip_OG; Y_nonzero(Y_nonzero==0) = [];
tl = tiledlayout(2, 2, 'TileSpacing','compact','Padding','compact');
nexttile(tl); histogram(Q_nonzero, 0:0.1:200); xlabel('Q [ns]'); ylabel('# of events'); title('Q total in sum of THICK STRIPS');
nexttile(tl); histogram(X_nonzero, 1:0.5:5.5); xlabel('X (strip with Qmax)'); ylabel('# of events'); title('X position (strip with Qmax)');
nexttile(tl); histogram(T_nonzero, -220:1:-100); xlabel('T [ns]'); ylabel('# of events'); title('T (mean of Tfl and Tbl)');
nexttile(tl); histogram(Y_nonzero, -2:0.01:2); xlabel('Y [ns]'); ylabel('# of events'); title('Y (Tfl-Tbl)/2');
sgtitle(sprintf('THICK STRIP OBSERVABLES (run %s)', formatted_datetime_tex));
capture_debug_png(fig, 'thick_strip_observables_raw');


fig = figure('Units','normalized','Position',[0.1 0.15 0.8 0.7]);
% Avoid plotting zero values in histograms, take ~= 0 values
Q_nonzero = Q_thick_strip_good; Q_nonzero(Q_nonzero==0) = [];
X_nonzero = X_thick_strip_good; X_nonzero(X_nonzero==0) = [];
T_nonzero = T_thick_strip_good; T_nonzero(T_nonzero==0) = [];
Y_nonzero = Y_thick_strip_good; Y_nonzero(Y_nonzero==0) = [];
tl = tiledlayout(2, 2, 'TileSpacing','compact','Padding','compact');
nexttile(tl); histogram(Q_nonzero, 0:0.1:200); xlabel('Q [ns]'); ylabel('# of events'); title('Q total in sum of THICK STRIPS');
nexttile(tl); histogram(X_nonzero, 1:0.5:5.5); xlabel('X (strip with Qmax)'); ylabel('# of events'); title('X position (strip with Qmax)');
nexttile(tl); histogram(T_nonzero, -220:1:-100); xlabel('T [ns]'); ylabel('# of events'); title('T (mean of Tfl and Tbl)');
nexttile(tl); histogram(Y_nonzero, -2:0.01:2); xlabel('Y [ns]'); ylabel('# of events'); title('Y (Tfl-Tbl)/2');
sgtitle(sprintf('THICK STRIP OBSERVABLES (run %s)', formatted_datetime_tex));
capture_debug_png(fig, 'thick_strip_observables_filtered');


% Histograms of QF-QB for each strip to see the distribution of the difference
% Normalized histograms for better comparison
fig = figure('Units','normalized','Position',[0.08 0.05 0.84 0.9]);
tl = tiledlayout(5, 1, 'TileSpacing','compact','Padding','compact');
for i = 1:5
    nexttile(tl);
    % Do not histogram zero values
    valid_diff_OG = QF_OG(:,i) - QB_OG(:,i);
    valid_diff_OG(valid_diff_OG == 0) = [];
    histogram(valid_diff_OG, 300, 'Normalization', 'probability');
    hold on;
    valid_diff = QF(:,i) - QB(:,i);
    valid_diff(valid_diff == 0) = [];
    histogram(valid_diff, 100, 'Normalization', 'probability');
    title(sprintf('Histogram of QF - QB for wide strip %d (run %s)', i, run_label));
    xlabel('QF - QB [ns]');
    ylabel('Counts');
    xline(charge_wide_strip_diff_thr, 'r--'); xline(-charge_wide_strip_diff_thr, 'r--');
end
sgtitle(sprintf('Histograms of QF - QB for all WIDE strips (run %s)', formatted_datetime_tex));
capture_debug_png(fig, 'wide_strip_qf_qb_histograms');

% Scatter plots of all pairs of Q, X, T, Y for the thick strips (always color version)
Qv = Q(:); Xv = X(:); Tv = T(:); Yv = Y(:);
n = min([numel(Qv), numel(Xv), numel(Tv), numel(Yv)]);
Qv = Qv(1:n); Xv = Xv(1:n); Tv = Tv(1:n); Yv = Yv(1:n);

% Pair definitions
names = {'Q','X','T','Y'};
vals  = {Qv,  Xv,  Tv,  Yv};
pairs = [1 2; 1 3; 1 4; 2 3; 2 4; 3 4];  % (Q,X), (Q,T), (Q,Y), (X,T), (X,Y), (T,Y)

fig = figure('Name','Scatter pairs: Q, X, T, Y');
tiledlayout(2,3,'TileSpacing','compact','Padding','compact');

% config outside the loop
ptSize = 20;      % point size
nx = 80; ny = 80; % 2D-hist bins
useLog = true;    % color scale

for i = 1:size(pairs,1)
    a = vals{pairs(i,1)};
    b = vals{pairs(i,2)};
    mask = (a ~= 0) & (b ~= 0) & isfinite(a) & isfinite(b);

    nexttile; 
    if any(mask)
        av = a(mask); 
        bv = b(mask);

        % 1) edges from masked data
        xedges = linspace(min(av), max(av), nx+1);
        yedges = linspace(min(bv), max(bv), ny+1);

        % 2) bin masked data
        [N,~,~,binX,binY] = histcounts2(av, bv, xedges, yedges);

        % 3) per-point counts
        idxValid = binX>0 & binY>0;
        cVals = zeros(size(av));
        cVals(idxValid) = N(sub2ind(size(N), binX(idxValid), binY(idxValid)));
        if useLog
            cVals = log10(cVals + 1);
        end

        % 4) density-colored scatter
        scatter(av, bv, ptSize, cVals, 'filled', 'MarkerFaceAlpha', 0.7);
        colormap(parula);
        cb = colorbar;
        if useLog
            cb.Label.String = 'log_{10}(count+1)';
        else
            cb.Label.String = 'count';
        end

        grid on; box on; axis tight;
        xlabel(names{pairs(i,1)}); ylabel(names{pairs(i,2)});
    title(sprintf('%s vs %s (run %s)', names{pairs(i,2)}, names{pairs(i,1)}, run_label));
    else
        axis off; 
        title(sprintf('%s vs %s (no data)', names{pairs(i,2)}, names{pairs(i,1)}));
    end
end

sgtitle(sprintf('All 2D scatter combinations (zeros removed) — run %s', run_label));
capture_debug_png(fig, 'thick_strip_scatter_matrix');



% -----------------------------------------------------------------------------
% RPC charges for the narrow strips, which do not carry timing info.
% -----------------------------------------------------------------------------

% This is a key plot. In run 1 the span of both axes is similar, while in runs 2
% and 3 the top charges are much lower, as expected. Calculating how much could give an idea
% of the relative gain of the top and bottom sides of the RPC and hence an idea on the
% real HV difference between both sides.

if should_plot

    fig = figure;
    subplot(4,6,1); plot(Qt(:,1), Qb(:,1),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip I');
    xlim(thin_top_scatter_limits); ylim(thin_bottom_scatter_limits);
    subplot(4,6,2); plot(Qt(:,2), Qb(:,2),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip II');
    xlim(thin_top_scatter_limits); ylim(thin_bottom_scatter_limits);
    subplot(4,6,3); plot(Qt(:,3), Qb(:,3),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip III');
    xlim(thin_top_scatter_limits); ylim(thin_bottom_scatter_limits);
    subplot(4,6,4); plot(Qt(:,4), Qb(:,4),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip IV');
    xlim(thin_top_scatter_limits); ylim(thin_bottom_scatter_limits);
    subplot(4,6,5); plot(Qt(:,5), Qb(:,5),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip V');
    xlim(thin_top_scatter_limits); ylim(thin_bottom_scatter_limits);
    subplot(4,6,6); plot(Qt(:,6), Qb(:,6),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip VI');
    xlim(thin_top_scatter_limits); ylim(thin_bottom_scatter_limits);
subplot(4,6,7); plot(Qt(:,7), Qb(:,7),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip VII');
xlim(thin_top_scatter_limits); ylim(thin_bottom_scatter_limits);
subplot(4,6,8); plot(Qt(:,8), Qb(:,8),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip VIII');
xlim(thin_top_scatter_limits); ylim(thin_bottom_scatter_limits);
subplot(4,6,9); plot(Qt(:,9), Qb(:,9),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip IX');
xlim(thin_top_scatter_limits); ylim(thin_bottom_scatter_limits);
subplot(4,6,10); plot(Qt(:,10), Qb(:,10),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip X');
xlim(thin_top_scatter_limits); ylim(thin_bottom_scatter_limits);
subplot(4,6,11); plot(Qt(:,11), Qb(:,11),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip XI');
xlim(thin_top_scatter_limits); ylim(thin_bottom_scatter_limits);
subplot(4,6,12); plot(Qt(:,12), Qb(:,12),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip XII');
xlim(thin_top_scatter_limits); ylim(thin_bottom_scatter_limits);
subplot(4,6,13); plot(Qt(:,13), Qb(:,13),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip XIII');
xlim(thin_top_scatter_limits); ylim(thin_bottom_scatter_limits);
subplot(4,6,14); plot(Qt(:,14), Qb(:,14),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip XIV');
xlim(thin_top_scatter_limits); ylim(thin_bottom_scatter_limits);
subplot(4,6,15); plot(Qt(:,15), Qb(:,15),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip XV');
xlim(thin_top_scatter_limits); ylim(thin_bottom_scatter_limits);
subplot(4,6,16); plot(Qt(:,16), Qb(:,16),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip XVI');
xlim(thin_top_scatter_limits); ylim(thin_bottom_scatter_limits);
subplot(4,6,17); plot(Qt(:,17), Qb(:,17),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip XVII');
xlim(thin_top_scatter_limits); ylim(thin_bottom_scatter_limits);
subplot(4,6,18); plot(Qt(:,18), Qb(:,18),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip XVIII');
xlim(thin_top_scatter_limits); ylim(thin_bottom_scatter_limits);
subplot(4,6,19); plot(Qt(:,19), Qb(:,19),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip XIX');
xlim(thin_top_scatter_limits); ylim(thin_bottom_scatter_limits);
subplot(4,6,20); plot(Qt(:,20), Qb(:,20),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip XX');
xlim(thin_top_scatter_limits); ylim(thin_bottom_scatter_limits);
subplot(4,6,21); plot(Qt(:,21), Qb(:,21),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip XXI');
xlim(thin_top_scatter_limits); ylim(thin_bottom_scatter_limits);
subplot(4,6,22); plot(Qt(:,22), Qb(:,22),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip XXII');
xlim(thin_top_scatter_limits); ylim(thin_bottom_scatter_limits);
subplot(4,6,23); plot(Qt(:,23), Qb(:,23),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip XXIII');
xlim(thin_top_scatter_limits); ylim(thin_bottom_scatter_limits);
subplot(4,6,24); plot(Qt(:,24), Qb(:,24),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip XXIV');
xlim(thin_top_scatter_limits); ylim(thin_bottom_scatter_limits);
sgtitle(sprintf('Narrow strip charge top vs bottom (run %s)', formatted_datetime_tex));
    capture_debug_png(fig, 'narrow_strip_top_vs_bottom');



% FIGURE 1 — Thin bottom / Thin top (hist + hist + scatter), with valid overlays
fig = figure;
subplot(1,3,1);
histogram(Q_thin_bot_event_signal_hist, thinBotEdges, 'DisplayName','all events', ...
    'FaceColor',[0.30 0.75 1.00], 'EdgeColor','none', 'FaceAlpha',0.8); hold on;
histogram(Q_thin_bot_event_good_hist, thinBotEdges, 'DisplayName','valid only', ...
    'FaceColor',[1.00 0.55 0.25], 'EdgeColor','none', 'FaceAlpha',0.9);
ylabel('# events'); xlabel('Q_{bot} [ADC]');
set(gca, 'YScale', 'log');
title({'Bottom charge','per event'});
xlim([q005 q95]); legend('show');

subplot(1,3,2);
histogram(Q_thin_top_event_signal_hist, thinTopEdges, 'DisplayName','all events', ...
    'FaceColor',[0.30 0.75 1.00], 'EdgeColor','none', 'FaceAlpha',0.8); hold on;
histogram(Q_thin_top_event_good_hist, thinTopEdges, 'DisplayName','valid only', ...
    'FaceColor',[1.00 0.55 0.25], 'EdgeColor','none', 'FaceAlpha',0.9);
ylabel('# events'); xlabel('Q_{top} [ADC]');
set(gca, 'YScale', 'log');
title({'Top charge','per event'});
xlim([q005 q95]); legend('show');

subplot(1,3,3);
plot(Q_thin_bot_event_signal, Q_thin_top_event_signal, '.', 'DisplayName','all events', ...
    'Color',[0.30 0.75 1.00], 'MarkerSize',7); hold on;
plot(Q_thin_bot_event_good, Q_thin_top_event_good, '.', 'DisplayName','valid only', ...
    'Color',[1.00 0.55 0.25], 'MarkerSize',7);
plot(thin_shared_scatter_limits, thin_shared_scatter_limits, '--','Color',[1 0.8 0.2],'LineWidth',2.2,'DisplayName','y = x');
xlabel('Q_{bot} [ADC]'); ylabel('Q_{top} [ADC]');
title('Bottom vs Top charge');
xlim(thin_bottom_scatter_limits); ylim(thin_top_scatter_limits); legend('show');
sgtitle(sprintf('Charge of the event (thin only; all vs valid; run %s)', run_label));
set(fig, 'Color', [0 0 0], 'InvertHardcopy', 'off');
axes_list = findall(fig, 'Type', 'axes');
for ax = reshape(axes_list,1,[])
    set(ax, 'Color', [0 0 0], 'XColor', [1 1 1], 'YColor', [1 1 1], ...
        'GridColor', [0.4 0.4 0.4], 'MinorGridColor', [0.25 0.25 0.25]);
end
style_figure_legends(fig, [1 1 1], [0 0 0]);
adjust_three_panel_row_figure(fig, slide_mode);
capture_debug_png(fig, 'thin_bottom_vs_top');

% FIGURE 2 — Thin bottom vs Thick
fig = figure;
subplot(1,3,1);
histogram(Q_thin_bot_event_signal_hist, thinBotEdges, 'DisplayName','all events'); hold on;
histogram(Q_thin_bot_event_good_hist, thinBotEdges, 'DisplayName','valid only');
ylabel('# of events'); xlabel('Q (bottom)');
set(gca, 'YScale', 'log');
title({'Q narrow bottom', 'per event'});
xlim([q005 q95]); legend('show');

subplot(1,3,2);
histogram(Q_thick_strip_signal_hist, thickEdges, 'DisplayName','all events'); hold on;
histogram(Q_thick_strip_good_hist, thickEdges, 'DisplayName','valid only');
ylabel('# of events'); xlabel('Q (thick)');
title('Q thick spectrum (sum of Q per event)');
xlim([q005_thick q95_thick]); legend('show');

subplot(1,3,3);
plot(Q_thin_bot_event_signal, Q_thick_strip_signal, '.', 'DisplayName','all events'); hold on;
plot(Q_thin_bot_event_good, Q_thick_strip_good, '.', 'DisplayName','valid only');
xlabel('Q (bottom)'); ylabel('Q (thick)');
title('Q bottom vs Q thick');
xlim(thin_bottom_scatter_limits); ylim(thick_scatter_limits); legend('show');
sgtitle(sprintf('Charge of the event (bottom vs thick; all vs valid; run %s)', run_label));
adjust_three_panel_row_figure(fig, slide_mode);
capture_debug_png(fig, 'thin_bottom_vs_thick');

% FIGURE 3 — Thick vs Thin top
fig = figure;
subplot(1,3,1);
histogram(Q_thick_strip_signal_hist, thickEdges, 'DisplayName','all events'); hold on;
histogram(Q_thick_strip_good_hist, thickEdges, 'DisplayName','valid only');
ylabel('# of events'); xlabel('Q (thick)');
title('Q thick spectrum (sum of Q per event)');
xlim([q005_thick q95_thick]); legend('show');

subplot(1,3,2);
histogram(Q_thin_top_event_signal_hist, thinTopEdges, 'DisplayName','all events'); hold on;
histogram(Q_thin_top_event_good_hist, thinTopEdges, 'DisplayName','valid only');
ylabel('# of events'); xlabel('Q (top)');
set(gca, 'YScale', 'log');
title({'Q narrow top', 'per event'});
xlim([q005 q95]); legend('show');

subplot(1,3,3);
plot(Q_thick_strip_signal, Q_thin_top_event_signal, '.', 'DisplayName','all events'); hold on;
plot(Q_thick_strip_good, Q_thin_top_event_good, '.', 'DisplayName','valid only');
xlabel('Q (thick)'); ylabel('Q (top)');
title('Q thick vs Q top');
xlim(thick_scatter_limits); ylim(thin_shared_scatter_limits); legend('show');
sgtitle(sprintf('Charge of the event (thick vs top; all vs valid; run %s)', run_label));
adjust_three_panel_row_figure(fig, slide_mode);
capture_debug_png(fig, 'thick_vs_thin_top');


% PMT 2x2 charge CDFs with binning_pmt and the _signal, _good, _range versions
fig = figure('Units','normalized','Position',[0.05 0.05 0.9 0.85]);
tl = tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
titles = {'Q pmt1','Q pmt2','Q pmt3','Q pmt4'};

for k = 1:4
    nexttile(tl);
    hold on;
    histogram(Qcint_signal(:,k), binning_pmt, 'DisplayName','all events', 'Normalization','pdf');
    histogram(Qcint_good(:,k),   binning_pmt, 'DisplayName','valid only', 'Normalization','pdf');
    histogram(Qcint_range(:,k),  binning_pmt, 'DisplayName','in range only', 'Normalization','pdf');
    xlabel(sprintf('Q (pmt%d)', k));
    ylabel('Fraction');
    title(titles{k});
    xlim(charge_limits_pmt);
    legend('show', 'Location','southeast');
    grid on; box on;
end

sgtitle(sprintf('PMT charge (run %s)', formatted_datetime_tex));
capture_debug_png(fig, 'pmt_charge_cdfs');

end


%%

% -------------------------------------------------------------------------
% Position from narrow strips (24 strips, no timing, only charge)
% -------------------------------------------------------------------------

if position_from_narrow_strips && should_plot

    % Choose method for thin-strip position: wrapped Gaussian fit (true) or wrapped weighted mean (false).
    thin_position_use_gaussian = false;
    try
        if evalin('base', 'exist(''thin_position_use_gaussian'',''var'')')
            candidate = evalin('base', 'thin_position_use_gaussian');
            if isstring(candidate) || ischar(candidate)
                candidate = strtrim(lower(string(candidate)));
                thin_position_use_gaussian = any(candidate == ["true","1","yes","y"]);
            else
                thin_position_use_gaussian = logical(candidate);
            end
        end
    catch
        log_debug('thin_position_use_gaussian override ignored (parse error).');
    end
    if thin_position_use_gaussian
        log_info('Thin position method: wrapped Gaussian fits.');
    else
        log_info('Thin position method: wrapped weighted mean.');
    end

    % Use no-crosstalk quantities for position calculation
    charge_thin_top_for_position = Qt_no_crosstalk;
    charge_thin_bot_for_position = Qb_no_crosstalk;
    charge_thick_for_position = Q_thick_strip_no_crosstalk;
    X_thick_for_position = X_thick_strip_no_crosstalk; % discrete (1..5)
    T_thick_for_position = T_thick_strip_no_crosstalk; % mean(Tfl,Tbl)
    Y_thick_for_position = Y_thick_strip_no_crosstalk; % (Tfl - Tbl)/2 in ns

    % Position charge threshold: only consider strips with charge > threshold; drop events with none.
    position_charge_min = 200;
    charge_thin_top_for_position(charge_thin_top_for_position <= position_charge_min) = 0;
    charge_thin_bot_for_position(charge_thin_bot_for_position <= position_charge_min) = 0;
    valid_pos_mask = (max(charge_thin_top_for_position, [], 2) > 0) & (max(charge_thin_bot_for_position, [], 2) > 0);
    charge_thin_top_for_position = charge_thin_top_for_position(valid_pos_mask, :);
    charge_thin_bot_for_position = charge_thin_bot_for_position(valid_pos_mask, :);
    X_thick_for_position = X_thick_for_position(valid_pos_mask, :);
    Y_thick_for_position = Y_thick_for_position(valid_pos_mask, :);
    T_thick_for_position = T_thick_for_position(valid_pos_mask, :);
    Qt_pos = charge_thin_top_for_position;
    Qb_pos = charge_thin_bot_for_position;

    % fprintf('Position from narrow strips: using raw Qt, Qb, Q_thick_strip (with no coincidence)\n');
    % charge_thin_top_for_position = Qt_signal;
    % charge_thin_bot_for_position = Qb_signal;
    % charge_thick_for_position = Q_thick_strip_signal;
    % X_thick_for_position = X_thick_strip_signal; % discrete (1..5)
    % T_thick_for_position = T_thick_strip_signal; % mean(Tfl,Tbl)
    % Y_thick_for_position = Y_thick_strip_signal; % (Tfl - Tbl)/2 in ns

    charge_thin_top_total = sum(charge_thin_top_for_position, 2);
    charge_thin_bot_total = sum(charge_thin_bot_for_position, 2);

    % ----- helpers -----
    ensure_col = @(v) v(:);
    isgood     = @(v) isfinite(v) & ~isnan(v);

    nStrips = 24;
    x = (1:nStrips)';               % strip index
    nTop = size(Qt_pos,1);  nBot = size(Qb_pos,1);

    fitTop = [];
    fitBot = [];
    fitTopParams = zeros(nTop,0);
    fitBotParams = zeros(nBot,0);

    if thin_position_use_gaussian
        % ===============================================================
        % (1a) WRAPPED GAUSSIAN FITS FOR Qt (TOP) AND Qb (BOTTOM)
        % ===============================================================
        fitTop = nan(nTop,3);           % [mu, sigma, chisq]
        fitBot = nan(nBot,3);
        fitTopParams = nan(nTop,4);     % raw [mu, log(sigma), log(ampl), baseline]
        fitBotParams = nan(nBot,4);

        wrapDist = @(dx) mod(dx + nStrips/2, nStrips) - nStrips/2;           % [-12,12)
        model_from_p = @(p) ( p(4) + exp(p(3)) .* exp( -0.5*(wrapDist(x - (1 + mod(p(1)-1,nStrips))).^2) ./ (exp(p(2)).^2) ) );
        sse = @(y,p) sum( (y - model_from_p(p)).^2 );
        optsFS = optimset('Display','off','MaxFunEvals',2000,'MaxIter',2000);

        % --- Fit TOP ---
        for i = 1:nTop
            y = double(Qt_pos(i,:))';
            if ~any(isfinite(y)) || all(y==0), continue; end
            [~,mu0] = max(y);
            yMin = min(y); yMax = max(y);
            A0 = max(yMax - yMin, eps);
            p0 = [mu0, log(3), log(A0), yMin];
            obj = @(p) sse(y,p);
            pFit = fminsearch(obj, p0, optsFS);

            mu    = 1 + mod(pFit(1)-1, nStrips);
            sigma = max(exp(pFit(2)), eps);
            chisq = obj(pFit);
            fitTop(i,:) = [mu, sigma, chisq];
            fitTopParams(i,:) = pFit;
        end

        % --- Fit BOTTOM ---
        for i = 1:nBot
            y = double(Qb_pos(i,:))';
            if ~any(isfinite(y)) || all(y==0), continue; end
            [~,mu0] = max(y);
            yMin = min(y); yMax = max(y);
            A0 = max(yMax - yMin, eps);
            p0 = [mu0, log(3), log(A0), yMin];
            obj = @(p) sse(y,p);
            pFit = fminsearch(obj, p0, optsFS);

            mu    = 1 + mod(pFit(1)-1, nStrips);
            sigma = max(exp(pFit(2)), eps);
            chisq = obj(pFit);
            fitBot(i,:) = [mu, sigma, chisq];
            fitBotParams(i,:) = pFit;
        end

    else
        % ===============================================================
        % (1b) WRAPPED WEIGHTED MEAN FOR Qt (TOP) AND Qb (BOTTOM)
        % ===============================================================
        angle_axis = 2*pi*(x-1)/nStrips; % 0..2pi
        fitTop = nan(nTop,3);            % [mu, sigma_like, 1-R]
        fitBot = nan(nBot,3);

        for i = 1:nTop
            y = double(Qt_pos(i,:))';
            if ~any(isfinite(y)) || all(y==0), continue; end
            y(~isfinite(y)) = 0;
            w = y;
            if all(w == 0), continue; end
            W = sum(w);
            if W <= 0, continue; end
            w = w / W;
            C = sum(w .* cos(angle_axis));
            S = sum(w .* sin(angle_axis));
            R = sqrt(C.^2 + S.^2);
            if R <= 0, continue; end
            ang = atan2(S, C);
            if ang < 0, ang = ang + 2*pi; end
            mu = 1 + (ang / (2*pi)) * nStrips;                    % wrapped mean in strip index space
            sigma_like = sqrt(max(-2*log(max(R, eps)), 0)) * (nStrips/(2*pi)); % circular spread mapped to strips
            fitTop(i,:) = [mu, sigma_like, 1 - R];                % 1-R as a simple quality metric
        end

        for i = 1:nBot
            y = double(Qb_pos(i,:))';
            if ~any(isfinite(y)) || all(y==0), continue; end
            y(~isfinite(y)) = 0;
            w = y;
            if all(w == 0), continue; end
            W = sum(w);
            if W <= 0, continue; end
            w = w / W;
            C = sum(w .* cos(angle_axis));
            S = sum(w .* sin(angle_axis));
            R = sqrt(C.^2 + S.^2);
            if R <= 0, continue; end
            ang = atan2(S, C);
            if ang < 0, ang = ang + 2*pi; end
            mu = 1 + (ang / (2*pi)) * nStrips;
            sigma_like = sqrt(max(-2*log(max(R, eps)), 0)) * (nStrips/(2*pi));
            fitBot(i,:) = [mu, sigma_like, 1 - R];
        end
    end

    % Keep only rows with finite fits
    goodTop = all(isfinite(fitTop),2);
    goodBot = all(isfinite(fitBot),2);
    % Use a common mask length (events) — assume Qt and Qb align by rows
    nEvents = min(numel(goodTop), numel(goodBot));
    fitTop  = fitTop (1:nEvents,:);
    fitBot  = fitBot (1:nEvents,:);
    if isempty(fitTopParams) || size(fitTopParams,1) < nEvents
        fitTopParams = zeros(nEvents, 0);
    else
        fitTopParams = fitTopParams(1:nEvents,:);
    end
    if isempty(fitBotParams) || size(fitBotParams,1) < nEvents
        fitBotParams = zeros(nEvents, 0);
    else
        fitBotParams = fitBotParams(1:nEvents,:);
    end
    goodTop = goodTop(1:nEvents);
    goodBot = goodBot(1:nEvents);
    goodFit = goodTop & goodBot;
    good_event_indices = find(goodFit);

    fitTop  = fitTop(goodFit,:);
    fitBot  = fitBot(goodFit,:);
    fitTopParams = fitTopParams(goodFit,:);
    fitBotParams = fitBotParams(goodFit,:);
    Qt_for_fit = double(Qt_pos(1:nEvents,:));
    Qb_for_fit = double(Qb_pos(1:nEvents,:));
    Qt_good = Qt_for_fit(goodFit,:);
    Qb_good = Qb_for_fit(goodFit,:);

    mu_top    = ensure_col(fitTop(:,1));
    sigma_top = ensure_col(fitTop(:,2));
    chi_top   = ensure_col(fitTop(:,3));

    mu_bot    = ensure_col(fitBot(:,1));
    sigma_bot = ensure_col(fitBot(:,2));
    chi_bot   = ensure_col(fitBot(:,3));

    % Decide whether thin-strip axes are rotated (swap top/bot roles for X/Y).
    thin_axes_rotated = false;
    try
        if exist('swap_narrow_top_bottom','var') && islogical(swap_narrow_top_bottom)
            thin_axes_rotated = swap_narrow_top_bottom;
        end
    catch
    end
    try
        if evalin('base','exist(''thin_axes_rotated'',''var'')')
            candidate = evalin('base','thin_axes_rotated');
            if isstring(candidate) || ischar(candidate)
                candidate = strtrim(lower(string(candidate)));
                thin_axes_rotated = any(candidate == ["true","1","yes","y"]);
            else
                thin_axes_rotated = logical(candidate);
            end
        end
    catch
        log_debug('thin_axes_rotated override ignored (parse error).');
    end
    if thin_axes_rotated
        log_info('Thin axes rotated: using BOTTOM for X and TOP for Y (swapped).');
    else
        log_info('Thin axes nominal: using TOP for X and BOTTOM for Y.');
    end

    % --- Charge-sharing examples (weighted mean mode) ---
    if ~thin_position_use_gaussian
        % Use chi (1-R) as a quality metric; prefer lower values and narrower sigma_like.
        quality_metric = chi_top + chi_bot + 0.1*(sigma_top + sigma_bot);
        quality_metric(~isfinite(quality_metric)) = Inf;
        [~, order] = sort(quality_metric, 'ascend');
        order = order(quality_metric(order) < Inf);
        max_examples = min(5, numel(order));
        strip_axis = 1:nStrips;
        for exIdx = 1:max_examples
            gIdx = order(exIdx);
            qt_profile = Qt_good(gIdx,:);
            qb_profile = Qb_good(gIdx,:);
            if all(~isfinite(qt_profile)) || all(~isfinite(qb_profile))
                continue;
            end
            qt_profile(~isfinite(qt_profile)) = 0;
            qb_profile(~isfinite(qb_profile)) = 0;

            fig = figure('Name', sprintf('Thin charge share (weighted) %d', gIdx), ...
                'Units','pixels', 'Position',[120 120 920 520], ...
                'Color', get(groot,'DefaultFigureColor'));
            tl = tiledlayout(fig, 2, 1, 'TileSpacing','compact', 'Padding','compact');

            axTop = nexttile(tl, 1);
            hold(axTop, 'on');
            bar(axTop, strip_axis, qt_profile, 'FaceColor', [0.2 0.6 0.9], 'FaceAlpha',0.65, 'EdgeColor','none');
            xline(axTop, mu_top(gIdx), 'Color',[1 0.3 0.3], 'LineWidth',1.4, 'LineStyle','-');
            hold(axTop, 'off');
            grid(axTop, 'on'); box(axTop, 'on');
            ylabel(axTop, 'Charge [ADC]');
            xlabel(axTop, 'Strip #');
            title(axTop, sprintf('Top thin (\\mu=%.2f, \\sigma_{like}=%.2f)', mu_top(gIdx), sigma_top(gIdx)), 'Interpreter','tex');
            set(axTop, 'FontSize', 11);

            axBot = nexttile(tl, 2);
            hold(axBot, 'on');
            bar(axBot, strip_axis, qb_profile, 'FaceColor', [0.9 0.5 0.2], 'FaceAlpha',0.65, 'EdgeColor','none');
            xline(axBot, mu_bot(gIdx), 'Color',[1 0.3 0.3], 'LineWidth',1.4, 'LineStyle','-');
            hold(axBot, 'off');
            grid(axBot, 'on'); box(axBot, 'on');
            ylabel(axBot, 'Charge [ADC]');
            xlabel(axBot, 'Strip #');
            title(axBot, sprintf('Bottom thin (\\mu=%.2f, \\sigma_{like}=%.2f)', mu_bot(gIdx), sigma_bot(gIdx)), 'Interpreter','tex');
            set(axBot, 'FontSize', 11);

            sgtitle(tl, sprintf('Thin strip charge sharing (weighted) — example %d', exIdx), 'FontSize', 13);
            capture_debug_png(fig, sprintf('thin_charge_share_weighted_%02d', exIdx));
        end
    end

    if thin_position_use_gaussian
        % --- Snapshot Gaussian overlays for slideshow ---
        max_gaussian_snapshots = 5;
        gaussian_sigma_cap = 6;  % strips; prefer narrower charge sharing
        available_snapshots = size(Qt_good, 1);
        if available_snapshots > 0
            strip_axis = 1:nStrips;
            quality_metric = chi_top + chi_bot + 0.1*(sigma_top + sigma_bot);
            quality_metric(~isfinite(quality_metric)) = Inf;
            sigma_pref_mask = (sigma_top <= gaussian_sigma_cap) & (sigma_bot <= gaussian_sigma_cap);
            [~, base_order] = sort(quality_metric, 'ascend');
            base_order = base_order(quality_metric(base_order) < Inf);
            preferred_order = base_order(sigma_pref_mask(base_order));
            fallback_order = base_order(~sigma_pref_mask(base_order));
            quality_order = [preferred_order; fallback_order];
            snapshots_to_plot = min(max_gaussian_snapshots, numel(quality_order));
            produced_snapshots = 0;
            for idx = 1:numel(quality_order)
                if produced_snapshots >= snapshots_to_plot
                    break;
                end
                gIdx = quality_order(idx);
                paramsTopRow = fitTopParams(gIdx,:);
                paramsBotRow = fitBotParams(gIdx,:);
                if any(~isfinite(paramsTopRow)) || any(~isfinite(paramsBotRow))
                    continue;
                end
                qt_profile = Qt_good(gIdx,:);
                qb_profile = Qb_good(gIdx,:);
                if all(~isfinite(qt_profile)) || all(~isfinite(qb_profile))
                    continue;
                end
                qt_profile(~isfinite(qt_profile)) = 0;
                qb_profile(~isfinite(qb_profile)) = 0;
                model_top = model_from_p(paramsTopRow(:));
                model_bot = model_from_p(paramsBotRow(:));
                if numel(model_top) ~= numel(strip_axis) || numel(model_bot) ~= numel(strip_axis)
                    continue;
                end
                event_label = 'n/a';
                if gIdx <= numel(good_event_indices)
                    event_label = sprintf('%d', good_event_indices(gIdx));
                end
                fig = figure('Name', sprintf('Thin Gaussian fit %d', gIdx), ...
                    'Units','pixels', 'Position',[120 120 920 520], ...
                    'Color', get(groot,'DefaultFigureColor'));
                tl = tiledlayout(fig, 2, 1, 'TileSpacing','compact', 'Padding','compact');

                axTop = nexttile(tl, 1);
                hold(axTop, 'on');
                bar(axTop, strip_axis, qt_profile, 'FaceColor', [0.2 0.6 0.9], 'FaceAlpha',0.65, 'EdgeColor','none');
                plot(axTop, strip_axis, model_top, 'Color',[1 1 1], 'LineWidth',1.6);
                hold(axTop, 'off');
                grid(axTop, 'on'); box(axTop, 'on');
                ylabel(axTop, 'Charge [ADC]');
                xlabel(axTop, 'Strip #');
                title(axTop, sprintf('Top thin strips — event %s (\\mu=%.2f, \\sigma=%.2f)', ...
                    event_label, mu_top(gIdx), sigma_top(gIdx)), 'Interpreter','tex');
                legend(axTop, {'Measured', 'Gaussian fit'}, 'Location','northeast', 'FontSize',10);
                set(axTop, 'FontSize', 11);

                axBot = nexttile(tl, 2);
                hold(axBot, 'on');
                bar(axBot, strip_axis, qb_profile, 'FaceColor', [0.9 0.5 0.2], 'FaceAlpha',0.65, 'EdgeColor','none');
                plot(axBot, strip_axis, model_bot, 'Color',[1 1 1], 'LineWidth',1.6);
                hold(axBot, 'off');
                grid(axBot, 'on'); box(axBot, 'on');
                ylabel(axBot, 'Charge [ADC]');
                xlabel(axBot, 'Strip #');
                title(axBot, sprintf('Bottom thin strips — event %s (\\mu=%.2f, \\sigma=%.2f)', ...
                    event_label, mu_bot(gIdx), sigma_bot(gIdx)), 'Interpreter','tex');
                legend(axBot, {'Measured', 'Gaussian fit'}, 'Location','northeast', 'FontSize',10);
                set(axBot, 'FontSize', 11);

                sgtitle(tl, sprintf('Thin-strip Gaussian fit snapshot %d', produced_snapshots + 1), 'FontSize', 13);
                capture_debug_png(fig, sprintf('thin_gaussian_fit_%02d', produced_snapshots + 1));
                produced_snapshots = produced_snapshots + 1;
            end
            if produced_snapshots == 0
                log_debug('No valid Gaussian fits found for thin-strip slideshow PNGs.');
            elseif produced_snapshots < max_gaussian_snapshots && produced_snapshots < available_snapshots
                log_debug('Generated %d Gaussian-fit PNG(s); fewer than requested due to quality filters.', produced_snapshots);
            end
        else
            log_debug('No Gaussian-fit candidates available for thin-strip slideshow PNGs.');
        end
    end


    % ===============================================================
    % 6x6 Fits matrix
    %  - Order: [mu_top, sigma_top, chi2_top, chi2_bot, sigma_bot, mu_bot]
    %  - Diagonal: single-variable histogram (log y)
    %  - Lower triangle: scatter (col -> x, row -> y)
    %  - Colors: TOP=blue, BOTTOM=orange
    %  - Limits: sigma in [0,24]; scatters use percentile caps (default 5%)
    % ===============================================================

    vars = { ...
        mu_top,    ... % 1
        sigma_top, ... % 2
        chi_top,   ... % 3
        chi_bot,   ... % 4
        sigma_bot, ... % 5
        mu_bot     ... % 6
    };
    labels = { ...
        '\mu_{top}', '\sigma_{top}', '\chi^2_{top}', ...
        '\chi^2_{bot}', '\sigma_{bot}', '\mu_{bot}' ...
    };

    % Colors (MATLAB default blue & orange)
    cTop = [0 0.4470 0.7410];      % blue
    cBot = [0.8500 0.3250 0.0980]; % orange
    colorByIdx = {@()cTop, @()cTop, @()cTop, @()cBot, @()cBot, @()cBot};

    percentile_position = 5;  % use 5%/95% caps (change if needed)

    fig = figure( ...
        'Name','Fits matrix (6x6): top/bottom variables', ...
        'Units','pixels', ...
        'Position',[80 80 1200 1100]);
    tl = tiledlayout(6,6,'TileSpacing','compact','Padding','compact');
    max_scatter_points = 4000;

    for r = 1:6
        for c = 1:6
            nexttile(tl);

            if r == c
                % ===== Diagonal: single-variable histogram =====
                v = vars{r};
                % Remove NaN/Inf/zeros
                v = v(isfinite(v) & v ~= 0);

                if isempty(v)
                    axis off; continue;
                end

                % Sigma variables (idx 2 = sigma_top, idx 5 = sigma_bot): force [0,24]
                if r == 2 || r == 5
                    v = v(v >= 0 & v <= 24);
                    be = linspace(0, 24, 60);
                else
                    be = linspace(min(v), max(v), 60);
                end

                hc = colorByIdx{r}();
                histogram(v, be, 'FaceAlpha',0.7, 'FaceColor',hc, 'EdgeColor','none');
                if r == 2 || r == 5
                    xlim([0 24]);
                end
                xlabel(labels{r}, 'Interpreter','tex');
                ylabel('count');
                set(gca,'YScale','log'); grid on; box on;

            elseif r > c
                % ===== Lower triangle: scatter (x = column var, y = row var) =====
                x = vars{c};
                y = vars{r};

                % Clean & pairwise mask: finite and non-zero on both
                m = isfinite(x) & isfinite(y) & (x ~= 0) & (y ~= 0);
                x = x(m); y = y(m);

                if isempty(x)
                    axis off; continue;
                end

                if numel(x) > max_scatter_points
                    sample_idx = randperm(numel(x), max_scatter_points);
                    x = x(sample_idx);
                    y = y(sample_idx);
                end

                hold on;
                % Edge color encodes x-var origin; face color encodes y-var origin

                scatter(x, y, 6, 'filled', 'r', 'MarkerFaceAlpha', 0.65);

                % Percentile-based limits per axis (respect current practice)
                pLo = percentile_position; pHi = 100 - percentile_position;
                % For sigma on any axis, additionally clamp to [0,24]
                % x-limits
                x_lo = prctile(x, pLo);
                x_hi = prctile(x, pHi);
                x1 = x_lo - 0.1*abs(x_lo);
                x2 = x_hi + 0.1*abs(x_hi);
                if c == 2 || c == 5
                    x1 = max(0, x1);
                    x2 = min(24, x2);
                end
                % y-limits
                y_lo = prctile(y, pLo);
                y_hi = prctile(y, pHi);
                y1 = y_lo - 0.1*abs(y_lo);
                y2 = y_hi + 0.1*abs(y_hi);
                if r == 2 || r == 5
                    y1 = max(0, y1);
                    y2 = min(24, y2);
                end

                % Ensure non-degenerate ranges
                if x2 <= x1, x2 = x1 + eps; end
                if y2 <= y1, y2 = y1 + eps; end

                xlim([x1, x2]); ylim([y1, y2]);

                xlabel(labels{c}, 'Interpreter','tex');
                ylabel(labels{r}, 'Interpreter','tex');
                grid on; box on;

            else
                % Upper triangle: empty
                axis off;
            end
        end
    end
    sgtitle(sprintf('Fits matrix (6x6) — run %s', run_label));
    capture_debug_png(fig, 'fits_matrix_top_bottom');




    % ===============================================================
    % (2) EXTENDED (PERIODICALLY EXPANDED) THIN COORDS
    % ===============================================================
    wrapPeriod = 24;  % strips per thick
    nWraps     = 5;   % number of thick strips in X (-> total 120)

    % "Original" 1..24 fits with orientation-aware mapping
    % Natural wiring (expected): TOP -> X, BOTTOM -> Y.
    if thin_axes_rotated
        thin_x_strip = ensure_col(mu_bot); % swapped: bottom drives X
        thin_y_strip = ensure_col(mu_top); % swapped: top drives Y
        thin_x_source = 'BOTTOM (rotated)';
        thin_y_source = 'TOP (rotated)';
    else
        thin_x_strip = ensure_col(mu_top); % top drives X
        thin_y_strip = ensure_col(mu_bot); % bottom drives Y
        thin_x_source = 'TOP';
        thin_y_source = 'BOTTOM';
    end
    % Keep legacy names for downstream use
    X_thin_strip_bot = thin_x_strip;
    Y_thin_strip_top = thin_y_strip;

    % Expand to show all periodic images
    X_thin_expanded_bot = arrayfun(@(x) x + (0:nWraps-1)*wrapPeriod, thin_x_strip, 'UniformOutput', false);
    X_thin_expanded_bot = vertcat(X_thin_expanded_bot{:});
    Y_thin_expanded_top = arrayfun(@(x) x + (0:nWraps-1)*wrapPeriod, thin_y_strip, 'UniformOutput', false);
    Y_thin_expanded_top = vertcat(Y_thin_expanded_top{:});


    % ===============================================================
    % (3) THICK & ORIGINAL THIN (top row), then THICK & FINAL THIN (bottom row)
    % ===============================================================

    % Build a consistent event mask for thick variables
    % Use the same events as kept in goodFit; align vectors to nEvents first
    X_thick_for_position = ensure_col(X_thick_for_position);
    Y_thick_for_position = ensure_col(Y_thick_for_position);

    nThick = min([numel(X_thick_for_position), numel(Y_thick_for_position), numel(goodFit)]);
    X_thick_for_position = X_thick_for_position(1:nThick);
    Y_thick_for_position = Y_thick_for_position(1:nThick);
    gf = goodFit(1:nThick);

    X_thick_for_position = X_thick_for_position(gf);   % 1..5
    Y_thick_for_position = Y_thick_for_position(gf);   % -1.5..1.5 ns
    % Thin fits (already gf-applied via fit trimming)
    % Now re-ensure same length:
    nPair = min([numel(thin_x_strip), numel(thin_y_strip), numel(X_thick_for_position), numel(Y_thick_for_position)]);
    thin_x_strip = thin_x_strip(1:nPair);
    thin_y_strip = thin_y_strip(1:nPair);
    X_thick_for_position = X_thick_for_position(1:nPair);
    Y_thick_for_position = Y_thick_for_position(1:nPair);

    % Take events (that is, rows) where the four vectors are different to 0
    nonzero_idx = (X_thick_for_position ~= 0) & (Y_thick_for_position ~= 0) & (thin_x_strip ~= 0) & (thin_y_strip ~= 0);
    X_thick_for_position = X_thick_for_position(nonzero_idx);      % [N x 1]
    Y_thick_for_position = Y_thick_for_position(nonzero_idx);      % [N x 1]
    thin_x_strip = thin_x_strip(nonzero_idx); % [N x 1]
    thin_y_strip = thin_y_strip(nonzero_idx); % [N x 1]
    nPair = numel(X_thick_for_position);

    % Map thick X (1..5 strips) onto thin-strip axis (1..120): center each 24-strip sector.
    X_thick_pos = (X_thick_for_position - 1) * wrapPeriod + wrapPeriod/2;

    % Map thick Y (time difference) linearly to 1..120 (±1.5 ns span)
    Y_thick_pos = (Y_thick_for_position + 1.5)/3 * 120 + 1;
    Y_thick_pos(~isfinite(Y_thick_pos)) = 60;
    Y_thick_pos = max(1, min(120, Y_thick_pos));

    % Randomize within each thick sector (keeps sector center) to reduce aliasing
    wrap_idx = floor((X_thick_pos-1) / wrapPeriod); % 0,1,2,3,4
    X_thick_pos = wrap_idx * wrapPeriod + rand(size(X_thick_pos))*wrapPeriod + 1;

    % "Final" (unwrapped) thin using thick X to pick the period
    X_thin_final = thin_x_strip + (X_thick_for_position - 1) * wrapPeriod;   % [1..120]

    % For Y (thin top): choose among 5 wraps the one closest to mapped thick-Y
    Ymap = Y_thick_pos;                                 % [1..120]
    % For Y: build the 5 possible wraps using fixed offsets of 24 strips
    y_offsets = (0:nWraps-1) * wrapPeriod;              % 1x5
    Y_cands = thin_y_strip + y_offsets;                 % N x 5
    diffs   = abs(Y_cands - Ymap);
    [~, idx_min] = min(diffs, [], 2);
    Y_thin_final = Y_cands(sub2ind(size(Y_cands), (1:nPair)', idx_min)); % [1..120]

    %%


    % Thin vs Thin (pre-check): raw 1..24 comparison to visualize mapping
    fig = figure('Name','Thin X vs Thin Y (raw 1..24)', ...
        'Units','pixels','Position',[140 140 520 520]);
    scatter(thin_x_strip, thin_y_strip, 6, 'filled', 'MarkerFaceAlpha',0.5);
    xlim([1 24]); ylim([1 24]); grid on; box on; axis square;
    xlabel(sprintf('THIN X (from %s) [1–24]', thin_x_source));
    ylabel(sprintf('THIN Y (from %s) [1–24]', thin_y_source));
    title(sprintf('Thin X vs Thin Y (run %s)', run_label));
    capture_debug_png(fig, 'thin_vs_thin_raw');

    % ---- PLOTS: original thin vs thick (top row), final thin vs thick (bottom row) ----
    commonColor = [0.2 0.8 0.2];
    lims = [1, 24*5];

    % mm conversions
    to_mm = @(ax) (ax/120 - 0.5) * 300;  % 1..120 -> -150..150 mm
    to_ax = @(mm) (mm/300 + 0.5) * 120;  % -150..150 mm -> 1..120

    % Optional rectangle in mm
    base_mm   = 20;
    height_mm = 80;
    if ismember(run, [1 2])
        center_mm = [-80, -27];
    else
        center_mm = [-80, 88]; % shift rectangle up by +100 mm for runs other than 1 or 2
    end

    base_left_mm   = center_mm(1) - base_mm/2;
    base_right_mm  = center_mm(1) + base_mm/2;
    height_bottom_mm = center_mm(2) - height_mm/2;
    height_top_mm    = center_mm(2) + height_mm/2;

    % Convert to axes coordinates
    base_left_ax   = to_ax(base_left_mm);
    base_right_ax  = to_ax(base_right_mm);
    height_bottom_ax = to_ax(height_bottom_mm);
    height_top_ax    = to_ax(height_top_mm);

    base_ax = base_right_ax - base_left_ax;
    height_ax = height_top_ax - height_bottom_ax;
    center_ax = [(base_left_ax + base_right_ax)/2, (height_bottom_ax + height_top_ax)/2];

    log_debug('Selection rectangle (mm): center=(%.1f, %.1f) | base=%.1f | height=%.1f', ...
            center_mm(1), center_mm(2), base_mm, height_mm);
    log_debug('Selection rectangle (axes units): center=(%.1f, %.1f) | base=%.1f | height=%.1f', ...
            center_ax(1), center_ax(2), base_ax, height_ax);

    fig = figure('Name','Original thin vs thick (top row) -> Final thin vs thick (bottom row)', ...
        'Units','pixels','Position',[120 120 900 700]);
    tl_wraps = tiledlayout(fig, 2, 2,'TileSpacing','compact','Padding','compact');

    % (a) THIN X (original 1..24 repeated) vs THICK Y
    ax_wrap_1 = nexttile(tl_wraps); hold(ax_wrap_1, 'on');
    for w = 0:nWraps-1
        scatter(ax_wrap_1, thin_x_strip + w*wrapPeriod, Y_thick_pos, 3, 'filled', 'MarkerFaceAlpha',0.6);
    end
    for k = 0:nWraps
        xline(ax_wrap_1, k*wrapPeriod+1, '-',  'LineWidth', 1);
        xline(ax_wrap_1, (k*wrapPeriod+wrapPeriod+1), '--', 'LineWidth', 1);
        yline(ax_wrap_1, k*wrapPeriod+1, '--', 'LineWidth', 1);
        yline(ax_wrap_1, (k*wrapPeriod+wrapPeriod+1), '--', 'LineWidth', 1);
    end
    rectangle(ax_wrap_1, 'Position', [center_ax(1)-base_ax/2, center_ax(2)-height_ax/2, base_ax, height_ax], ...
              'EdgeColor', 'r', 'LineWidth', 2);

    xlabel(ax_wrap_1, sprintf('THIN X (from %s, original) [1–120]', thin_x_source));
    ylabel(ax_wrap_1, 'THICK Y [1–120]');
    set(ax_wrap_1, 'LabelFontSizeMultiplier', 0.95, 'FontSize', 11);
    ax_wrap_1.XLabel.Units = 'normalized'; ax_wrap_1.XLabel.Position(2) = -0.09;
    ax_wrap_1.YLabel.Units = 'normalized'; ax_wrap_1.YLabel.Position(1) = -0.09;
    xlim(ax_wrap_1, lims); ylim(ax_wrap_1, lims); grid(ax_wrap_1, 'off'); box(ax_wrap_1, 'on'); axis(ax_wrap_1, 'square');

    % (b) THICK X vs THIN Y (original 1..24 repeated)
    ax_wrap_2 = nexttile(tl_wraps); hold(ax_wrap_2, 'on');
    for w = 0:nWraps-1
        scatter(ax_wrap_2, X_thick_pos, thin_y_strip + w*wrapPeriod, 3, 'filled', 'MarkerFaceAlpha',0.6);
    end
    for k = 0:nWraps
        xline(ax_wrap_2, k*wrapPeriod+1, '-',  'LineWidth', 1);
        xline(ax_wrap_2, (k*wrapPeriod+wrapPeriod+1), '--', 'LineWidth', 1);
        yline(ax_wrap_2, k*wrapPeriod+1, '--', 'LineWidth', 1);
        yline(ax_wrap_2, (k*wrapPeriod+wrapPeriod+1), '--', 'LineWidth', 1);
    end
    rectangle(ax_wrap_2, 'Position', [center_ax(1)-base_ax/2, center_ax(2)-height_ax/2, base_ax, height_ax], ...
              'EdgeColor', 'r', 'LineWidth', 2);

    xlabel(ax_wrap_2, 'THICK X [1–120]');
    ylabel(ax_wrap_2, sprintf('THIN Y (from %s, original) [1–120]', thin_y_source));
    set(ax_wrap_2, 'LabelFontSizeMultiplier', 0.95, 'FontSize', 11);
    ax_wrap_2.XLabel.Units = 'normalized'; ax_wrap_2.XLabel.Position(2) = -0.09;
    ax_wrap_2.YLabel.Units = 'normalized'; ax_wrap_2.YLabel.Position(1) = -0.09;
    xlim(ax_wrap_2, lims); ylim(ax_wrap_2, lims); grid(ax_wrap_2, 'off'); box(ax_wrap_2, 'on'); axis(ax_wrap_2, 'square');

    % (c) THIN X (final unwrapped) vs THICK Y
    ax_wrap_3 = nexttile(tl_wraps); hold(ax_wrap_3, 'on');
    scatter(ax_wrap_3, X_thin_final, Y_thick_pos, 3, commonColor, 'filled', 'MarkerFaceAlpha',0.6);
    for k = 0:nWraps
        xline(ax_wrap_3, k*wrapPeriod+1, '-',  'LineWidth', 1);
        xline(ax_wrap_3, (k*wrapPeriod+wrapPeriod+1), '--', 'LineWidth', 1);
        yline(ax_wrap_3, k*wrapPeriod+1, '--', 'LineWidth', 1);
        yline(ax_wrap_3, (k*wrapPeriod+wrapPeriod+1), '--', 'LineWidth', 1);
    end
    rectangle(ax_wrap_3, 'Position', [center_ax(1)-base_ax/2, center_ax(2)-height_ax/2, base_ax, height_ax], ...
              'EdgeColor', 'r', 'LineWidth', 2);

    xlabel(ax_wrap_3, sprintf('THIN X (from %s, final) [1–120]', thin_x_source));
    ylabel(ax_wrap_3, 'THICK Y [1–120]');
    set(ax_wrap_3, 'LabelFontSizeMultiplier', 0.95, 'FontSize', 11);
    ax_wrap_3.XLabel.Units = 'normalized'; ax_wrap_3.XLabel.Position(2) = -0.09;
    ax_wrap_3.YLabel.Units = 'normalized'; ax_wrap_3.YLabel.Position(1) = -0.09;
    xlim(ax_wrap_3, lims); ylim(ax_wrap_3, lims); grid(ax_wrap_3, 'off'); box(ax_wrap_3, 'on'); axis(ax_wrap_3, 'square');

    % (d) THICK X vs THIN Y (final unwrapped)
    ax_wrap_4 = nexttile(tl_wraps); hold(ax_wrap_4, 'on');
    scatter(ax_wrap_4, X_thick_pos, Y_thin_final, 3, commonColor, 'filled', 'MarkerFaceAlpha',0.6);
    for k = 0:nWraps
        xline(ax_wrap_4, k*wrapPeriod+1, '-',  'LineWidth', 1);
        xline(ax_wrap_4, (k*wrapPeriod+wrapPeriod+1), '--', 'LineWidth', 1);
        yline(ax_wrap_4, k*wrapPeriod+1, '--', 'LineWidth', 1);
        yline(ax_wrap_4, (k*wrapPeriod+wrapPeriod+1), '--', 'LineWidth', 1);
    end
    rectangle(ax_wrap_4, 'Position', [center_ax(1)-base_ax/2, center_ax(2)-height_ax/2, base_ax, height_ax], ...
              'EdgeColor', 'r', 'LineWidth', 2);
    xlabel(ax_wrap_4, 'THICK X [1–120]');
    ylabel(ax_wrap_4, sprintf('THIN Y (from %s, final) [1–120]', thin_y_source));
    set(ax_wrap_4, 'LabelFontSizeMultiplier', 0.95, 'FontSize', 11);
    ax_wrap_4.XLabel.Units = 'normalized'; ax_wrap_4.XLabel.Position(2) = -0.09;
    ax_wrap_4.YLabel.Units = 'normalized'; ax_wrap_4.YLabel.Position(1) = -0.09;
    xlim(ax_wrap_4, lims); ylim(ax_wrap_4, lims); grid(ax_wrap_4, 'off'); box(ax_wrap_4, 'on'); axis(ax_wrap_4, 'square');

    sgtitle(sprintf('Original thin vs thick -> Final thin vs thick (run %s)', run_label));
    capture_debug_png(fig, 'thin_vs_thick_wraps');

    %%

    % ===============================================================
    % (4) FINAL X-Y MAP (in mm) USING FINAL UNWRAPPED VALUES
    % ===============================================================

    X_final_ax = ensure_col(X_thin_final);
    Y_final_ax = ensure_col(Y_thin_final);
    valid = isgood(X_final_ax) & isgood(Y_final_ax);

    X_final_mm = to_mm(X_final_ax(valid));
    Y_final_mm = to_mm(Y_final_ax(valid));

    fig = figure('Name','Final XY map');
    scatter(X_final_mm, Y_final_mm, 6, 'filled', 'MarkerFaceAlpha',0.4); hold on;
    % Add xlines not dashed and dashed ylines each 24 strip interval, transforming from strip to mm
    for k = 0:nWraps
        xline((( k*wrapPeriod + 1 ) /120 - 0.5)*300, '-',  'LineWidth', 1);
        xline(((k*wrapPeriod+wrapPeriod + 1)/120 - 0.5)*300, '--', 'LineWidth', 1);
        yline(((k*wrapPeriod + 1 ) /120 - 0.5)*300, '--', 'LineWidth', 1);
        yline(((k*wrapPeriod+wrapPeriod + 1)/120 - 0.5)*300, '--', 'LineWidth', 1);
    end
    xlim([-150 150]); ylim([-150 150]); grid off; box on; axis square;
    xlabel(sprintf('X_{final} (from %s) [mm]', thin_x_source));
    ylabel(sprintf('Y_{final} (from %s) [mm]', thin_y_source));
    title(sprintf('Disambiguated thin positions using thick constraints — run %s', run_label));
    rectangle('Position', [center_mm(1)-base_mm/2, center_mm(2)-height_mm/2, base_mm, height_mm], ...
              'EdgeColor', 'r', 'LineWidth', 2);
    capture_debug_png(fig, 'final_xy_map');

end


%%


% ---------------------------------------------------------------------
% ---------------------------------------------------------------------
% Streamer calculation
% ---------------------------------------------------------------------
% ---------------------------------------------------------------------

Q_pmt_1 = Qcint_coin(:,1);
Q_pmt_2 = Qcint_coin(:,2);
Q_pmt_3 = Qcint_coin(:,3);
Q_pmt_4 = Qcint_coin(:,4);
Q_thick = Q_thick_strip_coin;
Q_thin_top = Q_thin_top_event_coin;
Q_thin_bot = Q_thin_bot_event_coin;

% And give the % of streamers in each case
num_streamers_thick = length(find(Q_thick > Q_thick_streamer_threshold));
percentage_streamer_thick = 100 * num_streamers_thick / rawEvents;
num_streamers_thin_top = length(find(Q_thin_top > Q_thin_top_streamer_threshold));
percentage_streamer_thin_top = 100 * num_streamers_thin_top / rawEvents;
num_streamers_thin_bot = length(find(Q_thin_bot > Q_thin_bot_streamer_threshold));
percentage_streamer_thin_bot = 100 * num_streamers_thin_bot / rawEvents;

percentage_streamer_pmt_top = 0; % Not defined
percentage_streamer_pmt_bot = 0; % Not defined

log_info('Streamer fraction of raw events | Thin top=%.2f%% | Thick=%.2f%% | Thin bottom=%.2f%%', ...
    percentage_streamer_thin_top, percentage_streamer_thick, percentage_streamer_thin_bot);

% Take only positive charges for the plots in a new vector that does not replace the original
Q_thick_plot = Q_thick(isfinite(Q_thick) & Q_thick > 0);
Q_thin_top_plot = Q_thin_top(isfinite(Q_thin_top) & Q_thin_top > 0);
Q_thin_bot_plot = Q_thin_bot(isfinite(Q_thin_bot) & Q_thin_bot > 0);

if should_plot
    % the streamer % in the histogram title with no decimals
    fig = figure;
    subplot(2,3,1); histogram(Q_thick_plot, 0:1:200); set(gca, 'YScale', 'log'); xlabel('Q_{thick\_event} [ADC bins]'); ylabel('# of events'); title(sprintf('Thick RPC Q, streamer <%d%%> (run %s)', round(percentage_streamer_thick), run_label));
    hold on; xline(Q_thick_streamer_threshold, 'r--', 'Streamer Threshold');
    subplot(2,3,2); histogram(Q_thin_top_plot, 0:100:10E4); set(gca, 'YScale', 'log'); xlabel('Q_{thin\_top\_event} [ADC bins]'); ylabel('# of events'); title(sprintf('Thin RPC TOP Q, streamer <%d%%> (run %s)', round(percentage_streamer_thin_top), run_label));
    hold on; xline(Q_thin_top_streamer_threshold, 'r--', 'Streamer Threshold');
    subplot(2,3,3); histogram(Q_thin_bot_plot, 0:100:10E4); set(gca, 'YScale', 'log'); xlabel('Q_{thin\_bot\_event} [ADC bins]'); ylabel('# of events'); title(sprintf('Thin RPC BOTTOM Q, streamer <%d%%> (run %s)', round(percentage_streamer_thin_bot), run_label));
    hold on; xline(Q_thin_bot_streamer_threshold, 'r--', 'Streamer Threshold');

    subplot(2,3,4); histogram(Q_thick_plot, 0:2:200, 'Normalization', 'cdf'); xlabel('Q_{thick\_event} [ADC bins]'); ylabel('Cumulative Distribution'); title('Thick RPC Q CDF');
    hold on; xline(Q_thick_streamer_threshold, 'r--', 'Streamer Threshold'); ylim([0 1]);
    subplot(2,3,5); histogram(Q_thin_top_plot, 0:500:10E4, 'Normalization', 'cdf'); xlabel('Q_{thin\_top\_event} [ADC bins]'); ylabel('Cumulative Distribution'); title('Thin RPC TOP Q CDF');
    hold on; xline(Q_thin_top_streamer_threshold, 'r--', 'Streamer Threshold'); ylim([0 1]);
    subplot(2,3,6); histogram(Q_thin_bot_plot, 0:500:10E4, 'Normalization', 'cdf'); xlabel('Q_{thin\_bot\_event} [ADC bins]'); ylabel('Cumulative Distribution'); title('Thin RPC BOTTOM Q CDF');
    hold on; xline(Q_thin_bot_streamer_threshold, 'r--', 'Streamer Threshold'); ylim([0 1]);

    sgtitle(sprintf('RPC Charge Spectra and cumulative distributions (run %s)', formatted_datetime_tex));
    capture_debug_png(fig, 'rpc_charge_streamers');
end


%%

% ---------------------------------------------------------------------
% ---------------------------------------------------------------------
% Charge main statistics calculation
% ---------------------------------------------------------------------
% ---------------------------------------------------------------------

% Create a version with vvalues larger than crosstalk and smaller than streamer
Q_thin_top_charge_params = Q_thin_top_plot(Q_thin_top_plot > top_narrow_strip_crosstalk & Q_thin_top_plot < Q_thin_top_streamer_threshold);
Q_thin_bot_charge_params = Q_thin_bot_plot(Q_thin_bot_plot > bot_narrow_strip_crosstalk & Q_thin_bot_plot < Q_thin_bot_streamer_threshold);
Q_thick_charge_params = Q_thick_plot(Q_thick_plot > thick_strip_crosstalk & Q_thick_plot < Q_thick_streamer_threshold);

% Mean
charge_thin_top_mean = mean(Q_thin_top_charge_params);
charge_thin_bot_mean = mean(Q_thin_bot_charge_params);
charge_thick_mean = mean(Q_thick_charge_params);

% Median
charge_thin_top_median = median(Q_thin_top_charge_params);
charge_thin_bot_median = median(Q_thin_bot_charge_params);
charge_thick_median = median(Q_thick_charge_params);

% Maximum
scale_maximum = 100;
charge_thin_top_max = mode(scale_maximum*round(Q_thin_top_charge_params/scale_maximum));
charge_thin_bot_max = mode(scale_maximum*round(Q_thin_bot_charge_params/scale_maximum));
scale_maximum = 10;
charge_thick_max = mode(scale_maximum*round(Q_thick_charge_params/scale_maximum));


% I want you to save in a csv the charge bin center and the count in each bin for thick_strips between 0 and 100, and use
% a bin width of 2 ADC bins. The csv should have two columns: "Charge_bin_center" and "Count".
bin_edges = 0:0.5:100;
[counts, edges] = histcounts(Q_thick_plot, bin_edges);
bin_centers = edges(1:end-1) + diff(edges)/2;
charge_histogram_table = table(bin_centers', counts', 'VariableNames', {'Charge_bin_center', 'Count'});

outdir = fullfile(outputs7_root, 'CHARGES');
if ~exist(outdir, 'dir')
    mkdir(outdir);
end

outfile = sprintf('%s/thick_strip_charge_histogram_run_%d.csv', outdir, run);
writetable(charge_histogram_table, outfile);

% Save thin strip charge histograms (top and bottom) using existing thin-strip binning
thin_edges = 0:100:10E4;
[counts_top, edges_top] = histcounts(Q_thin_top_plot, thin_edges);
bin_centers_top = edges_top(1:end-1) + diff(edges_top)/2;
charge_histogram_top = table(bin_centers_top', counts_top', 'VariableNames', {'Charge_bin_center', 'Count'});
outfile_top = sprintf('%s/thin_top_charge_histogram_run_%d.csv', outdir, run);
writetable(charge_histogram_top, outfile_top);

[counts_bot, edges_bot] = histcounts(Q_thin_bot_plot, thin_edges);
bin_centers_bot = edges_bot(1:end-1) + diff(edges_bot)/2;
charge_histogram_bot = table(bin_centers_bot', counts_bot', 'VariableNames', {'Charge_bin_center', 'Count'});
outfile_bot = sprintf('%s/thin_bottom_charge_histogram_run_%d.csv', outdir, run);
writetable(charge_histogram_bot, outfile_bot);

%%


% ---------------------------------------------------------------------
% ---------------------------------------------------------------------
% Efficiency calculation
% ---------------------------------------------------------------------
% ---------------------------------------------------------------------

variantSpecs = struct( ...
    'label', {'signal', 'coin', 'good', 'range', 'no_crosstalk'}, ...
    'Qcint', {Qcint_signal, Qcint_coin, Qcint_good, Qcint_range, Qcint_no_crosstalk}, ...
    'Q_thick', {Q_thick_strip_signal, Q_thick_strip_coin, Q_thick_strip_good, Q_thick_strip_range, Q_thick_strip_no_crosstalk}, ...
    'Q_thin_top',{Q_thin_top_event_signal, Q_thin_top_event_coin, Q_thin_top_event_good, Q_thin_top_event_range, Q_thin_top_event_no_crosstalk}, ...
    'Q_thin_bot',{Q_thin_bot_event_signal, Q_thin_bot_event_coin, Q_thin_bot_event_good, Q_thin_bot_event_range, Q_thin_bot_event_no_crosstalk} );


% Define threshold ranges (adjust as needed)
thin_top_median = median(Q_thin_top_event_good(Q_thin_top_event_good ~= 0));
thin_bot_median = median(Q_thin_bot_event_good(Q_thin_bot_event_good ~= 0));
thick_median   = median(Q_thick_strip_good(Q_thick_strip_good ~= 0), 'omitnan'); % avoid nan

quantile_binning = 30;
number_of_bins = number_of_bins_final_charge_and_eff_plots;
thin_top_thr_vec  = linspace(0, prctile(Q_thin_top_event_good(Q_thin_top_event_good ~= 0), quantile_binning), number_of_bins);
thin_bot_thr_vec  = linspace(0, prctile(Q_thin_bot_event_good(Q_thin_bot_event_good ~= 0), quantile_binning), number_of_bins);
thick_thr_vec     = linspace(0, prctile(Q_thick_strip_good(Q_thick_strip_good ~= 0), quantile_binning), number_of_bins);

variantLabels = {variantSpecs.label};
nVar = numel(variantSpecs);
escapeLegendLabel = @(s) strrep(char(s), '_', '\_');
variantLabelsDisplay = cellfun(escapeLegendLabel, variantLabels, 'UniformOutput', false);

eff_thin_top  = nan(numel(thin_top_thr_vec), nVar);
eff_thick     = nan(numel(thick_thr_vec), nVar);
eff_thin_bot  = nan(numel(thin_bot_thr_vec), nVar);

for v = 1:nVar
    spec = variantSpecs(v);
    Qcint_v      = spec.Qcint;
    Q_thick_v    = spec.Q_thick;
    Q_thin_top_v = spec.Q_thin_top;
    Q_thin_bot_v = spec.Q_thin_bot;

    events_with_pmt_list = any(Qcint_v ~= 0, 2);

    % THIN TOP
    for i = 1:numel(thin_top_thr_vec)
        thr = thin_top_thr_vec(i);
        hits = sum((Q_thin_top_v > thr) & events_with_pmt_list);
        total = sum(events_with_pmt_list);
        eff_thin_top(i,v) = 100 * hits / max(1,total);
    end

    % THICK
    for i = 1:numel(thick_thr_vec)
        thr = thick_thr_vec(i);
        hits = sum((Q_thick_v > thr) & events_with_pmt_list);
        total = sum(events_with_pmt_list);
        eff_thick(i,v) = 100 * hits / max(1,total);
    end

    % THIN BOT
    for i = 1:numel(thin_bot_thr_vec)
        thr = thin_bot_thr_vec(i);
        hits = sum((Q_thin_bot_v > thr) & events_with_pmt_list);
        total = sum(events_with_pmt_list);
        eff_thin_bot(i,v) = 100 * hits / max(1,total);
    end
end


% --- Plot ---
if should_plot
    fig = figure('Name','Efficiency vs Thresholds');
    tiledlayout(2,3,'TileSpacing','compact','Padding','compact');

    % THIN TOP
    nexttile;
    plot(thin_top_thr_vec, eff_thin_top, 'LineWidth',1.5); hold on;
    xline(top_narrow_strip_crosstalk, 'w--', 'Crosstalk Threshold'); % Crosstalk xline
    xline(Q_thin_top_streamer_threshold, 'r--', 'Streamer Threshold'); % Streamer line
    xline(thin_top_median, 'g--', 'Median Threshold'); % median line
    xlim([0 thin_top_thr_vec(end)]); % zoom in to the first 70% of the distribution
    ylim([0 100]);
    xlabel('Thin TOP threshold [ADC bins]');
    ylabel('Efficiency [%]');
    title('Thin TOP');
    legend(variantLabelsDisplay, 'Location','southwest');
    grid on; box on;

    % THICK
    nexttile;
    plot(thick_thr_vec, eff_thick, 'LineWidth',1.5); hold on;
    xline(thick_strip_crosstalk, 'w--', 'Crosstalk Threshold'); % Crosstalk xline
    xline(Q_thick_streamer_threshold, 'r--', 'Streamer Threshold'); % Streamer line
    xline(thick_median, 'g--', 'Median Threshold'); % median line
    xlim([0 thick_thr_vec(end)]); % zoom in to the first 70% of the distribution
    ylim([0 100]);
    xlabel('Thick threshold [ADC bins]');
    ylabel('Efficiency [%]');
    title('Thick');
    legend(variantLabelsDisplay, 'Location','southwest');
    grid on; box on;

    % THIN BOT
    nexttile;
    plot(thin_bot_thr_vec, eff_thin_bot, 'LineWidth',1.5); hold on;
    xline(bot_narrow_strip_crosstalk, 'w--', 'Crosstalk Threshold'); % Crosstalk xline
    xline(Q_thin_bot_streamer_threshold, 'r--', 'Streamer Threshold'); % Streamer line
    xline(thin_bot_median, 'g--', 'Median Threshold'); % median line
    xlim([0 thin_bot_thr_vec(end)]); % zoom in to the first 70% of the distribution
    ylim([0 100]);
    xlabel('Thin BOT threshold [ADC bins]');
    ylabel('Efficiency [%]');
    title('Thin BOT');
    legend(variantLabelsDisplay, 'Location','southwest');
    grid on; box on;


    % THIN TOP
    nexttile;
    hold on;
    colors = lines(nVar); % per-variant colors
    for v = 1:nVar
        Q_thin_top_v = variantSpecs(v).Q_thin_top;
        Q_thin_top_v_non_zero = Q_thin_top_v(Q_thin_top_v > 0);
        if isempty(Q_thin_top_v_non_zero), continue; end
        histogram(Q_thin_top_v_non_zero, 'BinEdges', thin_top_thr_vec, ...
            'Normalization', 'count', 'DisplayStyle', 'stairs', ...
            'EdgeColor', colors(v,:), 'LineWidth', 1.2, 'DisplayName', variantLabelsDisplay{v});
    end
    h1 = xline(top_narrow_strip_crosstalk, 'w--', 'Crosstalk Threshold');
    set(get(get(h1,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
    h2 = xline(Q_thin_top_streamer_threshold, 'r--', 'Streamer Threshold');
    set(get(get(h2,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
    h3 = xline(thin_top_median, 'g--', 'Median Threshold');
    set(get(get(h3,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
    xlim([0 thin_top_thr_vec(end)]);
    xlabel('Q thin top [ADC bins]');
    ylabel('Counts');
    title('Thin TOP');
    legend('show', 'Location','best');
    grid on; box on;

    % THICK
    nexttile;
    hold on;
    for v = 1:nVar
        Q_thick_v = variantSpecs(v).Q_thick;
        Q_thick_v_non_zero = Q_thick_v(Q_thick_v > 0);
        if isempty(Q_thick_v_non_zero), continue; end
        histogram(Q_thick_v_non_zero, 'BinEdges', thick_thr_vec, ...
            'Normalization', 'count', 'DisplayStyle', 'stairs', ...
            'EdgeColor', colors(v,:), 'LineWidth', 1.2, 'DisplayName', variantLabelsDisplay{v}); % outline only
    end
    legend('show', 'Location','best');
    xlabel('Q thick [ADC bins]');
    ylabel('Counts');
    title('Thick');
    h1 = xline(thick_strip_crosstalk, 'w--', 'Crosstalk Threshold');
    set(get(get(h1,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
    h2 = xline(Q_thick_streamer_threshold, 'r--', 'Streamer Threshold');
    set(get(get(h2,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
    h3 = xline(thick_median, 'g--', 'Median Threshold');
    set(get(get(h3,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
    xlim([0 thick_thr_vec(end)]);
    grid on; box on;

    % THIN BOT
    nexttile;
    hold on;
    for v = 1:nVar
        Q_thin_bot_v = variantSpecs(v).Q_thin_bot;
        Q_thin_bot_v_non_zero = Q_thin_bot_v(Q_thin_bot_v > 0);
        if isempty(Q_thin_bot_v_non_zero), continue; end
        histogram(Q_thin_bot_v_non_zero, 'BinEdges', thin_bot_thr_vec, ...
            'Normalization', 'count', 'DisplayStyle', 'stairs', ...
            'EdgeColor', colors(v,:), 'LineWidth', 1.2, 'DisplayName', variantLabelsDisplay{v});
    end
    legend('show', 'Location','best');
    xlabel('Q thin bot [ADC bins]');
    ylabel('Counts');
    h1 = xline(bot_narrow_strip_crosstalk, 'w--', 'Crosstalk Threshold');
    set(get(get(h1,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
    h2 = xline(Q_thin_bot_streamer_threshold, 'r--', 'Streamer Threshold');
    set(get(get(h2,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
    h3 = xline(thin_bot_median, 'g--', 'Median Threshold');
    set(get(get(h3,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
    xlim([0 thin_bot_thr_vec(end)]);
    title('Thin BOT');
    grid on; box on;

    sgtitle('Efficiency vs Threshold for Different Event Classes');
    capture_debug_png(fig, 'efficiency_vs_thresholds_full');
end


%%


% --- Plot ---
if should_plot
    fig = figure('Name','Efficiency vs Thresholds');
    tiledlayout(1,2,'TileSpacing','compact','Padding','compact');

    % THICK
    nexttile;
    plot(thick_thr_vec, eff_thick, 'LineWidth',1.5); hold on;
    xline(thick_strip_crosstalk, 'w--', 'Crosstalk Threshold'); % Crosstalk xline
    xline(Q_thick_streamer_threshold, 'r--', 'Streamer Threshold'); % Streamer line
    xline(thick_median, 'g--', 'Median Threshold'); % median line
    xlim([0 thick_thr_vec(end)]); % zoom in to the first 70% of the distribution
    ylim([0 100]);
    xlabel('Thick threshold [ADC bins]');
    ylabel('Efficiency [%]');
    title('Thick');
    legend(variantLabelsDisplay, 'Location','southwest');
    grid on; box on;


    % THICK
    nexttile;
    hold on;
    for v = 1:nVar
        Q_thick_v = variantSpecs(v).Q_thick;
        Q_thick_v_non_zero = Q_thick_v(Q_thick_v > 0);
        if isempty(Q_thick_v_non_zero), continue; end
        histogram(Q_thick_v_non_zero, 'BinEdges', thick_thr_vec, ...
            'Normalization', 'count', 'DisplayStyle', 'stairs', ...
            'EdgeColor', colors(v,:), 'LineWidth', 1.2, 'DisplayName', variantLabelsDisplay{v}); % outline only
    end
    legend('show', 'Location','best');
    xlabel('Q thick [ADC bins]');
    ylabel('Counts');
    title('Thick');
    h1 = xline(thick_strip_crosstalk, 'w--', 'Crosstalk Threshold');
    set(get(get(h1,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
    h2 = xline(Q_thick_streamer_threshold, 'r--', 'Streamer Threshold');
    set(get(get(h2,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
    h3 = xline(thick_median, 'g--', 'Median Threshold');
    set(get(get(h3,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
    xlim([0 thick_thr_vec(end)]);
    grid on; box on;


    sgtitle('Efficiency vs Threshold for Different Event Classes');
    capture_debug_png(fig, 'efficiency_vs_thresholds_zoom');
end


%%


thin_top_threshold = 0;
thin_bot_threshold = 0;
thick_threshold   = 0;

% Print these three limits
log_debug('Efficiency thresholds (ADCbins) | Thick=%g | Thin top=%g | Thin bottom=%g', ...
    thick_threshold, thin_top_threshold, thin_bot_threshold);

% Map PMT channels to top/bottom (adjust if your ordering differs)
pmt_top_cols = [1 2];
pmt_bot_cols = [3 4];

% Function that given numerator and denominator gives uncertainty in percentage
% assume a poisson for the number of counts in both numerator and denominator
effUnc = @(num,den) 100 * sqrt( (sqrt(num)/den)^2 + (num*sqrt(den)/den^2)^2 );

% Collect per-variant efficiencies, including PMT top/bottom
accum = struct([]);
for v = 1:numel(variantSpecs)
    spec = variantSpecs(v);
    Qcint_v      = spec.Qcint;
    Q_thick_v    = spec.Q_thick;
    Q_thin_top_v = spec.Q_thin_top;
    Q_thin_bot_v = spec.Q_thin_bot;

    % Qcint is N x 4, the rest are N x 1
    % An event is considered "with PMT" if both top and bottom PMTs have

    % Count number of "good" events: at least one PMT (of 4) fired
    events_with_pmt_list = any(Qcint_v ~= 0, 2);

    % For the rest (N x 1), count hits only where at least one PMT fired
    thick_hits     = sum((Q_thick_v    > thick_threshold) & events_with_pmt_list);
    thin_top_hits  = sum((Q_thin_top_v > thin_top_threshold) & events_with_pmt_list);
    thin_bot_hits  = sum((Q_thin_bot_v > thin_bot_threshold) & events_with_pmt_list);

    % For PMT top/bot, count events where at least one of the two fired
    pmt_top_hits   = sum(any(Qcint_v(:, pmt_top_cols) ~= 0, 2));
    pmt_bot_hits   = sum(any(Qcint_v(:, pmt_bot_cols) ~= 0, 2));

    % Total events with the four PMTs
    events_with_pmt = sum(events_with_pmt_list);

    if events_with_pmt == 0
        eff_thick = NaN; eff_thin_top = NaN; eff_thin_bot = NaN;
        eff_pmt_top = NaN; eff_pmt_bot = NaN;
    else
        eff_thick     = 100 * thick_hits    / events_with_pmt;
        eff_thin_top  = 100 * thin_top_hits / events_with_pmt;
        eff_thin_bot  = 100 * thin_bot_hits / events_with_pmt;
        eff_pmt_top   = 100 * pmt_top_hits  / events_with_pmt;
        eff_pmt_bot   = 100 * pmt_bot_hits  / events_with_pmt;

        % Uncertainties
        unc_thick     = effUnc(thick_hits,    events_with_pmt);
        unc_thin_top  = effUnc(thin_top_hits, events_with_pmt);
        unc_thin_bot  = effUnc(thin_bot_hits, events_with_pmt);
        unc_pmt_top   = effUnc(pmt_top_hits,  events_with_pmt);
        unc_pmt_bot   = effUnc(pmt_bot_hits,  events_with_pmt);
    end

    accum(v).label        = spec.label;
    accum(v).eff_thick    = eff_thick;
    accum(v).eff_thin_top = eff_thin_top;
    accum(v).eff_thin_bot = eff_thin_bot;
    accum(v).eff_pmt_top  = eff_pmt_top;
    accum(v).eff_pmt_bot  = eff_pmt_bot;

    accum(v).unc_thick    = unc_thick;
    accum(v).unc_thin_top = unc_thin_top;
    accum(v).unc_thin_bot = unc_thin_bot;
    accum(v).unc_pmt_top  = unc_pmt_top;
    accum(v).unc_pmt_bot  = unc_pmt_bot;
end

% Desired variant order for columns
variantOrder = {'signal', 'coin', 'good', 'range', 'no_crosstalk'};

% Helpers: fetch efficiency and uncertainty by label
getEff = @(lab, field) accum(strcmp({accum.label}, lab)).(field);
getUnc = @(lab, field) accum(strcmp({accum.label}, lab)).(strrep(field,'eff_','unc_'));

detectors = { ...
    'PMT_top',          'eff_pmt_top',   NaN,                           NaN,                    NaN,                     NaN; ...
    'RPC_thin_top',     'eff_thin_top',  percentage_streamer_thin_top,  charge_thin_top_mean,   charge_thin_top_median,  charge_thin_top_max; ...
    'RPC_thick_center', 'eff_thick',     percentage_streamer_thick,     charge_thick_mean,      charge_thick_median,     charge_thick_max; ...
    'RPC_thin_bottom',  'eff_thin_bot',  percentage_streamer_thin_bot,  charge_thin_bot_mean,   charge_thin_bot_median,  charge_thin_bot_max; ...
    'PMT_bottom',       'eff_pmt_bot',   NaN,                           NaN,                    NaN,                     NaN ...
};

nDet = size(detectors,1);
nVar = numel(variantOrder);

% Allocate with additional columns for StreamerPct, charge stats, and time resolutions
detRows = cell(nDet, 1 + 2*nVar + 6);

% Time resolution values may be unavailable if the corresponding fits were skipped
sigma_RPC_for_table = NaN;
if exist('sigma_RPC','var') && isscalar(sigma_RPC) && isfinite(sigma_RPC)
    sigma_RPC_for_table = sigma_RPC;
end
sigma_SC_for_table = NaN;
if exist('sigma_SC','var') && isscalar(sigma_SC) && isfinite(sigma_SC)
    sigma_SC_for_table = sigma_SC;
end

for i = 1:nDet
    detName    = detectors{i,1};
    effField   = detectors{i,2};
    streamerP  = detectors{i,3};
    meanQ      = detectors{i,4};
    medianQ    = detectors{i,5};
    maxQ       = detectors{i,6};

    detRows{i,1} = detName;

    % Interleaved [eff, unc] for each variant
    col = 2;
    for c = 1:nVar
        lab = variantOrder{c};
        detRows{i,col} = getEff(lab, effField); col = col + 1;
        detRows{i,col} = getUnc(lab, effField); col = col + 1;
    end

    % Tail columns
    detRows{i, 1 + 2*nVar + 1} = streamerP; % StreamerPct
    detRows{i, 1 + 2*nVar + 2} = meanQ;     % MeanCharge
    detRows{i, 1 + 2*nVar + 3} = medianQ;   % MedianCharge
    detRows{i, 1 + 2*nVar + 4} = maxQ;      % MaxCharge

    timeResRPC = NaN;
    timeResSC  = NaN;
    switch detName
        case 'RPC_thick_center'
            timeResRPC = sigma_RPC_for_table;
        case 'PMT_top'
            timeResSC = sigma_SC_for_table;
        case 'PMT_bottom'
            timeResSC = sigma_SC_for_table;
    end

    detRows{i, 1 + 2*nVar + 5} = timeResRPC; % time_res_RPC
    detRows{i, 1 + 2*nVar + 6} = timeResSC;  % time_res_SC
end

% Column names
varNames = {'Detector'};
for c = 1:nVar
    varNames{end+1} = variantOrder{c};
    varNames{end+1} = [variantOrder{c} '_unc'];
end
varNames = [varNames, {'StreamerPct','MeanCharge','MedianCharge','MaxCharge','time_res_RPC','time_res_SC'}];

detTable = cell2table(detRows, 'VariableNames', varNames);

% Round efficiencies/uncertainties; leave charges as-is (or round if you prefer)
for c = 1:nVar
    detTable{:, 1 + 2*(c-1) + 1} = round(detTable{:, 1 + 2*(c-1) + 1}, 1);
    detTable{:, 1 + 2*(c-1) + 2} = round(detTable{:, 1 + 2*(c-1) + 2}, 1);
end
detTable.StreamerPct = round(detTable.StreamerPct, 1);
detTable.MeanCharge   = round(detTable.MeanCharge);
detTable.MedianCharge = round(detTable.MedianCharge);
detTable.MaxCharge    = round(detTable.MaxCharge);


%%

% ===================== Pretty print (RPCs only) =====================

% Keep only the RPC rows
rpcNames = {'RPC_thin_top','RPC_thick_center','RPC_thin_bottom'};
idxRPC   = ismember(detTable.Detector, rpcNames);
detRPC   = detTable(idxRPC, :);

% -------- Efficiency Summary (values in %) --------
log_info('Efficiency summary (RPCs only; values in %%)');

% Build headers: Detector + one column per variant (value (unc))
colw_det = 17;
colw_var = 16;   % fits strings like "100.0 (10.0)"
fprintf('%-*s', colw_det, 'Detector');
for c = 1:nVar
    fprintf(' %-*s', colw_var, variantOrder{c});
end
fprintf('\n');

% Separator
sepLen = colw_det + (colw_var+1)*nVar;
fprintf('%s\n', repmat('-',1, sepLen));

% Rows: value (unc)
for i = 1:height(detRPC)
    fprintf('%-*s', colw_det, detRPC.Detector{i});
    for c = 1:nVar
        effVal = detRPC{ i, 1 + 2*(c-1) + 1 };
        uncVal = detRPC{ i, 1 + 2*(c-1) + 2 };

        if isnan(effVal)
            cellStr = 'NaN';
        else
            if isnan(uncVal)
                cellStr = sprintf('%.1f', effVal);
            else
                cellStr = sprintf('%.1f (%.1f)', effVal, uncVal);
            end
        end
        % print each variant cell
        fprintf(' %-*s', colw_var, cellStr);
    end
    fprintf('\n');
end
fprintf('%s\n', repmat('=',1, sepLen));

% -------- Charge Summary (ADCbins; streamer in %) --------
log_info('Charge summary (RPCs only; ADC bins, streamer %%)');

% Header
fprintf('%-*s %-12s %-12s %-12s %-12s\n', colw_det, 'Detector', 'Mean', 'Median', 'Max', 'StreamerPct');

% Separator
sepLen2 = colw_det + 4*(12+1);
fprintf('%s\n', repmat('-',1, sepLen2));

% Rows: integers for charges, one decimal for streamer pct
for i = 1:height(detRPC)
    detName = detRPC.Detector{i};
    meanQ   = detRPC.MeanCharge(i);
    medQ    = detRPC.MedianCharge(i);
    maxQ    = detRPC.MaxCharge(i);
    spct    = detRPC.StreamerPct(i);

    if isnan(meanQ), meanStr = 'NaN'; else meanStr = sprintf('%12.0f', meanQ); end
    if isnan(medQ),  medStr  = 'NaN'; else medStr  = sprintf('%12.0f', medQ);  end
    if isnan(maxQ),  maxStr  = 'NaN'; else maxStr  = sprintf('%12.0f', maxQ);  end
    if isnan(spct),  spStr   = '   NaN%%'; else spStr = sprintf('%11.1f%%', spct); end

    fprintf('%-*s %s %s %s %s\n', colw_det, detName, meanStr, medStr, maxStr, spStr);
end
fprintf('%s\n', repmat('=',1, sepLen2));

%%

% ---------------------------------------------------------------------

% CSV output
if run ~= 0
    summaryFileName = sprintf('RUN_%d_summary.csv', run);
else
    summaryFileName = 'summary.csv';
end
outCsv = fullfile(summary_output_dir, summaryFileName);
if exist(outCsv, 'file')
    delete(outCsv);
end

fid = fopen(outCsv, 'w');
% Update header comment with new column ordering
fprintf(fid, '# total_raw_events: %d\n', total_raw_events);
fprintf(fid, '# percentage_good_events_in_pmts: %.4f\n', percentage_good_events_in_pmts);
fprintf(fid, '# run_number: %d\n', run);
fprintf(fid, '%s\n', strjoin(varNames, ', '));
fclose(fid);

writetable(detTable, outCsv, 'WriteMode','append');

log_info('Summary CSV saved to %s', outCsv);

if ~should_plot
    log_info('No-plot flag enabled; CSV saved to %s. Skipping figure generation.', outCsv);
    log_banner('Completed caye_edits_minimal | Run %d | Input %s', run, input_dir);
    return;
end


% Print for verification
log_debug('Figure export directory: %s', save_plots_dir);
log_debug('Figure export filename: %s', pdfFileName);

if should_plot && save_plots
    if png_only_flag
        state = get_png_export_settings();
        exportedPngs = state.counter;
        pngDirs = state.dirs;
        if exportedPngs > 0
            log_info('PNG-only mode saved %d figure(s) per directory:', exportedPngs);
            for dIdx = 1:numel(pngDirs)
                log_info('  %s', pngDirs{dIdx});
            end
        else
            log_info('PNG-only mode enabled but no figures were exported.');
        end
    else
        try
            if ~exist(save_plots_dir, 'dir'), mkdir(save_plots_dir); end
            [pdfPath, exportedCount, totalFigures] = save_all_figures_to_pdf(save_plots_dir, pdfFileName, log_debug, pdf_page_limit);
            if exportedCount > 0 && ~isempty(pdfPath)
                if totalFigures > exportedCount
                    log_info('Saved %d of %d figure(s) to %s (PDF limited).', exportedCount, totalFigures, pdfPath);
                else
                    log_info('Saved %d figure(s) to %s', exportedCount, pdfPath);
                end
            else
                log_info('No figures generated to save.');
            end
        catch saveErr
            warning('Failed to save figures.');
        end
    end
end

log_banner('Completed caye_edits_minimal | Run %d | Input %s', run, input_dir);


%% 

% -------------------------------------------------------------------------
% -------------------------------------------------------------------------
% Functions ---------------------------------------------------------------
% -------------------------------------------------------------------------
% -------------------------------------------------------------------------

function [low, high] = ensure_axis_limits(low, high)
    % Ensure axis bounds are strictly increasing by padding symmetrically when necessary.
    if ~isfinite(low) || ~isfinite(high)
        return;
    end

    span = high - low;
    if span > 0 && isfinite(span)
        return;
    end

    magnitude = max([abs(low), abs(high), 1]);
    pad = max(magnitude * 0.05, eps(magnitude) * 10);
    if ~isfinite(pad) || pad <= 0
        pad = 1e-3;
    end

    mid = (low + high) / 2;
    if ~isfinite(mid)
        mid = 0;
    end

    low = mid - pad;
    high = mid + pad;
end

function limits = expand_axis_limits(limits, fraction)
    % Expand axis limits symmetrically by the requested fraction of their span.
    if nargin < 2 || isempty(fraction)
        fraction = 0.10;
    end
    if numel(limits) < 2 || any(~isfinite(limits))
        return;
    end

    low = limits(1);
    high = limits(2);
    [low, high] = ensure_axis_limits(low, high);

    span = high - low;
    if ~(span > 0 && isfinite(span))
        magnitude = max(abs([low, high]));
        padding = max(magnitude, 1) * fraction;
    else
        padding = span * fraction;
    end

    limits = [low - padding, high + padding];
end

function allowed = is_essential_plot(label)
    % Returns true if either essentials-only mode is off or the label is allowed.
    try
        essentials_only = evalin('base', 'exist(''plot_essentials_only'',''var'') && logical(plot_essentials_only)');
    catch
        essentials_only = false;
    end
    if ~essentials_only
        allowed = true;
        return;
    end

    try
        allowed_labels = evalin('base', 'essential_plot_labels');
    catch
        allowed_labels = {};
    end
    if isempty(allowed_labels)
        allowed = true;
        return;
    end

    if any(strcmpi(label, allowed_labels))
        allowed = true;
        return;
    end

    allowed = any(cellfun(@(p) startsWith(label, p, 'IgnoreCase', true), allowed_labels));
end

function capture_debug_png(figHandle, label)
    if nargin < 2
        label = '';
    end
    if ~(ishandle(figHandle) && strcmp(get(figHandle, 'Type'), 'figure'))
        return;
    end

    try
        debug_enabled = evalin('base', 'exist(''debug_mode'',''var'') && logical(debug_mode)');
    catch
        debug_enabled = false;
    end

    png_state = get_png_export_settings();
    png_enabled = png_state.enabled;

    if ~debug_enabled && ~png_enabled
        return;
    end

    if isempty(label)
        figName = get(figHandle, 'Name');
        if isempty(figName)
            label = sprintf('figure_%d', get(figHandle, 'Number'));
        else
            label = figName;
        end
    end
    label = sanitize_debug_label(label);

    % Force dark theme per-figure in case defaults were overridden.
    enforce_dark_background(figHandle);

    if ~is_essential_plot(label)
        try
            close(figHandle);
        catch
        end
        return;
    end

    fprintf('[INFO] Generating plot: %s\n', label);

    if debug_enabled
        try
            debug_dir = evalin('base', 'debug_png_dir');
        catch
            debug_dir = '';
        end
        if ~isempty(debug_dir)
            if ~exist(debug_dir, 'dir')
                mkdir(debug_dir);
            end
            try
                counter = evalin('base', 'debug_png_counter');
            catch
                counter = 0;
            end
            counter = counter + 1;
            assignin('base', 'debug_png_counter', counter);
            pngFile = sprintf('%03d_%s.png', counter, label);
            pngPath = fullfile(debug_dir, pngFile);
            try
                drawnow;
                exportgraphics(figHandle, pngPath, 'Resolution', 144);
            catch
                try
                    saveas(figHandle, pngPath);
                catch saveErr
                    warning('capture_debug_png:saveFailed', 'Unable to save figure %d: %s', get(figHandle, 'Number'), saveErr.message);
                end
            end
            fprintf('[DEBUG] Saved PNG #%d -> %s\n', counter, pngPath);
        end
    end

    if png_enabled
        try
            export_run_png(figHandle, label);
        catch pngErr
            warning('capture_debug_png:runPngFailed', 'Unable to export run PNG: %s', pngErr.message);
        end
    end
end

function clean = sanitize_debug_label(label)
    if nargin == 0 || isempty(label)
        clean = 'figure';
        return;
    end
    label = char(label);
    label = strtrim(label);
    if isempty(label)
        clean = 'figure';
        return;
    end

    clean = regexprep(label, '[^A-Za-z0-9_-]', '_');
    clean = regexprep(clean, '_+', '_');
    clean = regexprep(clean, '^_+|_+$', '');
    if isempty(clean)
        clean = 'figure';
    end
end

function enforce_dark_background(figHandle)
    if nargin < 1 || ~ishandle(figHandle)
        return;
    end
    try
        set(figHandle, 'Color', [0 0 0], 'InvertHardcopy', 'off');
    catch
    end
    try
        axesList = findall(figHandle, 'Type', 'axes');
        for ax = reshape(axesList,1,[])
            set(ax, 'Color', [0 0 0], 'XColor', [1 1 1], 'YColor', [1 1 1], 'ZColor', [1 1 1], ...
                'GridColor', [0.4 0.4 0.4], 'MinorGridColor', [0.25 0.25 0.25]);
        end
        cbList = findall(figHandle, 'Type', 'colorbar');
        for cb = reshape(cbList,1,[])
            set(cb, 'Color', [1 1 1]);
        end
    catch
    end
end

function state = get_png_export_settings()
    try
        state = evalin('base', 'png_export_settings');
    catch
        state = struct();
    end
    if ~isstruct(state)
        state = struct();
    end
    if ~isfield(state, 'enabled')
        state.enabled = false;
    end
    if ~isfield(state, 'dirs')
        state.dirs = {};
    end
    if ~isfield(state, 'counter')
        state.counter = 0;
    end
    if ~isfield(state, 'resolution') || ~isscalar(state.resolution)
        state.resolution = 150;
    end
    if ~isfield(state, 'auto_close')
        state.auto_close = false;
    end
end

function export_run_png(figHandle, label)
    state = get_png_export_settings();
    if ~state.enabled
        return;
    end
    if nargin < 2 || isempty(label)
        figName = get(figHandle, 'Name');
        if isempty(figName)
            label = sprintf('figure_%d', get(figHandle, 'Number'));
        else
            label = figName;
        end
    end
    label = sanitize_debug_label(label);
    state.counter = state.counter + 1;
    assignin('base', 'png_export_settings', state);
    filename = sprintf('%03d_%s.png', state.counter, label);
    for idx = 1:numel(state.dirs)
        targetDir = state.dirs{idx};
        if isempty(targetDir)
            continue;
        end
        if ~exist(targetDir, 'dir')
            mkdir(targetDir);
        end
        filePath = fullfile(targetDir, filename);
        try
            drawnow;
            exportgraphics(figHandle, filePath, 'Resolution', state.resolution);
        catch exportErr
            warning('export_run_png:saveFailed', 'Unable to save %s: %s', filePath, exportErr.message);
        end
    end
    if state.auto_close && ishandle(figHandle)
        try
            close(figHandle);
        catch
        end
    end
end


% Define a function called mm_to_strip that converts mm to strip number
function strip = mm_to_strip(mm)
    % Map from mm in [-150, 150] -> strip in [0, 120]
    strip = (mm + 150) / 300 * 120;
end


% Helper function to draw the vertical/horizontal boundary lines
function addBoundaries(ax, wrapPeriod, nWraps, lims)
    axes(ax); %#ok<LAXES>
    for k = 1:nWraps
        xline((k-1)*wrapPeriod + 0.5, '-', 'Color',[0.8 0.8 0.8], 'LineWidth', 1.2);
        xline(k*wrapPeriod       + 0.5, '--', 'Color',[0.8 0.8 0.8], 'LineWidth', 1.2);
        yline((k-1)*wrapPeriod + 0.5, '--', 'Color',[0.8 0.8 0.8], 'LineWidth', 1.2);
        yline(k*wrapPeriod       + 0.5, '--', 'Color',[0.8 0.8 0.8], 'LineWidth', 1.2);
    end
    xlim(lims);
    ylim(lims);
    grid on; box on; axis square;
end


% Saves all open figures to a single multi-page PDF in targetDir/pdfFileName
% Workspace overrides (set in base workspace prior to running):
%   save_dpi         -> scalar DPI (default 72) to balance quality/performance.
%   save_background  -> color spec (e.g., 'black', 'white', [0 0 0]) or "current".
%   save_pdf_mode    -> "stream" (default, low-memory exporter) or "legacy" (PNG staging).
%   keep_raster_temp -> true to retain intermediate PNGs when in legacy mode.
function [pdfPath, exportedCount, totalCount] = save_all_figures_to_pdf(targetDir, pdfFileName, log_debug, maxPages)
    if nargin < 3 || isempty(log_debug)
        log_debug = @(varargin) [];
    end
    if nargin < 4 || isempty(maxPages)
        maxPages = Inf;
    end
    if ~isnumeric(maxPages) || isempty(maxPages)
        maxPages = Inf;
    end
    if isfinite(maxPages)
        maxPages = max(0, floor(double(maxPages)));
    else
        maxPages = Inf;
    end
    figs = findall(0, 'Type', 'figure');

    % Filter out non-essential figures when essentials-only mode is active
    essentials_only = false;
    try
        essentials_only = evalin('base', 'exist(''plot_essentials_only'',''var'') && logical(plot_essentials_only)');
    catch
        essentials_only = false;
    end
    if essentials_only
        keep = false(size(figs));
        for k = 1:numel(figs)
            figName = get(figs(k), 'Name');
            if isempty(figName)
                label = sprintf('figure_%d', figs(k).Number);
            else
                label = char(figName);
            end
            label = sanitize_debug_label(label);
            if is_essential_plot(label)
                keep(k) = true;
            else
                try, close(figs(k)); catch, end
            end
        end
        figs = figs(keep);
    end

    totalCount = numel(figs);
    exportedCount = 0;
    pdfPath = '';
    if totalCount == 0
        log_debug('No figures available for export.');
        return;
    end
    if maxPages == 0
        log_debug('PDF page limit is zero; skipping export.');
        return;
    end
    if ~exist(targetDir, 'dir')
        mkdir(targetDir);
    end
    pdfPath = fullfile(targetDir, pdfFileName);

    % Sort by figure number for stable ordering
    [~, sortIdx] = sort([figs.Number]);
    figs = figs(sortIdx);
    if isfinite(maxPages) && totalCount > maxPages
        limit = min(totalCount, maxPages);
        figs = figs(1:limit);
        log_debug('Limiting PDF export to %d of %d figure(s).', limit, totalCount);
    end

    % -------- Export tuning (prioritize low memory footprint) --------
    % Allow overriding from base workspace: save_dpi = 72/96/120 ...
    try
        dpi = evalin('base', 'save_dpi');
        if isempty(dpi) || ~isscalar(dpi) || ~isfinite(dpi)
            dpi = [];
        end
    catch
        dpi = [];
    end
    if isempty(dpi)
        dpi = 72; % lower default DPI keeps exported rasters lightweight
    end
    dpi = max(36, min(200, double(dpi))); % clamp to sane bounds

    % Background color can still be overridden if the workspace defines it.
    try
        bgColor = evalin('base', 'save_background');
        if ~(ischar(bgColor) || isstring(bgColor)) && ~isnumeric(bgColor)
            bgColor = [];
        end
    catch
        bgColor = [];
    end
    if isempty(bgColor)
        bgColor = 'current'; % respect each figure's own color settings
    end

    exportOpts = {'ContentType','image','Resolution',dpi,'BackgroundColor',bgColor};

    % We stream figures directly into the PDF to avoid high-memory PNG staging.
    % Users can still opt-in to the legacy raster workflow by defining
    % save_pdf_mode = "legacy" in the base workspace.
    try
        pdfMode = evalin('base', 'save_pdf_mode');
        if ~isstring(pdfMode) && ~ischar(pdfMode)
            pdfMode = "stream";
        else
            pdfMode = string(pdfMode);
        end
    catch
        pdfMode = "stream";
    end

    if pdfMode == "legacy"
        log_debug('save_pdf_mode set to legacy; using PNG staging workflow.');
        pdfPath = run_legacy_pdf_export(figs, pdfPath, exportOpts, log_debug);
        exportedCount = numel(figs);
        return;
    end

    try
        stream_figures_to_pdf(figs, pdfPath, exportOpts, log_debug);
    catch streamErr
        warning(streamErr.identifier, 'Streaming PDF export failed: %s\nFalling back to legacy raster combine.', streamErr.message);
        pdfPath = run_legacy_pdf_export(figs, pdfPath, exportOpts, log_debug);
        exportedCount = numel(figs);
        return;
    end
    pdfPath = ensure_existing_pdf(pdfPath);
    exportedCount = numel(figs);
end

function pdfPath = run_legacy_pdf_export(figs, pdfPath, exportOpts, log_debug)
    targetDir = fileparts(pdfPath);
    dpi = exportOpts{4}; % exportOpts = {'ContentType','image','Resolution',dpi,'BackgroundColor',bgColor}
    if isnumeric(dpi), dpiVal = dpi; else dpiVal = NaN; end
    bgColorValue = exportOpts{end};

    tempDir = tempname(targetDir);
    mkdir(tempDir);
    log_debug('Legacy rasterization of %d figure(s) into %s (DPI=%s)', numel(figs), tempDir, mat2str(dpiVal));

    keepRasterTemp = false;
    try
        keepRasterTemp = evalin('base', "exist(''keep_raster_temp'',''var'') && logical(keep_raster_temp)");
    catch
        keepRasterTemp = false;
    end

    if ~keepRasterTemp
        cleanupObj = onCleanup(@() cleanup_temp_directory(tempDir)); %#ok<NASGU>
    else
        log_debug('keep_raster_temp is true; temporary PNGs retained in %s', tempDir);
    end

    pngFiles = cell(numel(figs), 1);
    for k = 1:numel(figs)
        fig = figs(k);
        prepare_figure_colors(fig, bgColorValue);
        pngFiles{k} = fullfile(tempDir, sprintf('page_%04d.png', k));
        try
            exportgraphics(fig, pngFiles{k}, exportOpts{:});
        catch err
            close(fig);
            rethrow(err);
        end
        close(fig);
    end
    combine_images_to_pdf(pngFiles, pdfPath, exportOpts);
    pdfPath = ensure_existing_pdf(pdfPath);
end

function stream_figures_to_pdf(figs, pdfPath, exportOpts, log_debug)
    if exist(pdfPath, 'file')
        delete(pdfPath);
    end
    bgColorValue = exportOpts{end};
    for idx = 1:numel(figs)
        fig = figs(idx);
        prepare_figure_colors(fig, bgColorValue);
        opts = exportOpts;
        if idx > 1
            opts = [opts, {'Append', true}];
        end
        try
            exportgraphics(fig, pdfPath, opts{:});
        catch err
            close(fig);
            rethrow(err);
        end
        close(fig);
        log_debug('Streamed figure %d/%d into %s', idx, numel(figs), pdfPath);
    end
end

function prepare_figure_colors(fig, bgValue)
    try, set(fig, 'InvertHardcopy','off'); end
    resolvedBg = resolve_background_color(fig, bgValue);
    if ~isempty(resolvedBg)
        set(fig, 'Color', resolvedBg);
    end
    labelColor = pick_contrasting_color(resolvedBg);
    ax = findall(fig, 'Type','axes');
    for a = reshape(ax,1,[])
        try
            axColor = get(a, 'Color');
            if ischar(axColor) || isstring(axColor)
                if strcmpi(axColor, 'none') && ~isempty(resolvedBg)
                    set(a, 'Color', resolvedBg);
                end
            elseif isnumeric(axColor)
                % leave numeric colors as-is
            else
                if ~isempty(resolvedBg)
                    set(a, 'Color', resolvedBg);
                end
            end
            set(a, 'XColor', labelColor, 'YColor', labelColor, 'ZColor', labelColor);
        catch
        end
    end
    style_figure_legends(fig, labelColor, resolvedBg);
end

function pdfPath = ensure_existing_pdf(pdfPath)
    if exist(pdfPath, 'file')
        pdfPath = char(pdfPath);
    else
        pdfPath = '';
    end
end

function resolvedBg = resolve_background_color(fig, bgValue)
    resolvedBg = [];
    if nargin < 2 || isempty(bgValue)
        bgValue = 'current';
    end

    if isnumeric(bgValue) && numel(bgValue) == 3
        resolvedBg = normalize_rgb(bgValue);
        return;
    end

    if isstring(bgValue) || ischar(bgValue)
        bgStr = lower(strtrim(string(bgValue)));
        if bgStr == "current"
            figColor = get(fig, 'Color');
            if isnumeric(figColor) && numel(figColor) == 3
                resolvedBg = normalize_rgb(figColor);
            elseif ischar(figColor) || isstring(figColor)
                if strcmpi(figColor, 'none')
                    resolvedBg = [0 0 0];
                else
                    resolvedBg = safe_validate_color(figColor);
                end
            end
        else
            resolvedBg = safe_validate_color(bgValue);
        end
    end

    if isempty(resolvedBg)
        resolvedBg = [0 0 0];
    end
end

function labelColor = pick_contrasting_color(bgColor)
    if isempty(bgColor)
        labelColor = [1 1 1];
        return;
    end
    luminance = 0.2126*bgColor(1) + 0.7152*bgColor(2) + 0.0722*bgColor(3);
    if luminance > 0.5
        labelColor = [0 0 0];
    else
        labelColor = [1 1 1];
    end
end

function rgb = safe_validate_color(colorSpec)
    try
        rgb = validatecolor(colorSpec, 'tuple');
        rgb = normalize_rgb(rgb);
    catch
        rgb = [];
    end
end

function rgb = normalize_rgb(rgb)
    rgb = double(rgb(:))';
    if numel(rgb) ~= 3
        rgb = [];
        return;
    end
    if any(rgb > 1)
        rgb = rgb / 255;
    end
    rgb = min(max(rgb, 0), 1);
end

function adjust_three_panel_row_figure(figHandle, slideMode)
    if nargin < 1 || isempty(figHandle) || ~ishandle(figHandle)
        return;
    end
    if ~isgraphics(figHandle, 'figure')
        return;
    end
    axesList = findall(figHandle, 'Type', 'axes');
    axesList = axesList(isgraphics(axesList, 'axes'));
    if numel(axesList) < 3
        return;
    end
    shrinkFactor = 0.9;
    if nargin >= 2 && ~isempty(slideMode) && logical(slideMode)
        shrinkFactor = 0.8;
    end
    originalUnits = get(figHandle, 'Units');
    try
        set(figHandle, 'Units', 'pixels');
        pos = get(figHandle, 'Position');
        if numel(pos) == 4
            newHeight = max(pos(4) * shrinkFactor, 1);
            delta = (pos(4) - newHeight) ./ 2;
            pos(2) = pos(2) + delta;
            pos(4) = newHeight;
            set(figHandle, 'Position', pos);
        end
    catch
    end
    try
        set(figHandle, 'Units', originalUnits);
    catch
    end
end


function config = get_presentation_mode_config()
    defaultConfig = struct( ...
        'enabled', false, ...
        'legendFontSize', [], ...
        'legendPadding', 10, ...
        'legendItemSize', [20 12]);
    if isappdata(groot, 'caye_slide_mode')
        stored = getappdata(groot, 'caye_slide_mode');
        config = defaultConfig;
        fields = fieldnames(stored);
        for idx = 1:numel(fields)
            config.(fields{idx}) = stored.(fields{idx});
        end
    else
        config = defaultConfig;
    end
    if ~isfield(config, 'legendPadding') || isempty(config.legendPadding)
        config.legendPadding = defaultConfig.legendPadding;
    end
    if ~isfield(config, 'legendItemSize') || isempty(config.legendItemSize)
        config.legendItemSize = defaultConfig.legendItemSize;
    end
end


function style_figure_legends(fig, labelColor, resolvedBg)
    if nargin < 2 || isempty(labelColor)
        labelColor = [1 1 1];
    end
    if nargin < 3 || isempty(resolvedBg)
        resolvedBg = [0 0 0];
    end
    config = get_presentation_mode_config();
    legends = findall(fig, 'Type', 'Legend');
    for idx = 1:numel(legends)
        lg = legends(idx);
        if ~isgraphics(lg, 'legend')
            continue;
        end
        try, set(lg, 'Interpreter', 'none'); catch, end
        try, set(lg, 'AutoUpdate', 'off'); catch, end
        try, set(lg, 'Box', 'on'); catch, end
        try, set(lg, 'Color', resolvedBg); catch, end
        try, set(lg, 'TextColor', labelColor); catch, end
        try, set(lg, 'EdgeColor', labelColor); catch, end
        try, set(lg, 'LineWidth', 1); catch, end
        try, set(lg, 'FitBoxToText', 'on'); catch, end
        if ~isempty(config.legendFontSize)
            try
                currentSize = get(lg, 'FontSize');
                set(lg, 'FontSize', max(config.legendFontSize, currentSize));
            catch
            end
        end
        if ~isempty(config.legendPadding)
            try, set(lg, 'Padding', config.legendPadding); catch, end
        end
        if ~isempty(config.legendItemSize)
            try
                token = get(lg, 'ItemTokenSize');
                if numel(token) == 2
                    token = max(token, config.legendItemSize);
                else
                    token = config.legendItemSize;
                end
                set(lg, 'ItemTokenSize', token);
            catch
            end
        end
    end
end


% Combines a list of PNG files into a single multi-page PDF
function combine_images_to_pdf(pngFiles, pdfPath, exportOpts)
    validMask = cellfun(@(p) ~isempty(p) && exist(p, 'file'), pngFiles);
    pngFiles = pngFiles(validMask);
    if isempty(pngFiles)
        return;
    end
    if exist(pdfPath, 'file')
        delete(pdfPath);
    end

    firstPage = true;
    for idx = 1:numel(pngFiles)
        img = imread(pngFiles{idx});
        comboFig = figure('Visible','off','Units','pixels', ...
            'Color','k', ...                % <- black figure background
            'Position',[100 100 max(1,size(img,2)) max(1,size(img,1))]);
        set(comboFig, 'PaperPositionMode','auto', 'InvertHardcopy','off'); % keep dark
        ax = axes('Parent',comboFig,'Units','normalized','Position',[0 0 1 1], 'Color','k');
        image('Parent',ax,'CData',img);
        axis(ax,'off'); axis(ax,'image'); ax.YDir = 'reverse';
        drawnow;

        if firstPage
            exportgraphics(comboFig, pdfPath, exportOpts{:});
            firstPage = false;
        else
            exportgraphics(comboFig, pdfPath, exportOpts{:}, 'Append', true);
        end
        close(comboFig);
    end
end

function value = parseParameterValue(rawValue)
    if iscell(rawValue)
        if isempty(rawValue)
            value = [];
            return;
        end
        rawValue = rawValue{1};
    end

    if ismissing(rawValue)
        value = [];
        return;
    end

    if isnumeric(rawValue)
        value = double(rawValue);
        return;
    end

    if isstring(rawValue)
        textValue = strtrim(rawValue);
    elseif ischar(rawValue)
        textValue = strtrim(string(rawValue));
    else
        value = rawValue;
        return;
    end

    if strlength(textValue) == 0
        value = [];
        return;
    end

    textChar = char(textValue);
    if numel(textChar) >= 2 && textChar(1) == '"' && textChar(end) == '"'
        textChar = textChar(2:end-1);
    end
    if numel(textChar) >= 2 && textChar(1) == '[' && textChar(end) == ']'
        textChar = textChar(2:end-1);
    end
    textChar = strtrim(strrep(textChar, ',', ' '));

    lowerText = lower(string(textChar));
    if lowerText == "true"
        value = true;
        return;
    elseif lowerText == "false"
        value = false;
        return;
    end

    numericValue = str2num(textChar); %#ok<ST2NM>
    if ~isempty(numericValue)
        value = numericValue;
        return;
    end

    scalarValue = str2double(textChar);
    if ~isnan(scalarValue)
        value = scalarValue;
    else
        value = char(textValue);
    end
end

function cleanup_temp_directory(tempDir)
    if exist(tempDir, 'dir')
        try
            rmdir(tempDir, 's');
        catch cleanupErr
            warning('Failed to remove temporary directory %s: %s', tempDir, cleanupErr.message);
        end
    end
end


function args = collect_cli_args()
    args = {};

    % Gather from base workspace variables if present
    candidateVars = {'caye_cli_args', 'cli_args', 'argv', 'args', 'commandLineArgs'};
    for i = 1:numel(candidateVars)
        name = candidateVars{i};
        try
            existsFlag = evalin('base', sprintf('exist(''%s'',''var'')', name));
        catch
            existsFlag = 0;
        end
        if existsFlag
            rawValue = evalin('base', name);
            args = [args, normalize_cli_arg_value(rawValue)]; %#ok<AGROW>
        end
    end

    % Environment variables
    envVars = {'CAYE_EDITS_ARGS', 'MATLAB_ARGS'};
    for i = 1:numel(envVars)
        envStr = getenv(envVars{i});
        if ~isempty(envStr)
            envTokens = strsplit(strtrim(envStr));
            args = [args, envTokens(~cellfun(@isempty, envTokens))]; %#ok<AGROW>
        end
    end

    % Remove empties and duplicates, preserve order
    args = args(~cellfun(@isempty, args));
    if ~isempty(args)
        [~, uniqueIdx] = unique(args, 'stable');
        args = args(sort(uniqueIdx));
    end
end


function out = normalize_cli_arg_value(value)
    if iscell(value)
        out = normalize_cellstr(value);
    elseif isstring(value)
        out = cellstr(value(:));
    elseif ischar(value)
        out = {value};
    else
        out = {};
    end
    out = out(~cellfun(@isempty, out));
end


function out = normalize_cellstr(value)
    out = {};
    for k = 1:numel(value)
        v = value{k};
        if isstring(v)
            out = [out, cellstr(v(:))]; %#ok<AGROW>
        elseif ischar(v)
            out{end+1} = v; %#ok<AGROW>
        end
    end
end


function defaults = apply_dark_plot_theme_defaults()
    props = {
        'DefaultFigureColor'
        'DefaultFigureInvertHardcopy'
        'DefaultAxesColor'
        'DefaultAxesXColor'
        'DefaultAxesYColor'
        'DefaultAxesZColor'
        'DefaultAxesGridColor'
        'DefaultAxesMinorGridColor'
        'DefaultTextColor'
        'DefaultHistogramEdgeColor'
    };

    defaults = struct();
    for k = 1:numel(props)
        prop = props{k};
        defaults.(prop) = get(groot, prop);
    end

    set(groot, ...
        'DefaultFigureColor', [0 0 0], ...
        'DefaultFigureInvertHardcopy', 'off', ...
        'DefaultAxesColor', [0 0 0], ...
        'DefaultAxesXColor', [1 1 1], ...
        'DefaultAxesYColor', [1 1 1], ...
        'DefaultAxesZColor', [1 1 1], ...
        'DefaultAxesGridColor', [0.4 0.4 0.4], ...
        'DefaultAxesMinorGridColor', [0.25 0.25 0.25], ...
        'DefaultTextColor', [1 1 1], ...
        'DefaultHistogramEdgeColor', 'none');
end


function restore_plot_theme_defaults(defaults)
    if nargin < 1 || isempty(defaults) || ~isstruct(defaults)
        return;
    end
    props = fieldnames(defaults);
    for k = 1:numel(props)
        prop = props{k};
        try
            set(groot, prop, defaults.(prop));
        catch
        end
    end
end


function defaults = apply_presentation_mode_defaults(slideMode)
    config = struct( ...
        'enabled', logical(slideMode), ...
        'legendFontSize', [], ...
        'legendPadding', 10, ...
        'legendItemSize', [20 12]);
    if config.enabled
        config.legendFontSize = 16;
        config.legendPadding = 14;
        config.legendItemSize = [26 14];
    end
    setappdata(groot, 'caye_slide_mode', config);

    defaults = struct('enabled', false, 'props', struct());
    if ~config.enabled
        return;
    end

    props = {
        'DefaultFigureUnits'
        'DefaultFigurePosition'
        'DefaultFigurePaperPositionMode'
        'DefaultAxesFontSize'
        'DefaultTextFontSize'
        'DefaultLegendFontSize'
        'DefaultAxesLabelFontSizeMultiplier'
        'DefaultAxesTitleFontSizeMultiplier'
        'DefaultLineLineWidth'
        'DefaultAxesLineWidth'
    };
    stored = struct();
    for k = 1:numel(props)
        prop = props{k};
        stored.(prop) = get(groot, prop);
    end

    set(groot, ...
        'DefaultFigureUnits', 'pixels', ...
        'DefaultFigurePosition', [100 100 960 640], ...
        'DefaultFigurePaperPositionMode', 'auto', ...
        'DefaultAxesFontSize', 16, ...
        'DefaultTextFontSize', 16, ...
        'DefaultLegendFontSize', 14, ...
        'DefaultAxesLabelFontSizeMultiplier', 1.05, ...
        'DefaultAxesTitleFontSizeMultiplier', 1.08, ...
        'DefaultLineLineWidth', 1.3, ...
        'DefaultAxesLineWidth', 1.1);

    defaults.enabled = true;
    defaults.props = stored;
end


function restore_presentation_mode_defaults(defaults)
    if isappdata(groot, 'caye_slide_mode')
        try
            rmappdata(groot, 'caye_slide_mode');
        catch
        end
    end
    if nargin < 1 || isempty(defaults) || ~isstruct(defaults) || ~isfield(defaults, 'enabled')
        return;
    end
    if ~defaults.enabled
        return;
    end
    props = fieldnames(defaults.props);
    for k = 1:numel(props)
        prop = props{k};
        try
            set(groot, prop, defaults.props.(prop));
        catch
        end
    end
end


% Save current defaults, set new ones, and restore at the end
function restore_figure_defaults(defaultVisibility, defaultCreateFcn)
    set(groot, 'DefaultFigureVisible', defaultVisibility);
    set(groot, 'DefaultFigureCreateFcn', defaultCreateFcn);
end


function [p, x_use, y_use, kept_mask] = polyfit_clipped(x, y, lo, hi, deg, res_mode, res_param)

    if nargin < 5 || isempty(deg), deg = 1; end
    if nargin < 6 || isempty(res_mode), res_mode = 'mad'; end
    if nargin < 7 || isempty(res_param)
        if strcmpi(res_mode,'mad')
            res_param = 3; % 3*MAD by default
        else
            error('polyfit_clipped_new:absThresholdMissing', ...
                'res_param (absolute residual threshold) must be provided for res_mode=''abs''.');
        end
    end

    % Vectorize and primary clipping
    x = x(:);  y = y(:);
    m0 = isfinite(x) & isfinite(y) & ...
        (x ~= 0) & (y ~= 0) & ...
        (abs(y) < 10) & ...
        (x > lo) & (x < hi) & ...
        (x > quantile(x, 0.05)) & (x < quantile(x, 0.95));

    x0 = x(m0);  y0 = y(m0);

    if numel(x0) < (deg + 1)
        error('Not enough points after initial clipping for degree-%d polyfit (need >= %d).', deg, deg+1);
    end

    % ---- First fit
    p0 = polyfit(x0, y0, deg);

    % ---- Residuals
    r = y0 - polyval(p0, x0);

    % ---- Residual-based inlier selection
    switch lower(res_mode)
        case 'mad'
            rmed = median(r);
            madR = median(abs(r - rmed));
            srob = 30 * madR; % robust sigma
            if srob <= 0
                kept_mask = true(size(r)); % all same -> keep all
            else
                kept_mask = abs(r - rmed) <= res_param * srob;
            end
        case 'abs'
            kept_mask = abs(r) <= res_param;
        otherwise
            error('Unknown res_mode: %s (use ''mad'' or ''abs'')', res_mode);
    end

    % Ensure we have enough points; otherwise, fall back to all prefiltered
    if sum(kept_mask) < (deg + 1)
        kept_mask = true(size(r));
    end

    x_use = x0(kept_mask);
    y_use = y0(kept_mask);

    % ---- Refit on inliers
    p = polyfit(x_use, y_use, deg);
end


function [p, x_use, y_use] = polyfit_clipped_new(y, x, lo, hi, deg, mode)
% Fits y = P(x) with:
%   1) range clipping lo < x < hi,
%   2) initial polyfit, residual-based inlier keep (MAD),
%   3) refit on inliers.
% mode: 'x_on_y' is just a mnemonic to remind inputs are (y,x).
    if nargin < 5 || isempty(deg),  deg = 1; end
    x = x(:); y = y(:);
    m0 = isfinite(x) & isfinite(y) & (x > lo) & (x < hi);
    x0 = x(m0); y0 = y(m0);
    if numel(x0) < (deg+1), error('Not enough points for degree-%d fit.',deg); end

    p0 = polyfit(x0, y0, deg);
    r  = y0 - polyval(p0, x0);
    rmed = median(r); madR = median(abs(r - rmed)); srob = 1.4826*madR;
    if srob <= 0, kin = true(size(r)); else, kin = abs(r - rmed) <= 3*srob; end
    if sum(kin) < (deg+1), kin = true(size(r)); end

    x_use = x0(kin); y_use = y0(kin);
    p     = polyfit(x_use, y_use, deg);
end




function plot_narrow_strip_histograms(data, label_prefix, fig_title, capture_tag)
    if nargin < 4 || isempty(capture_tag)
        capture_tag = 'narrow_strip_hist';
    end
    if isempty(data)
        return;
    end

    finite_vals = data(isfinite(data));
    if isempty(finite_vals)
        return;
    end

    min_val = quantile(finite_vals, 0.01);
    max_val = quantile(finite_vals, 0.99);
    % if ~(isfinite(min_val) && isfinite(max_val))
    %     return;
    % end
    % if min_val == max_val
    %     pad = max(abs(min_val), 1) * 0.05 + eps;
    %     min_val = min_val - pad;
    %     max_val = max_val + pad;
    % end

    edges = linspace(min_val, max_val, 120);
    fig = figure('Name', fig_title);
    tl = tiledlayout(fig, 6, 4, 'TileSpacing', 'compact', 'Padding', 'compact');
    nCols = size(data, 2);
    total_tiles = 6 * 4;

    for idx = 1:min(nCols, total_tiles)
        nexttile(tl);
        colData = data(:, idx);
        colData = colData(isfinite(colData));
        if isempty(colData)
            colData = 0;
        end
        histogram(colData, edges, 'FaceColor', [0.25 0.55 0.9], 'EdgeColor', 'none');
        xlim([min_val max_val]);
        grid on; box on;
        title(sprintf('%s strip %02d', label_prefix, idx));
        if mod(idx-1, 4) == 0
            ylabel('Counts');
        end
        if idx > total_tiles - 4
            xlabel('Charge [ADCbins]');
        end
    end
    sgtitle(fig_title);
    capture_debug_png(fig, capture_tag);
end