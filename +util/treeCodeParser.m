function [editableSection, callbacksFcn, startupFcn] = treeCodeParser(matlabCode, treeTable, startupFcnName)

    splitCode = splitlines(matlabCode);

    % An app class is divided in at least three blocks editables and 
    % non-editables, like described below.
    % (a) Section  1
    %     App components properties
    %     Non-editable
    %
    % (b) Section 2 to END-2 or END-3 (OPTIONAL BLOCKS)
    %     User's properties & functions
    %     Editable
    %
    % (c) Section END-2 (OPTIONAL BLOCK)
    %     User's callbacks & startupFcn
    %     Non-editable / Editable
    %
    % (d) Section END-1
    %     createComponents
    %     Non-editable
    %
    % (e) Section END
    %     construct/delete functions
    %     Non-editable

    editableSection = {};
    callbacksFcn    = struct('Name', {}, 'Code', []);
    startupFcn      = struct('Name', startupFcnName, 'Code', []);    

    if height(treeTable) > 3
        beginBlock = treeTable.Line(end-1)+1;
        endBlock   = treeTable.EndLine(end-1)+1;
    
        callbacksFcnNames = regexp(strjoin(splitCode(beginBlock:endBlock), '\n'), 'createCallbackFcn\(app, @(?<name>\w+), true\)', 'names');
        callbacksFcnNames = {callbacksFcnNames.name};

        % callbacksFcn & startupFcn
        if ~isempty(startupFcn) || ~isempty(callbacksFcnNames)        
            for ii = 1:numel(treeTable.Items{end-2})
                fcnName  = treeTable.Items{end-2}{ii}.Name;
                
                beginFcn = treeTable.Items{end-2}{ii}.Position(1)+2;
                endFcn   = treeTable.Items{end-2}{ii}.EndPosition(1);
    
                switch fcnName
                    case startupFcnName
                        startupFcn.Code          = splitCode(beginFcn:endFcn)';
    
                    case callbacksFcnNames
                        callbacksFcn(end+1).Name = fcnName;
                        callbacksFcn(end).Code   = splitCode(beginFcn:endFcn)';
                end
            end
        end

        % EditableSectionCode
        beginSection = min([treeTable.EndLine(1)+3, treeTable.Line(2)+1]);
        if ~isempty(callbacksFcn); endSection = max([treeTable.EndLine(end-3)+1, treeTable.Line(end-2)-2]);
        else;                      endSection = max([treeTable.EndLine(end-2)+1, treeTable.Line(end-1)-2]);
        end

        editableSection = splitCode(beginSection:endSection)';
    end

end