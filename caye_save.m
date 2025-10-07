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
    %run with all 4 scintillators
    load([HOME SCRIPTS DATA 'dabc25120133744-dabc25126121423_a003_T.mat']) 
    load([HOME SCRIPTS DATA_Q 'dabc25120133744-dabc25126121423_a004_Q.mat'])
elseif run == 2;
    load([HOME SCRIPTS DATA 'dabc25127151027-dabc25147011139_a001_T.mat']) % run com HV de cima desligada
    % run with the top HV switched off
    load([HOME SCRIPTS DATA 'dabc25127151027-dabc25147011139_a003_T.mat'])
    load([HOME SCRIPTS DATA_Q 'dabc25127151027-dabc25147011139_a004_Q.mat'])
elseif run == 3;
    load([HOME SCRIPTS DATA 'dabc25127151027-dabc25160092400_a001_T.mat']) % run com HV de cima desligada
    % run with the top HV switched off
    load([HOME SCRIPTS DATA 'dabc25127151027-dabc25160092400_a003_T.mat'])
    load([HOME SCRIPTS DATA_Q 'dabc25127151027-dabc25160092400_a004_Q.mat'])
end

% print the variables in the workspace
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

%leading times front [ns]; channels [32,28] -> 5 wide front strips
TFl = [l31 l32 l30 l28 l29];    %tempos leadings  front [ns]; chs [32,28] -> 5 strips gordas front

%trailing times front [ns]
TFt = [t31 t32 t30 t28 t29];    %tempos trailings front [ns]

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

% Total number of triggered events available in the loaded files.
events=size(EventPerFile,1);

whos


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
subplot(3,2,1); plot(Qcint(:,1), Qcint(:,2), '.'); xlabel('Qcint1'); ylabel('Qcint2'); title(sprintf('Charge PMT1 vs PMT2 (run %d)', run));
subplot(3,2,2); plot(Qcint(:,1), Qcint(:,3), '.'); xlabel('Qcint1'); ylabel('Qcint3'); title(sprintf('Charge PMT1 vs PMT3 (run %d)', run));
subplot(3,2,3); plot(Qcint(:,1), Qcint(:,4), '.'); xlabel('Qcint1'); ylabel('Qcint4'); title(sprintf('Charge PMT1 vs PMT4 (run %d)', run));
subplot(3,2,4); plot(Qcint(:,2), Qcint(:,3), '.'); xlabel('Qcint2'); ylabel('Qcint3'); title(sprintf('Charge PMT2 vs PMT3 (run %d)', run));
subplot(3,2,5); plot(Qcint(:,2), Qcint(:,4), '.'); xlabel('Qcint2'); ylabel('Qcint4'); title(sprintf('Charge PMT2 vs PMT4 (run %d)', run));
subplot(3,2,6); plot(Qcint(:,3), Qcint(:,4), '.'); xlabel('Qcint3'); ylabel('Qcint4'); title(sprintf('Charge PMT3 vs PMT4 (run %d)', run));
sgtitle(sprintf('PMT charge coincidences (run %d)', run));

figure;
subplot(3,2,1); plot(Tl_cint(:,1), Tl_cint(:,2),'.'); xlabel('Tl_cint1'); ylabel('Tl_cint2'); title(sprintf('Time lead PMT1 vs PMT2 (run %d)', run));
xlim([min(min(Tl_cint)) max(max(Tl_cint))]); ylim([min(min(Tl_cint)) max(max(Tl_cint))]);
subplot(3,2,2); plot(Tl_cint(:,1), Tl_cint(:,3),'.'); xlabel('Tl_cint1'); ylabel('Tl_cint3'); title(sprintf('Time lead PMT1 vs PMT3 (run %d)', run));
xlim([min(min(Tl_cint)) max(max(Tl_cint))]); ylim([min(min(Tl_cint)) max(max(Tl_cint))]);
subplot(3,2,3); plot(Tl_cint(:,1), Tl_cint(:,4),'.'); xlabel('Tl_cint1'); ylabel('Tl_cint4'); title(sprintf('Time lead PMT1 vs PMT4 (run %d)', run));
xlim([min(min(Tl_cint)) max(max(Tl_cint))]); ylim([min(min(Tl_cint)) max(max(Tl_cint))]);
subplot(3,2,4); plot(Tl_cint(:,2), Tl_cint(:,3),'.'); xlabel('Tl_cint2'); ylabel('Tl_cint3'); title(sprintf('Time lead PMT2 vs PMT3 (run %d)', run));
xlim([min(min(Tl_cint)) max(max(Tl_cint))]); ylim([min(min(Tl_cint)) max(max(Tl_cint))]);
subplot(3,2,5); plot(Tl_cint(:,2), Tl_cint(:,4),'.'); xlabel('Tl_cint2'); ylabel('Tl_cint4'); title(sprintf('Time lead PMT2 vs PMT4 (run %d)', run));
xlim([min(min(Tl_cint)) max(max(Tl_cint))]); ylim([min(min(Tl_cint)) max(max(Tl_cint))]);
subplot(3,2,6); plot(Tl_cint(:,3), Tl_cint(:,4),'.'); xlabel('Tl_cint3'); ylabel('Tl_cint4'); title(sprintf('Time lead PMT3 vs PMT4 (run %d)', run));
xlim([min(min(Tl_cint)) max(max(Tl_cint))]); ylim([min(min(Tl_cint)) max(max(Tl_cint))]);
sgtitle(sprintf('PMT time coincidences (run %d)', run));


