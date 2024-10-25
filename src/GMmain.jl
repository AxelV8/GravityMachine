# ==============================================================================
# The gravity machine (Man of Steel) -> to terraform the world

println("""\nAlgorithme "Gravity machine" --------------------------------\n""")

const verbose = true
const graphic = true

println("-) Active les packages requis\n")
using JuMP, GLPK, Printf, Random

NSGATrue= false
borneTrue= true
PlotsOuPyPlot = true
chooseKP = false

if PlotsOuPyPlot
    using Plots
else
    using PyPlot
end
verbose ? println("  Fait \n") : nothing

generateurVisualise = -1

# ==============================================================================

include("GMdatastructures.jl") # types, datastructures and global variables specially defined for GM
include("GMparsers.jl")        # parsers of instances and non-dominated points
include("GMgenerators.jl")     # compute the generators giving the L bound set
include("GMjumpModels.jl")     # JuMP models for computing relaxed optima of the SPA
include("GMrounding.jl")       # Startegies for rounding a LP-solution to a 01-solution
include("GMprojection.jl")     # JuMP models for computing the projection on the polytope of the SPA
include("GMmopPrimitives.jl")  # usuals algorithms in multiobjective optimization
include("GMperturbation.jl")   # routines dealing with the perturbation of a solution when a cycle is detected
include("GMquality.jl")        # quality indicator of the bound set U generated
include("kp_ex.jl")
include("admissible.jl")

include("testNSGAII.jl")

# ==============================================================================
# Ajout d'une solution relachee initiale a un generateur

function ajouterX0!(vg::Vector{tGenerateur}, k::Int64, s::tSolution{Float64})

    vg[k].sRel = deepcopy(s) # met en place le generateur \bar{x}^k
    vg[k].sPrj = deepcopy(s) # le generateur est la premiere projection \bar{x}^{k,0}
    return nothing
end


# ==============================================================================
# Ajout d'une solution entiere (arrondie ou perturbee) a un generateur

function ajouterXtilde!(vg::Vector{tGenerateur}, k::Int64, x::Vector{Int64}, y::Vector{Int64})

    vg[k].sInt.x = copy(x)
    vg[k].sInt.y = copy(y)
    return nothing
end


# ==============================================================================
# Ajout d'une solution fractionnaire (projetee) a un generateur

function ajouterXbar!(vg::Vector{tGenerateur}, k::Int64, x::Vector{Float64}, y::Vector{Float64})

    vg[k].sPrj.x = copy(x)
    vg[k].sPrj.y = copy(y)
    return nothing
end


# ==============================================================================
# Elabore 2 ensembles d'indices selon que xTilde[i] vaut 0 ou 1

function split01(xTilde::Array{Int,1})

   indices0 = (Int64)[]
   indices1 = (Int64)[]

   for i=1:length(xTilde)
       if xTilde[i] == 0
           push!(indices0,i)
       else
           push!(indices1,i)
       end
    end

   return indices0, indices1
end


# ==============================================================================
# test si une solution est admissible en verifiant si sa relaxation lineaire
# conduit a une solution entiere

function estAdmissible(x::Vector{Float64})

    admissible = true
    i=1
    while admissible && i<=length(x)
        if round(x[i], digits=3)!=0.0 && round(x[i], digits=3)!=1.0
            admissible = false
        end
        i+=1
    end
    return admissible
end


# ==============================================================================
# calcule la performance z d'une solution x sur les 2 objectifs

function evaluerSolution(x::Vector{Float64}, c1::Array{Int,1}, c2::Array{Int,1})

    z1 = 0.0; z2 = 0.0
    for i in 1:length(x)
        z1 += x[i] * c1[i]
        z2 += x[i] * c2[i]
    end
    return round(z1, digits=2), round(z2, digits=2)
end


# ==============================================================================
# nettoyage des valeurs des variables d'une solution x relachee sur [0,1]

function nettoyageSolution!(x::Vector{Float64})

    nbvar=length(x)
    for i in 1:nbvar
        if     round(x[i], digits=3) == 0.0
                   x[i] = 0.0
        elseif round(x[i], digits=3) == 1.0
                   x[i] = 1.0
        else
                   x[i] = round(x[i], digits=3)
        end
    end
end


