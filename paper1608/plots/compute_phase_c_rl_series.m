function rl = compute_phase_c_rl_series(res, actor_dof)
    % COMPUTE_PHASE_C_RL_SERIES
    % Read-only recompute of the RL/NN-side per-timestep quantities needed
    % by Figs. 4 (cost-to-go) and 5 (actor RBF output). Kept separate from
    % compute_phase_c_series.m because these are the PROVISIONAL figures
    % (Issue M/K/N) and are deliberately not part of the accepted
    % physical-state figure pipeline.
    %
    % actor_dof (default 3 = heave/z): which DOF's actor basis
    %   theta_a(chi_j, upsilon_j) to expose for Fig. 5. The actor RBF is
    %   defined PER DOF (Eq. 32 -- input xbar_aij = [chi_ij, upsilon_ij]),
    %   so any Fig. 5 rendering must pick one; z is chosen because it
    %   carries the largest initial formation error (chi_z(0)=16 for AUV0)
    %   and therefore the most informative activation sweep. This choice
    %   is a REPRODUCTION ASSUMPTION -- the paper does not state which DOF
    %   its Fig. 5 shows.
    %
    % rl fields:
    %   .t          [N x 1]        time
    %   .Chat       [N x 3]        critic cost-to-go estimate Wc_i'*theta_c(chi_i)  (Eq. 14)
    %   .theta_a    [N x 25 x 3]   actor RBF activations for DOF actor_dof
    %   .f_rl       [N x 6 x 3]    actor network output Wa_i'*theta_a       (Eq. 32)
    %   .Wc_norm    [N x 3]        ||Wc_i||  (to show projection-boundary pinning)
    %   .Wa_norm    [N x 3]        ||Wa_i||_F (same, for the actor bound)
    %   .actor_dof  scalar         the DOF used for .theta_a

    if nargin < 2 || isempty(actor_dof)
        actor_dof = 3;
    end

    cfg = nn_config();
    N = numel(res.t);

    Chat = zeros(N, 3);
    theta_a = zeros(N, cfg.actor_n_nodes, 3);
    f_rl = zeros(N, 6, 3);
    Wc_norm = zeros(N, 3);
    Wa_norm = zeros(N, 3);

    for k = 1:N
        Xk = res.X(k, :).';
        [eta_m, nu_m, ~, Wa_l, Wc_m] = unpack_states(Xk, cfg);
        for i = 1:3
            eta_i = eta_m(:, i); nu_i = nu_m(:, i);
            J = jacobian_J(eta_i); eta_dot_i = J * nu_i;
            [chi_i, vel_err_i] = formation_error(eta_i, eta_dot_i, res.t(k), i);

            Chat(k, i) = critic_output(chi_i, Wc_m(:, i), cfg);
            Wc_norm(k, i) = norm(Wc_m(:, i));
            Wa_norm(k, i) = norm(Wa_l{i}, 'fro');
            theta_a(k, :, i) = actor_basis(chi_i(actor_dof), vel_err_i(actor_dof), cfg).';
            f_rl(k, :, i) = actor_output(chi_i, vel_err_i, Wa_l{i}, cfg).';
        end
    end

    rl = struct();
    rl.t = res.t;
    rl.Chat = Chat;
    rl.theta_a = theta_a;
    rl.f_rl = f_rl;
    rl.Wc_norm = Wc_norm;
    rl.Wa_norm = Wa_norm;
    rl.actor_dof = actor_dof;
end
