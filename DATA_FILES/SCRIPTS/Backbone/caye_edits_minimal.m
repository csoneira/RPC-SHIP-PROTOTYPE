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

%clear all; close all; clc;
% Configure base folders that contain the scripts and MAT files to analyse.
% =====================================================================
% Configuration Paths and Run Selection
% =====================================================================

% clear variables and close figures
save_plots_dir_default = '/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/DATA_FILES/DATA/PDF';
if ~exist('save_plots','var')
    save_plots = false;
end
if ~exist('save_plots_dir','var') || isempty(save_plots_dir)
    save_plots_dir = save_plots_dir_default;
end

clearvars -except save_plots save_plots_dir save_plots_dir_default;
close all; clc;

if isstring(save_plots_dir)
    save_plots_dir = char(save_plots_dir);
end

if save_plots && (isempty(save_plots_dir) || (~ischar(save_plots_dir) && ~isstring(save_plots_dir)))
    save_plots_dir = save_plots_dir_default;
end

clear save_plots_dir_default;

restoreFigureVisibility = [];
if save_plots
    originalFigureVisibility = get(0, 'DefaultFigureVisible');
    restoreFigureVisibility = onCleanup(@() set(0, 'DefaultFigureVisible', originalFigureVisibility));
    set(0, 'DefaultFigureVisible', 'off');
end

HOME    = '/home/csoneira/WORK/LIP_stuff/';
SCRIPTS = 'JOAO_SETUP/';
DATA    = 'matFiles/time/';
DATA_Q    = 'matFiles/charge/';
path(path,[HOME SCRIPTS 'util_matPlots']);

% Select which acquisition run to process; each branch below loads time and
% charge information for that specific dataset.
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

whos

% ---------------------------------------------------------------------
% ---------------------------------------------------------------------
% Data Structuring
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

%tempos leadings  [ns] - leading times [ns]
Tl_cint = [l11 l12 l9 l10];    

%tempos trailings [ns] - trailing times [ns]
Tt_cint = [t11 t12 t9 t10];

%channels 1 and 2 -> bottom PMTs - ch1 e ch2 -> PMTs bottom
Qcint          = [Tt_cint(:,1) - Tl_cint(:,1) Tt_cint(:,2) - Tl_cint(:,2) Tt_cint(:,3) - Tl_cint(:,3) Tt_cint(:,4) - Tl_cint(:,4)]; 

%sum of the charges from the 2 bottom PMTs; used for the slewing correction
Qcint_sum_bot  = (Qcint(:,1) + Qcint(:,2)); %soma das cargas dos 2 PMTs bottom; usado no caso da slewing correction
Qcint_sum_top  = (Qcint(:,3) + Qcint(:,4)); %soma das cargas top

% Semisum of the leading edge times per side to estimate incident time in bottom PMTs
Tcint_mean_bot = (Tl_cint(:,1) + Tl_cint(:,2))/2;

% Semisum of the leading edge times per side to estimate incident time in top PMTs
Tcint_mean_top = (Tl_cint(:,3) + Tl_cint(:,4))/2;


% -----------------------------------------------------------------------------
% RPC WIDE STRIP Timing and Charge Derivations
% -----------------------------------------------------------------------------

% Try this, if it does not work, then store the channels from 24 to 28, and print a warning
% that the channel order is not as expected. So it was changed to the 24-28 order.

try
    TFl = [l31 l32 l30 l28 l29];    % tempos leadings front [ns]; chs [32,28] -> 5 strips gordas front
    TFt = [t31 t32 t30 t28 t29];    % tempos trailings front [ns]
catch
    warning('Variables l31/l32/l30 not found; using alternative channel order 24–28.');
    TFl = [l28 l27 l26 l25 l24];
    TFt = [t28 t27 t26 t25 t24];
end



%leading times back [ns]; channels [1,5] -> 5 wide back strips
TBl = [l2 l1 l3 l5 l4];         %tempos leadings  back  [ns]; chs [1,5] -> 5 strips gordas back

%trailing times back [ns]
TBt = [t2 t1 t3 t5 t4];         %tempos trailings back  [ns]

clearvars l32 l31 l30 l29 l28 t32 t31 t30 t29 t28 l1 l2 l3 l4 l5 t1 t2 t3 t4 t5 l11 l12 l9 l10 t11 t12 t9 t10 

% Charge proxies per strip (front/back)
QF  = TFt - TFl;
QB  = TBt - TBl;

rawEvents = size(TFl,1);


% -----------------------------------------------------------------------------
% RPC charges for the five NARROW STRIPS, which do not carry timing info.
% -----------------------------------------------------------------------------

% Convert charge arrays from cell traces to double matrices (after cable swap).
% nota: os cabos estavam trocados, por isso, Qt=Ib e Qb=It; note: the cables were swapped, so Qt=Ib and Qb=It
Qt = cast([Ib IIb IIIb IVb Vb VIb VIIb VIIIb IXb Xb XIb XIIb XIIIb XIVb XVb XVIb XVIIb XVIIIb XIXb XXb XXIb XXIIb XXIIIb XXIVb],"double");
Qb = cast([It IIt IIIt IVt Vt VIt VIIt VIIIt IXt Xt XIt XIIt XIIIt XIVt XVt XVIt XVIIt XVIIIt XIXt XXt XXIt XXIIt XXIIIt XXIVt],"double");

clearvars Ib IIb IIIb IVb Vb VIb VIIb VIIIb IXb Xb XIb XIIb XIIIb XIVb XVb XVIb XVIIb XVIIIb XIXb XXb XXIb XXIIb XXIIIb XXIVb It IIt IIIt IVt Vt VIt VIIt VIIIt IXt Xt XIt XIIt XIIIt XIVt XVt XVIt XVIIt XVIIIt XIXt XXt XXIt XXIIt XXIIIt XXIVt

% Charge sum over all narrow strips per event
Q_thin_top_event = sum(Qt, 2); % total charge in the 5 narrow strips on the top side per event
Q_thin_bot_event = sum(Qb, 2); % total charge in the 5 narrow strips on the bottom side per event

% Total number of triggered events available in the loaded files.
events=size(EventPerFile,1);

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
subplot(2,2,1); plot(Tl_cint(:,1), Tt_cint(:,1),'.'); xlabel('Tl_cint1'); ylabel('Tt_cint1'); title(sprintf('Time lead vs trail PMT1 (run %d)', run));
xlim([min(min(Tl_cint)) max(max(Tl_cint))]); ylim([min(min(Tt_cint)) max(max(Tt_cint))]);
subplot(2,2,2); plot(Tl_cint(:,2), Tt_cint(:,2),'.'); xlabel('Tl_cint2'); ylabel('Tt_cint2'); title(sprintf('Time lead vs trail PMT2 (run %d)', run));
xlim([min(min(Tl_cint)) max(max(Tl_cint))]); ylim([min(min(Tt_cint)) max(max(Tt_cint))]);
subplot(2,2,3); plot(Tl_cint(:,3), Tt_cint(:,3),'.'); xlabel('Tl_cint3'); ylabel('Tt_cint3'); title(sprintf('Time lead vs trail PMT3 (run %d)', run));
xlim([min(min(Tl_cint)) max(max(Tl_cint))]); ylim([min(min(Tt_cint)) max(max(Tt_cint))]);
subplot(2,2,4); plot(Tl_cint(:,4), Tt_cint(:,4),'.'); xlabel('Tl_cint4'); ylabel('Tt_cint4'); title(sprintf('Time lead vs trail PMT4 (run %d)', run));
xlim([min(min(Tl_cint)) max(max(Tl_cint))]); ylim([min(min(Tt_cint)) max(max(Tt_cint))]);
sgtitle(sprintf('PMT time lead vs trail (run %d)', run));

% Now plot the charge correlations for the same PMT pairs to verify that
figure;
subplot(1,2,1); plot(Qcint(:,1), Qcint(:,2), '.'); xlabel('Qcint1'); ylabel('Qcint2'); title(sprintf('Charge PMT1 vs PMT2 (run %d)', run));
xlim([min(min(Qcint)) max(max(Qcint))]); ylim([min(min(Qcint)) max(max(Qcint))]);
subplot(1,2,2); plot(Qcint(:,3), Qcint(:,4), '.'); xlabel('Qcint3'); ylabel('Qcint4'); title(sprintf('Charge PMT3 vs PMT4 (run %d)', run));
xlim([min(min(Qcint)) max(max(Qcint))]); ylim([min(min(Qcint)) max(max(Qcint))]);
sgtitle(sprintf('PMT charge correlations (run %d)', run));

