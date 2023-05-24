function mustBeMajorDotMinorFormatVersion(x)
%MUSTBEMAJORDOTMINORFORMATVERSION
% MUSTBEMAJORDOTMINORFORMATVERSION(x) throws an error if a not scalar text 
% of class "char" or "string" is passed, or if the text is not in the 
% "Major.Minor" format.

% Author.: Eric Magalhães Delgado
% Date...: May 23, 2023
% Version: 1.00
    
    Fcn = @(x) (ischar(x) | (isstring(x) & isscalar(x))) & ~isempty(regexp(x, '^\d+\.\d+$', 'once'));
    
    if ~Fcn(x)
        error('Input must be a text in the "Major.Minor" format, such as "1.00" or "1.01".');
    end
end