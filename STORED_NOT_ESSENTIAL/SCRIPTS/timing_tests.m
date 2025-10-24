% Timing tests

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
% Note: the cables were swapped, therefore Qt=Ib... and Qb=It...

% l: leading edge times
% t: trailing edge times
% Q = t - l


% ---------------------------------------------------------------------
% ---------------------------------------------------------------------
% Header
% ---------------------------------------------------------------------
% ---------------------------------------------------------------------

% Print terminal warning to indicate the matlab script starts
fprintf('Starting MATLAB script\n');

% ---------------------------------------------------------------------
% Command-line flag parsing
% ---------------------------------------------------------------------

cli_args = collect_cli_args();
no_plot_flag = any(strcmpi(cli_args, '--no-plot'));

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

should_plot = ~no_plot_flag;

save_plots_dir_default = '/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/DATA_FILES/DATA/PDF';
if ~exist('save_plots','var')
    save_plots = false;
end
if ~exist('save_plots_dir','var') || isempty(save_plots_dir)
    save_plots_dir = save_plots_dir_default;
end
if no_plot_flag
    save_plots = false;
end

clearvars -except save_plots save_plots_dir save_plots_dir_default input_dir keep_raster_temp test run should_plot no_plot_flag;
close all; clc;


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
    run = 4;
end
if isstring(run) || ischar(run)
    run = str2double(run);
end
if isnan(run)
    run = 0;
end

if test
    if run == 1
        input_dir = 'dabc25120133744-dabc25126121423_JOANA_RUN_1_2025-10-08_15h05m00s';
        data_dir = "/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/DATA_FILES/DATA/UNPACKED/IMPORTANT/dabc25120133744-dabc25126121423_JOANA_RUN_1_2025-10-08_15h05m00s";
    elseif run == 2
        input_dir = 'dabc25127151027-dabc25147011139_JOANA_RUN_2_2025-10-08_15h05m00s';
        data_dir = "/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/DATA_FILES/DATA/UNPACKED/IMPORTANT/dabc25127151027-dabc25147011139_JOANA_RUN_2_2025-10-08_15h05m00s";
    elseif run == 3
        input_dir = 'dabc25127151027-dabc25160092400_JOANA_RUN_3_2025-10-08_15h05m00s';
        data_dir = "/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/DATA_FILES/DATA/UNPACKED/IMPORTANT/dabc25127151027-dabc25160092400_JOANA_RUN_3_2025-10-08_15h05m00s";
    elseif run == 4
        input_dir = 'dabc25282152204_RUN_4_2025-10-20_16h00m00s';
        data_dir = "/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/DATA_FILES/DATA/UNPACKED/IMPORTANT/" + input_dir;
    elseif run == 5
        input_dir = 'dabc25291140248_RUN_5_2025-10-20_16h00m00s';
        data_dir = "/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/DATA_FILES/DATA/UNPACKED/IMPORTANT/" + input_dir;
    else
        error('For test mode, set run to 1, 2, 3, 4, or 5.');
    end
end

% if run is not 1,2,3, then set run to 0
if run ~= 1 && run ~= 2 && run ~= 3 && run ~=4 && run ~=5
    run = 0;
end

% Limit the events for testing purposes
limit = true;
limit_number_of_events = 5000;

% Position from narrow strips. Computationally expensive.
position_from_narrow_strips = false;

% ---------------------------------------------------------------------


%%


% ---------------------------------------------------------------------
% ---------------------------------------------------------------------
% File import and Setup
% ---------------------------------------------------------------------
% ---------------------------------------------------------------------


% Some paths ----------------------------------------------------------
HOME    = '/home/csoneira/WORK/LIP_stuff/';
SCRIPTS = 'JOAO_SETUP/STORED_NOT_ESSENTIAL/';
DATA    = 'matFiles/time/';
DATA_Q    = 'matFiles/charge/';
path(path,[HOME SCRIPTS 'util_matPlots/']);

summary_output_dir = '/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/DATA_FILES/DATA/TABLES/';
path(path,'/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/util_matPlots');
project_root = '/home/csoneira/WORK/LIP_stuff/JOAO_SETUP';
mst_saves_root = fullfile(project_root, 'MST_saves');
unpacked_root = fullfile(project_root, 'DATA_FILES', 'DATA', 'UNPACKED', 'PROCESSING');
% ---------------------------------------------------------------------


if isstring(save_plots_dir)
    save_plots_dir = char(save_plots_dir);
end

