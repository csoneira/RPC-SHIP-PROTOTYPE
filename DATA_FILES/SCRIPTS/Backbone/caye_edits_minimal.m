% Joana Pinto 2025
% csoneira@ucm.es 2025

% new script for the 4 scintillators, 2 top and 2 bottom
% run no.1 was acquired with the high voltage on
% runs no.2 and 3 were acquired with the top high voltage turned off

% NOTE!!!
% pay attention to the order of the strip connections:
% wide strips: TFl = [l31 l32 l30 l28 l29]; TFt = [t31 t32 t30 t28 t29];  TBl = [l2 l1 l3 l5 l4]; TBt = [t2 t1 t3 t5 t4];
% scintillators: Tl_cint = [l11 l12 l9 l10]; Tt_cint = [t11 t12 t9 t10];
% Note: the cables were swapped, therefore Qt=Ib... and Qb=It...

% l: leading edge times
% t: trailing edge times
% Q = t - l


% =====================================================================
% Configuration Paths and Run Selection
% =====================================================================

save_plots_dir_default = '/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/DATA_FILES/DATA/PDF';
if ~exist('save_plots','var')
    save_plots = false;
end
if ~exist('save_plots_dir','var') || isempty(save_plots_dir)
    save_plots_dir = save_plots_dir_default;
end

clearvars -except save_plots save_plots_dir save_plots_dir_default input_dir keep_raster_temp;
close all; clc;

% -------------------------------
test = false;
run = 0;

if test
    if run == 1
        input_dir = 'dabc25120133744-dabc25126121423_JOANA_RUN_1_2025-10-08_15h05m00s';
        data_dir = "/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/DATA_FILES/DATA/UNPACKED/IMPORTANTz/dabc25120133744-dabc25126121423_JOANA_RUN_1_2025-10-08_15h05m00s";
    elseif run == 2
        input_dir = 'dabc25127151027-dabc25147011139_JOANA_RUN_2_2025-10-08_15h05m00s';
        data_dir = "/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/DATA_FILES/DATA/UNPACKED/IMPORTANT/dabc25127151027-dabc25147011139_JOANA_RUN_2_2025-10-08_15h05m00s";
    elseif run == 3
        input_dir = 'dabc25127151027-dabc25160092400_JOANA_RUN_3_2025-10-08_15h05m00s';
        data_dir = "/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/DATA_FILES/DATA/UNPACKED/IMPORTANT/dabc25127151027-dabc25160092400_JOANA_RUN_3_2025-10-08_15h05m00s";
    else
        error('For test mode, set run to 1, 2, or 3.');
    end
end
% -------------------------------

HOME    = '/home/csoneira/WORK/LIP_stuff/';
SCRIPTS = 'JOAO_SETUP/';
DATA    = 'matFiles/time/';
DATA_Q    = 'matFiles/charge/';
path(path,[HOME SCRIPTS 'util_matPlots']);

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

% keep the onCleanup alive and unique
restoreFigureDefaultsGuard = get_restore_guard(save_plots);

function guard = get_restore_guard(save_plots)
    persistent restoreFigureDefaultsGuard
    if save_plots && (isempty(restoreFigureDefaultsGuard) || ~isvalid(restoreFigureDefaultsGuard))
        % Capture ALL defaults we’ll touch so we can restore them later
        orig = capture_figure_defaults();

        % Auto-restore on exit
        restoreFigureDefaultsGuard = onCleanup(@() restore_figure_defaults(orig));

        % ---- Global dark theme + headless plotting ----
        r = groot;
        set(r, ...
            'DefaultFigureVisible','off', ...
            'DefaultFigureCreateFcn', @(fig,~) set(fig,'Visible','off'), ...
            'DefaultFigureColor','k', ...                 % figure background
            'DefaultAxesColor','k', ...                   % axes background
            'DefaultAxesXColor',[1 1 1], ...              % axes/labels in white
            'DefaultAxesYColor',[1 1 1], ...
            'DefaultAxesZColor',[1 1 1], ...
            'DefaultTextColor',[1 1 1], ...
            'DefaultAxesGridColor',[0.45 0.45 0.45], ...
            'DefaultAxesMinorGridColor',[0.30 0.30 0.30], ...
            'DefaultFigureInvertHardcopy','off', ...      % keep dark bg on save
            'DefaultFigureRenderer','opengl');            % good with alpha/large scatters
    end
    guard = restoreFigureDefaultsGuard;
end

function orig = capture_figure_defaults()
    r = groot;
    props = {'DefaultFigureVisible','DefaultFigureCreateFcn','DefaultFigureColor', ...
             'DefaultAxesColor','DefaultAxesXColor','DefaultAxesYColor','DefaultAxesZColor', ...
             'DefaultTextColor','DefaultAxesGridColor','DefaultAxesMinorGridColor', ...
             'DefaultFigureInvertHardcopy','DefaultFigureRenderer'};
    for k = 1:numel(props)
        orig.(props{k}) = get(r, props{k});
    end
end

function restore_figure_defaults(orig)
    if isempty(orig), return; end
    r = groot;
    fns = fieldnames(orig);
    for k = 1:numel(fns)
        try, set(r, fns{k}, orig.(fns{k})); end %#ok<TRYNC>
    end
end



summary_output_dir = '/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/DATA_FILES/DATA/TABLES/';
if ~exist(summary_output_dir, 'dir')
    mkdir(summary_output_dir);
end

path(path,'/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/util_matPlots');

project_root = '/home/csoneira/WORK/LIP_stuff/JOAO_SETUP';
mst_saves_root = fullfile(project_root, 'MST_saves');
unpacked_root = fullfile(project_root, 'DATA_FILES', 'DATA', 'UNPACKED', 'PROCESSING');

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
fprintf("The time of the dataset is: %s\n", formatted_datetime);

execution_datetime = datestr(now, 'yyyy_mm_dd-HH.MM.SS');
pdfFileName = sprintf('caye_plots_%s_exec_%s.pdf', formatted_datetime, execution_datetime);
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

whos

% -----------------------------------------------------------
% Select run number and percentile thresholds for charge cuts
% -----------------------------------------------------------

% if run is not 1,2,3, then set run to 0
if run ~= 1 && run ~= 2 && run ~= 3
    run = 0;
end

percentile_pmt = 25;
percentile_narrow = 1;
percentile_thick = 1;
percentiles = true;

% Filters of the raw data only
% PMTs
lead_time_pmt_min = -120;
lead_time_pmt_max = -70;
trail_time_pmt_min = -50;
trail_time_pmt_max = 200;

time_pmt_diff_thr = 50; % ns

tTH = 4; %time threshold [ns] to assume it comes from a good event; obriga a ter tempos nos 4 cint JOANA HAD 3 ns

% WIDE
lead_time_wide_strip_min = -200;
lead_time_wide_strip_max = -50;
trail_time_wide_strip_min = -150;
trail_time_wide_strip_max = 300;

charge_wide_strip_diff_thr = 25;

% NARROW
charge_narrow_strip_min = 0;
charge_narrow_strip_max = 30000;
% -----------------------------------------------------------
% -----------------------------------------------------------

% -------- NaN scrubber: replace NaNs with 0 across all float variables -----
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

        fprintf('NaNs in %-25s : %d\n', name, nans);
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


% ---------------------------------------------------------------------
% ---------------------------------------------------------------------
% Original Data Structuring
% ---------------------------------------------------------------------
% ---------------------------------------------------------------------

% -----------------------------------------------------------------------------
% Scintillator Timing and Charge Derivations
% -----------------------------------------------------------------------------

% System layout:

% PMT 1 ------------------------ PMT 2
% --------------- RPC ----------------
% PMT 3 ------------------------ PMT 4

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

% Try this, if it does not work, then store the channels from 24 to 28, and print a warning
% that the channel order is not as expected. So it was changed to the 24-28 order.

% The order of the channels needs swapping, as I see from the picture and plots

% Joana - TFl = [l31 l32 l30 l28 l29];
        % TFt = [t31 t32 t30 t28 t29];
        % TBl = [l2 l1 l3 l5 l4];
        % TBt = [t2 t1 t3 t5 t4];

try
    TFl_OG = [l32 l31 l30 l29 l28];    % tempos leadings front [ns]; chs [32,28] -> 5 strips gordas front
    TFt_OG = [t32 t31 t30 t29 t28];    % tempos trailings front [ns]
catch
    warning('Variables l31/l32/l30/l28/l29 not found; using alternative channel order 24–28.');
    TFl_OG = [l28 l27 l26 l25 l24];
    TFt_OG = [t28 t27 t26 t25 t24];
end

TBl_OG = [l1 l2 l3 l4 l5]; %leading times back [ns]; channels [1,5] -> 5 wide back strips
TBt_OG = [t1 t2 t3 t4 t5]; %trailing times back [ns]

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

try
    Tl_cint = [l11 l12 l9 l10]; %tempos leadings  [ns] - leading times [ns]
    Tt_cint = [t11 t12 t9 t10]; %tempos trailings [ns] - trailing times [ns]
catch
    warning('Variables 9/10/11/12 not found; THIS EXITS THE CODE.');
    return;
end


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

try
    TFl = [l32 l31 l30 l29 l28];    % tempos leadings front [ns]; chs [32,28] -> 5 strips gordas front
    TFt = [t32 t31 t30 t29 t28];    % tempos trailings front [ns]
catch
    warning('Variables l31/l32/l30/l28/l29 not found; using alternative channel order 24–28.');
    TFl = [l28 l27 l26 l25 l24];
    TFt = [t28 t27 t26 t25 t24];
end

TBl = [l1 l2 l3 l4 l5]; %leading times back [ns]; channels [1,5] -> 5 wide back strips
TBt = [t1 t2 t3 t4 t5]; %trailing times back [ns]

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

% Convert charge arrays from cell traces to double matrices (after cable swap).
% nota: os cabos estavam trocados, por isso, Qt=Ib e Qb=It; note: the cables were swapped, so Qt=Ib and Qb=It

v = cast([Ib IIb IIIb IVb Vb VIb VIIb VIIIb IXb Xb XIb XIIb XIIIb XIVb XVb XVIb XVIIb XVIIIb XIXb XXb XXIb XXIIb XXIIIb XXIVb],"double");
w = cast([It IIt IIIt IVt Vt VIt VIIt VIIIt IXt Xt XIt XIIt XIIIt XIVt XVt XVIt XVIIt XVIIIt XIXt XXt XXIt XXIIt XXIIIt XXIVt],"double");

% if run == 1 || run == 2 || run == 3
%     Qt = v;
%     Qb = w;
% elseif run == 0
%     Qt = w; % top narrow strips charge proxy
%     Qb = v; % bottom narrow strips charge proxy
% end

Qt = v; % top narrow strips charge proxy
Qb = w; % bottom narrow strips charge proxy

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
xlim([min(min(Tl_cint_OG)) max(max(Tl_cint_OG))]); ylim([min(min(Tt_cint_OG)) max(max(Tt_cint_OG))]);
xline(lead_time_pmt_min, 'r--'); xline(lead_time_pmt_max, 'r--');
yline(trail_time_pmt_min, 'r--'); yline(trail_time_pmt_max, 'r--');
subplot(2,2,2); plot(Tl_cint_OG(:,2), Tt_cint_OG(:,2),'.'); hold on; plot(Tl_cint(:,2), Tt_cint(:,2),'.');
xlabel('Tl_cint2'); ylabel('Tt_cint2'); title('Time lead vs trail PMT2');
xlim([min(min(Tl_cint_OG)) max(max(Tl_cint_OG))]); ylim([min(min(Tt_cint_OG)) max(max(Tt_cint_OG))]);
xline(lead_time_pmt_min, 'r--'); xline(lead_time_pmt_max, 'r--');
yline(trail_time_pmt_min, 'r--'); yline(trail_time_pmt_max, 'r--');
subplot(2,2,3); plot(Tl_cint_OG(:,3), Tt_cint_OG(:,3),'.'); hold on; plot(Tl_cint(:,3), Tt_cint(:,3),'.');
xlabel('Tl_cint3'); ylabel('Tt_cint3'); title('Time lead vs trail PMT3');
xlim([min(min(Tl_cint_OG)) max(max(Tl_cint_OG))]); ylim([min(min(Tt_cint_OG)) max(max(Tt_cint_OG))]);
xline(lead_time_pmt_min, 'r--'); xline(lead_time_pmt_max, 'r--');
yline(trail_time_pmt_min, 'r--'); yline(trail_time_pmt_max, 'r--');
subplot(2,2,4); plot(Tl_cint_OG(:,4), Tt_cint_OG(:,4),'.'); hold on; plot(Tl_cint(:,4), Tt_cint(:,4),'.');
xlabel('Tl_cint4'); ylabel('Tt_cint4'); title('Time lead vs trail PMT4');
xlim([min(min(Tl_cint_OG)) max(max(Tl_cint_OG))]); ylim([min(min(Tt_cint_OG)) max(max(Tt_cint_OG))]);
sgtitle(sprintf('PMT time lead vs trail (data from %s)', formatted_datetime));
xline(lead_time_pmt_min, 'r--'); xline(lead_time_pmt_max, 'r--');
yline(trail_time_pmt_min, 'r--'); yline(trail_time_pmt_max, 'r--');

