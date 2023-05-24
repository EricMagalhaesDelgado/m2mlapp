function mustBeScalarText(x)
%MUSTBESCALARTEXT
% MUSTBESCALARTEXT(x) throws an error if a not scalar text of class
% "char" or "string" is passed.

% Author.: Eric Magalhães Delgado
% Date...: May 12, 2023
% Version: 1.00
    
    Fcn = @(x) ischar(x) | (isstring(x) & isscalar(x));
    
    if ~Fcn(x)
        error('Input is not a scalar text of class "char" or "string".');
    end
end