function [ x ] = minmax( x, mini, maxi)
%MINMAX truncate x to [mini...maxi]
x = min(max(x,mini),maxi);

