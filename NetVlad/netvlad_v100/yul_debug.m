addpath(genpath(fullfile(fileparts(fileparts(fileparts(pwd))), 'Script')));
loss_te = [];
loss_tr=[];
setup;
netID= 'featmapVlad';
paths= yul_localPaths();
% dbTrain= yul_get_ucf101(paths, 'trainlist01.txt');
% dbVal= yul_get_ucf101(paths, 'testlist01.txt');
% lr= 0.001;
% dbFmTrain = yul_get_dbFm(dbTrain, paths);
% dbFmVal = yul_get_dbFm(dbVal, paths);
% 
% load('output\VLADfeat_pool5.mat');
opts= struct(...
        'netID', 'featmapVlad', ...
        'layerName', 'conv5', ...
        'method', 'vlad_preL2_intra', ...
        'batchSize', 4, ...
        'learningRate', 0.0001, ...
        'lrDownFreq', 5, ...
        'lrDownFactor', 2, ...
        'weightDecay', 0.001, ...
        'momentum', 0.9, ...
        'backPropToLayer', 1, ...
        'fixLayers', [], ...
        'nNegChoice', 1000, ...
        'nNegCap', 10, ...
        'nNegCache', 10, ...
        'nEpoch', 30, ...
        'margin', 0.1, ...
        'excludeVeryHard', false, ...
        'sessionID', [], ...
        'outPrefix', [], ...
        'dbCheckpoint0', [], ...
        'qCheckpoint0', [], ...
        'dbCheckpoint0val', [], ...
        'qCheckpoint0val', [], ...
        'checkpoint0suffix', '', ...
        'info', '', ...
        'test0', true, ...
        'saveFrequency', 2000, ...
        'compFeatsFrequency', 1000, ...
        'computeBatchSize', 10, ...
        'epochTestFrequency', 1, ...
        'doDraw', false, ...
        'printLoss', false, ...
        'printBatchLoss', false, ...
        'nTestSample', 1000, ...
        'nTestRankSample', 5000, ...
        'recallNs', [1:5, 10:5:100], ...
        'useGPU', true, ...
        'numThreads', 12, ...
        'startEpoch', 1, ...
        'clsnum',2, ...
        'featlen', 64*512, ...
        'net', struct([]) ...
        );
    
% load('snapshot/net0_softmax_debug.mat')
% iepoch_ = 1;
% net.lr = opts.learningRate;
% %% --- Add my layers
% % net= yul_addLayers(net, opts, dbFmTrain);
% res=[];
% %% --- Prepare for train
% % net= netPrepareForTrain(net);
% 
opts.backPropToLayer= 1;
    opts.backPropToLayerName= net.layers{opts.backPropToLayer}.name;
    opts.backPropDepth= length(net.layers)-opts.backPropToLayer+1;
%     
opts.batchSize=128;
feattr = zeros(1,1,32768,opts.batchSize,'single');
featte = zeros(1,1,32768,size(label_test, 1),'single');
load('snapshot/net0_softmax_debug.mat');
if opts.useGPU
        net= relja_simplenn_move(net, 'gpu');
end

lr=0.001;
loss_tr = [];
loss_te = [];
for iBatch = 1 : 10000
    %% Train
%     fprintf('Iter:%d --- ', iBatch);
    bid = randperm(size(feature_train, 1), opts.batchSize);
    feattr(1,1,:,:) = feature_train(bid,:)';
    class_t = label_train(bid);
    net.layers{end}.class = single(class_t);
    feattr_gpu = gpuArray(feattr);
    res= yul_simplenn(net, feattr_gpu, 1, [], ...
                'backPropDepth', opts.backPropDepth, ... % just for memory
                'conserveMemoryDepth', true, ...
                'conserveMemory', false);
    [net,res] = accumulate_gradients(opts, lr, opts.batchSize, net, res) ;
    dzdy = res(end).x;
    loss_tr(end+1) = gather(dzdy/opts.batchSize);
%     fprintf('loss=%f\n', loss_tr(end));
    figure(1)
    plot(loss_tr, 'b');
    drawnow;
%% Test
    if mod(iBatch,100)==1
        testloss = 0;
        %test
            featte(1,1,:,:) = feature_test';
            class_t = label_test;
            net.layers{end}.class = single(class_t);
            
            res= yul_simplenn(net, gpuArray(featte), 1, [], ...
                        'backPropDepth', opts.backPropDepth, ... % just for memory
                        'conserveMemoryDepth', true, ...
                        'conserveMemory', false);
            testloss = testloss + res(end).x;
        %
        testloss = gather(testloss) / size(label_test, 1);
        loss_te(end+1) = testloss;
        figure(2)
        fprintf('===========Test loss=%f============\n', loss_te(end));
        plot(loss_te, 'g');
        drawnow;
    end
end % for ibatch

