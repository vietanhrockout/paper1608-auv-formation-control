function verify_step39_actor_update()
    % VERIFY_STEP39_ACTOR_UPDATE Verifies Model-Free Actor update law gradient descent (Paper Eq. 37, 38)
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'math'));
    addpath(fullfile(project_root, 'control'));
    addpath(fullfile(project_root, 'nn'));
    
    params = paper_params();
    cfg = nn_config();
    chi_i = [1; -1; 0.5; -0.1; 0.05; -0.01];
    vel_err_i = [0.1; -0.05; 0.02; -0.01; 0.005; -0.002];
    Wa_i = zeros(cfg.actor_n_nodes, 6);
    Wc_i = zeros(cfg.critic_n_nodes, 1);
    
    dWa_i = actor_update(chi_i, vel_err_i, Wa_i, Wc_i, params, cfg);
    
    C_hat_i = critic_output(chi_i, Wc_i, cfg);
    for j = 1:6
        th_aj = actor_basis(chi_i(j), vel_err_i(j), cfg);
        f_rl_j = Wa_i(:, j)' * th_aj;
        arg_tanh = f_rl_j + params.c0a * C_hat_i;
        desired_j = -params.lambda_a * tanh(arg_tanh) * th_aj;
        if norm(dWa_i(:, j) - desired_j) > 1e-12
            error('STEP 39: FAIL - Actor update for DOF %d does not match Paper Eq. (37)', j);
        end
    end
    
    fprintf('STEP 39: PASS\n');
end