% Finally, plot the Tl_cint i vs Tl_cint j scatter plots for all PMT pairs to verify the
figure;
subplot(1,2,1); plot(Tl_cint(:,1), Tl_cint(:,2),'.'); xlabel('Tl_cint1'); ylabel('Tl_cint2'); title(sprintf('Time lead PMT1 vs PMT2 (run %d)', run));
xlim([min(min(Tl_cint)) max(max(Tl_cint))]); ylim([min(min(Tl_cint)) max(max(Tl_cint))]);
subplot(1,2,2); plot(Tl_cint(:,3), Tl_cint(:,4),'.'); xlabel('Tl_cint3'); ylabel('Tl_cint4'); title(sprintf('Time lead PMT3 vs PMT4 (run %d)', run));
xlim([min(min(Tl_cint)) max(max(Tl_cint))]); ylim([min(min(Tl_cint)) max(max(Tl_cint))]);
sgtitle(sprintf('PMT time coincidences (run %d)', run));


% -----------------------------------------------------------------------------
% RPC wide strip Timing and Charge Derivations
% -----------------------------------------------------------------------------

%leading times front [ns]; channels [32,28] -> 5 wide front strips
% TFl, TBl, QF, QB

% Similar scatter subplot plots for the wide strips to verify no obvious problems.
figure;
subplot(2,5,1); plot(TFl(:,1), TBl(:,1),'.'); xlabel('TFl'); ylabel('TBl'); title(sprintf('Time lead Front vs back strip1 (run %d)', run));
xlim([min(min(TFl)) max(max(TFl))]); ylim([min(min(TBl)) max(max(TBl))]);
subplot(2,5,2); plot(TFl(:,2), TBl(:,2),'.'); xlabel('TFl'); ylabel('TBl'); title(sprintf('Time lead Front vs back strip2 (run %d)', run));
xlim([min(min(TFl)) max(max(TFl))]); ylim([min(min(TBl)) max(max(TBl))]);
subplot(2,5,3); plot(TFl(:,3), TBl(:,3),'.'); xlabel('TFl'); ylabel('TBl'); title(sprintf('Time lead Front vs back strip3 (run %d)', run));
xlim([min(min(TFl)) max(max(TFl))]); ylim([min(min(TBl)) max(max(TBl))]);
subplot(2,5,4); plot(TFl(:,4), TBl(:,4),'.'); xlabel('TFl'); ylabel('TBl'); title(sprintf('Time lead Front vs back strip4 (run %d)', run));
xlim([min(min(TFl)) max(max(TFl))]); ylim([min(min(TBl)) max(max(TBl))]);
subplot(2,5,5); plot(TFl(:,5), TBl(:,5),'.'); xlabel('TFl'); ylabel('TBl'); title(sprintf('Time lead Front vs back strip5 (run %d)', run));
xlim([min(min(TFl)) max(max(TFl))]); ylim([min(min(TBl)) max(max(TBl))]);

subplot(2,5,6); plot(QF(:,1), QB(:,1),'.'); xlabel('QF'); ylabel('QB'); title(sprintf('Charge Front vs back strip1 (run %d)', run));
xlim([min(min(QF)) max(max(QF))]); ylim([min(min(QB)) max(max(QB))]);
subplot(2,5,7); plot(QF(:,2), QB(:,2),'.'); xlabel('QF'); ylabel('QB'); title(sprintf('Charge Front vs back strip2 (run %d)', run));
xlim([min(min(QF)) max(max(QF))]); ylim([min(min(QB)) max(max(QB))]);
subplot(2,5,8); plot(QF(:,3), QB(:,3),'.'); xlabel('QF'); ylabel('QB'); title(sprintf('Charge Front vs back strip3 (run %d)', run));
xlim([min(min(QF)) max(max(QF))]); ylim([min(min(QB)) max(max(QB))]);
subplot(2,5,9); plot(QF(:,4), QB(:,4),'.'); xlabel('QF'); ylabel('QB'); title(sprintf('Charge Front vs back strip4 (run %d)', run));
xlim([min(min(QF)) max(max(QF))]); ylim([min(min(QB)) max(max(QB))]);
subplot(2,5,10); plot(QF(:,5), QB(:,5),'.'); xlabel('QF'); ylabel('QB'); title(sprintf('Charge Front vs back strip5 (run %d)', run));
xlim([min(min(QF)) max(max(QF))]); ylim([min(min(QB)) max(max(QB))]);
sgtitle(sprintf('Thick strip time and charge front vs back (run %d)', run));


% Wide Strip Charge Spectra and Offset Calibration

% Inspect per-strip charge spectra before any calibration to compare front
% and back readouts channel by channel.

% 5 histograms for wide strips, Q as a function of # of events

% Static offsets measured with self-trigger data; subtract to calibrate strip
% responses on both faces.

QB_offsets = [81, 84, 82, 85, 84]; %selfTrigger
QF_offsets = [75, 85.5, 82, 80, 80];

QB_p = QB - QB_offsets;
QF_p = QF - QF_offsets;

clearvars QB_offsets QF_offsets

right_lim_q_wide = 100; %adjust as needed

figure;
for strip = 1:5
    % Left column: uncalibrated
    subplot(5,2,strip*2-1);
    histogram(QF(:,strip),-2:0.1:150); hold on;
    histogram(QB(:,strip),-2:0.1:150); xlim([-2 150]);
    legend(sprintf('QF - strip%d', strip), sprintf('QB - strip%d', strip), 'Location', 'northeast');
    ylabel('# of events');
    xlabel('Q [ns]');
    % Right column: calibrated
    subplot(5,2,strip*2);
    histogram(QF_p(:,strip), -2:0.1:right_lim_q_wide); hold on;
    histogram(QB_p(:,strip), -2:0.1:right_lim_q_wide);
    xlim([-2 right_lim_q_wide]);
    legend(sprintf('QF - strip%d', strip), sprintf('QB - strip%d', strip), 'Location', 'northeast');
    ylabel('# of events');
    xlabel('Q [ns]');
    sgtitle(sprintf('Wide strip charge spectra and calibration (run %d)', run));
end


% Event-Level Maximum Charge Aggregation

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

% Ensure Q is [rawEvents x 1] for mask compatibility
if length(Q) < rawEvents
    Q_full = nan(rawEvents,1);
    Q_full(rows) = Q(rows);
    Q = Q_full;
end

% Charge sum over all wide strips per event
Q_thick_event = Q;

figure;
subplot(2,2,1); histogram(Q, 0:0.1:300); xlabel('Q [ns]'); ylabel('# of events'); title(sprintf('Q total in sum of THICK STRIPS (run %d)', run));
subplot(2,2,2); histogram(X, 1:0.5:5.5); xlabel('X (strip with Qmax)'); ylabel('# of events'); title(sprintf('X position (strip with Qmax) (run %d)', run));
subplot(2,2,3); histogram(T, -220:1:-100); xlabel('T [ns]'); ylabel('# of events'); title(sprintf('T (mean of Tfl and Tbl) (run %d)', run));
subplot(2,2,4); histogram(Y, -2:0.1:2); xlabel('Y [ns]'); ylabel('# of events'); title(sprintf('Y (Tfl-Tbl)/2 (run %d)', run));
sgtitle(sprintf('THICK STRIP OBSERVABLES (run %d)', run));

STLevel = 100; % 230 with the 1 mm gap RPCs; streamer threshold
Qmean = mean(Q, 'omitnan'); % mean of the 'sum of Qmax front and back' over all events
Qmedian = median(Q, 'omitnan'); %median
ST      = length(find(Q > STLevel))/rawEvents; %percentage of streamers


% -----------------------------------------------------------------------------
% RPC charges for the five narrow strips, which do not carry timing info.
% -----------------------------------------------------------------------------

% This is a key plot. In run 1 the span of both axes is similar, while in runs 2
% and 3 the top charges are much lower, as expected. Calculating how much could give an idea
% of the relative gain of the top and bottom sides of the RPC and hence an idea on the
% real HV difference between both sides.

