function [XY] = STRATOS2DplotsXY(X,Y,binsX,binsY)

XY     = zeros(length(binsX)-1,length(binsY)-1);

for i=1:length(binsX)-1
    for j= 1:length(binsY)-1
        I = find(X > binsX(i) & X <= binsX(i+1) & Y > binsY(j) & Y <= binsY(j+1));
        XY(i,j)     = length(I);
    end
end
