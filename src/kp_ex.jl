using JuMP, GLPK, PyPlot, Printf, Random
include("GMprojection.jl")

function kp_exchange(pb, n::Int64, k::Int64, 
	A::Array{Int,2}, c1::Array{Int,1}, c2::Array{Int,1}, 
	λ1::Vector{Float64}, λ2::Vector{Float64},
	d::tListDisplay)

	println("On entre dans la fonction kp")

	lA::Vector{tGenerateur} = [] 
	nbIter::Int64 = rand(1:n)


	l0::Vector{Int64} = []
	l1::Vector{Int64} = []

	for i in 1:length(pb.sInt.x)
		if pb.sInt.x[i] == 0
			push!(l0,i)
		else
			push!(l1,i)
		end

	end

	println("Taille lo:", length(l0))
	println("Taille l1:", length(l1))
	

	for i in 1:nbIter
		rnd = rand(1:3)
		println("go kp: ", rnd)

		stock_l0 = rand(l0)
		println(stock_l0)
		stock_l1 = rand(l1)
		println(stock_l1)

		if rnd == 1
			#=-------MAJ_LIST--------------------=#
			println("Je supprime dans l0")
			l0 = deleteat!(l0, stock_l0)

			println("Je supprime dans l1")
			l1 = deleteat!(l1, stock_l1)

			println("J'ajoute dans l1")
			l1 = push!(l1,stock_l0)

			println("J'ajoute dans l0")
			l0 = push!(l0, stock_l1)
			#=-----------------------------------=#
			pb = kp_1_1(pb, stock_l0,stock_l1)
		elseif rnd == 2
			#=-------MAJ_LIST--------------------=#
			println("Je supprime dans l0")
			l0 = deleteat!(l0, stock_l0)
			println("J'ajoute dans l1")
			l1 = push!(l1,stock_l0)
			#=------------------------------------=#
			
			pb = kp_0_1(pb, stock_l0)
		else
			#=-------MAJ_LIST--------------------=#
			println("Je supprime dans l1")
			l1 = deleteat!(l1, stock_l1)
			println("J'ajoute dans l0")
			l0 = push!(l0, stock_l1)
			#=------------------------------------=#

			pb = kp_1_0(pb, stock_l1)
		end
		push!(lA, pb)
		println("On projette la solution")
		projectingSolution!(lA, i, A, c1, c2, λ1, λ2,d)
		#TRES TRES CHIANT: JETTE UN COUP D'OEIL A LA FONCTION PROJECTING SOLUTION
		#SOLUTION: PUSH TOUTE LES SOLUTIONS DU KP DANS LA ET FAIRE UN BOUCLE DANS LE MAIN QUI TRIE LES SOLUTIONS ADMISSIBLE
		#=if (!lA[i].sFea)
			println("La sol n'est pas admissible")
			#La solution n'est pas admissible trouver une alternative 
		end=#
		#Push l'ensemble du point car on aura surement besoin de l'ajouter soit dans vg soit dans une autre liste 
	end
	println("Fin KP")
	return lA
end

function kp_1_1(pb,i,j)
	pb.sInt.x[i] == 1
	pb.sInt.x[j] == 0

	return pb
end

function kp_0_1(pb,i)
	pb.sInt.x[i] == 1
	return pb
end

function kp_1_0(pb,i)
	pb.sInt.x[i] == 0
	return pb
end