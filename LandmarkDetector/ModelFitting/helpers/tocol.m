function [ out ] = tocol(in)
%TOCOL returns the input as a column vector
%useful to avoid temporary variables, for example:
%tmp = f(x); y = g(tmp(:));       will become
%y = g(tocol(f(x)))
out = in(:);
