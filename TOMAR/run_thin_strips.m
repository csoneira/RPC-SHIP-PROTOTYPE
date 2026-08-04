% Terminal entry point for TOMAR sampled thin-strip pulse analysis.
%
% From the repository root:
%   octave-cli --quiet TOMAR/run_thin_strips.m
%   octave-cli --quiet TOMAR/run_thin_strips.m TOMAR/DATA/another_run.mat
%
% With no argument this intentionally targets Alberto's first
% high-statistics thin-strip run, dabc26212155929.mat.

script_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(script_dir, 'SCRIPTS'));
cli_args = argv();
if isempty(cli_args)
    % Use the configured run so the standard output lifecycle applies:
    % newest files stay in 23_thin_strips_first and the preceding execution
    % is archived in 23_thin_strips_first/LAST.
    analyze_fast_6x6('', false, true, [], 'thin_strips_first');
else
    % An explicit MAT path remains available for ad-hoc thin-only studies.
    data_file = cli_args{1};
    [~, run_name] = fileparts(data_file);
    output_dir = fullfile(script_dir, 'OUTPUTS', run_name);
    analyze_thin_strips(data_file, output_dir, true, true, run_name);
end