# ==============================================================================
# predicat : verifie si une solution entiere est realisable
function isFeasible(vg::Vector{tGenerateur}, k::Int64)
    #verbose && vg[k].sFea == true ? println("   feasible") : nothing
    return (vg[k].sFea == true)
end


# ==============================================================================
# predicat : verifie si le nombre d'essai maximum a ete tente
function isFinished(trial::Int64, maxTrial::Int64)
#    verbose && trial > maxTrial ? println("   maxTrial") : nothing
    return (trial > maxTrial)
end


# ==============================================================================
# predicat : verifie si le budget de calcul maximum a ete consomme
function isTimeout(temps, maxTime)
#    verbose && time()- temps > maxTime ? println("   maxTime") : nothing
    return (time()- temps > maxTime)
end


# ==============================================================================
# elabore pC le pointeur du cone ouvert vers L

function elaborePointConeOuvertversL(vg::Vector{tGenerateur}, k::Int64, pB::tPoint, pA::tPoint)

    # recupere les coordonnees du point projete
    pC=tPoint(vg[k].sPrj.y[1], vg[k].sPrj.y[2])

    # etablit le point nadir pN au depart des points pA et pB adjacents au generateur k
    pN = tPoint( pA.x , pB.y )

#    print("Coordonnees du cone 2 : ")
#    @show pC, pN

    # retient pN si pC domine pN (afin d'ouvrir le cone)
    if pC.x < pN.x  &&  pC.y < pN.y
        # remplace pC par pN
        pC=tPoint( pA.x , pB.y )
    end

    return pC
end


# ==============================================================================
#= Retourne un booléen indiquant si un point se trouve dans un secteur défini dans
  le sens de rotation trigonométrique (repère X de gauche à droite, Y du haut vers
  le bas).
  https://www.stashofcode.fr/presence-dun-point-dans-un-secteur-angulaire/#more-328
  M    Point dont la position est à tester (point resultant a tester)
  O    Point sommet du secteur (point generateur)
  A    Point de départ du secteur (point adjacent inferieur)
  B    Point d'arrivée du secteur (point adjacent superieur)
  sortie : Booléen indiquant si le point est dans le secteur ou non.

  Exemple :

  B=point(2.0,1.0)
  O=point(2.5,2.5)
  A=point(5.0,5.0)

  M=point(5.0,4.0)
  inSector(M, O, A, B)
=#

function inSector(M, O, A, B)

    cpAB = (A.y - O.y) * (B.x - O.x) - (A.x - O.x) * (B.y - O.y)
    cpAM = (A.y - O.y) * (M.x - O.x) - (A.x - O.x) * (M.y - O.y)
    cpBM = (B.y - O.y) * (M.x - O.x) - (B.x - O.x) * (M.y - O.y)

    if (cpAB > 0)
        if ((cpAM > 0) && (cpBM < 0))
            return true
        else
            return false
        end
    else
        if (!((cpAM < 0) && (cpBM > 0)))
            return true
        else
            return false
        end
    end
end

function inCone(pOrg, pDeb, pFin, pCur)
    # pOrg : point origine du cone (la ou il est pointe)
    # pDeb : point depart du cone (point du rayon [pOrg,pDeb])
    # pFin : point final du cone (point du rayon [pOrg,pFin])
    # pCur : point courant a tester
    # retourne VRAI si pCur est dans le cone pDeb-pFin-pOrg, FAUX sinon

    cp_pDeb_pFin = (pDeb.x - pOrg.x) * (pFin.y - pOrg.y) - (pDeb.y - pOrg.y) * (pFin.x - pOrg.x)
    cp_pDeb_pCur = (pDeb.x - pOrg.x) * (pCur.y - pOrg.y) - (pDeb.y - pOrg.y) * (pCur.x - pOrg.x)
    cp_pFin_pCur = (pFin.x - pOrg.x) * (pCur.y - pOrg.y) - (pFin.y - pOrg.y) * (pCur.x - pOrg.x)

    if (cp_pDeb_pFin > 0)
        if ((cp_pDeb_pCur >= 0) && (cp_pFin_pCur <= 0))
            return true
        else
            return false
        end
    else
        if (!((cp_pDeb_pCur < 0) && (cp_pFin_pCur > 0)))
            return true
        else
            return false
        end
    end
end

