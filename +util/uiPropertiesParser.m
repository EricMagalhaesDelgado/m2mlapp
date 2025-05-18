function uiProperties = uiPropertiesParser(matlabCode, treeCode)

    splitCode  = splitlines(matlabCode);

    % Parsing the first block (properties), identifying the names of the 
    % objects and their position in the "genealogical graphical tree", 
    % which is sorted as follows:
    % (a) Parents above children; and
    % (b) Younger siblings above older ones.
    blockCode1 = splitCode(treeCode.Line(1)+2:treeCode.EndLine(1));
    blockCode1 = regexprep(blockCode1, '%.*$', '');
    propNames  = struct2table(regexp(strjoin(blockCode1, '\n'), '(?<name>\w+)\s+(?<class>[\w.]+)', 'names'));
    propNames  = addvars(propNames, (1:height(propNames))', 'Before', 1, 'NewVariableNames', 'id');
    

    % Parsing the second last block (createComponents function)
    blockCode2 = util.removeNonExecutingCode(strjoin(splitCode(treeCode.Items{end-1}{1}.Position(1)+2:treeCode.Items{end-1}{1}.EndPosition(1)), '\n'));
    
    propCode   = struct2table(regexp(blockCode2, 'app[.](?<name>\w+)\s*=\s*(?<fcn>[\w.]+)', 'names'));
    nProperties = height(propCode);
    
    blockCode2 = splitlines(blockCode2);

    propCode.parent            = repmat({{}}, nProperties, 1);
    propCode.CodeContent       = repmat({{}}, nProperties, 1);
    % propCode.CodeRow           = repmat({[]}, nProperties, 1);
    propCode.callbackName      = repmat({{}}, nProperties, 1);
    propCode.callbackFcn       = repmat({{}}, nProperties, 1);
    % propCode.stackGeneration   = zeros(nProperties, 1);
    propCode.stackChildrens    = zeros(nProperties, 1);
    % propCode.stackSiblingOrder = zeros(nProperties, 1);

    % nonProperties = table('Size', [0,2],                       ...
    %                       'VariableTypes', {'cell', 'double'}, ...
    %                       'VariableNames', {'CodeContent', 'CodeRow'});

    for ii = 1:numel(blockCode2)
        objName = regexp(blockCode2{ii}, 'app[.](?<name>\w+)', 'names');

        if ~isempty(objName)
            objName = objName(1).name;
            
            idx1 = find(strcmp(propCode.name, objName));
            idx2 = [];

            objCallback = regexp(blockCode2{ii}, 'app[.](?<name>\w+)[.](?<callbackName>\w+)\s*=\s*createCallbackFcn\(\s*app\s*,\s*@(?<callbackFcn>\w+)\s*,\s*true\s*\)', 'names');
            switch numel(objCallback)
                case 0
                    objParent = regexp(blockCode2{ii}, 'app[.](?<name>\w+)[.]?[\w.]*\s*=\s*[\w.]+\(app[.](?<parent>\w+).*\)', 'names');
                    if ~isempty(objParent)
                        idx2 = find(strcmp(propCode.name, objParent.parent));
                    end

                    mapNameFrom = {['app.' objName], ['app.' objParent.parent]};
                    mapNameTo   = {'app.ad_CODENAME_ad', 'app.ad_PARENTCODENAME_ad'};

                    switch propCode.fcn{idx1}
                        case 'uifigure'
                            if isempty(idx2)
                                propCode.parent{idx1} = 'groot';

                                % propCode.stackGeneration(idx1)   = 1;
                                % propCode.stackSiblingOrder(idx1) = 1;
                            end

                        otherwise
                            if ~isempty(idx2)
                                propCode.stackChildrens(idx2) = propCode.stackChildrens(idx2)+1; % Update parent info
                                propCode.parent{idx1}         = propCode.name{idx2}; % Children info

                                % propCode.stackGeneration(idx1)   = propCode.stackGeneration(idx2)+1;
                                % propCode.stackSiblingOrder(idx1) = propCode.stackChildrens(idx2);
                            end
                    end

                case 1
                    mapNameFrom = {['app.' objName], extractAfter(blockCode2{ii}, '=')};
                    mapNameTo   = {'app.ad_CODENAME_ad',  sprintf(' ''%s'';', strtrim(char(extractBetween(blockCode2{ii}, '@', ','))))};
            end
    
            propCode.CodeContent{idx1}  = [propCode.CodeContent{idx1}; replace(blockCode2{ii}, mapNameFrom, mapNameTo)];
            % propCode.CodeRow{idx1}    = [propCode.CodeRow{idx1}, ii];
            propCode.callbackName{idx1} = [propCode.callbackName{idx1}; objCallback.callbackName];
            propCode.callbackFcn{idx1}  = [propCode.callbackFcn{idx1};  objCallback.callbackFcn];

        else
            % nonProperties(end+1,:) = {blockCode2{ii}, ii};
        end
    end


    % Join info in a single table...
    uiProperties = join(propCode, propNames, 'Keys', 'name');

end