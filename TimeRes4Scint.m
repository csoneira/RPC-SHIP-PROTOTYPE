%Joana Pinto 2025
% script novo para os 4 cintiladores, 2 top 2 bottom
% o run nº1 foi com a alta tensão ligada 
% o run nº2 e 3 foram adquiridos com a alta tensão desligada em cima

% NOTA!!!
% ter atensão à ordem das ligações das strips:
% gordas: TFl = [l31 l32 l30 l28 l29]; TFt = [t31 t32 t30 t28 t29];  TBl = [l2 l1 l3 l5 l4]; TBt = [t2 t1 t3 t5 t4];
% cintiladores: Tl_cint = [l11 l12 l9 l10]; Tt_cint = [t11 t12 t9 t10]; 
% Nota: os cabos estavam trocados, por isso, Qt=Ib... e Qb=It...

%clear all; close all; clc;
HOME    = '/home/csoneira/WORK/LIP_stuff/';
SCRIPTS = 'JOAO_SETUP/';
DATA    = 'matFiles/time/';
DATA_Q    = 'matFiles/charge/';
path(path,[HOME SCRIPTS 'util_matPlots']);

run = 3;
if run == 1
    load([HOME SCRIPTS DATA 'dabc25120133744-dabc25126121423_a001_T.mat']) %run com os 4 cintiladores
    load([HOME SCRIPTS DATA 'dabc25120133744-dabc25126121423_a003_T.mat']) 
    load([HOME SCRIPTS DATA_Q 'dabc25120133744-dabc25126121423_a004_Q.mat'])
elseif run == 2;
    load([HOME SCRIPTS DATA 'dabc25127151027-dabc25147011139_a001_T.mat']) % run com HV de cima desligada
    load([HOME SCRIPTS DATA 'dabc25127151027-dabc25147011139_a003_T.mat'])
elseif run == 3;
    load([HOME SCRIPTS DATA 'dabc25127151027-dabc25160092400_a001_T.mat']) % run com HV de cima desligada
    load([HOME SCRIPTS DATA 'dabc25127151027-dabc25160092400_a003_T.mat'])
    load([HOME SCRIPTS DATA_Q 'dabc25127151027-dabc25160092400_a004_Q.mat'])
    

end

Tl_cint = [l11 l12 l9 l10];    %tempos leadings  [ns]
Tt_cint = [t11 t12 t9 t10];    %tempos trailings [ns]
Qcint          = [Tt_cint(:,1) - Tl_cint(:,1) Tt_cint(:,2) - Tl_cint(:,2) Tt_cint(:,3) - Tl_cint(:,3) Tt_cint(:,4) - Tl_cint(:,4)]; %ch1 e ch2 -> PMTs bottom
Qcint_sum_bot  = (Qcint(:,1) + Qcint(:,2)); %soma das cargas dos 2 PMTs bottom; usado no caso da slewing correction
Qcint_sum_top  = (Qcint(:,3) + Qcint(:,4)); %soma das cargas top
Tcint_mean_bot = (Tl_cint(:,1) + Tl_cint(:,2))/2;
Tcint_mean_top = (Tl_cint(:,3) + Tl_cint(:,4))/2;
%nan(size(EventPerFile))
TFl = [l31 l32 l30 l28 l29];    %tempos leadings  front [ns]; chs [32,28] -> 5 strips gordas front
TFt = [t31 t32 t30 t28 t29];    %tempos trailings front [ns]
TBl = [l2 l1 l3 l5 l4];         %tempos leadings  back  [ns]; chs [1,5] -> 5 strips gordas back
TBt = [t2 t1 t3 t5 t4];         %tempos trailings back  [ns]
clearvars l32 l31 l30 l29 l28 t32 t31 t30 t29 t28 l1 l2 l3 l4 l5 t1 t2 t3 t4 t5 l11 l12 l9 l10 t11 t12 t9 t10 
QF  = TFt - TFl;
QB  = TBt - TBl;
rawEvents = size(TFl,1);
Qt = cast([Ib IIb IIIb IVb Vb VIb VIIb VIIIb IXb Xb XIb XIIb XIIIb XIVb XVb XVIb XVIIb XVIIIb XIXb XXb XXIb XXIIb XXIIIb XXIVb],"double"); %nota: os cabos estavam trocados, por isso, Qt=Ib e Qb=It
Qb = cast([It IIt IIIt IVt Vt VIt VIIt VIIIt IXt Xt XIt XIIt XIIIt XIVt XVt XVIt XVIIt XVIIIt XIXt XXt XXIt XXIIt XXIIIt XXIVt],"double");