function inCone1VersZ(pOrg, pDeb, pFin, pCur)
    return inCone(pOrg, pDeb, pFin, pCur)
end

function inCone2Vers0(pOrg, pDeb, pFin, pCur)
    return !inCone(pOrg, pDeb, pFin, pCur)
end


# ==============================================================================
# Selectionne les points pour le cone pointe sur le generateur k (pCour) et ouvert vers Y
function selectionPoints(vg::Vector{tGenerateur}, k::Int64)
    nbgen = size(vg,1)
    if k==1
        # premier generateur (point predecesseur fictif)
        pPrec = tPoint(vg[k].sRel.y[1], vg[k].sRel.y[2]+1.0)
        pCour = tPoint(vg[k].sRel.y[1], vg[k].sRel.y[2])
        pSuiv = tPoint(vg[k+1].sRel.y[1], vg[k+1].sRel.y[2])
    elseif k==nbgen
        # dernier generateur (point suivant fictif)
        pPrec = tPoint(vg[k-1].sRel.y[1], vg[k-1].sRel.y[2])
        pCour = tPoint(vg[k].sRel.y[1], vg[k].sRel.y[2])
        pSuiv = tPoint(vg[k].sRel.y[1]+1.0, vg[k].sRel.y[2])
    else
        # generateur non extreme
        pPrec = tPoint(vg[k-1].sRel.y[1], vg[k-1].sRel.y[2])
        pCour = tPoint(vg[k].sRel.y[1], vg[k].sRel.y[2])
        pSuiv = tPoint(vg[k+1].sRel.y[1], vg[k+1].sRel.y[2])
    end
#    print("Coordonnees du cone 1 : ")
#    @show pPrec, pCour, pSuiv
    return pPrec, pCour, pSuiv
end


# ==============================================================================
# Calcule la direction d'interet du nadir vers le milieu de segment reliant deux points generateurs
function calculerDirections(L::Vector{tSolution{Float64}}, vg::Vector{tGenerateur})
   # function calculerDirections(L, vg::Vector{tGenerateur})

    nbgen = size(vg,1)
    for k in 2:nbgen

        n1 = L[end].y[1]
        n2 = L[1].y[2]

        x1,y1 = vg[k-1].sRel.y[1], vg[k-1].sRel.y[2]
        x2,y2 = vg[k].sRel.y[1], vg[k].sRel.y[2]
        xm=(x1+x2)/2.0
        ym=(y1+y2)/2.0
        Δx = abs(n1-xm)
        Δy = abs(n2-ym)
        λ1 =  1 - Δx / (Δx+Δy)
        λ2 =  1 - Δy / (Δx+Δy)
        @printf("  x1= %7.2f   y1= %7.2f \n",x1,y1)
        @printf("  x2= %7.2f   y2= %7.2f \n",x2,y2)
        @printf("  Δx= %7.2f    Δy= %7.2f \n",Δx,Δy)
        @printf("  λ1= %6.5f    λ2= %6.5f \n",λ1,λ2)
        plot(n1, n2, xm, ym, linestyle="-", color="blue", marker="+")
        annotate("",
                 xy=[xm;ym],# Arrow tip
                 xytext=[n1;n2], # Text offset from tip
                 arrowprops=Dict("arrowstyle"=>"->"))
        println("")
    end

end


# ==============================================================================
# Calcule la direction d'interet du nadir vers un point generateur
function calculerDirections2(L::Vector{tSolution{Float64}}, vg::Vector{tGenerateur})
    #function calculerDirections2(L, vg::Vector{tGenerateur})

    nbgen = size(vg,1)
    λ1=Vector{Float64}(undef, nbgen)
    λ2=Vector{Float64}(undef, nbgen)
    for k in 1:nbgen

        n1 = L[end].y[1]
        n2 = L[1].y[2]

        xm=vg[k].sRel.y[1]
        ym=vg[k].sRel.y[2]
        Δx = abs(n1-xm)
        Δy = abs(n2-ym)
        λ1[k] =  1 - Δx / (Δx+Δy)
        λ2[k] =  1 - Δy / (Δx+Δy)
        @printf("  k= %3d   ",k)
        @printf("  xm= %7.2f   ym= %7.2f ",xm,ym)
        @printf("  Δx= %8.2f    Δy= %8.2f ",Δx,Δy)
        @printf("  λ1= %6.5f    λ2= %6.5f \n",λ1[k],λ2[k])
        if !PlotsOuPyPlot
            if generateurVisualise == -1 
                # affichage pour tous les generateurs
                
                plot(n1, n2, xm, ym, linestyle="-", color="blue", marker="+")
                plot 
                annotate("",
                        xy=[xm;ym],# Arrow tip
                        xytext=[n1;n2], # Text offset from tip
                        arrowprops=Dict("arrowstyle"=>"->")) 
            elseif generateurVisualise == k
                # affichage seulement pour le generateur k
                plot(n1, n2, xm, ym, linestyle="-", color="blue", marker="+")
                plot 
                annotate("",
                        xy=[xm;ym],# Arrow tip
                        xytext=[n1;n2], # Text offset from tip
                        arrowprops=Dict("arrowstyle"=>"->"))
            end 
        end
        #println("")
    end
    return λ1, λ2