% -----------------------------------------------------------------------------
% RPC wide strip Timing and Charge Derivations
% -----------------------------------------------------------------------------

%leading times front [ns]; channels [32,28] -> 5 wide front strips
% TFl, TBl, QF, QB

% Similar scatter subplot plots for the wide strips to verify no obvious problems.

figure;
subplot(1,5,1); plot(TFl(:,1), TBl(:,1),'.'); xlabel('TFl'); ylabel('TBl'); title(sprintf('Time lead Front vs back strip1 (run %d)', run));
xlim([min(min(TFl)) max(max(TFl))]); ylim([min(min(TBl)) max(max(TBl))]);
subplot(1,5,2); plot(TFl(:,2), TBl(:,2),'.'); xlabel('TFl'); ylabel('TBl'); title(sprintf('Time lead Front vs back strip2 (run %d)', run));
xlim([min(min(TFl)) max(max(TFl))]); ylim([min(min(TBl)) max(max(TBl))]);
subplot(1,5,3); plot(TFl(:,3), TBl(:,3),'.'); xlabel('TFl'); ylabel('TBl'); title(sprintf('Time lead Front vs back strip3 (run %d)', run));
xlim([min(min(TFl)) max(max(TFl))]); ylim([min(min(TBl)) max(max(TBl))]);
subplot(1,5,4); plot(TFl(:,4), TBl(:,4),'.'); xlabel('TFl'); ylabel('TBl'); title(sprintf('Time lead Front vs back strip4 (run %d)', run));
xlim([min(min(TFl)) max(max(TFl))]); ylim([min(min(TBl)) max(max(TBl))]);
subplot(1,5,5); plot(TFl(:,5), TBl(:,5),'.'); xlabel('TFl'); ylabel('TBl'); title(sprintf('Time lead Front vs back strip5 (run %d)', run));
xlim([min(min(TFl)) max(max(TFl))]); ylim([min(min(TBl)) max(max(TBl))]);
sgtitle(sprintf('Thick strip time front vs back (run %d)', run));

figure;
subplot(1,5,1); plot(QF(:,1), QB(:,1),'.'); xlabel('QF'); ylabel('QB'); title(sprintf('Charge Front vs back strip1 (run %d)', run));
xlim([min(min(QF)) max(max(QF))]); ylim([min(min(QB)) max(max(QB))]);
subplot(1,5,2); plot(QF(:,2), QB(:,2),'.'); xlabel('QF'); ylabel('QB'); title(sprintf('Charge Front vs back strip2 (run %d)', run));
xlim([min(min(QF)) max(max(QF))]); ylim([min(min(QB)) max(max(QB))]);
subplot(1,5,3); plot(QF(:,3), QB(:,3),'.'); xlabel('QF'); ylabel('QB'); title(sprintf('Charge Front vs back strip3 (run %d)', run));
xlim([min(min(QF)) max(max(QF))]); ylim([min(min(QB)) max(max(QB))]);
subplot(1,5,4); plot(QF(:,4), QB(:,4),'.'); xlabel('QF'); ylabel('QB'); title(sprintf('Charge Front vs back strip4 (run %d)', run));
xlim([min(min(QF)) max(max(QF))]); ylim([min(min(QB)) max(max(QB))]);
subplot(1,5,5); plot(QF(:,5), QB(:,5),'.'); xlabel('QF'); ylabel('QB'); title(sprintf('Charge Front vs back strip5 (run %d)', run));
xlim([min(min(QF)) max(max(QF))]); ylim([min(min(QB)) max(max(QB))]);
sgtitle(sprintf('Thick strip charge front vs back (run %d)', run));


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

