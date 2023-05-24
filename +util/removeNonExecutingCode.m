function cleanCode = removeNonExecutingCode(matlabCode)
    
    cleanCode = splitlines(matlabCode);

    for ii = numel(cleanCode):-1:1
        lineCode = strtrim(cleanCode{ii});
        if isempty(lineCode) || ~isempty(regexp(lineCode, '^\%.*', 'once'))
            cleanCode(ii) = [];
        else
            cleanCode{ii} = lineCode;
        end
    end
    
    cleanCode  = strjoin(cleanCode, '\n');

    % I tried to use appdesigner.internal.codegeneration.removeNonExecutingCode,
    % but there is a BUG when the function is dealing with a line that have 
    % comment after a code, or a formatSpec (like '%s', or '%.3f', for example).

    % matlabCleanCode = appdesigner.internal.codegeneration.removeNonExecutingCode(matlabCode);

end