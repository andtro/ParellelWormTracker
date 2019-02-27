function TrackWorms()

global WormTrackerPrefs

PlotFrameRate = str2num(get(findobj('Tag', 'PLOT_FRAME_RATE'), 'String'));    
% Display tracking results every 'PlotFrameRate' frames - increase
% this value (in GUI) to get faster tracking performance


% Get movies to track
% -------------------
MovieNames = {};

%Mname = eval(['get(findobj(''Tag'', ''MOVIE_NAME_' num2str(i) '''), ''String'')']);
Mname = uigetfile;
%Mstart = eval(['get(findobj(''Tag'', ''MOVIE_START_' num2str(1) '''), ''String'')']);
%Mend = eval(['get(findobj(''Tag'', ''MOVIE_END_' num2str(1) '''), ''String'')']);

% Setup figure for plotting tracker results
% -----------------------------------------
WTFigH = findobj('Tag', 'WTFIG');
if isempty(WTFigH)
    WTFigH = figure('Name', 'Tracking Results', ...
        'NumberTitle', 'off', ...
        'Tag', 'WTFIG');
else
    figure(WTFigH);
end

% Start Tracker
% -------------
    FileInfo = VideoReader(Mname);
    Tracks = [];
    tic;
    % Analyze Movie
    % -------------
    %for Frame = 1:FileInfo.Duration * FileInfo.FrameRate
    %frames = 1:Fileinfo.Duration * 
    frameNumber = 0;
    while FileInfo.hasFrame()
        disp("here " + toc);tic;
        % Get Frame
        frameNumber = frameNumber + 1;
        frame = readFrame(FileInfo);%aviread(MovieNames{MN}, Frame);
        
        % Make sure it is gray scale
        %frame = rgb2gray(frame);
        disp("here1 " + toc);tic;
        
        % Convert frame to a binary image 
        if WormTrackerPrefs.AutoThreshold       % use auto thresholding
            Level = graythresh(frame) + WormTrackerPrefs.CorrectFactor;
            Level = max(min(Level,1) ,0);
        else
            Level = WormTrackerPrefs.ManualSetLevel;
        end
        if WormTrackerPrefs.DarkObjects
            BW = ~im2bw(frame, Level);  % For tracking dark objects on a bright background
        else
            BW = im2bw(frame, Level);  % For tracking bright objects on a dark background
        end
        disp("here2 " + toc);tic;
        
        % Identify all objects
        [L,NUM] = bwlabel(BW);
        disp("here2.5 " + toc);tic;
        STATS = regionprops(L, {'Area', 'Centroid', 'FilledArea', 'Eccentricity'});
        disp("here3 " + toc);tic;
        
        % Identify all worms by size, get their centroid coordinates
        WormIndices = find([STATS.Area] > WormTrackerPrefs.MinWormArea & ...
            [STATS.Area] < WormTrackerPrefs.MaxWormArea);
        NumWorms = length(WormIndices);
        WormCentroids = [STATS(WormIndices).Centroid];
        WormCoordinates = [WormCentroids(1:2:2*NumWorms)', WormCentroids(2:2:2*NumWorms)'];
        WormSizes = [STATS(WormIndices).Area];
        WormFilledAreas = [STATS(WormIndices).FilledArea];
        WormEccentricities = [STATS(WormIndices).Eccentricity];
        disp("here4 " + toc);tic;
        
        % Track worms 
        % ----------- 
        if ~isempty(Tracks)
            ActiveTracks = find([Tracks.Active]);
        else
            ActiveTracks = [];
        end
        
        disp("here5 " + toc);tic;
        % Update active tracks with new coordinates
        for i = 1:length(ActiveTracks)
            DistanceX = WormCoordinates(:,1) - Tracks(ActiveTracks(i)).LastCoordinates(1);
            DistanceY = WormCoordinates(:,2) - Tracks(ActiveTracks(i)).LastCoordinates(2);
            Distance = sqrt(DistanceX.^2 + DistanceY.^2);
            [MinVal, MinIndex] = min(Distance);
            if (MinVal <= WormTrackerPrefs.MaxDistance) & ...
                    (abs(WormSizes(MinIndex) - Tracks(ActiveTracks(i)).LastSize) < WormTrackerPrefs.SizeChangeThreshold)
                Tracks(ActiveTracks(i)).Path = [Tracks(ActiveTracks(i)).Path; WormCoordinates(MinIndex, :)];
                Tracks(ActiveTracks(i)).LastCoordinates = WormCoordinates(MinIndex, :);
                Tracks(ActiveTracks(i)).Frames = [Tracks(ActiveTracks(i)).Frames, frameNumber];
                Tracks(ActiveTracks(i)).Size = [Tracks(ActiveTracks(i)).Size, WormSizes(MinIndex)];
                Tracks(ActiveTracks(i)).LastSize = WormSizes(MinIndex);
                Tracks(ActiveTracks(i)).FilledArea = [Tracks(ActiveTracks(i)).FilledArea, WormFilledAreas(MinIndex)];
                Tracks(ActiveTracks(i)).Eccentricity = [Tracks(ActiveTracks(i)).Eccentricity, WormEccentricities(MinIndex)];
                WormCoordinates(MinIndex,:) = [];
                WormSizes(MinIndex) = [];
                WormFilledAreas(MinIndex) = [];
                WormEccentricities(MinIndex) = [];
            else
                Tracks(ActiveTracks(i)).Active = 0;
                if length(Tracks(ActiveTracks(i)).Frames) < WormTrackerPrefs.MinTrackLength
                    Tracks(ActiveTracks(i)) = [];
                    ActiveTracks = ActiveTracks - 1;
                end
            end
        end
        disp("here6 " + toc);tic;
        
        % Start new tracks for coordinates not assigned to existing tracks
        NumTracks = length(Tracks);
        for i = 1:length(WormCoordinates(:,1))
            Index = NumTracks + i;
            Tracks(Index).Active = 1;
            Tracks(Index).Path = WormCoordinates(i,:);
            Tracks(Index).LastCoordinates = WormCoordinates(i,:);
            Tracks(Index).Frames = frameNumber;
            Tracks(Index).Size = WormSizes(i);
            Tracks(Index).LastSize = WormSizes(i);
            Tracks(Index).FilledArea = WormFilledAreas(i);
            Tracks(Index).Eccentricity = WormEccentricities(i);
        end
        disp("here7 " + toc);tic;
        
        % Display every PlotFrameRate'th frame
        if ~mod(frameNumber, PlotFrameRate)
            disp("here7.1 " + toc);tic;
            PlotFrame(WTFigH, frame, Tracks);
            disp("here7.15 " + toc);tic;
            
            FigureName = ['Tracking Results for Frame ', num2str(frameNumber)];
            disp("here7.2 " + toc);tic;
            set(WTFigH, 'Name', FigureName);

            if WormTrackerPrefs.PlotRGB
                disp("here7.3 " + toc);tic;
                RGB = label2rgb(L, @jet, 'k');
                disp("here7.4 " + toc);tic;
                figure(6)
                disp("here7.5 " + toc);tic;
                set(6, 'Name', FigureName);
                disp("here7.6 " + toc);tic;
                imshow(RGB);
                disp("here7.7 " + toc);tic;
                hold on
                disp("here7.8 " + toc);tic;
                if ~isempty(Tracks)
                    ActiveTracks = find([Tracks.Active]);
                else
                    ActiveTracks = [];
                end
                disp("here7.9 " + toc);tic;
            
                for i = 1:length(ActiveTracks)
                    
                    plot(Tracks(ActiveTracks(i)).LastCoordinates(1), ...
                        Tracks(ActiveTracks(i)).LastCoordinates(2), 'wo');
                end
                hold off
            end
            
            if WormTrackerPrefs.PlotObjectSizeHistogram
                figure(7)
                hist([STATS.Area],300)
                set(7, 'Name', FigureName);
                title('Histogram of Object Sizes Identified by Tracker')
                xlabel('Object Size (pixels')
                ylabel('Number of Occurrences')
            end

            if WormTrackerPrefs.PauseDuringPlot
            	pause;
            end
        end
        disp("here8 " + toc);tic;
        
    end    % END for Frame = 1:FileInfo.NumFrames
    
    % Get rid of invalid tracks
    DeleteTracks = [];
    for i = 1:length(Tracks)
        if length(Tracks(i).Frames) < WormTrackerPrefs.MinTrackLength
            DeleteTracks = [DeleteTracks, i];
        end
    end
    Tracks(DeleteTracks) = [];
    
    % Save Tracks
    SaveFileName = [MovieNames{MN}(1:length(MovieNames{MN})-4) '.mat'];
    save(SaveFileName, 'Tracks');
    
end    % END for i = 1:FileNameSize(1)