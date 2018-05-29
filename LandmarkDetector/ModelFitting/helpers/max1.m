function [ out ] = max1( in, stop )
%DIFF1 normalizes the input "in" to [min/max...1] over the first "stop" dimensions
%default: all dimensions
if nargin < 2
    stop = inf;
end

m = in;
for i = 1:min(stop,ndims(in))
    m = max(m);
end
out = bsxfun(@rdivide,in,m);
