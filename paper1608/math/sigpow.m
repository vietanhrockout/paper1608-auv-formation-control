function y = sigpow(x, a)
    % SIGPOW Evaluates the signed power operator sig^a(x) = |x|^a * sgn(x)
    % Inputs:
    %   x: scalar, vector, or matrix input
    %   a: exponent power
    % Output:
    %   y: evaluated signed power with preserved sign and no complex numbers
    
    y = sign(x) .* (abs(x) .^ a);
end
