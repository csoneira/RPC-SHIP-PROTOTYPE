% join_mat_files.m
% -------------------------------------------------------------------------
% Utility script to concatenate time (l*/t*) and charge (Ib/It variations)
% variables spread across multiple MAT files. Provide the list of dataset
% directories (or individual MAT file paths) in the cell array `file_paths`
% before running the script. Optionally set `output_root` to choose where the
% merged MAT files will be written.
%
% The script inspects every MAT file, collects variables that match the
% expected naming pattern (e.g. l11_1, t11_2, Ib_3, …), concatenates the
% numeric payloads along the event dimension, and writes two MAT files:
%   <base>_joined_a001_T.mat  -> time variables (lXX/tXX)
%   <base>_joined_a004_Q.mat  -> charge variables (Ib/It …)
% under `fullfile(output_root, 'time')` and `'charge'`, respectively.
%
% Example usage inside MATLAB:
%   runs = {
%       '/.../STAGE_6/DATA/DATA_FILES/TO_JOIN/RUN_5'
%   };
%   output_root = '/.../STAGE_6/DATA/DATA_FILES/ALREADY_JOINED/RUN_5';
%   run('join_mat_files.m');
%
% Notes:
% - Files that do not contain the expected variables are ignored.
% - Empty or missing variables are skipped but reported.
% - Column/row vectors are flattened to columns whenever shapes disagree.
% - Directories are expected to mirror the JOAO time/charge structure (subdirs `time/` and `charge/`).
% - When scanning directories, the script prefers files containing "a001" for time and "a004" for charge.
% - When invoked without `runs` or `file_paths`, the script looks for STAGE 6 logbook entries and processes the available RUN directories automatically.
% -------------------------------------------------------------------------

script_full_path = mfilename('fullpath');
if isempty(script_full_path)
    error('join_mat_files:Context', 'Unable to resolve script location with mfilename. Invoke via run(''join_mat_files.m'').');
end

script_dir = fileparts(script_full_path);
stage6_root = fileparts(script_dir);
stages_root = fileparts(stage6_root);
repo_root = fileparts(stages_root);

stage5_root = fullfile(repo_root, 'STAGES', 'STAGE_5');
default_logbook = fullfile(stage5_root, 'DATA', 'DATA_LOGS', 'file_logbook.csv');
runs_root = fullfile(stage6_root, 'DATA', 'DATA_FILES', 'TO_JOIN');
joined_root = fullfile(stage6_root, 'DATA', 'DATA_FILES', 'ALREADY_JOINED');
% Allow fall-back to ALL_UNPACKED if RUN folders are absent.
unpacked_root = fullfile(stage5_root, 'DATA', 'DATA_FILES', 'ALL_UNPACKED');

has_runs = exist('runs', 'var') == 1;
has_file_paths = exist('file_paths', 'var') == 1;
has_output_root = exist('output_root', 'var') == 1;
has_logbook_path = exist('logbook_path', 'var') == 1;

if has_runs
    runs_input = runs;
else
    runs_input = {};
end
if has_file_paths
    file_paths_input = file_paths;
else
    file_paths_input = {};
end
if has_output_root
    output_root_input = output_root;
else
    output_root_input = '';
end
if has_logbook_path && ~isempty(logbook_path)
    logbook_input = logbook_path;
else
    logbook_input = '';
end

jobs = {};

if has_runs || has_file_paths
    manual_job = struct();
    manual_job.source_entries = local_prepare_source_entries(runs_input, file_paths_input);
    manual_job.output_root = output_root_input;
    manual_job.label_hint = local_extract_run_label(output_root_input);
    jobs = {manual_job};
else
    jobs = local_prepare_jobs_from_logbook(logbook_input, default_logbook, runs_root, joined_root, unpacked_root);
end

if isempty(jobs)
    error('join_mat_files:NoInputs', ['No input datasets found. Provide `runs`/`file_paths` ' ...
           'or ensure the logbook and RUN directories are populated.']);
end

for job_idx = 1:numel(jobs)
    local_join_single(jobs{job_idx});
end

clear script_full_path script_dir stage6_root stages_root repo_root default_logbook runs_root joined_root ...
      stage5_root unpacked_root has_runs has_file_paths has_output_root has_logbook_path ...
      runs_input file_paths_input output_root_input logbook_input jobs job_idx manual_job;

