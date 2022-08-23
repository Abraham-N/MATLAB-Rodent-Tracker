load('Detector.mat') %loading ACF detector created in TrainingDetector
[file,path] = uigetfile({'*.mp4',... %prompt user for video file
    'Video Files (*.mp4,*.avi,*.wmv)'},...
    'Select A Video File')
vidReader = VideoReader(file) %read video file using VideoReader
I = readFrame(vidReader);     %read the first frame of the video, store in I
imshow(I)                     %show the first frame
button = uicontrol('Style','pushbutton','String', 'mark boundaries',...         %button for marking boundaries
    'position',[40 0 150 50],'FontSize',11,'Callback',{@markboundaries, file})  %call back to function markboudaries
%main function to that analyzes each frame of video and analyzes mouse
%position.
function run_analysis(object_handle,event, x_half, y_half, xbounds, ybounds,file,ref)
clf('reset');
detector = load('Detector.mat');          %loading detector and initializing variables
vidReader = VideoReader(file);  
I = readFrame(vidReader);
i = 1;                                   
results = struct('Boxes',[],'Scores',[]);  
line_crossingsCount = uicontrol('Style','text'); 
total_distCount = uicontrol('Style','text');
line_crossings = -1; 
previous_position = 0;
total_dist = 0;
refdist = pdist([[xbounds(1),ybounds(1)];[xbounds(2),ybounds(2)]])
ratio = refdist/ref;
imshow(I);
line_crossingsCount_label = uicontrol('Style', 'text', 'string', "Line Crossings:", ...
        'position', [375 0 150 50], 'FontSize',13); %Create label for number of line crossings
total_distCount_label = uicontrol('Style', 'text', 'string', "Total Distance(cm):", ...
        'position', [100 0 150 50], 'FontSize',13); %Create label for the total distance
stop_button = uicontrol('Style','togglebutton','String', 'stop analysis',... 
    'position',[610 0 150 50],'FontSize',11);%display stop analysis button
while(hasFrame(vidReader))
    hold on
    % GET DATA
    I = readFrame(vidReader); %Read the current frame of the video, store in I
    
    % PROCESS
    [bboxes, scores] = detect(detector.detector,I,'Threshold',1); %store the positions of the mouse
    % Select strongest detection 
    [~,idx] = max(scores); %idx contains the strongest detection of mouse
    
    
    if idx == 0 %if mouse detector failed for this frame, do nothing
    else
    box_position = bboxes(idx,:); %otherwise set box_position to the coordinates stored in bboxes
    end
    
    %Determine position of mouse
    if isempty(box_position) %if mouse detector failed, do nothing
    else %otherwise compare the box_position of the mouse to the defined boundaries
        if box_position(1) > x_half && box_position(2) > y_half ... %if the upper left corner of the box
            && (box_position(2)+box_position(4)) > y_half           %x and y coordinates are greater than boundaries x and y
            position = 4;                                           %set position to 4
        elseif box_position(1) < x_half && (box_position(1)+box_position(3)) < x_half && box_position(2) > y_half ...
                && (box_position(2)+box_position(4)) > y_half
            position = 3;
        elseif box_position(1) < x_half && (box_position(1)+box_position(3)) < x_half && box_position(2) < y_half
            position = 2;
        elseif box_position(1) > x_half && box_position(2) < y_half
            position = 1;
        end
    end
  
    if position ~= previous_position % if the previous position is not the same as current
        line_crossings = line_crossings + 1; %add one to the line_crossings
    end
    
    %calculate the distance in cm from prev to current box
    if exist('prev_box_position', 'var')
    dist = pdist([[prev_box_position(1),prev_box_position(2)];[box_position(1),box_position(2)]])
    dist = dist/ratio
    total_dist = total_dist + dist
    end
   
    %Display the measures
    prev_box_position = box_position
    previous_position = position; %set the previous_position to the current position
    delete(line_crossingsCount); %delete the count of line crossings
    delete(total_distCount);
    line_crossingsStr = int2str(line_crossings); %typecast int to string for line crossings
    line_crossingsCount = uicontrol('Style', 'text', 'string', line_crossingsStr, ...
        'position', [520 20 30 30], 'FontSize',18); %Recreate the linecrossings count and display the count
    total_distStr = int2str(total_dist)
    total_distCount = uicontrol('Style', 'text', 'string', total_distStr, ...
        'position', [250 20 30 30], 'FontSize',18);
    
    results(i).Boxes = bboxes; %store bboxes in struct
    results(i).Scores = scores; %store scores in struct
    
    % VISUALIZE
    annotation = sprintf('%s , Confidence %4.2f',detector.detector.ModelName,scores(idx)); %create annotation for confidence of detection
    I = insertObjectAnnotation(I,'rectangle',bboxes(idx,:),annotation); %insert the annotation
    figure(1) %call figure 1
    imshow(I); %show the current frame
    hold on 
    line([x_half,x_half],[ybounds(1),ybounds(3)]); %show the boundaries for line crossings
    line([xbounds(1),xbounds(2)],[y_half,y_half]);
    hold off
    i = i+1;  %add one to the index for results struct
    
    %Determine if stop_button is pressed
    drawnow
	if get(stop_button,'value')
        stopanalysis(stop_button,results,line_crossings, total_dist, file)
    end
    set(stop_button, 'String', 'stop analysis')
