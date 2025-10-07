%Joana Pinto 2025
% script novo para os 4 cintiladores, 2 top 2 bottom
% new script for the 4 scintillators, 2 top and 2 bottom
% o run nº1 foi com a alta tensão ligada 
% run no.1 was acquired with the high voltage on
% o run nº2 e 3 foram adquiridos com a alta tensão desligada em cima
% runs no.2 and 3 were acquired with the top high voltage turned off

% NOTA!!!
% NOTE!!!
% ter atensão à ordem das ligações das strips:
% pay attention to the order of the strip connections:
% gordas: TFl = [l31 l32 l30 l28 l29]; TFt = [t31 t32 t30 t28 t29];  TBl = [l2 l1 l3 l5 l4]; TBt = [t2 t1 t3 t5 t4];
% wide strips: TFl = [l31 l32 l30 l28 l29]; TFt = [t31 t32 t30 t28 t29];  TBl = [l2 l1 l3 l5 l4]; TBt = [t2 t1 t3 t5 t4];
% cintiladores: Tl_cint = [l11 l12 l9 l10]; Tt_cint = [t11 t12 t9 t10]; 
% scintillators: Tl_cint = [l11 l12 l9 l10]; Tt_cint = [t11 t12 t9 t10];
% Nota: os cabos estavam trocados, por isso, Qt=Ib... e Qb=It...
% Note: the cables were swapped, therefore Qt=Ib... and Qb=It...

% l: leading edge times
% t: trailing edge times
% Q = t - l

%clear all; close all; clc;
% Configure base folders that contain the scripts and MAT files to analyse.
% =====================================================================
% Configuration Paths and Run Selection
% =====================================================================
HOME    = '/home/csoneira/WORK/LIP_stuff/';
SCRIPTS = 'JOAO_SETUP/';
DATA    = 'matFiles/time/';
DATA_Q    = 'matFiles/charge/';
path(path,[HOME SCRIPTS 'util_matPlots']);

% Select which acquisition run to process; each branch below loads time and
% charge information for that specific dataset.
run = 2;
if run == 1
    load([HOME SCRIPTS DATA 'dabc25120133744-dabc25126121423_a001_T.mat']) %run com os 4 cintiladores
    %run with all 4 scintillators
    load([HOME SCRIPTS DATA 'dabc25120133744-dabc25126121423_a003_T.mat']) 
    load([HOME SCRIPTS DATA_Q 'dabc25120133744-dabc25126121423_a004_Q.mat'])
elseif run == 2;
    load([HOME SCRIPTS DATA 'dabc25127151027-dabc25147011139_a001_T.mat']) % run com HV de cima desligada
    % run with the top HV switched off
    load([HOME SCRIPTS DATA 'dabc25127151027-dabc25147011139_a003_T.mat'])
elseif run == 3;
    load([HOME SCRIPTS DATA 'dabc25127151027-dabc25160092400_a001_T.mat']) % run com HV de cima desligada
    % run with the top HV switched off
    load([HOME SCRIPTS DATA 'dabc25127151027-dabc25160092400_a003_T.mat'])
    load([HOME SCRIPTS DATA_Q 'dabc25127151027-dabc25160092400_a004_Q.mat'])
    

end

% =====================================================================
% Scintillator Timing and Charge Derivations
% =====================================================================

% System layout:

% PMT 1 --- PMT 2
% ----- RPC -----
% PMT 3 --- PMT 4

% Build matrices with leading/trailing edge times for each scintillator PMT
% and derive simple charge proxies and mean times per side.
Tl_cint = [l11 l12 l9 l10];    %tempos leadings  [ns]
%leading times [ns]
Tt_cint = [t11 t12 t9 t10];    %tempos trailings [ns]
%trailing times [ns]
Qcint          = [Tt_cint(:,1) - Tl_cint(:,1) Tt_cint(:,2) - Tl_cint(:,2) Tt_cint(:,3) - Tl_cint(:,3) Tt_cint(:,4) - Tl_cint(:,4)]; %ch1 e ch2 -> PMTs bottom
%channels 1 and 2 -> bottom PMTs
Qcint_sum_bot  = (Qcint(:,1) + Qcint(:,2)); %soma das cargas dos 2 PMTs bottom; usado no caso da slewing correction
%sum of the charges from the 2 bottom PMTs; used for the slewing correction
Qcint_sum_top  = (Qcint(:,3) + Qcint(:,4)); %soma das cargas top
%sum of the top times to get incident time
Tcint_mean_bot = (Tl_cint(:,1) + Tl_cint(:,2))/2;
Tcint_mean_top = (Tl_cint(:,3) + Tl_cint(:,4))/2;
%nan(size(EventPerFile))

