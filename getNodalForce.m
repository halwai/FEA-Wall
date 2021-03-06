function [nodal_force] = getNodalForce(force_type, no_elements, load_vec)
%**************************************************************************
% Computes nodal force from provided constant force value.
%**************************************************************************
%
% Input parameters:
% force_type  - String storing force type i.e. body/surface/point load.
% no_elements - Total number of elements.
% load_value  - Load value vector consisting of constant force value in x,
%               y and z direction
%

%%
nodal_force = zeros(24, 1, no_elements);
for ii = 1:no_elements
    nodal_force(:, :, ii) = getEleNodalBodyForce(load_vec(1),load_vec(2), load_vec(3));
end
% size(nodal_force);