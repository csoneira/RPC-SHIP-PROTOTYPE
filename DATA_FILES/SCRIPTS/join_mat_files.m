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
%       '/.../UNPACKED/UNPROCESSED/dabc25127151027-dabc25147011139_...'
%       '/.../UNPACKED/UNPROCESSED/dabc25127151027-dabc25160092400_...'
%   };
%   output_root = '/desired/output/directory';
%   run('join_mat_files.m');
%
% Notes:
% - Files that do not contain the expected variables are ignored.
% - Empty or missing variables are skipped but reported.
% - Column/row vectors are flattened to columns whenever shapes disagree.
% - Directories are expected to mirror the JOAO time/charge structure (subdirs `time/` and `charge/`).
% - When scanning directories, the script prefers files containing "a001" for time and "a004" for charge.
% -------------------------------------------------------------------------

% -------------------------------------------------------------------------
% User configuration (uncomment/edit to use the script standalone)
% runs = {
%     '/path/to/dataset_a'
%     '/path/to/dataset_b'
% };
% file_paths = {}; % optional: mix in specific MAT files or additional directories


% RUN 4
% runs = {
%     '/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/DATA_FILES/DATA/UNPACKED/TO_JOIN_OCT_17/dabc25281080959_2025-10-15_08h15m12s'
%     '/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/DATA_FILES/DATA/UNPACKED/TO_JOIN_OCT_17/dabc25282152204_2025-10-15_08h17m46s'
%     '/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/DATA_FILES/DATA/UNPACKED/TO_JOIN_OCT_17/dabc25283203259_2025-10-15_08h19m13s'
%     '/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/DATA_FILES/DATA/UNPACKED/TO_JOIN_OCT_17/dabc25285040522_2025-10-15_08h30m37s'
%     '/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/DATA_FILES/DATA/UNPACKED/TO_JOIN_OCT_17/dabc25286122758_2025-10-15_08h32m12s'
%     };


% runs = {
%     '/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/DATA_FILES/DATA/HLD_FILES/dabc25289014720.hld'
%     '/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/DATA_FILES/DATA/HLD_FILES/dabc25290081026.hld'
%     '/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/DATA_FILES/DATA/HLD_FILES/dabc25290151552.hld'
%     '/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/DATA_FILES/DATA/HLD_FILES/dabc25291140248.hld'
%     '/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/DATA_FILES/DATA/HLD_FILES/dabc25292123618.hld'
%     };


% Run 4
% runs = {
%     '/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/DATA_FILES/DATA/UNPACKED/ALL/dabc25282152204_2025-10-20_11h53m51s'
%     '/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/DATA_FILES/DATA/UNPACKED/ALL/dabc25283203259_2025-10-20_11h54m47s'
%     '/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/DATA_FILES/DATA/UNPACKED/ALL/dabc25285040522_2025-10-20_11h55m38s'
%     '/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/DATA_FILES/DATA/UNPACKED/ALL/dabc25286122758_2025-10-20_11h56m33s'
%     '/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/DATA_FILES/DATA/UNPACKED/ALL/dabc25287190025_2025-10-20_11h57m28s'
%     '/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/DATA_FILES/DATA/UNPACKED/ALL/dabc25289014720_2025-10-20_11h48m38s'
%     '/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/DATA_FILES/DATA/UNPACKED/ALL/dabc25290081026_2025-10-20_11h49m04s'
%     '/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/DATA_FILES/DATA/UNPACKED/ALL/dabc25290151552_2025-10-20_11h50m22s'
%     };


% Run 5
runs = {
    '/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/DATA_FILES/DATA/UNPACKED/ALL/dabc25291140248_2025-10-20_11h51m27s'
    '/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/DATA_FILES/DATA/UNPACKED/ALL/dabc25292123618_2025-10-20_11h52m27s'
    '/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/DATA_FILES/DATA/UNPACKED/ALL/dabc25293115731_2025-10-21_19h33m08s'
    '/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/DATA_FILES/DATA/UNPACKED/ALL/dabc25294114556_2025-10-21_19h33m23s'
    };


