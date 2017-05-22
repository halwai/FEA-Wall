% Computes the element stiffness matrix.

% Input Parameter
%
% element_nodal_coordinates: The x, y and z coordinates of the element
% whose stiffness matrix is to be calculated.
%
% D: Stress = D * Strain.
%
% Output parameter
% stiff: Global Stiffness matrix

function [stiff] = octa_element_stiff(mod_of_elas, element_nodal_coordinates)

% For reference the images used:
%        (z)                         (5) _____________ (8)
%         ^                             /|           /|
%         |                            / |          / |
%         |                           /  |         /  |
%         |                      (6) /___|________/(7)|
%          --------> (y)             |   |________|___|(4)
%        /                           |(1)/        |   / 
%       /                            |  /         |  /
%      /                             | /          | /  
%    (x)                          (2)|/___________|/(3)

zeta_at_nodes = [-1, 1, 1, -1, -1, 1, 1, -1];
eta_at_nodes = [-1, -1, 1, 1, -1, -1, 1, 1];
nu_at_nodes = [-1, -1, -1, -1, 1, 1, 1, 1];
syms zeta eta nu;

%% Shape Function
% Shape functions for 4 noded rectangular element.
shape_function_matrix = [];
for i = 1:8
    N(i) = 1/8*(1 + zeta*zeta_at_nodes(i))*(1 + eta*eta_at_nodes(i))*(1 + nu*nu_at_nodes(i));
    shape_function_matrix = [shape_function_matrix,N(i)*eye(3)];
end

%% Jacobian Matrix
jacobian = sym(zeros(3,3));
intrinsic_coord = [zeta, eta, nu];

% This can be optimized if the later explained method is correct. Check
% that and proceed.

for i = 1:3
    for j = 1:3
        for k = 1:8
            jacobian(i,j) = jacobian(i,j) + element_nodal_coordinates(k, j)*diff(N(k),intrinsic_coord(i));
        end
    end
end
% By carefully studying the jacobian matrix we can clearly see that it is
% going to be a diagonal matrix. It is going to happen because of symmetry.
% Cross check it once then implement it so that we are not calculating the
% whole jacobian matrix again and again.

jacobian_testing = sym(zeros(3,3));
for i = 1:3
    jacobian_testing(i, i) = diff(N, intrinsic_coord(i))*element_nodal_coordinates(:, i);
end

inv_jaco = inv(jacobian_testing);


%%  Strain matrix B 
% Calculating the matrix of differentiation of shape function wrt intrinsic
% coordinates i.e. d(Ni)/d(zeta), d(Ni)/d(eta)
diff_row = sym(zeros(3, 8));
for i = 1:3
    diff_row(i, :) = diff(N, intrinsic_coord(i));
end

% Starin matrix calulation.
% strain_mat_initial contains the differentiation of shape funsiton wrt to
% the actual coordinates i.e. x,y and z
strain_mat_initial = jacobian_testing\diff_row;

for i = 1 : 8
    strain_mat(:, 3*(i-1) + 1: 3*i) = [
            diff_row(1, i)  0               0;
            0               diff_row(2, i)  0;
            0               0               diff_row(3, i);
            0               diff_row(3, i)  diff_row(2, i);
            diff_row(3, i)  0               diff_row(1, i);
            diff_row(2, i)  diff_row(1, i)  0;
        ];
end

%
a = mod_of_elas * (1-pois_ratio) / ((1- 2 * pois_ratio) * (1 + pois_ratio));
b = mod_of_elas * pois_ratio / ((1- 2 * pois_ratio) * (1 + pois_ratio));
G = mod_of_elas / (2 * (1 + pois_ratio));
D = [ a b b 0 0 0;
      b a b 0 0 0;
      b b a 0 0 0;
      0 0 0 G 0 0;
      0 0 0 0 G 0;
      0 0 0 0 0 G;
    ];

% Stress Strain relation, D matrix (Stress = D * Strain in 3 Dimension)
pre_stiff = strain_mat.' * D * strain_mat;

%% Stiffness Matrix Calulation

% Stiffness matrix is the integration of strain_mat.' x E x starin_mat over
% the volume which we will be doing by numerical integration.
[gaussian_points, weights] = gauss_quadrature(2);
 
stiff = zeros(24, 24);
for i = 1:length(weights)
    temp = gaussian_points;
    temp_pre_stiff = pre_stiff;
    temp_pre_stiff = subs(temp_pre_stiff, zeta, temp(i, 1));
    temp_pre_stiff = subs(temp_pre_stiff, eta, temp(i, 2));
    temp_pre_stiff = subs(temp_pre_stiff, nu, temp(i, 3));
    stiff = stiff + vpa(temp_pre_stiff);
end
