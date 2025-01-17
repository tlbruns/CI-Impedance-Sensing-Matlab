%% Load Trained Network 

load('D:\Trevor\My Documents\MED lab\Cochlear R01\Impedance Sensing\Experiments\Dissertation data\Zsense_LSTMclassify-min.mat')
net = netZsensing;
net.resetState;

% create a copy for each channel
nets = {net, net, net, net};

%% Configure Serial

if ~isempty(instrfind)
    fclose(instrfind);
    delete(instrfind);
end

s = serial('COM12', 'BaudRate',115200, 'Terminator','LF');
fopen(s);


%% Send command to start sampling

% disp('Press Enter when ready to begin calibration')
% pause
% 
fprintf(s, 's')



%% Read Streaming Data and Compute Average for Bias Calibration

% n_avg_samples = 500;
% update_interval = 25; % [samples]
% 
% n_channels = 4;
% 
% Zdata_avg = nan(n_avg_samples,n_channels);
% count = 0;
% 
% % close/open to flush buffer
% fclose(s);
% fopen(s);
% for ii=1:15
%     fgetl(s);
% end
% 
% 
% % begin reading data
% tic
% while (count<n_avg_samples)
%     data_string = fgetl(s);
%     count = count+1;
%     Zdata_avg(count,:) = cell2mat(textscan(data_string, '%f', 4, 'Delimiter',','));
% 
%     if ~mod(count,update_interval)
%         % print out the current values
%         fprintf('%i: %.2f, %.2f, %.2f, %.2f\n', count, Zdata_avg(count,:))
%     end
% end
% toc
% 
% % compute bias
% bias = mean(Zdata_avg);
% fprintf('\nbias: [%.2f, %.2f, %.2f, %.2f]\n\n', bias)
% fprintf('std:  [%.2f, %.2f, %.2f, %.2f]\n\n', std(Zdata_avg))


%% Read Streaming Data and Compute Predictions

disp('Press Enter when ready to begin trial')
pause

data_rate = 1000/16.923497; % [Hz]
max_samples = ceil(5*60*data_rate);


% bias = [1698.53078 1798.83866 1885.92846 1943.44295]; % [ohms]
n_channels = 4;
update_interval = 10; % [samples]


Zdata = nan(max_samples,n_channels);
predictions = categorical(nan(max_samples,n_channels));
count = 0;

% send command to start running
fprintf(s, 's')

%
hWaitbar = waitbar(0, 'Collecting Data', 'Name', 'CI Impedance Sensing','CreateCancelBtn','delete(gcbf)');
check_flag = false;

% close/open to flush buffer
fclose(s);
fopen(s);
for ii=1:15
    fgetl(s)
end

% begin reading data
tic
while ((count<max_samples) && ishandle(hWaitbar))

if s.BytesAvailable
    data_string = fgetl(s);
    count = count+1;
    Zdata(count,:) = cell2mat(textscan(data_string, '%f', 4, 'Delimiter',','));

    if ~mod(count,update_interval)
        for ii=1:4
            cur_range = (count-update_interval+1):count;
%             min_range = (count-200):count;
%             if min_range(1) < 1
%                 min_range = 1:count;
%             end

            [nets{ii}, p] = classifyAndUpdateState(nets{ii}, Zdata(cur_range, ii)' - min(Zdata(1:count,ii)));
            predictions(cur_range, ii) = p;
        end

        % print out the current predictions
        fprintf('%i: %.2f, %.2f, %.2f, %.2f => %s, %s, %s, %s\n', count, Zdata(count,:), predictions(count,:))

        check_flag = true;
    end
end

if check_flag
    drawnow;
end

end
toc


%% perform remain predictions
for ii=1:4
    cur_range = mod(count,update_interval)+1:count;
    [nets{ii}, p] = classifyAndUpdateState(nets{ii}, Zdata(cur_range, ii)');
    predictions(cur_range, ii) = p;
end

% trim away NaNs
Zdata(count+1:end,:) = [];
predictions(count+1:end,:) = [];


%% Close Serial

fclose(s)