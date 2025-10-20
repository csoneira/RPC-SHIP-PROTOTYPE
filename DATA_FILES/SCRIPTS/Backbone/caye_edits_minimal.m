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

save_plots_dir_default = '/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/DATA_FILES/DATA/PDF';
if ~exist('save_plots','var')
    save_plots = false;
end
if ~exist('save_plots_dir','var') || isempty(save_plots_dir)
    save_plots_dir = save_plots_dir_default;
end

clearvars -except save_plots save_plots_dir save_plots_dir_default input_dir keep_raster_temp;
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
    run = 5;
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
        input_dir = 'dabc25291140248_RUN_5_2025-10-20_11h51m27s';
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

figure; histogram(Q_thin_top_event_test, edges, 'Normalization', 'probability'); 
xlabel('Charge (ADC bins)'); ylabel('Probability'); title('Positive Charges (Thin)'); hold on;
histogram(Q_thin_bot_event_test, edges, 'Normalization', 'probability');

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

figure;
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
% Quick Visual Checks
% ---------------------------------------------------------------------
% ---------------------------------------------------------------------

% -----------------------------------------------------------------------------
% Scintillator Timing and Charge Derivations
% -----------------------------------------------------------------------------

% Plot scatter plots of Tl_cint i vs Tl_cint j for all PMT pairs to verify the
% coincidence cut. In the same figure the 6 pairs

figure;
subplot(2,2,1); plot(Tl_cint_OG(:,1), Tt_cint_OG(:,1),'.'); hold on; plot(Tl_cint(:,1), Tt_cint(:,1),'.');
xlabel('Tl_cint1');ylabel('Tt_cint1'); title('Time lead vs trail PMT1');
xlim(lead_time_limits_pmt); ylim(trail_time_limits_pmt);
xline(lead_time_pmt_min, 'r--'); xline(lead_time_pmt_max, 'r--');
yline(trail_time_pmt_min, 'r--'); yline(trail_time_pmt_max, 'r--');
subplot(2,2,2); plot(Tl_cint_OG(:,2), Tt_cint_OG(:,2),'.'); hold on; plot(Tl_cint(:,2), Tt_cint(:,2),'.');
xlabel('Tl_cint2'); ylabel('Tt_cint2'); title('Time lead vs trail PMT2');
xlim(lead_time_limits_pmt); ylim(trail_time_limits_pmt);
xline(lead_time_pmt_min, 'r--'); xline(lead_time_pmt_max, 'r--');
yline(trail_time_pmt_min, 'r--'); yline(trail_time_pmt_max, 'r--');
subplot(2,2,3); plot(Tl_cint_OG(:,3), Tt_cint_OG(:,3),'.'); hold on; plot(Tl_cint(:,3), Tt_cint(:,3),'.');
xlabel('Tl_cint3'); ylabel('Tt_cint3'); title('Time lead vs trail PMT3');
xlim(lead_time_limits_pmt); ylim(trail_time_limits_pmt);
xline(lead_time_pmt_min, 'r--'); xline(lead_time_pmt_max, 'r--');
yline(trail_time_pmt_min, 'r--'); yline(trail_time_pmt_max, 'r--');
subplot(2,2,4); plot(Tl_cint_OG(:,4), Tt_cint_OG(:,4),'.'); hold on; plot(Tl_cint(:,4), Tt_cint(:,4),'.');
xlabel('Tl_cint4'); ylabel('Tt_cint4'); title('Time lead vs trail PMT4');
xlim(lead_time_limits_pmt); ylim(trail_time_limits_pmt);
sgtitle(sprintf('PMT time lead vs trail (data from %s)', formatted_datetime_tex));
xline(lead_time_pmt_min, 'r--'); xline(lead_time_pmt_max, 'r--');
yline(trail_time_pmt_min, 'r--'); yline(trail_time_pmt_max, 'r--');


% Now plot the charge correlations for the same PMT pairs
figure;
subplot(1,2,1); plot(Qcint_OG(:,1), Qcint_OG(:,2), '.'); hold on; plot(Qcint(:,1), Qcint(:,2), '.');
xlabel('Qcint1'); ylabel('Qcint2'); title('Charge PMT1 vs PMT2');
xlim(charge_limits_pmt); ylim(charge_limits_pmt);
subplot(1,2,2); plot(Qcint_OG(:,3), Qcint_OG(:,4), '.'); hold on; plot(Qcint(:,3), Qcint(:,4), '.');
xlabel('Qcint3'); ylabel('Qcint4'); title('Charge PMT3 vs PMT4');
xlim(charge_limits_pmt); ylim(charge_limits_pmt);
sgtitle(sprintf('PMT charge correlations (data from %s)', formatted_datetime_tex));


% Finally, plot the Tl_cint i vs Tl_cint j scatter plots for all PMT pairs
figure;
subplot(1,2,1); plot(Tl_cint_OG(:,1), Tl_cint_OG(:,2),'.'); hold on; plot(Tl_cint(:,1), Tl_cint(:,2),'.');
xlabel('Tl_cint1'); ylabel('Tl_cint2'); title('Time lead PMT1 vs PMT2');
xlim(lead_time_limits_pmt); ylim(lead_time_limits_pmt);
refline(1, time_pmt_diff_thr); refline(1, -time_pmt_diff_thr); % Plot the line y = x +- time_pmt_diff_thr
subplot(1,2,2); plot(Tl_cint_OG(:,3), Tl_cint_OG(:,4),'.'); hold on; plot(Tl_cint(:,3), Tl_cint(:,4),'.');
xlabel('Tl_cint3'); ylabel('Tl_cint4'); title('Time lead PMT3 vs PMT4');
xlim(lead_time_limits_pmt); ylim(lead_time_limits_pmt);
sgtitle(sprintf('PMT time coincidences (data from %s)', formatted_datetime_tex));
refline(1, time_pmt_diff_thr); refline(1, -time_pmt_diff_thr); % Plot the line y = x +- time_pmt_diff_thr


% Histograms of Tl for each strip to see the distribution of the difference
% Normalized histograms of the time lead differences for each PMT pair to verify the
figure;
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
sgtitle(sprintf('Histograms of time lead differences for PMTs (data from %s)', formatted_datetime_tex));
xline(time_pmt_diff_thr); xline(-time_pmt_diff_thr);