% Gather RPC leading/trailing edge times for the five "fat" strips on the
% front and back readouts, then compute their charge-equivalent widths.
TFl = [l31 l32 l30 l28 l29];    %tempos leadings  front [ns]; chs [32,28] -> 5 strips gordas front
%leading times front [ns]; channels [32,28] -> 5 wide front strips
TFt = [t31 t32 t30 t28 t29];    %tempos trailings front [ns]
%trailing times front [ns]
TBl = [l2 l1 l3 l5 l4];         %tempos leadings  back  [ns]; chs [1,5] -> 5 strips gordas back
%leading times back [ns]; channels [1,5] -> 5 wide back strips
TBt = [t2 t1 t3 t5 t4];         %tempos trailings back  [ns]
%trailing times back [ns]
clearvars l32 l31 l30 l29 l28 t32 t31 t30 t29 t28 l1 l2 l3 l4 l5 t1 t2 t3 t4 t5 l11 l12 l9 l10 t11 t12 t9 t10 
QF  = TFt - TFl;
QB  = TBt - TBl;
rawEvents = size(TFl,1);
% Convert charge arrays from cell traces to double matrices (after cable swap).
Qt = cast([Ib IIb IIIb IVb Vb VIb VIIb VIIIb IXb Xb XIb XIIb XIIIb XIVb XVb XVIb XVIIb XVIIIb XIXb XXb XXIb XXIIb XXIIIb XXIVb],"double"); %nota: os cabos estavam trocados, por isso, Qt=Ib e Qb=It
%note: the cables were swapped, so Qt=Ib and Qb=It
Qb = cast([It IIt IIIt IVt Vt VIt VIIt VIIIt IXt Xt XIt XIIt XIIIt XIVt XVt XVIt XVIIt XVIIIt XIXt XXt XXIt XXIIt XXIIIt XXIVt],"double");

% Total number of triggered events available in the loaded files.
events=size(EventPerFile,1);

% ---------------------------------------------------------------------
% Quick Visual Checks
% ---------------------------------------------------------------------
% Quick sanity check: compare front vs. back charge per strip in a scatter plot.
%plot de cada strip
%plot of each strip
hold on;
for i = 1:5
    plot(QF(:,i),QB(:,i),'.');
end
hold off;
%% finas
% thin strips
% Sum charge over all thin strips (bottom/top) to estimate RPC efficiency
% using simple activity thresholds.
ChargePerEvent_b = sum(Qb,2); 
ChargePerEvent_t = sum(Qt,2);    %max 512ADCbins*32DSampling*24strips ~400000
%uma forma de calcular a eficiencia da RPC: os PMTs dispararam mas a RPC nada viu, logo soma das cargas por evento (Q spectrum) -> mto perto de zero
%one way to calculate the RPC efficiency: the PMTs fired but the RPC saw nothing, so the charge sum per event (Q spectrum) should be very close to zero
%olhar para os espetros de carga top e bottom e ver qual é o limiar que consideramos nao ter carga ou nao ter visto (tem um pico inicial); 600 demasiado baixo -> dá Eff=5% com HV=0kV
%look at the top and bottom charge spectra and decide the threshold that means no charge or not seen (there is an initial peak); 600 is too low -> gives Eff=5% with HV=0 kV
I=find(ChargePerEvent_b <2100);    %limite inf da soma da Q nas 24 strips; 700 ou  800; para a multiplicidade usar threshold = 100 pq é um limite de Q por strip
%lower bound of the charge sum on the 24 strips; 700 or 800; for multiplicity use threshold = 100 because it is a per-strip charge limit
eff_bottom = 100*(1-(size(I,1)/events));
I=find(ChargePerEvent_t <2000);
eff_top    = 100*(1-(size(I,1)/events));

% Print these efficiencies
fprintf('Efficiency bottom (all events): %2.2f%%\n', eff_bottom);
fprintf('Efficiency top (all events): %2.2f%%\n', eff_top);

% ---------------------------------------------------------------------
% PMT Coincidence-Based Efficiency Filtering
% ---------------------------------------------------------------------

% Plot scatter plots of Tl_cint i vs Tl_cint j for all PMT pairs to verify the
% coincidence cut. In the same figure the 6 pairs
figure;
subplot(3,2,1); plot(Tl_cint(:,1), Tl_cint(:,2),'.'); xlabel('Tl_cint1'); ylabel('Tl_cint2'); title('Time lead PMT1 vs PMT2');
xlim([min(min(Tl_cint)) max(max(Tl_cint))]); ylim([min(min(Tl_cint)) max(max(Tl_cint))]);
subplot(3,2,2); plot(Tl_cint(:,1), Tl_cint(:,3),'.'); xlabel('Tl_cint1'); ylabel('Tl_cint3'); title('Time lead PMT1 vs PMT3');
xlim([min(min(Tl_cint)) max(max(Tl_cint))]); ylim([min(min(Tl_cint)) max(max(Tl_cint))]);
subplot(3,2,3); plot(Tl_cint(:,1), Tl_cint(:,4),'.'); xlabel('Tl_cint1'); ylabel('Tl_cint4'); title('Time lead PMT1 vs PMT4');
xlim([min(min(Tl_cint)) max(max(Tl_cint))]); ylim([min(min(Tl_cint)) max(max(Tl_cint))]);
subplot(3,2,4); plot(Tl_cint(:,2), Tl_cint(:,3),'.'); xlabel('Tl_cint2'); ylabel('Tl_cint3'); title('Time lead PMT2 vs PMT3');
xlim([min(min(Tl_cint)) max(max(Tl_cint))]); ylim([min(min(Tl_cint)) max(max(Tl_cint))]);
subplot(3,2,5); plot(Tl_cint(:,2), Tl_cint(:,4),'.'); xlabel('Tl_cint2'); ylabel('Tl_cint4'); title('Time lead PMT2 vs PMT4');
xlim([min(min(Tl_cint)) max(max(Tl_cint))]); ylim([min(min(Tl_cint)) max(max(Tl_cint))]);
subplot(3,2,6); plot(Tl_cint(:,3), Tl_cint(:,4),'.'); xlabel('Tl_cint3'); ylabel('Tl_cint4'); title('Time lead PMT3 vs PMT4');
xlim([min(min(Tl_cint)) max(max(Tl_cint))]); ylim([min(min(Tl_cint)) max(max(Tl_cint))]);
sgtitle(sprintf('PMT time coincidences'));