right_lim_q_wide = 50; %adjust as needed

figure;
for strip = 1:5
    % Left column: uncalibrated
    subplot(5,2,strip*2-1);
    histf(QF(:,strip),-2:0.1:150); hold on;
    histf(QB(:,strip),-2:0.1:150); xlim([-2 150]);
    legend(sprintf('QF - strip%d', strip), sprintf('QB - strip%d', strip), 'Location', 'northeast');
    ylabel('# of events');
    xlabel('Q [ns]');
    % Right column: calibrated
    subplot(5,2,strip*2);
    histf(QF_p(:,strip), -2:0.1:right_lim_q_wide); hold on;
    histf(QB_p(:,strip), -2:0.1:right_lim_q_wide);
    xlim([-2 right_lim_q_wide]);
    legend(sprintf('QF - strip%d', strip), sprintf('QB - strip%d', strip), 'Location', 'northeast');
    ylabel('# of events');
    xlabel('Q [ns]');
end


% Event-Level Maximum Charge Aggregation

% calculation of maximum charges and RAW position as a function of Qmax

[QFmax,XFmax] = max(QF_p,[],2);    %XFmax -> strip of Qmax
[QBmax,XBmax] = max(QB_p,[],2);

% Keep only events where the strip with maximum charge matches on both faces
% and use those indices to compute representative timing/charge observables.

Ind2Cut   = find(~isnan(QF_p) & ~isnan(QB_p) & XFmax == XBmax);
[row,col] = ind2sub(size(TFl),Ind2Cut); %row=evento com Qmax na mesma strip; col=strip não interessa pois fica-se com a strip com Qmax

%row = event with Qmax in the same strip; col = strip not needed because we keep the strip with Qmax
rows      = unique(row); %events sorted and without repetitions
Ind2Keep  = sub2ind(size(TFl),rows,XFmax(rows)); %indices of the Qmax values, provided QFmax and QBmax are on the same strip

T = nan(rawEvents,1); Q = nan(rawEvents,1); X = nan(rawEvents,1); Y = nan(rawEvents,1);
T(rows) = (TFl(Ind2Keep) + TBl(Ind2Keep)) / 2; %[ns]
Q(rows) = (QF_p(Ind2Keep) + QB_p(Ind2Keep)) /2;    %[ns] sum of Qmax front and back -> contains NaNs if an event fails the Ind2Keep condition
X(rows) = XFmax(rows);  %strip number where Qmax is found (1 to 5)
Y(rows) = (TFl(Ind2Keep) - TBl(Ind2Keep)) / 2; %[ns]

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

% Sum charge over all thin strips (bottom/top) to estimate RPC efficiency
% using simple activity thresholds.

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


% one way to calculate the RPC efficiency: the PMTs fired but the RPC saw nothing, so the charge sum per event 
% (Q spectrum) should be very close to zero
% look at the top and bottom charge spectra and decide the threshold that means no charge or not seen (there
% is an initial peak); 600 is too low -> gives Eff=5% with HV=0 kV

% lower bound of the charge sum on the 24 strips; 700 or 800; for multiplicity use threshold = 100 because 
% it is a per-strip charge limit

%%

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
plot(q_strip_threshold_values, eff_bottom_values, '-o', 'DisplayName', 'Bottom');
hold on;
plot(q_strip_threshold_values, eff_top_values, '-o', 'DisplayName', 'Top');
xlabel('Q Threshold');
ylabel('Efficiency [%]');
title(sprintf('Efficiency vs Q Threshold (run %d)', run));

%%

