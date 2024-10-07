using JuMP, GLPK, PyPlot, Printf, Random
include("GMprojection.jl")

function kp_exchange(pb, n::Int64, k::Int64, 
	A::Array{Int,2}, c1::Array{Int,1}, c2::Array{Int,1}, 
	λ1::Vector{Float64}, λ2::Vector{Float64},
	d::tListDisplay)


	lA::tSolution{Int64} = []
	nbIter::Int64 = rand(1:n)

	l0::Vector{Int64} = findall(i : pb.sInt.x[i]== 0)
	l1::Vector{Int64} = findall(i : pb.sInt.x[i]== 1)

	for i in 1:nbIter
		rnd = rand(1:3)
		if rnd == 1
			stock_l0 = rand(l0)
			stock_l1 = rand(l1)

			#=-------MAJ_LIST--------------------=#
			l0 = delete!(l0, stock_l0)
			l1 = push!(l1,stock_l0)

			l1 = delete!(l1, stock_l1)
			l0 = push!(l0, stock_l1)
			#=-----------------------------------=#
			pb = kp_1_1(pb, stock_l0,stock_l1)
		elseif rnd == 2
			#=-------MAJ_LIST--------------------=#
			stock_l0 = rand(l0)
			l0 = delete!(l0, stock_l0)
			l1 = push!(l1,stock_l0)
			#=------------------------------------=#
			
			pb = kp_0_1(pb, stock_l0)
		else
			#=-------MAJ_LIST--------------------=#
			stock_l1 = rand(l1)
			l1 = delete!(l1, stock_l1)
			l0 = push!(l0, stock_l1)
			#=------------------------------------=#

			pb = kp_1_0(pb, stock_l1)
		end

		projectingSolution!(pb,  k, A, c1, c2, λ1, λ2,d)

		#=
		if(?????)
			push!(lA,[vg[k].sInt.y[1],vg[k].sInt.y[2]])
		end
		=#
	end

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