end
 

# ==============================================================================
# point d'entree principal

function GM( fname::String,
             tailleSampling::Int64,
             maxTrial::Int64,
             maxTime::Int64
           )

    @assert tailleSampling>=3 "Erreur : Au moins 3 sont requis"

    @printf("0) instance et parametres \n\n")
    verbose ? println("  instance = $fname | tailleSampling = $tailleSampling | maxTrial = $maxTrial | maxTime = $maxTime\n\n") : nothing

    # chargement de l'instance numerique ---------------------------------------
    c1, c2, A = loadInstance2SPA(fname) # instance numerique de SPA
    nbctr = size(A,1)
    nbvar = size(A,2)
    nbobj = 2

    
    # structure pour les points qui apparaitront dans l'affichage graphique
    d = tListDisplay([],[], [],[], [],[], [],[], [],[], [],[], [],[])

    # --------------------------------------------------------------------------
    # --------------------------------------------------------------------------
    @printf("1) calcule les etendues de valeurs sur les 2 objectifs\n\n")

    # calcule la valeur optimale relachee de f1 seule et le point (z1,z2) correspondant
    f1RL, xf1RL = computeLinearRelax2SPA(nbvar, nbctr, A, c1, c2, typemax(Int), 1) # opt fct 1
    minf1RL, maxf2RL = evaluerSolution(xf1RL, c1, c2)

    # calcule la valeur optimale relachee de f2 seule et le point (z1,z2) correspondant
    f2RL, xf2RL = computeLinearRelax2SPA(nbvar, nbctr, A, c1, c2, typemax(Int), 2) # opt fct 2
    maxf1RL, minf2RL = evaluerSolution(xf2RL, c1, c2)

    verbose ? @printf("  f1_min=%8.2f ↔ f1_max=%8.2f (Δ=%.2f) \n",minf1RL, maxf1RL, maxf1RL-minf1RL) : nothing
    verbose ? @printf("  f2_min=%8.2f ↔ f2_max=%8.2f (Δ=%.2f) \n\n",minf2RL, maxf2RL, maxf2RL-minf2RL) : nothing


    # --------------------------------------------------------------------------
    # --------------------------------------------------------------------------
    @printf("2) calcule les generateurs par e-contrainte alternant minimiser z1 et z2\n\n")

    nbgen, L = calculGenerateurs(A, c1, c2, tailleSampling, minf1RL, maxf2RL, maxf1RL, minf2RL, d)

    # --------------------------------------------------------------------------
    # --------------------------------------------------------------------------
    # allocation de memoire pour la structure de donnees -----------------------

    vg = allocateDatastructure(nbgen, nbvar, nbobj)

    # --------------------------------------------------------------------------
    # --------------------------------------------------------------------------
    @printf("3) place L dans structure et verifie l'admissibilite de chaque generateur\n\n")

    for k=1:nbgen

        verbose ? @printf("  %2d  : [ %8.2f , %8.2f ] ", k, L[k].y[1], L[k].y[2]) : nothing

        # copie de l'ensemble bornant inferieur dans la stru de donnees iterative ---
        ajouterX0!(vg, k, L[k])

        # test d'admissibilite et marquage de la solution le cas echeant -------
        if estAdmissible(vg[k].sRel.x)
            ajouterXtilde!(vg, k, convert.(Int, vg[k].sRel.x), convert.(Int, L[k].y))
            vg[k].sFea   = true
            verbose ? @printf("→ Admissible \n") : nothing
            # archive le point obtenu pour les besoins d'affichage    
            if generateurVisualise == -1 
                # archivage pour tous les generateurs
                push!(d.XFeas,vg[k].sInt.y[1])
                push!(d.YFeas,vg[k].sInt.y[2])
            elseif generateurVisualise == k
                # archivage seulement pour le generateur k
                push!(d.XFeas,vg[k].sInt.y[1])
                push!(d.YFeas,vg[k].sInt.y[2])
            end 
        else
            vg[k].sFea   = false
            verbose ? @printf("→ x          \n") : nothing
        end

    end
    verbose ? println("") : nothing

    # --------------------------------------------------------------------------
    # --------------------------------------------------------------------------
    # Sortie graphique

    if PlotsOuPyPlot
        plot(figsize=(6.5,5))
        title!("Gravity Machine")
        xlabel!("z1(x)")
        ylabel!("z2(x)")
    else
        figure("Gravity Machine",figsize=(6.5,5))
        #xlim(25000,45000)
        #ylim(20000,40000)
        xlabel("z1(x)")
        ylabel("z2(x)")
        PyPlot.title("Cone | 1 rounding | 2-$fname")
    end
    

    # --------------------------------------------------------------------------
    # --------------------------------------------------------------------------
    # calcule les directions (λ1,λ2) pour chaque generateur a utiliser lors des projections
    λ1,λ2 = calculerDirections2(L,vg)

    # ==========================================================================

    @printf("4) terraformation generateur par generateur \n\n")

    Lz1=[]
    Lz2=[]
    compteurAdmissibleViaKP=0
    totalKPEffectuer=0

    # ==========================================================================
    # ==========================================================================Calcule d'un nadir "dystopique"
    maxZ1=0
    maxZ2=0
    for point in vg
        if point.sRel.y[1]>maxZ1
            maxZ1=point.sRel.y[1]
        end
        if point.sRel.y[2]>maxZ2
            maxZ2=point.sRel.y[2]
        end
    end
    #maxC1=maximum(c1)
    #maxC2=maximum(c2)
    dystoZ1=maxZ1+1
    dystoZ2=maxZ2+1

    listNSGAZ1=[]
    listNSGAZ2=[]

    solutionX=[]

    list_Admissible = []
    for k in [i for i in 1:nbgen if !isFeasible(vg,i)]
        temps = time()
        trial = 0
        H =(Vector{Int64})[]