figure;
subplot(2,2,1); plot(Tl_cint(:,1), Tt_cint(:,1),'.'); xlabel('Tl_cint1'); ylabel('Tt_cint1'); title('Time lead vs trail PMT1');
xlim([min(min(Tl_cint)) max(max(Tl_cint))]); ylim([min(min(Tt_cint)) max(max(Tt_cint))]);
subplot(2,2,2); plot(Tl_cint(:,2), Tt_cint(:,2),'.'); xlabel('Tl_cint2'); ylabel('Tt_cint2'); title('Time lead vs trail PMT2');
xlim([min(min(Tl_cint)) max(max(Tl_cint))]); ylim([min(min(Tt_cint)) max(max(Tt_cint))]);
subplot(2,2,3); plot(Tl_cint(:,3), Tt_cint(:,3),'.'); xlabel('Tl_cint3'); ylabel('Tt_cint3'); title('Time lead vs trail PMT3');
xlim([min(min(Tl_cint)) max(max(Tl_cint))]); ylim([min(min(Tt_cint)) max(max(Tt_cint))]);
subplot(2,2,4); plot(Tl_cint(:,4), Tt_cint(:,4),'.'); xlabel('Tl_cint4'); ylabel('Tt_cint4'); title('Time lead vs trail PMT4');
xlim([min(min(Tl_cint)) max(max(Tl_cint))]); ylim([min(min(Tt_cint)) max(max(Tt_cint))]);
sgtitle(sprintf('PMT time lead vs trail'));

% Now plot the charge correlations for the same PMT pairs to verify that
figure;
subplot(3,2,1); plot(Tt_cint(:,1) - Tl_cint(:,1), Tt_cint(:,2) - Tl_cint(:,2), '.'); xlabel('Tt\_cint1 - Tl\_cint1'); ylabel('Tt\_cint2 - Tl\_cint2'); title('Charge PMT1 vs PMT2');
xlim([min(min(Tt_cint - Tl_cint)) max(max(Tt_cint - Tl_cint))]); ylim([min(min(Tt_cint - Tl_cint)) max(max(Tt_cint - Tl_cint))]);
subplot(3,2,2); plot(Tt_cint(:,1) - Tl_cint(:,1), Tt_cint(:,3) - Tl_cint(:,3), '.'); xlabel('Tt\_cint1 - Tl\_cint1'); ylabel('Tt\_cint3 - Tl\_cint3'); title('Charge PMT1 vs PMT3');
xlim([min(min(Tt_cint - Tl_cint)) max(max(Tt_cint - Tl_cint))]); ylim([min(min(Tt_cint - Tl_cint)) max(max(Tt_cint - Tl_cint))]);
subplot(3,2,3); plot(Tt_cint(:,1) - Tl_cint(:,1), Tt_cint(:,4) - Tl_cint(:,4), '.'); xlabel('Tt\_cint1 - Tl\_cint1'); ylabel('Tt\_cint4 - Tl\_cint4'); title('Charge PMT1 vs PMT4');
xlim([min(min(Tt_cint - Tl_cint)) max(max(Tt_cint - Tl_cint))]); ylim([min(min(Tt_cint - Tl_cint)) max(max(Tt_cint - Tl_cint))]);
subplot(3,2,4); plot(Tt_cint(:,2) - Tl_cint(:,2), Tt_cint(:,3) - Tl_cint(:,3), '.'); xlabel('Tt\_cint2 - Tl\_cint2'); ylabel('Tt\_cint3 - Tl\_cint3'); title('Charge PMT2 vs PMT3');
xlim([min(min(Tt_cint - Tl_cint)) max(max(Tt_cint - Tl_cint))]); ylim([min(min(Tt_cint - Tl_cint)) max(max(Tt_cint - Tl_cint))]);
subplot(3,2,5); plot(Tt_cint(:,2) - Tl_cint(:,2), Tt_cint(:,4) - Tl_cint(:,4), '.'); xlabel('Tt\_cint2 - Tl\_cint2'); ylabel('Tt\_cint4 - Tl\_cint4'); title('Charge PMT2 vs PMT4');
xlim([min(min(Tt_cint - Tl_cint)) max(max(Tt_cint - Tl_cint))]); ylim([min(min(Tt_cint - Tl_cint)) max(max(Tt_cint - Tl_cint))]);
subplot(3,2,6); plot(Tt_cint(:,3) - Tl_cint(:,3), Tt_cint(:,4) - Tl_cint(:,4), '.'); xlabel('Tt\_cint3 - Tl\_cint3'); ylabel('Tt\_cint4 - Tl\_cint4'); title('Charge PMT3 vs PMT4');
xlim([min(min(Tt_cint - Tl_cint)) max(max(Tt_cint - Tl_cint))]); ylim([min(min(Tt_cint - Tl_cint)) max(max(Tt_cint - Tl_cint))]);
% I want the aspect ratio of x and y axes to be equal, i mean, force it to be a square. It's not 1:1 yet
sgtitle(sprintf('PMT charge coincidences'));


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
title('Good events vs tTH');