% -----------------------------------------------------------------------------
% RPC wide strip Timing and Charge Derivations
% -----------------------------------------------------------------------------

% leading times front [ns]; channels [32,28] -> 5 wide front strips
% TFl, TFt
% TBl, TBt

% Similar scatter subplot plots for the wide strips to verify no obvious problems.
figure;
xlimits_1 = [t_lead_left t_lead_right];
ylimits_1 = [t_trail_left t_trail_right];
subplot(2,5,1); plot(TFl_OG(:,1), TFt_OG(:,1),'.'); hold on; plot(TFl(:,1), TFt(:,1),'.');
xlabel('TFl'); ylabel('TFt'); title('Front, Time lead vs trail strip1');
xlim(xlimits_1); ylim(ylimits_1);
xline(lead_time_wide_strip_min, 'r--'); xline(lead_time_wide_strip_max, 'r--');
yline(trail_time_wide_strip_min, 'r--'); yline(trail_time_wide_strip_max, 'r--');
subplot(2,5,2); plot(TFl_OG(:,2), TFt_OG(:,2),'.'); hold on; plot(TFl(:,2), TFt(:,2),'.');
xlabel('TFl'); ylabel('TFt'); title('Front, Time lead vs trail strip2');
xlim(xlimits_1); ylim(ylimits_1);
xline(lead_time_wide_strip_min, 'r--'); xline(lead_time_wide_strip_max, 'r--');
yline(trail_time_wide_strip_min, 'r--'); yline(trail_time_wide_strip_max, 'r--');
subplot(2,5,3); plot(TFl_OG(:,3), TFt_OG(:,3),'.'); hold on; plot(TFl(:,3), TFt(:,3),'.');
xlabel('TFl'); ylabel('TFt'); title('Time lead Front vs back strip3');
xlim(xlimits_1); ylim(ylimits_1);
xline(lead_time_wide_strip_min, 'r--'); xline(lead_time_wide_strip_max, 'r--');
yline(trail_time_wide_strip_min, 'r--'); yline(trail_time_wide_strip_max, 'r--');
subplot(2,5,4); plot(TFl_OG(:,4), TFt_OG(:,4),'.'); hold on; plot(TFl(:,4), TFt(:,4),'.');
xlabel('TFl'); ylabel('TFt'); title('Front, Time lead vs trail strip4');
xlim(xlimits_1); ylim(ylimits_1);
xline(lead_time_wide_strip_min, 'r--'); xline(lead_time_wide_strip_max, 'r--');
yline(trail_time_wide_strip_min, 'r--'); yline(trail_time_wide_strip_max, 'r--');
subplot(2,5,5); plot(TFl_OG(:,5), TFt_OG(:,5),'.'); hold on; plot(TFl(:,5), TFt(:,5),'.');
xlabel('TFl'); ylabel('TFt'); title('Front, Time lead vs trail strip5');
xlim(xlimits_1); ylim(ylimits_1);
xline(lead_time_wide_strip_min, 'r--'); xline(lead_time_wide_strip_max, 'r--');
yline(trail_time_wide_strip_min, 'r--'); yline(trail_time_wide_strip_max, 'r--');
subplot(2,5,6); plot(TBl_OG(:,1), TBt_OG(:,1),'.'); hold on; plot(TBl(:,1), TBt(:,1),'.');
xlabel('TBl'); ylabel('TBt'); title('Back, Time lead vs trail strip1');
xlim(xlimits_1); ylim(ylimits_1);
xline(lead_time_wide_strip_min, 'r--'); xline(lead_time_wide_strip_max, 'r--');
yline(trail_time_wide_strip_min, 'r--'); yline(trail_time_wide_strip_max, 'r--');
subplot(2,5,7); plot(TBl_OG(:,2), TBt_OG(:,2),'.'); hold on; plot(TBl(:,2), TBt(:,2),'.');
xlabel('TBl'); ylabel('TBt'); title('Back, Time lead vs trail strip2');
xlim(xlimits_1); ylim(ylimits_1);
xline(lead_time_wide_strip_min, 'r--'); xline(lead_time_wide_strip_max, 'r--');
yline(trail_time_wide_strip_min, 'r--'); yline(trail_time_wide_strip_max, 'r--');
subplot(2,5,8); plot(TBl_OG(:,3), TBt_OG(:,3),'.'); hold on; plot(TBl(:,3), TBt(:,3),'.');
xlabel('TBl'); ylabel('TBt'); title('Back, Time lead vs trail strip3');
xlim(xlimits_1); ylim(ylimits_1);
xline(lead_time_wide_strip_min, 'r--'); xline(lead_time_wide_strip_max, 'r--');
yline(trail_time_wide_strip_min, 'r--'); yline(trail_time_wide_strip_max, 'r--');
subplot(2,5,9); plot(TBl_OG(:,4), TBt_OG(:,4),'.'); hold on; plot(TBl(:,4), TBt(:,4),'.');
xlabel('TBl'); ylabel('TBt'); title('Back, Time lead vs trail strip4');
xlim(xlimits_1); ylim(ylimits_1);
xline(lead_time_wide_strip_min, 'r--'); xline(lead_time_wide_strip_max, 'r--');
yline(trail_time_wide_strip_min, 'r--'); yline(trail_time_wide_strip_max, 'r--');
subplot(2,5,10); plot(TBl_OG(:,5), TBt_OG(:,5),'.'); hold on; plot(TBl(:,5), TBt(:,5),'.');
xlabel('TBl'); ylabel('TBt'); title('Back, Time lead vs trail strip5');
xlim(xlimits_1); ylim(ylimits_1);
sgtitle(sprintf('Thick strip time lead vs trail (data from %s)', formatted_datetime_tex));
xline(lead_time_wide_strip_min, 'r--'); xline(lead_time_wide_strip_max, 'r--');
yline(trail_time_wide_strip_min, 'r--'); yline(trail_time_wide_strip_max, 'r--');


