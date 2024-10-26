using JuMP, GLPK, Printf, Random
include("GMprojection.jl")

#Faire une autre fonction pour kp 2-2
#attention si liste taille 1 obligé kp 11 
#attention les deux randoms ne sont pas egaux, si c'est le cas on change et apres on shuffle la liste
#random qui choisit entre les deux fonctions

function choose_KP(pb, n::Int64, k::Int64, 
	A::Array{Int,2}, c1::Array{Int,1}, c2::Array{Int,1}, 
	λ1::Vector{Float64}, λ2::Vector{Float64},
	d::tListDisplay, nadirGenerateurZ1, nadirGenerateurZ2, borneTrue, chooseKP::Bool)


	#=---------------------------INITIALISATION------------------------------------=#
	lA::Vector{tGenerateur} = [] 
	nbIter::Int64 = rand(1:n)


	l0::Vector{Int64} = []
	l1::Vector{Int64} = []

	z1=pb.sInt.y[1]
	z2=pb.sInt.y[2]

	z1list=[]
	z2list=[]

	z1Generateur=pb.sRel.y[1]
	z2Generateur=pb.sRel.y[2]
	sommeZ1Z2Generateur=z1Generateur+z2Generateur

	for i in 1:length(pb.sInt.x)
		if pb.sInt.x[i] == 0
			push!(l0,i)
		else
			push!(l1,i)
		end

	end

	#println("Taille lo:", length(l0))
	#println("Taille l1:", length(l1))
	#=------------------------------------------------------------------------=#
	

	if chooseKP
		println("On choisit le kp 1-1")
		return kp_exchangev1(pb, n, k, A, c1, c2, λ1, λ2,d, nadirGenerateurZ1, nadirGenerateurZ2, borneTrue, lA, nbIter, l0, l1, z1, z2, z1list, z2list, sommeZ1Z2Generateur)
	else
		println("On choisit le kp 2-2")
		return kp_exchangev2(pb, n, k, A, c1, c2, λ1, λ2,d, nadirGenerateurZ1, nadirGenerateurZ2, borneTrue, lA, nbIter, l0, l1, z1, z2, z1list, z2list, sommeZ1Z2Generateur)
		if length(l0) == 1 || length(l1) == 1
			println("Liste taille 1, on force le lancement de kp 1-1")
			return kp_exchangev1(pb, n, k, A, c1, c2, λ1, λ2,d, nadirGenerateurZ1, nadirGenerateurZ2, borneTrue, lA, nbIter, l0, l1, z1, z2, z1list, z2list, sommeZ1Z2Generateur)
		end

	end


end

