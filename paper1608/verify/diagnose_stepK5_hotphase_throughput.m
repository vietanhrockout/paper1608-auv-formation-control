function diagnose_stepK5_hotphase_throughput(t_hot_final, h)
% DIAGNOSE_STEPK5_HOTPHASE_THROUGHPUT
%
% Empirically measure wall-clock throughput of projected_rk4_integrate
% over a candidate "hot phase" horizon/step, to size Step K.5's hybrid
% integrator before committing to a full Phase B.2 (15s) run.
%
% NO controller/model modification. Uses unchanged production defaults
% (tau_cmd_raw reward -- SUPERSEDED 2026-08-18 by tau_act_saturated; delta_c=100, delta_a=50).

    if nargin < 1 || isempty(t_hot_final)
        t_hot_final = 0.02;
    end
    if nargin < 2 || isempty(h)
        h = 1e-6;
    end

    project_root = fileparts(fileparts(mfilename('fullpath')));

    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'model'));
    addpath(fullfile(project_root, 'reference'));
    addpath(fullfile(project_root, 'math'));
    addpath(fullfile(project_root, 'control'));
    addpath(fullfile(project_root, 'nn'));
    addpath(fullfile(project_root, 'simulation'));

    params  = simulation_params();
    sat_cfg = saturation_config();
    cfg     = nn_config();

    fprintf('\n============================================================\n');
    fprintf(' STEP K.5 -- HOT-PHASE THROUGHPUT TEST\n');
    fprintf('============================================================\n');
    fprintf('t_hot_final = %.6e s, h = %.6e s -> %d steps\n', ...
        t_hot_final, h, ceil(t_hot_final/h));
    fprintf('delta_c = %.3e, delta_a = %.3e (production defaults)\n', cfg.delta_c, cfg.delta_a);

    [eta_init, nu_init] = initial_conditions();
    omega_aw = zeros(6,3);
    Wa = {zeros(cfg.actor_n_nodes,6), zeros(cfg.actor_n_nodes,6), zeros(cfg.actor_n_nodes,6)};
    Wc = zeros(cfg.critic_n_nodes,3);
    X0 = pack_states(eta_init, nu_init, omega_aw, Wa, Wc, cfg);

    [t_hot, X_hot, stats] = projected_rk4_integrate(t_hot_final, h, X0, params, sat_cfg, cfg);

    fprintf('\nRESULT:\n');
    fprintf('steps               = %d\n', stats.nsteps);
    fprintf('elapsed wall time   = %.3f s\n', stats.elapsed);
    fprintf('steps/sec           = %.1f\n', stats.nsteps/max(stats.elapsed,1e-9));
    fprintf('max retraction norm = %.6e\n', stats.max_retraction);
    fprintf('total retractions   = %d\n', stats.total_retracted);

    % Endpoint weight norms
    Xend = X_hot(end,:).';
    [eta_e, nu_e, ~, Wa_e, Wc_e] = unpack_states(Xend, cfg);

    Wc_norm = zeros(1,3);
    Wa_norm = zeros(1,3);
    for i = 1:3
        Wc_norm(i) = norm(Wc_e(:,i));
        Wa_norm(i) = norm(Wa_e{i}, 'fro');
    end

    fprintf('\nEndpoint (t=%.6e s):\n', t_hot(end));
    fprintf('||Wc|| per AUV   = [%.6e %.6e %.6e] (delta_c=%.1f)\n', Wc_norm, cfg.delta_c);
    fprintf('||Wa||_F per AUV = [%.6e %.6e %.6e] (delta_a=%.1f)\n', Wa_norm, cfg.delta_a);

    assert(all(Wc_norm <= cfg.delta_c + 1e-9), 'K.5 FAIL: Wc exceeded delta_c.');
    assert(all(Wa_norm <= cfg.delta_a + 1e-9), 'K.5 FAIL: Wa exceeded delta_a.');
    assert(~any(isnan(Xend)) && ~any(isinf(Xend)), 'K.5 FAIL: NaN/Inf in endpoint state.');

    fprintf('\nSTATUS: PASS -- structural bounds held, state finite.\n');

    % Extrapolate to a hypothetical full hot-phase horizon
    est_150ms = stats.elapsed * (0.15/t_hot_final);
    fprintf('\nExtrapolated wall time for a 0.15s hot phase at this h: %.1f s\n', est_150ms);
end