figure;
subplot(4,6,1); plot(Qt(:,1), Qb(:,1),'.'); xlabel('Qt'); ylabel('Qb'); title(sprintf('Charge top vs bottom NARROW strip I (run %d)', run));
xlim([min(min(Qt)) max(max(Qt))]); ylim([min(min(Qb)) max(max(Qb))]);
subplot(4,6,2); plot(Qt(:,2), Qb(:,2),'.'); xlabel('Qt'); ylabel('Qb'); title(sprintf('Charge top vs bottom NARROW strip II (run %d)', run));
xlim([min(min(Qt)) max(max(Qt))]); ylim([min(min(Qb)) max(max(Qb))]);
subplot(4,6,3); plot(Qt(:,3), Qb(:,3),'.'); xlabel('Qt'); ylabel('Qb'); title(sprintf('Charge top vs bottom NARROW strip III (run %d)', run));
xlim([min(min(Qt)) max(max(Qt))]); ylim([min(min(Qb)) max(max(Qb))]);
subplot(4,6,4); plot(Qt(:,4), Qb(:,4),'.'); xlabel('Qt'); ylabel('Qb'); title(sprintf('Charge top vs bottom NARROW strip IV (run %d)', run));
xlim([min(min(Qt)) max(max(Qt))]); ylim([min(min(Qb)) max(max(Qb))]);
subplot(4,6,5); plot(Qt(:,5), Qb(:,5),'.'); xlabel('Qt'); ylabel('Qb'); title(sprintf('Charge top vs bottom NARROW strip V (run %d)', run));
xlim([min(min(Qt)) max(max(Qt))]); ylim([min(min(Qb)) max(max(Qb))]);
subplot(4,6,6); plot(Qt(:,6), Qb(:,6),'.'); xlabel('Qt'); ylabel('Qb'); title(sprintf('Charge top vs bottom NARROW strip VI (run %d)', run));
xlim([min(min(Qt)) max(max(Qt))]); ylim([min(min(Qb)) max(max(Qb))]);
subplot(4,6,7); plot(Qt(:,7), Qb(:,7),'.'); xlabel('Qt'); ylabel('Qb'); title(sprintf('Charge top vs bottom NARROW strip VII (run %d)', run));
xlim([min(min(Qt)) max(max(Qt))]); ylim([min(min(Qb)) max(max(Qb))]);
subplot(4,6,8); plot(Qt(:,8), Qb(:,8),'.'); xlabel('Qt'); ylabel('Qb'); title(sprintf('Charge top vs bottom NARROW strip VIII (run %d)', run));
xlim([min(min(Qt)) max(max(Qt))]); ylim([min(min(Qb)) max(max(Qb))]);
subplot(4,6,9); plot(Qt(:,9), Qb(:,9),'.'); xlabel('Qt'); ylabel('Qb'); title(sprintf('Charge top vs bottom NARROW strip IX (run %d)', run));
xlim([min(min(Qt)) max(max(Qt))]); ylim([min(min(Qb)) max(max(Qb))]);
subplot(4,6,10); plot(Qt(:,10), Qb(:,10),'.'); xlabel('Qt'); ylabel('Qb'); title(sprintf('Charge top vs bottom NARROW strip X (run %d)', run));
xlim([min(min(Qt)) max(max(Qt))]); ylim([min(min(Qb)) max(max(Qb))]);
subplot(4,6,11); plot(Qt(:,11), Qb(:,11),'.'); xlabel('Qt'); ylabel('Qb'); title(sprintf('Charge top vs bottom NARROW strip XI (run %d)', run));
xlim([min(min(Qt)) max(max(Qt))]); ylim([min(min(Qb)) max(max(Qb))]);
subplot(4,6,12); plot(Qt(:,12), Qb(:,12),'.'); xlabel('Qt'); ylabel('Qb'); title(sprintf('Charge top vs bottom NARROW strip XII (run %d)', run));
xlim([min(min(Qt)) max(max(Qt))]); ylim([min(min(Qb)) max(max(Qb))]);
subplot(4,6,13); plot(Qt(:,13), Qb(:,13),'.'); xlabel('Qt'); ylabel('Qb'); title(sprintf('Charge top vs bottom NARROW strip XIII (run %d)', run));
xlim([min(min(Qt)) max(max(Qt))]); ylim([min(min(Qb)) max(max(Qb))]);
subplot(4,6,14); plot(Qt(:,14), Qb(:,14),'.'); xlabel('Qt'); ylabel('Qb'); title(sprintf('Charge top vs bottom NARROW strip XIV (run %d)', run));
xlim([min(min(Qt)) max(max(Qt))]); ylim([min(min(Qb)) max(max(Qb))]);
subplot(4,6,15); plot(Qt(:,15), Qb(:,15),'.'); xlabel('Qt'); ylabel('Qb'); title(sprintf('Charge top vs bottom NARROW strip XV (run %d)', run));
xlim([min(min(Qt)) max(max(Qt))]); ylim([min(min(Qb)) max(max(Qb))]);
subplot(4,6,16); plot(Qt(:,16), Qb(:,16),'.'); xlabel('Qt'); ylabel('Qb'); title(sprintf('Charge top vs bottom NARROW strip XVI (run %d)', run));
xlim([min(min(Qt)) max(max(Qt))]); ylim([min(min(Qb)) max(max(Qb))]);
subplot(4,6,17); plot(Qt(:,17), Qb(:,17),'.'); xlabel('Qt'); ylabel('Qb'); title(sprintf('Charge top vs bottom NARROW strip XVII (run %d)', run));
xlim([min(min(Qt)) max(max(Qt))]); ylim([min(min(Qb)) max(max(Qb))]);
subplot(4,6,18); plot(Qt(:,18), Qb(:,18),'.'); xlabel('Qt'); ylabel('Qb'); title(sprintf('Charge top vs bottom NARROW strip XVIII (run %d)', run));
xlim([min(min(Qt)) max(max(Qt))]); ylim([min(min(Qb)) max(max(Qb))]);
subplot(4,6,19); plot(Qt(:,19), Qb(:,19),'.'); xlabel('Qt'); ylabel('Qb'); title(sprintf('Charge top vs bottom NARROW strip XIX (run %d)', run));
xlim([min(min(Qt)) max(max(Qt))]); ylim([min(min(Qb)) max(max(Qb))]);
subplot(4,6,20); plot(Qt(:,20), Qb(:,20),'.'); xlabel('Qt'); ylabel('Qb'); title(sprintf('Charge top vs bottom NARROW strip XX (run %d)', run));
xlim([min(min(Qt)) max(max(Qt))]); ylim([min(min(Qb)) max(max(Qb))]);
subplot(4,6,21); plot(Qt(:,21), Qb(:,21),'.'); xlabel('Qt'); ylabel('Qb'); title(sprintf('Charge top vs bottom NARROW strip XXI (run %d)', run));
xlim([min(min(Qt)) max(max(Qt))]); ylim([min(min(Qb)) max(max(Qb))]);
subplot(4,6,22); plot(Qt(:,22), Qb(:,22),'.'); xlabel('Qt'); ylabel('Qb'); title(sprintf('Charge top vs bottom NARROW strip XXII (run %d)', run));
xlim([min(min(Qt)) max(max(Qt))]); ylim([min(min(Qb)) max(max(Qb))]);
subplot(4,6,23); plot(Qt(:,23), Qb(:,23),'.'); xlabel('Qt'); ylabel('Qb'); title(sprintf('Charge top vs bottom NARROW strip XXIII (run %d)', run));
xlim([min(min(Qt)) max(max(Qt))]); ylim([min(min(Qb)) max(max(Qb))]);
subplot(4,6,24); plot(Qt(:,24), Qb(:,24),'.'); xlabel('Qt'); ylabel('Qb'); title(sprintf('Charge top vs bottom NARROW strip XXIV (run %d)', run));
xlim([min(min(Qt)) max(max(Qt))]); ylim([min(min(Qb)) max(max(Qb))]);
sgtitle(sprintf('Narrow strip charge top vs bottom (run %d)', run));


% Sum charge over all thin strips (bottom/top)
ChargePerEvent_b = sum(Qb,2); 
ChargePerEvent_t = sum(Qt,2); %max 512ADCbins*32DSampling*24strips ~400000

% Calculate a 95% quantile to put as right limit in the histograms
q005_b = quantile(ChargePerEvent_b, 0.005);
q005_t = quantile(ChargePerEvent_t, 0.005);
q005 = min(q005_b, q005_t);

q95_b = quantile(ChargePerEvent_b, 0.95);
q95_t = quantile(ChargePerEvent_t, 0.95);
q95 = max(q95_b, q95_t);

figure;
subplot(1,3,1); histogram(ChargePerEvent_b, 0:200:5E4); ylabel('# of events'); xlabel('Q (bottom)'); title(sprintf('Q BOTTOM spectrum (sum of Q per event) (run %d)', run));
xlim([q005 q95]);
subplot(1,3,2); histogram(ChargePerEvent_t, 0:200:5E4); ylabel('# of events'); xlabel('Q (top)'); title(sprintf('Q TOP spectrum (sum of Q per event) (run %d)', run));
xlim([q005 q95]);
% scatter plot
subplot(1,3,3); plot(ChargePerEvent_b, ChargePerEvent_t,'.'); xlabel('Q (bottom)'); ylabel('Q (top)'); title(sprintf('Q bottom vs Q top (run %d)', run));
xlim([q005 q95]); ylim([q005 q95])
% Title for the entire figure
sgtitle(sprintf('Charge of the event (run %d)', run));



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