%%

% Now plot the charge correlations for the same PMT pairs
figure;
subplot(1,2,1); plot(Qcint_OG(:,1), Qcint_OG(:,2), '.'); hold on; plot(Qcint(:,1), Qcint(:,2), '.');
xlabel('Qcint1'); ylabel('Qcint2'); title('Charge PMT1 vs PMT2');
xlim([min(min(Qcint_OG)) max(max(Qcint_OG))]); ylim([min(min(Qcint_OG)) max(max(Qcint_OG))]);
subplot(1,2,2); plot(Qcint_OG(:,3), Qcint_OG(:,4), '.'); hold on; plot(Qcint(:,3), Qcint(:,4), '.');
xlabel('Qcint3'); ylabel('Qcint4'); title('Charge PMT3 vs PMT4');
xlim([min(min(Qcint_OG)) max(max(Qcint_OG))]); ylim([min(min(Qcint_OG)) max(max(Qcint_OG))]);
sgtitle(sprintf('PMT charge correlations (data from %s)', formatted_datetime));


%%

% Finally, plot the Tl_cint i vs Tl_cint j scatter plots for all PMT pairs
figure;
subplot(1,2,1); plot(Tl_cint_OG(:,1), Tl_cint_OG(:,2),'.'); hold on; plot(Tl_cint(:,1), Tl_cint(:,2),'.');
xlabel('Tl_cint1'); ylabel('Tl_cint2'); title('Time lead PMT1 vs PMT2');
xlim([min(min(Tl_cint_OG)) max(max(Tl_cint_OG))]); ylim([min(min(Tl_cint_OG)) max(max(Tl_cint_OG))]);
refline(1, time_pmt_diff_thr); refline(1, -time_pmt_diff_thr); % Plot the line y = x +- time_pmt_diff_thr
subplot(1,2,2); plot(Tl_cint_OG(:,3), Tl_cint_OG(:,4),'.'); hold on; plot(Tl_cint(:,3), Tl_cint(:,4),'.');
xlabel('Tl_cint3'); ylabel('Tl_cint4'); title('Time lead PMT3 vs PMT4');
xlim([min(min(Tl_cint_OG)) max(max(Tl_cint_OG))]); ylim([min(min(Tl_cint_OG)) max(max(Tl_cint_OG))]);
sgtitle(sprintf('PMT time coincidences (data from %s)', formatted_datetime));
refline(1, time_pmt_diff_thr); refline(1, -time_pmt_diff_thr); % Plot the line y = x +- time_pmt_diff_thr

%%

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
sgtitle(sprintf('Histograms of time lead differences for PMTs (data from %s)', formatted_datetime));
xline(time_pmt_diff_thr); xline(-time_pmt_diff_thr);


%%



% -----------------------------------------------------------------------------
% RPC wide strip Timing and Charge Derivations
% -----------------------------------------------------------------------------

% leading times front [ns]; channels [32,28] -> 5 wide front strips
% TFl, TFt
% TBl, TBt



% Similar scatter subplot plots for the wide strips to verify no obvious problems.
figure;
subplot(2,5,1); plot(TFl_OG(:,1), TFt_OG(:,1),'.'); hold on; plot(TFl(:,1), TFt(:,1),'.');
xlabel('TFl'); ylabel('TFt'); title('Front, Time lead vs trail strip1');
xlim([min(min(TFl_OG)) max(max(TFl_OG))]); ylim([min(min(TFt_OG)) max(max(TFt_OG))]);
xline(lead_time_wide_strip_min, 'r--'); xline(lead_time_wide_strip_max, 'r--');
yline(trail_time_wide_strip_min, 'r--'); yline(trail_time_wide_strip_max, 'r--');
subplot(2,5,2); plot(TFl_OG(:,2), TFt_OG(:,2),'.'); hold on; plot(TFl(:,2), TFt(:,2),'.');
xlabel('TFl'); ylabel('TFt'); title('Front, Time lead vs trail strip2');
xlim([min(min(TFl_OG)) max(max(TFl_OG))]); ylim([min(min(TFt_OG)) max(max(TFt_OG))]);
xline(lead_time_wide_strip_min, 'r--'); xline(lead_time_wide_strip_max, 'r--');
yline(trail_time_wide_strip_min, 'r--'); yline(trail_time_wide_strip_max, 'r--');
subplot(2,5,3); plot(TFl_OG(:,3), TFt_OG(:,3),'.'); hold on; plot(TFl(:,3), TFt(:,3),'.');
xlabel('TFl'); ylabel('TFt'); title('Time lead Front vs back strip3');
xlim([min(min(TFl_OG)) max(max(TFl_OG))]); ylim([min(min(TFt_OG)) max(max(TFt_OG))]);
xline(lead_time_wide_strip_min, 'r--'); xline(lead_time_wide_strip_max, 'r--');
yline(trail_time_wide_strip_min, 'r--'); yline(trail_time_wide_strip_max, 'r--');
subplot(2,5,4); plot(TFl_OG(:,4), TFt_OG(:,4),'.'); hold on; plot(TFl(:,4), TFt(:,4),'.');
xlabel('TFl'); ylabel('TFt'); title('Front, Time lead vs trail strip4');
xlim([min(min(TFl_OG)) max(max(TFl_OG))]); ylim([min(min(TFt_OG)) max(max(TFt_OG))]);
xline(lead_time_wide_strip_min, 'r--'); xline(lead_time_wide_strip_max, 'r--');
yline(trail_time_wide_strip_min, 'r--'); yline(trail_time_wide_strip_max, 'r--');
subplot(2,5,5); plot(TFl_OG(:,5), TFt_OG(:,5),'.'); hold on; plot(TFl(:,5), TFt(:,5),'.');
xlabel('TFl'); ylabel('TFt'); title('Front, Time lead vs trail strip5');
xlim([min(min(TFl_OG)) max(max(TFl_OG))]); ylim([min(min(TFt_OG)) max(max(TFt_OG))]);
xline(lead_time_wide_strip_min, 'r--'); xline(lead_time_wide_strip_max, 'r--');
yline(trail_time_wide_strip_min, 'r--'); yline(trail_time_wide_strip_max, 'r--');
subplot(2,5,6); plot(TBl_OG(:,1), TBt_OG(:,1),'.'); hold on; plot(TBl(:,1), TBt(:,1),'.');
xlabel('TBl'); ylabel('TBt'); title('Back, Time lead vs trail strip1');
xlim([min(min(TBl_OG)) max(max(TBl_OG))]); ylim([min(min(TBt_OG)) max(max(TBt_OG))]);
xline(lead_time_wide_strip_min, 'r--'); xline(lead_time_wide_strip_max, 'r--');
yline(trail_time_wide_strip_min, 'r--'); yline(trail_time_wide_strip_max, 'r--');
subplot(2,5,7); plot(TBl_OG(:,2), TBt_OG(:,2),'.'); hold on; plot(TBl(:,2), TBt(:,2),'.');
xlabel('TBl'); ylabel('TBt'); title('Back, Time lead vs trail strip2');
xlim([min(min(TBl_OG)) max(max(TBl_OG))]); ylim([min(min(TBt_OG)) max(max(TBt_OG))]);
xline(lead_time_wide_strip_min, 'r--'); xline(lead_time_wide_strip_max, 'r--');
yline(trail_time_wide_strip_min, 'r--'); yline(trail_time_wide_strip_max, 'r--');
subplot(2,5,8); plot(TBl_OG(:,3), TBt_OG(:,3),'.'); hold on; plot(TBl(:,3), TBt(:,3),'.');
xlabel('TBl'); ylabel('TBt'); title('Back, Time lead vs trail strip3');
xlim([min(min(TBl_OG)) max(max(TBl_OG))]); ylim([min(min(TBt_OG)) max(max(TBt_OG))]);
xline(lead_time_wide_strip_min, 'r--'); xline(lead_time_wide_strip_max, 'r--');
yline(trail_time_wide_strip_min, 'r--'); yline(trail_time_wide_strip_max, 'r--');
subplot(2,5,9); plot(TBl_OG(:,4), TBt_OG(:,4),'.'); hold on; plot(TBl(:,4), TBt(:,4),'.');
xlabel('TBl'); ylabel('TBt'); title('Back, Time lead vs trail strip4');
xlim([min(min(TBl_OG)) max(max(TBl_OG))]); ylim([min(min(TBt_OG)) max(max(TBt_OG))]);
xline(lead_time_wide_strip_min, 'r--'); xline(lead_time_wide_strip_max, 'r--');
yline(trail_time_wide_strip_min, 'r--'); yline(trail_time_wide_strip_max, 'r--');
subplot(2,5,10); plot(TBl_OG(:,5), TBt_OG(:,5),'.'); hold on; plot(TBl(:,5), TBt(:,5),'.');
xlabel('TBl'); ylabel('TBt'); title('Back, Time lead vs trail strip5');
xlim([min(min(TBl_OG)) max(max(TBl_OG))]); ylim([min(min(TBt_OG)) max(max(TBt_OG))]);
sgtitle(sprintf('Thick strip time lead vs trail (data from %s)', formatted_datetime));
xline(lead_time_wide_strip_min, 'r--'); xline(lead_time_wide_strip_max, 'r--');
yline(trail_time_wide_strip_min, 'r--'); yline(trail_time_wide_strip_max, 'r--');

%%


