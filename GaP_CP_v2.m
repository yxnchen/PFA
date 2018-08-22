function [tensor_hat,FactorMat,rmse] = GaP_CP_v2(original_tensor,sparse_tensor,varargin)
% Bayesian CP Factorization for Count Data with GaP assumption

dim = size(sparse_tensor);
d = length(dim);
position = find(sparse_tensor~=0);
pos = find(original_tensor>0 & sparse_tensor==0);
binary_tensor = zeros(dim);
binary_tensor(position) = 1;

ip = inputParser;
ip.addParamValue('CP_rank',20,@isscalar);
ip.addParamValue('maxiter',200,@isscalar);
ip.parse(varargin{:});

r_CP = ip.Results.CP_rank;
maxiter = ip.Results.maxiter;

U = cell(d,1);
r = cell(d,1);
p = cell(d,1);
for k = 1:d
    U{k} = rand(dim(k),r_CP);
    r{k} = 50/r_CP*ones(dim(k),1);
    p{k} = 0.5*ones(r_CP,1);
end

a0 = 1e-2;
b0 = 1e-2;
c0 = 1e-2;
d0 = 1e-2;

% figure;
rmse = zeros(maxiter,1);
fprintf('\n------Bayesian CP Factorization for Count Data with GaP assumption------\n');
for iter = 1:maxiter
	% Update x_{nmk}
    % 5s
    mat = kr(kr(U{3},U{2}),U{1});
    mat = mat./sum(mat,2);
    vec = sparse_tensor(:);
    pos0 = find(vec>0);
    new_mat = zeros(dim(1)*dim(2)*dim(3),r_CP);
    new_mat(pos0,:) = mnrnd(vec(pos0),mat(pos0,:));
    X = zeros(dim(1), dim(2), dim(3), r_CP);
    for i = 1:r_CP
        X(:,:,:,i) = reshape(new_mat(:,i),[dim(1),dim(2),dim(3)]);
    end
        
	% Update factor matrices U^{(d)}
    % 0.56s
    X_nk = sum(sum(X,2),3);
    X_mk = sum(sum(X,1),3);
    X_lk = sum(sum(X,1),2);
    for n = 1:dim(1)
        for k = 1:r_CP
            sum_factor = sum(sum(U{2}(:,k)*U{3}(:,k)'));
            U{1}(n,k) = gamrnd(r{1}(n,1)+X_nk(n,1,1,k), p{1}(k,1)./(1-p{1}(k,1)+p{1}(k,1)*sum_factor));
        end
    end
    for m = 1:dim(2)
        for k = 1:r_CP
            sum_factor = sum(sum(U{1}(:,k)*U{3}(:,k)'));
            U{2}(m,k) = gamrnd(r{2}(m,1)+X_mk(1,m,1,k), p{2}(k,1)./(1-p{2}(k,1)+p{2}(k,1)*sum_factor));
        end
    end
    for l = 1:dim(3)
        for k = 1:r_CP
            sum_factor = sum(sum(U{1}(:,k)*U{2}(:,k)'));
            U{3}(l,k) = gamrnd(r{3}(l,1)+X_lk(1,1,l,k), p{3}(k,1)./(1-p{3}(k,1)+p{3}(k,1)*sum_factor));
        end
    end
	
	factor = cp_combination(U,dim);
    tensor_hat = round(factor);
	rmse(iter,1) = sqrt(sum((original_tensor(pos)-tensor_hat(pos)).^2)./length(pos));
	
	% Update hyper-parameter p
    X_k = sum(sum(sum(X,1),2),3);
    for k = 1:r_CP
        p{1}(k,1) = betarnd(c0+X_k(1,1,1,k), d0+sum(r{1}));
        p{2}(k,1) = betarnd(c0+X_k(1,1,1,k), d0+sum(r{2}));
        p{3}(k,1) = betarnd(c0+X_k(1,1,1,k), d0+sum(r{3}));
    end
	
	% Update hyper-parameter r
    % ~3s
    for n = 1:dim(1)
        sum_log_pk = sum(log(ones(r_CP,1) - p{1}));
        L = 0;
        for k = 1:r_CP
            x = X_nk(n,1,1,k);
            if x > 0 
                t = 1:x;
                pro_success = r{1}(n,1)./(t'-1+r{1}(n,1));
                b_t = rand(x,1);
                b_t = (b_t <= pro_success); % bernoulli random number
                L = L + sum(b_t);
            end
        end
        r{1}(n,1) = gamrnd(a0+L, 1./(b0-sum_log_pk));
    end
    for m = 1:dim(2)
        sum_log_pk = sum(log(ones(r_CP,1) - p{2}));
        L = 0;
        for k = 1:r_CP
            x = X_mk(1,m,1,k);
            if x > 0 
               t = 1:x;
               pro_success = r{2}(m,1)./(t'-1+r{2}(m,1));
               b_t = rand(x,1);
               b_t = (b_t <= pro_success); % bernoulli random number
               L = L + sum(b_t);
            end
        end
        r{2}(m,1) = gamrnd(a0+L, 1./(b0-sum_log_pk));
    end
    for l = 1:dim(3)
        sum_log_pk = sum(log(ones(r_CP,1) - p{3}));
        L = 0;
        for k = 1:r_CP
            x = X_lk(1,1,l,k);
            if x > 0 
                t = 1:x;
                pro_success = r{3}(l,1)./(t'-1+r{3}(l,1));
                b_t = rand(x,1);
                b_t = (b_t <= pro_success); % bernoulli random number
                L = L + sum(b_t);
            end
        end
        r{3}(l,1) = gamrnd(a0+L, 1./(b0-sum_log_pk));
    end
    
	
	
	% Print the results
    fprintf('#iteration = %g, #RMSE = %g km/h \n',iter,rmse(iter));
    set(gcf, 'Units', 'Normalized', 'OuterPosition', [0 0 1 1]);
    for k = 1:d
        subplot(1,d+3,k);imagesc(U{k});
    end
    subplot(1,d+3,d+1:d+3);plot(rmse(1:iter));
    ylim([5,7.5]);xlabel('iteration');ylabel('RMSE (km/h)');
    drawnow;
end
FactorMat = U;