%%{
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
numberSeenEvents=length(find(ChargePerEvent_b_goodEventsOnly >1400));
eff_bottom_goodEventsOnly = 100*(numberSeenEvents/numberGoodEvents);
numberSeenEvents=length(find(ChargePerEvent_t_goodEventsOnly >1400));
eff_top_goodEventsOnly    = 100*(numberSeenEvents/numberGoodEvents);
figure;
subplot(2,1,1); histogram(ChargePerEvent_b_goodEventsOnly, 0:200:5E4); ylabel('# of events'); xlabel('Q (bottom)'); title(sprintf('Q spectrum (sum of Q per event); Eff_{bot} = %2.2f%%', eff_bottom_goodEventsOnly));
subplot(2,1,2); histogram(ChargePerEvent_t_goodEventsOnly, 0:200:5E4); ylabel('# of events'); xlabel('Q (top)'); title(sprintf('Q spectrum (sum of Q per event); Eff_{top} = %2.2f%%', eff_top_goodEventsOnly));
%%}

return;

%%
% ---------------------------------------------------------------------
% Wide Strip Charge Spectra and Offset Calibration
% ---------------------------------------------------------------------
% Inspect per-strip charge spectra before any calibration to compare front
% and back readouts channel by channel.
% 5 hitogramas para strips gordas, Q em função # of events
% 5 histograms for wide strips, Q as a function of # of events
first = 1; last = 5;
fig=figure('Position', [700 10 600 900]); hold on
for strip=first:last
    subplot(5,1,strip);
    histf(QF(:,strip),-2:0.1:150); hold on;
    histf(QB(:,strip),-2:0.1:150); xlim([-2 150]); legend(sprintf('QF - strip%d', strip), sprintf('QB - strip%d', strip), 'Location', 'northeast')
    %ylim([0 250]);
end
%return
% Static offsets measured with self-trigger data; subtract to calibrate strip
% responses on both faces.
QB_offsets = [81, 84, 82, 85, 84];%selfTrigger
QF_offsets = [75, 85.5, 82, 80, 80];
QB_p = QB - QB_offsets; 
QF_p = QF - QF_offsets;
clearvars QB_offsets QF_offsets
%{
for strip = 1:5
    figure
    histf(QF_p(:,strip), -2:0.1:250); hold on;
    histf(QB_p(:,strip), -2:0.1:250);
    xlim([-2 250]);
    legend(sprintf('QF - strip%d', strip), sprintf('QB - strip%d', strip), 'Location', 'northeast');
    % Adicionando título e labels
    % Adding title and labels
    ylabel('# of events');
    xlabel('Q [ns]');
end
%}
% Re-evaluate the calibrated spectra to confirm the offset subtraction worked.
% 5 hitogramas para strips gordas, Q em função # of events
first = 1; last = 5;
fig=figure('Position', [700 10 600 900]); hold on
for strip=first:last
    subplot(5,1,strip);
    histf(QF_p(:,strip),-2:0.1:150); hold on;
    histf(QB_p(:,strip),-2:0.1:150); xlim([-2 150]); legend(sprintf('QF - strip%d', strip), sprintf('QB - strip%d', strip), 'Location', 'northeast')
    %ylim([0 250]);
end
handle=axes(fig,'visible','off'); handle.Title.Visible='on'; handle.XLabel.Visible='on'; handle.YLabel.Visible='on';
ylabel(handle, '# of events'); xlabel(handle, 'Q [ns]'); title(handle, 'Q front and back (calibrated) per strip');

% ---------------------------------------------------------------------
% Event-Level Maximum Charge Aggregation
% ---------------------------------------------------------------------
%% calculo das cargas maximas e posição RAW em função de Qmax
% calculation of maximum charges and RAW position as a function of Qmax
[QFmax,XFmax] = max(QF_p,[],2);    %XFmax -> strip of Qmax
[QBmax,XBmax] = max(QB_p,[],2);

