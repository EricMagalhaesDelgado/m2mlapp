function [startupFcnName, inputArgs, singleton] = startupFcnParser(cleanCode)
    
    startupFcnName = regexp(cleanCode, 'runStartupFcn\(app, @(\(app\))?(?<name>\w+)(\(app, ?varargin{:}\)\))?', 'names');
    inputArgs      = '';
    singleton      = '';

    if regexp(cleanCode, 'runningApp = getRunningApp\(app\);', 'once')
        singleton = 'FOCUS';
    end

    if numel(startupFcnName) > 1
        error('An app must have only one startup callback.')    
    elseif numel(startupFcnName) == 1
        startupFcnName = startupFcnName.name;
        inputArgs  = extractBetween(cleanCode, sprintf('function %s(app, ', startupFcnName), ')');
        
        if numel(inputArgs) == 1
            inputArgs = char(inputArgs);        
        elseif numel(inputArgs) > 1
            error('An app must have only one declaration of startup function.')
        end
    else
        startupFcnName = {};
    end

end