#perturbSolution30!(vg,k,c1,c2,d)

        # rounding solution : met a jour sInt dans vg --------------------------
        #roundingSolution!(vg,k,c1,c2,d)  # un cone
        #roundingSolutionnew24!(vg,k,c1,c2,d) # deux cones
        roundingSolutionNew23!(vg,k,c1,c2,d) # un cone et LS sur generateur


        push!(H,[vg[k].sInt.y[1],vg[k].sInt.y[2]])
        println("   t=",trial,"  |  Tps=", round(time()- temps, digits=4))

        while !(t1=isFeasible(vg,k)) && !(t2=isFinished(trial, maxTrial)) && !(t3=isTimeout(temps, maxTime))

            trial+=1

            # projecting solution : met a jour sPrj, sInt, sFea dans vg --------
            projectingSolution!(vg,k,A,c1,c2,λ1,λ2,d)
            println("   t=",trial,"  |  Tps=", round(time()- temps, digits=4))

            if !isFeasible(vg,k)

                # rounding solution : met a jour sInt dans vg --------------------------
                #roundingSolution!(vg,k,c1,c2,d)
                #roundingSolutionnew24!(vg,k,c1,c2,d)
                roundingSolutionNew23!(vg,k,c1,c2,d)
                #=----------------------------------------------KP-EXCHANGEEEEEEEEEE---------------------------------------------------------------------------=#
                println("Print de sInt:")
                

                #=------------------------------------------------AMELIORATION---------------------------------=#
                println("Run les Kp:")
                randomNumber=rand(500:1000)
                totalKPEffectuer+=randomNumber
                list, listz1, listz2 = choose_KP(deepcopy(vg[k]), randomNumber, k, A, c1, c2, λ1, λ2,d, dystoZ1, dystoZ2, borneTrue, chooseKP)
                append!(Lz1, listz1)
                append!(Lz2, listz2)

                println("Taille liste:", length(list))

                #------------------------------------------------PROJECTION DE LA SOLUTION----------------------------------
                #=for i in 1:length(list)
                    projectingSolution!(list, i, A, c1, c2, λ1, λ2,d)
                end=#


                #=---------------------------------------------------------------------------------------------------------=#
                stock_index = []
                #=if length(list) != 0 # A DECOMENTER TODO FIXME 
                    println("on entre dans la boucle")
                    for i in 1:length(list)
                        if admissibleBourin(list[i].sInt.x ,A)#list[i].sFea
                            println("La sol est admissible")
                            compteurAdmissibleViaKP+=1
                            push!(H,[list[i].sInt.y[1],list[i].sInt.y[2]])
                        else
                            push!(stock_index,i)

                        end
                    end
                        println("Taille de truc a sup ", length(stock_index) )
                        println("Taille list de base ",length(list))
                        deleteat!(list,stock_index)
                        println("Taille list apres supp ",length(list))
                    

                    push!(list_Admissible,list)
                end=#

                #=---------------------------------------------------------------------------------------------------------------------------------------------=#
                println("   t=",trial,"  |  Tps=", round(time()- temps, digits=4))

                # test detection cycle sur solutions entieres ------------------
                cycle = [vg[k].sInt.y[1],vg[k].sInt.y[2]] in H
                if (cycle == true)
                    println("CYCLE!!!!!!!!!!!!!!!")
                    # perturb solution
                    perturbSolution30!(vg,k,c1,c2,d)
                end
                push!(H,[vg[k].sInt.y[1],vg[k].sInt.y[2]])
            end
            if NSGATrue
                (nsgaY1, nsgaY2) = NSGAII_GM(c1, c2, A, vg[k].sInt)
                append!(listNSGAZ1, nsgaY1)
                append!(listNSGAZ2, nsgaY2)
            end
        end
        if t1
            println("   feasible \n")
            push!(solutionX, vg[k].sInt.x)
        elseif t2
            println("   maxTrial \n")
        elseif t3
            println("   maxTime \n")
        end


    end

    println("");

    # ==========================================================================

    @printf("5) Extraction des resultats\n\n")


    for k=1:nbgen
        verbose ? @printf("  %2d  : [ %8.2f , %8.2f ] ", k, vg[k].sInt.y[1],vg[k].sInt.y[2]) : nothing
        # test d'admissibilite et marquage de la solution le cas echeant -------
        if vg[k].sFea
            verbose ? @printf("→ Admissible \n") : nothing
        else
            verbose ? @printf("→ x          \n") : nothing
        end
    end

    # allocation de memoire pour les ensembles bornants ------------------------
    U = Vector{tSolution{Int64}}(undef,nbgen)
    for j = 1:nbgen
        U[j] = tSolution{Int64}(zeros(Int64,nbvar),zeros(Int64,nbobj))
    end
    #--> TODO : stocker l'EBP dans U proprement


    # ==========================================================================
    @printf("6) Edition des resultats \n\n")