% Keep only events where the strip with maximum charge matches on both faces
% and use those indices to compute representative timing/charge observables.
Ind2Cut   = find(~isnan(QF_p) & ~isnan(QB_p) & XFmax == XBmax);
[row,col] = ind2sub(size(TFl),Ind2Cut); %row=evento com Qmax na mesma strip; col=strip não interessa pois fica-se com a strip com Qmax
%row = event with Qmax in the same strip; col = strip not needed because we keep the strip with Qmax
rows      = unique(row); %eventos sorted e sem repetiçoes
%events sorted and without repetitions
Ind2Keep  = sub2ind(size(TFl),rows,XFmax(rows)); %indices das Qmax, desde que QFmax e QBmax estejam na mesma strip
%indices of the Qmax values, provided QFmax and QBmax are on the same strip

T = nan(rawEvents,1); Q = nan(rawEvents,1); X = nan(rawEvents,1); Y = nan(rawEvents,1);
T(rows) = (TFl(Ind2Keep) + TBl(Ind2Keep)) /2; %[ns]
Q(rows) = QF_p(Ind2Keep) + QB_p(Ind2Keep);    %[ns], soma das Qmax Front e Back -> com nans se algum evento não cumpre Ind2Keep
%sum of Qmax front and back -> contains NaNs if an event fails the Ind2Keep condition
X(rows) = XFmax(rows);                        %strip #
Y(rows) = (TFl(Ind2Keep) - TBl(Ind2Keep)) /2; %[ns]
figure;
histogram(Q, 0:0.1:300);
STLevel = 100; %230 com as RPC de 1mm gap
%230 with the 1 mm gap RPCs
Qmean = mean(Q, 'omitnan'); % Calculate mean while ignoring NaN values; média da 'soma das Qmax Front e Back' de todos os eventos
%mean of the 'sum of Qmax front and back' over all events
Qmedian = median(Q, 'omitnan'); %mediana
%median
ST      = length(find(Q > STLevel))/rawEvents; %percentagem de streamers
%percentage of streamers
%%%%%%%%%%%%%%%%%%
%return

% ---------------------------------------------------------------------
% Combined PMT/RPC Efficiency Recalculation
% ---------------------------------------------------------------------
%%{
%EFFICIENCY
% Repeat the efficiency estimate but require both PMT coincidence and at
% least one valid charge sample on each RPC face.
tTH = 3; %time threshold [ns] to assume it comes from a good event; obriga a ter tempos nos 4 cint
restrictionsForPMTs = abs(Tl_cint(:,1)-Tl_cint(:,2)) <tTH & ...
                      abs(Tl_cint(:,1)-Tl_cint(:,3)) <tTH & ...
                      abs(Tl_cint(:,1)-Tl_cint(:,4)) <tTH & ...
                      abs(Tl_cint(:,2)-Tl_cint(:,3)) <tTH & ...
                      abs(Tl_cint(:,2)-Tl_cint(:,4)) <tTH & ...
                      abs(Tl_cint(:,3)-Tl_cint(:,4)) <tTH;
numberGoodEvents    = length(find(restrictionsForPMTs));
restrictionsForRPC  = any(QF_p,2) & any(QB_p,2); %QF_p e QB_p têm de ter em cada evento pelo menos 1 tempo
%QF_p and QB_p must have at least one time per event
%restrictionsForRPC  = any(QF_p,2) & any(QB_p,2) & abs(T(:)-Tl_cint(:,2))<5; %QF_p e QB_p tem de ter em cada evento pelo menos 1 tempo; o tempo da RPC tem de estar a menos de 5ns do tempo dos PMTs
%QF_p and QB_p must have at least one time per event; the RPC time has to be within 5 ns of the PMT time
%restrictionsForRPC  = any(Q,2); %Q tem todas as restriçoes de QF_p e QB_p e tem de ter Qmax na mesma strip <- demasiado restritivo
%Q contains all restrictions from QF_p and QB_p and must have Qmax in the same strip <- too restrictive
numberSeenEvents    = sum(restrictionsForPMTs & restrictionsForRPC); %seen by PMTs AND RPCs (obrigar visto por pmts pois tb há triggers do SiPMs vistos pelas RPCs)
%require being seen by PMTs because there are SiPM triggers seen by the RPCs as well
%numberNotSeenEvents = sum(restrictionsForPMTs & ~restrictionsForRPC); %seen by PMTs BUT NOT BY RPCs
Eff = numberSeenEvents * 100 / numberGoodEvents; %numberGoodEvents or rawEvents
%%}

%HISTOGRAM OF CHARGE WITH Q = SUM OF QFmax AND QBmax IF THEY ARE IN THE SAME STRIP
figure; histogram(Q, 0:400/200:400);     %histogram(Q_max, 0:400/200:400);
ylabel('# of events'); xlabel('Q [ns]'); title('Qspectrum (Qmax)'); %legend('gordas');
%legend('wide strips');

%return
% ---------------------------------------------------------------------
% Events Seen by PMTs but Missed by the RPC
% ---------------------------------------------------------------------
%% evento nao vistos pela rpc
% events not seen by the RPC

