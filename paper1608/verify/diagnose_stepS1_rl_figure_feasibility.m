function diagnose_stepS1_rl_figure_feasibility()
    % DIAGNOSE_STEPS1_RL_FIGURE_FEASIBILITY
    % Read-only feasibility audit for the paper's Figs. 4 (cost-to-go) and
    % 5 (actor RBF output), computed from the accepted Phase C 100s
    % dataset. Run BEFORE writing any Fig.4/5 plotting code, so that the
    % figures are built with an honest, quantified statement of what they
    % can and cannot reproduce -- rather than discovering the gap after
    % the fact or silently rescaling to make the plot "look right".
    %
    % Central question: the paper's own Fig. 4 shows the cost-to-go
    % plateauing at 0.85e8 / 1.4e8 / 2.1e8 (recorded in docs/HANDOFF.md from a
    % direct render of the source PDF). This project's critic uses
    % Chat = Wc' * theta_c(chi) with ||Wc|| <= delta_c and theta_c a
    % vector of m_c Gaussian RBFs each in (0,1]. Cauchy-Schwarz therefore
    % caps |Chat| at delta_c * sqrt(m_c) REGARDLESS of the trajectory.
    % delta_c=100 is this project's own ASSUMED value (Table 1 gives no
    % numeric delta_c/delta_a) -- see Issue N. This script quantifies the
    % resulting gap and the delta_c that Fig. 4's scale would demand.
    %
    % Does not modify any production file.

    paths = project_paths();

    cfg = nn_config();
    d = load(fullfile(paths.phase_c, 'phase_c_result_t100.mat'));
    res = d.res;
    params = res.params;
    N = numel(res.t);

    fprintf('=== Step S1: Fig.4/Fig.5 reproduction feasibility ===\n\n');

    % --- Analytic ceiling on the critic output ---------------------------
    ceiling = cfg.delta_c * sqrt(cfg.critic_n_nodes);
    fprintf('Critic: m_c=%d nodes, delta_c=%.1f\n', cfg.critic_n_nodes, cfg.delta_c);
    fprintf('  Cauchy-Schwarz ceiling |Chat| <= delta_c*sqrt(m_c) = %.4f\n', ceiling);
    fprintf('  Paper Fig.4 plateaus (from docs/HANDOFF.md, direct PDF render): 0.85e8 / 1.4e8 / 2.1e8\n');
    fprintf('  => ceiling is %.3e times SMALLER than the paper''s smallest plateau (0.85e8)\n\n', ...
        0.85e8 / ceiling);

    % --- Actual trajectory values ---------------------------------------
    Chat = zeros(N, 3);
    theta_c_norm = zeros(N, 3);
    Wc_norm = zeros(N, 3);
    theta_a_max = zeros(N, 3);      % max activation across all 6 DOF x 25 nodes
    theta_a_sum_max = zeros(N, 3);  % max over DOF of sum_k theta_a(k)
    f_rl_absmax = zeros(N, 3);

    for k = 1:N
        Xk = res.X(k, :).';
        [eta_m, nu_m, ~, Wa_l, Wc_m] = unpack_states(Xk, cfg);
        for i = 1:3
            eta_i = eta_m(:, i); nu_i = nu_m(:, i);
            J = jacobian_J(eta_i); eta_dot_i = J * nu_i;
            [chi_i, vel_err_i] = formation_error(eta_i, eta_dot_i, res.t(k), i);

            th_c = critic_basis(chi_i, cfg);
            Chat(k, i) = Wc_m(:, i).' * th_c;
            theta_c_norm(k, i) = norm(th_c);
            Wc_norm(k, i) = norm(Wc_m(:, i));

            best = 0; best_sum = 0;
            for j = 1:6
                th_a = actor_basis(chi_i(j), vel_err_i(j), cfg);
                best = max(best, max(th_a));
                best_sum = max(best_sum, sum(th_a));
            end
            theta_a_max(k, i) = best;
            theta_a_sum_max(k, i) = best_sum;

            f_rl = actor_output(chi_i, vel_err_i, Wa_l{i}, cfg);
            f_rl_absmax(k, i) = max(abs(f_rl));
        end
    end

    fprintf('--- Fig.4 candidate quantity: Chat_i(t) = Wc_i'' * theta_c(chi_i) ---\n');
    for i = 1:3
        fprintf('  AUV%d: min=%.4f  max=%.4f  final=%.4f  (|Chat| ceiling %.2f)\n', ...
            i - 1, min(Chat(:, i)), max(Chat(:, i)), Chat(end, i), ceiling);
    end
    fprintf('  max ||Wc|| over run = %.4f (delta_c=%.1f), max ||theta_c|| = %.4f (sqrt(m_c)=%.4f)\n', ...
        max(Wc_norm(:)), cfg.delta_c, max(theta_c_norm(:)), sqrt(cfg.critic_n_nodes));

    needed_delta_c = 0.85e8 / max(max(theta_c_norm(:)), eps);
    fprintf('  delta_c that Fig.4''s SMALLEST plateau (0.85e8) would require, at the\n');
    fprintf('  observed max ||theta_c||=%.4f: delta_c >= %.4e (vs. assumed %.1f)\n\n', ...
        max(theta_c_norm(:)), needed_delta_c, cfg.delta_c);

    fprintf('--- Fig.5 candidate quantity: actor RBF activations theta_a ---\n');
    fprintf('  max single-node activation over whole run: %.6f (RBF range is (0,1] by construction)\n', ...
        max(theta_a_max(:)));
    fprintf('  max over-DOF sum of 25 activations:       %.6f\n', max(theta_a_sum_max(:)));
    fprintf('  paper Fig.5 stated y-range (docs/HANDOFF.md): [0, 1.5]\n');
    fprintf('  => individual activations are IN RANGE; the 25-node sum is NOT necessarily.\n\n');

    fprintf('--- Actor network OUTPUT f_RL = Wa'' * theta_a (the other reading of "actor output") ---\n');
    for i = 1:3
        fprintf('  AUV%d: max|f_RL| = %.6f\n', i - 1, max(f_rl_absmax(:, i)));
    end

    fprintf('\n=== VERDICT ===\n');
    if max(abs(Chat(:))) <= ceiling + 1e-9
        fprintf('Chat respects its analytic ceiling (consistency check PASS).\n');
    else
        fprintf('FAIL: Chat exceeded its own analytic ceiling -- implementation inconsistency.\n');
    end
    fprintf(['Fig.4 CANNOT be quantitatively reproduced at the paper''s 1e8 scale under the\n' ...
        'assumed delta_c=100: the projection bound caps the cost-to-go %.2e times below it,\n' ...
        'independent of trajectory quality. This is Issue N (delta_c/delta_a are NOT given\n' ...
        'numeric values by the paper), not a convergence or integrator defect. Fig.4 must be\n' ...
        'published as a SHAPE/qualitative reproduction with the scale gap stated explicitly.\n'], ...
        0.85e8 / ceiling);
    fprintf(['Fig.5 IS reproducible in range: RBF activations are in (0,1] by construction and\n' ...
        'the paper''s stated [0,1.5] axis accommodates them.\n']);

    if ~exist(paths.phase_c_work, 'dir')
        mkdir(paths.phase_c_work);
    end
    output_path = fullfile(paths.phase_c_work, 'stepS1_rl_feasibility.mat');
    save(output_path, 'Chat', 'theta_c_norm', 'Wc_norm', ...
        'theta_a_max', 'theta_a_sum_max', 'f_rl_absmax', 'ceiling');
    fprintf('\nSaved raw series to %s\n', output_path);
end