% Debug: Print the save_plots_dir to verify its value
fprintf('Using save_plots_dir: %s\n', save_plots_dir);

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

if ~exist(summary_output_dir, 'dir')
    mkdir(summary_output_dir);
end

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
    fprintf('Automatically selected oldest MST_saves directory: %s\n', input_dir);
elseif isstring(input_dir)
    input_dir = char(input_dir);
end

if ~test
    data_dir_candidates = {fullfile(unpacked_root, input_dir), fullfile(mst_saves_root, input_dir)};
    existing_dirs = data_dir_candidates(cellfun(@isfolder, data_dir_candidates));
    if isempty(existing_dirs)
        error('Data directory "%s" not found in "%s" or "%s".', input_dir, unpacked_root, mst_saves_root);
    end
    data_dir = existing_dirs{1};
end

time_dir = fullfile(data_dir, 'time');
charge_dir = fullfile(data_dir, 'charge');

if ~isfolder(time_dir)
    error('Time directory not found: %s', time_dir);
end
if ~isfolder(charge_dir)
    error('Charge directory not found: %s', charge_dir);
end

underscore_idx = strfind(input_dir, '_');
if isempty(underscore_idx)
    name_prefix = input_dir;
else
    name_prefix = input_dir(1:underscore_idx(1)-1);
end

dash_idx = strfind(name_prefix, '-');
if isempty(dash_idx)
    dataset_basename = name_prefix;
else
    dataset_basename = name_prefix(1:dash_idx(1)-1);
end

% Extract datetime from the basename and convert to 'yyyy-mm-dd_HH.MM.SS'
datetime_str = regexp(dataset_basename, '\d{11}', 'match', 'once'); % Extract the YYYYDOYHHMMSS part
if isempty(datetime_str)
    error('Failed to extract datetime from basename: %s', dataset_basename);
end

% Parse correctly (calendar year, day-of-year, hour, minute, second)
file_datetime = datetime(datetime_str, 'InputFormat', 'yyyyDDDHHmmss');

% For readability in filenames
formatted_datetime = datestr(file_datetime, 'yyyy-mm-dd_HH.MM.SS');
formatted_datetime_tex = strrep(formatted_datetime, '_', '\_'); % Escape underscores for titles/labels
fprintf("The time of the dataset is: %s\n", formatted_datetime);

execution_datetime = datestr(now, 'yyyy_mm_dd-HH.MM.SS');
if run ~= 0
    pdfFileName = sprintf('RUN_%d_%s_exec_%s.pdf', run, formatted_datetime, execution_datetime);
else
    pdfFileName = sprintf('results_%s_exec_%s.pdf', formatted_datetime, execution_datetime);
end
pdfPath = fullfile(save_plots_dir, pdfFileName);
fprintf("PDF will be saved to: %s\n", pdfPath);

% Dynamically detect time MAT files in the directory
time_files = dir(fullfile(time_dir, sprintf('%s*_T.mat', dataset_basename)));

if isempty(time_files)
    error('No time MAT files found matching "%s*_T.mat" in %s', dataset_basename, time_dir);
end

% Load each time file
for i = 1:length(time_files)
    time_file_path = fullfile(time_dir, time_files(i).name);
    fprintf('Loading time file: %s\n', time_file_path);
    load(time_file_path);
end

charge_listing = dir(fullfile(charge_dir, sprintf('%s*_a*_Q.mat', dataset_basename)));
if isempty(charge_listing)
    error('No charge MAT files found matching "%s_a*_Q.mat" in %s', dataset_basename, charge_dir);
end
charge_files = sort({charge_listing.name});
for idx = 1:numel(charge_files)
    charge_path = fullfile(charge_dir, charge_files{idx});
    fprintf('Loading charge data: %s\n', charge_path);
    load(charge_path);
end

% whos


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

% ------------- Summary -------------
total_nans = sum(replaced_counts);
fprintf('\n=====================================================\n');
fprintf('NaN replacement summary\n');
fprintf('  Variables processed (float): %d\n', numel(replaced_names));
fprintf('  Total NaNs replaced:         %d\n', total_nans);
fprintf('  Variables skipped:           %d\n', numel(skipped_names));
fprintf('=====================================================\n');


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
config_file = fullfile(fileparts(thisFile), 'run_parameters_config.csv');
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
    fprintf('Using configuration column %s for run %d\n', run_field, run);
