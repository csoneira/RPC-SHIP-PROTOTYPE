function Tfited = FitAndPlot(X, Y, polynomialDegree, showPlots)
p = polyfit(X,Y,polynomialDegree);    %Fit polynomial. P = POLYFIT(X,Y,N) finds the coefficients of a polynomial P(X) of degree N
Tfit   = polyval(p,X);
Tfited = Y - Tfit;
if showPlots
    figure; subplot(1,2,1); plot(X, Y, '.'); xlim([min(X)-20 max(X)+20]); ylim([-10 10]); ylabel('Time [ns]'); xlabel('Charge [ns]');
    hold on; plot(X, Tfit, '.g'); legend('time vs. charge', 'fit')
    subplot(1,2,2); plot(X, Tfited, '.'); xlim([min(X)-20 max(X)+20]); ylim([-10 10]); ylabel('Time [ns]'); xlabel('Charge [ns]'); legend('time-fit vs. charge')
end
%[ny,nx]=histf(Tfited,-3.:0.1:3); [parout, chisq] = hfitg(nx,ny,showPlots);
%T_Res_slewCorr=parout(2)/sqrt(2);
end