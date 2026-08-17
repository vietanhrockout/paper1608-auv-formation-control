function series = compute_phase_c_series(res)
    % COMPUTE_PHASE_C_SERIES
    % Shared, read-only recompute of all per-timestep physical quantities
    % needed by the Fig.2/3/6/7/8/9 plotting functions, from a saved Phase
    % C result struct (res.t, res.X, res.params). Centralizing this avoids
    % 6 copies of the same unpack/formation_error/sliding_surface loop.
    %
    % series fields (all indexed AUV 1=leader/AUV0, 2=AUV1, 3=AUV2, matching
    % formation_offsets.m / analyze_phase_c_result.m convention):
    %   .t            [N x 1]   time
    %   .eta          [N x 6 x 3]  physical pose (x,y,z,phi,theta,psi)
    %   .eta_d0       [N x 6]      virtual leader reference trajectory
    %   .chi          [N x 6 x 3]  formation tracking error (Eq. 5)
    %   .s            [N x 6 x 3]  sliding surface (Eq. 21)
    %   .leader_rel   [N x 6 x 3]  eta_i(t) - eta_1(t) (actual leader-relative
    %                              distance; leader_rel(:,:,1) is identically 0)
    %   .offsets      [6 x 3]      configured formation offsets (formation_offsets.m)

    cfg = nn_config();
    params = res.params;
    N = numel(res.t);

    eta = zeros(N, 6, 3);
    eta_d0 = zeros(N, 6);
    chi = zeros(N, 6, 3);
    s = zeros(N, 6, 3);

    offsets = formation_offsets();

    for k = 1:N
        Xk = res.X(k, :).';
        [eta_m, nu_m, ~, ~, ~] = unpack_states(Xk, cfg);
        [eta_d0_k, ~, ~] = reference_1608(res.t(k));
        eta_d0(k, :) = eta_d0_k.';
        for i = 1:3
            eta(k, :, i) = eta_m(:, i).';
            eta_i = eta_m(:, i); nu_i = nu_m(:, i);
            J = jacobian_J(eta_i); eta_dot_i = J * nu_i;
            [chi_i, vel_err_i] = formation_error(eta_i, eta_dot_i, res.t(k), i);
            chi(k, :, i) = chi_i.';
            s(k, :, i) = sliding_surface(chi_i, vel_err_i, params).';
        end
    end

    leader_rel = zeros(N, 6, 3);
    for i = 1:3
        leader_rel(:, :, i) = eta(:, :, i) - eta(:, :, 1);
    end

    series = struct();
    series.t = res.t;
    series.eta = eta;
    series.eta_d0 = eta_d0;
    series.chi = chi;
    series.s = s;
    series.leader_rel = leader_rel;
    series.offsets = offsets;
end