% loop on q_threshold and plot efficiency vs q_threshold
q_threshold_values = 200:200:20000; % example range, adjust as needed
eff_bottom_values = zeros(size(q_threshold_values));
eff_top_values = zeros(size(q_threshold_values));
for i = 1:length(q_threshold_values)
    q_threshold = q_threshold_values(i);
    I_b = find(ChargePerEvent_b < q_threshold);
    eff_bottom_values(i) = 100*(1-(size(I_b,1)/events));
    I_t = find(ChargePerEvent_t < q_threshold);
    eff_top_values(i) = 100*(1-(size(I_t,1)/events));
end
figure;
plot(q_threshold_values, eff_bottom_values, '-o', 'DisplayName', 'Bottom');
hold on;
plot(q_threshold_values, eff_top_values, '-o', 'DisplayName', 'Top');
xlabel('Q Threshold');
ylabel('Efficiency [%]');
title(sprintf('Efficiency vs Q Threshold (run %d)', run));
legend show;

%%

% ---------------------------------------------------------------------
% PMT Coincidence-Based Efficiency Filtering
% ---------------------------------------------------------------------

% Loop over tTH and plot % of good events
tTH_values = 1:0.1:7; % example range, adjust as needed
percent_good_events = zeros(size(tTH_values));
for i = 1:length(tTH_values)
    tTH = tTH_values(i);
    restrictionsForPMTs_test = abs(Tl_cint(:,1)-Tl_cint(:,2)) < tTH & ...
                          abs(Tl_cint(:,1)-Tl_cint(:,3)) < tTH & ...
                          abs(Tl_cint(:,1)-Tl_cint(:,4)) < tTH & ...
                          abs(Tl_cint(:,2)-Tl_cint(:,3)) < tTH & ...
                          abs(Tl_cint(:,2)-Tl_cint(:,4)) < tTH & ...
                          abs(Tl_cint(:,3)-Tl_cint(:,4)) < tTH;
    indicesGoodEvents_test = find(restrictionsForPMTs_test);
    numberGoodEvents_test = length(indicesGoodEvents_test);
    percent_good_events(i) = 100 * numberGoodEvents_test / rawEvents;
end
figure;
plot(tTH_values, percent_good_events, '-o');
xlabel('tTH [ns]');
ylabel('% of good events');
title(sprintf('Good events vs tTH (run %d)', run));

%%

% Apply a ±tTH time coincidence across all PMTs to keep only events seen by
% the scintillator stack, then inspect the corresponding charge spectra.

tTH = 4; %time threshold [ns] to assume it comes from a good event; obriga a ter tempos nos 4 cint JOANA HAD 3 ns

%forces the four scintillators to have timestamps within this window
restrictionsForPMTs = abs(Tl_cint(:,1)-Tl_cint(:,2)) <tTH & ...
                      abs(Tl_cint(:,1)-Tl_cint(:,3)) <tTH & ...
                      abs(Tl_cint(:,1)-Tl_cint(:,4)) <tTH & ...
                      abs(Tl_cint(:,2)-Tl_cint(:,3)) <tTH & ...
                      abs(Tl_cint(:,2)-Tl_cint(:,4)) <tTH & ...
                      abs(Tl_cint(:,3)-Tl_cint(:,4)) <tTH;

indicesGoodEvents=find(restrictionsForPMTs);
numberGoodEvents = length(indicesGoodEvents);

% percentage of good events
fprintf('Number of good events (PMT coincidence): %d out of %d (%.2f%%)\n', numberGoodEvents, rawEvents, 100*numberGoodEvents/rawEvents);

ChargePerEvent_b_goodEventsOnly= ChargePerEvent_b(indicesGoodEvents);
ChargePerEvent_t_goodEventsOnly= ChargePerEvent_t(indicesGoodEvents);

numberSeenEvents=length(find(ChargePerEvent_b_goodEventsOnly > 1400));
eff_bottom_goodEventsOnly = 100*(numberSeenEvents/numberGoodEvents);

numberSeenEvents=length(find(ChargePerEvent_t_goodEventsOnly > 1400));
eff_top_goodEventsOnly    = 100*(numberSeenEvents/numberGoodEvents);
figure;
subplot(2,1,1); histogram(ChargePerEvent_b_goodEventsOnly, 0:200:5E4); ylabel('# of events'); xlabel('Q (bottom)'); title(sprintf('Q spectrum (sum of Q per event); Eff_{bot} = %2.2f%% (run %d)', eff_bottom_goodEventsOnly, run));
subplot(2,1,2); histogram(ChargePerEvent_t_goodEventsOnly, 0:200:5E4); ylabel('# of events'); xlabel('Q (top)'); title(sprintf('Q spectrum (sum of Q per event); Eff_{top} = %2.2f%% (run %d)', eff_top_goodEventsOnly, run));
xlim([q005 q95]);

%%

% loop on q_threshold and plot efficiency vs q_threshold
q_strip_threshold_values = 200:200:20000; % example range, adjust as needed
eff_bottom_values = zeros(size(q_strip_threshold_values));
eff_top_values = zeros(size(q_strip_threshold_values));
for i = 1:length(q_strip_threshold_values)
    q_threshold = q_strip_threshold_values(i);
    I_b = find(ChargePerEvent_b_goodEventsOnly < q_threshold);
    eff_bottom_values(i) = 100*(1-(size(I_b,1)/events));
    I_t = find(ChargePerEvent_t_goodEventsOnly < q_threshold);
    eff_top_values(i) = 100*(1-(size(I_t,1)/events));
end
figure;
plot(q_strip_threshold_values, eff_bottom_values, '-o', 'DisplayName', 'Bottom'); hold on;
plot(q_strip_threshold_values, eff_top_values, '-o', 'DisplayName', 'Top');
xlabel('Q in sum of narrow strips per event threshold');
ylabel('Efficiency [%]');
legend show;
title(sprintf('Efficiency vs Q Threshold (run %d)', run));

%%

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
Q_pmt_1 = Qcint(:,1); Q_pmt_1(isnan(Q_pmt_1)) = -20;
Q_pmt_2 = Qcint(:,2); Q_pmt_2(isnan(Q_pmt_2)) = -20;
Q_pmt_3 = Qcint(:,3); Q_pmt_3(isnan(Q_pmt_3)) = -20;
Q_pmt_4 = Qcint(:,4); Q_pmt_4(isnan(Q_pmt_4)) = -20;
Q_thick = Q_thick_event; Q_thick(isnan(Q_thick)) = -20;
Q_thin_top = Q_thin_top_event; Q_thin_top(isnan(Q_thin_top)) = -20;
Q_thin_bot = Q_thin_bot_event; Q_thin_bot(isnan(Q_thin_bot)) = -20;


%%


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

fprintf('Percentage of streamers (Q > threshold) in Thick RPC: %.2f%%\n', percentage_streamer_thick);
fprintf('Percentage of streamers (Q > threshold) in Thin RPC TOP: %.2f%%\n', percentage_streamer_thin_top);
fprintf('Percentage of streamers (Q > threshold) in Thin RPC BOTTOM: %.2f%%\n', percentage_streamer_thin_bot);

% the streamer % in the histogram title with no decimals
figure;
subplot(2,3,1); histogram(Q_thick, 0:1:300); set(gca, 'YScale', 'log'); xlabel('Q_{thick\_event} [ADC bins]'); ylabel('# of events'); title(sprintf('Thick RPC Q, streamer <%d%%> (run %d)', round(percentage_streamer_thick), run));
hold on; xline(Q_thick_streamer_threshold, 'r--', 'Streamer Threshold');
subplot(2,3,2); histogram(Q_thin_top, 0:100:10E4); set(gca, 'YScale', 'log'); xlabel('Q_{thin\_top\_event} [ADC bins]'); ylabel('# of events'); title(sprintf('Thin RPC TOP Q, streamer <%d%%> (run %d)', round(percentage_streamer_thin_top), run));
hold on; xline(Q_thin_top_streamer_threshold, 'r--', 'Streamer Threshold');
subplot(2,3,3); histogram(Q_thin_bot, 0:100:10E4); set(gca, 'YScale', 'log'); xlabel('Q_{thin\_bot\_event} [ADC bins]'); ylabel('# of events'); title(sprintf('Thin RPC BOTTOM Q, streamer <%d%%> (run %d)', round(percentage_streamer_thin_bot), run));
hold on; xline(Q_thin_bot_streamer_threshold, 'r--', 'Streamer Threshold');