elseif strcmp(run_field, 'default')
    fprintf('Using default parameter configuration for run %d\n', run);
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
    warning('Variables l31/l32/l30/l28/l29 not found; using alternative channel order 24–28.');
    TFl_OG = [l28 l27 l26 l25 l24];
    TFt_OG = [t28 t27 t26 t25 t24];
    TBl_OG = [l1 l2 l3 l4 l5]; %leading times back [ns]; channels [1,5] -> 5 wide back strips
    TBt_OG = [t1 t2 t3 t4 t5]; %trailing times back [ns]
end

% Charge proxies per strip (front/back)
QF_OG  = TFt_OG - TFl_OG;
QB_OG  = TBt_OG - TBl_OG;





% -----------------------------------------------------------------------------
% RPC charges for the five NARROW STRIPS, which do not carry timing info.
% -----------------------------------------------------------------------------

% Convert charge arrays from cell traces to double matrices (after cable swap).
% note: the cables were swapped, so Qt=Ib and Qb=It

v = cast([Ib IIb IIIb IVb Vb VIb VIIb VIIIb IXb Xb XIb XIIb XIIIb XIVb XVb XVIb XVIIb XVIIIb XIXb XXb XXIb XXIIb XXIIIb XXIVb],"double");
w = cast([It IIt IIIt IVt Vt VIt VIIt VIIIt IXt Xt XIt XIIt XIIIt XIVt XVt XVIt XVIIt XVIIIt XIXt XXt XXIt XXIIt XXIIIt XXIVt],"double");

Qt_OG = v; % top narrow strips charge proxy
Qb_OG = w; % bottom narrow strips charge proxy

Q_thin_top_event_OG = sum(Qt_OG, 2); % total charge in the 5 narrow strips on the top side per event
Q_thin_bot_event_OG = sum(Qb_OG, 2); % total charge in the 5 narrow strips on the bottom side per event

%%

% Ancillary

% Sum 10 to all Qt_OG and Qb_OG to avoid negative values
Qt_test = Qt_OG + charge_top_pedestal;
Qb_test = Qb_OG + charge_bot_pedestal;
Q_thin_top_event_test = sum(Qt_test, 2);
Q_thin_bot_event_test = sum(Qb_test, 2);
% Histogram them, thinner bars

% Create with linspace edges from 0 to 50000
edges = linspace(0, 50000, 150);


%%

% Pedestal addition
Qt_OG = Qt_OG + charge_top_pedestal;
Qb_OG = Qb_OG + charge_bot_pedestal;


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
fprintf('Total raw events with any leading time in Tl_cint: %d\n', rawEvents);

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
fprintf('Total filtered events with any leading time in Tl_cint after PMT cuts: %d\n', filteredEvents);
percentage_good_events_in_pmts = 100 * filteredEvents / rawEvents;
fprintf('Percentage of good events in PMTs after PMT cuts: %.2f%%\n', percentage_good_events_in_pmts);

%channels 1 and 2 -> bottom PMTs
Qcint = [Tt_cint(:,1) - Tl_cint(:,1) Tt_cint(:,2) - Tl_cint(:,2) Tt_cint(:,3) - Tl_cint(:,3) Tt_cint(:,4) - Tl_cint(:,4)]; 

% If Qcint(:,1) == 0, put Qcint(:,2) = 0, if Qcint(:,2) == 0, put Qcint(:,1) = 0
Qcint(Qcint(:,1) == 0, 2) = 0;  % if col1 is 0 → set col2 to 0 (same rows)
Qcint(Qcint(:,2) == 0, 1) = 0;  % if col2 is 0 → set col1 to 0 (same rows)
Qcint(Qcint(:,1) == 0, 2) = 0;  % if col1 is 0 → set col2 to 0 (same rows)
Qcint(Qcint(:,2) == 0, 1) = 0;  % if col2 is 0 → set col1 to 0 (same rows)

Qcint(Qcint(:,3) == 0, 4) = 0;  % if col1 is 0 → set col2 to 0 (same rows)
Qcint(Qcint(:,4) == 0, 3) = 0;  % if col2 is 0 → set col1 to 0 (same rows)
Qcint(Qcint(:,3) == 0, 4) = 0;  % if col1 is 0 → set col2 to 0 (same rows)
Qcint(Qcint(:,4) == 0, 3) = 0;  % if col2 is 0 → set col1 to 0 (same rows)


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

% Zero BOTH QF and QB wherever |QF - QB| < threshold (column-wise, all 5 strips)
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
% Definition of new datasets
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
% Same as before, validEvents_coin = (Qcint(:,1) ~= 0) & (Qcint(:,2) ~= 0) & (Qcint(:,3) ~= 0) & (Qcint(:,4) ~= 0);


