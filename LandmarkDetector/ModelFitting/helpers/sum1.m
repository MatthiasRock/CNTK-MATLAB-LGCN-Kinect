function [ out ] = sum1( in, stop )
%DIFF1 normalizes the input "in" so that it sums to 1 over the first "stop" dimensions
%0/0 is treated as 0
%default: all dimensions
if nargin < 2
    stop = inf;
end

m = in;
for i = 1:min(stop,ndims(in))
    m = sum(m);
end
out = bsxfun(@rdivide,in,m);
out(isnan(out))=0;
