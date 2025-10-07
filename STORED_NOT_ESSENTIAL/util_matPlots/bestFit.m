function [X_min,X_max,Chisq, Number_bins]=bestFit(distributionToFit, extSigmaBound, intSigmaBound, binningRule)
%SEARCH FOR BEST FIT BOUNDARIES - START WITH AN INITIAL QUICK FIT AND TEST SEVERAL BOUNDS TO FIND THE LOWER CHI²/NDF 

%figure; histfit(distributionToFit);
pd = fitdist(distributionToFit, 'Normal');
boundExternal = extSigmaBound*pd.sigma;   %varer x_min de e.g. 2 sigma abaixo de miu
boudInternal  = intSigmaBound*pd.sigma;   %até e.g. 0.4 sigma abaixo de miu (0.4*sigma ou 0.8*sigma ou 1.2*sigma...)
steps         = pd.sigma/20;              %usando steps de sigma/20

bestValues = [];
for x_min = pd.mu-boundExternal:steps:pd.mu-boudInternal
    for x_max = pd.mu+boudInternal:steps:pd.mu+boundExternal %o mesmo com x_max mas acima de miu e não abaixo
        Xdiff_limited_mm = distributionToFit;
        Xdiff_limited_mm(find(distributionToFit > x_max)) = nan;
        Xdiff_limited_mm(find(distributionToFit < x_min)) = nan;
        events_limited = nnz(~isnan(Xdiff_limited_mm));
        if binningRule == 1
            %NUMBER OF BINS VIA THE RICE RULE -> ceil(2*(events_limited)^(1/3)) %simple alternative to Sturges' rule (wiki)
            number_bins=floor(2*(events_limited)^(1/3));    %uso floor em vez de ceil para a Rice rule
            x_bin=abs(x_max-x_min)/number_bins;
        elseif binningRule == 2
            %NUMBER OF BINS VIA SCOTT RULE -> 3.49*pd.sigma / (events_limited^(1/3)) %optimal for random samples of normally distributed data; sensitive to outliers in data
            x_bin = 3.49*pd.sigma / (events_limited^(1/3));
            number_bins = ceil(abs(x_max-x_min)/x_bin);
            x_bin=abs(x_max-x_min)/number_bins;
        elseif binningRule == 3
            %NUMBER OF BINS VIA STURGES RULE -> ceil(1+3.3*log10(events_limited)) %perform poorly if n < 30, because the number of bins will be small
            number_bins=ceil(1+3.3*log10(events_limited));
            x_bin=abs(x_max-x_min)/number_bins;
        end
        [ny,nx] = histf(Xdiff_limited_mm, x_min:x_bin:x_max);
        [pars,chisq] = hfitg(nx,ny);
        if isempty(bestValues)
            bestValues(1) = x_min;
            bestValues(2) = x_max;
            bestValues(3) = chisq;
            bestValues(4) = number_bins;
        else
            if chisq < bestValues(3)
                bestValues(1) = x_min;
                bestValues(2) = x_max;
                bestValues(3) = chisq;
                bestValues(4) = number_bins;
            end
        end
    end
end

X_min       = bestValues(1);
X_max       = bestValues(2);
Chisq       = bestValues(3);
Number_bins = bestValues(4);