% Apply masks ---------------------------------------------------------

% --- PMTs --- N x 4
Qcint_good = zeros(size(Qcint), 'like', Qcint);
Qcint_good(validEvents_coin, :) = Qcint(validEvents_coin, :);

% --- THICK ---
X_thick_strip_good = zeros(size(X_thick_strip), 'like', X_thick_strip);
Y_thick_strip_good = zeros(size(Y_thick_strip), 'like', Y_thick_strip);
T_thick_strip_good = zeros(size(T_thick_strip), 'like', T_thick_strip);
Q_thick_strip_good = zeros(size(Q_thick_event), 'like', Q_thick_event);
X_thick_strip_good(validEvents_coin, :) = X_thick_strip(validEvents_coin, :);
Y_thick_strip_good(validEvents_coin, :) = Y_thick_strip(validEvents_coin, :);
T_thick_strip_good(validEvents_coin, :) = T_thick_strip(validEvents_coin, :);
Q_thick_strip_good(validEvents_coin) = Q_thick_event(validEvents_coin);

% Extra, only for calibration checking
QF_good = zeros(size(QF), 'like', QF);
QB_good = zeros(size(QB), 'like', QB);
QF_p_good = zeros(size(QF_p), 'like', QF_p);
QB_p_good = zeros(size(QB_p), 'like', QB_p);
QF_good(validEvents_coin, :) = QF(validEvents_coin, :);
QB_good(validEvents_coin, :) = QB(validEvents_coin, :);
QF_p_good(validEvents_coin, :) = QF_p(validEvents_coin, :);
QB_p_good(validEvents_coin, :) = QB_p(validEvents_coin, :);

% --- THIN STRIPS ---
Qb_good = zeros(size(Qb), 'like', Qb);
Qt_good = zeros(size(Qt), 'like', Qt);
Qb_good(validEvents_coin, :) = Qb(validEvents_coin, :);
Qt_good(validEvents_coin, :) = Qt(validEvents_coin, :);

% Totals per event --- N x 1
Q_thin_top_event_good = sum(Qt_good, 2);
Q_thin_bot_event_good = sum(Qb_good, 2);



% ------------------------------------------------------------------------
% ==================== RANGE EVENTS (zero-out others) ====================
% ------------------------------------------------------------------------

% Create masks------------------------------------------------------------
fprintf("Calculating PMT charge thresholds for run 0 based on 20th and 80th percentiles.\n");
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

validEventsFiltered_range = ...
    (Qcint(:,1) >= pmt_1_charge_threshold_min) & (Qcint(:,1) <= pmt_1_charge_threshold_max) & ...
    (Qcint(:,2) >= pmt_2_charge_threshold_min) & (Qcint(:,2) <= pmt_2_charge_threshold_max) & ...
    (Qcint(:,3) >= pmt_3_charge_threshold_min) & (Qcint(:,3) <= pmt_3_charge_threshold_max) & ...
    (Qcint(:,4) >= pmt_4_charge_threshold_min) & (Qcint(:,4) <= pmt_4_charge_threshold_max);

% Apply masks ------------------------------------------------------------

% --- PMTs --- N x 4
Qcint_range = zeros(size(Qcint_good), 'like', Qcint_good);
Qcint_range(validEventsFiltered_range, :) = Qcint_good(validEventsFiltered_range, :);

% --- THICK STRIPS --- N x 1
X_thick_strip_range = zeros(size(X_thick_strip_good), 'like', X_thick_strip_good);
Y_thick_strip_range = zeros(size(Y_thick_strip_good), 'like', Y_thick_strip_good);
T_thick_strip_range = zeros(size(T_thick_strip_good), 'like', T_thick_strip_good);
Q_thick_strip_range = zeros(size(Q_thick_strip_good), 'like', Q_thick_strip_good);
X_thick_strip_range(validEventsFiltered_range, :) = X_thick_strip_good(validEventsFiltered_range, :);
Y_thick_strip_range(validEventsFiltered_range, :) = Y_thick_strip_good(validEventsFiltered_range, :);
T_thick_strip_range(validEventsFiltered_range, :) = T_thick_strip_good(validEventsFiltered_range, :);

Q_thick_strip_range(validEventsFiltered_range) = Q_thick_strip_good(validEventsFiltered_range);