#------------------------------------------------KP_AMELIORATION_GANDIBLEUX-----------------------------------------------=#
function kp_exchangev2(pb, n::Int64, k::Int64, 
	A::Array{Int,2}, c1::Array{Int,1}, c2::Array{Int,1}, 
	λ1::Vector{Float64}, λ2::Vector{Float64},
	d::tListDisplay, nadirGenerateurZ1, nadirGenerateurZ2, borneTrue, lA, nbIter, l0, l1, z1, z2, z1list, z2list, sommeZ1Z2Generateur)

	#println("On entre dans la fonction kp")

	#=lA::Vector{tGenerateur} = [] 
	nbIter::Int64 = rand(1:n)


	l0::Vector{Int64} = []
	l1::Vector{Int64} = []

	z1=pb.sInt.y[1]
	z2=pb.sInt.y[2]

	z1list=[]
	z2list=[]

	z1Generateur=pb.sRel.y[1]
	z2Generateur=pb.sRel.y[2]
	
	sommeZ1Z2Generateur=z1Generateur+z2Generateur

	for i in 1:length(pb.sInt.x)
		if pb.sInt.x[i] == 0
			push!(l0,i)
		else
			push!(l1,i)
		end

	end

	println("Taille lo:", length(l0))
	println("Taille l1:", length(l1))
	=#

	for i in 1:nbIter
		rnd = rand(1:3)

		println("go kp: ", rnd)

		#KP 2-2 check quand les rnd sont egaux et quand la liste est que de
		#----------------------rnd_stock_0--------------------------------
		stock_l0 = rand(l0)
		stock_l0_2 = rand(l0)
		
		#Evite de prendre la meme valeur
		while stock_l0_2 == stock_l0
			stock_l0_2 = rand(l0)
		end
		println(stock_l0)
		println(stock_l0_2)
		#-----------------------------------------------------------------
		#----------------------rnd_stock_1--------------------------------
		stock_l1 = rand(l1)
		stock_l1_2 = rand(l1)
		
		#Evite de prendre la meme valeur
		while stock_l1_2 == stock_l1
			stock_l1_2 = rand(l1)
		end

		println(stock_l1)

		#-------------------------Debut_KP----------------------------------------

		if rnd == 1
			#---------KP_1_1-----------------------
			#=-------MAJ_LIST--------------------=#
			#println("Je supprime dans l0")
			deleteat!(l0, findall(x->x==stock_l0, l0))

			#println("Je supprime dans l1")
			deleteat!(l1, findall(x->x==stock_l1, l1))

			#println("J'ajoute dans l1")
			push!(l1,stock_l0)

			#println("J'ajoute dans l0")
			push!(l0, stock_l1)
			#=-----------------------------------=#
			pb = kp_1_1(pb, stock_l0,stock_l1)
			z1=z1+c1[stock_l0]-c1[stock_l1]
			z2=z2+c2[stock_l0]-c2[stock_l1]
		elseif rnd == 2
			#--------kp_2_2------------------------
			#=-------MAJ_LIST--------------------=#
			#println("Je supprime dans l0")
			deleteat!(l0, findall(x->x==stock_l0, l0))

			#println("Je supprime dans l1")
			deleteat!(l1, findall(x->x==stock_l1, l1))

			#println("J'ajoute dans l1")
			push!(l1,stock_l0)

			#println("J'ajoute dans l0")
			push!(l0, stock_l1)

			#println("Je supprime dans l0")
			deleteat!(l0, findall(x->x==stock_l0_2, l0))

			#println("Je supprime dans l1")
			deleteat!(l1, findall(x->x==stock_l1_2, l1))

			#println("J'ajoute dans l1")
			push!(l1,stock_l0_2)

			#println("J'ajoute dans l0")
			push!(l0, stock_l1_2)
			#=------------------------------------=#
			
			pb = kp_2_2(pb, stock_l0,stock_l1,stock_l0_2,stock_l1_2)
			#FAIRE la MAJ
			z1=z1+c1[stock_l0] + c1[stock_l0_2] - c1[stock_l1] - c1[stock_l1_2]
			z2=z2+c2[stock_l0] + c2[stock_l0_2] - c2[stock_l1] - c2[stock_l1_2]
			
		else
			#---------kp_2_1-----------------------
			#=-------MAJ_LIST--------------------=#
			#println("Je supprime dans l0")
			deleteat!(l0, findall(x->x==stock_l0, l0))

			#println("Je supprime dans l1")
			deleteat!(l1, findall(x->x==stock_l1, l1))

			#println("J'ajoute dans l1")
			push!(l1,stock_l0)

			#println("J'ajoute dans l0")
			push!(l0, stock_l1)

			#println("Je supprime dans l0")
			deleteat!(l0, findall(x->x==stock_l0_2, l0))

			#println("J'ajoute dans l1")
			push!(l1,stock_l0_2)
			#=------------------------------------=#

			pb = kp_2_1(pb, stock_l0,stock_l1,stock_l0_2)

			#METTRE A JOUR LES VALEURS DE Z
			z1=z1-c1[stock_l1] + c1[stock_l0_2] + c1[stock_l0]
			z2=z2-c2[stock_l1] + c2[stock_l0_2] + c2[stock_l0]
		end
		if borneTrue
			while (z1+z2<sommeZ1Z2Generateur)#si notre solution domine la solution de la borne sup alors ça sert à rien on la remonte
				stock_l0 = rand(l0)
				deleteat!(l0, findall(x->x==stock_l0, l0))
				push!(l1,stock_l0)
				pb = kp_0_1(pb, stock_l0)
				z1=z1+c1[stock_l0]
				z2=z2+c2[stock_l0]
			end
			while (z1>nadirGenerateurZ1)||(z2>nadirGenerateurZ2)#si notre solution est dominé par le point "dystopique" alors ça sert à rien on le redessent
				stock_l1 = rand(l1)
				deleteat!(l1, findall(x->x==stock_l1, l1))
				push!(l0, stock_l1)
				pb = kp_1_0(pb, stock_l1)
				z1=z1-c1[stock_l1]
				z2=z2-c2[stock_l1]
			end
		end
		push!(lA, pb)
		push!(z1list, z1)
		push!(z2list, z2)
		#println("On projette la solution")
		#projectingSolution!(lA, i, A, c1, c2, λ1, λ2,d)
		#TRES TRES CHIANT: JETTE UN COUP D'OEIL A LA FONCTION PROJECTING SOLUTION
		#SOLUTION: PUSH TOUTE LES SOLUTIONS DU KP DANS LA ET FAIRE UN BOUCLE DANS LE MAIN QUI TRIE LES SOLUTIONS ADMISSIBLE
		#=if (!lA[i].sFea)
			println("La sol n'est pas admissible")
			#La solution n'est pas admissible trouver une alternative 
		end=#
		#Push l'ensemble du point car on aura surement besoin de l'ajouter soit dans vg soit dans une autre liste 
	end
	println("Fin KP")
	return lA, z1list, z2list
end


