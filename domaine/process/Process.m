classdef (Abstract) Process < handle & matlab.mixin.Heterogeneous & matlab.mixin.Copyable
    %
    % Class: Process
    %
    % Process Properties:
    %   Name - Name of the process.        
    %   fName - Name of the function.
    %   Date - Date of creation.
    %   Parameters - Structure with parameters.
    %   Documentation - Documentation about the process.
    %   sProcess - Structure with information about the function.
    %   History - History.
    %
    % Process Methods:
    %   Process - Constructor.
    %   addParameter - Adds a new parameter to the process.
    %   print - Displays the process.
    %   printDocumentation - Displays Documentation
    %   webDocumentation - Open web page with Brainstorm documentation.
    %   printParametersWithValuesWithValues [Protected] - Format parameters to characters.
    %   addProcessToHistory [Protected] - Adds a new entry to history.  
    
    properties (Access = public)
        
        Name; % [char] only keywords
        fName; % [char] only keywords
        Date; % [char] YYYY-MM-DD-HH-MM-SS
        Parameters;  % [struct] the fields are keywords
        Documentation; % [char]
        sProcess; % [struct] Generated by Brainstorm
        History; % [cell]
        
    end
    
    properties (Access = protected)
        
        IsGeneral; % [logical] True if process can be applied to EEG or MEG, False otherwise
        Util = Utility.instance();
        GeneralProcesses = [...
            "Review Raw Files", ...
            "Notch Filter", ...
            "Band-Pass Filter", ...
            "Power Spectrum Density", ...
            "ICA", ...
            "Export To BIDS"];
        
    end
    
    properties (Abstract, Access = protected)
        
        Type; % [char] EEG/MEG
        Analyzer; % [Analyzer] Store an Analyzer (EEG_Analyzer or MEG_Analyzer).
        SpecificProcesses; % [string]
        
    end
    
    methods (Access = public)
                
        function obj = Process(nameOrStructure, parameterStructure)
            
            obj.Date = Utility.get_Time_Now();
            
            if isempty(parameterStructure)
                
                if isstruct(nameOrStructure)
                    obj.constructorWithStructure(nameOrStructure);
                    return
                
                elseif ischar(nameOrStructure)
                    obj.constructorWithName(nameOrStructure);
                    return
                end
                
            else
                
                if ischar(nameOrStructure) && isstruct(parameterStructure)
                    obj.constructorWithName(nameOrStructure);
                    obj.asgParameterStructure(parameterStructure);
                    return
                end
            end
            
            error('No constructor available for this input');
        end
        
        function addParameter(obj, field, parameter)
           % obj.addParameter(field, parameter)
           % Adds the field 'field' and the corresponding value 'parameter' to the parameter structure of the process 'obj'.
           %
           % PRECONDITION:  The field must be of type characters.
           %                The field must be a keyword.
           %
           % param[in]: field [char]
           %            parameter [~]
           
           arguments 
               obj Process
           end
           arguments (Repeating)
               field char
               parameter
           end
           
           % Assert the field is valid
           assert(all(cellfun(@(x) isfield(obj.Parameters, x), field)), ...
               ['Wrong field name.' newline ...
                'Here are the possible field names:' newline newline ...
                obj.printParameterFields()]);
           
           % Assert the parameter class is valid
           assert(all(cellfun(@(x, y) isa(x, class(obj.Parameters.(y))), parameter, field)), ...
               ['Wrong value class.' newline ...
                'Here are the possible value class for each field:' newline newline ...
                obj.printParameterFields()]);
           
           
            % Add field-parameter entry as key-value in the parameter structure.
            for i = 1:length(field)

                obj.Parameters.(field{i}) = parameter{i};

            end
           
        end
       
        function asgParameterStructure(obj, parameterStructure)
            
            assert(isstruct(parameterStructure));
            
            if obj.verifyParameterStructure(parameterStructure)
                
                
            obj.Parameters = parameterStructure;
            
            end
            
        end
        
        function asgDocumentation(obj, documentation)
            % obj.addDocumentation(documentation)
            % Add documentation to the process 'obj'.
            %
            % PRECONDITION: The documentation must be of type characters.
            %
            % param[in]: documentation [char]
            
            assert(ischar(documentation));
            
            obj.Documentation = documentation;
            
        end
        
        function ch = print(obj)
            % Displays the process.
            
            % param[out]: Process formated [char]
            
            ch =    [convertStringsToChars(obj.Name) sprintf('\n\t\t') ...
                    char(strjoin(obj.printParametersWithValues(), '\n\t\t'))];
        end
        
        function ch = printDocumentation(obj)
           % Displays the documentation.
           % param[out]: Documentation formated [char]
           
           ch = [obj.Name, sprintf('\n\t\t'), obj.Documentation];
           
        end
        
        function webDocumentation(obj)
           % Open web documentation from Brainstorm website.
            
            web(obj.sProcess.Description);
        
        end

        function sFilesOut = run(obj, sFilesIn)

            arguments
                obj Process
                sFilesIn struct = [];
            end
            
           sFilesOut = struct.empty();
            
           switch obj.fName
               
               case 'process_import_data_raw'
                        for i = 1:length(obj.Parameters.Subjects)
                            sFilesOut{i} = obj.Analyzer.reviewRawFiles(...
                                obj.Parameters.Subjects{i}, ...
                                obj.Parameters.RawFiles{i});
                        end
                        
                case 'process_notch'
                    sFilesOut = obj.Analyzer.notchFilter(sFilesIn, obj.Parameters.Frequence);
                   
                case 'process_bandpass'
                    sFilesOut = obj.Analyzer.bandPassFilter(sFilesIn, obj.Parameters.Frequence);

                case 'process_psd'
                    sFilesOut = obj.Analyzer.powerSpectrumDensity(sFilesIn, obj.Parameters.WindowLength);

                case 'process_ica'
                    sFilesOut = obj.Analyzer.ica(sFilesIn, obj.Parameters.NumberOfComponents);

                case 'process_export_bids'
                    sFilesOut = obj.Analyzer.convertToBids(sFilesIn, obj.Parameters.Folder, ...
                        obj.Parameters.DataFileFormat);   
           end
           
        end
        
        function isEqual = eq(obj, process)

            arguments
                obj Process
                process Process;
            end
            
            isEqual = true;
            
            if isempty(obj) || isempty(process)
                isEqual = false;
                return
            
            elseif not(strcmp(obj.Type, process.Type))
                isEqual = false;
                return
                
            elseif not(strcmp(obj.Name, process.Name))
                isEqual = false;
                return
                
            elseif ~isequal(obj.Parameters, process.Parameters)
                isEqual = false;
                return
                
            end
            
        end
        
        function quickImport(obj, folderToImport, extension)
            
            arguments
                obj Process
                folderToImport char = [];
                extension char = '.eeg';
            end
            
            % Pre-condition
            % Assert process is Review Raw Files
            assert(strcmp(obj.fName, 'process_import_data_raw'));
            
            % Assert folder to import is not empty
            assert(isfolder(folderToImport), 'The folder does not exist!')
            
            waitfor(msgbox(['The folder should be organized like this: ' ...
               newline 'the extension is by default .eeg (to change)']));
            
            % Extract files
            contentOfFolder = dir(folderToImport);
            
            index = 0;
            for i = 1:length(contentOfFolder)

                folder = contentOfFolder(i).name;

                % skip . and .. folder
                if strcmp(folder, '.') || strcmp(folder, '..')
                   continue 
                end
                
                index = index + 1;
                file = dir(fullfile(contentOfFolder(i).folder, contentOfFolder(i).name, strcat('*', extension)));
                obj.Parameters.Subjects{index} = folder;
                obj.Parameters.RawFiles{index} = fullfile({file.folder}, {file.name});
            end
        end
        
        function deleteSProcess(obj)
            
            obj.sProcess = [];
            
        end
        
    end
    
    methods (Access = protected)
        
        function constructorWithStructure(obj, structure)
            
            obj.Name = structure.Name;
            obj.initialization();

            correctFields = intersect(properties(obj), fieldnames(structure));
            
            for i = 1:length(correctFields)
                
                obj.(correctFields{i}) = structure.(correctFields{i});
                
            end
            
            obj.switchColumnParameterToVector();
                
        end
        
        function constructorWithName(obj, nameOrStructure)
            
            obj.Name = strtrim(nameOrStructure);
            obj.initialization();
            
        end
        
        function initialization(obj)
            
            obj.Parameters = struct();
            
            obj.IsGeneral = true;
            switch obj.Name

                case obj.GeneralProcesses(1)
                    obj.fName = 'process_import_data_raw'; 
                    obj.Parameters.Subjects = cell.empty();
                    obj.Parameters.RawFiles = cell.empty();
                
                case obj.GeneralProcesses(2)
                    obj.fName = 'process_notch';
                    obj.Parameters.Frequence = double.empty();
            
                case obj.GeneralProcesses(3)
                    obj.fName = 'process_bandpass';
                    obj.Parameters.Frequence = double.empty();

                case obj.GeneralProcesses(4)
                    obj.fName = 'process_psd';
                    obj.Parameters.WindowLength = double.empty();

                case obj.GeneralProcesses(5)
                    obj.fName = 'process_ica';
                    obj.Parameters.NumberOfComponents = double.empty();

                case obj.GeneralProcesses(6)
                    obj.fName = 'process_export_bids';
                    obj.Parameters.Folder = char.empty();
                    obj.Parameters.DataFileFormat = char.empty();
                    
                otherwise
                    obj.IsGeneral = false;
            end
        end
        
        function addToHistory(obj)
            % Adds an entry to the history of the process everytime the
            % process is ran. The entry has the name of the process and the
            % date/time.

            row = size(obj.History, 1);
            obj.History{row+1, 1} = obj.Name;
            obj.History{row+1, 2} = Utility.get_Time_Now();
            
        end
              
        function isValid = verifyParameterStructure(obj, parameters)

            fieldsIn = fieldnames(parameters);

            incorrectFields = setxor(fieldsIn, intersect(fieldsIn, fieldnames(obj.Parameters)));

            assert(isempty(incorrectFields), ...
                ['Error with field names! The following fieldnames are incorrect:'...
                newline newline strjoin(incorrectFields, '\n') newline newline ...
                'Here are the list of fields allowed:' newline newline obj.printParameterFields()]);

            for i = 1:length(fieldsIn)
                
               assert(isa(parameters.(fieldsIn{i}), class(obj.Parameters.(fieldsIn{i}))), ...
                   ['Wrong class!' 'The value for the field ' fieldsIn{i} ' must be a ' class(obj.Parameters.(fieldsIn{i})) '.' ...
                   ' Right now, your value is of class ' class(parameters.(fieldsIn{i})) '.']);
                
            end
            
            isValid = true;
            return
            
        end
        
        function switchColumnParameterToVector(obj)
            
           fields = fieldnames(obj.Parameters);
           
           for i = 1:length(fields)
              
               param = obj.Parameters.(fields{i});
               if iscolumn(param)
                   obj.Parameters.(fields{i}) = param';
               end
               
           end
        end

        function ch = printSupportedProcess(obj)
            % Format the supported Processes to characters.
            % param[out]: Supported Process formated [char]
            
            ch = [upper(obj.Type) ' PROCESSES:' ...
                newline char(strjoin(obj.SpecificProcesses, '\n')) ...
                newline newline ...
                'GENERAL PROCESSES:' newline char(strjoin(obj.GeneralProcesses, '\n'))];
            
        end

        function strParameters = printParametersWithValues(obj)
            % Format the parameters to characters.
            % param[out]: Parameters formated [char]            
            
            fields = fieldnames(obj.Parameters);
            if isempty(fields)
                strParameters = strings(1,1);
                strParameters(1) =  'No Parameters';
                return
            end
            
            strParameters = strings(1, length(fields));
            for i = 1:length(fields)
                
                param = obj.Parameters.(fields{i});
                if isempty(param)
                    str_param = ['[' class(param) ']'];
                    
                elseif isstring(param)
                    str_param = convertStringsToChars(strjoin(param, ', '));
                    
                elseif islogical(param)
                    str_param = 'No';
                    if (param)
                        str_param = 'Yes';
                    end
                    
                else
                    str_param = num2str(param);
                    
                end
                
                strParameters(i) = [fields{i} ': ' str_param];
            end
        end
        
        function strParametersFields = printParameterFields(obj)
            
            fieldNames = fields(obj.Parameters);
            
            if isempty(fieldNames)
                strParametersFields = ['No fields for this process (' obj.Name ').'];
                return
            end
            
            % Cell of fields' class
            fieldsClass = cellfun(@(x) class(obj.Parameters.(x)), fieldNames, ...
                'UniformOutput', false);
            
            % Cell of char
            fieldsAndClass = cellfun(@(x, y) [x ': [' y ']'], fieldNames, fieldsClass, 'UniformOutput', false);

            % Join cell
            strParametersFields = strjoin(fieldsAndClass, '\n');
        end      
        
        function ch = printCellContent(~, c)
            
            if isa(c{1}, 'char')

                str = strings(1,length(c));

                for j = 1:length(str)
                    str(j) = c{j};
                end
                ch = char(strjoin(str, ', '));
                
            else 
                ch = num2str(cellfun('length', c));
                
            end
            
        end
             
    end

end