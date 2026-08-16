function y = sigpow_negative(x, a, mode, eps_v)
    % SIGPOW_NEGATIVE Evaluates negative signed power sig^a(x) where a < 0
    % Used for terms like sig^{1 - \alpha_1}(v_i) where 1 - \alpha_1 = -0.2
    % Modes:
    %   'literal': Direct evaluation sign(x) .* (abs(x).^a), returning 0 at x=0 since sign(0)=0.
    %   'regularized': Regularized evaluation sign(x) .* ((abs(x) + eps_v).^a)
    
    if nargin < 3 || isempty(mode)
        mode = 'regularized';
    end
    if nargin < 4 || isempty(eps_v)
        eps_v = 1e-6;
    end
    
    if strcmp(mode, 'literal')
        y = zeros(size(x));
        nz = (x ~= 0);
        y(nz) = sign(x(nz)) .* (abs(x(nz)) .^ a);
    else
        y = sign(x) .* ((abs(x) + eps_v) .^ a);
    end
end