events=size(EventPerFile,1);

%plot de cada strip
hold on;
for i = 1:5
    plot(QF(:,i),QB(:,i),'.');
end
hold off;
%% finas
ChargePerEvent_b = sum(Qb,2); 
ChargePerEvent_t = sum(Qt,2);    %max 512ADCbins*32DSampling*24strips ~400000
%uma forma de calcular a eficiencia da RPC: os PMTs dispararam mas a RPC nada viu, logo soma das cargas por evento (Q spectrum) -> mto perto de zero
%olhar para os espetros de carga top e bottom e ver qual é o limiar que consideramos nao ter carga ou nao ter visto (tem um pico inicial); 600 demasiado baixo -> dá Eff=5% com HV=0kV
I=find(ChargePerEvent_b <2100);    %limite inf da soma da Q nas 24 strips; 700 ou  800; para a multiplicidade usar threshold = 100 pq é um limite de Q por strip
eff_bottom = 100*(1-(size(I,1)/events));
I=find(ChargePerEvent_t <2000);
eff_top    = 100*(1-(size(I,1)/events));
%%{
tTH = 3; %time threshold [ns] to assume it comes from a good event; obriga a ter tempos nos 4 cint
restrictionsForPMTs = abs(Tl_cint(:,1)-Tl_cint(:,2)) <tTH & ...
                      abs(Tl_cint(:,1)-Tl_cint(:,3)) <tTH & ...
                      abs(Tl_cint(:,1)-Tl_cint(:,4)) <tTH & ...
                      abs(Tl_cint(:,2)-Tl_cint(:,3)) <tTH & ...
                      abs(Tl_cint(:,2)-Tl_cint(:,4)) <tTH & ...
                      abs(Tl_cint(:,3)-Tl_cint(:,4)) <tTH;
indicesGoodEvents=find(restrictionsForPMTs);
numberGoodEvents = length(indicesGoodEvents);
ChargePerEvent_b_goodEventsOnly= ChargePerEvent_b(indicesGoodEvents);
ChargePerEvent_t_goodEventsOnly= ChargePerEvent_t(indicesGoodEvents);
numberSeenEvents=length(find(ChargePerEvent_b_goodEventsOnly >1400));
eff_bottom_goodEventsOnly = 100*(numberSeenEvents/numberGoodEvents);
numberSeenEvents=length(find(ChargePerEvent_t_goodEventsOnly >1400));
eff_top_goodEventsOnly    = 100*(numberSeenEvents/numberGoodEvents);
figure; histogram(ChargePerEvent_b_goodEventsOnly, 0:200:5E4); ylabel('# of events'); xlabel('Q (bottom)'); title(sprintf('Q spectrum (sum of Q per event); Eff_{bot} = %2.2f%%', eff_bottom_goodEventsOnly));
figure; histogram(ChargePerEvent_t_goodEventsOnly, 0:200:5E4); ylabel('# of events'); xlabel('Q (top)'); title(sprintf('Q spectrum (sum of Q per event); Eff_{top} = %2.2f%%', eff_top_goodEventsOnly));
%%}


%%
% 5 hitogramas para strips gordas, Q em função # of events
first = 1; last = 5;
fig=figure('Position', [700 10 600 900]); hold on
for strip=first:last
    subplot(5,1,strip);
    histf(QF(:,strip),-2:0.1:150); hold on;
    histf(QB(:,strip),-2:0.1:150); xlim([-2 150]); legend(sprintf('QF - strip%d', strip), sprintf('QB - strip%d', strip), 'Location', 'northeast')
    %ylim([0 250]);
end
%return
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
    ylabel('# of events');
    xlabel('Q [ns]');
end
%}
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

%% calculo das cargas maximas e posição RAW em função de Qmax
[QFmax,XFmax] = max(QF_p,[],2);    %XFmax -> strip of Qmax
[QBmax,XBmax] = max(QB_p,[],2);

