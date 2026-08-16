function e_ai = actor_error(f_rl, f_target)
    % ACTOR_ERROR Computes Actor estimation error vector e_{ai} (Eq. 34)
    % e_{ai} = f_{iRL} - f_{target}
    % Inputs:
    %   f_rl: 6x1 NN drift approximation
    %   f_target: 6x1 target drift (f_true in benchmark, or sliding surface surrogate)
    
    e_ai = f_rl - f_target;
end