figure;
xlimits_1 = [t_lead_left t_lead_right];
ylimits_1 = [t_lead_left t_lead_right];
subplot(2,5,1); plot(TFl_OG(:,1), TBl_OG(:,1),'.'); hold on; plot(TFl(:,1), TBl(:,1),'.');
xlabel('TFl'); ylabel('TBl'); title('Time lead Front vs back strip1');
xlim(xlimits_1); ylim(ylimits_1);
xline(lead_time_wide_strip_min, 'r--'); xline(lead_time_wide_strip_max, 'r--');
yline(lead_time_wide_strip_min, 'r--'); yline(lead_time_wide_strip_max, 'r--');
subplot(2,5,2); plot(TFl_OG(:,2), TBl_OG(:,2),'.'); hold on; plot(TFl(:,2), TBl(:,2),'.');
xlabel('TFl'); ylabel('TBl'); title('Time lead Front vs back strip2');
xlim(xlimits_1); ylim(ylimits_1);
xline(lead_time_wide_strip_min, 'r--'); xline(lead_time_wide_strip_max, 'r--');
yline(lead_time_wide_strip_min, 'r--'); yline(lead_time_wide_strip_max, 'r--');
subplot(2,5,3); plot(TFl_OG(:,3), TBl_OG(:,3),'.'); hold on; plot(TFl(:,3), TBl(:,3),'.');
xlabel('TFl'); ylabel('TBl'); title('Time lead Front vs back strip3');
xlim(xlimits_1); ylim(ylimits_1);
xline(lead_time_wide_strip_min, 'r--'); xline(lead_time_wide_strip_max, 'r--');
yline(lead_time_wide_strip_min, 'r--'); yline(lead_time_wide_strip_max, 'r--');
subplot(2,5,4); plot(TFl_OG(:,4), TBl_OG(:,4),'.'); hold on; plot(TFl(:,4), TBl(:,4),'.');
xlabel('TFl'); ylabel('TBl'); title('Time lead Front vs back strip4');
xlim(xlimits_1); ylim(ylimits_1);
xline(lead_time_wide_strip_min, 'r--'); xline(lead_time_wide_strip_max, 'r--');
yline(lead_time_wide_strip_min, 'r--'); yline(lead_time_wide_strip_max, 'r--');
subplot(2,5,5); plot(TFl_OG(:,5), TBl_OG(:,5),'.'); hold on; plot(TFl(:,5), TBl(:,5),'.');
xlabel('TFl'); ylabel('TBl'); title('Time lead Front vs back strip5');
xlim(xlimits_1); ylim(ylimits_1);
xline(lead_time_wide_strip_min, 'r--'); xline(lead_time_wide_strip_max, 'r--');
yline(lead_time_wide_strip_min, 'r--'); yline(lead_time_wide_strip_max, 'r--');

xlimits_2 = [q005_thick q95_thick];
ylimits_2 = [q005_thick q95_thick];
subplot(2,5,6); plot(QF_OG(:,1), QB_OG(:,1),'.'); hold on; plot(QF(:,1), QB(:,1),'.');
xlabel('QF'); ylabel('QB'); title('Charge Front vs back strip1');
xlim(xlimits_2); ylim(ylimits_2);
subplot(2,5,7); plot(QF_OG(:,2), QB_OG(:,2),'.'); hold on; plot(QF(:,2), QB(:,2),'.');
xlabel('QF'); ylabel('QB'); title('Charge Front vs back strip2');
xlim(xlimits_2); ylim(ylimits_2);
subplot(2,5,8); plot(QF_OG(:,3), QB_OG(:,3),'.'); hold on; plot(QF(:,3), QB(:,3),'.');
xlabel('QF'); ylabel('QB'); title('Charge Front vs back strip3');
xlim(xlimits_2); ylim(ylimits_2);
subplot(2,5,9); plot(QF_OG(:,4), QB_OG(:,4),'.'); hold on; plot(QF(:,4), QB(:,4),'.');
xlabel('QF'); ylabel('QB'); title('Charge Front vs back strip4');
xlim(xlimits_2); ylim(ylimits_2);
subplot(2,5,10); plot(QF_OG(:,5), QB_OG(:,5),'.'); hold on; plot(QF(:,5), QB(:,5),'.');
xlabel('QF'); ylabel('QB'); title('Charge Front vs back strip5');
xlim(xlimits_2); ylim(ylimits_2);
sgtitle(sprintf('Thick strip time and charge front vs back (data from %s)', formatted_datetime_tex));


right_lim_q_wide = 100; %adjust as needed

figure;
for strip = 1:5
    % Left column: uncalibrated
    subplot(5,2,strip*2-1);
    % Avoid plotting zero values
    QF_nonzero = QF_good(:,strip); QF_nonzero(QF_nonzero==0) = [];
    QB_nonzero = QB_good(:,strip); QB_nonzero(QB_nonzero==0) = [];
    histogram(QF_nonzero,-2:1:150); hold on;
    histogram(QB_nonzero,-2:1:150); xlim([-2 150]);
    legend(sprintf('QF - strip%d', strip), sprintf('QB - strip%d', strip), 'Location', 'northeast');
    ylabel('# of events');
    xlabel('Q [ns]');
    % Right column: calibrated
    subplot(5,2,strip*2);
    % Avoid plotting zero values
    QF_p_nonzero = QF_p_good(:,strip); QF_p_nonzero(QF_p_nonzero==0) = [];
    QB_p_nonzero = QB_p_good(:,strip); QB_p_nonzero(QB_p_nonzero==0) = [];
    histogram(QF_p_nonzero, -2:1:right_lim_q_wide); hold on;
    histogram(QB_p_nonzero, -2:1:right_lim_q_wide);
    xlim([-2 right_lim_q_wide]);
    legend(sprintf('QF - strip%d', strip), sprintf('QB - strip%d', strip), 'Location', 'northeast');
    ylabel('# of events');
    xlabel('Q [ns]');
    sgtitle(sprintf('Wide strip charge spectra and calibration (data from %s)', formatted_datetime_tex));
end