output_root = '/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/DATA_FILES/DATA/UNPACKED/JOINED_OUTPUT/dabc25282152204_RUN_5_2025-10-20_16h00m00s';

% -------------------------------------------------------------------------

if exist('runs', 'var') == 1 && ~isempty(runs)
    if ~iscell(runs) || any(~cellfun(@(p) ischar(p) || isstring(p), runs))
        error('`runs` must be a cell array of character vectors or strings.');
    end
    run_entries = cellfun(@char, runs(:), 'UniformOutput', false);
else
    run_entries = {};
end

if exist('file_paths', 'var') ~= 1 || isempty(file_paths)
    if isempty(run_entries)
        error('Provide either `runs` (dataset directories) or `file_paths` (directories/MAT files).');
    end
    file_paths = run_entries;
else
    if ~iscell(file_paths) || any(~cellfun(@(p) ischar(p) || isstring(p), file_paths))
        error('`file_paths` must be a cell array of character vectors or strings.');
    end
    file_paths = [file_paths(:); run_entries(:)];
end

if isempty(file_paths)
    error('Input list is empty after processing `runs`/`file_paths`.');
end

% Normalize to char vectors and expand directories into their MAT contents.
source_entries = cellfun(@char, file_paths, 'UniformOutput', false);

mat_file_paths = {};
for idx = 1:numel(source_entries)
    entry = source_entries{idx};

    if isfolder(entry)
        time_dir = fullfile(entry, 'time');
        charge_dir = fullfile(entry, 'charge');

        time_paths = {};
        charge_paths = {};

        if isfolder(time_dir)
            time_listing = dir(fullfile(time_dir, '*_a001_T.mat'));
            time_listing = time_listing(~[time_listing.isdir]);
            if isempty(time_listing)
                warning('No time MAT files found in %s', time_dir);
            else
                preferred_time = time_listing(contains({time_listing.name}, 'a001'));
                if ~isempty(preferred_time)
                    time_listing = preferred_time;
                end
                [~, sort_idx] = sort({time_listing.name});
                time_listing = time_listing(sort_idx);
                time_paths = arrayfun(@(d) fullfile(d.folder, d.name), time_listing, 'UniformOutput', false);
                mat_file_paths = [mat_file_paths; time_paths(:)]; %#ok<AGROW>
            end
        else
            warning('Time directory not found in %s', entry);
        end

        if isfolder(charge_dir)
            charge_listing = dir(fullfile(charge_dir, '*_a004_Q.mat'));
            charge_listing = charge_listing(~[charge_listing.isdir]);
            if isempty(charge_listing)
                warning('No charge MAT files found in %s', charge_dir);
            else
                preferred_charge = charge_listing(contains({charge_listing.name}, 'a004'));
                if ~isempty(preferred_charge)
                    charge_listing = preferred_charge;
                end
                [~, sort_idx] = sort({charge_listing.name});
                charge_listing = charge_listing(sort_idx);
                charge_paths = arrayfun(@(d) fullfile(d.folder, d.name), charge_listing, 'UniformOutput', false);
                mat_file_paths = [mat_file_paths; charge_paths(:)]; %#ok<AGROW>
            end
        else
            warning('Charge directory not found in %s', entry);
        end

        if isempty(time_paths) && isempty(charge_paths)
            warning('No MAT files discovered inside directory: %s', entry);
        end
    elseif isfile(entry)
        [~, ~, ext] = fileparts(entry);
        if strcmpi(ext, '.mat')
            mat_file_paths{end+1, 1} = entry; %#ok<AGROW>
        else
            warning('Skipping non-MAT file entry: %s', entry);
        end
    else
        warning('Skipping missing entry: %s', entry);
    end
end

if isempty(mat_file_paths)
    error('No MAT files found in the provided entries.');
end

file_paths = unique(mat_file_paths(:), 'stable');

% Target variable names grouped by category.
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

% Aggregator for variable slices discovered across the MAT files.
aggregated_cells = struct();
for idx = 1:numel(all_target_names)
    aggregated_cells.(all_target_names{idx}) = {};
end

% Track which files contribute to time/charge outputs for naming purposes.
time_source_paths = {};
charge_source_paths = {};