#    figure("Gravity Machine",figsize=(6.5,5))
    #xlim(25000,45000)
    #ylim(20000,40000)
#    xlabel(L"z^1(x)")
#    ylabel(L"z^2(x)")
    # Donne les points relaches initiaux ---------------------------------------
#    scatter(d.xLf1,d.yLf1,color="blue", marker="x")
#    scatter(d.xLf2,d.yLf2,color="red", marker="+")
    if PlotsOuPyPlot
        graphic ? scatter!(d.xL,d.yL, mc=:blue, markershape=:xcross , label="y in L") : nothing
    else
        graphic ? scatter(d.xL,d.yL,color="blue", marker="x", label = "y in L") : nothing
    end
    # Donne les points entiers -------------------------------------------------
    if PlotsOuPyPlot
        graphic ? scatter!(d.XInt,d.YInt, mc=:orange, markershape=:rect , label="y rounded") : nothing
    else
        graphic ? scatter(d.XInt,d.YInt,color="orange", marker="s", label = "y rounded") : nothing
    end
#    @show d.XInt
#    @show d.YInt

    # Donne les points apres projection Δ(x,x̃) ---------------------------------
    if PlotsOuPyPlot
        graphic ? scatter!(d.XProj,d.YProj, mc=:red, markershape=:xcross , label="y projected") : nothing
    else
        graphic ? scatter(d.XProj,d.YProj, color="red", marker="x", label = "y projected") : nothing
    end