figure;
subplot(2,5,1); plot(TFl_OG(:,1), TBl_OG(:,1),'.'); hold on; plot(TFl(:,1), TBl(:,1),'.');
xlabel('TFl'); ylabel('TBl'); title('Time lead Front vs back strip1');
xlim([min(min(TFl_OG)) max(max(TFl_OG))]); ylim([min(min(TBl_OG)) max(max(TBl_OG))]);
xline(lead_time_wide_strip_min, 'r--'); xline(lead_time_wide_strip_max, 'r--');
yline(lead_time_wide_strip_min, 'r--'); yline(lead_time_wide_strip_max, 'r--');
subplot(2,5,2); plot(TFl_OG(:,2), TBl_OG(:,2),'.'); hold on; plot(TFl(:,2), TBl(:,2),'.');
xlabel('TFl'); ylabel('TBl'); title('Time lead Front vs back strip2');
xlim([min(min(TFl_OG)) max(max(TFl_OG))]); ylim([min(min(TBl_OG)) max(max(TBl_OG))]);
xline(lead_time_wide_strip_min, 'r--'); xline(lead_time_wide_strip_max, 'r--');
yline(lead_time_wide_strip_min, 'r--'); yline(lead_time_wide_strip_max, 'r--');
subplot(2,5,3); plot(TFl_OG(:,3), TBl_OG(:,3),'.'); hold on; plot(TFl(:,3), TBl(:,3),'.');
xlabel('TFl'); ylabel('TBl'); title('Time lead Front vs back strip3');
xlim([min(min(TFl_OG)) max(max(TFl_OG))]); ylim([min(min(TBl_OG)) max(max(TBl_OG))]);
xline(lead_time_wide_strip_min, 'r--'); xline(lead_time_wide_strip_max, 'r--');
yline(lead_time_wide_strip_min, 'r--'); yline(lead_time_wide_strip_max, 'r--');
subplot(2,5,4); plot(TFl_OG(:,4), TBl_OG(:,4),'.'); hold on; plot(TFl(:,4), TBl(:,4),'.');
xlabel('TFl'); ylabel('TBl'); title('Time lead Front vs back strip4');
xlim([min(min(TFl_OG)) max(max(TFl_OG))]); ylim([min(min(TBl_OG)) max(max(TBl_OG))]);
xline(lead_time_wide_strip_min, 'r--'); xline(lead_time_wide_strip_max, 'r--');
yline(lead_time_wide_strip_min, 'r--'); yline(lead_time_wide_strip_max, 'r--');
subplot(2,5,5); plot(TFl_OG(:,5), TBl_OG(:,5),'.'); hold on; plot(TFl(:,5), TBl(:,5),'.');
xlabel('TFl'); ylabel('TBl'); title('Time lead Front vs back strip5');
xlim([min(min(TFl_OG)) max(max(TFl_OG))]); ylim([min(min(TBl_OG)) max(max(TBl_OG))]);
xline(lead_time_wide_strip_min, 'r--'); xline(lead_time_wide_strip_max, 'r--');
yline(lead_time_wide_strip_min, 'r--'); yline(lead_time_wide_strip_max, 'r--');
subplot(2,5,6); plot(QF_OG(:,1), QB_OG(:,1),'.'); hold on; plot(QF(:,1), QB(:,1),'.');
xlabel('QF'); ylabel('QB'); title('Charge Front vs back strip1');
xlim([min(min(QF_OG)) max(max(QF_OG))]); ylim([min(min(QB_OG)) max(max(QB_OG))]);
subplot(2,5,7); plot(QF_OG(:,2), QB_OG(:,2),'.'); hold on; plot(QF(:,2), QB(:,2),'.');
xlabel('QF'); ylabel('QB'); title('Charge Front vs back strip2');
xlim([min(min(QF_OG)) max(max(QF_OG))]); ylim([min(min(QB_OG)) max(max(QB_OG))]);
subplot(2,5,8); plot(QF_OG(:,3), QB_OG(:,3),'.'); hold on; plot(QF(:,3), QB(:,3),'.');
xlabel('QF'); ylabel('QB'); title('Charge Front vs back strip3');
xlim([min(min(QF_OG)) max(max(QF_OG))]); ylim([min(min(QB_OG)) max(max(QB_OG))]);
subplot(2,5,9); plot(QF_OG(:,4), QB_OG(:,4),'.'); hold on; plot(QF(:,4), QB(:,4),'.');
xlabel('QF'); ylabel('QB'); title('Charge Front vs back strip4');
xlim([min(min(QF_OG)) max(max(QF_OG))]); ylim([min(min(QB_OG)) max(max(QB_OG))]);
subplot(2,5,10); plot(QF_OG(:,5), QB_OG(:,5),'.'); hold on; plot(QF(:,5), QB(:,5),'.');
xlabel('QF'); ylabel('QB'); title('Charge Front vs back strip5');
xlim([min(min(QF_OG)) max(max(QF_OG))]); ylim([min(min(QB_OG)) max(max(QB_OG))]);
sgtitle(sprintf('Thick strip time and charge front vs back (data from %s)', formatted_datetime));

%%

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
sgtitle(sprintf('Histograms of QF - QB for all WIDE strips (data from %s)', formatted_datetime));



%%

% Wide Strip Charge Spectra and Offset Calibration

% Inspect per-strip charge spectra before any calibration to compare front
% and back readouts channel by channel.

% 5 histograms for wide strips, Q as a function of # of events

% Static offsets measured with self-trigger data; subtract to calibrate strip
% responses on both faces.



% QF_offsets = [75, 85.5, 82, 80, 80]; % from selfTrigger
% QB_offsets = [81, 84, 82, 85, 84];


if run == 1 || run == 2 || run == 3
    % Joana runs (previous to June 2025)
    QF_offsets = [82, 75, 82, 80, 75]; % from selfTrigger
    QB_offsets = [82, 84, 81, 83, 81];
else
    % October run (from October 2025 to beyond)
    fprintf('Using October 2025 offsets\n');
    QF_offsets = [90, 83, 70, 86, 81]; % from selfTrigger
    QB_offsets = [87, 88, 70, 87, 87];
end


% Only subtract offsets where the original entries are non-zero
QB_p = QB - QB_offsets .* (QB ~= 0);
QF_p = QF - QF_offsets .* (QF ~= 0);

QB_p_OG = QB_OG - QB_offsets .* (QB_OG ~= 0);
QF_p_OG = QF_OG - QF_offsets .* (QF_OG ~= 0);
Q_thick_event_OG = sum( (QF_p_OG + QB_p_OG) / 2, 2); % total charge in the 5 wide strips per event, calibrated

clearvars QB_offsets QF_offsets


% -----------------------------------------------------------------------------
% RPC charges for the five narrow strips, which do not carry timing info.
% -----------------------------------------------------------------------------

% This is a key plot. In run 1 the span of both axes is similar, while in runs 2
% and 3 the top charges are much lower, as expected. Calculating how much could give an idea
% of the relative gain of the top and bottom sides of the RPC and hence an idea on the
% real HV difference between both sides.