% Visualise charge recorded on thin strips for PMT-tagged events where the
% RPC showed no activity (helps to tune thresholds).
indices_not_seen = find(restrictionsForPMTs & ~restrictionsForRPC);
Qb_not_seen = ChargePerEvent_b(indices_not_seen);

figure;
histogram(Qb_not_seen, 0:200:5E4);
xlabel('Qb ');
ylabel('# of events');
title('Espetro de carga nas strips finas (baixo) para eventos não vistos pela RPC');
%title: Charge spectrum in the thin strips (bottom) for events not seen by the RPC


% ---------------------------------------------------------------------
% Time Resolution Studies
% ---------------------------------------------------------------------
%% time resolution
%%{
% Select the central region of each PMT charge distribution to focus on good
% signals before computing timing resolution.
%HISTOGRAM OF Qcint FOR EACH PMT AND SELECTION OF EVENTS FOR TEMPORAL RES - selecionar eventos nas matrizes de carga -> apenas o pico central
%HISTOGRAM OF Qcint FOR EACH PMT AND EVENT SELECTION FOR TIME RESOLUTION - keep only the central peak in the charge matrices
X_T_min = [94 101  146 95];
X_T_max = [103 120 180 107];


first = 1; last = 4;
fig=figure('Position', [70 70 1100 400]); %[posX posY dimX dimY]
for pmt=first:last
    subplot(2,2,pmt);
    histogram(Qcint(:,pmt),75:1:275); hold on;
    temp = Qcint(:,pmt); temp(find( Qcint(:,pmt) > X_T_max(pmt) )) = nan; Qcint(:,pmt) = temp;
    temp = Qcint(:,pmt); temp(find( Qcint(:,pmt) < X_T_min(pmt) )) = nan; Qcint(:,pmt) = temp;
    histogram(Qcint(:,pmt),-2:1:300); legend(sprintf('Q - PMT%d', pmt), sprintf('Q - PMT%d selection', pmt), 'Location', 'northeast')
    xlim([70 280]); %ylim([0 1500]);
end
handle=axes(fig,'visible','off'); handle.Title.Visible='on'; handle.XLabel.Visible='on'; handle.YLabel.Visible='on';
ylabel(handle, '# of events'); xlabel(handle, 'Q [ns]'); title(handle, 'Q for each PMT (bottom: PMT1 & PMT2) + selected events');
%%}

%return

%%{
% ------------------------------------------------------------------
% Data Cleaning Prior to Slewing Corrections
% ------------------------------------------------------------------
% Remove any event with missing values so that polynomial fits and slewing
% corrections downstream have fully populated rows.
%remove events with at least a value = nan; ao usar Qcint -> obriga-se a haver tempos nos 4PMTs, igual a 'restrictionsForPMTs' no cálculo da eff; Q -> para o lado da RPC
%remove events with at least one NaN; by using Qcint we enforce times in all 4 PMTs, same as 'restrictionsForPMTs' in the efficiency, Q refers to the RPC side
%usando a slewing corr, polyfit não pode ter nans
%using the slewing correction, polyfit cannot contain NaNs
I_toRemoveLines = any(isnan(Qcint),2) | any(isnan(Q), 2); %row=1 if the event has at least one column with a nan
Qcint(I_toRemoveLines,:)          = [];
Tcint_mean_bot(I_toRemoveLines,:) = [];
Tcint_mean_top(I_toRemoveLines,:) = [];
Qcint_sum_bot(I_toRemoveLines,:)  = [];
Qcint_sum_top(I_toRemoveLines,:)  = [];
Q(I_toRemoveLines,:)              = [];
T(I_toRemoveLines,:)              = [];
X(I_toRemoveLines,:)              = []; %para os plots 2D mais abaixo
%for the 2D plots below
Y(I_toRemoveLines,:)              = []; %para os plots 2D mais abaixo
%for the 2D plots below
QB_p(I_toRemoveLines,:)           = []; %se usarmos o EventDisplayer mais abaixo
%if we use the EventDisplayer further down
QF_p(I_toRemoveLines,:)           = []; %se usarmos o EventDisplayer mais abaixo
%if we use the EventDisplayer further down
TFl(I_toRemoveLines,:)            = []; %se usarmos o EventDisplayer mais abaixo
%if we use the EventDisplayer further down
TBl(I_toRemoveLines,:)            = []; %se usarmos o EventDisplayer mais abaixo
%if we use the EventDisplayer further down
Tl_cint(I_toRemoveLines,:)        = []; %se usarmos o EventDisplayer mais abaixo
%if we use the EventDisplayer further down
%%}

%%

%return

