function [XY,XY_Q,XY_ST] = STRATOS2Dplots(X,Y,Q,binsX,binsY,STLevel)

XY     = zeros(length(binsX)-1,length(binsY)-1);
XY_Q   = cell(length(binsX)-1,length(binsY)-1);
XY_ST  = zeros(length(binsX)-1,length(binsY)-1);

for i=1:length(binsX)-1
    for j= 1:length(binsY)-1
        I = find(X > binsX(i) & X <= binsX(i+1) & Y > binsY(j) & Y <= binsY(j+1));
        XY(i,j)     = length(I);
        XY_Q{i,j}   = Q(I);
        XY_ST(i,j)  = length(find(Q(I) > STLevel));
    end
end