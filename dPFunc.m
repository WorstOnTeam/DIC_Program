function out = dPFunc(dx,dy)
%DPFUNC
%    OUT = DPFUNC(DX,DY)

%    This function was generated by the Symbolic Math Toolbox version 7.2.
%    28-Nov-2017 11:07:25

out = reshape([1.0,0.0,dx,0.0,dy,0.0,0.0,1.0,0.0,dx,0.0,dy],[2,6]);