%%{
% ------------------------------------------------------------------
% Raw Time-Difference Analysis (No Slewing Correction)
% ------------------------------------------------------------------
% Compute the raw timing difference between scintillators and the RPC before
% any slewing correction, then fit the distribution with a Gaussian model.
%RESOLUÇÃO TEMPORAL SEM SLEWING CORRECTION -> tempo_cintiladores - tempo_RPC ou tempo_cintiladores_bottom - tempo_cintiladores_top
%TIME RESOLUTION WITHOUT SLEWING CORRECTION -> scintillator time minus RPC time or bottom minus top scintillator time
tempo1 = Tcint_mean_top;    %Tcint_mean_bot ou Tcint_mean_top
%Tcint_mean_bot or Tcint_mean_top
tempo2 = T;                 %T para a RPC; para os cint: Tcint_mean_bot ou Tcint_mean_top
%T for the RPC; for the scintillators: Tcint_mean_bot or Tcint_mean_top
Tdiff  = [tempo1 - tempo2]; %[ns];
figure; histogram(Tdiff, 0:0.05:20);xlabel('Tdiff [ns]'); ylabel('# of events'); title('TcintBottom - Trpc');
figure; histogram(Tdiff);,

%%%%%%%%%%%%%%%%%%
%se for necessário impor boundaries a Tdiff para o fit ser bem sucedido com bestFit.m:
%if necessary impose boundaries on Tdiff so the fit succeeds with bestFit.m:
%Tdiff(find((Tdiff < 12.5) | (Tdiff > 14.5))) = nan; %sigma 1 bot
%sets Tdiff to NaN outside 12.5-14.5 ns for sigma 1 on the bottom
Tdiff(find((Tdiff < 11) | (Tdiff > 12.1))) = nan; %sigma 2
%Tdiff(find((Tdiff < -2.7) | (Tdiff > -1.2))) = nan; %sigma 3
%sets Tdiff to NaN outside -2.7 to -1.2 ns for sigma 3
%Tdiff(find((Tdiff < 1.2) | (Tdiff > 2.7))) = nan; 
%sets Tdiff to NaN outside 1.2 to 2.7 ns
%figure; histogram(Tdiff);
%plot the histogram of Tdiff
%%%%%%%%%%%%%%%%%%
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
xlabel('Tdiff [ns]','FontSize',14,'Color','k'); ylabel('# of events','FontSize',14,'Color','k'); title(sprintf('TcintBottom - Trpc; gaussian fit (borders: %.3f -> %.3f)', x_min, x_max));
xlim([x_min-x_bin*number_bins x_max+x_bin*number_bins]);
%FWHM=2.355*pars(2)/sqrt(2)    %for T=T1-T2
%%}

%return

