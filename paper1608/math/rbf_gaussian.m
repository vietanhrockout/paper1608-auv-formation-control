function theta = rbf_gaussian(input_vec, centers, width)
    % RBF_GAUSSIAN Computes Gaussian Radial Basis Function activation vector (Eq. 14)
    % theta_k(I) = exp( - ||I - c_k||^2 / width^2 )
    % Inputs:
    %   input_vec: n x 1 input vector
    %   centers: n x m matrix of RBF node centers
    %   width: scalar Gaussian width l_k
    % Output:
    %   theta: m x 1 activation vector
    
    m_nodes = size(centers, 2);
    theta = zeros(m_nodes, 1);
    
    for k = 1:m_nodes
        diff_c = input_vec - centers(:, k);
        norm_sq = sum(diff_c .^ 2);
        theta(k) = exp(-norm_sq / (width ^ 2));
    end
end
