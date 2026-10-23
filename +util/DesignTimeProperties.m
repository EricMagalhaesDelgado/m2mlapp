function [uiFigure, customComponents, tempFilePath, screenshotPath, imageRelativePaths] = DesignTimeProperties(mPath, className, matlabCode, uiProperties, screenshotFlag)

    % Unique per call (millisecond + random suffix), because MATLAB caches class definitions.
    tempClass = sprintf('m2mlapp_%s_%04d', char(datetime('now', 'Format', 'yyyyMMdd''T''HHmmssSSS')), randi(9999));
    tempCode  = replace(matlabCode, {sprintf('classdef %s < matlab.apps.AppBase', className), ...
                                     sprintf('function app = %s', className),                 ...
                                     'runStartupFcn(app',                                     ...
                                     sprintf('app.%s.Visible', uiProperties.name{1})},        ...
                                    {sprintf('classdef %s < matlab.apps.AppBase', tempClass), ...
                                     sprintf('function app = %s', tempClass),                 ...
                                     '% runStartupFcn(app',                                   ...
                                     sprintf('%% app.%s.Visible', uiProperties.name{1})});



    % Simulate the app creation, avoiding its startup function.
    try
        [rootPath, packagePrefix] = util.packageRoot(mPath);
        if ~util.isOnMATLABPath(rootPath)
            addpath(rootPath)
        end
        
        tempFilePath = fullfile(mPath, [tempClass '.m']);

        fileID = fopen(tempFilePath, "w");
        fwrite(fileID, unicode2native(tempCode, 'UTF-8'), 'uint8');
        fclose(fileID);
        
        % MATLAB caches folder contents (and packages), so the new file is only found after a rehash.
        numAttempts = 10;
        for attempt = 1:numAttempts
            if isfile(tempFilePath)
                rehash
                drawnow
                try
                    app = eval([packagePrefix tempClass]);
                    break
                catch ME
                    if attempt == numAttempts
                        rethrow(ME)
                    end
                end
            elseif attempt == numAttempts
                error('m2mlapp:TempClassNotFound', 'The temporary file "%s" was not created.', tempFilePath)
            end
            pause(.100)
        end
        drawnow


        % "DesignTimeProperties" property creation, and custom components
        % mapping.
        warnState = warning('off', 'MATLAB:structOnObject');
        matlabComponentsList = struct(appdesigner.internal.application.getComponentAdapterMap()).serialization.keys';
        warning(warnState)
        customComponents = {};
        imageRelativePaths = {};
        uiProperties.CodeContent{1}(end) = []; % app.UIFigure.Visible = 'on';

        for ii = 1:height(uiProperties)
            objHandle = app.(uiProperties.name{ii});
            set(objHandle, HandleVisibilityMode = 'manual', ...
                           CreateFcnMode        = 'manual', ...
                           TagMode              = 'manual')

            switch class(objHandle)
                case 'matlab.ui.Figure'
                    set(objHandle, CloseRequestFcnMode  = 'manual', ...
                                   SizeChangedFcnMode   = 'manual', ...
                                   ColormapMode         = 'manual')
                    uiFigure = objHandle;
    
                otherwise
                    if ~ismember(class(objHandle), matlabComponentsList)
                        customComponents{end+1} = class(objHandle);
                    end
            end
    

            % Callbacks
            for jj = 1:numel(uiProperties.callbackName{ii})
                objHandle.(uiProperties.callbackName{ii}{jj}) = uiProperties.callbackFcn{ii}{jj};
            end
            

            % MATLAB R2022a release notes
            % "When you specify image data for your app, select an image that 
            % is in the same folder as the MLAPP file or one of its subfolders. 
            % The image will then load whenever the app is opened or run without 
            % it needing to be on the MATLAB path. Alternatively, you can continue 
            % to use images in any location by adding the image files to
            % the MATLAB path."
            imgRelativePath = '';
            for kk = numel(uiProperties.CodeContent{ii}):-1:1
                if ~isempty(regexp(uiProperties.CodeContent{ii}{kk}, '^app[.][\w_.]+\s*=\s*fullfile(pathToMLAPP,.*', 'once'))
                    imgPieces = strtrim(strsplit(char(extractBetween(uiProperties.CodeContent{ii}{kk}, 'fullfile(pathToMLAPP,', ');')), ','));

                    if isscalar(imgPieces)
                        imgPieces = char(replace(imgPieces, '''', ''));
                        imgRelativePath = imgPieces;
                        if isfile(fullfile(mPath, imgPieces))
                            imgPieces = fullfile(mPath, imgPieces);
                        end

                    elseif numel(imgPieces) > 1
                        imgRelativePath = strjoin(replace(imgPieces, '''', ''), '/');
                        if isfile(fullfile(mPath, imgRelativePath))
                            imgPieces = fullfile(mPath, imgRelativePath);
                        else
                            imgPieces = char(replace(imgPieces{end}, '''', ''));
                        end                        
                    end
                    uiProperties.CodeContent{ii}{kk} = sprintf('%s = ''%s'';', strtrim(extractBefore(uiProperties.CodeContent{ii}{kk}, '=')), imgPieces);
                end
            end


            % "DesignTimeProperties" property
            if ~isempty(imgRelativePath) && ~ismember(imgRelativePath, imageRelativePaths)
                imageRelativePaths{end+1} = imgRelativePath;
            end

            addprop(objHandle, 'DesignTimeProperties');
            objHandle.DesignTimeProperties = struct('CodeName', uiProperties.name{ii},             ...
                                                    'GroupId', '',                                 ...
                                                    'ComponentCode', uiProperties.CodeContent(ii), ...
                                                    'ImageRelativePath', imgRelativePath);
        end


        % screenshot of the app (this part is not essential)
        screenshotPath = '';
        if screenshotFlag
            try
                screenshotPath = [tempname, '.png'];
                exportapp(uiFigure, screenshotPath)
            catch ME
                disp(getReport(ME))
                screenshotPath = '';
            end
        end


        % Children order as saved by AppDesigner: newest first (reverse of the creation
        % order in createComponents), except tabs and tree nodes, which keep the creation order.
        for ll = find(uiProperties.stackChildrens > 1)'
            objParent = app.(uiProperties.name{ll});

            desirableOrder = uiProperties.name(strcmp(uiProperties.parent, uiProperties.name{ll}));
            if ~ismember(class(objParent), {'matlab.ui.container.TabGroup', 'matlab.ui.container.Tree', 'matlab.ui.container.CheckBoxTree', 'matlab.ui.container.TreeNode'})
                desirableOrder = flipud(desirableOrder);
            end

            stackTable = table('Size', [0, 3],                                ...
                               'VariableTypes', {'cell', 'double', 'double'}, ...
                               'VariableNames', {'name', 'actualOrder', 'desirableOrder'});

            for mm = 1:numel(objParent.Children)
                childrenName = objParent.Children(mm).DesignTimeProperties.CodeName;
                stackTable(end+1,:) = {childrenName, mm, find(strcmp(desirableOrder, childrenName), 1)};
            end

            if ~isequal(desirableOrder, stackTable.name)
                stackTable = sortrows(stackTable, 'desirableOrder');
                objParent.Children = objParent.Children(stackTable.actualOrder);
            end
        end

    catch ME
        if exist('app', 'var') && isvalid(app)
            delete(app)
        end

        if exist('tempFilePath', 'var') && isfile(tempFilePath)
            delete(tempFilePath)
        end

        throwAsCaller(ME)
    end

end