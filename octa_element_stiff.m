function [ele_stiffness, jacobian, jacobian_testing, nodal_coordinates, pre_stiff, stiff] =  octa_element_stiff(mesh_size, element_no, dimension, mesh_meta_data, D)

% For reference the images used:
%
%      (z)   (x                             (5) ___________ (8)  
%       |   /                                  |\          |\
%       |  /                                   | \         | \
%       | /                                    |  \________|__\    
%       |/__________ (y)                       |  |(6)     |  |(7)
%                                          (1) |__|________|  | 
%                                              \  |     (4)\  |   
%                                               \ |         \ |   
%                                             (2)\|__________\|(3)       

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

%% Element's Meta Data Calculation

% layer if the layer of cube mesh repeated over the depth. Layer = 0 would
% mean first layer and 1 would mean the second layer behind the first one
% and so on.
layer = floor((element_no-1)/(mesh_meta_data(1)*mesh_meta_data(2)));

% Element number is updated by taking its mod with the total number of
% elements in one layer so that now that will be like its first layer only
% (Here we mean that numbering will become equivalent to first layer
% numbering).
temp_ele_no = element_no;
temp = mod(element_no, mesh_meta_data(1)*mesh_meta_data(2));
if temp
    element_no = temp;
else
    element_no = mesh_meta_data(1)*mesh_meta_data(2);
end

% Row at which the element falls.
row = floor(element_no/mesh_meta_data(2));

% Index along y-direction of the element.
temp2 = mod(element_no, mesh_meta_data(2));
if temp2
    index = temp2;
else
    index = mesh_meta_data(2);
end

% Intial coordinates of the first vertex of the cube. Look at the above
% referenced image for clearence. First nodes coordinates.
initial_coord = [layer*mesh_size, (index-1)*mesh_size, row*mesh_size];

% Coordinates of all the elemental nodes in global coordinate system.
x = [initial_coord(1);
    initial_coord(1)+mesh_size;
    initial_coord(1)+mesh_size;
    initial_coord(1);
    initial_coord(1);
    initial_coord(1)+mesh_size;
    initial_coord(1)+mesh_size;
    initial_coord(1);
    ];
       
y = [initial_coord(2);
    initial_coord(2);    
    initial_coord(2)+mesh_size;
    initial_coord(2)+mesh_size;
    initial_coord(2);
    initial_coord(2);
    initial_coord(2)+mesh_size;
    initial_coord(2)+mesh_size;
    ];

z = [initial_coord(3);
    initial_coord(3);
    initial_coord(3);
    initial_coord(3);
    initial_coord(3)+mesh_size;
    initial_coord(3)+mesh_size;
    initial_coord(3)+mesh_size;
    initial_coord(3)+mesh_size;
    ];
nodal_coordinates = [x, y, z];

%% Jacobian Matrix
jacobian = sym(zeros(3,3));
intrinsic_coord = [zeta, eta, nu];

% This can be optimized if the later explained method is correct. Check
% that and proceed.
for i = 1:3
    for j = 1:3
        for k = 1:8
            jacobian(i,j) = jacobian(i,j) + nodal_coordinates(k, j)*diff(N(k),intrinsic_coord(i));
        end
    end
end

% By carefully studying the jacobian matrix we can clearly see that it is
% going to be a diagonal matrix. It is going to happen because of symmetry.
% Cross check it once then implement it so that we are not calculating the
% whole jacobian matrix again and again.

jacobian_testing = sym(zeros(3,3));
for i = 1:3
    jacobian_testing(i, i) = diff(N, intrinsic_coord(i))*nodal_coordinates(:, i);
end

inv_jaco = inv(jacobian_testing);
ele_stiffness = 0;


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
strain_mat_initial = inv_jaco*diff_row;

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
%     zeta = temp(1);
%     eta = temp(2);
%     nu = temp(3);
    temp_pre_stiff = subs(temp_pre_stiff, zeta, temp(i, 1));
    temp_pre_stiff = subs(temp_pre_stiff, eta, temp(i, 2));
    temp_pre_stiff = subs(temp_pre_stiff, nu, temp(i, 3));
    stiff = stiff + vpa(temp_pre_stiff);
%     syms zeta eta nu;

end