% loop on q_threshold and plot efficiency vs q_threshold
q_strip_threshold_values = 4000:100:15000; % example range, adjust as needed
q_pmt_threshold_values = 0:1:250; % example range, adjust as needed
eff_bottom_values = zeros(length(q_pmt_threshold_values), length(q_strip_threshold_values));
eff_top_values = zeros(length(q_pmt_threshold_values), length(q_strip_threshold_values));
for i = 1:length(q_strip_threshold_values)
    for j = 1:length(q_pmt_threshold_values)
        q_threshold = q_strip_threshold_values(i);
        q_pmt_threshold = q_pmt_threshold_values(j);

        restrictionsForPMTs_test = Qcint_sum_bot > q_pmt_threshold & Qcint_sum_top > q_pmt_threshold;
        indicesGoodEvents_test = find(restrictionsForPMTs_test);
        ChargePerEvent_b_goodEventsOnly= ChargePerEvent_b(indicesGoodEvents_test);
        ChargePerEvent_t_goodEventsOnly= ChargePerEvent_t(indicesGoodEvents_test);

        I_b = find(ChargePerEvent_b_goodEventsOnly < q_threshold);
        eff_bottom_values(j, i) = 100*(1-(size(I_b,1)/events));

        I_t = find(ChargePerEvent_t_goodEventsOnly < q_threshold);
        eff_top_values(j, i) = 100*(1-(size(I_t,1)/events));
    end
end

figure;
[X, Y] = meshgrid(q_strip_threshold_values, q_pmt_threshold_values);
subplot(1,2,1);
contourf(X, Y, eff_bottom_values, 20); colorbar;
xlabel('Strip Q Threshold');
ylabel('PMT Q Threshold');
title(sprintf('Bottom Efficiency (run %d)', run));
subplot(1,2,2);
contourf(X, Y, eff_top_values, 20); colorbar;
xlabel('Strip Q Threshold');
ylabel('PMT Q Threshold');
title(sprintf('Top Efficiency (run %d)', run));
legend show;

%%

figure;
subplot(1,2,1);
surf(X, Y, eff_bottom_values, 'EdgeColor', 'none');
xlabel('Strip Q Threshold');
ylabel('PMT Q Threshold');
zlabel('Efficiency [%]');
title(sprintf('Bottom Efficiency (run %d)', run));
colorbar;
view(45,30);

subplot(1,2,2);
surf(X, Y, eff_top_values, 'EdgeColor', 'none');
xlabel('Strip Q Threshold');
ylabel('PMT Q Threshold');
zlabel('Efficiency [%]');
title(sprintf('Top Efficiency (run %d)', run));
colorbar;
view(45,30);

%%

% ---------------------------------------------------------------------
% ---------------------------------------------------------------------
% Combined PMT/RPC Efficiency Calculation
% ---------------------------------------------------------------------
% ---------------------------------------------------------------------

% EFFICIENCY restricting with certain constraints on PMTs and RPCs
% Detectors to restrict:
% 1. Top PMT
% 2. Bottom PMT
% 3. Thick RPC strips
% 4. Top Thin RPC strips
% 5. Bottom Thin RPC strips

% PMT
% Time
tTH = 4; %time threshold [ns] to assume it comes from a good event; obriga a ter tempos nos 4 cint
% Charge
top_pmt_charge_threshold = 20; %ADCbins
bot_pmt_charge_threshold = 20; %ADCbins

% RPC
% Thick strip charge
thick_strip_charge_threshold = 4000; %ADCbins
% Thin strip charge (per strip)
top_narrow_strip_charge_threshold = 100; %ADCbins per strip
bot_narrow_strip_charge_threshold = 100; %ADCbins per strip

% Restrictions on PMTs
time_restrictionsForPMTs = abs(Tl_cint(:,1)-Tl_cint(:,2)) < tTH & ...
                      abs(Tl_cint(:,1)-Tl_cint(:,3)) < tTH & ...
                      abs(Tl_cint(:,1)-Tl_cint(:,4)) < tTH & ...
                      abs(Tl_cint(:,2)-Tl_cint(:,3)) < tTH & ...
                      abs(Tl_cint(:,2)-Tl_cint(:,4)) < tTH & ...
                      abs(Tl_cint(:,3)-Tl_cint(:,4)) < tTH;
top_charge_restrictionsForPMTs = Qcint_sum_top >= top_pmt_charge_threshold;
bot_charge_restrictionsForPMTs = Qcint_sum_bot >= bot_pmt_charge_threshold;
charge_restrictionsForPMTs = bot_charge_restrictionsForPMTs & top_charge_restrictionsForPMTs;
restrictionsForPMTs = time_restrictionsForPMTs & charge_restrictionsForPMTs; %time and charge restrictions