end
results = struct2table(results);%create a table from results struct
saveData(results,line_crossings, total_dist, file)
end

%Function to mark boundaries and set reference length
function markboundaries(object_handle,event,file)
hold on %hold the image of the frame
boundary_instructions = 'Click the vertices of the rectangular boundaries starting in the upper left and work clockwise. Afterwards, enter the length of the top side in cm below.'
boundary_text = uicontrol('Style','text', 'String',boundary_instructions,... %display instructions for setting boundary
    'position', [200 400 350 50], 'FontSize', 11)
[x1,y1] = ginput(1); %take click input from user 
plot(x1,y1,'*b','MarkerSize', 8) %plot a marker on where user clicked
[x2,y2] = ginput(1); %repeat for each vertice
plot(x2,y2,'*b','MarkerSize', 8)
[x3,y3] = ginput(1);
plot(x3,y3,'*b','MarkerSize', 8)
[x4,y4] = ginput(1);
plot(x4,y4,'*b','MarkerSize', 8)
xbounds = [x1,x2,x3,x4]; %add the boundary x coordinates to an array
ybounds = [y1,y2,y3,y4]; %add the boudnary y coordinates to an array
xbounds(1) = xbounds(4)  %make the bounds perfectly rectangular
xbounds(2) = xbounds(3)
ybounds(1) = ybounds(2)
ybounds(3) = ybounds(4)
x_half = (abs((xbounds(2) - xbounds(1))/2)) + xbounds(1) %find the midpoint of x and y sides of rectangle
y_half = (abs((ybounds(4) - ybounds(1))/2)) + ybounds(1)
line([x_half,x_half],[ybounds(1),ybounds(3)]) %show the line crossing boundaries
line([xbounds(1),xbounds(2)],[y_half,y_half])
line([x1,x2,x3,x4,x1],[y1,y2,y3,y4,y1],'LineWidth',3) %show the boundaries drawn by user
userinput = uicontrol('Style','edit','position', [200 300 60 20])
submit = uicontrol('style','pushbutton','string','submit','position', [250,300,60,20], 'callback',{@textget,userinput,x_half,y_half,xbounds,ybounds,file})
hold off 
end

%Stops the analysis and saves the data. Also restarts analysis
function stopanalysis(stop_button,results,line_crossings, total_dist, file)
msgbox(sprintf('The analysis has been stopped'));
set(stop_button, 'String', 'start analysis')
results = struct2table(results);%create a table from results struct
saveData(results,line_crossings, total_dist, file)
    while true
        drawnow
        if get(stop_button,'value')
        else
            break
        end
    end
return
end 

%Takes the user's input for the reference length and displays the start 
%analysis button
function textget(object_handle,event,edit_handle,x_half,y_half,xbounds,ybounds,file)
userinput = get(edit_handle,'string');
ref = str2double(userinput);
analysis_button = uicontrol('Style','pushbutton','String', 'run analysis',... %display run analysis button with callback to run analysis
    'position',[210 0 150 50],'FontSize',11,'Callback',{@run_analysis,x_half,y_half,xbounds,ybounds,file,ref});
end

%Saves the data collected to a text file and excel file
function saveData(results,line_crossings, total_dist, file)
str = sprintf('%s.txt', file);
fid = fopen(str,'wt');
fprintf(fid,'file name\tline crossings\ttotal distance\n');
fprintf(fid,'%s\t%d\t%f\n',file,line_crossings,total_dist);
fclose(fid);
return
end