subplot(2,3,4); histogram(Q_thick, 0:2:300, 'Normalization', 'cdf'); xlabel('Q_{thick\_event} [ADC bins]'); ylabel('Cumulative Distribution'); title(sprintf('Thick RPC Q CDF (run %d)', run));
hold on; xline(Q_thick_streamer_threshold, 'r--', 'Streamer Threshold'); ylim([0 1]);
subplot(2,3,5); histogram(Q_thin_top, 0:500:10E4, 'Normalization', 'cdf'); xlabel('Q_{thin\_top\_event} [ADC bins]'); ylabel('Cumulative Distribution'); title(sprintf('Thin RPC TOP Q CDF (run %d)', run));
hold on; xline(Q_thin_top_streamer_threshold, 'r--', 'Streamer Threshold'); ylim([0 1]);
subplot(2,3,6); histogram(Q_thin_bot, 0:500:10E4, 'Normalization', 'cdf'); xlabel('Q_{thin\_bot\_event} [ADC bins]'); ylabel('Cumulative Distribution'); title(sprintf('Thin RPC BOTTOM Q CDF (run %d)', run));
hold on; xline(Q_thin_bot_streamer_threshold, 'r--', 'Streamer Threshold'); ylim([0 1]);

sgtitle(sprintf('RPC Charge Spectra and cumulative distributions (run %d)', run));


%%

% ---------------------------------------------------------------------
% EFFICIENCY
% ---------------------------------------------------------------------

tTH = 4; % time threshold [ns]

% PMTs (Qcint per tube)
pmt_1_charge_threshold_min = 94;  pmt_1_charge_threshold_max = 103;  % ADCbins
pmt_2_charge_threshold_min = 101; pmt_2_charge_threshold_max = 120;  % ADCbins
pmt_3_charge_threshold_min = 146; pmt_3_charge_threshold_max = 180;  % ADCbins
pmt_4_charge_threshold_min = 95;  pmt_4_charge_threshold_max = 107;  % ADCbins

% Thick RPC (sum of Qmax front/back)
thick_strip_charge_threshold_min = 5;    % ADCbins
thick_strip_charge_threshold_max = 40;   % ADCbins

% Thin RPC (event sums)
if run == 1
    top_narrow_strip_charge_threshold_min = 2600;  % ADCbins/event
    top_narrow_strip_charge_threshold_max = 15000; % ADCbins/event
elseif run == 2
    top_narrow_strip_charge_threshold_min = 200;   % ADCbins/event
    top_narrow_strip_charge_threshold_max = 3000;  % ADCbins/event
elseif run == 3
    top_narrow_strip_charge_threshold_min = 200;   % ADCbins/event
    top_narrow_strip_charge_threshold_max = 3000;  % ADCbins/event
else
    top_narrow_strip_charge_threshold_min = 200;   % ADCbins/event
    top_narrow_strip_charge_threshold_max = 3000;  % ADCbins/event
end

bot_narrow_strip_charge_threshold_min = 4600;  % ADCbins/event
bot_narrow_strip_charge_threshold_max = 20000; % ADCbins/event

% Calculate efficiency using different types of masks.

% The first essential is that four PMTs have positive charge
pmt_exists_Mask = (Q_pmt_1 > 0) & (Q_pmt_2 > 0) & (Q_pmt_3 > 0) & (Q_pmt_4 > 0);
pmt_range_Mask  = (Q_pmt_1 >= pmt_1_charge_threshold_min) & (Q_pmt_1 <= pmt_1_charge_threshold_max) & ...
                      (Q_pmt_2 >= pmt_2_charge_threshold_min) & (Q_pmt_2 <= pmt_2_charge_threshold_max) & ...
                      (Q_pmt_3 >= pmt_3_charge_threshold_min) & (Q_pmt_3 <= pmt_3_charge_threshold_max) & ...
                      (Q_pmt_4 >= pmt_4_charge_threshold_min) & (Q_pmt_4 <= pmt_4_charge_threshold_max);
pmt_time_Mask = abs(Tl_cint(:,1)-Tl_cint(:,2)) <tTH & ...
                      abs(Tl_cint(:,1)-Tl_cint(:,3)) <tTH & ...
                      abs(Tl_cint(:,1)-Tl_cint(:,4)) <tTH & ...
                      abs(Tl_cint(:,2)-Tl_cint(:,3)) <tTH & ...
                      abs(Tl_cint(:,2)-Tl_cint(:,4)) <tTH & ...
                      abs(Tl_cint(:,3)-Tl_cint(:,4)) <tTH;
                      

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

% Plot layout: 3x3 (7 used)
figure('Name','Charge Histograms with In-Range Overlays');
tiledlayout(3,3,'TileSpacing','compact','Padding','compact');

nBins = 150;  % adjust if you want finer/coarser binning

for k = 1:numel(detNames)
    x = detData{k};
    x = x(isfinite(x)); % keep finite values only
    
    if isempty(x)
        nexttile;
        axis off;
        title(detNames{k}, 'Interpreter','none');
        text(0.5,0.5,'No data','HorizontalAlignment','center');
        continue;
    end
    
    % Bin edges based on full data range for consistent overlay
    xmin = min(x);
    xmax = max(x);
    if xmin == xmax
        xmax = xmin + 1; % avoid zero-width range
    end
    edges = linspace(xmin, xmax, nBins+1);

    % In-range selection
    inMin = minVals(k);
    inMax = maxVals(k);
    maskIn = (x >= inMin) & (x <= inMax);
    xin = x(maskIn);

    nexttile;
    hold on;
    % Full histogram (background)
    hAll = histogram(x, 'BinEdges', edges, 'DisplayStyle','bar', 'EdgeAlpha', 0.4, 'FaceAlpha', 0.35);
    % In-range overlay (foreground)
    if ~isempty(xin)
        hIn  = histogram(xin, 'BinEdges', edges, 'DisplayStyle','bar', 'EdgeAlpha', 0.9, 'FaceAlpha', 0.8);
    else
        hIn = [];
    end
    xlabel('ADC bins'); ylabel('Counts');
    title(sprintf('%s', detNames{k}), 'Interpreter','tex');

    % Vertical lines for the limits
    yL = ylim;
    plot([inMin inMin], yL, '--', 'LineWidth', 1);
    plot([inMax inMax], yL, '--', 'LineWidth', 1);
    ylim(yL); % keep same after lines

    % Legend (handle empty in-range gracefully)
    if isempty(hIn)
        legend(hAll, {'All events'}, 'Location','best');
    else
        legend([hAll hIn], {'All events', sprintf('In range [%g, %g]', inMin, inMax)}, 'Location','best');
    end
    box on; hold off;
end

% Optional: add a super title
sgtitle('Charge distributions (full) with thresholded subset overlaid');


% Now define masks for each detector based on the min/max thresholds, explicitly
thick_exists_Mask = Q_thick > 0;
thick_range_Mask = (Q_thick >= thick_strip_charge_threshold_min) & (Q_thick <= thick_strip_charge_threshold_max);

thinTop_exists_Mask = Q_thin_top > 0;
thinTop_range_Mask = (Q_thin_top >= top_narrow_strip_charge_threshold_min) & (Q_thin_top <= top_narrow_strip_charge_threshold_max);

thinBot_exists_Mask = Q_thin_bot > 0;
thinBot_range_Mask = (Q_thin_bot >= bot_narrow_strip_charge_threshold_min) & (Q_thin_bot <= bot_narrow_strip_charge_threshold_max);



% Now combine masks in different ways to see the effect on efficiency for different detectors
% For example, I want the efficiency of thin top when pmt exists


% Efficiency of thin top -------------------------------------------
% Existence masks
% I want the efficiency of thin top when pmt exists

% I want the efficiency of thin top when pmt exists and thick exists

% I want the efficiency of thin top when pmt exists and thin exists

% I want the efficiency of thin top when pmt exists and thick exists and thin bot exists

% Range masks
% I want the efficiency of thin top when pmt is in range

% I want the efficiency of thin top when pmt is in range and thick is in range

% I want the efficiency of thin top when pmt is in range and thin is in range

% I want the efficiency of thin top when pmt is in range and thick is in range and thin bot is in range


% Efficiency of thin bot -------------------------------------------
% Existence masks
% I want the efficiency of thin bot when pmt exists

% I want the efficiency of thin bot when pmt exists and thick exists

% I want the efficiency of thin bot when pmt exists and thin exists

% I want the efficiency of thin bot when pmt exists and thick exists and thin top exists

% Range masks
% I want the efficiency of thin bot when pmt is in range

% I want the efficiency of thin bot when pmt is in range and thick is in range

% I want the efficiency of thin bot when pmt is in range and thin is in range

% I want the efficiency of thin bot when pmt is in range and thick is in range and thin top is in range


% Efficiency of thick -------------------------------------------
% Existence masks
% I want the efficiency of thick when pmt exists

% I want the efficiency of thick when pmt exists and thin top exists

% I want the efficiency of thick when pmt exists and thin bot exists

% I want the efficiency of thick when pmt exists and thin top and thin bot exist

% Range masks
% I want the efficiency of thick when pmt is in range

% I want the efficiency of thick when pmt is in range and thin top is in range

% I want the efficiency of thick when pmt is in range and thin bot is in range

