function net= yul_addLayers(net, opts, dbTrain)
    
    
    
    methodOpts= strsplit(opts.method, '_');
    [~, sz]= relja_netOutputDim(net);
    D= sz(3);
    
    if ismember('preL2', methodOpts)
        % normalize feature-wise
        net.layers{end+1}= struct('type', 'normalize', 'name', 'preL2', ...
            'param', [2*D, 1e-12, 1, 0.5]);
        methodOpts= removeOpt(methodOpts, 'preL2');
        doPreL2= true;
    else
        doPreL2= false;
    end
    
    if ismember('n2h', methodOpts)
        % normalize feature-wise
        net.layers{end+1}= struct('type', 'put_n_2_h', 'name', 'concatframe');
        methodOpts= removeOpt(methodOpts, 'n2h');
    end
    
    
    
    if relja_startsWith(opts.method, 'max')
        methodOpts= removeOpt(methodOpts, 'max');
        net.layers{end+1}= layerTotalMaxPool('max:core');
        
        
        
    elseif relja_startsWith(opts.method, 'avg')
        methodOpts= removeOpt(methodOpts, 'avg');
        net.layers{end+1}= layerTotalAvgPool('avg:core');
        
        
        
    elseif relja_startsWith(opts.method, 'vlad')
        
        if doPreL2
            L2str= '_preL2';
        else
            L2str= '';
        end
        
        whichDesc= sprintf('%s_%s%s', opts.netID, opts.layerName, L2str);
        
        k= 64;
        paths= localPaths();
        trainDescFn= sprintf('%s%s_%s_traindescs.mat', paths.initData, dbTrain.name, whichDesc);
        clstFn= sprintf('%s%s_%s_k%03d_clst.mat', paths.initData, dbTrain.name, whichDesc, k);
        
        clsts= getClusters(net, opts, clstFn, k, dbTrain, trainDescFn);
        
        load( trainDescFn, 'trainDescs');
        load( clstFn, 'clsts');
        net.sessionID= sprintf('%s_%s', net.sessionID, dbTrain.name);
        
        
        
        % --- VLAD layer
        
        if relja_startsWith(opts.method, 'vladv2')
            methodOpts= removeOpt(methodOpts, 'vladv2');
            
            % set alpha for sparsity
            [~, dsSq]= yael_nn(clsts, trainDescs, 2); clear trainDescs;
            alpha= -log(0.01)/mean( dsSq(2,:)-dsSq(1,:) ); clear dsSq;
            
            net.layers{end+1}= layerVLADv2('vlad:core');
            net.layers{end}= net.layers{end}.constructor({alpha*2*clsts, -alpha*sum(clsts.^2,1), -clsts});
            
        elseif relja_startsWith(opts.method, 'vlad_') || strcmp(opts.method, 'vlad')
            % see comments on vladv2 vs vlad in the README_more.md
            
            methodOpts= removeOpt(methodOpts, 'vlad');
            
            % set alpha for sparsity
            clstsAssign= relja_l2normalize_col(clsts);
            dots= sort(clstsAssign'*trainDescs, 1, 'descend'); clear trainDescs;
            alpha= -log(0.01)/mean( dots(1,:) - dots(2,:) ); clear dots;
            
            net.layers{end+1}= layerVLAD('vlad:core');
            net.layers{end}= net.layers{end}.constructor({alpha*clstsAssign, clsts});
            
        else
            error('Unsupported method "%s"', opts.method);
        end
        
        if ismember('intra', methodOpts)
            % --- intra-normalization
            net.layers{end+1}= struct('type', 'normalize', 'name', 'vlad:intranorm', ...
                'param', [2*D, 1e-12, 1, 0.5]);
            methodOpts= removeOpt(methodOpts, 'intra');
        end
        
    else
        error('Unsupported method "%s"', opts.method);
    end
    
    
    
    % --- final normalization
    net.layers{end+1}= layerWholeL2Normalize('postL2');
    
    % --- class layer
    net.layers{end+1} = struct('pad', [0, 0, 0, 0],...
        'type', 'conv',...
        'name', 'cls',...
        'stride', [1, 1],...
        'weights', cell(1, 2));
    net.layers{end}.weight{1} = normrnd(0, 0.001, [1 1 opt.featlen opt.clsnum]);
    
    % --- final softmax layer
%     net.layers{end+1} = struct('pad', [0, 0, 0, 0],...
%         'type', 'softmax',...
%         'name', 'prob');
%     
    % --- check if all options are used
    if ~isempty(methodOpts)
        error('Unsupported options (method=%s): %s', opts.method, strjoin(methodOpts, ', '));
    end
    
    net.sessionID= sprintf('%s_%s', net.sessionID, opts.method);
    net.epoch= 0;
    
end



function opts= removeOpt(opts, optName)
    opts(ismember(opts, optName))= [];
end