% Restrictions on THICK RPC STRIPS
restrictionsForThickRPC = any(Q > thick_strip_charge_threshold, 2); %at least 4000 ADCbins in the sum of Qmax front and back
restrictionsForThickRPC = restrictionsForThickRPC & ~isnan(Q); %Q contains NaNs if the event fails the Ind2Keep condition (Qmax not in the same strip front and back)
% Restrictions on THIN RPC STRIPS
restrictionsForTopRPC  = any(ChargePerEvent_t >= top_narrow_strip_charge_threshold, 2);
restrictionsForBotRPC  = any(ChargePerEvent_b >= bot_narrow_strip_charge_threshold, 2);
restrictionsForThinRPC  = restrictionsForTopRPC & restrictionsForBotRPC;
% Joined RPC restrictions
restrictionsForRPC = restrictionsForThickRPC & restrictionsForThinRPC;

restrictions = restrictionsForPMTs & restrictionsForRPC;

numberGoodEvents    = length(find(restrictionsForPMTs));
numberSeenEvents    = sum(restrictionsForPMTs & restrictionsForRPC); % require being seen by PMTs because there are SiPM triggers seen by the RPCs as well

Eff = numberSeenEvents * 100 / numberGoodEvents; %numberGoodEvents or rawEvents

% print efficiency
fprintf('Number of seen events (PMT coincidence + PMT charge + RPC charge): %d out of %d (%.2f%%)\n', numberSeenEvents, numberGoodEvents, Eff);



%%

% ---------------------------------------------------------------------
% Events Seen by PMTs but Missed by the RPC
% ---------------------------------------------------------------------

% events not seen by the RPC

% Visualise charge recorded on thin strips for PMT-tagged events where the
% RPC showed no activity (helps to tune thresholds).
indices_not_seen = find(restrictionsForPMTs & ~restrictionsForRPC);
Qb_not_seen = ChargePerEvent_b(indices_not_seen);
Qt_not_seen = ChargePerEvent_t(indices_not_seen);

figure;
histogram(Qb_not_seen, 0:200:5E4); hold on;
histogram(Qt_not_seen, 0:200:5E4);
xlabel('Qb ');
ylabel('# of events');
title(sprintf('Espetro de carga nas strips finas (baixo) para eventos não vistos pela RPC (run %d)', run));
legend('Qb not seen by RPC', 'Qt not seen by RPC');

%%



% I want you to calculate the efficiency 




%%

% ---------------------------------------------------------------------
% Time Resolution Studies
% ---------------------------------------------------------------------

% Select the central region of each PMT charge distribution to focus on good
% signals before computing timing resolution.

%HISTOGRAM OF Qcint FOR EACH PMT AND EVENT SELECTION FOR TIME RESOLUTION - keep only the central peak in the charge matrices
X_T_min = [94 101  146 95];
X_T_max = [103 120 180 107];

first = 1; last = 4;
figure
for pmt=first:last
    subplot(2,2,pmt);
    histogram(Qcint(:,pmt),75:1:275); hold on;
    temp = Qcint(:,pmt); temp(find( Qcint(:,pmt) > X_T_max(pmt) )) = nan; Qcint(:,pmt) = temp;
    temp = Qcint(:,pmt); temp(find( Qcint(:,pmt) < X_T_min(pmt) )) = nan; Qcint(:,pmt) = temp;
    histogram(Qcint(:,pmt),-2:1:300); legend(sprintf('Q - PMT%d', pmt), sprintf('Q - PMT%d selection', pmt), 'Location', 'northeast')
    xlim([70 280]); %ylim([0 1500]);
end
sgtitle(sprintf('PMT charge spectra and selection (run %d)', run));

%return

%%

% ------------------------------------------------------------------
% ------------------------------------------------------------------
% Data Cleaning Prior to Slewing Corrections
% ------------------------------------------------------------------
% ------------------------------------------------------------------

% Remove any event with missing values so that polynomial fits and slewing
% corrections downstream have fully populated rows.

% remove events with at least one NaN; by using Qcint we enforce times in all 4 PMTs, same as 'restrictionsForPMTs' in the efficiency, Q refers to the RPC side

% using the slewing correction, polyfit cannot contain NaNs