Ind2Cut   = find(~isnan(QF_p) & ~isnan(QB_p) & XFmax == XBmax);
[row,col] = ind2sub(size(TFl),Ind2Cut); %row=evento com Qmax na mesma strip; col=strip não interessa pois fica-se com a strip com Qmax
rows      = unique(row); %eventos sorted e sem repetiçoes
Ind2Keep  = sub2ind(size(TFl),rows,XFmax(rows)); %indices das Qmax, desde que QFmax e QBmax estejam na mesma strip

T = nan(rawEvents,1); Q = nan(rawEvents,1); X = nan(rawEvents,1); Y = nan(rawEvents,1);
T(rows) = (TFl(Ind2Keep) + TBl(Ind2Keep)) /2; %[ns]
Q(rows) = QF_p(Ind2Keep) + QB_p(Ind2Keep);    %[ns], soma das Qmax Front e Back -> com nans se algum evento não cumpre Ind2Keep
X(rows) = XFmax(rows);                        %strip #
Y(rows) = (TFl(Ind2Keep) - TBl(Ind2Keep)) /2; %[ns]
figure;
histogram(Q, 0:0.1:300);
STLevel = 100; %230 com as RPC de 1mm gap
Qmean = mean(Q, 'omitnan'); % Calculate mean while ignoring NaN values; média da 'soma das Qmax Front e Back' de todos os eventos
Qmedian = median(Q, 'omitnan'); %mediana
ST      = length(find(Q > STLevel))/rawEvents; %percentagem de streamers
%%%%%%%%%%%%%%%%%%
%return
%%{
%EFFICIENCY
tTH = 3; %time threshold [ns] to assume it comes from a good event; obriga a ter tempos nos 4 cint
restrictionsForPMTs = abs(Tl_cint(:,1)-Tl_cint(:,2)) <tTH & ...
                      abs(Tl_cint(:,1)-Tl_cint(:,3)) <tTH & ...
                      abs(Tl_cint(:,1)-Tl_cint(:,4)) <tTH & ...
                      abs(Tl_cint(:,2)-Tl_cint(:,3)) <tTH & ...
                      abs(Tl_cint(:,2)-Tl_cint(:,4)) <tTH & ...
                      abs(Tl_cint(:,3)-Tl_cint(:,4)) <tTH;
numberGoodEvents    = length(find(restrictionsForPMTs));
restrictionsForRPC  = any(QF_p,2) & any(QB_p,2); %QF_p e QB_p têm de ter em cada evento pelo menos 1 tempo
%restrictionsForRPC  = any(QF_p,2) & any(QB_p,2) & abs(T(:)-Tl_cint(:,2))<5; %QF_p e QB_p tem de ter em cada evento pelo menos 1 tempo; o tempo da RPC tem de estar a menos de 5ns do tempo dos PMTs
%restrictionsForRPC  = any(Q,2); %Q tem todas as restriçoes de QF_p e QB_p e tem de ter Qmax na mesma strip <- demasiado restritivo
numberSeenEvents    = sum(restrictionsForPMTs & restrictionsForRPC); %seen by PMTs AND RPCs (obrigar visto por pmts pois tb há triggers do SiPMs vistos pelas RPCs)
%numberNotSeenEvents = sum(restrictionsForPMTs & ~restrictionsForRPC); %seen by PMTs BUT NOT BY RPCs
Eff = numberSeenEvents * 100 / numberGoodEvents; %numberGoodEvents or rawEvents
%%}

%HISTOGRAM OF CHARGE WITH Q = SUM OF QFmax AND QBmax IF THEY ARE IN THE SAME STRIP
figure; histogram(Q, 0:400/200:400);     %histogram(Q_max, 0:400/200:400);
ylabel('# of events'); xlabel('Q [ns]'); title('Qspectrum (Qmax)'); %legend('gordas');

%return
%% evento nao vistos pela rpc

indices_not_seen = find(restrictionsForPMTs & ~restrictionsForRPC);
Qb_not_seen = ChargePerEvent_b(indices_not_seen);

figure;
histogram(Qb_not_seen, 0:200:5E4);
xlabel('Qb ');
ylabel('# of events');
title('Espetro de carga nas strips finas (baixo) para eventos não vistos pela RPC');


%% time resolution
%%{
%HISTOGRAM OF Qcint FOR EACH PMT AND SELECTION OF EVENTS FOR TEMPORAL RES - selecionar eventos nas matrizes de carga -> apenas o pico central
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
%remove events with at least a value = nan; ao usar Qcint -> obriga-se a haver tempos nos 4PMTs, igual a 'restrictionsForPMTs' no cálculo da eff; Q -> para o lado da RPC
%usando a slewing corr, polyfit não pode ter nans
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
%%}