% I want the efficiency of thick when pmt is in range and thin bot is in range and thin top is in range

%%

% =====================================================================
% EFFICIENCY CALCULATIONS
% =====================================================================

fprintf('\n========================================\n');
fprintf('EFFICIENCY CALCULATIONS - Run %d\n', run);
fprintf('========================================\n\n');

% Helper function to calculate efficiency
calcEff = @(detector_mask, condition_mask) ...
    100 * sum(detector_mask & condition_mask) / sum(condition_mask);

% -------------------------------------------------------------------------
% THIN TOP EFFICIENCY
% -------------------------------------------------------------------------
fprintf('--- THIN TOP EFFICIENCY ---\n\n');

% Existence masks
fprintf('With EXISTENCE masks:\n');
mask_cond = pmt_exists_Mask;
eff_thinTop_pmtEx = calcEff(thinTop_exists_Mask, mask_cond);
fprintf('  Thin Top when PMT exists: %.2f%% (%d/%d)\n', ...
    eff_thinTop_pmtEx, sum(thinTop_exists_Mask & mask_cond), sum(mask_cond));

mask_cond = pmt_exists_Mask & thick_exists_Mask;
eff_thinTop_pmtEx_thickEx = calcEff(thinTop_exists_Mask, mask_cond);
fprintf('  Thin Top when PMT exists AND Thick exists: %.2f%% (%d/%d)\n', ...
    eff_thinTop_pmtEx_thickEx, sum(thinTop_exists_Mask & mask_cond), sum(mask_cond));

mask_cond = pmt_exists_Mask & thinBot_exists_Mask;
eff_thinTop_pmtEx_thinBotEx = calcEff(thinTop_exists_Mask, mask_cond);
fprintf('  Thin Top when PMT exists AND Thin Bot exists: %.2f%% (%d/%d)\n', ...
    eff_thinTop_pmtEx_thinBotEx, sum(thinTop_exists_Mask & mask_cond), sum(mask_cond));

mask_cond = pmt_exists_Mask & thick_exists_Mask & thinBot_exists_Mask;
eff_thinTop_pmtEx_thickEx_thinBotEx = calcEff(thinTop_exists_Mask, mask_cond);
fprintf('  Thin Top when PMT exists AND Thick exists AND Thin Bot exists: %.2f%% (%d/%d)\n', ...
    eff_thinTop_pmtEx_thickEx_thinBotEx, sum(thinTop_exists_Mask & mask_cond), sum(mask_cond));

% Range masks
fprintf('\nWith RANGE masks:\n');
mask_cond = pmt_range_Mask;
eff_thinTop_pmtRange = calcEff(thinTop_range_Mask, mask_cond);
fprintf('  Thin Top when PMT in range: %.2f%% (%d/%d)\n', ...
    eff_thinTop_pmtRange, sum(thinTop_range_Mask & mask_cond), sum(mask_cond));

mask_cond = pmt_range_Mask & thick_range_Mask;
eff_thinTop_pmtRange_thickRange = calcEff(thinTop_range_Mask, mask_cond);
fprintf('  Thin Top when PMT in range AND Thick in range: %.2f%% (%d/%d)\n', ...
    eff_thinTop_pmtRange_thickRange, sum(thinTop_range_Mask & mask_cond), sum(mask_cond));

mask_cond = pmt_range_Mask & thinBot_range_Mask;
eff_thinTop_pmtRange_thinBotRange = calcEff(thinTop_range_Mask, mask_cond);
fprintf('  Thin Top when PMT in range AND Thin Bot in range: %.2f%% (%d/%d)\n', ...
    eff_thinTop_pmtRange_thinBotRange, sum(thinTop_range_Mask & mask_cond), sum(mask_cond));

mask_cond = pmt_range_Mask & thick_range_Mask & thinBot_range_Mask;
eff_thinTop_pmtRange_thickRange_thinBotRange = calcEff(thinTop_range_Mask, mask_cond);
fprintf('  Thin Top when PMT in range AND Thick in range AND Thin Bot in range: %.2f%% (%d/%d)\n', ...
    eff_thinTop_pmtRange_thickRange_thinBotRange, sum(thinTop_range_Mask & mask_cond), sum(mask_cond));

% -------------------------------------------------------------------------
% THIN BOT EFFICIENCY
% -------------------------------------------------------------------------
fprintf('\n--- THIN BOT EFFICIENCY ---\n\n');

% Existence masks
fprintf('With EXISTENCE masks:\n');
mask_cond = pmt_exists_Mask;
eff_thinBot_pmtEx = calcEff(thinBot_exists_Mask, mask_cond);
fprintf('  Thin Bot when PMT exists: %.2f%% (%d/%d)\n', ...
    eff_thinBot_pmtEx, sum(thinBot_exists_Mask & mask_cond), sum(mask_cond));

mask_cond = pmt_exists_Mask & thick_exists_Mask;
eff_thinBot_pmtEx_thickEx = calcEff(thinBot_exists_Mask, mask_cond);
fprintf('  Thin Bot when PMT exists AND Thick exists: %.2f%% (%d/%d)\n', ...
    eff_thinBot_pmtEx_thickEx, sum(thinBot_exists_Mask & mask_cond), sum(mask_cond));

mask_cond = pmt_exists_Mask & thinTop_exists_Mask;
eff_thinBot_pmtEx_thinTopEx = calcEff(thinBot_exists_Mask, mask_cond);
fprintf('  Thin Bot when PMT exists AND Thin Top exists: %.2f%% (%d/%d)\n', ...
    eff_thinBot_pmtEx_thinTopEx, sum(thinBot_exists_Mask & mask_cond), sum(mask_cond));

mask_cond = pmt_exists_Mask & thick_exists_Mask & thinTop_exists_Mask;
eff_thinBot_pmtEx_thickEx_thinTopEx = calcEff(thinBot_exists_Mask, mask_cond);
fprintf('  Thin Bot when PMT exists AND Thick exists AND Thin Top exists: %.2f%% (%d/%d)\n', ...
    eff_thinBot_pmtEx_thickEx_thinTopEx, sum(thinBot_exists_Mask & mask_cond), sum(mask_cond));

% Range masks
fprintf('\nWith RANGE masks:\n');
mask_cond = pmt_range_Mask;
eff_thinBot_pmtRange = calcEff(thinBot_range_Mask, mask_cond);
fprintf('  Thin Bot when PMT in range: %.2f%% (%d/%d)\n', ...
    eff_thinBot_pmtRange, sum(thinBot_range_Mask & mask_cond), sum(mask_cond));

mask_cond = pmt_range_Mask & thick_range_Mask;
eff_thinBot_pmtRange_thickRange = calcEff(thinBot_range_Mask, mask_cond);
fprintf('  Thin Bot when PMT in range AND Thick in range: %.2f%% (%d/%d)\n', ...
    eff_thinBot_pmtRange_thickRange, sum(thinBot_range_Mask & mask_cond), sum(mask_cond));

mask_cond = pmt_range_Mask & thinTop_range_Mask;
eff_thinBot_pmtRange_thinTopRange = calcEff(thinBot_range_Mask, mask_cond);
fprintf('  Thin Bot when PMT in range AND Thin Top in range: %.2f%% (%d/%d)\n', ...
    eff_thinBot_pmtRange_thinTopRange, sum(thinBot_range_Mask & mask_cond), sum(mask_cond));

mask_cond = pmt_range_Mask & thick_range_Mask & thinTop_range_Mask;
eff_thinBot_pmtRange_thickRange_thinTopRange = calcEff(thinBot_range_Mask, mask_cond);
fprintf('  Thin Bot when PMT in range AND Thick in range AND Thin Top in range: %.2f%% (%d/%d)\n', ...
    eff_thinBot_pmtRange_thickRange_thinTopRange, sum(thinBot_range_Mask & mask_cond), sum(mask_cond));

% -------------------------------------------------------------------------
% THICK EFFICIENCY
% -------------------------------------------------------------------------
fprintf('\n--- THICK EFFICIENCY ---\n\n');

% Existence masks
fprintf('With EXISTENCE masks:\n');
mask_cond = pmt_exists_Mask;
eff_thick_pmtEx = calcEff(thick_exists_Mask, mask_cond);
fprintf('  Thick when PMT exists: %.2f%% (%d/%d)\n', ...
    eff_thick_pmtEx, sum(thick_exists_Mask & mask_cond), sum(mask_cond));

mask_cond = pmt_exists_Mask & thinTop_exists_Mask;
eff_thick_pmtEx_thinTopEx = calcEff(thick_exists_Mask, mask_cond);
fprintf('  Thick when PMT exists AND Thin Top exists: %.2f%% (%d/%d)\n', ...
    eff_thick_pmtEx_thinTopEx, sum(thick_exists_Mask & mask_cond), sum(mask_cond));