figure;
% Avoid plotting zero values in histograms, take ~= 0 values
Q_nonzero = Q_thick_strip_OG; Q_nonzero(Q_nonzero==0) = [];
X_nonzero = X_thick_strip_OG; X_nonzero(X_nonzero==0) = [];
T_nonzero = T_thick_strip_OG; T_nonzero(T_nonzero==0) = [];
Y_nonzero = Y_thick_strip_OG; Y_nonzero(Y_nonzero==0) = [];
subplot(2,2,1); histogram(Q_nonzero, 0:0.1:200); xlabel('Q [ns]'); ylabel('# of events'); title('Q total in sum of THICK STRIPS');
subplot(2,2,2); histogram(X_nonzero, 1:0.5:5.5); xlabel('X (strip with Qmax)'); ylabel('# of events'); title('X position (strip with Qmax)');
subplot(2,2,3); histogram(T_nonzero, -220:1:-100); xlabel('T [ns]'); ylabel('# of events'); title('T (mean of Tfl and Tbl)');
subplot(2,2,4); histogram(Y_nonzero, -2:0.01:2); xlabel('Y [ns]'); ylabel('# of events'); title('Y (Tfl-Tbl)/2');
sgtitle(sprintf('THICK STRIP OBSERVABLES (data from %s)', formatted_datetime_tex));


figure;
% Avoid plotting zero values in histograms, take ~= 0 values
Q_nonzero = Q_thick_strip_good; Q_nonzero(Q_nonzero==0) = [];
X_nonzero = X_thick_strip_good; X_nonzero(X_nonzero==0) = [];
T_nonzero = T_thick_strip_good; T_nonzero(T_nonzero==0) = [];
Y_nonzero = Y_thick_strip_good; Y_nonzero(Y_nonzero==0) = [];
subplot(2,2,1); histogram(Q_nonzero, 0:0.1:200); xlabel('Q [ns]'); ylabel('# of events'); title('Q total in sum of THICK STRIPS');
subplot(2,2,2); histogram(X_nonzero, 1:0.5:5.5); xlabel('X (strip with Qmax)'); ylabel('# of events'); title('X position (strip with Qmax)');
subplot(2,2,3); histogram(T_nonzero, -220:1:-100); xlabel('T [ns]'); ylabel('# of events'); title('T (mean of Tfl and Tbl)');
subplot(2,2,4); histogram(Y_nonzero, -2:0.01:2); xlabel('Y [ns]'); ylabel('# of events'); title('Y (Tfl-Tbl)/2');
sgtitle(sprintf('THICK STRIP OBSERVABLES (data from %s)', formatted_datetime_tex));


% Histograms of QF-QB for each strip to see the distribution of the difference
% Normalized histograms for better comparison
figure;
for i = 1:5
    subplot(5,1,i);
    % Do not histogram zero values
    valid_diff_OG = QF_OG(:,i) - QB_OG(:,i);
    valid_diff_OG(valid_diff_OG == 0) = [];
    histogram(valid_diff_OG, 300, 'Normalization', 'probability');
    hold on;
    valid_diff = QF(:,i) - QB(:,i);
    valid_diff(valid_diff == 0) = [];
    histogram(valid_diff, 100, 'Normalization', 'probability');
    title(sprintf('Histogram of QF - QB for wide strip %d (run %s)', i, run));
    xlabel('QF - QB [ns]');
    ylabel('Counts');
    xline(charge_wide_strip_diff_thr, 'r--'); xline(-charge_wide_strip_diff_thr, 'r--');
end
sgtitle(sprintf('Histograms of QF - QB for all WIDE strips (data from %s)', formatted_datetime_tex));

% Scatter plots of all pairs of Q, X, T, Y for the thick strips (always color version)
Qv = Q(:); Xv = X(:); Tv = T(:); Yv = Y(:);
n = min([numel(Qv), numel(Xv), numel(Tv), numel(Yv)]);
Qv = Qv(1:n); Xv = Xv(1:n); Tv = Tv(1:n); Yv = Yv(1:n);

% Pair definitions
names = {'Q','X','T','Y'};
vals  = {Qv,  Xv,  Tv,  Yv};
pairs = [1 2; 1 3; 1 4; 2 3; 2 4; 3 4];  % (Q,X), (Q,T), (Q,Y), (X,T), (X,Y), (T,Y)

figure('Name','Scatter pairs: Q, X, T, Y');
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
        title(sprintf('%s vs %s (run %s)', names{pairs(i,2)}, names{pairs(i,1)}, run));
    else
        axis off; 
        title(sprintf('%s vs %s (no data)', names{pairs(i,2)}, names{pairs(i,1)}));
    end
end

sgtitle(sprintf('All 2D scatter combinations (zeros removed) — run %s', run));



% -----------------------------------------------------------------------------
% RPC charges for the narrow strips, which do not carry timing info.
% -----------------------------------------------------------------------------

% This is a key plot. In run 1 the span of both axes is similar, while in runs 2
% and 3 the top charges are much lower, as expected. Calculating how much could give an idea
% of the relative gain of the top and bottom sides of the RPC and hence an idea on the
% real HV difference between both sides.

