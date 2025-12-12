% Caye Stage 7 NaN Diagnostics
% Based on caye_edits_minimal.m header flow, but focuses on NaN analysis only.

%
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

log_info = @(fmt, varargin) fprintf('[INFO] %s\n', sprintf(fmt, varargin{:}));
if debug_mode
    log_debug = @(fmt, varargin) fprintf('[DEBUG] %s\n', sprintf(fmt, varargin{:}));
else
    log_debug = @(varargin) [];
end
log_banner = @(fmt, varargin) fprintf('\n=== %s ===\n', sprintf(fmt, varargin{:}));

log_banner('Starting caye_nan_diagnostics');
if debug_mode
    log_info('Debug logging enabled.');
end

% ---------------------------------------------------------------------
% Workspace preparation and directory layout (mirrors main script)
% ---------------------------------------------------------------------

should_plot = ~no_plot_flag; %#ok<NASGU> % Kept for parity with main script

project_root = '/home/csoneira/WORK/LIP_stuff/JOAO_SETUP';
outputs7_root = fullfile(project_root, 'STAGES', 'STAGE_7', 'DATA', 'DATA_FILES', 'OUTPUTS_7');
save_plots_dir_default = fullfile(outputs7_root, 'PDF'); %#ok<NASGU>
summary_output_dir = fullfile(outputs7_root, 'TABLES');
nan_reports_dir = fullfile(summary_output_dir, 'NAN_DIAGNOSTICS');
if ~exist(outputs7_root, 'dir'); mkdir(outputs7_root); end
if ~exist(summary_output_dir, 'dir'); mkdir(summary_output_dir); end
if ~exist(nan_reports_dir, 'dir'); mkdir(nan_reports_dir); end
if ~exist(fullfile(outputs7_root, 'PDF'), 'dir'); mkdir(fullfile(outputs7_root, 'PDF')); end
if ~exist(fullfile(outputs7_root, 'CHARGES'), 'dir'); mkdir(fullfile(outputs7_root, 'CHARGES')); end

if ~exist('save_plots','var')
    save_plots = true;
end
if ~exist('save_plots_dir','var') || isempty(save_plots_dir)
    save_plots_dir = nan_reports_dir;
end

path(path,'/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/STORED_NOT_ESSENTIAL/util_matPlots'); %#ok<MCAP>

% Tidy up any prior state while preserving configuration handles
clearvars -except cli_args no_plot_flag debug_flag debug_mode log_info log_debug log_banner ...
    should_plot project_root outputs7_root summary_output_dir nan_reports_dir save_plots save_plots_dir;
close all; clc;

% ---------------------------------------------------------------------
% Run/test setup (mirrors caye_edits_minimal defaults)
% ---------------------------------------------------------------------

parsed_cli = parse_nan_cli_options(cli_args);

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

if ~exist('input_dir','var')
    input_dir = '';
end

if parsed_cli.has_run_override
    run = parsed_cli.run_override;
    test = true;
end

if parsed_cli.has_input_dir
    input_dir = parsed_cli.input_dir;
    test = false;
end

if parsed_cli.has_limit_override
    limit = true;
    limit_number_of_events = parsed_cli.limit_override;
else
    limit = true;
    limit_number_of_events = 5000;
end %#ok<NASGU>

position_from_narrow_strips = false; %#ok<NASGU>

HOME    = '/home/csoneira/WORK/LIP_stuff/'; %#ok<NASGU>
DATA    = 'matFiles/time/'; %#ok<NASGU>
DATA_Q  = 'matFiles/charge/'; %#ok<NASGU>

mst_saves_root = fullfile(project_root, 'STAGES', 'STAGE_6', 'DATA', 'DATA_FILES', 'JOINED');
unpacked_root = fullfile(project_root, 'STAGES', 'STAGE_6', 'DATA', 'DATA_FILES', 'JOINED');

formatted_datetime = datestr(now, 'yyyy-mm-dd_HH.MM.SS'); %#ok<NASGU>
execution_datetime = datestr(now, 'yyyy_mm_dd-HH.MM.SS'); %#ok<NASGU>

% ---------------------------------------------------------------------
% Resolve input directories (copied from main script logic)
% ---------------------------------------------------------------------