missing_records = struct('path', {}, 'missing', {});

for file_idx = 1:numel(file_paths)
    mat_path = file_paths{file_idx};
    if ~isfile(mat_path)
        warning('Skipping missing file: %s', mat_path);
        continue;
    end

    data_struct = load(mat_path);
    field_names = fieldnames(data_struct);

    % Determine which variables are expected in this file based on its suffix.
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

    % Track whether this file contained at least one target time/charge var.
    time_used = false;
    charge_used = false;

    for f_idx = 1:numel(field_names)
        raw_name = field_names{f_idx};

        % Extract base variable name (portion before the final underscore+index).
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

    % Identify target variables that were expected but not present in this file.
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

% Helper to concatenate numeric cells while keeping compatibility.
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
    warning('No target variables discovered across the provided files. Nothing to save.');
    return;
end

% Derive sensible output root if none supplied.
if ~(exist('output_root', 'var') == 1) || isempty(output_root)
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
        [candidate_dir, ~, ~] = fileparts(candidate_path);      % e.g. .../time
        if isempty(candidate_dir)
            dataset_root = pwd;
        else
            [dataset_root, ~, ~] = fileparts(candidate_dir);    % e.g. .../dataset
            if isempty(dataset_root)
                dataset_root = candidate_dir;
            end
        end
    end
    output_root = fullfile(dataset_root, 'joined_output');
end
output_root = char(output_root);

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

% Infer base names from contributing files for more descriptive output names.
infer_base = @(paths, fallback) local_infer_basename(paths, fallback);

time_base = infer_base(time_source_paths, 'joined_time');
charge_base = infer_base(charge_source_paths, 'joined_charge');

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

% Provide a brief summary of missing variables per file (if any).
for idx = 1:numel(missing_records)
    missing_list = missing_records(idx).missing;
    if isempty(missing_list)
        continue;
    end
    fprintf('Info: variables not found in %s -> %s\n', missing_records(idx).path, strjoin(missing_list, ', '));
end

clear candidate_dir candidate_path charge_base charge_output_dir charge_output_name ...
      charge_output_path charge_output_struct charge_paths charge_source_paths charge_used ...
      data_struct dataset_root expected_names expects_time field_names file_base file_idx idx ...
      infer_base mat_file_paths mat_path missing_here missing_records output_root present_bases ...
      present_tokens raw_name run_entries slices source_entries time_base time_output_dir ...
      time_output_name time_output_path time_output_struct time_paths time_source_paths ...
      time_used time_fallback_groups time_var_names time_primary_var_names time_fallback_var_names ...
      charge_var_names all_target_names tokens value var_name;

% -------------------------------------------------------------------------
function filtered = apply_time_fallbacks(missing_list, present_bases, fallback_groups)
%APPLY_TIME_FALLBACKS Remove missing entries satisfied by fallback channel sets.
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
function combined = local_concat(values)
%LOCAL_CONCAT Concatenate a cell array of numeric matrices along rows.
    values = values(~cellfun('isempty', values));
    if isempty(values)
        combined = [];
        return;
    end

    % Ensure everything is numeric and share the same class.
    classes = cellfun(@class, values, 'UniformOutput', false);
    if numel(unique(classes)) > 1
        error('Cannot concatenate values with different classes: %s', strjoin(unique(classes), ', '));
    end

    ndim = ndims(values{1});
    tail_shape = size(values{1});

    % Check compatibility along trailing dimensions.
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

    % Fall back to column-wise stacking when shapes disagree (e.g. row vs column vectors).
    reshaped = cellfun(@(x) x(:), values, 'UniformOutput', false);
    combined = vertcat(reshaped{:});
end

function base = local_infer_basename(paths, fallback)
%LOCAL_INFER_BASENAME Pull the dataset base name from an input filename.
    if isempty(paths)
        base = fallback;
        return;
    end
    [~, name, ~] = fileparts(paths{1});
    tokens = regexp(name, '^(.*)_a\d{3}_[TQ]$', 'tokens', 'once');
    if ~isempty(tokens)
        base = tokens{1};
        return;
    end
    base = fallback;
end