%%

%return

%%{
%RESOLUÇÃO TEMPORAL SEM SLEWING CORRECTION -> tempo_cintiladores - tempo_RPC ou tempo_cintiladores_bottom - tempo_cintiladores_top
tempo1 = Tcint_mean_top;    %Tcint_mean_bot ou Tcint_mean_top
tempo2 = T;                 %T para a RPC; para os cint: Tcint_mean_bot ou Tcint_mean_top
Tdiff  = [tempo1 - tempo2]; %[ns];
figure; histogram(Tdiff, 0:0.05:20);xlabel('Tdiff [ns]'); ylabel('# of events'); title('TcintBottom - Trpc');
figure; histogram(Tdiff);,

%%%%%%%%%%%%%%%%%%
%se for necessário impor boundaries a Tdiff para o fit ser bem sucedido com bestFit.m:
%Tdiff(find((Tdiff < 12.5) | (Tdiff > 14.5))) = nan; %sigma 1 bot
Tdiff(find((Tdiff < 11) | (Tdiff > 12.1))) = nan; %sigma 2
%Tdiff(find((Tdiff < -2.7) | (Tdiff > -1.2))) = nan; %sigma 3
%Tdiff(find((Tdiff < 1.2) | (Tdiff > 2.7))) = nan; 
%figure; histogram(Tdiff);
%%%%%%%%%%%%%%%%%%
%search the best gaussian fit of the distribution:
binningRule = 1;    %1 -> use RICE rule; 2 -> use SCOTT rule; 3 -> use STURGES rule
distToFit = Tdiff;
[x_min,x_max,chi_sq, number_bins] = bestFit(distToFit, 2.0, 1.2, binningRule);    %e.g.: bestFit(distToFit, 2, 0.8, 1); (dist, extSigmaBound, intSigmaBound, binningRule)
%chi_sq não é usado mas permite comparar com chisq obtido mais abaixo com hfitg_altJPS; chi_sq e chisq têm de ser iguais
%x_min=0.5; x_max=1.5; number_bins=45; %forçar valores em vez de bestFit
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
yl = ylim; % Get limits of y axis so we can find a nice height for the text labels.
text(pars(1)+abs(pars(2)), 0.8 * yl(2), message, 'Color', 'r', 'FontSize', 12); %pode obter-se sigmas negativos com hfitg mas o módulo está correto; vê-se tb sigmas negativos mesmo centrando a dist primeiro)
xlabel('Tdiff [ns]','FontSize',14,'Color','k'); ylabel('# of events','FontSize',14,'Color','k'); title(sprintf('TcintBottom - Trpc; gaussian fit (borders: %.3f -> %.3f)', x_min, x_max));
xlim([x_min-x_bin*number_bins x_max+x_bin*number_bins]);
%FWHM=2.355*pars(2)/sqrt(2)    %for T=T1-T2
%%}

%return

%%{
%RESOLUÇÃO TEMPORAL COM SLEWING CORRECTION -> tempo_cintiladores - tempo_RPC ou tempo_cintiladores_bottom - tempo_cintiladores_top
tempo1 = Tcint_mean_top;    %Tcint_mean_bot ou Tcint_mean_top
tempo2 = T;                 %T para a RPC; para os cint: Tcint_mean_bot ou Tcint_mean_top
Tdiff  = [tempo1 - tempo2]; %[ns];
carga1 = Qcint_sum_top;     %Qcint_sum_bot ou Qcint_sum_top
carga2 = Q;                 %Q para a RPC; para os cint: Qcint_sum_bot ou Qcint_sum_top
%figure; histogram(Tdiff);
%%%%%%%%%%%%%%%%%%
%%{
%se for necessário impor boundaries a Tdiff para o fit ser bem sucedido com bestFit.m:

%Tdiff(find((Tdiff < 12.5) | (Tdiff > 14.5))) = nan; %sigma 1
Tdiff(find((Tdiff < 11) | (Tdiff > 12.1))) = nan; %sigma 2
%Tdiff(find((Tdiff < -2.7) | (Tdiff > -1.2))) = nan; %sigma 3
%Tdiff(find((Tdiff < 1.2) | (Tdiff > 2.7))) = nan;
%com a slewing corr, as matrizes em polyfit (script FitAndPlot.m) não podem ter nans:
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
message = sprintf('n = %d\n\\mu =  %.3f ns\n\\sigma = %.3f ns\n\\chi²/ndf = %.1f/%d', events_limited, pars(1), abs(pars(2)), chisq, ndf); %modulo do sigma pois hfitg pode resultar num valor neg -> ver mais abaixo explicação
yl = ylim; % Get limits of y axis so we can find a nice height for the text labels.
text(pars(1)+abs(pars(2)), 0.8 * yl(2), message, 'Color', 'r', 'FontSize', 12); %pode obter-se sigmas negativos com hfitg mas o módulo está correto; vê-se tb sigmas negativos mesmo centrando a dist primeiro)
xlabel('Tdiff [ns]','FontSize',14,'Color','k'); ylabel('# of events','FontSize',14,'Color','k'); title(sprintf('TcintBottom - Trpc w/ slewing corr. (borders: %.3f -> %.3f)', x_min, x_max));
xlim([x_min-x_bin*number_bins x_max+x_bin*number_bins]);
%FWHM=2.355*pars(2)/sqrt(2)    %for T=T1-T2
%%}


