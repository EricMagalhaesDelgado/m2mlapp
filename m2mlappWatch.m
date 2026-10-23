function watcher = m2mlappWatch(folder, varargin)
%M2MLAPPWATCH
% M2MLAPPWATCH monitors a folder and regenerates the .MLAPP file (through
% m2mlapp) whenever the equivalent .M file (classdef ... < matlab.apps.AppBase)
% is created or modified.
%
% SYNTAX:
% watcher = m2mlappWatch(folder, Name, Value)
% m2mlappWatch('stop')   % stops all watchers
%
% OPTIONAL NAME-PARAMETERS ARGUMENTS:
% - Recursive   logical = false  Also monitors the subfolders.
% - Period      double  = 1      Polling period (seconds).
% - Screenshot  logical = true   Passed to m2mlapp.
% - Block       logical = false  Blocks until Ctrl+C. Useful for headless use:
%                                matlab -batch "m2mlappWatch(pwd, 'Block', true)"
%
% Notes:
% (a) Only .M files that already have a .MLAPP with the same name are monitored.
%     At start, .M files missing for an existing .MLAPP are extracted from it, and
%     .MLAPP files older than the .M are regenerated.
% (b) A change is only converted after the .M stops changing for one period
%     (editors may save in more than one write).
% (c) The app is never opened in AppDesigner by the watcher. Close the app in
%     AppDesigner before editing the .M, otherwise AppDesigner holds a stale copy.

    if nargin == 1 && strcmpi(folder, 'stop')
        stopAll();
        return
    end

    validators.mustBeScalarText(folder)

    p = inputParser;
    addParameter(p, 'Recursive',  true,  @islogical)
    addParameter(p, 'Period',     1,     @(x) isnumeric(x) && isscalar(x) && x > 0)
    addParameter(p, 'Screenshot', true,  @islogical)
    addParameter(p, 'Block',      false, @islogical)
    parse(p, varargin{:});

    folder = char(folder);
    if ~isfolder(folder)
        error('The folder "%s" does not exist.', folder)
    end
    folder = char(java.io.File(folder).getCanonicalPath());

    stopAll(folder)

    state = struct('Folder',     folder,                ...
                   'Recursive',  p.Results.Recursive,   ...
                   'Screenshot', p.Results.Screenshot,  ...
                   'Initial',    true,                  ...
                   'Seen',       containers.Map(),      ... % path -> [datenum bytes] last observed
                   'Done',       containers.Map(),      ... % path -> [datenum bytes] last converted
                   'IsApp',      containers.Map());         % path -> logical

    watcher = timer('Name',          ['m2mlappWatch:' folder], ...
                    'ExecutionMode', 'fixedSpacing',           ...
                    'BusyMode',      'drop',                   ...
                    'Period',        p.Results.Period,         ...
                    'UserData',      state,                    ...
                    'TimerFcn',      @poll);
    start(watcher)
    fprintf('[m2mlappWatch] Monitoring "%s".\n', folder)

    if p.Results.Block
        cleanupObj = onCleanup(@() stopAll(folder));
        while isvalid(watcher) && strcmp(watcher.Running, 'on')
            pause(0.5)
        end
    end
end

%-----------------------------------------------------------------%
function poll(t, ~)
    state = t.UserData;

    if state.Initial
        extractMissingMFiles(state)
    end

    try
        if state.Recursive
            listing = dir(fullfile(state.Folder, '**', '*.m'));
        else
            listing = dir(fullfile(state.Folder, '*.m'));
        end
    catch
        return
    end

    for ii = 1:numel(listing)
        % Skip temporary classes created by m2mlapp, and folders named *.m.
        if listing(ii).isdir || startsWith(listing(ii).name, 'm2mlapp_')
            continue
        end

        mFile = fullfile(listing(ii).folder, listing(ii).name);
        mlappFile = [mFile(1:end-2) '.mlapp'];
        if ~isfile(mlappFile)
            continue
        end

        stamp = [listing(ii).datenum, listing(ii).bytes];

        if isKey(state.Done, mFile) && isequal(state.Done(mFile), stamp)
            continue
        end

        % Debounce: only converts when the file is stable between two polls.
        firstSeen = ~isKey(state.Seen, mFile);
        stable    = ~firstSeen && isequal(state.Seen(mFile), stamp);
        state.Seen(mFile) = stamp;
        if ~stable && ~(firstSeen && state.Initial)
            if isKey(state.IsApp, mFile)
                state.IsApp.remove(mFile);
            end
            continue
        end

        if ~isKey(state.IsApp, mFile)
            state.IsApp(mFile) = isAppBaseClass(mFile);
        end
        if ~state.IsApp(mFile)
            state.Done(mFile) = stamp;
            continue
        end

        % At start, an up-to-date .MLAPP is not rebuilt.
        if state.Initial
            mlappInfo = dir(mlappFile);
            if mlappInfo.datenum >= listing(ii).datenum
                state.Done(mFile) = stamp;
                continue
            end
        end

        fprintf('[m2mlappWatch] %s: converting "%s"...\n', char(datetime('now', 'Format', 'HH:mm:ss')), mFile)
        tStart = tic;
        result = m2mlapp(mFile, 'OpenApp', false, 'Screenshot', state.Screenshot);
        if isempty(result)
            fprintf(2, '[m2mlappWatch] Conversion failed: "%s".\n', mFile);
        else
            fprintf('[m2mlappWatch] Done in %.1f s.\n', toc(tStart))
        end

        % Failed conversions are not retried until the .M changes again.
        state.Done(mFile) = stamp;
    end

    state.Initial = false;
    t.UserData    = state;
end

%-----------------------------------------------------------------%
function extractMissingMFiles(state)
    if state.Recursive
        mlappList = dir(fullfile(state.Folder, '**', '*.mlapp'));
    else
        mlappList = dir(fullfile(state.Folder, '*.mlapp'));
    end

    for ii = 1:numel(mlappList)
        [~, name] = fileparts(mlappList(ii).name);
        mlappFile = fullfile(mlappList(ii).folder, mlappList(ii).name);
        mFile     = fullfile(mlappList(ii).folder, [name '.m']);

        if mlappList(ii).isdir || endsWith(name, '_m2mlapp_tmp') || isfile(mFile)
            continue
        end

        try
            matlabCode = util.extractMATFile(mlappFile);
            writematrix(matlabCode, mFile, 'FileType', 'text', 'QuoteStrings', false)
            fprintf('[m2mlappWatch] Extracted "%s".\n', mFile)

            % The extracted .M is already in sync with the .MLAPP.
            mInfo = dir(mFile);
            state.Done(fullfile(mInfo.folder, mInfo.name)) = [mInfo.datenum, mInfo.bytes];
        catch ME
            fprintf(2, '[m2mlappWatch] Extraction failed for "%s": %s\n', mlappFile, ME.message);
        end
    end
end

%-----------------------------------------------------------------%
function flag = isAppBaseClass(mFile)
    flag = ~isempty(regexp(fileread(mFile), '^\s*classdef\s+\w+\s*<\s*matlab\.apps\.AppBase', 'once', 'lineanchors'));
end

%-----------------------------------------------------------------%
function stopAll(folder)
    timers = timerfindall;

    if isempty(timers)
        return
    end

    names  = {timers.Name};
    if nargin
        timers = timers(strcmp(names, ['m2mlappWatch:' folder]));
    else
        timers = timers(startsWith(names, 'm2mlappWatch:'));
    end

    if isempty(timers)
        return
    end

    stop(timers)
    delete(timers)
end