%%{
% ------------------------------------------------------------------
% Slewing-Corrected Time Resolution
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
%%%%%%%%%%%%%%%%%%
%%{
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

% 
% %%{
% %ESPETRO DE CARGA
% %CHARGE SPECTRUM
% %HISTOGRAM OF Q_calibrated FRONT AND BACK, PER STRIP OF ALL EVENTS
% first = 1; last = 5;
% fig=figure('Position', [700 10 600 900]); hold on
% for strip=first:last
%     subplot(5,1,strip);
%     histf(QF_p(:,strip),-2:0.1:250); hold on;
%     histf(QB_p(:,strip),-2:0.1:250); xlim([-2 250]); legend(sprintf('QF - strip%d', strip), sprintf('QB - strip%d', strip), 'Location', 'northeast')
%     %ylim([0 250]);
% end
% handle=axes(fig,'visible','off'); handle.Title.Visible='on'; handle.XLabel.Visible='on'; handle.YLabel.Visible='on';
% ylabel(handle, '# of events'); xlabel(handle, 'Q [ns]'); title(handle, 'Q front and back (calibrated) per strip');
% 
% %HISTOGRAM OF CHARGE WITH Q = SUM OF QFmax AND QBmax IF THEY ARE IN THE SAME STRIP
% figure; histogram(Q, 0:400/200:400);     %histogram(Q_max, 0:400/200:400);
% ylabel('# of events'); xlabel('Q [ns]'); title('Qspectrum (Qmax)'); %legend('gordas');
% %legend('wide strips');
% %xlim([-10 100]); %ylim([0 7500]);
% %%}
% 
% 
% %return
% 
% 
% %%{
% %MULTIPLICITY (não se atribui um Qthreshold como se fez na MB48chs pq um th de -40mV já é colocado nas DB)
% %MULTIPLICITY (a Q threshold is not assigned as in the MB48chs because a -40 mV threshold is already set on the DBs)
% IF=find(~isnan(QF_p)); MF=zeros(size(QF_p)); MF(IF)=1;
% IB=find(~isnan(QB_p)); MB=zeros(size(QB_p)); MB(IB)=1;
% 
% MperEventF=sum(MF,2);    %multiplicidade de todos os eventos, lado Front
% %multiplicity of all events, front side
% NperStripF=sum(MF,1);    %check hits per ch (# of values for each strip), lado Front
% %check hits per channel (# of values for each strip), front side
% MperEventB=sum(MB,2);    %multiplicidade de todos os eventos, lado Back
% %multiplicity of all events, back side
% NperStripB=sum(MB,1);    %check hits per ch (# of values for each strip), lado Back
% %check hits per channel (# of values for each strip), back side
% 
% figure; stairs(NperStripF); hold on
% stairs(NperStripB); xlim([0.5 5.5]); ylabel('# of hits (charge in both strip ends)'); xlabel('strip'); title('Hits per strip'); legend('front', 'back', 'Location', 'northwest')
% 
% figure; histogram(MperEventF, 0:1:6); hold on %alguns eventos de M=0 -> eventos de QF_p sem carga pq tempos em strips diferentes: I = find(~isnan(TFl) & ~isnan(TBl));
% some events with M=0 -> QF_p events without charge because times are in different strips: I = find(~isnan(TFl) & ~isnan(TBl));
% hh = histogram(MperEventB, 0:1:6); xlabel('multiplicity','FontSize',14); ylabel('# of events','FontSize',14); title('Multiplicity per event (readout gordas)');
% title translation: Multiplicity per event (wide readout)
% legend('front', 'back', 'Location', 'northwest');
% 
% 
% %Events (with Qmax) per strip -> similar a NperStripF mas com Qmax e não as cargas todas
% %Events (with Qmax) per strip -> similar to NperStripF but using Qmax instead of all charges
% figure; h=histogram(X); ylabel('# of events'); xlabel('strip'); title('Events (with Qmax) per strip');
% %com X mais restritivo que XFmax ou XBmax pq força ambos a estarem na mesma strip 
% %with X more restrictive than XFmax or XBmax because it forces both to be in the same strip
% %sum(h.Values) = Ind2Keep
% %%}
% 
% 
% 
% %%
% %%{
% %Y CALIBRATION
% %histogram(Y)
% 
% Y_calibrated_ns = Y;
% for i=1:5
%    I_ = find(X== i);
%    Y_calibrated_ns(I_) = (Y(I_) - YCenters(i));
% end
% 
% showMe=0;    %to check the result of the YY calibration
% if showMe
%     figure; plot(X,Y,'.'); xaxis(0.5,5.5);yaxis(-5,5);
%     figure; plot(X,Y_calibrated_ns,'.'); xaxis(0.5,5.5); yaxis(-5,5);
% end
% 
% showMe2=0;    %para calcular a velocidade de propagação do signal sabendo o comprimento da área ativa (camada da tinta resistiva)
% %to calculate the signal propagation speed knowing the length of the active area (resistive paint layer)
% if showMe2
%     figure; histf(Y_calibrated_ns,-15:0.01:15);
%     ylabel('# of events'); xlabel('Y [ns]'); title('Y projection');
% end
% %xmin = -0.82ns, xmax = 0.87ns; 0.87-(-0.82)=1.69ns; camada resistiva com ~29cm de comprimento ->  290mm/1.69ns = 171mm/ns
% %change from [ns] to [mm]
% vprop=171;    %171; 177; [mm/ns]
% X_= ((X -1) + (rand(length(X),1))) * 303/5; %30.3cm de largo / 5 strips gooordas
% %30.3 cm wide / 5 wide strips
% Y_calibrated_mm = Y_calibrated_ns*vprop;
% 
% showMe3=1;
% if showMe3
%     % X: as strips estendem-se de 0 a 303mm; Y: as strips estendem-se de -190mm a 190mm mas a tinta resistiva vai apenas de -145mm a 145mm
%     % X: the strips extend from 0 to 303 mm; Y: the strips extend from -190 mm to 190 mm but the resistive paint only goes from -145 mm to 145 mm
%     %[XY] = STRATOS2DplotsXY(X_,Y_calibrated_mm,-10:10:370,-200:10:200); %X: -10:10:370 -> 380/10=38bins para 380mm -> 1bin/cm;Y:-200:10:200 -> 40bin/40cm -> 1bin/cm
%     %[XY] = STRATOS2DplotsXY(X_,Y_calibrated_mm,-10:10:370,-200:10:200); %X: -10:10:370 -> 380/10 = 38 bins for 380 mm -> 1 bin/cm; Y: -200:10:200 -> 40 bins/40 cm -> 1 bin/cm
%     [XY,XY_Q,XY_ST] = STRATOS2Dplots(X_,Y_calibrated_mm,Q,-10:10:310,-200:10:200,STLevel); %STRATOS2Dplots(X_,Y_calibrated_mm,Q,-10:10:310,-200:10:200,STLevel);
%     figure; %clims = [0 80];
%     imagesc(0,-20,XY'); c = colorbar; %imagesc(0,-20,XY', clims);
%     ylabel('Y [cm]'); xlabel('X [cm]'); c.Label.String = ('# of events'); title('XY map (30.3cm(X) x 38cm(Y))');
%     QMEAN=cellfun(@mean, XY_Q');
%     figure; imagesc(0,-20,QMEAN); c = colorbar;
%     ylabel('Y [cm]'); xlabel('X [cm]'); c.Label.String = ('Qmean [ns]'); title('Qmean (Q max same strip) map (30.3cm(X) x 38cm(Y))');
%     figure; imagesc(0,-20,XY_ST'); c = colorbar;
%     ylabel('Y [cm]'); xlabel('X [cm]'); c.Label.String = ('# of streamers / # of events'); title('Qstreamers map (30.3cm(X) x 38cm(Y))');
% end
