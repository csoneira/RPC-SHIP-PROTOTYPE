%Joana Pinto 2025
% script novo para os 4 cintiladores, 2 top 2 bottom
% o run nº1 foi com a alta tensão ligada 
% o run nº2 e 3 foram adquiridos com a alta tensão desligada em cima

% NOTA!!!
% ter atensão à ordem das ligações das strips:
% gordas: TFl = [l31 l32 l30 l28 l29]; TFt = [t31 t32 t30 t28 t29];  TBl = [l2 l1 l3 l5 l4]; TBt = [t2 t1 t3 t5 t4];
% cintiladores: Tl_cint = [l11 l12 l9 l10]; Tt_cint = [t11 t12 t9 t10]; 
% Nota: os cabos estavam trocados, por isso, Qt=Ib... e Qb=It...

clear all; close all; clc;

%clear all; close all; clc;
HOME    = '/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/';
SCRIPTS = '/STORED_NOT_ESSENTIAL/';
DATA    = 'matFiles/time/';
DATA_Q    = 'matFiles/charge/';
path(path,[HOME SCRIPTS 'util_matPlots']);

% Select which acquisition run to process; each branch below loads time and
% charge information for that specific dataset.
run = 1;

if run == 1
    % load([HOME SCRIPTS DATA 'dabc25120133744-dabc25126121423_a001_T.mat']) %run com os 4 cintiladores
    %run with all 4 scintillators
    % load([HOME SCRIPTS DATA 'dabc25120133744-dabc25126121423_a003_T.mat']) 
    load([HOME SCRIPTS DATA_Q 'dabc25120133744-dabc25126121423_a004_Q.mat'])
elseif run == 2
    load([HOME SCRIPTS DATA 'dabc25127151027-dabc25147011139_a001_T.mat']) % run com HV de cima desligada
    % run with the top HV switched off
    load([HOME SCRIPTS DATA 'dabc25127151027-dabc25147011139_a003_T.mat']);
    load([HOME SCRIPTS DATA_Q 'dabc25127151027-dabc25147011139_a004_Q.mat']);
elseif run == 3
    load([HOME SCRIPTS DATA 'dabc25127151027-dabc25160092400_a001_T.mat']) % run com HV de cima desligada
    % run with the top HV switched off
    load([HOME SCRIPTS DATA 'dabc25127151027-dabc25160092400_a003_T.mat'])
    load([HOME SCRIPTS DATA_Q 'dabc25127151027-dabc25160092400_a004_Q.mat'])
end


whos
