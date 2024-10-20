using NSGAII
using Plots
using Random: bitrand

include("admissible.jl")


function NSGAII_GM(c1, c2, A, initx)
    nbctr = size(A,1)
    nbvar = size(A,2)

    f1(x) = sum(x[i]+c1[i] for i in 1:nbvar)
    f2(x) = sum(x[i]+c2[i] for i in 1:nbvar)
    z(x) = f1(x), f2(x)

    #retourne 0 si la contrainte est respecté, >0 sinon
    function CV(X)
        sumReturn=0
        for i in 1:nbctr
            listIndex=findall(x -> x==1, A[i, :])
            sum=0
            for j in listIndex
                sum+=X[j]
            end
            if sum!=1
                sum == 0 ? sumReturn+=1 : sumReturn+=sum
            end
        end
        return sumReturn
    end

    initBit=BitVector(undef, nbvar)

    for i in 1:nbvar
        initBit[i]=initx.x[i]==1
    end

    init()=initBit


    println("==================NSGA II==================")

    result = nsga(5, 20, z, init, fCV = CV)

    #result = filter(indiv -> indiv.rank == 1, result)
    listY1=[]
    listY2=[]
    for indiv in result
        println(floor(indiv.y[1]), " ", floor(indiv.y[2]))
        println(admissibleBourin(indiv.x, A))
        if admissibleBourin(indiv.x, A)
            push!(listY1, floor(indiv.y[1]))
            push!(listY2, floor(indiv.y[2]))
        end
    end
    return (listY1, listY2)
end
#plot(figsize=(6.5,5))
#scatter!(listY1, listY2)
#savefig("Nsga2.png")