if test
    switch run
        case 1
            input_dir = 'dabc25120133744-dabc25126121423_JOANA_RUN_1_2025-10-08_15h05m00s';
            data_dir = fullfile(project_root, 'STAGES', 'STAGE_5', 'DATA', 'DATA_FILES', 'ANCILLARY', 'RUN_1');
        case 2
            input_dir = 'dabc25127151027-dabc25147011139_JOANA_RUN_2_2025-10-08_15h05m00s';
            data_dir = fullfile(project_root, 'STAGES', 'STAGE_5', 'DATA', 'DATA_FILES', 'ANCILLARY', 'RUN_2');
        case 3
            input_dir = 'dabc25127151027-dabc25160092400_JOANA_RUN_3_2025-10-08_15h05m00s';
            data_dir = fullfile(project_root, 'STAGES', 'STAGE_5', 'DATA', 'DATA_FILES', 'ANCILLARY', 'RUN_3');
        case 4
            input_dir = 'dabc25282152204_RUN_4_2025-10-20_16h00m00s';
            data_dir = fullfile(project_root, 'STAGES', 'STAGE_5', 'DATA', 'DATA_FILES', 'ALL_UNPACKED', input_dir);
        case 5
            input_dir = 'dabc25291140248_RUN_5_2025-10-20_16h00m00s';
            data_dir = fullfile(project_root, 'STAGES', 'STAGE_5', 'DATA', 'DATA_FILES', 'ALL_UNPACKED', input_dir);
        otherwise
            error('For test mode, set run to 1, 2, 3, 4, or 5.');
    end
    data_dir = char(data_dir);
else
    if isempty(input_dir)
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
    end
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

log_info('NaN diagnostics for run %d using input directory "%s".', run, input_dir);
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

log_info('Loading MAT files for dataset "%s".', dataset_basename);

time_files = dir(fullfile(time_dir, sprintf('%s*_T.mat', dataset_basename)));
if isempty(time_files)
    error('No time MAT files found matching "%s*_T.mat" in %s', dataset_basename, time_dir);
end
log_info('Loading %d time file(s) from %s', numel(time_files), time_dir);
for i = 1:numel(time_files)
    time_file_path = fullfile(time_dir, time_files(i).name);
    log_debug('Loading time file: %s', time_file_path);
    load(time_file_path);
end

charge_files_listing = dir(fullfile(charge_dir, sprintf('%s*_a*_Q.mat', dataset_basename)));
if isempty(charge_files_listing)
    error('No charge MAT files found matching "%s_a*_Q.mat" in %s', dataset_basename, charge_dir);
end
charge_files = sort({charge_files_listing.name});
log_info('Loading %d charge file(s) from %s', numel(charge_files), charge_dir);
for idx = 1:numel(charge_files)
    charge_path = fullfile(charge_dir, charge_files{idx});
    log_debug('Loading charge data: %s', charge_path);
    load(charge_path);
end

log_info('Loaded variables. Beginning NaN diagnostics analysis.');

vars = evalin('base', 'whos');
nan_analysis_cfg = struct( ...
    'maxSampleIndices', 10, ...
    'maxLoggedVariables', 15, ...
    'debugMode', debug_mode);

nan_report = analyze_nan_workspace(vars, nan_analysis_cfg, log_info, log_debug);

category_specs = define_nan_categories();
[column_stats, column_table] = build_nan_column_stats(vars, nan_report);
[column_stats, category_summary, category_summary_table, column_table] = summarize_nan_categories(column_stats, column_table, category_specs, log_info);

nan_report.column_stats = column_stats;
nan_report.column_table = column_table;
nan_report.category_summary = category_summary;
nan_report.category_summary_table = category_summary_table;
nan_report.category_specs = category_specs;

nan_category_summary_filename = sprintf('nan_categories_%s_run%d.csv', dataset_basename, run);
nan_category_summary_path = fullfile(nan_reports_dir, nan_category_summary_filename);
if ~isempty(category_summary_table)
    writetable(category_summary_table, nan_category_summary_path);
    log_info('Wrote NaN category summary to %s', nan_category_summary_path);
end

nan_column_summary_filename = sprintf('nan_columns_%s_run%d.csv', dataset_basename, run);
nan_column_summary_path = fullfile(nan_reports_dir, nan_column_summary_filename);
if ~isempty(column_table)
    writetable(column_table, nan_column_summary_path);
    log_info('Wrote NaN per-column detail to %s', nan_column_summary_path);
end

figure_paths = struct();
if should_plot && save_plots
    figure_paths = generate_nan_figures(column_stats, dataset_basename, run, save_plots_dir, log_info, log_debug);
else
    if ~should_plot
        log_info('Plot generation disabled by no-plot flag; skipping NaN diagnostic figures.');
    elseif ~save_plots
        log_info('save_plots set to false; skipping NaN diagnostic figures.');
    end
end
nan_report.figure_paths = figure_paths;

summary_filename = sprintf('nan_summary_%s_run%d.csv', dataset_basename, run);
summary_path = fullfile(nan_reports_dir, summary_filename);
if ~isempty(nan_report.summary_table)
    writetable(nan_report.summary_table, summary_path);
    log_info('Wrote NaN summary table to %s', summary_path);
else
    log_info('No numeric variables found for NaN summary export.');
end

charge_summary_filename = sprintf('nan_summary_charges_%s_run%d.csv', dataset_basename, run);
charge_summary_path = fullfile(nan_reports_dir, charge_summary_filename);
if ~isempty(nan_report.charge_summary_table)
    writetable(nan_report.charge_summary_table, charge_summary_path);
    log_info('Wrote NaN charge summary table to %s', charge_summary_path);
