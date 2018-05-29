function [ d ] = diff_matrix( s )
%DIFF_MATRIX returns a vector element difference matrix for vectors of the specified length

if  s < 2
    error('size must be greater than 2');
end

d=[1 -1];

for i = 2:s-1
   nd = [ones(i,1), -eye(i)];
   pad = zeros(size(d,1),1);
   d=[nd; pad, d];
end

end