% --- THIN STRIPS --- N x 24
Qb_range = zeros(size(Qb_good), 'like', Qb_good);
Qt_range = zeros(size(Qt_good), 'like', Qt_good);
Qb_range(validEventsFiltered_range, :) = Qb_good(validEventsFiltered_range, :);
Qt_range(validEventsFiltered_range, :) = Qt_good(validEventsFiltered_range, :);

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
q005_b = quantile(Q_thin_bot_event_good, 0.01);
q005_t = quantile(Q_thin_top_event_good, 0.01);
q005   = min(q005_b, q005_t);

q95_b  = quantile(Q_thin_bot_event_good, 0.99);
q95_t  = quantile(Q_thin_top_event_good, 0.99);
q95    = max(q95_b, q95_t);

% Thick channel limits (separate scale)
t_lead_back_left = min(quantile(TBl, 0.001));
t_lead_front_left = min(quantile(TFl, 0.001));
t_lead_left = min(t_lead_back_left, t_lead_front_left);
t_lead_back_right = min(quantile(TBl, 0.999));
t_lead_front_right = min(quantile(TFl, 0.999));
t_lead_right = max(t_lead_back_right, t_lead_front_right);

t_trail_back_left = min(quantile(TBt, 0.001));
t_trail_front_left = min(quantile(TFt, 0.001));
t_trail_left = min(t_trail_back_left, t_trail_front_left);
t_trail_back_right = min(quantile(TBt, 0.999));
t_trail_front_right = min(quantile(TFt, 0.999));
t_trail_right = max(t_trail_back_right, t_trail_front_right);

t005_thick = quantile(T_thick_strip_good, 0.001);
t95_thick  = quantile(T_thick_strip_good, 0.999);
q005_thick = quantile(Q_thick_strip_good, 0.001);
q95_thick  = quantile(Q_thick_strip_good, 0.999);

% Bin edges (match your “like this” snippet for thin; keep fine bins for thick)
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

fprintf('Percentage of streamers (Q > threshold) in Thin RPC TOP: %.2f%%\n', percentage_streamer_thin_top);
fprintf('Percentage of streamers (Q > threshold) in Thick RPC: %.2f%%\n', percentage_streamer_thick);
fprintf('Percentage of streamers (Q > threshold) in Thin RPC BOTTOM: %.2f%%\n', percentage_streamer_thin_bot);

% Take only positive charges for the plots in a new vector that does not replace the original
Q_thick_plot = Q_thick(isfinite(Q_thick) & Q_thick > 0);
Q_thin_top_plot = Q_thin_top(isfinite(Q_thin_top) & Q_thin_top > 0);
Q_thin_bot_plot = Q_thin_bot(isfinite(Q_thin_bot) & Q_thin_bot > 0);


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

outdir = '/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/DATA_FILES/DATA/CHARGES/';
if ~exist(outdir, 'dir')
    mkdir(outdir);
end

outfile = sprintf('%sthick_strip_charge_histogram_run_%d.csv', outdir, run);
writetable(charge_histogram_table, outfile);

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



%%


thin_top_threshold = 0;
thin_bot_threshold = 0;
thick_threshold   = 0;

% Print these three limits
fprintf('Using thresholds for efficiency calculation:\n');
fprintf('  Thick RPC: %g ADC bins\n', thick_threshold);
fprintf('  Thin RPC TOP: %g ADC bins\n', thin_top_threshold);
fprintf('  Thin RPC BOTTOM: %g ADC bins\n', thin_bot_threshold);

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

% Allocate with 3 extra columns for Mean/Median/Max (prev was +1 for StreamerPct)
detRows = cell(nDet, 1 + 2*nVar + 4);

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
end

% Column names
varNames = {'Detector'};
for c = 1:nVar
    varNames{end+1} = variantOrder{c};
    varNames{end+1} = [variantOrder{c} '_unc'];
end
varNames = [varNames, {'StreamerPct','MeanCharge','MedianCharge','MaxCharge'}];

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
fprintf('\n==== Efficiency Summary (RPCs only; values in %%) ====\n');

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
fprintf('\n==== Charge Summary (RPCs only; ADC bins, streamer in %%) ====\n');

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
    summaryFileName = sprintf('RUN_%d_summary_%s_exec_%s.csv', run, formatted_datetime, execution_datetime);
else
    summaryFileName = sprintf('summary_%s_exec_%s.csv', formatted_datetime, execution_datetime);
end
outCsv = fullfile(summary_output_dir, summaryFileName);