end

report_mat_filename = sprintf('nan_report_%s_run%d.mat', dataset_basename, run);
report_mat_path = fullfile(nan_reports_dir, report_mat_filename);
save(report_mat_path, 'nan_report', '-v7.3');
log_info('Persisted full NaN diagnostics report to %s', report_mat_path);

log_banner('NaN diagnostics complete');



% ---------------------------------------------------------------------
% NaN scrubber + NaN% summary + overlaid barplot with event filter
% ---------------------------------------------------------------------

ws   = 'base';                     % workspace to operate on
vars = evalin(ws, 'whos');         % list all variables

replaced_names   = {};
nan_counts       = [];   % original NaN counts
tot_counts       = [];   % original total element counts
pct_nans         = [];   % original %NaNs

% We'll also compute %NaNs AFTER filtering out "events" flagged by l*/t* rule
pct_nans_filtered = NaN(0,1);  % filled later per var (if compatible with row-filter)

skipped_names = {};
skipped_types = {};

% ---- Build the “event-removal” mask using your rule on l9..l12, t9..t12 ----
% Fetch originals (without altering the workspace yet)
need = {'l9','l10','l11','l12','t9','t10','t11','t12'};
present = true(size(need));
vals = cell(size(need));
for i = 1:numel(need)
    if evalin(ws, sprintf('exist(''%s'',''var'')', need{i}))
        vals{i} = evalin(ws, need{i});
    else
        present(i) = false;
        vals{i} = [];
    end
end

% Default: no filtering if required vectors are missing or sizes inconsistent
event_mask_bad = [];
can_filter = all(present);

if can_filter
    % Basic sanity: all are vectors of the same length along the first dim
    lens = cellfun(@(x) size(x,1), vals);
    if ~all(lens == lens(1))
        can_filter = false;
    else
        N = lens(1);

        % Replace NaNs by 0 ONLY in temporary copies for mask construction
        L9  = vals{1}; L9(isnan(L9)) = 0;
        L10 = vals{2}; L10(isnan(L10)) = 0;
        L11 = vals{3}; L11(isnan(L11)) = 0;
        L12 = vals{4}; L12(isnan(L12)) = 0;

        T9  = vals{5}; T9(isnan(T9)) = 0;
        T10 = vals{6}; T10(isnan(T10)) = 0;
        T11 = vals{7}; T11(isnan(T11)) = 0;
        T12 = vals{8}; T12(isnan(T12)) = 0;

        % Differences
        q9  = T9  - L9;
        q10 = T10 - L10;
        q11 = T11 - L11;
        q12 = T12 - L12;

        % Events to REMOVE: any qk ~= 0 (interpreting your "…and then put to 0 if qk ~= 0")
        % If you intended a tolerance, change to |qk| > tol
        event_mask_bad = (q9 == 0) | (q10 == 0) | (q11 == 0) | (q12 == 0);

        % (Optional) If you literally want to set those L/T entries to 0 in-base, uncomment:
        % for idx = 1:numel(need)
        %     v = evalin(ws, need{idx});
        %     v(event_mask_bad) = 0;
        %     assignin(ws, need{idx}, v);
        % end
    end
end

log_info('Scanning %d workspace variable(s) for NaNs', numel(vars));

% We'll also store per-var filtered % if we can apply the row-mask cleanly
filtered_names = {};

for k = 1:numel(vars)
    name = vars(k).name;
    cls  = vars(k).class;

    % Fetch value safely from the target workspace
    val = evalin(ws, name);

    if isfloat(val)   % double/single (incl. complex/sparse)
        mask = isnan(val);
        nans = nnz(mask);
        total = numel(val);

        % Save original stats (BEFORE mutation)
        replaced_names{end+1,1} = name; %#ok<AGROW>
        nan_counts(end+1,1)     = nans; %#ok<AGROW>
        tot_counts(end+1,1)     = total; %#ok<AGROW>
        pct_nans(end+1,1)       = 100 * (nans / max(total,1)); %#ok<AGROW>

        % Compute filtered %NaNs if applicable:
        % Only do this if we have a valid event_mask_bad and the variable
        % has the same number of rows as the l*/t* vectors so we can "remove events"
        if ~isempty(event_mask_bad)
            % Try to interpret "events" as rows along first dimension
            if size(val,1) == numel(event_mask_bad)
                keep = ~event_mask_bad;
                % Index along first dimension; retain shape in other dims
                slicer = repmat({':'}, 1, ndims(val));
                slicer{1} = keep;
                val_kept = val(slicer{:});
                nans_kept  = nnz(isnan(val_kept));
                total_kept = numel(val_kept);
                pct_nans_filtered(end+1,1) = 100 * (nans_kept / max(total_kept,1));
                filtered_names{end+1,1}    = name; %#ok<AGROW>
            else
                % not compatible -> mark NaN (no filtered value)
                pct_nans_filtered(end+1,1) = NaN; %#ok<AGROW>
                filtered_names{end+1,1}    = name; %#ok<AGROW>
            end
        end

        % Now perform the replacement (mutate workspace): NaNs -> 0
        if nans > 0
            val(mask) = 0;
            assignin(ws, name, val);
        end

    else
        skipped_names{end+1,1} = name;  %#ok<AGROW>
        skipped_types{end+1,1} = cls;   %#ok<AGROW>
    end
