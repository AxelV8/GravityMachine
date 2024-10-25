function admissibleBourin(X, A)
    (m, n)=size(A)
    for i in 1:m
        listIndex=findall(x -> x==1, A[i, :])
        sum=0
        for j in listIndex
            sum+=X[j]
        end
        if sum!=1
            return false
        end
    end
    return true
end