mask_cond = pmt_exists_Mask & thinBot_exists_Mask;
eff_thick_pmtEx_thinBotEx = calcEff(thick_exists_Mask, mask_cond);
fprintf('  Thick when PMT exists AND Thin Bot exists: %.2f%% (%d/%d)\n', ...
    eff_thick_pmtEx_thinBotEx, sum(thick_exists_Mask & mask_cond), sum(mask_cond));

mask_cond = pmt_exists_Mask & thinTop_exists_Mask & thinBot_exists_Mask;
eff_thick_pmtEx_thinTopEx_thinBotEx = calcEff(thick_exists_Mask, mask_cond);
fprintf('  Thick when PMT exists AND Thin Top exists AND Thin Bot exists: %.2f%% (%d/%d)\n', ...
    eff_thick_pmtEx_thinTopEx_thinBotEx, sum(thick_exists_Mask & mask_cond), sum(mask_cond));

% Range masks
fprintf('\nWith RANGE masks:\n');
mask_cond = pmt_range_Mask;
eff_thick_pmtRange = calcEff(thick_range_Mask, mask_cond);
fprintf('  Thick when PMT in range: %.2f%% (%d/%d)\n', ...
    eff_thick_pmtRange, sum(thick_range_Mask & mask_cond), sum(mask_cond));

mask_cond = pmt_range_Mask & thinTop_range_Mask;
eff_thick_pmtRange_thinTopRange = calcEff(thick_range_Mask, mask_cond);
fprintf('  Thick when PMT in range AND Thin Top in range: %.2f%% (%d/%d)\n', ...
    eff_thick_pmtRange_thinTopRange, sum(thick_range_Mask & mask_cond), sum(mask_cond));

mask_cond = pmt_range_Mask & thinBot_range_Mask;
eff_thick_pmtRange_thinBotRange = calcEff(thick_range_Mask, mask_cond);
fprintf('  Thick when PMT in range AND Thin Bot in range: %.2f%% (%d/%d)\n', ...
    eff_thick_pmtRange_thinBotRange, sum(thick_range_Mask & mask_cond), sum(mask_cond));

mask_cond = pmt_range_Mask & thinTop_range_Mask & thinBot_range_Mask;
eff_thick_pmtRange_thinTopRange_thinBotRange = calcEff(thick_range_Mask, mask_cond);
fprintf('  Thick when PMT in range AND Thin Top in range AND Thin Bot in range: %.2f%% (%d/%d)\n', ...
    eff_thick_pmtRange_thinTopRange_thinBotRange, sum(thick_range_Mask & mask_cond), sum(mask_cond));

fprintf('\n========================================\n');
fprintf('END OF EFFICIENCY CALCULATIONS\n');
fprintf('========================================\n\n');

% -------------------------------------------------------------------------
% SUMMARY TABLE (optional - create a structured summary)
% -------------------------------------------------------------------------

% Create a summary table for easy viewing
detectorNames = {'Thin Top', 'Thin Bot', 'Thick'};

% Existence mask results
existenceResults = [...
    eff_thinTop_pmtEx, eff_thinTop_pmtEx_thickEx, eff_thinTop_pmtEx_thinBotEx, eff_thinTop_pmtEx_thickEx_thinBotEx; ...
    eff_thinBot_pmtEx, eff_thinBot_pmtEx_thickEx, eff_thinBot_pmtEx_thinTopEx, eff_thinBot_pmtEx_thickEx_thinTopEx; ...
    eff_thick_pmtEx, eff_thick_pmtEx_thinTopEx, eff_thick_pmtEx_thinBotEx, eff_thick_pmtEx_thinTopEx_thinBotEx];

% Range mask results
rangeResults = [...
    eff_thinTop_pmtRange, eff_thinTop_pmtRange_thickRange, eff_thinTop_pmtRange_thinBotRange, eff_thinTop_pmtRange_thickRange_thinBotRange; ...
    eff_thinBot_pmtRange, eff_thinBot_pmtRange_thickRange, eff_thinBot_pmtRange_thinTopRange, eff_thinBot_pmtRange_thickRange_thinTopRange; ...
    eff_thick_pmtRange, eff_thick_pmtRange_thinTopRange, eff_thick_pmtRange_thinBotRange, eff_thick_pmtRange_thinTopRange_thinBotRange];

conditionLabels = {'PMT only', 'PMT + Det1', 'PMT + Det2', 'PMT + Det1 + Det2'};

% Print existence table
fprintf('\n--- EXISTENCE MASK EFFICIENCY SUMMARY (%) ---\n');
fprintf('%-12s', 'Detector');
for i = 1:length(conditionLabels)
    fprintf(' | %-20s', conditionLabels{i});
end
fprintf('\n');
fprintf('%s\n', repmat('-', 1, 100));
for i = 1:length(detectorNames)
    fprintf('%-12s', detectorNames{i});
    for j = 1:size(existenceResults, 2)
        fprintf(' | %20.2f', existenceResults(i,j));
    end
    fprintf('\n');
end

% Print range table
fprintf('\n--- RANGE MASK EFFICIENCY SUMMARY (%) ---\n');
fprintf('%-12s', 'Detector');
for i = 1:length(conditionLabels)
    fprintf(' | %-20s', conditionLabels{i});
end
fprintf('\n');
fprintf('%s\n', repmat('-', 1, 100));
for i = 1:length(detectorNames)
    fprintf('%-12s', detectorNames{i});
    for j = 1:size(rangeResults, 2)
        fprintf(' | %20.2f', rangeResults(i,j));
    end
    fprintf('\n');
end
fprintf('\n');

%%

% =====================================================================
% SAVE EFFICIENCY RESULTS TO CSV
% =====================================================================

% Prepare CSV data with all efficiency calculations
csvData = {};
rowIdx = 1;

% Helper function to add a row
addRow = @(detector, maskType, condition, detected, passed, efficiency) ...
    {detector, maskType, condition, detected, passed, efficiency};

% -------------------------------------------------------------------------
% THIN TOP Efficiencies
% -------------------------------------------------------------------------

% Existence masks
mask_cond = pmt_exists_Mask;
detected = sum(thinTop_exists_Mask & mask_cond);
passed = sum(mask_cond);
csvData(rowIdx,:) = addRow('Thin Top', 'Existence', 'PMT exists', detected, passed, eff_thinTop_pmtEx);
rowIdx = rowIdx + 1;

mask_cond = pmt_exists_Mask & thick_exists_Mask;
detected = sum(thinTop_exists_Mask & mask_cond);
passed = sum(mask_cond);
csvData(rowIdx,:) = addRow('Thin Top', 'Existence', 'PMT exists AND Thick exists', detected, passed, eff_thinTop_pmtEx_thickEx);
rowIdx = rowIdx + 1;

mask_cond = pmt_exists_Mask & thinBot_exists_Mask;
detected = sum(thinTop_exists_Mask & mask_cond);
passed = sum(mask_cond);
csvData(rowIdx,:) = addRow('Thin Top', 'Existence', 'PMT exists AND Thin Bot exists', detected, passed, eff_thinTop_pmtEx_thinBotEx);
rowIdx = rowIdx + 1;

mask_cond = pmt_exists_Mask & thick_exists_Mask & thinBot_exists_Mask;
detected = sum(thinTop_exists_Mask & mask_cond);
passed = sum(mask_cond);
csvData(rowIdx,:) = addRow('Thin Top', 'Existence', 'PMT exists AND Thick exists AND Thin Bot exists', detected, passed, eff_thinTop_pmtEx_thickEx_thinBotEx);
rowIdx = rowIdx + 1;

% Range masks
mask_cond = pmt_range_Mask;
detected = sum(thinTop_range_Mask & mask_cond);
passed = sum(mask_cond);
csvData(rowIdx,:) = addRow('Thin Top', 'Range', 'PMT in range', detected, passed, eff_thinTop_pmtRange);
rowIdx = rowIdx + 1;

mask_cond = pmt_range_Mask & thick_range_Mask;
detected = sum(thinTop_range_Mask & mask_cond);
passed = sum(mask_cond);
csvData(rowIdx,:) = addRow('Thin Top', 'Range', 'PMT in range AND Thick in range', detected, passed, eff_thinTop_pmtRange_thickRange);
rowIdx = rowIdx + 1;

mask_cond = pmt_range_Mask & thinBot_range_Mask;
detected = sum(thinTop_range_Mask & mask_cond);
passed = sum(mask_cond);
csvData(rowIdx,:) = addRow('Thin Top', 'Range', 'PMT in range AND Thin Bot in range', detected, passed, eff_thinTop_pmtRange_thinBotRange);
rowIdx = rowIdx + 1;