end

% Build table and save to base workspace
nan_summary = table( ...
    string(replaced_names), ...
    nan_counts, ...
    tot_counts, ...
    pct_nans, ...
    'VariableNames', {'Variable','NaN_Count','Total_Elements','Pct_NaNs_Original'});

% Attach filtered percentages if we computed them (align names)
if ~isempty(filtered_names)
    % Ensure same order; fill with NaN if mismatch
    pct_after = NaN(height(nan_summary),1);
    [tf,loc] = ismember(nan_summary.Variable, string(filtered_names));
    pct_after(tf) = pct_nans_filtered(loc(tf));
    nan_summary.Pct_NaNs_AfterFilter = pct_after;
end

assignin(ws, 'nan_summary', nan_summary);

% ------------- Summary log -------------
total_nans = sum(nan_counts);
log_debug('NaN replacement summary | float vars=%d | total replaced=%d | skipped=%d', ...
    numel(nan_counts), total_nans, numel(skipped_names));

% ------------- Plot -------------
% Grouped bar: blue = original %NaNs, orange = after-filter %NaNs
figure('Name','%NaNs per variable (original vs. after event filter)','Color','k');
hold on;
xnames = nan_summary.Variable;
y1 = nan_summary.Pct_NaNs_Original;
if ismember('Pct_NaNs_AfterFilter', nan_summary.Properties.VariableNames)
    y2 = nan_summary.Pct_NaNs_AfterFilter;
    Y  = [y1, y2];
    hb = bar(categorical(xnames), Y, 'grouped'); % default color + second (we'll recolor)
    % Set second series to orange
    if numel(hb) >= 2
        hb(2).FaceColor = [1.0, 0.5, 0.0];  % orange
    end
    legend({'Original','After event filter'}, 'Location','bestoutside');
else
    bar(categorical(xnames), y1);
    legend({'Original'}, 'Location','bestoutside');
end
ylabel('NaNs (%)');
title('% of NaNs by variable');
xtickangle(90);
grid on; box on;
hold off;

% ------------- Notes -------------
% - "After event filter" removes rows where ANY(q9,q10,q11,q12) ~= 0,
%   with qk = tk - lk computed after NaNs in l*/t* are replaced by 0 (temporary).
% - If you want a tolerance around zero, replace (qk ~= 0) with (abs(qk) > tol).
% - The script does NOT permanently zero out l*/t* entries for flagged rows.
%   Uncomment the optional block above if you really want that side effect.




%% Helper functions ----------------------------------------------------

function specs = define_nan_categories()
    specs = struct( ...
        'name', {'PMTs', 'Wide Strips', 'Thin Strips Top', 'Thin Strips Bottom'}, ...
        'patterns', {{'(?i)pmt', '(?i)cint'}, {'(?i)wide', '(?i)thick', '(?i)^(tf|tb)'}, ...
            {'(?i)thin.*top', '(?i)Qt', '(?i)_top'}, {'(?i)thin.*bot', '(?i)Qb', '(?i)_bot'}}, ...
        'expected', {8, 20, 48, 48});
end

function [column_stats, column_table] = build_nan_column_stats(vars, nan_report)
    ws = 'base';
    column_stats = struct('base_name', {}, 'display_name', {}, 'column_index', {}, ...
        'num_elements', {}, 'nan_count', {}, 'nan_fraction_pct', {}, 'nan_indices', {});

    for k = 1:numel(vars)
        name = vars(k).name;
        val = evalin(ws, name);

        if isempty(val) || ~(isnumeric(val) || islogical(val))
            continue;
        end

        if isfield(nan_report.nan_masks, name)
            mask = nan_report.nan_masks.(name);
        else
            mask = isnan(val);
        end

        if isvector(val)
            mask_vec = mask(:);
            nan_count = nnz(mask_vec);
            total = numel(mask_vec);
            column_stats(end+1) = struct( ... %#ok<AGROW>
                'base_name', name, ...
                'display_name', name, ...
                'column_index', 1, ...
                'num_elements', total, ...
                'nan_count', nan_count, ...
                'nan_fraction_pct', 100 * nan_count / max(1, total), ...
                'nan_indices', find(mask_vec));
        elseif isnumeric(val) && ndims(val) == 2
            if size(mask,1) ~= size(val,1) || size(mask,2) ~= size(val,2)
                continue;
            end
            for col = 1:size(val, 2)
                mask_col = mask(:, col);
                nan_count = nnz(mask_col);
                total = numel(mask_col);
                column_stats(end+1) = struct( ... %#ok<AGROW>
                    'base_name', name, ...
                    'display_name', sprintf('%s(:,%d)', name, col), ...
                    'column_index', col, ...
                    'num_elements', total, ...
                    'nan_count', nan_count, ...
                    'nan_fraction_pct', 100 * nan_count / max(1, total), ...
                    'nan_indices', find(mask_col));
            end
        end
    end

    if isempty(column_stats)
        column_table = table();
    else
        column_table = struct2table(column_stats);
    end
end

function [column_stats, category_summary, category_summary_table, column_table] = summarize_nan_categories(column_stats, column_table, category_specs, log_info)
    if isempty(column_stats)
        category_summary = struct('name', {}, 'variable_count', {}, 'expected', {}, 'mean_nan_pct', {}, ...
            'median_nan_pct', {}, 'max_nan_pct', {}, 'max_nan_variable', {}, 'total_nan_count', {}, 'total_elements', {});
        category_summary_table = table();
        if isempty(column_table)
            column_table = table();
        end
        return;
    end

    categories = cell(1, numel(column_stats));
    for idx = 1:numel(column_stats)
        categories{idx} = assign_nan_category(column_stats(idx).base_name, column_stats(idx).display_name, category_specs);
    end
    [column_stats.category] = categories{:};
    if ~isempty(column_table)
        column_table.category = categories';
    end

    all_categories = unique(categories);
    summary_entries = [];
    category_summary = struct('name', {}, 'variable_count', {}, 'expected', {}, 'mean_nan_pct', {}, ...
        'median_nan_pct', {}, 'max_nan_pct', {}, 'max_nan_variable', {}, 'total_nan_count', {}, 'total_elements', {});

    for idx = 1:numel(all_categories)
        cat_name = all_categories{idx};
        subset_mask = strcmp(categories, cat_name);
        subset = column_stats(subset_mask);
        nan_pcts = [subset.nan_fraction_pct];
        nan_counts = [subset.nan_count];
        totals = [subset.num_elements];

        mean_nan_pct = mean(nan_pcts);
        median_nan_pct = median(nan_pcts);
        [max_nan_pct, max_idx] = max(nan_pcts);
        max_nan_variable = subset(max_idx).display_name;
        total_nan_count = sum(nan_counts);
        total_elements = sum(totals);

        expected = NaN;
        for spec_idx = 1:numel(category_specs)
            if strcmp(category_specs(spec_idx).name, cat_name)
                expected = category_specs(spec_idx).expected;
                break;
            end
        end

        summary_struct = struct( ...
            'name', cat_name, ...
            'variable_count', numel(subset), ...
            'expected', expected, ...
            'mean_nan_pct', mean_nan_pct, ...
            'median_nan_pct', median_nan_pct, ...
            'max_nan_pct', max_nan_pct, ...
            'max_nan_variable', max_nan_variable, ...
            'total_nan_count', total_nan_count, ...
            'total_elements', total_elements);
        category_summary(end+1) = summary_struct; %#ok<AGROW>

        summary_entries = [summary_entries; {cat_name, numel(subset), expected, mean_nan_pct, median_nan_pct, max_nan_pct, max_nan_variable, total_nan_count, total_elements}]; %#ok<AGROW>

        if ~isempty(nan_pcts)
            log_info('Category %-18s | variables=%3d%s | mean NaN%%=%.2f | median=%.2f | max=%.2f (%s)', ...
                cat_name, numel(subset), format_expected_suffix(expected, numel(subset)), ...
                mean_nan_pct, median_nan_pct, max_nan_pct, max_nan_variable);

            [~, sort_idx] = sort(nan_pcts, 'descend');
            top_n = min(3, numel(sort_idx));
            for t = 1:top_n
                entry = subset(sort_idx(t));
                log_info('    #%d %-40s | NaN%%=%.2f | NaNs=%d/%d', ...
                    t, truncate_label(entry.display_name, 40), entry.nan_fraction_pct, entry.nan_count, entry.num_elements);
            end
            if ~isnan(expected) && expected ~= numel(subset)
                log_info('    Note: expected %d variable(s) but matched %d. Adjust define_nan_categories() if needed.', ...
                    expected, numel(subset));
            end
        else
            log_info('Category %-18s | variables=%3d%s | no NaNs detected.', ...
                cat_name, numel(subset), format_expected_suffix(expected, numel(subset)));
            if ~isnan(expected) && expected ~= numel(subset)
                log_info('    Note: expected %d variable(s) but matched %d. Adjust define_nan_categories() if needed.', ...
                    expected, numel(subset));
            end
        end
    end

    if isempty(summary_entries)
        category_summary_table = table();
    else
        category_summary_table = cell2table(summary_entries, ...
            'VariableNames', {'Category', 'VariableCount', 'ExpectedCount', 'MeanNaNPercent', 'MedianNaNPercent', 'MaxNaNPercent', 'MaxNaNVariable', 'TotalNaNCount', 'TotalElements'});
    end
end

function suffix = format_expected_suffix(expected, actual)
    if isnan(expected) || expected <= 0
        suffix = '';
    elseif expected == actual
        suffix = sprintf(' (expected=%d)', expected);
    else
        suffix = sprintf(' (expected=%d, actual=%d)', expected, actual);
    end
end

function category = assign_nan_category(base_name, display_name, specs)
    category = 'Other';
    for idx = 1:numel(specs)
        spec = specs(idx);
        for p = 1:numel(spec.patterns)
            pattern = spec.patterns{p};
            if ~isempty(regexp(base_name, pattern, 'once')) || ~isempty(regexp(display_name, pattern, 'once'))
                category = spec.name;
                return;
            end
        end
    end
end

function figure_paths = generate_nan_figures(column_stats, dataset_basename, run, output_dir, log_info, log_debug)
    figure_paths = struct();
    if isempty(column_stats)
        return;
    end
    categories = {column_stats.category};
    unique_categories = unique(categories);

    max_points = 1e5;
    for idx = 1:numel(unique_categories)
        cat_name = unique_categories{idx};
        subset = column_stats(strcmp(categories, cat_name));
        if isempty(subset)
            continue;
        end

        labels = {subset.display_name};
        nan_percents = [subset.nan_fraction_pct];
        [nan_percents, sort_idx] = sort(nan_percents, 'descend');
        labels = labels(sort_idx);

        bar_fig = figure('Visible','off','Name',sprintf('NaN percentage - %s', cat_name), ...
            'Units','pixels','Position',[100 100 1400 600]);
        bar(nan_percents);
        ax = gca;
        ax.XTick = 1:numel(labels);
        ax.XTickLabel = arrayfun(@(i) truncate_label(labels{i}, 60), 1:numel(labels), 'UniformOutput', false);
        ax.XTickLabelRotation = 90;
        ylabel('NaN events [%]');
        title(sprintf('NaN percentage per variable — %s', cat_name));
        grid on;
        bar_path = fullfile(output_dir, sprintf('nan_bar_%s_%s_run%d.png', make_safe_filename(cat_name), dataset_basename, run));
        exportgraphics(bar_fig, bar_path, 'Resolution', 200);
        close(bar_fig);
        figure_paths.(make_safe_field(sprintf('%s_bar', cat_name))) = bar_path;
        log_info('Saved NaN percentage bar plot for %s to %s', cat_name, bar_path);

        scatter_fig = figure('Visible','off','Name',sprintf('NaN indices - %s', cat_name));
        hold on;
        y_ticks = [];
        y_labels = {};
        for sIdx = 1:numel(subset)
            nan_indices = subset(sIdx).nan_indices;
            if isempty(nan_indices)
                continue;
            end
            if numel(nan_indices) > max_points
                step = ceil(numel(nan_indices) / max_points);
                nan_indices = nan_indices(1:step:end);
                log_debug('Downsampled NaN index plot for %s to %d points.', subset(sIdx).display_name, numel(nan_indices));
            end
            scatter(nan_indices, repmat(sIdx, size(nan_indices)), 10, 'filled');
            y_ticks(end+1) = sIdx; %#ok<AGROW>
            y_labels{end+1} = truncate_label(subset(sIdx).display_name, 40); %#ok<AGROW>
        end
        xlabel('Event index');
        ylabel('Variable');
        if isempty(y_ticks)
            yticks([]);
            text(0.5, 0.5, 'No NaNs detected', 'Units', 'normalized', 'HorizontalAlignment', 'center');
        else
            yticks(y_ticks);
            yticklabels(y_labels);
        end
        title(sprintf('NaN locations per event — %s', cat_name));
        grid on;
        scatter_path = fullfile(output_dir, sprintf('nan_scatter_%s_%s_run%d.png', make_safe_filename(cat_name), dataset_basename, run));
        exportgraphics(scatter_fig, scatter_path, 'Resolution', 200);
        close(scatter_fig);
        figure_paths.(make_safe_field(sprintf('%s_scatter', cat_name))) = scatter_path;
        log_info('Saved NaN index scatter plot for %s to %s', cat_name, scatter_path);
    end
end

function safe = make_safe_filename(str)
    lowerStr = lower(str);
    safe = regexprep(lowerStr, '\s+', '_');
    safe = regexprep(safe, '[^a-z0-9_\-]', '');
    if isempty(safe)
        safe = 'nan_category';
    end
end

function safe_field = make_safe_field(str)
    safe_field = regexprep(str, '\s+', '_');
    safe_field = regexprep(safe_field, '[^a-zA-Z0-9_]', '');
    if isempty(safe_field)
        safe_field = 'field';
    end
end

function label = truncate_label(str, maxLen)
    if numel(str) <= maxLen
        label = str;
    else
        label = [str(1:maxLen-3) '...'];
    end
end

function parsed = parse_nan_cli_options(args)
    parsed = struct( ...
        'has_run_override', false, ...
        'run_override', 0, ...
        'has_input_dir', false, ...
        'input_dir', '', ...
        'has_limit_override', false, ...
        'limit_override', 0);

    if isempty(args)
        return;
    end

    idx = 1;
    while idx <= numel(args)
        token = args{idx};
        if startsWith(token, '--run=')
            parsed.has_run_override = true;
            parsed.run_override = str2double(token(7:end));
        elseif strcmpi(token, '--run') || strcmpi(token, '-r')
            if idx + 1 <= numel(args)
                parsed.has_run_override = true;
                parsed.run_override = str2double(args{idx + 1});
                idx = idx + 1;
            end
        elseif startsWith(token, '--input-dir=')
            parsed.has_input_dir = true;
            parsed.input_dir = token(13:end);
        elseif strcmpi(token, '--input-dir')
            if idx + 1 <= numel(args)
                parsed.has_input_dir = true;
                parsed.input_dir = args{idx + 1};
                idx = idx + 1;
            end
        elseif startsWith(token, '--limit=')
            parsed.has_limit_override = true;
            parsed.limit_override = str2double(token(9:end));
        elseif strcmpi(token, '--limit')
            if idx + 1 <= numel(args)
                parsed.has_limit_override = true;
                parsed.limit_override = str2double(args{idx + 1});
                idx = idx + 1;
            end
        end
        idx = idx + 1;
    end

    if isnan(parsed.run_override)
        parsed.run_override = 0;
    end
    if isnan(parsed.limit_override)
        parsed.limit_override = 0;
    end
end

function report = analyze_nan_workspace(vars, cfg, log_info, log_debug)
    ws = 'base';
    num_vars = numel(vars);

    summary_entries = [];
    charge_entries = [];
    details = struct('name', {}, 'class', {}, 'size', {}, 'numel', {}, ...
        'nan_count', {}, 'nan_fraction', {}, 'has_inf', {}, 'nan_linear_indices', {}, ...
        'nan_rows', {}, 'nan_cols', {}, 'nan_subscripts', {}, 'sample_neighbors', {});

    nan_masks = struct();
    nan_union_by_length = struct();

    total_nan_count = 0;
    vars_with_nan = 0;

    for k = 1:num_vars
        name = vars(k).name;
        val = evalin(ws, name);

        if ~(isnumeric(val) || islogical(val))
            continue;
        end

        mask_nan = isnan(val);
        mask_inf = isinf(val);
        nan_count = nnz(mask_nan);
        inf_count = nnz(mask_inf);
        total_count = numel(val);

        size_vec = size(val);
        size_str = size_to_str(size_vec);
        nan_fraction = double(nan_count) / max(1, double(total_count));
        summary_entries = [summary_entries; {name, class(val), size_str, total_count, nan_count, nan_fraction, inf_count}]; %#ok<AGROW>

        if startsWith(lower(name), 'q')
            charge_entries = [charge_entries; {name, class(val), size_str, total_count, nan_count, nan_fraction, inf_count}]; %#ok<AGROW>
        end

        if nan_count > 0
            vars_with_nan = vars_with_nan + 1;
            total_nan_count = total_nan_count + nan_count;

            nan_masks.(name) = mask_nan;

            detail = struct();
            detail.name = name;
            detail.class = class(val);
            detail.size = size_vec;
            detail.numel = total_count;
            detail.nan_count = nan_count;
            detail.nan_fraction = nan_fraction;
            detail.has_inf = inf_count > 0;

            if isvector(val)
                mask_vector = mask_nan(:);
                detail.nan_linear_indices = find(mask_vector);
                detail.nan_rows = [];
                detail.nan_cols = [];
                detail.nan_subscripts = [];

                key = sprintf('n%d', numel(mask_vector));
                if ~isfield(nan_union_by_length, key)
                    union_entry = struct();
                    union_entry.length = numel(mask_vector);
                    union_entry.union_mask = false(numel(mask_vector), 1);
                    union_entry.variable_names = {};
                    union_entry.masks_by_var = struct();
                    union_entry.sample_values = [];
                    nan_union_by_length.(key) = union_entry;
                end
                union_entry = nan_union_by_length.(key);
                union_entry.union_mask = union_entry.union_mask | mask_vector;
                union_entry.variable_names{end+1} = name; %#ok<AGROW>
                union_entry.masks_by_var.(name) = mask_vector;
                nan_union_by_length.(key) = union_entry;

                neighbor_samples = build_neighbor_samples_vector(val, mask_vector, cfg.maxSampleIndices);
                detail.sample_neighbors = neighbor_samples;

            elseif ndims(val) == 2
                [row_idx, col_idx] = find(mask_nan);
                detail.nan_linear_indices = [];
                detail.nan_rows = unique(row_idx);
                detail.nan_cols = unique(col_idx);
                detail.nan_subscripts = [];
                detail.sample_neighbors = [];
            else
                nan_linear = find(mask_nan);
                detail.nan_linear_indices = nan_linear;
                detail.nan_rows = [];
                detail.nan_cols = [];
                detail.nan_subscripts = {};
                [detail.nan_subscripts{1:numel(size_vec)}] = ind2sub(size_vec, nan_linear); %#ok<NASGU>
                detail.sample_neighbors = [];
            end

            details(end+1) = detail; %#ok<AGROW>
        end
    end

    if ~isempty(summary_entries)
        summary_table = cell2table(summary_entries, ...
            'VariableNames', {'Variable', 'Class', 'Size', 'NumElements', 'NaNCount', 'NaNFraction', 'InfCount'});
        summary_table.NaNFraction = summary_table.NaNFraction * 100; % convert to percent
    else
        summary_table = table();
    end

    if ~isempty(charge_entries)
        charge_summary_table = cell2table(charge_entries, ...
            'VariableNames', {'Variable', 'Class', 'Size', 'NumElements', 'NaNCount', 'NaNFraction', 'InfCount'});
        charge_summary_table.NaNFraction = charge_summary_table.NaNFraction * 100;
    else
        charge_summary_table = table();
    end

    union_keys = fieldnames(nan_union_by_length);
    union_reports = struct('length', {}, 'total_indices', {}, 'sample_indices', {}, 'variables_per_index', {}, 'sample_values', {});
    for idx = 1:numel(union_keys)
        key = union_keys{idx};
        entry = nan_union_by_length.(key);
        nan_indices = find(entry.union_mask);
        if isempty(nan_indices)
            continue;
        end
        sample_indices = nan_indices(1:min(numel(nan_indices), cfg.maxSampleIndices));

        variables_per_index = cell(numel(sample_indices), 1);
        sample_values = cell(numel(sample_indices), 1);
        for j = 1:numel(sample_indices)
            sample_idx = sample_indices(j);
            vars_here = {};
            value_struct = struct();
            for vn = 1:numel(entry.variable_names)
                var_name = entry.variable_names{vn};
                mask_for_var = entry.masks_by_var.(var_name);
                if mask_for_var(sample_idx)
                    vars_here{end+1} = var_name; %#ok<AGROW>
                end
                val = evalin(ws, var_name);
                if isvector(val)
                    value_struct.(var_name) = val(sample_idx);
                end
            end
            variables_per_index{j} = vars_here;
            sample_values{j} = value_struct;
        end

        union_reports(end+1) = struct( ... %#ok<AGROW>
            'length', entry.length, ...
            'total_indices', numel(nan_indices), ...
            'sample_indices', sample_indices, ...
            'variables_per_index', {variables_per_index}, ...
            'sample_values', {sample_values});
    end

    if cfg.debugMode
        log_debug('Found %d numeric/logical variable(s).', size(summary_entries, 1));
        log_debug('Variables containing NaNs: %d (total NaN elements: %d)', vars_with_nan, total_nan_count);
        top_limit = min(cfg.maxLoggedVariables, size(summary_entries, 1));
        if top_limit > 0
            [~, sorted_idx] = sort(cell2mat(summary_entries(:,5)), 'descend');
            top_idx = sorted_idx(1:top_limit);
            log_debug('Top %d variables by NaN count:', top_limit);
            for t = 1:numel(top_idx)
                entry = summary_entries(top_idx(t), :);
                log_debug('  %s | NaNs=%d | elements=%d | size=%s', ...
                    entry{1}, entry{5}, entry{4}, entry{3});
            end
        end
    end

    report = struct();
    report.summary_table = summary_table;
    report.charge_summary_table = charge_summary_table;
    report.variable_details = details;
    report.nan_masks = nan_masks;
    report.union_reports = union_reports;
    report.generated_on = datetime('now');
    report.generator = 'caye_nan_diagnostics';
end

function samples = build_neighbor_samples_vector(val, mask_vector, max_samples)
    nan_indices = find(mask_vector);
    if isempty(nan_indices)
        samples = [];
        return;
    end
    sample_indices = nan_indices(1:min(numel(nan_indices), max_samples));
    samples = struct('index', {}, 'window_indices', {}, 'window_values', {});
    for idx = 1:numel(sample_indices)
        center = sample_indices(idx);
        win_lo = max(1, center - 2);
        win_hi = min(numel(val), center + 2);
        samples(idx).index = center; %#ok<AGROW>
        samples(idx).window_indices = win_lo:win_hi;
        samples(idx).window_values = val(win_lo:win_hi);
    end
end

function size_str = size_to_str(sz)
    if isempty(sz)
        size_str = "[]";
        return;
    end
    size_str = sprintf('%dx', sz);
    size_str = size_str(1:end-1);
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
