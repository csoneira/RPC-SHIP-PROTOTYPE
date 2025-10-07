% clear variables and close figures
clear all; close all; clc;

HOME    = '/home/csoneira/WORK/LIP_stuff/';
SCRIPTS = 'JOAO_SETUP/';
DATA    = 'matFiles/time/';
DATA_Q    = 'matFiles/charge/';
path(path,[HOME SCRIPTS 'util_matPlots']);

% Select which acquisition run to process; each branch below loads time and
% charge information for that specific dataset.
run = 1;
if run == 1
    load([HOME SCRIPTS DATA 'dabc25120133744-dabc25126121423_a001_T.mat']) %run com os 4 cintiladores
    % load([HOME SCRIPTS DATA 'dabc25120133744-dabc25126121423_a002_T.mat']); % no data info in this file
    load([HOME SCRIPTS DATA 'dabc25120133744-dabc25126121423_a003_T.mat']) 
    load([HOME SCRIPTS DATA_Q 'dabc25120133744-dabc25126121423_a004_Q.mat'])
elseif run == 2
    load([HOME SCRIPTS DATA 'dabc25127151027-dabc25147011139_a001_T.mat']) % run com HV de cima desligada
    % load([HOME SCRIPTS DATA 'dabc25127151027-dabc25147011139_a002_T.mat']); % no data info in this file
    load([HOME SCRIPTS DATA 'dabc25127151027-dabc25147011139_a003_T.mat']);
    load([HOME SCRIPTS DATA_Q 'dabc25127151027-dabc25147011139_a004_Q.mat']);
elseif run == 3
    load([HOME SCRIPTS DATA 'dabc25127151027-dabc25160092400_a001_T.mat']) % run com HV de cima desligada
    % load([HOME SCRIPTS DATA 'dabc25127151027-dabc25160092400_a002_T.mat']); % no data info in this file
    load([HOME SCRIPTS DATA 'dabc25127151027-dabc25160092400_a003_T.mat'])
    load([HOME SCRIPTS DATA_Q 'dabc25127151027-dabc25160092400_a004_Q.mat'])
elseif run == 4
    load('/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/MST_saves/dabc25268104307-dabc25279081551_2025-10-07_17h32m05s/time/dabc25268104307-dabc25276125059_a001_T.mat')
    load('/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/MST_saves/dabc25268104307-dabc25279081551_2025-10-07_17h32m05s/time/dabc25268104307-dabc25276125059_a002_T.mat')
    load('/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/MST_saves/dabc25268104307-dabc25279081551_2025-10-07_17h32m05s/charge/dabc25268104307-dabc25276125059_a004_Q.mat')
end

fprintf('Variables loaded from .mat files, run %d:\n', run);
whos
clear all;


run = 4;
if run == 1
    load([HOME SCRIPTS DATA 'dabc25120133744-dabc25126121423_a001_T.mat']) %run com os 4 cintiladores
    % load([HOME SCRIPTS DATA 'dabc25120133744-dabc25126121423_a002_T.mat']); % no data info in this file
    load([HOME SCRIPTS DATA 'dabc25120133744-dabc25126121423_a003_T.mat']) 
    load([HOME SCRIPTS DATA_Q 'dabc25120133744-dabc25126121423_a004_Q.mat'])
elseif run == 2
    load([HOME SCRIPTS DATA 'dabc25127151027-dabc25147011139_a001_T.mat']) % run com HV de cima desligada
    % load([HOME SCRIPTS DATA 'dabc25127151027-dabc25147011139_a002_T.mat']); % no data info in this file
    load([HOME SCRIPTS DATA 'dabc25127151027-dabc25147011139_a003_T.mat']);
    load([HOME SCRIPTS DATA_Q 'dabc25127151027-dabc25147011139_a004_Q.mat']);
elseif run == 3
    load([HOME SCRIPTS DATA 'dabc25127151027-dabc25160092400_a001_T.mat']) % run com HV de cima desligada
    % load([HOME SCRIPTS DATA 'dabc25127151027-dabc25160092400_a002_T.mat']); % no data info in this file
    load([HOME SCRIPTS DATA 'dabc25127151027-dabc25160092400_a003_T.mat'])
    load([HOME SCRIPTS DATA_Q 'dabc25127151027-dabc25160092400_a004_Q.mat'])
elseif run == 4
    load('/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/MST_saves/dabc25268104307-dabc25279081551_2025-10-07_17h32m05s/time/dabc25268104307-dabc25276125059_a001_T.mat')
    load('/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/MST_saves/dabc25268104307-dabc25279081551_2025-10-07_17h32m05s/time/dabc25268104307-dabc25276125059_a002_T.mat')
    load('/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/MST_saves/dabc25268104307-dabc25279081551_2025-10-07_17h32m05s/charge/dabc25268104307-dabc25276125059_a004_Q.mat')
end

fprintf('Variables loaded from .mat files, run %d:\n', run);
whos
clear all;

