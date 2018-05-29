function [ out ] = diff1( in, stop )
%DIFF1 normalizes the input "in" to [0...1] over the first "stop" dimensions
%default: all dimensions
if nargin < 2
    stop = inf;
end

m = in;
for i = 1:min(stop,ndims(in))
    m = min(m);
end
m = bsxfun(@minus,in,m);
out = max1(m,stop);