#    @show d.XProj
#    @show d.YProj

    # Donne les points admissibles ---------------------------------------------
    if PlotsOuPyPlot
        graphic ? scatter!(d.XFeas,d.YFeas, mc=:green, markershape=:circle , label="y in F") : nothing
    else
        graphic ? scatter(d.XFeas,d.YFeas, color="green", marker="o", label = "y in F") : nothing
    end
#    @show d.XFeas
#    @show d.YFeas

    # Donne l'ensemble bornant primal obtenu + la frontiere correspondante -----
    #--> TODO : stocker l'EBP dans U proprement
    X_EBP_frontiere, Y_EBP_frontiere, X_EBP, Y_EBP = ExtractEBP(d.XFeas, d.YFeas)
    if PlotsOuPyPlot
        plot!(X_EBP_frontiere, Y_EBP_frontiere, lc=:green, ms=3.0, markershape=:cross)
        scatter!(X_EBP,Y_EBP, mc=:green, markershape=:circle , label="y in U")
    else
        plot(X_EBP_frontiere, Y_EBP_frontiere, color="green", markersize=3.0, marker="x")
        scatter(X_EBP, Y_EBP, color="green", s = 150, alpha = 0.3, label = "y in U")
    end
   
    # Donne les points qui ont fait l'objet d'une perturbation -----------------
    if PlotsOuPyPlot
        scatter!(d.XPert,d.YPert, mc=:magenta, markershape=:rect , label="pertub")
    else
        scatter(d.XPert,d.YPert, color="magenta", marker="s", label ="pertub")
    end

    # Donne les points non-domines exacts de cette instance --------------------
     XN,YN = loadNDPoints2SPA(fname)
     if PlotsOuPyPlot
        plot!(XN, YN, lc=:black, lw=0.75, markershape=:cross, ms=1.0, ls=:dot, label="y in YN")
        scatter!(XN,YN, mc=:black, markershape=:cross)
     else
        plot(XN, YN, color="black", linewidth=0.75, marker="+", markersize=1.0, linestyle=":", label = "y in YN")
        scatter(XN, YN, color="black", marker="+")
     end

    # Affiche le cadre avec les legendes des differents traces -----------------
    if PlotsOuPyPlot
        plot!(legend=:outerright)
    else
        legend(bbox_to_anchor=[1,1], loc=0, borderaxespad=0, fontsize = "x-small")
    end
    #PyPlot.title("Cone | 1 rounding | 2-$fname")

    # Compute the quality indicator of the bound set U generated ---------------
    # Need at least 2 points in EBP to compute the quality indicator
    if length(X_EBP) > 1
        quality = qualityMeasure(XN,YN, X_EBP,Y_EBP)
        @printf("Quality measure: %5.2f %%\n", quality*100)
    end

    #@show A
    if PlotsOuPyPlot
        scatter!(Lz1,Lz2, mc=:pink, markershape=:xcross)
        scatter!(listNSGAZ1,listNSGAZ1, mc=:black, markershape=:xcross)
    else
        scatter(Lz1, Lz2, color="pink", marker="x")
        scatter(listNSGAZ1, listNSGAZ1, color="black", marker="x")
    end


    println(solutionX[1])
    res1, res2=NSGAII_GM_SolAdmissible(c1, c2, A, solutionX)
    scatter!(res1,res2, mc=:black, markershape=:xcross)

    savefig("test")
    println("compteur Admissible Via KP : ", compteurAdmissibleViaKP)
    println("total KP Effectuer : ", totalKPEffectuer)

end

# ==============================================================================

@time GM("sppaa02.txt", 6, 20, 20)
#@time GM("sppnw20.txt", 6, 20, 20)


#@time GM("sppnw04.txt", 6, 20, 20)
#@time GM("sppnw03.txt", 6, 20, 20) #pb glpk
#@time GM("didactic5.txt", 5, 5, 10)
#@time GM("sppnw29.txt", 6, 30, 20)
nothing
