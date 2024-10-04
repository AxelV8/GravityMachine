function k1p1(C::Vector{Int64}, Av::Vector{Vector{Int64}}, Ac::Vector{Vector{Int64}}, S::Vector{Int64}, z::Int64, u::Vector{Tuple{Float64, Int64}}, possible::Vector{Bool}, contrainteLibre::Vector{Int64}, listeInter::Vector{Set{Int64}}, inS::Vector{Bool})
	newPossible=Vector{Bool}(undef, length(Av))
	newz=0
	compteur=0
	stock=true
	for i in S
		newPossible=copy(possible)
		for j in listeInter[i]
			newPossible[j]=true
			for k in listeInter[j]
				if ((inS[k]==true)&&(k!=i))
					newPossible[j]=false
				end
			end
		end
		compteur+=1
		for (_, e) in u
			if(newPossible[e])
				newz=z-C[i]+C[e]
				if(newz>z)
					inS[i]=false
					inS[e]=true
					for k in Av[i]
						contrainteLibre[k]=true
					end
					possible[e]=false
					for k in Av[e] #on parcourt les varibles qui apparaisent dans les contraintes 
						contrainteLibre[k]=false
						for p in Ac[k]
							possible[p]=false;
						end
					end
					for k in Av[i]
						stock=true
						for p in Ac[k]
							for j in Av[p]
								if contrainteLibre[j]==false
									stock=false
								end
							end
							if stock
								possible[p]=true
							end
						end
					end
					S[compteur]=e
					return(false, S, newz, possible, contrainteLibre, inS)
				end
			end
		end
	end
	return(true, S, z, possible, contrainteLibre, inS)
end
#kp exchange avec k=0 et p=1
function k0p1(C::Vector{Int64}, Av::Vector{Vector{Int64}}, Ac::Vector{Vector{Int64}}, S::Vector{Int64}, z::Int64, u::Vector{Tuple{Float64, Int64}}, possible::Vector{Bool})
	for (_, e) in u
		if (possible[e])
			possible[e]=false
			for k in Av[e] #on parcourt les varibles qui apparaisent dans les contraintes 
				for p in Ac[k]
					possible[p]=false;
				end
			end
			return (false, append!(S, e), (z+C[e]), possible)
		end
	end
	(true, S, z, possible)
end
#descente de notre algorithme utilisant les kp exchange
function descente(C::Vector{Int64}, Av::Vector{Vector{Int64}}, Ac::Vector{Vector{Int64}}, S::Vector{Int64}, z::Int64, u::Vector{Tuple{Float64, Int64}}, possible::Vector{Bool}, contrainteLibre::Vector{Int64}, listeInter::Vector{Set{Int64}}, inS::Vector{Bool}, bavard::Bool)
	if bavard
		print("|")
	end
	fin=false
	stock=false#si on a rien bougé alors k0p1 sert à rien
	while !(fin)
		(fin, S, z, possible, contrainteLibre, inS)=k2p1(C, Av, Ac, S, z, u, possible, contrainteLibre, listeInter, inS)
		if !(fin)&&bavard
			print("^")
			stock=true
		end
	end
	fin=false
	while !(fin)
		(fin, S, z, possible, contrainteLibre, inS)=k1p1(C, Av, Ac, S, z, u, possible, contrainteLibre, listeInter, inS)
		if !(fin)&&bavard
			print("^")
			stock=true
		end
	end
	if(stock)
		fin=false
		while !(fin)
			(fin, S, z, possible)=k0p1(C, Av, Ac, S, z, u, possible)
			if !(fin)&&bavard
				print("^")
			end
		end
	end
	return (S, z)
end