figure;
subplot(4,6,1); plot(Qt(:,1), Qb(:,1),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip I');
xlim([min(min(Qt)) max(max(Qt))]); ylim([min(min(Qb)) max(max(Qb))]);
subplot(4,6,2); plot(Qt(:,2), Qb(:,2),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip II');
xlim([min(min(Qt)) max(max(Qt))]); ylim([min(min(Qb)) max(max(Qb))]);
subplot(4,6,3); plot(Qt(:,3), Qb(:,3),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip III');
xlim([min(min(Qt)) max(max(Qt))]); ylim([min(min(Qb)) max(max(Qb))]);
subplot(4,6,4); plot(Qt(:,4), Qb(:,4),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip IV');
xlim([min(min(Qt)) max(max(Qt))]); ylim([min(min(Qb)) max(max(Qb))]);
subplot(4,6,5); plot(Qt(:,5), Qb(:,5),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip V');
xlim([min(min(Qt)) max(max(Qt))]); ylim([min(min(Qb)) max(max(Qb))]);
subplot(4,6,6); plot(Qt(:,6), Qb(:,6),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip VI');
xlim([min(min(Qt)) max(max(Qt))]); ylim([min(min(Qb)) max(max(Qb))]);
subplot(4,6,7); plot(Qt(:,7), Qb(:,7),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip VII');
xlim([min(min(Qt)) max(max(Qt))]); ylim([min(min(Qb)) max(max(Qb))]);
subplot(4,6,8); plot(Qt(:,8), Qb(:,8),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip VIII');
xlim([min(min(Qt)) max(max(Qt))]); ylim([min(min(Qb)) max(max(Qb))]);
subplot(4,6,9); plot(Qt(:,9), Qb(:,9),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip IX');
xlim([min(min(Qt)) max(max(Qt))]); ylim([min(min(Qb)) max(max(Qb))]);
subplot(4,6,10); plot(Qt(:,10), Qb(:,10),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip X');
xlim([min(min(Qt)) max(max(Qt))]); ylim([min(min(Qb)) max(max(Qb))]);
subplot(4,6,11); plot(Qt(:,11), Qb(:,11),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip XI');
xlim([min(min(Qt)) max(max(Qt))]); ylim([min(min(Qb)) max(max(Qb))]);
subplot(4,6,12); plot(Qt(:,12), Qb(:,12),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip XII');
xlim([min(min(Qt)) max(max(Qt))]); ylim([min(min(Qb)) max(max(Qb))]);
subplot(4,6,13); plot(Qt(:,13), Qb(:,13),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip XIII');
xlim([min(min(Qt)) max(max(Qt))]); ylim([min(min(Qb)) max(max(Qb))]);
subplot(4,6,14); plot(Qt(:,14), Qb(:,14),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip XIV');
xlim([min(min(Qt)) max(max(Qt))]); ylim([min(min(Qb)) max(max(Qb))]);
subplot(4,6,15); plot(Qt(:,15), Qb(:,15),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip XV');
xlim([min(min(Qt)) max(max(Qt))]); ylim([min(min(Qb)) max(max(Qb))]);
subplot(4,6,16); plot(Qt(:,16), Qb(:,16),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip XVI');
xlim([min(min(Qt)) max(max(Qt))]); ylim([min(min(Qb)) max(max(Qb))]);
subplot(4,6,17); plot(Qt(:,17), Qb(:,17),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip XVII');
xlim([min(min(Qt)) max(max(Qt))]); ylim([min(min(Qb)) max(max(Qb))]);
subplot(4,6,18); plot(Qt(:,18), Qb(:,18),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip XVIII');
xlim([min(min(Qt)) max(max(Qt))]); ylim([min(min(Qb)) max(max(Qb))]);
subplot(4,6,19); plot(Qt(:,19), Qb(:,19),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip XIX');
xlim([min(min(Qt)) max(max(Qt))]); ylim([min(min(Qb)) max(max(Qb))]);
subplot(4,6,20); plot(Qt(:,20), Qb(:,20),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip XX');
xlim([min(min(Qt)) max(max(Qt))]); ylim([min(min(Qb)) max(max(Qb))]);
subplot(4,6,21); plot(Qt(:,21), Qb(:,21),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip XXI');
xlim([min(min(Qt)) max(max(Qt))]); ylim([min(min(Qb)) max(max(Qb))]);
subplot(4,6,22); plot(Qt(:,22), Qb(:,22),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip XXII');
xlim([min(min(Qt)) max(max(Qt))]); ylim([min(min(Qb)) max(max(Qb))]);
subplot(4,6,23); plot(Qt(:,23), Qb(:,23),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip XXIII');
xlim([min(min(Qt)) max(max(Qt))]); ylim([min(min(Qb)) max(max(Qb))]);
subplot(4,6,24); plot(Qt(:,24), Qb(:,24),'.'); xlabel('Qt'); ylabel('Qb'); title('Charge top vs bottom NARROW strip XXIV');
xlim([min(min(Qt)) max(max(Qt))]); ylim([min(min(Qb)) max(max(Qb))]);
sgtitle(sprintf('Narrow strip charge top vs bottom (data from %s)', formatted_datetime));



%%


% NOW THE CROSSED CUTS ARE APPLIED TO SELECT VALID EVENTS IN THE PMTS
% Create a condition where the Qcint is ~= 0 in the four PMTs

validEvents_signal = (Qcint_OG(:,1) ~= 0) & (Qcint_OG(:,2) ~= 0) & (Qcint_OG(:,3) ~= 0) & (Qcint_OG(:,4) ~= 0);
validEvents_coin = (Qcint(:,1) ~= 0) & (Qcint(:,2) ~= 0) & (Qcint(:,3) ~= 0) & (Qcint(:,4) ~= 0);


% ==================== Signal EVENTS (zero-out others) ====================

% --- PMTs ---
Qcint_signal = zeros(size(Qcint_OG), 'like', Qcint_OG);
Qcint_signal(validEvents_signal, :) = Qcint_OG(validEvents_signal, :);

% --- THICK (event-level) ---
Q_thick_event_signal = zeros(size(Q_thick_event_OG), 'like', Q_thick_event_OG);
Q_thick_event_signal(validEvents_signal) = Q_thick_event_OG(validEvents_signal);

% --- THIN STRIPS ---
Qb_signal = zeros(size(Qb_OG), 'like', Qb_OG);
Qt_signal = zeros(size(Qt_OG), 'like', Qt_OG);
Qb_signal(validEvents_signal, :) = Qb_OG(validEvents_signal, :);
Qt_signal(validEvents_signal, :) = Qt_OG(validEvents_signal, :);

% Totals per event within the valid selection (zeros for non-valid rows)
Q_thin_top_event_signal = sum(Qt_signal, 2);
Q_thin_bot_event_signal = sum(Qb_signal, 2);


% ==================== COIN VALID EVENTS (zero-out others) ====================

% --- PMTs ---
Qcint_coin = zeros(size(Qcint_OG), 'like', Qcint_OG);
Qcint_coin(validEvents_coin, :) = Qcint_OG(validEvents_coin, :);

% --- THICK (event-level) ---
Q_thick_event_coin = zeros(size(Q_thick_event_OG), 'like', Q_thick_event_OG);
Q_thick_event_coin(validEvents_coin) = Q_thick_event_OG(validEvents_coin);

% --- THIN STRIPS ---
Qb_coin = zeros(size(Qb_OG), 'like', Qb_OG);
Qt_coin = zeros(size(Qt_OG), 'like', Qt_OG);
Qb_coin(validEvents_coin, :) = Qb_OG(validEvents_coin, :);
Qt_coin(validEvents_coin, :) = Qt_OG(validEvents_coin, :);

% Totals per event within the valid selection (zeros for non-valid rows)
Q_thin_top_event_coin = sum(Qt_coin, 2);
Q_thin_bot_event_coin = sum(Qb_coin, 2);


% ==================== VALID EVENTS (zero-out others) ====================

% --- PMTs ---
Qcint_good = zeros(size(Qcint), 'like', Qcint);
Qcint_good(validEvents_coin, :) = Qcint(validEvents_coin, :);

% --- THICK (event-level/matrices) ---
% X_thick_strip_good = zeros(size(X_thick_strip), 'like', X_thick_strip);
% Y_thick_strip_good = zeros(size(Y_thick_strip), 'like', Y_thick_strip);
% T_thick_strip_good = zeros(size(T_thick_strip), 'like', T_thick_strip);

% X_thick_strip_good(validEvents_coin, :) = X_thick_strip(validEvents_coin, :);
% Y_thick_strip_good(validEvents_coin, :) = Y_thick_strip(validEvents_coin, :);
% T_thick_strip_good(validEvents_coin, :) = T_thick_strip(validEvents_coin, :);

% Q_thick_event_good = zeros(size(Q_thick_event), 'like', Q_thick_event);
% Q_thick_event_good(validEvents_coin) = Q_thick_event(validEvents_coin);

% --- THIN STRIPS ---
Qb_good = zeros(size(Qb), 'like', Qb);
Qt_good = zeros(size(Qt), 'like', Qt);
Qb_good(validEvents_coin, :) = Qb(validEvents_coin, :);
Qt_good(validEvents_coin, :) = Qt(validEvents_coin, :);

% Totals per event within the valid selection (zeros for non-valid rows)
Q_thin_top_event_good = sum(Qt_good, 2);
Q_thin_bot_event_good = sum(Qb_good, 2);


%%



QF_good = zeros(size(QF), 'like', QF);
QB_good = zeros(size(QB), 'like', QB);
QF_good(validEvents_coin, :) = QF(validEvents_coin, :);
QB_good(validEvents_coin, :) = QB(validEvents_coin, :);


QF_p_good = zeros(size(QF_p), 'like', QF_p);
QB_p_good = zeros(size(QB_p), 'like', QB_p);
QF_p_good(validEvents_coin, :) = QF_p(validEvents_coin, :);
QB_p_good(validEvents_coin, :) = QB_p(validEvents_coin, :);


TFl_good = zeros(size(TFl), 'like', TFl);
TBl_good = zeros(size(TBl), 'like', TBl);
TFl_good(validEvents_coin, :) = TFl(validEvents_coin, :);
TBl_good(validEvents_coin, :) = TBl(validEvents_coin, :);

% Charge sum over all wide strips per event

% QB_p_pos = QB_p; QB_p_pos(QB_p<0) = 0; %set negative charges to 0
% QF_p_pos = QF_p; QF_p_pos(QF_p<0) = 0; %set negative charges to 0

% Q_thick_event = (QB_p_pos + QF_p_pos) / 2; % total charge in the 5 wide strips per event

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
    sgtitle(sprintf('Wide strip charge spectra and calibration (data from %s)', formatted_datetime));
end


%%




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

figure;
% Avoid plotting zero values in histograms, take ~= 0 values
Q_nonzero = Q; Q_nonzero(Q_nonzero==0) = [];
X_nonzero = X; X_nonzero(X_nonzero==0) = [];
T_nonzero = T; T_nonzero(T_nonzero==0) = [];
Y_nonzero = Y; Y_nonzero(Y_nonzero==0) = [];
subplot(2,2,1); histogram(Q_nonzero, 0:0.1:200); xlabel('Q [ns]'); ylabel('# of events'); title('Q total in sum of THICK STRIPS');
subplot(2,2,2); histogram(X_nonzero, 1:0.5:5.5); xlabel('X (strip with Qmax)'); ylabel('# of events'); title('X position (strip with Qmax)');
subplot(2,2,3); histogram(T_nonzero, -220:1:-100); xlabel('T [ns]'); ylabel('# of events'); title('T (mean of Tfl and Tbl)');
subplot(2,2,4); histogram(Y_nonzero, -2:0.01:2); xlabel('Y [ns]'); ylabel('# of events'); title('Y (Tfl-Tbl)/2');
sgtitle(sprintf('THICK STRIP OBSERVABLES (data from %s)', formatted_datetime));

X_thick_strip = X; %redefine X_thick_strip to be the strip number with maximum charge
Y_thick_strip = Y; %redefine Y_thick_strip to be the Y position with maximum charge
T_thick_strip = T; %redefine T_thick_strip to be the T from the strip with maximum charge

Q_thick_event = Q; %redefine Q_thick_event to be the Q from the strip with maximum charge



%%







% Event-Level Maximum Charge Aggregation

% Filtered events for 0s

% calculation of maximum charges and RAW position as a function of Qmax
[QFmax,XFmax] = max(QF_p_good,[],2);    %XFmax -> strip of Qmax
[QBmax,XBmax] = max(QB_p_good,[],2);

% Keep only events where the strip with maximum charge matches on both faces
Ind2Cut   = find(~isnan(QF_p_good) & ~isnan(QB_p_good) & XFmax == XBmax);
[row,col] = ind2sub(size(TFl),Ind2Cut); %row=evento com Qmax na mesma strip; col=strip não interessa pois fica-se com a strip com Qmax
rows      = unique(row); %events sorted and without repetitions
Ind2Keep  = sub2ind(size(TFl),rows,XFmax(rows)); %indices of the Qmax values, provided QFmax and QBmax are on the same strip

T = nan(rawEvents,1); Q = nan(rawEvents,1); X = nan(rawEvents,1); Y = nan(rawEvents,1);
T(rows) = (TFl_good(Ind2Keep) + TBl_good(Ind2Keep)) / 2; %[ns]
Q(rows) = (QF_p_good(Ind2Keep) + QB_p_good(Ind2Keep)) /2;    %[ns] sum of Qmax front and back -> contains NaNs if an event fails the Ind2Keep condition
X(rows) = XFmax(rows);  %strip number where Qmax is found (1 to 5)
Y(rows) = (TFl_good(Ind2Keep) - TBl_good(Ind2Keep)) / 2; %[ns]

figure;
% Avoid plotting zero values in histograms, take ~= 0 values
Q_nonzero = Q; Q_nonzero(Q_nonzero==0) = [];
X_nonzero = X; X_nonzero(X_nonzero==0) = [];
T_nonzero = T; T_nonzero(T_nonzero==0) = [];
Y_nonzero = Y; Y_nonzero(Y_nonzero==0) = [];
subplot(2,2,1); histogram(Q_nonzero, 0:0.1:200); xlabel('Q [ns]'); ylabel('# of events'); title('Q total in sum of THICK STRIPS');
subplot(2,2,2); histogram(X_nonzero, 1:0.5:5.5); xlabel('X (strip with Qmax)'); ylabel('# of events'); title('X position (strip with Qmax)');
subplot(2,2,3); histogram(T_nonzero, -220:1:-100); xlabel('T [ns]'); ylabel('# of events'); title('T (mean of Tfl and Tbl)');
subplot(2,2,4); histogram(Y_nonzero, -2:0.01:2); xlabel('Y [ns]'); ylabel('# of events'); title('Y (Tfl-Tbl)/2');
sgtitle(sprintf('THICK STRIP OBSERVABLES (data from %s)', formatted_datetime));

X_thick_strip_good = X; %redefine X_thick_strip to be the strip number with maximum charge
Y_thick_strip_good = Y; %redefine Y_thick_strip to be the Y position with maximum charge
T_thick_strip_good = T; %redefine T_thick_strip to be the T from the strip with maximum charge

Q_thick_event_good = Q; %redefine Q_thick_event to be the Q from the strip with maximum charge

scatter_plot = false;

% Flatten to column vectors and equalize length
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

        if scatter_plot
            scatter(av, bv, ptSize, '.', 'MarkerEdgeAlpha', 0.35);
        else
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
        end

        grid on; box on; axis tight;
        xlabel(names{pairs(i,1)}); ylabel(names{pairs(i,2)});
        title(sprintf('%s vs %s (run %s)', names{pairs(i,2)}, names{pairs(i,1)}, run));
    else
        axis off; title(sprintf('%s vs %s (no data)', names{pairs(i,2)}, names{pairs(i,1)}));
    end
end


sgtitle(sprintf('All 2D scatter combinations (zeros removed) — run %s', run));




%%


% 2) Quantile limits (thin channels share limits)
q005_b = quantile(Q_thin_bot_event_good, 0.005);
q005_t = quantile(Q_thin_top_event_good, 0.005);
q005   = min(q005_b, q005_t);

q95_b  = quantile(Q_thin_bot_event_good, 0.95);
q95_t  = quantile(Q_thin_top_event_good, 0.95);
q95    = max(q95_b, q95_t);

% Thick channel limits (separate scale)
q005_thick = quantile(Q_thick_event_good, 0.005);
q95_thick  = quantile(Q_thick_event_good, 0.95);

% Bin edges (match your “like this” snippet for thin; keep fine bins for thick)
thinEdges  = 0:300:5e4;
thickEdges = 0:1:300;


% Create a non_zero version called Q_thick_event_good_hist
% THICK
Q_thick_event_hist = Q_thick_event;
Q_thick_event_hist(Q_thick_event_hist == 0) = []; % remove zeros for histogram
Q_thick_event_good_hist = Q_thick_event_good;
Q_thick_event_good_hist(Q_thick_event_good_hist == 0) = []; % remove zeros for histogram

% THIN TOP
Q_thin_bot_event_hist = Q_thin_bot_event;
Q_thin_bot_event_hist(Q_thin_bot_event_hist == 0) = []; % remove zeros for histogram
Q_thin_bot_event_good_hist = Q_thin_bot_event_good;
Q_thin_bot_event_good_hist(Q_thin_bot_event_good_hist == 0) = []; % remove zeros for histogram

% THIN BOTTOM
Q_thin_top_event_hist = Q_thin_top_event;
Q_thin_top_event_hist(Q_thin_top_event_hist == 0) = []; % remove zeros for histogram
Q_thin_top_event_good_hist = Q_thin_top_event_good;
Q_thin_top_event_good_hist(Q_thin_top_event_good_hist == 0) = []; % remove zeros for histogram


% FIGURE 1 — Thin bottom / Thin top (hist + hist + scatter), with valid overlays
figure;
subplot(1,3,1);
histogram(Q_thin_bot_event_hist, thinEdges, 'DisplayName','all events'); hold on;
histogram(Q_thin_bot_event_good_hist, thinEdges, 'DisplayName','valid only');
ylabel('# of events'); xlabel('Q (bottom)');
title('Q narrow bottom spectrum (sum of Q per event)');
xlim([q005 q95]); legend('show');

subplot(1,3,2);
histogram(Q_thin_top_event_hist, thinEdges, 'DisplayName','all events'); hold on;
histogram(Q_thin_top_event_good_hist, thinEdges, 'DisplayName','valid only');
ylabel('# of events'); xlabel('Q (top)');
title('Q narrow top spectrum (sum of Q per event)');
xlim([q005 q95]); legend('show');

subplot(1,3,3);
plot(Q_thin_bot_event, Q_thin_top_event, '.', 'DisplayName','all events'); hold on;
plot(Q_thin_bot_event_good, Q_thin_top_event_good, '.', 'DisplayName','valid only');
plot([q005 q95],[q005 q95],'--','Color',[1 0.5 0],'LineWidth',2.5,'DisplayName','y = x');
xlabel('Q (bottom)'); ylabel('Q (top)');
title('Q bottom vs Q top');
xlim([q005 q95]); ylim([q005 q95]); legend('show');
sgtitle(sprintf('Charge of the event (thin only; all vs valid; run %s)', run));

% FIGURE 2 — Thin bottom vs Thick
figure;
subplot(1,3,1);
histogram(Q_thin_bot_event_hist, thinEdges, 'DisplayName','all events'); hold on;
histogram(Q_thin_bot_event_good_hist, thinEdges, 'DisplayName','valid only');
ylabel('# of events'); xlabel('Q (bottom)');
title('Q narrow bottom spectrum (sum of Q per event)');
xlim([q005 q95]); legend('show');

subplot(1,3,2);
histogram(Q_thick_event_hist, thickEdges, 'DisplayName','all events'); hold on;
histogram(Q_thick_event_good_hist, thickEdges, 'DisplayName','valid only');
ylabel('# of events'); xlabel('Q (thick)');
title('Q thick spectrum (sum of Q per event)');
xlim([q005_thick q95_thick]); legend('show');

subplot(1,3,3);
plot(Q_thin_bot_event, Q_thick_event, '.', 'DisplayName','all events'); hold on;
plot(Q_thin_bot_event_good, Q_thick_event_good, '.', 'DisplayName','valid only');
xlabel('Q (bottom)'); ylabel('Q (thick)');
title('Q bottom vs Q thick');
xlim([q005 q95]); ylim([q005_thick q95_thick]); legend('show');
sgtitle(sprintf('Charge of the event (bottom vs thick; all vs valid; run %s)', run));

% FIGURE 3 — Thick vs Thin top
figure;
subplot(1,3,1);
histogram(Q_thick_event_hist, thickEdges, 'DisplayName','all events'); hold on;
histogram(Q_thick_event_good_hist, thickEdges, 'DisplayName','valid only');
ylabel('# of events'); xlabel('Q (thick)');
title('Q thick spectrum (sum of Q per event)');
xlim([q005_thick q95_thick]); legend('show');

subplot(1,3,2);
histogram(Q_thin_top_event_hist, thinEdges, 'DisplayName','all events'); hold on;
histogram(Q_thin_top_event_good_hist, thinEdges, 'DisplayName','valid only');
ylabel('# of events'); xlabel('Q (top)');
title('Q narrow top spectrum (sum of Q per event)');
xlim([q005 q95]); legend('show');

subplot(1,3,3);
plot(Q_thick_event, Q_thin_top_event, '.', 'DisplayName','all events'); hold on;
plot(Q_thick_event_good, Q_thin_top_event_good, '.', 'DisplayName','valid only');
xlabel('Q (thick)'); ylabel('Q (top)');
title('Q thick vs Q top');
xlim([q005_thick q95_thick]); ylim([q005 q95]); legend('show');
sgtitle(sprintf('Charge of the event (thick vs top; all vs valid; run %s)', run));




%%

% Define a function called mm_to_strip that converts mm to strip number, it works with vectors too,
% for example with center
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

position_from_narrow_strips = false;
if position_from_narrow_strips

    % Position determination from the narrow strips
    % Plot in X the strip numbers (1 to 24) and in Y each row of the Qt matrix
    % I explain: I want in the x axes the strip number (1 to 24) and in the y axis
    % the charge value in each component
    
    figure;
    subplot(2,1,1);
    % Plot only a random sample of 1000 events to avoid overplotting
    sample_indices = randperm(rawEvents, min(5, rawEvents));
    plot(1:24, Qt(sample_indices, :)', '-o'); hold on;
    title(sprintf('Charge distribution across NARROW strips for sample events (top) - Sample size: %d (run %s)', length(sample_indices), run));
    xlabel('Strip Number');
    ylabel('Charge Qt [ns]');
    xlim([1 24]);
    subplot(2,1,2);
    % Plot only a random sample of 1000 events to avoid overplotting
    sample_indices = randperm(rawEvents, min(10, rawEvents));
    plot(1:24, Qb(sample_indices, :)', '-o'); hold on;
    title(sprintf('Charge distribution across NARROW strips for sample events (bottom) - Sample size: %d (run %s)', length(sample_indices), run));
    xlabel('Strip Number');
    ylabel('Charge Qb [ns]');
    xlim([1 24]);

    sgtitle(sprintf('NARROW STRIP CHARGE DISTRIBUTION (top and bottom) (data from %s)', formatted_datetime));


    % ===============================================================
    % WRAPPED GAUSSIAN FITS FOR Qt AND Qb
    % ===============================================================

    nStrips = 24;
    x = (1:nStrips)';                 % strip indices (column)
    nTop   = size(Qt,1);
    nBot   = size(Qb,1);

    fitTop = nan(nTop,3);             % [mu, sigma, chisq]
    fitBot = nan(nBot,3);

    % Helper to wrap distances on a 24-strip circle
    wrapDist = @(dx) mod(dx + nStrips/2, nStrips) - nStrips/2;  % in [-12, 12)

    % Model with parameters p = [mu_raw, log_sigma, log_amp, baseline]
    % (sigma = exp(p2) >= 0, amp = exp(p3) >= 0, baseline free)
    model_from_p = @(p) ( ...
        p(4) + exp(p(3)) * exp( -0.5 * (wrapDist(x - (1 + mod(p(1)-1,nStrips))).^2) / (exp(p(2))^2) ) ...
    );

    % Sum of squared residuals (used as "chisq" proxy)
    sse = @(y, p) sum( (y - model_from_p(p)).^2 );

    % fminsearch options
    optsFS = optimset('Display','off','MaxFunEvals',2000,'MaxIter',2000);

    % --------------- Fit Qt (TOP) ---------------
    for i = 1:nTop
        y = double(Qt(i,:))';
        if ~any(isfinite(y)) || all(y==0)
            continue;
        end
        % Initial guesses
        [~, mu0] = max(y);
        yMin = min(y); yMax = max(y);
        A0 = max(yMax - yMin, eps);
        p0 = [mu0, log(3), log(A0), yMin];

        obj = @(p) sse(y, p);
        pFit = fminsearch(obj, p0, optsFS);

        mu    = 1 + mod(pFit(1)-1, nStrips);  % wrap to [1,24]
        sigma = max(exp(pFit(2)), eps);
        chisq = obj(pFit);                     % SSE as chi^2-like metric

        fitTop(i,:) = [mu, sigma, chisq];
    end

    % --------------- Fit Qb (BOTTOM) ---------------
    for i = 1:nBot
        y = double(Qb(i,:))';
        if ~any(isfinite(y)) || all(y==0)
            continue;
        end
        [~, mu0] = max(y);
        yMin = min(y); yMax = max(y);
        A0 = max(yMax - yMin, eps);
        p0 = [mu0, log(3), log(A0), yMin];

        obj = @(p) sse(y, p);
        pFit = fminsearch(obj, p0, optsFS);

        mu    = 1 + mod(pFit(1)-1, nStrips);
        sigma = max(exp(pFit(2)), eps);
        chisq = obj(pFit);

        fitBot(i,:) = [mu, sigma, chisq];
    end

    % Clean rows (optional): remove any rows that stayed NaN
    fitTop = fitTop(any(isfinite(fitTop),2), :);
    fitBot = fitBot(any(isfinite(fitBot),2), :);

    Y_thin_strip_top = fitTop(:,1);    % mu from top fit
    X_thin_strip_bot = fitBot(:,1);    % mu from bottom fit




    % ===============================================================
    % Diagnostic plots
    % ===============================================================

    % ===============================================================
    % 6x6 CORRELATION PLOT FOR FIT PARAMETERS (Top and Bot Combined)
    % ===============================================================

    % Combine fitTop and fitBot data in the specified order: mu_top, sigma_top, chisq_top, chisq_bot, sigma_bot, mu_bot
    fitCombined = [fitTop(:,1), fitTop(:,2), fitTop(:,3), Q_thin_top_event, Q_thin_bot_event, fitBot(:,3), fitBot(:,2), fitBot(:,1)];

    % Labels for the variables
    labels = {'\mu_{top}', '\sigma_{top}', '\chi^2_{top}', 'Q_{top}', 'Q_{bot}', '\chi^2_{bot}', '\sigma_{bot}', '\mu_{bot}'};

    % Remove rows with any NaN
    fitCombined = fitCombined(all(isfinite(fitCombined), 2), :);

    % Compute 95th percentiles for chisq variables to set appropriate limits
    q_95_qthin_top = prctile(fitCombined(:,4), 99);
    q_95_qthin_bot = prctile(fitCombined(:,5), 99);
    q95_chisq_top = prctile(fitTop(:,3), 99);
    q95_chisq_bot = prctile(fitBot(:,3), 99);
    max_chisq = max(q95_chisq_top, q95_chisq_bot);

    % Define xLimits for each variable (use 0-25 for mu and sigma, 0-max_chisq for chisq)
    xLimits = [25, 8, max_chisq, q_95_qthin_top, q_95_qthin_bot, max_chisq, 8, 25];  % Adjust as needed for other variables

    % Bin edges (fixed for simplicity, but xlim will adjust)
    binEdges = 0:0.1:25;

    figure;
    tiledlayout(8,8,'TileSpacing','compact','Padding','compact');

    for i = 1:8
        for j = 1:8
            nexttile((i-1)*8 + j);
            if i == j
                % --- Diagonal: histogram of the variable ---
                histogram(fitCombined(:,i), binEdges, ...
                    'FaceColor',[0.3 0.5 0.8], 'EdgeColor','none');
                xlim([0, xLimits(i)]);
                xlabel(labels{i}, 'Interpreter','tex');
                ylabel('Count');
            elseif i > j
                % --- Lower triangle: scatter ---
                scatter(fitCombined(:,j), fitCombined(:,i), 3, ...
                    'filled', 'MarkerFaceAlpha', 0.5);
                xlim([0, xLimits(j)]);
                ylim([0, xLimits(i)]);
                xlabel(labels{j}, 'Interpreter','tex');
                ylabel(labels{i}, 'Interpreter','tex');
                
            else
                % --- Upper triangle: leave blank ---
                axis off;
            end
        end
    end

    sgtitle(sprintf('Correlation of Gaussian Fit Parameters (Top and Bot Combined) (data from %s)', formatted_datetime));



    % I want a scatter plot which is X_thick_strip vs Y_thick_strip
    % Also there is a multiplexing in the thin strips, so what we have to do is to
    % remove the degeneracy using the thick strip information, that is, X_thin_strip is
    % a value between 1 and 24, but actually is like a modulo 24, because there are 5 thick strips
    % and 24 thin strips INSIDE each thick strip. So I want to create first a matrix of X_thin positions
    % where to each X, it is associated [X, X+24, X +48, X+72, X+96] and now display them in a scatter plot
    % top and bottom


    wrapPeriod = 24;             % strips per period
    nWraps = 5;                  % number of periods to replicate


    % Only use nonzero Y_thick_strip values
    % nonzero_idx = Y_thick_strip ~= 0;
    % Y_thin_strip_top_sel = Y_thin_strip_top(nonzero_idx);      % [N x 1]
    Y_thin_strip_top_sel = Y_thin_strip_top;      % [N x 1]
    % Yvals = (Y_thick_strip(nonzero_idx) + 1.5)/3 * 120 + 1;   % [N x 1]
    Yvals = (Y_thick_strip + 1.5)/3 * 120 + 1;   % [N x 1]
    % Expand Y_thin_strip_top_sel for all wrap possibilities [N x nWraps]
    Y_thin_strip_top_all = Y_thin_strip_top_sel + (0:nWraps-1)*wrapPeriod; % [N x nWraps]
    % For each event, find the wrap that minimizes the distance to Yvals
    diffs = abs(Y_thin_strip_top_all - Yvals);
    [~, idx_min] = min(diffs, [], 2);
    % Select the best unwrapped Y_thin_strip_top for each event
    Y_thin_strip_top_real = Y_thin_strip_top_all(sub2ind(size(Y_thin_strip_top_all), (1:size(Y_thin_strip_top_all,1))', idx_min));


    X_thin_bot_real = X_thin_strip_bot + (X_thick_strip - 1) * wrapPeriod;
    Y_thin_top_real = Y_thin_strip_top_real;



    % ===============================================================
    % Periodically expanded scatter: top vs bottom fitted mu values
    % showing all wrapped diagonals
    % ===============================================================

    wrapPeriod = 24;             % strips per period
    nWraps = 5;                  % number of periods to replicate

    % Expand along the wrap dimension for both axes
    X_thin_expanded_bot = arrayfun(@(x) x + (0:nWraps-1)*wrapPeriod, X_thin_strip_bot, 'UniformOutput', false);
    X_thin_expanded_bot = vertcat(X_thin_expanded_bot{:});

    Y_thin_expanded_top = arrayfun(@(x) x + (0:nWraps-1)*wrapPeriod, Y_thin_strip_top, 'UniformOutput', false);
    Y_thin_expanded_top = vertcat(Y_thin_expanded_top{:});

    % Make all combinations of (top+offsetTop , bot+offsetBot)
    [Xgrid_bot, Ygrid_top] = ndgrid(0:(nWraps-1), 0:(nWraps-1));
    pairs = [Xgrid_bot(:), Ygrid_top(:)];


    nonzero_idx = Y_thick_strip ~= 0;
    X_thick_strip = X_thick_strip(nonzero_idx);      % [N x 1]
    Y_thick_strip = Y_thick_strip(nonzero_idx);      % [N x 1]
    X_thin_strip_bot = X_thin_strip_bot(nonzero_idx);% [N x 1]
    Y_thin_strip_top = Y_thin_strip_top(nonzero_idx);% [N x 1]

    X_thick_pos = X_thick_strip / 5 * 120 - 12;
    Y_thick_pos = (Y_thick_strip + 1.5)/3 * 120 + 1;

    % I want you to put distribute every value in X_thick_pos in a uniform distribution
    % between [0, 24] if it is between [0, 24], between [24, 48] if it is between [24, 48], etc
    wrap_idx = floor(X_thick_pos / wrapPeriod); % 0-based index: 0 for [0,24), 1 for [24,48), etc.
    X_thick_pos_uniform = wrap_idx * wrapPeriod + rand(size(X_thick_pos)) * wrapPeriod;
    X_thick_pos = X_thick_pos_uniform;


    % ===============================================================
    % Unified 2x2 scatter plot matrix with consistent limits, labels, and boundaries
    % ===============================================================

    wrapPeriod = 24;
    nWraps     = 5;
    totalRange = wrapPeriod * nWraps;
    lims       = [1 totalRange];
    commonColor = [0.2 0.8 0.2];  % same greenish tone for all points

    % ---------------------------------------------------------------


    % mm in [-150,150] -> axis coordinate in [1,120]
    toPosCoord = @(mm) 1 + (mm + 150) * (119/300);   % exact: -150 -> 1, +150 -> 120

    % mm size (width/height) -> axis size (same units as [1..120])
    toPosSize  = @(mm) abs(mm) * (119/300);          % scale only, no offset


    % --- Inputs in mm ---
    base_mm   = 20;
    height_mm = 80;
    center_mm = [-80, -27];

    % --- Convert to axis units (1..120) ---
    base_ax   = toPosSize(base_mm);
    height_ax = toPosSize(height_mm);
    center_ax = [toPosCoord(center_mm(1)), toPosCoord(center_mm(2))];

    % --- Rectangle [x_left, y_bottom, width, height] in axis units ---
    rect_ax = [center_ax(1) - base_ax/2, center_ax(2) - height_ax/2, base_ax, height_ax];

    
    figure;

    % === (1) THICK X vs THICK Y ===
    subplot(2,2,1);
    scatter(X_thick_pos, Y_thick_pos, 3, commonColor, 'filled', 'MarkerFaceAlpha', 0.6);
    hold on;
    xlabel('THICK X position [1–120]');
    ylabel('THICK Y position [1–120]');
    title('THICK X vs THICK Y');
    addBoundaries(gca, wrapPeriod, nWraps, lims);
    rectangle('Position', rect_ax, 'EdgeColor', 'r', 'LineWidth', 2);

    % === (2) THIN X vs THICK Y ===
    subplot(2,2,2); hold on;
    for k = 1:size(pairs,1)
        offsetBot = pairs(k,2)*wrapPeriod;
        scatter(X_thin_strip_bot + offsetBot, Y_thick_pos, ...
                3, commonColor, 'filled', 'MarkerFaceAlpha', 0.6);
    end
    hold on;
    xlabel('THIN X_{bot} (unwrapped) [1–120]');
    ylabel('THICK Y position [1–120]');
    title('THIN X (bot) vs THICK Y');
    addBoundaries(gca, wrapPeriod, nWraps, lims);
    rectangle('Position', rect_ax, 'EdgeColor', 'r', 'LineWidth', 2);

    % === (3) THICK X vs THIN Y ===
    subplot(2,2,3); hold on;
    for k = 1:size(pairs,1)
        offsetTop = pairs(k,1)*wrapPeriod;
        scatter(X_thick_pos, Y_thin_strip_top + offsetTop, ...
                3, commonColor, 'filled', 'MarkerFaceAlpha', 0.6);
    end
    hold on;
    xlabel('THICK X position [1–120]');
    ylabel('THIN Y_{top} (unwrapped) [1–120]');
    title('THICK X vs THIN Y (top)');
    addBoundaries(gca, wrapPeriod, nWraps, lims);
    rectangle('Position', rect_ax, 'EdgeColor', 'r', 'LineWidth', 2);

    % === (4) THIN X vs THIN Y ===
    subplot(2,2,4); hold on;
    for k = 1:size(pairs,1)
        offsetBot = pairs(k,2)*wrapPeriod;
        offsetTop = pairs(k,1)*wrapPeriod;
        scatter(X_thin_strip_bot + offsetBot, Y_thin_strip_top + offsetTop, ...
                3, commonColor, 'filled', 'MarkerFaceAlpha', 0.6);
    end
    hold on;
    xlabel('THIN X_{bot} (unwrapped) [1–120]');
    ylabel('THIN Y_{top} (unwrapped) [1–120]');
    title('THIN X vs THIN Y');
    addBoundaries(gca, wrapPeriod, nWraps, lims);
    rectangle('Position', rect_ax, 'EdgeColor', 'r', 'LineWidth', 2);

    sgtitle(sprintf('2×2 Correlations between THICK and THIN Strip Positions (all wrapped) (data from %s)', formatted_datetime));
    


    % ===============================================================
    % Joint wrap decode using a composite cost over multiple pairings:
    %   (Xthin,Ythin), (Xthick,Ythick), (Xthin,Ythick), (Xthick,Ythin)
    % The only degrees of freedom are the thin wraps (kx, ky). We score each
    % candidate (kx, ky) with a weighted sum of distances:
    %   - 2D thin↔thick:        rho2d([Xc-Xt, Yc-Yt])                (w_tt2d)
    %   - 2D cross (thinX vs thickY & thickX vs thinY combined):     rho2d([Xc-Xt, Yc-Yt]) (w_cross2d)
    %   - 1D X-only (thinX↔thickX):                                  rho1d(|Xc-Xt|)        (w_x1d)
    %   - 1D Y-only (thinY↔thickY):                                  rho1d(|Yc-Yt|)        (w_y1d)
    % Each term can use a different loss (L2, L1, Huber). Tweak weights/deltas
    % to tune behavior and kill artifacts.
    %
    % Inputs (column vectors):
    %   X_thick_pos : N x 1 in [1..120]
    %   Y_thick_pos : N x 1 in [1..120]
    %   Xthin_base  : N x 1 in [1..24]
    %   Ythin_base  : N x 1 in [1..24]
    %
    wrapPeriod = 24;
    nWraps     = 5;             % 5 * 24 = 120

    % ---------- TUNABLE COST SETTINGS ----------
    % Weights (start with these; tweak as needed)
    w_tt2d    = 1.0;    % main thin↔thick (2D) term
    w_cross2d = 0.2;    % cross 2D consistency (same geometry as 2D, but separate weight)
    w_x1d     = 0.5;    % X-only consistency
    w_y1d     = 0.9;    % Y-only consistency

    % Loss choices: 'l2', 'l1', or 'huber'
    loss_tt2d    = 'huber';
    loss_cross2d = 'huber';
    loss_x1d     = 'huber';
    loss_y1d     = 'huber';

    % Robust deltas (in strip units). Make larger if you still see wrap-jumps.
    delta_2d_tt    = 1.8;
    delta_2d_cross = 1.2;
    delta_x1d      = 1.8;
    delta_y1d      = 1.5;
    % -------------------------------------------

    % Anonymous robust penalties
    huber = @(r,delta) (r<=delta).*0.5.*r.^2 + (r>delta).*(delta.*(r - 0.5*delta));
    rho1d = @(d,loss,delta) ...
        (strcmp(loss,'l2')    .* (0.5.*d.^2) + ...
        strcmp(loss,'l1')    .* (d) + ...
        strcmp(loss,'huber') .* huber(d,delta));
    rho2d = @(dx,dy,loss,delta) ...
        rho1d(sqrt(dx.^2 + dy.^2), loss, delta);   % reduce to 1D on the radius

    Xthin_base = X_thin_strip_bot;
    Ythin_base = Y_thin_strip_top;

    % Valid mask
    valid = isfinite(X_thick_pos) & isfinite(Y_thick_pos) & ...
            isfinite(Xthin_base)  & isfinite(Ythin_base);

    N  = numel(Xthin_base);
    X_thin_unwrapped = nan(N,1);
    Y_thin_unwrapped = nan(N,1);
    kx_out = nan(N,1);
    ky_out = nan(N,1);
    cmin   = nan(N,1);

    if any(valid)
        nv    = sum(valid);
        wraps = (0:nWraps-1) * wrapPeriod;          % 1 x nWraps

        % Candidate wrapped copies (nv x nWraps)
        Xc = Xthin_base(valid) + wraps;
        Yc = Ythin_base(valid) + wraps;

        Xt = X_thick_pos(valid);                    % nv x 1
        Yt = Y_thick_pos(valid);                    % nv x 1

        % Differences
        DX = Xc - Xt;                               % nv x nWraps   (depends on kx)
        DY = Yc - Yt;                               % nv x nWraps   (depends on ky)

        % Broadcast to nv x nWraps x nWraps
        DX3 = reshape(DX, nv, nWraps, 1);           % varies with kx
        DY3 = reshape(DY, nv, 1,      nWraps);      % varies with ky

        % ---- Composite cost over all (kx,ky) ----
        % 2D thin↔thick:
        C_tt2d    = rho2d(DX3, DY3, loss_tt2d,    delta_2d_tt);

        % 2D cross term (thinX vs thickY, thickX vs thinY): same geometry (ΔX,ΔY),
        % but its own weight/delta/loss lets you tune behavior independently.
        C_cross2d = rho2d(DX3, DY3, loss_cross2d, delta_2d_cross);

        % 1D X-only and Y-only terms (replicate along the "other" wrap dimension):
        C_x1d = rho1d(abs(DX3), loss_x1d, delta_x1d);    % |ΔX|
        C_y1d = rho1d(abs(DY3), loss_y1d, delta_y1d);    % |ΔY|

        % Weighted sum
        Cost = w_tt2d*C_tt2d + w_cross2d*C_cross2d + w_x1d*C_x1d + w_y1d*C_y1d;  % nv x nWraps x nWraps

        % Argmin over (kx, ky)
        [cmin_v, idxFlat] = min(reshape(Cost, nv, []), [], 2);   % nv x 1
        [kx, ky] = ind2sub([nWraps, nWraps], idxFlat);

        % Select winners
        selX = sub2ind([nv, nWraps], (1:nv)', kx);
        selY = sub2ind([nv, nWraps], (1:nv)', ky);

        Xsel = Xc(selX);
        Ysel = Yc(selY);

        % Write back (clamp for safety)
        totalRange = wrapPeriod * nWraps;           % 120
        X_thin_unwrapped(valid) = min(max(Xsel, 1), totalRange);
        Y_thin_unwrapped(valid) = min(max(Ysel, 1), totalRange);

        % Debug/diagnostics
        kx_out(valid) = kx;
        ky_out(valid) = ky;
        cmin(valid)   = cmin_v;
    end



    X_final = X_thin_unwrapped;
    Y_final = Y_thin_unwrapped;


    figure; scatter( (X_final(valid) / 120 - 0.5) * 300, ( Y_final(valid) / 120 - 0.5) * 300, 6, 'filled', 'MarkerFaceAlpha', 0.4);
    hold on;
    % for k = 1:nWraps
    %     xline((k-1)*wrapPeriod + 0.5, '-',  'LineWidth', 1);
    %     xline(k*wrapPeriod       + 0.5, '--', 'LineWidth', 1);
    %     yline((k-1)*wrapPeriod + 0.5, '--', 'LineWidth', 1);
    %     yline(k*wrapPeriod       + 0.5, '--', 'LineWidth', 1);
    % end
    plot([-150 -150], [150 150], '--', 'LineWidth', 1);
    xlim([-150 150]); ylim([-150 150]); grid on; box on; axis square;
    xlabel('X_{final} (1..120)'); ylabel('Y_{final} (1..120)');
    title('Disambiguated thin positions using thick constraints');

    % Add a rectangle
    base = 20;
    height = 80;
    center = [-80 -27];
    rectangle('Position',[center(1)-base/2, center(2)-height/2, base, height],'EdgeColor','r','LineWidth',2);



    % ===============================================================
    % Correlation: X_thin_BOT (unwrapped) vs X_thick
    % ===============================================================
    figure;
    % Histogram of Y_thick_strip, avoid zeroes
    subplot(2,2,1);
    histogram( X_thick_strip - 0.5, 0.5:1:5.5);
    xlabel('X_{thick} [strip]');
    ylabel('# of events');
    title('X_{thick} distribution');
    xlim([0.5 5.5]);
    grid on; box on;


    X_thin_strip_bot_real = X_thin_strip_bot + (X_thick_strip - 1)*wrapPeriod;

    % Histogram of Y_thin_strip_top (unwrapped) but the unwrapping does not use X_thick_strip,
    % I prefer that it simply creates the full posibilities which is Y_thin_strip_top + (1:5-1)*24
    subplot(2,2,3);
    histogram(X_thin_strip_bot + (0:nWraps-1)*wrapPeriod, 1:0.5:120); hold on;
    histogram(X_thin_strip_bot_real, 1:0.5:120);
    xlabel('X_{thin} (unwrapped) [ns]');
    ylabel('# of events');
    title('X_{thin} (unwrapped) distribution');
    xlim([1 120]);
    grid on; box on;


    % Y_thick_strip is a value in ns which goes from -1.5 to 1.5 ns, since the strips are 30 cm long
    % and the signal propagates at 2/3 the speed of light, so 30 cm / (c*2/3) = 1.5 ns.
    % At the same time, the Y_thin_strip_top is a value between 1 and 24, when it's wrapped,
    % but actually it is a value between 1 and 120. What I want is to histogram Y_thick_strip
    % and above it plot Y_thin_strip_top but uynwrapped, that is, Y_thin_strip_top + (X_thick_strip - 1)*24
    % to see if there is a correlation between Y_thin_strip_top unwrapped and Y_thick_strip

    % ===============================================================
    % Correlation: X_thin_TOP (unwrapped) vs Y_thick
    % ===============================================================

    % Histogram of Y_thick_strip, avoid zeroes
    subplot(2,2,2);
    histogram( ( Y_thick_strip(Y_thick_strip ~= 0) + 1.5 ) / 3 * 120 + 1, 1:0.5:120);
    xlabel('Y_{thick} [(Tfl - Tbl)/2] [AU]');
    ylabel('# of events');
    title('Y_{thick} distribution');
    % xlim([-1.5 1.5]);
    grid on; box on;


    % Only use nonzero Y_thick_strip values
    nonzero_idx = Y_thick_strip ~= 0;
    Y_thin_strip_top_sel = Y_thin_strip_top(nonzero_idx);      % [N x 1]
    Yvals = (Y_thick_strip(nonzero_idx) + 1.5)/3 * 120 + 1;   % [N x 1]

    % Expand Y_thin_strip_top_sel for all wrap possibilities [N x nWraps]
    Y_thin_strip_top_all = Y_thin_strip_top_sel + (0:nWraps-1)*wrapPeriod; % [N x nWraps]

    % Do a copy of Y vals to match dimensions [N x nWraps]
    % Yvals = repmat(Yvals, 1, nWraps); % [N x nWraps]

    % For each event, find the wrap that minimizes the distance to Yvals
    diffs = abs(Y_thin_strip_top_all - Yvals);
    [~, idx_min] = min(diffs, [], 2);

    % Select the best unwrapped Y_thin_strip_top for each event
    Y_thin_strip_top_real = Y_thin_strip_top_all(sub2ind(size(Y_thin_strip_top_all), (1:size(Y_thin_strip_top_all,1))', idx_min));

    % Histogram of Y_thin_strip_top (unwrapped) but the unwrapping does not use X_thick_strip,
    % I prefer that it simply creates the full posibilities which is Y_thin_strip_top + (1:5-1)*24
    subplot(2,2,4);
    histogram(Y_thin_strip_top + (0:nWraps-1)*wrapPeriod, 1:0.5:120); hold on;
    histogram(Y_thin_strip_top_real, 1:0.5:120);
    xlabel('X_{thin} (unwrapped) [ns]');
    ylabel('# of events');
    title('X_{thin} (unwrapped) distribution');
    xlim([1 120]);
    grid on; box on;
end


%%


% ---------------------------------------------------------------------
% ---------------------------------------------------------------------
% ---------------------------------------------------------------------
% Now let's calculate efficiencies
% ---------------------------------------------------------------------
% ---------------------------------------------------------------------
% ---------------------------------------------------------------------

% ---------------------------------------------------------------------
% ---------------------------------------------------------------------
% finas - narrow strips charge spectra and efficiency estimation
% ---------------------------------------------------------------------
% ---------------------------------------------------------------------

% one way to calculate the RPC efficiency: the PMTs fired but the RPC saw nothing, so the charge sum per event 
% (Q spectrum) should be very close to zero
% look at the top and bottom charge spectra and decide the threshold that means no charge or not seen (there
% is an initial peak); 600 is too low -> gives Eff=5% with HV=0 kV

% lower bound of the charge sum on the 24 strips; 700 or 800; for multiplicity use threshold = 100 because 
% it is a per-strip charge limit


% ---------------------------------------------------------------------
% ---------------------------------------------------------------------
% Combined PMT/RPC Efficiency Calculation
% ---------------------------------------------------------------------
% ---------------------------------------------------------------------

% I have some vectors with the same length, one vector per each detector
% - PMT 1 --> Qcint(:,1), Tl_cint(:,1)
% - PMT 2 --> Qcint(:,2), Tl_cint(:,2)
% - PMT 3 --> Qcint(:,3), Tl_cint(:,3)
% - PMT 4 --> Qcint(:,4), Tl_cint(:,4)
% - Thick RPC (sum of Qmax front/back) --> Q_thick_event
% - Thin RPC TOP (event sums) --> Q_thin_top_event
% - Thin RPC BOTTOM (event sums) --> Q_thin_bot_event

% Replace NaNs with 0 before mask calculations in all vectors
Q_pmt_1 = Qcint_good(:,1);
Q_pmt_2 = Qcint_good(:,2);
Q_pmt_3 = Qcint_good(:,3);
Q_pmt_4 = Qcint_good(:,4);
Q_thick = Q_thick_event_good;
Q_thin_top = Q_thin_top_event_good;
Q_thin_bot = Q_thin_bot_event_good;

% Plot Q_thick, Q_thin_top, Q_thin_bot histograms in ylog scale

Q_thick_streamer_threshold = 50; % ADCbins
Q_thin_top_streamer_threshold = 15000; % ADCbins
Q_thin_bot_streamer_threshold = 15000; % ADCbins

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

% percentage_streamer_pmt_top
% percentage_streamer_thin_top
% percentage_streamer_thick
% percentage_streamer_thin_bot
% percentage_streamer_pmt_bot

% Take only positive charges for the plots in a new vector that does not replace the original
Q_thick_plot = Q_thick(Q_thick > 0);
Q_thin_top_plot = Q_thin_top(Q_thin_top > 0);
Q_thin_bot_plot = Q_thin_bot(Q_thin_bot > 0);

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

sgtitle(sprintf('RPC Charge Spectra and cumulative distributions (data from %s)', formatted_datetime));


%%

% ---------------------------------------------------------------------
% EFFICIENCY
% ---------------------------------------------------------------------

fprintf("Calculating PMT charge thresholds for run 0 based on 20th and 80th percentiles.\n");
pmt_1_charge_threshold_min = prctile(Q_pmt_1(Q_pmt_1>0), percentile_pmt); % ADCbins
pmt_1_charge_threshold_max = prctile(Q_pmt_1(Q_pmt_1>0), 100 - percentile_pmt); % ADCbins
pmt_2_charge_threshold_min = prctile(Q_pmt_2(Q_pmt_2>0), percentile_pmt); % ADCbins
pmt_2_charge_threshold_max = prctile(Q_pmt_2(Q_pmt_2>0), 100 - percentile_pmt); % ADCbins
pmt_3_charge_threshold_min = prctile(Q_pmt_3(Q_pmt_3>0), percentile_pmt); % ADCbins
pmt_3_charge_threshold_max = prctile(Q_pmt_3(Q_pmt_3>0), 100 - percentile_pmt); % ADCbins
pmt_4_charge_threshold_min = prctile(Q_pmt_4(Q_pmt_4>0), percentile_pmt); % ADCbins
pmt_4_charge_threshold_max = prctile(Q_pmt_4(Q_pmt_4>0), 100 - percentile_pmt); % ADCbins

% Thick RPC (sum of Qmax front/back)
fprintf("Calculating Thick RPC charge thresholds for run 0 based on %dth and %dth percentiles.\n", percentile_thick, 100 - percentile_thick);
thick_strip_charge_threshold_min = prctile(Q_thick(Q_thick>0), percentile_thick);  % ADCbins
thick_strip_charge_threshold_max = prctile(Q_thick(Q_thick>0), 100 - percentile_thick);  % ADCbins

% Thin RPC (event sums)
top_narrow_strip_charge_threshold_min = prctile(Q_thin_top(Q_thin_top>0), percentile_narrow);  % ADCbins/event
top_narrow_strip_charge_threshold_max = prctile(Q_thin_top(Q_thin_top>0), 100 - percentile_narrow);  % ADCbins/event
bot_narrow_strip_charge_threshold_min = prctile(Q_thin_bot(Q_thin_bot>0), percentile_narrow);  % ADCbins/event
bot_narrow_strip_charge_threshold_max = prctile(Q_thin_bot(Q_thin_bot>0), 100 - percentile_narrow);  % ADCbins/event



validEventsFiltered_PMT = ...
    (Q_pmt_1 >= pmt_1_charge_threshold_min) & (Q_pmt_1 <= pmt_1_charge_threshold_max) & ...
    (Q_pmt_2 >= pmt_2_charge_threshold_min) & (Q_pmt_2 <= pmt_2_charge_threshold_max) & ...
    (Q_pmt_3 >= pmt_3_charge_threshold_min) & (Q_pmt_3 <= pmt_3_charge_threshold_max) & ...
    (Q_pmt_4 >= pmt_4_charge_threshold_min) & (Q_pmt_4 <= pmt_4_charge_threshold_max);
% validEventsFiltered_thick = ...
%     (Q_thick >= thick_strip_charge_threshold_min) & (Q_thick <= thick_strip_charge_threshold_max);
% validEventsFiltered_thin_top = ...
%     (Q_thin_top >= top_narrow_strip_charge_threshold_min) & (Q_thin_top <= top_narrow_strip_charge_threshold_max);
% validEventsFiltered_thin_bot = ...
%     (Q_thin_bot >= bot_narrow_strip_charge_threshold_min) & (Q_thin_bot <= bot_narrow_strip_charge_threshold_max);


% validEventsFiltered_thick, validEventsFiltered_thin_top, validEventsFiltered_thin_bot are all trues
% validEventsFiltered_thick = true(size(Q_thick));
% validEventsFiltered_thin_top = true(size(Q_thin_top));
% validEventsFiltered_thin_bot = true(size(Q_thin_bot));

validEventsFiltered_thick = validEventsFiltered_PMT; % Use the same mask as PMTs
validEventsFiltered_thin_top = validEventsFiltered_PMT; % Use the same mask as PMTs
validEventsFiltered_thin_bot = validEventsFiltered_PMT; % Use the same mask as PMTs


% ========== VALID FILTERED EVENTS (zero-out everything else) ==========

% --- PMTs (mask: validEventsFiltered_PMT) ---
Qcint_range = zeros(size(Qcint_good), 'like', Qcint_good);
Qcint_range(validEventsFiltered_PMT, :) = Qcint_good(validEventsFiltered_PMT, :);

% --- THICK STRIPS (mask: validEventsFiltered_thick) ---
X_thick_strip_range = zeros(size(X_thick_strip_good), 'like', X_thick_strip_good);
Y_thick_strip_range = zeros(size(Y_thick_strip_good), 'like', Y_thick_strip_good);
T_thick_strip_range = zeros(size(T_thick_strip_good), 'like', T_thick_strip_good);

X_thick_strip_range(validEventsFiltered_thick, :) = X_thick_strip_good(validEventsFiltered_thick, :);
Y_thick_strip_range(validEventsFiltered_thick, :) = Y_thick_strip_good(validEventsFiltered_thick, :);
T_thick_strip_range(validEventsFiltered_thick, :) = T_thick_strip_good(validEventsFiltered_thick, :);

Q_thick_event_range = zeros(size(Q_thick_event_good), 'like', Q_thick_event_good);
Q_thick_event_range(validEventsFiltered_thick) = Q_thick_event_good(validEventsFiltered_thick);

% --- THIN STRIPS (masks: validEventsFiltered_thin_bot / validEventsFiltered_thin_top) ---
Qb_range = zeros(size(Qb_good), 'like', Qb_good);
Qt_range = zeros(size(Qt_good), 'like', Qt_good);

Qb_range(validEventsFiltered_thin_bot, :) = Qb_good(validEventsFiltered_thin_bot, :);
Qt_range(validEventsFiltered_thin_top, :) = Qt_good(validEventsFiltered_thin_top, :);

% Totals per event (length preserved; zero for non-selected rows)
Q_thin_top_event_range = sum(Qt_range, 2);
Q_thin_bot_event_range = sum(Qb_range, 2);



% Calculate efficiency using different types of masks.

% Assumes you already defined:
% Q_pmt_1..4, Q_thick, Q_thin_top, Q_thin_bot (NaNs->0 already done above)
% and the threshold variables:
% pmt_1_charge_threshold_min/max, ... , pmt_4_charge_threshold_min/max,
% thick_strip_charge_threshold_min/max,
% top_narrow_strip_charge_threshold_min/max,
% bot_narrow_strip_charge_threshold_min/max

% Package data + limits
detNames = { ...
    'PMT 1 (Qcint(:,1))', ...
    'PMT 2 (Qcint(:,2))', ...
    'PMT 3 (Qcint(:,3))', ...
    'PMT 4 (Qcint(:,4))', ...
    'Thick RPC (Q_{thick\_event})', ...
    'Thin TOP (Q_{thin\_top\_event})', ...
    'Thin BOTTOM (Q_{thin\_bot\_event})'};

detData  = {Q_pmt_1, Q_pmt_2, Q_pmt_3, Q_pmt_4, Q_thick, Q_thin_top, Q_thin_bot};

minVals  = [ ...
    pmt_1_charge_threshold_min, ...
    pmt_2_charge_threshold_min, ...
    pmt_3_charge_threshold_min, ...
    pmt_4_charge_threshold_min, ...
    thick_strip_charge_threshold_min, ...
    top_narrow_strip_charge_threshold_min, ...
    bot_narrow_strip_charge_threshold_min ];

maxVals  = [ ...
    pmt_1_charge_threshold_max, ...
    pmt_2_charge_threshold_max, ...
    pmt_3_charge_threshold_max, ...
    pmt_4_charge_threshold_max, ...
    thick_strip_charge_threshold_max, ...
    top_narrow_strip_charge_threshold_max, ...
    bot_narrow_strip_charge_threshold_max ];


nBins = 150;  % histogram resolution

% ========= 2x2: PMTs (zeros excluded) =========
figure('Name','PMT charges (zeros excluded)');
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');

for k = 1:4
    x = detData{k};
    % keep finite & nonzero values only
    x = x(isfinite(x) & x ~= 0);

    nexttile;

    if isempty(x)
        axis off;
        title(detNames{k}, 'Interpreter','tex');
        text(0.5,0.5,'No data (after removing zeros)','HorizontalAlignment','center');
        continue;
    end

    xmin = min(x); xmax = max(x);
    if xmin == xmax, xmax = xmin + 1; end
    edges = linspace(xmin, xmax, nBins+1);

    inMin = minVals(k); inMax = maxVals(k);
    xin = x((x >= inMin) & (x <= inMax));

    hold on;
    hAll = histogram(x,   'BinEdges', edges, 'DisplayStyle','bar', 'EdgeAlpha',0.4, 'FaceAlpha',0.35);
    if ~isempty(xin)
        hIn  = histogram(xin, 'BinEdges', edges, 'DisplayStyle','bar', 'EdgeAlpha',0.9, 'FaceAlpha',0.8);
    else
        hIn = [];
    end

    xlabel('ADC bins'); ylabel('Counts');
    title(detNames{k}, 'Interpreter','tex');

    yL = ylim;
    plot([inMin inMin], yL, '--', 'LineWidth',1);
    plot([inMax inMax], yL, '--', 'LineWidth',1);
    ylim(yL);

    if isempty(hIn)
        legend(hAll, {'All events (\neq 0)'}, 'Location','best');
    else
        legend([hAll hIn], {'All events (\neq 0)', sprintf('In range [%g, %g]', inMin, inMax)}, 'Location','best');
    end
    box on;
end

sgtitle(sprintf('PMT charge distributions (zeros excluded) (data from %s)', formatted_datetime));


% ========= 1x3: RPCs (Thick, Thin TOP, Thin BOTTOM; zeros excluded) =========
figure('Name','RPC charges (zeros excluded)');
tiledlayout(1,3,'TileSpacing','compact','Padding','compact');

for k = 5:7
    x = detData{k};
    % keep finite & nonzero values only
    x = x(isfinite(x) & x ~= 0);

    nexttile;

    if isempty(x)
        axis off;
        title(detNames{k}, 'Interpreter','tex');
        text(0.5,0.5,'No data (after removing zeros)','HorizontalAlignment','center');
        continue;
    end

    xmin = min(x); xmax = max(x);
    if xmin == xmax, xmax = xmin + 1; end
    edges = linspace(xmin, xmax, nBins+1);

    inMin = minVals(k); inMax = maxVals(k);
    xin = x((x >= inMin) & (x <= inMax));

    hold on;
    hAll = histogram(x,   'BinEdges', edges, 'DisplayStyle','bar', 'EdgeAlpha',0.4, 'FaceAlpha',0.35);
    if ~isempty(xin)
        hIn  = histogram(xin, 'BinEdges', edges, 'DisplayStyle','bar', 'EdgeAlpha',0.9, 'FaceAlpha',0.8);
    else
        hIn = [];
    end

    % log scale in Y
    set(gca, 'YScale', 'log');

    xlabel('ADC bins'); ylabel('Counts');
    title(detNames{k}, 'Interpreter','tex');

    yL = ylim;
    plot([inMin inMin], yL, '--', 'LineWidth',1);
    plot([inMax inMax], yL, '--', 'LineWidth',1);
    ylim(yL);

    if isempty(hIn)
        legend(hAll, {'All events (\neq 0)'}, 'Location','best');
    else
        legend([hAll hIn], {'All events (\neq 0)', sprintf('In range [%g, %g]', inMin, inMax)}, 'Location','best');
    end
    box on;
end

sgtitle(sprintf('RPC charge distributions (zeros excluded) (data from %s)', formatted_datetime));



%%


variantSpecs = struct( ...
    'label', {'signal', 'coin', 'good', 'range'}, ...
    'Qcint', {Qcint_signal, Qcint_coin, Qcint_good, Qcint_range}, ...
    'Q_thick', {Q_thick_event_signal, Q_thick_event_coin, Q_thick_event_good, Q_thick_event_range}, ...
    'Q_thin_top',{Q_thin_top_event_signal, Q_thin_top_event_coin, Q_thin_top_event_good, Q_thin_top_event_range}, ...
    'Q_thin_bot',{Q_thin_bot_event_signal, Q_thin_bot_event_coin, Q_thin_bot_event_good, Q_thin_bot_event_range} );

thin_top_threshold = top_narrow_strip_charge_threshold_min;
thin_bot_threshold = bot_narrow_strip_charge_threshold_min;
thick_threshold   = thick_strip_charge_threshold_min;

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
variantOrder = {'signal', 'coin', 'good', 'range'};

% Helpers: fetch efficiency and uncertainty by label
getEff = @(lab, field) accum(strcmp({accum.label}, lab)).(field);
getUnc = @(lab, field) accum(strcmp({accum.label}, lab)).(strrep(field,'eff_','unc_'));

% Build detector rows in required order
detectors = { ...
    'PMT_top',         'eff_pmt_top',  percentage_streamer_pmt_top;  ...
    'RPC_thin_top',    'eff_thin_top', percentage_streamer_thin_top; ...
    'RPC_thick_center','eff_thick',    percentage_streamer_thick;    ...
    'RPC_thin_bottom', 'eff_thin_bot', percentage_streamer_thin_bot; ...
    'PMT_bottom',      'eff_pmt_bot',  percentage_streamer_pmt_bot   ...
};

% Interleaved columns: [Detector] [OG, OG_unc] [valid_OG, valid_OG_unc] [valid, valid_unc] [range, range_unc] [StreamerPct]
nDet = size(detectors,1);
nVar = numel(variantOrder);
detRows = cell(nDet, 1 + 2*nVar + 1);

for i = 1:nDet
    detName   = detectors{i,1};
    effField  = detectors{i,2};
    streamerP = detectors{i,3};

    detRows{i,1} = detName;
    col = 2;
    for c = 1:nVar
        lab = variantOrder{c};
        detRows{i,col}   = getEff(lab, effField); col = col + 1;
        detRows{i,col}   = getUnc(lab, effField); col = col + 1;
    end
    detRows{i, 1 + 2*nVar + 1} = streamerP;  % StreamerPct
end

% Build variable names interleaving efficiency and its uncertainty
varNames = {'Detector'};
for c = 1:nVar
    varNames{end+1} = variantOrder{c};
    varNames{end+1} = [variantOrder{c} '_unc'];
end
varNames{end+1} = 'StreamerPct';

detTable = cell2table(detRows, 'VariableNames', varNames);

% Round to 1 decimal place
for c = 1:nVar
    detTable{:, 1 + 2*(c-1) + 1} = round(detTable{:, 1 + 2*(c-1) + 1}, 1);
    detTable{:, 1 + 2*(c-1) + 2} = round(detTable{:, 1 + 2*(c-1) + 2}, 1);
end
detTable.StreamerPct = round(detTable.StreamerPct, 1);

% Pretty print
fprintf('\n==== Efficiency Summary (values in %%) ====\n');

% Header
fprintf('%-17s', 'Detector');
for c = 1:nVar
    fprintf(' %12s %12s', varNames{1 + 2*(c-1) + 1}, varNames{1 + 2*(c-1) + 2});
end
fprintf(' | %12s\n', 'StreamerPct');

% Separator
sepLen = 17 + (12+1)*2*nVar + 3 + 12;
fprintf('%s\n', repmat('-',1, max(86, sepLen)));

% Rows
for i = 1:size(detTable,1)
    fprintf('%-17s', detTable.Detector{i});
    for c = 1:nVar
        effVal = detTable{ i, 1 + 2*(c-1) + 1 };
        uncVal = detTable{ i, 1 + 2*(c-1) + 2 };
        fprintf(' %12.1f %12.1f', effVal, uncVal);
    end
    fprintf(' | %11.1f%%\n', detTable.StreamerPct(i));
end
fprintf('%s\n', repmat('=',1, max(86, sepLen)));

% CSV output
outCsv = fullfile(summary_output_dir, ...
    sprintf('efficiency_summary_%s_exec_%s.csv', formatted_datetime, execution_datetime));

fid = fopen(outCsv, 'w');
% Update header comment with new column ordering
fprintf(fid, '# total_raw_events: %d\n', total_raw_events);
fprintf(fid, '# percentage_good_events_in_pmts: %.4f\n', percentage_good_events_in_pmts);
fprintf(fid, '%s\n', strjoin(varNames, ', '));
fclose(fid);

writetable(detTable, outCsv, 'WriteMode','append');

%%


% -------------------------------------------------------------------------
% -------------------------------------------------------------------------
% -------------------------------------------------------------------------
% -------------------------------------------------------------------------
% -------------------------------------------------------------------------

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

function cleanup_temp_directory(tempDir)
    if exist(tempDir, 'dir')
        try
            rmdir(tempDir, 's');
        catch cleanupErr
            warning('Failed to remove temporary directory %s: %s', tempDir, cleanupErr.message);
        end
    end
end


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