%return

% 
% %%{
% %ESPETRO DE CARGA
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
% %xlim([-10 100]); %ylim([0 7500]);
% %%}
% 
% 
% %return
% 
% 
% %%{
% %MULTIPLICITY (não se atribui um Qthreshold como se fez na MB48chs pq um th de -40mV já é colocado nas DB)
% IF=find(~isnan(QF_p)); MF=zeros(size(QF_p)); MF(IF)=1;
% IB=find(~isnan(QB_p)); MB=zeros(size(QB_p)); MB(IB)=1;
% 
% MperEventF=sum(MF,2);    %multiplicidade de todos os eventos, lado Front
% NperStripF=sum(MF,1);    %check hits per ch (# of values for each strip), lado Front
% MperEventB=sum(MB,2);    %multiplicidade de todos os eventos, lado Back
% NperStripB=sum(MB,1);    %check hits per ch (# of values for each strip), lado Back
% 
% figure; stairs(NperStripF); hold on
% stairs(NperStripB); xlim([0.5 5.5]); ylabel('# of hits (charge in both strip ends)'); xlabel('strip'); title('Hits per strip'); legend('front', 'back', 'Location', 'northwest')
% 
% figure; histogram(MperEventF, 0:1:6); hold on %alguns eventos de M=0 -> eventos de QF_p sem carga pq tempos em strips diferentes: I = find(~isnan(TFl) & ~isnan(TBl));
% hh = histogram(MperEventB, 0:1:6); xlabel('multiplicity','FontSize',14); ylabel('# of events','FontSize',14); title('Multiplicity per event (readout gordas)');
% legend('front', 'back', 'Location', 'northwest');
% 
% 
% %Events (with Qmax) per strip -> similar a NperStripF mas com Qmax e não as cargas todas
% figure; h=histogram(X); ylabel('# of events'); xlabel('strip'); title('Events (with Qmax) per strip');
% %com X mais restritivo que XFmax ou XBmax pq força ambos a estarem na mesma strip 
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
% if showMe2
%     figure; histf(Y_calibrated_ns,-15:0.01:15);
%     ylabel('# of events'); xlabel('Y [ns]'); title('Y projection');
% end
% %xmin = -0.82ns, xmax = 0.87ns; 0.87-(-0.82)=1.69ns; camada resistiva com ~29cm de comprimento ->  290mm/1.69ns = 171mm/ns
% %change from [ns] to [mm]
% vprop=171;    %171; 177; [mm/ns]
% X_= ((X -1) + (rand(length(X),1))) * 303/5; %30.3cm de largo / 5 strips gooordas
% Y_calibrated_mm = Y_calibrated_ns*vprop;
% 
% showMe3=1;
% if showMe3
%     % X: as strips estendem-se de 0 a 303mm; Y: as strips estendem-se de -190mm a 190mm mas a tinta resistiva vai apenas de -145mm a 145mm
%     %[XY] = STRATOS2DplotsXY(X_,Y_calibrated_mm,-10:10:370,-200:10:200); %X: -10:10:370 -> 380/10=38bins para 380mm -> 1bin/cm;Y:-200:10:200 -> 40bin/40cm -> 1bin/cm
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