#=-----------------------------------------------KP_AMELIORATION_1------------------------------------------------------------=#
function kp_exchangev1(pb, n::Int64, k::Int64, 
	A::Array{Int,2}, c1::Array{Int,1}, c2::Array{Int,1}, 
	λ1::Vector{Float64}, λ2::Vector{Float64},
	d::tListDisplay, nadirGenerateurZ1, nadirGenerateurZ2, borneTrue,  lA, nbIter, l0, l1, z1, z2, z1list, z2list, sommeZ1Z2Generateur)

	println("On entre dans la fonction kp")

	#=
	lA::Vector{tGenerateur} = [] 
	nbIter::Int64 = rand(1:n)


	l0::Vector{Int64} = []
	l1::Vector{Int64} = []

	z1=pb.sInt.y[1]
	z2=pb.sInt.y[2]

	z1list=[]
	z2list=[]

	z1Generateur=pb.sRel.y[1]
	z2Generateur=pb.sRel.y[2]
	sommeZ1Z2Generateur=z1Generateur+z2Generateur

	for i in 1:length(pb.sInt.x)
		if pb.sInt.x[i] == 0
			push!(l0,i)
		else
			push!(l1,i)
		end

	end

	println("Taille lo:", length(l0))
	println("Taille l1:", length(l1))
	=#

	for i in 1:nbIter
		rnd = rand(1:3)
		println("go kp: ", rnd)

		#KP 2-2 check quand les rnd sont egaux et quand la liste est que de
		stock_l0=0
		stock_l1=0
		if length(l0)==0
			rnd=3
		else
			stock_l0 = rand(l0)
			println(stock_l0)
		end
		if length(l1)==0
			rnd=2
		else
			stock_l1 = rand(l1)
			println(stock_l1)
		end

		if rnd == 1
			#=-------MAJ_LIST--------------------=#
			#println("Je supprime dans l0")
			deleteat!(l0, findall(x->x==stock_l0, l0))

			#println("Je supprime dans l1")
			deleteat!(l1, findall(x->x==stock_l1, l1))

			#println("J'ajoute dans l1")
			push!(l1,stock_l0)

			#println("J'ajoute dans l0")
			push!(l0, stock_l1)
			#=-----------------------------------=#
			pb = kp_1_1(pb, stock_l0,stock_l1)
			z1=z1+c1[stock_l0]-c1[stock_l1]
			z2=z2+c2[stock_l0]-c2[stock_l1]
		elseif rnd == 2
			#=-------MAJ_LIST--------------------=#
			#println("Je supprime dans l0")
			deleteat!(l0, findall(x->x==stock_l0, l0))
			#println("J'ajoute dans l1")
			push!(l1,stock_l0)
			#=------------------------------------=#
			
			pb = kp_0_1(pb, stock_l0)
			z1=z1+c1[stock_l0]
			z2=z2+c2[stock_l0]
		else
			#=-------MAJ_LIST--------------------=#
			#println("Je supprime dans l1")
			deleteat!(l1, findall(x->x==stock_l1, l1))
			#println("J'ajoute dans l0")
			push!(l0, stock_l1)
			#=------------------------------------=#

			pb = kp_1_0(pb, stock_l1)
			z1=z1-c1[stock_l1]
			z2=z2-c2[stock_l1]
		end
		if borneTrue
			while (z1+z2<sommeZ1Z2Generateur)#si notre solution domine la solution de la borne sup alors ça sert à rien on la remonte
				stock_l0 = rand(l0)
				deleteat!(l0, findall(x->x==stock_l0, l0))
				push!(l1,stock_l0)
				pb = kp_0_1(pb, stock_l0)
				z1=z1+c1[stock_l0]
				z2=z2+c2[stock_l0]
			end
			while (z1>nadirGenerateurZ1)||(z2>nadirGenerateurZ2)#si notre solution est dominé par le point "dystopique" alors ça sert à rien on le redessent
				stock_l1 = rand(l1)
				deleteat!(l1, findall(x->x==stock_l1, l1))
				push!(l0, stock_l1)
				pb = kp_1_0(pb, stock_l1)
				z1=z1-c1[stock_l1]
				z2=z2-c2[stock_l1]
			end
		end
		push!(lA, pb)
		push!(z1list, z1)
		push!(z2list, z2)
		#println("On projette la solution")
		#projectingSolution!(lA, i, A, c1, c2, λ1, λ2,d)
		#TRES TRES CHIANT: JETTE UN COUP D'OEIL A LA FONCTION PROJECTING SOLUTION
		#SOLUTION: PUSH TOUTE LES SOLUTIONS DU KP DANS LA ET FAIRE UN BOUCLE DANS LE MAIN QUI TRIE LES SOLUTIONS ADMISSIBLE
		#=if (!lA[i].sFea)
			println("La sol n'est pas admissible")
			#La solution n'est pas admissible trouver une alternative 
		end=#
		#Push l'ensemble du point car on aura surement besoin de l'ajouter soit dans vg soit dans une autre liste 
	end
	println("Fin KP")
	return lA, z1list, z2list
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

function kp_2_1(pb,i,j,k)
	pb.sInt.x[i] == 1
	pb.sInt.x[j] == 0

	pb.sInt.x[k] == 1

	return pb
end

function kp_2_2(pb,i,j,k,l)
	pb.sInt.x[i] == 1
	pb.sInt.x[j] == 0

	pb.sInt.x[k] == 1
	pb.sInt.x[l] == 0

	return pb
end