% -------------------------------------------------------------------------
function entries = local_prepare_source_entries(runs_input, file_paths_input)
    entries = {};
    run_entries = {};

    if ~isempty(runs_input)
        if isstring(runs_input)
            runs_input = cellstr(runs_input);
        end
        if ~iscell(runs_input)
            error('join_mat_files:InvalidRuns', '`runs` must be a cell array or string array of paths.');
        end
        run_entries = cellfun(@char, runs_input(:), 'UniformOutput', false);
    end

    if isempty(file_paths_input)
        entries = run_entries;
    else
        if isstring(file_paths_input)
            file_paths_input = cellstr(file_paths_input);
        end
        if ~iscell(file_paths_input)
            error('join_mat_files:InvalidFilePaths', '`file_paths` must be a cell array or string array of paths.');
        end
        file_entries = cellfun(@char, file_paths_input(:), 'UniformOutput', false);
        entries = [file_entries(:); run_entries(:)];
    end

    if isempty(entries)
        error('join_mat_files:EmptySources', 'Input list is empty after processing `runs`/`file_paths`.');
    end
end

% -------------------------------------------------------------------------
function jobs = local_prepare_jobs_from_logbook(explicit_logbook, default_logbook, runs_root, joined_root, unpacked_root)
    jobs = {};

    candidates = {explicit_logbook, default_logbook};
    logbook_path = '';
    for idx = 1:numel(candidates)
        candidate = candidates{idx};
        if isempty(candidate)
            continue;
        end
        try
            candidate_str = char(candidate);
        catch
            continue;
        end
        if isfile(candidate_str)
            logbook_path = candidate_str;
            break;
        end
    end

    if isempty(logbook_path)
        return;
    end

    try
        tbl = readtable(logbook_path, 'TextType', 'string');
    catch readErr
        warning('join_mat_files:LogbookReadFailed', 'Could not read logbook %s (%s).', logbook_path, readErr.message);
        return;
    end

    potential_columns = ["run_id", "run"];
    run_column = "";
    for candidate = potential_columns
        if any(strcmpi(tbl.Properties.VariableNames, candidate))
            run_column = candidate;
            break;
        end
    end
    if strlength(run_column) == 0
        warning('join_mat_files:LogbookNoRuns', 'Logbook %s lacks a run identifier column; skipping automatic mode.', logbook_path);
        return;
    end

    run_values = tbl.(run_column);
    if iscell(run_values)
        run_values = string(run_values);
    end
    run_values = strtrim(run_values);
    run_values = run_values(run_values ~= "");
    if isempty(run_values)
        return;
    end

    unique_run_ids = unique(run_values, 'stable');

    for idx = 1:numel(unique_run_ids)
        run_id = unique_run_ids(idx);
        if strlength(run_id) == 0
            continue;
        end
        run_id_char = char(run_id);
        run_dirname = sprintf('RUN_%s', run_id_char);
        run_dir = fullfile(runs_root, run_dirname);

        if ~isfolder(run_dir)
            % Fall back to ALL_UNPACKED structure if the RUN mirror is missing.
            if ~any(strcmpi(tbl.Properties.VariableNames, 'filename'))
                warning('join_mat_files:LogbookNoFilenames', 'Logbook %s lacks a filename column; cannot infer directories for run %s.', logbook_path, run_id_char);
                continue;
            end
            hld_matches = tbl.(run_column) == run_id;
            related_files = tbl.filename(hld_matches);
            related_files = related_files(~ismissing(related_files));
            collected_dirs = {};
            for jdx = 1:numel(related_files)
                raw_name = char(related_files(jdx));
                dataset_prefix = erase(raw_name, '.hld');
                dir_listing = dir(fullfile(unpacked_root, sprintf('%s*', dataset_prefix)));
                dir_listing = dir_listing([dir_listing.isdir]);
                if isempty(dir_listing)
                    fprintf('Info: no unpacked directory found for %s (run %s); skipping.\n', raw_name, run_id_char);
                    continue;
                end
                collected_dirs{end+1, 1} = fullfile(unpacked_root, dir_listing(1).name); %#ok<AGROW>
            end

            if isempty(collected_dirs)
                warning('join_mat_files:MissingRunDir', 'No directories found for run %s; skipping.', run_id_char);
                continue;
            end

            job = struct();
            job.source_entries = collected_dirs;
            job.output_root = fullfile(joined_root, run_dirname);
            job.label_hint = run_dirname;
            jobs{end+1} = job; %#ok<AGROW>
            continue;
        end

        job = struct();
        job.source_entries = {run_dir};
        job.output_root = fullfile(joined_root, run_dirname);
        job.label_hint = run_dirname;
        jobs{end+1} = job; %#ok<AGROW>
    end
