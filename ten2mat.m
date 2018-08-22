function mat = ten2mat( ten,dim,k)
% Tensor unfolding
% dim = (n1,n2,...,nd)
% k=1,2,...,d
mat = reshape(permute(ten,[k,1:k-1,k+1:length(dim)]),dim(k),[]);