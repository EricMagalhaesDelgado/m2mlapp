function [uiFigure, customComponents, tempFilePath, screenshotPath] = DesignTimeProperties(mPath, ClassName, matlabCode, uiProperties, ScreenshotFlag)

    tempClass = ['m2mlapp_' datestr(now, 'yyyymmddTHHMMSS')];
    tempCode  = replace(matlabCode, {sprintf('classdef %s < matlab.apps.AppBase', ClassName), ...
                                     sprintf('function app = %s', ClassName),                 ...
                                     'runStartupFcn(app',                                     ...
                                     sprintf('app.%s.Visible', uiProperties.name{1})},        ...
                                    {sprintf('classdef %s < matlab.apps.AppBase', tempClass), ...
                                     sprintf('function app = %s', tempClass),                 ...
                                     '% runStartupFcn(app',                                   ...
                                     sprintf('%% app.%s.Visible', uiProperties.name{1})});


    % Simulate the app creation, avoiding its startup function.
    try
        if ~util.isOnMATLABPath(mPath)
            addpath(mPath)
        end
        
        tempFilePath = fullfile(mPath, [tempClass '.m']);

        fileID = fopen(tempFilePath, "w");
        fprintf(fileID, '%c', tempCode);
        fclose(fileID);
        
        app = eval(tempClass);
        drawnow


        % "DesignTimeProperties" property creation, and custom components
        % mapping.
        matlabComponentsList = struct(appdesigner.internal.application.getComponentAdapterMap()).serialization.keys';
        customComponents = {};
        
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

                    if numel(imgPieces) == 1
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
            addprop(objHandle, 'DesignTimeProperties');
            objHandle.DesignTimeProperties = struct('CodeName', uiProperties.name{ii},             ...
                                                    'GroupId', '',                                 ...
                                                    'ComponentCode', uiProperties.CodeContent(ii), ...
                                                    'ImageRelativePath', imgRelativePath);
        end


        % screenshot of the app (this part is not essential)
        screenshotPath = '';
        if ScreenshotFlag
            try
                screenshotPath = [tempname, '.png'];
                exportapp(uiFigure, screenshotPath)
            catch ME
                disp(getReport(ME))
                screenshotPath = '';
            end
        end


        % uiFigure stacking order, ennsuring that the visual stacking of UI 
        % components respects what is established in the properties section 
        % of the components.
        idx3 = find(uiProperties.stackChildrens > 1)';
        for ll = idx3
            objParent = app.(uiProperties.name{ll});
            
            % Desirable stacking order
            desirableOrder = uiProperties.name(strcmp(uiProperties.parent, uiProperties.name{ll}));

            % Situation table
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
        throwAsCaller(ME)
    end

end