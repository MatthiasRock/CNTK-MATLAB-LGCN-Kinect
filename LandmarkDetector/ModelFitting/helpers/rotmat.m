function [ mat ] = rotmat( theta )
%ROTMAT returns a rotation matrix for 2d vectors

theta = -theta; %matlab plotting compatibility
c = cosd(theta);
s = sind(theta);
mat = [c -s; s c];
end