I_toRemoveLines = any(isnan(Qcint),2) | any(isnan(Q), 2); %row=1 if the event has at least one column with a nan
Qcint(I_toRemoveLines,:)          = [];
Tcint_mean_bot(I_toRemoveLines,:) = [];
Tcint_mean_top(I_toRemoveLines,:) = [];
Qcint_sum_bot(I_toRemoveLines,:)  = [];
Qcint_sum_top(I_toRemoveLines,:)  = [];
Q(I_toRemoveLines,:)              = [];
T(I_toRemoveLines,:)              = [];
X(I_toRemoveLines,:)              = []; %para os plots 2D mais abaixo
Y(I_toRemoveLines,:)              = []; %para os plots 2D mais abaixo
QB_p(I_toRemoveLines,:)           = []; %se usarmos o EventDisplayer mais abaixo
QF_p(I_toRemoveLines,:)           = []; %se usarmos o EventDisplayer mais abaixo
TFl(I_toRemoveLines,:)            = []; %se usarmos o EventDisplayer mais abaixo
TBl(I_toRemoveLines,:)            = []; %se usarmos o EventDisplayer mais abaixo
Tl_cint(I_toRemoveLines,:)        = []; %se usarmos o EventDisplayer mais abaixo

%%

% ------------------------------------------------------------------
% Raw Time-Difference Analysis (No Slewing Correction)
% ------------------------------------------------------------------

% Compute the raw timing difference between scintillators and the RPC before
% any slewing correction, then fit the distribution with a Gaussian model.

% RESOLUÇÃO TEMPORAL SEM SLEWING CORRECTION -> tempo_cintiladores - tempo_RPC ou tempo_cintiladores_bottom - tempo_cintiladores_top
% TIME RESOLUTION WITHOUT SLEWING CORRECTION -> scintillator time minus RPC time or bottom minus top scintillator time
tempo1 = Tcint_mean_top;    %Tcint_mean_bot ou Tcint_mean_top
tempo2 = T;                 %T para a RPC; para os cint: Tcint_mean_bot ou Tcint_mean_top
Tdiff  = [tempo1 - tempo2]; %[ns];
figure; histogram(Tdiff, 0:0.05:20);xlabel('Tdiff [ns]'); ylabel('# of events'); title(sprintf('TcintBottom - Trpc (run %d)', run));



% if necessary impose boundaries on Tdiff so the fit succeeds with bestFit.m:
% Tdiff(find((Tdiff < 12.5) | (Tdiff > 14.5))) = nan; %sigma 1 bot
% sets Tdiff to NaN outside 12.5-14.5 ns for sigma 1 on the bottom
Tdiff(find((Tdiff < 11) | (Tdiff > 12.1))) = nan; %sigma 2
% Tdiff(find((Tdiff < -2.7) | (Tdiff > -1.2))) = nan; %sigma 3
% sets Tdiff to NaN outside -2.7 to -1.2 ns for sigma 3
% Tdiff(find((Tdiff < 1.2) | (Tdiff > 2.7))) = nan;
% sets Tdiff to NaN outside 1.2 to 2.7 ns
% figure; histogram(Tdiff);
% plot the histogram of Tdiff

%search the best gaussian fit of the distribution:
binningRule = 1;    %1 -> use RICE rule; 2 -> use SCOTT rule; 3 -> use STURGES rule
distToFit = Tdiff;
[x_min,x_max,chi_sq, number_bins] = bestFit(distToFit, 2.0, 1.2, binningRule);    %e.g.: bestFit(distToFit, 2, 0.8, 1); (dist, extSigmaBound, intSigmaBound, binningRule)
%chi_sq não é usado mas permite comparar com chisq obtido mais abaixo com hfitg_altJPS; chi_sq e chisq têm de ser iguais
%chi_sq is not used but allows comparison with the chisq obtained below with hfitg_altJPS; chi_sq and chisq must match
%x_min=0.5; x_max=1.5; number_bins=45; %forçar valores em vez de bestFit
%x_min=0.5; x_max=1.5; number_bins=45; %force values instead of using bestFit
%plot the gaussian fit:

distToFit_limited = distToFit;
distToFit_limited(find(distToFit > x_max)) = nan;    %don't use 0 or it will appear in the histogram!
distToFit_limited(find(distToFit < x_min)) = nan;
events_limited = nnz(~isnan(distToFit_limited));    %number of nonzero (here non NANs) elements
x_bin=abs(x_max-x_min)/number_bins;
figure; histogram(distToFit_limited, x_min:x_bin:x_max, 'FaceAlpha',0.7, 'FaceColor','0.00,0.45,0.74'); hold on;
[ny,nx] = histf(distToFit_limited, x_min:x_bin:x_max);
[pars,chisq] = hfitg_altJPS(nx,ny,2); hold on;
histogram(distToFit, x_min-x_bin*number_bins:x_bin:x_max+x_bin*number_bins, 'FaceAlpha',0.3, 'FaceColor','0.00,0.45,0.74');
ndf=length(find (ny > 0)); ndf=ndf-3;    %3 -> miu, sigma e max do hist; ndf é o nº de pontos usado para o fit logo neste caso é o nº de bins
message = sprintf('n = %d\n\\mu =  %.3f ns\n\\sigma = %.3f ns\n\\chi²/ndf = %.1f/%d', events_limited, pars(1), abs(pars(2)), chisq, ndf); %modulo do sigma pois hfitg pode resultar num valor neg -> ver mais abaixo explicação
%absolute value of sigma because hfitg can give a negative result -> see explanation below
yl = ylim; % Get limits of y axis so we can find a nice height for the text labels.
text(pars(1)+abs(pars(2)), 0.8 * yl(2), message, 'Color', 'r', 'FontSize', 12); %pode obter-se sigmas negativos com hfitg mas o módulo está correto; vê-se tb sigmas negativos mesmo centrando a dist primeiro)
%hfitg may yield negative sigmas but the absolute value is correct; negative sigmas appear even after centering the distribution first
xlabel('Tdiff [ns]','FontSize',14,'Color','k'); ylabel('# of events','FontSize',14,'Color','k'); title(sprintf('TcintBottom - Trpc; gaussian fit (borders: %.3f -> %.3f) (run %d)', x_min, x_max, run));
xlim([x_min-x_bin*number_bins x_max+x_bin*number_bins]);
%FWHM=2.355*pars(2)/sqrt(2)    %for T=T1-T2

%return

% ------------------------------------------------------------------
% ------------------------------------------------------------------
% Slewing-Corrected Time Resolution
% ------------------------------------------------------------------
% ------------------------------------------------------------------

% Apply a two-stage slewing correction (first with PMT charges, then with RPC
% charge) and evaluate the improved timing resolution.
%RESOLUÇÃO TEMPORAL COM SLEWING CORRECTION -> tempo_cintiladores - tempo_RPC ou tempo_cintiladores_bottom - tempo_cintiladores_top
%TIME RESOLUTION WITH SLEWING CORRECTION -> scintillator time minus RPC time or bottom minus top scintillator time
tempo1 = Tcint_mean_top;    %Tcint_mean_bot ou Tcint_mean_top
%Tcint_mean_bot or Tcint_mean_top
tempo2 = T;                 %T para a RPC; para os cint: Tcint_mean_bot ou Tcint_mean_top
%T for the RPC; for the scintillators: Tcint_mean_bot or Tcint_mean_top
Tdiff  = [tempo1 - tempo2]; %[ns];
carga1 = Qcint_sum_top;     %Qcint_sum_bot ou Qcint_sum_top
%Qcint_sum_bot or Qcint_sum_top
carga2 = Q;                 %Q para a RPC; para os cint: Qcint_sum_bot ou Qcint_sum_top
%Q for the RPC; for the scintillators: Qcint_sum_bot or Qcint_sum_top
%figure; histogram(Tdiff);


%se for necessário impor boundaries a Tdiff para o fit ser bem sucedido com bestFit.m:
%if it is necessary to impose boundaries on Tdiff for the bestFit.m fit to succeed:

%Tdiff(find((Tdiff < 12.5) | (Tdiff > 14.5))) = nan; %sigma 1
%sets Tdiff to NaN outside 12.5-14.5 ns for sigma 1
Tdiff(find((Tdiff < 11) | (Tdiff > 12.1))) = nan; %sigma 2
%Tdiff(find((Tdiff < -2.7) | (Tdiff > -1.2))) = nan; %sigma 3
%sets Tdiff to NaN outside -2.7 to -1.2 ns for sigma 3
%Tdiff(find((Tdiff < 1.2) | (Tdiff > 2.7))) = nan;
%sets Tdiff to NaN outside 1.2 to 2.7 ns
%com a slewing corr, as matrizes em polyfit (script FitAndPlot.m) não podem ter nans:
%with the slewing correction, the matrices used in polyfit (script FitAndPlot.m) cannot have NaNs
I_toRemoveLines = any(isnan(Tdiff),2); %row=1 if the event has at least one column with a nan
Tdiff(I_toRemoveLines,:)  = [];
carga1(I_toRemoveLines,:) = [];
carga2(I_toRemoveLines,:) = [];
%figure; histogram(Tdiff);
%%}
%%%%%%%%%%%%%%%%%%
%Time vs. Qbottom:
figure; plot(carga1, Tdiff, '.'); xlim([0 max(carga1)+50]); ylabel('Time [ns]'); xlabel('Charge [ns]'); title('Time (Tcint\_mean\_bot-T\_rpc) vs. Q (Qcint\_sum\_bot)');
%fit1:
Tfited_bottom = FitAndPlot(carga1, Tdiff, 2, 1);    %FitAndPlot arguments: Q, T, polynomialDegree, showPlots(0/1); adapted from stratos
%Time_corrected1 vs. Qbottom:
figure; plot(carga2, Tfited_bottom, '.'); xlim([0 max(carga2)+50]); ylabel('Time fited_bottom [ns]'); xlabel('Charge [ns]'); title('Time fited\_bottom vs. Qtop (mean(Qt3,Qt4))');
%fit2:
Tfited_topAndBottom = FitAndPlot(carga2, Tfited_bottom, 2, 1);    %FitAndPlot arguments: Q, T, polynomialDegree, showPlots(0/1); adapted from stratos
%%%%%%%%%%%%%%%%%%
%search the best gaussian fit to the corrected distribution:
binningRule = 3;    %1 -> use RICE rule; 2 -> use SCOTT rule; 3 -> use STURGES rule
distToFit = Tfited_topAndBottom;
[x_min,x_max,chi_sq, number_bins] = bestFit(distToFit, 2.0, 1.2, binningRule);    %e.g.: bestFit(distToFit, 2, 0.8, 1); (dist, extSigmaBound, intSigmaBound, binningRule)
%plot the gaussian fit:
distToFit_limited = distToFit;
distToFit_limited(find(distToFit > x_max)) = nan;    %don't use 0 or it will appear in the histogram!
distToFit_limited(find(distToFit < x_min)) = nan;
events_limited = nnz(~isnan(distToFit_limited));    %number of nonzero (here non NANs) elements
x_bin=abs(x_max-x_min)/number_bins;
figure; histogram(distToFit_limited, x_min:x_bin:x_max, 'FaceAlpha',0.7, 'FaceColor','0.00,0.45,0.74'); hold on;
[ny,nx] = histf(distToFit_limited, x_min:x_bin:x_max);
[pars,chisq] = hfitg_altJPS(nx,ny,2); hold on;
histogram(distToFit, x_min-x_bin*number_bins:x_bin:x_max+x_bin*number_bins, 'FaceAlpha',0.3, 'FaceColor','0.00,0.45,0.74');
ndf=length(find (ny > 0)); ndf=ndf-3;    %3 -> miu, sigma e max do hist; ndf é o nº de pontos usado para o fit logo neste caso é o nº de bins
%3 -> mean, sigma and histogram maximum; ndf is the number of points used for the fit, therefore here it equals the number of bins
message = sprintf('n = %d\n\\mu =  %.3f ns\n\\sigma = %.3f ns\n\\chi²/ndf = %.1f/%d', events_limited, pars(1), abs(pars(2)), chisq, ndf); %modulo do sigma pois hfitg pode resultar num valor neg -> ver mais abaixo explicação
%absolute value of sigma because hfitg can return a negative value -> see explanation below
yl = ylim; % Get limits of y axis so we can find a nice height for the text labels.
text(pars(1)+abs(pars(2)), 0.8 * yl(2), message, 'Color', 'r', 'FontSize', 12); %pode obter-se sigmas negativos com hfitg mas o módulo está correto; vê-se tb sigmas negativos mesmo centrando a dist primeiro)
%hfitg may yield negative sigmas but the absolute value is correct; negative sigmas appear even after centering the distribution first
xlabel('Tdiff [ns]','FontSize',14,'Color','k'); ylabel('# of events','FontSize',14,'Color','k'); title(sprintf('TcintBottom - Trpc w/ slewing corr. (borders: %.3f -> %.3f)', x_min, x_max));
xlim([x_min-x_bin*number_bins x_max+x_bin*number_bins]);
%FWHM=2.355*pars(2)/sqrt(2)    %for T=T1-T2
%%}

%return