fid = fopen(outCsv, 'w');
% Update header comment with new column ordering
fprintf(fid, '# total_raw_events: %d\n', total_raw_events);
fprintf(fid, '# percentage_good_events_in_pmts: %.4f\n', percentage_good_events_in_pmts);
fprintf(fid, '# run_number: %d\n', run);
fprintf(fid, '%s\n', strjoin(varNames, ', '));
fclose(fid);

writetable(detTable, outCsv, 'WriteMode','append');

if ~should_plot
    fprintf('No-plot flag enabled; CSV saved to %s. Exiting before plot generation.\n', outCsv);
    return;
end


% Print for verification
fprintf('Save plots directory: %s\n', save_plots_dir);
fprintf('PDF file name: %s\n', pdfFileName);

if should_plot && save_plots
    try
        if ~exist(save_plots_dir, 'dir'), mkdir(save_plots_dir); end
        [pdfPath, figCount] = save_all_figures_to_pdf(save_plots_dir, pdfFileName);
        if figCount > 0 && ~isempty(pdfPath)
            fprintf('Saved %d figure(s) to %s\n', figCount, pdfPath);
        else
            fprintf('No figures generated to save.\n');
        end
    catch saveErr
        warning('Failed to save figures.');
    end
end


%%

% -------------------------------------------------------------------------
% -------------------------------------------------------------------------
% Functions ---------------------------------------------------------------
% -------------------------------------------------------------------------
% -------------------------------------------------------------------------


% Define a function called mm_to_strip that converts mm to strip number
function strip = mm_to_strip(mm)
    % Map from mm in [-150, 150] → strip in [0, 120]
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
function [pdfPath, figCount] = save_all_figures_to_pdf(targetDir, pdfFileName)
    figs = findall(0, 'Type', 'figure');
    figCount = numel(figs);
    pdfPath = '';
    if figCount == 0
        return;
    end
    if ~exist(targetDir, 'dir')
        mkdir(targetDir);
    end
    pdfPath = fullfile(targetDir, pdfFileName);

    % Sort by figure number for stable ordering
    [~, sortIdx] = sort([figs.Number]);
    figs = figs(sortIdx);

    % -------- Raster options (black bg + moderate DPI) --------
    % Allow overriding from base workspace: save_dpi = 120/150/200 ...
    try
        dpi = evalin('base', 'save_dpi');
        if isempty(dpi) || ~isscalar(dpi), dpi = 100; end
    catch
        dpi = 100;
    end
    rasterOpts = {'ContentType','image','Resolution',dpi,'BackgroundColor','black'};

    % Temp folder for per-page PNGs
    tempDir = tempname(targetDir);
    mkdir(tempDir);
    fprintf('Rasterizing %d figure(s) into %s (DPI=%d, bg=black)\n', figCount, tempDir, dpi);

    keepRasterTemp = false;
    cleanupObj = [];
    try
        keepRasterTemp = evalin('base', "exist(''keep_raster_temp'',''var'') && logical(keep_raster_temp)");
    catch
        keepRasterTemp = false;
    end
    if keepRasterTemp
        fprintf('keep_raster_temp is true; temporary PNGs will be left in place.\n');
    else
        cleanupObj = onCleanup(@() cleanup_temp_directory(tempDir)); %#ok<NASGU>
    end

    % Export each figure to a PNG with dark bg and close it
    pngFiles = cell(figCount, 1);
    for k = 1:figCount
        fig = figs(k);
        % Ensure figure won’t invert colors on save (belt & suspenders)
        try, set(fig, 'InvertHardcopy','off'); end
        % If the figure wasn't created with dark defaults, force them now
        try, set(fig, 'Color','k'); end
        ax = findall(fig, 'Type','axes');
        for a = reshape(ax,1,[])
            try
                set(a, 'Color','k', 'XColor','w','YColor','w','ZColor','w');
            end
        end

        pngFiles{k} = fullfile(tempDir, sprintf('page_%04d.png', k));
        exportgraphics(fig, pngFiles{k}, rasterOpts{:});
        close(fig);
    end

    % Combine into a multi-page PDF (also with black bg)
    try
        combine_images_to_pdf(pngFiles, pdfPath, rasterOpts);
    catch combineErr
        warning(combineErr.identifier, '%s', combineErr.message);
        pdfPath = '';
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


% Save current defaults, set new ones, and restore at the end
function restore_figure_defaults(defaultVisibility, defaultCreateFcn)
    set(groot, 'DefaultFigureVisible', defaultVisibility);
    set(groot, 'DefaultFigureCreateFcn', defaultCreateFcn);
end
