% Octave entry point for the TOMAR fast-electronics 6 x 6 analysis.
% Run from the repository root with:
%   octave-cli --quiet TOMAR/run_fast_6x6.m
% By default this processes the last row of TOMAR/CONFIGS/runs.csv. To select a
% specific configured run, pass its run_name as the first argument:
%   octave-cli --quiet TOMAR/run_fast_6x6.m first
% To select a specific data row in runs.csv (needed when names are repeated),
% pass @ followed by its one-based data-row number:
%   octave-cli --quiet TOMAR/run_fast_6x6.m @13
% The TOMAR_RUN environment variable is also supported.
%
% This terminal-friendly entry point writes CSV, MAT, and PNG histogram
% outputs without opening figures.

script_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(script_dir, 'SCRIPTS'));
requested_run = getenv('TOMAR_RUN');
cli_args = argv();
if ~isempty(cli_args)
    requested_run = cli_args{1};
end
analyze_fast_6x6('', false, true, [], requested_run);