end

% -------------------------------------------------------------------------
function local_join_single(job)
    if ~isfield(job, 'source_entries') || isempty(job.source_entries)
        warning('join_mat_files:EmptyJob', 'Encountered a job without source entries; skipping.');
        return;
    end

    source_entries = job.source_entries;
    if ~iscell(source_entries)
        source_entries = {source_entries};
    end
    source_entries = source_entries(:);
    source_entries = cellfun(@char, source_entries, 'UniformOutput', false);

    time_primary_var_names = {
        'l11','l12','l9','l10',...
        't11','t12','t9','t10',...
        'l30','l31','l32','l29','l28',...
        't30','t31','t32','t29','t28',...
        'l3','l2','l1','l4','l5',...
        't3','t2','t1','t4','t5'...
    };

    time_fallback_var_names = {
        'l28','l27','l26','l25','l24',...
        't28','t27','t26','t25','t24'...
    };

    time_var_names = unique([time_primary_var_names, time_fallback_var_names], 'stable');

    charge_var_names = {
        'Ib','IIb','IIIb','IVb','Vb','VIb','VIIb','VIIIb','IXb','Xb','XIb','XIIb','XIIIb','XIVb','XVb','XVIb','XVIIb','XVIIIb','XIXb','XXb','XXIb','XXIIb','XXIIIb','XXIVb',...
        'It','IIt','IIIt','IVt','Vt','VIt','VIIt','VIIIt','IXt','Xt','XIt','XIIt','XIIIt','XIVt','XVt','XVIt','XVIIt','XVIIIt','XIXt','XXt','XXIt','XXIIt','XXIIIt','XXIVt'...
    };

    time_fallback_groups = {
        struct('primary', {{'l30','l31','l32','l29','l28'}}, 'fallback', {{'l28','l27','l26','l25','l24'}})
        struct('primary', {{'t30','t31','t32','t29','t28'}}, 'fallback', {{'t28','t27','t26','t25','t24'}})
    };

    all_target_names = [time_var_names, charge_var_names];

    mat_file_paths = {};
    time_source_paths = {};
    charge_source_paths = {};

    for idx = 1:numel(source_entries)
        entry = source_entries{idx};

        if isfolder(entry)
            time_dir = fullfile(entry, 'time');
            charge_dir = fullfile(entry, 'charge');

            if isfolder(time_dir)
                time_listing = dir(fullfile(time_dir, '*_a001_T.mat'));
                time_listing = time_listing(~[time_listing.isdir]);
                if isempty(time_listing)
                    fprintf('Info: no time MAT files found in %s\n', time_dir);
                else
                    preferred_time = time_listing(contains({time_listing.name}, 'a001'));
                    if ~isempty(preferred_time)
                        time_listing = preferred_time;
                    end
                    [~, sort_idx] = sort({time_listing.name});
                    time_listing = time_listing(sort_idx);
                    time_paths = arrayfun(@(d) fullfile(d.folder, d.name), time_listing, 'UniformOutput', false);
                    mat_file_paths = [mat_file_paths; time_paths(:)]; %#ok<AGROW>
                    time_source_paths = [time_source_paths; time_paths(:)]; %#ok<AGROW>
                end
            else
                fprintf('Info: time directory not found in %s\n', entry);
            end

            if isfolder(charge_dir)
                charge_listing = dir(fullfile(charge_dir, '*_a004_Q.mat'));
                charge_listing = charge_listing(~[charge_listing.isdir]);
                if isempty(charge_listing)
                    fprintf('Info: no charge MAT files found in %s\n', charge_dir);
                else
                    preferred_charge = charge_listing(contains({charge_listing.name}, 'a004'));
                    if ~isempty(preferred_charge)
                        charge_listing = preferred_charge;
                    end
                    [~, sort_idx] = sort({charge_listing.name});
                    charge_listing = charge_listing(sort_idx);
                    charge_paths = arrayfun(@(d) fullfile(d.folder, d.name), charge_listing, 'UniformOutput', false);
                    mat_file_paths = [mat_file_paths; charge_paths(:)]; %#ok<AGROW>
                    charge_source_paths = [charge_source_paths; charge_paths(:)]; %#ok<AGROW>
                end
            else
                fprintf('Info: charge directory not found in %s\n', entry);
            end
        elseif isfile(entry)
            [~, ~, ext] = fileparts(entry);
            if strcmpi(ext, '.mat')
                mat_file_paths{end+1, 1} = entry; %#ok<AGROW>
                if contains(entry, '_a001_T')
                    time_source_paths{end+1, 1} = entry; %#ok<AGROW>
                elseif contains(entry, '_a004_Q')
                    charge_source_paths{end+1, 1} = entry; %#ok<AGROW>
                end
            else
                fprintf('Info: skipping non-MAT file entry %s\n', entry);
            end
        else
            fprintf('Info: skipping missing entry %s\n', entry);
        end
    end

    if isempty(mat_file_paths)
        warning('join_mat_files:NoMatFiles', 'No MAT files found for sources: %s', strjoin(source_entries, ', '));
        return;
    end

    file_paths = unique(mat_file_paths(:), 'stable');

    aggregated_cells = struct();
    for idx = 1:numel(all_target_names)
        aggregated_cells.(all_target_names{idx}) = {};
    end

    missing_records = struct('path', {}, 'missing', {});

    for file_idx = 1:numel(file_paths)
        mat_path = file_paths{file_idx};
        if ~isfile(mat_path)
            fprintf('Info: skipping missing file %s\n', mat_path);
            continue;
        end

        try
            data_struct = load(mat_path);
        catch loadErr
            warning('join_mat_files:LoadFailed', 'Unable to load %s (%s). Skipping.', mat_path, loadErr.message);
            continue;
        end
        field_names = fieldnames(data_struct);

        % if isempty(field_names)
        %     fprintf('%s\n\t%s\n', mat_path, '[no variables found]');
        % else
        %     sorted_names = sort(field_names);
        %     fprintf('%s\n\t%s\n', mat_path, strjoin(sorted_names', ', '));
        % end

        [~, file_base, ~] = fileparts(mat_path);
        if ~isempty(regexp(file_base, '_T$', 'once'))
            expected_names = time_primary_var_names;
            expects_time = true;
        elseif ~isempty(regexp(file_base, '_Q$', 'once'))
            expected_names = charge_var_names;
            expects_time = false;
        else
            expected_names = all_target_names;
            expects_time = true;
        end

        time_used = false;
        charge_used = false;

        for f_idx = 1:numel(field_names)
            raw_name = field_names{f_idx};

            tokens = regexp(raw_name, '^(?<base>[A-Za-z0-9]+?)(?:_(?<idx>\d+))?$', 'names');
            if isempty(tokens)
                continue;
            end

            base_name = tokens.base;

            if ~ismember(base_name, all_target_names)
                continue;
            end

            value = data_struct.(raw_name);
            aggregated_cells.(base_name){end+1} = value; %#ok<AGROW>

            if ismember(base_name, time_var_names)
                time_used = true;
            else
                charge_used = true;
            end
        end

        if time_used
            time_source_paths{end+1} = mat_path; %#ok<AGROW>
        end
        if charge_used
            charge_source_paths{end+1} = mat_path; %#ok<AGROW>
        end

        present_tokens = cellfun(@(name) regexp(name, '^(?<base>[A-Za-z0-9]+?)(?:_\d+)?$', 'tokens', 'once'), field_names, 'UniformOutput', false);
        present_tokens = present_tokens(~cellfun('isempty', present_tokens));
        present_bases = cellfun(@(tok) tok{1}, present_tokens, 'UniformOutput', false);
        present_bases = unique(present_bases);

        missing_here = setdiff(expected_names, present_bases);
        if expects_time
            missing_here = apply_time_fallbacks(missing_here, present_bases, time_fallback_groups);
        end

        if ~isempty(missing_here)
            record_idx = numel(missing_records) + 1;
            missing_records(record_idx).path = mat_path; %#ok<AGROW>
            missing_records(record_idx).missing = missing_here; %#ok<AGROW>
        end
    end

    concatenate_cells = @(values) local_concat(values);

    time_output_struct = struct();
    for idx = 1:numel(time_var_names)
        var_name = time_var_names{idx};
        slices = aggregated_cells.(var_name);
        if isempty(slices)
            continue;
        end
        time_output_struct.(var_name) = concatenate_cells(slices);
    end

    charge_output_struct = struct();
    for idx = 1:numel(charge_var_names)
        var_name = charge_var_names{idx};
        slices = aggregated_cells.(var_name);
        if isempty(slices)
            continue;
        end
        charge_output_struct.(var_name) = concatenate_cells(slices);
    end

    if isempty(fieldnames(time_output_struct)) && isempty(fieldnames(charge_output_struct))
        warning('join_mat_files:NoVariables', 'No target variables discovered across the provided files. Nothing to save.');
        return;
    end

    if isfield(job, 'output_root') && ~isempty(job.output_root)
        output_root = char(job.output_root);
    else
        candidate_path = '';
        if ~isempty(time_source_paths)
            candidate_path = time_source_paths{1};
        elseif ~isempty(charge_source_paths)
            candidate_path = charge_source_paths{1};
        elseif ~isempty(file_paths)
            candidate_path = file_paths{1};
        else
            candidate_path = source_entries{1};
        end

        if isfolder(candidate_path)
            dataset_root = candidate_path;
        else
            [candidate_dir, ~, ~] = fileparts(candidate_path);
            if isempty(candidate_dir)
                dataset_root = pwd;
            else
                [dataset_root, ~, ~] = fileparts(candidate_dir);
                if isempty(dataset_root)
                    dataset_root = candidate_dir;
                end
            end
        end
        output_root = fullfile(dataset_root, 'joined_output');
    end
    output_root = char(output_root);

    run_label = local_pick_run_label(output_root, job.label_hint, time_source_paths, charge_source_paths, source_entries);

    infer_base = @(paths, fallback) local_infer_basename(paths, fallback);
    if ~isempty(run_label)
        time_base = run_label;
        charge_base = run_label;
    else
        time_base = infer_base(time_source_paths, 'joined_time');
        charge_base = infer_base(charge_source_paths, 'joined_charge');
    end

    time_output_dir = fullfile(output_root, 'time');
    charge_output_dir = fullfile(output_root, 'charge');

    if ~isempty(fieldnames(time_output_struct))
        if ~exist(time_output_dir, 'dir')
            mkdir(time_output_dir);
        end
    end
    if ~isempty(fieldnames(charge_output_struct))
        if ~exist(charge_output_dir, 'dir')
            mkdir(charge_output_dir);
        end
    end

    fprintf('-------------------------------------------------------------------\n');
    fprintf('-------------------------------------------------------------------\n');
    fprintf('-------------------------------------------------------------------\n');

    if ~isempty(run_label)
        fprintf('Joining files for %s\n', run_label);
    else
        fprintf('Joining files into %s\n', output_root);
    end

    if ~isempty(fieldnames(time_output_struct))
        time_output_name = sprintf('%s_joined_a001_T.mat', time_base);
        if strcmp(time_base, 'joined_time')
            time_output_name = 'joined_a001_T.mat';
        end
        time_output_path = fullfile(time_output_dir, time_output_name);
        save(time_output_path, '-struct', 'time_output_struct', '-v7');
        fprintf('Wrote concatenated time variables to: %s\n', time_output_path);
    end

    if ~isempty(fieldnames(charge_output_struct))
        charge_output_name = sprintf('%s_joined_a004_Q.mat', charge_base);
        if strcmp(charge_base, 'joined_charge')
            charge_output_name = 'joined_a004_Q.mat';
        end
        charge_output_path = fullfile(charge_output_dir, charge_output_name);
        save(charge_output_path, '-struct', 'charge_output_struct', '-v7');
        fprintf('Wrote concatenated charge variables to: %s\n', charge_output_path);
    end

    for idx = 1:numel(missing_records)
        missing_list = missing_records(idx).missing;
        if isempty(missing_list)
            continue;
        end
        fprintf('Info: variables not found in %s -> %s\n', missing_records(idx).path, strjoin(missing_list, ', '));
    end
end

% -------------------------------------------------------------------------
function filtered = apply_time_fallbacks(missing_list, present_bases, fallback_groups)
    filtered = missing_list;
    if isempty(filtered) || isempty(fallback_groups)
        return;
    end

    for g = 1:numel(fallback_groups)
        group = fallback_groups{g};
        if isempty(group.fallback)
            continue;
        end
        if ~all(ismember(group.fallback, present_bases))
            continue;
        end

        removable = intersect(filtered, group.primary);
        if isempty(removable)
            continue;
        end

        filtered = setdiff(filtered, removable, 'stable');
    end
end

% -------------------------------------------------------------------------
function label = local_pick_run_label(output_root, label_hint, time_paths, charge_paths, source_entries)
    label = '';
    candidates = {};

    if exist('label_hint', 'var') && ~isempty(label_hint)
        candidates{end+1} = label_hint; %#ok<AGROW>
    end
    if exist('output_root', 'var') && ~isempty(output_root)
        candidates{end+1} = output_root; %#ok<AGROW>
    end
    if exist('source_entries', 'var') && ~isempty(source_entries)
        candidates = [candidates, source_entries(:)']; %#ok<AGROW>
    end
    if exist('time_paths', 'var') && ~isempty(time_paths)
        candidates = [candidates, time_paths(:)']; %#ok<AGROW>
    end
    if exist('charge_paths', 'var') && ~isempty(charge_paths)
        candidates = [candidates, charge_paths(:)']; %#ok<AGROW>
    end

    for idx = 1:numel(candidates)
        candidate = candidates{idx};
        label = local_extract_run_label(candidate);
        if ~isempty(label)
            return;
        end
    end
end

% -------------------------------------------------------------------------
function label = local_extract_run_label(candidate)
    label = '';
    if nargin == 0 || isempty(candidate)
        return;
    end
    if iscell(candidate)
        candidate = candidate{1};
    end
    try
        candidate_str = char(candidate);
    catch
        return;
    end
    tokens = regexp(candidate_str, '(RUN_\d+)', 'tokens', 'once');
    if ~isempty(tokens)
        label = tokens{1};
    end
end

% -------------------------------------------------------------------------
function combined = local_concat(values)
    values = values(~cellfun('isempty', values));
    if isempty(values)
        combined = [];
        return;
    end

    classes = cellfun(@class, values, 'UniformOutput', false);
    if numel(unique(classes)) > 1
        error('Cannot concatenate values with different classes: %s', strjoin(unique(classes), ', '));
    end

    ndim = ndims(values{1});
    tail_shape = size(values{1});

    compatible = true;
    for idx = 2:numel(values)
        sz = size(values{idx});
        if ndims(values{idx}) ~= ndim || ~isequal(sz(2:end), tail_shape(2:end))
            compatible = false;
            break;
        end
    end

    if compatible
        combined = cat(1, values{:});
        return;
    end

    reshaped = cellfun(@(x) x(:), values, 'UniformOutput', false);
    combined = vertcat(reshaped{:});
end

% -------------------------------------------------------------------------
function base = local_infer_basename(paths, fallback)
    if isempty(paths)
        base = fallback;
        return;
    end
    candidate = paths{1};
    if iscell(candidate)
        candidate = candidate{1};
    end
    try
        candidate = char(candidate);
    catch
        base = fallback;
        return;
    end
    [~, name, ~] = fileparts(candidate);
    tokens = regexp(name, '^(.*)_a\d{3}_[TQ]$', 'tokens', 'once');
    if ~isempty(tokens)
        base = tokens{1};
        return;
    end
    tokens = regexp(candidate, '(RUN_\d+)', 'tokens', 'once');
    if ~isempty(tokens)
        base = tokens{1};
        return;
    end
    base = fallback;
end