mask_cond = pmt_range_Mask & thick_range_Mask & thinBot_range_Mask;
detected = sum(thinTop_range_Mask & mask_cond);
passed = sum(mask_cond);
csvData(rowIdx,:) = addRow('Thin Top', 'Range', 'PMT in range AND Thick in range AND Thin Bot in range', detected, passed, eff_thinTop_pmtRange_thickRange_thinBotRange);
rowIdx = rowIdx + 1;

% -------------------------------------------------------------------------
% THIN BOT Efficiencies
% -------------------------------------------------------------------------

% Existence masks
mask_cond = pmt_exists_Mask;
detected = sum(thinBot_exists_Mask & mask_cond);
passed = sum(mask_cond);
csvData(rowIdx,:) = addRow('Thin Bot', 'Existence', 'PMT exists', detected, passed, eff_thinBot_pmtEx);
rowIdx = rowIdx + 1;

mask_cond = pmt_exists_Mask & thick_exists_Mask;
detected = sum(thinBot_exists_Mask & mask_cond);
passed = sum(mask_cond);
csvData(rowIdx,:) = addRow('Thin Bot', 'Existence', 'PMT exists AND Thick exists', detected, passed, eff_thinBot_pmtEx_thickEx);
rowIdx = rowIdx + 1;

mask_cond = pmt_exists_Mask & thinTop_exists_Mask;
detected = sum(thinBot_exists_Mask & mask_cond);
passed = sum(mask_cond);
csvData(rowIdx,:) = addRow('Thin Bot', 'Existence', 'PMT exists AND Thin Top exists', detected, passed, eff_thinBot_pmtEx_thinTopEx);
rowIdx = rowIdx + 1;

mask_cond = pmt_exists_Mask & thick_exists_Mask & thinTop_exists_Mask;
detected = sum(thinBot_exists_Mask & mask_cond);
passed = sum(mask_cond);
csvData(rowIdx,:) = addRow('Thin Bot', 'Existence', 'PMT exists AND Thick exists AND Thin Top exists', detected, passed, eff_thinBot_pmtEx_thickEx_thinTopEx);
rowIdx = rowIdx + 1;

% Range masks
mask_cond = pmt_range_Mask;
detected = sum(thinBot_range_Mask & mask_cond);
passed = sum(mask_cond);
csvData(rowIdx,:) = addRow('Thin Bot', 'Range', 'PMT in range', detected, passed, eff_thinBot_pmtRange);
rowIdx = rowIdx + 1;

mask_cond = pmt_range_Mask & thick_range_Mask;
detected = sum(thinBot_range_Mask & mask_cond);
passed = sum(mask_cond);
csvData(rowIdx,:) = addRow('Thin Bot', 'Range', 'PMT in range AND Thick in range', detected, passed, eff_thinBot_pmtRange_thickRange);
rowIdx = rowIdx + 1;

mask_cond = pmt_range_Mask & thinTop_range_Mask;
detected = sum(thinBot_range_Mask & mask_cond);
passed = sum(mask_cond);
csvData(rowIdx,:) = addRow('Thin Bot', 'Range', 'PMT in range AND Thin Top in range', detected, passed, eff_thinBot_pmtRange_thinTopRange);
rowIdx = rowIdx + 1;

mask_cond = pmt_range_Mask & thick_range_Mask & thinTop_range_Mask;
detected = sum(thinBot_range_Mask & mask_cond);
passed = sum(mask_cond);
csvData(rowIdx,:) = addRow('Thin Bot', 'Range', 'PMT in range AND Thick in range AND Thin Top in range', detected, passed, eff_thinBot_pmtRange_thickRange_thinTopRange);
rowIdx = rowIdx + 1;

% -------------------------------------------------------------------------
% THICK Efficiencies
% -------------------------------------------------------------------------

% Existence masks
mask_cond = pmt_exists_Mask;
detected = sum(thick_exists_Mask & mask_cond);
passed = sum(mask_cond);
csvData(rowIdx,:) = addRow('Thick', 'Existence', 'PMT exists', detected, passed, eff_thick_pmtEx);
rowIdx = rowIdx + 1;

mask_cond = pmt_exists_Mask & thinTop_exists_Mask;
detected = sum(thick_exists_Mask & mask_cond);
passed = sum(mask_cond);
csvData(rowIdx,:) = addRow('Thick', 'Existence', 'PMT exists AND Thin Top exists', detected, passed, eff_thick_pmtEx_thinTopEx);
rowIdx = rowIdx + 1;

mask_cond = pmt_exists_Mask & thinBot_exists_Mask;
detected = sum(thick_exists_Mask & mask_cond);
passed = sum(mask_cond);
csvData(rowIdx,:) = addRow('Thick', 'Existence', 'PMT exists AND Thin Bot exists', detected, passed, eff_thick_pmtEx_thinBotEx);
rowIdx = rowIdx + 1;

mask_cond = pmt_exists_Mask & thinTop_exists_Mask & thinBot_exists_Mask;
detected = sum(thick_exists_Mask & mask_cond);
passed = sum(mask_cond);
csvData(rowIdx,:) = addRow('Thick', 'Existence', 'PMT exists AND Thin Top exists AND Thin Bot exists', detected, passed, eff_thick_pmtEx_thinTopEx_thinBotEx);
rowIdx = rowIdx + 1;

% Range masks
mask_cond = pmt_range_Mask;
detected = sum(thick_range_Mask & mask_cond);
passed = sum(mask_cond);
csvData(rowIdx,:) = addRow('Thick', 'Range', 'PMT in range', detected, passed, eff_thick_pmtRange);
rowIdx = rowIdx + 1;

mask_cond = pmt_range_Mask & thinTop_range_Mask;
detected = sum(thick_range_Mask & mask_cond);
passed = sum(mask_cond);
csvData(rowIdx,:) = addRow('Thick', 'Range', 'PMT in range AND Thin Top in range', detected, passed, eff_thick_pmtRange_thinTopRange);
rowIdx = rowIdx + 1;

mask_cond = pmt_range_Mask & thinBot_range_Mask;
detected = sum(thick_range_Mask & mask_cond);
passed = sum(mask_cond);
csvData(rowIdx,:) = addRow('Thick', 'Range', 'PMT in range AND Thin Bot in range', detected, passed, eff_thick_pmtRange_thinBotRange);
rowIdx = rowIdx + 1;

mask_cond = pmt_range_Mask & thinTop_range_Mask & thinBot_range_Mask;
detected = sum(thick_range_Mask & mask_cond);
passed = sum(mask_cond);
csvData(rowIdx,:) = addRow('Thick', 'Range', 'PMT in range AND Thin Top in range AND Thin Bot in range', detected, passed, eff_thick_pmtRange_thinTopRange_thinBotRange);
rowIdx = rowIdx + 1;

% -------------------------------------------------------------------------
% Write to CSV file
% -------------------------------------------------------------------------

outputFileName = sprintf('efficiency_summary_run_%d.csv', run);
outputFilePath = [HOME SCRIPTS outputFileName];

% Create table with proper column names
T = cell2table(csvData, 'VariableNames', {'Detector', 'MaskType', 'Condition', 'Detected', 'Passed', 'Efficiency_Percent'});

% Write table to CSV
writetable(T, outputFilePath);

fprintf('\n=====================================================\n');
fprintf('Efficiency summary saved to: %s\n', outputFilePath);
fprintf('=====================================================\n\n');

if save_plots
    try
        if ~exist(save_plots_dir, 'dir')
            mkdir(save_plots_dir);
        end
        [pdfPath, figCount] = save_all_figures_to_pdf(save_plots_dir);
        if figCount > 0 && ~isempty(pdfPath)
            fprintf('Saved %d figure(s) to %s\n', figCount, pdfPath);
        else
            fprintf('No figures generated to save.\n');
        end
    catch saveErr
        warning('Failed to save figures: %s', saveErr.message);
    end
end

%% ------------------------------------------------------------------------
% Local functions
%% ------------------------------------------------------------------------
function [pdfPath, figCount] = save_all_figures_to_pdf(targetDir)
%SAVE_ALL_FIGURES_TO_PDF Export all open figures into a single rasterized PDF.
    figs = findall(0, 'Type', 'figure');
    figCount = numel(figs);
    pdfPath = '';

    if figCount == 0
        return;
    end

    [~, sortIdx] = sort([figs.Number]);
    figs = figs(sortIdx);

    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    pdfPath = fullfile(targetDir, sprintf('caye_plots_%s.pdf', timestamp));

    if exist(pdfPath, 'file')
        delete(pdfPath);
    end

    opts = {'ContentType','image','Resolution',300};
    firstPage = true;

    for k = 1:figCount
        fig = figs(k);
        if firstPage
            exportgraphics(fig, pdfPath, opts{:});
            firstPage = false;
        else
            exportgraphics(fig, pdfPath, opts{:}, 'Append', true);
        end
        close(fig);
    end
end