figure;
subplot(4,6,1); plot(Qt(:,1), Qb(:,1),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip I');
xlim([q005_t q95_t]); ylim([q005_b q95_b]);
subplot(4,6,2); plot(Qt(:,2), Qb(:,2),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip II');
xlim([q005_t q95_t]); ylim([q005_b q95_b]);
subplot(4,6,3); plot(Qt(:,3), Qb(:,3),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip III');
xlim([q005_t q95_t]); ylim([q005_b q95_b]);
subplot(4,6,4); plot(Qt(:,4), Qb(:,4),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip IV');
xlim([q005_t q95_t]); ylim([q005_b q95_b]);
subplot(4,6,5); plot(Qt(:,5), Qb(:,5),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip V');
xlim([q005_t q95_t]); ylim([q005_b q95_b]);
subplot(4,6,6); plot(Qt(:,6), Qb(:,6),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip VI');
xlim([q005_t q95_t]); ylim([q005_b q95_b]);
subplot(4,6,7); plot(Qt(:,7), Qb(:,7),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip VII');
xlim([q005_t q95_t]); ylim([q005_b q95_b]);
subplot(4,6,8); plot(Qt(:,8), Qb(:,8),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip VIII');
xlim([q005_t q95_t]); ylim([q005_b q95_b]);
subplot(4,6,9); plot(Qt(:,9), Qb(:,9),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip IX');
xlim([q005_t q95_t]); ylim([q005_b q95_b]);
subplot(4,6,10); plot(Qt(:,10), Qb(:,10),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip X');
xlim([q005_t q95_t]); ylim([q005_b q95_b]);
subplot(4,6,11); plot(Qt(:,11), Qb(:,11),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip XI');
xlim([q005_t q95_t]); ylim([q005_b q95_b]);
subplot(4,6,12); plot(Qt(:,12), Qb(:,12),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip XII');
xlim([q005_t q95_t]); ylim([q005_b q95_b]);
subplot(4,6,13); plot(Qt(:,13), Qb(:,13),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip XIII');
xlim([q005_t q95_t]); ylim([q005_b q95_b]);
subplot(4,6,14); plot(Qt(:,14), Qb(:,14),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip XIV');
xlim([q005_t q95_t]); ylim([q005_b q95_b]);
subplot(4,6,15); plot(Qt(:,15), Qb(:,15),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip XV');
xlim([q005_t q95_t]); ylim([q005_b q95_b]);
subplot(4,6,16); plot(Qt(:,16), Qb(:,16),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip XVI');
xlim([q005_t q95_t]); ylim([q005_b q95_b]);
subplot(4,6,17); plot(Qt(:,17), Qb(:,17),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip XVII');
xlim([q005_t q95_t]); ylim([q005_b q95_b]);
subplot(4,6,18); plot(Qt(:,18), Qb(:,18),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip XVIII');
xlim([q005_t q95_t]); ylim([q005_b q95_b]);
subplot(4,6,19); plot(Qt(:,19), Qb(:,19),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip XIX');
xlim([q005_t q95_t]); ylim([q005_b q95_b]);
subplot(4,6,20); plot(Qt(:,20), Qb(:,20),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip XX');
xlim([q005_t q95_t]); ylim([q005_b q95_b]);
subplot(4,6,21); plot(Qt(:,21), Qb(:,21),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip XXI');
xlim([q005_t q95_t]); ylim([q005_b q95_b]);
subplot(4,6,22); plot(Qt(:,22), Qb(:,22),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip XXII');
xlim([q005_t q95_t]); ylim([q005_b q95_b]);
subplot(4,6,23); plot(Qt(:,23), Qb(:,23),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip XXIII');
xlim([q005_t q95_t]); ylim([q005_b q95_b]);
subplot(4,6,24); plot(Qt(:,24), Qb(:,24),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip XXIV');
xlim([q005_t q95_t]); ylim([q005_b q95_b]);
sgtitle(sprintf('Narrow strip charge top vs bottom (data from %s)', formatted_datetime_tex));



% FIGURE 1 — Thin bottom / Thin top (hist + hist + scatter), with valid overlays
figure;
subplot(1,3,1);
histogram(Q_thin_bot_event_signal_hist, thinBotEdges, 'DisplayName','all events'); hold on;
histogram(Q_thin_bot_event_good_hist, thinBotEdges, 'DisplayName','valid only');
ylabel('# of events'); xlabel('Q (bottom)');
title('Q narrow bottom spectrum (sum of Q per event)');
xlim([q005 q95]); legend('show');

subplot(1,3,2);
histogram(Q_thin_top_event_signal_hist, thinTopEdges, 'DisplayName','all events'); hold on;
histogram(Q_thin_top_event_good_hist, thinTopEdges, 'DisplayName','valid only');
ylabel('# of events'); xlabel('Q (top)');
title('Q narrow top spectrum (sum of Q per event)');
xlim([q005 q95]); legend('show');

subplot(1,3,3);
plot(Q_thin_bot_event_signal, Q_thin_top_event_signal, '.', 'DisplayName','all events'); hold on;
plot(Q_thin_bot_event_good, Q_thin_top_event_good, '.', 'DisplayName','valid only');
plot([q005 q95],[q005 q95],'--','Color',[1 0.5 0],'LineWidth',2.5,'DisplayName','y = x');
xlabel('Q (bottom)'); ylabel('Q (top)');
title('Q bottom vs Q top');
xlim([q005_b q95_b]); ylim([q005_t q95_t]); legend('show');
sgtitle(sprintf('Charge of the event (thin only; all vs valid; run %s)', run));

% FIGURE 2 — Thin bottom vs Thick
figure;
subplot(1,3,1);
histogram(Q_thin_bot_event_signal_hist, thinBotEdges, 'DisplayName','all events'); hold on;
histogram(Q_thin_bot_event_good_hist, thinBotEdges, 'DisplayName','valid only');
ylabel('# of events'); xlabel('Q (bottom)');
title('Q narrow bottom spectrum (sum of Q per event)');
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
xlim([q005_b q95_b]); ylim([q005_thick q95_thick]); legend('show');
sgtitle(sprintf('Charge of the event (bottom vs thick; all vs valid; run %s)', run));

% FIGURE 3 — Thick vs Thin top
figure;
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
title('Q narrow top spectrum (sum of Q per event)');
xlim([q005 q95]); legend('show');

subplot(1,3,3);
plot(Q_thick_strip_signal, Q_thin_top_event_signal, '.', 'DisplayName','all events'); hold on;
plot(Q_thick_strip_good, Q_thin_top_event_good, '.', 'DisplayName','valid only');
xlabel('Q (thick)'); ylabel('Q (top)');
title('Q thick vs Q top');
xlim([q005_thick q95_thick]); ylim([q005 q95]); legend('show');
sgtitle(sprintf('Charge of the event (thick vs top; all vs valid; run %s)', run));


% PMT 2x2 charge CDFs with binning_pmt and the _signal, _good, _range versions
figure;
titles = {'Q pmt1','Q pmt2','Q pmt3','Q pmt4'};

for k = 1:4
    subplot(2,2,k);
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

sgtitle(sprintf('PMT charge (data from %s)', formatted_datetime_tex));


%%

% -------------------------------------------------------------------------
% Position from narrow strips (24 strips, no timing, only charge)
% -------------------------------------------------------------------------

if position_from_narrow_strips

    % Use no-crosstalk quantities for position calculation
    charge_thin_top_for_position = Qt_no_crosstalk;
    charge_thin_bot_for_position = Qb_no_crosstalk;
    charge_thick_for_position = Q_thick_strip_no_crosstalk;
    X_thick_for_position = X_thick_strip_no_crosstalk; % discrete (1..5)
    T_thick_for_position = T_thick_strip_no_crosstalk; % mean(Tfl,Tbl)
    Y_thick_for_position = Y_thick_strip_no_crosstalk; % (Tfl - Tbl)/2 in ns

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

    % ===============================================================
    % (1) WRAPPED GAUSSIAN FITS FOR Qt (TOP) AND Qb (BOTTOM)
    %     Return per-event [mu, sigma, chisq] for each plane
    % ===============================================================
    nStrips = 24;
    x = (1:nStrips)';               % strip index
    nTop = size(Qt,1);  nBot = size(Qb,1);

    fitTop = nan(nTop,3);           % [mu, sigma, chisq]
    fitBot = nan(nBot,3);

    wrapDist = @(dx) mod(dx + nStrips/2, nStrips) - nStrips/2;           % [-12,12)
    model_from_p = @(p) ( p(4) + exp(p(3)) .* exp( -0.5*(wrapDist(x - (1 + mod(p(1)-1,nStrips))).^2) ./ (exp(p(2)).^2) ) );
    sse = @(y,p) sum( (y - model_from_p(p)).^2 );
    optsFS = optimset('Display','off','MaxFunEvals',2000,'MaxIter',2000);

    % --- Fit TOP ---
    for i = 1:nTop
        y = double(Qt(i,:))';
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
    end

    % --- Fit BOTTOM ---
    for i = 1:nBot
        y = double(Qb(i,:))';
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
    end

    % Keep only rows with finite fits
    goodTop = all(isfinite(fitTop),2);
    goodBot = all(isfinite(fitBot),2);
    % Use a common mask length (events) — assume Qt and Qb align by rows
    nEvents = min(numel(goodTop), numel(goodBot));
    fitTop  = fitTop (1:nEvents,:);
    fitBot  = fitBot (1:nEvents,:);
    goodTop = goodTop(1:nEvents);
    goodBot = goodBot(1:nEvents);
    goodFit = goodTop & goodBot;

    fitTop  = fitTop(goodFit,:);
    fitBot  = fitBot(goodFit,:);

    mu_top    = ensure_col(fitTop(:,1));
    sigma_top = ensure_col(fitTop(:,2));
    chi_top   = ensure_col(fitTop(:,3));

    mu_bot    = ensure_col(fitBot(:,1));
    sigma_bot = ensure_col(fitBot(:,2));
    chi_bot   = ensure_col(fitBot(:,3));


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

    figure('Name','Fits matrix (6x6): top/bottom variables');
    tiledlayout(6,6,'TileSpacing','compact','Padding','compact');

    for r = 1:6
        for c = 1:6
            nexttile;

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

                hold on;
                % Edge color encodes x-var origin; face color encodes y-var origin

                scatter(x, y, 18, 'filled', 'r', 'MarkerFaceAlpha', 0.75);

                % Percentile-based limits per axis (respect current practice)
                pLo = percentile_position; pHi = 100 - percentile_position;
                % For sigma on any axis, additionally clamp to [0,24]
                % x-limits
                x1 = prctile(x, pLo); x2 = prctile(x, pHi);
                if c == 2 || c == 5, x1 = max(0, x1); x2 = min(24, x2); end
                % y-limits
                y1 = prctile(y, pLo); y2 = prctile(y, pHi);
                if r == 2 || r == 5, y1 = max(0, y1); y2 = min(24, y2); end

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

    sgtitle(sprintf('Fits matrix (6x6) — run %s', run));




    % ===============================================================
    % (2) EXTENDED (PERIODICALLY EXPANDED) THIN COORDS
    % ===============================================================
    wrapPeriod = 24;  % strips per thick
    nWraps     = 5;   % number of thick strips in X (→ total 120)

    % “Original” 1..24 fits
    X_thin_strip_bot = ensure_col(mu_bot);
    Y_thin_strip_top = ensure_col(mu_top);

    % Expand to show all periodic images
    X_thin_expanded_bot = arrayfun(@(x) x + (0:nWraps-1)*wrapPeriod, X_thin_strip_bot, 'UniformOutput', false);
    X_thin_expanded_bot = vertcat(X_thin_expanded_bot{:});
    Y_thin_expanded_top = arrayfun(@(x) x + (0:nWraps-1)*wrapPeriod, Y_thin_strip_top, 'UniformOutput', false);
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
    nPair = min([numel(X_thin_strip_bot), numel(Y_thin_strip_top), numel(X_thick_for_position), numel(Y_thick_for_position)]);
    X_thin_strip_bot = X_thin_strip_bot(1:nPair);
    Y_thin_strip_top = Y_thin_strip_top(1:nPair);
    X_thick_for_position = X_thick_for_position(1:nPair);
    Y_thick_for_position = Y_thick_for_position(1:nPair);

    % Take events (that is, rows) where the four vectors are different to 0
    nonzero_idx = (X_thick_for_position ~= 0) & (Y_thick_for_position ~= 0) & (X_thin_strip_bot ~= 0) & (Y_thin_strip_top ~= 0);
    X_thick_for_position = X_thick_for_position(nonzero_idx);      % [N x 1]
    Y_thick_for_position = Y_thick_for_position(nonzero_idx);      % [N x 1]
    X_thin_strip_bot = X_thin_strip_bot(nonzero_idx); % [N x 1]
    Y_thin_strip_top = Y_thin_strip_top(nonzero_idx); % [N x 1]
    nPair = numel(X_thick_for_position);

    % Map thick to [1..120] axis for overlay plots
    X_thick_pos = X_thick_for_position / 5 * 120 - 12;            % your mapping
    Y_thick_pos = (Y_thick_for_position + 1.5)/3 * 120 + 1;

    % Randomize thick-X within each 24-wide sector to reduce aliasing (keeps sector)
    wrap_idx = floor(X_thick_pos / wrapPeriod); % 0,1,2,3,4
    X_thick_pos = wrap_idx * wrapPeriod + rand(size(X_thick_pos))*wrapPeriod;

    % “Final” (unwrapped) thin using thick X to pick the period
    X_thin_bot_final = X_thin_strip_bot + (X_thick_for_position - 1) * wrapPeriod;   % [1..120]

    % For Y (thin top): choose among 5 wraps the one closest to mapped thick-Y
    Ymap = Y_thick_pos;                                 % [1..120]
    Y_all = Y_thin_strip_top + (0:nWraps-1)*wrapPeriod; % [N x 5, implicit]
    Y_all_mat = Y_thin_strip_top + (0:nWraps-1)*wrapPeriod; % row vector offsets
    Y_all_mat = Y_all_mat(:)'; % 1x5
    Y_cands = Y_thin_strip_top + Y_all_mat;             % N x 5
    diffs   = abs(Y_cands - Ymap);
    [~, idx_min] = min(diffs, [], 2);
    Y_thin_top_final = Y_cands(sub2ind(size(Y_cands), (1:nPair)', idx_min)); % [1..120]

    %%


    % ---- PLOTS: original thin vs thick (top row), final thin vs thick (bottom row) ----
    commonColor = [0.2 0.8 0.2];
    lims = [1, 24*5];

    % mm conversions
    to_mm = @(ax) (ax/120 - 0.5) * 300;  % 1..120 → -150..150 mm
    to_ax = @(mm) (mm/300 + 0.5) * 120;  % -150..150 mm → 1..120

    % Optional rectangle in mm
    base_mm   = 20;
    height_mm = 80;
    center_mm = [-80, -27];

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

    fprintf('Rectangle in mm: center=(%.1f, %.1f), base=%.1f, height=%.1f\n', ...
            center_mm(1), center_mm(2), base_mm, height_mm);
    fprintf('Rectangle in axes: center=(%.1f, %.1f), base=%.1f, height=%.1f\n', ...
            center_ax(1), center_ax(2), base_ax, height_ax);

    figure('Name','Original thin vs thick (top row) → Final thin vs thick (bottom row)');
    tiledlayout(2,2,'TileSpacing','compact','Padding','compact');

    % (a) THIN X (original 1..24 repeated) vs THICK Y
    nexttile; hold on;
    for w = 0:nWraps-1
        scatter(X_thin_strip_bot + w*wrapPeriod, Y_thick_pos, 3, 'filled', 'MarkerFaceAlpha',0.6);
    end
    for k = 0:nWraps
        xline(k*wrapPeriod+1, '-',  'LineWidth', 1);
        xline((k*wrapPeriod+wrapPeriod+1), '--', 'LineWidth', 1);
        yline(k*wrapPeriod+1, '--', 'LineWidth', 1);
        yline((k*wrapPeriod+wrapPeriod+1), '--', 'LineWidth', 1);
    end
    rectangle('Position', [center_ax(1)-base_ax/2, center_ax(2)-height_ax/2, base_ax, height_ax], ...
              'EdgeColor', 'r', 'LineWidth', 2);
    xlabel('THIN X_{bot} (original, wrapped to each period) [1–120]');
    ylabel('THICK Y [1–120]');
    xlim(lims); ylim(lims); grid off; box on; axis square;

    % (b) THICK X vs THIN Y (original 1..24 repeated)
    nexttile; hold on;
    for w = 0:nWraps-1
        scatter(X_thick_pos, Y_thin_strip_top + w*wrapPeriod, 3, 'filled', 'MarkerFaceAlpha',0.6);
    end
    for k = 0:nWraps
        xline(k*wrapPeriod+1, '-',  'LineWidth', 1);
        xline((k*wrapPeriod+wrapPeriod+1), '--', 'LineWidth', 1);
        yline(k*wrapPeriod+1, '--', 'LineWidth', 1);
        yline((k*wrapPeriod+wrapPeriod+1), '--', 'LineWidth', 1);
    end
    rectangle('Position', [center_ax(1)-base_ax/2, center_ax(2)-height_ax/2, base_ax, height_ax], ...
              'EdgeColor', 'r', 'LineWidth', 2);
    xlabel('THICK X [1–120]');
    ylabel('THIN Y_{top} (original, wrapped to each period) [1–120]');
    xlim(lims); ylim(lims); grid off; box on; axis square;

    % (c) THIN X (final unwrapped) vs THICK Y
    nexttile; hold on;
    scatter(X_thin_bot_final, Y_thick_pos, 3, commonColor, 'filled', 'MarkerFaceAlpha',0.6);
    for k = 0:nWraps
        xline(k*wrapPeriod+1, '-',  'LineWidth', 1);
        xline((k*wrapPeriod+wrapPeriod+1), '--', 'LineWidth', 1);
        yline(k*wrapPeriod+1, '--', 'LineWidth', 1);
        yline((k*wrapPeriod+wrapPeriod+1), '--', 'LineWidth', 1);
    end
    rectangle('Position', [center_ax(1)-base_ax/2, center_ax(2)-height_ax/2, base_ax, height_ax], ...
              'EdgeColor', 'r', 'LineWidth', 2);
    xlabel('THIN X_{bot} (final, unwrapped) [1–120]');
    ylabel('THICK Y [1–120]');
    xlim(lims); ylim(lims); grid off; box on; axis square;

    % (d) THICK X vs THIN Y (final unwrapped)
    nexttile; hold on;
    scatter(X_thick_pos, Y_thin_top_final, 3, commonColor, 'filled', 'MarkerFaceAlpha',0.6);
    for k = 0:nWraps
        xline(k*wrapPeriod+1, '-',  'LineWidth', 1);
        xline((k*wrapPeriod+wrapPeriod+1), '--', 'LineWidth', 1);
        yline(k*wrapPeriod+1, '--', 'LineWidth', 1);
        yline((k*wrapPeriod+wrapPeriod+1), '--', 'LineWidth', 1);
    end
    rectangle('Position', [center_ax(1)-base_ax/2, center_ax(2)-height_ax/2, base_ax, height_ax], ...
              'EdgeColor', 'r', 'LineWidth', 2);
    xlabel('THICK X [1–120]');
    ylabel('THIN Y_{top} (final, unwrapped) [1–120]');
    xlim(lims); ylim(lims); grid off; box on; axis square;

    sgtitle(sprintf('Original thin vs thick → Final thin vs thick (run %s)', run));

    %%

    % ===============================================================
    % (4) FINAL X–Y MAP (in mm) USING FINAL UNWRAPPED VALUES
    % ===============================================================

    X_final_ax = ensure_col(X_thin_bot_final);
    Y_final_ax = ensure_col(Y_thin_top_final);
    valid = isgood(X_final_ax) & isgood(Y_final_ax);

    X_final_mm = to_mm(X_final_ax(valid));
    Y_final_mm = to_mm(Y_final_ax(valid));

    figure('Name','Final XY map');
    scatter(X_final_mm, Y_final_mm, 6, 'filled', 'MarkerFaceAlpha',0.4); hold on;
    % Add xlines not dashed and dashed ylines each 24 strip interval, transforming from strip to mm
    for k = 0:nWraps
        xline((( k*wrapPeriod + 1 ) /120 - 0.5)*300, '-',  'LineWidth', 1);
        xline(((k*wrapPeriod+wrapPeriod + 1)/120 - 0.5)*300, '--', 'LineWidth', 1);
        yline(((k*wrapPeriod + 1 ) /120 - 0.5)*300, '--', 'LineWidth', 1);
        yline(((k*wrapPeriod+wrapPeriod + 1)/120 - 0.5)*300, '--', 'LineWidth', 1);
    end
    xlim([-150 150]); ylim([-150 150]); grid off; box on; axis square;
    xlabel('X_{final} [mm]'); ylabel('Y_{final} [mm]');
    title(sprintf('Disambiguated thin positions using thick constraints — run %s', run));
    rectangle('Position', [center_mm(1)-base_mm/2, center_mm(2)-height_mm/2, base_mm, height_mm], ...
              'EdgeColor', 'r', 'LineWidth', 2);

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

fprintf('Percentage of streamers (Q > threshold) in Thin RPC TOP: %.2f%%\n', percentage_streamer_thin_top);
fprintf('Percentage of streamers (Q > threshold) in Thick RPC: %.2f%%\n', percentage_streamer_thick);
fprintf('Percentage of streamers (Q > threshold) in Thin RPC BOTTOM: %.2f%%\n', percentage_streamer_thin_bot);

% Take only positive charges for the plots in a new vector that does not replace the original
Q_thick_plot = Q_thick(isfinite(Q_thick) & Q_thick > 0);
Q_thin_top_plot = Q_thin_top(isfinite(Q_thin_top) & Q_thin_top > 0);
Q_thin_bot_plot = Q_thin_bot(isfinite(Q_thin_bot) & Q_thin_bot > 0);

% the streamer % in the histogram title with no decimals
figure;
subplot(2,3,1); histogram(Q_thick_plot, 0:1:200); set(gca, 'YScale', 'log'); xlabel('Q_{thick\_event} [ADC bins]'); ylabel('# of events'); title(sprintf('Thick RPC Q, streamer <%d%%> (run %s)', round(percentage_streamer_thick), run));
hold on; xline(Q_thick_streamer_threshold, 'r--', 'Streamer Threshold');
subplot(2,3,2); histogram(Q_thin_top_plot, 0:100:10E4); set(gca, 'YScale', 'log'); xlabel('Q_{thin\_top\_event} [ADC bins]'); ylabel('# of events'); title(sprintf('Thin RPC TOP Q, streamer <%d%%> (run %s)', round(percentage_streamer_thin_top), run));
hold on; xline(Q_thin_top_streamer_threshold, 'r--', 'Streamer Threshold');
subplot(2,3,3); histogram(Q_thin_bot_plot, 0:100:10E4); set(gca, 'YScale', 'log'); xlabel('Q_{thin\_bot\_event} [ADC bins]'); ylabel('# of events'); title(sprintf('Thin RPC BOTTOM Q, streamer <%d%%> (run %s)', round(percentage_streamer_thin_bot), run));
hold on; xline(Q_thin_bot_streamer_threshold, 'r--', 'Streamer Threshold');

subplot(2,3,4); histogram(Q_thick_plot, 0:2:200, 'Normalization', 'cdf'); xlabel('Q_{thick\_event} [ADC bins]'); ylabel('Cumulative Distribution'); title('Thick RPC Q CDF');
hold on; xline(Q_thick_streamer_threshold, 'r--', 'Streamer Threshold'); ylim([0 1]);
subplot(2,3,5); histogram(Q_thin_top_plot, 0:500:10E4, 'Normalization', 'cdf'); xlabel('Q_{thin\_top\_event} [ADC bins]'); ylabel('Cumulative Distribution'); title('Thin RPC TOP Q CDF');
hold on; xline(Q_thin_top_streamer_threshold, 'r--', 'Streamer Threshold'); ylim([0 1]);
subplot(2,3,6); histogram(Q_thin_bot_plot, 0:500:10E4, 'Normalization', 'cdf'); xlabel('Q_{thin\_bot\_event} [ADC bins]'); ylabel('Cumulative Distribution'); title('Thin RPC BOTTOM Q CDF');
hold on; xline(Q_thin_bot_streamer_threshold, 'r--', 'Streamer Threshold'); ylim([0 1]);

sgtitle(sprintf('RPC Charge Spectra and cumulative distributions (data from %s)', formatted_datetime_tex));


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
figure('Name','Efficiency vs Thresholds');
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


% Print for verification
fprintf('Save plots directory: %s\n', save_plots_dir);
fprintf('PDF file name: %s\n', pdfFileName);

if save_plots
    try
        if ~exist(save_plots_dir, 'dir'), mkdir(save_plots_dir); end
        [pdfPath, figCount] = save_all_figures_to_pdf(save_plots_dir, pdfFileName);
        if figCount > 0 && ~isempty(pdfPath)
            fprintf('Saved %d figure(s) to %s\n', figCount, pdfPath);
        else
            fprintf('No figures generated to save.\n');
        end
    catch saveErr
        warning('Failed to save figures: %s', saveErr.message);
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


% Save current defaults, set new ones, and restore at the end
function restore_figure_defaults(defaultVisibility, defaultCreateFcn)
    set(groot, 'DefaultFigureVisible', defaultVisibility);
    set(groot, 'DefaultFigureCreateFcn', defaultCreateFcn);
end
